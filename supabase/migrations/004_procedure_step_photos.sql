-- Step photo attachments (FR-PROC-03)

alter table public.procedure_steps
  add column if not exists photo_url text;

-- procedure-attachments: members read; owner/manager write (path: {home_id}/{procedure_id}/{file})
create policy procedure_attachments_select on storage.objects for select
  using (
    bucket_id = 'procedure-attachments'
    and public.is_home_member(((storage.foldername(name))[1])::uuid)
  );

create policy procedure_attachments_insert on storage.objects for insert
  with check (
    bucket_id = 'procedure-attachments'
    and public.get_user_role(((storage.foldername(name))[1])::uuid) in ('owner', 'manager')
  );

create policy procedure_attachments_update on storage.objects for update
  using (
    bucket_id = 'procedure-attachments'
    and public.get_user_role(((storage.foldername(name))[1])::uuid) in ('owner', 'manager')
  );

create policy procedure_attachments_delete on storage.objects for delete
  using (
    bucket_id = 'procedure-attachments'
    and public.get_user_role(((storage.foldername(name))[1])::uuid) in ('owner', 'manager')
  );
