# =====================================================================
#  seed-issues.ps1  —  devsecops-cicd-pipeline
#  Creates the full ticket backlog as GitHub issues.
#  All tickets assigned to Corrierethan (Ethan).
#
#  Usage:
#    pwsh ./scripts/seed-issues.ps1
#  Requires: gh CLI authenticated as a repo collaborator.
#  Note: running twice creates duplicate issues.
# =====================================================================

$ErrorActionPreference = 'Stop'
$env:Path += ";C:\Program Files\GitHub CLI"

$Repo     = 'Corrierethan/devsecops-cicd-pipeline'
$Assignee = 'Corrierethan'

Write-Host "Seeding issues into $Repo ..." -ForegroundColor Cyan

# ---------------------------------------------------------------------
# Labels
# ---------------------------------------------------------------------
$labels = @(
    @{ name = 'type:skeleton';   color = 'c5def5'; desc = 'Repo scaffolding / structure' },
    @{ name = 'type:feature';    color = '0e8a16'; desc = 'New capability' },
    @{ name = 'type:security';   color = 'b60205'; desc = 'Security gate / hardening' },
    @{ name = 'type:ci';         color = '5319e7'; desc = 'CI / pipeline plumbing' },
    @{ name = 'type:docs';       color = '1d76db'; desc = 'Documentation' },
    @{ name = 'type:chore';      color = 'ededed'; desc = 'Maintenance / finishing touches' },
    @{ name = 'size:S';          color = 'c2e0c6'; desc = 'Small (<= half day)' },
    @{ name = 'size:M';          color = 'fef2c0'; desc = 'Medium (~1 day)' },
    @{ name = 'size:L';          color = 'f9d0c4'; desc = 'Large (multi-day)' }
)

foreach ($l in $labels) {
    gh label create $l.name --repo $Repo --color $l.color --description $l.desc --force | Out-Null
}
Write-Host "Labels ready." -ForegroundColor Green

# ---------------------------------------------------------------------
# Issues
# ---------------------------------------------------------------------
$issues = @()

# ---- #0 Skeleton ----------------------------------------------------
$issues += @{
title  = '#0 Initialize repository skeleton'
labels = 'type:skeleton,size:S'
body   = @'
Stand up the empty repo structure so every later ticket has a home. **No real logic yet** — just files, folders, and placeholders.

### Files / folders to create
- [ ] `.gitignore` (Python + Terraform + OS noise: `__pycache__/`, `*.pyc`, `.venv/`, `.env`, `.DS_Store`)
- [ ] `.editorconfig` (LF line endings, 2-space YAML, 4-space Python)
- [ ] `LICENSE` (MIT)
- [ ] `CHANGELOG.md` (Keep a Changelog format, `## [Unreleased]`)
- [ ] `app/` (empty, with `.gitkeep`)
- [ ] `templates/` (empty, with `.gitkeep`)
- [ ] `docs/` (empty, with `.gitkeep`)
- [ ] `.github/workflows/` (empty, with `.gitkeep`)

### Acceptance criteria
- Repo clones clean and `tree` matches the layout in the README.
- `main` is protected (1 approval, no force-push) — coordinate with repo admin.
- README already present; confirm badges point at the right workflow path.

### Out of scope
- Any pipeline logic, app code, or Dockerfile (handled in later tickets).
'@
}

