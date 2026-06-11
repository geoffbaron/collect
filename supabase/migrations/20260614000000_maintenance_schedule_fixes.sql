-- ============================================================
-- Collect — Preventive Maintenance Schedules: fixes (Phase 4 QA)
-- Migration: 20260614000000_maintenance_schedule_fixes.sql
-- ============================================================
-- Replaces generate_due_work_orders() with two functions:
--
-- 1. _generate_due_maintenance_work_orders() — security definer,
--    bypasses RLS, intended for pg_cron only (revoked from API
--    roles). Processes every account's due schedules, locks rows
--    with FOR UPDATE SKIP LOCKED to avoid duplicate runs, copies
--    assigned_to onto the generated work order, and no longer
--    stamps last_completed_at (that field means "last time someone
--    actually completed the task", not "last time we generated a
--    ticket for it").
--
-- 2. generate_due_work_orders() — security invoker (RLS-respecting),
--    kept as a manual "run now" RPC for managers. Updates
--    next_due_date FIRST; if RLS blocks that update (caller isn't a
--    manager), the schedule is skipped entirely so no orphaned work
--    order is created.
--
-- Also schedules the internal function via pg_cron (daily), if the
-- pg_cron extension is available on this project.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. Internal cron-only function
-- ════════════════════════════════════════════════════════════

create or replace function public._generate_due_maintenance_work_orders()
returns integer
language plpgsql
security definer
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
    for update skip locked
  loop
    step := case due.frequency
      when 'daily'      then interval '1 day'
      when 'weekly'     then interval '1 week'
      when 'monthly'    then interval '1 month'
      when 'quarterly'  then interval '3 months'
      when 'semiannual' then interval '6 months'
      when 'annual'     then interval '1 year'
    end;

    update public.maintenance_schedules
      set next_due_date = (due.next_due_date + step)::date
      where id = due.id;

    insert into public.work_orders (
      account_id, property_id, building_id, unit_id, common_area_id,
      title, description, category, priority, status, assigned_to
    ) values (
      due.account_id, due.property_id, due.building_id, due.unit_id, due.common_area_id,
      due.title, due.description, due.category, 'medium', 'open', due.assigned_to
    );

    created_count := created_count + 1;
  end loop;

  return created_count;
end;
$$;

revoke all on function public._generate_due_maintenance_work_orders() from public, anon, authenticated;


-- ════════════════════════════════════════════════════════════
-- 2. Public, RLS-respecting "run now" RPC
-- ════════════════════════════════════════════════════════════

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
  updated_rows integer;
begin
  for due in
    select * from public.maintenance_schedules
    where active and deleted_at is null and next_due_date <= current_date
    for update skip locked
  loop
    step := case due.frequency
      when 'daily'      then interval '1 day'
      when 'weekly'     then interval '1 week'
      when 'monthly'    then interval '1 month'
      when 'quarterly'  then interval '3 months'
      when 'semiannual' then interval '6 months'
      when 'annual'     then interval '1 year'
    end;

    update public.maintenance_schedules
      set next_due_date = (due.next_due_date + step)::date
      where id = due.id;

    -- If RLS silently filtered the update (caller isn't a manager for
    -- this account), don't create an orphaned work order.
    get diagnostics updated_rows = row_count;
    if updated_rows = 0 then
      continue;
    end if;

    insert into public.work_orders (
      account_id, property_id, building_id, unit_id, common_area_id,
      title, description, category, priority, status, assigned_to
    ) values (
      due.account_id, due.property_id, due.building_id, due.unit_id, due.common_area_id,
      due.title, due.description, due.category, 'medium', 'open', due.assigned_to
    );

    created_count := created_count + 1;
  end loop;

  return created_count;
end;
$$;


-- ════════════════════════════════════════════════════════════
-- 3. Schedule the internal function via pg_cron (best-effort)
-- ════════════════════════════════════════════════════════════

do $$
begin
  create extension if not exists pg_cron;
exception when others then
  raise notice 'pg_cron extension unavailable, skipping: %', sqlerrm;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'generate-due-maintenance-work-orders') then
      perform cron.unschedule('generate-due-maintenance-work-orders');
    end if;
    perform cron.schedule(
      'generate-due-maintenance-work-orders',
      '0 6 * * *',
      $cron$select public._generate_due_maintenance_work_orders()$cron$
    );
  end if;
exception when others then
  raise notice 'failed to schedule pg_cron job, skipping: %', sqlerrm;
end $$;
