#!/usr/bin/env bash
# fleet-update.sh — Update all bot VMs in the fleet
#
# SSHs to each bot VM, pulls the latest code, and restarts the bot service.
# Intended to be run from a management host (e.g., Jorbot's Mac Mini or
# the tunnel VM).
#
# Usage:
#   ./fleet-update.sh [--dry-run] [--bot <bot-name>]
#
# Options:
#   --dry-run   Print commands without executing
#   --bot NAME  Update only a specific bot (by short name, e.g. "change-mgmt")
#
# chmod +x shared/config/scripts/fleet-update.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Bot fleet inventory (from infra/proxmox/vm-specifications.md)
# ---------------------------------------------------------------------------

declare -A BOT_IPS=(
    ["dispatch"]="172.16.10.21"
    ["archi"]="172.16.10.22"
    ["audit"]="172.16.10.23"
    ["coding"]="172.16.10.24"
    ["project-mgmt"]="172.16.10.25"
    ["devops-proxmox"]="172.16.10.30"
    ["devops-cloudflare"]="172.16.10.31"
    ["unifi"]="172.16.10.32"
    ["crm"]="172.16.10.33"
)

declare -A BOT_HOSTNAMES=(
    ["dispatch"]="prod-botfleet-dispatch-01"
    ["archi"]="prod-botfleet-archi-01"
    ["audit"]="prod-botfleet-audit-01"
    ["coding"]="prod-botfleet-coding-01"
    ["project-mgmt"]="prod-botfleet-projectmgmt-01"
    ["devops-proxmox"]="prod-botfleet-devproxmox-01"
    ["devops-cloudflare"]="prod-botfleet-devcloudflare-01"
    ["unifi"]="prod-botfleet-devunifi-01"
    ["crm"]="prod-botfleet-crm-01"
)

SSH_USER="${SSH_USER:-bot}"
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o BatchMode=yes"
REPO_DIR="/opt/bot-fleet"
BOT_SERVICE_NAME="bot-agent"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

LOGFILE="/var/log/fleet-update.log"
DRY_RUN=false
TARGET_BOT=""

log() {
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "${timestamp} [fleet-update] $*" | tee -a "${LOGFILE}" 2>/dev/null || echo "${timestamp} [fleet-update] $*"
}

usage() {
    echo "Usage: $0 [--dry-run] [--bot <bot-name>]"
    echo ""
    echo "Available bots:"
    for bot in $(echo "${!BOT_IPS[@]}" | tr ' ' '\n' | sort); do
        echo "  ${bot} (${BOT_IPS[$bot]})"
    done
    exit 1
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --bot)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: --bot requires a bot name argument" >&2
                usage
            fi
            TARGET_BOT="$2"
            if [[ -z "${BOT_IPS[$TARGET_BOT]+x}" ]]; then
                echo "ERROR: Unknown bot '${TARGET_BOT}'" >&2
                usage
            fi
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "ERROR: Unknown argument '$1'" >&2
            usage
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Update function
# ---------------------------------------------------------------------------

update_bot() {
    local bot_name="$1"
    local bot_ip="${BOT_IPS[$bot_name]}"
    local bot_host="${BOT_HOSTNAMES[$bot_name]}"

    log "--- Updating ${bot_name} (${bot_host} @ ${bot_ip}) ---"

    # Build the remote command sequence
    local remote_cmd="cd ${REPO_DIR} && \
git fetch origin main && \
git reset --hard origin/main && \
sudo systemctl restart ${BOT_SERVICE_NAME} && \
echo 'UPDATE_SUCCESS'"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log "[DRY RUN] ssh ${SSH_OPTS} ${SSH_USER}@${bot_ip} '${remote_cmd}'"
        return 0
    fi

    # Execute update via SSH
    local output
    if output=$(ssh ${SSH_OPTS} "${SSH_USER}@${bot_ip}" "${remote_cmd}" 2>&1); then
        if echo "${output}" | grep -q "UPDATE_SUCCESS"; then
            log "SUCCESS: ${bot_name} updated and service restarted"
            return 0
        else
            log "WARNING: ${bot_name} SSH succeeded but update marker not found"
            log "Output: ${output}"
            return 1
        fi
    else
        log "ERROR: Failed to update ${bot_name} at ${bot_ip}"
        log "Output: ${output}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

log "========================================="
log "Fleet update started"
if [[ "${DRY_RUN}" == "true" ]]; then
    log "MODE: DRY RUN (no changes will be made)"
fi
log "========================================="

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_BOTS=()

# Determine which bots to update
if [[ -n "${TARGET_BOT}" ]]; then
    BOTS_TO_UPDATE=("${TARGET_BOT}")
else
    # Sort for consistent ordering
    mapfile -t BOTS_TO_UPDATE < <(echo "${!BOT_IPS[@]}" | tr ' ' '\n' | sort)
fi

for bot in "${BOTS_TO_UPDATE[@]}"; do
    if update_bot "${bot}"; then
        ((SUCCESS_COUNT++))
    else
        ((FAIL_COUNT++))
        FAILED_BOTS+=("${bot}")
    fi
    echo ""
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

log "========================================="
log "Fleet update complete"
log "  Successful: ${SUCCESS_COUNT}"
log "  Failed:     ${FAIL_COUNT}"

if [[ ${FAIL_COUNT} -gt 0 ]]; then
    log "  Failed bots: ${FAILED_BOTS[*]}"
    log "========================================="
    exit 1
fi

log "========================================="
exit 0
