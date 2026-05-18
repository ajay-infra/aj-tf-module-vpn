# ── TLS Certificates ──────────────────────────────────────────────────────────
# Self-signed certificates generated at apply time and imported into ACM.
# The server cert authenticates the VPN endpoint to clients.
# The client CA cert signs individual engineer client certs.
#
# Note: private keys are stored in Terraform state (marked sensitive).
# For regulated environments, replace with AWS Private CA.

# ── Server Certificate ────────────────────────────────────────────────────────

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = "server.vpn.${var.environment}"
    organization = local.name_prefix
  }

  validity_period_hours = var.cert_validity_hours
  is_ca_certificate     = false

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "server" {
  private_key      = tls_private_key.server.private_key_pem
  certificate_body = tls_self_signed_cert.server.cert_pem

  tags = merge(local.full_tags, { Purpose = "vpn-server" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── Client CA Certificate ─────────────────────────────────────────────────────
# This is the root CA used to sign individual engineer client certs.
# Engineers generate their own keypair + CSR, then get it signed by this CA.

resource "tls_private_key" "client_ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "client_ca" {
  private_key_pem = tls_private_key.client_ca.private_key_pem

  subject {
    common_name  = "client-ca.vpn.${var.environment}"
    organization = local.name_prefix
  }

  validity_period_hours = var.cert_validity_hours
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

resource "aws_acm_certificate" "client_ca" {
  private_key      = tls_private_key.client_ca.private_key_pem
  certificate_body = tls_self_signed_cert.client_ca.cert_pem

  tags = merge(local.full_tags, { Purpose = "vpn-client-ca" })

  lifecycle {
    create_before_destroy = true
  }
}
