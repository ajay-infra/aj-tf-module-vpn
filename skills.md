# skills.md — aj-tf-module-vpn

## Purpose
Provisions AWS Client VPN with mutual TLS or AD authentication, split-tunnel routing, and per-environment access controls.

## Type
`tf-module`

## Stable ref
```
source = "github.com/ajaylakma/aj-tf-module-vpn?ref=vpn-01"
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
`Env`, `Team`, `ManagedBy`, `CostCenter`, `Model`, `Customer`

## Depends on
`aj-tf-module-directory` — for AD-based VPN auth (optional)

## Branching convention
- `main` — active development
- `vpn-01` — stable pinned release

## CI checks
fmt, validate, plan (dry-run), tfsec/checkov

## Agentic capabilities
- Validate client_cidr doesn't overlap with target_vpc_cidr
- Check split-tunnel is enabled (cost — avoid routing all traffic through VPN)
- Detect if VPN is associated with public subnets
- Generate PR to add route when new VPC is peered
