-- ============================================================
-- Collect — Set the app owner's plan to 'pro'
-- Migration: 20260528030000_set_owner_plan_pro.sql
-- ============================================================

-- Upgrade geoffbaron@gmail.com to pro so cloud_storage (photo upload)
-- and all other pro features are enabled during development.
UPDATE public.profiles
SET plan = 'pro'
WHERE email = 'geoffbaron@gmail.com';
