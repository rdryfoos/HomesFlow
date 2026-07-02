-- HomeFlow MVP initial schema
-- @covers FR-HOME-01, FR-USER-01, FR-PROC-01, FR-LOG-01, NFR-SEC-01

-- Enums
create type public.home_role as enum ('owner', 'manager', 'guest');
create type public.step_status as enum ('not_started', 'in_progress', 'complete', 'na');
create type public.procedure_status as enum ('not_started', 'in_progress', 'complete', 'na');
create type public.visibility as enum ('owner', 'manager', 'guest');
create type public.invite_status as enum ('pending', 'accepted', 'revoked');

-- updated_at trigger
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Profiles
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Homes
create table public.homes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  street_address text not null,
  photo_url text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger homes_updated_at
  before update on public.homes
  for each row execute function public.set_updated_at();

-- Memberships
create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.home_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (home_id, user_id)
);

create index memberships_home_id_idx on public.memberships (home_id);
create index memberships_user_id_idx on public.memberships (user_id);

create trigger memberships_updated_at
  before update on public.memberships
  for each row execute function public.set_updated_at();

-- Auto-owner membership when home is created
create or replace function public.handle_new_home()
returns trigger as $$
begin
  insert into public.memberships (home_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_home_created
  after insert on public.homes
  for each row execute function public.handle_new_home();

-- Invites
create table public.invites (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  email text not null,
  role public.home_role not null check (role in ('manager', 'guest')),
  token text not null unique,
  status public.invite_status not null default 'pending',
  invited_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index invites_token_idx on public.invites (token) where status = 'pending';

create trigger invites_updated_at
  before update on public.invites
  for each row execute function public.set_updated_at();

-- Service providers
create table public.service_providers (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  company_name text not null,
  service_type text not null,
  account_number text,
  phone text,
  website text,
  hours text,
  notes text,
  visibility public.visibility not null default 'manager',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger service_providers_updated_at
  before update on public.service_providers
  for each row execute function public.set_updated_at();

-- Documents
create table public.documents (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  title text not null,
  category text,
  storage_path text,
  visibility public.visibility not null default 'manager',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger documents_updated_at
  before update on public.documents
  for each row execute function public.set_updated_at();

-- Procedures
create table public.procedures (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  title text not null,
  category text,
  description text,
  status public.procedure_status not null default 'not_started',
  visibility public.visibility not null default 'manager',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index procedures_home_id_idx on public.procedures (home_id);

create trigger procedures_updated_at
  before update on public.procedures
  for each row execute function public.set_updated_at();

-- Procedure steps
create table public.procedure_steps (
  id uuid primary key default gen_random_uuid(),
  procedure_id uuid not null references public.procedures (id) on delete cascade,
  sort_order int not null,
  title text not null,
  status public.step_status not null default 'not_started',
  notes text,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index procedure_steps_procedure_id_idx on public.procedure_steps (procedure_id);

create trigger procedure_steps_updated_at
  before update on public.procedure_steps
  for each row execute function public.set_updated_at();

-- Activity log (append-only)
create table public.activity_log (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references public.homes (id) on delete cascade,
  actor_id uuid not null references public.profiles (id),
  entity_type text not null,
  entity_id uuid,
  action text not null,
  summary text not null,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index activity_log_home_id_idx on public.activity_log (home_id, created_at desc);

-- RLS helpers
create or replace function public.get_user_role(p_home_id uuid)
returns public.home_role as $$
  select role from public.memberships
  where home_id = p_home_id and user_id = auth.uid()
$$ language sql stable security definer;

create or replace function public.is_home_member(p_home_id uuid)
returns boolean as $$
  select exists (
    select 1 from public.memberships
    where home_id = p_home_id and user_id = auth.uid()
  )
$$ language sql stable security definer;

create or replace function public.visibility_allows(p_role public.home_role, p_vis public.visibility)
returns boolean as $$
  select case p_role
    when 'owner' then true
    when 'manager' then p_vis in ('manager', 'guest')
    when 'guest' then p_vis = 'guest'
  end
$$ language sql immutable;

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.homes enable row level security;
alter table public.memberships enable row level security;
alter table public.invites enable row level security;
alter table public.service_providers enable row level security;
alter table public.documents enable row level security;
alter table public.procedures enable row level security;
alter table public.procedure_steps enable row level security;
alter table public.activity_log enable row level security;

-- Profiles: own row
create policy profiles_select on public.profiles for select using (id = auth.uid());
create policy profiles_update on public.profiles for update using (id = auth.uid());

-- Homes: members read; owner write
create policy homes_select on public.homes for select
  using (public.is_home_member(id));

create policy homes_insert on public.homes for insert
  with check (created_by = auth.uid());

create policy homes_update on public.homes for update
  using (public.get_user_role(id) = 'owner');

create policy homes_delete on public.homes for delete
  using (public.get_user_role(id) = 'owner');

-- Memberships
create policy memberships_select on public.memberships for select
  using (public.is_home_member(home_id));

create policy memberships_insert on public.memberships for insert
  with check (public.get_user_role(home_id) = 'owner');

create policy memberships_update on public.memberships for update
  using (public.get_user_role(home_id) = 'owner');

create policy memberships_delete on public.memberships for delete
  using (public.get_user_role(home_id) = 'owner');

-- Invites: owner only
create policy invites_all on public.invites for all
  using (public.get_user_role(home_id) = 'owner')
  with check (public.get_user_role(home_id) = 'owner');

-- Service providers
create policy providers_select on public.service_providers for select
  using (
    public.is_home_member(home_id)
    and public.visibility_allows(public.get_user_role(home_id), visibility)
  );

create policy providers_write on public.service_providers for insert
  with check (
    public.get_user_role(home_id) in ('owner', 'manager')
  );

create policy providers_update on public.service_providers for update
  using (public.get_user_role(home_id) in ('owner', 'manager'));

create policy providers_delete on public.service_providers for delete
  using (public.get_user_role(home_id) in ('owner', 'manager'));

-- Documents
create policy documents_select on public.documents for select
  using (
    public.is_home_member(home_id)
    and public.visibility_allows(public.get_user_role(home_id), visibility)
  );

create policy documents_write on public.documents for insert
  with check (public.get_user_role(home_id) in ('owner', 'manager'));

create policy documents_update on public.documents for update
  using (public.get_user_role(home_id) in ('owner', 'manager'));

create policy documents_delete on public.documents for delete
  using (public.get_user_role(home_id) in ('owner', 'manager'));

-- Procedures
create policy procedures_select on public.procedures for select
  using (
    public.is_home_member(home_id)
    and public.visibility_allows(public.get_user_role(home_id), visibility)
  );

create policy procedures_write on public.procedures for insert
  with check (public.get_user_role(home_id) in ('owner', 'manager'));

create policy procedures_update on public.procedures for update
  using (public.get_user_role(home_id) in ('owner', 'manager'));

create policy procedures_delete on public.procedures for delete
  using (public.get_user_role(home_id) in ('owner', 'manager'));

-- Procedure steps: read via procedure access; update owner/manager
create policy steps_select on public.procedure_steps for select
  using (
    exists (
      select 1 from public.procedures p
      where p.id = procedure_id
        and public.is_home_member(p.home_id)
        and public.visibility_allows(public.get_user_role(p.home_id), p.visibility)
    )
  );

create policy steps_insert on public.procedure_steps for insert
  with check (
    exists (
      select 1 from public.procedures p
      where p.id = procedure_id
        and public.get_user_role(p.home_id) in ('owner', 'manager')
    )
  );

create policy steps_update on public.procedure_steps for update
  using (
    exists (
      select 1 from public.procedures p
      where p.id = procedure_id
        and public.get_user_role(p.home_id) in ('owner', 'manager')
        and public.visibility_allows(public.get_user_role(p.home_id), p.visibility)
    )
  );

create policy steps_delete on public.procedure_steps for delete
  using (
    exists (
      select 1 from public.procedures p
      where p.id = procedure_id
        and public.get_user_role(p.home_id) in ('owner', 'manager')
    )
  );

-- Activity log: members read; members insert
create policy activity_log_select on public.activity_log for select
  using (public.is_home_member(home_id));

create policy activity_log_insert on public.activity_log for insert
  with check (
    public.is_home_member(home_id)
    and actor_id = auth.uid()
  );

-- Storage buckets
insert into storage.buckets (id, name, public)
values
  ('home-photos', 'home-photos', false),
  ('documents', 'documents', false),
  ('procedure-attachments', 'procedure-attachments', false)
on conflict (id) do nothing;
