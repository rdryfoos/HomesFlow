# Tasks: HomeFlow MVP

**Input**: [spec.md](./spec.md) · [plan.md](./plan.md) · [data-model.md](./data-model.md) · [contracts/](./contracts/)

**Feature**: `001-mvp` | **Date**: 2026-06-28

**UI reference** (non-authoritative): https://haze-rabbit-58180688.figma.site — SwiftUI-native iPhone/iPad only.

## Format

- **Traces**: AC/FR/NFR ID(s) implemented
- **[P]**: Parallelizable
- **[US-*]**: User story label

---

## Phase 1: Setup

**Purpose**: Repo tooling and project skeleton

- [ ] T001 Create `ios/HomeFlow.xcodeproj` — universal iOS 17+ SwiftUI app target + unit/UI test targets per plan.md — **Traces**: plan Phase 0 (infrastructure)
- [ ] T002 [P] Initialize `supabase/` with `config.toml` and local dev setup per quickstart.md — **Traces**: plan Phase 0 (infrastructure)
- [ ] T003 [P] Add `.gitignore` entries for `Secrets.xcconfig`, DerivedData (verify ios secrets not committed) — **Traces**: NFR-SEC-01

---

## Phase 2: Foundational (blocking)

**Purpose**: Backend schema, auth, local cache, sync skeleton — **no user story UI until complete**

- [ ] T004 Write `supabase/migrations/001_initial_schema.sql` from data-model.md (enums, tables, indexes) — **Traces**: FR-HOME-01, FR-USER-01, FR-PROC-01
- [ ] T005 Implement RLS policies + `get_user_role()` per contracts/rls-permissions.md — **Traces**: FR-USER-01, FR-GUEST-01, AC-GUEST-02
- [ ] T006 [P] Configure Supabase Auth: Apple + email/password providers — **Traces**: FR-AUTH-01
- [ ] T007 [P] Create Supabase Storage buckets + policies (home-photos, documents, procedure-attachments) — **Traces**: FR-HOME-01, FR-HOME-03, FR-PROC-03
- [ ] T008 Implement `ios/HomeFlow/Core/Supabase/SupabaseClientProvider.swift` + Keychain session — **Traces**: FR-AUTH-01, NFR-SEC-01
- [ ] T009 Define SwiftData models mirroring server tables + `MutationOutbox` in `ios/HomeFlow/Core/Models/` — **Traces**: NFR-OFFL-01
- [ ] T010 Implement `PermissionService` matching RLS matrix in `ios/HomeFlow/Core/Permissions/` — **Traces**: FR-USER-01, AC-PROC-02, AC-GUEST-02
- [ ] T011 Implement `SyncEngine` skeleton (outbox enqueue, push, pull, revert-on-deny) in `ios/HomeFlow/Core/Sync/` — **Traces**: NFR-OFFL-01, AC-SYNC-01, AC-SYNC-02, AC-SYNC-03
- [ ] T012 Implement `ActivityLogService` append + fetch in `ios/HomeFlow/Core/ActivityLog/` — **Traces**: FR-LOG-01
- [ ] T013 Wire `AppRouter` + root auth gate in `ios/HomeFlow/App/` — **Traces**: FR-AUTH-01

**Checkpoint**: Sign-in works; empty authenticated shell loads; migrations apply cleanly.

---

## Phase 3: User Story — Auth & dashboard (P1)

**Goal**: Sign in, see home list — **US-ADMIN-01** (partial)

### Implementation

- [ ] T014 [US-ADMIN-01] Auth screens: email/password sign-up, sign-in, Sign in with Apple in `ios/HomeFlow/Features/Auth/` — **Traces**: FR-AUTH-01
- [ ] T015 [US-ADMIN-01] Dashboard home list view (SwiftUI) — cards with name, location, open-procedure count placeholder in `ios/HomeFlow/Features/Dashboard/` — **Traces**: FR-HOME-01
- [ ] T016 [P] [US-ADMIN-01] Adaptive layout: iPhone `NavigationStack`, iPad `NavigationSplitView` shell for dashboard — **Traces**: NFR-PERF-01

