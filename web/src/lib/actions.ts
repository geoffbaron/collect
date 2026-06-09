"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import type { LeaseStatus, ProductMode, TurnStatus } from "@/lib/types";

/**
 * Switches the signed-in account between the homeowner and property-manager
 * products. Only account owners/admins can do this (enforced by the
 * "accounts: admins update" RLS policy); a personal account-of-one owner
 * qualifies. Revalidates the dashboard layout so the nav re-renders.
 */
export async function setProductMode(mode: ProductMode) {
  if (mode !== "homeowner" && mode !== "property_manager") {
    return { ok: false, error: "Unknown product mode." };
  }
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false, error: "Not signed in." };

  const { data: profile } = await supabase
    .from("profiles")
    .select("account_id")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile?.account_id) return { ok: false, error: "No account found." };

  const { error } = await supabase
    .from("accounts")
    .update({ product_mode: mode })
    .eq("id", profile.account_id);

  revalidatePath("/dashboard", "layout");
  return { ok: !error, error: error?.message };
}

const EDITABLE_FIELDS = [
  "name",
  "category",
  "asset_description",
  "condition",
  "quantity",
  "estimated_value",
  "listing_status",
  "asking_price",
  "listing_title",
  "listing_description",
];

export async function updateAsset(id: string, fields: Record<string, unknown>) {
  const supabase = createClient();
  const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };
  for (const key of EDITABLE_FIELDS) {
    if (key in fields) patch[key] = fields[key];
  }
  // Keep platform flags consistent when moving out of an active listing state.
  if (patch.listing_status === "not_listed") {
    patch.listed_facebook = false;
    patch.listed_craigslist = false;
    patch.listed_at = null;
  }
  const { error } = await supabase.from("assets").update(patch).eq("id", id);
  revalidatePath("/dashboard/items");
  revalidatePath("/dashboard/listings");
  revalidatePath("/dashboard");
  return { ok: !error, error: error?.message };
}

