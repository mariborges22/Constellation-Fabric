variable "domain_name" { type = string }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "acm_certificate_arn" { type = string }
variable "route53_zone_id" { type = string }
variable "alb_arn" { type = string }
variable "alb_dns_name" { type = string }
variable "alb_zone_id" { type = string }
variable "target_group_arn" { type = string }
variable "project_name" { type = string }
