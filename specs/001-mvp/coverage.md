# Coverage Matrix: HomeFlow MVP

**GENERATED FILE — do not edit.** Regenerate with `bash scripts/check-traceability.sh --matrix`.
CI fails if this file is stale. Source of truth: `HomeFlow.prd.md` registry × `tasks.md` × `@covers` annotations × test names.

## Summary

| Metric | Count |
|--------|-------|
| Registry IDs | 61 |
| Acceptance criteria | 34 |
| ACs verified (test passing in suite) | 19 |
| ACs implemented — test pending | 12 |
| ACs planned (tracked, not implemented) | 1 |

## Acceptance criteria

| ID | Status | Done tasks | Pending tasks | Tests |
|----|--------|------------|---------------|-------|
| AC-GUEST-01 | Verified | T057 T062 | T064 T065 | `test_AC_GUEST_01_guest_fields_only` |
| AC-GUEST-02 | Verified | T005 T010 T058 T063a | — | `test_AC_GUEST_02_restricted_deep_link_denied` |
| AC-GUEST-03 | Verified | T059 T063b | — | `test_AC_GUEST_03_offline_visibility_sync` |
| AC-GUEST-04 | Verified | T047c T060 T063c | — | `test_AC_GUEST_04_guest_procedure_read_only` |
| AC-GUEST-05 | Verified | T061 T063 | — | `test_AC_GUEST_05_guest_cannot_update_step` |
| AC-HOME-01 | Verified | T018 T019 | T022 | `test_AC_HOME_01_valid_home_passes_validation` |
| AC-HOME-02 | Verified | T018 T023 | — | `test_AC_HOME_02_empty_address_rejected`<br>`test_AC_HOME_02_empty_name_rejected` |
| AC-HOME-03 | Verified | T020 T024 | — | `test_AC_HOME_03_local_newer_keeps_pending_local`<br>`test_AC_HOME_03_server_newer_overwrites_pending_local`<br>`test_AC_HOME_03_synced_home_applies_server` |
| AC-HOME-04 | Verified | T051 T052 T055 | — | `test_AC_HOME_04_local_newer_edit_is_kept`<br>`test_AC_HOME_04_provider_edit_propagates` |
| AC-HOME-05 | Verified | T037 T053 T056 | — | `test_AC_HOME_05_delete_wins_over_edit`<br>`test_AC_HOME_05_local_only_insert_survives_pull`<br>`test_AC_HOME_05_synced_row_removed_silently` |
| AC-HOME-06 | Implemented — test pending | T019a | T024a | — |
| AC-HOME-07 | Implemented — test pending | T019a | T024b | — |
| AC-HOME-08 | Implemented — test pending | T019 | T024c | — |
| AC-HOME-09 | Implemented — test pending | T021a | T024d | — |
| AC-HOME-10 | Implemented — test pending | T021a T021c | T024e | — |
| AC-HOME-11 | Implemented — test pending | T021b | T024f T065 | — |
| AC-PROC-01 | Verified | T042 T046 T048 | — | `test_AC_PROC_01_completed_step_counts_toward_progress` |
| AC-PROC-02 | Verified | T010 T044 T049 | — | `test_AC_PROC_02_edit_cannot_update_admin_only_step`<br>`test_AC_PROC_02_guest_cannot_update_guest_visible_step` |
| AC-PROC-03 | Verified | T037 T045 T050 | — | `test_AC_PROC_03_local_newer_keeps_pending_local`<br>`test_AC_PROC_03_server_newer_overwrites_pending_local` |
| AC-PROC-04 | Verified | T047b T050a | — | `test_AC_PROC_04_admin_can_manage_step_structure`<br>`test_AC_PROC_04_edit_can_manage_step_structure`<br>`test_AC_PROC_04_edit_cannot_manage_admin_only_procedure_steps` |
| AC-PROC-05 | Verified | T047b T050a | — | `test_AC_PROC_05_move_down_swaps_with_next_step`<br>`test_AC_PROC_05_move_is_noop_at_list_boundaries`<br>`test_AC_PROC_05_move_up_swaps_with_previous_step`<br>`test_AC_PROC_05_new_step_appends_at_end` |
| AC-PROC-06 | Verified | T047a T050b | — | `test_AC_PROC_06_structure_changes_produce_activity_summaries` |
| AC-PROC-07 | Verified | T047c T050c | — | `test_AC_PROC_07_guest_cannot_manage_step_structure` |
| AC-SYNC-01 | Implemented — test pending | T011 T020 T034 T037 T045 T053 | T027 T038 T072 | — |
| AC-SYNC-02 | Implemented — test pending | T011 | T035 T039 T072 | — |
| AC-SYNC-03 | Implemented — test pending | T011 T036 | T040 T072 | — |
| AC-SYNC-04 | Implemented — test pending | T015 T037 | T040a | — |
| AC-USER-01 | Implemented — test pending | T025 T026 | T030 | — |
| AC-USER-02 | Implemented — test pending | T025 | T031 | — |
| AC-USER-03 | Planned | — | T027 T033a | — |
| AC-USER-04 | Verified | T028 | T032 | `test_AC_USER_04_edit_can_update_step` |
| AC-USER-05 | Verified | T028 T033 | — | `test_AC_USER_05_guest_role_read_only` |
| AC-USER-06 | In progress | T028 T029 | T033b | — |
| AC-USER-07 | In progress | T025 T026 | T033c | — |

