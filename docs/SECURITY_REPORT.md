# QuantumTrade IaC Security Assessment Report

**Date:** 2026-04-24  
**Assessor:** Aurelien Kumarathas  
**Scope:** Terraform infrastructure code — `terraform/` directory  
**Tools:** Checkov v3.2.510 | tfsec v1.28.11 | OPA v0.63.0  
**Terraform Version:** 1.6.6 | AWS Provider: ~> 5.0  
**Region:** eu-west-2 (London)

---

## Executive Summary

This report presents findings from automated static analysis security scanning of QuantumTrade's Infrastructure as Code (IaC). Three independent tools were run against the Terraform configuration to demonstrate defence-in-depth scanning. The original `main.tf` on the `test-security-scan` branch was intentionally written with security misconfigurations to demonstrate what real-world insecure infrastructure looks like. Hardened reusable modules were then built to remediate all findings, and the `main` branch now uses these modules exclusively.

### Risk Summary — Original `main.tf` (`test-security-scan` branch)

| Severity | Checkov | tfsec | Total | Status |
|----------|---------|-------|-------|--------|
| CRITICAL | 0 | 2 | 2 | ✅ Remediated |
| HIGH | 9 | 9 | 13 (unique) | ✅ Remediated |
| MEDIUM | 6 | 6 | 8 (unique) | ✅ Remediated |
| LOW | 4 | 2 | 4 (unique) | ✅ Remediated |
| **Total** | **19** | **19** | **27 unique** | |

### Risk Summary — Hardened Modules (`main` branch)

| Severity | Checkov | tfsec | Status |
|----------|---------|-------|--------|
| CRITICAL | 0 | 0 | ✅ Resolved |
| HIGH | 0 | 0 | ✅ Resolved |
| MEDIUM | 0 | 0 | ✅ Resolved |
| LOW | 1 | 0 | 📝 Accepted — documented below |
| **Total** | **1** | **0** | **95% reduction from original** |

### OPA Custom Policy Results — `main` branch

| Policy | Violations | Detail |
|--------|-----------|--------|
| `required_tags` | 0 | All resources have Environment, Owner, CostCenter |
| `ec2_instance_types` | 0 | t3.medium is in approved instance family |
| `s3_versioning` | 0 | Versioning enabled on all production buckets |

---

## Findings — Original `main.tf` (`test-security-scan` branch)

### CRITICAL Findings (2)

#### CRIT-01: SSH Access Open to Entire Internet
- **Severity:** CRITICAL
- **Resource:** `aws_security_group.app_sg`
- **Checkov:** CKV_AWS_24 — FAILED
- **tfsec:** aws-ec2-no-public-ingress-sgr — CRITICAL
- **Issue:** `cidr_blocks = ["0.0.0.0/0"]` on port 22 allows SSH from any IP globally
- **Risk:** Any attacker can attempt brute-force or credential stuffing against the instance
- **Real-world Impact:** Exposed SSH is one of the most common initial access vectors for ransomware groups
- **Resolution:** Removed all ingress rules — access managed via AWS Systems Manager Session Manager
- **Status:** ✅ Resolved — secure `aws_security_group.app_sg` in `main` has zero ingress rules

#### CRIT-02: Unrestricted Outbound Traffic
- **Severity:** CRITICAL
- **Resource:** `aws_security_group.app_sg`
- **Checkov:** CKV_AWS_382 — FAILED
- **tfsec:** aws-ec2-no-public-egress-sgr — CRITICAL
- **Issue:** `protocol = "-1"` and `cidr_blocks = ["0.0.0.0/0"]` allows all outbound traffic on all ports
- **Risk:** Compromised instance can exfiltrate data or beacon to command-and-control servers
- **Resolution:** Egress locked to HTTPS (443) only for AWS API calls
- **Status:** ✅ Resolved

---

### HIGH Findings (13 unique)

#### HIGH-01: S3 Bucket No Encryption
- **Severity:** HIGH
- **Resource:** `aws_s3_bucket.data_bucket`
- **Checkov:** CKV_AWS_19 — FAILED
- **tfsec:** aws-s3-enable-bucket-encryption — HIGH
- **Issue:** No server-side encryption on S3 bucket storing financial transaction data
- **Risk:** Objects readable if bucket policy misconfiguration occurs
- **Resolution:** `aws_s3_bucket_server_side_encryption_configuration` with `sse_algorithm = "aws:kms"` enforced in S3 module
- **Evidence:** `terraform/modules/s3/main.tf`
- **Status:** ✅ Resolved

#### HIGH-02: S3 Public Access Blocks All Disabled
- **Severity:** HIGH
- **Resource:** `aws_s3_bucket_public_access_block.data_bucket_pab`
- **Checkov:** CKV_AWS_53, CKV_AWS_54, CKV_AWS_55, CKV_AWS_56 — ALL FAILED
- **tfsec:** aws-s3-block-public-acls, aws-s3-block-public-policy, aws-s3-ignore-public-acls, aws-s3-no-public-buckets — ALL HIGH
- **Issue:** All four public access block settings explicitly set to `false`
- **Risk:** Any IAM misconfiguration could expose bucket objects publicly
- **Resolution:** All four settings hardcoded to `true` in secure S3 module — cannot be overridden by callers
- **Evidence:** `terraform/modules/s3/main.tf`
- **Status:** ✅ Resolved — all four Checkov checks now PASSING

