-- ============================================================
-- Collect — Team roles & invites (Phase 5)
-- Migration: 20260618000000_team_roles.sql
-- ============================================================
-- 1. Adds a dedicated 'maintenance' role for field staff: same
--    access as 'member' today (account-wide read + insert via
--    is_account_member, plus the existing "work_orders: assignee
--    update" policy). The distinct label lets the UI route them
--    to a work-order-centric experience.
-- 2. account_invites: email invites claimed automatically at
--    signup, or explicitly by an existing signed-in user via
--    claim_my_invite(). No invite emails are sent yet — the
--    inviter tells the person to sign up with that email.
-- 3. Lets teammates read each other's profiles (name/email) so
--    member pickers and assignee labels can render.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. 'maintenance' role
-- ════════════════════════════════════════════════════════════

alter table public.account_members
  drop constraint if exists account_members_role_check;

alter table public.account_members
  add constraint account_members_role_check
  check (role in ('owner', 'admin', 'manager', 'member', 'maintenance'));


-- ════════════════════════════════════════════════════════════
-- 2. account_invites
-- ════════════════════════════════════════════════════════════

create table if not exists public.account_invites (
  id         uuid        primary key default gen_random_uuid(),
  account_id uuid        not null references public.accounts(id) on delete cascade,
  email      text        not null,
  role       text        not null default 'member'
               check (role in ('admin', 'manager', 'member', 'maintenance')),
  invited_by uuid        references auth.users(id),
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  claimed_by uuid        references auth.users(id),
  revoked_at timestamptz,
  constraint account_invites_email_lower check (email = lower(email))
);

alter table public.account_invites enable row level security;

-- One *pending* invite per (account, email); history rows may repeat.
create unique index if not exists account_invites_pending_uniq
  on public.account_invites (account_id, email)
  where claimed_at is null and revoked_at is null;

create index if not exists account_invites_email_idx
  on public.account_invites (email)
  where claimed_at is null and revoked_at is null;

-- Invites are managed by owners/admins only. Invitees never read the
-- table directly — they go through pending_invite_for_me() below.
drop policy if exists "account_invites: admins manage" on public.account_invites;
create policy "account_invites: admins manage"
  on public.account_invites for all
  using  (public.has_account_role(account_id, array['owner', 'admin']))
  with check (public.has_account_role(account_id, array['owner', 'admin']));


-- ════════════════════════════════════════════════════════════
-- 3. Teammates can read each other's profiles
-- ════════════════════════════════════════════════════════════
-- is_account_member is security definer, so referencing it here
-- does not recurse into profiles RLS.

drop policy if exists "profiles: visible to account co-members" on public.profiles;
create policy "profiles: visible to account co-members"
  on public.profiles for select
  using (account_id is not null and public.is_account_member(account_id));


-- ════════════════════════════════════════════════════════════
-- 4. Claim helpers
-- ════════════════════════════════════════════════════════════

-- Shared claim logic: attach p_user to the inviting account and mark
-- the invite claimed. Keeps the user's personal account + ownership;
-- profiles.account_id (the active account) now points at the org.
create or replace function public.claim_invite_for(p_user uuid, p_email text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inv record;
begin
  select * into inv
  from public.account_invites
  where email = lower(p_email)
    and claimed_at is null
    and revoked_at is null
  order by created_at desc
  limit 1;

  if inv.id is null then
    return null;
  end if;

  insert into public.account_members (account_id, user_id, role)
  values (inv.account_id, p_user, inv.role)
  on conflict (account_id, user_id) do update set role = excluded.role;

  update public.profiles set account_id = inv.account_id where id = p_user;

  update public.account_invites
  set claimed_at = now(), claimed_by = p_user
  where id = inv.id;

  return inv.account_id;
end $$;

-- Existing signed-in users accept an invite explicitly (web banner).
create or replace function public.claim_my_invite()
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.claim_invite_for(auth.uid(), auth.email());
$$;

-- What the signed-in user's pending invite looks like, if any.
create or replace function public.pending_invite_for_me()
returns table (account_name text, role text)
language sql
stable
security definer
set search_path = public
as $$
  select a.name, i.role
  from public.account_invites i
  join public.accounts a on a.id = i.account_id
  where i.email = lower(auth.email())
    and i.claimed_at is null
    and i.revoked_at is null
    and not exists (
      select 1 from public.account_members m
      where m.account_id = i.account_id and m.user_id = auth.uid()
    )
  order by i.created_at desc
  limit 1;
$$;


-- ════════════════════════════════════════════════════════════
-- 5. Auto-claim at signup
-- ════════════════════════════════════════════════════════════
-- Same bootstrap as 20260609120000 (personal account + profile +
-- owner membership), then claim a matching pending invite so the
-- new user lands directly in the inviting org.

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

  if new.email is not null then
    perform public.claim_invite_for(new.id, new.email);
  end if;

  return new;
end $$;


-- ════════════════════════════════════════════════════════════
-- 6. Member removal
-- ════════════════════════════════════════════════════════════
-- Deleting the membership row alone would strand the user: their
-- profiles.account_id would still point at the org, so inserts
-- (which default account_id from it) would fail RLS. Reset their
-- active account to their own personal account in the same step.
-- Owners/admins remove others; anyone may remove themselves (leave).

create or replace function public.remove_account_member(p_account_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_role  text;
  personal_acc uuid;
begin
  if not (public.has_account_role(p_account_id, array['owner', 'admin'])
          or p_user_id = auth.uid()) then
    raise exception 'not allowed';
  end if;

  select role into target_role
  from public.account_members
  where account_id = p_account_id and user_id = p_user_id;

  if target_role is null then
    raise exception 'not a member';
  end if;

  if target_role = 'owner' then
    raise exception 'cannot remove an owner';
  end if;

  delete from public.account_members
  where account_id = p_account_id and user_id = p_user_id;

  -- Point them back at the personal account they own.
  select m.account_id into personal_acc
  from public.account_members m
  join public.accounts a on a.id = m.account_id
  where m.user_id = p_user_id and m.role = 'owner' and a.is_personal
  order by a.created_at
  limit 1;

  if personal_acc is not null then
    update public.profiles
    set account_id = personal_acc
    where id = p_user_id and account_id = p_account_id;
  end if;
end $$;
