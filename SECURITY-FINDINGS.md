# Security Findings — Terraform Infrastructure Audit

Manual code review of Terraform configuration against CIS AWS Benchmark.

> This manual review demonstrates the value of automated scanning — each of these findings
> would be caught instantly by Checkov or Trivy IaC, eliminating hours of manual effort.

---

## Findings Summary

| Resource | Issue | Severity | CIS Benchmark |
|---|---|---|---|
| S3 Bucket | No encryption at rest | HIGH | 2.1.1 |
| S3 Bucket | Public access not blocked | CRITICAL | 2.1.2 |
| Security Group | SSH open to 0.0.0.0/0 | HIGH | 5.2 |
| EC2 | Root volume unencrypted | HIGH | 2.2.1 |
| EC2 | IMDSv2 not required | MEDIUM | 5.7 |
| RDS | Storage not encrypted | HIGH | 2.3.1 |
| RDS | No deletion protection | MEDIUM | — |
| VPC | No flow logs enabled | MEDIUM | 3.9 |

---

## Detailed Findings

### 🔴 CRITICAL

#### S3 — Public Access Not Blocked
- **CIS Benchmark**: 2.1.2
- **Risk**: Any data stored in this bucket is publicly readable — a common cause of data breaches
- **Fix**: Set `block_public_acls`, `block_public_policy`, `ignore_public_acls` and `restrict_public_buckets` to `true`

---

### 🟠 HIGH

#### S3 — No Encryption at Rest
- **CIS Benchmark**: 2.1.1
- **Risk**: Data stored unencrypted — violates compliance requirements (PCI-DSS, HIPAA, GDPR)
- **Fix**: Add `server_side_encryption_configuration` block with AES-256 or aws:kms

#### Security Group — SSH Open to 0.0.0.0/0
- **CIS Benchmark**: 5.2
- **Risk**: Exposes SSH port 22 to the entire internet — brute force and credential attacks
- **Fix**: Restrict ingress to known IP ranges or use AWS Systems Manager Session Manager instead

#### EC2 — Root Volume Unencrypted
- **CIS Benchmark**: 2.2.1
- **Risk**: If EBS snapshot is exfiltrated, data is readable in plaintext
- **Fix**: Set `encrypted = true` in `root_block_device`

#### RDS — Storage Not Encrypted
- **CIS Benchmark**: 2.3.1
- **Risk**: Database contents unprotected at rest — compliance violation
- **Fix**: Set `storage_encrypted = true` in RDS resource

---

### 🟡 MEDIUM

#### EC2 — IMDSv2 Not Required
- **CIS Benchmark**: 5.7
- **Risk**: IMDSv1 is vulnerable to SSRF attacks — used in Capital One breach (2019)
- **Fix**: Set `http_tokens = "required"` in `metadata_options`

#### RDS — No Deletion Protection
- **Risk**: Database can be accidentally or maliciously deleted with no safeguard
- **Fix**: Set `deletion_protection = true`

#### VPC — No Flow Logs
- **CIS Benchmark**: 3.9
- **Risk**: No network traffic visibility — blind to lateral movement or data exfiltration
- **Fix**: Enable `aws_flow_log` resource attached to the VPC

---

## Why Automate This?

This manual review took significant time and is error-prone. The same findings are caught
automatically by:

| Tool | What it catches |
|---|---|
| **Checkov** | All of the above in seconds |
| **Trivy IaC** | Same findings + additional misconfigurations |
| **OPA/Rego** | Custom policy enforcement at plan time |

See `policies/checkov` and `policies/opa` for the automated equivalents.
