#!/usr/bin/env bash
# init-bot-workspace.sh — Initialize a bot workspace from templates
#
# Renders the workspace template (shared/config/workspace-template/) for a
# specific bot, replacing template variables with provided values, and copies
# the result into bots/<bot-name>/.
#
# Usage:
#   ./init-bot-workspace.sh \
#     --bot-name "Dispatch Bot" \
#     --bot-dir "dispatch-bot" \
#     --github-user "dispatch-bot" \
#     --role "Dispatch" \
#     --vmid "411" \
#     --ip "172.16.10.21" \
#     --hostname "prod-botfleet-dispatch-01" \
#     --vlan "1010" \
#     --tier "Standard" \
#     --email "dispatch@bot-fleet.org" \
#     --emoji ":scales:" \
#     --mission "Detects events, triages issues, and dispatches work to other bots." \
#     --principles "" \
#     --boundaries ""
#
# chmod +x shared/config/scripts/init-bot-workspace.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_DIR="${BOT_FLEET_REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TEMPLATE_DIR="${REPO_DIR}/shared/config/workspace-template"
BOTS_DIR="${REPO_DIR}/bots"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() {
    echo "[init-bot-workspace] $*"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Usage: init-bot-workspace.sh [OPTIONS]

Required options:
  --bot-name NAME         Display name (e.g. "Dispatch Bot")
  --bot-dir DIR           Directory name under bots/ (e.g. "dispatch-bot")
  --github-user USER      GitHub username (e.g. "dispatch-bot")
  --role ROLE             Bot role description (e.g. "Dispatch")

Optional options:
  --vmid ID               Proxmox VM ID (e.g. "411")
  --ip ADDRESS            IP address (e.g. "172.16.10.21")
  --hostname HOST         VM hostname (e.g. "prod-botfleet-dispatch-01")
  --vlan ID               VLAN ID (e.g. "1010")
  --tier TIER             Security tier (e.g. "Standard", "Infra-Access")
  --email EMAIL           Bot email address (e.g. "dispatch@bot-fleet.org")
  --emoji EMOJI           Bot emoji (e.g. ":rotating_light:")
  --mission TEXT          Mission statement for SOUL.md
  --principles TEXT       Additional principles for SOUL.md
  --boundaries TEXT       Additional boundaries for SOUL.md
  --force                 Overwrite existing bot directory

USAGE
    exit 1
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

BOT_NAME=""
BOT_DIR=""
GITHUB_USER=""
BOT_ROLE=""
VMID=""
IP=""
HOSTNAME=""
VLAN="1010"
TIER="Standard"
BOT_EMAIL=""
EMOJI=""
BOT_MISSION=""
BOT_PRINCIPLES=""
BOT_BOUNDARIES=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bot-name)     BOT_NAME="$2"; shift 2 ;;
        --bot-dir)      BOT_DIR="$2"; shift 2 ;;
        --github-user)  GITHUB_USER="$2"; shift 2 ;;
        --role)         BOT_ROLE="$2"; shift 2 ;;
        --vmid)         VMID="$2"; shift 2 ;;
        --ip)           IP="$2"; shift 2 ;;
        --hostname)     HOSTNAME="$2"; shift 2 ;;
        --vlan)         VLAN="$2"; shift 2 ;;
        --tier)         TIER="$2"; shift 2 ;;
        --email)        BOT_EMAIL="$2"; shift 2 ;;
        --emoji)        EMOJI="$2"; shift 2 ;;
        --mission)      BOT_MISSION="$2"; shift 2 ;;
        --principles)   BOT_PRINCIPLES="$2"; shift 2 ;;
        --boundaries)   BOT_BOUNDARIES="$2"; shift 2 ;;
        --force)        FORCE=true; shift ;;
        -h|--help)      usage ;;
        *)              die "Unknown argument: $1" ;;
    esac
done

# ---------------------------------------------------------------------------
# Validate required parameters
# ---------------------------------------------------------------------------

[[ -z "${BOT_NAME}" ]]    && die "--bot-name is required"
[[ -z "${BOT_DIR}" ]]     && die "--bot-dir is required"
[[ -z "${GITHUB_USER}" ]] && die "--github-user is required"
[[ -z "${BOT_ROLE}" ]]    && die "--role is required"

# Validate template directory exists
[[ ! -d "${TEMPLATE_DIR}" ]] && die "Template directory not found: ${TEMPLATE_DIR}"

