"use server";

import { createHash, randomBytes } from "crypto";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export type ApiKeyScope = "read" | "read_write";

export type ApiKeyRow = {
  id: string;
  name: string;
  key_prefix: string;
  scope: ApiKeyScope;
  created_at: string;
  last_used_at: string | null;
  revoked_at: string | null;
};

export async function getApiKeys(): Promise<ApiKeyRow[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("api_keys")
    .select("id, name, key_prefix, scope, created_at, last_used_at, revoked_at")
    .order("created_at", { ascending: false });
  return (data as ApiKeyRow[]) ?? [];
}

/**
 * Creates a new API key and returns the full key once. Only the SHA-256
 * hash is stored — the plaintext key cannot be recovered after this call.
 * RLS on api_keys restricts inserts to account owners/admins.
 */
export async function createApiKey(name: string, scope: ApiKeyScope) {
  if (!name.trim()) return { ok: false as const, error: "Name is required." };
  if (scope !== "read" && scope !== "read_write") {
    return { ok: false as const, error: "Invalid scope." };
  }

  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false as const, error: "Not signed in." };

  const secret = randomBytes(24).toString("hex");
  const key = `ck_live_${secret}`;
  const keyHash = createHash("sha256").update(key).digest("hex");
  const keyPrefix = key.slice(0, 12);

  const { error } = await supabase.from("api_keys").insert({
    name: name.trim(),
    key_prefix: keyPrefix,
    key_hash: keyHash,
    scope,
    created_by: user.id,
  });

  if (error) return { ok: false as const, error: error.message };

  revalidatePath("/dashboard/settings/developer");
  return { ok: true as const, key };
}

export async function revokeApiKey(id: string) {
  const supabase = createClient();
  const { error } = await supabase
    .from("api_keys")
    .update({ revoked_at: new Date().toISOString() })
    .eq("id", id);

  if (error) return { ok: false as const, error: error.message };

  revalidatePath("/dashboard/settings/developer");
  return { ok: true as const };
}
