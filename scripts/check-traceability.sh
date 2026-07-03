#!/usr/bin/env bash
# Gate 2 — post-build traceability check (see traceability.md §6).
#
# Modes:
#   (no args)  Check the golden thread; exit non-zero on any violation.
#   --matrix   Regenerate specs/001-mvp/coverage.md from the same extraction.
#   --json     Print the per-ID coverage dataset as JSON to stdout.
#   --canvas   Update the local Golden Thread Coverage canvas (Cursor; not in git).
#   --refresh  Gate 2 check + --matrix + --canvas (run after traceability changes).
#
# Checks (default mode):
#   1. The ID registry (PRD) matches spec.md and tasks.md exactly (no drift).
#   2. Every task in tasks.md declares a Traces field.
#   3. No untraced scope: every @covers ID in source and every AC ID encoded in a
#      test name exists in the PRD registry.
#   4. No silent gaps: every AC in the registry either has a test that names it,
#      or appears in an unchecked task in tasks.md (tracked debt).
set -euo pipefail
cd "$(dirname "$0")/.."

# Deterministic sort/grep across macOS and Linux (CI regenerates and diffs the matrix).
export LC_ALL=C

# Domain segment allows digits (e.g. A11Y) but must start with a letter.
ID_RE='(FR|NFR|AC|US)-[A-Z][A-Z0-9]{1,5}-[0-9]{2,}[a-z]?'
PRD=HomesFlow.prd.md
SPEC=specs/001-mvp/spec.md
TASKS=specs/001-mvp/tasks.md
MATRIX=specs/001-mvp/coverage.md
SVG=specs/001-mvp/coverage.svg
CANVAS="${GOLDEN_THREAD_CANVAS:-$HOME/.cursor/projects/Users-rik-Developer-HomeFlow/canvases/golden-thread-coverage.canvas.tsx}"
SRC_DIRS=(ios/HomeFlow)
TEST_DIRS=(ios/HomeFlowTests ios/HomeFlowUITests)

MODE="${1:-check}"

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------------------
# Extraction (shared by all modes)
# ---------------------------------------------------------------------------
grep -Eoh "$ID_RE" "$PRD"   | sort -u > "$tmp/prd.txt"
grep -Eoh "$ID_RE" "$SPEC"  | sort -u > "$tmp/spec.txt"
grep -Eoh "$ID_RE" "$TASKS" | sort -u > "$tmp/tasks.txt"

grep -rEoh "@covers.*" "${SRC_DIRS[@]}" "${TEST_DIRS[@]}" --include='*.swift' 2>/dev/null \
  | grep -Eo "$ID_RE" | sort -u > "$tmp/covers.txt" || true

grep -rEoh 'func test_[A-Za-z0-9_]+' "${TEST_DIRS[@]}" --include='*.swift' 2>/dev/null \
  | sed 's/^func //' | sort -u > "$tmp/test_names.txt" || true

grep -Eo 'AC_[A-Z][A-Z0-9]{1,5}_[0-9]{2,}[a-z]?' "$tmp/test_names.txt" \
  | tr '_' '-' | sort -u > "$tmp/test_acs.txt" || true

grep -E '^- \[ \]' "$TASKS" | grep -Eo "$ID_RE" | sort -u > "$tmp/pending.txt" || true

# status|taskId|traces — one line per task (Traces segment only)
sed -nE 's/^- \[(x| )\] (T[0-9]+[a-z]?).*\*\*Traces\*\*: (.*)$/\1|\2|\3/p' "$TASKS" > "$tmp/task_map.txt"
# status|taskId|full line — for US story labels like [US-EDIT-01]
sed -nE 's/^- \[(x| )\] (T[0-9]+[a-z]?)(.*)$/\1|\2|\3/p' "$TASKS" > "$tmp/task_full.txt"

# Per-ID facts. Word-edge match: an ID is never followed by another digit or
# a lowercase suffix character unless it is a different (longer) ID.
# US IDs associate via their story label anywhere in the task line; all other
# types associate strictly via the Traces field.
tasks_for() { # $1=id  $2=status(x or space)
  local map="$tmp/task_map.txt"
  case "$1" in US-*) map="$tmp/task_full.txt" ;; esac
  awk -F'|' -v id="$1" -v st="$2" '$1==st && $3 ~ (id"([^0-9a-z]|$)") { printf "%s ", $2 }' "$map" | sed 's/ $//'
}
tests_for() { # $1=id (AC only)
  local underscored; underscored=$(echo "$1" | tr '-' '_')
  grep -E "test_${underscored}([^0-9a-z]|$)" "$tmp/test_names.txt" | paste -sd' ' - || true
}
is_covered() { grep -qx "$1" "$tmp/covers.txt"; }
is_tested()  { grep -qx "$1" "$tmp/test_acs.txt"; }

