-- Returns the current user's scan usage for the current calendar month
-- and their monthly limit from plan_limits.
create or replace function public.get_scan_usage()
returns table (
  scans_this_month  int,
  monthly_limit     int,
  plan              text
)
language sql
security definer
stable
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
    p.plan
  from   public.profiles   p
  join   public.plan_limits pl on pl.plan = p.plan
  where  p.id = auth.uid();
$$;
