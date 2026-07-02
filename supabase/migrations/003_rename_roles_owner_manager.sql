-- Rename membership roles and content visibility: admin→owner, edit→manager (guest unchanged)

alter type public.home_role rename value 'admin' to 'owner';
alter type public.home_role rename value 'edit' to 'manager';

alter type public.visibility rename value 'admin' to 'owner';
alter type public.visibility rename value 'edit' to 'manager';

create or replace function public.handle_new_home()
returns trigger as $$
begin
  insert into public.memberships (home_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end;
$$ language plpgsql security definer;

alter table public.invites
  drop constraint if exists invites_role_check;

alter table public.invites
  add constraint invites_role_check check (role in ('manager', 'guest'));

create or replace function public.visibility_allows(p_role public.home_role, p_vis public.visibility)
returns boolean as $$
  select case p_role
    when 'owner' then true
    when 'manager' then p_vis in ('manager', 'guest')
    when 'guest' then p_vis = 'guest'
    else false
  end;
$$ language sql stable;
