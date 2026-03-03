# Bot Resources (BR) Playbook

Living document that evolves with each bot onboarding cycle. BFI's equivalent of HR — **routines and playbooks that improve as we learn**.

**Version**: 1.0
**Last Updated**: 2026-03-03

---

## Philosophy

Workspace files (SOUL.md, IDENTITY.md, CONTEXT.md, AGENTS.md, TOOLS.md, HEARTBEAT.md, MEMORY.md, README.md) are **crafted, not stamped**. The init script creates scaffolding; the BR process creates a colleague.

Each bot onboarding is a unique conversation between Jorgen and Claude that shapes a unique agent. Templates are starting points — the real work happens in the interview and training phases.

---

## Onboarding Phases

| Phase | Duration | Output |
|-------|----------|--------|
| 1. Interview | 1–2 sessions | SOUL.md draft, role boundaries |
| 2. Skill Mapping | 1 session | TOOLS.md, AGENTS.md draft |
| 3. Identity Workshop | 30 min | IDENTITY.md, CONTEXT.md, communication patterns |
| 4. Deployment | 30 min | Running service on Proxmox VM |
| 5. Training | 1–3 days | Iterative workspace file refinement |
| 6. Graduation | Review | Bot declared operational |

---

## Phase 1: Interview

A structured conversation between Jorgen and Claude to define the bot's personality, judgement style, tone, boundaries, and escalation triggers.

### Interview Protocol

**Goal**: Produce a SOUL.md draft that captures who this bot is — not just what it does.

**Questions to explore**:

1. **Mission**: What is this bot's single-sentence purpose? What does it do that no other bot does?
2. **Boundaries**: What must this bot NEVER do? What adjacent work should it refuse?
3. **Judgement style**: When should this bot act autonomously vs. ask for confirmation? What's the threshold?
4. **Communication tone**: Formal or casual? Terse or explanatory? How does it handle disagreement?
5. **Escalation triggers**: What situations should always go to a human? What about to dispatch-bot?
6. **Peer interactions**: How does this bot relate to other fleet members? Who does it depend on? Who depends on it?
7. **Domain expertise**: What domain knowledge does this bot need? What standards does it follow?
8. **Error handling**: When things go wrong, what's the bot's default response? Retry? Escalate? Log and move on?

### Bot Tier Considerations

The interview depth varies by tier:

| Tier | Interview Depth | Focus |
|------|----------------|-------|
| **Manager** (dispatch-bot) | Deep — 2 sessions | Personality, dialogue patterns, judgement heuristics, preference learning |
| **Specialist** (archi-bot, coding-bot, etc.) | Medium — 1 session | Domain expertise, quality standards, escalation rules |
| **Operator** (devops-proxmox-bot, etc.) | Focused — 1 session | Strict boundaries, runbook adherence, confirmation requirements |
| **Service** (crm-bot, design-bot, etc.) | Medium — 1 session | Domain patterns, deliverable standards, request handling |

### Output

- SOUL.md first draft — reviewed and iterated before deployment
- Key decisions captured in the Lessons Learned section below

---

## Phase 2: Skill Mapping

Identify which capabilities the bot needs, select or create tools, and populate TOOLS.md and AGENTS.md.

### Process

1. **List required capabilities** — what actions does this bot perform? (e.g., "read ArchiMate models", "run compliance checks", "create PRs")
2. **Map to tools** — which CLI tools, APIs, or libraries enable each capability?
3. **Define security boundaries** — what can the bot read, write, and never access?
4. **Define the main loop** — what does the bot do every 60 seconds? What are its heartbeat tasks?
5. **Define LLM routing** — which tasks use local LLM (cheap, fast) vs. Claude (expensive, smart)?

### Output

- TOOLS.md — available tools with usage examples
- AGENTS.md — polling config, security boundaries, session lifecycle, main loop definition

---

## Phase 3: Identity Workshop

Define the bot's voice, emoji, communication patterns, and organisational context.

### Process

1. **Choose emoji** — single emoji used in all issue comments (e.g., 📋 for dispatch-bot, 🏛️ for archi-bot)
2. **Define comment prefix** — `<emoji> **<bot-name>**: ` for clear attribution
3. **Set communication patterns** — how does this bot structure its comments? Tables? Checklists? Prose?
4. **Brief on org context** — what does this bot need to know about BFI, its peers, and its infrastructure?
5. **Review fleet-knowledge.md** — ensure the bot's CONTEXT.md is consistent with fleet-wide facts

### Output

