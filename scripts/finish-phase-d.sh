#!/usr/bin/env bash
# Finish Craft Phase D: branch protection + Sonar suppression checklist.
# Usage: bash scripts/finish-phase-d.sh
set -euo pipefail

REPO="rdryfoos/HomeFlow"
BRANCH="main"
CRAFT_CHECK="craft-gate"
SONAR_CHECK="SonarCloud Code Analysis"

echo "=== Phase D finish ==="
echo

# --- 1. Verify latest commit has required checks ---
SHA=$(git rev-parse HEAD)
echo "Latest commit: $SHA"
echo "Checking GitHub status checks..."
CHECKS=$(curl -s "https://api.github.com/repos/${REPO}/commits/${SHA}/check-runs" \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for run in data.get('check_runs', []):
    print(f\"{run['name']}: {run['conclusion']}\")
")

echo "$CHECKS"
echo

if echo "$CHECKS" | grep -q "${CRAFT_CHECK}: success" && echo "$CHECKS" | grep -q "${SONAR_CHECK}: success"; then
  echo "✓ Required checks present on HEAD"
else
  echo "⚠ Push to main and wait for CI + Sonar before enabling branch protection"
fi

echo
echo "--- Sonar suppressions (UI — automatic analysis ignores git multicriteria) ---"
echo "Open: https://sonarcloud.io/project/settings?id=rdryfoos_HomeFlow&category=exclusions"
echo "Add under 'Ignore Issues on Multiple Criteria':"
echo
printf "  %-14s %s\n" "swift:S100" "**/HomeFlowTests/**"
printf "  %-14s %s\n" "swift:S115" "**/ios/**"
printf "  %-14s %s\n" "swift:S1075" "**/HomeFlowTests/**"
printf "  %-14s %s\n" "swift:S1186" "**/ios/HomeFlow/Features/**"
echo

# --- 2. Branch protection (requires gh auth or GH_TOKEN) ---
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo "--- Configuring branch protection on ${BRANCH} ---"
  gh api \
    --method PUT \
    "repos/${REPO}/branches/${BRANCH}/protection" \
    --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      {"context": "${CRAFT_CHECK}"},
      {"context": "${SONAR_CHECK}"}
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
  echo "✓ Branch protection configured"
else
  echo "--- Branch protection (manual) ---"
  echo "Run: gh auth login"
  echo "Then re-run: bash scripts/finish-phase-d.sh"
  echo
  echo "Or set manually: https://github.com/${REPO}/settings/branches"
  echo "  Require: ${CRAFT_CHECK}, ${SONAR_CHECK}"
  echo "  Require branches to be up to date before merging"
fi

echo
echo "=== Done ==="
