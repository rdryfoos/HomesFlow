# SonarCloud Disposition: HomesFlow MVP

**Project**: [rdryfoos_HomeFlow](https://sonarcloud.io/project/overview?id=rdryfoos_HomeFlow)  
**Policy file**: `sonar-project.properties` (version-controlled)  
**Craft context**: `craft-conventions.md`

SonarCloud reports **code smells only** (no bugs/vulnerabilities at baseline). Most findings were **tool misconfiguration**, not craft failures.

---

## Configured suppressions (in git)

| Rule | Count (baseline) | Disposition | Rationale |
|------|----------------:|-------------|-----------|
| **swift:S100** | 109 | Ignore on `HomeFlowTests/**` | Gate 2 requires `test_AC_*` snake_case names |
| **swift:S115** | 26 | Ignore on `ios/**` | Supabase JSON uses `snake_case` field names |
| **swift:S1075** | 7 | Ignore on `HomeFlowTests/**` | Test fixture URIs, not production config |
| **swift:S1186** | 13 | Ignore on `Features/**` | SwiftUI dismiss-only closures |
| **plsql:S1192** | 19 | Exclude `supabase/**` | Immutable migrations; “extract constant” is inappropriate |

---

## Fix in code (not suppressed)

| Rule | Action |
|------|--------|
| **swift:S1172** | Rename unused parameters to `_` |
| **shelldre:S7688** / **S7679** | `shellcheck` + `[[` in `scripts/` |
| **swift:S107** | Refactor only when readability suffers (case-by-case) |

---

## Accepted / won't fix in Sonar UI (optional)

After the next analysis, bulk-close any remaining **S1186** outside `Features/` with reason: *SwiftUI dismiss handler*.

---

## Quality gate target (new code)

Once baseline is calibrated:

- **0** new bugs, vulnerabilities, blocker issues  
- **0** new critical on `ios/HomeFlow/**` (excluding configured suppressions)  
- Legacy debt on old code: trend down, not zero  

---

## Maintenance

When adding a convention that Sonar fights:

1. Update `craft-conventions.md`  
2. Add a `sonar.issue.ignore.multicriteria` entry with a one-line rationale  
3. Note the change here — do not hand-edit Sonar UI without updating git  
