# Sync Protocol Contract

**Feature**: `001-mvp` | **Covers**: NFR-OFFL-01, AC-SYNC-01, AC-SYNC-02, AC-SYNC-03

## Outbox entry

```json
{
  "id": "uuid",
  "entity_type": "procedure_steps",
  "entity_id": "uuid",
  "operation": "update",
  "payload": { "status": "complete", "updated_at": "2026-06-28T12:00:00Z" },
  "client_updated_at": "2026-06-28T12:00:01Z"
}
```

## Push (client → server)

1. Dequeue outbox entries in FIFO order by `client_updated_at`.
2. For each entry, `UPSERT` or `DELETE` on Supabase table.
3. Server sets `updated_at = now()` on successful write.
4. On success: mark local row `sync_status = synced`, remove outbox entry.
5. On RLS denial (403): revert local change, remove outbox entry, surface permission error (**AC-SYNC-03**).

## Conflict detection (same entity, same field)

When server `updated_at` at read time differs from client's `server_updated_at` stale copy:

| Rule | Behavior |
|------|----------|
| **AC-SYNC-01** | Compare server `updated_at`. Later timestamp wins. Loser gets in-app notification + `activity_log` action=`conflict`. |
| **AC-SYNC-02** | If changed fields are disjoint sets, merge into one update; `activity_log` action=`merged`. |

## Pull (server → client)

```
GET */*?updated_at=gt.{last_synced_at}&home_id=in.(user_home_ids)
```

Apply rows to SwiftData. Update `last_synced_at` on completion.

## Realtime (optional, online enhancement)

Subscribe to `postgres_changes` on tables for user's homes. On event, upsert local row if incoming `updated_at` > local `server_updated_at`.

## Notification payloads (in-app)

| Event | Message template |
|-------|------------------|
| Overwritten offline edit | "Your change to {entity} was updated by {actor} while you were offline." |
| Delete won over edit | "Your edit to {provider} was removed because it was deleted on another device." |
| Permission reverted | "You no longer have permission to change {entity}. Your offline edit was reverted." |

## Test matrix (minimum)

| Test name | AC |
|-----------|-----|
| `test_AC_SYNC_01_offline_overwrite_notifies_loser` | AC-SYNC-01 |
| `test_AC_SYNC_02_disjoint_fields_merge` | AC-SYNC-02 |
| `test_AC_SYNC_03_stale_permission_reverts` | AC-SYNC-03 |