# ---- #1 Sample app --------------------------------------------------
$issues += @{
title  = '#1 Add sample Python service to exercise the pipeline'
labels = 'type:feature,size:M'
body   = @'
The pipeline needs a small, real app to scan, build, and sign. Keep it intentionally simple but production-shaped.

### Files to create
- [ ] `app/main.py` — minimal FastAPI (or Flask) app with `GET /healthz` and `GET /version`
- [ ] `app/requirements.txt` — pinned versions (e.g. `fastapi==x`, `uvicorn==x`)
- [ ] `app/test_main.py` — pytest tests hitting `/healthz` and `/version`
- [ ] `app/__init__.py`

### Acceptance criteria
- `pip install -r app/requirements.txt` succeeds.
- `pytest app/` passes locally with at least 2 tests.
- `/version` reads the version from an env var (`APP_VERSION`, default `0.0.0`).

### Notes
- Pin every dependency — the SCA stage (#6) depends on deterministic versions.
- Do **not** add secrets or credentials to the code (the secret scanner in #5 will check).
'@
}

# ---- #2 Dockerfile --------------------------------------------------
$issues += @{
title  = '#2 Add hardened multi-stage Dockerfile'
labels = 'type:security,size:M'
body   = @'
Container the sample app with a hardened, minimal image so the container-scan (#8) and signing (#10) stages have an artifact.

### Files to create
- [ ] `Dockerfile` — multi-stage (builder + runtime)
- [ ] `.dockerignore` (exclude `.git`, `tests`, `__pycache__`, `docs`)

### Hardening requirements (checklist)
- [ ] Pinned base image by digest (e.g. `python:3.12-slim@sha256:...`)
- [ ] Non-root `USER` (create a uid/gid, e.g. `10001`)
- [ ] No build tools in the final image (multi-stage copy only the venv/app)
- [ ] `HEALTHCHECK` hitting `/healthz`
- [ ] Read-only-friendly (no writes outside `/tmp`)
- [ ] Drop to a single `ENTRYPOINT`

### Acceptance criteria
- `docker build -t sample-app .` succeeds.
- `docker run` serves `/healthz` returning 200.
- Image runs as non-root (`docker run ... id -u` != 0).
'@
}

# ---- #3 CI base -----------------------------------------------------
$issues += @{
title  = '#3 CI workflow base: lint + unit tests'
labels = 'type:ci,size:M'
body   = @'
Create the first GitHub Actions workflow that runs on every push/PR. This is the foundation later security stages plug into.

### Files to create
- [ ] `.github/workflows/ci.yml`

### Jobs / stages
- [ ] `lint` — `ruff` (or `flake8`) + `black --check` on `app/`
- [ ] `test` — `pytest app/` with coverage, upload coverage as artifact
- [ ] Trigger on `push` to `main` and all `pull_request`
- [ ] `permissions:` block set to least privilege (`contents: read`)
- [ ] Pin actions by SHA, not floating tags

### Acceptance criteria
- Workflow runs green on a PR.
- A deliberate lint error fails the `lint` job.
- The CI badge in the README turns green.

### Notes
- Use a job matrix only if needed; keep it single-version for now.
'@
}

# ---- #4 SAST --------------------------------------------------------
$issues += @{
title  = '#4 Security gate: SAST (Semgrep)'
labels = 'type:security,size:M'
body   = @'
Add static application security testing as a pipeline stage. Maps to NIST **SA-11**.

### Files to create / change
- [ ] `.semgrep.yml` (or reference managed rulesets: `p/python`, `p/security-audit`, `p/secrets`)
- [ ] Add `sast` job to `.github/workflows/ci.yml`

### Requirements
- [ ] Run Semgrep against `app/`
- [ ] Output SARIF and upload to the GitHub **code scanning** tab (`github/codeql-action/upload-sarif`)
- [ ] Job is **report-only** for now (does not block) — blocking handled in #11
- [ ] Pin Semgrep version

### Acceptance criteria
- Findings (if any) appear in the Security > Code scanning tab.
- SARIF artifact is attached to the run.
- A planted insecure pattern (e.g. `eval(input())`) is detected.
'@
}

# ---- #5 Secret scan -------------------------------------------------
$issues += @{
title  = '#5 Security gate: secret scanning (Gitleaks)'
labels = 'type:security,size:S'
body   = @'
Detect committed secrets/keys before they reach a registry. Maps to NIST **IA-5, SI-12**.

### Files to create / change
- [ ] `.gitleaks.toml` (start from default ruleset, add allowlist for test fixtures)
- [ ] Add `secret-scan` job to `.github/workflows/ci.yml`

### Requirements
- [ ] Scan full history on PR (`--log-opts` or `gitleaks detect`)
- [ ] Upload SARIF to code scanning
- [ ] Fail the job on any **verified** secret (this gate **blocks**)

### Acceptance criteria
- A planted fake AWS key triggers a failure.
- Allowlisted test fixtures do not cause false positives.
'@
}

# ---- #6 SCA ---------------------------------------------------------
$issues += @{
title  = '#6 Security gate: dependency scanning / SCA (Trivy fs + pip-audit)'
labels = 'type:security,size:M'
body   = @'
Scan third-party dependencies for known CVEs. Maps to NIST **SA-11, SR-3**.

### Files to create / change
- [ ] Add `sca` job to `.github/workflows/ci.yml`
- [ ] `docs/thresholds.md` stub (full content in #15) noting the SCA severity threshold

### Requirements
- [ ] `trivy fs --scanners vuln` against the repo
- [ ] `pip-audit` against `app/requirements.txt` as a second opinion
- [ ] Upload Trivy SARIF to code scanning
- [ ] Severity threshold via input (default `HIGH`) — report-only until #11
- [ ] Cache the Trivy vuln DB to support restricted-network runs

### Acceptance criteria
- A pinned vulnerable dependency is flagged by both tools.
- Results visible in the code scanning tab.
'@
}

# ---- #7 Build & push ------------------------------------------------
$issues += @{
title  = '#7 Build & push container image to Amazon ECR'
labels = 'type:ci,size:M'
body   = @'
Build the image once and push to ECR so downstream stages scan/sign the exact artifact.

### Files to create / change
- [ ] Add `build` job to `.github/workflows/ci.yml`
- [ ] `docs/ecr-setup.md` — how to create the ECR repo + the OIDC IAM role

### Requirements
- [ ] Authenticate to AWS via **OIDC** (no static keys) — `aws-actions/configure-aws-credentials`
- [ ] `region` and `partition` as workflow inputs (defaults `us-gov-west-1` / `aws-us-gov`)
- [ ] Build with Buildx, tag with both `git-sha` and `latest`
- [ ] Push to ECR, export the image digest as a job output for #8/#9/#10
- [ ] `permissions: id-token: write`

### Acceptance criteria
- Image appears in ECR tagged by commit SHA.
- The immutable digest is available to later jobs.

### Notes
- Use a private ECR repo. Do not push to Docker Hub.
'@
}

# ---- #8 Container scan ----------------------------------------------
$issues += @{
title  = '#8 Security gate: container image scan (Trivy image)'
labels = 'type:security,size:S'
body   = @'
Scan the built image for OS/layer CVEs. Maps to NIST **SI-2, RA-5**.

### Files to create / change
- [ ] Add `container-scan` job to `.github/workflows/ci.yml` (depends on #7)

### Requirements
- [ ] `trivy image` against the pushed digest from #7
- [ ] Scan OS packages + language deps
- [ ] Upload SARIF to code scanning
- [ ] Severity threshold input (default `HIGH`) — report-only until #11

### Acceptance criteria
- Base-image CVEs are reported.
- Scan runs against the **digest**, not a mutable tag.
'@
}

# ---- #9 SBOM --------------------------------------------------------
$issues += @{
title  = '#9 Generate SBOM (Syft)'
labels = 'type:security,size:S'
body   = @'
Produce a software bill of materials for the image. Maps to NIST **SR-3, SR-4** and EO 14028.

### Files to create / change
- [ ] Add `sbom` job to `.github/workflows/ci.yml` (depends on #7)

### Requirements
- [ ] `syft` the image digest -> SPDX JSON **and** CycloneDX JSON
- [ ] Upload both SBOMs as build artifacts
- [ ] Name artifacts with the commit SHA

### Acceptance criteria
- Both SBOM formats are downloadable from the run.
- SBOM lists the app + OS packages.

### Notes
- The SBOM is attached/attested during signing in #10.
'@
}

# ---- #10 Sign -------------------------------------------------------
$issues += @{
title  = '#10 Sign image + attest SBOM (Cosign keyless)'
labels = 'type:security,size:M'
body   = @'
Sign the image and attach the SBOM as an attestation for supply-chain provenance. Maps to NIST **SR-11, CM-14**.

### Files to create / change
- [ ] Add `sign` job to `.github/workflows/ci.yml` (depends on #7, #9)

### Requirements
- [ ] `cosign sign` the image **digest** using keyless/OIDC (Fulcio/Rekor)
- [ ] `cosign attest` the SPDX SBOM from #9
- [ ] `permissions: id-token: write`
- [ ] Document the verification command in `docs/verifying-signatures.md` (stub now, full in #15)

### Acceptance criteria
- `cosign verify` succeeds against the pushed digest.
- `cosign verify-attestation` returns the SBOM.

### Notes
- For air-gapped use, note the key-based signing fallback in docs (no Rekor reachability).
'@
}

# ---- #11 Thresholds / gates ----------------------------------------
$issues += @{
title  = '#11 Policy gates: turn report-only stages into blocking gates'
labels = 'type:security,size:M'
body   = @'
Wire the configurable severity thresholds so the pipeline can **fail** builds, not just report.

### Files to create / change
- [ ] `.github/policy/thresholds.yml` — per-stage severity (sast/sca/container-scan)
- [ ] Update `ci.yml` jobs (#4, #6, #8) to read the threshold and set `exit-code`

### Requirements
- [ ] Single source of truth for thresholds
- [ ] Default: `secret-scan` blocks always; others block at `HIGH`+
- [ ] Allow a documented break-glass override via PR label (e.g. `risk-accepted`)

### Acceptance criteria
- Lowering a threshold flips a previously green run to red.
- The override label is honored and logged in the job summary.
'@
}

# ---- #12 Reusable workflow -----------------------------------------
$issues += @{
title  = '#12 Convert pipeline into a reusable GitHub Actions workflow'
labels = 'type:feature,size:L'
body   = @'
Package the whole gauntlet as a `workflow_call` reusable workflow so any consumer repo adopts it with one `uses:` line.

### Files to create / change
- [ ] `.github/workflows/devsecops.yml` — `on: workflow_call` with typed `inputs` and `secrets`
- [ ] Refactor `ci.yml` to simply **call** `devsecops.yml`

### Inputs to expose
- [ ] `image-name`, `dockerfile-path`, `fail-on-severity`, `region`, `partition`, `ecr-repo`

### Acceptance criteria
- `ci.yml` is now a thin caller and still passes.
- A second test repo can call the workflow via `uses: Corrierethan/devsecops-cicd-pipeline/.github/workflows/devsecops.yml@main`.

### Notes
- Keep all secrets passed via `secrets: inherit` or explicit mapping; never hardcode.
'@
}

# ---- #13 GitLab parity ---------------------------------------------
$issues += @{
title  = '#13 GitLab CI parity template'
labels = 'type:feature,size:M'
body   = @'
Many federal teams run GitLab. Provide an include-able template with the same stages.

### Files to create
- [ ] `templates/devsecops.gitlab-ci.yml` — stages: lint, test, sast, secret-scan, sca, build, container-scan, sbom, sign
- [ ] `docs/gitlab-usage.md` — how to `include:` the template

### Requirements
- [ ] Same tools (Semgrep, Gitleaks, Trivy, Syft, Cosign)
- [ ] Use GitLab CI variables for thresholds + ECR/region
- [ ] Document OIDC-to-AWS via GitLab ID tokens

### Acceptance criteria
- Template is valid GitLab CI YAML (lint via GitLab CI lint or `yamllint`).
- Stage list matches the GitHub workflow.
'@
}

# ---- #14 Consumer example ------------------------------------------
$issues += @{
title  = '#14 Consumer usage example'
labels = 'type:docs,size:S'
body   = @'
Show a downstream team exactly how to adopt the reusable workflow.

### Files to create
- [ ] `examples/consumer-workflow.yml` — minimal caller of `devsecops.yml`
- [ ] `docs/adopting-this-pipeline.md` (stub; full content in #15)

### Acceptance criteria
- Example copy-pastes into a new repo and runs.
- README "Adopting the reusable workflow" snippet matches the example.
'@
}

# ---- #15 Docs -------------------------------------------------------
$issues += @{
title  = '#15 Documentation: adoption guide, thresholds, signature verification, NIST mapping'
labels = 'type:docs,size:M'
body   = @'
Fill in the docs that earlier tickets stubbed so the repo is portfolio- and reviewer-ready.

### Files to create / complete
- [ ] `docs/adopting-this-pipeline.md` — prerequisites, inputs, OIDC role setup, first run
- [ ] `docs/thresholds.md` — every gate, its default severity, how to override
- [ ] `docs/verifying-signatures.md` — full `cosign verify` + `verify-attestation` walkthrough
- [ ] `docs/nist-control-mapping.md` — table mapping each stage to NIST 800-53 / 800-218 controls

### Acceptance criteria
- No remaining "stub" placeholders.
- Every doc linked from the README resolves.
'@
}

# ---- #16 Finishing touches -----------------------------------------
$issues += @{
title  = '#16 Finishing touches: badges, branch protection, release tag'
labels = 'type:chore,size:S'
body   = @'
Polish for handoff.

### Tasks
- [ ] Confirm all README badges render (CI, license)
- [ ] Verify branch protection on `main` (1 review, status checks required, linear history)
- [ ] Make required status checks = the security gates from #11
- [ ] Tag `v0.1.0` and write the CHANGELOG entry
- [ ] Add a short `SECURITY.md` (how to report a vuln)

### Acceptance criteria
- A PR cannot merge with a failing security gate.
- `v0.1.0` release exists with notes.
'@
}

# ---------------------------------------------------------------------
# Create issues
# ---------------------------------------------------------------------
$created = 0
foreach ($i in $issues) {
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp.FullName -Value $i.body -Encoding utf8
    gh issue create --repo $Repo --title $i.title --body-file $tmp.FullName --assignee $Assignee --label $i.labels
    Remove-Item $tmp.FullName -Force
    $created++
}

Write-Host "Done. Created $created issues in $Repo." -ForegroundColor Green
