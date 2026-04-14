-- ── Plan Features ─────────────────────────────────────────────────────────────
-- Replaces the global on/off for plan-gated features with per-plan access.
-- Global feature_flags.enabled acts as an emergency kill-switch;
-- plan_features.enabled controls per-plan access.
-- Effective access = feature_flags.enabled AND plan_features.enabled

create table public.plan_features (
  plan    text    not null,
  key     text    not null references public.feature_flags(key) on delete cascade,
  enabled boolean not null default false,
  primary key (plan, key)
);

alter table public.plan_features enable row level security;

create policy "Authenticated users can read plan features"
  on public.plan_features for select
  to authenticated
  using (true);

-- Seed: floor_scans + location_features are pro/enterprise features
insert into public.plan_features (plan, key, enabled) values
  ('free',       'floor_scans',       false),
  ('free',       'location_features', false),
  ('pro',        'floor_scans',       true),
  ('pro',        'location_features', true),
  ('enterprise', 'floor_scans',       true),
  ('enterprise', 'location_features', true);

-- Add enterprise tier to plan_limits
insert into public.plan_limits
  (plan, max_video_seconds, max_properties, max_rooms_per_property, max_assets_per_scan, max_scans_per_month)
values
  ('enterprise', -1, -1, -1, -1, -1)
on conflict (plan) do nothing;

-- ── RPC: get_my_features ──────────────────────────────────────────────────────
-- Returns plan-gated features for the calling user.
-- Both the global flag AND the plan flag must be true.

create or replace function public.get_my_features()
returns table (key text, enabled boolean)
language sql
security definer
stable
as $$
  select
    ff.key,
    (ff.enabled and pf.enabled) as enabled
  from public.feature_flags   ff
  join public.plan_features   pf on pf.key  = ff.key
  join public.profiles         p  on p.plan  = pf.plan
  where p.id = auth.uid();
$$;
