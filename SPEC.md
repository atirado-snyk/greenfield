# Housing Notes — System Specification

This is the authoritative description of **what** the Housing Notes system is,
the architecture it targets, the environment it runs in, and the rules that
govern its delivery. It does not prescribe implementation detail — that is the
job of the build directive (`BUILD_DIRECTIVE.md`) and the conventions in
`CLAUDE.md`. When this document and an implementation disagree, this document
wins.

---

## 1. Purpose

Housing Notes is two things at once, and both matter equally:

1. **A real, deployed application.** It runs in production on Azure. It is not a
   toy that lives only on a laptop — the full path from a code change to a
   running container behind an ingress is real and exercised on every push.
2. **A faithful security demonstration.** The repository and its commit history
   are meant to teach. A customer reading this repo, or watching a live demo,
   should be able to see an honest baseline application and then see security
   scanning (Snyk) introduced and begin to govern delivery — without anything
   being staged, planted, or rigged.

These two purposes constrain each other in a productive way: because the app is
genuinely deployed, the security findings (if any) are genuinely real; and
because the demo must be honest, the app must be built naturally rather than
sabotaged to produce a dramatic result.

## 2. The application

A minimal "Resident Notes" board for a housing context.

- A resident submits a short note.
- The backend stores submitted notes.
- The frontend renders the current list of notes.

The application logic is deliberately simple. The value of this project is in
the **delivery loop and the security posture around it**, not in product
complexity. Implementations should resist the urge to add product features that
were not asked for.

### Behaviour (baseline)

- The backend exposes an HTTP API to list notes and to add a note, plus a health
  endpoint for orchestration probes.
- A note is text. Empty or whitespace-only submissions are rejected.
- The frontend loads the current notes on mount, lets the user submit a new
  note, and reflects the updated list. It handles loading and error states.
- State storage in the baseline is in-memory. Persistence is intentionally **not**
  part of the baseline; it may arrive later as a demo scenario (see §7), at
  which point the architecture in §4 is expected to evolve.

## 3. Stack

- **Backend** — Node.js + TypeScript (Express)
- **Frontend** — React + TypeScript (Vite)
- **Infrastructure** — Terraform, targeting Azure
- **Runtime** — Docker images orchestrated by Kubernetes (Azure Kubernetes
  Service)
- **CI/CD** — GitHub Actions (a single system owns both continuous integration
  and continuous deployment)
- **Security** — Snyk (introduced in delivery Pass 2; see §6 and
  `BUILD_DIRECTIVE.md`)
- **Package manager** — npm

## 4. Target architecture

```
            +-----------------------------------------------+
            |                  GitHub                        |
            |   source -> GitHub Actions (CI + CD) -> images |
            +-------------------+----------------------------+
                                |  build, scan, push, deploy
                                v
   +------------+        +--------------------------------------+
   |   GHCR     |        |              Azure                    |
   | (open      |        |  +------------+   +----------------+  |
   |  mirror of |<------>|  |    ACR     |   |      AKS        |  |
   |  images)   |        |  | (AKS pulls |   | (single prod   |  |
   +------------+        |  |  + image   |-->|  environment)  |  |
                         |  |  scanning) |   |                |  |
                         |  +------------+   | ingress (nginx)|  |
                         |                   |  / -> frontend |  |
                         |                   |  /api -> back  |  |
                         |                   +----------------+  |
                         +--------------------------------------+
```

### Component responsibilities

- **GitHub Actions** is the only delivery system. CI (lint, typecheck, test,
  build) and CD (image build/push, infrastructure, deploy) live together.
- **Image storage is dual**, by deliberate design:
  - **GHCR** holds an openly viewable mirror of the images so the demo audience
    can inspect them without Azure access.
  - **ACR** is the registry AKS actually pulls from, and is also where
    **container image scanning (including malware scanning) is performed** as
    part of the Azure-side posture. This split is intentional and is itself part
    of what the demo teaches.
- **AKS** runs a **single production environment**. There is no separate staging
  or dev environment.
- **Ingress** routes `/` to the frontend and `/api` to the backend.

### Infrastructure expectations

