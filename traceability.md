# HomesFlow — Traceability Standard (Durable IDs)

Purpose: guarantee an unbroken chain from PRD requirement → spec → task → code → test, so that coverage and scope are *machine-checkable* rather than maintained by hand.

This file is the single source of mechanics. The short, non-negotiable **principle** belongs in the Spec Kit constitution (`.specify/memory/constitution.md`); everything else lives here and is referenced from there.

---

## 1. Where each piece lives

| Layer | Artifact | Holds |
|---|---|---|
| Principle | `.specify/memory/constitution.md` | The non-negotiable rule, written verifiably so `/speckit.analyze` can enforce it. |
| Mechanics | this file (`traceability.md`) | ID grammar, the chain, test naming, CI behavior. |
| Structure | `.specify/templates/spec-template.md`, `tasks-template.md` | Required ID fields so IDs are mandatory structure, not afterthoughts. |
| Gate 1 (pre-build) | `/speckit.analyze` | Constitutional check: ACs without tasks, tasks without IDs, etc. |
| Gate 2 (post-build) | `scripts/check-traceability.sh` + `.github/workflows/ci.yml` | Greps tests + source for IDs, diffs against the registry, fails on orphans. |

Rationale: the constitution is read by every Spec Kit phase but should stay stable. Keep volatile detail (regex, script) out of it so you tweak conventions without amending your "supreme law."

---

## 2. Constitution principle (paste-ready)

Add this as an article in `constitution.md` (or feed it to `/speckit.constitution`). It is written to be *verifiable*, which is what makes `/analyze` able to enforce it.

> ### Article: End-to-End Traceability (NON-NEGOTIABLE)
>
> Every functional requirement, non-functional requirement, and acceptance criterion carries a durable unique ID of the form `<TYPE>-<DOMAIN>-<NN>` (e.g. `FR-LOG-01`, `AC-OFFL-03`). IDs are assigned once at the PRD level and are never reused or renumbered; retired IDs are tombstoned, not recycled.
>
> 1. Each acceptance criterion is **atomic** — one independently testable assertion — and maps to at least one automated test.
> 2. Every task in `tasks.md` MUST declare the ID(s) it implements via a `Traces:` field.
> 3. Every test name MUST encode the AC ID it verifies (e.g. `test_AC_OFFL_03_no_silent_regression`). Every source module implementing a requirement MUST carry a `@covers <ID>` annotation.
> 4. Coverage is **bidirectional** and machine-checked: no acceptance criterion without a test (a *gap*), and no feature-level test or requirement-bearing module without a referenced ID (*untraced scope*). CI fails the build on either.
> 5. `/speckit.analyze` MUST report zero traceability violations before `/speckit.implement` runs.

---

## 3. ID scheme

**Grammar:** `<TYPE>-<DOMAIN>-<NN>` — regex `^(FR|NFR|AC|US)-[A-Z]{2,6}-\d{2,}$`

- **TYPE** — `US` user story · `FR` functional requirement · `NFR` non-functional requirement · `AC` acceptance criterion.
- **DOMAIN** — short uppercase area code. Suggested for HomeFlow: `AUTH`, `USER`, `HOME`, `PROC`, `LOG`, `GUEST`, `NOTIF`, `OFFL`, `SYNC`, `A11Y`, `NAV`.
- **NN** — zero-padded sequence within (TYPE, DOMAIN), starting `01`.

**Rules**

- Assign IDs **once, at the PRD level.** Feature specs inherit the subset of PRD IDs they implement — they never mint their own. (Spec Kit fans out into numbered per-feature `spec.md` folders; minting per-feature would collide.)
- IDs are immutable. Reword the text freely; never repoint an ID to a different meaning.
- Retire, don't reuse: a removed requirement's ID is marked retired and never reissued.
- ACs are children of an FR and inherit its domain: `FR-OFFL-02` → `AC-OFFL-02a`, `AC-OFFL-02b`, … OR a flat `AC-OFFL-NN` registry cross-referenced to its FR. Pick one and keep it consistent.

---

## 4. The traceability chain