export async function deleteAsset(id: string) {
  const supabase = createClient();
  // Soft delete (matches the iOS app's sync semantics) so the deletion propagates.
  const { error } = await supabase
    .from("assets")
    .update({ deleted_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq("id", id);
  revalidatePath("/dashboard/items");
  revalidatePath("/dashboard/listings");
  return { ok: !error, error: error?.message };
}

// ── Multifamily CRUD ─────────────────────────────────────────

export async function createBuilding(propertyId: string, name: string, address = "") {
  const supabase = createClient();
  const { data, error } = await supabase
    .from("buildings")
    .insert({ property_id: propertyId, name: name.trim(), address: address.trim() })
    .select()
    .single();
  if (error) return { ok: false, error: error.message, building: null };
  revalidatePath(`/dashboard/portfolio/${propertyId}`);
  return { ok: true, error: null, building: data };
}

export async function createUnit(input: {
  propertyId: string;
  buildingId: string;
  unitNumber: string;
  floorNumber?: number | null;
  sqft?: number | null;
  bedrooms?: number | null;
  bathrooms?: number | null;
}) {
  const supabase = createClient();
  const { data, error } = await supabase
    .from("units")
    .insert({
      property_id: input.propertyId,
      building_id: input.buildingId,
      unit_number: input.unitNumber.trim(),
      floor_number: input.floorNumber ?? null,
      sqft: input.sqft ?? null,
      bedrooms: input.bedrooms ?? null,
      bathrooms: input.bathrooms ?? null,
    })
    .select()
    .single();
  if (error) return { ok: false, error: error.message, unit: null };
  revalidatePath(`/dashboard/portfolio/${input.propertyId}/${input.buildingId}`);
  return { ok: true, error: null, unit: data };
}

export async function updateUnitStatus(
  id: string,
  propertyId: string,
  buildingId: string,
  patch: { lease_status?: LeaseStatus; turn_status?: TurnStatus }
) {
  const supabase = createClient();
  const { error } = await supabase.from("units").update(patch).eq("id", id);
  revalidatePath(`/dashboard/portfolio/${propertyId}/${buildingId}`);
  return { ok: !error, error: error?.message };
}

/**
 * Bulk-creates units from a CSV string with columns:
 * unit_number, floor_number, bedrooms, bathrooms, sqft
 * (header row required; extra columns ignored)
 */
export async function importUnitsFromCsv(
  propertyId: string,
  buildingId: string,
  csvText: string
) {
  const lines = csvText.trim().split(/\r?\n/);
  if (lines.length < 2) return { ok: false, error: "CSV must have a header row and at least one data row.", count: 0 };

  const header = lines[0].split(",").map((h) => h.trim().toLowerCase());
  const col = (name: string) => header.indexOf(name);

  if (col("unit_number") === -1) {
    return { ok: false, error: "CSV must have a 'unit_number' column.", count: 0 };
  }

  const rows = lines.slice(1).map((line) => {
    const cells = line.split(",").map((c) => c.trim());
    const get = (name: string) => {
      const i = col(name);
      return i >= 0 ? (cells[i] ?? "") : "";
    };
    const num = (name: string) => {
      const v = parseFloat(get(name));
      return isNaN(v) ? null : v;
    };
    return {
      property_id: propertyId,
      building_id: buildingId,
      unit_number: get("unit_number"),
      floor_number: num("floor_number") != null ? Math.round(num("floor_number")!) : null,
      bedrooms: num("bedrooms"),
      bathrooms: num("bathrooms"),
      sqft: num("sqft") != null ? Math.round(num("sqft")!) : null,
    };
  }).filter((r) => r.unit_number.length > 0);

  if (rows.length === 0) return { ok: false, error: "No valid rows found in CSV.", count: 0 };

  const supabase = createClient();
  const { error } = await supabase.from("units").insert(rows);
  if (error) return { ok: false, error: error.message, count: 0 };

  revalidatePath(`/dashboard/portfolio/${propertyId}/${buildingId}`);
  return { ok: true, error: null, count: rows.length };
}

type Backup = {
  properties?: any[];
  floors?: any[];
  rooms?: any[];
  collections?: any[];
  assets?: any[];
};

/**
 * Imports a JSON backup into the signed-in account. All IDs are regenerated and
 * relationships remapped, so it's safe to import into the same or a different
 * account without primary-key collisions. Photos are not included in JSON
 * backups, so imported items come in without images.
 */
export async function importBackup(jsonText: string) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false, error: "Not signed in." };

  let backup: Backup;
  try {
    backup = JSON.parse(jsonText);
  } catch {
    return { ok: false, error: "That file isn't valid JSON." };
  }

  const now = new Date().toISOString();
  const idMap = new Map<string, string>();
  const remap = (oldId: string) => {
    if (!idMap.has(oldId)) idMap.set(oldId, crypto.randomUUID());
    return idMap.get(oldId)!;
  };

  const properties = (backup.properties ?? []).map((p) => ({
    id: remap(p.id),
    user_id: user.id,
    name: p.name ?? "Imported Property",
    address: p.address ?? "",
    created_at: now,
    updated_at: now,
  }));

  const floors = (backup.floors ?? []).map((f) => ({
    id: remap(f.id),
    user_id: user.id,
    property_id: remap(f.property_id),
    name: f.name ?? "Floor",
    sort_order: f.sort_order ?? 0,
    created_at: now,
    updated_at: now,
  }));

  const rooms = (backup.rooms ?? []).map((r) => ({
    id: remap(r.id),
    user_id: user.id,
    floor_id: remap(r.floor_id),
    name: r.name ?? "Room",
    created_at: now,
    updated_at: now,
  }));

  const collections = (backup.collections ?? []).map((c) => ({
    id: remap(c.id),
    user_id: user.id,
    room_id: remap(c.room_id),
    prompt_type: c.prompt_type ?? "generalInventory",
    custom_prompt: c.custom_prompt ?? null,
    status: "completed",
    captured_at: c.captured_at ?? now,
    created_at: now,
    updated_at: now,
  }));

  const assets = (backup.assets ?? []).map((a) => ({
    id: remap(a.id),
    user_id: user.id,
    collection_id: remap(a.collection_id),
    name: a.name ?? "Item",
    category: a.category ?? "Other",
    asset_description: a.asset_description ?? "",
    condition: a.condition ?? null,
    quantity: a.quantity ?? 1,
    confidence: a.confidence ?? 1.0,
    estimated_value: a.estimated_value ?? null,
    is_confirmed: a.is_confirmed ?? true,
    // Photos live in storage and aren't portable across accounts — import without them.
    photo1_path: null,
    photo2_path: null,
    listing_status: a.listing_status ?? "not_listed",
    asking_price: a.asking_price ?? null,
    created_at: now,
    updated_at: now,
  }));

  // Insert parents before children to satisfy FK constraints.
  for (const [table, rows] of [
    ["properties", properties],
    ["floors", floors],
    ["rooms", rooms],
    ["collections", collections],
    ["assets", assets],
  ] as const) {
    if (rows.length === 0) continue;
    const { error } = await supabase.from(table).insert(rows as any[]);
    if (error) return { ok: false, error: `Failed importing ${table}: ${error.message}` };
  }

  revalidatePath("/dashboard");
  revalidatePath("/dashboard/items");
  return {
    ok: true,
    counts: {
      properties: properties.length,
      floors: floors.length,
      rooms: rooms.length,
      collections: collections.length,
      assets: assets.length,
    },
  };
}
