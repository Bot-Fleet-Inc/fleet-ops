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

/** Read conversation for a bot from a single KV key. */
async function readConversation(
  env: Env,
  bot: string,
): Promise<ChatMessage[]> {
  const raw = await env.BOTFLEET_CHAT.get(`conv:${bot}`);
  if (!raw) return [];
  return JSON.parse(raw) as ChatMessage[];
}

/** Write conversation for a bot to a single KV key. */
async function writeConversation(
  env: Env,
  bot: string,
  messages: ChatMessage[],
): Promise<void> {
  await env.BOTFLEET_CHAT.put(`conv:${bot}`, JSON.stringify(messages), {
    expirationTtl: TTL_30_DAYS,
  });
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
      const conversation = await readConversation(env, bot);
      const messages = conversation.filter(
        (m) => m.from === "human" && (!since || m.timestamp > since),
      );

      return json({ messages });
    }

    // POST /api/inbox/:msgId/reply
    // Bot posts a reply to a specific human message.
    if (request.method === "POST" && pathname.endsWith("/reply")) {
      const middle = pathname.slice("/api/inbox/".length, -"/reply".length);
      const msgId = decodeURIComponent(middle);

      // Extract bot name from msgId (format: msg:<bot>:<timestamp>)
      const parts = msgId.split(":");
      if (parts.length < 3)
        return json({ error: "Invalid message ID format" }, 400);
      const bot = parts[1];

      const conversation = await readConversation(env, bot);
      const original = conversation.find((m) => m.id === msgId);
      if (!original)
        return json({ error: "Original message not found" }, 404);

      let body: string;
      try {
        const parsed = (await request.json()) as { body: string };
        body = parsed.body;
      } catch {
        return json({ error: "Invalid JSON body" }, 400);
      }
      if (!body) return json({ error: "Missing 'body' in request" }, 400);

      const now = Date.now();
      const originalTs = msgId.split(":")[2];
      const replyId = `reply:${bot}:${originalTs}:${now}`;

      const reply: ChatMessage = {
        id: replyId,
        from: bot,
        to: "human",
        body,
        timestamp: new Date(now).toISOString(),
        replyTo: msgId,
      };

      conversation.push(reply);
      await writeConversation(env, bot, conversation);

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

    const messages = await readConversation(env, bot);
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

      const conversation = await readConversation(env, bot);
      conversation.push(msg);
      await writeConversation(env, bot, conversation);

      sent.push(msg);
    }

    return json({ messages: sent }, 201);
  }

  return json({ error: "Not found" }, 404);
}
