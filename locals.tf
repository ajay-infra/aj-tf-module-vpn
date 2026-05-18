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

  full_tags = merge({
    Project     = "aj-infra-platform"
    ManagedBy   = "Terraform"
    Repository  = "aj-tf-module-vpn"
    Environment = var.environment
    Team        = var.team
    CostCenter  = var.cost_center
  }, var.tags)
}
