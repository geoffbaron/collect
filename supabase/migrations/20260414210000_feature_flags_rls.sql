-- Enable RLS on feature_flags and allow anyone to read
-- (flags are public config, not sensitive — anon key can read at app startup)
alter table public.feature_flags enable row level security;

create policy "Anyone can read feature flags"
  on public.feature_flags for select
  to anon, authenticated
  using (true);

-- New app feature flags
insert into public.feature_flags (key, enabled, description) values
  ('floor_scans',       true, 'LiDAR room layout scanning and floor plan views (requires LiDAR hardware)'),
  ('location_features', true, 'Property map view and GPS tagging')
on conflict (key) do nothing;
