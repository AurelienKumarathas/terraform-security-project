# SOC 2 Control Mapping for QuantumTrade Infrastructure
**Document Version:** 1.0  
**Date:** 2026-03-20  
**Author:** Aurelien Kumarathas  
**Project:** terraform-security-project  
**Tools Used:** Checkov v3.2.510 | tfsec v1.28.14 | OPA v0.71 | Terraform v1.14.4

---

## Executive Summary

This document maps the security controls implemented in the QuantumTrade AWS infrastructure to the SOC 2 Trust Service Criteria (TSC). All infrastructure is defined as code using Terraform and validated through three independent static analysis tools before deployment.

### Scan Results Summary

| Tool | Passed | Failed | Status |
|------|--------|--------|--------|
| Checkov (original `main.tf`) | 14 | 19 | ❌ Pre-remediation |
| tfsec (original `main.tf`) | 9 | 19 | ❌ Pre-remediation |
| Checkov (secure modules) | 33 | 2 | ✅ Post-remediation |
| tfsec (secure modules) | 12 | 1 | ✅ Post-remediation |
| OPA custom policies | N/A | 23 tag violations | ✅ Identified & documented |

Remediation reduced Checkov failures by **89%** (19 → 2) and tfsec failures by **95%** (19 → 1).

---

## Scope

### Infrastructure Components Assessed
| Resource | Terraform ID | Purpose |
|----------|-------------|---------|
| S3 Bucket | `aws_s3_bucket.data_bucket` | Transaction data storage |
| S3 Public Access Block | `aws_s3_bucket_public_access_block.data_bucket_pab` | Public access prevention |
| EC2 Instance | `aws_instance.app_server` | Application server |
| Security Group | `aws_security_group.app_sg` | Network access control |
| RDS PostgreSQL | `aws_db_instance.main` | Primary database (postgres v14) |
| VPC | `aws_vpc.main` | Network isolation (10.0.0.0/16) |
| Private Subnets | `aws_subnet.private`, `aws_subnet.private_2` | eu-west-2a, eu-west-2b |
| KMS Key | `aws_kms_key.main` | Encryption key management |

### AWS Region
- **Primary Region:** eu-west-2 (London)

---

## CC6: Logical and Physical Access Controls

### CC6.1 — Security Software and Infrastructure Configurations

#### S3 Encryption at Rest
| Item | Detail |
|------|--------|
| **Control** | All S3 data encrypted using AWS KMS |
| **Implementation** | `aws_s3_bucket_server_side_encryption_configuration` with `sse_algorithm = "aws:kms"` |
| **Module** | `terraform/modules/s3/main.tf` lines 48-57 |
| **Checkov** | CKV_AWS_19 — ✅ PASSED (post-remediation) |
| **tfsec** | aws-s3-enable-bucket-encryption — ✅ PASSED (post-remediation) |
| **Pre-remediation State** | `storage_encrypted = false` on both S3 and RDS |
| **SOC 2 Criteria** | Encryption of data at rest to prevent unauthorised access |

#### RDS Encryption at Rest
| Item | Detail |
|------|--------|
| **Control** | RDS PostgreSQL storage encrypted |
| **Implementation** | `storage_encrypted = true` with KMS CMK |
| **File** | `terraform/main.tf` line 123 |
| **Checkov** | CKV_AWS_16 — ❌ FAILED (original), documented for remediation |
| **tfsec** | aws-rds-encrypt-instance-storage-data — ❌ FAILED (original) |
| **Pre-remediation State** | `storage_encrypted = false` — data readable if storage compromised |
| **SOC 2 Criteria** | Protection of sensitive financial transaction data |

#### EC2 EBS Volume Encryption
| Item | Detail |
|------|--------|
| **Control** | Root EBS volume encrypted with KMS CMK |
| **Implementation** | `encrypted = true`, `kms_key_id = var.kms_key_id` in root_block_device |
| **Module** | `terraform/modules/ec2/main.tf` |
| **Checkov** | CKV_AWS_8 — ✅ PASSED (post-remediation) |
| **tfsec** | aws-ec2-enable-at-rest-encryption — ✅ PASSED (post-remediation) |
| **Pre-remediation State** | `encrypted = false` on root_block_device |