#### HIGH-03: RDS Storage Not Encrypted
- **Severity:** HIGH
- **Resource:** `aws_db_instance.main`
- **Checkov:** CKV_AWS_16 — FAILED
- **tfsec:** aws-rds-encrypt-instance-storage-data — HIGH
- **Issue:** `storage_encrypted = false` — PostgreSQL database containing transaction data stored in plaintext
- **Risk:** Database files readable if underlying EBS storage is accessed
- **Resolution:** `storage_encrypted = true` with KMS CMK (`aws_kms_key.main`)
- **Status:** ✅ Resolved in `terraform/main.tf`

#### HIGH-04: EC2 Root Volume Not Encrypted
- **Severity:** HIGH
- **Resource:** `aws_instance.app_server`
- **Checkov:** CKV_AWS_8 — FAILED
- **tfsec:** aws-ec2-enable-at-rest-encryption — HIGH
- **Issue:** `encrypted = false` in root_block_device
- **Resolution:** `encrypted = true` with KMS CMK enforced in EC2 module
- **Evidence:** `terraform/modules/ec2/main.tf`
- **Status:** ✅ Resolved

#### HIGH-05: IMDSv1 Enabled on EC2 (SSRF Vulnerability)
- **Severity:** HIGH
- **Resource:** `aws_instance.app_server`
- **Checkov:** CKV_AWS_79 — FAILED
- **tfsec:** aws-ec2-enforce-http-token-imds — HIGH
- **Issue:** IMDSv1 allows unauthenticated metadata retrieval — exploitable via SSRF attacks
- **Real-world Impact:** IMDSv1 was the attack vector in the 2019 Capital One breach ($80M fine, 100M customer records exposed)
- **Resolution:** `metadata_options { http_tokens = "required", http_put_response_hop_limit = 1 }` enforced in EC2 module
- **Evidence:** `terraform/modules/ec2/main.tf`
- **Status:** ✅ Resolved — CKV_AWS_79 now PASSING

#### HIGH-06: RDS No IAM Authentication
- **Severity:** HIGH
- **Resource:** `aws_db_instance.main`
- **Checkov:** CKV_AWS_161 — FAILED
- **Issue:** Database only accepts username/password authentication — no short-lived credential rotation
- **Resolution:** `iam_database_authentication_enabled = true`
- **Status:** ✅ Resolved in `terraform/main.tf`

#### HIGH-07: RDS No Deletion Protection
- **Severity:** HIGH
- **Resource:** `aws_db_instance.main`
- **Checkov:** CKV_AWS_293 — FAILED
- **Issue:** Database can be accidentally or maliciously deleted without safeguard
- **Resolution:** `deletion_protection = true`
- **Status:** ✅ Resolved in `terraform/main.tf`

#### HIGH-08: RDS No Multi-AZ
- **Severity:** HIGH
- **Resource:** `aws_db_instance.main`
- **Checkov:** CKV_AWS_157 — FAILED
- **Issue:** Single availability zone — no automatic failover for a production financial database
- **Resolution:** `multi_az = true`
- **Status:** ✅ Resolved in `terraform/main.tf`

---

### MEDIUM Findings (8 unique)

#### MED-01: S3 No Access Logging
- **tfsec:** aws-s3-enable-bucket-logging — MEDIUM
- **Issue:** No audit trail of object access
- **Resolution:** `aws_s3_bucket_logging` targeting dedicated `quantumtrade-logs-production` bucket
- **Status:** ✅ Resolved in S3 module

#### MED-02: S3 No Versioning
- **tfsec:** aws-s3-enable-versioning — MEDIUM
- **Issue:** Deleted or overwritten objects unrecoverable
- **Resolution:** `aws_s3_bucket_versioning` with `status = "Enabled"`
- **Status:** ✅ Resolved in S3 module

#### MED-03: VPC Flow Logs Disabled
- **tfsec:** aws-ec2-require-vpc-flow-logs-for-all-vpcs — MEDIUM
- **Issue:** No network traffic visibility — cannot investigate security incidents or detect lateral movement
- **Resolution:** `aws_flow_log` with CloudWatch Logs destination and 90-day retention
- **Status:** ✅ Resolved in `terraform/main.tf`

#### MED-04: RDS No CloudWatch Logs
- **Checkov:** CKV_AWS_129 — FAILED
- **Issue:** No PostgreSQL logs exported — no audit trail for database queries
- **Resolution:** `enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]`
- **Status:** ✅ Resolved in `terraform/main.tf`

#### MED-05: RDS No Auto Minor Upgrades
- **Checkov:** CKV_AWS_226 — FAILED
- **Issue:** Security patches not automatically applied
- **Resolution:** `auto_minor_version_upgrade = true`
- **Status:** ✅ Resolved in `terraform/main.tf`

