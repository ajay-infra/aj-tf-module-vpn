# skills.md — aj-tf-module-vpn

## Purpose
Provisions AWS Client VPN with mutual TLS or AD authentication, split-tunnel routing, and per-environment access controls.

## Type
`tf-module`

## Stable ref
```
source = "github.com/ajay-infra/aj-tf-module-vpn?ref=v1.0.0"
```

## Key inputs
| Variable | Description |
|---|---|
| `environment` | dev \| staging \| uat \| prod |
| `name_prefix` | Resource name prefix |
| `vpc_id` | VPC to associate the VPN endpoint with |
| `target_subnet_ids` | Subnets for VPN association |
| `client_cidr` | IP range assigned to VPN clients |
| `target_vpc_cidr` | VPC CIDR to route through VPN |
| `additional_routes` | Extra CIDRs to route (e.g. peered VPCs) |

## AWS tags applied
`Project`, `ManagedBy`, `Repository`, `Environment`, `Team`, `CostCenter` (set in
`locals.full_tags`), plus whatever's in `var.tags`. No `Env`, `Model`, or `Customer`
tag exists in this module.

## Depends on
`aj-tf-module-directory` — for AD-based VPN auth (optional)

## Branching convention
- `main` — active development
- semver tags (`v1.0.0`, ...) — stable pinned releases, per `README.md` usage examples

## CI checks
fmt, validate, plan (dry-run), tfsec/checkov

## Agentic capabilities
- Validate client_cidr doesn't overlap with target_vpc_cidr
- Check split-tunnel is enabled (cost — avoid routing all traffic through VPN)
- Detect if VPN is associated with public subnets
- Generate PR to add route when new VPC is peered
