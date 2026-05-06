terraform-security-project/
├── .github/
│   └── workflows/
│       └── iac-security.yml       # Full CI/CD pipeline definition
├── .checkov.yaml                  # Checkov configuration
├── .tfsec/                        # tfsec custom configuration
├── terraform/
│   ├── main.tf                    # Root module (references hardened modules)
│   ├── rds.tf                     # RDS subnet group + module invocation
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Key resource identifiers
│   ├── tfplan.json                # Pre-generated plan for OPA evaluation (see note below)
│   └── modules/
│       ├── s3/main.tf             # Hardened S3 module
│       ├── ec2/main.tf            # Hardened EC2 module
│       └── rds/                   # Hardened RDS module
│           ├── main.tf            # RDS instance configuration
│           ├── variables.tf       # RDS module inputs
│           └── outputs.tf         # RDS module outputs
├── policies/
│   └── opa/
│       ├── required_tags.rego     # Enforce Owner, Environment, CostCenter
│       ├── ec2_instance_types.rego # Block t2 instances in production
│       └── s3_versioning.rego     # Require versioning on production buckets
├── screenshots/
│   ├── pipeline-overview 2.png    # Live pipeline run — all jobs passing
│   └── pipeline-annotations 2.png # GitHub Actions annotations — green run, no security findings
├── docs/
│   ├── SOC2_CONTROL_MAPPING.md    # SOC 2 Trust Service Criteria mapping
│   └── SECURITY_REPORT.md        # Full security assessment report
├── SECURITY.md                    # Responsible disclosure policy
└── SECURITY-FINDINGS.md          # Consolidated findings with fix examples