## Functional requirements

| ID | Status | Done tasks | Pending tasks |
|----|--------|------------|---------------|
| FR-AUTH-01 | In progress | T006 T008 T013 T014 T067 | T017 |
| FR-GUEST-01 | In progress | T005 T057 | T071 |
| FR-GUEST-02 | Implemented | T025 | — |
| FR-HOME-01 | Implemented | T004 T007 T015 T018 T019 T019a T021 | — |
| FR-HOME-02 | Implemented | T051 T054 | — |
| FR-HOME-03 | In progress | T007 | T065 |
| FR-LOG-01 | Implemented | T012 T020 T029 T046 T061 | — |
| FR-NAV-01 | Implemented | T021a T021b T021c | — |
| FR-NOTIF-01 | Planned | — | T066 |
| FR-PROC-01 | Implemented | T004 T041 | — |
| FR-PROC-02 | Implemented | T041 T042 T047a | — |
| FR-PROC-03 | In progress | T007 | T043 |
| FR-USER-01 | In progress | T004 T005 T010 | T071 |
| FR-USER-02 | In progress | T025 T028 | T068 |

## Non-functional requirements

| ID | Status | Done tasks | Pending tasks |
|----|--------|------------|---------------|
| NFR-OFFL-01 | Implemented | T009 T011 | — |
| NFR-PERF-01 | In progress | T016 T019a T047 | T072a |
| NFR-REL-01 | Planned | — | T072c |
| NFR-SCALE-01 | Planned | — | T072b |
| NFR-SEC-01 | Implemented | T003 T008 | — |
| NFR-SYNC-01 | Planned | — | T072 T072a |

## User stories

| ID | Status | Done tasks | Pending tasks |
|----|--------|------------|---------------|
| US-ADMIN-01 | In progress | T014 T015 T016 T018 T019 T019a T020 T021 T021a T021b T021c T023 T024 | T017 T022 T024a T024b T024c T024d T024e T024f |
| US-ADMIN-02 | In progress | T025 T026 | T027 T030 T031 T033a T033c |
| US-ADMIN-03 | In progress | T028 T029 T033 | T032 T033b |
| US-EDIT-01 | In progress | T041 T042 T044 T045 T046 T047 T047a T047b T047c T048 T049 T050 T050a T050b T050c | T043 |
| US-EDIT-02 | Tasks done — no @covers | T051 T052 T053 T054 T055 T056 | — |
| US-GUEST-01 | In progress | T057 T058 T059 T062 T063a T063b | T064 |
| US-GUEST-02 | Tasks done — no @covers | T060 T061 T063 T063c | — |

