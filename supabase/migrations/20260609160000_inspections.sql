-- ============================================================
-- Collect — Inspections (Phase 3)
-- Migration: 20260609160000_inspections.sql
-- ============================================================
-- Adds the move-in / move-out inspection workflow. Each inspection
-- visits a unit, scans its rooms, and captures condition evidence.
-- A move_out inspection can reference a move_in baseline so the
-- web dashboard can diff conditions and produce a deposit-deduction
-- report.
--
-- Reuses the existing scan engine: existing collections get a
-- nullable inspection_id so scans done during an inspection are
-- automatically associated with it.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. inspections
-- ════════════════════════════════════════════════════════════

create table if not exists public.inspections (
  id                     uuid        primary key default gen_random_uuid(),
  account_id             uuid        not null references public.accounts(id)    on delete cascade,
  unit_id                uuid        not null references public.units(id)       on delete cascade,
  inspection_type        text        not null
                           check (inspection_type in ('move_in','move_out','routine','turn')),
  status                 text        not null default 'in_progress'
                           check (status in ('in_progress','completed','cancelled')),
  inspector_id           uuid        references auth.users(id),
  scheduled_at           timestamptz,
  completed_at           timestamptz,
  notes                  text        not null default '',
  -- move_out inspections reference the move_in baseline for diffing
  baseline_inspection_id uuid        references public.inspections(id),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  deleted_at             timestamptz
);

alter table public.inspections enable row level security;

create index if not exists inspections_account_idx on public.inspections (account_id, deleted_at);
create index if not exists inspections_unit_idx    on public.inspections (unit_id,    deleted_at);
-- Fast lookup of the latest completed move_in for baseline selection.
create index if not exists inspections_type_status_idx
  on public.inspections (unit_id, inspection_type, status)
  where deleted_at is null;


-- ════════════════════════════════════════════════════════════
-- 2. inspection_rooms — rooms visited during an inspection
-- ════════════════════════════════════════════════════════════
-- Lightweight link so we know which rooms were checked, even before
-- a scan collection exists for them.

create table if not exists public.inspection_rooms (
  id              uuid        primary key default gen_random_uuid(),
  account_id      uuid        not null references public.accounts(id)       on delete cascade,
  inspection_id   uuid        not null references public.inspections(id)    on delete cascade,
  room_id         uuid        not null references public.rooms(id)          on delete cascade,
  condition_note  text        not null default '',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (inspection_id, room_id)
);

alter table public.inspection_rooms enable row level security;

create index if not exists inspection_rooms_inspection_idx on public.inspection_rooms (inspection_id);
create index if not exists inspection_rooms_account_idx    on public.inspection_rooms (account_id);


-- ════════════════════════════════════════════════════════════
-- 3. Tag collections with their inspection
-- ════════════════════════════════════════════════════════════

alter table public.collections
  add column if not exists inspection_id uuid references public.inspections(id) on delete set null;

create index if not exists collections_inspection_idx on public.collections (inspection_id);


-- ════════════════════════════════════════════════════════════
-- 4. Auto-fill triggers
-- ════════════════════════════════════════════════════════════

create trigger set_account_id before insert on public.inspections
  for each row execute function public.set_account_id_default();

create trigger set_account_id before insert on public.inspection_rooms
  for each row execute function public.set_account_id_default();


-- ════════════════════════════════════════════════════════════
-- 5. updated_at triggers
-- ════════════════════════════════════════════════════════════

drop trigger if exists touch_inspections_updated      on public.inspections;
drop trigger if exists touch_inspection_rooms_updated on public.inspection_rooms;

create trigger touch_inspections_updated
  before update on public.inspections
  for each row execute function public.touch_updated_at();

create trigger touch_inspection_rooms_updated
  before update on public.inspection_rooms
  for each row execute function public.touch_updated_at();


-- ════════════════════════════════════════════════════════════
-- 6. RLS policies
-- ════════════════════════════════════════════════════════════

-- inspections
drop policy if exists "inspections: members read"    on public.inspections;
drop policy if exists "inspections: members insert"  on public.inspections;
drop policy if exists "inspections: managers update" on public.inspections;
drop policy if exists "inspections: managers delete" on public.inspections;

create policy "inspections: members read"
  on public.inspections for select
  using (public.is_account_member(account_id));

create policy "inspections: members insert"
  on public.inspections for insert
  with check (public.is_account_member(account_id));

create policy "inspections: managers update"
  on public.inspections for update
  using  (public.has_account_role(account_id, array['owner','admin','manager']))
  with check (public.has_account_role(account_id, array['owner','admin','manager']));

create policy "inspections: managers delete"
  on public.inspections for delete
  using (public.has_account_role(account_id, array['owner','admin','manager']));

-- inspection_rooms (same pattern)
drop policy if exists "inspection_rooms: members read"    on public.inspection_rooms;
drop policy if exists "inspection_rooms: members insert"  on public.inspection_rooms;
drop policy if exists "inspection_rooms: managers update" on public.inspection_rooms;
drop policy if exists "inspection_rooms: managers delete" on public.inspection_rooms;

create policy "inspection_rooms: members read"
  on public.inspection_rooms for select
  using (public.is_account_member(account_id));

create policy "inspection_rooms: members insert"
  on public.inspection_rooms for insert
  with check (public.is_account_member(account_id));

create policy "inspection_rooms: managers update"
  on public.inspection_rooms for update
  using  (public.has_account_role(account_id, array['owner','admin','manager']))
  with check (public.has_account_role(account_id, array['owner','admin','manager']));

create policy "inspection_rooms: managers delete"
  on public.inspection_rooms for delete
  using (public.has_account_role(account_id, array['owner','admin','manager']));
