# DevSecOps CI/CD Pipeline

[![ci](https://github.com/Corrierethan/devsecops-cicd-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/Corrierethan/devsecops-cicd-pipeline/actions/workflows/ci.yml)

A reusable DevSecOps pipeline that bakes security gates directly into every build —
built by **Ascent DevOps** (Veteran-Owned Small Business, SDVOSB) to align with
**Executive Order 14028** software supply-chain requirements and **NIST SP 800-53 / 800-218 (SSDF)**.

The pipeline is delivered as a **reusable GitHub Actions workflow** (with a GitLab CI template
variant) so any downstream repo can adopt the full security gauntlet by referencing one file.

---

## What this pipeline does

Every commit runs through a security gauntlet before it can merge or publish:

```
lint → test → sast → secret-scan → sca → build → container-scan → sbom → sign → publish
```

| Stage | Tool | What it catches | NIST control |
|-------|------|-----------------|--------------|
| SAST | Semgrep | Code bugs + vulnerable patterns | SA-11 |
| Secret scan | Gitleaks | Leaked keys / tokens | IA-5, SI-12 |
| SCA | Trivy (fs) / pip-audit | Vulnerable dependencies | SA-11, SR-3 |
| Container scan | Trivy (image) | OS + layer CVEs | SI-2, RA-5 |
| SBOM | Syft (SPDX/CycloneDX) | Software bill of materials | SR-3, SR-4 |
| Sign | Cosign (keyless) | Supply-chain provenance | SR-11, CM-14 |

Each gate has a configurable severity threshold so teams can start in "report" mode and
ratchet up to "block" as the codebase matures.

---

## Repository layout

```
devsecops-cicd-pipeline/
├── app/                          # Sample Python service used to exercise the pipeline
│   ├── main.py
│   ├── requirements.txt
│   └── test_main.py
├── Dockerfile                    # Hardened, non-root, multi-stage build
├── .github/
│   └── workflows/
│       ├── ci.yml                # Pipeline that runs on this repo
│       └── devsecops.yml         # Reusable workflow consumers call via `uses:`
├── templates/
│   └── devsecops.gitlab-ci.yml   # GitLab CI include template (parity build)
├── docs/
│   ├── adopting-this-pipeline.md
│   ├── thresholds.md
│   └── verifying-signatures.md
└── scripts/
    └── seed-issues.ps1
```

---

## Adopting the reusable workflow

```yaml
# .github/workflows/security.yml in a consumer repo
jobs:
  devsecops:
    uses: Corrierethan/devsecops-cicd-pipeline/.github/workflows/devsecops.yml@main
    with:
      image-name: my-service
      fail-on-severity: HIGH
```

---

## AWS GovCloud notes

The publish stage targets **Amazon ECR** (region and partition are variables so the same
workflow runs in both `aws` and `aws-us-gov` partitions). Scanner vulnerability databases can
be pre-fetched and cached, allowing the pipeline to run in environments with restricted
outbound network access.

---

*Built by Ascent DevOps · Veteran-Owned · SDVOSB*
