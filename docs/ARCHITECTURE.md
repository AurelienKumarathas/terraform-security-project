# Architecture — QuantumTrade AWS Infrastructure

**Region:** `eu-west-2` (London) · **Terraform:** `>= 1.0.0` · **AWS Provider:** `~> 5.0`  
**Last updated:** 2026-05-07

This document gives a reviewer instant orientation: what is deployed, how every security control is wired in, and how the CI/CD pipeline enforces that nothing regresses.

---

## Infrastructure Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│  AWS Account  ·  eu-west-2 (London)                                    │
│                                                                        │
│  ┌─ KMS CMK  alias/quantumtrade-main ───────────────────────────────┐ │
│  │  enable_key_rotation = true  ·  deletion_window = 7 days         │ │
│  │  Explicit key policy (EnableRootAccess)  ·  Satisfies CKV2_AWS_64│ │
│  │  Used by: EBS · RDS storage · S3 SSE · CloudWatch Logs           │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                          │ encrypts every layer below                  │
│  ┌─ VPC  10.0.0.0/16 ───────────────────────────────────────────────┐ │
│  │  enable_dns_hostnames = true  ·  enable_dns_support = true       │ │
│  │  Default SG: locked down — no ingress, no egress  (CKV2_AWS_12) │ │
│  │                                                                   │ │
│  │  ┌─ Private Subnet A  10.0.1.0/24  eu-west-2a ────────────────┐ │ │
│  │  │                                                             │ │ │
│  │  │  ┌─ EC2  t3.medium  module/ec2 ──────────────────────────┐ │ │ │
│  │  │  │  associate_public_ip_address = false                  │ │ │ │
│  │  │  │  IMDSv2: http_tokens=required, hop_limit=1            │ │ │ │
│  │  │  │  EBS root volume: encrypted with KMS CMK              │ │ │ │
│  │  │  │  monitoring = true  (1-min CloudWatch metrics)        │ │ │ │
│  │  │  │  Access: SSM Session Manager only — no port 22        │ │ │ │
│  │  │  └───────────────────────────────────────────────────────┘ │ │ │
│  │  │                                                             │ │ │
│  │  │  ┌─ RDS PostgreSQL 14  db.t3.medium  module/rds ─────────┐ │ │ │
│  │  │  │  multi_az = true  (standby replica → Subnet B)        │ │ │ │
│  │  │  │  publicly_accessible = false                          │ │ │ │
│  │  │  │  storage_encrypted = true  (KMS CMK)                  │ │ │ │
│  │  │  │  iam_database_authentication_enabled = true           │ │ │ │
│  │  │  │  deletion_protection = true                           │ │ │ │
│  │  │  │  backup_retention_period = 7 days                     │ │ │ │
│  │  │  │  auto_minor_version_upgrade = true                    │ │ │ │
│  │  │  │  CW logs: postgresql + upgrade                        │ │ │ │
│  │  │  └───────────────────────────────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────────────────────────────┘ │ │
│  │                                                                   │ │
│  │  ┌─ Private Subnet B  10.0.2.0/24  eu-west-2b ────────────────┐ │ │
│  │  │  RDS Multi-AZ standby replica                               │ │ │
│  │  └─────────────────────────────────────────────────────────────┘ │ │
│  │                                                                   │ │
│  │  SG: quantumtrade-app-sg                                         │ │
│  │    Ingress: none  (SSM via VPC endpoint — no open ports)         │ │
│  │    Egress:  HTTPS 443 only                                       │ │
│  │                                                                   │ │
│  │  VPC Flow Logs → CW /aws/vpc/quantumtrade-flow-logs              │ │
│  │    traffic_type = ALL  ·  KMS-encrypted  ·  90-day retention     │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│  ┌─ S3  module/s3 ───────────────────────────────────────────────────┐ │
│  │                                                                   │ │
│  │  quantumtrade-logs-{env}          (log bucket)                   │ │
│  │    SSE-KMS  ·  all public access blocked  ·  versioning on        │ │
│  │    Lifecycle: → Glacier at 90 days                                │ │
│  │                                                                   │ │
│  │  quantumtrade-transaction-data-{env}   (data bucket)             │ │
│  │    SSE-KMS  ·  all public access blocked  ·  versioning on        │ │
│  │    Access logs → log bucket  ·  Lifecycle: → Glacier at 90 days  │ │
│  └───────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Security Posture

