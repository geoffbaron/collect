import { createClient } from "@/lib/supabase/server";
import { localDateString } from "@/lib/dates";
import type { Account, AccountInvite, AccountRole, AssetWithLocation, Building, CapitalAsset, CommonArea, Inspection, MaintenanceSchedule, Property, ProductMode, TeamMember, Unit, WorkOrder, WorkOrderPriority, WorkOrderStatus, WorkOrderWithContext } from "@/lib/types";

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

// ── Team (Phase 5) ──────────────────────────────────────────

/** The signed-in user's role in their active account. */
export async function getMyRole(): Promise<AccountRole | null> {
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
    .from("account_members")
    .select("role")
    .eq("account_id", profile.account_id)
    .eq("user_id", user.id)
    .maybeSingle();
  return (data?.role as AccountRole) ?? null;
}

/** Everyone in the signed-in user's active account, with profile name/email. */
export async function getAccountMembers(): Promise<TeamMember[]> {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [];
  const { data: profile } = await supabase
    .from("profiles")
    .select("account_id")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile?.account_id) return [];

  const { data: members } = await supabase
    .from("account_members")
    .select("user_id, role, created_at")
    .eq("account_id", profile.account_id)
    .order("created_at", { ascending: true });
  if (!members || members.length === 0) return [];

  // account_members.user_id references auth.users (no FK to profiles), so
  // PostgREST can't embed — fetch the profiles in a second query.
  const { data: profiles } = await supabase
    .from("profiles")
    .select("id, name, email")
    .in("id", members.map((m) => m.user_id));
  const profileById = new Map((profiles ?? []).map((p) => [p.id, p]));

  return members.map((m) => ({
    user_id: m.user_id,
    role: m.role as AccountRole,
    created_at: m.created_at,
    name: profileById.get(m.user_id)?.name ?? null,
    email: profileById.get(m.user_id)?.email ?? null,
  }));
}

/** Unclaimed, unrevoked invites for the signed-in user's account (owner/admin only — RLS returns [] otherwise). */
export async function getPendingInvites(): Promise<AccountInvite[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("account_invites")
    .select("*")
    .is("claimed_at", null)
    .is("revoked_at", null)
    .order("created_at", { ascending: false });
  return (data ?? []) as AccountInvite[];
}

