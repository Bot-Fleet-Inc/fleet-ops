# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Repository Overview

**fleet-ops** is the operational workspace for Bot Fleet Inc (BFI) — an autonomous AI bot fleet organisation. Bots are persistent AI agents that collaborate via GitHub Issues.

## Key Concepts

- **GitHub Issues = coordination bus** — bots communicate by creating, assigning, and closing issues
- **Each bot** has its own directory under `bots/`, with workspace files defining identity, mission, tools, and behaviour
- **Bot Fleet Inc (BFI)** is the bots' GitHub organisation — bots only operate within BFI repos
- **All bots** run on dedicated Proxmox VMs with access to local LLM inference (Nvidia A10)

## BFI Repositories

| Repo | Purpose |
|------|---------|
| `Bot-Fleet-Inc/fleet-ops` (this repo) | Bot implementations, shared code, deployment configs |
| `Bot-Fleet-Inc/bot-fleet-continuum` | Enterprise architecture — ArchiMate, BPMN, governance |
| `Bot-Fleet-Inc/fleet-vault` | Obsidian-compatible knowledge vault |

## Standards

This project follows enterprise architecture standards from [bot-fleet-continuum](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum). Key standards:

- ArchiMate viewpoint documentation structure
- BPMN process definitions
- TypeScript/Python coding standards
- Cloudflare deployment patterns (for webhook ingress)

## Working in This Repo

- **Bot implementations** go in `bots/<bot-name>/`
- **Shared code** goes in `shared/`
- **Infrastructure configs** go in `infra/`
- **Issue templates** for bot-generated issues go in `templates/`
- **Operational docs** go in `docs/`

## No Build Process Yet

Build, test, and deployment commands will be defined per-bot as they are implemented.
