output "vpc_id" {
  value = module.vpc.vpc_id
}
output "aws_vpc_cidr" {
  value = var.aws_vpc_cidr
}
output "onprem_cidr" {
  value = var.onprem_cidr
}
output "alb_dns_name" {
  value = aws_lb.mobile.dns_name
}
output "vpn_connection_id" {
  value = aws_vpn_connection.hybrid.id
}
output "vpn_gateway_id" {
  value = aws_vpn_gateway.vgw.id
}
output "customer_gateway_id" {
  value = aws_customer_gateway.onprem_accra.id
}
output "mobile_api_instance_id" {
  value = aws_instance.mobile_api.id
}
output "rds_endpoint" {
  value = aws_db_instance.mobile.address
}
output "next_step" {
  value = "Check VPN in console, curl ALB /health.json, then terraform destroy"
}
