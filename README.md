# Terraform IaC Security Pipeline — QuantumTrade (Vulnerable Baseline)

> ⚠️ **This branch contains intentional security misconfigurations for demonstration purposes.**
> See the [`main`](https://github.com/AurelienKumarathas/terraform-security-project/tree/main) branch for the fully remediated, hardened infrastructure.

---

## Purpose

This branch represents the **before** state of the QuantumTrade AWS infrastructure — the raw, misconfigured Terraform that triggered the security review. It exists so you can run the scanning tools yourself and reproduce the findings documented in the main branch.

## What's Deliberately Broken

| Resource | Misconfiguration | Real-World Risk |
|---|---|---|
| `aws_security_group` | SSH open to `0.0.0.0/0` | Brute-force attack surface on port 22 |
| `aws_security_group` | Unrestricted egress all ports | Compromised instance can exfiltrate to anywhere |
| `aws_s3_bucket` | No encryption, public access blocks all `false` | Data exposed to internet; Capital One-style leak vector |
| `aws_instance` | IMDSv1 enabled, EBS unencrypted | SSRF → credential theft via metadata endpoint |
| `aws_db_instance` | No encryption, no deletion protection, no Multi-AZ | Data loss on instance failure; storage readable at rest |
| `aws_vpc` | Flow logs disabled | Zero network visibility for incident response |

## Reproduce the Scan Results

```bash
git clone https://github.com/AurelienKumarathas/terraform-security-project.git
cd terraform-security-project
git checkout test-security-scan

# Checkov
checkov -d terraform/

# tfsec
tfsec terraform/

# OPA (after generating tfplan.json)
cd terraform && terraform init && terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json && cd ..
opa eval --format pretty --data policies/opa/ --input terraform/tfplan.json "data.terraform"
```

## Branch Comparison

| | `test-security-scan` (this branch) | `main` |
|---|---|---|
| Checkov failures | 19 | 2 |
| tfsec failures | 19 | 1 |
| Critical issues | 2 | 0 |
| OPA violations | 23 | 0 |
| Risk level | 🔴 High | 🟢 Low |

---

*All misconfigurations are intentional. Do not deploy this branch to a real AWS environment.*
