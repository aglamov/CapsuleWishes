# AI Backend

Capsule Wishes keeps provider API keys outside the iOS app. The app calls an HTTPS Cloudflare Worker, and the Worker calls OpenAI using a Cloudflare secret.

## Cloudflare Setup

1. Open Cloudflare Dashboard.
2. Go to Workers & Pages.
3. Create or deploy the Worker from `workers/capsule-wishes-ai`.
4. Open the Worker settings.
5. Go to Variables and Secrets.
6. Add a secret named `OPENAI_API_KEY`.
7. Paste the OpenAI API key as the secret value.

Do not add `OPENAI_API_KEY` to `wrangler.toml`, `Info.plist`, build settings, or source files.

## CLI Setup

If Wrangler is installed and authenticated:

```sh
cd workers/capsule-wishes-ai
wrangler secret put OPENAI_API_KEY
wrangler deploy
```

After deploy, use the Worker URL as the app endpoint:

```text
CAPSULE_WISHES_AI_ENDPOINT=https://capsule-wishes-ai.<account>.workers.dev
```

The iOS app sends:

```json
{
  "instructions": "...",
  "input": "...",
  "max_output_tokens": 180
}
```

The Worker returns:

```json
{
  "text": "..."
}
```

## Opaque Usage Limits

The Worker keeps AI limits hidden from the app UI. If a limit is reached, it returns `429`, and the iOS app falls back to local non-AI text.

The built-in request limits are configured through Worker variables:

```text
DAILY_TOKEN_LIMIT=50000
DAILY_IP_TOKEN_LIMIT=8000
MAX_INPUT_CHARS=6000
```

Daily token counters require an optional Cloudflare KV binding named `AI_USAGE_KV`. Without that binding, the Worker still applies per-request size and output-token caps, but cannot persist daily usage.