### Tests

- [ ] T017 [P] [US-ADMIN-01] XCUITest: sign-in with email → dashboard visible — **Traces**: FR-AUTH-01

---

## Phase 4: User Story — Admin creates/edits home (P1)

**Goal**: Home CRUD + offline home edit — **US-ADMIN-01**

### Implementation

- [ ] T018 [US-ADMIN-01] Home create/edit form + validation in `ios/HomeFlow/Features/HomeSetup/` — **Traces**: AC-HOME-01, AC-HOME-02, FR-HOME-01
- [ ] T019 [US-ADMIN-01] Home photo pick + upload to Supabase Storage — **Traces**: AC-HOME-01, FR-HOME-01
- [ ] T020 [US-ADMIN-01] Home edit offline + sync conflict (timestamp wins + activity log) — **Traces**: AC-HOME-03, AC-SYNC-01, FR-LOG-01
- [ ] T021 [P] [US-ADMIN-01] Home detail header (name, address) + tab bar shell (Procedures | Contacts | Documents | People) — **Traces**: FR-HOME-01

### Tests

- [ ] T022 [P] [US-ADMIN-01] Unit test `test_AC_HOME_01_valid_home_created` — **Traces**: AC-HOME-01
- [ ] T023 [P] [US-ADMIN-01] Unit test `test_AC_HOME_02_invalid_home_rejected` — **Traces**: AC-HOME-02
- [ ] T024 [US-ADMIN-01] Unit test `test_AC_HOME_03_offline_edit_conflict_logged` — **Traces**: AC-HOME-03

---

## Phase 5: User Story — Admin invites & roles (P1)

**Goal**: Invites, memberships, role enforcement — **US-ADMIN-02**, **US-ADMIN-03**

### Implementation

- [ ] T025 [US-ADMIN-02] Invite flow: create/revoke invite token, email invite link in `ios/HomeFlow/Features/Members/` — **Traces**: AC-USER-01, AC-USER-02, FR-GUEST-02, FR-USER-02
- [ ] T026 [US-ADMIN-02] Accept invite → create membership with role — **Traces**: AC-USER-01
- [ ] T027 [US-ADMIN-02] Offline invite conflict resolution — **Traces**: AC-USER-03, AC-SYNC-01
- [ ] T028 [US-ADMIN-03] Members list (People tab) + role assignment UI — **Traces**: AC-USER-04, AC-USER-05, AC-USER-06, FR-USER-02
- [ ] T029 [US-ADMIN-03] Role change sync + audit entry for prior role — **Traces**: AC-USER-06, FR-LOG-01

### Tests

- [ ] T030 [P] [US-ADMIN-02] Unit test `test_AC_USER_01_invite_accepted_grants_role` — **Traces**: AC-USER-01
- [ ] T031 [P] [US-ADMIN-02] Unit test `test_AC_USER_02_revoked_token_invalid` — **Traces**: AC-USER-02
- [ ] T032 [US-ADMIN-03] Unit test `test_AC_USER_04_edit_role_can_modify_procedures` — **Traces**: AC-USER-04
- [ ] T033 [US-ADMIN-03] Unit test `test_AC_USER_05_guest_role_read_only` — **Traces**: AC-USER-05
- [ ] T033a [P] [US-ADMIN-02] Unit test `test_AC_USER_03_offline_invite_conflict` — **Traces**: AC-USER-03
- [ ] T033b [US-ADMIN-03] Unit test `test_AC_USER_06_concurrent_role_change_audit` — **Traces**: AC-USER-06

---

## Phase 6: User Story — Offline sync (P1, cross-cutting)

**Goal**: Reliable offline writes and conflict rules — **NFR-OFFL-01**

### Implementation

