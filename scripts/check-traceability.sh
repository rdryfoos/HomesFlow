#!/usr/bin/env bash
# Gate 2 — post-build traceability check (see traceability.md §6).
#
# Verifies the golden thread PRD → spec → tasks → code → tests is machine-checkable:
#   1. The ID registry (PRD) matches spec.md and tasks.md exactly (no drift).
#   2. Every task in tasks.md declares a Traces field.
#   3. No untraced scope: every @covers ID in source and every AC ID encoded in a
#      test name exists in the PRD registry.
#   4. No silent gaps: every AC in the registry either has a test that names it,
#      or appears in an unchecked task in tasks.md (tracked debt).
#
# Exit code 0 = thread intact. Non-zero = at least one violation (printed to stderr).
set -euo pipefail
cd "$(dirname "$0")/.."

ID_RE='(FR|NFR|AC|US)-[A-Z]{2,6}-[0-9]{2,}[a-z]?'
PRD=HomeFlow.prd.md
SPEC=specs/001-mvp/spec.md
TASKS=specs/001-mvp/tasks.md
SRC_DIRS=(ios/HomeFlow)
TEST_DIRS=(ios/HomeFlowTests ios/HomeFlowUITests)

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

grep -Eoh "$ID_RE" "$PRD"   | sort -u > "$tmp/prd.txt"
grep -Eoh "$ID_RE" "$SPEC"  | sort -u > "$tmp/spec.txt"
grep -Eoh "$ID_RE" "$TASKS" | sort -u > "$tmp/tasks.txt"

# --- 1. Registry drift ------------------------------------------------------
for artifact in spec tasks; do
  if ! diff -q "$tmp/prd.txt" "$tmp/$artifact.txt" >/dev/null; then
    err "ID drift between $PRD and $artifact:"
    diff "$tmp/prd.txt" "$tmp/$artifact.txt" | sed 's/^/  /' >&2 || true
  fi
done

# --- 2. Tasks without a Traces field ----------------------------------------
untraced_tasks=$(grep -En '^- \[[ x]\] T[0-9]+' "$TASKS" | grep -v '\*\*Traces\*\*' || true)
if [ -n "$untraced_tasks" ]; then
  err "tasks missing a Traces field:"
  echo "$untraced_tasks" | sed 's/^/  /' >&2
fi

# --- 3. Untraced scope (code/tests referencing unknown IDs) ------------------
grep -rEoh "@covers.*" "${SRC_DIRS[@]}" "${TEST_DIRS[@]}" --include='*.swift' 2>/dev/null \
  | grep -Eo "$ID_RE" | sort -u > "$tmp/covers.txt" || true

grep -rEoh 'func test_[A-Za-z0-9_]+' "${TEST_DIRS[@]}" --include='*.swift' 2>/dev/null \
  | grep -Eo 'AC_[A-Z]{2,6}_[0-9]{2,}[a-z]?' | tr '_' '-' | sort -u > "$tmp/test_acs.txt" || true

orphan_covers=$(comm -13 "$tmp/prd.txt" "$tmp/covers.txt")
if [ -n "$orphan_covers" ]; then
  err "@covers IDs not in the PRD registry (untraced scope):"
  echo "$orphan_covers" | sed 's/^/  /' >&2
fi

orphan_tests=$(comm -13 <(grep '^AC-' "$tmp/prd.txt") "$tmp/test_acs.txt")
if [ -n "$orphan_tests" ]; then
  err "test names encode AC IDs not in the PRD registry (untraced scope):"
  echo "$orphan_tests" | sed 's/^/  /' >&2
fi

# --- 4. Gaps: AC with no test and no tracked (unchecked) task ----------------
grep -E '^- \[ \]' "$TASKS" | grep -Eo "$ID_RE" | sort -u > "$tmp/pending.txt" || true

gap_count=0
while IFS= read -r ac; do
  if grep -qx "$ac" "$tmp/test_acs.txt"; then continue; fi   # tested
  if grep -qx "$ac" "$tmp/pending.txt"; then continue; fi    # tracked debt
  err "gap: $ac has no test and no pending task in $TASKS"
  gap_count=$((gap_count + 1))
done < <(grep '^AC-' "$tmp/prd.txt")

# --- Summary -----------------------------------------------------------------
total_ids=$(wc -l < "$tmp/prd.txt" | tr -d ' ')
total_acs=$(grep -c '^AC-' "$tmp/prd.txt")
tested_acs=$(wc -l < "$tmp/test_acs.txt" | tr -d ' ')
covers_ids=$(wc -l < "$tmp/covers.txt" | tr -d ' ')

echo "Traceability summary:"
echo "  Registry IDs (PRD):        $total_ids"
echo "  ACs in registry:           $total_acs"
echo "  ACs with tests:            $tested_acs"
echo "  IDs with @covers in code:  $covers_ids"
echo "  Untested ACs are tracked as pending tasks unless flagged above."

if [ "$fail" -ne 0 ]; then
  echo "Gate 2: FAILED — golden thread broken (see FAIL lines above)." >&2
  exit 1
fi
echo "Gate 2: PASSED — golden thread intact."
