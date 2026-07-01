# Tasks: HomeFlow MVP

**Input**: [spec.md](./spec.md) · [plan.md](./plan.md) · [data-model.md](./data-model.md) · [contracts/](./contracts/)

**Feature**: `001-mvp` | **Updated**: 2026-07-01

**UI reference** (non-authoritative): https://haze-rabbit-58180688.figma.site — SwiftUI-native iPhone/iPad only.

## Implementation status

| Phase | Progress | Blocker / next |
|-------|----------|----------------|
| 1–2 Setup + foundation | **Complete** | — |
| 3–4 Auth, dashboard, homes | **Mostly complete** | XCUITest T017 |
| 5 Invites & roles | **Partial** | Deep links T026; offline conflict T027; unit tests |
| 6 Offline sync | **Partial** | Field merge T035; full sync tests |
| 7 Procedures | **Mostly complete** | Photo attach T043 |
| 8–10 P2/P3 features | Not started | Contacts tab next |
| 11 Hardening | Not started | Re-run analyze after P1 checkpoint |

Partial deliverables documented in [dev-notes.md](./dev-notes.md). **Do not** encode implementation details in [spec.md](./spec.md).

## Format

- **Traces**: AC/FR/NFR ID(s) implemented
- **[P]**: Parallelizable
- **[US-*]**: User story label

---

## Phase 1: Setup

**Purpose**: Repo tooling and project skeleton

- [x] T001 Create `ios/HomeFlow.xcodeproj` — universal iOS 17+ SwiftUI app target + unit/UI test targets per plan.md — **Traces**: plan Phase 0 (infrastructure)
- [x] T002 [P] Initialize `supabase/` with `config.toml` and local dev setup per quickstart.md — **Traces**: plan Phase 0 (infrastructure)
- [x] T003 [P] Add `.gitignore` entries for `Secrets.xcconfig`, DerivedData (verify ios secrets not committed) — **Traces**: NFR-SEC-01

---

## Phase 2: Foundational (blocking)

**Purpose**: Backend schema, auth, local cache, sync skeleton — **no user story UI until complete**

- [x] T004 Write `supabase/migrations/001_initial_schema.sql` from data-model.md (enums, tables, indexes) — **Traces**: FR-HOME-01, FR-USER-01, FR-PROC-01
- [x] T005 Implement RLS policies + `get_user_role()` per contracts/rls-permissions.md — **Traces**: FR-USER-01, FR-GUEST-01, AC-GUEST-02
- [x] T006 [P] Configure Supabase Auth: Apple + email/password providers — **Traces**: FR-AUTH-01 — *email/password done; Apple deferred (see dev-notes D12)*
- [x] T007 [P] Create Supabase Storage buckets + policies (home-photos, documents, procedure-attachments) — **Traces**: FR-HOME-01, FR-HOME-03, FR-PROC-03 — *002_storage_profiles_invites.sql*
- [x] T008 Implement `ios/HomeFlow/Core/Supabase/SupabaseClientProvider.swift` + Keychain session — **Traces**: FR-AUTH-01, NFR-SEC-01 — *supabase-swift session + authStateChanges*
- [x] T009 Define SwiftData models mirroring server tables + `MutationOutbox` in `ios/HomeFlow/Core/Models/` — **Traces**: NFR-OFFL-01
- [x] T010 Implement `PermissionService` matching RLS matrix in `ios/HomeFlow/Core/Permissions/` — **Traces**: FR-USER-01, AC-PROC-02, AC-GUEST-02
- [x] T011 Implement `SyncEngine` skeleton (outbox enqueue, push, pull, revert-on-deny) in `ios/HomeFlow/Core/Sync/` — **Traces**: NFR-OFFL-01, AC-SYNC-01, AC-SYNC-02, AC-SYNC-03 — *homes push/pull; partial AC-SYNC-02*
- [x] T012 Implement `ActivityLogService` append + fetch in `ios/HomeFlow/Core/ActivityLog/` — **Traces**: FR-LOG-01 — *append done; fetch UI pending*
- [x] T013 Wire `AppRouter` + root auth gate in `ios/HomeFlow/App/` — **Traces**: FR-AUTH-01

**Checkpoint**: Sign-in works; empty authenticated shell loads; migrations apply cleanly. ✅

---

## Phase 3: User Story — Auth & dashboard (P1)

**Goal**: Sign in, see home list — **US-ADMIN-01** (partial)

### Implementation

