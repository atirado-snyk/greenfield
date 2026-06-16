# Housing Notes

A minimal "Resident Notes" board. Users submit a note, the backend caches it in
memory, and the frontend renders the current list of notes. No database.

## Stack
- **Backend** — Node.js + TypeScript (Express), in-memory cache
- **Frontend** — React + TypeScript (Vite)
- **Infrastructure** — Terraform (Azure AKS)
- **Containers** — Docker + Kubernetes manifests
- **CI/CD** — GitHub Actions

## Project structure
```
/backend  — Express API (in-memory note cache)
/frontend — React + Vite app
/infra    — Terraform modules for Azure AKS
/k8s      — Kubernetes manifests
```

## Development

Install dependencies in each package, then:

```bash
# Backend (default port 3000)
cd backend && npm run dev

# Frontend (default port 5173)
cd frontend && npm run dev
```

The frontend proxies `/api` to the backend during development.

## Configuration

All configuration is read from environment variables. See `backend/.env.example`.

| Variable      | Default | Description                          |
| ------------- | ------- | ------------------------------------ |
| `PORT`        | `3000`  | Backend HTTP port                    |
| `AUTH_TOKEN`  | _unset_ | Optional bearer token for the API    |

## Operations

### Bootstrap (one-time Azure setup)

`bootstrap.ps1` provisions the one-time "trust" layer that the CI/CD pipeline
depends on but cannot create for itself: the deployer managed identity and its
GitHub OIDC federated credential (scoped to `main`), the required role
assignments, the Terraform remote-state backend, and the necessary resource
provider registrations. It is idempotent and parameterised, so it can rebuild
the environment from nothing or stand up a fresh one. Run it in Azure Cloud
Shell (PowerShell) as a user with Owner / User Access Administrator on the
subscription:

```powershell
./bootstrap.ps1 -SubscriptionId <sub-id> -SetGitHubSecrets
```

It prints the GitHub secret values and the exact Terraform backend block to wire
into `infra/providers.tf`. See [DEPLOY.md](DEPLOY.md) §8 for full detail and the
rationale for why this step is out-of-band.

### Get the application's public IP

The app is reached over the ingress controller's public LoadBalancer IP. After a
deploy, fetch it from the cluster (Azure Cloud Shell):

```powershell
az aks get-credentials --resource-group housing-notes-rg --name housing-notes-aks --overwrite-existing
kubectl get svc -n ingress-nginx ingress-nginx-controller -o wide
```

The address is in the `EXTERNAL-IP` column. If it shows `<pending>`, Azure is
still assigning it — re-run until an IP appears. Then the frontend is at
`http://<EXTERNAL-IP>/` and the API at `http://<EXTERNAL-IP>/api/notes`.

### Stop the cluster to avoid cost

Between demos, stop the AKS cluster to halt compute billing while preserving the
cluster and its workloads:

```powershell
az aks stop --resource-group housing-notes-rg --name housing-notes-aks
```

Bring it back when needed (takes a few minutes):

```powershell
az aks start --resource-group housing-notes-rg --name housing-notes-aks
```

To remove the application infrastructure entirely (zero ongoing cost; a fresh
deploy will provision a new IP), run `terraform destroy` in `/infra` or delete
the `housing-notes-rg` resource group. This does not affect the bootstrap trust
layer or the Terraform state backend, which live in separate scope.

## Documentation

This repository is both a working application and a teaching artifact. The
governing documents describe what it is, how it is built, and how it is
deployed:

- **[SPEC.md](SPEC.md)** — what the system is, the target architecture, the
  single production environment, and the demo scenarios. Start here.
- **[BUILD_DIRECTIVE.md](BUILD_DIRECTIVE.md)** — the two-pass build order for the
  building agent: an honest baseline first, then Snyk security integration.
- **[DEPLOY.md](DEPLOY.md)** — the Azure deployment definition: OIDC/Workload
  Identity Federation, the GHCR and ACR registries, Terraform remote state, and
  ingress bootstrap.
- **[CLAUDE.md](CLAUDE.md)** — engineering and delivery conventions, loaded by
  the agent on every session.