- IDENTITY.md — machine identity (GitHub user, email, VMID, IP, hostname)
- CONTEXT.md — organisation, fleet roster, infrastructure, coordination model
- HEARTBEAT.md — periodic task schedule

---

## Phase 4: Deployment

Follow the standard deployment runbook with the bot's customised workspace files.

### Checklist

- [ ] Claude Max subscription active for bot's Google account
- [ ] `claude setup-token` authenticated on VM
- [ ] Workspace files committed and pushed to fleet-ops
- [ ] Secrets injected to `/opt/bot/secrets/<bot-name>.env`
- [ ] gh CLI authenticated
- [ ] systemd unit enabled and started
- [ ] Bot reads all 8 workspace files on startup (verify in journal logs)

### References

- `docs/deployment-runbook.md` — step-by-step VM deployment
- `docs/bot-provisioning-runbook.md` — full provisioning lifecycle

---

## Phase 5: Training

Deploy the bot, assign real work, observe its behaviour, and iteratively refine workspace files.

### Training Protocol

1. **First run**: Watch logs as the bot starts. Verify it reads all files in the correct order.
2. **Simple task**: Assign a straightforward issue that clearly matches the bot's domain.
3. **Observe**: Does it handle the issue correctly? Does the comment tone match SOUL.md?
4. **Edge case**: Assign an ambiguous issue. Does it escalate or ask for clarification?
5. **Cross-domain**: Assign an issue that touches multiple bots' domains. Does it coordinate correctly?
6. **Stress test**: Assign multiple issues simultaneously. Does it prioritise correctly?

### Refinement Loop

After each training task:
1. Review the bot's actions (issue comments, labels, assignments)
2. Identify gaps — wrong assignment? Bad tone? Missed escalation?
3. Update the relevant workspace file (SOUL.md for personality, AGENTS.md for behaviour, TOOLS.md for capabilities)
4. Restart the service to pick up changes
5. Repeat until stable

### What to Watch For

- **Over-dispatch**: Creating too many sub-issues for simple tasks
- **Under-escalation**: Attempting work beyond the bot's boundaries instead of escalating
- **Tone drift**: Comments that don't match SOUL.md's defined style
- **Memory gaps**: Bot forgetting context that should be in MEMORY.md
- **Loop stalls**: Bot getting stuck on an issue and not progressing

---

## Phase 6: Graduation

When is the bot "trained" and ready for autonomous operation?

### Graduation Criteria

| Criterion | Description |
|-----------|-------------|
| **5 clean tasks** | Bot has processed 5+ tasks correctly without human intervention |
| **1 clean escalation** | Bot has correctly escalated at least one ambiguous/out-of-scope issue |
| **Stable tone** | Comments match SOUL.md style consistently |
| **Memory working** | Daily logs are being written; MEMORY.md has been curated at least once |
| **No boundary violations** | Bot has not attempted actions outside its security tier |
| **Restart recovery** | Bot has been restarted and recovered context from memory files |

### Graduation Review

Jorgen reviews the bot's first week of operation:
1. Read through all issue comments by the bot
2. Check MEMORY.md for quality of curated observations
3. Verify no boundary violations in the journal logs
4. Confirm heartbeat tasks are running on schedule
5. Sign off — bot is now fully operational

---

## Lessons Learned

*Updated after each onboarding cycle. Captures what worked, what didn't, and what to change for the next bot.*

### dispatch-bot (2026-03-03) — First Onboarding

- **Blocker**: Claude Code CLI requires subscription auth (`claude auth login`), not just `ANTHROPIC_API_KEY` — discovered after deployment, resolved with Claude Max subscription model
- **Decision**: Adopt OpenClaw workspace patterns (8-file structure, dual memory, heartbeats) without platform dependency
- **Decision**: Claude Max ($100/mo per bot) as auth model — setup token per VM
- **Observation**: Workspace files need more personality depth than templates provide — interview process is essential
- **Process**: Added "Dialogue and Judgement" section to SOUL.md during onboarding — this section is as important as Principles and Boundaries for manager-tier bots

---

## Related Documents

| Document | Purpose |
|----------|---------|
| `CHARTER.md` | BFI founding document — governance, principles, security model |
| `docs/bot-provisioning-runbook.md` | Full provisioning lifecycle (identity → infrastructure → config) |
| `docs/deployment-runbook.md` | VM deployment steps |
| `docs/workspace-standard.md` | 8-file workspace structure specification |
| `shared/config/workspace-template/` | Template files for workspace initialisation |
