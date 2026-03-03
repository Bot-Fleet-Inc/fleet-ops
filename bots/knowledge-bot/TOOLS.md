# knowledge-bot — Tools

## GitHub CLI (`gh`)

### Issues

```bash
gh issue view <number> --repo Bot-Fleet-Inc/<repo> --json title,body,labels,assignees,comments
```
```bash
gh issue comment <number> --repo Bot-Fleet-Inc/<repo> --body "📚 **knowledge-bot**: <message>"
```
```bash
gh issue close <number> --repo Bot-Fleet-Inc/<repo> --comment "📚 **knowledge-bot**: Completed. <summary>"
```
```bash
gh issue create --repo Bot-Fleet-Inc/<repo> --title "<title>" --body "<body>" --assignee <user> --label "<labels>"
```
```bash
gh issue edit <number> --repo Bot-Fleet-Inc/<repo> --add-label "status:in-progress"
gh issue edit <number> --repo Bot-Fleet-Inc/<repo> --remove-label "status:needs-triage"
```

### Pull Requests

```bash
gh pr create --repo Bot-Fleet-Inc/<repo> --title "<title>" --body "<body>" --base main --head <branch>
```

### Labels

```bash
gh label list --repo Bot-Fleet-Inc/<repo>
```

## OpenClaw Runtime

Model-agnostic agent runtime. Selects the right model per task complexity.

| Task Complexity | Model | Provider |
|-----------------|-------|----------|
| Low (classify, label, summarize) | Local LLM | Ollama (A10 GPU) |
| Medium (synthesis, curation) | Gemini 2.5 Flash | Google (free tier) |
| High (KB analysis, reporting) | Claude Sonnet | Anthropic API |
| Critical (complex reasoning) | Claude Opus | Anthropic API |

Config: `.openclaw/openclaw.json` — exec tool allowlist: `gh`, `git`, `curl`

## Local LLM (vLLM)

- **URL**: `http://172.16.11.10:8000`
- **Use for**: Low-complexity classification, tag suggestion, frontmatter validation
- **Fallback**: Claude Sonnet via Anthropic API

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GITHUB_TOKEN` | GitHub PAT for API access |
| `ANTHROPIC_API_KEY` | Claude API access |
| `CHAT_WORKER_TOKEN` | Chat Worker inbox polling |
| `BOT_NAME` | `knowledge-bot` |
| `LOCAL_LLM_URL` | `http://172.16.11.10:8000` |
| `CHAT_WORKER_URL` | `https://botfleet-chat.bot-fleet-inc.workers.dev` |
