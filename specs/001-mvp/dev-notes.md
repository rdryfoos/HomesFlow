# Dev Notes: HomesFlow MVP Implementation

**Feature**: `001-mvp` | **Updated**: 2026-06-28

Operational learnings from `/speckit.implement` (Phases 0–5 partial). **Product requirements remain in [spec.md](./spec.md)** — this file is engineering-only.

For traceability mechanics and design-control mapping, see [traceability.md](../../traceability.md). Archived process narrative: `process.deprecated.rtf`.

---

## Process & toolchain

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Process | Spec Kit (`.specify/`, `specs/`) | Spec-driven loops anchored in constitution, PRD, and traceability gates |
| IDE / AI | Cursor | Agents operate on repo artifacts, not ad-hoc prompts |
| Client | Swift / SwiftUI (iOS) | Native accessibility, performance, offline behavior |
| Backend | Supabase (PostgreSQL, auth, Storage, realtime) | Typed data, household-scoped RLS, low-latency sync |
| Delivery | GitHub + GitHub Actions | Source-controlled path to TestFlight / device builds |

---

## Environments

| Mode | Xcode config | Secrets file | Supabase target | Use for |
|------|--------------|--------------|-----------------|---------|
| Local dev | **Debug** | `Secrets.xcconfig` | `http://127.0.0.1:54321` (Docker) | Simulator, fast iteration |
| Device / demo | **Release** | `Secrets.Release.xcconfig` | `https://<ref>.supabase.co` | iPhone, TestFlight, stakeholders |

Both files are **gitignored**. Copy from `*.example` templates in `ios/HomeFlow/Resources/`.

### API keys (critical)

| Key type | Prefix | Use in iOS app? |
|----------|--------|-----------------|
| anon public | `eyJhbGci...` | Yes |
| publishable | `sb_publishable_...` | Yes |
| secret / service_role | `sb_secret_...` | **Never** — server only |

After editing any `*.xcconfig`, **save the file** before building. Verify in Xcode → HomeFlow target → **Build Settings** → search `SUPABASE_URL` (must not show `YOUR_PROJECT_REF` or `127.0.0.1` when testing cloud on device).

---

## Supabase cloud setup

