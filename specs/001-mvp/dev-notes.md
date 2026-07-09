# Dev Notes: HomesFlow MVP Implementation

**Feature**: `001-mvp` | **Updated**: 2026-07-08

Operational learnings from `/speckit.implement`. **Product requirements remain in [spec.md](./spec.md)** — this file is engineering-only (environments, deployment, feature breadcrumbs, backlog).

| Topic | Where |
|-------|--------|
| Product traceability | [traceability.md](../../traceability.md) |
| Code craft & lint policy | [craft-conventions.md](./craft-conventions.md) |
| Sonar waivers | [sonar-disposition.md](./sonar-disposition.md) |

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
3. Migrations: `001`–`006` in `supabase/migrations/` (schema, storage/invites, roles, step photos, documents bucket, log book)
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

- **FR-AUTH-01**: Email/password + **Sign in with Apple** on device builds. Entitlement restored in `HomeFlow.entitlements`; app exchanges Apple identity token via `SupabaseClientProvider.signInWithApple`.
- **Local Supabase**: `auth.external.apple.enabled = false` in `config.toml` — Apple button shows but Supabase rejects until cloud provider is configured; use email/password for local Docker dev.
- **Cloud / TestFlight**: Enable **Apple** provider in Supabase Dashboard → Authentication → Providers (Services ID + secret per [research.md](./research.md) D12). Email provider remains enabled.

