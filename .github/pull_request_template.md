## Summary

<!-- What does this PR change and why? -->

## Type of Change

- [ ] Terraform infrastructure change
- [ ] OPA policy change
- [ ] GitHub Actions workflow change
- [ ] Documentation update
- [ ] Bug fix / false positive correction
- [ ] Other (describe below)

---

## Security Scan Checklist

All items below must be confirmed before requesting review.

### Automated Scans
- [ ] **Checkov** — pipeline passing, no new CRITICAL or HIGH findings
- [ ] **tfsec** — pipeline passing, no new CRITICAL or HIGH findings
- [ ] **OPA policies** — all custom policy evaluations passing (0 deny violations)
- [ ] **Terraform Validate** — `terraform validate` and `terraform fmt -check` passing

### For Terraform Changes
- [ ] Hardened modules used — no direct resource declarations outside `terraform/modules/`
- [ ] All resources tagged with `Environment`, `Owner`, `CostCenter`
- [ ] KMS encryption applied to all storage resources (S3, EBS, RDS)
- [ ] No public access enabled (S3 public access blocks, EC2 no public IP)
- [ ] Security group rules minimally scoped — no `0.0.0.0/0` ingress
- [ ] IMDSv2 enforced on any EC2 resources (`http_tokens = "required"`)

### For Policy Changes
- [ ] New/modified Rego policy tested against both the vulnerable baseline (`test-security-scan`) and hardened state (`main`)
- [ ] Policy package name matches the `.rego` filename
- [ ] OPA syntax validated: `opa check policies/opa/`

### For Workflow Changes
- [ ] Action versions pinned to a specific tag (not `@master` or `@latest`)
- [ ] No new secrets or environment variables introduced without documenting in README
- [ ] `permissions` block scoped to minimum required

---

## SOC 2 Impact

<!-- Does this change affect any SOC 2 Trust Service Criteria?
     Reference the relevant control IDs from docs/SOC2_CONTROL_MAPPING.md
     e.g. CC6.1 (encryption at rest), CC6.6 (network controls), CC7.2 (monitoring) -->

- [ ] No SOC 2 impact
- [ ] SOC 2 impact — controls affected: <!-- list here -->

---

## Rollback Plan

<!-- How would this change be reversed if it causes an issue in production?
     For Terraform: `git revert` + `terraform apply` of prior state
     For workflow changes: revert commit and re-run pipeline -->

---

## Screenshots / Evidence

<!-- Paste pipeline run link or scan output confirming all checks pass -->