```
PRD requirement (FR-OFFL-02)
  └─ acceptance criterion (AC-OFFL-03)   ← atomic, one assertion
       └─ spec.md                        ← carries the ID
            └─ tasks.md task              ← "Traces: AC-OFFL-03"
                 └─ commit / PR           ← references task + ID
                      └─ source module    ← "// @covers AC-OFFL-03"
                           └─ test          ← test_AC_OFFL_03_no_silent_regression
```

Because the ID is a literal string at every hop, the whole matrix is a `grep`, not a spreadsheet.

---

## 5. Atomic acceptance criteria

A test maps cleanly to an AC only when the AC asserts one thing. Compound ACs silently turn a 1:1 mapping into 1:N and make the coverage report lie.

**Split compound ACs before `/speckit.specify` ingests the PRD.** Example from the offline status-update criterion, which bundles four assertions:

| ID | Atomic assertion |
|---|---|
| `AC-OFFL-03a` | Offline status change syncs on reconnect, ordered by server arrival. |
| `AC-OFFL-03b` | Sync is idempotent — a flaky reconnect never double-applies. |
| `AC-OFFL-03c` | A change that would regress a Complete/N/A step does not apply silently. |
| `AC-OFFL-03d` | A genuine status disagreement surfaces as a flagged conflict for human resolution. |

Each row is now one test.

---

## 6. Enforcement

**Gate 1 — `/speckit.analyze` (before `/speckit.implement`).** With the principle in the constitution, analyze flags: ACs with no task, tasks with no `Traces:`, and IDs that don't match the grammar. Run it every time before implementing.

**Gate 2 — CI traceability check (after implementation).** Implemented as `scripts/check-traceability.sh`, run locally or by CI (`.github/workflows/ci.yml`) on every push/PR. A small script that:

1. Parses the ID registry from the PRD/spec (the authoritative ID list).
2. Scans test names for `AC-[A-Z]+-\d+` and source for `@covers <ID>`.
3. **Fails the build** if either direction has an orphan:
   - an AC ID with no matching test → **gap**
   - a feature test / `@covers` ID not in the registry → **untraced scope** (your scope-creep tripwire — useful given this PRD already grew a log-book feature mid-stream).

Per-ID status is **generated on demand** (`bash scripts/check-traceability.sh --json`). A human-readable **portfolio snapshot** lives in `specs/001-mvp/coverage.md` (regenerate with `--matrix` before hiring or release pushes; not CI-enforced for freshness).

---

## 7. Template edits (make IDs mandatory structure)

Spec Kit templates are just markdown — edit them so IDs can't be skipped.

- **`.specify/templates/spec-template.md`** — give requirements and acceptance-criteria sections an explicit `ID` field; add **Intended Use** and **Risk & failure modes** sections per `traceability.md` §9.3; add a line: "Every requirement and AC MUST have an ID per `traceability.md`."
- **`.specify/templates/tasks-template.md`** — add a required `Traces:` field to the per-task structure so every generated task names the AC(s) it satisfies.

After this, the structure carries the rule forward automatically on every new feature.

---

## 8. One-time setup checklist

1. Tag every requirement and AC in the PRD with an ID (§3); split compound ACs (§5). This produces the authoritative **ID registry**.
2. Add the Article (§2) to `constitution.md`.
3. Edit the two templates (§7).
4. Add the CI coverage script (§6, Gate 2).
5. From here, run `/speckit.specify` → `/speckit.clarify` → `/speckit.plan` → `/speckit.tasks` → `/speckit.analyze` (must be clean) → `/speckit.implement`.

---

## 9. Lightweight design controls (ISO 13485 / IEC 62304 inspired)

HomesFlow is **not** a medical device and does **not** target ISO 13485 or IEC 62304 certification. This section borrows the **useful discipline** — traceability, verification, validation, release evidence — without audit binders or SOUP dossiers.

### 9.1 Standard clause map

