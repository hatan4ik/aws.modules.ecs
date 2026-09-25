provider "aws" {
  region = var.region
}

# The smallest useful platform foundation: a cluster, a shared KMS key, an
# application log group, and the registry and session-store submodules, all
# on their defaults. No private endpoints are declared, so tasks in these
# subnets need a NAT gateway or another egress path to reach AWS APIs; see
# examples/complete for interface and gateway endpoints.
module "platform" {
  source = "../../"

  name                    = var.name
  vpc_id                  = var.vpc_id
  vpc_cidr                = var.vpc_cidr
  private_subnet_ids      = var.private_subnet_ids
  private_route_table_ids = var.private_route_table_ids
  log_retention_in_days   = var.log_retention_in_days
  tags                    = var.tags
}
