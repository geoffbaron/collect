-- ============================================================
-- Collect — Preventive Maintenance Schedules (Phase 4)
-- Migration: 20260613000000_maintenance_schedules.sql
-- ============================================================
-- Recurring maintenance tasks (e.g. "Replace HVAC filter", "Service
-- elevator") for a property/building/unit/common area. Always carries
-- property_id (denormalized) so portfolio-wide queries ("schedules
-- due this month") don't need joins through units/buildings.
--
-- generate_due_work_orders() finds active schedules whose
-- next_due_date has arrived, creates a work_order from each, and
-- advances next_due_date by the schedule's frequency.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. maintenance_schedules
-- ════════════════════════════════════════════════════════════

create table if not exists public.maintenance_schedules (
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
  frequency           text        not null default 'monthly'
                        check (frequency in ('daily','weekly','monthly','quarterly','semiannual','annual')),
  next_due_date       date        not null default current_date,
  last_completed_at   date,
  assigned_to         uuid        references auth.users(id),
  active              boolean     not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);

alter table public.maintenance_schedules enable row level security;

create index if not exists maintenance_schedules_account_idx  on public.maintenance_schedules (account_id, deleted_at);
create index if not exists maintenance_schedules_property_idx on public.maintenance_schedules (property_id, next_due_date, deleted_at);
create index if not exists maintenance_schedules_unit_idx     on public.maintenance_schedules (unit_id, deleted_at);
create index if not exists maintenance_schedules_due_idx      on public.maintenance_schedules (next_due_date) where active and deleted_at is null;


-- ════════════════════════════════════════════════════════════
-- 2. Auto-fill / updated_at triggers
-- ════════════════════════════════════════════════════════════

create trigger set_account_id before insert on public.maintenance_schedules
  for each row execute function public.set_account_id_default();

drop trigger if exists touch_maintenance_schedules_updated on public.maintenance_schedules;

create trigger touch_maintenance_schedules_updated
  before update on public.maintenance_schedules
  for each row execute function public.touch_updated_at();


-- ════════════════════════════════════════════════════════════
-- 3. RLS policies
-- ════════════════════════════════════════════════════════════

drop policy if exists "maintenance_schedules: members read"    on public.maintenance_schedules;
drop policy if exists "maintenance_schedules: members insert"  on public.maintenance_schedules;
drop policy if exists "maintenance_schedules: managers update" on public.maintenance_schedules;
drop policy if exists "maintenance_schedules: managers delete" on public.maintenance_schedules;

create policy "maintenance_schedules: members read"
  on public.maintenance_schedules for select
  using (public.is_account_member(account_id));

create policy "maintenance_schedules: members insert"
  on public.maintenance_schedules for insert
  with check (public.is_account_member(account_id));

create policy "maintenance_schedules: managers update"
  on public.maintenance_schedules for update
  using  (public.has_account_role(account_id, array['owner','admin','manager']))
  with check (public.has_account_role(account_id, array['owner','admin','manager']));

create policy "maintenance_schedules: managers delete"
  on public.maintenance_schedules for delete
  using (public.has_account_role(account_id, array['owner','admin','manager']));


-- ════════════════════════════════════════════════════════════
-- 4. generate_due_work_orders()
-- ════════════════════════════════════════════════════════════
-- For every active, non-deleted schedule whose next_due_date has
-- arrived, creates a work order and advances next_due_date by the
-- schedule's frequency. Returns the number of work orders created.
-- Runs as the calling user, so it only touches schedules/work orders
-- the caller's account can see/insert (RLS-safe for cron via service role).

create or replace function public.generate_due_work_orders()
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  due record;
  created_count integer := 0;
  step interval;
begin
  for due in
    select * from public.maintenance_schedules
    where active and deleted_at is null and next_due_date <= current_date
  loop
    insert into public.work_orders (
      account_id, property_id, building_id, unit_id, common_area_id,
      title, description, category, priority, status
    ) values (
      due.account_id, due.property_id, due.building_id, due.unit_id, due.common_area_id,
      due.title, due.description, due.category, 'medium', 'open'
    );

    step := case due.frequency
      when 'daily'      then interval '1 day'
      when 'weekly'     then interval '1 week'
      when 'monthly'    then interval '1 month'
      when 'quarterly'  then interval '3 months'
      when 'semiannual' then interval '6 months'
      when 'annual'     then interval '1 year'
    end;

    update public.maintenance_schedules
      set next_due_date     = (due.next_due_date + step)::date,
          last_completed_at = current_date
      where id = due.id;

    created_count := created_count + 1;
  end loop;

  return created_count;
end;
$$;
