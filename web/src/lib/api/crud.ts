import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import type { ZodError, ZodType } from "zod";
import { createServiceClient } from "@/lib/supabase/service";
import { authenticateRequest, isApiAuthError, errorResponse } from "@/lib/api/auth";

type CrudOptions = {
  table: string;
  createSchema: ZodType<Record<string, unknown>>;
  patchSchema: ZodType<Record<string, unknown>>;
  filterColumns?: string[];
  defaultOrder?: { column: string; ascending?: boolean };
  /**
   * Some legacy tables (properties, rooms, assets) have a `user_id not null`
   * column with no default, kept as "created by". When set, this column is
   * populated from the API key's `created_by` user on insert.
   */
  userIdColumn?: string;
};

/**
 * Builds list/create handlers for a collection route and get/patch/remove
 * handlers for an [id] route, all scoped to the requesting API key's
 * account_id via the service-role client (bypasses RLS).
 */
export function createResourceHandlers(options: CrudOptions) {
  const { table, createSchema, patchSchema, filterColumns = [], defaultOrder, userIdColumn } = options;

  async function list(request: Request) {
    const auth = await authenticateRequest(request);
    if (isApiAuthError(auth)) return auth;

    const supabase = createServiceClient();
    const url = new URL(request.url);
    const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit") ?? "50", 10) || 50, 1), 200);
    const offset = Math.max(parseInt(url.searchParams.get("offset") ?? "0", 10) || 0, 0);

    let query = supabase
      .from(table)
      .select("*", { count: "exact" })
      .eq("account_id", auth.accountId)
      .is("deleted_at", null);

    for (const col of filterColumns) {
      const value = url.searchParams.get(col);
      if (value !== null) query = query.eq(col, value);
    }

    if (defaultOrder) {
      query = query.order(defaultOrder.column, { ascending: defaultOrder.ascending ?? true });
    }

    const { data, error, count } = await query.range(offset, offset + limit - 1);
    if (error) return errorResponse(500, error.message);

    return NextResponse.json({ data, total: count ?? data?.length ?? 0 });
  }

  async function create(request: Request) {
    const auth = await authenticateRequest(request, { requireWrite: true });
    if (isApiAuthError(auth)) return auth;

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return errorResponse(400, "Invalid JSON body.");
    }

    const parsed = createSchema.safeParse(body);
    if (!parsed.success) return errorResponse(400, formatZodError(parsed.error));

    if (userIdColumn && !auth.createdBy) {
      return errorResponse(500, "This API key has no associated user; cannot create records on this resource.");
    }

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from(table)
      // Some legacy tables (properties, rooms, assets) have no `id` default,
      // so the id is generated here rather than left to Postgres.
      .insert({
        id: randomUUID(),
        ...parsed.data,
        account_id: auth.accountId,
        ...(userIdColumn ? { [userIdColumn]: auth.createdBy } : {}),
      })
      .select("*")
      .single();

    if (error) return errorResponse(400, error.message);
    return NextResponse.json({ data }, { status: 201 });
  }

  async function get(request: Request, id: string) {
    const auth = await authenticateRequest(request);
    if (isApiAuthError(auth)) return auth;

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from(table)
      .select("*")
      .eq("id", id)
      .eq("account_id", auth.accountId)
      .is("deleted_at", null)
      .maybeSingle();

    if (error) return errorResponse(500, error.message);
    if (!data) return errorResponse(404, "Not found.");
    return NextResponse.json({ data });
  }

  async function patch(request: Request, id: string) {
    const auth = await authenticateRequest(request, { requireWrite: true });
    if (isApiAuthError(auth)) return auth;

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return errorResponse(400, "Invalid JSON body.");
    }

    const parsed = patchSchema.safeParse(body);
    if (!parsed.success) return errorResponse(400, formatZodError(parsed.error));

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from(table)
      .update(parsed.data)
      .eq("id", id)
      .eq("account_id", auth.accountId)
      .is("deleted_at", null)
      .select("*")
      .maybeSingle();

    if (error) return errorResponse(400, error.message);
    if (!data) return errorResponse(404, "Not found.");
    return NextResponse.json({ data });
  }

  async function remove(request: Request, id: string) {
    const auth = await authenticateRequest(request, { requireWrite: true });
    if (isApiAuthError(auth)) return auth;

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from(table)
      .update({ deleted_at: new Date().toISOString() })
      .eq("id", id)
      .eq("account_id", auth.accountId)
      .is("deleted_at", null)
      .select("id")
      .maybeSingle();

    if (error) return errorResponse(400, error.message);
    if (!data) return errorResponse(404, "Not found.");
    return new NextResponse(null, { status: 204 });
  }

  return { list, create, get, patch, remove };
}

function formatZodError(error: ZodError) {
  return error.issues.map((i) => `${i.path.join(".") || "(body)"}: ${i.message}`).join("; ");
}
