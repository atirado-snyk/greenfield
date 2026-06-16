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
