#variable "region" {
#  description = "AWS region"
#  type = string
#}

#variable "profile" {
#  description = "AWS profile"
#  type = string
#}

variable "project" {
  description = "Project name"
  type = string
}


variable "domain_name" {
  description = "Root domain to deploy"
  type = string
}


variable "subdomain" {
  description = "Subdomain to point at CloudFront"
  type = string
}


variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for the domain"
  type = string
}


variable "lambda_zip_path" {
  description = "Local path to zipped lambda function payload"
  type = string
}


variable "create_dynamodb" {
  type = bool
  default = true
}


variable "bookings_table_name" {
  description = "Bookings table for meal rocket"
  type = string
 
}


variable "from_email" {
type = string
description = "Verified SES from email"
}