| Control | What is configured | Compliance reference |
|---|---|---|
| **KMS CMK** | Key rotation enabled; explicit key policy; 7-day deletion window | CKV2_AWS_64 · SOC 2 CC6.1 |
| **No public compute** | EC2 has no public IP; RDS `publicly_accessible = false`; no public subnets | CKV_AWS_8 · SOC 2 CC6.6 |
| **IMDSv2 enforced** | `http_tokens = "required"`, hop limit = 1 | CKV_AWS_79 · NIST CSF PR.AC |
| **Default SG lockdown** | AWS default SG overridden — no ingress, no egress | CKV2_AWS_12 · CIS AWS 5.4 |
| **SSM-only access** | No inbound SG rules on EC2; no SSH key pairs; access via Session Manager | Eliminates port 22 exposure |
| **VPC Flow Logs** | ALL traffic logged; KMS-encrypted; 90-day retention | CKV2_AWS_49 · SOC 2 CC7.1 |
| **S3 hardening** | All 4 public-access block settings; SSE-KMS; versioning; access logging; lifecycle | CKV_AWS_19/53–56/21 |
| **RDS hardening** | Multi-AZ; KMS storage encryption; IAM auth; deletion protection; 7-day backups | CKV_AWS_17/157/293/133 |
| **EBS encryption** | Root volume encrypted with CMK on every EC2 instance | CKV_AWS_8 |
| **Mandatory tags** | `Environment`, `Owner`, `CostCenter`, `ManagedBy` on every resource | OPA `required_tags` policy |
| **Approved instance types** | EC2 instance family restricted via OPA policy | OPA `ec2_instance_types` policy |
| **S3 versioning enforced** | Versioning cannot be disabled on any bucket | OPA `s3_versioning` policy |

---

## Module Design

Security controls are encapsulated inside modules so that any new environment inherits them automatically. A caller supplies only business-level inputs; no security parameter has an insecure default.

```
terraform/
├── main.tf           # VPC · KMS · subnets · SGs · Flow Logs · module calls
├── rds.tf            # DB subnet group + module/rds call
├── variables.tf      # Inputs with validation (db_password complexity, environment enum)
├── outputs.tf        # Exported values (VPC ID, EC2 ID, RDS endpoint — marked sensitive)
└── modules/
    ├── ec2/          # IMDSv2 · encrypted EBS · no public IP · detailed monitoring
    ├── s3/           # SSE-KMS · public-access block · versioning · lifecycle · logging
    └── rds/          # Encrypted · Multi-AZ · IAM auth · deletion protection · backups
```

### `modules/ec2`

| Input | Secure default | Override allowed? |
|---|---|---|
| `associate_public_ip_address` | `false` | Yes, but Checkov will flag it |
| `http_tokens` (IMDSv2) | `"required"` | No — hard-coded in module |
| `http_put_response_hop_limit` | `1` | No — hard-coded in module |
| `encrypted` (EBS) | `true` | No — hard-coded in module |
| `monitoring` | `true` | No — hard-coded in module |

### `modules/s3`

| Control | Implementation |
|---|---|
| Encryption | `aws:kms` — `kms_master_key_id` is a required input; no AWS-managed key fallback |
| Public access | All four `aws_s3_bucket_public_access_block` booleans set to `true` |
| Versioning | Enabled via `aws_s3_bucket_versioning`; enforced by OPA `s3_versioning` |
| Access logging | Delivers to a separate log bucket via `aws_s3_bucket_logging` |
| Lifecycle | Transitions objects to Glacier at 90 days via `aws_s3_bucket_lifecycle_configuration` |

### `modules/rds`

| Input | Value in root config | Why |
|---|---|---|
| `engine` / `engine_version` | `postgres` / `14` | LTS version |
| `publicly_accessible` | `false` | No internet reachability |
| `storage_encrypted` | `true` | Data at rest encrypted with CMK |
| `multi_az` | `true` | Availability; also satisfies CKV_AWS_157 |
| `iam_database_authentication_enabled` | `true` | Removes password-based DB auth |
| `deletion_protection` | `true` | Guards against accidental `terraform destroy` |
| `backup_retention_period` | `7` | 7-day PITR window |
| `auto_minor_version_upgrade` | `true` | Security patches applied automatically |
| `enabled_cloudwatch_logs_exports` | `["postgresql", "upgrade"]` | Audit trail for DB activity |

---

## CI/CD Pipeline

Five jobs run in parallel on every push to `main` and on every pull request. All four scan/validate jobs must pass before the `Security Summary` job completes. SARIF output from Checkov and tfsec feeds the GitHub Security tab, giving finding annotations directly on PR diffs.

```
git push / pull_request  →  .github/workflows/iac-security.yml
                │
    ┌───────────┼────────────────────────────────────┐
    │           │                │                   │
    ▼           ▼                ▼                   ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────────┐
│ Checkov  │ │  tfsec   │ │   OPA    │ │  Terraform Validate  │
│ Security │ │ Security │ │  Policy  │ │  fmt -check          │
│   Scan   │ │   Scan   │ │  Eval.   │ │  init -backend=false │
│          │ │          │ │          │ │  validate            │
│v3.2.510  │ │v1.28.11  │ │ v0.63.0  │ │  TF v1.6.6           │
│--config  │ │--config  │ │ policies/│ │                      │
│.checkov  │ │.tfsec/   │ │ opa/*.reg│ │                      │
│  .yaml   │ │config.yml│ │    o     │ │                      │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └──────────┬───────────┘
     │  SARIF     │  SARIF      │                   │
     ▼            ▼             └─────────┬─────────┘
 GitHub Security tab                      │
 (PR-level annotations)                   ▼
                                  ┌───────────────┐
                                  │Security Summary│
                                  │  (needs: all) │
                                  └───────────────┘
```

