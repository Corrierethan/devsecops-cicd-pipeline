# Severity Thresholds

All scanner stages start in **report-only** mode and are ratcheted to blocking
in issue #11 once the baseline false-positive rate is known.

| Stage | Tool | Current mode | Blocking threshold | NIST control |
|-------|------|--------------|--------------------|--------------|
| SAST | Semgrep | Report-only | ERROR severity | SA-11 |
| Secret scan | Gitleaks | **Blocking** | Any verified secret | IA-5, SI-12 |
| SCA (fs) | Trivy fs | Report-only | HIGH / CRITICAL | SA-11, SR-3 |
| SCA (audit) | pip-audit | Report-only | Any known CVE | SA-11, SR-3 |
| Container scan | Trivy image | Report-only | HIGH / CRITICAL | SI-2, RA-5 |

## Changing a threshold

Set `TRIVY_SEVERITY` or pass `--severity` directly in the relevant workflow
step. To flip report-only → blocking, change `--exit-code 0` to
`--exit-code 1` (Trivy) or remove `continue-on-error: true` (pip-audit,
Semgrep). Full policy gate work tracked in [issue #11].
