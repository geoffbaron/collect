import { createResourceHandlers } from "@/lib/api/crud";
import { createCapitalAssetSchema, patchCapitalAssetSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "capital_assets",
  createSchema: createCapitalAssetSchema,
  patchSchema: patchCapitalAssetSchema,
  filterColumns: ["property_id", "building_id", "unit_id", "common_area_id", "asset_type", "condition"],
  defaultOrder: { column: "created_at", ascending: false },
});

export const GET = handlers.list;
export const POST = handlers.create;
