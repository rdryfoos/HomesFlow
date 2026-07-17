#!/usr/bin/env bash
# Finish Craft Phase E: PR-only merge to main + required craft/Sonar checks.
# Usage: bash scripts/finish-phase-e.sh
#
# Prerequisites:
#   - gh authenticated with admin rights on the repo
#   - craft-gate + SonarCloud Code Analysis have run successfully on main at least once
#   - Prefer CI-based Sonar (T089) so git multicriteria apply; see sonar-disposition.md
set -euo pipefail

REPO="rdryfoos/HomesFlow"
BRANCH="main"
CRAFT_CHECK="craft-gate"
SONAR_CHECK="SonarCloud Code Analysis"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI required" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Run: gh auth login" >&2
  exit 1
fi

echo "=== Phase E finish — branch protection on ${BRANCH} ==="
echo "Repo: ${REPO}"
echo "Required checks: ${CRAFT_CHECK}, ${SONAR_CHECK}"
echo "PR required before merge; enforce_admins=true (no silent bypass)"
echo

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
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": false
}
EOF

echo
echo "✓ Branch protection updated for Phase E"
echo
echo "Verify: https://github.com/${REPO}/settings/branches"
echo "Expected:"
echo "  - Require a pull request before merging (0 approvals OK for solo)"
echo "  - Require status checks: ${CRAFT_CHECK}, ${SONAR_CHECK}"
echo "  - Require branches to be up to date"
echo "  - Do not allow bypassing the above settings (enforce admins)"
echo
echo "Break-glass: temporarily disable enforce_admins in settings, then re-run this script."
echo "=== Done ==="
