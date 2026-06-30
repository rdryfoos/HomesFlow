# Implementation Plan: HomeFlow MVP

**Branch**: `001-mvp` | **Date**: 2026-06-28 | **Spec**: [spec.md](./spec.md) | **Status**: [tasks.md](./tasks.md) · [dev-notes.md](./dev-notes.md)

## Implementation status (2026-06-28)

| Phase | Status | Notes |
|-------|--------|-------|
| 0 Foundation | **Done** | iOS project, Supabase schema, auth shell |
| 1 P1 homes/users | **Partial** | Home CRUD, photos, People tab; Procedures not started |
| 2 P2 procedures/providers | Not started | |
| 3 P3 guest/docs | Not started | |
| 4 Testing/hardening | Not started | |

**Deployed path validated**: Supabase Cloud + Release build on physical iPhone (`com.rdryfoos.homeflow`). Local Docker + Debug Simulator also supported. See [quickstart.md](./quickstart.md).

## Summary

Build a native iOS 17+ app (SwiftUI) backed by Supabase for second-home management: auth, multi-home dashboard, role-based access (Admin/Edit/Guest), procedures with step tracking, service providers, documents, activity log, and offline-first sync with timestamp-wins conflict resolution. Push notifications deferred; Settings toggle is UI-only.

## Technical Context

**Language/Version**: Swift 5.9+, iOS 17+  
**Primary Dependencies**: SwiftUI, SwiftData, supabase-swift, AuthenticationServices (Sign in with Apple)  
**Storage**: Supabase PostgreSQL + Storage; SwiftData local cache + mutation outbox  
**Testing**: XCTest (sync, permissions, conflicts), XCUITest (auth, home CRUD, procedure step, guest read-only)  
**Target Platform**: iPhone and iPad (adaptive SwiftUI)  
**Project Type**: Mobile app + managed backend (Supabase)  
**Performance Goals**: Screen load < 2s (NFR-PERF-01); sync round-trip < 1s when online (NFR-SYNC-01)  
**Constraints**: Offline-capable from day one (NFR-OFFL-01); RLS-enforced permissions; traceability IDs in tests  
**Scale/Scope**: MVP ~15–20 screens; 1 feature spec; 7 user stories; 26 acceptance criteria

## Constitution Check

| Principle | Plan compliance |
|-----------|-----------------|
| Spec-driven | Plan derived from `spec.md`; no code before tasks + analyze |
| Native iOS | SwiftUI universal app in `ios/` |
| Offline sync | SwiftData + outbox + sync engine (see research D4) |
| Role-based access | Supabase RLS + client-side UI gating |
| Traceability | Tests named `test_AC_*`; modules annotated `@covers` |

**Gate**: Pass — no violations requiring complexity tracking.

## Project Structure

### Documentation (this feature)

```text
specs/001-mvp/
├── spec.md
├── plan.md              ← this file
├── research.md
├── data-model.md
├── quickstart.md
├── dev-notes.md         ← implementation / deploy gotchas (not product spec)
├── contracts/
│   ├── sync-protocol.md
│   └── rls-permissions.md
└── tasks.md             ← task list (generated)
```

### Source Code (repository root)

```text
ios/
├── HomeFlow.xcodeproj      # generated via project.yml + xcodegen
├── project.yml
├── HomeFlow/
│   ├── App/
│   │   ├── HomeFlowApp.swift
│   │   └── AppRouter.swift
│   ├── Features/
│   │   ├── Auth/
│   │   ├── Dashboard/
│   │   ├── HomeSetup/
│   │   ├── HomeDetail/
│   │   ├── Members/            # People tab — invites (partial)
│   │   ├── Procedures/         # Phase 7 — not yet
│   │   ├── Providers/          # Phase 8 — not yet
│   │   ├── Documents/          # Phase 10 — not yet
│   │   └── Settings/           # Phase 10 — not yet
│   ├── Core/
│   │   ├── AppEnvironment.swift
│   │   ├── Models/
│   │   ├── Supabase/
│   │   ├── Sync/
│   │   ├── Home/               # HomeRepository, DTOs, conflict resolver
│   │   ├── Members/
│   │   ├── Storage/            # HomePhotoService
│   │   ├── Permissions/
│   │   └── ActivityLog/
│   └── Resources/
│       ├── Secrets.xcconfig.example          # Debug / local
│       ├── Secrets.Release.xcconfig.example  # Release / cloud
│       └── HomeFlow.entitlements             # Apple Sign-In deferred
├── HomeFlowTests/
└── HomeFlowUITests/

supabase/
├── config.toml
├── migrations/
│   ├── 001_initial_schema.sql
│   └── 002_storage_profiles_invites.sql
└── seed.sql
```

