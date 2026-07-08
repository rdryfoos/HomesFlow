#!/usr/bin/env bash
# Finish Craft Phase D: branch protection + Sonar suppression checklist.
# Usage: bash scripts/finish-phase-d.sh [--no-wait]
set -euo pipefail

REPO="rdryfoos/HomeFlow"
BRANCH="main"
CRAFT_CHECK="craft-gate"
SONAR_CHECK="SonarCloud Code Analysis"
WAIT_FOR_CI=true

if [[ "${1:-}" == "--no-wait" ]]; then
  WAIT_FOR_CI=false
fi

fetch_checks() {
  local sha="$1"
  curl -s "https://api.github.com/repos/${REPO}/commits/${sha}/check-runs" \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for run in data.get('check_runs', []):
    name = run['name']
    status = run.get('status', 'unknown')
    conclusion = run.get('conclusion')
    if conclusion:
        label = conclusion
    elif status == 'in_progress':
        label = 'in_progress'
    elif status == 'queued':
        label = 'queued'
    else:
        label = status
    print(f'{name}: {label}')
"
}

checks_ready() {
  local checks="$1"
  echo "$checks" | grep -q "${CRAFT_CHECK}: success" \
    && echo "$checks" | grep -q "${SONAR_CHECK}: success"
}

echo "=== Phase D finish ==="
echo

SHA=$(git rev-parse HEAD)
echo "Latest commit: $SHA"
echo "Checking GitHub status checks..."

CHECKS=$(fetch_checks "$SHA")
if $WAIT_FOR_CI && ! checks_ready "$CHECKS"; then
  echo "(waiting for craft-gate + Sonar — ios job takes ~3–4 min)"
  for _ in $(seq 1 40); do
    sleep 15
    CHECKS=$(fetch_checks "$SHA")
    if checks_ready "$CHECKS"; then
      break
    fi
    echo "  … still waiting ($(date +%H:%M:%S))"
  done
fi

echo "$CHECKS"
echo

if checks_ready "$CHECKS"; then
  echo "✓ Required checks present on HEAD"
  READY=true
else
  echo "⚠ craft-gate or Sonar not green yet — see https://github.com/${REPO}/actions"
  echo "  Re-run after CI finishes: bash scripts/finish-phase-d.sh --no-wait"
  READY=false
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

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  if $READY; then
    echo "--- Configuring branch protection on ${BRANCH} ---"
    gh api \
      --method PUT \
      "repos/${REPO}/branches/${BRANCH}/protection" \
      -f required_status_checks[strict]=true \
      -f required_status_checks[checks][][context]="${CRAFT_CHECK}" \
      -f required_status_checks[checks][][context]="${SONAR_CHECK}" \
      -F enforce_admins=false \
      -F allow_force_pushes=false \
      -F allow_deletions=false \
      >/dev/null
    echo "✓ Branch protection configured (${CRAFT_CHECK} + ${SONAR_CHECK})"
  else
    echo "--- Branch protection skipped (checks not ready) ---"
    echo "Re-run when CI is green: bash scripts/finish-phase-d.sh"
  fi
else
  echo "--- Branch protection (needs gh auth) ---"
  echo "  gh auth login"
  echo "  bash scripts/finish-phase-d.sh"
  echo
  echo "Or manually: https://github.com/${REPO}/settings/branches"
  echo "  Require: ${CRAFT_CHECK}, ${SONAR_CHECK}"
  echo "  Require branches to be up to date before merging"
fi

echo
echo "=== Done ==="
