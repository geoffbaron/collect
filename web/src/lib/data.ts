import { createClient } from "@/lib/supabase/server";
import type { Account, AssetWithLocation, Building, CommonArea, Inspection, Property, ProductMode, Unit } from "@/lib/types";

export async function getUser() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}

export async function getProfile() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle();
  return data;
}

export type AdminPlatformStats = {
  total_accounts: number;
  total_users: number;
  homeowner_accounts: number;
  property_mgr_accounts: number;
  free_accounts: number;
  pro_accounts: number;
  enterprise_accounts: number;
  total_properties: number;
  total_assets: number;
  signups_last_7_days: number;
  signups_last_30_days: number;
};

export type AdminAccountRow = {
  id: string;
  name: string;
  product_mode: ProductMode;
  plan: string;
  is_personal: boolean;
  created_at: string;
  member_count: number;
  owner_email: string | null;
  property_count: number;
  asset_count: number;
};

/** Platform-wide stats for the super-admin overview page. Returns null for non-admins. */
export async function getAdminStats(): Promise<AdminPlatformStats | null> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_platform_stats").maybeSingle();
  if (error || !data) return null;
  return data as AdminPlatformStats;
}

/** One row per account with usage stats, for the super-admin accounts table. Returns [] for non-admins. */
export async function getAdminAccounts(): Promise<AdminAccountRow[]> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_list_accounts");
  if (error || !data) return [];
  return data as AdminAccountRow[];
}

export type AdminUserRow = {
  id: string;
  email: string | null;
  name: string | null;
  is_super_admin: boolean;
  created_at: string;
};

/** Users matching a search term, for the super-admin "promote to super admin" picker. Returns [] for non-admins. */
export async function getAdminUsers(search = ""): Promise<AdminUserRow[]> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_list_users", { search });
  if (error || !data) return [];
  return data as AdminUserRow[];
}

/** The signed-in user's account (carries product_mode + plan). */
export async function getAccount(): Promise<Account | null> {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data: profile } = await supabase
    .from("profiles")
    .select("account_id")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile?.account_id) return null;
  const { data } = await supabase
    .from("accounts")
    .select("*")
    .eq("id", profile.account_id)
    .maybeSingle();
  return (data as Account) ?? null;
}

export async function getProperties(): Promise<Property[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("properties")
    .select("*")
    .is("deleted_at", null)
    .order("updated_at", { ascending: false });
  return data ?? [];
}

/** All of the user's items, each joined to its property/floor/room and a signed thumbnail. */
export async function getAssetsWithLocation(): Promise<AssetWithLocation[]> {
  const supabase = createClient();
  const { data, error } = await supabase
    .from("assets")
    .select(
      "*, collection:collections(room:rooms(name, floor:floors(name, property:properties(name))))"
    )
    .is("deleted_at", null)
    .order("updated_at", { ascending: false });

  if (error || !data) return [];

  const assets: AssetWithLocation[] = data.map((row: any) => {
    const room = row.collection?.room;
    const floor = room?.floor;
    const property = floor?.property;
    const { collection, ...asset } = row;
    return {
      ...asset,
      room_name: room?.name ?? null,
      floor_name: floor?.name ?? null,
      property_name: property?.name ?? null,
      thumb_url: null,
    };
  });

  // Batch-sign first-photo thumbnails (private bucket).
  const paths = assets.map((a) => a.photo1_path).filter((p): p is string => !!p);
  if (paths.length) {
    const { data: signed } = await supabase.storage
      .from("asset-photos")
      .createSignedUrls(paths, 3600);
    const map = new Map<string, string>();
    signed?.forEach((s) => {
      if (s.path && s.signedUrl) map.set(s.path, s.signedUrl);
    });
    for (const a of assets) {
      if (a.photo1_path) a.thumb_url = map.get(a.photo1_path) ?? null;
    }
  }

  return assets;
}

export async function getBuildings(propertyId: string): Promise<Building[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("buildings")
    .select("*")
    .eq("property_id", propertyId)
    .is("deleted_at", null)
    .order("name");
  return (data ?? []) as Building[];
}

export async function getUnits(opts: {
  propertyId?: string;
  buildingId?: string;
}): Promise<Unit[]> {
  const supabase = createClient();
  let query = supabase
    .from("units")
    .select("*")
    .is("deleted_at", null)
    .order("unit_number");
  if (opts.buildingId) query = query.eq("building_id", opts.buildingId);
  else if (opts.propertyId) query = query.eq("property_id", opts.propertyId);
  const { data } = await query;
  return (data ?? []) as Unit[];
}

export async function getCommonAreas(propertyId: string): Promise<CommonArea[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("common_areas")
    .select("*")
    .eq("property_id", propertyId)
    .is("deleted_at", null)
    .order("name");
  return (data ?? []) as CommonArea[];
}

export async function getInspections(unitId: string): Promise<Inspection[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("inspections")
    .select("*")
    .eq("unit_id", unitId)
    .is("deleted_at", null)
    .order("created_at", { ascending: false });
  return (data ?? []) as Inspection[];
}

