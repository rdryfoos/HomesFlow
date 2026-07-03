# Data Model: HomesFlow MVP

**Feature**: `001-mvp` | **Date**: 2026-06-28

Supabase PostgreSQL schema. All tables include `updated_at timestamptz` for conflict resolution. RLS enabled on every table.

## Enums

```sql
create type home_role as enum ('owner', 'manager', 'guest');
create type step_status as enum ('not_started', 'in_progress', 'complete', 'na');
create type procedure_status as enum ('not_started', 'in_progress', 'complete', 'na');
create type visibility as enum ('owner', 'manager', 'guest');
create type invite_status as enum ('pending', 'accepted', 'revoked');
```

## Entity relationship overview

```text
profiles ──┬── memberships ── homes
           │                    ├── service_providers
           │                    ├── documents
           │                    ├── procedures ── procedure_steps
           │                    ├── invites
           │                    └── activity_log
```

## Tables

### `profiles`

Extends Supabase `auth.users`. One row per authenticated user.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | FK → auth.users.id |
| display_name | text | |
| email | text | Denormalized from auth |
| created_at | timestamptz | |
| updated_at | timestamptz | |

### `homes`

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| name | text NOT NULL | |
| street_address | text NOT NULL | |
| photo_url | text | Supabase Storage path |
| created_by | uuid FK → profiles.id | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

**Covers**: FR-HOME-01, AC-HOME-01…03, AC-HOME-06, AC-HOME-07, AC-HOME-08

### `memberships`

User ↔ home with role. Source of truth for permissions.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| home_id | uuid FK → homes.id | |
| user_id | uuid FK → profiles.id | |
| role | home_role NOT NULL | admin / edit / guest |
| created_at | timestamptz | |
| updated_at | timestamptz | |

Unique: `(home_id, user_id)`

**Covers**: FR-USER-01, FR-USER-02, AC-USER-04…06

### `invites`

Pending invitations before user accepts.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| home_id | uuid FK → homes.id | |
| email | text NOT NULL | |
| role | home_role NOT NULL | edit or guest (admin via transfer only) |
| token | text UNIQUE NOT NULL | URL-safe random |
| status | invite_status | pending / accepted / revoked |
| invited_by | uuid FK → profiles.id | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

**Covers**: FR-GUEST-02, AC-USER-01…03

### `service_providers`

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| home_id | uuid FK → homes.id | |
| company_name | text NOT NULL | |
| service_type | text NOT NULL | electric, propane, etc. |
| account_number | text | |
| phone | text | |
| website | text | |
| hours | text | |
| notes | text | |
| visibility | visibility DEFAULT 'manager' | guest sees if visibility ≤ guest |
| created_at | timestamptz | |
| updated_at | timestamptz | |

**Covers**: FR-HOME-02, AC-HOME-04…05

### `documents`

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| home_id | uuid FK → homes.id | |
| title | text NOT NULL | |
| category | text | manuals, wifi, care, etc. |
| storage_path | text | Supabase Storage |
| visibility | visibility NOT NULL | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

**Covers**: FR-HOME-03, AC-GUEST-01…03

### `procedures`

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| home_id | uuid FK → homes.id | |
| title | text NOT NULL | |
| category | text | emergency, seasonal, etc. |
| description | text | |
| status | procedure_status | Aggregated from steps |
| visibility | visibility NOT NULL | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

**Covers**: FR-PROC-01, FR-GUEST-01

### `procedure_steps`

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| procedure_id | uuid FK → procedures.id ON DELETE CASCADE | |
| sort_order | int NOT NULL | Stable ordering; reorder updates this column |
| title | text NOT NULL | Editable by Owner/Manager via long-press Rename |
| status | step_status DEFAULT 'not_started' | |
| notes | text | Free-text per run |
| photo_url | text | Storage path in `procedure-attachments` bucket |
| created_at | timestamptz | |
| updated_at | timestamptz | |

**Covers**: FR-PROC-02, FR-PROC-03, AC-PROC-01…07, AC-GUEST-04…05

**Client UX (Owner/Manager)**: tap step → toggle complete; long-press → Rename / Delete / Move Up / Move Down; Steps section **Add** → insert at end. Guest: read-only — no structure controls.

