-- ============================================================
-- Collect — Add condition & category to marketplace listings
-- Migration: 20260528020000_listing_condition_category.sql
-- ============================================================

ALTER TABLE public.assets
  ADD COLUMN IF NOT EXISTS listing_condition  text,   -- e.g. "Used - Like New", "New"
  ADD COLUMN IF NOT EXISTS listing_category   text;   -- e.g. "Home & Garden", "Electronics"
