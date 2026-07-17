# SonarCloud Disposition: HomesFlow MVP

**Project**: [rdryfoos_HomesFlow](https://sonarcloud.io/project/overview?id=rdryfoos_HomesFlow)  
**Policy files**: `sonar-project.properties` (CI-based analysis — authoritative) · `.sonarcloud.properties` (legacy automatic-analysis scope)  
**Craft context**: `craft-conventions.md`

SonarCloud reports **code smells only** (no bugs/vulnerabilities at baseline). Most findings were **tool misconfiguration**, not craft failures.

## Analysis mode (Craft Phase E / T089)

| Mode | Status | Notes |
|------|--------|-------|
| **CI-based** (preferred) | Job `sonar` in `.github/workflows/ci.yml` | Reads git `sonar.issue.ignore.multicriteria`; needs `SONAR_TOKEN` secret |
| Automatic analysis | Disable after CI Sonar is green | Ignores multicriteria from properties files |

**Setup**

1. Create a SonarCloud **analysis token** (My Account → Security).  
2. Add repo secret `SONAR_TOKEN` (Settings → Secrets and variables → Actions).  
3. Confirm the `sonar` job runs the scan (not the skip warning) and is green on a PR.  
4. In SonarCloud → Administration → Analysis Method, **turn off Automatic Analysis** so only CI scans run (avoids double analysis and keeps suppressions in git).  

Until `SONAR_TOKEN` exists, the CI `sonar` job **skips with a warning**; Automatic Analysis continues to decorate PRs as `SonarCloud Code Analysis`.

UI multicriteria rows (below) can remain as belt-and-suspenders until automatic analysis is off; after that, git is source of truth.

---

## Configured suppressions (in git; mirror in Sonar UI until automatic analysis is off)

| Rule key pattern | File path pattern | Count (baseline) | Rationale |
|------------------|-------------------|----------------:|-----------|
| **swift:S100** | `**/HomesFlowTests/**` | 109 | Gate 2 requires `test_AC_*` snake_case names |
| **swift:S115** | `**/ios/**` | 26 | Supabase JSON uses `snake_case` field names |
| **swift:S1075** | `**/HomesFlowTests/**` | 7 | Test fixture URIs, not production config |
| **swift:S1186** | `**/ios/HomesFlow/Features/**` | 13 | SwiftUI dismiss-only closures |
| *(scope)* | `supabase/**` excluded | 19 plsql | Immutable migrations — via properties exclusions |

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

- **0** new bugs, vulnerabilities, blocker issues  
- **0** new critical on `ios/HomesFlow/**` (excluding configured suppressions)  
- Legacy debt on old code: trend down, not zero  

Branch protection requires the GitHub check **SonarCloud Code Analysis** (posted by the SonarCloud GitHub App after CI or automatic analysis).

---

## Maintenance

When adding a convention that Sonar fights:

1. Update `craft-conventions.md`  
2. Add a `sonar.issue.ignore.multicriteria` entry with a one-line rationale  
3. Note the change here — do not rely on Sonar UI alone once CI analysis is the source of truth  
