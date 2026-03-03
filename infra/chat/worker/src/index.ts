import { handleApiRequest } from "./api";
import { renderUI } from "./ui";

export interface Env {
  BOTFLEET_CHAT: KVNamespace;
  API_TOKEN: string;
}

export interface ChatMessage {
  id: string;
  from: "human" | string; // "human" or bot name
  to: string; // bot name or "broadcast"
  body: string; // plain text
  timestamp: string; // ISO 8601
  replyTo?: string; // original message ID (for bot replies)
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/")) {
      return handleApiRequest(request, url, env);
    }

    // Serve chat web UI
    if (url.pathname === "/" || url.pathname === "") {
      return renderUI();
    }

    return new Response("Not Found", { status: 404 });
  },
};