#### MED-06: Missing Security Group Rule Description
- **Checkov:** CKV_AWS_23 — FAILED
- **Issue:** Egress rule has no description — poor auditability
- **Resolution:** `description = "HTTPS outbound for AWS API calls"` added
- **Status:** ✅ Resolved in `terraform/main.tf`

---

### LOW Findings

#### LOW-01: EC2 Not EBS Optimised (False Positive)
- **Checkov:** CKV_AWS_135
- **Note:** `t3.medium` has EBS optimisation enabled by default — Checkov flag is a false positive for this instance type. Accepted and documented in `.checkov.yaml`.
- **Status:** 📝 Accepted — documented false positive

#### ~~LOW-02: S3 No Abort Incomplete Multipart Upload Rule~~ ✅ Resolved
- **Checkov:** CKV_AWS_300
- **Resolution:** `abort_incomplete_multipart_upload { days_after_initiation = 7 }` block present in the S3 module lifecycle configuration (`terraform/modules/s3/main.tf`). CKV_AWS_300 passes when scanning the module directly.
- **Status:** ✅ Resolved

---

## OPA Custom Policy Findings — `test-security-scan` Branch

### Tag Compliance Violations (23 total)

Every resource in the original `main.tf` was missing required business tags, making cost attribution and incident response harder:

| Resource | Environment | Owner | CostCenter |
|----------|-------------|-------|------------|
| `aws_db_instance.main` | ❌ | ❌ | ❌ |
| `aws_db_subnet_group.main` | ❌ | ❌ | ❌ |
| `aws_instance.app_server` | ❌ | ❌ | ❌ |
| `aws_s3_bucket.data_bucket` | ✅ | ❌ | ❌ |
| `aws_security_group.app_sg` | ❌ | ❌ | ❌ |
| `aws_subnet.private` | ❌ | ❌ | ❌ |
| `aws_subnet.private_2` | ❌ | ❌ | ❌ |
| `aws_vpc.main` | ❌ | ❌ | ❌ |

**Remediation:** Secure modules require `owner` and `cost_center` as mandatory input variables — tags cannot be omitted by callers. All 23 violations resolved on `main`.

---

## Final Remediation Summary

| Control | Before | After |
|---------|--------|-------|
| S3 encryption | None | KMS (`aws:kms`) + CMK |
| S3 public access | All `false` | All `true` — hardcoded in module |
| S3 versioning | Disabled | Enabled |
| S3 access logging | None | Dedicated log bucket |
| S3 lifecycle | None | Standard-IA (90d), Glacier (180d), abort multipart (7d) |
| EC2 EBS encryption | `false` | `true` + KMS CMK |
| EC2 IMDSv2 | Not enforced | `http_tokens = required` |
| EC2 monitoring | Disabled | Enabled |
| EC2 public IP | Assigned | Disabled |
| RDS encryption | `false` | `true` + KMS CMK |
| RDS deletion protection | Disabled | Enabled |
| RDS Multi-AZ | Disabled | Enabled |
| RDS IAM auth | Disabled | Enabled |
| RDS CloudWatch logs | None | postgresql + upgrade |
| VPC default SG | Unrestricted | All traffic denied (`aws_default_security_group`) |
| VPC flow logs | Disabled | CloudWatch Logs, 90d retention |
| KMS key policy | Default (implicit) | Explicit root account policy |
| SSH ingress | `0.0.0.0/0` | No ingress rules |
| Resource tagging | 0/3 tags | 3/3 required (enforced in modules) |
| **Checkov failures** | **19** | **1 (accepted false positive)** |
| **tfsec failures** | **19** | **0** |
| **OPA violations** | **23** | **0** |

---

## Compliance Mapping

See [`docs/SOC2_CONTROL_MAPPING.md`](SOC2_CONTROL_MAPPING.md) for full SOC 2 Trust Service Criteria mapping (CC6, CC7, CC8, CC9).

## Recommendations (Next Steps)

1. **Implement AWS Config rules** — continuous compliance monitoring post-deployment; detects drift if someone manually changes a security group via the console
2. **Enable GuardDuty** — runtime threat detection for EC2, S3, and RDS; catches anomalous API calls and credential misuse that static scanning cannot detect
3. **Add RDS Performance Insights** — `performance_insights_enabled = true`; resolves CKV_AWS_353, provides SOC 2 CC7.1 observability evidence
4. **Integrate Snyk or Trivy container scanning** — extends defence-in-depth to the workload layer; IaC hardening secures the infrastructure but not the container images running on it
5. **Formalise risk register** — document out-of-scope items (CKV_AWS_144 cross-region replication, CKV2_AWS_62 event notifications) with owner, acceptance date, and review cadence

---

## Appendix — Tool Versions

| Tool | Version |
|------|---------|
| Checkov | 3.2.510 |
| tfsec | 1.28.11 |
| OPA | 0.63.0 |
| Terraform | 1.6.6 |
| AWS Provider | hashicorp/aws ~> 5.0 |

---

*Assessment completed: 2026-04-24 | [terraform-security-project](https://github.com/AurelienKumarathas/terraform-security-project)*
