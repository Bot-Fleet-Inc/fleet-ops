import PostalMime from "postal-mime";

interface Env {
  BOTFLEET_EMAIL: KVNamespace;
  API_TOKEN: string;
}

interface StoredEmail {
  id: string;
  from: string;
  to: string;
  subject: string;
  date: string;
  body: string;
}

/** Authenticate API requests via Bearer token. */
function isAuthorized(request: Request, env: Env): boolean {
  const header = request.headers.get("Authorization");
  if (!header) return false;
  const [scheme, token] = header.split(" ", 2);
  return scheme === "Bearer" && token === env.API_TOKEN;
}

/** Build a JSON response. */
function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export default {
  /** Handle incoming emails — parse and store in KV. */
  async email(message: ForwardableEmailMessage, env: Env): Promise<void> {
    const rawEmail = await new Response(message.raw).arrayBuffer();
    const parsed = await new PostalMime().parse(rawEmail);

    const to = message.to.toLowerCase();
    const timestamp = Date.now();
    const id = `${to}:${timestamp}`;

    const stored: StoredEmail = {
      id,
      from: message.from,
      to,
      subject: parsed.subject || "(no subject)",
      date: parsed.date || new Date(timestamp).toISOString(),
      body: parsed.text || parsed.html || "",
    };

    // Store with 7-day TTL — these are ephemeral verification emails
    await env.BOTFLEET_EMAIL.put(id, JSON.stringify(stored), {
      expirationTtl: 7 * 24 * 60 * 60,
    });
  },

  /** Handle API requests to read/delete stored emails. */
  async fetch(request: Request, env: Env): Promise<Response> {
    if (!isAuthorized(request, env)) {
      return json({ error: "Unauthorized" }, 401);
    }

    const url = new URL(request.url);
    const { pathname } = url;

    // GET /api/emails?to=archi-bot@bot-fleet.org — list emails for an address
    if (request.method === "GET" && pathname === "/api/emails") {
      const to = url.searchParams.get("to")?.toLowerCase();
      if (!to) {
        return json({ error: "Missing 'to' query parameter" }, 400);
      }

      const list = await env.BOTFLEET_EMAIL.list({ prefix: `${to}:` });
      const emails: StoredEmail[] = [];

      for (const key of list.keys) {
        const value = await env.BOTFLEET_EMAIL.get(key.name);
        if (value) {
          emails.push(JSON.parse(value));
        }
      }

      return json({ emails });
    }

    // GET /api/emails/:id — read a specific email
    if (request.method === "GET" && pathname.startsWith("/api/emails/")) {
      const id = decodeURIComponent(pathname.slice("/api/emails/".length));
      const value = await env.BOTFLEET_EMAIL.get(id);
      if (!value) {
        return json({ error: "Not found" }, 404);
      }
      return json(JSON.parse(value));
    }

    // DELETE /api/emails/:id — delete after reading
    if (request.method === "DELETE" && pathname.startsWith("/api/emails/")) {
      const id = decodeURIComponent(pathname.slice("/api/emails/".length));
      await env.BOTFLEET_EMAIL.delete(id);
      return json({ deleted: true });
    }

    return json({ error: "Not found" }, 404);
  },
};
