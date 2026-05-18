# envs/prod.tfvars — prod access (via central-prod management VPC)

aws_region  = "us-east-1"
environment = "prod"

vpc_id            = "REPLACE_WITH_MGMT_VPC_ID"
target_subnet_ids = ["REPLACE_WITH_MGMT_SUBNET_A", "REPLACE_WITH_MGMT_SUBNET_B"]
target_vpc_cidr   = "10.201.0.0/16"

client_cidr  = "172.16.4.0/22" # different range from dev VPN to avoid overlap
split_tunnel = true

dns_servers  = ["REPLACE_WITH_AD_DNS_IP_1", "REPLACE_WITH_AD_DNS_IP_2"]
directory_id = "REPLACE_WITH_DIRECTORY_ID"

additional_routes = {
  prod-blue-vpc  = "10.120.0.0/16"
  prod-green-vpc = "10.121.0.0/16"
  prod-data-vpc  = "10.122.0.0/16"
}

cert_validity_hours = 87600
log_retention_days  = 90

team        = "infra-core"
cost_center = "infra-2026-q1"