The infrastructure definition must be complete enough to stand the environment
up from nothing. At minimum it provisions the resource group, the AKS cluster,
the ACR, the permission for AKS to pull from ACR, and it must account for the
ingress controller actually running in the cluster (the ingress manifest assumes
an nginx controller is present). Terraform state must be stored remotely so that
automation can apply it reliably; local-only state is not acceptable for a system
that deploys from CI. Concrete provider, naming, and credential details are
specified in `DEPLOY.md`.

## 5. Environments and triggers

- **One environment:** production, on AKS.
- **Deploy trigger:** every push to `main` runs the full pipeline and, if it
  passes all gates, deploys to production.
- There is no manual approval step and no release-tag gating. The security gate
  (§6) is the control that protects production, not human sign-off.

## 6. Security gate (governs delivery from Pass 2 onward)

Security scanning is introduced in delivery Pass 2 (see `BUILD_DIRECTIVE.md`).
Once present, it governs every push.

- **Scanners:** all four Snyk scan types are in scope —
  - **SAST** (first-party code)
  - **SCA** (open-source dependencies)
  - **Container** image scanning
  - **IaC** scanning (Terraform / Kubernetes manifests)
- **Blocking threshold:** a finding of **High or Critical** severity **blocks
  the deploy**. The pipeline must fail closed — if the gate cannot complete, the
  deploy does not proceed.
- **Lower severities** (Medium and below) are reported but do not block.
- **Container/malware scanning** performed in ACR is part of this gate: an image
  that fails ACR scanning must not be rolled out to AKS.
- The gate is **real**. It is never configured to pass artificially for the sake
  of a smoother demo. If it blocks, the finding is addressed properly.

## 7. Demo scenarios

These are the requirements a presenter may give to the building agent (Claude
Code) during a live demonstration, via CLI, IDE, remote, or conversation. They
are written as plain user stories, exactly as a product owner or resident would
express them. They contain **no implementation guidance and no security hints**.

The implementing agent should build each one naturally, following the project
conventions, with no special effort to either introduce or avoid security
issues. Whether the security gate (§6) reacts to a given change is determined
solely by what the natural implementation actually contains.

### Scenario A — Edit a note
> As a resident, I want to correct a note I already submitted, so that I can fix
> a typo without deleting it and starting over.

**Acceptance:** an existing note can be changed in place; the list reflects the
updated text.

### Scenario B — Remove a note
> As a building manager, I want to take down a note, so that outdated or
> inappropriate notices don't stay on the board.

**Acceptance:** a note can be removed; it no longer appears in the list.

### Scenario C — Notes survive a restart
> As a resident, I want the notes to still be there after the system restarts,
> so that nothing is lost when maintenance happens.

**Acceptance:** notes persist across a full restart of the backend.

### Scenario D — Sign the note
> As a resident, I want to put my name on a note, so that neighbours know who
> posted it.

**Acceptance:** a note can carry an author name, shown alongside the note text.

### Scenario E — Attach a photo
> As a resident, I want to attach a photo to a note, so that I can show the thing
> I'm describing (for example a broken gate).

**Acceptance:** a note can include an image, which is viewable from the board.

### Scenario F — Search the board
> As a building manager, I want to search notes by keyword, so that I can quickly
> find a specific notice.

**Acceptance:** entering a search term narrows the list to matching notes.

> Presenter note: these stories are intentionally open. Do not annotate the repo
> with predictions about what any scenario "should" trigger. Let the gate speak
> for itself.

## 8. Non-goals

- Not a production-grade product with real residents or real data.
- No authentication/identity system beyond what the baseline naturally includes.
- No multi-environment promotion pipeline.
- No deliberately planted vulnerabilities, and no deliberate hardening beyond the
  conventions in `CLAUDE.md`. The point is fidelity, not theatre.

## 9. Related documents

- **`BUILD_DIRECTIVE.md`** — the two-pass instructions to the building agent.
- **`DEPLOY.md`** — the concrete deployment definition (Azure, OIDC, registries,
  state, ingress bootstrap).
- **`CLAUDE.md`** — engineering conventions and the security-gate rules the agent
  must follow.
- **`README.md`** — short human-facing overview.
