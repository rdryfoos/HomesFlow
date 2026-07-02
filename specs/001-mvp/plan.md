# Implementation Plan: HomesFlow MVP

**Branch**: `001-mvp` | **Date**: 2026-06-28 | **Spec**: [spec.md](./spec.md) | **Status**: [tasks.md](./tasks.md) · [dev-notes.md](./dev-notes.md)

## Implementation status (2026-06-28)

| Phase | Status | Notes |
|-------|--------|-------|
| 0 Foundation | **Done** | iOS project, Supabase schema, auth shell |
| 1 P1 homes/users | **Partial** | Home CRUD, photos, People tab; Procedures mostly done; iPad nav shell + accessibility pending |
| 2 P2 procedures/providers | **Partial** | Procedures UI; step structure T047a–c; Contacts tab next |
| 3 P3 guest/docs | Not started | Files tab (UI label), Settings, guest views |
| 4 Testing/hardening | Not started | |

**Deployed path validated**: Supabase Cloud + Release build on physical iPhone (`com.rdryfoos.homeflow`). Local Docker + Debug Simulator also supported. See [quickstart.md](./quickstart.md).

## Summary

Build a native iOS 17+ app (SwiftUI) backed by Supabase for second-home management: auth, multi-home dashboard, role-based access (Owner/Manager/Guest), procedures with step tracking, service providers, documents, activity log, and offline-first sync with timestamp-wins conflict resolution. Push notifications deferred; Settings toggle is UI-only.

## Technical Context

**Language/Version**: Swift 5.9+, iOS 17+  
**Primary Dependencies**: SwiftUI, SwiftData, supabase-swift, AuthenticationServices (Sign in with Apple)  
**Storage**: Supabase PostgreSQL + Storage; SwiftData local cache + mutation outbox  
**Testing**: XCTest (sync, permissions, conflicts), XCUITest (auth, home CRUD, procedure step, guest read-only)  
**Target Platform**: iPhone and iPad (adaptive SwiftUI)  
**Project Type**: Mobile app + managed backend (Supabase)  
**Performance Goals**: Screen load < 2s (NFR-PERF-01); sync round-trip < 1s when online (NFR-SYNC-01)  
**Constraints**: Offline-capable from day one (NFR-OFFL-01); RLS-enforced permissions; traceability IDs in tests; accessibility first-class (**NFR-A11Y-01**)  
**Scale/Scope**: MVP ~15–20 screens; 1 feature spec; 7 user stories; 26 acceptance criteria

## Constitution Check

| Principle | Plan compliance |
|-----------|-----------------|
| Spec-driven | Plan derived from `spec.md`; no code before tasks + analyze |
| Native iOS | SwiftUI universal app in `ios/` |
| Offline sync | SwiftData + outbox + sync engine (see research D4) |
| Role-based access | Supabase RLS + client-side UI gating |
| Accessibility | Dynamic Type, VoiceOver, Reduce Motion per **NFR-A11Y-01** |
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
│   │   ├── HomeDetail/         # Section shell (FR-NAV-01)
│   │   ├── Members/            # People tab — invites (partial)
│   │   ├── Procedures/         # Phase 7
│   │   ├── Providers/          # Phase 8 — Contacts tab
│   │   ├── Documents/          # Phase 10 — Files tab (UI label)
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
| US-ADMIN-01 | Home CRUD, dashboard, photo upload, home section navigation | AC-HOME-01…03, AC-HOME-09…11, FR-NAV-01 |
| US-ADMIN-02/03 | Invites, membership roles, member list | AC-USER-01…06 |
| NFR-OFFL-01 | Outbox, pull sync, conflict handler | AC-SYNC-01…03 |

**Exit criteria**: Owner creates home offline, syncs; invites Manager user; conflict produces activity log entry.

### Phase 2 — P2 stories (procedures, providers)

| Story | Key deliverables | AC IDs |
|-------|------------------|--------|
| US-EDIT-01 | Procedure list, step checklist, status + structure updates | AC-PROC-01…07 |
| US-EDIT-02 | Provider directory, search, edit | AC-HOME-04…05 |

**Exit criteria**: Manager user updates step; Owner sees change after sync; provider edit/delete conflict handled.

### Phase 3 — P3 stories (guest, documents, polish)

| Story | Key deliverables | AC IDs |
|-------|------------------|--------|
| US-GUEST-01/02 | Guest-scoped views, read-only procedures | AC-GUEST-01…05 |
| FR-HOME-03 | Files library (document entity) with visibility | AC-GUEST-01…03 |
| FR-NOTIF-01 | Settings toggle (disabled, “Coming soon”) | deferred |
| FR-LOG-01 | Activity log screen for Owner | all audit ACs |

**Exit criteria**: Guest cannot edit; unauthorized step attempt logged; SC-03 manual review pass.