| ISO 13485 §7.3 / IEC 62304 | HomesFlow artifact | Gate or evidence |
|---|---|---|
| Design planning | `specs/<feature>/plan.md`, `tasks.md` | `/speckit.plan`, `/speckit.tasks` |
| Design inputs (user needs) | `HomesFlow.prd.md`, `spec.md` (intended use, ACs) | `/speckit.specify` |
| Risk management (lightweight) | `spec.md` → **Risk & failure modes** (§9.3) | Human review at `/speckit.analyze` |
| Architectural / detailed design | `plan.md`, `data-model.md`, source structure | Plan approval before implement |
| Design outputs | `ios/`, `supabase/migrations/` | Git commits, PR review |
| Design verification | XCTest, Gate 2 traceability | `check-traceability.sh`; CI green |
| Design validation | XCUITest, manual/exploratory sessions | Tasks **T064**, **T069**, **T069a** (§9.4) |
| Design transfer / release | `specs/<feature>/release-checklist.md` | Pre-TestFlight / pre-prod sign-off (§9.5) |
| Change control | Spec Kit workflow + immutable IDs | No `/speckit.implement` until analyze clean; ID tombstones only |
| DHF / objective evidence | Git history, `coverage.md` snapshot, CI logs, release checklist | Auditable chain per §4 |

### 9.2 Verification vs validation (keep explicit)

| Activity | Question | HomesFlow practice |
|---|---|---|
| **Verification** | Did we build it **right**? | Unit tests name AC IDs; `@covers` on source; Gate 2 matrix |
| **Validation** | Did we build the **right thing** for real users? | XCUITest journeys, guest read-only checks, accessibility pass, structured manual sessions on device |

Verification is largely **automated today**. Validation is **tracked debt** until T064/T069/T069a land — not optional polish (§9.4).

### 9.3 Risk notes (per feature)

Every `spec.md` MUST include a **Risk & failure modes** section (see `.specify/templates/spec-template.md`). Keep it short — typically 3–8 bullets:

```markdown
## Risk & failure modes

| Failure | User impact | Mitigation / trace |
|---------|-------------|-------------------|
| Guest edits step offline | Unauthorized state change | Permission gate + AC-GUEST-05; activity log |
| Sync conflict on procedure step | Lost or surprising status | Timestamp-wins + user notification AC-PROC-03, AC-SYNC-01 |
```

No separate FMEA spreadsheet required unless scope or harm potential grows. Link mitigations to FR/AC IDs so they enter the golden thread.

### 9.4 Validation debt (not “nice to have”)

These tasks are **design validation** work — equivalent to IEC 62304 system testing and ISO 13485 validation evidence:

| Task | Validates |
|---|---|
| **T064** | Guest cannot edit restricted content (SC-03) |
| **T069** | End-to-end Owner → invite → step update → guest read-only (SC-01…03) |
| **T069a** | Accessibility under real iOS settings (AC-A11Y-01…03) |
| **T072** | Sync conflict matrix — 95% scripted scenarios (SC-04) |

Leave them unchecked in `tasks.md` until done; do not ship a milestone release without updating the release checklist (§9.5) for known validation gaps.

### 9.5 Release checklist

Before TestFlight, staging demo, or production promotion, complete [`specs/<feature>/release-checklist.md`](specs/001-mvp/release-checklist.md):

- Migrations pushed; secrets configured for target environment
- Unit tests + Gate 2 traceability green
- Known issues and open validation tasks documented
- Rollback / revert plan noted (app version, migration downgrade policy)

This is IEC 62304 **software release** thinking without a formal anomaly list binder.

### 9.6 DHF artifact summary

| Design control | Repository artifact | Objective evidence |
|---|---|---|
| Governance & language | `constitution.md`, `glossary.md` | Version-controlled laws and domain terms |
| User needs | `HomesFlow.prd.md`, `specs/<feature>/spec.md` | Intended use, personas, ACs, risk notes |
| Design inputs | `specs/<feature>/plan.md` | Data models, API contracts, tasks |
| Design outputs | Source + migrations | Signed Git commits |
| Design verification | XCTest | CI logs; `@covers` + `test_AC_*` per §6 |
| Design validation | XCUITest + exploratory | E2E logs; qualitative user-flow confirmation |

**Example flow** (winterization checklist): constitution requires auditable cross-user changes → spec defines personas and ACs → plan proposes Supabase tables, RLS, SwiftUI → verified by XCTest → validated by XCUITest / manual sessions on device.