- [ ] T034 [NFR-OFFL-01] Network reachability → trigger `SyncEngine.run()` on reconnect in `ios/HomeFlow/Core/Sync/` — **Traces**: AC-SYNC-01
- [ ] T035 [NFR-OFFL-01] Field-level merge for non-conflicting offline edits — **Traces**: AC-SYNC-02
- [ ] T036 [NFR-OFFL-01] Stale-permission revert + user-facing error — **Traces**: AC-SYNC-03
- [ ] T037 [P] [NFR-OFFL-01] In-app conflict/overwrite notification banners — **Traces**: AC-SYNC-01, AC-PROC-03, AC-HOME-05

### Tests

- [ ] T038 [P] [NFR-OFFL-01] Unit test `test_AC_SYNC_01_offline_overwrite_notifies_loser` — **Traces**: AC-SYNC-01
- [ ] T039 [P] [NFR-OFFL-01] Unit test `test_AC_SYNC_02_disjoint_fields_merge` — **Traces**: AC-SYNC-02
- [ ] T040 [NFR-OFFL-01] Unit test `test_AC_SYNC_03_stale_permission_reverts` — **Traces**: AC-SYNC-03

**Checkpoint**: P1 stories independently testable.

---

## Phase 7: User Story — Edit user procedures (P2)

**Goal**: Procedure list, steps, status updates — **US-EDIT-01**

### Implementation

- [ ] T041 [US-EDIT-01] Procedures list with progress (e.g. 2/6) in `ios/HomeFlow/Features/Procedures/` — **Traces**: FR-PROC-01, FR-PROC-02
- [ ] T042 [US-EDIT-01] Procedure detail: step checklist, status toggle, N/A option — **Traces**: FR-PROC-02, AC-PROC-01
- [ ] T043 [US-EDIT-01] Step notes + photo attach (Storage) — **Traces**: FR-PROC-03
- [ ] T044 [US-EDIT-01] Block step update when permission insufficient — **Traces**: AC-PROC-02
- [ ] T045 [US-EDIT-01] Offline step conflict + notification — **Traces**: AC-PROC-03, AC-SYNC-01
- [ ] T046 [P] [US-EDIT-01] Recent activity section on procedure detail — **Traces**: FR-LOG-01, AC-PROC-01
- [ ] T047 [P] [US-EDIT-01] iPad: procedure list + detail columns — **Traces**: NFR-PERF-01

### Tests

- [ ] T048 [P] [US-EDIT-01] Unit test `test_AC_PROC_01_step_complete_creates_log` — **Traces**: AC-PROC-01
- [ ] T049 [P] [US-EDIT-01] Unit test `test_AC_PROC_02_permission_denied_blocks_update` — **Traces**: AC-PROC-02
- [ ] T050 [US-EDIT-01] Unit test `test_AC_PROC_03_offline_step_conflict` — **Traces**: AC-PROC-03

---

## Phase 8: User Story — Edit user service providers (P2)

**Goal**: Contacts tab = service provider directory — **US-EDIT-02**, **FR-HOME-02**

### Implementation

- [ ] T051 [US-EDIT-02] Service provider list + search in `ios/HomeFlow/Features/Providers/` (UI tab: Contacts) — **Traces**: FR-HOME-02, AC-HOME-04
- [ ] T052 [US-EDIT-02] Provider create/edit form (company, type, phone, website, hours, notes) — **Traces**: AC-HOME-04
- [ ] T053 [US-EDIT-02] Provider edit vs delete sync conflict — **Traces**: AC-HOME-05, AC-SYNC-01
- [ ] T054 [P] [US-EDIT-02] Tap phone → `tel:` link — **Traces**: FR-HOME-02

### Tests

- [ ] T055 [P] [US-EDIT-02] Unit test `test_AC_HOME_04_provider_edit_propagates` — **Traces**: AC-HOME-04
- [ ] T056 [US-EDIT-02] Unit test `test_AC_HOME_05_delete_wins_over_edit` — **Traces**: AC-HOME-05

---

## Phase 9: User Story — Guest access (P3)

**Goal**: Read-only guest views — **US-GUEST-01**, **US-GUEST-02**

### Implementation

