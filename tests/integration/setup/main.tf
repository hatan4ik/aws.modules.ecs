# Disposable prerequisites for the integration suites: a VPC with two private
# subnets and two private route tables, nothing else. The root module always
# needs a real vpc_id (module.endpoints creates its security group there even
# when no endpoint is declared), but the smoke suite requests zero interface
# and gateway endpoints, so no NAT gateway, internet gateway, or public subnet
# is needed here. Everything is created and destroyed by `terraform test` in
# the caller's own account; nothing here is shared or long-lived.

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  name = "${var.name_prefix}-${random_id.suffix.hex}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = merge(var.tags, {
    Name            = local.name
    IntegrationTest = "aws.modules.ecs"
    Disposable      = "true"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.tags
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone = local.azs[count.index]

  tags = merge(local.tags, { Name = "${local.name}-private-${count.index}", Tier = "private" })
}

# One route table per subnet, with no routes: nothing outside the VPC is
# reachable, which matches the module's own precondition-free default and
# needs no NAT gateway, internet gateway, or Elastic IP for the suite.
resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${local.name}-private-${count.index}" })
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
