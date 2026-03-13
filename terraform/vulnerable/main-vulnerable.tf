# ============================================================
# INTENTIONALLY VULNERABLE TERRAFORM - BEFORE AI REMEDIATION
# This file contains known security misconfigurations for the
# purpose of demonstrating AI-driven security remediation.
# DO NOT USE IN PRODUCTION
# ============================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------
# VULNERABILITY 1: Security Group with SSH open to 0.0.0.0/0
# ---------------------------------------------------------------
resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Security group for web application"
  vpc_id      = aws_vpc.main.id

  # INSECURE: SSH open to entire internet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # VULNERABILITY: Should be restricted IP
  }

  # INSECURE: HTTP open to entire internet (acceptable for web)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # INSECURE: All outbound traffic allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]   # VULNERABILITY: Overly permissive egress
  }

  tags = {
    Name = "web-sg-vulnerable"
  }
}

# ---------------------------------------------------------------
# VULNERABILITY 2: EC2 instance with unencrypted root volume
# ---------------------------------------------------------------
resource "aws_instance" "web_server" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  # INSECURE: No encryption on root volume
  root_block_device {
    volume_size = 20
    volume_type = "gp2"
    encrypted   = false   # VULNERABILITY: Disk not encrypted
  }

  # INSECURE: User data passed in plaintext
  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    docker run -d -p 80:3000 devsecops-app:latest
  EOF

  tags = {
    Name = "web-server-vulnerable"
  }
}

# ---------------------------------------------------------------
# VULNERABILITY 3: S3 Bucket with public access enabled
# ---------------------------------------------------------------
resource "aws_s3_bucket" "app_storage" {
  bucket = "devsecops-app-storage-${random_id.suffix.hex}"
}

# INSECURE: Public access NOT blocked
resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = false   # VULNERABILITY
  block_public_policy     = false   # VULNERABILITY
  ignore_public_acls      = false   # VULNERABILITY
  restrict_public_buckets = false   # VULNERABILITY
}

# INSECURE: No bucket versioning
resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id
  versioning_configuration {
    status = "Disabled"   # VULNERABILITY: Should be Enabled
  }
}

# ---------------------------------------------------------------
# Networking
# ---------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "main-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true   # VULNERABILITY: Auto-assigns public IPs
  tags = { Name = "public-subnet" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "random_id" "suffix" {
  byte_length = 4
}

output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app_storage.bucket
}
