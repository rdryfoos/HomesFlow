# Research: HomesFlow MVP

**Feature**: `001-mvp` | **Date**: 2026-06-28

## Decisions

### D1 — Client platform

**Decision**: Native SwiftUI, iOS 17+, universal iPhone + iPad.

**Rationale**: PRD non-goals exclude web/Android. Constitution requires native iOS. SwiftUI gives adaptive layouts for iPad sidebar vs iPhone stack with one codebase.

**Alternatives rejected**: React Native (PRD says native); UIKit-only (slower to build adaptive UI).

---

### D2 — Backend

**Decision**: Supabase (PostgreSQL, Auth, Storage, Realtime, RLS).

**Rationale**: Clarify decision. Auth supports Apple + email/password. RLS maps cleanly to Owner/Manager/Guest per home. Realtime optional enhancement when online; offline handled client-side.

**Alternatives rejected**: Firebase (less SQL-friendly for relational home/membership model); custom API server (too much ops for solo MVP).

---

### D3 — Authentication

**Decision**: Supabase Auth with Sign in with Apple + email/password.

**Rationale**: Clarify decision. Apple required for App Store when offering email signup. Supabase handles session tokens; app stores session in Keychain.

**Alternatives rejected**: Apple-only (excludes users without Apple ID preference); custom auth (reinventing session management).

---

### D4 — Offline sync strategy

**Decision**: SwiftData local store + outbound mutation outbox; sync engine pushes outbox then pulls server changes since `last_synced_at`.

**Rationale**: NFR-OFFL-01 is non-negotiable. Supabase Realtime alone does not solve offline writes. Pattern: optimistic local write → queue → sync on connectivity.

**Conflict rules** (from PRD):
- Same field / whole-record conflict → latest `updated_at` wins; activity log + user notification (AC-SYNC-01).
- Different fields on same entity → merge both; audit combined update (AC-SYNC-02).
- Server rejects stale permission → revert local change (AC-SYNC-03).

**Alternatives rejected**: Online-only MVP (violates constitution); full CRDT (overkill for MVP).

---

### D5 — Local persistence library

**Decision**: SwiftData for cached entities and outbox records.

**Rationale**: First-party, SwiftUI-friendly, good enough for MVP cache. Models mirror Supabase tables with `@Attribute(.externalStorage)` for large blobs as needed.

**Alternatives rejected**: Core Data (more boilerplate); GRDB (extra dependency, fine for v2 if SwiftData limits hit).

---

### D6 — Push notifications

**Decision**: **Deferred.** Settings screen shows FR-NOTIF-01 toggle (disabled / “Coming soon”). No APNs entitlements in MVP build.

**Rationale**: Clarify decision. In-app activity log covers accountability for v1.

---

### D10 — UI reference & tab mapping

**Decision**: Figma site is non-authoritative visual reference. PRD + spec govern behavior. SwiftUI-native adaptive layouts (not web port).

**Home detail tabs** (inside a selected home):

| Tab (UI label) | Implements | Notes |
|----------------|------------|-------|
| Procedures | FR-PROC-* | Figma “Tasks” → Procedures in spec |
| Contacts | FR-HOME-02 | Service providers directory only |
| Files | FR-HOME-03 | Document library; UI label **Files** (not Documents) |
| People | FR-USER-* | Members, invites, roles (Owner) |

**iPad home detail (D10b)**: Three-panel layout on every section — leading sidebar (compact hero + vertical tabs) + nested list | detail in the trailing area (**AC-HOME-09…10**, **FR-NAV-01**). iPad **My Homes** dashboard cards are tall (~528pt) with vertically centered photos. Return to **My Homes** to switch homes.

**Launch screen (D10c)**: `LaunchLogo` ~1.5× size, tighter icon-to-wordmark spacing (engineering detail in dev-notes).

**Accessibility (D11)**: Dynamic Type, VoiceOver, Reduce Motion, and 44pt tap targets are MVP requirements (**NFR-A11Y-01**), not deferred polish.

**Out of MVP UI scope from prototype**: per-step assignees.

### D7 — File storage

**Decision**: Supabase Storage buckets: `home-photos`, `procedure-attachments`, `documents`. Paths scoped by `home_id`. RLS via storage policies tied to membership role.

**Rationale**: FR-HOME-01 photos, FR-PROC-03 attachments, FR-HOME-03 documents all need binary storage.

---

### D8 — Testing

**Decision**: XCTest for sync logic, permissions, and conflict resolution; XCUITest for critical flows (sign-in, create home, update step, guest read-only).

**Rationale**: Constitution and traceability require AC-mapped tests. Sync unit tests highest ROI for offline ACs.

---

### D9 — Project layout

**Decision**: `ios/` Xcode project at repo root; `supabase/` for migrations and local dev config.

**Rationale**: Keeps Spec Kit docs at root; clear separation for GitHub Actions later (TestFlight).

---

### D11 — Debug vs Release Supabase targets (2026-06-28)

**Decision**: Two gitignored xcconfig files — `Secrets.xcconfig` (Debug → local Docker) and `Secrets.Release.xcconfig` (Release → Supabase Cloud). Wired in `ios/project.yml` via XcodeGen.

**Rationale**: Simulator dev stays on `127.0.0.1`; physical device / stakeholder demos require cloud URL (phone cannot reach Mac localhost). Prevents accidental shipping of local URL in Release builds.

**Alternatives rejected**: Single xcconfig switched manually (error-prone); environment plists in repo (secret leakage risk).

---

### D12 — Apple Sign-In & entitlements (2026-06-28, updated 2026-07-08)

**Decision (original)**: Email/password only for device builds while Personal Team signing blocked Apple entitlement.

**Update (2026-07-03)**: Paid Apple Developer Program active (Admin role).

**Update (2026-07-08)**: Apple Sign-In **shipped in app** — `HomesFlow.entitlements` restored; `SignInWithAppleButton` + `signInWithIdToken` in `SupabaseClientProvider`. Remaining ops: enable Apple provider on **cloud** Supabase (Services ID `com.rdryfoos.homesflow`, JWT secret from Apple Developer portal).

**Local dev**: Keep `[auth.external.apple] enabled = false` in `config.toml`; use email/password.

**Revisit before App Store**: Confirm cloud Apple provider + App Store Connect Sign in with Apple capability on production bundle ID.

---

### D13 — Bundle identifier (2026-06-28)

**Decision**: `com.rdryfoos.homesflow` (replaces planned `com.homesflow.app`).

**Rationale**: Global bundle ID `com.homesflow.app` unavailable on Apple's registry for developer's team.

---

### D14 — Auth session handling (2026-06-28)

**Decision**: `SupabaseClientProvider` sets session from sign-in/sign-up return value and subscribes to `authStateChanges`; do not rely solely on `try? await client.auth.session` immediately after sign-in.

**Rationale**: Observed silent sign-in failure on device when refresh dropped session before `isAuthenticated` updated.

---

## Open items (non-blocking for MVP)

| Item | Notes |
|------|-------|
| SMS invites (FR-GUEST-02) | MVP: shareable invite link + manual token paste (**AC-USER-07**); automated email/SMS deferred |
| Deep links (AC-GUEST-02) | Universal Links in v1.1; MVP uses paste-token invite accept + `homesflow://` share link only |
| Sentry / crash telemetry | Recommended before TestFlight; not blocking first implement pass |
