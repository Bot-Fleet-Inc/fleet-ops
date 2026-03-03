import type { Env, ChatMessage } from "./index";

/** All bots in the fleet — used for broadcast messages. */
const BOTS = [
  "dispatch-bot",
  "archi-bot",
  "audit-bot",
  "coding-bot",
  "design-bot",
  "project-mgmt-bot",
  "devops-proxmox-bot",
  "devops-cloudflare-bot",
  "unifi-network-bot",
  "crm-bot",
];

const TTL_30_DAYS = 30 * 24 * 60 * 60;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Authenticate bot API requests via Bearer token. */
function isAuthorized(request: Request, env: Env): boolean {
  const header = request.headers.get("Authorization");
  if (!header) return false;
  const [scheme, token] = header.split(" ", 2);
  return scheme === "Bearer" && token === env.API_TOKEN;
}

export async function handleApiRequest(
  request: Request,
  url: URL,
  env: Env,
): Promise<Response> {
  const { pathname } = url;

  // ── Bot-facing endpoints (Bearer token auth) ──────────────────────

  if (pathname.startsWith("/api/inbox")) {
    if (!isAuthorized(request, env)) {
      return json({ error: "Unauthorized" }, 401);
    }

    // GET /api/inbox?bot=<name>&since=<ts>
    // Bot polls for new messages from the human.
    if (request.method === "GET" && pathname === "/api/inbox") {
      const bot = url.searchParams.get("bot");
      if (!bot) return json({ error: "Missing 'bot' query parameter" }, 400);

      const since = url.searchParams.get("since") || "";

      const list = await env.BOTFLEET_CHAT.list({ prefix: `msg:${bot}:` });
      const messages: ChatMessage[] = [];

      for (const key of list.keys) {
        const value = await env.BOTFLEET_CHAT.get(key.name);
        if (value) {
          const msg: ChatMessage = JSON.parse(value);
          if (!since || msg.timestamp > since) {
            messages.push(msg);
          }
        }
      }

      messages.sort((a, b) => a.timestamp.localeCompare(b.timestamp));
      return json({ messages });
    }

    // POST /api/inbox/:msgId/reply
    // Bot posts a reply to a specific human message.
    if (request.method === "POST" && pathname.endsWith("/reply")) {
      const middle = pathname.slice("/api/inbox/".length, -"/reply".length);
      const msgId = decodeURIComponent(middle);

      const original = await env.BOTFLEET_CHAT.get(msgId);
      if (!original) return json({ error: "Original message not found" }, 404);

      const originalMsg: ChatMessage = JSON.parse(original);

      let body: string;
      try {
        const parsed = (await request.json()) as { body: string };
        body = parsed.body;
      } catch {
        return json({ error: "Invalid JSON body" }, 400);
      }
      if (!body) return json({ error: "Missing 'body' in request" }, 400);

      const now = Date.now();
      const bot = originalMsg.to;
      // Key: reply:<bot>:<original-timestamp>:<reply-timestamp>
      const originalTs = originalMsg.id.split(":")[2];
      const replyId = `reply:${bot}:${originalTs}:${now}`;

      const reply: ChatMessage = {
        id: replyId,
        from: bot,
        to: "human",
        body,
        timestamp: new Date(now).toISOString(),
        replyTo: msgId,
      };

      await env.BOTFLEET_CHAT.put(replyId, JSON.stringify(reply), {
        expirationTtl: TTL_30_DAYS,
      });

      return json(reply, 201);
    }

    return json({ error: "Not found" }, 404);
  }

  // ── Human-facing endpoints (protected by Cloudflare Zero Trust) ───

  // GET /api/messages?bot=<name>
  // Human views the full conversation with a specific bot.
  if (request.method === "GET" && pathname === "/api/messages") {
    const bot = url.searchParams.get("bot");
    if (!bot) return json({ error: "Missing 'bot' query parameter" }, 400);

    // Fetch both directions: human→bot and bot→human
    const [sentList, replyList] = await Promise.all([
      env.BOTFLEET_CHAT.list({ prefix: `msg:${bot}:` }),
      env.BOTFLEET_CHAT.list({ prefix: `reply:${bot}:` }),
    ]);

    const messages: ChatMessage[] = [];

    for (const key of [...sentList.keys, ...replyList.keys]) {
      const value = await env.BOTFLEET_CHAT.get(key.name);
      if (value) messages.push(JSON.parse(value));
    }

    messages.sort((a, b) => a.timestamp.localeCompare(b.timestamp));
    return json({ messages });
  }

  // POST /api/messages — Human sends a message: { to, body }
  // Use to: "broadcast" to send to all bots.
  if (request.method === "POST" && pathname === "/api/messages") {
    let to: string;
    let body: string;
    try {
      const parsed = (await request.json()) as { to: string; body: string };
      to = parsed.to;
      body = parsed.body;
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }
    if (!to || !body) return json({ error: "Missing 'to' or 'body'" }, 400);

    const now = Date.now();
    const targets = to === "broadcast" ? BOTS : [to];
    const sent: ChatMessage[] = [];

    for (const bot of targets) {
      const id = `msg:${bot}:${now}`;
      const msg: ChatMessage = {
        id,
        from: "human",
        to: bot,
        body,
        timestamp: new Date(now).toISOString(),
      };

      await env.BOTFLEET_CHAT.put(id, JSON.stringify(msg), {
        expirationTtl: TTL_30_DAYS,
      });

      sent.push(msg);
    }

    return json({ messages: sent }, 201);
  }

  return json({ error: "Not found" }, 404);
}
