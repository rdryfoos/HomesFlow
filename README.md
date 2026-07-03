# HomesFlow

A home management app for owners of multiple properties who need to coordinate maintenance and usage with family or a caretaking team.

Also an honest experiment: can one bring serious product discipline and rigor to AI-assisted development and actually enjoy the process? Built spec-first, iteratively, with traceable requirements and proper verification & validation, because I've spent years watching teams skip the rigor, and I wanted to find out if AI assistance finally makes it very reasonable to craft high-quality code.

## Core documents

| Document | Role |
|----------|------|
| **[Story map](https://homeflow.storiesonboard.com/m/homeflow1)** (StoriesOnBoard) | Product planning view — releases, story slices, and what's next; feeds the PRD |
| **`HomesFlow.prd.md`** | Product requirements, user stories, acceptance criteria |
| **`.specify/memory/constitution.md`** | Non-negotiable architectural and process laws |
| **`traceability.md`** | How IDs flow from PRD → spec → tasks → code → tests |
| **`specs/001-mvp/dev-notes.md`** | Engineering operational notes (environments, signing, gaps) |

## Repository layout

```text
HomeFlow/
├── HomesFlow.prd.md              ← product truth (you write / maintain)
├── traceability.md              ← traceability mechanics
├── glossary.md                  ← domain terms
├── process.deprecated.rtf       ← archived process narrative (superseded by markdown above)
├── .specify/                    ← Spec Kit (templates, scripts, constitution)
│   └── memory/constitution.md   ← non-negotiable laws
├── ios/                         ← SwiftUI app (XcodeGen)
├── supabase/                    ← migrations + local config
└── specs/
    └── 001-mvp/                 ← active feature (spec → plan → tasks → code)
        ├── spec.md
        ├── plan.md              (after /speckit.plan)
        └── tasks.md             (after /speckit.tasks)
```

## Spec Kit workflow

Active feature: **`001-mvp`**

```bash
export SPECIFY_FEATURE=001-mvp
export SPECIFY_FEATURE_DIRECTORY=specs/001-mvp
```

| Step | Command | Output |
|------|---------|--------|
| 1 | `/speckit.specify` | Fills `specs/001-mvp/spec.md` from `HomesFlow.prd.md` |
| 2 | `/speckit.clarify` | Resolves open questions |
| 3 | `/speckit.plan` | `plan.md`, `research.md`, `data-model.md` |
| 4 | `/speckit.tasks` | `tasks.md` with `Traces:` fields |
| 5 | `/speckit.analyze` | Gate — must pass before coding |
| 6 | `/speckit.implement` | `ios/`, `supabase/` |

## Quality checks

- **Traceability (Gate 2, enforced)** — `bash scripts/check-traceability.sh --refresh` verifies the PRD → spec → tasks → `@covers` → tests golden thread; CI fails on every push if broken (`.github/workflows/traceability.yml`).
- **Static analysis (informational)** — [SonarCloud dashboard](https://sonarcloud.io/project/overview?id=rdryfoos_HomeFlow) analyzes pushes for code smells and security hotspots. Its quality gate is not yet enforced anywhere; review findings manually until it's wired into CI or branch protection.

## Run locally (Phase 0)

```bash
supabase start && supabase db reset
cp ios/HomeFlow/Resources/Secrets.xcconfig.example ios/HomeFlow/Resources/Secrets.xcconfig
# Paste SUPABASE_URL and SUPABASE_ANON_KEY from `supabase start` output
cd ios && xcodegen generate && open HomeFlow.xcodeproj
```

UI reference (non-authoritative): https://haze-rabbit-58180688.figma.site

**Before step 1:** Add durable IDs to requirements and ACs in `HomesFlow.prd.md` per `traceability.md` §3.

## What not to duplicate

- Do **not** maintain a separate root `spec.md` / `plan.md` — Spec Kit uses `specs/<feature>/`.
- Do **not** rewrite the PRD into the feature spec by hand — let `/speckit.specify` derive the feature slice.
