# archi-bot — Available Tools

## Core Tools

### gh CLI
GitHub CLI for issue management.
- `gh issue list` — scan assigned issues
- `gh issue create` — create new issues
- `gh issue comment` — add comments to issues
- `gh issue close` — close completed issues
- `gh pr create` — create pull requests for model changes

### OpenClaw Runtime
Model-agnostic agent runtime. Selects the right model per task complexity.

| Task Complexity | Model | Provider |
|-----------------|-------|----------|
| Low (classify, label, summarize) | Local LLM | Ollama (A10 GPU) |
| Medium (triage, dispatch, chat) | Gemini 2.5 Flash | Google (free tier) |
| High (multi-domain analysis) | Claude Sonnet | Anthropic API |
| Critical (escalation reasoning) | Claude Opus | Anthropic API |

Config: `.openclaw/openclaw.json` — exec tool allowlist: `gh`, `git`, `curl`

### Local LLM
Quick classification tasks via http://172.16.11.10:8000
- Issue triage and label suggestion
- Quick summarization of infrastructure changes
- Element type classification

## Enterprise Skills

### ea-core-archimate
ArchiMate viewpoint governance and AI-assisted modeling.
- Viewpoint selection and documentation
- Model scope strategy
- BPMN/DMN cross-model integration

### ea-core-advisor
Enterprise architecture consistency validation.
- Cross-standard validation (ArchiMate, BPMN, DMN)
- Technology standards compliance
- Architecture pattern enforcement

## Bot-Specific APIs

None — archi-bot does not access infrastructure APIs directly. Infrastructure state is learned from:
- Git commits to infra/ directory
- Issues created by DevOps bots
- Change management events from change-mgmt-bot
