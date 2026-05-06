# Architecture — QuantumTrade IaC Security Pipeline

**Project:** terraform-security-project  
**Author:** Aurelien Kumarathas  
**Region:** AWS eu-west-2 (London)  
**Last Updated:** 2026-05-06

---

## Overview

This repository provisions a hardened AWS infrastructure for **QuantumTrade**, a fintech platform processing cryptocurrency transactions. All infrastructure is defined as Terraform and validated through three independent security scanning tools before any change can reach the cloud.

The design follows a **defence-in-depth** approach: every layer — network, compute, storage, database, and CI/CD — has independent security controls. No single misconfiguration can expose the system.

---

## Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS eu-west-2 (London)                      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   VPC 10.0.0.0/16                        │  │
│  │                                                          │  │
│  │  ┌─────────────────────┐  ┌─────────────────────────┐   │  │
│  │  │  Private Subnet A   │  │   Private Subnet B       │   │  │
│  │  │  10.0.1.0/24        │  │   10.0.2.0/24            │   │  │
│  │  │  eu-west-2a         │  │   eu-west-2b             │   │  │
│  │  │                     │  │                          │   │  │
│  │  │  ┌───────────────┐  │  │  ┌───────────────────┐   │   │  │
│  │  │  │  EC2 (app)    │  │  │  │  RDS PostgreSQL   │   │   │  │
│  │  │  │  t3.medium    │  │  │  │  db.t3.medium     │   │   │  │
│  │  │  │  No public IP │  │  │  │  Multi-AZ standby │   │   │  │
│  │  │  │  IMDSv2 only  │  │  │  │  Not public       │   │   │  │
│  │  │  │  SSM access   │  │  │  └───────────────────┘   │   │  │
│  │  │  └───────────────┘  │  │                          │   │  │
│  │  └─────────────────────┘  └─────────────────────────┘   │  │
│  │                                                          │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │  Security Group: quantumtrade-app-sg              │   │  │
│  │  │  Ingress: none (SSM only)                         │   │  │
│  │  │  Egress: HTTPS 443 outbound only                  │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  │                                                          │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │  Default SG: all traffic denied (CKV2_AWS_12)    │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  │                                                          │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │  VPC Flow Logs → CloudWatch (90-day retention)   │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────┐  ┌─────────────────────────┐  │
│  │  S3: quantumtrade-logs      │  │  S3: transaction-data   │  │
│  │  KMS encrypted              │  │  KMS encrypted          │  │
│  │  Public access blocked      │  │  Versioning enabled     │  │
│  │  Receives access logs       │  │  Lifecycle: IA→Glacier  │  │
│  └─────────────────────────────┘  └─────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  KMS CMK (alias/quantumtrade-main)                       │  │
│  │  Key rotation: enabled  │  Deletion window: 7 days       │  │
│  │  Used by: EC2 EBS, RDS storage, S3 SSE, CloudWatch logs  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Design

All three service layers are implemented as **reusable, opinionated modules**. The modules encode secure defaults — callers cannot accidentally deploy an insecure resource without explicitly overriding a hardened setting.

```
terraform/
├── main.tf          # Root: VPC, KMS, subnets, SG, flow logs, module calls
├── rds.tf           # RDS subnet group + module call
├── variables.tf     # Root inputs (region, environment, db_password with validation)
├── outputs.tf       # Exports: VPC ID, EC2 ID, S3 ARN, RDS endpoint (sensitive)
└── modules/
    ├── s3/          # Hardened S3 bucket
    ├── ec2/         # Hardened EC2 instance
    └── rds/         # Hardened RDS PostgreSQL instance
```

### `modules/s3` — Secure S3 Module

| Control | Implementation |
|---------|----------------|
| Encryption at rest | KMS CMK SSE (`aws:kms`) — key ARN required input |
| Public access | All 4 block settings `true` via `aws_s3_bucket_public_access_block` |
| Versioning | Configurable via `enable_versioning` input (default: `false`) |
| Access logging | Logs delivered to dedicated log bucket via `aws_s3_bucket_logging` |
| Lifecycle | Standard-IA at 90 days → Glacier at 180 days |
| Tagging | `Environment`, `Owner`, `CostCenter` required inputs |