### Phase 4 — Testing & hardening

- XCTest: sync conflict matrix (SC-04 — 95% scripted scenarios)
- XCUITest: sign-in → create home → invite → update step → guest read-only
- RLS policy verification against `contracts/rls-permissions.md`
- Accessibility: Dynamic Type, VoiceOver, Reduce Motion manual pass (**AC-A11Y-01…03**)

## UI Architecture

**Authority**: PRD + spec. [Figma prototype](https://haze-rabbit-58180688.figma.site) is visual reference only — implement with native SwiftUI patterns, not as a web port.

### Home section labels (all devices — **FR-NAV-01**, **AC-HOME-11**)

| UI label | Spec term | FR | Suggested SF Symbol |
|----------|-----------|-----|---------------------|
| Procedures | Procedures | FR-PROC-* | `checklist` |
| Contacts | Service providers | FR-HOME-02 | `person.crop.circle` |
| Files | Documents | FR-HOME-03 | `folder` |
| People | Memberships | FR-USER-02 | `person.2` |

Icons are illustrative; choose equivalent symbols if accessibility labels remain clear (**AC-A11Y-02**).

### iPhone layout

```text
NavigationStack
  My Homes — full-bleed hero cards → push to home detail
    Home detail
      ├─ Full-bleed home hero (photo, name, address)
      ├─ Segmented control: Procedures | Contacts | Files | People
      └─ Section content
```

Do **not** bind `List(selection:)` on iPhone with `NavigationLink` (blocks push). App-level Settings via toolbar (Phase 10).

### iPad layout (**AC-HOME-09**, **AC-HOME-10**)

```text
My Homes (dashboard) — home list; select a home to enter home detail
  iPad dashboard cards: ~528pt tall, vertically centered photo, name + address/city-state

Home detail — NavigationSplitView (regular horizontal size class)
  Column 1 — Leading sidebar (~260–320 pt)
    ├─ Compact home hero (photo, name, address, sync badge)
    ├─ "All Homes" → returns to dashboard
    └─ Vertical section tabs (icon + label)
         Procedures / Contacts / Files / People

  Columns 2 + 3 — Trailing area (nested NavigationSplitView per section)
    ├─ Section list (middle) — e.g. procedures, contacts, files, members
    └─ Section detail (right) — e.g. checklist, contact detail, file preview, member detail
```

Every section (**Procedures**, **Contacts**, **Files**, **People**) uses the same three-panel pattern on iPad. The trailing area has **no** home-level hero or horizontal tab bar (**AC-HOME-09**).

The leading column is **not** a persistent home picker while viewing home detail (**FR-NAV-01**, T021c).

**Dashboard**: Full-bleed photo hero cards with name/address overlay (FR-HOME-01). iPhone ~152pt; iPad ~528pt with vertically centered photos. Unsynced homes indicated (AC-SYNC-04).

**Launch screen**: `LaunchLogo` @1x/@2x/@3x on black (`LaunchBackground`); wordmark ~1.5× prior size, reduced gap between green house icon and **HomesFlow** text.

### Procedure detail (trailing column on iPad; below tabs on iPhone)

| Gesture / control | Action | Roles |
|-------------------|--------|-------|
| Tap step row | Toggle complete ↔ not started | Owner, Edit |
| Long-press step | Context menu: Rename, Delete, Move Up, Move Down | Owner, Edit |
| Note icon | Edit step notes | Owner, Edit |
| ⋯ menu | Set status (In progress, N/A, etc.) | Owner, Edit |
| Steps section **Add** | Create new step at end | Owner, Edit |
| (none) | Read-only steps and status | Guest |

### Accessibility (**NFR-A11Y-01**)

- Dynamic Type–friendly fonts; `@ScaledMetric` for fixed layout elements where needed.
- Test at **Extra Large** and largest **Accessibility** content sizes (**AC-A11Y-01**).
- Section tabs: meaningful `accessibilityLabel` + selected state (**AC-A11Y-02**).
- Minimum **44×44 pt** hit targets for tabs and primary actions.
- Honor `@Environment(\.accessibilityReduceMotion)` (**AC-A11Y-03**).

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
| Scope creep | FR-NOTIF-01, SMS invites, deep links explicitly deferred; MVP invites = share link + token paste (AC-USER-07) |
| SwiftData + Supabase drift | Single source schema in `data-model.md`; codegen DTOs from migrations |
| Debug vs Release config drift | Separate `Secrets.xcconfig` / `Secrets.Release.xcconfig`; verify Build Settings before device deploy |
| Personal Team signing | Bundle ID `com.rdryfoos.homeflow`; Apple Sign-In entitlement deferred until paid program |

## Complexity Tracking

> No constitution violations. Table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
