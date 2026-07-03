# Coverage Matrix: HomesFlow MVP

**GENERATED FILE — do not edit.** Regenerate with `bash scripts/check-traceability.sh --matrix`.
CI fails if this file is stale. Source of truth: `HomesFlow.prd.md` registry × `tasks.md` × `@covers` annotations × test names.

## Summary

| Metric | Count |
|--------|-------|
| Registry IDs | 79 |
| Acceptance criteria | 50 |
| ACs verified (test passing in suite) | 36 |
| ACs implemented — test pending | 4 |
| ACs planned (tracked, not implemented) | 10 |

## Acceptance criteria

| ID | Status | Done tasks | Pending tasks | Tests |
|----|--------|------------|---------------|-------|
| AC-A11Y-01 | Verified | T066a | T069a | `test_AC_A11Y_01_hero_height_grows_with_text_size`<br>`test_AC_A11Y_01_scale_factor_is_monotonic_across_sizes` |
| AC-A11Y-02 | Verified | T021b T066a | T069a | `test_AC_A11Y_02_every_section_tab_has_meaningful_voiceover_text`<br>`test_AC_A11Y_02_step_status_values_cover_all_statuses` |
| AC-A11Y-03 | Verified | T066a | T069a | `test_AC_A11Y_03_reduce_motion_disables_animation` |
| AC-GUEST-01 | Verified | T057 T062 T065 | T064 | `test_AC_GUEST_01_guest_fields_only` |
| AC-GUEST-02 | Verified | T005 T010 T058 T063a | — | `test_AC_GUEST_02_restricted_deep_link_denied` |
| AC-GUEST-03 | Verified | T059 T063b | — | `test_AC_GUEST_03_offline_visibility_sync` |
| AC-GUEST-04 | Verified | T047c T060 T063c | — | `test_AC_GUEST_04_guest_procedure_read_only` |
| AC-GUEST-05 | Verified | T061 T063 | — | `test_AC_GUEST_05_guest_cannot_update_step` |
| AC-HOME-01 | Verified | T018 T019 | T022 | `test_AC_HOME_01_valid_home_passes_validation` |
| AC-HOME-02 | Verified | T018 T023 | — | `test_AC_HOME_02_empty_address_rejected`<br>`test_AC_HOME_02_empty_name_rejected` |
| AC-HOME-03 | Verified | T020 T024 | — | `test_AC_HOME_03_local_newer_keeps_pending_local`<br>`test_AC_HOME_03_server_newer_overwrites_pending_local`<br>`test_AC_HOME_03_synced_home_applies_server` |
| AC-HOME-04 | Verified | T051 T052 T055 | — | `test_AC_HOME_04_local_newer_edit_is_kept`<br>`test_AC_HOME_04_provider_edit_propagates` |
| AC-HOME-05 | Verified | T037 T053 T056 | — | `test_AC_HOME_05_delete_wins_over_edit`<br>`test_AC_HOME_05_local_only_insert_survives_pull`<br>`test_AC_HOME_05_synced_row_removed_silently` |
| AC-HOME-06 | Verified | T019a T024a | — | `test_AC_HOME_06_invalid_image_data_rejected`<br>`test_AC_HOME_06_small_image_not_upscaled`<br>`test_AC_HOME_06_upload_resizes_before_storage` |
| AC-HOME-07 | Verified | T019a T024b | — | `test_AC_HOME_07_hero_renders_from_local_cache`<br>`test_AC_HOME_07_removed_photo_no_longer_cached` |
| AC-HOME-08 | Verified | T019 T024c | — | `test_AC_HOME_08_blocked_errors_carry_actionable_guidance`<br>`test_AC_HOME_08_connected_upload_runs_sync_then_passes_when_synced`<br>`test_AC_HOME_08_offline_edit_without_photo_defers_sync`<br>`test_AC_HOME_08_photo_blocked_until_home_synced` |
| AC-HOME-09 | Implemented — test pending | T021a | T024d | — |
| AC-HOME-10 | Implemented — test pending | T021a T021c | T024e | — |
| AC-HOME-11 | Implemented — test pending | T021b T065 | T024f | — |
| AC-HOME-12 | Verified | T065a T065d | — | `test_AC_HOME_12_contacts_and_files_add_for_owner_and_manager`<br>`test_AC_HOME_12_guest_has_no_section_add_actions`<br>`test_AC_HOME_12_matches_repository_manage_flags`<br>`test_AC_HOME_12_people_add_owner_only`<br>`test_AC_HOME_12_section_add_actions_use_parallel_construction` |
| AC-HOME-13 | Verified | T065b T065e T065d | — | `test_AC_HOME_13_local_file_name_falls_back_to_id_and_extension`<br>`test_AC_HOME_13_local_file_name_uses_storage_path`<br>`test_AC_HOME_13_non_success_download_throws`<br>`test_AC_HOME_13_preview_icon_maps_by_extension`<br>`test_AC_HOME_13_streams_download_to_preview_directory` |
| AC-HOME-14 | Verified | T065c T065d | — | `test_AC_HOME_14_apply_pick_fills_title_from_file_name`<br>`test_AC_HOME_14_apply_pick_preserves_existing_title`<br>`test_AC_HOME_14_camera_file_name_is_dated_jpeg`<br>`test_AC_HOME_14_includes_camera_when_available`<br>`test_AC_HOME_14_offers_library_and_file_browser_sources`<br>`test_AC_HOME_14_upload_requires_valid_draft_and_file_data` |
| AC-LOG-01 | Planned | — | T078 T084 | — |
| AC-LOG-02 | Planned | — | T079 T084 | — |
| AC-LOG-03 | Planned | — | T080 T085 | — |
| AC-LOG-04 | Planned | — | T081 T085 | — |
| AC-LOG-05 | Planned | — | T082 T086 | — |
| AC-LOG-06 | Planned | — | T077 T083 T086 | — |
| AC-PROC-01 | Verified | T042 T046 T048 | — | `test_AC_PROC_01_complete_and_na_steps_mark_procedure_complete`<br>`test_AC_PROC_01_completed_step_counts_toward_progress`<br>`test_AC_PROC_01_final_step_completion_marks_procedure_complete` |
| AC-PROC-02 | Verified | T010 T044 T049 | — | `test_AC_PROC_02_guest_cannot_update_guest_visible_step`<br>`test_AC_PROC_02_manager_cannot_update_owner_only_step` |
| AC-PROC-03 | Verified | T037 T045 T050 | — | `test_AC_PROC_03_local_newer_keeps_pending_local`<br>`test_AC_PROC_03_server_newer_overwrites_pending_local` |
| AC-PROC-04 | Verified | T047b T050a | — | `test_AC_PROC_04_manager_can_manage_step_structure`<br>`test_AC_PROC_04_manager_cannot_manage_owner_only_procedure_steps`<br>`test_AC_PROC_04_owner_can_manage_step_structure` |
| AC-PROC-05 | Verified | T047b T050a | — | `test_AC_PROC_05_move_down_swaps_with_next_step`<br>`test_AC_PROC_05_move_is_noop_at_list_boundaries`<br>`test_AC_PROC_05_move_up_swaps_with_previous_step`<br>`test_AC_PROC_05_new_step_appends_at_end` |
| AC-PROC-06 | Verified | T047a T050b | — | `test_AC_PROC_06_structure_changes_produce_activity_summaries` |
| AC-PROC-07 | Verified | T047c T050c | — | `test_AC_PROC_07_guest_cannot_manage_step_structure` |
| AC-PROC-08 | Verified | T047d T050d | — | `test_AC_PROC_08_photo_indicator_and_edit_controls`<br>`test_AC_PROC_08_tap_toggle_status_mapping`<br>`test_AC_PROC_08_terminal_statuses_strike_through` |
| AC-SYNC-01 | Verified | T011 T020 T034 T037 T038 T045 T053 T072 | T027 | `test_AC_SYNC_01_conflict_decision_is_idempotent`<br>`test_AC_SYNC_01_home_timestamp_wins_matrix`<br>`test_AC_SYNC_01_offline_overwrite_notifies_loser`<br>`test_AC_SYNC_01_provider_timestamp_wins_matrix`<br>`test_AC_SYNC_01_server_delete_matrix` |
| AC-SYNC-02 | Implemented — test pending | T011 T072 | T035 T039 | — |
| AC-SYNC-03 | Verified | T011 T036 T040 T072 | — | `test_AC_SYNC_03_permission_denied_revert_matrix` |
| AC-SYNC-04 | Verified | T015 T037 T040a | — | `test_AC_SYNC_04_pending_state_announced_to_voiceover`<br>`test_AC_SYNC_04_pending_sync_visible_on_dashboard` |
| AC-SYNC-05 | Planned | — | T074 T074a | — |
| AC-SYNC-06 | Planned | — | T075 T075a | — |
| AC-SYNC-07 | Planned | — | T076 T076a | — |
| AC-USER-01 | Verified | T025 T026 T030 | — | `test_AC_USER_01_invite_accepted_grants_role`<br>`test_AC_USER_01_invite_email_validation_and_token_shape` |
| AC-USER-02 | Verified | T025 T031 | — | `test_AC_USER_02_revoked_token_invalid` |
| AC-USER-03 | Planned | — | T027 T033a | — |
| AC-USER-04 | Verified | T028 T032 | — | `test_AC_USER_04_edit_role_can_modify_procedures`<br>`test_AC_USER_04_manager_can_update_step` |
| AC-USER-05 | Verified | T028 T033 | — | `test_AC_USER_05_guest_role_read_only` |
| AC-USER-06 | Verified | T028 T029 T033b | — | `test_AC_USER_06_concurrent_role_change_audit` |
| AC-USER-07 | Verified | T025 T026 T033c | — | `test_AC_USER_07_paste_token_accepts_invite` |

