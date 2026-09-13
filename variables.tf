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

variable "saml_provider_arn" {
  type        = string
  description = <<-EOT
    IAM SAML provider ARN (in THIS account) built from IAM Identity Center's
    metadata — aj-infra-identity stacks/vpn-idp creates it. When set, the
    endpoint uses federated-authentication alongside the client certificate:
    the engineer signs in through Identity Center in a browser and the SAML
    assertion carries their group names in memberOf. Mutually exclusive with
    directory_id: Client VPN allows one user-auth method beside mutual TLS,
    and this is the one that reads the estate's groups
    (identity-and-access-v1.md §7). Leave "" for certificate-only or AD.
  EOT
  default     = ""
  validation {
    condition     = var.saml_provider_arn == "" || can(regex("^arn:aws:iam::[0-9]{12}:saml-provider/", var.saml_provider_arn))
    error_message = "saml_provider_arn must be an IAM SAML provider ARN, or empty."
  }
}

variable "self_service_saml_provider_arn" {
  type        = string
  description = "Optional second SAML provider for the self-service portal (client download). Empty = none."
  default     = ""
}

variable "groups" {
  type        = list(string)
  description = <<-EOT
    The group names that may connect — as they arrive in the SAML assertion's
    memberOf attribute, verbatim on the identity-and-access-v1.md §3 grammar.
    Derived by the caller (aj-infra scripts/vpn-groups.py): the four estate
    tiers plus read/write for every active team whose classes include this
    hub's class. When non-empty, authorization rules are per group (below)
    and no rule authorizes all groups. Empty = every authenticated user may
    reach every route (the pre-SAML behaviour, certificate/AD auth).
  EOT
  default     = []
  validation {
    condition     = alltrue([for g in var.groups : can(regex("^(team-[0-9]{4}-(read|write)|estate-(read|infra|admin|break-glass))$", g))])
    error_message = "Every group must be team-NNNN-read|write or estate-read|infra|admin|break-glass."
  }
}

variable "group_rules" {
  type        = map(list(string))
  description = <<-EOT
    Which routes each TIER of group may reach. Keys: "estate", "team-read",
    "team-write". Values: route names — keys of additional_routes, plus
    "management" for the endpoint's own VPC. Expanded against var.groups:
    every estate-* group gets the "estate" list, every team-*-read the
    "team-read" list, and so on. Lives in the environment's vpn.tfvars, so
    what a tier reaches is configuration, while WHICH groups exist is derived.
    Ignored when groups is empty.
  EOT
  default = {
    estate     = ["management"]
    team-read  = ["management"]
    team-write = ["management"]
  }
  validation {
    condition     = alltrue([for k, _ in var.group_rules : contains(["estate", "team-read", "team-write"], k)])
    error_message = "group_rules keys must be estate, team-read, team-write."
  }
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
  description = "Owning team CODE — the Team tag, and the `team` label on any namespace this creates. A row in aj-infra/envs/org/teams.yaml. No default: `infra-core` was the default until 2026-09-13, and a caller that forgot to pass a team silently tagged everything with a slug nobody registered; with require-product-code at deny, a namespace so labelled is refused."
  type        = string
  validation {
    condition     = can(regex("^team-[0-9]{4}$", var.team))
    error_message = "team must be a team code — team- and four digits (aj-infra/envs/org/teams.yaml)."
  }
}

variable "cost_center" {
  type    = string
  default = "infra-2026-q1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
