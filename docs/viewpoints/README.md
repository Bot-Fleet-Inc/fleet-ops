# ArchiMate Viewpoints (fleet-ops)

Operational architecture viewpoints for Bot Fleet Inc. These document the implemented architecture — how BFI actually works.

For the full viewpoint framework, see [bot-fleet-continuum/Architecture/](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/tree/main/Architecture).

## Current Viewpoints

| Viewpoint | Document | Description |
|-----------|----------|-------------|
| Technology | [technology-infrastructure.md](technology-infrastructure.md) | VM topology, software stack, ArchiMate element catalogue |
| Technology | [credential-management.md](credential-management.md) | Credential architecture — 1Password, PATs, tokens, rotation |
| Implementation | [ssh-access-operations.md](ssh-access-operations.md) | SSH access paths, user accounts, key management, emergency procedures |

## Naming Convention

**Format:** `topic-name_viewpoint-name.md`

The underscore separates content from viewpoint classification. See [bot-fleet-continuum CONTRIBUTING.md](https://github.com/Bot-Fleet-Inc/bot-fleet-continuum/blob/main/CONTRIBUTING.md) for full naming standards.

## Needed Viewpoints

Based on EA compliance audit (2026-03-03), the following viewpoints should be added:

| Viewpoint | Suggested Document | Priority |
|-----------|-------------------|----------|
| Motivation | `bfi-strategic-goals_motivation.md` | High |
| Layered | `bot-fleet-system_layered.md` | High |
| Application-Cooperation | `fleet-services-integration_application-cooperation.md` | High |
| Application-Usage | `human-bot-interaction_application-usage.md` | Medium |
| Information-Structure | `fleet-data-architecture_information-structure.md` | Medium |
| Physical | `bot-fleet-infrastructure_physical.md` | Medium |
| Migration | `bot-onboarding-migration_migration.md` | Low |
