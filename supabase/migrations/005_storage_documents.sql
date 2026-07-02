-- documents bucket storage policies (FR-HOME-03)
-- Path: {home_id}/{document_id}/{filename}

create policy documents_storage_select on storage.objects for select
  using (
    bucket_id = 'documents'
    and public.is_home_member(((storage.foldername(name))[1])::uuid)
  );

create policy documents_storage_insert on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and public.get_user_role(((storage.foldername(name))[1])::uuid) in ('owner', 'manager')
  );

create policy documents_storage_update on storage.objects for update
  using (
    bucket_id = 'documents'
    and public.get_user_role(((storage.foldername(name))[1])::uuid) in ('owner', 'manager')
  );

create policy documents_storage_delete on storage.objects for delete
  using (
    bucket_id = 'documents'
    and public.get_user_role(((storage.foldername(name))[1])::uuid) in ('owner', 'manager')
  );
