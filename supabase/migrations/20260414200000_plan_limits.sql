-- ── Plan Limits ──────────────────────────────────────────────────────────────
-- Stores configurable usage limits per plan. -1 means unlimited.

create table public.plan_limits (
  plan                   text    primary key,
  max_video_seconds      integer not null default 60,
  max_properties         integer not null default 3,
  max_rooms_per_property integer not null default -1,
  max_assets_per_scan    integer not null default 25,
  max_scans_per_month    integer not null default 5,
  updated_at             timestamptz not null default now()
);

-- Authenticated users can read (iOS app needs this to enforce client-side limits)
alter table public.plan_limits enable row level security;

create policy "Authenticated users can read plan limits"
  on public.plan_limits for select
  to authenticated
  using (true);

-- Seed defaults
insert into public.plan_limits
  (plan, max_video_seconds, max_properties, max_rooms_per_property, max_assets_per_scan, max_scans_per_month)
values
  ('free', 60,  3,  -1, 25,  5),
  ('pro',  180, -1, -1, 100, -1);

-- ── RPC: get_my_limits ────────────────────────────────────────────────────────
-- Returns the plan_limits row for the calling user's plan.

create or replace function public.get_my_limits()
returns setof public.plan_limits
language sql
security definer
stable
as $$
  select pl.*
  from public.plan_limits pl
  join public.profiles p on p.plan = pl.plan
  where p.id = auth.uid()
  limit 1;
$$;
