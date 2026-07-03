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
- Local Supabase: `auth.external.apple.enabled = false` in `config.toml` for email-only dev
- Cloud: enable **Email** provider; Apple deferred for MVP device demos

---

## Sync & photos

- Homes sync to server **before** photo upload (storage RLS requires membership) — **AC-HOME-08**
- **AC-HOME-06**: uploads resized to max 1280px long edge (~82% JPEG) before Storage write
- **AC-HOME-07**: hero cards load from disk/memory cache keyed by storage path; signed URLs cached ~55 min; dashboard prefetches after home list load (max **2 concurrent** downloads per NFR-PERF-01)
- **AC-HOME-13 / NFR-PERF-01**: file Quick Look preview streams download to temp via `URLSession.download` — avoids holding entire files in RAM
- **AC-HOME-08**: sync-before-photo gating extracted to `HomePhotoSyncGate` (unit tested); iPad layout ACs (AC-HOME-09…11, T024d–f) rely on **manual iPad pass** until snapshot/XCUITest infra lands
- **FR-USER-02 (T068)**: owner removes member via swipe or detail action → confirmation → `memberships` row deleted (RLS owner-only); revoked user loses access on next sync since `is_home_member` fails closed. Removal requires connectivity (`MemberError.offlineRemoval`); gating in `MemberRemovalPolicy`
- **AC-SYNC-04**: pending-sync cloud icons on home heroes, sync issue banners, pull-to-refresh on dashboard
- `HomeConflictResolver` + activity log on home edit conflicts (timestamp wins)
- **Conflict model evolution (2026-07-03, decided on story map)**: timestamp-wins (AC-SYNC-01) stays shipped/verified for v1, but the model becomes **data-type-aware** — never silently regress Complete/N/A step statuses (AC-SYNC-05, T074), surface genuine status conflicts for human resolution (AC-SYNC-06, T075), connectivity-gate structural actions (AC-SYNC-07, T076). Field-level merge (AC-SYNC-02, T035/T039) **deferred post-MVP** with version vectors. Current code still silently applies server-newer — Phase 12 changes that.
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

---

## Known gaps (next spec-aligned work)

*Updated 2026-07-03. Suite: 77 unit tests; coverage 30/50 ACs verified (Gate 2 green; registry grew to 50 ACs with Log Book + conflict model evolution).*

- **Apple Sign-In wiring** — paid Developer Program now active; restore entitlement, Services ID, enable Supabase Apple provider (App Store requirement — research D12)
- **Phase 12 (T074–T076a)** — data-type-aware conflict model: protect terminal step statuses, human conflict resolution, connectivity-gated structural actions (AC-SYNC-05…07)
- **Phase 13 (T077–T086)** — Log Book: user-authored household/procedure entries, unified view, grace-window editing, Guest exclusion (FR-LOG-02, AC-LOG-01…06)
- **T035/T039** — AC-SYNC-02 field-level merge — **deferred post-MVP** (2026-07-03 decision; pairs with version vectors)
- **T030–T033c** — member/invite unit tests; **T027/T033a** offline invite conflict
- **T072a** — performance baselines (pair with device smoke session: launch, dashboard load, sync round-trip, Quick Look on large PDF)
- **T069a** — manual VoiceOver + largest Dynamic Type pass on device
- **T024d–f** — iPad layout tests (deferred pending snapshot/XCUITest infra; manual iPad pass until then)
- **XCUITests** T017, T069; **T040a** AC-SYNC-04 test; **T050d** AC-PROC-08 test

---

## Traceability Gate 2

`scripts/check-traceability.sh` verifies the golden thread (registry drift, missing `Traces:`, untraced scope, untested ACs with no tracked task). Runs in CI via `.github/workflows/traceability.yml` on every push/PR; run locally with `bash scripts/check-traceability.sh`.

Modes: `--matrix` regenerates [coverage.md](./coverage.md) (commit after traceability changes; CI fails if stale). `--canvas` updates the local **Golden Thread Coverage** Cursor canvas. `--refresh` runs Gate 2 + matrix + canvas — use after changing tasks, `@covers`, or tests. See `.cursor/rules/golden-thread-coverage.mdc`. The canvas helper (`scripts/update-golden-thread-canvas.py`) resolves and confines CLI paths to allowed directories before any file read/write.

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
