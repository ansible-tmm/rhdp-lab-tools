# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Bash troubleshooting toolkit for RHDP (Red Hat Demo Platform) lab deployments running on OpenShift. Labs use KubeVirt VMs (control, node1-3) with a Showroom pod serving the lab guide.

## Scripts

- **`rhdp-lab-status.sh`** — One-shot status check. Run directly: `./rhdp-lab-status.sh <namespace>`
- **`rhdp-lab-debug.sh`** — Interactive toolkit. Source it, then call functions: `source rhdp-lab-debug.sh <namespace>` followed by `login`, `pods`, `showroom_status`, `ssh_cmd`, etc.

Both scripts require the `oc` CLI and an OCP bearer token. SSH functions additionally need `sshpass`.

## Architecture

The debug script exposes three function layers when sourced:

1. **Core OCP** — generic `oc` wrappers (`pods`, `events`, `routes`, `pod_logs`, etc.) that work against any namespace
2. **Showroom** — lab-guide-specific functions (`showroom_status`, `showroom_init_logs`) that find the showroom pod by label `app=showroom`
3. **SSH** — KubeVirt VM access via `oc port-forward` + `sshpass` (`ssh_cmd`, `ssh_root_cmd`, `ssh_bridge`)

The status script is standalone (not sourced) and duplicates some logic from the debug script intentionally — it's meant to be a quick copy-paste diagnostic, not a library consumer.

## Configuration

All config is via environment variables — no credentials in the scripts. Users copy `.env.example` to `.env` (gitignored) for local convenience. Required: `OCP_API`, `OCP_TOKEN`, `RHDP_SSH_PASS` (for SSH functions).

## Testing

No automated tests exist. Verify changes by sourcing the debug script against a live RHDP namespace.
