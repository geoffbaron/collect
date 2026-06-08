-- ============================================================
-- Collect — Cloud Sync Schema
-- Migration: 20260415000000_cloud_sync.sql
-- ============================================================

-- ── Storage bucket ────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'asset-photos',
  'asset-photos',
  false,
  10485760,         -- 10 MB per file
  array['image/jpeg', 'image/png', 'image/webp']
) on conflict (id) do nothing;

-- Storage RLS (path convention: {user_id}/{asset_id}/photo1.jpg)
create policy "asset-photos: owner insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'asset-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "asset-photos: owner select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'asset-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "asset-photos: owner update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'asset-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "asset-photos: owner delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'asset-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );


-- ── properties ────────────────────────────────────────────────
create table if not exists public.properties (
  id          uuid        primary key,
  user_id     uuid        not null references auth.users(id) on delete cascade,
  name        text        not null,
  address     text        not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

alter table public.properties enable row level security;

create policy "properties: owner full access"
  on public.properties for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists properties_user_id_idx on public.properties (user_id, deleted_at);


-- ── floors ────────────────────────────────────────────────────
create table if not exists public.floors (
  id            uuid        primary key,
  user_id       uuid        not null references auth.users(id) on delete cascade,
  property_id   uuid        not null references public.properties(id) on delete cascade,
  name          text        not null,
  sort_order    integer     not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

alter table public.floors enable row level security;

create policy "floors: owner full access"
  on public.floors for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists floors_property_id_idx on public.floors (property_id, deleted_at);


-- ── rooms ─────────────────────────────────────────────────────
create table if not exists public.rooms (
  id              uuid             primary key,
  user_id         uuid             not null references auth.users(id) on delete cascade,
  floor_id        uuid             not null references public.floors(id) on delete cascade,
  name            text             not null,
  map_latitude    double precision,
  map_longitude   double precision,
  map_heading     double precision not null default 0,
  created_at      timestamptz      not null default now(),
  updated_at      timestamptz      not null default now(),
  deleted_at      timestamptz
);

alter table public.rooms enable row level security;

create policy "rooms: owner full access"
  on public.rooms for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists rooms_floor_id_idx on public.rooms (floor_id, deleted_at);


-- ── collections ───────────────────────────────────────────────
create table if not exists public.collections (
  id              uuid        primary key,
  user_id         uuid        not null references auth.users(id) on delete cascade,
  room_id         uuid        not null references public.rooms(id) on delete cascade,
  prompt_type     text        not null,
  custom_prompt   text,
  status          text        not null default 'completed',
  captured_at     timestamptz not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

alter table public.collections enable row level security;

create policy "collections: owner full access"
  on public.collections for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists collections_room_id_idx on public.collections (room_id, deleted_at);


-- ── assets ────────────────────────────────────────────────────
create table if not exists public.assets (
  id                uuid             primary key,
  user_id           uuid             not null references auth.users(id) on delete cascade,
  collection_id     uuid             not null references public.collections(id) on delete cascade,
  name              text             not null,
  category          text             not null default 'Other',
  asset_description text             not null default '',
  condition         text,
  quantity          integer          not null default 1,
  confidence        double precision not null default 1.0,
  estimated_value   double precision,
  latitude          double precision,
  longitude         double precision,
  layout_x          double precision,
  layout_z          double precision,
  is_confirmed      boolean          not null default false,
  photo1_path       text,
  photo2_path       text,
  created_at        timestamptz      not null default now(),
  updated_at        timestamptz      not null default now(),
  deleted_at        timestamptz
);

alter table public.assets enable row level security;

create policy "assets: owner full access"
  on public.assets for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists assets_collection_id_idx on public.assets (collection_id, deleted_at);
create index if not exists assets_user_id_idx       on public.assets (user_id, deleted_at);


-- ── cloud_storage feature flag ────────────────────────────────
insert into public.feature_flags (key, enabled, description) values
  ('cloud_storage', true, 'Photo upload to Supabase Storage (premium feature)')
on conflict (key) do nothing;

insert into public.plan_features (plan, key, enabled) values
  ('free',       'cloud_storage', false),
  ('pro',        'cloud_storage', true),
  ('enterprise', 'cloud_storage', true)
on conflict (plan, key) do nothing;