- [x] T014 [US-ADMIN-01] Auth screens: email/password sign-up, sign-in, Sign in with Apple in `ios/HomeFlow/Features/Auth/` — **Traces**: FR-AUTH-01 — *Apple placeholder only*
- [x] T015 [US-ADMIN-01] Dashboard home list view (SwiftUI) — full-bleed photo hero cards with name/address in `ios/HomeFlow/Features/Dashboard/` — **Traces**: FR-HOME-01, AC-SYNC-04 — *procedure count placeholder not yet*
- [x] T016 [P] [US-ADMIN-01] Adaptive layout: iPhone `NavigationStack`, iPad `NavigationSplitView` shell for dashboard — **Traces**: NFR-PERF-01

### Tests

- [ ] T017 [P] [US-ADMIN-01] XCUITest: sign-in with email → dashboard visible — **Traces**: FR-AUTH-01

---

## Phase 4: User Story — Admin creates/edits home (P1)

**Goal**: Home CRUD + offline home edit — **US-ADMIN-01**

### Implementation

- [x] T018 [US-ADMIN-01] Home create/edit form + validation in `ios/HomeFlow/Features/HomeSetup/` — **Traces**: AC-HOME-01, AC-HOME-02, FR-HOME-01
- [x] T019 [US-ADMIN-01] Home photo pick + upload to Supabase Storage — **Traces**: AC-HOME-01, AC-HOME-08, FR-HOME-01 — *sync-before-upload*
- [x] T019a [P] [US-ADMIN-01] Home photo display optimization: resize on upload, disk/memory cache, signed-URL reuse, dashboard prefetch in `ios/HomeFlow/Core/Storage/` — **Traces**: AC-HOME-06, AC-HOME-07, FR-HOME-01, NFR-PERF-01
- [x] T020 [US-ADMIN-01] Home edit offline + sync conflict (timestamp wins + activity log) — **Traces**: AC-HOME-03, AC-SYNC-01, FR-LOG-01 — *HomeConflictResolver + merge; full offline E2E pending*
- [x] T021 [P] [US-ADMIN-01] Home detail full-bleed photo hero header + tab bar shell (Procedures | Contacts | Documents | People) — **Traces**: FR-HOME-01 — *superseded by T021a–b*
- [x] T021a [P] [US-ADMIN-01] iPad home detail: compact left-column hero + vertical icon tabs; trailing area three-panel (list | detail) for **all** sections — **Traces**: FR-NAV-01, AC-HOME-09, AC-HOME-10 — *ContactsView, FilesView, MembersView split shells*
- [x] T021b [P] [US-ADMIN-01] Rename Documents UI tab to **Files**; add SF Symbol icons to all four section tabs (iPhone horizontal + iPad vertical list) — **Traces**: FR-NAV-01, AC-HOME-11, AC-A11Y-02
- [x] T021c [P] [US-ADMIN-01] iPad: **All Homes** navigation from home detail back to dashboard (sidebar not persistent home picker) — **Traces**: AC-HOME-10, FR-NAV-01

### Tests

- [ ] T022 [P] [US-ADMIN-01] Unit test `test_AC_HOME_01_valid_home_created` — **Traces**: AC-HOME-01 — *validator only; integration test pending*
- [x] T023 [P] [US-ADMIN-01] Unit test `test_AC_HOME_02_invalid_home_rejected` — **Traces**: AC-HOME-02
- [x] T024 [US-ADMIN-01] Unit test `test_AC_HOME_03_offline_edit_conflict_logged` — **Traces**: AC-HOME-03 — *HomeConflictResolverTests; activity log integration pending*
- [ ] T024a [P] [US-ADMIN-01] Unit test `test_AC_HOME_06_upload_resizes_before_storage` — **Traces**: AC-HOME-06
- [ ] T024b [P] [US-ADMIN-01] Unit test `test_AC_HOME_07_hero_renders_from_local_cache` — **Traces**: AC-HOME-07
- [ ] T024c [P] [US-ADMIN-01] Unit test `test_AC_HOME_08_photo_blocked_until_home_synced` — **Traces**: AC-HOME-08
- [ ] T024d [P] [US-ADMIN-01] Snapshot or UI test: iPad home detail trailing column has no hero/segmented tabs — **Traces**: AC-HOME-09
- [ ] T024e [P] [US-ADMIN-01] Snapshot or UI test: iPad leading column shows compact home hero + vertical icon section tabs — **Traces**: AC-HOME-10
- [ ] T024f [P] [US-ADMIN-01] UI test: Contacts, Files, and People sections use the three-panel layout on iPad — **Traces**: AC-HOME-11

---

## Phase 5: User Story — Admin invites & roles (P1)

**Goal**: Invites, memberships, role enforcement — **US-ADMIN-02**, **US-ADMIN-03**

### Implementation

