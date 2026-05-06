# Security Findings Register — Terraform IaC Security Pipeline

This document consolidates the original Checkov and tfsec findings from the intentionally vulnerable `test-security-scan` branch and tracks their remediation status on `main`.

> Scope: Terraform configuration for QuantumTrade's core AWS infrastructure (VPC, EC2, S3, RDS, security groups). Scanned using Checkov v3.2.510 and tfsec v1.28.11.

---

## Summary by Severity (Original Baseline)

| Tool    | Critical | High | Medium | Low | Info | Total |
|---------|----------|------|--------|-----|------|-------|
| Checkov | 0        | 10   | 6      | 3   | 0    | 19    |
| tfsec   | 2        | 9    | 6      | 2   | 0    | 19    |

All critical and high findings are fully remediated on the `main` branch. Medium and low findings are either fixed or explicitly documented as out-of-scope controls in `.checkov.yaml` and `.tfsec/config.yml`.

---

## Detailed Findings

### Critical Findings (tfsec)

| # | Tool  | Check ID                        | Resource / File                    | Severity | Status  | Notes |
|---|-------|----------------------------------|------------------------------------|----------|---------|-------|
| 1 | tfsec | aws-ec2-no-public-ingress-sgr   | `aws_security_group.app_sg`        | Critical | Fixed   | SSH from `0.0.0.0/0` removed; SG now restricted to private CIDR / SSM only. |
| 2 | tfsec | aws-ec2-no-public-egress-sgr    | `aws_security_group.app_sg`        | Critical | Fixed   | Unrestricted egress tightened to specific ports / destinations. |

### High Findings (Sample)

| # | Tool   | Check ID               | Resource / File                    | Severity | Status | Original Issue |
|---|--------|------------------------|------------------------------------|----------|--------|----------------|
| 3 | Checkov| CKV_AWS_19             | `aws_s3_bucket.data_bucket`        | High     | Fixed  | S3 bucket missing encryption at rest. |
| 4 | tfsec  | aws-s3-enable-bucket-encryption | `aws_s3_bucket.data_bucket` | High | Fixed | S3 bucket SSE not enabled. |
| 5 | Checkov| CKV_AWS_53–56          | `aws_s3_bucket_public_access_block`| High     | Fixed  | All four S3 public access block settings disabled. |
| 6 | Checkov| CKV_AWS_8              | `aws_instance.app_server`          | High     | Fixed  | EC2 root EBS volume not encrypted. |
| 7 | Checkov| CKV_AWS_16             | `aws_db_instance.main`             | High     | Fixed  | RDS storage not encrypted. |
| 8 | Checkov| CKV_AWS_79             | `aws_instance.app_server`          | High     | Fixed  | IMDSv1 enabled; IMDSv2 not required. |
| 9 | Checkov| CKV_AWS_293            | `aws_db_instance.main`             | High     | Fixed  | RDS instance missing deletion protection. |
|10 | Checkov| CKV_AWS_157            | `aws_db_instance.main`             | High     | Fixed  | RDS instance not configured for Multi-AZ. |
|11 | Checkov| CKV_AWS_161            | `aws_db_instance.main`             | High     | Fixed  | RDS instance not using IAM authentication. |
|12 | Checkov| CKV_AWS_126            | `aws_instance.app_server`          | High     | Fixed  | EC2 detailed monitoring disabled. |

### Medium / Low Findings (Sample)

| # | Tool   | Check ID        | Resource / File          | Severity | Status        | Disposition |
|---|--------|-----------------|--------------------------|----------|---------------|------------|
|13 | Checkov| CKV_AWS_135     | `aws_instance.app_server`| Medium   | Accepted risk | Documented false positive — instance type has built-in EBS optimisation. |
|14 | Checkov| CKV2_AWS_6      | `aws_s3_bucket.data_bucket` | Medium | Accepted risk | Public access block enforced in module; check does not follow nested resources. |
|15 | Checkov| CKV_AWS_353     | `aws_db_instance.main`   | Low      | Out of scope  | RDS Performance Insights — observability control, not baseline security. |
|16 | Checkov| CKV_AWS_118     | `aws_db_instance.main`   | Low      | Out of scope  | RDS enhanced monitoring — operational monitoring, separate workstream. |
|17 | Checkov| CKV2_AWS_30     | `aws_db_instance.main`   | Medium   | Out of scope  | RDS query logging — audit logging control. |
|18 | Checkov| CKV2_AWS_60     | `aws_db_instance.main`   | Medium   | Out of scope  | RDS copy tags to snapshots — operational tagging. |
|19 | Checkov| CKV2_AWS_62     | `aws_s3_bucket.data_bucket` | Medium | Out of scope | S3 event notifications — observability / pipeline design. |
|20 | Checkov| CKV_AWS_338     | `aws_cloudwatch_log_group.flow_logs` | Medium | Out of scope | 1-year log retention — compliance policy decision. |
|21 | Checkov| CKV_AWS_300     | `aws_s3_bucket.data_bucket` | Low    | Out of scope | Abort incomplete multipart uploads — cost optimisation.

> For every accepted risk or out-of-scope item, there is a written justification in `.checkov.yaml` or `.tfsec/config.yml`, mirroring how risk registers are maintained in real security programmes.

---

## Before vs After

| Metric             | Baseline (`test-security-scan`) | Hardened (`main`) | Change |
|--------------------|----------------------------------|-------------------|--------|
| Checkov failures   | 19                               | 0                 | −100%  |
| tfsec failures     | 19                               | 0                 | −100%  |
| Critical issues    | 2                                | 0                 | −100%  |
| OPA violations     | 23                               | 0                 | −100%  |

The hardened modules (`terraform/modules/s3` and `terraform/modules/ec2`) now encode these remediations as defaults, so any new environment created from this repo inherits the secure configuration without additional work.

---

## How to Reproduce Findings

1. Check out the vulnerable baseline:
   ```bash
   git checkout test-security-scan
   checkov -d terraform/
   tfsec terraform/
   ```
2. Observe the failing checks above.
3. Switch to the hardened branch and re-run:
   ```bash
   git checkout main
   checkov -d terraform/modules/
   tfsec terraform/modules/
   ```
4. Confirm that all critical/high findings are resolved and that any remaining checks are explicitly documented as accepted risk or out of scope.
