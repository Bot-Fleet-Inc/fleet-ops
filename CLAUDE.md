# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Repository Overview

**fleet-ops** is the operational workspace for Bot Fleet Inc (BFI) — an autonomous AI bot fleet organisation. Bots are persistent AI agents that collaborate via GitHub Issues.

## Key Concepts

- **GitHub Issues = coordination bus** — bots communicate by creating, assigning, and closing issues
- **Each bot** has its own directory under `bots/`, with workspace files defining identity, mission, tools, and behaviour
- **Bot Fleet Inc (BFI)** is the bots' GitHub organisation — bots only operate within BFI repos
- **All bots** run on dedicated Proxmox VMs with 4-tier LLM routing via OpenClaw runtime

## BFI Repositories

| Repo | Purpose |
|------|---------|
| `Bot-Fleet-Inc/fleet-ops` (this repo) | Bot implementations, shared code, deployment configs |
| `Bot-Fleet-Inc/bot-fleet-continuum` | Enterprise architecture — ArchiMate, BPMN, governance |
| `Bot-Fleet-Inc/fleet-vault` | Obsidian-compatible knowledge vault |

## Enterprise Architecture Standards

This repo implements standards defined in [bot-fleet-continuum](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum):

- **Architecture viewpoints**: 10 ArchiMate viewpoints in `bot-fleet-continuum/Architecture/`
- **Standards library**: Maturity tiers (Mandated/Recommended/Emerging) in `bot-fleet-continuum/Standards/`
- **Processes**: BPMN Level-1/Level-2 in `bot-fleet-continuum/Processes/`
- **Skills**: Bot fleet skills in `bot-fleet-continuum/Skills/`
- **Governance**: Decision log and org registry in `bot-fleet-continuum/Governance/`

## Working in This Repo

- **Bot implementations** go in `bots/<bot-name>/` — 8-file workspace standard (see `docs/workspace-standard.md`)
- **Shared code** goes in `shared/`
- **Infrastructure configs** go in `infra/` (Cloud-Init, Workers, networking, Proxmox, GPU)
- **Operational docs** go in `docs/`
- **ArchiMate viewpoints** go in `docs/viewpoints/`
- **Issue templates** for bot-generated issues go in `templates/`

See [CONTRIBUTING.md](CONTRIBUTING.md) for document placement decision tree.

## Bot Runtime

- **Runtime**: OpenClaw — model-agnostic agent runtime
- **LLM routing**: Local LLM (Ollama) -> Gemini Flash (free) -> Claude Sonnet (API) -> Claude Opus (API)
- **systemd unit**: `openclaw-bot@<bot-name>.service`
- **Config**: `.openclaw/openclaw.json` in each bot's private repo
- **Exec tools**: `gh`, `git`, `curl` via safeBins allowlist

## No Build Process Yet

Build, test, and deployment commands will be defined per-bot as they are implemented.