#### KMS Key Management
| Item | Detail |
|------|--------|
| **Control** | Customer-managed KMS keys with rotation enabled |
| **Implementation** | `enable_key_rotation = true`, `deletion_window_in_days = 7` |
| **File** | `terraform/main_secure.tf` lines 57-66 |
| **Checkov** | CKV_AWS_7 — ✅ PASSED, CKV_AWS_227 — ✅ PASSED, CKV_AWS_33 — ✅ PASSED |

---

### CC6.6 — System Boundary Protection

#### S3 Public Access Blocks
| Item | Detail |
|------|--------|
| **Control** | All four S3 public access block settings enforced |
| **Implementation** | `block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets` all set to `true` |
| **Module** | `terraform/modules/s3/main.tf` lines 60-67 |
| **Checkov** | CKV_AWS_53, CKV_AWS_54, CKV_AWS_55, CKV_AWS_56 — ✅ ALL PASSED (post-remediation) |
| **tfsec** | aws-s3-block-public-acls, aws-s3-block-public-policy, aws-s3-ignore-public-acls, aws-s3-no-public-buckets — ✅ ALL PASSED |
| **Pre-remediation State** | All four settings were `false` — bucket objects fully exposed |

#### Security Group — Ingress Restrictions
| Item | Detail |
|------|--------|
| **Control** | No inbound access from 0.0.0.0/0 on sensitive ports |
| **Implementation** | SSH (port 22) restricted; no RDP (3389); no port 80 from internet |
| **File** | `terraform/main.tf` lines 39-64 |
| **Checkov** | CKV_AWS_24 — ❌ FAILED (SSH open), CKV_AWS_25 — ✅ PASSED (no RDP), CKV_AWS_260 — ✅ PASSED (no port 80) |
| **tfsec** | aws-ec2-no-public-ingress-sgr — ❌ CRITICAL (SSH open to 0.0.0.0/0) |
| **Risk** | CRITICAL — SSH brute force attack vector open to entire internet |
| **Remediation** | Restrict `cidr_blocks` to specific IP or VPN CIDR range |

#### Security Group — Egress Restrictions
| Item | Detail |
|------|--------|
| **Control** | Outbound traffic restricted to required destinations only |
| **File** | `terraform/main.tf` lines 53-59 |
| **Checkov** | CKV_AWS_382 — ❌ FAILED (all ports open outbound) |
| **tfsec** | aws-ec2-no-public-egress-sgr — ❌ CRITICAL (unrestricted egress) |
| **Risk** | CRITICAL — Compromised instance could exfiltrate data to any IP |
| **Remediation** | Restrict egress to HTTPS (443) and database port (5432) only |

#### EC2 Instance — No Public IP
| Item | Detail |
|------|--------|
| **Control** | EC2 instance not directly internet-accessible |
| **Implementation** | `associate_public_ip_address = false`, deployed in private subnet |
| **Checkov** | CKV_AWS_88 — ✅ PASSED |
| **SOC 2 Criteria** | Prevents direct internet access to application servers |

#### VPC Private Subnets
| Item | Detail |
|------|--------|
| **Control** | Subnets do not auto-assign public IPs |
| **Implementation** | `map_public_ip_on_launch = false` on both subnets |
| **Checkov** | CKV_AWS_130 — ✅ PASSED (both subnets) |

---

## CC7: System Operations

### CC7.1 — Detection and Monitoring of Security Events

#### EC2 Detailed Monitoring
| Item | Detail |
|------|--------|
| **Control** | CloudWatch detailed monitoring enabled on EC2 |
| **Implementation** | `monitoring = true` in EC2 module |
| **Module** | `terraform/modules/ec2/main.tf` |
| **Checkov** | CKV_AWS_126 — ✅ PASSED (post-remediation) |
| **Pre-remediation State** | Monitoring not enabled — no 1-minute metric granularity |

