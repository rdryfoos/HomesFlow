# HomesFlow

Native iOS app for managing a second home — built with Spec Kit.

## Core documents

| Document | Role |
|----------|------|
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
