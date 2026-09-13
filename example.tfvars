# example.tfvars — CI dry-run plan (no real AWS credentials required)

aws_region  = "us-east-1"
environment = "dev"

# Management VPC
vpc_id            = "vpc-0management123456"
target_subnet_ids = ["subnet-0mgmt111aaa", "subnet-0mgmt222bbb"]
target_vpc_cidr   = "10.200.0.0/16"

# Client IP range — must not overlap any VPC CIDR
client_cidr = "172.16.0.0/22"

# Split tunnel — only RFC1918 goes through VPN
split_tunnel = true

# AD DNS servers from aj-tf-module-directory (placeholder)
dns_servers = ["10.200.1.5", "10.200.1.6"]

# AD directory ID from aj-tf-module-directory (empty = cert-only auth)
directory_id = ""

# Workload VPCs reachable through VPN
additional_routes = {
  dev-vpc     = "10.100.0.0/16"
  dev-data    = "10.102.0.0/16"
  staging-vpc = "10.110.0.0/16"
}

# Cert validity — 10 years
cert_validity_hours = 87600

# Connection logs retention
log_retention_days = 30

team        = "team-0001"   # a team code — aj-infra/envs/org/teams.yaml
cost_center = "infra-2026-q1"
