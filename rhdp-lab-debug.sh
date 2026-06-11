#!/bin/bash
# RHDP Lab Debugger
# Troubleshooting toolkit for RHDP lab deployments on OCP.
# Works with any RHDP lab — KubeVirt VMs, showroom, or plain OCP workloads.
#
# Prerequisites:
#   - oc CLI installed
#   - OCP API token
#   - sshpass (only for ssh_* functions with VM labs)
#
# Usage:
#   source rhdp-lab-debug.sh <namespace> [ocp_api_url] [token]
#
# Environment variables (set in .env or export before sourcing):
#   OCP_API        - OCP API URL (required)
#   OCP_TOKEN      - Bearer token for authentication
#   RHDP_SSH_USER  - SSH user for VM access (default: rhel)
#   RHDP_SSH_PASS  - SSH password for VM access (required)
#   RHDP_SSH_PORT  - Local port for SSH tunnel (default: 2222)
#
# Copy .env.example to .env and fill in your values.
#
# Examples:
#   # Using full namespace:
#   source rhdp-lab-debug.sh sandbox-gc6m9-zt-ansiblebu
#
#   # With explicit API and token:
#   OCP_TOKEN=sha256~xxx source rhdp-lab-debug.sh my-namespace https://api.mycluster.com:6443
#
#   # Custom SSH credentials:
#   RHDP_SSH_USER=admin RHDP_SSH_PASS=secret source rhdp-lab-debug.sh my-namespace

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

RHDP_NAMESPACE="${1:?Usage: source $0 <namespace> [ocp_api_url] [token]}"
OCP_API="${2:-${OCP_API:?Set OCP_API or pass as 2nd arg. See .env.example}}"
OCP_TOKEN="${3:-${OCP_TOKEN:-}}"
RHDP_SSH_USER="${RHDP_SSH_USER:-rhel}"
RHDP_SSH_PASS="${RHDP_SSH_PASS:-}"
RHDP_SSH_PORT="${RHDP_SSH_PORT:-2222}"

export RHDP_NAMESPACE OCP_API OCP_TOKEN RHDP_SSH_USER RHDP_SSH_PASS RHDP_SSH_PORT

# ============================================================
# Core OCP functions — work on any namespace
# ============================================================

login() {
    if [ -z "$OCP_TOKEN" ]; then
        echo "No token. Set OCP_TOKEN or pass as 3rd arg to source."
        return 1
    fi
    oc login "$OCP_API" --token="$OCP_TOKEN" --insecure-skip-tls-verify 2>&1 | grep -v "^WARNING"
    oc project "$RHDP_NAMESPACE" 2>&1
}

pods() {
    echo "=== Pods in $RHDP_NAMESPACE ==="
    oc get pods -n "$RHDP_NAMESPACE" -o wide 2>&1
}

events() {
    local count="${1:-20}"
    echo "=== Last $count events in $RHDP_NAMESPACE ==="
    oc get events -n "$RHDP_NAMESPACE" --sort-by='.lastTimestamp' 2>&1 | tail -"$count"
}

routes() {
    echo "=== Routes ==="
    oc get routes -n "$RHDP_NAMESPACE" -o custom-columns=NAME:.metadata.name,HOST:.spec.host 2>&1
}

services() {
    echo "=== Services ==="
    oc get services -n "$RHDP_NAMESPACE" -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,PORTS:.spec.ports[*].port 2>&1
}

