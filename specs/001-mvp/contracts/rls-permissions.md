# RLS Permissions Contract

**Feature**: `001-mvp` | **Covers**: FR-USER-01, FR-GUEST-01, AC-USER-04, AC-USER-05, AC-GUEST-01, AC-GUEST-02

## Role capabilities matrix

| Action | Admin | Edit | Guest |
|--------|:-----:|:----:|:-----:|
| Create home | ✓ | — | — |
| Edit home details | ✓ | — | — |
| Invite / revoke users | ✓ | — | — |
| Change roles | ✓ | — | — |
| CRUD service providers | ✓ | ✓ | Read† |
| CRUD documents | ✓ | ✓‡ | Read† |
| CRUD procedures | ✓ | ✓‡ | Read† |
| Update step status | ✓ | ✓‡ | — |
| View activity log | ✓ | ✓ | — |
| Settings / sign out | ✓ | ✓ | ✓ |

† Only rows where `visibility = 'guest'`  
‡ Only rows where `visibility` in (`edit`, `guest`)

## SQL helper

```sql
create or replace function get_user_role(p_home_id uuid)
returns home_role as $$
  select role from memberships
  where home_id = p_home_id and user_id = auth.uid()
$$ language sql stable security definer;
```

## Example policies

### `procedure_steps` — update

```sql
-- Edit and Admin can update steps on procedures they can access
create policy "steps_update" on procedure_steps for update using (
  exists (
    select 1 from procedures p
    join memberships m on m.home_id = p.home_id
    where p.id = procedure_steps.procedure_id
      and m.user_id = auth.uid()
      and (
        m.role = 'admin'
        or (m.role = 'edit' and p.visibility in ('edit', 'guest'))
      )
  )
);
```

### `procedure_steps` — guest blocked from update

Guest role has SELECT only policy filtered by `procedures.visibility = 'guest'`. No INSERT/UPDATE/DELETE policy → default deny (**AC-GUEST-05**).

## Client mirror

`PermissionService.can(_ action: Action, on entity: Entity, role: HomeRole)` must match RLS rules so UI hides/disabled controls before a doomed API call (**AC-PROC-02**, **AC-GUEST-02**).

## Deep link / navigation guard

Before presenting any detail view:

```swift
guard permissionService.can(.read, entity, role) else {
  showAccessDenied()  // AC-GUEST-02
  return
}
```

## Verification

Integration tests insert rows as each role via Supabase test client and assert allowed/denied operations match this matrix.