export async function getInspection(id: string): Promise<Inspection | null> {
  const supabase = createClient();
  const { data } = await supabase
    .from("inspections")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  return (data as Inspection) ?? null;
}

/**
 * For a move_out inspection, compute the condition diff against the baseline
 * move_in inspection. Returns an array of rooms, each with per-item comparisons.
 */
export async function getInspectionDiff(
  moveOutInspectionId: string
): Promise<InspectionDiffResult> {
  const supabase = createClient();

  const moveOut = await getInspection(moveOutInspectionId);
  if (!moveOut?.baseline_inspection_id) return { rooms: [], unitId: moveOut?.unit_id ?? "" };

  // Fetch all assets from both inspections, joined to room name
  const fetchAssets = async (inspectionId: string) => {
    const { data } = await supabase
      .from("assets")
      .select(
        "id, name, category, condition, estimated_value, photo1_path, collection:collections!inner(inspection_id, room:rooms(name))"
      )
      .eq("collections.inspection_id", inspectionId)
      .is("deleted_at", null);
    return (data ?? []).map((row: any) => ({
      name: row.name as string,
      category: row.category as string,
      condition: (row.condition ?? "Unknown") as string,
      estimatedValue: row.estimated_value as number | null,
      photo1Path: row.photo1_path as string | null,
      roomName: (row.collection?.room?.name ?? "Unknown") as string,
    }));
  };

  const [moveInAssets, moveOutAssets] = await Promise.all([
    fetchAssets(moveOut.baseline_inspection_id),
    fetchAssets(moveOutInspectionId),
  ]);

  // Group by room
  const roomsMap = new Map<string, InspectionDiffRoom>();

  const getOrCreate = (name: string): InspectionDiffRoom => {
    if (!roomsMap.has(name)) roomsMap.set(name, { roomName: name, items: [] });
    return roomsMap.get(name)!;
  };

  // Index move_in by room+name
  const moveInByRoomItem = new Map<string, typeof moveInAssets[0]>();
  for (const a of moveInAssets) {
    moveInByRoomItem.set(`${a.roomName}||${a.name.toLowerCase()}`, a);
  }

  // Mark all move_in items as baseline
  for (const a of moveInAssets) {
    getOrCreate(a.roomName).items.push({
      name: a.name,
      category: a.category,
      moveInCondition: a.condition,
      moveOutCondition: null,
      photo1Path: a.photo1Path,
      isDamaged: false,
      isMissing: false,
    });
  }

  // Process move_out: match to move_in items or flag as new damage
  for (const a of moveOutAssets) {
    const key = `${a.roomName}||${a.name.toLowerCase()}`;
    const room = getOrCreate(a.roomName);
    const existing = room.items.find(
      (i) => i.name.toLowerCase() === a.name.toLowerCase()
    );
    const isDamaged =
      a.condition?.toLowerCase().includes("damage") ||
      a.condition?.toLowerCase().includes("poor") ||
      a.condition?.toLowerCase() === "bad";

    if (existing) {
      existing.moveOutCondition = a.condition;
      existing.isDamaged = isDamaged;
      if (!existing.photo1Path) existing.photo1Path = a.photo1Path;
    } else {
      // New item found in move_out (damage that wasn't there at move_in)
      room.items.push({
        name: a.name,
        category: a.category,
        moveInCondition: null,
        moveOutCondition: a.condition,
        photo1Path: a.photo1Path,
        isDamaged,
        isMissing: false,
      });
    }
  }

  // Mark items from move_in that don't appear in move_out as missing
  for (const a of moveInAssets) {
    const room = roomsMap.get(a.roomName);
    const item = room?.items.find((i) => i.name.toLowerCase() === a.name.toLowerCase() && i.moveOutCondition === null);
    if (item && !moveOutAssets.some((o) => o.roomName === a.roomName && o.name.toLowerCase() === a.name.toLowerCase())) {
      item.isMissing = true;
    }
  }

  return { rooms: Array.from(roomsMap.values()), unitId: moveOut.unit_id };
}

export type InspectionDiffRoom = {
  roomName: string;
  items: InspectionDiffItem[];
};

export type InspectionDiffItem = {
  name: string;
  category: string;
  moveInCondition: string | null;
  moveOutCondition: string | null;
  photo1Path: string | null;
  isDamaged: boolean;
  isMissing: boolean;
};

export type InspectionDiffResult = {
  rooms: InspectionDiffRoom[];
  unitId: string;
};

/** Vacancy summary for a property's units (for the PM portfolio dashboard). */
export async function getPropertyVacancySummary(
  propertyId: string
): Promise<{ total: number; vacant: number; occupied: number; notice: number }> {
  const supabase = createClient();
  const { data } = await supabase
    .from("units")
    .select("lease_status")
    .eq("property_id", propertyId)
    .is("deleted_at", null);
  const rows = data ?? [];
  return {
    total: rows.length,
    vacant: rows.filter((r: any) => r.lease_status === "vacant").length,
    occupied: rows.filter((r: any) => r.lease_status === "occupied").length,
    notice: rows.filter((r: any) => r.lease_status === "notice").length,
  };
}