- [ ] T057 [US-GUEST-01] Visibility filtering on providers, documents, procedures — **Traces**: AC-GUEST-01, FR-GUEST-01
- [ ] T058 [US-GUEST-01] Navigation guard: deny restricted content with message — **Traces**: AC-GUEST-02
- [ ] T059 [US-GUEST-01] Offline visibility sync — **Traces**: AC-GUEST-03
- [ ] T060 [US-GUEST-02] Guest procedure detail read-only (no status edits) — **Traces**: AC-GUEST-04
- [ ] T061 [US-GUEST-02] Reject guest step status change + audit unauthorized attempt — **Traces**: AC-GUEST-05, FR-LOG-01

### Tests

- [ ] T062 [P] [US-GUEST-01] Unit test `test_AC_GUEST_01_guest_fields_only` — **Traces**: AC-GUEST-01
- [ ] T063 [P] [US-GUEST-02] Unit test `test_AC_GUEST_05_unauthorized_step_rejected` — **Traces**: AC-GUEST-05
- [ ] T063a [P] [US-GUEST-01] Unit test `test_AC_GUEST_02_restricted_deep_link_denied` — **Traces**: AC-GUEST-02
- [ ] T063b [P] [US-GUEST-01] Unit test `test_AC_GUEST_03_offline_visibility_sync` — **Traces**: AC-GUEST-03
- [ ] T063c [P] [US-GUEST-02] Unit test `test_AC_GUEST_04_guest_procedure_read_only` — **Traces**: AC-GUEST-04
- [ ] T064 [US-GUEST-01] XCUITest: guest cannot edit provider — **Traces**: AC-GUEST-01, SC-03

---

## Phase 10: Documents, settings, polish (P3)

**Goal**: Document library, settings, deferred push UI — **FR-HOME-03**, **FR-NOTIF-01**

### Implementation

- [ ] T065 [FR-HOME-03] Documents list + upload + visibility in `ios/HomeFlow/Features/Documents/` — **Traces**: FR-HOME-03, AC-GUEST-01
- [ ] T066 [P] [FR-NOTIF-01] Settings screen: account, notification toggle disabled (“Coming soon”) in `ios/HomeFlow/Features/Settings/` — **Traces**: FR-NOTIF-01
- [ ] T067 [P] Settings: sign out clears session — **Traces**: FR-AUTH-01
- [ ] T068 Admin revoke member access → lose access on next sync — **Traces**: FR-USER-02

### Tests

- [ ] T069 [P] XCUITest end-to-end: sign-in → create home → invite → update step → guest read-only — **Traces**: SC-01, SC-02, SC-03

---

## Phase 11: Hardening

- [ ] T070 Run `/speckit.analyze` and fix all traceability violations — **Traces**: constitution traceability article
- [ ] T071 [P] RLS integration tests against contracts/rls-permissions.md — **Traces**: FR-USER-01, FR-GUEST-01
- [ ] T072 [P] Sync conflict matrix — target SC-04 (95% scripted scenarios) — **Traces**: SC-04, AC-SYNC-01, AC-SYNC-02, AC-SYNC-03, NFR-SYNC-01
- [ ] T072a [P] Performance smoke: screen load & sync latency baselines — **Traces**: NFR-PERF-01, NFR-SYNC-01
- [ ] T072b [P] Document NFR-SCALE-01 architecture assumptions in plan.md (no load test in MVP) — **Traces**: NFR-SCALE-01
- [ ] T072c [P] Enable Xcode crash report collection / document NFR-REL-01 monitoring path — **Traces**: NFR-REL-01
- [ ] T073 Update quickstart.md with any dev-setup deltas discovered during implement — **Traces**: plan Phase 0 (infrastructure)

---

## Dependencies

```text
Phase 1 → Phase 2 (blocking) → Phases 3–6 (P1, can overlap after T013)
Phase 6 checkpoint → Phases 7–8 (P2)
Phases 7–8 → Phases 9–10 (P3)
All → Phase 11
```

## MVP scope reminders

- No step assignees
- Contacts tab = service providers (FR-HOME-02) only
- Figma = visual reference; SwiftUI-native layouts
- Push notifications UI-only
