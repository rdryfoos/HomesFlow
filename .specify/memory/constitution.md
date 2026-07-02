# HomesFlow Constitution

Non-negotiable laws for this codebase. Product requirements live in `HomesFlow.prd.md`. Traceability mechanics live in `traceability.md`.

## Core Principles

### I. Spec-Driven Development (NON-NEGOTIABLE)

No production code without an approved feature spec, plan, and tasks under `specs/`. Run `/speckit.analyze` and resolve all violations before `/speckit.implement`.

### II. Native iOS First

HomesFlow ships as a native iOS app (Swift / SwiftUI) for iPhone and iPad. No Android, web, or desktop in the initial release (per PRD non-goals).

### III. Offline-Capable Sync (NON-NEGOTIABLE)

Local caching and offline sync are core from day one. Conflict resolution follows the PRD: most-recent timestamp wins; users are notified when their offline change is overwritten.

### IV. Role-Based Access

Every data operation respects Owner / Manager / Guest roles per home. UI and API must fail closed — insufficient permission blocks the action with a clear message.

### V. End-to-End Traceability (NON-NEGOTIABLE)

Every FR, NFR, and AC carries a durable ID assigned at the PRD level (`<TYPE>-<DOMAIN>-<NN>`). Each AC is atomic and maps to at least one automated test. Every task in `tasks.md` declares `Traces: <ID>`. `/speckit.analyze` MUST report zero traceability violations before implementation.

Full mechanics: `traceability.md`.

### VI. Accessible by Design

UI MUST respect iOS accessibility settings — especially Dynamic Type, VoiceOver, Reduce Motion, and sufficient contrast. Layouts MUST remain usable at all supported content size categories (**NFR-A11Y-01**). Accessibility is MVP scope, not post-launch polish.

## Technology Constraints

- **Client**: Swift / SwiftUI (iOS)
- **Backend**: Supabase (PostgreSQL, auth, real-time sync) — see `specs/001-mvp/dev-notes.md` for rationale
- **Process**: Spec Kit (`.specify/`, `specs/`)
- **Testing**: XCTest / XCUITest when source exists

## Hierarchy of Truth

When documents conflict, higher layers win:

1. This constitution (`.specify/memory/constitution.md`)
2. `glossary.md`
3. `HomesFlow.prd.md` (product requirements and AC registry)
4. `specs/<feature>/spec.md` (feature slice derived from PRD)
5. `specs/<feature>/plan.md` and `tasks.md`
6. Source code

## Governance

Amendments require a version bump and brief rationale. Traceability mechanics live in `traceability.md`; engineering and toolchain notes in `specs/001-mvp/dev-notes.md`. Neither overrides this file or the PRD.

**Version**: 1.1.0 | **Ratified**: 2026-06-28 | **Last Amended**: 2026-07-01
