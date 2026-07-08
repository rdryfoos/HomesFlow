# Release checklist — 001-mvp

Per `traceability.md` §9.5. Complete before TestFlight, staging demo, or production promotion. Copy this file per release and fill in the bracketed fields.

**Release**: [version / build number]  
**Date**: [YYYY-MM-DD]  
**Target**: [ ] Staging demo  [ ] TestFlight  [ ] Production  
**Signer**: [name]

---

## Pre-release

- [ ] All migrations for this release applied to target Supabase project (`supabase db push` on staging/prod as appropriate)
- [ ] `Secrets*.xcconfig` / cloud keys configured for target environment (no service-role key in app)
- [ ] `bash scripts/check-traceability.sh --refresh` — Gate 2 **PASSED**; coverage snapshot refreshed (`coverage.md` / `coverage.svg`)
- [ ] Unit tests green: `xcodebuild test -scheme HomeFlow -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:HomeFlowTests`
- [ ] App builds Release on physical device (or CI artifact equivalent)

## Validation status (design validation — not optional long-term)

- [ ] **T064** XCUITest guest cannot edit provider — [ ] done  [ ] deferred (document below)
- [ ] **T069** XCUITest end-to-end Owner → invite → step → guest read-only — [ ] done  [ ] deferred
- [ ] **T069a** Manual accessibility pass — [ ] done  [ ] deferred
- [ ] **T072** Sync conflict matrix (SC-04) — [ ] done  [ ] deferred

**Open validation gaps accepted for this release:**

| Task | Gap | Rationale / follow-up |
|------|-----|------------------------|
| | | |

## Known issues

| ID / link | Severity | User impact | Workaround |
|-----------|----------|-------------|------------|
| | | | |

## Rollback plan

- **App**: Revert to prior TestFlight / App Store build [build number]
- **Database**: Migrations are forward-only; document any manual fix or note irreversible schema change
- **Config**: Restore prior Supabase project ref / secrets if environment rollback needed

---

## Sign-off

- [ ] Intended use and risk notes in `spec.md` still accurate for this release
- [ ] Release notes drafted (user-visible changes)
- [ ] Approved to ship: _________________  Date: _________