**Structure Decision**: Single iOS app + Supabase backend folder. No separate API server — client talks to Supabase directly with RLS. Feature folders map to user stories for independent delivery.

## Implementation Phases

### Phase 0 — Foundation

1. Create Xcode project (`ios/`) — universal iPhone/iPad, SwiftUI lifecycle
2. Add Supabase project + `supabase/` migrations from `data-model.md`
3. Configure Auth providers: Apple + email/password
4. SwiftData model definitions mirroring server tables + outbox
5. Supabase client wrapper + Keychain session storage

**Exit criteria**: User can sign up/in; empty dashboard loads.

### Phase 1 — P1 stories (homes, users, sync core)

| Story | Key deliverables | AC IDs |
|-------|------------------|--------|
| US-ADMIN-01 | Home CRUD, dashboard, photo upload | AC-HOME-01…03 |
| US-ADMIN-02/03 | Invites, membership roles, member list | AC-USER-01…06 |
| NFR-OFFL-01 | Outbox, pull sync, conflict handler | AC-SYNC-01…03 |

**Exit criteria**: Admin creates home offline, syncs; invites Edit user; conflict produces activity log entry.

### Phase 2 — P2 stories (procedures, providers)

| Story | Key deliverables | AC IDs |
|-------|------------------|--------|
| US-EDIT-01 | Procedure list, step checklist, status updates | AC-PROC-01…03 |
| US-EDIT-02 | Provider directory, search, edit | AC-HOME-04…05 |

**Exit criteria**: Edit user updates step; Admin sees change after sync; provider edit/delete conflict handled.

### Phase 3 — P3 stories (guest, documents, polish)

| Story | Key deliverables | AC IDs |
|-------|------------------|--------|
| US-GUEST-01/02 | Guest-scoped views, read-only procedures | AC-GUEST-01…05 |
| FR-HOME-03 | Document library with visibility | AC-GUEST-01…03 |
| FR-NOTIF-01 | Settings toggle (disabled, “Coming soon”) | deferred |
| FR-LOG-01 | Activity log screen for Admin | all audit ACs |

**Exit criteria**: Guest cannot edit; unauthorized step attempt logged; SC-03 manual review pass.

### Phase 4 — Testing & hardening

- XCTest: sync conflict matrix (SC-04 — 95% scripted scenarios)
- XCUITest: sign-in → create home → invite → update step → guest read-only
- RLS policy verification against `contracts/rls-permissions.md`

## UI Architecture

**Authority**: PRD + spec. [Figma prototype](https://haze-rabbit-58180688.figma.site) is visual reference only — implement with native SwiftUI patterns, not as a web port.

**iPhone**: `NavigationStack` — dashboard (home list) → **push** via `NavigationLink` to home detail with segmented control: **Procedures | Contacts | Documents | People**. Do **not** bind `List(selection:)` on iPhone (blocks push). App-level Settings via toolbar or tab (Settings screen Phase 10).

**iPad**: `NavigationSplitView` — sidebar uses `List(selection:)`; detail column shows selected home. Use `horizontalSizeClass == .regular` to branch layouts.

**Home detail tab mapping**:

| UI label | Spec term | FR |
|----------|-----------|-----|
| Procedures | Procedures | FR-PROC-* |
| Contacts | Service providers | FR-HOME-02 |
| Documents | Documents | FR-HOME-03 |
| People | Members | FR-USER-* |

**MVP exclusions**: step assignees; separate key-contacts entity.

**State**: `@Observable` view models per feature; inject `SyncEngine`, `AuthService`, `PermissionService`.

## Sync Engine (high level)

```text
User action → write SwiftData (optimistic) → enqueue outbox
     ↓
Network available → SyncEngine.run()
     1. Push outbox FIFO (respect updated_at)
     2. On 409/conflict: apply timestamp-wins; write activity_log; notify UI
     3. Pull rows where updated_at > last_synced_at
     4. Merge non-conflicting fields (AC-SYNC-02)
     5. On permission denied: revert local row (AC-SYNC-03)
```

See [contracts/sync-protocol.md](./contracts/sync-protocol.md).

## Risk / mitigations

| Risk | Mitigation |
|------|------------|
| Offline + RLS complexity | Unit-test sync engine heavily; keep outbox logic pure Swift |
| Scope creep | FR-NOTIF-01, SMS invites, deep links explicitly deferred |
| SwiftData + Supabase drift | Single source schema in `data-model.md`; codegen DTOs from migrations |
| Debug vs Release config drift | Separate `Secrets.xcconfig` / `Secrets.Release.xcconfig`; verify Build Settings before device deploy |
| Personal Team signing | Bundle ID `com.rdryfoos.homeflow`; Apple Sign-In entitlement deferred until paid program |

## Complexity Tracking

> No constitution violations. Table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
