locals {
  name_prefix = var.name_prefix != "" ? var.name_prefix : var.environment

  # Cross-product of additional routes × target subnets for route resources
  route_pairs = {
    for pair in setproduct(keys(var.additional_routes), var.target_subnet_ids) :
    "${pair[0]}--${pair[1]}" => {
      name      = pair[0]
      cidr      = var.additional_routes[pair[0]]
      subnet_id = pair[1]
    }
  }

  # SAML and AD are alternatives — Client VPN accepts one user-auth method
  # beside mutual TLS, and the estate's is SAML (groups in the assertion).
  saml_enabled = var.saml_provider_arn != ""

  # Group → tier → the routes that tier may reach → one authorization rule per
  # (group, route). "management" is the endpoint's own VPC.
  route_cidrs = merge({ management = var.target_vpc_cidr }, var.additional_routes)
  group_tier = {
    for g in var.groups : g => (
      startswith(g, "estate-") ? "estate" : endswith(g, "-read") ? "team-read" : "team-write"
    )
  }
  group_rule_pairs = {
    for pair in flatten([
      for g, tier in local.group_tier : [
        for route in lookup(var.group_rules, tier, []) : { group = g, route = route }
      ]
    ]) : "${pair.group}--${pair.route}" => pair
  }
  per_group_rules = length(var.groups) > 0

  full_tags = merge({
    Project     = "aj-infra-platform"
    ManagedBy   = "Terraform"
    Repository  = "aj-tf-module-vpn"
    Environment = var.environment
    Team        = var.team
    CostCenter  = var.cost_center
  }, var.tags)
}