Session and sign-out craft patterns: [craft-conventions.md](./craft-conventions.md#auth--session-implementation).

### Cloud Apple provider (device / TestFlight)

1. **Apple Developer** → Identifiers → App ID `com.rdryfoos.homeflow` → enable **Sign in with Apple**
2. Create a **Services ID** (e.g. `com.rdryfoos.homeflow.auth`) → configure Sign in with Apple → domain = `<ref>.supabase.co`, return URL = `https://<ref>.supabase.co/auth/v1/callback`
3. Create a **Sign in with Apple key** (.p8) → note Key ID and Team ID
4. **Supabase Dashboard** → Authentication → Providers → **Apple** → enable; paste Services ID as Client ID; generate JWT secret from Team ID + Key ID + .p8 (Supabase docs) or use Apple's secret generator
5. Build **Release** scheme with `Secrets.Release.xcconfig` pointing at cloud Supabase → run on physical device → tap **Sign in with Apple**

Local Docker: Apple provider stays disabled; friendly error guides to email/password or cloud config.

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
- **Conflict model evolution (Phase 12, shipped 2026-07-03)**: timestamp-wins (AC-SYNC-01) plus **data-type-aware** rules — never silently regress Complete/N/A step statuses (AC-SYNC-05, `StepStatusConflictPolicy`), auto-resolve other status conflicts and notify the loser with re-apply guidance — **no human resolution UI** (AC-SYNC-06), connectivity-gate structural actions (AC-SYNC-07, `StructuralActionPolicy`). Pull-before-push in `SyncEngine.run()` prevents stale offline overwrites. Field-level merge (AC-SYNC-02, T035/T039) **deferred post-MVP** with version vectors. Full per-type rules: data-model.md "Conflict semantics" table.
- Invite offline conflicts (AC-USER-03) **not yet implemented**

---

## Navigation & accessibility (pointers)

SwiftUI layout rules, iPad shells, and accessibility engineering conventions: [craft-conventions.md](./craft-conventions.md#swiftui-layout) (manual **T069a** device pass still tracked below).

Feature breadcrumbs: iPhone hero ~152pt; iPad hero ~528pt; section shells use `ContactsView`, `FilesView`, `MembersView`, `ProceduresView`.

---

## Launch screen

- Static launch via `UILaunchScreen` in Info.plist: `LaunchBackground` (black) + `LaunchLogo` imageset.
- Assets regenerated ~**1.5×** prior wordmark/icon size with **tighter** green-house-to-text spacing (@1x/@2x/@3x PNG).
- Regenerate with PIL crop/recompose from master `@3x` if adjusting again (see git history `2244b42`).

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

*Updated 2026-07-09. Suite: 114 unit tests; 45/50 ACs verified (Gate 2 green). Task checkboxes: [tasks.md](./tasks.md).*

### Open — ship path

- **Supabase Apple provider (cloud)** — Dashboard config for device/TestFlight sign-in (Services ID + secret); see Auth implementation below
- **T027/T033a** — offline invite conflict (`AC-USER-03`); only unchecked P1 *implementation* task

### Open — validation debt

- **T069a** — manual VoiceOver + largest Dynamic Type pass on device
- **T024d–f** — iPad layout tests for AC-HOME-09…11; manual iPad pass until snapshot/XCUITest infra
- **XCUITests** T017, T064, T069 — see [release-checklist.md](./release-checklist.md) (note: `HomeFlowUITests.testLaunch` only passes on a simulator with a signed-in session)
- **T022** — AC-HOME-01 integration test (validator-only today)

### Open — hardening

- **T070** — `/speckit.analyze` pass
- **T071** — RLS integration tests against `contracts/rls-permissions.md`
- **T072a** — performance smoke baselines (launch, dashboard load, sync round-trip, Quick Look on large PDF)
- **T072b/c** — NFR-SCALE-01 assumptions in plan.md; NFR-REL-01 crash monitoring path

### Deferred post-MVP

- **T035/T039** — AC-SYNC-02 field-level merge (pairs with version vectors)

### Shipped milestones (complete — do not reopen unless regressing)

| Phase | Tasks | Summary |
|-------|-------|---------|
| **12** | T074–T076a | Data-type-aware conflict: terminal status protection, auto-resolve + loser notify, structural offline gate |
| **13** | T077–T086 | Communications Log: migration `006`, offline append, grace-window edit, unified view, guest denial |

See [Implementation changelog](#implementation-changelog) below for dated breadcrumbs.

---

## Implementation changelog

Test-debt sweep (2026-07-03): T030–T033c, T040a, T050d closed via extracted seams (`InvitePolicy`, `RoleChangeAudit`, `MembershipMerge`, `SyncIndicatorPolicy`, `StepRowPresentation`). The AC-USER-04 test exposed a real bug: `PermissionService` let Managers create/update/delete owner-only procedures, providers, and documents because those cases ignored visibility; now all mutations go through `visibilityAllows`. Bonus UX fix: pasting a full `homeflow://invite?token=…` link into Accept Invite now works (previously only the bare token did).

T038 (2026-07-03): `OverwriteNotificationPolicy` centralizes AC-SYNC-01 loser-notification rules; `SyncEngine.mergeHome` now posts the banner when a pending home edit loses to a newer server timestamp. Test: `test_AC_SYNC_01_offline_overwrite_notifies_loser` in SyncConflictMatrixTests.

T074 (2026-07-03): `StepStatusConflictPolicy` implements AC-SYNC-05. Test: `StepStatusConflictPolicyTests.test_AC_SYNC_05_terminal_status_never_silently_regressed`.

**Sync pull-before-push (2026-07-03)**: `SyncEngine.run()` pulls homes before pushing the outbox (AC-SYNC-01 / AC-HOME-03). Provider updates get a pre-push server fetch via `OutboxSyncPolicy` + `reconcileProviderBeforePush`.

T075 (2026-07-03): AC-SYNC-06 auto-resolve status conflicts with loser notification + re-apply guidance (no human resolution UI).

T076 (2026-07-03): `StructuralActionPolicy` implements AC-SYNC-07 — structural actions blocked offline; UI disables controls up front.

**Phase 13 Communications Log (2026-07-03)**: migration `006_log_book_entries.sql`; `LogBookRepository` + outbox push in `SyncEngine`; `CommunicationsLogView`; `LogBookGraceWindowPolicy` (10 min from server receipt); occurrence-time sort via `LogBookEntryOrganizer`. Apply migration before device test: `supabase db push`.

### Offline ordering — decided breadcrumb (2026-07-03)

**Applies to Phase 13 (Communications Log) and step status history in unified timelines.**

- **Communications Log** (UI name; spec **Log Book**, FR-LOG-02) and **step status updates** (Complete, N/A, etc.) MUST remain **offline-capable** — same class as notes/home fields, not structural actions.
- When synced, entries/events MUST appear in **occurrence-time order** — the real wall-clock moment the user acted on device — **not** server receipt order, outbox queue order, or entity `updated_at` from timestamp-wins conflict resolution.
- **Activity log** (FR-LOG-01, system audit) stays distinct; do not conflate with Communications Log in UI copy.
- **Implementation hint (Phase 13+)**: store client `created_at` / `occurred_at` at write time; sort unified chronological views on that field; append-only for log entries; status changes already emit activity-log rows — ensure those rows carry occurrence time for timeline merge with Communications Log entries.

---

## Quality gates (pointers)

- **Gate 2 (traceability)**: [traceability.md](../../traceability.md) — `bash scripts/check-traceability.sh`
- **Gate 0 + craft**: [craft-conventions.md](./craft-conventions.md) — CI in `.github/workflows/ci.yml`

---

## Platform readiness

| Area | Target practice | Status |
|------|-----------------|--------|
| Schema evolution | Supabase migrations in Git (`supabase db push`); no manual dashboard DDL on staging/prod | In use |
| Secrets | `Secrets*.xcconfig` gitignored; never commit service-role keys | In use |
| **Craft Phase A** | `sonar-project.properties`, `craft-conventions.md`, `sonar-disposition.md`, quick fixes | **Done** (2026-07-08) |
| **Craft Phase B** | CI: shellcheck + Gate 2 + SwiftLint + build + `HomeFlowTests` | **Done** (2026-07-08) — `.github/workflows/ci.yml` |
| **Craft Phase C** | Tighten SwiftLint incrementally (re-enable size/complexity rules as files are split); optional `unused_parameter` as warning-as-error | **Next** (opportunistic) |
| **Craft Phase D** | SonarCloud suppressions (UI) + GitHub branch protection on `main` | **Done** (2026-07-08) |
| **Craft Phase E** | PR-only merge + PR template + CI-based Sonar scan | **Next** — tasks T087–T090 |
| Observability | Sentry crash telemetry (DSN-gated via `SENTRY_DSN`) | **Done** — optional until TestFlight |
| Regression evals | Scripted sync/conflict scenario datasets in CI (SC-04 matrix) | **Done** — `SyncConflictMatrixTests` |

Pre-release sign-off: [`release-checklist.md`](./release-checklist.md) per `traceability.md` §9.5.

### Craft roadmap detail

**Phase C** — expand lint without boiling the ocean:

1. Pick one high-churn file (e.g. split `ProcedureRepository`) and enable `type_body_length` for new code only, or per-file SwiftLint config  
2. Add `unused_closure_parameter` fixes as encountered  
3. Document any new rule adoptions in `craft-conventions.md`

**Phase D** — make Sonar enforceable: **done** (2026-07-08)

1. ~~Confirm CI green on push~~ ✅ (run #4)
2. ~~SonarCloud UI suppressions~~ ✅ per `sonar-disposition.md` (git `multicriteria` ignored by automatic analysis)
3. ~~GitHub branch protection~~ ✅ — `craft-gate` + `SonarCloud Code Analysis` on `main`

**Phase E** — PR workflow + CI Sonar (tracked in [tasks.md](./tasks.md) Phase 14):

1. **T087** — PR-only merge to `main`; remove reliance on admin bypass (gates exist but direct push still works for repo admins)
2. **T088** — PR template: task ID(s), traced AC/FR IDs, test/Gate 2 evidence
3. **T089** — Sonar from CI so git `multicriteria` in `sonar-project.properties` is authoritative (automatic analysis ignores them today)
4. **T090** — Document branch → PR → merge in `craft-conventions.md` and README

Target flow: feature branch → open PR → `craft-gate` + Sonar green on PR → merge → `main` protected without bypass.

---

## Regenerating Xcode project

See [craft-conventions.md § Xcode project generation](./craft-conventions.md#xcode-project-generation). Historical note: `.xcodeproj` has been gitignored since `54dca64` to avoid signing-team diff noise.
