-- ============================================================
-- Collect — Multifamily Data Model (Phase 2)
-- Migration: 20260609140000_multifamily_model.sql
-- ============================================================
-- Adds the building/unit layer required by property managers.
-- Homeowner data is untouched — the existing property→floor→room
-- hierarchy keeps working unchanged.
--
-- PM hierarchy: Property(complex) → Building → Unit → Room → Collection → Asset
-- Common areas: Property(complex) → Building? → CommonArea → Room → Collection → Asset
--
-- rooms.floor_id becomes nullable so PM rooms can belong to a
-- unit (or common area) instead of a homeowner floor.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. buildings
-- ════════════════════════════════════════════════════════════

create table if not exists public.buildings (
  id          uuid        primary key default gen_random_uuid(),
  account_id  uuid        not null references public.accounts(id)    on delete cascade,
  property_id uuid        not null references public.properties(id)  on delete cascade,
  name        text        not null,
  address     text        not null default '',
  floor_count integer,
  year_built  integer,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

alter table public.buildings enable row level security;

create index if not exists buildings_account_idx  on public.buildings (account_id,  deleted_at);
create index if not exists buildings_property_idx on public.buildings (property_id, deleted_at);


-- ════════════════════════════════════════════════════════════
-- 2. units — the leasable apartment; center of gravity for PM
-- ════════════════════════════════════════════════════════════

create table if not exists public.units (
  id                  uuid        primary key default gen_random_uuid(),
  account_id          uuid        not null references public.accounts(id)   on delete cascade,
  property_id         uuid        not null references public.properties(id) on delete cascade,
  -- nullable: simple properties may have no buildings
  building_id         uuid        references public.buildings(id)           on delete set null,
  unit_number         text        not null,
  floor_number        integer,
  sqft                integer,
  bedrooms            numeric(4,1),
  bathrooms           numeric(4,1),
  lease_status        text        not null default 'vacant'
                        check (lease_status in ('vacant','occupied','notice','eviction')),
  turn_status         text        not null default 'clean'
                        check (turn_status in ('clean','needs_turn','in_progress','turned')),
  current_tenant_name text,
  lease_start         date,
  lease_end           date,
  monthly_rent        numeric(10,2),
  notes               text        not null default '',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);

alter table public.units enable row level security;

create index if not exists units_account_idx      on public.units (account_id,  deleted_at);
create index if not exists units_property_idx     on public.units (property_id, deleted_at);
create index if not exists units_building_idx     on public.units (building_id, deleted_at);
-- Vacancy dashboards filter by lease_status; keep this fast.
create index if not exists units_vacancy_idx      on public.units (account_id, lease_status) where deleted_at is null;


-- ════════════════════════════════════════════════════════════
-- 3. common_areas — shared spaces (lobby, gym, pool, etc.)
-- ════════════════════════════════════════════════════════════

create table if not exists public.common_areas (
  id          uuid        primary key default gen_random_uuid(),
  account_id  uuid        not null references public.accounts(id)    on delete cascade,
  property_id uuid        not null references public.properties(id)  on delete cascade,
  building_id uuid        references public.buildings(id)            on delete set null,
  name        text        not null,
  area_type   text        not null default 'other'
                check (area_type in ('lobby','gym','pool','hallway','laundry','parking','office','other')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

alter table public.common_areas enable row level security;

create index if not exists common_areas_property_idx on public.common_areas (property_id, deleted_at);
create index if not exists common_areas_account_idx  on public.common_areas (account_id,  deleted_at);


-- ════════════════════════════════════════════════════════════
-- 4. Extend rooms for the PM hierarchy
-- ════════════════════════════════════════════════════════════
-- floor_id was NOT NULL (homeowner only). PM rooms belong to a unit
-- or a common_area instead of a floor, so we drop the constraint.

alter table public.rooms alter column floor_id drop not null;

alter table public.rooms
  add column if not exists unit_id        uuid references public.units(id)        on delete cascade,
  add column if not exists common_area_id uuid references public.common_areas(id) on delete cascade;

create index if not exists rooms_unit_id_idx        on public.rooms (unit_id,        deleted_at);
create index if not exists rooms_common_area_id_idx on public.rooms (common_area_id, deleted_at);


-- ════════════════════════════════════════════════════════════
-- 5. Auto-fill account_id on insert (keeps existing clients working)
-- ════════════════════════════════════════════════════════════
-- Reuse the SECURITY DEFINER function from the Phase 0 migration.

create trigger set_account_id before insert on public.buildings
  for each row execute function public.set_account_id_default();

create trigger set_account_id before insert on public.units
  for each row execute function public.set_account_id_default();

create trigger set_account_id before insert on public.common_areas
  for each row execute function public.set_account_id_default();


-- ════════════════════════════════════════════════════════════
-- 6. Auto-update updated_at
-- ════════════════════════════════════════════════════════════
-- Reuse touch_updated_at() defined in Phase 0.

drop trigger if exists touch_buildings_updated   on public.buildings;
drop trigger if exists touch_units_updated       on public.units;
drop trigger if exists touch_common_areas_updated on public.common_areas;

create trigger touch_buildings_updated
  before update on public.buildings
  for each row execute function public.touch_updated_at();

create trigger touch_units_updated
  before update on public.units
  for each row execute function public.touch_updated_at();

create trigger touch_common_areas_updated
  before update on public.common_areas
  for each row execute function public.touch_updated_at();


-- ════════════════════════════════════════════════════════════
-- 7. RLS policies
-- ════════════════════════════════════════════════════════════
-- Pattern: all account members can read + insert; only
-- owners/admins/managers can update or soft-delete.

-- buildings
drop policy if exists "buildings: members read"     on public.buildings;
drop policy if exists "buildings: members insert"   on public.buildings;
drop policy if exists "buildings: managers update"  on public.buildings;
drop policy if exists "buildings: managers delete"  on public.buildings;

create policy "buildings: members read"
  on public.buildings for select
  using (public.is_account_member(account_id));

create policy "buildings: members insert"
  on public.buildings for insert
  with check (public.is_account_member(account_id));

create policy "buildings: managers update"
  on public.buildings for update
  using  (public.has_account_role(account_id, array['owner','admin','manager']))
  with check (public.has_account_role(account_id, array['owner','admin','manager']));

create policy "buildings: managers delete"
  on public.buildings for delete
  using (public.has_account_role(account_id, array['owner','admin','manager']));

-- units
drop policy if exists "units: members read"    on public.units;
drop policy if exists "units: members insert"  on public.units;
drop policy if exists "units: managers update" on public.units;
drop policy if exists "units: managers delete" on public.units;

create policy "units: members read"
  on public.units for select
  using (public.is_account_member(account_id));

create policy "units: members insert"
  on public.units for insert
  with check (public.is_account_member(account_id));

create policy "units: managers update"
  on public.units for update
  using  (public.has_account_role(account_id, array['owner','admin','manager']))
  with check (public.has_account_role(account_id, array['owner','admin','manager']));

create policy "units: managers delete"
  on public.units for delete
  using (public.has_account_role(account_id, array['owner','admin','manager']));

-- common_areas
drop policy if exists "common_areas: members read"    on public.common_areas;
drop policy if exists "common_areas: members insert"  on public.common_areas;
drop policy if exists "common_areas: managers update" on public.common_areas;
drop policy if exists "common_areas: managers delete" on public.common_areas;

create policy "common_areas: members read"
  on public.common_areas for select
  using (public.is_account_member(account_id));

create policy "common_areas: members insert"
  on public.common_areas for insert
  with check (public.is_account_member(account_id));

create policy "common_areas: managers update"
  on public.common_areas for update
  using  (public.has_account_role(account_id, array['owner','admin','manager']))
  with check (public.has_account_role(account_id, array['owner','admin','manager']));

create policy "common_areas: managers delete"
  on public.common_areas for delete
  using (public.has_account_role(account_id, array['owner','admin','manager']));
