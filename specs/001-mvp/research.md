# Research: HomeFlow MVP

**Feature**: `001-mvp` | **Date**: 2026-06-28

## Decisions

### D1 — Client platform

**Decision**: Native SwiftUI, iOS 17+, universal iPhone + iPad.

**Rationale**: PRD non-goals exclude web/Android. Constitution requires native iOS. SwiftUI gives adaptive layouts for iPad sidebar vs iPhone stack with one codebase.

**Alternatives rejected**: React Native (PRD says native); UIKit-only (slower to build adaptive UI).

---

### D2 — Backend

**Decision**: Supabase (PostgreSQL, Auth, Storage, Realtime, RLS).

**Rationale**: Clarify decision. Auth supports Apple + email/password. RLS maps cleanly to Admin/Edit/Guest per home. Realtime optional enhancement when online; offline handled client-side.

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
| Documents | FR-HOME-03 | Visibility-scoped library |
| People | FR-USER-* | Members, invites, roles (Admin) |

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

## Open items (non-blocking for MVP)

| Item | Notes |
|------|-------|
| SMS invites (FR-GUEST-02) | MVP: email invite via Supabase Auth magic link or invite token URL; SMS deferred |
| Deep links (AC-GUEST-02) | Universal Links in v1.1; MVP uses in-app navigation only |
| Sentry / crash telemetry | Recommended before TestFlight; not blocking first implement pass |
