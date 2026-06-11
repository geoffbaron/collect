-- ============================================================
-- Collect — Capital Asset Register (Phase 4)
-- Migration: 20260612000000_capital_assets.sql
-- ============================================================
-- Tracks major building systems/equipment (HVAC units, roofs,
-- water heaters, appliances, etc.) for a property/building/unit/
-- common area. Always carries property_id (denormalized) so
-- portfolio-wide queries ("assets nearing end of life") don't
-- need joins through units/buildings. building_id / unit_id /
-- common_area_id are nullable — an asset can belong to any one
-- of them, or just the property as a whole.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. capital_assets
-- ════════════════════════════════════════════════════════════

create table if not exists public.capital_assets (
  id                      uuid        primary key default gen_random_uuid(),
  account_id              uuid        not null references public.accounts(id)     on delete cascade,
  property_id             uuid        not null references public.properties(id)   on delete cascade,
  building_id             uuid        references public.buildings(id)             on delete set null,
  unit_id                 uuid        references public.units(id)                 on delete set null,
  common_area_id          uuid        references public.common_areas(id)          on delete set null,
  name                    text        not null,
  asset_type              text        not null default 'other'
                            check (asset_type in ('hvac','roof','water_heater','appliance','electrical_panel','plumbing','elevator','structural','other')),
  manufacturer            text        not null default '',
  model                   text        not null default '',
  serial_number           text        not null default '',
  install_date            date,
  expected_lifespan_years integer,
  purchase_cost           numeric,
  condition               text        not null default 'good'
                            check (condition in ('excellent','good','fair','poor','needs_replacement')),
  warranty_expires        date,
  last_serviced_at        date,
  notes                   text        not null default '',
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  deleted_at              timestamptz
);

alter table public.capital_assets enable row level security;

create index if not exists capital_assets_account_idx  on public.capital_assets (account_id, deleted_at);
create index if not exists capital_assets_property_idx on public.capital_assets (property_id, deleted_at);
create index if not exists capital_assets_unit_idx     on public.capital_assets (unit_id, deleted_at);


-- ════════════════════════════════════════════════════════════
-- 2. Auto-fill / updated_at triggers
-- ════════════════════════════════════════════════════════════

create trigger set_account_id before insert on public.capital_assets
  for each row execute function public.set_account_id_default();

drop trigger if exists touch_capital_assets_updated on public.capital_assets;

create trigger touch_capital_assets_updated
  before update on public.capital_assets
  for each row execute function public.touch_updated_at();


-- ════════════════════════════════════════════════════════════
-- 3. RLS policies
-- ════════════════════════════════════════════════════════════

drop policy if exists "capital_assets: members read"    on public.capital_assets;
drop policy if exists "capital_assets: members insert"  on public.capital_assets;
drop policy if exists "capital_assets: managers update" on public.capital_assets;
drop policy if exists "capital_assets: managers delete" on public.capital_assets;

create policy "capital_assets: members read"
  on public.capital_assets for select
  using (public.is_account_member(account_id));

create policy "capital_assets: members insert"
  on public.capital_assets for insert
  with check (public.is_account_member(account_id));

create policy "capital_assets: managers update"
  on public.capital_assets for update
  using  (public.has_account_role(account_id, array['owner','admin','manager']))
  with check (public.has_account_role(account_id, array['owner','admin','manager']));

create policy "capital_assets: managers delete"
  on public.capital_assets for delete
  using (public.has_account_role(account_id, array['owner','admin','manager']));
