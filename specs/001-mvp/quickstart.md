# Quickstart: HomeFlow MVP

**Feature**: `001-mvp` | **Date**: 2026-06-28

## Prerequisites

- macOS with Xcode 15+ (iOS 17 SDK)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (`brew install supabase/tap/supabase`)
- Docker Desktop (for local Supabase)
- Apple Developer account (for Sign in with Apple — can defer to simulator-only email auth initially)

## 1. Clone and open

```bash
cd ~/Developer/HomeFlow
open ios/HomeFlow.xcodeproj   # exists after /speckit.implement Phase 0
```

## 2. Local Supabase

```bash
supabase init          # once, if not already done
supabase start
supabase db reset      # applies migrations/ + seed
```

Note local URLs and keys printed by `supabase start`.

## 3. App configuration

Create `ios/HomeFlow/Resources/Secrets.xcconfig` (gitignored):

```text
SUPABASE_URL = http://127.0.0.1:54321
SUPABASE_ANON_KEY = <from supabase start>
```

Add to Xcode project build settings; load in `SupabaseClientProvider`.

## 4. Auth providers (Supabase dashboard or config)

- Enable **Email** provider
- Enable **Apple** provider (requires Services ID + key for production; local dev can use email only)

## 5. Run the app

1. Select iPhone 15 Pro simulator (or iPad)
2. ⌘R
3. Sign up with email/password
4. Create first home → verify row in `homes` table:

```bash
supabase db shell --command "select id, name from homes;"
```

## 6. Run tests

```bash
xcodebuild test \
  -project ios/HomeFlow.xcodeproj \
  -scheme HomeFlow \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 7. Spec Kit context

```bash
export SPECIFY_FEATURE=001-mvp
export SPECIFY_FEATURE_DIRECTORY=specs/001-mvp
```

## Key paths

| Artifact | Path |
|----------|------|
| Feature spec | `specs/001-mvp/spec.md` |
| Plan | `specs/001-mvp/plan.md` |
| Schema | `specs/001-mvp/data-model.md` |
| Migrations | `supabase/migrations/` |
| PRD | `HomeFlow PRD.md` |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| RLS denies insert | Ensure `memberships` row exists for current user as admin |
| Sync not running | Check `NetworkMonitor`; verify outbox table has pending rows |
| Apple Sign-In fails in sim | Use email/password for local dev |
