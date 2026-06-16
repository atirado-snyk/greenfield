# Housing Notes — Build Directive

These are the marching orders for the building agent (Claude Code). They define
**the order in which the system is built and deployed**, in two deliberate
passes. Read `SPEC.md` (what and why), `DEPLOY.md` (Azure/identity/registry
specifics), and `CLAUDE.md` (conventions) before starting and keep them open
throughout. Where any of those documents and this one disagree on *what* the
system is, `SPEC.md` wins; this document governs *sequence*.

## Why two passes

This repository is both a real deployed application and a teaching artifact
(`SPEC.md` §1). The commit history is part of the lesson. Pass 1 produces an
honest baseline — the application exactly as the agent naturally builds it, with
no security tooling and no deliberate hardening or sabotage. Pass 2 then
introduces Snyk, so a reader can see security scanning arrive and begin to govern
delivery against a genuine baseline.

Do **not** blend the passes. Pass 1 must land, build, and deploy on its own
before any Snyk work begins. Keep each pass to its own set of commits so the
history reads as a clear narrative.

---

## Pass 1 — Honest baseline (build + deploy, no Snyk)

**Goal:** a genuinely deployed, working Housing Notes application on Azure AKS,
built naturally, with the full GitHub Actions delivery loop — and **no security
tooling of any kind**.

### Scope

1. **Application** — implement the backend and frontend behaviour described in
   `SPEC.md` §2, following every convention in `CLAUDE.md`. In-memory storage for
   the baseline. Do not add product features that were not asked for.
2. **Containers** — Dockerfiles for backend and frontend, suitable for AKS.
3. **Infrastructure** (`/infra`) — Terraform that can stand the environment up
   from nothing: resource group, AKS, ACR, the `AcrPull` permission for the
   cluster, and a **remote** state backend (Azure storage). See `DEPLOY.md` §2,
   §6.
4. **Kubernetes** (`/k8s`) — Deployments for backend and frontend, a Service for
   each, and the ingress (`/` → frontend, `/api` → backend). Point image
   references at **ACR**, not the inherited `atiradonet` GHCR path.
5. **Delivery** (`.github/workflows`) — a single GitHub Actions pipeline that, on
   every push to `main`:
   - installs, lints, typechecks, tests, and builds both packages;
   - builds the images and pushes them to **both** GHCR (public mirror) and ACR
     (authoritative pull source);
   - authenticates to Azure via **OIDC / Workload Identity Federation** (no
     stored cloud secret);
   - runs `terraform apply` against remote state;
   - ensures the **nginx ingress controller** is present in the cluster, then
     applies `/k8s` and rolls out the new images.

### Rules for Pass 1

- **No Snyk. No other scanners. No security hardening beyond `CLAUDE.md`.** Do
  not add ignore files, gates, or "secure defaults" reflexively. Build it the way
  you normally would.
- **Do not introduce anything unsafe on purpose either.** The baseline must be a
  faithful picture of the natural output — neither hardened nor sabotaged.
- **Reconcile inherited references.** The upstream repo carries
  `ghcr.io/atiradonet/...` placeholders; update them for this fork and point the
  cluster at ACR (`DEPLOY.md` §5).
- **Typecheck before considering anything complete** (`CLAUDE.md`).

### Done when

- A push to `main` runs the pipeline green and the application is reachable
  through the ingress in the production AKS environment.
- The history contains a clean baseline the next pass can build on.

---

## Pass 2 — Snyk integration (dev-loop hooks + CI deploy gate)

**Goal:** introduce Snyk at **two distinct enforcement points**, following the
Snyk-recommended flow:

- **Developer loop (agent-side):** catch issues *as code is written*.
- **CI gate (pipeline backstop):** catch issues *before deploy*, protecting the
  production environment.

These are complementary — the hook shortens the feedback loop while the code is
being written; the CI gate is the backstop that guarantees nothing reaches
production unscanned, regardless of how the code arrived.

> Before relying on the exact commands and directive text below, verify them
> against current Snyk documentation (or AlphaPatch). Snyk's onboarding flow is
> the source of truth; the snippets here reflect guidance captured at authoring
> time and may have moved on.

