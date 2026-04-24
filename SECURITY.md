# Security Policy

## Supported Versions

This is a portfolio demonstration project. The `main` branch represents the fully hardened, production-ready state. The `test-security-scan` branch contains **intentional security misconfigurations** for demonstration purposes — do not deploy it to a real AWS environment.

| Branch | State |
|--------|-------|
| `main` | ✅ Hardened — production-ready patterns |
| `test-security-scan` | ❌ Intentionally vulnerable — demo only |

## Reporting a Vulnerability

If you identify a genuine security issue in this repository (e.g. a hardcoded secret, an unintended exposure, or a misconfiguration on `main` that was not intentional), please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Contact: Please raise a private security advisory via GitHub's built-in [Security Advisories](../../security/advisories/new) feature, or reach out directly via the contact details on the [GitHub profile](https://github.com/AurelienKumarathas).

## Scope

The following are **in scope** for responsible disclosure:
- Hardcoded credentials or secrets accidentally committed to `main`
- A misconfiguration on `main` that contradicts the documented hardened state
- A broken access control in the repository itself

The following are **out of scope**:
- Any finding on the `test-security-scan` branch — all misconfigurations there are intentional and documented
- Theoretical vulnerabilities with no practical exploit path
- Issues already documented in [`SECURITY-FINDINGS.md`](SECURITY-FINDINGS.md) or [`docs/SECURITY_REPORT.md`](docs/SECURITY_REPORT.md)

## Response

I aim to acknowledge all valid reports within 5 business days and provide a resolution timeline within 10 business days.

---

*This project follows the principle of responsible disclosure. All intentional vulnerabilities are confined to the `test-security-scan` branch and are fully documented.*
