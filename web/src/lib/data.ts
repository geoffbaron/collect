import { createClient } from "@/lib/supabase/server";
import type { AssetWithLocation, Property } from "@/lib/types";

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
