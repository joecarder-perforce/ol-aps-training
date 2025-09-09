output "api_endpoints" {
  value = { for k, m in module.cluster : k => m.api_endpoint }
}

output "nlb_dns" {
  value = { for k, m in module.cluster : k => m.nlb_dns }
}

output "private_zone_ids" {
  value = { for k, m in module.cluster : k => m.private_zone_id }
}

output "api_nlb_dns_name" {
  description = "API/MCS NLB DNS names per cluster (from module)"
  value       = { for k, m in module.ocp_compact : k => m.nlb_dns }
}

output "private_zone_id" {
  description = "Private hosted zone IDs per cluster (from module)"
  value       = { for k, m in module.ocp_compact : k => m.private_zone_id }
}