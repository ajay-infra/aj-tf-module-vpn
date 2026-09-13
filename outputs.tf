output "vpn_endpoint_id" {
  description = "Client VPN endpoint ID."
  value       = aws_ec2_client_vpn_endpoint.main.id
}

output "vpn_dns_name" {
  description = "Client VPN endpoint DNS name — embedded in the .ovpn client config."
  value       = aws_ec2_client_vpn_endpoint.main.dns_name
}

output "security_group_id" {
  description = "VPN endpoint security group ID."
  value       = aws_security_group.vpn.id
}

output "client_ca_cert_pem" {
  description = "Client CA certificate PEM — needed to sign individual engineer client certs."
  value       = tls_self_signed_cert.client_ca.cert_pem
  sensitive   = true
}

output "client_ca_private_key_pem" {
  description = <<-EOT
    Client CA private key PEM — used to sign engineer client certs.
    Store securely (Secrets Manager or Vault). Never commit to git.
  EOT
  value       = tls_private_key.client_ca.private_key_pem
  sensitive   = true
}

output "client_config_template" {
  description = <<-EOT
    Base .ovpn configuration template. Add <cert> and <key> blocks for each engineer
    before distributing. The CA cert block is already included.
  EOT
  sensitive   = true
  value       = <<-EOT
    client
    dev tun
    proto udp
    remote ${aws_ec2_client_vpn_endpoint.main.dns_name} 443
    remote-random-hostname
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    remote-cert-tls server
    cipher AES-256-GCM
    verb 3
    reneg-sec 0
    <ca>
    ${tls_self_signed_cert.client_ca.cert_pem}
    </ca>
    # Add engineer-specific certificate and private key:
    # <cert>
    # -----BEGIN CERTIFICATE-----
    # ...
    # -----END CERTIFICATE-----
    # </cert>
    # <key>
    # -----BEGIN RSA PRIVATE KEY-----
    # ...
    # -----END RSA PRIVATE KEY-----
    # </key>
  EOT
}

output "log_group_name" {
  description = "CloudWatch log group name for VPN connection logs."
  value       = aws_cloudwatch_log_group.vpn.name
}

output "server_certificate_arn" {
  description = "ACM ARN of the server certificate."
  value       = aws_acm_certificate.server.arn
}

output "client_ca_certificate_arn" {
  description = "ACM ARN of the client CA certificate."
  value       = aws_acm_certificate.client_ca.arn
}

output "authorization_mode" {
  description = "per-group (SAML, rules keyed on memberOf) or all-groups (certificate / AD)."
  value       = local.per_group_rules ? "per-group" : "all-groups"
}

output "group_rule_count" {
  value = length(local.group_rule_pairs)
}
