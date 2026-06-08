// Mirrors the Supabase schema (public.* tables). Snake_case to match Postgres.

export type Property = {
  id: string;
  user_id: string;
  name: string;
  address: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type Floor = {
  id: string;
  user_id: string;
  property_id: string;
  name: string;
  sort_order: number;
  deleted_at: string | null;
};

export type Room = {
  id: string;
  user_id: string;
  floor_id: string;
  name: string;
  deleted_at: string | null;
};

export type Collection = {
  id: string;
  user_id: string;
  room_id: string;
  prompt_type: string;
  custom_prompt: string | null;
  status: string;
  captured_at: string;
  deleted_at: string | null;
};

export type ListingStatus = "not_listed" | "ready" | "listed" | "pending" | "sold";

export type Asset = {
  id: string;
  user_id: string;
  collection_id: string;
  name: string;
  category: string;
  asset_description: string;
  condition: string | null;
  quantity: number;
  confidence: number;
  estimated_value: number | null;
  latitude: number | null;
  longitude: number | null;
  is_confirmed: boolean;
  photo1_path: string | null;
  photo2_path: string | null;
  listing_status: ListingStatus;
  listing_title: string | null;
  listing_description: string | null;
  asking_price: number | null;
  listed_facebook: boolean;
  listed_craigslist: boolean;
  listed_at: string | null;
  sold_price: number | null;
  sold_platform: string | null;
  sold_at: string | null;
  listing_url: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

// Asset joined with its location path (property > floor > room) for the UI.
export type AssetWithLocation = Asset & {
  room_name: string | null;
  floor_name: string | null;
  property_name: string | null;
  thumb_url?: string | null;
};

export const LISTING_LABELS: Record<ListingStatus, string> = {
  not_listed: "Not Listed",
  ready: "Ready",
  listed: "Listed",
  pending: "Pending",
  sold: "Sold",
};
