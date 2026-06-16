# Housing Notes — Deployment Definition

This document defines **how Housing Notes is deployed to Azure** and what must
exist for the GitHub Actions pipeline to run the full code-to-production loop. It
is the concrete companion to the architecture described in `SPEC.md` §4. It is
written for two readers: a DevOps/platform engineer setting the account up by
hand, and the building agent (Claude Code) wiring the automation.

Where `SPEC.md` says *what* and *why*, this document says *which services, which
identities, which names*. It does **not** contain secrets — only the shape of the
secrets and where they live.

> **Bootstrap status:** the one-time Azure trust and Terraform state backend
> described in §3 and §6 have **already been provisioned** (see §8). The
> identifiers below are the real, live values — not placeholders. The building
> agent must **use** them, not recreate them.

---

## 1. Principles

- **No long-lived cloud credentials.** Azure authentication from GitHub Actions
  uses **Workload Identity Federation (OIDC)**. There is no Azure client secret
  stored in GitHub.
- **Fail closed.** If any required identity, permission, or gate is missing or
  cannot be evaluated, the deploy stops. It never falls back to an unprotected
  path.
- **Reproducible.** The *application* infrastructure (AKS, ACR, and their role
  bindings) is fully described by the Terraform in `/infra` and can be rebuilt
  by re-running the pipeline. The *bootstrap* layer (identity, trust, state
  backend) is provisioned once, out of band, and is intentionally not managed by
  the pipeline that depends on it (see §8 for why).
- **Single production environment.** No staging or dev. The security gate, not a
  promotion step, is what protects production.

## 2. Azure resources

Resources are split across **two** resource groups: a small, persistent
**bootstrap** group that holds the Terraform state, and the **application** group
that Terraform manages and that can be torn down freely.

| Resource | Purpose | Reference name | Resource group |
| --- | --- | --- | --- |
| Application resource group | Holds all Terraform-managed app infra | `housing-notes-rg` | — |
| AKS cluster | Runs the workloads | `housing-notes-aks` | `housing-notes-rg` |
| Azure Container Registry | Images AKS pulls; image + malware scanning | unique name, e.g. `housingnotesacr` (see §2.2) | `housing-notes-rg` |
| Deployer identity | OIDC federation target for GitHub Actions | `housing-notes-deployer` | `housing-notes-rg` |
| Bootstrap (state) resource group | Holds only the Terraform state | `housing-notes-tfstate-rg` | — |
| State storage account | Terraform remote state | `hnotestf3909` | `housing-notes-tfstate-rg` |
| State blob container | Terraform state blob | `tfstate` | `housing-notes-tfstate-rg` |

Region is `eastus`. The split keeps the application group disposable — deleting
`housing-notes-rg` (or `terraform destroy`) never touches the state that
describes it.

### 2.1 AKS

- One node pool with sensible defaults (see `/infra/variables.tf`).
- System-assigned (or kubelet) identity used to pull from ACR.
- **ACR pull permission:** the cluster's kubelet identity is granted `AcrPull`
  on the ACR so it can pull images without image-pull secrets. This binding is
  created by Terraform — which is why the deployer identity needs role-assignment
  rights (see §3).

### 2.2 ACR

- Standard tier or above (image scanning / quarantine features must be
  available).
- **The ACR name must be globally unique** across all of Azure and must be
  lowercase alphanumeric (no dashes), 5–50 chars. `housingnotesacr` is a
  starting suggestion; if it is taken, pick another and use the **same** name
  consistently in `/infra`, in `/k8s` image references, and in the workflow.
- **Image scanning is enabled** and is treated as part of the security gate
  (`SPEC.md` §6): an image that fails ACR scanning must not roll out to AKS.
- ACR is the **only** registry AKS pulls from. GHCR (see §5) is a public mirror
  for inspection, not a pull source for the cluster.

### 2.3 Ingress controller

The Kubernetes manifests in `/k8s` assume an **nginx ingress controller** is
running in the cluster. Installing it is an explicit deploy step, not an
assumption.

- Because the pipeline runs on **every push to `main`**, the install step must be
  **idempotent** — safe to run when the controller is already present. Use a
  declarative install (e.g. `helm upgrade --install`, or `kubectl apply` of the
  pinned release manifest) so repeated runs converge rather than fail.
- Pin the controller version; do not track "latest".

## 3. GitHub OIDC / Workload Identity Federation

GitHub Actions authenticates to Azure with a federated credential — no stored
secret. **This is already set up** (§8); the description here is the
specification it satisfies.

1. Identity: a **user-assigned managed identity** named `housing-notes-deployer`
   in `housing-notes-rg`.
2. Federated credential: subject
   `repo:atirado-snyk/greenfield:ref:refs/heads/main`, issuer
   `https://token.actions.githubusercontent.com`, audience
   `api://AzureADTokenExchange`.
   - **Consequence — `main` only.** The trust matches **only** workflow runs on
     the `main` branch. Any Azure-authenticated step on a pull request or other
     branch will fail to obtain a token. Therefore: **Azure-touching jobs
     (terraform, image push to ACR, deploy) run on `main` only.** Pull-request /
     branch runs are limited to the non-Azure CI stages (install, lint,
     typecheck, test, build). Do not wire OIDC login into a PR-triggered job.
