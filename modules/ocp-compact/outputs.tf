output "api_endpoint" { value = "https://api.${var.cluster_name}.${var.base_domain}:6443" }
output "nlb_dns" { value = aws_lb.api_mcs.dns_name }
output "private_zone_id" { value = aws_route53_zone.private.zone_id }
output "api_endpoint" { value = "https://api.${var.cluster}.${var.base_domain}:6443"}
output "private_zone_name" { value = "${var.cluster}.${var.base_domain}"}