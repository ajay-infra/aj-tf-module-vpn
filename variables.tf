# ── Core ──────────────────────────────────────────────────────────────────────

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "name_prefix" {
  type    = string
  default = ""
}

# ── Network ───────────────────────────────────────────────────────────────────

variable "vpc_id" {
  type        = string
  description = "Management VPC ID — where the VPN endpoint is associated."
}

variable "target_subnet_ids" {
  type        = list(string)
  description = <<-EOT
    Management VPC private subnet IDs to associate with the VPN endpoint.
    One association per subnet — VPN clients are assigned IPs from client_cidr
    and routed through these subnets.
    Minimum 1 required; 2 recommended for AZ resilience.
  EOT
}

variable "client_cidr" {
  type        = string
  description = <<-EOT
    CIDR block for VPN client IP assignment. Must not overlap with any VPC CIDR.
    /22 gives up to 1022 concurrent clients.
    Default: 172.16.0.0/22
  EOT
  default     = "172.16.0.0/22"
}

variable "target_vpc_cidr" {
  type        = string
  description = "Management VPC CIDR — added as an authorization rule and route so VPN clients can reach the management VPC."
}

variable "additional_routes" {
  type        = map(string)
  description = <<-EOT
    Additional CIDRs to route through the VPN (workload VPCs, data VPCs).
    Map of descriptive name → CIDR block.
    Example: {
      dev-vpc     = "10.100.0.0/16"
      staging-vpc = "10.110.0.0/16"
      prod-vpc    = "10.120.0.0/16"
    }
    Routes and authorization rules are created for each entry.
  EOT
  default     = {}
}

variable "split_tunnel" {
  type        = bool
  description = <<-EOT
    Enable split tunneling — only RFC1918 traffic routes through the VPN.
    Internet traffic bypasses the VPN entirely.
    Recommended: true. Cost + UX — engineers keep their normal internet connection.
    Set false only if you need to force all traffic through a security appliance.
  EOT
  default     = true
}

variable "dns_servers" {
  type        = list(string)
  description = <<-EOT
    DNS servers pushed to VPN clients. Set to AD DNS IPs from aj-tf-module-directory
    so engineers resolve corp.* names while connected.
    Example: ["10.200.1.5", "10.200.1.6"]
  EOT
  default     = []
}

# ── Authentication ─────────────────────────────────────────────────────────────

variable "directory_id" {
  type        = string
  description = <<-EOT
    AWS Managed AD directory ID from aj-tf-module-directory.
    When set, adds directory-service-authentication alongside certificate auth.
    Engineers must present a valid client cert AND valid AD credentials.
    Leave empty ("") to use certificate-only authentication.
  EOT
  default     = ""
}

variable "cert_validity_hours" {
  type        = number
  description = "Validity period for generated server and CA certificates in hours. Default: 10 years."
  default     = 87600
}

# ── Logging ───────────────────────────────────────────────────────────────────

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention for VPN connection logs."
  default     = 90
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch retention period."
  }
}

# ── Tags ──────────────────────────────────────────────────────────────────────

variable "team" {
  type    = string
  default = "infra-core"
}

variable "cost_center" {
  type    = string
  default = "infra-2026-q1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