3. Role assignments granted to the identity:
   - **`Contributor`** on `housing-notes-rg` — to create/manage AKS, ACR, etc.
   - **`Role Based Access Control Administrator`** on `housing-notes-rg` — so
     **Terraform can create the `AcrPull` binding** between AKS and ACR.
     Contributor alone **cannot** create role assignments
     (`Microsoft.Authorization/*/Write` is excluded from it), so without this
     the `terraform apply` that wires AKS→ACR fails with a 403. This role is the
     least-privilege way to grant that one capability (narrower than Owner).
   - **`Storage Blob Data Contributor`** on the state storage account
     `hnotestf3909` — to read/write Terraform state via OIDC (no storage keys).

The workflow uses `permissions: id-token: write` and the official Azure login
action configured for OIDC.

## 4. GitHub configuration

Stored in the repository settings. Because auth is OIDC, the Azure ones are
**identifiers, not secrets** — but stored as secrets for tidiness. **These are
already set** (§8).

| Name | Kind | Purpose |
| --- | --- | --- |
| `AZURE_CLIENT_ID` | secret | The deployer identity's client ID |
| `AZURE_TENANT_ID` | secret | Azure tenant |
| `AZURE_SUBSCRIPTION_ID` | secret | Target subscription |
| `SNYK_TOKEN` | secret | Auth for Snyk scans (added in Pass 2) |

`SNYK_TOKEN` is the one true secret here and is only required once Pass 2
introduces scanning.

## 5. Image registries

Two registries, by design (`SPEC.md` §4):

- **GHCR — `ghcr.io/atirado-snyk/housing-notes-*`** — a public, openly viewable
  mirror so a demo audience can inspect the images without Azure access. Pushed
  to from the workflow using the built-in `GITHUB_TOKEN` with `packages: write`.
- **ACR — `<acr-name>.azurecr.io/housing-notes-*`** — the registry AKS pulls
  from and where image/malware scanning happens. Pushed to using the OIDC
  identity (which has push rights via its `Contributor` role on the app RG, or an
  explicit `AcrPush` binding created by Terraform).

The same image content is pushed to both; ACR is authoritative for what runs.
Use the real ACR name (§2.2) consistently everywhere.

## 6. Terraform remote state

The backend is **already provisioned** (§8). `/infra` must declare it explicitly
with these exact values:

- Resource group: `housing-notes-tfstate-rg`
- Storage account: `hnotestf3909`
- Container: `tfstate`
- Key: `housing-notes.tfstate`
- Auth: OIDC against the storage account (`use_oidc = true`, `use_azuread_auth
  = true`); **no storage account keys**.

Local-only state is **not** acceptable — CI must apply reliably and repeatably.
The building agent must **point at** this backend, not create it.

## 7. Pipeline shape (reference)

The detailed, phased build of the pipeline lives in `BUILD_DIRECTIVE.md`. As a
reference, the end-state pipeline does, in order:

1. **CI** (all triggers) — install, lint, typecheck, test, build (backend and
   frontend). Safe on PRs and branches; no Azure access.
2. **Security gate (Pass 2 onward, `main` only)** — Snyk SAST, SCA, IaC, and
   container scans. High/Critical findings **stop the run** before any deploy.
3. **Build & push images (`main` only)** — to GHCR (public mirror) and ACR
   (authoritative). ACR image/malware scanning applies; a failing image does not
   roll out.
4. **Infrastructure (`main` only)** — `terraform apply` against the remote
   backend (§6) to ensure AKS, ACR, and the AcrPull binding exist.
5. **Deploy (`main` only)** — idempotently ensure the nginx ingress controller
   is present, then apply `/k8s` and roll out the new images.

Steps 2–5 run only on `main` and only if the prior gate passes. There is no
human approval step.

## 8. Bootstrap — what's already done, and what remains

The one-time Azure trust and state backend were provisioned via Azure Cloud
Shell. **Completed:**

1. ✅ Application resource group `housing-notes-rg`.
2. ✅ User-assigned managed identity `housing-notes-deployer`.
3. ✅ Federated credential `github-main`
   (`repo:atirado-snyk/greenfield:ref:refs/heads/main`).
4. ✅ `Contributor` on `housing-notes-rg`.
5. ✅ Bootstrap resource group `housing-notes-tfstate-rg`, storage account
   `hnotestf3909`, blob container `tfstate`.
6. ✅ `Storage Blob Data Contributor` for the deployer on `hnotestf3909`.
7. ✅ GitHub secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
   `AZURE_SUBSCRIPTION_ID`.

**Remaining before the first deploy can fully apply:**

- ⬜ Grant the deployer **`Role Based Access Control Administrator`** on
  `housing-notes-rg` (see §3 — required for Terraform to create the AcrPull
  binding). One command in Cloud Shell:

  ```
  az role assignment create `
    --assignee-object-id <deployer-principalId> `
    --assignee-principal-type ServicePrincipal `
    --role "Role Based Access Control Administrator" `
    --scope "/subscriptions/<sub-id>/resourceGroups/housing-notes-rg"
  ```

Why the bootstrap is out-of-band: the pipeline authenticates *as* the deployer
identity and writes state to the backend. Neither the identity nor its own state
store can be created by the pipeline that depends on them — so they are
provisioned once, by hand, and excluded from Terraform's managed scope.

After the remaining grant and the first successful run, subsequent pushes to
`main` are fully automated.

## 9. Related documents

- **`SPEC.md`** — what the system is and the architecture this realises.
- **`BUILD_DIRECTIVE.md`** — the two-pass instructions that build this pipeline.
- **`CLAUDE.md`** — conventions and delivery rules.
