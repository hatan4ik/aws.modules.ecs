# Advisory checks: they warn on every plan and apply but never block.

check "container_insights_disabled" {
  assert {
    condition     = var.container_insights != "disabled"
    error_message = "Container Insights is disabled. Task and service metrics will not be collected for this cluster."
  }
}

check "no_endpoints_declared" {
  assert {
    condition     = length(var.interface_endpoint_services) > 0 || length(var.gateway_endpoint_services) > 0
    error_message = "No VPC endpoints are declared. Future ECS tasks in private subnets will need a NAT gateway or another egress path to reach AWS APIs."
  }
}
