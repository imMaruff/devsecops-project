variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance (Ubuntu 22.04 LTS)"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS us-east-1
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance (your IP)"
  type        = string
  # REPLACE with your actual IP: e.g. "203.0.113.10/32"
  default     = "10.0.0.0/8"
}