- [x] T025 [US-ADMIN-02] Invite flow: create/revoke invite token, share invite link in `ios/HomeFlow/Features/Members/` — **Traces**: AC-USER-01, AC-USER-02, AC-USER-07, FR-GUEST-02, FR-USER-02 — *share sheet; no email/SMS send*
- [x] T026 [US-ADMIN-02] Accept invite → create membership with role — **Traces**: AC-USER-01, AC-USER-07 — *paste token + RPC; deep link pending*
- [ ] T027 [US-ADMIN-02] Offline invite conflict resolution — **Traces**: AC-USER-03, AC-SYNC-01
- [x] T028 [US-ADMIN-03] Members list (People tab) + role assignment UI — **Traces**: AC-USER-04, AC-USER-05, AC-USER-06, FR-USER-02
- [x] T029 [US-ADMIN-03] Role change sync + audit entry for prior role — **Traces**: AC-USER-06, FR-LOG-01 — *activity log append; concurrent conflict partial*

### Tests

- [ ] T030 [P] [US-ADMIN-02] Unit test `test_AC_USER_01_invite_accepted_grants_role` — **Traces**: AC-USER-01
- [ ] T031 [P] [US-ADMIN-02] Unit test `test_AC_USER_02_revoked_token_invalid` — **Traces**: AC-USER-02
- [ ] T032 [US-ADMIN-03] Unit test `test_AC_USER_04_edit_role_can_modify_procedures` — **Traces**: AC-USER-04
- [ ] T033 [US-ADMIN-03] Unit test `test_AC_USER_05_guest_role_read_only` — **Traces**: AC-USER-05
- [ ] T033a [P] [US-ADMIN-02] Unit test `test_AC_USER_03_offline_invite_conflict` — **Traces**: AC-USER-03
- [ ] T033b [US-ADMIN-03] Unit test `test_AC_USER_06_concurrent_role_change_audit` — **Traces**: AC-USER-06
- [ ] T033c [P] [US-ADMIN-02] Unit test `test_AC_USER_07_paste_token_accepts_invite` — **Traces**: AC-USER-07

---

## Phase 6: User Story — Offline sync (P1, cross-cutting)

**Goal**: Reliable offline writes and conflict rules — **NFR-OFFL-01**

### Implementation

- [x] T034 [NFR-OFFL-01] Network reachability → trigger `SyncEngine.run()` on reconnect in `ios/HomeFlow/Core/Sync/` — **Traces**: AC-SYNC-01
- [ ] T035 [NFR-OFFL-01] Field-level merge for non-conflicting offline edits — **Traces**: AC-SYNC-02
- [x] T036 [NFR-OFFL-01] Stale-permission revert + user-facing error — **Traces**: AC-SYNC-03 — *revert + SyncNotification*
- [x] T037 [P] [NFR-OFFL-01] In-app conflict/overwrite notification banners + pending-sync dashboard indicators — **Traces**: AC-SYNC-01, AC-SYNC-04, AC-PROC-03, AC-HOME-05 — *dashboard sync banners, cloud icons, pull-to-refresh*

### Tests

- [ ] T038 [P] [NFR-OFFL-01] Unit test `test_AC_SYNC_01_offline_overwrite_notifies_loser` — **Traces**: AC-SYNC-01
- [ ] T039 [P] [NFR-OFFL-01] Unit test `test_AC_SYNC_02_disjoint_fields_merge` — **Traces**: AC-SYNC-02
- [ ] T040 [NFR-OFFL-01] Unit test `test_AC_SYNC_03_stale_permission_reverts` — **Traces**: AC-SYNC-03
- [ ] T040a [P] [NFR-OFFL-01] Unit test `test_AC_SYNC_04_pending_sync_visible_on_dashboard` — **Traces**: AC-SYNC-04

**Checkpoint**: P1 stories independently testable. ⏳ *Pending T027, sync tests, Procedures for full demo*

---

## Phase 7: User Story — Edit user procedures (P2)

**Goal**: Procedure list, steps, status updates, step structure editing — **US-EDIT-01**

### Implementation

- [x] T041 [US-EDIT-01] Procedures list with progress (e.g. 2/6) in `ios/HomeFlow/Features/Procedures/` — **Traces**: FR-PROC-01, FR-PROC-02
- [x] T042 [US-EDIT-01] Procedure detail: step checklist, status toggle, N/A option — **Traces**: FR-PROC-02, AC-PROC-01
- [ ] T043 [US-EDIT-01] Step notes + photo attach (Storage) — **Traces**: FR-PROC-03 — *notes done; photos pending*
- [x] T044 [US-EDIT-01] Block step update when permission insufficient — **Traces**: AC-PROC-02
- [x] T045 [US-EDIT-01] Offline step conflict + notification — **Traces**: AC-PROC-03, AC-SYNC-01
- [x] T046 [P] [US-EDIT-01] Recent activity section on procedure detail — **Traces**: FR-LOG-01, AC-PROC-01
- [x] T047 [P] [US-EDIT-01] iPad: procedure list + detail columns — **Traces**: NFR-PERF-01
- [x] T047a [US-EDIT-01] Step structure sync: create, rename, delete, reorder in `ProcedureRepository` + `SyncEngine` — **Traces**: FR-PROC-02, AC-PROC-06
- [x] T047b [US-EDIT-01] Long-press step context menu (rename, delete, move up/down) + Add step on Steps section — **Traces**: AC-PROC-04, AC-PROC-05
- [x] T047c [US-EDIT-01] Hide step structure controls for Guest (read-only) — **Traces**: AC-PROC-07, AC-GUEST-04

