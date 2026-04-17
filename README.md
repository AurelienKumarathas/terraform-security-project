# Terraform IaC Security Pipeline — QuantumTrade

[![IaC Security Pipeline](https://github.com/AurelienKumarathas/terraform-security-project/actions/workflows/iac-security.yml/badge.svg)](https://github.com/AurelienKumarathas/terraform-security-project/actions/workflows/iac-security.yml)

![Checkov](https://img.shields.io/badge/Checkov-v3.2.510-brightgreen)
![tfsec](https://img.shields.io/badge/tfsec-v1.28.14-brightgreen)
![OPA](https://img.shields.io/badge/OPA-v0.63.0-brightgreen)
![Terraform](https://img.shields.io/badge/Terraform-v1.6.0-blue)
![AWS](https://img.shields.io/badge/AWS-eu--west--2-orange)

## Overview

This project demonstrates an enterprise-grade Infrastructure as Code (IaC) security pipeline for **QuantumTrade**, a fintech platform processing cryptocurrency transactions. It implements a defence-in-depth scanning approach using three independent tools — Checkov, tfsec, and OPA — to identify and block security misconfigurations before they ever reach AWS.

The pipeline runs automatically on every push and pull request via GitHub Actions. Findings are uploaded to the GitHub Security tab as SARIF so they're visible at the PR level, not buried in logs.

> **Branch strategy:**
> - [`test-security-scan`](https://github.com/AurelienKumarathas/terraform-security-project/tree/test-security-scan) — the intentionally vulnerable baseline. Run the tools here to reproduce every finding.
> - [`main`](https://github.com/AurelienKumarathas/terraform-security-project/tree/main) — the fully remediated, hardened state. This is the production-ready solution.

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

## Pipeline Architecture

```
 Push / Pull Request
        │
        ▼
┌───────────────────────────────────────────────────┐
│              GitHub Actions Pipeline               │
│                                                   │
│  ┌──────────┐  ┌──────────┐  ┌─────────────────┐ │
│  │ Checkov  │  │  tfsec   │  │  OPA (Rego)     │ │
│  │ 2,500+   │  │ AWS-spec │  │  Custom policy  │ │
│  │ CIS rules│  │ severity │  │  as code        │ │
│  └────┬─────┘  └────┬─────┘  └────────┬────────┘ │
│       │             │                  │          │
│       └─────────────┴──────────────────┘          │
│                      │                            │
│              ┌───────▼────────┐                   │
│              │ Terraform      │                   │
│              │ Validate + fmt │                   │
│              └───────┬────────┘                   │
│                      │                            │
│              ┌───────▼────────┐                   │
│              │ Security       │                   │
│              │ Summary        │                   │
│              └────────────────┘                   │
└───────────────────────────────────────────────────┘
        │                    │
        ▼                    ▼
 GitHub Security Tab    Pipeline blocks
 (SARIF findings)       on any failure
```

---

## Scan Results

### Vulnerable Baseline (`test-security-scan` branch)

| Tool | Passed | Failed | Critical |
|------|--------|--------|----------|
| Checkov v3.2.510 | 14 | 19 | 0 |
| tfsec v1.28.14 | 9 | 19 | 2 |
| OPA v0.63.0 | — | 23 tag violations | — |

### Remediated State (`main` branch)

| Tool | Passed | Failed | Improvement |
|------|--------|--------|-------------|
| Checkov | 33 | 2 | 89% reduction |
| tfsec | 12 | 1 | 95% reduction |
| OPA | 0 violations | — | 100% resolved |

---

## Repository Structure

```
terraform-security-project/
├── .github/
│   └── workflows/
│       └── iac-security.yml       # Full CI/CD pipeline definition
├── .checkov.yaml                  # Checkov configuration
├── .tfsec/                        # tfsec custom configuration
├── terraform/
│   ├── main.tf                    # Root module (references hardened modules)
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Key resource identifiers
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
└── SECURITY-FINDINGS.md          # Consolidated findings with fix examples
```

---

## Security Tools

### Checkov (Prisma Cloud) — v3.2.510
Static analysis against 2,500+ CIS Benchmark and compliance policies. Scans Terraform files without requiring AWS credentials or a live deployment. Results uploaded to GitHub Security tab as SARIF.

```bash
checkov -d terraform/
checkov -d terraform/modules/
```

### tfsec (Aqua Security) — v1.28.14
AWS-specific security rules with severity ratings (CRITICAL/HIGH/MEDIUM/LOW). Catches issues Checkov misses including VPC flow logs and unrestricted egress. Runs with a minimum severity threshold of HIGH in CI.

```bash
tfsec terraform/
tfsec terraform/ --minimum-severity HIGH
```

### OPA (Open Policy Agent) — v0.63.0
Custom Rego policies enforcing organisation-specific rules that no commercial tool knows — tagging standards, approved instance types, and S3 versioning requirements. Evaluates against the Terraform plan JSON so it catches dynamic values that static scanners miss.

```bash
opa eval --format pretty \
  --data policies/opa/ \
  --input terraform/tfplan.json \
  "data.terraform"
```

---

## Key Security Findings

### Critical Issues (Vulnerable Baseline)

| # | Issue | Tool | Check ID | Real-World Risk |
|---|-------|------|----------|-----------------|
| 1 | SSH open to `0.0.0.0/0` on port 22 | tfsec | aws-ec2-no-public-ingress-sgr | Full internet brute-force attack surface |
| 2 | Unrestricted egress all ports | tfsec | aws-ec2-no-public-egress-sgr | Compromised instance can exfiltrate data anywhere |

### High Issues (Vulnerable Baseline, Sample)

| # | Issue | Tool | Check ID |
|---|-------|------|----------|
| 1 | S3 bucket no encryption | Checkov + tfsec | CKV_AWS_19 / aws-s3-enable-bucket-encryption |
| 2 | All 4 S3 public access blocks disabled | Checkov | CKV_AWS_53-56 |
| 3 | RDS storage not encrypted | Checkov + tfsec | CKV_AWS_16 |
| 4 | EC2 EBS root volume not encrypted | Checkov + tfsec | CKV_AWS_8 |
| 5 | IMDSv1 enabled on EC2 | Checkov + tfsec | CKV_AWS_79 |
| 6 | RDS no deletion protection | Checkov | CKV_AWS_293 |
| 7 | RDS no Multi-AZ | Checkov | CKV_AWS_157 |
| 8 | RDS no IAM authentication | Checkov | CKV_AWS_161 |
| 9 | EC2 detailed monitoring disabled | Checkov | CKV_AWS_126 |

> **Why IMDSv1 matters:** IMDSv1 was the attack vector in the 2019 Capital One breach — 100 million customer records exposed via SSRF through the EC2 metadata endpoint, resulting in an $80M fine. IMDSv2 with `http_tokens = "required"` eliminates this attack class entirely.

### OPA Policy Violations (23 total on baseline)

Every resource in the vulnerable baseline was missing mandatory business tags, making cost attribution and incident response significantly harder.

| Resource | Environment | Owner | CostCenter |
|----------|-------------|-------|------------|
| `aws_db_instance.main` | ❌ | ❌ | ❌ |
| `aws_instance.app_server` | ❌ | ❌ | ❌ |
| `aws_s3_bucket.data_bucket` | ✅ | ❌ | ❌ |
| `aws_security_group.app_sg` | ❌ | ❌ | ❌ |
| `aws_vpc.main` | ❌ | ❌ | ❌ |

---

## Remediation

### Impact

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Checkov failures | 19 | 2 | −89% |
| tfsec failures | 19 | 1 | −95% |
| Critical issues | 2 | 0 | −100% |
| OPA violations | 23 | 0 | −100% |

### S3 Module (`terraform/modules/s3/`)

Every bucket created with this module enforces by default:

- ✅ KMS server-side encryption (`sse_algorithm = "aws:kms"`)
- ✅ All 4 public access block settings set to `true`
- ✅ Versioning enabled
- ✅ Access logging to dedicated log bucket
- ✅ Lifecycle rules (Standard-IA at 90 days, Glacier at 180 days)
- ✅ `Owner`, `Environment`, `CostCenter` tags required as module inputs

### EC2 Module (`terraform/modules/ec2/`)

Every instance created with this module enforces by default:

- ✅ IMDSv2 required (`http_tokens = "required"`, hop limit = 1)
- ✅ EBS root volume encrypted with KMS CMK
- ✅ Detailed CloudWatch monitoring enabled
- ✅ No public IP address
- ✅ t2 instance family blocked via Terraform input validation
- ✅ `Owner`, `Environment`, `CostCenter` tags required as module inputs

---

## OPA Policies

### `required_tags.rego`
Denies any resource missing `Environment`, `Owner`, or `CostCenter` tags. Warns if the Environment value is not one of `production`, `staging`, or `development`.

### `ec2_instance_types.rego`
Denies t2 family instances in production environments. Warns about micro-sized instances in production.

### `s3_versioning.rego`
Denies production S3 buckets without versioning enabled. Warns about any S3 bucket missing lifecycle rules.

Policies use modern OPA v0.60+ syntax (`contains`, `if` keywords) and are pinned to `v0.63.0` in CI for deterministic evaluation.

---

## Getting Started

### Prerequisites

```bash
pip install checkov
brew install tfsec opa terraform   # macOS
```

### Reproduce the Vulnerable Baseline

```bash
git clone https://github.com/AurelienKumarathas/terraform-security-project.git
cd terraform-security-project
git checkout test-security-scan

checkov -d terraform/
tfsec terraform/
```

### Run Against the Hardened Modules

```bash
git checkout main

checkov -d terraform/modules/
tfsec terraform/modules/

# OPA — requires a tfplan.json (see below)
cd terraform
terraform init -backend=false
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
cd ..

opa eval --format pretty \
  --data policies/opa/ \
  --input terraform/tfplan.json \
  "data.terraform"
```

---

## Compliance Documentation

| Document | Description |
|----------|-------------|
| [`docs/SOC2_CONTROL_MAPPING.md`](docs/SOC2_CONTROL_MAPPING.md) | SOC 2 TSC mapping — CC6, CC7, CC8, CC9 with evidence |
| [`docs/SECURITY_REPORT.md`](docs/SECURITY_REPORT.md) | Full security assessment with all findings and remediation status |
| [`SECURITY-FINDINGS.md`](SECURITY-FINDINGS.md) | Consolidated findings from Checkov and tfsec with fix code examples |

---

## Skills Demonstrated

- **IaC Security** — Static analysis of Terraform using Checkov and tfsec across 2,500+ rules
- **Policy as Code** — Custom Rego policies in OPA enforcing business-specific rules no commercial tool covers
- **Threat Modelling** — Identifying real attack vectors: SSRF via IMDSv1, data exfiltration via unrestricted egress, brute-force SSH
- **Secure Module Design** — Reusable hardened Terraform modules that make the secure path the default path
- **CI/CD Integration** — GitHub Actions pipeline with SARIF upload to GitHub Security tab, blocking on failure
- **Compliance Mapping** — SOC 2 Trust Service Criteria mapped to specific scan findings with evidence
- **Defence in Depth** — Three independent tools each catching different issue classes; no single point of failure in the scanning strategy

---

*All vulnerabilities on the `test-security-scan` branch are intentional for demonstration. The hardened modules on `main` represent production-ready patterns.*
