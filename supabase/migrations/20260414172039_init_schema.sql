-- ============================================================
-- Collect – Initial Schema
-- ============================================================

-- Profiles: one row per auth user, auto-created by trigger
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  name        text,
  plan        text not null default 'free',
  scans_used  int  not null default 0,
  created_at  timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, name)
  values (new.id, new.email, new.raw_user_meta_data->>'name')
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Scans: one row per analysis run
create table if not exists public.scans (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade,
  prompt_type text,
  asset_count int,
  success     boolean default true,
  created_at  timestamptz default now()
);

alter table public.scans enable row level security;

create policy "Users can view own scans"
  on public.scans for select
  using (auth.uid() = user_id);

-- Feature flags
create table if not exists public.feature_flags (
  key         text primary key,
  enabled     boolean not null default true,
  description text
);

insert into public.feature_flags (key, enabled, description) values
  ('new_signups',      true,  'Allow new user registrations'),
  ('maintenance_mode', false, 'Show maintenance screen in app')
on conflict (key) do nothing;
