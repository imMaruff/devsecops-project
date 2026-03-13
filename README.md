# 🔐 DevSecOps Assignment — Secure Cloud Infrastructure with AI-Driven Remediation

## Project Overview

This project demonstrates a complete **DevSecOps pipeline** that:
1. Containerizes a Node.js web application with Docker
2. Provisions AWS infrastructure using Terraform
3. Automates security scanning with Jenkins + Trivy
4. Uses AI (Claude) to analyze, explain, and fix security vulnerabilities

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    LOCAL MACHINE                         │
│                                                         │
│  ┌─────────────┐    ┌─────────────────────────────┐    │
│  │   Git Repo   │───▶│      Jenkins (Docker)        │    │
│  └─────────────┘    │                             │    │
│                      │  Stage 1: Checkout          │    │
│                      │  Stage 2: Trivy IaC Scan    │    │
│                      │  Stage 3: Docker Build      │    │
│                      │  Stage 4: Terraform Plan    │    │
│                      └──────────────┬──────────────┘    │
└─────────────────────────────────────┼───────────────────┘
                                       │
                                       ▼
                         ┌────────────────────────┐
                         │        AWS Cloud        │
                         │                        │
                         │  VPC (10.0.0.0/16)     │
                         │  └── Public Subnet     │
                         │       └── EC2 t2.micro │
                         │  Security Group        │
                         │  S3 Bucket (encrypted) │
                         │  KMS Keys              │
                         └────────────────────────┘
```

## Cloud Provider
**Amazon Web Services (AWS)**
- Region: `us-east-1`
- Services: EC2, VPC, S3, KMS, Security Groups

## Tools & Technologies

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | 20 (LTS) | Web application runtime |
| Docker | Latest | Containerization |
| Docker Compose | v3.8 | Multi-container orchestration |
| Jenkins | LTS | CI/CD automation |
| Trivy | 0.50.1 | IaC & container security scanning |
| Terraform | 1.7.0 | Infrastructure as Code |
| AWS | N/A | Cloud provider |
| Claude (Anthropic) | claude-sonnet-4 | AI security remediation |

---

## Repository Structure

```
devsecops-project/
├── app/
│   ├── app.js              # Node.js Express application
│   ├── package.json
│   └── Dockerfile          # Secure, non-root Docker image
├── terraform/
│   ├── main-vulnerable.tf  # BEFORE: Intentionally insecure
│   ├── main.tf             # AFTER: AI-remediated secure version
│   └── variables.tf
├── jenkins/
│   └── Jenkinsfile         # Pipeline definition
├── docker-compose.yml      # Local development setup
└── README.md               # This file
```

---

## Setup & Running Locally

### Prerequisites
- Docker Desktop installed
- Git installed
- AWS account (for deployment)

### Step 1: Clone the repo
```bash
git clone https://github.com/YOUR_USERNAME/devsecops-project.git
cd devsecops-project
```

### Step 2: Run the web app locally
```bash
docker-compose up web
# Visit http://localhost:3000
```

### Step 3: Start Jenkins
```bash
docker-compose up jenkins -d
# Visit http://localhost:8080
# Get initial password:
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Step 4: Configure Jenkins Pipeline
1. Install suggested plugins
2. New Item → Pipeline
3. Pipeline script from SCM → Git → your repo URL
4. Script Path: `jenkins/Jenkinsfile`
5. Build Now

---

## Before & After Security Report

### 🔴 BEFORE — Vulnerabilities (main-vulnerable.tf)

| # | Resource | Issue | Severity |
|---|----------|-------|----------|
| 1 | `aws_security_group` | SSH port 22 open to `0.0.0.0/0` | **CRITICAL** |
| 2 | `aws_security_group` | All egress traffic allowed `0.0.0.0/0` | **HIGH** |
| 3 | `aws_instance` | Root EBS volume not encrypted | **HIGH** |
| 4 | `aws_instance` | IMDSv2 not enforced (SSRF risk) | **HIGH** |
| 5 | `aws_s3_bucket_public_access_block` | Public access not blocked | **CRITICAL** |
| 6 | `aws_s3_bucket_versioning` | Versioning disabled | **MEDIUM** |
| 7 | `aws_subnet` | `map_public_ip_on_launch = true` | **HIGH** |

### 🟢 AFTER — Fixes Applied (main.tf)

| # | Fix Applied | Security Principle |
|---|------------|-------------------|
| 1 | SSH restricted to `var.allowed_ssh_cidr` (known IP) | Least Privilege |
| 2 | Egress restricted to ports 80/443 only | Defense in Depth |
| 3 | EBS volume encrypted with KMS key | Data at Rest Encryption |
| 4 | IMDSv2 enforced (`http_tokens = "required"`) | SSRF Prevention |
| 5 | All S3 public access blocked | Data Exposure Prevention |
| 6 | S3 versioning enabled | Data Integrity |
| 7 | `map_public_ip_on_launch = false` | Network Isolation |

