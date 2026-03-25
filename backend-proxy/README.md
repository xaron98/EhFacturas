# FacturaApp Backend Proxy

CloudFlare Worker that proxies AI API calls for FacturaApp.

## Setup

1. Install wrangler: `npm install -g wrangler`
2. Login: `wrangler login`
3. Set secrets:
   ```
   wrangler secret put CLAUDE_API_KEY
   wrangler secret put OPENAI_API_KEY
   ```
4. Deploy: `wrangler deploy`

## Endpoints

- `POST /auth` — Authenticate with StoreKit receipt
- `POST /claude` — Forward to Claude API
- `POST /openai` — Forward to OpenAI API

## Rate limits

- 100 requests/hour per session
- 24h session expiry
