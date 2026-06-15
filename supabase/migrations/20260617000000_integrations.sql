-- ============================================================
-- Collect — PM-software integrations
-- Migration: 20260617000000_integrations.sql
-- ============================================================
-- Stores per-account connections to external property management
-- systems (Buildium, Yardi, AppFolio, RealPage). `config` holds
-- provider-specific credentials and is only ever read/written via
-- server actions using the regular (RLS-scoped) client, so RLS here
-- restricts management to owner/admin.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. integrations
-- ════════════════════════════════════════════════════════════

create table if not exists public.integrations (
  id               uuid        primary key default gen_random_uuid(),
  account_id       uuid        not null references public.accounts(id) on delete cascade,
  provider         text        not null
                      check (provider in ('buildium','yardi','appfolio','realpage')),
  status           text        not null default 'disconnected'
                      check (status in ('disconnected','connected','error')),
  config           jsonb       not null default '{}'::jsonb,
  last_synced_at   timestamptz,
  last_sync_error  text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (account_id, provider)
);

alter table public.integrations enable row level security;

create index if not exists integrations_account_idx on public.integrations (account_id);

create trigger set_account_id before insert on public.integrations
  for each row execute function public.set_account_id_default();

create trigger touch_updated_at before update on public.integrations
  for each row execute function public.touch_updated_at();


-- ════════════════════════════════════════════════════════════
-- 2. RLS policies — owner/admin manage their account's integrations
-- ════════════════════════════════════════════════════════════

drop policy if exists "integrations: admins read"   on public.integrations;
drop policy if exists "integrations: admins insert" on public.integrations;
drop policy if exists "integrations: admins update" on public.integrations;
drop policy if exists "integrations: admins delete" on public.integrations;

create policy "integrations: admins read"
  on public.integrations for select
  using (public.has_account_role(account_id, array['owner','admin']));

create policy "integrations: admins insert"
  on public.integrations for insert
  with check (public.has_account_role(account_id, array['owner','admin']));

create policy "integrations: admins update"
  on public.integrations for update
  using  (public.has_account_role(account_id, array['owner','admin']))
  with check (public.has_account_role(account_id, array['owner','admin']));

create policy "integrations: admins delete"
  on public.integrations for delete
  using (public.has_account_role(account_id, array['owner','admin']));
