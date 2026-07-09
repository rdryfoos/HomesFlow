# Craft Conventions: HomesFlow MVP

**Feature**: `001-mvp` | Engineering craft (complements product traceability in `traceability.md`)

Product rigor answers *what* we build and *how we prove it* (Gate 2). Craft rigor answers *how we write code* without fighting our tools.

---

## Hierarchy

1. **Constitution** + **PRD** — product law  
2. **traceability.md** — golden thread (Gate 2)  
3. **This file** — Swift, shell, and static-analysis policy  
4. **sonar-project.properties** — SonarCloud configuration (must match this file)  
5. **sonar-disposition.md** — bulk Sonar waivers with rationale  

When Sonar and Gate 2 disagree, **Gate 2 wins** for tests; **Supabase API shape wins** for DTO naming.

---

## Swift — production (`ios/HomeFlow/`)

| Topic | Convention |
|-------|------------|
| Business logic | Policy objects + repositories; keep SwiftUI views thin |
| Unused parameters | Remove or label `_` |
| `force_try` / `force_cast` | Avoid in production paths |
| Supabase `Encodable` rows | `snake_case` property names matching Postgres/JSON (`home_id`, `created_at`) — use `CodingKeys` only when Swift name must differ |
| DTO structs | `*DTO.swift` with `Codable`; mirror server schema literally |

---

## Swift — tests (`ios/HomeFlowTests/`)

| Topic | Convention |
|-------|------------|
| AC tests | `func test_AC_<DOMAIN>_<NN>_<description>()` — **required** for Gate 2 |
| Naming style | `snake_case` after `test_` prefix (overrides Sonar S100) |
| Fixture URIs | `homeflow://…` strings in tests are intentional (not production config) |

---

## SwiftUI

| Topic | Convention |
|-------|------------|
| Dismiss-only handlers | Empty closure `{ }` is allowed on alert/button dismiss actions |
| Non-obvious no-ops | Add `/* dismiss */` inside the closure if Sonar flags outside `Features/` |

---

## SQL migrations (`supabase/migrations/`)

- Append-only; never refactor applied migrations for linter satisfaction  
- Excluded from Sonar analysis (immutable deployment artifacts)

---

## Shell (`scripts/`)

- Gate scripts MUST pass `shellcheck`  
- Prefer `[[ … ]]` over `[ … ]` for conditionals  
- `set -euo pipefail` on entrypoints  

---

## CI craft gates

| Gate | Command | Runner |
|------|---------|--------|
| **Gate 0** | `xcodebuild build` + `xcodebuild test` (`HomeFlowTests`) | macOS |
| **Gate 2** | `bash scripts/check-traceability.sh` | Linux or macOS |
| **Shell** | `shellcheck scripts/*.sh` | Linux or macOS |
| **SwiftLint** | `swiftlint lint --config ios/.swiftlint.yml` | macOS |
| **Sonar** | SonarCloud on push (quality gate on **new code** after Phase D) | SonarCloud |

SwiftLint intentionally disables size/complexity rules on the existing codebase; opt-in rules target `force_try`, `force_cast`, and similar footguns. Sonar policy excludes migrations and suppresses conventions documented in `sonar-disposition.md`.

---

## SwiftUI layout

| Topic | Convention |
|-------|------------|
| iPhone navigation | `NavigationStack` push — **do not** use `List(selection:)` with `NavigationLink` (blocks push) |
| iPad home detail | Three-panel split: leading sidebar (hero + vertical tabs) + nested list \| detail — not a persistent home picker |
| Home switching | **All Homes** (or equivalent) returns to dashboard (**FR-NAV-01**) |
| Section labels | UI may say **Files** / **People**; code folders may stay `Documents/` / `Members/` |
| Business logic | Extract to `*Policy.swift`, repositories, and presenters — keep views declarative |

---

## Accessibility engineering

Shared rules live in `AccessibilityBaseline` (unit tested):

- Hero card heights scale with Dynamic Type (**AC-A11Y-01**)
- Section tabs carry meaningful VoiceOver labels (**AC-A11Y-02**)
- `animation(reduceMotion:)` returns nil under Reduce Motion (**AC-A11Y-03**)
- Interactive controls use 44pt `minimumTapTarget` where applicable
- Step rows announce status via `accessibilityValue` ("N/A" → "Not applicable")

Manual VoiceOver + largest Dynamic Type pass on device remains **T069a** (tracked in `dev-notes.md`).

---

## Auth & session (implementation)

- Apply session from sign-in/sign-up **response** and subscribe to `authStateChanges` — do not rely on `try? await client.auth.session` alone immediately after sign-in
- `emitLocalSessionAsInitialSession: true` on `SupabaseClientOptions`; treat `session.isExpired` as signed-out in `applySession`
- Sign in with Apple: generate raw nonce → SHA-256 hash on `ASAuthorizationAppleIDRequest.nonce` → exchange identity token via `signInWithIdToken` with raw nonce (see `AppleSignInPolicy`, `AuthViewModel`)
- Sign-out purges local SwiftData (`LocalDataStore.purgeAll`) so the next account does not inherit cached homes

---

## Observability (optional)

Crash telemetry via [Sentry](https://sentry.io) — **disabled by default** (empty `SENTRY_DSN` in xcconfig).

| Topic | Convention |
|-------|------------|
| Activation | Set `SENTRY_DSN` in `Secrets.Release.xcconfig` before TestFlight |
| Local dev | Leave `SENTRY_DSN` empty in `Secrets.xcconfig` |
| Privacy | No PII, emails, or home names in Sentry breadcrumbs/tags |
| Wiring | `CrashReporting.start()` in `HomeFlowApp` — no-op without DSN |

---

## Xcode project generation

`ios/HomeFlow.xcodeproj/` is **generated** from `ios/project.yml` (often gitignored). After clone or `project.yml` edits:

```bash
cd ~/Developer/HomeFlow/ios && xcodegen generate
```

Re-select **Team** in Signing if needed. SPM versions resolve from `project.yml` (`from: 2.5.1`); pin exact versions before App Store submission if reproducible builds matter.

---

## Refactoring seam

When logic grows testable, extract **policy objects** and merge helpers (`InvitePolicy`, `MembershipMerge`, `SyncIndicatorPolicy`, `HomeAccessPolicy`, etc.) rather than enlarging views or repositories. Gate 2 tests target the policy layer where possible.

---

## Before a hiring / release push

```bash
bash scripts/check-traceability.sh --refresh   # Gate 2 + portfolio snapshot
shellcheck scripts/*.sh
cd ios && swiftlint lint --config .swiftlint.yml
xcodebuild test … -only-testing:HomeFlowTests
```

Commit refreshed `coverage.md` / `coverage.svg` when the public snapshot should change.