### `modules/ec2` — Secure EC2 Module

| Control | Implementation |
|---------|----------------|
| IMDSv2 | `http_tokens = "required"`, hop limit = 1 — prevents SSRF credential theft |
| EBS encryption | Root volume encrypted with KMS CMK (`kms_key_id` required input) |
| No public IP | `associate_public_ip_address = false` |
| Monitoring | `monitoring = true` — CloudWatch 1-minute detailed metrics |
| Access | SSM Session Manager via `AmazonSSMManagedInstanceCore` IAM policy — no SSH, no bastion |
| Instance type | `t2.*` blocked via input validation |
| Tagging | `Environment`, `Owner`, `CostCenter` required inputs |

### `modules/rds` — Secure RDS Module

| Control | Implementation |
|---------|----------------|
| Encryption | `storage_encrypted = true` with KMS CMK — key ARN required input |
| Network isolation | `publicly_accessible = false`, deployed into private subnets |
| Deletion protection | `deletion_protection = true` |
| Backup | `backup_retention_period = 7` days |
| High availability | `multi_az = true` — standby replica in eu-west-2b |
| IAM auth | `iam_database_authentication_enabled = true` |
| Auto patching | `auto_minor_version_upgrade = true` |
| Audit logs | `enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]` |
| Tagging | `Environment`, `Owner`, `CostCenter` required inputs |

---

## Security Scanning Pipeline

```
Git push / Pull Request
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│                  GitHub Actions Pipeline                      │
│                                                              │
│  ┌───────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │  Checkov  │  │  tfsec   │  │   OPA    │  │ tf fmt +  │  │
│  │  v3.2.510 │  │ v1.28.11 │  │  v0.63.0 │  │ validate  │  │
│  │  2,500+   │  │  AWS     │  │  Custom  │  │           │  │
│  │  CIS rules│  │  rules   │  │  Rego    │  │           │  │
│  └─────┬─────┘  └─────┬────┘  └─────┬────┘  └─────┬─────┘  │
│        └──────────────┴──────────────┴─────────────┘        │
│                              │                               │
│                    ┌─────────▼──────────┐                    │
│                    │  Security Summary  │                    │
│                    └────────────────────┘                    │
└──────────────────────────────────────────────────────────────┘
        │                         │
        ▼                         ▼
 GitHub Security Tab         Job logs
 (SARIF findings)            (console output)
```

### What each tool catches

| Tool | Strength | Example findings caught |
|------|----------|-------------------------|
| Checkov | Broad CIS/PCI/HIPAA policy library | S3 encryption off, RDS not multi-AZ, IMDSv1 enabled |
| tfsec | AWS-native rules with severity ratings | SSH open to internet (CRITICAL), unrestricted egress |
| OPA | Custom business rules via Rego | Missing required tags, unapproved instance types |
| `terraform validate` + `fmt` | HCL correctness and formatting | Syntax errors, unformatted code blocked at gate |

### SARIF Integration

Checkov and tfsec results are uploaded to the GitHub Security tab as SARIF on every run. This means:
- Security findings are visible at the PR level, not buried in logs
- Historical findings are tracked over time
- The Security tab acts as a lightweight findings register during development

---

## Data Flow

```
  Internet
     │
     │  (no inbound — no IGW, no public IPs)
     ✗
     │
┌────▼────────────────────────────────┐
│  AWS Systems Manager (SSM)          │
│  VPC Endpoint                        │
└────┬────────────────────────────────┘
     │  Encrypted session
     ▼
┌─────────────────────────────────────┐
│  EC2 App Server (Private Subnet A)  │
│  No public IP, IMDSv2, EBS KMS      │
└────┬────────────────────────────────┘
     │  Port 5432 (PostgreSQL)
     ▼
┌─────────────────────────────────────┐
│  RDS PostgreSQL (Private Subnet B)  │
│  Multi-AZ, KMS, IAM auth, no public │
└─────────────────────────────────────┘
     │
     │  Logs / backups
     ▼
┌─────────────────────────────────────┐
│  S3 (transaction-data bucket)       │
│  KMS, versioning, lifecycle         │
└─────────────────────────────────────┘
     │  Access logs
     ▼
┌─────────────────────────────────────┐
│  S3 (log bucket)                    │
│  KMS, no public access              │
└─────────────────────────────────────┘
```

