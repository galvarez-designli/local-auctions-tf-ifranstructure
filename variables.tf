variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "project_name" {
  description = "Project name (used for resource naming)"
  type        = string
}

variable "environment" {
  description = "Environment (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "sender_email" {
  description = "The email address to send from (Must be verified in SES)"
  type        = string
}
