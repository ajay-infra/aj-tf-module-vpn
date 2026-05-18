# CLAUDE.md — aj-tf-module-vpn

> Local context file for Claude Code. Not pushed to GitHub.

## What This Module Does

AWS Client VPN — engineer access to private resources without public exposure.
Provisioned after aj-tf-module-directory (needs directory_id + dns_ip_addresses).

## Module Structure

```
certs.tf     → tls_private_key, tls_self_signed_cert, aws_acm_certificate
               (server cert + client CA cert)
main.tf      → aws_cloudwatch_log_group, aws_security_group,
               aws_ec2_client_vpn_endpoint, aws_ec2_client_vpn_network_association,
               aws_ec2_client_vpn_route, aws_ec2_client_vpn_authorization_rule
locals.tf    → name_prefix, route_pairs cross-product, full_tags
outputs.tf   → vpn_endpoint_id, vpn_dns_name, client_config_template,
               client_ca_cert/key_pem (sensitive), log_group_name
providers.tf → aws + tls providers, skip_* flags
```

## Key Design Decisions

- **tls provider for certs** — self-signed, no external CA needed; private keys in state
  (sensitive). Fine for this scale; replace with AWS Private CA for regulated envs.
- **split_tunnel = true** — only RFC1918 goes through VPN; internet stays local.
  Engineers keep normal internet, cost is lower (no data transfer through VPN).
- **directory_id is optional** — when set, adds AD auth on top of cert auth (both required).
  When empty, cert-only. Start with cert-only, add AD after directory is validated.
- **route_pairs cross-product** — each additional_routes CIDR × each target_subnet_id
  creates one aws_ec2_client_vpn_route resource (AWS requires one per subnet per CIDR).
- **authorize_all_groups = true** — all authenticated users get all routes initially;
  narrow to AD group IDs (access_group_id) once groups are established.
- **session_timeout_hours = 8** — engineers re-authenticate each workday; prevents
  indefinite sessions from forgotten VPN connections.

## Client CA Private Key in State

The client CA private key is in TF state (sensitive). Access control:
- S3 state bucket: SSE-KMS + bucket policy restricted to infra-lead role
- Never check state into git
- After signing engineer certs, delete the local ca.key copy

## Known TODOs

- [ ] Fill in directory_id + dns_servers in envs/*.tfvars after directory is applied
- [ ] Fill in vpc_id + subnet_ids after management VPC is provisioned
- [ ] Narrow authorization rules from authorize_all_groups to AD group IDs
- [ ] Consider AWS Private CA for regulated environments (eliminates key from state)
- [ ] Document CVPN client choice: AWS VPN Client (recommended) vs Tunnelblick
