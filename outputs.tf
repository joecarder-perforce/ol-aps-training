output "api_endpoints" {
  value = { for k, m in module.cluster : k => m.api_endpoint }
}

output "nlb_dns" {
  value = { for k, m in module.cluster : k => m.nlb_dns }
}

output "private_zone_ids" {
  value = { for k, m in module.cluster : k => m.private_zone_id }
}

output "private_zone_id"  { 
  value = aws_route53_zone.private.zone_id
}

output "api_nlb_dns_name" { 
  value = aws_lb.api.dns_name 
}