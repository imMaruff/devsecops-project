# ============================================================
# SECURED TERRAFORM - AFTER AI REMEDIATION
# All vulnerabilities identified by Trivy have been fixed
# per AI-recommended security best practices.
# ============================================================

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------
# FIX 1: Security Group - SSH restricted, no overly permissive rules
# ---------------------------------------------------------------
resource "aws_security_group" "web_sg" {
  name        = "web-security-group-secured"
  description = "Security group for web application - secured"
  vpc_id      = aws_vpc.main.id

  # FIXED: SSH restricted to specific IP (your office/home IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]   # FIXED: Restricted to known IP
    description = "SSH access from trusted IP only"
  }

  # HTTP allowed for web traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP web traffic"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS web traffic"
  }

  # FIXED: Restrictive egress - only necessary ports
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }

  tags = {
    Name        = "web-sg-secured"
    Environment = "production"
  }
}

# ---------------------------------------------------------------
# FIX 2: EC2 instance with encrypted volumes & IMDSv2
# ---------------------------------------------------------------
resource "aws_instance" "web_server" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  # FIXED: Encrypted root volume
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true   # FIXED: Encryption enabled
    kms_key_id  = aws_kms_key.ebs_key.arn
  }

  # FIXED: IMDSv2 enforced (prevents SSRF attacks)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # FIXED: IMDSv2 required
    http_put_response_hop_limit = 1
  }

  # FIXED: Monitoring enabled
  monitoring = true

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    docker run -d -p 80:3000 --restart unless-stopped devsecops-app:latest
  EOF
  )

  tags = {
    Name        = "web-server-secured"
    Environment = "production"
  }
}

# ---------------------------------------------------------------
# FIX 3: S3 Bucket - all public access blocked, versioning on
# ---------------------------------------------------------------
resource "aws_s3_bucket" "app_storage" {
  bucket = "devsecops-app-storage-${random_id.suffix.hex}"

  tags = {
    Name        = "app-storage"
    Environment = "production"
  }
}

# FIXED: All public access blocked
resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true   # FIXED
  block_public_policy     = true   # FIXED
  ignore_public_acls      = true   # FIXED
  restrict_public_buckets = true   # FIXED
}

# FIXED: Versioning enabled
resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id
  versioning_configuration {
    status = "Enabled"   # FIXED
  }
}

# FIXED: Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
    bucket_key_enabled = true
  }
}

# ---------------------------------------------------------------
# KMS Keys for encryption
# ---------------------------------------------------------------
resource "aws_kms_key" "ebs_key" {
  description             = "KMS key for EBS volume encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "ebs-encryption-key" }
}

resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "s3-encryption-key" }
}

# ---------------------------------------------------------------
# Networking (unchanged)
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
  map_public_ip_on_launch = false   # FIXED: Disable auto public IP
  tags                    = { Name = "public-subnet" }
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