### `activity_log`

Append-only audit trail.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| home_id | uuid FK → homes.id | |
| actor_id | uuid FK → profiles.id | |
| entity_type | text | home, step, provider, membership, etc. |
| entity_id | uuid | |
| action | text | created, updated, deleted, conflict, denied |
| summary | text | Human-readable |
| metadata | jsonb | Prior values, conflict details |
| created_at | timestamptz | Immutable |

**Covers**: FR-LOG-01, AC-HOME-03, AC-PROC-01, AC-GUEST-05

### `log_book_entries`

User-authored Log Book (FR-LOG-02, added 2026-07-03; Phase 13 — not yet migrated).

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | Client-generated for offline append (AC-LOG-03) |
| home_id | uuid FK → homes.id | |
| procedure_id | uuid FK → procedures.id, nullable | Null = household scope (AC-LOG-01); set = procedure scope (AC-LOG-02) |
| author_id | uuid FK → profiles.id | |
| body | text | Free-form entry |
| created_at | timestamptz | Client write time |
| received_at | timestamptz | Server receipt; starts the 10-minute edit grace window (AC-LOG-04) |
| edited_at | timestamptz, nullable | Must be within `received_at + 10 min`, enforced server-side |

RLS: Owner/Manager read + insert; author-only update within grace window; **no Guest access** (AC-LOG-06). Append-only offline via outbox — no conflict resolution needed (AC-LOG-03).

## RLS policy summary

| Table | Owner | Edit | Guest |
|-------|-------|------|-------|
| homes | CRUD own memberships | Read | Read |
| memberships | CRUD | Read | Read own |
| invites | CRUD | — | — |
| service_providers | CRUD | CRUD | Read if visibility=guest |
| documents | CRUD | CRUD if visibility≤edit | Read if visibility=guest |
| procedures | CRUD | CRUD if visibility≤edit | Read if visibility=guest |
| procedure_steps | CRUD | CRUD if parent procedure visibility≤edit | Read only |
| activity_log | Read + insert | Read + insert | Read own home |
| log_book_entries | Read + insert; author edit in grace window | Read + insert; author edit in grace window | — (no access, AC-LOG-06) |

Helper SQL function: `get_user_role(home_id uuid) returns home_role` — used in all policies.

## Local (SwiftData) mirror

Cache tables mirror server schema plus:

| Field | Purpose |
|-------|---------|
| `sync_status` | synced / pending / conflict |
| `local_updated_at` | Client timestamp for outbox ordering |
| `server_updated_at` | Last known server `updated_at` |

### `mutation_outbox`

| Column | Purpose |
|--------|---------|
| id | UUID |
| entity_type | Table name |
| entity_id | Record id |
| operation | insert / update / delete |
| payload | JSON encoded fields |
| created_at | Queue time |

**Covers**: NFR-OFFL-01, AC-SYNC-01…03

### Conflict semantics (data-type-aware, 2026-07-03)

| Data type | Rule |
|-----------|------|
| Step/procedure status | Timestamp-wins, **except** terminal statuses (Complete / N/A) never silently regress (AC-SYNC-05); loser notified with re-apply guidance (AC-SYNC-06) |
| Entity field edits | Timestamp-wins whole-record (AC-SYNC-01); field-level merge (AC-SYNC-02) deferred post-MVP |
| Structural actions (step/procedure/provider CRUD, memberships) | Connectivity-gated — blocked offline (AC-SYNC-07) |
| Log Book entries | Append-only; no conflicts by construction (AC-LOG-03) |

## Storage buckets

| Bucket | Path pattern | Access |
|--------|--------------|--------|
| home-photos | `{home_id}/{uuid}.jpg` | Members read; Owner/Manager write; client uploads display-optimized JPEG (AC-HOME-06) |
| documents | `{home_id}/{uuid}` | Per document visibility |
| procedure-attachments | `{home_id}/{procedure_id}/{uuid}` | Per procedure visibility |

## Indexes

- `memberships(home_id)`, `memberships(user_id)`
- `procedures(home_id)`, `procedure_steps(procedure_id)`
- `activity_log(home_id, created_at desc)`
- `invites(token)` where status = pending
