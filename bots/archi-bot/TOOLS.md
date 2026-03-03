# archi-bot — Available Tools

## Core Tools

### gh CLI
GitHub CLI for issue management.
- `gh issue list` — scan assigned issues
- `gh issue create` — create new issues
- `gh issue comment` — add comments to issues
- `gh issue close` — close completed issues
- `gh pr create` — create pull requests for model changes

### Claude Code CLI
Complex reasoning and file editing.
- Multi-step architecture analysis
- ArchiMate XML editing
- Viewpoint documentation generation

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
