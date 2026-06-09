-- ============================================================
-- Collect — Organization / Account Foundation (Phase 0)
-- Migration: 20260609120000_org_accounts_foundation.sql
-- ============================================================
-- Introduces an account/organization layer above the user so the app can
-- serve two products (homeowner + property_manager) and, eventually,
-- enterprise teams managing thousands of complexes.
--
-- Design goals:
--   * Re-key ownership + RLS from per-user (auth.uid() = user_id) to
--     per-account membership, WITHOUT breaking the running iOS/web app.
--   * Stay transparent to existing clients: a BEFORE INSERT trigger
--     auto-fills account_id, so current inserts that omit it keep working.
--   * Forward-compatible enterprise hooks (regions/scoped roles) that are
--     present now but only activated in later phases.
--
-- Backward-compat invariant: every existing user becomes the owner of a
-- personal account-of-one, so RLS returns exactly the same rows as before.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. Core entities: accounts, regions, account_members
-- ════════════════════════════════════════════════════════════

create table if not exists public.accounts (
  id           uuid        primary key default gen_random_uuid(),
  name         text        not null default '',
  -- Which product experience this account sees. Gates the whole UX.
  product_mode text        not null default 'homeowner'
                 check (product_mode in ('homeowner', 'property_manager')),
  -- Billing tier. Authoritative home for "plan" (was profiles.plan).
  plan         text        not null default 'free',
  -- Personal account-of-one (homeowner) vs a real organization.
  is_personal  boolean     not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.accounts enable row level security;

-- Optional grouping under an account for enterprise (region / portfolio).
-- Present now so member scoping needs no schema change later; unused in
-- homeowner mode.
create table if not exists public.regions (
  id         uuid        primary key default gen_random_uuid(),
  account_id uuid        not null references public.accounts(id) on delete cascade,
  name       text        not null,
  created_at timestamptz not null default now()
);

alter table public.regions enable row level security;
create index if not exists regions_account_id_idx on public.regions (account_id);

-- A user's membership in an account, with a role and an optional region
-- scope. region_id = null means account-wide (the only case in Phase 0).
create table if not exists public.account_members (
  account_id uuid        not null references public.accounts(id) on delete cascade,
  user_id    uuid        not null references auth.users(id)      on delete cascade,
  role       text        not null default 'member'
                 check (role in ('owner', 'admin', 'manager', 'member')),
  region_id  uuid        references public.regions(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (account_id, user_id)
);

alter table public.account_members enable row level security;
create index if not exists account_members_user_idx on public.account_members (user_id);


-- ════════════════════════════════════════════════════════════
-- 2. Helper functions (SECURITY DEFINER → bypass RLS, no recursion)
-- ════════════════════════════════════════════════════════════
-- Data-table RLS policies call these. Because they are SECURITY DEFINER
-- they read account_members with the definer's rights, so referencing
-- account_members from a policy ON account_members does not recurse.
-- (current_account_id() is defined in section 3, after profiles.account_id
-- exists — a `language sql` body is validated at creation time.)

create or replace function public.is_account_member(p_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.account_members m
    where m.account_id = p_account_id
      and m.user_id = auth.uid()
  );
$$;

create or replace function public.has_account_role(p_account_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.account_members m
    where m.account_id = p_account_id
      and m.user_id = auth.uid()
      and m.role = any(p_roles)
  );
$$;

-- True if auth.uid() shares any account with p_user. Used by storage RLS
-- so account members can read each other's uploaded photos.
create or replace function public.shares_account_with(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.account_members a
    join public.account_members b on a.account_id = b.account_id
    where a.user_id = auth.uid()
      and b.user_id = p_user
  );
$$;


-- ════════════════════════════════════════════════════════════
-- 3. Add account_id to profiles + every data table
-- ════════════════════════════════════════════════════════════
-- Columns are added nullable first; backfilled in section 4; constrained
-- in section 5. user_id columns are KEPT (now "created by") — non-destructive.

alter table public.profiles          add column if not exists account_id uuid references public.accounts(id) on delete cascade;

-- The caller's active/primary account (account-of-one in Phase 0; becomes
-- the "currently selected" account once multi-account lands). Defined here,
-- after profiles.account_id exists, because its SQL body is validated now.
create or replace function public.current_account_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select account_id from public.profiles where id = auth.uid();
$$;

alter table public.properties        add column if not exists account_id uuid references public.accounts(id) on delete cascade;
alter table public.floors            add column if not exists account_id uuid references public.accounts(id) on delete cascade;
alter table public.rooms             add column if not exists account_id uuid references public.accounts(id) on delete cascade;
alter table public.collections       add column if not exists account_id uuid references public.accounts(id) on delete cascade;
alter table public.assets            add column if not exists account_id uuid references public.accounts(id) on delete cascade;
alter table public.scans             add column if not exists account_id uuid references public.accounts(id) on delete cascade;
alter table public.monthly_listings  add column if not exists account_id uuid references public.accounts(id) on delete cascade;


-- ════════════════════════════════════════════════════════════
-- 4. Backfill: one personal account per existing user
-- ════════════════════════════════════════════════════════════

do $$
declare
  r       record;
  new_acc uuid;
begin
  for r in select id, email, name, plan from public.profiles where account_id is null loop
    insert into public.accounts (name, plan, is_personal, product_mode)
    values (
      coalesce(nullif(r.name, ''), r.email, 'Personal'),
      coalesce(nullif(r.plan, ''), 'free'),
      true,
      'homeowner'
    )
    returning id into new_acc;

    update public.profiles set account_id = new_acc where id = r.id;

    insert into public.account_members (account_id, user_id, role)
    values (new_acc, r.id, 'owner')
    on conflict (account_id, user_id) do nothing;
  end loop;
end $$;

-- Stamp account_id onto every existing data row via its owning user.
update public.properties       t set account_id = p.account_id from public.profiles p where p.id = t.user_id and t.account_id is null;
update public.floors           t set account_id = p.account_id from public.profiles p where p.id = t.user_id and t.account_id is null;
update public.rooms            t set account_id = p.account_id from public.profiles p where p.id = t.user_id and t.account_id is null;
update public.collections      t set account_id = p.account_id from public.profiles p where p.id = t.user_id and t.account_id is null;
update public.assets           t set account_id = p.account_id from public.profiles p where p.id = t.user_id and t.account_id is null;
update public.scans            t set account_id = p.account_id from public.profiles p where p.id = t.user_id and t.account_id is null;
update public.monthly_listings t set account_id = p.account_id from public.profiles p where p.id = t.user_id and t.account_id is null;


-- ════════════════════════════════════════════════════════════
-- 5. Constrain + index account_id
-- ════════════════════════════════════════════════════════════
-- scans.user_id is nullable (server-inserted rows may lack a user), so
-- scans.account_id stays nullable; everything else is NOT NULL.

alter table public.profiles          alter column account_id set not null;
alter table public.properties        alter column account_id set not null;
alter table public.floors            alter column account_id set not null;
alter table public.rooms             alter column account_id set not null;
alter table public.collections       alter column account_id set not null;
alter table public.assets            alter column account_id set not null;
alter table public.monthly_listings  alter column account_id set not null;

create index if not exists properties_account_idx       on public.properties       (account_id, deleted_at);
create index if not exists floors_account_idx           on public.floors           (account_id, deleted_at);
create index if not exists rooms_account_idx            on public.rooms            (account_id, deleted_at);
create index if not exists collections_account_idx      on public.collections      (account_id, deleted_at);
create index if not exists assets_account_idx           on public.assets           (account_id, deleted_at);
create index if not exists scans_account_idx            on public.scans            (account_id);
create index if not exists monthly_listings_account_idx on public.monthly_listings (account_id);
create index if not exists profiles_account_idx         on public.profiles         (account_id);


-- ════════════════════════════════════════════════════════════
-- 6. Auto-fill account_id on insert (keeps existing clients working)
-- ════════════════════════════════════════════════════════════
-- The iOS app and web dashboard insert rows without an account_id. This
-- BEFORE INSERT trigger fills it from the caller's account, so NOT NULL +
-- account-scoped RLS hold without any client change. Covers both omitted
-- and explicitly-null account_id.

create or replace function public.set_account_id_default()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.account_id is null then
    new.account_id := (select account_id from public.profiles where id = auth.uid());
  end if;
  return new;
end $$;

do $$
declare tbl text;
begin
  foreach tbl in array array[
    'properties', 'floors', 'rooms', 'collections', 'assets', 'scans', 'monthly_listings'
  ] loop
    execute format('drop trigger if exists set_account_id on public.%I', tbl);
    execute format(
      'create trigger set_account_id before insert on public.%I
         for each row execute function public.set_account_id_default()', tbl);
  end loop;
end $$;


-- ════════════════════════════════════════════════════════════
-- 7. Re-key RLS: from auth.uid() = user_id  →  account membership
-- ════════════════════════════════════════════════════════════

-- profiles: own profile, plus fellow account members (for assignee names).
drop policy if exists "Users can view own profile" on public.profiles;
create policy "profiles: self or co-member readable"
  on public.profiles for select
  using (auth.uid() = id or public.is_account_member(account_id));

-- scans: account-scoped read (inserts are server-side / service role).
drop policy if exists "Users can view own scans" on public.scans;
create policy "scans: account read"
  on public.scans for select
  using (public.is_account_member(account_id));

-- properties / floors / rooms / collections / assets: full access to members.
drop policy if exists "properties: owner full access" on public.properties;
create policy "properties: account full access"
  on public.properties for all
  using  (public.is_account_member(account_id))
  with check (public.is_account_member(account_id));

drop policy if exists "floors: owner full access" on public.floors;
create policy "floors: account full access"
  on public.floors for all
  using  (public.is_account_member(account_id))
  with check (public.is_account_member(account_id));

drop policy if exists "rooms: owner full access" on public.rooms;
create policy "rooms: account full access"
  on public.rooms for all
  using  (public.is_account_member(account_id))
  with check (public.is_account_member(account_id));

drop policy if exists "collections: owner full access" on public.collections;
create policy "collections: account full access"
  on public.collections for all
  using  (public.is_account_member(account_id))
  with check (public.is_account_member(account_id));

drop policy if exists "assets: owner full access" on public.assets;
create policy "assets: account full access"
  on public.assets for all
  using  (public.is_account_member(account_id))
  with check (public.is_account_member(account_id));

drop policy if exists "monthly_listings: owner access" on public.monthly_listings;
create policy "monthly_listings: account access"
  on public.monthly_listings for all
  using  (public.is_account_member(account_id))
  with check (public.is_account_member(account_id));


-- ════════════════════════════════════════════════════════════
-- 8. RLS for the new tables
-- ════════════════════════════════════════════════════════════

-- accounts: members can read; only owners/admins can update.
drop policy if exists "accounts: members read"  on public.accounts;
create policy "accounts: members read"
  on public.accounts for select
  using (public.is_account_member(id));

drop policy if exists "accounts: admins update" on public.accounts;
create policy "accounts: admins update"
  on public.accounts for update
  using  (public.has_account_role(id, array['owner', 'admin']))
  with check (public.has_account_role(id, array['owner', 'admin']));

-- account_members: see your own rows + everyone in accounts you belong to;
-- only owners/admins can change membership.
drop policy if exists "account_members: visible to co-members" on public.account_members;
create policy "account_members: visible to co-members"
  on public.account_members for select
  using (user_id = auth.uid() or public.is_account_member(account_id));

drop policy if exists "account_members: admins manage" on public.account_members;
create policy "account_members: admins manage"
  on public.account_members for all
  using  (public.has_account_role(account_id, array['owner', 'admin']))
  with check (public.has_account_role(account_id, array['owner', 'admin']));

-- regions: members read; owners/admins/managers manage.
drop policy if exists "regions: members read" on public.regions;
create policy "regions: members read"
  on public.regions for select
  using (public.is_account_member(account_id));

drop policy if exists "regions: managers manage" on public.regions;
create policy "regions: managers manage"
  on public.regions for all
  using  (public.has_account_role(account_id, array['owner', 'admin', 'manager']))
  with check (public.has_account_role(account_id, array['owner', 'admin', 'manager']));


-- ════════════════════════════════════════════════════════════
-- 9. Storage: let account members read each other's photos
-- ════════════════════════════════════════════════════════════
-- Path convention is {user_id}/{asset_id}/photoN.jpg. The existing owner
-- policies remain (insert/update/delete stay uploader-scoped); this ADDS a
-- member read path. For a homeowner account-of-one this is a no-op.

drop policy if exists "asset-photos: account member select" on storage.objects;
create policy "asset-photos: account member select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'asset-photos'
    and public.shares_account_with(((storage.foldername(name))[1])::uuid)
  );


-- ════════════════════════════════════════════════════════════
-- 10. Plan: authoritative on accounts; mirror to profiles for legacy reads
-- ════════════════════════════════════════════════════════════
-- accounts.plan is now the source of truth. profiles.plan is kept as a
-- read mirror so existing iOS/web code that reads it keeps working; a
-- trigger syncs it whenever an account's plan changes.

create or replace function public.sync_profiles_plan()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.plan is distinct from old.plan then
    update public.profiles set plan = new.plan where account_id = new.id;
  end if;
  return new;
end $$;

drop trigger if exists sync_plan on public.accounts;
create trigger sync_plan
  after update of plan on public.accounts
  for each row execute function public.sync_profiles_plan();

-- Resolve plan-gated config through the caller's account (was profiles.plan).
create or replace function public.get_my_limits()
returns setof public.plan_limits
language sql
security definer
stable
set search_path = public
as $$
  select pl.*
  from public.profiles    p
  join public.accounts     a  on a.id   = p.account_id
  join public.plan_limits  pl on pl.plan = a.plan
  where p.id = auth.uid()
  limit 1;
$$;

create or replace function public.get_my_features()
returns table (key text, enabled boolean)
language sql
security definer
stable
set search_path = public
as $$
  select
    ff.key,
    (ff.enabled and pf.enabled) as enabled
  from public.feature_flags ff
  join public.profiles       p  on p.id   = auth.uid()
  join public.accounts        a  on a.id   = p.account_id
  join public.plan_features   pf on pf.key = ff.key and pf.plan = a.plan;
$$;

create or replace function public.get_scan_usage()
returns table (
  scans_this_month int,
  monthly_limit    int,
  plan             text
)
language sql
security definer
stable
set search_path = public
as $$
  select
    (
      select count(*)::int
      from   public.scans
      where  user_id    = auth.uid()
      and    created_at >= date_trunc('month', now())
      and    success    = true
    ) as scans_this_month,
    pl.max_scans_per_month as monthly_limit,
    a.plan
  from   public.profiles    p
  join   public.accounts     a  on a.id   = p.account_id
  join   public.plan_limits  pl on pl.plan = a.plan
  where  p.id = auth.uid();
$$;


-- ════════════════════════════════════════════════════════════
-- 11. New-user trigger: create a personal account + owner membership
-- ════════════════════════════════════════════════════════════

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_acc uuid;
begin
  insert into public.accounts (name, plan, is_personal, product_mode)
  values (
    coalesce(new.raw_user_meta_data->>'name', new.email, 'Personal'),
    'free',
    true,
    'homeowner'
  )
  returning id into new_acc;

  insert into public.profiles (id, email, name, plan, account_id)
  values (new.id, new.email, new.raw_user_meta_data->>'name', 'free', new_acc)
  on conflict (id) do update set account_id = excluded.account_id;

  insert into public.account_members (account_id, user_id, role)
  values (new_acc, new.id, 'owner')
  on conflict (account_id, user_id) do nothing;

  return new;
end $$;


-- ════════════════════════════════════════════════════════════
-- 12. Keep the dev owner on the pro plan (account-level now)
-- ════════════════════════════════════════════════════════════

update public.accounts a
set    plan = 'pro'
from   public.profiles p
where  p.account_id = a.id
  and  p.email = 'geoffbaron@gmail.com';

-- Mirror onto profiles directly too, in case the sync trigger's UPDATE OF
-- did not fire during this same statement ordering.
update public.profiles
set    plan = 'pro'
where  email = 'geoffbaron@gmail.com';


-- ════════════════════════════════════════════════════════════
-- 13. Touch updated_at on accounts
-- ════════════════════════════════════════════════════════════

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists touch_accounts_updated on public.accounts;
create trigger touch_accounts_updated
  before update on public.accounts
  for each row execute function public.touch_updated_at();
