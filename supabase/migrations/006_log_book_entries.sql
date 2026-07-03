-- Communications Log (Log Book) — FR-LOG-02, AC-LOG-03, AC-LOG-04, AC-LOG-06
-- @covers FR-LOG-02, AC-LOG-03, AC-LOG-04, AC-LOG-06

create table public.log_book_entries (
  id uuid primary key,
  home_id uuid not null references public.homes (id) on delete cascade,
  procedure_id uuid references public.procedures (id) on delete set null,
  author_id uuid not null references public.profiles (id),
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null,
  received_at timestamptz not null default now(),
  edited_at timestamptz
);

create index log_book_entries_home_id_idx
  on public.log_book_entries (home_id, created_at desc);

create index log_book_entries_procedure_id_idx
  on public.log_book_entries (procedure_id)
  where procedure_id is not null;

alter table public.log_book_entries enable row level security;

-- AC-LOG-06: Guests have no access (no guest policies).
create policy log_book_select on public.log_book_entries
  for select using (
    public.get_user_role(home_id) in ('owner', 'manager')
  );

create policy log_book_insert on public.log_book_entries
  for insert with check (
    public.get_user_role(home_id) in ('owner', 'manager')
    and author_id = auth.uid()
  );

-- AC-LOG-04: author may edit within 10 minutes of server receipt.
create policy log_book_update on public.log_book_entries
  for update using (
    author_id = auth.uid()
    and public.get_user_role(home_id) in ('owner', 'manager')
    and now() <= received_at + interval '10 minutes'
  )
  with check (
    author_id = auth.uid()
    and public.get_user_role(home_id) in ('owner', 'manager')
    and now() <= received_at + interval '10 minutes'
  );
