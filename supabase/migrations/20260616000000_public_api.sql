-- ============================================================
-- Collect — Public REST API: API keys
-- Migration: 20260616000000_public_api.sql
-- ============================================================
-- API keys authenticate requests to /api/v1/* (the public REST API).
-- Routes use a service-role client (bypasses RLS) and resolve
-- account_id from the key, so RLS here only governs management of
-- keys from within the dashboard (owner/admin only).
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. api_keys
-- ════════════════════════════════════════════════════════════

create table if not exists public.api_keys (
  id           uuid        primary key default gen_random_uuid(),
  account_id   uuid        not null references public.accounts(id) on delete cascade,
  name         text        not null,
  key_prefix   text        not null,
  key_hash     text        not null unique,
  scope        text        not null default 'read'
                  check (scope in ('read','read_write')),
  created_by   uuid        references auth.users(id),
  created_at   timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at   timestamptz
);

alter table public.api_keys enable row level security;

create index if not exists api_keys_account_idx on public.api_keys (account_id);
create unique index if not exists api_keys_hash_idx on public.api_keys (key_hash);

create trigger set_account_id before insert on public.api_keys
  for each row execute function public.set_account_id_default();


-- ════════════════════════════════════════════════════════════
-- 2. RLS policies — owner/admin manage their account's keys
-- ════════════════════════════════════════════════════════════

drop policy if exists "api_keys: admins read"   on public.api_keys;
drop policy if exists "api_keys: admins insert" on public.api_keys;
drop policy if exists "api_keys: admins update" on public.api_keys;
drop policy if exists "api_keys: admins delete" on public.api_keys;

create policy "api_keys: admins read"
  on public.api_keys for select
  using (public.has_account_role(account_id, array['owner','admin']));

create policy "api_keys: admins insert"
  on public.api_keys for insert
  with check (public.has_account_role(account_id, array['owner','admin']));

create policy "api_keys: admins update"
  on public.api_keys for update
  using  (public.has_account_role(account_id, array['owner','admin']))
  with check (public.has_account_role(account_id, array['owner','admin']));

create policy "api_keys: admins delete"
  on public.api_keys for delete
  using (public.has_account_role(account_id, array['owner','admin']));
