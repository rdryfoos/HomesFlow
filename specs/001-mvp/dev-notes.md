# Dev Notes: HomeFlow MVP Implementation

**Feature**: `001-mvp` | **Updated**: 2026-06-28

Operational learnings from `/speckit.implement` (Phases 0–5 partial). **Product requirements remain in [spec.md](./spec.md)** — this file is engineering-only.

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
- **Personal Team**: works for device install; re-sign ~every 7 days on free account
- **Sign in with Apple** entitlement removed temporarily for Personal Team signing — email/password only until paid Apple Developer Program + entitlement restored
- Set **Team** in Xcode → HomeFlow target → **Signing & Capabilities**
- **Release** scheme + physical device for cloud Supabase

---

## Auth implementation

- **MVP scope (FR-AUTH-01)**: Email/password only on device builds; Apple Sign-In deferred — see spec Assumptions + research D12
- `SupabaseClientProvider` applies session from sign-in response + listens to `authStateChanges` (do not rely on `try? await client.auth.session` alone after sign-in)
- Local Supabase: `auth.external.apple.enabled = false` in `config.toml` for email-only dev
- Cloud: enable **Email** provider; Apple deferred for MVP device demos

---

## Sync & photos

- Homes sync to server **before** photo upload (storage RLS requires membership) — **AC-HOME-08**
- **AC-HOME-06**: uploads resized to max 1280px long edge (~82% JPEG) before Storage write
- **AC-HOME-07**: hero cards load from disk/memory cache keyed by storage path; signed URLs cached ~55 min; dashboard prefetches after home list load
- **AC-SYNC-04**: pending-sync cloud icons on home heroes, sync issue banners, pull-to-refresh on dashboard
- `HomeConflictResolver` + activity log on home edit conflicts (timestamp wins)
- Full field-level merge (AC-SYNC-02) and invite offline conflicts **not yet implemented**

---

## Navigation (SwiftUI)

| Device | Dashboard | Home detail |
|--------|-------------|---------------|
| iPhone | `NavigationStack` + `NavigationLink(value:)` push | Full-bleed hero + horizontal segmented tabs: Procedures \| Contacts \| Files \| People |
| iPad | Home list (select home to enter detail) | `NavigationSplitView`: **leading** = compact hero + vertical icon tabs; **trailing** = section content only (**AC-HOME-09…10**) |

**Do not** use `List(selection:)` on iPhone with `NavigationLink` — selection mode blocks push navigation.

iPad home detail leading column is **not** a persistent home picker. Use **All Homes** (or equivalent) to return to dashboard and switch homes (**FR-NAV-01**).

Section UI label **Files** implements document library (FR-HOME-03); code folder may remain `Documents/`.

---

## Accessibility

- **NFR-A11Y-01**: Respect Dynamic Type, VoiceOver, Reduce Motion, contrast.
- Test primary flows at largest Accessibility text sizes before release (**AC-A11Y-01**).
- Section tabs need clear `accessibilityLabel` + selected state (**AC-A11Y-02**).
- Minimum 44×44 pt tap targets on tabs and primary actions.

---

## Invites (partial)

- Admin: People tab → Invite → share `homeflow://invite?token=…` link (**AC-USER-07**)
- Invitee: Dashboard → Join with Invite → paste token; must sign in with **invited email**
- `accept_invite(token)` RPC in migration `002`
- Deep link / Universal Links **not wired** — manual token paste only
- Email delivery of invite links **not implemented**

---

## Known gaps (next spec-aligned work)

- Procedures tab (Phase 7)
- Apple Sign-In (App Store requirement before public release)
- XCUITests T017, T069
- Offline invite conflict T027; full sync matrix Phase 6
- Member/invite unit tests T030–T033b
- Files tab (Phase 10), Settings, guest read-only views

---

## Regenerating Xcode project

After editing `ios/project.yml`:

```bash
cd ~/Developer/HomeFlow/ios && xcodegen generate
```

Re-select **Team** in Signing if xcodegen resets `DEVELOPMENT_TEAM`.
