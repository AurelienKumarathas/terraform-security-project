# Contributing to terraform-security-project

Thank you for taking the time to look at this project. These guidelines explain how to work with the codebase, run the security tools locally, and open a pull request that will pass all pipeline checks.

---

## Project Philosophy

This repository exists to demonstrate **security-as-code** applied to Terraform IaC. Every module is hardened by default — insecure configuration is not possible without explicitly removing a control. When contributing, the principle is:

> _"Secure by default. Explicit when accepting risk."_

---

## Prerequisites

Install the following tools before working with this repo:

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.6.0 | `brew install terraform` or [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads) |
| Checkov | 3.2.510 | `pip install checkov==3.2.510` |
| tfsec | 1.28.14 | `brew install tfsec` or [GitHub releases](https://github.com/aquasecurity/tfsec/releases) |
| OPA | 0.63.0 | `brew install opa` or [openpolicyagent.org](https://www.openpolicyagent.org/docs/latest/#running-opa) |
| Python | >= 3.9 | Required for Checkov |

> **Version pinning matters.** The CI pipeline uses exact versions. Running different versions locally may produce different pass/fail counts.

---

## Repository Layout

```
terraform-security-project/
├── terraform/
│   ├── main.tf              # Root: VPC, KMS, SG, flow logs, module calls
│   ├── variables.tf         # Root input variables (with validation)
│   ├── outputs.tf           # Root outputs
│   ├── tfplan.json          # Pre-generated plan for OPA evaluation (see below)
│   └── modules/
│       ├── s3/              # Hardened S3 module (encryption, versioning, logging)
│       ├── ec2/             # Hardened EC2 module (IMDSv2, KMS EBS, SSM access)
│       └── rds/             # Hardened RDS module (encryption, Multi-AZ, IAM auth)
├── policies/
│   └── opa/
│       ├── required_tags.rego      # Enforces Environment, Owner, CostCenter on all resources
│       ├── ec2_instance_types.rego # Blocks t2.* instance family
│       └── s3_versioning.rego      # Requires versioning on data buckets
├── .github/
│   └── workflows/
│       └── iac-security.yml  # CI pipeline: Checkov, tfsec, OPA, tf fmt + validate
├── docs/
│   ├── ARCHITECTURE.md         # Infrastructure diagrams and design decisions
│   ├── SOC2_CONTROL_MAPPING.md # SOC 2 trust criteria → Terraform control mapping
│   └── SECURITY_REPORT.md      # Executive summary of findings
├── screenshots/          # Pipeline screenshots for README
├── .checkov.yaml         # Checkov skip rules with documented justifications
├── .tfsec/config.yml     # tfsec severity overrides
├── SECURITY-FINDINGS.md  # Full findings register (19 Checkov + 19 tfsec)
├── SECURITY.md           # Vulnerability disclosure policy
└── README.md
```

---

## Running Security Scans Locally

All scans should pass before pushing. The CI pipeline runs exactly these commands.

### Terraform format + validate

```bash
cd terraform/
terraform fmt -recursive -check
terraform init -backend=false
terraform validate
```

Fix formatting automatically with:

```bash
terraform fmt -recursive
```

### Checkov

```bash
checkov -d terraform/ \
  --config-file .checkov.yaml \
  --output cli \
  --output sarif \
  --output-file-path results/
```

Expected result: **2 failures** (both skipped in `.checkov.yaml` with documented justifications). Any new failures introduced by your change must either be fixed or added to `.checkov.yaml` with a written justification.

### tfsec

```bash
tfsec terraform/ \
  --config-file .tfsec/config.yml \
  --format default
```

Expected result: **1 medium finding** (severity override in `.tfsec/config.yml`). Same rule applies as Checkov.

### OPA

```bash
opa eval \
  --format pretty \
  --data policies/opa/ \
  --input terraform/tfplan.json \
  "data.terraform"
```

OPA evaluates against `terraform/tfplan.json`. This file is pre-generated and committed to allow CI evaluation without live AWS credentials. In production it would be generated fresh on every run.

See `.gitignore` for context on why `tfplan.json` is an intentional exception to the usual rule of not committing plan outputs.

---

## Branching & Pull Request Conventions

### Branch naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature / improvement | `feat/<short-description>` | `feat/rds-module` |
| Bug fix | `fix/<short-description>` | `fix/sg-egress-rule` |
| Documentation | `docs/<short-description>` | `docs/add-architecture` |
| Security hardening | `security/<short-description>` | `security/imdsv2-enforcement` |
| Chore / cleanup | `chore/<short-description>` | `chore/remove-stale-screenshots` |

### PR checklist

Before opening a PR, confirm:

- [ ] `terraform fmt -recursive` passes with no changes
- [ ] `terraform validate` passes
- [ ] Checkov scan passes (or new skips added to `.checkov.yaml` with justification)
- [ ] tfsec scan passes (or severity override added to `.tfsec/config.yml` with justification)
- [ ] OPA scan passes
- [ ] If you changed a module, `outputs.tf` and `variables.tf` are updated to match
- [ ] If you added a new security skip/override, `SECURITY-FINDINGS.md` is updated with the finding
- [ ] PR description explains _what_ changed and _why_

### PR description template

```
## What
<!-- One-line summary of the change -->

## Why
<!-- Business or security rationale -->

## Security impact
<!-- Does this change add, remove, or modify any security control? -->
<!-- If removing a control: what compensating control replaces it? -->

## Scan results
<!-- Paste summary line from Checkov and tfsec after your change -->
```

---

## Adding or Modifying a Module

All modules follow the same structure:

```
modules/<name>/
├── main.tf       # Resources (all controls must be hardened by default)
├── variables.tf  # Inputs (required inputs for KMS key, tags, etc.)
└── outputs.tf    # Exports (ARNs, IDs, endpoints)
```

**Non-negotiable module rules:**

1. **No default values for security-critical inputs.** `kms_key_id`, `subnet_id`, `db_password` must all be required. Forcing callers to provide them explicitly prevents accidental insecure defaults.
2. **Sensitive inputs must be marked `sensitive = true`** (e.g. `db_password`). This prevents values appearing in Terraform output and CI logs.
3. **All resources must have `Environment`, `Owner`, and `CostCenter` tags.** These are required inputs on every module. OPA will flag missing tags.
4. **No hardcoded AMI IDs, CIDRs, or region strings.** Use variables.
5. **Module outputs must not expose sensitive values in plaintext.** Use `sensitive = true` on any output that carries a secret.

---

## Skipping a Security Check

Occasionally a check must be suppressed (e.g. the project intentionally demonstrates a vulnerable state for comparison). The process:

**Checkov:** Add an entry to `.checkov.yaml` under `skip-check`:

```yaml
skip-check:
  - id: CKV_AWS_XXX
    comment: "<reason> — compensating control: <what replaces it>"
```

**tfsec:** Add an entry to `.tfsec/config.yml` under `severity_overrides`:

```yaml
severity_overrides:
  aws-xxx-rule-id: NONE
```

In both cases, update `SECURITY-FINDINGS.md` with the finding, its check ID, severity, and justification.

**Inline suppression is not permitted.** Using `#checkov:skip` or `#tfsec:ignore` comments in `.tf` files bypasses the central audit trail. All suppressions must go through the config files.

---

## Documentation Standards

| Document | Owner | What to update |
|----------|-------|----------------|
| `SECURITY-FINDINGS.md` | All contributors | Add a row for any new finding you introduce or remediate |
| `docs/SOC2_CONTROL_MAPPING.md` | All contributors | Update if a new control is added that maps to a SOC 2 criterion |
| `docs/ARCHITECTURE.md` | All contributors | Update if the resource topology changes (new module, new service, etc.) |
| `README.md` | Maintainer | Update screenshots / badge if pipeline structure changes |

---

## Getting Help

- For questions about Terraform module design, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- For questions about security findings and their remediation, see [`SECURITY-FINDINGS.md`](SECURITY-FINDINGS.md)
- For the SOC 2 control mapping rationale, see [`docs/SOC2_CONTROL_MAPPING.md`](docs/SOC2_CONTROL_MAPPING.md)
- To report a security vulnerability, see [`SECURITY.md`](SECURITY.md)
