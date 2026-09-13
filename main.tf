# ── CloudWatch Logs ───────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "vpn" {
  name              = "/aws/vpn/${local.name_prefix}-connection-logs"
  retention_in_days = var.log_retention_days

  tags = local.full_tags
}

# ── Security Group ────────────────────────────────────────────────────────────
# Applied to the VPN endpoint's virtual network interface.
# Egress: allow all — VPN clients need to reach AD, EKS API, Aurora, Valkey.
# Ingress: managed by the VPN service itself (UDP 443 for client connections).

resource "aws_security_group" "vpn" {
  name        = "${local.name_prefix}-vpn-endpoint"
  description = "Client VPN endpoint — egress to management VPC and peered workload VPCs"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow VPN clients to reach all internal resources"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.full_tags, { Name = "${local.name_prefix}-vpn-endpoint" })
}

# ── Client VPN Endpoint ───────────────────────────────────────────────────────

resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "${local.name_prefix} Client VPN — engineer access to private resources"
  client_cidr_block      = var.client_cidr
  server_certificate_arn = aws_acm_certificate.server.arn
  vpc_id                 = var.vpc_id
  security_group_ids     = [aws_security_group.vpn.id]
  split_tunnel           = var.split_tunnel
  transport_protocol     = "udp"
  vpn_port               = 443
  session_timeout_hours  = 8

  dns_servers = length(var.dns_servers) > 0 ? var.dns_servers : null

  # Certificate auth — every client needs a cert signed by the client CA
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_ca.arn
  }

  # AD auth — layered on top of cert auth when directory_id is provided and
  # SAML is not. Kept for the pre-SAML path; identity-and-access-v1.md §2
  # demotes the directory and this is its last consumer.
  dynamic "authentication_options" {
    for_each = var.directory_id != "" && !local.saml_enabled ? [1] : []
    content {
      type                = "directory-service-authentication"
      active_directory_id = var.directory_id
    }
  }

  # SAML — the engineer signs in through IAM Identity Center; the assertion's
  # memberOf carries the estate's group names, which the authorization rules
  # below key on. The AWS-provided client is required (it opens the browser).
  dynamic "authentication_options" {
    for_each = local.saml_enabled ? [1] : []
    content {
      type                           = "federated-authentication"
      saml_provider_arn              = var.saml_provider_arn
      self_service_saml_provider_arn = var.self_service_saml_provider_arn != "" ? var.self_service_saml_provider_arn : null
    }
  }

  lifecycle {
    precondition {
      condition     = !(var.directory_id != "" && local.saml_enabled)
      error_message = "directory_id and saml_provider_arn are both set. Client VPN takes one user-auth method beside mutual TLS; the estate's is SAML — drop directory_id."
    }
    precondition {
      condition     = !(local.saml_enabled && length(var.groups) == 0)
      error_message = "SAML is enabled but groups is empty — every authenticated user would reach every route. Pass the derived group list (scripts/vpn-groups.py)."
    }
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.vpn.name
    cloudwatch_log_stream = "connections"
  }

  tags = local.full_tags
}

# ── Network Associations ──────────────────────────────────────────────────────
# Associate VPN endpoint with management VPC subnets.
# One association per subnet — AWS creates an ENI in each subnet.

resource "aws_ec2_client_vpn_network_association" "main" {
  for_each = toset(var.target_subnet_ids)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = each.value
}

# ── Routes ────────────────────────────────────────────────────────────────────
# Routes tell VPN clients how to reach private CIDRs.
# Management VPC — always routed.

resource "aws_ec2_client_vpn_route" "management_vpc" {
  for_each = toset(var.target_subnet_ids)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  destination_cidr_block = var.target_vpc_cidr
  target_vpc_subnet_id   = each.value
  description            = "Management VPC"

  depends_on = [aws_ec2_client_vpn_network_association.main]
}

# Additional workload/data VPC routes
resource "aws_ec2_client_vpn_route" "additional" {
  for_each = local.route_pairs

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  destination_cidr_block = each.value.cidr
  target_vpc_subnet_id   = each.value.subnet_id
  description            = each.value.name

  depends_on = [aws_ec2_client_vpn_network_association.main]
}

# ── Authorization Rules ───────────────────────────────────────────────────────
# Two modes, never both:
#   groups empty  → every authenticated user reaches every route (cert / AD)
#   groups given  → one rule per (group, route) from group_rules; the group
#                   name in the rule is the SAML memberOf value, verbatim

resource "aws_ec2_client_vpn_authorization_rule" "management_vpc" {
  count = local.per_group_rules ? 0 : 1

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.target_vpc_cidr
  authorize_all_groups   = true
  description            = "Management VPC — all authenticated VPN users"
}

resource "aws_ec2_client_vpn_authorization_rule" "additional" {
  for_each = local.per_group_rules ? {} : var.additional_routes

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = each.value
  authorize_all_groups   = true
  description            = each.key
}

resource "aws_ec2_client_vpn_authorization_rule" "group" {
  for_each = local.per_group_rules ? local.group_rule_pairs : {}

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = local.route_cidrs[each.value.route]
  access_group_id        = each.value.group
  description            = "${each.value.group} → ${each.value.route}"

  lifecycle {
    precondition {
      condition     = contains(keys(local.route_cidrs), each.value.route)
      error_message = "group_rules names route ${each.value.route}, which is neither \"management\" nor a key of additional_routes."
    }
  }
}