1. Create project at [supabase.com/dashboard](https://supabase.com/dashboard)
2. Link and push migrations:
   ```bash
   cd ~/Developer/HomeFlow
   supabase login
   supabase link --project-ref <ref>
   supabase db push
   ```
3. Migrations: `001_initial_schema.sql`, `002_storage_profiles_invites.sql`
4. Create test users under **Authentication → Users** (not Table Editor)
5. Profile rows appear in **`public.profiles`** (auto-created on signup)
6. Paused free-tier projects cause connection failures — **Restore** in dashboard

Safari visiting `https://<ref>.supabase.co` and seeing `{"error":"requested path is invalid"}` is **normal** (no web UI at root).

---

## iOS signing & bundle ID

- **Bundle ID**: `com.rdryfoos.homeflow` (global `com.homeflow.app` was unavailable)
- **Developer Team**: paid Apple Developer Program, Admin role
- Set **Team** in Xcode → HomeFlow target → **Signing & Capabilities**
- **Release** scheme + physical device for cloud Supabase

---

## Auth implementation

- **MVP scope (FR-AUTH-01)**: Email/password only on device builds; Apple Sign-In deferred pending entitlement wiring — see spec Assumptions + research D12
- `SupabaseClientProvider` applies session from sign-in response + listens to `authStateChanges` (do not rely on `try? await client.auth.session` alone after sign-in)
- **supabase-swift session emit (2026-07-03)**: `emitLocalSessionAsInitialSession: true` on `SupabaseClientOptions` (opt-in to upcoming 3.x default); `applySession` treats `session.isExpired` as signed-out so stale Keychain tokens do not route to the dashboard
- Local Supabase: `auth.external.apple.enabled = false` in `config.toml` for email-only dev
- Cloud: enable **Email** provider; Apple deferred for MVP device demos

---

## Sync & photos

- Homes sync to server **before** photo upload (storage RLS requires membership) — **AC-HOME-08**
- **AC-HOME-06**: uploads resized to max 1280px long edge (~82% JPEG) before Storage write
- **AC-HOME-07**: hero cards load from disk/memory cache keyed by storage path; signed URLs cached ~55 min; dashboard prefetches after home list load (max **2 concurrent** downloads per NFR-PERF-01)
- **AC-HOME-13 / NFR-PERF-01**: file Quick Look preview streams download to temp via `URLSession.download` — avoids holding entire files in RAM
- **AC-HOME-08**: sync-before-photo gating extracted to `HomePhotoSyncGate` (unit tested); iPad layout ACs (AC-HOME-09…11, T024d–f) rely on **manual iPad pass** until snapshot/XCUITest infra lands
- **FR-USER-02 (T068)**: owner removes member via swipe or detail action → confirmation → `memberships` row deleted (RLS owner-only); revoked user loses access on next sync since `is_home_member` fails closed. Removal requires connectivity (`StructuralActionPolicy`, context `.members`); gating in `MemberRemovalPolicy` + UI disables invite/role/remove controls when offline (T076)
- **AC-SYNC-04**: pending-sync cloud icons on home heroes, sync issue banners, pull-to-refresh on dashboard
- `HomeConflictResolver` + activity log on home edit conflicts (timestamp wins)
- **Conflict model evolution (2026-07-03, decided on story map; refined same day)**: timestamp-wins (AC-SYNC-01) stays shipped/verified for v1, but the model becomes **data-type-aware** — never silently regress Complete/N/A step statuses (AC-SYNC-05, T074), auto-resolve other status conflicts and notify the loser with re-apply guidance — **no human resolution UI** (AC-SYNC-06, T075), connectivity-gate structural actions (AC-SYNC-07, T076). Field-level merge (AC-SYNC-02, T035/T039) **deferred post-MVP** with version vectors. Constitution Principle III amended to 1.2.0 to match. Current code still silently applies server-newer — Phase 12 changes that. Full per-type rules: data-model.md "Conflict semantics" table.
- Invite offline conflicts (AC-USER-03) **not yet implemented**

---

## Navigation (SwiftUI)

| Device | Dashboard | Home detail |
|--------|-------------|---------------|
| iPhone | `NavigationStack` push; hero cards **~152pt** | Full-bleed hero + horizontal tabs; single-column section content |
| iPad | `NavigationStack` push; hero cards **~528pt**, vertically centered photo, name + address/`locationLabel` | **Three-panel**: leading sidebar (compact hero + vertical tabs) + trailing nested split (section list \| section detail) for **all** sections (**AC-HOME-09…10**) |

**Do not** use `List(selection:)` on iPhone with `NavigationLink` — selection mode blocks push navigation.

iPad home detail leading column is **not** a persistent home picker. Use **All Homes** (or equivalent) to return to dashboard and switch homes (**FR-NAV-01**).

Section UI label **Files** implements document library (FR-HOME-03); code folder may remain `Documents/`.

**iPad section shells** (list | detail placeholders until Phases 8–10): `ContactsView`, `FilesView`, `MembersView` (People), `ProceduresView`.

---

## Launch screen

- Static launch via `UILaunchScreen` in Info.plist: `LaunchBackground` (black) + `LaunchLogo` imageset.
- Assets regenerated ~**1.5×** prior wordmark/icon size with **tighter** green-house-to-text spacing (@1x/@2x/@3x PNG).
- Regenerate with PIL crop/recompose from master `@3x` if adjusting again (see git history `2244b42`).

---

## Accessibility

- **NFR-A11Y-01**: Respect Dynamic Type, VoiceOver, Reduce Motion, contrast.
- Shared rules live in `AccessibilityBaseline` (unit tested, T066a): hero card heights scale with Dynamic Type (**AC-A11Y-01**), section tab hints (**AC-A11Y-02**), `animation(reduceMotion:)` returns nil under Reduce Motion (**AC-A11Y-03**), 44pt `minimumTapTarget` applied to section tabs and procedure step actions.
- Step rows announce status via `accessibilityValue` ("N/A" spoken as "Not applicable").
- Manual pass at largest Accessibility text sizes + VoiceOver remains **T069a** (device).

---

## Invites (partial)

- Owner: People tab → Invite → share `homeflow://invite?token=…` link (**AC-USER-07**)
- Invitee: Dashboard → Join with Invite → paste token; must sign in with **invited email**
- `accept_invite(token)` RPC in migration `002`
- Deep link / Universal Links **not wired** — manual token paste only
- Email delivery of invite links **not implemented**

### Pending invite UX (2026-07-06)

- **Tap invite** → detail (share link + revoke). **Never** one-tap revoke from the list.
- **iPad:** `PeopleSelection` tagged list (`.member` / `.invite`) drives split detail — see `PeopleSelection.swift`; do not use bare `UUID?` selection.
- **iPhone:** same `PendingInviteDetailView` in a **sheet** (`inviteDetailSheet`); compact width has no split column.
- Revoke requires confirmation dialog (**AC-USER-02**); disabled offline per **AC-SYNC-07**.

---

## Known gaps (next spec-aligned work)

*Updated 2026-07-03. Suite: 77 unit tests; coverage 30/50 ACs verified (Gate 2 green; registry grew to 50 ACs with Log Book + conflict model evolution).*

- **Apple Sign-In wiring** — paid Developer Program now active; restore entitlement, Services ID, enable Supabase Apple provider (App Store requirement — research D12)
- **Phase 12 (T074–T076a)** — data-type-aware conflict model: protect terminal step statuses (T074), auto-resolve status conflicts with loser notification (T075), connectivity-gated structural actions with upfront UI disable + repository guard (T076, AC-SYNC-07)
- **Phase 13 (T077–T086)** — Communications Log shipped: `log_book_entries` migration + RLS, offline append sync, grace-window edit policy, unified view with scope filter, guest denial; UI label "Communications Log"
- **T035/T039** — AC-SYNC-02 field-level merge — **deferred post-MVP** (2026-07-03 decision; pairs with version vectors)
- **T027/T033a** — offline invite conflict (implementation + test)
- **T072a** — performance baselines (pair with device smoke session: launch, dashboard load, sync round-trip, Quick Look on large PDF)
- **T069a** — manual VoiceOver + largest Dynamic Type pass on device
- **T024d–f** — iPad layout tests (deferred pending snapshot/XCUITest infra; manual iPad pass until then)
- **XCUITests** T017, T069 (note: `HomeFlowUITests.testLaunch` only passes on a simulator with a signed-in session — it asserts the HomesFlow dashboard nav bar, so a signed-out sim shows the auth screen instead)

Test-debt sweep (2026-07-03): T030–T033c, T040a, T050d closed via extracted seams (`InvitePolicy`, `RoleChangeAudit`, `MembershipMerge`, `SyncIndicatorPolicy`, `StepRowPresentation`) — 36/50 ACs verified. The AC-USER-04 test exposed a real bug: `PermissionService` let Managers create/update/delete owner-only procedures, providers, and documents because those cases ignored visibility; now all mutations go through `visibilityAllows`. Bonus UX fix: pasting a full `homeflow://invite?token=…` link into Accept Invite now works (previously only the bare token did).

T038 (2026-07-03): `OverwriteNotificationPolicy` centralizes AC-SYNC-01 loser-notification rules; `SyncEngine.mergeHome` now posts the banner when a pending home edit loses to a newer server timestamp (steps and providers already did). Test: `test_AC_SYNC_01_offline_overwrite_notifies_loser` in SyncConflictMatrixTests.

T074 (2026-07-03): `StepStatusConflictPolicy` implements AC-SYNC-05 — Complete/N/A never silently regress on step merge; conflicting server status is surfaced via activity log + notification while non-status fields still merge. Test: `StepStatusConflictPolicyTests.test_AC_SYNC_05_terminal_status_never_silently_regressed`.

**Sync pull-before-push (2026-07-03)**: `SyncEngine.run()` now pulls homes before pushing the outbox so timestamp-wins merge runs first (AC-SYNC-01 / AC-HOME-03). Fixes the two-device home-rename scenario where an older offline iPhone edit overwrote a newer iPad edit. Provider updates get a pre-push server fetch via `OutboxSyncPolicy` + `reconcileProviderBeforePush`. Re-test: iPhone offline rename → iPad online rename → iPhone reconnect should keep the iPad name and notify the iPhone.

T075 (2026-07-03): AC-SYNC-06 auto-resolve status conflicts with loser notification + re-apply guidance (no human resolution UI).

T076 (2026-07-03): `StructuralActionPolicy` implements AC-SYNC-07 — structural actions blocked offline; UI disables controls up front. Step status, notes, and home edits remain offline-capable.

**Phase 13 Communications Log (2026-07-03)**: migration `006_log_book_entries.sql`; `LogBookRepository` + outbox push in `SyncEngine`; `CommunicationsLogView` (household + unified); procedure detail add/view; `LogBookGraceWindowPolicy` (10 min from server receipt); occurrence-time sort via `LogBookEntryOrganizer`. 100 unit tests green. Apply migration before device test: `supabase db push`.

### Offline ordering — decided breadcrumb (2026-07-03)

**Applies to Phase 13 (Communications Log) and step status history in unified timelines.**

- **Communications Log** (UI name; spec **Log Book**, FR-LOG-02) and **step status updates** (Complete, N/A, etc.) MUST remain **offline-capable** — same class as notes/home fields, not structural actions.
- When synced, entries/events MUST appear in **occurrence-time order** — the real wall-clock moment the user acted on device — **not** server receipt order, outbox queue order, or entity `updated_at` from timestamp-wins conflict resolution.
- **Activity log** (FR-LOG-01, system audit) stays distinct; do not conflate with Communications Log in UI copy.
- **Implementation hint (Phase 13+)**: store client `created_at` / `occurred_at` at write time; sort unified chronological views on that field; append-only for log entries; status changes already emit activity-log rows — ensure those rows carry occurrence time for timeline merge with Communications Log entries.

---

## Traceability Gate 2

`scripts/check-traceability.sh` verifies the golden thread (registry drift, missing `Traces:`, untraced scope, untested ACs with no tracked task). Runs in CI via `.github/workflows/traceability.yml` on every push/PR; run locally with `bash scripts/check-traceability.sh`.

Modes: `--matrix` regenerates [coverage.md](./coverage.md) and `coverage.svg` (portfolio snapshot — commit before hiring or release pushes; not CI-enforced). `--json` prints per-ID status to stdout. `--canvas` updates the local **Golden Thread Coverage** Cursor canvas. `--refresh` runs Gate 2 + matrix + optional canvas — use after changing tasks, `@covers`, or tests. See `.cursor/rules/golden-thread-coverage.mdc`.

---

## Platform readiness (planned)

| Area | Target practice | Status |
|------|-----------------|--------|
| Schema evolution | Supabase migrations in Git (`supabase db push`); no manual dashboard DDL on staging/prod | In use |
| Secrets | `Secrets*.xcconfig` gitignored; never commit service-role keys | In use |
| Observability | Mobile crash/sync telemetry (e.g. Sentry for iOS), queued upload after reconnect | Not integrated |
| Regression evals | Scripted sync/conflict scenario datasets in CI (SC-04 matrix) | Partial — unit tests only |

Pre-release sign-off: [`release-checklist.md`](./release-checklist.md) per `traceability.md` §9.5.

---

## Regenerating Xcode project

`ios/HomeFlow.xcodeproj/` is **generated and untracked** (since `54dca64`): Xcode kept
rewriting the personal signing team into the XcodeGen output, causing permanent diff
noise. `ios/project.yml` is the source of truth.

- **Fresh clone / new machine**: run `xcodegen generate` before opening the project.
- After editing `ios/project.yml`:

```bash
cd ~/Developer/HomeFlow/ios && xcodegen generate
```

- Re-select **Team** in Signing if xcodegen resets `DEVELOPMENT_TEAM` (safe now — stays local).
- **Dependency pinning trade-off**: `Package.resolved` lives inside the untracked
  `.xcodeproj`, so exact SPM versions are no longer pinned in git. Builds resolve
  Supabase from the `from: 2.5.1` constraint in `project.yml` and may pick up newer
  minors. Pin an exact version in `project.yml` if reproducible builds start to matter
  (e.g. before TestFlight/App Store submissions).