---

## Key Design Decisions

### Why no bastion host?

EC2 instances are accessed exclusively via **AWS Systems Manager Session Manager**. This eliminates the SSH attack surface entirely — no port 22, no key pairs to rotate, no bastion to harden. Session Manager logs all shell activity to CloudWatch, providing a better audit trail than SSH.

### Why a customer-managed KMS key (CMK) over AWS-managed?

A CMK (`aws_kms_key`) gives explicit control over the key policy, rotation schedule, and deletion window. AWS-managed keys (`aws/s3`, `aws/rds`) cannot have custom key policies, which means you cannot restrict which principals can use them or audit their usage with the same granularity.

### Why OPA in addition to Checkov and tfsec?

Checkov and tfsec enforce industry-standard rules. OPA enforces **organisation-specific rules** that no vendor tool knows — QuantumTrade's tagging standard, approved instance families, and versioning requirements. It also evaluates against the Terraform plan JSON, which means it catches dynamic values that static file scanners miss.

### Why pin tool versions?

All three scanners are pinned to specific versions in the pipeline (`Checkov==3.2.510`, `tfsec:v1.28.11`, `opa: 0.63.0`). This ensures scan results are reproducible and comparable across runs. A new tool version could add or remove rules, changing the pass/fail count without any infrastructure change.

### Why `tfplan.json` is committed

In production, `terraform plan` would run in CI with live AWS credentials to generate a fresh plan. This portfolio repo has no live credentials, so a pre-generated plan is committed to enable OPA evaluation in CI. `.gitignore` documents this explicitly with commented-out exclusion rules to make the intent clear to any reader.

---

## Compliance Mapping

This architecture is mapped to SOC 2 Trust Service Criteria in [`docs/SOC2_CONTROL_MAPPING.md`](../docs/SOC2_CONTROL_MAPPING.md).

| SOC 2 Criterion | Controls implemented |
|-----------------|---------------------|
| CC6.1 — Access controls | KMS CMK encryption (EC2 EBS, RDS, S3, CloudWatch logs) |
| CC6.6 — Boundary protection | No public IPs, S3 public access blocked, SG lockdown |
| CC7.1 — Security monitoring | VPC flow logs, EC2 detailed monitoring, S3 access logging |
| CC7.2 — Incident response | IMDSv2 (SSRF protection), no hardcoded credentials |
| CC8.1 — Change management | Git version control, automated security gates in CI/CD |
| CC9 — Risk mitigation | OPA tag enforcement, accepted risk register |

---

## What Is Not In Scope

The following controls are documented as out-of-scope for this IaC hardening engagement. They would form the next workstreams in a production engagement:

| Control | Why out of scope | Next step |
|---------|------------------|-----------|
| AWS GuardDuty | Runtime threat detection — requires live AWS environment | Enable via Terraform in production account |
| AWS Config Rules | Continuous compliance post-deploy — drift detection | Add `aws_config_rule` resources |
| Container / image scanning | Snyk or Trivy — secures workloads, not infrastructure | Separate pipeline stage |
| S3 cross-region replication | DR control — requires second region and KMS keys | Business continuity workstream |
| RDS Performance Insights | Observability — not a security misconfiguration | Operational monitoring workstream |
| CloudWatch 1-year retention | Compliance log retention policy decision | Governance workstream |

---

*For all security findings and their remediation status, see [SECURITY-FINDINGS.md](../SECURITY-FINDINGS.md).*
