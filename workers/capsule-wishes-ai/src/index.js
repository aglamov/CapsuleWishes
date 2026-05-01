const DEFAULT_MODEL = "gpt-5.4-mini";

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

    if (!instructions || !input) {
      return json({ error: "Missing instructions or input" }, 400);
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

    if (!text) {
      return json({ error: "AI response did not include text" }, 502);
    }

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