## Functional requirements

| ID | Status | Done tasks | Pending tasks |
|----|--------|------------|---------------|
| FR-AUTH-01 | In progress | T006 T008 T013 T014 T067 | T017 |
| FR-GUEST-01 | In progress | T005 T057 | T071 |
| FR-GUEST-02 | Implemented | T025 | — |
| FR-HOME-01 | Implemented | T004 T007 T015 T018 T019 T019a T021 | — |
| FR-HOME-02 | Implemented | T051 T054 | — |
| FR-HOME-03 | Implemented | T007 T065 | — |
| FR-LOG-01 | Implemented | T012 T020 T029 T046 T061 | — |
| FR-LOG-02 | Planned | — | T077 |
| FR-NAV-01 | Implemented | T021a T021b T021c | — |
| FR-NOTIF-01 | Implemented | T066 | — |
| FR-PROC-01 | Implemented | T004 T041 | — |
| FR-PROC-02 | Implemented | T041 T042 T047a | — |
| FR-PROC-03 | Implemented | T007 T043 | — |
| FR-USER-01 | In progress | T004 T005 T010 | T071 |
| FR-USER-02 | Implemented | T025 T028 T068 | — |

## Non-functional requirements

| ID | Status | Done tasks | Pending tasks |
|----|--------|------------|---------------|
| NFR-A11Y-01 | Implemented | T066a | — |
| NFR-OFFL-01 | Implemented | T009 T011 | — |
| NFR-PERF-01 | In progress | T016 T019a T047 T065e | T072a |
| NFR-REL-01 | Planned | — | T072c |
| NFR-SCALE-01 | Planned | — | T072b |
| NFR-SEC-01 | Implemented | T003 T008 | — |
| NFR-SYNC-01 | In progress | T072 | T072a |

## User stories

| ID | Status | Done tasks | Pending tasks |
|----|--------|------------|---------------|
| US-ADMIN-01 | In progress | T014 T015 T016 T018 T019 T019a T020 T021 T021a T021b T021c T023 T024 T024a T024b T024c | T017 T022 T024d T024e T024f |
| US-ADMIN-02 | In progress | T025 T026 T030 T031 T033c | T027 T033a |
| US-ADMIN-03 | Tasks done — no @covers | T028 T029 T032 T033 T033b | — |
| US-EDIT-01 | Tasks done — no @covers | T041 T042 T043 T044 T045 T046 T047 T047a T047b T047c T047d T048 T049 T050 T050a T050b T050c T050d | — |
| US-EDIT-02 | Tasks done — no @covers | T051 T052 T053 T054 T055 T056 | — |
| US-GUEST-01 | In progress | T057 T058 T059 T062 T063a T063b | T064 |
| US-GUEST-02 | Tasks done — no @covers | T060 T061 T063 T063c | — |

