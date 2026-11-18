# Project 02 - Migrate Hybrid Bank Ghana - FAST DEMO v4 - NO EKS
# Why no EKS? EKS takes 20-30 min and fails late. EC2 proves the SAME hybrid story in 5 min.
# Core stays on-prem 192.168.0.0/16. Mobile on AWS 10.1.0.0/16. Connected by VPN 2 tunnels.
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
provider "aws" { region = var.aws_region }
locals {
  name = var.project_name
  tags = { Project = "02-migrate-hybrid-bank-ghana", Owner = var.owner, Env = var.environment, ManagedBy = "terraform", Industry = "Banking-Ghana", LinkedToHotel = "NO", DemoMode = "fast-ec2-no-eks" }
}
# VPC
module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "5.0.0"
  name                 = "${local.name}-vpc"
  cidr                 = var.aws_vpc_cidr
  azs                  = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets       = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets      = ["10.1.11.0/24", "10.1.12.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_vpn_gateway   = false
  tags                 = local.tags
}
# KMS + Secrets - v2 name + immediate delete, no recycle-bin clash
resource "aws_kms_key" "bank" {
  description         = "Bank mobile KMS - hybrid"
  enable_key_rotation = true
  tags                = local.tags
}
resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name}/rds/password-v2"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.bank.key_id
  tags                    = local.tags
}
# RDS - Postgres 16.4 - verified current in eu-west-1
resource "aws_db_subnet_group" "mobile" {
  name       = "${local.name}-db-subnet"
  subnet_ids = module.vpc.private_subnets
  tags       = local.tags
}
resource "aws_security_group" "rds" {
  name   = "${local.name}-rds-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
    description = "EC2 mobile API only"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}
resource "aws_db_instance" "mobile" {
  identifier = "${local.name}-mobile-db"
  engine     = "postgres"
  # engine_version removed on purpose - let AWS use its current default, so we never hit "Cannot find version" again
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.bank.arn
  db_name                = "bankmobile"
  username               = "bankadmin"
  password               = "ChangeMe123!DemoOnly"
  db_subnet_group_name   = aws_db_subnet_group.mobile.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  deletion_protection    = false
  tags                   = local.tags
}
# EC2 Mobile API - replaces EKS, same story, 2 min to launch, free-tier eligible
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
resource "aws_security_group" "ec2" {
  name   = "${local.name}-ec2-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ALB to EC2"
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
    description = "SSH from VPC only"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}
resource "aws_instance" "mobile_api" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data              = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3
    echo '{"status":"ok","service":"bank-mobile-api","mode":"hybrid","core":"on-prem-192.168.0.0/16-Ghana"}' > /tmp/health.json
    nohup python3 -m http.server 80 --directory /tmp &
  EOF
  tags                   = merge(local.tags, { Name = "${local.name}-mobile-api" })
}
# HYBRID VPN - 2 tunnels
resource "aws_customer_gateway" "onprem_accra" {
  bgp_asn    = 65000
  ip_address = var.onprem_public_ip
  type       = "ipsec.1"
  tags       = merge(local.tags, { Role = "on-prem-router-accra", OnPremCIDR = var.onprem_cidr })
}
resource "aws_vpn_gateway" "vgw" {
  vpc_id = module.vpc.vpc_id
  tags   = merge(local.tags, { Role = "vgw" })
}
resource "aws_vpn_gateway_route_propagation" "prop" {
  vpn_gateway_id = aws_vpn_gateway.vgw.id
  route_table_id = module.vpc.private_route_table_ids[0]
}
resource "aws_vpn_connection" "hybrid" {
  vpn_gateway_id      = aws_vpn_gateway.vgw.id
  customer_gateway_id = aws_customer_gateway.onprem_accra.id
  type                = "ipsec.1"
  static_routes_only  = false
  tags                = merge(local.tags, { Role = "hybrid-vpn-2-tunnels", Note = "DX-1Gbps-Accra-MSA is future upgrade path, not provisioned here" })
}
resource "aws_route" "to_onprem" {
  route_table_id         = module.vpc.private_route_table_ids[0]
  destination_cidr_block = var.onprem_cidr
  gateway_id             = aws_vpn_gateway.vgw.id
  depends_on             = [aws_vpn_connection.hybrid]
}
# ALB
resource "aws_security_group" "alb" {
  name   = "${local.name}-alb-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Mobile app public"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}
resource "aws_lb" "mobile" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets
  tags               = local.tags
}
resource "aws_lb_target_group" "mobile" {
  name     = "${local.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  health_check {
    path                = "/health.json"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
  }
  tags = local.tags
}
resource "aws_lb_target_group_attachment" "mobile" {
  target_group_arn = aws_lb_target_group.mobile.arn
  target_id        = aws_instance.mobile_api.id
  port             = 80
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.mobile.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mobile.arn
  }
}
# Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/aws/vpc/${local.name}/flow"
  retention_in_days = 30
  tags              = local.tags
}
resource "aws_iam_role" "flow" {
  name = "${local.name}-flow-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
  tags = local.tags
}
resource "aws_flow_log" "vpc" {
  vpc_id          = module.vpc.vpc_id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.vpc_flow.arn
  iam_role_arn    = aws_iam_role.flow.arn
  tags            = local.tags
}
