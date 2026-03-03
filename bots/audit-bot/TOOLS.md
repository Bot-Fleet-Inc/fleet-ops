# 🔍 audit-bot — Available Tools

## GitHub CLI (`gh`)

The primary tool for issue management and repository operations. Authenticated via `GITHUB_TOKEN` environment variable.

### Issue Management

```bash
# List assigned issues
gh search issues --assignee=botfleet-audit --state=open --limit=50

# Read issue details
gh issue view <number> --repo Bot-Fleet-Inc/<repo> --json title,body,labels,assignees,comments

# Comment on issue
gh issue comment <number> --repo Bot-Fleet-Inc/<repo> --body "🔍 **audit-bot**: <message>"

# Close issue with summary
gh issue close <number> --repo Bot-Fleet-Inc/<repo> --comment "🔍 **audit-bot**: Completed. <summary>"

# Create new issue
gh issue create --repo Bot-Fleet-Inc/<repo> --title "<title>" --body "<body>" --assignee <user> --label "<labels>"

# Add/remove labels
gh issue edit <number> --repo Bot-Fleet-Inc/<repo> --add-label "status:in-progress"
gh issue edit <number> --repo Bot-Fleet-Inc/<repo> --remove-label "status:needs-triage"

# Transfer issue assignment
gh issue edit <number> --repo Bot-Fleet-Inc/<repo> --add-assignee <other-bot> --remove-assignee botfleet-audit
```

### Pull Request Operations

```bash
# Create PR
gh pr create --repo Bot-Fleet-Inc/<repo> --title "<title>" --body "<body>" --base main --head <branch>

# List PRs needing review
gh pr list --repo Bot-Fleet-Inc/<repo> --state open --json number,title,author

# Review PR
gh pr review <number> --repo Bot-Fleet-Inc/<repo> --approve --body "🔍 **audit-bot**: Approved. <reason>"
gh pr review <number> --repo Bot-Fleet-Inc/<repo> --request-changes --body "🔍 **audit-bot**: Changes requested. <details>"

# Check PR status
gh pr checks <number> --repo Bot-Fleet-Inc/<repo>
```

### Label Management

```bash
# List labels
gh label list --repo Bot-Fleet-Inc/<repo>

# Create label (if it does not exist)
gh label create "<name>" --repo Bot-Fleet-Inc/<repo> --description "<desc>" --color "<hex>"
```

## OpenClaw Runtime

Model-agnostic agent runtime. Selects the right model per task complexity.

| Task Complexity | Model | Provider |
|-----------------|-------|----------|
| Low (classify, label, summarize) | Local LLM | Ollama (A10 GPU) |
| Medium (triage, analysis) | Gemini 2.5 Flash | Google (free tier) |
| High (multi-step analysis) | Claude Sonnet | Anthropic API |
| Critical (complex reasoning) | Claude Opus | Anthropic API |

Config: `.openclaw/openclaw.json` — exec tool allowlist: `gh`, `git`, `curl`

### Usage Guidelines

- OpenClaw automatically routes to the right model based on task complexity.
- Prefer `gh` CLI directly for straightforward issue/PR operations.
- Always include the issue number in prompts for traceability.
- Exec tools are constrained by the `safeBins` allowlist in `openclaw.json`.

## Local LLM Inference

Shared LLM service on the inference VLAN. Use for quick classification, summarization, and extraction tasks that do not require frontier-model reasoning.

### vLLM (Primary) — OpenAI-Compatible API

```bash
# Endpoint
http://172.16.11.10:8000

# Chat completion
curl -s http://172.16.11.10:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "<prompt>"}],
    "max_tokens": 512,
    "temperature": 0.1
  }'

# Health check
curl -s http://172.16.11.10:8000/health
```

### Ollama (Fallback)

```bash
# Endpoint
http://172.16.11.10:11434

# Generate
curl -s http://172.16.11.10:11434/api/generate \
  -d '{
    "model": "<model_name>",
    "prompt": "<prompt>",
    "stream": false
  }'

# Health check
curl -s http://172.16.11.10:11434/api/tags
```

### Recommended Use Cases for Local LLM

| Task | Use Local LLM | Use OpenClaw |
|------|---------------|--------------|
| Issue classification (bug/feature/question) | YES | NO |
| Label suggestion | YES | NO |
| Short text summarization (< 2000 tokens) | YES | NO |
| Code review with reasoning | NO | YES |
| Multi-file analysis | NO | YES |
| Architecture decisions | NO | YES |
| Complex issue triage | NO | YES |

## Bot-Specific Tools

{{BOT_TOOLS}}

## Enterprise Skills

Skills from the enterprise-continuum repository that audit-bot may reference or invoke:

| Skill | Purpose | Reference |
|-------|---------|-----------|
| ea-deploy-proxmox | VM provisioning standards | [SKILL.md](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Skills/ea-deploy-proxmox/SKILL.md) |
| ea-network-unifi | Network configuration standards | [SKILL.md](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Skills/ea-network-unifi/SKILL.md) |
| ea-deploy-cloudflare | Cloudflare deployment patterns | [SKILL.md](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/Skills/ea-deploy-cloudflare/SKILL.md) |

{{BOT_ADDITIONAL_SKILLS}}

## Standard Environment Variables

These variables are injected at runtime and available to all tools:

| Variable | Purpose |
|----------|---------|
| `GITHUB_TOKEN` | GitHub API authentication for `gh` CLI |
| `ANTHROPIC_API_KEY` | Claude API authentication |
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password service account for secret retrieval |
| `BOT_NAME` | This bot's name (`audit-bot`) |
| `BOT_ROLE` | This bot's role (`Compliance review (read-only)`) |
| `BOT_WORKSPACE` | Path to workspace directory |
| `LLM_ENDPOINT` | Local LLM URL (`http://172.16.11.10:8000`) |
| `LLM_FALLBACK_ENDPOINT` | Ollama URL (`http://172.16.11.10:11434`) |
