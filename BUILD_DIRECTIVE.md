> **⚠️ SUPERSEDED — historical reference only.**
>
> This document was the original scaffold directive used to create the honest
> baseline of Housing Notes on a personal account. It has been **superseded by
> the structured project documents** and should not be followed directly.
>
> Use these instead:
> - **`SPEC.md`** — what the system is, the target architecture, and demo scenarios
> - **`DEPLOY.md`** — Azure, OIDC, registries, Terraform state, ingress bootstrap
> - **`CLAUDE.md`** — engineering and delivery conventions
> - **`BUILD_DIRECTIVE.md`** — the two-pass build order (baseline, then Snyk)
>
> It is retained for reference because the repository is a teaching artifact: it
> shows where the project started before being generalized into the current
> structure. The intent it captured — build an honest baseline naturally, with
> nothing planted, before introducing security tooling — now lives in
> `BUILD_DIRECTIVE.md` (Pass 1).

---

# Claude Code Scaffold Directive — Housing Notes Demo (natural build)
*Repo:* git@github.com:atiradonet/greenfield.git

*RUN THIS BEFORE installing Snyk Studio*

This produces an honest baseline: the app exactly as Claude Code builds it, with nothing planted. Snyk scans what the model actually emits. Do NOT install or configure Snyk first.

You are scaffolding a greenfield SaaS web application. Keep the application logic
deliberately simple: a "Resident Notes" board. A user types a note, submits it,
the backend caches it in memory, and the frontend renders the current list of
notes. No database. Build it the way you normally would, following the project
conventions in CLAUDE.md. Do not deliberately introduce or avoid security issues
— just build it cleanly and naturally.

## Stack
- Backend: Node.js + TypeScript (Express), in-memory cache (a plain array)
- Frontend: React + TypeScript (Vite)
- Infrastructure: Terraform (Azure AKS)
- Containers: Docker + Kubernetes manifests
- CI/CD: GitHub Actions
- Package manager: npm

---

## Step 1 — Create CLAUDE.md at repo root

```
# Housing Notes — Claude Code Project Context

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
- .github/workflows — GitHub Actions CI

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
```

---

## Step 2 — File and folder structure

```
/
├── CLAUDE.md
├── .gitignore
├── README.md
├── .github/workflows/ci.yml
├── backend/
│   ├── package.json
│   ├── tsconfig.json
│   ├── Dockerfile
│   └── src/
│       ├── index.ts           # Express server, mounts routes, /health
│       ├── config.ts          # reads config from process.env
│       ├── cache.ts           # in-memory notes array + get/add
│       ├── routes/notes.ts    # GET /notes, POST /notes
│       └── middleware/auth.ts # bearer-token check stub
├── frontend/
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   ├── Dockerfile
│   └── src/
│       ├── main.tsx
│       ├── App.tsx
│       └── components/NoteBoard.tsx  # input + submit + render list
├── infra/
│   ├── providers.tf
│   ├── main.tf            # resource group + AKS cluster
│   ├── variables.tf
│   └── outputs.tf
└── k8s/
    ├── backend-deployment.yaml
    ├── frontend-deployment.yaml
    └── ingress.yaml
```

---

## Step 3 — Application behaviour (keep it minimal)

- Backend `cache.ts`: a module-level `notes: string[]` array with `getNotes()`
  and `addNote(text: string)`. That is the entire backend state.
- Backend `routes/notes.ts`:
  - `GET /notes` returns the array as JSON
  - `POST /notes` reads `{ text }` from the body, calls `addNote`, returns 201
    with the updated list
- Backend `index.ts`: Express app reading the port from config, JSON body
  parser, mounts the notes router, a `/health` endpoint returning 200, basic
  error middleware.
- Frontend `NoteBoard.tsx`: a text input, a submit button, and the rendered
  list. POST on submit, GET on mount, handle loading/error.
- One Jest test on the backend (e.g. addNote appends to the cache) so the CI
  `test` job has something to run.
- Infra: a standard Terraform config for a working Azure resource group and AKS
  cluster with one node pool, variables with sensible defaults.
- K8s: standard Deployments for backend and frontend (2 replicas each, image
  placeholders `ghcr.io/atiradonet/...`), and an ingress routing / to frontend
  and /api to backend.

Build all of the above to a normal, working standard. Do not add extra security
hardening beyond the CLAUDE.md conventions, and do not introduce anything unsafe
on purpose. The goal is a faithful picture of what this stack looks like as
scaffolded — nothing more, nothing less.

---

## Step 4 — Dependencies

Write each `package.json` with explicit pinned versions you consider appropriate
for this stack, from your own knowledge. **Do NOT run `npm install`** — this is a
scaffold-only pass; the manifests will be reviewed before anything is installed.

---

## Step 5 — Final checks (scaffold only)

1. Run `npm run typecheck` for backend and frontend; fix type errors only.
2. Ensure .gitignore excludes node_modules, .env, dist, *.tfstate,
   *.tfstate.*, *.tfvars, .terraform/.
3. Confirm CLAUDE.md exists at repo root.
4. Do NOT install dependencies, do NOT run the app, and do NOT install or
   configure Snyk.
5. Report what was created and list the files.
