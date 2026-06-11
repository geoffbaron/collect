-- ============================================================
-- Collect — Work Orders (Phase 4)
-- Migration: 20260611000000_work_orders.sql
-- ============================================================
-- Maintenance tickets for a property/building/unit/common area.
-- Always carries property_id (denormalized) so portfolio-wide
-- queries ("open work orders by property") don't need joins
-- through units/buildings. unit_id / building_id / common_area_id
-- are nullable — a work order can target any one of them, or just
-- the property as a whole.
--
-- A work order can optionally originate from an inspection finding
-- (source_inspection_id), and can be assigned to any account member
-- (e.g. on-site maintenance staff with role 'member').
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. work_orders
-- ════════════════════════════════════════════════════════════

create table if not exists public.work_orders (
  id                  uuid        primary key default gen_random_uuid(),
  account_id          uuid        not null references public.accounts(id)     on delete cascade,
  property_id         uuid        not null references public.properties(id)   on delete cascade,
  building_id         uuid        references public.buildings(id)             on delete set null,
  unit_id             uuid        references public.units(id)                 on delete set null,
  common_area_id      uuid        references public.common_areas(id)          on delete set null,
  title               text        not null,
  description         text        not null default '',
  category            text        not null default 'other'
                        check (category in ('plumbing','electrical','hvac','appliance','structural','pest','safety','cosmetic','other')),
  priority            text        not null default 'medium'
                        check (priority in ('low','medium','high','urgent')),
  status              text        not null default 'open'
                        check (status in ('open','in_progress','completed','cancelled')),
  assigned_to         uuid        references auth.users(id),
  reported_by         uuid        references auth.users(id) default auth.uid(),
  due_date            date,
  completed_at        timestamptz,
  source_inspection_id uuid       references public.inspections(id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);

alter table public.work_orders enable row level security;

create index if not exists work_orders_account_idx  on public.work_orders (account_id, deleted_at);
create index if not exists work_orders_property_idx on public.work_orders (property_id, status, deleted_at);
create index if not exists work_orders_unit_idx     on public.work_orders (unit_id, deleted_at);
create index if not exists work_orders_assignee_idx on public.work_orders (assigned_to, status) where deleted_at is null;


-- ════════════════════════════════════════════════════════════
-- 2. Auto-fill / updated_at triggers
-- ════════════════════════════════════════════════════════════

create trigger set_account_id before insert on public.work_orders
  for each row execute function public.set_account_id_default();

drop trigger if exists touch_work_orders_updated on public.work_orders;

create trigger touch_work_orders_updated
  before update on public.work_orders
  for each row execute function public.touch_updated_at();


-- ════════════════════════════════════════════════════════════
-- 3. RLS policies
-- ════════════════════════════════════════════════════════════

drop policy if exists "work_orders: members read"    on public.work_orders;
drop policy if exists "work_orders: members insert"  on public.work_orders;
drop policy if exists "work_orders: managers update" on public.work_orders;
drop policy if exists "work_orders: assignee update" on public.work_orders;
drop policy if exists "work_orders: managers delete" on public.work_orders;

create policy "work_orders: members read"
  on public.work_orders for select
  using (public.is_account_member(account_id));

create policy "work_orders: members insert"
  on public.work_orders for insert
  with check (public.is_account_member(account_id));

create policy "work_orders: managers update"
  on public.work_orders for update
  using  (public.has_account_role(account_id, array['owner','admin','manager']))
  with check (public.has_account_role(account_id, array['owner','admin','manager']));

-- The assigned member can update their own work order (e.g. mark
-- in_progress/completed) even if they aren't a manager.
create policy "work_orders: assignee update"
  on public.work_orders for update
  using  (assigned_to = auth.uid())
  with check (assigned_to = auth.uid());

create policy "work_orders: managers delete"
  on public.work_orders for delete
  using (public.has_account_role(account_id, array['owner','admin','manager']));
