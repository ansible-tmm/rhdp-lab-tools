# RHDP Lab Debug Scripts

Interactive troubleshooting toolkit for RHDP lab deployments running on OpenShift (KubeVirt VMs + Showroom).

## Setup

Copy the example env file and fill in your values:

```bash
cp .env.example .env
```

## Scripts

### `rhdp-lab-status.sh`

One-shot status check for a lab deployment. Prints a quick overview and exits.

**What it checks:**
- Pod status (phase, readiness, restart count)
- Init container issues (finds any non-ready init container and reports reason + exit code)
- OpenShift routes (showroom, control, node URLs)
- Recent namespace events (last 10)

**Usage:**
```bash
./rhdp-lab-status.sh <namespace>
```

### `rhdp-lab-debug.sh`

Interactive debugging toolkit. Source it to get functions you call as needed.

**Core OCP functions (work on any namespace):**
- `login` — Authenticate and switch to namespace
- `pods` — List all pods with status
- `events [count]` — Recent namespace events
- `routes` — List OpenShift routes
- `services` — List services and ports
- `pod_init_status <pod>` — Detailed init container status for any pod
- `pod_logs <pod> [container] [tail]` — Logs from any pod/container
- `pod_conditions <pod>` — Pod scheduling/readiness conditions

**Showroom functions (for labs using showroom):**
- `showroom_status` — Combined init container + conditions view
- `showroom_init_logs [container]` — Logs from showroom init containers (default: `setup`)

**SSH functions (for labs with KubeVirt VMs):**
- `ssh_bridge [host] [port]` — Open persistent SSH tunnel via `oc port-forward`
- `ssh_cmd <host> <command>` — Run a one-shot command on a VM
- `ssh_root_cmd <host> <command>` — Run a command as root on a VM

**Usage:**
```bash
source rhdp-lab-debug.sh <namespace>
login
showroom_status
ssh_cmd control "cat /tmp/setup-scripts/setup-control.log"
```

## Health Check Role

Ansible role that verifies a deployed lab is fully functional. See
[`roles/health_check/README.md`](roles/health_check/README.md) for full
documentation.

Quick start:

```bash
ansible-playbook health-check.yml \
  -e health_check_ocp_api=https://api.cluster.example.com:6443 \
  -e health_check_ocp_token=sha256~xxx \
  -e health_check_ocp_namespace=sandbox-abc12-zt-ansiblebu \
  -e health_check_manifest=manifests/intro-controller.yml
```

## Configuration

All configuration via environment variables — set them in `.env` or export before running.

| Variable | Description | Required |
|---|---|---|
| `OCP_API` | OCP API URL | Yes |
| `OCP_TOKEN` | OCP bearer token | Yes |
| `RHDP_SSH_USER` | SSH username for VMs | No (default: `rhel`) |
| `RHDP_SSH_PASS` | SSH password for VMs | Yes (for SSH functions) |
| `RHDP_SSH_PORT` | Local port for SSH tunnel | No (default: `2222`) |

## Prerequisites

- `oc` CLI installed and accessible
- `sshpass` (only for SSH functions)
- `python3` (for JSON parsing in status output)