# Check target directory
TARGET_DIR="${BOTS_DIR}/${BOT_DIR}"
if [[ -d "${TARGET_DIR}" && "${FORCE}" != "true" ]]; then
    # Check if it has more than just .gitkeep
    FILE_COUNT=$(find "${TARGET_DIR}" -not -name ".gitkeep" -not -path "${TARGET_DIR}" | wc -l | tr -d ' ')
    if [[ "${FILE_COUNT}" -gt 0 ]]; then
        die "Bot directory ${TARGET_DIR} already exists and has content. Use --force to overwrite."
    fi
fi

# ---------------------------------------------------------------------------
# Render templates
# ---------------------------------------------------------------------------

log "Initializing workspace for ${BOT_NAME} (${BOT_DIR})"
log "  Template: ${TEMPLATE_DIR}"
log "  Target:   ${TARGET_DIR}"

# Create target directory structure
mkdir -p "${TARGET_DIR}/.claude"
mkdir -p "${TARGET_DIR}/memory"

# Process each template file
render_template() {
    local src="$1"
    local dst="$2"

    log "  Rendering: $(basename "${src}") -> $(basename "${dst}")"

    sed \
        -e "s|{{BOT_NAME}}|${BOT_NAME}|g" \
        -e "s|{{BOT_DIR}}|${BOT_DIR}|g" \
        -e "s|{{GITHUB_USER}}|${GITHUB_USER}|g" \
        -e "s|{{BOT_ROLE}}|${BOT_ROLE}|g" \
        -e "s|{{VMID}}|${VMID}|g" \
        -e "s|{{IP}}|${IP}|g" \
        -e "s|{{HOSTNAME}}|${HOSTNAME}|g" \
        -e "s|{{VLAN}}|${VLAN}|g" \
        -e "s|{{TIER}}|${TIER}|g" \
        -e "s|{{BOT_EMAIL}}|${BOT_EMAIL}|g" \
        -e "s|{{EMOJI}}|${EMOJI}|g" \
        -e "s|{{BOT_MISSION}}|${BOT_MISSION}|g" \
        -e "s|{{BOT_PRINCIPLES}}|${BOT_PRINCIPLES}|g" \
        -e "s|{{BOT_BOUNDARIES}}|${BOT_BOUNDARIES}|g" \
        "${src}" > "${dst}"
}

# Process all files in the template directory
while IFS= read -r -d '' file; do
    # Skip .gitkeep files
    if [[ "$(basename "${file}")" == ".gitkeep" ]]; then
        continue
    fi

    # Compute relative path from template dir
    rel_path="${file#"${TEMPLATE_DIR}"/}"

    # Strip .template extension if present
    if [[ "${rel_path}" == *.template ]]; then
        rel_path="${rel_path%.template}"
    fi

    dst_path="${TARGET_DIR}/${rel_path}"

    # Create parent directory if needed
    mkdir -p "$(dirname "${dst_path}")"

    # Copy and render variables
    render_template "${file}" "${dst_path}"
done < <(find "${TEMPLATE_DIR}" -type f -print0)

# ---------------------------------------------------------------------------
# Generate IDENTITY.md
# ---------------------------------------------------------------------------

log "  Generating: IDENTITY.md"

cat > "${TARGET_DIR}/IDENTITY.md" <<EOF
# ${EMOJI} ${BOT_NAME} — Identity

| Key         | Value                          |
|-------------|--------------------------------|
| bot_name    | ${BOT_NAME}                    |
| role        | ${BOT_ROLE}                    |
| github_user | ${GITHUB_USER}                 |
| email       | ${BOT_EMAIL}                   |
| vmid        | ${VMID}                        |
| ip          | ${IP}                          |
| hostname    | ${HOSTNAME}                    |
| vlan        | ${VLAN}                        |
| tier        | ${TIER}                        |
| emoji       | ${EMOJI}                       |
EOF

# ---------------------------------------------------------------------------
# Generate initial MEMORY.md
# ---------------------------------------------------------------------------

log "  Generating: memory/MEMORY.md"

cat > "${TARGET_DIR}/memory/MEMORY.md" <<EOF
# ${EMOJI} ${BOT_NAME} — Memory

## Session Log

*No sessions recorded yet.*

## Patterns Learned

*No patterns recorded yet.*

## Known Issues

*No known issues recorded yet.*
EOF

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

log ""
log "Workspace initialized successfully!"
log ""
log "Files created:"
find "${TARGET_DIR}" -type f | sort | while read -r f; do
    log "  ${f#"${REPO_DIR}"/}"
done
log ""
log "Next steps:"
log "  1. Review and customize ${BOT_DIR}/SOUL.md"
log "  2. Add bot-specific code to bots/${BOT_DIR}/"
log "  3. Create the bot's GitHub account: ${GITHUB_USER}"
log "  4. Deploy to VM ${VMID} (${HOSTNAME} @ ${IP})"
