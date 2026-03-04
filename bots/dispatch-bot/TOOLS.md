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
Quick classification tasks via Ollama (http://172.16.11.10:11434).
- Issue type classification (architecture, code, infrastructure, etc.)
- Priority suggestion from issue body text
- Quick summarization of long issue threads

## Messaging

### Telegram
Human-to-bot messaging via OpenClaw's native Telegram channel binding.

- Messages from the human arrive automatically in the agent session — no polling required
- OpenClaw routes inbound Telegram messages to the agent via the `bindings` config
- Reply inline; the response is sent back to the Telegram conversation automatically

No curl commands or REST endpoints needed — OpenClaw handles the transport.
