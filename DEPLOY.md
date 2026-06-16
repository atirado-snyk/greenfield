# Housing Notes — Deployment Definition

This document defines **how Housing Notes is deployed to Azure** and what must
exist for the GitHub Actions pipeline to run the full code-to-production loop. It
is the concrete companion to the architecture described in `SPEC.md` §4. It is
written for two readers: a DevOps/platform engineer setting the account up by
hand, and the building agent (Claude Code) wiring the automation.

Where `SPEC.md` says *what* and *why*, this document says *which services, which
identities, which names*. It does **not** contain secrets — only the shape of the
secrets and where they live.

---

## 1. Principles

- **No long-lived cloud credentials.** Azure authentication from GitHub Actions
  uses **Workload Identity Federation (OIDC)**. There is no Azure client secret
  stored in GitHub.
- **Fail closed.** If any required identity, permission, or gate is missing or
  cannot be evaluated, the deploy stops. It never falls back to an unprotected
  path.
- **Reproducible from nothing.** The infrastructure can be stood up in a clean
  Azure subscription using only this document, the Terraform in `/infra`, and the
  GitHub configuration described here.
- **Single production environment.** No staging or dev. The security gate, not a
  promotion step, is what protects production.

## 2. Azure resources

All resources live in one resource group in a single region.

| Resource | Purpose | Reference name |
| --- | --- | --- |
| Resource group | Container for everything | `housing-notes-rg` |
| AKS cluster | Runs the workloads | `housing-notes-aks` |
| Azure Container Registry | Images that AKS pulls; image + malware scanning | `housingnotesacr` (globally unique; adjust if taken) |
| Storage account + container | Terraform remote state backend | `housingnotestfstate` / `tfstate` |
| User-assigned managed identity / app registration | OIDC federation target for GitHub Actions | `housing-notes-deployer` |

Region default is `eastus` (matches `/infra/variables.tf`). Names follow the
existing Terraform defaults so the documents and code stay consistent.

### 2.1 AKS

- One node pool with sensible defaults (see `/infra/variables.tf`).
- System-assigned identity on the cluster (already in `/infra/main.tf`).
- **ACR pull permission:** the cluster's kubelet identity must be granted
  `AcrPull` on the ACR so it can pull images without image-pull secrets. This is
  part of the Terraform, not a manual step.

### 2.2 ACR

- Standard tier or above (image scanning / quarantine features must be
  available).
- **Image scanning is enabled**, and it is treated as part of the security gate
  (`SPEC.md` §6): an image that fails ACR scanning must not roll out to AKS.
- ACR is the **only** registry AKS pulls from. GHCR (see §5) is a public mirror
  for inspection, not a pull source for the cluster.

### 2.3 Ingress controller

The Kubernetes manifests in `/k8s` assume an **nginx ingress controller** is
running in the cluster. Standing up that controller is part of bringing the
environment up — it must be installed into the cluster (for example via its
official manifests or Helm chart) before the application ingress can resolve.
This is an explicit deployment step, not an assumption; the pipeline or the
bootstrap process must ensure the controller exists.

## 3. GitHub OIDC / Workload Identity Federation

GitHub Actions authenticates to Azure with a federated credential — no stored
secret.

1. Create the Azure identity (`housing-notes-deployer`) — either a user-assigned
   managed identity or an app registration with a federated credential.
2. Add a **federated credential** scoped to this repository and the `main`
   branch, so only workflows on `main` of `atirado-snyk/greenfield` can assume
   it. The subject is the GitHub OIDC subject for the repo + ref.
3. Grant that identity the Azure role assignments it needs:
   - `Contributor` on the resource group (to apply Terraform / manage AKS), and
   - `AcrPush` on the ACR (to push images), and
   - access to the Terraform state storage account.
   Scope these as tightly as the demo allows.

The workflow uses `permissions: id-token: write` and the official Azure login
action configured for OIDC.

## 4. GitHub configuration

Stored in the repository (or org) settings. Because auth is OIDC, these are
**identifiers, not secrets** — but treat them as configuration regardless.

| Name | Kind | Purpose |
| --- | --- | --- |
| `AZURE_CLIENT_ID` | variable/secret | The deployer identity's client ID |
| `AZURE_TENANT_ID` | variable/secret | Azure tenant |
| `AZURE_SUBSCRIPTION_ID` | variable/secret | Target subscription |
| `SNYK_TOKEN` | secret | Auth for Snyk scans (added in Pass 2) |

`SNYK_TOKEN` is the one true secret here and is only required once Pass 2
introduces scanning. Nothing else about the app requires a stored cloud
credential.

## 5. Image registries

Two registries, by design (`SPEC.md` §4):

- **GHCR — `ghcr.io/atirado-snyk/housing-notes-*`** — a public, openly viewable
  mirror so a demo audience can inspect the images without Azure access. Pushed
  to from the workflow using the built-in `GITHUB_TOKEN` with `packages: write`.
  > Note: existing `/k8s` manifests reference `ghcr.io/atiradonet/...` (the
  > personal-account origin). When deploying from this fork, image references
  > must point at the registry AKS actually pulls from — the **ACR** — and the
  > GHCR path should match this repo's owner. Reconcile these during the build.
- **ACR — `housingnotesacr.azurecr.io/housing-notes-*`** — the registry AKS
  pulls from and where image/malware scanning happens. Pushed to using the OIDC
  identity's `AcrPush` role.

The same image content is pushed to both; ACR is authoritative for what runs.

## 6. Terraform remote state

- Backend: the Azure storage account + container in §2.
- Local-only state is **not** acceptable — CI must be able to apply
  reliably and repeatably.
- State access is via the OIDC identity; no storage keys in GitHub.
- `/infra` must declare this backend explicitly.

## 7. Pipeline shape (reference)

The detailed, phased build of the pipeline lives in `BUILD_DIRECTIVE.md`. As a
reference, the end-state pipeline on every push to `main` does, in order:

1. **CI** — install, lint, typecheck, test, build (backend and frontend).
2. **Security gate (Pass 2 onward)** — Snyk SAST, SCA, IaC, and container scans.
   High/Critical findings **stop the run** before anything is deployed.
3. **Build & push images** — to GHCR (public mirror) and ACR (authoritative).
   ACR image/malware scanning applies; a failing image does not roll out.
4. **Infrastructure** — `terraform apply` against remote state to ensure the
   resource group, AKS, ACR, and role assignments exist.
5. **Deploy** — ensure the nginx ingress controller is present, then apply the
   `/k8s` manifests to the cluster and roll out the new images.

Steps 4–5 run only if step 2 passes. The gate protects production; there is no
human approval step.

## 8. Bringing it up the first time (manual bootstrap checklist)

For a clean subscription, before the pipeline can self-serve:

1. Create the resource group and the Terraform state storage account + container.
2. Create the `housing-notes-deployer` identity and its federated credential for
   `atirado-snyk/greenfield` on `main`.
3. Assign roles (§3).
4. Set the GitHub configuration values (§4).
5. Push to `main` — the pipeline provisions the rest (AKS, ACR, ACR pull
   permission) via Terraform and performs the first deploy.

After the first successful run, subsequent pushes are fully automated.

## 9. Related documents

- **`SPEC.md`** — what the system is and the architecture this realises.
- **`BUILD_DIRECTIVE.md`** — the two-pass instructions that build this pipeline.
- **`CLAUDE.md`** — conventions and the security-gate rules.
