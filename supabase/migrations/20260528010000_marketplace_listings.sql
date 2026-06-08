-- ============================================================
-- Collect — Marketplace Listing Columns + Usage Log
-- Migration: 20260528010000_marketplace_listings.sql
-- ============================================================

-- ── Listing state on assets ───────────────────────────────────
ALTER TABLE public.assets
  ADD COLUMN IF NOT EXISTS listing_status       text             NOT NULL DEFAULT 'not_listed',
  ADD COLUMN IF NOT EXISTS listing_title        text,
  ADD COLUMN IF NOT EXISTS listing_description  text,
  ADD COLUMN IF NOT EXISTS asking_price         double precision,
  ADD COLUMN IF NOT EXISTS listed_facebook      boolean          NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS listed_craigslist    boolean          NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS listed_at            timestamptz,
  ADD COLUMN IF NOT EXISTS sold_price           double precision,
  ADD COLUMN IF NOT EXISTS sold_platform        text,
  ADD COLUMN IF NOT EXISTS sold_at              timestamptz;

-- ── Usage log for listing generation (no enforcement yet) ─────
CREATE TABLE IF NOT EXISTS public.monthly_listings (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  asset_id     uuid        NOT NULL,
  platform     text        NOT NULL,
  generated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.monthly_listings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "monthly_listings: owner access"
  ON public.monthly_listings FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS monthly_listings_user_idx
  ON public.monthly_listings (user_id, generated_at DESC);