#### RDS Enhanced Monitoring
| Item | Detail |
|------|--------|
| **Control** | RDS enhanced monitoring and performance insights |
| **File** | `terraform/main.tf` lines 109-132 |
| **Checkov** | CKV_AWS_118 — ❌ FAILED, CKV_AWS_353 — ❌ FAILED |
| **tfsec** | aws-rds-enable-performance-insights — LOW |
| **Remediation** | Add `monitoring_interval = 60` and `performance_insights_enabled = true` |

#### S3 Access Logging
| Item | Detail |
|------|--------|
| **Control** | S3 bucket access logs recorded to dedicated log bucket |
| **Implementation** | `aws_s3_bucket_logging` resource in S3 module pointing to log bucket |
| **Module** | `terraform/modules/s3/main.tf` |
| **tfsec** | aws-s3-enable-bucket-logging — ✅ PASSED (post-remediation) |
| **Pre-remediation State** | No logging — no audit trail of bucket access |

#### VPC Flow Logs
| Item | Detail |
|------|--------|
| **Control** | Network traffic logged to CloudWatch |
| **File** | `terraform/main.tf` lines 88-96 |
| **tfsec** | aws-ec2-require-vpc-flow-logs-for-all-vpcs — ❌ MEDIUM |
| **Risk** | No network visibility — cannot investigate security incidents |
| **Remediation** | Add `aws_flow_log` resource for the VPC |

#### RDS Logs
| Item | Detail |
|------|--------|
| **Control** | PostgreSQL logs exported to CloudWatch |
| **Checkov** | CKV_AWS_129 — ❌ FAILED |
| **Remediation** | Add `enabled_cloudwatch_logs_exports = ["postgresql"]` |

---

### CC7.2 — Response to Security Incidents

#### IMDSv2 Enforcement (SSRF Protection)
| Item | Detail |
|------|--------|
| **Control** | EC2 Instance Metadata Service v2 required (prevents SSRF attacks) |
| **Implementation** | `http_tokens = "required"` in metadata_options block |
| **Module** | `terraform/modules/ec2/main.tf` lines 67-74 |
| **Checkov** | CKV_AWS_79 — ✅ PASSED (post-remediation) |
| **tfsec** | aws-ec2-enforce-http-token-imds — ✅ PASSED (post-remediation) |
| **Pre-remediation State** | IMDSv1 enabled — attackers could steal IAM credentials via SSRF |
| **Why Critical** | IMDSv1 was exploited in the 2019 Capital One breach ($80M fine) |

#### No Hardcoded Credentials
| Item | Detail |
|------|--------|
| **Control** | No AWS keys or secrets hardcoded in Terraform files |
| **Implementation** | Variables used for all secrets; secrets framework scan passed |
| **Checkov** | CKV_AWS_41 — ✅ PASSED, CKV_AWS_46 — ✅ PASSED |
| **Note** | DB password uses `var.db_password` — never hardcoded |

---

## CC8: Change Management

### CC8.1 — Infrastructure Change Controls

#### Version Control
| Item | Detail |
|------|--------|
| **Control** | All infrastructure changes tracked in Git |
| **Implementation** | GitHub repository with full commit history |
| **Evidence** | Git log showing all changes with author, timestamp, description |

#### Automated Security Gates
| Item | Detail |
|------|--------|
| **Control** | Security scans run automatically on every code change |
| **Implementation** | GitHub Actions CI/CD pipeline |
| **Tools** | Checkov, tfsec, OPA all run as pipeline stages |
| **Effect** | Insecure code cannot be merged without addressing findings |

#### Terraform Plan Review
| Item | Detail |
|------|--------|
| **Control** | Infrastructure changes reviewed before apply |
| **Implementation** | `terraform plan` generates `tfplan.json` for review |
| **Evidence** | `terraform/tfplan.json` (gitignored — contains sensitive data) |

---

## CC9: Risk Mitigation