### 2a. Developer-loop integration — **Hooks (default, recommended)**

Hooks fire automatically outside the agent loop, consume tokens only when a
vulnerability is found, always fire (deterministic), and run in parallel rather
than sequentially. This is the recommended mode and the default for this project.

Configure with the one-time setup:

```
npx -y snyk@latest mcp configure --tool=claude-cli
```

Behaviour once configured: the agent writes code → the hook fires → the Snyk CLI
scans in the background → if nothing is found the agent simply continues; if
issues are found the agent is interrupted and `/snyk-fix` remediates, then
re-scans.

#### Alternative — **Rules mode (fallback)**

Use Rules only for agents/ADEs that do not support hooks, or when you
deliberately want the scan/fix loop to be *visible in the agent transcript* (for
example, to demonstrate the loop live). Snyk positions Rules as a fallback that
is being phased out, so it is **not** the default here.

If using Rules, add directives of this form to `CLAUDE.md` (verify exact wording
against current Snyk guidance first):

- Always run the Snyk code-scan tool for new first-party code generated in a
  Snyk-supported language.
- If issues are found in newly introduced or modified code or dependencies,
  attempt to fix them using the Snyk results context.
- Re-scan after fixing to confirm the issues are resolved and that no new issues
  were introduced.
- Repeat until no new issues are found.

Trade-offs to keep in mind: Rules consume tokens at every step, run
sequentially, and are non-deterministic (the agent may skip the rule). They are
documented here as the alternative, not the recommendation.

### 2b. CI deploy gate — pipeline backstop

Add Snyk scanning to the GitHub Actions pipeline as the gate that protects
production, independent of the developer-loop hook.

- **All four scan types** run in the pipeline: SAST (code), SCA (dependencies),
  Container image scanning, and IaC scanning (Terraform + K8s).
- **High or Critical findings block the deploy.** Medium and below are reported
  but do not block.
- **Fail closed.** If the gate cannot complete, the deploy does not proceed.
- **ACR image/malware scanning is part of the gate:** an image that fails ACR
  scanning must not roll out to AKS.
- The gate runs **before** the build/push/infra/deploy steps from Pass 1, which
  now execute only if the gate passes.
- `SNYK_TOKEN` is provided as a GitHub secret (`DEPLOY.md` §4); reference it,
  never inline it.
- **Never neutralise the gate for convenience** — no lowering the threshold, no
  blanket ignore entries, no continue-on-error to force a green run. If the gate
  blocks, remediate the underlying finding properly. The integrity of the gate is
  the point.

### Rules for Pass 2

- Introduce the developer-loop integration and the CI gate as their own commits,
  distinct from the Pass 1 baseline, so the history shows security arriving.
- When the gate (or a hook) surfaces a real finding against the baseline, fix it
  properly — upgrade the dependency, correct the code, fix the IaC — rather than
  bypassing it.
- Defer to the official Snyk flow for exact configuration; this document
  specifies the *shape* (two enforcement points, four scan types, High/Critical
  blocking, fail-closed) rather than freezing commands that may change.

### Done when

- The developer-loop hook is configured and demonstrably scans on code
  generation.
- The CI pipeline runs all four scan types and blocks on High/Critical, fail
  closed, before any deploy step.
- Any genuine findings against the baseline have been remediated properly, and a
  clean push to `main` scans, passes, and deploys.

---

## After Pass 2 — demo scenarios

With both passes in place, the system is ready for live demonstration. A
presenter gives a requirement (the user stories in `SPEC.md` §7, or a fresh one)
via CLI, IDE, remote, or conversation, and the agent implements it naturally per
`CLAUDE.md`. The developer-loop hook reacts as code is written; the CI gate
reacts before deploy. Let both react on their own merits — do not pre-empt them
and do not annotate the repo with predictions about what they will flag.

## Related documents

- `SPEC.md` — system definition, architecture, demo scenarios
- `DEPLOY.md` — Azure, OIDC, registries, Terraform state, ingress bootstrap
- `CLAUDE.md` — engineering and delivery conventions
- `README.md` — short human-facing overview
