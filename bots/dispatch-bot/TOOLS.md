# dispatch-bot — Available Tools

## Core Tools

### gh CLI
GitHub CLI for issue management — dispatch-bot's primary tool.
- `gh issue list` — scan assigned and unassigned issues
- `gh issue create` — create new issues (sub-issues, escalations, reminders)
- `gh issue comment` — add triage comments, assignment rationale
- `gh issue close` — close completed dispatch tasks
- `gh issue edit` — assign issues, add/remove labels
- `gh label list` — verify label existence

### OpenClaw Runtime
Model-agnostic agent runtime. Selects the right model per task complexity.

| Task Complexity | Model | Provider |
|-----------------|-------|----------|
| Low (classify, label, summarize) | Local LLM | Ollama (A10 GPU) |
| Medium (triage, dispatch, chat) | Gemini 2.5 Flash | Google (free tier) |
| High (multi-domain analysis) | Claude Sonnet | Anthropic API |
| Critical (escalation reasoning) | Claude Opus | Anthropic API |

### Local LLM
Quick classification tasks via http://172.16.11.10:8000
- Issue type classification (architecture, code, infrastructure, etc.)
- Priority suggestion from issue body text
- Quick summarization of long issue threads

## Bot-Specific APIs

### Chat Worker

Human-to-bot messaging via Cloudflare Worker + KV. Protected by Cloudflare Zero Trust Access.

- **Base URL**: `https://chat.bot-fleet.org`
- **Auth**: Bearer token (`$CHAT_WORKER_TOKEN`) + Cloudflare Access service token
- **Access headers**: `CF-Access-Client-Id` (`$CF_ACCESS_CLIENT_ID`) and `CF-Access-Client-Secret` (`$CF_ACCESS_CLIENT_SECRET`)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/inbox?bot=dispatch-bot&since=<ISO-ts>` | GET | Poll for new messages from human |
| `/api/inbox/<msgId>/reply` | POST | Reply to a specific message — body: `{"body":"..."}` |

#### Poll example
```bash
curl -s \
  -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
  -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET" \
  -H "Authorization: Bearer $CHAT_WORKER_TOKEN" \
  "https://chat.bot-fleet.org/api/inbox?bot=dispatch-bot&since=$LAST_POLL"
```

#### Reply example
```bash
curl -s -X POST \
  -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
  -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET" \
  -H "Authorization: Bearer $CHAT_WORKER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body":"Acknowledged — creating issue now."}' \
  "https://chat.bot-fleet.org/api/inbox/$MSG_ID/reply"
```