status_for() { # $1=id  $2=done_tasks  $3=pending_tasks
  local id="$1" done_t="$2" pend_t="$3" type="${1%%-*}"
  if [ "$type" = "AC" ]; then
    if is_tested "$id"; then echo "verified"; return; fi
    if is_covered "$id"; then
      if [ -n "$pend_t" ]; then echo "implemented-test-pending"; else echo "gap"; fi
      return
    fi
  else
    if is_covered "$id"; then
      if [ -n "$pend_t" ]; then echo "in-progress"; else echo "implemented"; fi
      return
    fi
  fi
  if [ -n "$pend_t" ]; then
    if [ -n "$done_t" ]; then echo "in-progress"; else echo "planned"; fi
    return
  fi
  if [ -n "$done_t" ]; then echo "done-no-covers"; return; fi
  echo "unmapped"
}

json_list() {
  echo "$1" | tr ' ' '\n' | { grep -v '^$' || true; } | sed 's/.*/"&"/' | paste -sd',' -
}

write_json_file() { # $1=output path
  local out="$1"
  {
    echo "["
    first=1
    while IFS= read -r id; do
      done_t=$(tasks_for "$id" "x")
      pend_t=$(tasks_for "$id" " ")
      tests=""
      if [ "${id%%-*}" = "AC" ]; then tests=$(tests_for "$id"); fi
      covered=false
      if is_covered "$id"; then covered=true; fi
      status=$(status_for "$id" "$done_t" "$pend_t")
      domain=$(echo "$id" | cut -d- -f2)
      if [ $first -eq 0 ]; then echo ","; fi
      first=0
      printf '  {"id":"%s","type":"%s","domain":"%s","status":"%s","covered":%s,"doneTasks":[%s],"pendingTasks":[%s],"tests":[%s]}' \
        "$id" "${id%%-*}" "$domain" "$status" "$covered" \
        "$(json_list "$done_t")" "$(json_list "$pend_t")" "$(json_list "$tests")"
    done < "$tmp/prd.txt"
    echo
    echo "]"
  } > "$out"
}

emit_matrix() {
  label_for() {
    case "$1" in
      verified)                 echo "Verified" ;;
      implemented-test-pending) echo "Implemented — test pending" ;;
      implemented)              echo "Implemented" ;;
      in-progress)              echo "In progress" ;;
      planned)                  echo "Planned" ;;
      gap)                      echo "GAP — implemented, no test, untracked" ;;
      done-no-covers)           echo "Tasks done — no @covers" ;;
      unmapped)                 echo "Unmapped" ;;
    esac
  }

  section() { # $1=type  $2=heading  $3=include tests column (yes/no)
    local type="$1" heading="$2" with_tests="$3"
    echo "## $heading"
    echo
    if [ "$with_tests" = "yes" ]; then
      echo "| ID | Status | Done tasks | Pending tasks | Tests |"
      echo "|----|--------|------------|---------------|-------|"
    else
      echo "| ID | Status | Done tasks | Pending tasks |"
      echo "|----|--------|------------|---------------|"
    fi
    while IFS= read -r id; do
      [ "${id%%-*}" = "$type" ] || continue
      local done_t pend_t tests status
      done_t=$(tasks_for "$id" "x")
      pend_t=$(tasks_for "$id" " ")
      status=$(label_for "$(status_for "$id" "$done_t" "$pend_t")")
      if [ "$with_tests" = "yes" ]; then
        tests=$(tests_for "$id" | tr ' ' '\n' | { grep -v '^$' || true; } | sed 's/.*/`&`/' \
          | awk '{ printf "%s%s", (NR > 1 ? "<br>" : ""), $0 } END { print "" }')
        echo "| $id | $status | ${done_t:-—} | ${pend_t:-—} | ${tests:-—} |"
      else
        echo "| $id | $status | ${done_t:-—} | ${pend_t:-—} |"
      fi
    done < "$tmp/prd.txt"
    echo
  }

  total_ids=$(wc -l < "$tmp/prd.txt" | tr -d ' ')
  total_acs=$(grep -c '^AC-' "$tmp/prd.txt")
  verified=0; test_pending=0; planned_acs=0
  while IFS= read -r id; do
    done_t=$(tasks_for "$id" "x"); pend_t=$(tasks_for "$id" " ")
    case "$(status_for "$id" "$done_t" "$pend_t")" in
      verified) verified=$((verified+1)) ;;
      implemented-test-pending) test_pending=$((test_pending+1)) ;;
      planned) planned_acs=$((planned_acs+1)) ;;
    esac
  done < <(grep '^AC-' "$tmp/prd.txt")

  {
    echo "# Coverage Matrix: HomesFlow MVP"
    echo
    echo "**GENERATED FILE — do not edit.** Regenerate with \`bash scripts/check-traceability.sh --matrix\`."
    echo "CI fails if this file is stale. Source of truth: \`HomesFlow.prd.md\` registry × \`tasks.md\` × \`@covers\` annotations × test names."
    echo
    echo "## Summary"
    echo
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Registry IDs | $total_ids |"
    echo "| Acceptance criteria | $total_acs |"
    echo "| ACs verified (test passing in suite) | $verified |"
    echo "| ACs implemented — test pending | $test_pending |"
    echo "| ACs planned (tracked, not implemented) | $planned_acs |"
    echo
    section "AC"  "Acceptance criteria" "yes"
    section "FR"  "Functional requirements" "no"
    section "NFR" "Non-functional requirements" "no"
    section "US"  "User stories" "no"
  } > "$MATRIX"

  emit_svg
  echo "Wrote $MATRIX and $SVG ($total_ids IDs; $verified/$total_acs ACs verified)."
}