### Tests

- [x] T048 [P] [US-EDIT-01] Unit test `test_AC_PROC_01_step_complete_creates_log` — **Traces**: AC-PROC-01 — *ProcedureAggregatorTests*
- [x] T049 [P] [US-EDIT-01] Unit test `test_AC_PROC_02_permission_denied_blocks_update` — **Traces**: AC-PROC-02
- [x] T050 [US-EDIT-01] Unit test `test_AC_PROC_03_offline_step_conflict` — **Traces**: AC-PROC-03
- [x] T050a [P] [US-EDIT-01] Unit test `test_AC_PROC_04_edit_can_manage_step_structure` — **Traces**: AC-PROC-04, AC-PROC-05 — *StepStructureTests*
- [x] T050b [P] [US-EDIT-01] Unit test `test_AC_PROC_06_step_structure_change_logged` — **Traces**: AC-PROC-06 — *StepStructureTests*
- [x] T050c [P] [US-EDIT-01] Unit test `test_AC_PROC_07_guest_no_step_structure_controls` — **Traces**: AC-PROC-07 — *StepStructureTests*

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

## Phase 10: Files, settings, polish (P3)

**Goal**: Files library (document entity), settings, deferred push UI — **FR-HOME-03**, **FR-NOTIF-01**

### Implementation

- [ ] T065 [FR-HOME-03] Files tab: documents list + upload + visibility in `ios/HomeFlow/Features/Documents/` — **Traces**: FR-HOME-03, AC-GUEST-01, AC-HOME-11
- [ ] T066 [P] [FR-NOTIF-01] Settings screen: account, notification toggle disabled (“Coming soon”) in `ios/HomeFlow/Features/Settings/` — **Traces**: FR-NOTIF-01
- [ ] T066a [P] Accessibility baseline: Dynamic Type layouts, VoiceOver labels on section tabs, Reduce Motion, 44pt targets across dashboard/home/procedures — **Traces**: NFR-A11Y-01, AC-A11Y-01, AC-A11Y-02, AC-A11Y-03
- [x] T067 [P] Sign out clears session — **Traces**: FR-AUTH-01 — *dashboard toolbar today; Settings screen Phase 10*
- [ ] T068 Admin revoke member access → lose access on next sync — **Traces**: FR-USER-02

### Tests

- [ ] T069 [P] XCUITest end-to-end: sign-in → create home → invite → update step → guest read-only — **Traces**: SC-01, SC-02, SC-03
- [ ] T069a [P] Manual accessibility pass: largest Dynamic Type + VoiceOver on dashboard, home sections, procedure checklist — **Traces**: AC-A11Y-01, AC-A11Y-02, AC-A11Y-03

---

## Phase 11: Hardening

- [ ] T070 Run `/speckit.analyze` and fix all traceability violations — **Traces**: constitution traceability article
- [ ] T071 [P] RLS integration tests against contracts/rls-permissions.md — **Traces**: FR-USER-01, FR-GUEST-01
- [ ] T072 [P] Sync conflict matrix — target SC-04 (95% scripted scenarios) — **Traces**: SC-04, AC-SYNC-01, AC-SYNC-02, AC-SYNC-03, NFR-SYNC-01
- [ ] T072a [P] Performance smoke: screen load & sync latency baselines — **Traces**: NFR-PERF-01, NFR-SYNC-01
- [ ] T072b [P] Document NFR-SCALE-01 architecture assumptions in plan.md (no load test in MVP) — **Traces**: NFR-SCALE-01
- [ ] T072c [P] Enable Xcode crash report collection / document NFR-REL-01 monitoring path — **Traces**: NFR-REL-01
- [x] T073 Update quickstart.md with any dev-setup deltas discovered during implement — **Traces**: plan Phase 0 (infrastructure)

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
- Files tab = document library (FR-HOME-03); UI label **Files**, not Documents
- Section labels: Procedures | Contacts | Files | People (**FR-NAV-01**)
- Accessibility (Dynamic Type, VoiceOver, Reduce Motion) is MVP scope (**NFR-A11Y-01**), not post-launch polish
- Figma = visual reference; SwiftUI-native layouts
- Push notifications UI-only
