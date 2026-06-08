-- ============================================================
-- Collect — Add listing_url to assets
-- Migration: 20260529000000_asset_listing_url.sql
-- ============================================================
-- Stores the marketplace listing URL (e.g. Facebook Marketplace item link)
-- so the Chrome extension and iOS app can track and link to the live ad.

ALTER TABLE public.assets
  ADD COLUMN IF NOT EXISTS listing_url text;
