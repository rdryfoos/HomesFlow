# Quickstart: HomeFlow MVP

**Feature**: `001-mvp` | **Updated**: 2026-06-28

See also: [dev-notes.md](./dev-notes.md) for implementation gotchas discovered during build.

## Prerequisites

- macOS with Xcode 15+ (iOS 17 SDK; tested on Xcode 26.x)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (`brew install supabase/tap/supabase`)
- Docker Desktop (for **local** Supabase only)
- Apple ID in Xcode (Personal Team) for **physical device** install
- Apple Developer Program ($99/yr) for TestFlight / App Store (optional for solo device demo)

---

## 1. Clone and open

```bash
cd ~/Developer/HomeFlow
cd ios && xcodegen generate   # if project.yml changed
open HomeFlow.xcodeproj
```

---

## 2. Choose your backend

### Option A — Local Supabase (Simulator / Debug)

```bash
cd ~/Developer/HomeFlow
supabase start
supabase db reset    # applies migrations + seed
supabase status      # copy API URL and anon key
```

Create `ios/HomeFlow/Resources/Secrets.xcconfig` (gitignored):

```text
SUPABASE_URL = http:/$()/127.0.0.1:54321
SUPABASE_ANON_KEY = <anon key from supabase status>
```

Run with **Debug** scheme on **Simulator** (⌘R).

### Option B — Supabase Cloud (iPhone / stakeholder demo)

1. Create project at [supabase.com/dashboard](https://supabase.com/dashboard)
2. Push schema:
   ```bash
   supabase login
   supabase link --project-ref <your-ref>
   supabase db push
   ```
3. Copy **Project URL** and **anon public** or **publishable** key from **Project Settings → API**

Create `ios/HomeFlow/Resources/Secrets.Release.xcconfig` (gitignored):

```text
SUPABASE_URL = https:/$()/YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY = <anon or sb_publishable_... — NOT sb_secret_...>
```

4. Create test users in **Authentication → Users**
5. In Xcode: **Product → Scheme → Edit Scheme → Run → Build Configuration → Release**
6. Set **Signing & Capabilities → Team** on HomeFlow target
7. Select your **iPhone** → ⌘R

**Bundle ID**: `com.rdryfoos.homeflow`

---

## 3. Auth providers

| Environment | Email/password | Apple Sign-In |
|-------------|----------------|---------------|
| Local (`config.toml`) | Enabled | Disabled for dev |
| Cloud dashboard | Enable Email | Deferred for MVP demos |
| App Store (future) | Enabled | Required when email offered |

Sign-up: password ≥ 6 characters.

---

## 4. Verify it works

### Local

```bash
supabase db shell --command "select id, name from public.homes;"
```

### Cloud

**Table Editor → `homes`** in Supabase dashboard after creating a home in the app.

### App flow

1. Sign in / create account
2. **My Homes** → Add Home
3. Tap home → detail with **Procedures | Contacts | Documents | People** tabs
4. Edit home → add photo (requires cloud sync + online)

---

## 5. Run tests

```bash
cd ~/Developer/HomeFlow/ios
xcodebuild test \
  -project HomeFlow.xcodeproj \
  -scheme HomeFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

---

## 6. Spec Kit context

```bash
export SPECIFY_FEATURE=001-mvp
export SPECIFY_FEATURE_DIRECTORY=specs/001-mvp
```

Implementation status: [tasks.md](./tasks.md) (checkboxes) + [dev-notes.md](./dev-notes.md).

---

## Key paths

| Artifact | Path |
|----------|------|
| Feature spec | `specs/001-mvp/spec.md` |
| Plan | `specs/001-mvp/plan.md` |
| Dev / deploy notes | `specs/001-mvp/dev-notes.md` |
| Schema | `specs/001-mvp/data-model.md` |
| Migrations | `supabase/migrations/` |
| Debug secrets template | `ios/HomeFlow/Resources/Secrets.xcconfig.example` |
| Release secrets template | `ios/HomeFlow/Resources/Secrets.Release.xcconfig.example` |
| PRD | `HomeFlow.prd.md` |

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| RLS denies insert | User needs profile + admin membership (auto on home create via trigger) |
| Sync not running | Pull to refresh; check dashboard sync banner; confirm online |
| Apple Sign-In fails in sim | Use email/password (Apple deferred) |
| **Could not connect / hostname not found** on iPhone | Release secrets not saved or still `YOUR_PROJECT_REF`; Clean Build (⇧⌘K); verify Build Settings `SUPABASE_URL` |
| Sign-in does nothing (no error) | Fixed: session from sign-in response — pull latest; clean rebuild |
| Photo upload fails | Sync home first; must be online; check storage policies (migration 002) |
| Home row highlights but won't open | Fixed: iPhone must not use `List(selection:)` — pull latest |
| Signing requires development team | Xcode → Settings → Accounts; pick Team on target |
| Bundle ID unavailable | Use `com.rdryfoos.homeflow` (already in project) |
| `diane@test.com` exists (local) | Sign in, don't re-register; or `supabase db reset` |
| Safari shows invalid path at supabase.co | Normal — API is up |
| Cloud project paused | Restore in Supabase dashboard |
