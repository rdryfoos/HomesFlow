## Summary

<!-- What changed and why (one short paragraph). -->

## Traceability

- **Task ID(s):** T0xx
- **Traces:** AC-… / FR-… / NFR-… (from `tasks.md` `**Traces**:` fields)
- **PRD silent?** No / Yes — proposed PRD change: …

## Proof

- [ ] Gate 2 locally: `bash scripts/check-traceability.sh` (or rely on CI `traceability` job)
- [ ] Unit tests / AC-named tests updated or justified as tracked debt
- [ ] `@covers` on new/changed production modules when they implement a requirement

## Delivery checklist

- [ ] Feature branch (not direct to `main`)
- [ ] Scope from `HomesFlow.prd.md` only — no invented product behavior
- [ ] Craft conventions followed (`specs/001-mvp/craft-conventions.md`)