**OPA policies enforced on `terraform/tfplan.json`:**

| Policy file | Rule | What it blocks |
|---|---|---|
| `required_tags.rego` | `deny` | Any resource missing `Environment`, `Owner`, `CostCenter`, or `ManagedBy` |
| `ec2_instance_types.rego` | `deny` | EC2 instances outside the approved instance family list |
| `s3_versioning.rego` | `deny` | S3 buckets with versioning disabled |

**Suppressed findings and overrides** are documented with justifications in `.checkov.yaml` and `.tfsec/config.yml` respectively. No finding is silenced without an explicit written rationale in those files.

---

## Data Flow

```
  Internet
     │
     ✗  (no inbound — no IGW, no public subnets, no public IPs)
     │
  AWS Systems Manager (VPC Endpoint)
     │  Encrypted TLS session — full shell audit trail in CloudWatch
     ▼
  EC2 app server  (Private Subnet A · 10.0.1.0/24)
  No public IP · IMDSv2 · EBS KMS-encrypted
     │
     │  Port 5432 (PostgreSQL · IAM token auth)
     ▼
  RDS PostgreSQL  (Private Subnets A+B · Multi-AZ)
  KMS-encrypted · not publicly accessible
     │
     │  Application writes / reads
     ▼
  S3 transaction-data bucket
  SSE-KMS · versioned · lifecycle → Glacier 90 days
     │
     │  S3 server access logs
     ▼
  S3 log bucket
  SSE-KMS · no public access
     │
     │  VPC Flow Logs (all traffic)
     ▼
  CloudWatch Logs  /aws/vpc/quantumtrade-flow-logs
  KMS-encrypted · 90-day retention
```

---

## Key Design Decisions

**Why SSM instead of SSH?**  
No inbound SG rule means port 22 is never open, even accidentally. Session Manager logs every shell command to CloudWatch with an IAM-authenticated session ID — a stronger audit trail than SSH keys. No key pairs to rotate or leak.

**Why a customer-managed KMS key instead of AWS-managed keys?**  
AWS-managed keys (`aws/s3`, `aws/rds`) cannot have custom key policies, so you cannot restrict or audit which principals can perform `kms:Decrypt`. A CMK gives an explicit policy, automatic rotation, and a configurable deletion window — all auditable controls required for SOC 2 CC6.1.

**Why OPA alongside Checkov and tfsec?**  
Checkov and tfsec enforce vendor-defined industry rules. OPA enforces organisation-specific rules that no vendor tool knows — this project's tagging standard, approved instance families, and versioning requirement. OPA also evaluates the Terraform plan JSON, catching dynamic values that static HCL scanners can miss.

**Why pin all tool versions?**  
All scanners are pinned (`checkov==3.2.510`, `tfsec:v1.28.11`, `opa:0.63.0`). A tool version bump can add or remove rules, silently changing pass/fail counts with no infrastructure change. Pinning makes scan results reproducible and comparable across runs.

**Why is `tfplan.json` committed?**  
In production, `terraform plan` runs in CI with live AWS credentials to generate a fresh plan on each run. This portfolio repo carries no live credentials, so a pre-generated plan is committed to keep OPA evaluation working in CI. `.gitignore` documents this explicitly with commented-out exclusion lines to signal intent to any reader.

---

## Compliance Mapping

Full control evidence is in [`docs/SOC2_CONTROL_MAPPING.md`](./SOC2_CONTROL_MAPPING.md).

| SOC 2 Criterion | Controls implemented |
|---|---|
| CC6.1 — Logical access controls | KMS CMK; IAM DB authentication; SSM-only access |
| CC6.6 — Network boundary protection | No public IPs; private subnets only; SG lockdown; default SG restricted |
| CC6.7 — Encryption in transit | RDS IAM token auth over TLS; EC2 egress limited to HTTPS 443 |
| CC7.1 — Security monitoring | VPC Flow Logs; EC2 detailed monitoring; S3 access logging; RDS CW logs |
| CC8.1 — Change management | Git version control; automated security gates block non-compliant changes |
| CC9 — Risk mitigation | OPA tag enforcement; accepted-risk register in `.checkov.yaml` / `.tfsec/config.yml` |
| A1.2 — Availability | RDS Multi-AZ; deletion protection; 7-day PITR backups |

---

## Related Documents

| Document | Purpose |
|---|---|
| [`SECURITY-FINDINGS.md`](../SECURITY-FINDINGS.md) | Full findings register — all Checkov + tfsec original findings, severity, fix applied |
| [`docs/SOC2_CONTROL_MAPPING.md`](./SOC2_CONTROL_MAPPING.md) | Control-by-control SOC 2 evidence mapping |
| [`docs/SECURITY_REPORT.md`](./SECURITY_REPORT.md) | Narrative security assessment report |
| [`CONTRIBUTING.md`](../CONTRIBUTING.md) | How to run all tools locally and contribute safely |
| [`SECURITY.md`](../SECURITY.md) | Vulnerability disclosure policy |
