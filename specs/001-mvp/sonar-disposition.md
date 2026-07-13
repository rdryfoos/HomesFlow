# SonarCloud Disposition: HomesFlow MVP

**Project**: [rdryfoos_HomesFlow](https://sonarcloud.io/project/overview?id=rdryfoos_HomesFlow)  
**Policy files**: `sonar-project.properties` (CI-based analysis) · `.sonarcloud.properties` (automatic analysis scope)  
**Craft context**: `craft-conventions.md`

SonarCloud reports **code smells only** (no bugs/vulnerabilities at baseline). Most findings were **tool misconfiguration**, not craft failures.

> **Automatic analysis limitation**: SonarCloud ignores `sonar.issue.ignore.multicriteria` from properties files. Until we switch to CI-based scan, enter the suppressions below in **Project Administration → General Settings → Analysis Scope → Ignore Issues on Multiple Criteria** (same patterns as git).

---

## Configured suppressions (in git + Sonar UI)

| Rule key pattern | File path pattern | Count (baseline) | Rationale |
|------------------|-------------------|----------------:|-----------|
| **swift:S100** | `**/HomesFlowTests/**` | 109 | Gate 2 requires `test_AC_*` snake_case names |
| **swift:S115** | `**/ios/**` | 26 | Supabase JSON uses `snake_case` field names |
| **swift:S1075** | `**/HomesFlowTests/**` | 7 | Test fixture URIs, not production config |
| **swift:S1186** | `**/ios/HomesFlow/Features/**` | 13 | SwiftUI dismiss-only closures |
| *(scope)* | `supabase/**` excluded | 19 plsql | Immutable migrations — via `.sonarcloud.properties` |

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
- **0** new critical on `ios/HomesFlow/**` (excluding configured suppressions)  
- Legacy debt on old code: trend down, not zero  

---

## Maintenance

When adding a convention that Sonar fights:

1. Update `craft-conventions.md`  
2. Add a `sonar.issue.ignore.multicriteria` entry with a one-line rationale  
3. Note the change here — do not hand-edit Sonar UI without updating git  