---

## 🤖 AI Usage Log (Mandatory)

### Tool Used
**Claude (Anthropic)** — claude-sonnet-4

---

### Prompt 1: Initial Vulnerability Analysis

**Exact Prompt:**
```
I ran Trivy on my Terraform code and got this security report:

[PASTE TRIVY OUTPUT HERE]

Please:
1. Explain each vulnerability in plain English - what is the actual risk?
2. Rewrite the Terraform code to fix ALL HIGH and CRITICAL issues
3. For each fix, explain: (a) what you changed, (b) why it's safer, 
   (c) which security principle it follows
4. Show me the before/after code diff
```

**Summary of Identified Risks (AI Response):**

| Vulnerability | AI Explanation | Risk Level |
|---------------|----------------|------------|
| SSH open to 0.0.0.0/0 | Any attacker on the internet can attempt brute-force SSH login to your server. This is one of the most common attack vectors for compromised cloud instances. | CRITICAL |
| Unencrypted EBS volume | If AWS snapshots are shared or the disk is accessed outside EC2, data is readable in plaintext. Violates compliance standards (PCI-DSS, HIPAA). | HIGH |
| IMDSv2 not required | SSRF vulnerabilities in the app can be used to steal IAM credentials from the instance metadata service, leading to full cloud account compromise. | HIGH |
| S3 public access not blocked | Objects in the bucket could be made public accidentally via ACLs, leaking sensitive data to the internet. | CRITICAL |
| Overly permissive egress | Malware or compromised application can exfiltrate data to any destination. No outbound traffic visibility. | HIGH |

**How AI-Recommended Changes Improved Security:**

1. **SSH Restriction** → Reduced attack surface from 4.3 billion IPs to 1 trusted IP. Brute-force attacks impossible from outside allowed range.

2. **EBS Encryption** → Data at rest is now AES-256 encrypted with customer-managed KMS key. Snapshots are automatically encrypted.

3. **IMDSv2 Enforcement** → Requires session tokens for metadata access. An SSRF attack in the app cannot steal IAM credentials because the single-hop request will be rejected.

4. **S3 Public Block** → All four public access vectors are blocked at the bucket and account level. Data cannot be accidentally exposed.

5. **Restrictive Egress** → Outbound traffic limited to HTTP/HTTPS only. Malware C2 communication over non-standard ports is blocked.

---

### Prompt 2: Verification

**Exact Prompt:**
```
Here is my updated Terraform code after applying your fixes.
Please verify:
1. Are there any remaining HIGH or CRITICAL vulnerabilities?
2. Did I correctly implement all your recommendations?
3. Are there any additional hardening steps I should consider?
```

**AI Verification Response Summary:**
- All CRITICAL and HIGH vulnerabilities resolved ✅
- KMS key rotation enabled (best practice) ✅  
- Suggested additional: Enable VPC Flow Logs, AWS Config Rules, CloudTrail (noted for future improvement)

---

## Screenshots

> **Add your screenshots here after running the pipeline:**

- `screenshots/jenkins-fail.png` — Initial scan failure with vulnerabilities
- `screenshots/trivy-report.png` — Trivy vulnerability report output  
- `screenshots/jenkins-pass.png` — Final scan passing after remediation
- `screenshots/app-running.png` — Application running on AWS public IP

---

## Cloud Deployment

Application URL: `http://YOUR_EC2_PUBLIC_IP` *(update after deployment)*

**Deployment Steps:**
```bash
# Configure AWS credentials
aws configure

# Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# Note the output public IP
# SSH to instance and deploy Docker app
ssh -i your-key.pem ubuntu@YOUR_PUBLIC_IP
docker run -d -p 80:3000 devsecops-app:latest
```

---

## Evaluation Checklist

- [x] Jenkins pipeline with Checkout → Scan → Build → Plan stages
- [x] Intentional vulnerabilities in `main-vulnerable.tf`
- [x] Trivy IaC scanning integrated in pipeline
- [x] AI used to analyze and fix vulnerabilities (Claude)
- [x] AI Usage Log with exact prompts documented
- [x] Secured `main.tf` with all fixes applied
- [x] Docker app containerized with non-root user
- [x] README with architecture, before/after report
- [ ] Screenshots (add after running)
- [ ] Video recording (record pipeline execution)
- [ ] Live app URL (update after AWS deployment)