# Deterministic coverage chart embedded by README.md. No timestamps — CI
# regenerates and diffs this file, so content must be a pure function of state.
emit_svg() {
  local tracked=$((total_acs - verified - test_pending))
  local bw=744 bx=8
  local vw=$((verified * bw / total_acs))
  local tw=$((test_pending * bw / total_acs))
  local rw=$((bw - vw - tw))
  local pct=$((verified * 100 / total_acs))

  cat > "$SVG" <<SVGEOF
<svg xmlns="http://www.w3.org/2000/svg" width="760" height="150" viewBox="0 0 760 150" role="img" aria-label="Golden thread coverage: $verified of $total_acs acceptance criteria verified">
  <style>
    text { font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif; }
    .title { font-size: 20px; font-weight: 600; fill: #1f2328; }
    .sub   { font-size: 13px; fill: #57606a; }
    .leg   { font-size: 13px; fill: #1f2328; }
  </style>
  <text x="8" y="26" class="title">Golden Thread Coverage — $verified/$total_acs acceptance criteria verified ($pct%)</text>
  <text x="8" y="48" class="sub">$total_ids registry IDs · PRD → spec → tasks → @covers → tests · Gate 2 enforced in CI</text>
  <clipPath id="bar"><rect x="$bx" y="62" width="$bw" height="26" rx="7"/></clipPath>
  <rect x="$bx" y="62" width="$bw" height="26" rx="7" fill="#eaeef2"/>
  <g clip-path="url(#bar)">
    <rect x="$bx" y="62" width="$vw" height="26" fill="#2da44e"/>
    <rect x="$((bx + vw))" y="62" width="$tw" height="26" fill="#d4a72c"/>
    <rect x="$((bx + vw + tw))" y="62" width="$rw" height="26" fill="#afb8c1"/>
  </g>
  <circle cx="16" cy="116" r="6" fill="#2da44e"/>
  <text x="28" y="121" class="leg">Verified by named test ($verified)</text>
  <circle cx="236" cy="116" r="6" fill="#d4a72c"/>
  <text x="248" y="121" class="leg">Implemented, test pending ($test_pending)</text>
  <circle cx="476" cy="116" r="6" fill="#afb8c1"/>
  <text x="488" y="121" class="leg">Tracked debt — planned tasks ($tracked)</text>
  <text x="8" y="145" class="sub">Generated by scripts/check-traceability.sh — stale copies fail CI.</text>
</svg>
SVGEOF
}

# ---------------------------------------------------------------------------
# Mode routing
# ---------------------------------------------------------------------------
if [ "$MODE" = "--json" ]; then
  write_json_file /dev/stdout
  exit 0
fi

if [ "$MODE" = "--canvas" ]; then
  write_json_file "$tmp/data.json"
  if [ ! -f "$CANVAS" ]; then
    echo "Canvas not found: $CANVAS" >&2
    echo "Set GOLDEN_THREAD_CANVAS or open the Golden Thread Coverage canvas once in Cursor." >&2
    exit 1
  fi
  python3 scripts/update-golden-thread-canvas.py "$tmp/data.json" "$CANVAS"
  exit 0
fi

if [ "$MODE" = "--matrix" ]; then
  emit_matrix
  exit 0
fi

if [ "$MODE" = "--refresh" ]; then
  emit_matrix
  if [ -f "$CANVAS" ]; then
    write_json_file "$tmp/data.json"
    python3 scripts/update-golden-thread-canvas.py "$tmp/data.json" "$CANVAS"
  else
    echo "Skipping canvas (not found: $CANVAS)" >&2
  fi
  MODE=check
fi

# ---------------------------------------------------------------------------
# Mode: check (default, and final step of --refresh)
# ---------------------------------------------------------------------------

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
while IFS= read -r ac; do
  if grep -qx "$ac" "$tmp/test_acs.txt"; then continue; fi   # tested
  if grep -qx "$ac" "$tmp/pending.txt"; then continue; fi    # tracked debt
  err "gap: $ac has no test and no pending task in $TASKS"
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
