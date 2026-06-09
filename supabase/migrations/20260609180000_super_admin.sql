-- ════════════════════════════════════════════════════════════
-- Super admin: a small number of operator accounts that can see
-- platform-wide stats and the account list across every tenant,
-- for support and operations — not exposed to regular users.
-- ════════════════════════════════════════════════════════════

alter table public.profiles add column if not exists is_super_admin boolean not null default false;

-- ── is_super_admin() ──────────────────────────────────────────
-- security definer + owned by the migration role, so it bypasses
-- RLS on profiles when checking the caller's own row (same pattern
-- as is_account_member / has_account_role).
create or replace function public.is_super_admin()
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (select p.is_super_admin from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

-- ── Read-all policies for super admins ────────────────────────
drop policy if exists "accounts: super admin read" on public.accounts;
create policy "accounts: super admin read"
  on public.accounts for select
  using (public.is_super_admin());

drop policy if exists "profiles: super admin read" on public.profiles;
create policy "profiles: super admin read"
  on public.profiles for select
  using (public.is_super_admin());

drop policy if exists "account_members: super admin read" on public.account_members;
create policy "account_members: super admin read"
  on public.account_members for select
  using (public.is_super_admin());

-- ── admin_platform_stats() ─────────────────────────────────────
-- Headline counters for the admin overview page.
create or replace function public.admin_platform_stats()
returns table (
  total_accounts        bigint,
  total_users           bigint,
  homeowner_accounts    bigint,
  property_mgr_accounts bigint,
  free_accounts         bigint,
  pro_accounts          bigint,
  enterprise_accounts   bigint,
  total_properties      bigint,
  total_assets          bigint,
  signups_last_7_days   bigint,
  signups_last_30_days  bigint
)
language sql
security definer
stable
as $$
  select
    (select count(*) from public.accounts),
    (select count(*) from public.profiles),
    (select count(*) from public.accounts where product_mode = 'homeowner'),
    (select count(*) from public.accounts where product_mode = 'property_manager'),
    (select count(*) from public.accounts where plan = 'free'),
    (select count(*) from public.accounts where plan = 'pro'),
    (select count(*) from public.accounts where plan = 'enterprise'),
    (select count(*) from public.properties where deleted_at is null),
    (select count(*) from public.assets where deleted_at is null),
    (select count(*) from public.profiles where created_at >= now() - interval '7 days'),
    (select count(*) from public.profiles where created_at >= now() - interval '30 days')
  where public.is_super_admin();
$$;

-- ── admin_list_accounts() ──────────────────────────────────────
-- One row per account with member count, owner email, and a rough
-- usage snapshot — for the admin accounts table.
create or replace function public.admin_list_accounts()
returns table (
  id              uuid,
  name            text,
  product_mode    text,
  plan            text,
  is_personal     boolean,
  created_at      timestamptz,
  member_count    bigint,
  owner_email     text,
  property_count  bigint,
  asset_count     bigint
)
language sql
security definer
stable
as $$
  select
    a.id,
    a.name,
    a.product_mode,
    a.plan,
    a.is_personal,
    a.created_at,
    (select count(*) from public.account_members m where m.account_id = a.id),
    (
      select p.email
      from public.account_members m
      join public.profiles p on p.id = m.user_id
      where m.account_id = a.id and m.role = 'owner'
      order by p.created_at asc
      limit 1
    ),
    (select count(*) from public.properties pr where pr.account_id = a.id and pr.deleted_at is null),
    (select count(*) from public.assets ax where ax.account_id = a.id and ax.deleted_at is null)
  from public.accounts a
  where public.is_super_admin()
  order by a.created_at desc;
$$;

-- ── Grant Geoff super admin ────────────────────────────────────
update public.profiles set is_super_admin = true where email = 'geoffbaron@gmail.com';
