// CloudFlare Worker — FacturaApp API Proxy
// Handles authentication and forwards AI requests to Claude/OpenAI

const CLAUDE_API_KEY = "YOUR_CLAUDE_API_KEY_HERE";
const OPENAI_API_KEY = "YOUR_OPENAI_API_KEY_HERE";
const APPLE_VERIFY_URL = "https://buy.itunes.apple.com/verifyReceipt";

// Simple token store (in production, use KV or D1)
const tokens = new Map();

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST",
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
      });
    }

    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }

    try {
      switch (path) {
        case "/auth":
          return await handleAuth(request, env);
        case "/claude":
          return await handleClaude(request, env);
        case "/openai":
          return await handleOpenAI(request, env);
        default:
          return jsonResponse({ error: "Not found" }, 404);
      }
    } catch (e) {
      return jsonResponse({ error: e.message }, 500);
    }
  },
};

// Auth: validate StoreKit receipt, return session token
async function handleAuth(request, env) {
  const body = await request.json();
  const receipt = body.receipt;
  const bundleId = body.bundleId;

  // Validate receipt with Apple (simplified)
  // In production, verify with Apple's server and check subscription status
  if (!receipt || !bundleId) {
    return jsonResponse({ error: "Missing receipt or bundleId" }, 400);
  }

  // Generate session token
  const token = crypto.randomUUID();
  tokens.set(token, {
    created: Date.now(),
    bundleId: bundleId,
    requests: 0,
  });

  return jsonResponse({ token: token, expiresIn: 86400 });
}

// Forward to Claude API
async function handleClaude(request, env) {
  const authCheck = checkAuth(request);
  if (authCheck) return authCheck;

  const body = await request.json();
  const apiKey = env.CLAUDE_API_KEY || CLAUDE_API_KEY;

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(body),
  });

  const data = await response.json();
  incrementRequests(request);
  return jsonResponse(data);
}

// Forward to OpenAI API
async function handleOpenAI(request, env) {
  const authCheck = checkAuth(request);
  if (authCheck) return authCheck;

  const body = await request.json();
  const apiKey = env.OPENAI_API_KEY || OPENAI_API_KEY;

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  const data = await response.json();
  incrementRequests(request);
  return jsonResponse(data);
}

// Auth check
function checkAuth(request) {
  const auth = request.headers.get("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const token = auth.replace("Bearer ", "");
  const session = tokens.get(token);

  if (!session) {
    return jsonResponse({ error: "Invalid token" }, 401);
  }

  // Check expiry (24h)
  if (Date.now() - session.created > 86400000) {
    tokens.delete(token);
    return jsonResponse({ error: "Token expired" }, 401);
  }

  // Rate limit (100 req/hour)
  if (session.requests >= 100) {
    return jsonResponse({ error: "Rate limit exceeded" }, 429);
  }

  return null; // Auth OK
}

function incrementRequests(request) {
  const auth = request.headers.get("Authorization");
  const token = auth?.replace("Bearer ", "");
  if (token && tokens.has(token)) {
    tokens.get(token).requests++;
  }
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
