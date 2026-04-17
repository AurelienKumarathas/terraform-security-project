# Terraform IaC Security Pipeline — QuantumTrade

[![IaC Security Pipeline](https://github.com/aurelienkumarathas/terraform-security-project/actions/workflows/iac-security.yml/badge.svg)](https://github.com/aurelienkumarathas/terraform-security-project/actions/workflows/iac-security.yml)

![Checkov](https://img.shields.io/badge/Checkov-v3.2.510-brightgreen)
![tfsec](https://img.shields.io/badge/tfsec-v1.28.14-brightgreen)
![OPA](https://img.shields.io/badge/OPA-v0.71-brightgreen)
![Terraform](https://img.shields.io/badge/Terraform-v1.14.4-blue)
![AWS](https://img.shields.io/badge/AWS-eu--west--2-orange)

## Overview

This project demonstrates enterprise-grade Infrastructure as Code (IaC) security scanning for **QuantumTrade**, a fintech platform processing cryptocurrency transactions. It implements a defence-in-depth scanning approach using three independent tools — Checkov, tfsec, and OPA — to identify and remediate security misconfigurations before deployment.

The project intentionally includes an insecure `main.tf` to demonstrate what real-world misconfigurations look like, then provides hardened Terraform modules as the remediated solution.

---

## Business Context

| Item | Detail |
|------|--------|
| **Client** | QuantumTrade — Cryptocurrency Trading Platform |
| **Problem** | S3 data exposure risk, approaching SOC 2 compliance deadline |
| **Solution** | Automated IaC security scanning integrated into CI/CD |
| **Region** | AWS eu-west-2 (London) |
| **Stack** | Terraform + AWS (S3, EC2, RDS PostgreSQL, VPC, KMS) |

---

## Scan Results Summary

### Original `main.tf` (Intentionally Insecure)

| Tool | Passed | Failed | Critical |
|------|--------|--------|----------|
| Checkov v3.2.510 | 14 | 19 | 0 |
| tfsec v1.28.14 | 9 | 19 | 2 |
| OPA v0.71 | — | 23 tag violations | — |

### Secure Modules (Post-Remediation)

| Tool | Passed | Failed | Improvement |
|------|--------|--------|-------------|
| Checkov | 33 | 2 | 89% reduction |
| tfsec | 12 | 1 | 95% reduction |
| OPA | 0 violations | — | 100% resolved |

---

## Repository Structure

```
terraform-security-project/
├── terraform/
│   ├── main.tf                    # Intentionally insecure (demo)
│   ├── main_secure.tf             # Secure version using modules
│   ├── variables.tf               # Input variables
│   └── modules/
│       ├── s3/main.tf             # Hardened S3 module
│       └── ec2/main.tf            # Hardened EC2 module
├── policies/
│   └── opa/
│       ├── required_tags.rego     # Enforce Owner, Environment, CostCenter
│       ├── ec2_instance_types.rego # Block t2 instances in production
│       └── s3_versioning.rego     # Require versioning on production buckets
├── docs/
│   ├── SOC2_CONTROL_MAPPING.md    # SOC 2 Trust Service Criteria mapping
│   └── SECURITY_REPORT.md        # Full security assessment report
├── checkov-results.json           # Checkov raw output (original main.tf)
├── tfsec-results.json             # tfsec raw output (original main.tf)
├── tfsec-results.sarif            # SARIF format for GitHub Security tab
├── checkov-modules-results.txt    # Checkov output (secure modules)
├── tfsec-modules-results.txt      # tfsec output (secure modules)
├── opa-results.json               # OPA policy evaluation output
└── security-findings.md          # Consolidated findings document
```

---

## Security Tools

### Checkov (Prisma Cloud) — v3.2.510
Static analysis against 2,500+ CIS Benchmark and compliance policies. Scans Terraform files without requiring AWS credentials or deployment.

```bash
checkov -d terraform/
checkov -d terraform/modules/
checkov -f terraform/main.tf -o json > checkov-results.json
```

### tfsec (Aqua Security) — v1.28.14
AWS-specific security rules with severity ratings (CRITICAL/HIGH/MEDIUM/LOW). Catches issues Checkov misses including VPC flow logs and S3 versioning.

```bash
tfsec terraform/
tfsec terraform/ --format json > tfsec-results.json
tfsec terraform/ --format sarif > tfsec-results.sarif
tfsec terraform/ --minimum-severity HIGH
```

### OPA (Open Policy Agent) — v0.71
Custom Rego policies enforcing organisation-specific rules that commercial tools do not know about — tagging standards, approved instance types, and architecture requirements.

```bash
opa eval --format pretty \
  --data policies/opa/ \
  --input terraform/tfplan.json \
  "data.terraform"
```

---

## Key Findings

### Critical Issues (Original `main.tf`)

| # | Issue | Tool | Check ID | Risk |
|---|-------|------|----------|------|
| 1 | SSH open to 0.0.0.0/0 on port 22 | tfsec | aws-ec2-no-public-ingress-sgr | Brute force attack vector open to entire internet |
| 2 | Unrestricted egress on all ports | tfsec | aws-ec2-no-public-egress-sgr | Compromised instance can exfiltrate data anywhere |

### High Issues (Original `main.tf`, Sample)

| # | Issue | Tool | Check ID |
|---|-------|------|----------|
| 1 | S3 bucket no encryption | Checkov + tfsec | CKV_AWS_19 / aws-s3-enable-bucket-encryption |
| 2 | All 4 S3 public access blocks disabled | Checkov | CKV_AWS_53, 54, 55, 56 |
| 3 | RDS storage not encrypted | Checkov + tfsec | CKV_AWS_16 / aws-rds-encrypt-instance-storage-data |
| 4 | EC2 EBS root volume not encrypted | Checkov + tfsec | CKV_AWS_8 / aws-ec2-enable-at-rest-encryption |
| 5 | IMDSv1 enabled on EC2 (SSRF risk) | Checkov + tfsec | CKV_AWS_79 / aws-ec2-enforce-http-token-imds |
| 6 | RDS no deletion protection | Checkov | CKV_AWS_293 |
| 7 | RDS no Multi-AZ | Checkov | CKV_AWS_157 |
| 8 | RDS no IAM authentication | Checkov | CKV_AWS_161 |
| 9 | EC2 detailed monitoring disabled | Checkov | CKV_AWS_126 |

> **Why IMDSv1 matters:** IMDSv1 was the attack vector in the 2019 Capital One breach — 100 million customer records exposed and an $80M fine. IMDSv2 with `http_tokens = "required"` prevents this class of SSRF attack entirely.

### Medium Issues (Original `main.tf`)

| # | Issue | Tool | Check ID |
|---|-------|------|----------|
| 1 | S3 no access logging | tfsec | aws-s3-enable-bucket-logging |
| 2 | S3 no versioning | tfsec | aws-s3-enable-versioning |
| 3 | VPC flow logs disabled | tfsec | aws-ec2-require-vpc-flow-logs-for-all-vpcs |
| 4 | RDS no CloudWatch logs | Checkov | CKV_AWS_129 |
| 5 | RDS no auto minor upgrades | Checkov | CKV_AWS_226 |
| 6 | Missing security group rule description | Checkov | CKV_AWS_23 |

### OPA Custom Policy Violations (23 total)

All resources in the original `main.tf` were missing required business tags. Without consistent tagging, cost attribution is impossible and incident response is slower.

| Resource | Missing: Environment | Missing: Owner | Missing: CostCenter |
|----------|---------------------|----------------|---------------------|
| `aws_db_instance.main` | ❌ | ❌ | ❌ |
| `aws_db_subnet_group.main` | ❌ | ❌ | ❌ |
| `aws_instance.app_server` | ❌ | ❌ | ❌ |
| `aws_s3_bucket.data_bucket` | ✅ | ❌ | ❌ |
| `aws_security_group.app_sg` | ❌ | ❌ | ❌ |
| `aws_subnet.private` | ❌ | ❌ | ❌ |
| `aws_subnet.private_2` | ❌ | ❌ | ❌ |
| `aws_vpc.main` | ❌ | ❌ | ❌ |

## Remediation Impact

| | Before (main.tf) | After (modules/) |
|---|---|---|
| Checkov failures | 19 | 2 |
| tfsec failures | 19 | 1 |
| Critical issues | 2 | 0 |
| OPA violations | 23 | 0 |
| **Risk reduction** | | **89–95%** |

---

## Secure Module Design

### S3 Module (`terraform/modules/s3/`)

Every bucket created with this module automatically enforces:

- ✅ KMS server-side encryption (`sse_algorithm = "aws:kms"`)
- ✅ All 4 public access block settings set to `true`
- ✅ Versioning enabled (`status = "Enabled"`)
- ✅ Access logging to dedicated log bucket
- ✅ Lifecycle rules (Standard-IA at 90 days, Glacier at 180 days)
- ✅ `Owner`, `Environment`, and `CostCenter` tags required as mandatory inputs

### EC2 Module (`terraform/modules/ec2/`)

Every instance created with this module automatically enforces:

- ✅ IMDSv2 required (`http_tokens = "required"`, `http_put_response_hop_limit = 1`)
- ✅ EBS root volume encrypted with KMS CMK (`encrypted = true`)
- ✅ Detailed CloudWatch monitoring (`monitoring = true`)
- ✅ No public IP address (`associate_public_ip_address = false`)
- ✅ t2 instance family blocked via Terraform input validation
- ✅ `Owner`, `Environment`, and `CostCenter` tags required as mandatory inputs

---

## OPA Policies

### `required_tags.rego`
Denies any resource missing `Environment`, `Owner`, or `CostCenter` tags. Warns if the Environment value is not one of `production`, `staging`, or `development`.

### `ec2_instance_types.rego`
Denies t2 family instances in production environments. Warns about micro-sized instances in production.

### `s3_versioning.rego`
Denies production S3 buckets without versioning enabled. Warns about any S3 bucket missing lifecycle rules.

> **Note:** OPA policies were updated from legacy Rego syntax to modern OPA v0.60+ syntax using `contains` and `if` keywords.

---

## Getting Started

### Prerequisites

```bash
# Checkov (Python)
pip install checkov

# tfsec and OPA (macOS)
brew install tfsec
brew install opa
brew install terraform
```

### Running All Scans

```bash
# Clone
git clone https://github.com/YOUR_USERNAME/terraform-security-project.git
cd terraform-security-project

# Checkov — original insecure config
checkov -d terraform/

# Checkov — secure modules
checkov -d terraform/modules/

# tfsec — original insecure config
tfsec terraform/

# tfsec — secure modules
tfsec terraform/modules/

# Terraform plan (requires AWS credentials via aws configure)
cd terraform
terraform init
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
cd ..

# OPA — evaluate all policies
opa eval --format pretty \
  --data policies/opa/ \
  --input terraform/tfplan.json \
  "data.terraform"
```

---

## Compliance Documentation

| Document | Description |
|----------|-------------|
| [`docs/SOC2_CONTROL_MAPPING.md`](docs/SOC2_CONTROL_MAPPING.md) | Full SOC 2 TSC mapping — CC6, CC7, CC8, CC9 |
| [`docs/SECURITY_REPORT.md`](docs/SECURITY_REPORT.md) | Complete security assessment with all findings and remediation status |
| [`security-findings.md`](security-findings.md) | Consolidated findings from Checkov and tfsec with fix code examples |

---

## Skills Demonstrated

- **IaC Security:** Static analysis of Terraform using Checkov and tfsec
- **Policy as Code:** Custom Rego policies in OPA enforcing business-specific rules
- **Threat Modelling:** Identifying real attack vectors (SSRF via IMDSv1, data exfiltration, brute force SSH)
- **Remediation:** Reducing security failures from 19 to 2 through hardened reusable modules
- **Compliance:** SOC 2 control mapping with evidence collection
- **Defence in Depth:** Three independent tools each catching different issue classes
- **Secret Management:** Preventing hardcoded credentials; tfplan.json gitignored

---

## About

*All vulnerabilities in `main.tf` are intentional for educational demonstration. The secure modules in `terraform/modules/` represent production-ready hardened patterns.*
