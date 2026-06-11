#!/bin/bash
# RHDP Lab Quick Status
# One-shot overview of a lab deployment — pods, init containers, routes, events.
#
# Usage:
#   ./rhdp-lab-status.sh <namespace> [ocp_api_url] [token]
#
# Environment variables (set in .env or export before sourcing):
#   OCP_API   - OCP API URL (required)
#   OCP_TOKEN - Bearer token
#
# Copy .env.example to .env and fill in your values.
#
# Examples:
#   OCP_TOKEN=sha256~xxx ./rhdp-lab-status.sh sandbox-gc6m9-zt-ansiblebu
#   ./rhdp-lab-status.sh my-namespace https://api.mycluster.com:6443 sha256~xxx

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

NAMESPACE="${1:?Usage: $0 <namespace> [ocp_api_url] [token]}"
OCP_API="${2:-${OCP_API:?Set OCP_API or pass as 2nd arg. See .env.example}}"
OCP_TOKEN="${3:-${OCP_TOKEN:-}}"

if [ -z "$OCP_TOKEN" ]; then
    echo "No token. Set OCP_TOKEN or pass as 3rd arg."
    exit 1
fi

oc login "$OCP_API" --token="$OCP_TOKEN" --insecure-skip-tls-verify > /dev/null 2>&1
oc project "$NAMESPACE" > /dev/null 2>&1

echo "=== Lab: $NAMESPACE ==="
echo ""

echo "--- Pods ---"
oc get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?\(@.type==\"Ready\"\)].status,RESTARTS:.status.containerStatuses[0].restartCount 2>&1
echo ""

# Check for pods with init containers that aren't ready
echo "--- Init Container Issues ---"
oc get pods -n "$NAMESPACE" -o json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
found = False
for pod in data.get('items', []):
    name = pod['metadata']['name']
    for c in pod['status'].get('initContainerStatuses', []):
        if not c.get('ready', False):
            state_key = list(c['state'].keys())[0]
            state_detail = c['state'][state_key]
            reason = state_detail.get('reason', state_key)
            exit_code = state_detail.get('exitCode', '')
            exit_str = f' exit={exit_code}' if exit_code != '' else ''
            print(f'  {name} / {c[\"name\"]}: {reason}{exit_str} restarts={c[\"restartCount\"]}')
            found = True
if not found:
    print('  All init containers OK')
"
echo ""

echo "--- Routes ---"
oc get routes -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,HOST:.spec.host --no-headers 2>&1
echo ""

echo "--- Recent Events (last 10) ---"
oc get events -n "$NAMESPACE" --sort-by='.lastTimestamp' --no-headers 2>&1 | tail -10
