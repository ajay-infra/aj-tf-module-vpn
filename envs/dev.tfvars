# envs/dev.tfvars — dev + staging access (via central-nonprod management VPC)

aws_region  = "us-east-1"
environment = "dev"

vpc_id            = "REPLACE_WITH_MGMT_VPC_ID"
target_subnet_ids = ["REPLACE_WITH_MGMT_SUBNET_A", "REPLACE_WITH_MGMT_SUBNET_B"]
target_vpc_cidr   = "10.200.0.0/16"

client_cidr  = "172.16.0.0/22"
split_tunnel = true

# From aj-tf-module-directory outputs
dns_servers  = ["REPLACE_WITH_AD_DNS_IP_1", "REPLACE_WITH_AD_DNS_IP_2"]
directory_id = "REPLACE_WITH_DIRECTORY_ID"

# Workload VPCs reachable through VPN
additional_routes = {
  dev-blue-vpc = "10.100.0.0/16"
  dev-data-vpc = "10.102.0.0/16"
  staging-vpc  = "10.110.0.0/16"
  staging-data = "10.112.0.0/16"
}

cert_validity_hours = 87600
log_retention_days  = 30

team        = "infra-core"
cost_center = "infra-2026-q1"
