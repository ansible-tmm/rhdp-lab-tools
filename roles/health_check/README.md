# health_check

Verify a deployed RHDP lab environment is fully functional.

This role is read-only — it checks and reports, never modifies target systems.

## Requirements

- `ansible-core` >= 2.15
- `redhat.openshift` collection (OCP queries and auth)
- `ansible.controller` collection (CaC checks, optional)
- Network access to the OCP cluster or direct SSH to lab VMs

## Role Variables

### Connection

| Variable | Description | Default |
|---|---|---|
| `health_check_provider` | Connection method: `ssh`, `portforward`, or empty (auto-detect) | `""` |
| `health_check_bastion_host` | Bastion hostname (SSH provider) | `""` |
| `health_check_bastion_user` | SSH username for bastion | `""` |
| `health_check_bastion_password` | SSH password for bastion | (required for SSH) |
| `health_check_ocp_api` | OCP API URL (port-forward provider) | `""` |
| `health_check_ocp_token` | OCP bearer token | (required for port-forward) |
| `health_check_ocp_username` | OCP username (alternative to token) | `""` |
| `health_check_ocp_password` | OCP password (with username) | (required if using username) |
| `health_check_ocp_namespace` | OCP namespace containing the lab | `""` |
| `health_check_ocp_validate_certs` | Validate OCP TLS certs | `false` |
| `health_check_ssh_port` | Local port for SSH tunnel | `2222` |

### Configuration

| Variable | Description | Default |
|---|---|---|
| `health_check_foundry_config` | Path to `.foundry.yml` | `""` |
| `health_check_manifest` | Path to standalone lab manifest | `""` |

### Check Toggles

| Variable | Description | Default |
|---|---|---|
| `health_check_infra_enabled` | Enable infrastructure checks | `true` |
| `health_check_control_enabled` | Enable control node checks | `true` |
| `health_check_nodes_enabled` | Enable worker node checks | `true` |
| `health_check_cac_enabled` | Enable CaC object checks | `false` |
| `health_check_content_enabled` | Enable content checks | `true` |

### Report

| Variable | Description | Default |
|---|---|---|
| `health_check_report_path` | Path for JSON report (empty = console only) | `""` |

## Tags

- `health_check_infra` — VM and pod checks
- `health_check_control` — Control node health
- `health_check_nodes` — Worker node health
- `health_check_cac` — CaC object validation
- `health_check_content` — Showroom content checks

## Example Playbooks

```yaml
# Full health check via port-forward
- hosts: localhost
  gather_facts: false
  roles:
    - role: health_check
      health_check_ocp_api: "https://api.cluster.example.com:6443"
      health_check_ocp_token: "sha256~xxx"
      health_check_ocp_namespace: "sandbox-abc12-zt-ansiblebu"
      health_check_manifest: "manifests/intro-controller.yml"

# Full health check via direct SSH
- hosts: localhost
  gather_facts: false
  roles:
    - role: health_check
      health_check_provider: ssh
      health_check_bastion_host: "control.lab.example.com"
      health_check_bastion_user: rhel
      health_check_bastion_password: "{{ vault_bastion_password }}"
      health_check_manifest: "manifests/intro-controller.yml"

# Subset: infrastructure + control only
- hosts: localhost
  gather_facts: false
  roles:
    - role: health_check
      health_check_manifest: "manifests/intro-controller.yml"
```

## Idempotency

This role is idempotent. Running it multiple times with the same parameters
produces the same results. It is read-only and makes no changes to target
systems.

## Check Mode

Fully supported. The role works in check mode without failing.

## Rollback

Not applicable — this role makes no changes to roll back.

## License

GPL-3.0-or-later

## Author

Red Hat Ansible TMM
