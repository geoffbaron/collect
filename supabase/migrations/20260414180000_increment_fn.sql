create or replace function public.increment_scans_used(user_id uuid)
returns void as $$
  update public.profiles
  set scans_used = scans_used + 1
  where id = user_id;
$$ language sql security definer;
