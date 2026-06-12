import { createResourceHandlers } from "@/lib/api/crud";
import { createAssetSchema, patchAssetSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "assets",
  createSchema: createAssetSchema,
  patchSchema: patchAssetSchema,
  filterColumns: ["collection_id", "listing_status"],
  defaultOrder: { column: "created_at", ascending: false },
  userIdColumn: "user_id",
});

export const GET = handlers.list;
export const POST = handlers.create;
