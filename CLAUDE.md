# Housing Notes — Claude Code Project Context

This file is the persistent context for the building agent. It carries the
engineering conventions for the project plus the delivery rules that govern how
code reaches production. For *what* the system is and *why*, read `SPEC.md`. For
the concrete Azure/registry/identity setup, read `DEPLOY.md`. For the
step-by-step build order, read `BUILD_DIRECTIVE.md`.

## Bash commands
- npm run build: Build all packages
- npm run typecheck: Run the TypeScript compiler check
- npm run lint: Run ESLint
- npm run test: Run the Jest test suite
- npm run dev: Start backend and frontend in development mode

## Project structure
- /backend  — Node.js + TypeScript Express API (in-memory note cache)
- /frontend — React + TypeScript Vite app
- /infra    — Terraform modules for Azure AKS
- /k8s      — Kubernetes manifests
- .github/workflows — GitHub Actions CI/CD

## Code style
- Use ES modules (import/export), not CommonJS (require)
- Destructure imports where possible
- Explicit TypeScript return types on functions
- No use of the `any` type
- React components are functional (arrow functions)

## Workflow
- Run typecheck after a series of code changes
- Run lint before committing
- Branch naming: feature/, fix/, chore/
- Prefer rebase over merge

## IMPORTANT
- Never hardcode secrets, credentials, or API keys in source files
- Read all configuration from environment variables via process.env
- YOU MUST typecheck before considering any task complete

---

## Delivery (CI/CD)

GitHub Actions is the single delivery system; it owns both CI and CD. There is
one production environment on Azure AKS and no manual approval step.

- **Trigger:** every push to `main` runs the full pipeline; if all gates pass it
  deploys to production.
- **CI stages:** install, lint, typecheck, test, build — for both backend and
  frontend.
- **Images:** build once, push to both registries —
  - **GHCR** (`ghcr.io/atirado-snyk/housing-notes-*`): public mirror for
    inspection, pushed with the built-in token (`packages: write`).
  - **ACR** (`housingnotesacr.azurecr.io/housing-notes-*`): the registry AKS
    pulls from. ACR is authoritative for what actually runs.
  - Image references in `/k8s` point at the **ACR** (`<acr-name>.azurecr.io/...`),
    the registry AKS pulls from — use the real, globally-unique ACR name
    consistently across `/infra`, `/k8s`, and the workflow (`DEPLOY.md` §2.2).
- **Azure auth:** Workload Identity Federation (OIDC). No long-lived Azure
  secret is ever stored or committed. The workflow uses
  `permissions: id-token: write` and the official Azure login action.
- **Infrastructure:** `terraform apply` runs against **remote** state (Azure
  storage backend). Never rely on local Terraform state in CI.
- **Cluster prerequisite:** the nginx ingress controller must be present in the
  cluster before the app ingress is applied. Treat its installation as an
  explicit deploy step, not an assumption.

## Building demo scenarios

When given a new requirement (the user stories in `SPEC.md` §7, or a fresh one
during a demo):

- Implement it **naturally**, following the conventions above.
- Build it the way you normally would, with no special effort to either
  introduce or avoid particular kinds of issues.
- Do not annotate the code or the repo with predictions about how it will be
  assessed.

## Related documents
- `SPEC.md` — system definition, architecture, demo scenarios
- `DEPLOY.md` — Azure, OIDC, registries, Terraform state, ingress bootstrap
- `BUILD_DIRECTIVE.md` — the two-pass build order for the agent
- `README.md` — short human-facing overview
