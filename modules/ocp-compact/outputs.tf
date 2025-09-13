output "api_endpoint" {
  value = "https://api.${var.cluster}.${var.base_domain}:6443"
}

output "nlb_dns" {
  value = aws_lb.api_mcs.dns_name
}

output "private_zone_id" {
  value = var.private_zone_id
}

output "private_zone_name" {
  value = "${var.cluster}.${var.base_domain}"
}

output "vpc_id" {
  description = "ID of the cluster VPC"
  value       = aws_vpc.main.id
}