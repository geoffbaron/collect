-- ════════════════════════════════════════════════════════════
-- Super admin: let existing super admins promote/demote other
-- users to/from super admin from the admin UI.
-- ════════════════════════════════════════════════════════════

-- ── admin_list_users() ─────────────────────────────────────────
-- Users matching a search term (by email/name), for the admin
-- "promote to super admin" picker. Returns [] for non-admins.
create or replace function public.admin_list_users(search text default '')
returns table (
  id              uuid,
  email           text,
  name            text,
  is_super_admin  boolean,
  created_at      timestamptz
)
language sql
security definer
stable
as $$
  select p.id, p.email, p.name, p.is_super_admin, p.created_at
  from public.profiles p
  where public.is_super_admin()
    and (
      search = ''
      or p.email ilike '%' || search || '%'
      or p.name ilike '%' || search || '%'
    )
  order by p.created_at desc
  limit 50;
$$;

-- ── admin_set_super_admin() ────────────────────────────────────
-- Promote or demote a user. Only callable by an existing super
-- admin; a no-op (returns false) for everyone else.
create or replace function public.admin_set_super_admin(target_user_id uuid, value boolean)
returns boolean
language plpgsql
security definer
as $$
begin
  if not public.is_super_admin() then
    return false;
  end if;

  update public.profiles
  set is_super_admin = value
  where id = target_user_id;

  return found;
end;
$$;
