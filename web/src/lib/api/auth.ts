import { createHash } from "crypto";
import { NextResponse } from "next/server";
import { createServiceClient } from "@/lib/supabase/service";

export type ApiAuth = {
  accountId: string;
  scope: "read" | "read_write";
  apiKeyId: string;
  createdBy: string | null;
};

export type ApiAuthResult = ApiAuth | NextResponse;

export function isApiAuthError(result: ApiAuthResult): result is NextResponse {
  return result instanceof NextResponse;
}

function hashKey(key: string): string {
  return createHash("sha256").update(key).digest("hex");
}

export function errorResponse(status: number, message: string) {
  return NextResponse.json({ error: message }, { status });
}

/**
 * Authenticates a request to /api/v1/* via `Authorization: Bearer <key>`.
 * Looks up the key by its SHA-256 hash using the service-role client
 * (bypassing RLS), and returns the account_id + scope it grants.
 */
export async function authenticateRequest(
  request: Request,
  { requireWrite = false }: { requireWrite?: boolean } = {}
): Promise<ApiAuthResult> {
  const authHeader = request.headers.get("authorization") ?? "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return errorResponse(401, "Missing or malformed Authorization header. Expected: Bearer <api key>");
  }

  const key = match[1].trim();
  const keyHash = hashKey(key);
  const supabase = createServiceClient();

  const { data: apiKey, error } = await supabase
    .from("api_keys")
    .select("id, account_id, scope, revoked_at, created_by")
    .eq("key_hash", keyHash)
    .is("revoked_at", null)
    .maybeSingle();

  if (error || !apiKey) {
    return errorResponse(401, "Invalid or revoked API key.");
  }

  if (requireWrite && apiKey.scope !== "read_write") {
    return errorResponse(403, "This API key has read-only scope and cannot perform write operations.");
  }

  await supabase
    .from("api_keys")
    .update({ last_used_at: new Date().toISOString() })
    .eq("id", apiKey.id);

  return { accountId: apiKey.account_id, scope: apiKey.scope, apiKeyId: apiKey.id, createdBy: apiKey.created_by };
}