/** A pending invite addressed to the signed-in user's email, if any. */
export async function getMyPendingInvite(): Promise<{ account_name: string; role: AccountRole } | null> {
  const supabase = createClient();
  const { data } = await supabase.rpc("pending_invite_for_me").maybeSingle();
  if (!data) return null;
  return data as { account_name: string; role: AccountRole };
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

/**
 * All of the user's items, each joined to its property/floor/room and a
 * signed thumbnail. Pass `skipThumbnails: true` for views (e.g. the PM
 * portfolio dashboard) that only need counts, to avoid signing a URL for
 * every asset's photo.
 */
export async function getAssetsWithLocation(opts: { skipThumbnails?: boolean } = {}): Promise<AssetWithLocation[]> {
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

  if (opts.skipThumbnails) return assets;

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

/** Building counts for many properties in a single query, keyed by property_id. */
export async function getBuildingCountsByProperty(propertyIds: string[]): Promise<Map<string, number>> {
  const counts = new Map<string, number>();
  if (propertyIds.length === 0) return counts;

  const supabase = createClient();
  const { data } = await supabase
    .from("buildings")
    .select("property_id")
    .in("property_id", propertyIds)
    .is("deleted_at", null);

  for (const row of data ?? []) {
    counts.set(row.property_id, (counts.get(row.property_id) ?? 0) + 1);
  }
  return counts;
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

// ── Work Orders (Phase 4) ───────────────────────────────────

export async function getWorkOrders(filter: { propertyId: string; unitId?: string }): Promise<WorkOrder[]> {
  const supabase = createClient();
  let query = supabase
    .from("work_orders")
    .select("*")
    .eq("property_id", filter.propertyId)
    .is("deleted_at", null);
  if (filter.unitId) query = query.eq("unit_id", filter.unitId);
  const { data } = await query.order("created_at", { ascending: false });
  return (data ?? []) as WorkOrder[];
}

export async function getWorkOrder(id: string): Promise<WorkOrder | null> {
  const supabase = createClient();
  const { data } = await supabase
    .from("work_orders")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  return (data as WorkOrder) ?? null;
}

// ── Capital Asset Register (Phase 4) ────────────────────────

export async function getCapitalAssets(filter: { propertyId: string; unitId?: string }): Promise<CapitalAsset[]> {
  const supabase = createClient();
  let query = supabase
    .from("capital_assets")
    .select("*")
    .eq("property_id", filter.propertyId)
    .is("deleted_at", null);
  if (filter.unitId) query = query.eq("unit_id", filter.unitId);
  const { data } = await query.order("created_at", { ascending: false });
  return (data ?? []) as CapitalAsset[];
}

export async function getCapitalAsset(id: string): Promise<CapitalAsset | null> {
  const supabase = createClient();
  const { data } = await supabase
    .from("capital_assets")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  return (data as CapitalAsset) ?? null;
}

// ── Preventive Maintenance Schedules (Phase 4) ──────────────

export async function getMaintenanceSchedules(filter: { propertyId: string; unitId?: string }): Promise<MaintenanceSchedule[]> {
  const supabase = createClient();
  let query = supabase
    .from("maintenance_schedules")
    .select("*")
    .eq("property_id", filter.propertyId)
    .is("deleted_at", null);
  if (filter.unitId) query = query.eq("unit_id", filter.unitId);
  const { data } = await query.order("next_due_date", { ascending: true });
  return (data ?? []) as MaintenanceSchedule[];
}

export async function getMaintenanceSchedule(id: string): Promise<MaintenanceSchedule | null> {
  const supabase = createClient();
  const { data } = await supabase
    .from("maintenance_schedules")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  return (data as MaintenanceSchedule) ?? null;
}

// ── Portfolio-wide dashboard queries (Phase 4) ──────────────

/** Open or in-progress work orders across every property in the account. */
export async function getOpenWorkOrders(): Promise<WorkOrder[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("work_orders")
    .select("*")
    .in("status", ["open", "in_progress"])
    .is("deleted_at", null)
    .order("created_at", { ascending: false });
  return (data ?? []) as WorkOrder[];
}

/** Map of user_id → display name (profile name, falling back to email) for assignee labels. */
export async function getProfileNames(userIds: string[]): Promise<Map<string, string>> {
  const ids = Array.from(new Set(userIds.filter(Boolean)));
  if (ids.length === 0) return new Map();
  const supabase = createClient();
  const { data } = await supabase.from("profiles").select("id, name, email").in("id", ids);
  return new Map((data ?? []).map((p) => [p.id, p.name || p.email || "Unknown"]));
}

export type WorkOrderFilters = {
  status?: WorkOrderStatus | "open_or_in_progress";
  priority?: WorkOrderPriority;
  propertyId?: string;
  assignedTo?: string;
};

/**
 * Work orders across every property in the account, with property/unit and
 * assignee display context — for the portfolio-wide work orders page.
 */
export async function getAllWorkOrders(filters: WorkOrderFilters = {}): Promise<WorkOrderWithContext[]> {
  const supabase = createClient();
  let query = supabase
    .from("work_orders")
    .select("*, properties(name), units(unit_number)")
    .is("deleted_at", null);
  if (filters.status === "open_or_in_progress") query = query.in("status", ["open", "in_progress"]);
  else if (filters.status) query = query.eq("status", filters.status);
  if (filters.priority) query = query.eq("priority", filters.priority);
  if (filters.propertyId) query = query.eq("property_id", filters.propertyId);
  if (filters.assignedTo) query = query.eq("assigned_to", filters.assignedTo);
  const { data } = await query.order("created_at", { ascending: false });

  const rows = (data ?? []) as (WorkOrder & {
    properties: { name: string } | null;
    units: { unit_number: string } | null;
  })[];
  const names = await getProfileNames(rows.map((r) => r.assigned_to ?? ""));
  return rows.map(({ properties, units, ...wo }) => ({
    ...wo,
    property_name: properties?.name ?? null,
    unit_number: units?.unit_number ?? null,
    assignee_name: wo.assigned_to ? names.get(wo.assigned_to) ?? null : null,
  }));
}

/** Active maintenance schedules whose next due date has passed, across every property. */
export async function getOverdueMaintenanceSchedules(): Promise<MaintenanceSchedule[]> {
  const supabase = createClient();
  const today = localDateString();
  const { data } = await supabase
    .from("maintenance_schedules")
    .select("*")
    .eq("active", true)
    .lte("next_due_date", today)
    .is("deleted_at", null)
    .order("next_due_date", { ascending: true });
  return (data ?? []) as MaintenanceSchedule[];
}

/** Vacancy summary across every unit in the account's portfolio. */
export async function getPortfolioVacancySummary(): Promise<{ total: number; vacant: number; occupied: number; notice: number }> {
  const supabase = createClient();
  const { data } = await supabase
    .from("units")
    .select("lease_status")
    .is("deleted_at", null);
  const rows = data ?? [];
  return {
    total: rows.length,
    vacant: rows.filter((r: any) => r.lease_status === "vacant").length,
    occupied: rows.filter((r: any) => r.lease_status === "occupied").length,
    notice: rows.filter((r: any) => r.lease_status === "notice").length,
  };
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
