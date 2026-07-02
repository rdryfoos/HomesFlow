-- Storage policies, co-member profile reads, accept_invite RPC
-- @covers FR-HOME-01, FR-USER-02, AC-USER-01

-- Co-members can read each other's profile (email, display name for People tab)
create policy profiles_select_home_members on public.profiles for select
  using (
    exists (
      select 1
      from public.memberships mine
      join public.memberships theirs on mine.home_id = theirs.home_id
      where mine.user_id = auth.uid()
        and theirs.user_id = profiles.id
    )
  );

-- Accept pending invite (invitee must match invite email)
create or replace function public.accept_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.invites%rowtype;
  v_membership_id uuid;
  v_user_email text;
begin
  select email into v_user_email from auth.users where id = auth.uid();
  if v_user_email is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_invite
  from public.invites
  where token = p_token and status = 'pending'
  for update;

  if not found then
    raise exception 'Invalid or expired invite';
  end if;

  if lower(v_invite.email) <> lower(v_user_email) then
    raise exception 'Invite email does not match signed-in account';
  end if;

  insert into public.memberships (home_id, user_id, role)
  values (v_invite.home_id, auth.uid(), v_invite.role)
  on conflict (home_id, user_id) do update
    set role = excluded.role, updated_at = now()
  returning id into v_membership_id;

  update public.invites
  set status = 'accepted', updated_at = now()
  where id = v_invite.id;

  return v_membership_id;
end;
$$;

grant execute on function public.accept_invite(text) to authenticated;

-- home-photos: members read; owner/manager write
create policy home_photos_select on storage.objects for select
  using (
    bucket_id = 'home-photos'
    and public.is_home_member(((storage.foldername(name))[1])::uuid)
  );

create policy home_photos_insert on storage.objects for insert
  with check (
    bucket_id = 'home-photos'
    and public.get_user_role(((storage.foldername(name))[1])::uuid) in ('owner', 'manager')
  );

create policy home_photos_update on storage.objects for update
  using (
    bucket_id = 'home-photos'
    and public.get_user_role(((storage.foldername(name))[1])::uuid) in ('owner', 'manager')
  );

create policy home_photos_delete on storage.objects for delete
  using (
    bucket_id = 'home-photos'
    and public.get_user_role(((storage.foldername(name))[1])::uuid) in ('owner', 'manager')
  );
