variable "project_name" {
  type        = string
  default     = "bank-mobile"
  description = "Prefix for all resources"
}

variable "owner" {
  type    = string
  default = "your-name"
}

variable "environment" {
  type    = string
  default = "demo"
}

variable "aws_region" {
  type        = string
  default     = "eu-west-1"
  description = "Closest to Ghana for demo"
}

variable "aws_vpc_cidr" {
  type        = string
  default     = "10.1.0.0/16"
  description = "AWS side - MUST NOT overlap on-prem"
}

variable "onprem_cidr" {
  type        = string
  default     = "192.168.0.0/16"
  description = "On-prem core banking in Ghana - BoG law, stays on-prem"
}

variable "onprem_public_ip" {
  type        = string
  default     = "203.0.113.10"
  description = "REPLACE with real on-prem router public IP in production. 203.0.113.10 is TEST-NET-3 placeholder for demo."
}
