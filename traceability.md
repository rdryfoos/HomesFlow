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
| Gate 2 (post-build) | `scripts/check-traceability.sh` + `.github/workflows/traceability.yml` | Greps tests + source for IDs, diffs against the registry, fails on orphans. |

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

**Gate 2 — CI coverage check (after implementation).** Implemented as `scripts/check-traceability.sh`, run locally or by CI (`.github/workflows/traceability.yml`) on every push/PR. A small script that:

1. Parses the ID registry from the PRD/spec (the authoritative ID list).
2. Scans test names for `AC-[A-Z]+-\d+` and source for `@covers <ID>`.
3. Emits a coverage matrix (`scripts/check-traceability.sh --matrix` → `specs/001-mvp/coverage.md`, freshness-checked in CI) and **fails the build** if either direction has an orphan:
   - an AC ID with no matching test → **gap**
   - a feature test / `@covers` ID not in the registry → **untraced scope** (your scope-creep tripwire — useful given this PRD already grew a log-book feature mid-stream).

Keep the matrix **generated**, never hand-maintained.

---

## 7. Template edits (make IDs mandatory structure)

Spec Kit templates are just markdown — edit them so IDs can't be skipped.

- **`.specify/templates/spec-template.md`** — give requirements and acceptance-criteria sections an explicit `ID` field, and add a line: "Every requirement and AC MUST have an ID per `traceability.md`."
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

## 9. Design controls mapping (DHF-aligned practice)

The repo maps classical design-control concepts to concrete artifacts and objective evidence. **Verification** asks whether implementation matches specified requirements; **validation** asks whether users can achieve the intended use.

| Design control | Repository artifact | Objective evidence |
|---|---|---|
| Governance & language | `constitution.md`, `glossary.md` | Version-controlled laws and domain terms used across specs, plans, and tests |
| User needs | `HomesFlow.prd.md`, `specs/<feature>/spec.md` | Intended use, personas, acceptance criteria, risk notes |
| Design inputs | `specs/<feature>/plan.md` | Data models, API contracts, task breakdown under constitution + glossary constraints |
| Design outputs | Source code + migrations | Signed Git commits implementing the approved plan |
| Design verification | XCTest unit/integration suites | CI test logs; `@covers` + `test_AC_*` naming per §6 |
| Design validation | XCUITest + exploratory testing | E2E logs; qualitative feedback that critical flows work for real users |

**Example flow** (winterization checklist): a constitution rule requires auditable cross-user state changes → the feature spec defines personas and ACs → `/speckit.plan` proposes Supabase tables, RLS, and SwiftUI structure → implementation is verified by XCTest and validated by XCUITest / manual sessions.

Feature specs SHOULD call out intended use and material failure modes where relevant; trace those through plan, code, and tests using the ID chain in §4.
