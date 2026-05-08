const DEFAULT_MODEL = "gpt-5.4-mini";
const DEFAULT_DAILY_TOKEN_LIMIT = 50000;
const DEFAULT_DAILY_IP_TOKEN_LIMIT = 8000;
const DEFAULT_MAX_INPUT_CHARS = 6000;

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    if (request.method !== "POST") {
      return json({ error: "Method Not Allowed" }, 405);
    }

    if (!env.OPENAI_API_KEY) {
      return json({ error: "AI backend is not configured" }, 500);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }

    const instructions = cleanText(body.instructions);
    const input = cleanText(body.input);
    const maxOutputTokens = Number.isInteger(body.max_output_tokens)
      ? Math.min(Math.max(body.max_output_tokens, 1), 800)
      : 180;
    const estimatedTokens = estimateTokenCost(instructions, input, maxOutputTokens);

    if (!instructions || !input) {
      return json({ error: "Missing instructions or input" }, 400);
    }

    if (instructions.length + input.length > maxInputChars(env)) {
      return json({ error: "AI request is too large" }, 413);
    }

    const usageCheck = await checkTokenBudget(request, env, estimatedTokens);
    if (!usageCheck.allowed) {
      return json({ error: "AI is temporarily unavailable" }, 429);
    }

    const openAIResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: env.OPENAI_MODEL || DEFAULT_MODEL,
        instructions,
        input,
        max_output_tokens: maxOutputTokens
      })
    });

    if (!openAIResponse.ok) {
      return json({ error: "AI request failed" }, 502);
    }

    const data = await openAIResponse.json();
    const text = extractText(data);
    const tokenUsage = actualTokenUsage(data) ?? estimatedTokens;

    if (!text) {
      return json({ error: "AI response did not include text" }, 502);
    }

    await recordTokenUsage(request, env, tokenUsage);

    return json({ text });
  }
};

function cleanText(value) {
  return typeof value === "string" ? value.trim() : "";
}

function extractText(data) {
  if (typeof data.output_text === "string") {
    return data.output_text.trim();
  }

  const text = data.output
    ?.flatMap((item) => item.content ?? [])
    .map((item) => item.text)
    .filter(Boolean)
    .join("\n")
    .trim();

  return text || "";
}

function estimateTokenCost(instructions, input, maxOutputTokens) {
  return Math.ceil((instructions.length + input.length) / 4) + maxOutputTokens;
}

function actualTokenUsage(data) {
  const totalTokens = data?.usage?.total_tokens;
  return Number.isFinite(totalTokens) && totalTokens > 0 ? Math.ceil(totalTokens) : null;
}

async function checkTokenBudget(request, env, estimatedTokens) {
  if (!env.AI_USAGE_KV) {
    return { allowed: true };
  }

  const [globalUsage, ipUsage] = await Promise.all([
    readUsage(env, globalUsageKey()),
    readUsage(env, await ipUsageKey(request))
  ]);

  if (globalUsage + estimatedTokens > dailyTokenLimit(env)) {
    return { allowed: false };
  }

  if (ipUsage + estimatedTokens > dailyIPTokenLimit(env)) {
    return { allowed: false };
  }

  return { allowed: true };
}

async function recordTokenUsage(request, env, tokenUsage) {
  if (!env.AI_USAGE_KV) {
    return;
  }

  await Promise.all([
    incrementUsage(env, globalUsageKey(), tokenUsage),
    incrementUsage(env, await ipUsageKey(request), tokenUsage)
  ]);
}

async function readUsage(env, key) {
  const value = await env.AI_USAGE_KV.get(key);
  const usage = Number.parseInt(value ?? "0", 10);
  return Number.isFinite(usage) ? usage : 0;
}

async function incrementUsage(env, key, amount) {
  const nextUsage = (await readUsage(env, key)) + amount;
  await env.AI_USAGE_KV.put(key, String(nextUsage), { expirationTtl: 60 * 60 * 36 });
}

function globalUsageKey() {
  return `ai-usage:global:${utcDayKey()}`;
}

async function ipUsageKey(request) {
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const ipHash = await sha256(ip);
  return `ai-usage:ip:${utcDayKey()}:${ipHash}`;
}

function utcDayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function sha256(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .slice(0, 12)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function dailyTokenLimit(env) {
  return positiveInteger(env.DAILY_TOKEN_LIMIT, DEFAULT_DAILY_TOKEN_LIMIT);
}

function dailyIPTokenLimit(env) {
  return positiveInteger(env.DAILY_IP_TOKEN_LIMIT, DEFAULT_DAILY_IP_TOKEN_LIMIT);
}

function maxInputChars(env) {
  return positiveInteger(env.MAX_INPUT_CHARS, DEFAULT_MAX_INPUT_CHARS);
}

function positiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function json(payload, status = 200) {
  return Response.json(payload, {
    status,
    headers: corsHeaders()
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  };
}
