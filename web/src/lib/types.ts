// Mirrors the Supabase schema (public.* tables). Snake_case to match Postgres.

// ── Account / organization layer (Phase 0 foundation) ──────────────────
// Data is owned by an account, not a user. A homeowner is an account-of-one;
// a property manager is an organization with many members. `user_id` on the
// rows below is retained as "created by".

export type ProductMode = "homeowner" | "property_manager";
export type AccountRole = "owner" | "admin" | "manager" | "member";
export type Plan = "free" | "pro" | "enterprise";

export type Account = {
  id: string;
  name: string;
  product_mode: ProductMode;
  plan: Plan;
  is_personal: boolean;
  created_at: string;
  updated_at: string;
};

export type AccountMember = {
  account_id: string;
  user_id: string;
  role: AccountRole;
  region_id: string | null;
  created_at: string;
};

export type Region = {
  id: string;
  account_id: string;
  name: string;
  created_at: string;
};

export type Property = {
  id: string;
  account_id: string;
  user_id: string;
  name: string;
  address: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type Floor = {
  id: string;
  account_id: string;
  user_id: string;
  property_id: string;
  name: string;
  sort_order: number;
  deleted_at: string | null;
};

export type Room = {
  id: string;
  account_id: string;
  user_id: string;
  floor_id: string | null;
  unit_id: string | null;
  common_area_id: string | null;
  name: string;
  deleted_at: string | null;
};

// ── Multifamily model (Phase 2) ─────────────────────────────

export type LeaseStatus = "vacant" | "occupied" | "notice" | "eviction";
export type TurnStatus = "clean" | "needs_turn" | "in_progress" | "turned";
export type AreaType = "lobby" | "gym" | "pool" | "hallway" | "laundry" | "parking" | "office" | "other";

export type Building = {
  id: string;
  account_id: string;
  property_id: string;
  name: string;
  address: string;
  floor_count: number | null;
  year_built: number | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type Unit = {
  id: string;
  account_id: string;
  property_id: string;
  building_id: string | null;
  unit_number: string;
  floor_number: number | null;
  sqft: number | null;
  bedrooms: number | null;
  bathrooms: number | null;
  lease_status: LeaseStatus;
  turn_status: TurnStatus;
  current_tenant_name: string | null;
  lease_start: string | null;
  lease_end: string | null;
  monthly_rent: number | null;
  notes: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type CommonArea = {
  id: string;
  account_id: string;
  property_id: string;
  building_id: string | null;
  name: string;
  area_type: AreaType;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

// ── Inspections (Phase 3) ───────────────────────────────────

export type InspectionType = "move_in" | "move_out" | "routine" | "turn";
export type InspectionStatus = "in_progress" | "completed" | "cancelled";

export type Inspection = {
  id: string;
  account_id: string;
  unit_id: string;
  inspection_type: InspectionType;
  status: InspectionStatus;
  inspector_id: string | null;
  scheduled_at: string | null;
  completed_at: string | null;
  notes: string;
  baseline_inspection_id: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export const INSPECTION_TYPE_LABELS: Record<InspectionType, string> = {
  move_in:  "Move-In",
  move_out: "Move-Out",
  routine:  "Routine",
  turn:     "Turn",
};

export const INSPECTION_STATUS_LABELS: Record<InspectionStatus, string> = {
  in_progress: "In Progress",
  completed:   "Completed",
  cancelled:   "Cancelled",
};

export const LEASE_STATUS_LABELS: Record<LeaseStatus, string> = {
  vacant: "Vacant",
  occupied: "Occupied",
  notice: "Notice",
  eviction: "Eviction",
};

export const TURN_STATUS_LABELS: Record<TurnStatus, string> = {
  clean: "Clean",
  needs_turn: "Needs Turn",
  in_progress: "In Progress",
  turned: "Turned",
};

export type Collection = {
  id: string;
  account_id: string;
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
  account_id: string;
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
