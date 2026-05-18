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

  # AD auth — layered on top of cert auth when directory_id is provided
  dynamic "authentication_options" {
    for_each = var.directory_id != "" ? [1] : []
    content {
      type                = "directory-service-authentication"
      active_directory_id = var.directory_id
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
# Control which connected clients can reach which CIDRs.
# authorize_all_groups = true — any authenticated VPN user.
# Restrict to AD groups (access_group_id) once AD groups are defined.

resource "aws_ec2_client_vpn_authorization_rule" "management_vpc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.target_vpc_cidr
  authorize_all_groups   = true
  description            = "Management VPC — all authenticated VPN users"
}

resource "aws_ec2_client_vpn_authorization_rule" "additional" {
  for_each = var.additional_routes

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = each.value
  authorize_all_groups   = true
  description            = each.key
}