# Get detailed status of a pod's init containers
pod_init_status() {
    local pod="${1:?Usage: pod_init_status <pod-name>}"
    echo "=== Init Containers: $pod ==="
    oc get pod "$pod" -n "$RHDP_NAMESPACE" -o json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data['status'].get('initContainerStatuses', []):
    state_key = list(c['state'].keys())[0]
    state_detail = c['state'][state_key]
    reason = state_detail.get('reason', state_key)
    exit_code = state_detail.get('exitCode', '')
    exit_str = f' exit={exit_code}' if exit_code != '' else ''
    print(f\"  {c['name']:20s} ready={str(c['ready']):5s} restarts={c['restartCount']}  {reason}{exit_str}\")
"
}

# Get logs from any container (init or regular) in a pod
pod_logs() {
    local pod="${1:?Usage: pod_logs <pod-name> [container-name] [tail-lines]}"
    local container="${2:-}"
    local tail="${3:-}"
    local args=()
    [ -n "$container" ] && args+=(-c "$container")
    [ -n "$tail" ] && args+=(--tail="$tail")
    echo "=== Logs: $pod ${container:+/ $container} ==="
    oc logs "$pod" -n "$RHDP_NAMESPACE" "${args[@]}" 2>&1
}

# Get pod conditions
pod_conditions() {
    local pod="${1:?Usage: pod_conditions <pod-name>}"
    echo "=== Conditions: $pod ==="
    oc get pod "$pod" -n "$RHDP_NAMESPACE" -o jsonpath='{range .status.conditions[*]}{.type}={.status}  reason={.reason}  {.message}{"\n"}{end}' 2>&1
}

# ============================================================
# Showroom functions — for RHDP labs using showroom
# ============================================================

# Find the showroom pod name
_showroom_pod() {
    oc get pods -n "$RHDP_NAMESPACE" -l app=showroom -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

showroom_status() {
    local pod
    pod=$(_showroom_pod)
    if [ -z "$pod" ]; then
        echo "No showroom pod found (label app=showroom)"
        return 1
    fi
    pod_init_status "$pod"
    echo ""
    pod_conditions "$pod"
}

showroom_init_logs() {
    local container="${1:-setup}"
    local pod
    pod=$(_showroom_pod)
    if [ -z "$pod" ]; then
        echo "No showroom pod found"
        return 1
    fi
    pod_logs "$pod" "$container"
}

# ============================================================
# SSH functions — for RHDP labs with KubeVirt VMs
# ============================================================

# Open an SSH tunnel to a VM via oc port-forward
ssh_bridge() {
    if [ -z "$RHDP_SSH_PASS" ]; then echo "Set RHDP_SSH_PASS. See .env.example"; return 1; fi
    local host="${1:-control}"
    local local_port="${2:-$RHDP_SSH_PORT}"
    echo "Opening SSH bridge to $host on localhost:$local_port"
    echo "Connect with:"
    echo "  sshpass -p '$RHDP_SSH_PASS' ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -p $local_port $RHDP_SSH_USER@127.0.0.1"
    echo ""
    echo "Press Ctrl+C to stop"
    oc port-forward "svc/$host" "$local_port:22" -n "$RHDP_NAMESPACE"
}

# Run a command on a VM via port-forward (one-shot)
ssh_cmd() {
    if [ -z "$RHDP_SSH_PASS" ]; then echo "Set RHDP_SSH_PASS. See .env.example"; return 1; fi
    local host="${1:?Usage: ssh_cmd <host> <command>}"
    local cmd="${2:?Usage: ssh_cmd <host> <command>}"
    local local_port="$RHDP_SSH_PORT"

    oc port-forward "svc/$host" "$local_port:22" -n "$RHDP_NAMESPACE" > /dev/null 2>&1 &
    local pf_pid=$!
    sleep 2

    sshpass -p "$RHDP_SSH_PASS" ssh \
        -o StrictHostKeyChecking=no \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        -p "$local_port" "${RHDP_SSH_USER}@127.0.0.1" \
        "$cmd" 2>&1

    local rc=$?
    kill "$pf_pid" 2>/dev/null
    wait "$pf_pid" 2>/dev/null
    return $rc
}

# Run a command as root on a VM
ssh_root_cmd() {
    local host="${1:?Usage: ssh_root_cmd <host> <command>}"
    local cmd="${2:?Usage: ssh_root_cmd <host> <command>}"
    ssh_cmd "$host" "sudo bash -c '$cmd'"
}

# ============================================================
# Help
# ============================================================

usage() {
    cat <<HELP
RHDP Lab Debugger

  Core OCP:
    login                         Log in and switch to namespace
    pods                          List pods
    events [count]                Recent events (default 20)
    routes                        List routes
    services                      List services
    pod_init_status <pod>         Init container status for any pod
    pod_logs <pod> [container]    Logs from any pod/container
    pod_conditions <pod>          Pod conditions

  Showroom:
    showroom_status               Init containers + conditions
    showroom_init_logs [name]     Init container logs (default: setup)

  SSH (KubeVirt VMs):
    ssh_bridge [host] [port]      Open SSH tunnel (default: control:$RHDP_SSH_PORT)
    ssh_cmd <host> <command>      Run command on VM
    ssh_root_cmd <host> <command> Run command as root on VM

  Current config:
    Namespace:  $RHDP_NAMESPACE
    API:        $OCP_API
    SSH user:   $RHDP_SSH_USER
    SSH port:   $RHDP_SSH_PORT

HELP
}

# If sourced, export functions. If executed, show help.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    usage
    echo "Tip: source this script to use functions interactively:"
    echo "  source $0 <namespace>"
fi