### OPA Custom Policy Findings

The OPA policy engine identified **23 tag compliance violations** across all resources, indicating missing required tags (`Environment`, `Owner`, `CostCenter`).

| Resource | Missing Tags |
|----------|-------------|
| `aws_db_instance.main` | Environment, Owner, CostCenter |
| `aws_db_subnet_group.main` | Environment, Owner, CostCenter |
| `aws_instance.app_server` | Environment, Owner, CostCenter |
| `aws_s3_bucket.data_bucket` | Owner, CostCenter |
| `aws_security_group.app_sg` | Environment, Owner, CostCenter |
| `aws_subnet.private` | Environment, Owner, CostCenter |
| `aws_subnet.private_2` | Environment, Owner, CostCenter |
| `aws_vpc.main` | Environment, Owner, CostCenter |

**Impact:** Without consistent tagging, cost attribution is impossible, ownership is unclear, and incident response is slower.  
**Remediation:** Secure modules enforce all three tags as required inputs.

---

## Accepted Risks

| Risk | Severity | Justification | Compensating Control | Review Date |
|------|----------|---------------|---------------------|-------------|
| SSH open to 0.0.0.0/0 in demo `main.tf` | CRITICAL | Intentionally insecure for demonstration purposes | Only in `main.tf` (insecure version), not in modules | N/A — demo only |
| RDS not encrypted in demo `main.tf` | HIGH | Intentionally insecure for demonstration purposes | Remediated in secure modules | N/A — demo only |
| S3 lifecycle missing abort rule | LOW | Minor compliance gap in module | Add `abort_incomplete_multipart_upload` block | Next sprint |
| EBS not optimised in EC2 module | LOW | `t3.medium` has EBS optimisation by default despite check | Instance type handles this natively | Next sprint |

---

## Remediation Summary

### Pre vs Post Remediation

| Finding | Pre-Remediation | Post-Remediation |
|---------|----------------|-----------------|
| S3 public access blocks | All `false` | All `true` |
| S3 encryption | None | KMS CMK (`aws:kms`) |
| S3 versioning | Disabled | Enabled |
| S3 access logging | Disabled | Enabled (log bucket) |
| EC2 EBS encryption | `false` | `true` with KMS |
| EC2 IMDSv2 | Not enforced | `http_tokens = required` |
| EC2 detailed monitoring | Disabled | `monitoring = true` |
| RDS encryption | `false` | `true` (documented) |
| Checkov failures | **19** | **2** |
| tfsec failures | **19** | **1** |

---

## Appendix A — Tool Versions

| Tool | Version |
|------|---------|
| Checkov | 3.2.510 |
| tfsec | 1.28.14 |
| OPA | 0.71 |
| Terraform | 1.14.4 |
| AWS Provider | 5.100.0 |

## Appendix B — Scan Evidence Files

| File | Contents |
|------|---------|
| `checkov-results.json` | Full Checkov scan of original `main.tf` |
| `tfsec-results.json` | Full tfsec scan of original `main.tf` |
| `tfsec-results.sarif` | SARIF format for GitHub Security tab |
| `checkov-modules-results.txt` | Checkov scan of secure modules |
| `tfsec-modules-results.txt` | tfsec scan of secure modules |
| `opa-results.json` | OPA custom policy evaluation results |

## Appendix C — CIS Benchmark Mappings

| CIS Control | Checkov Check | Status |
|-------------|--------------|--------|
| CIS 2.1.1 - S3 server-side encryption | CKV_AWS_19 | ✅ Remediated |
| CIS 2.1.2 - S3 block public access | CKV_AWS_53/54/55/56 | ✅ Remediated |
| CIS 2.3.1 - RDS encryption | CKV_AWS_16 | ⚠️ In original only |
| CIS 5.1 - No unrestricted SSH | CKV_AWS_24 | ⚠️ In original only |
| CIS 5.4 - No public EC2 instances | CKV_AWS_88 | ✅ Passing |

---

*Report generated: 2026-03-20 | terraform-security-project*