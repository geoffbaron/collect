import { createClient } from "@/lib/supabase/server";
import type { Account, AssetWithLocation, Building, CommonArea, Property, Unit } from "@/lib/types";

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
