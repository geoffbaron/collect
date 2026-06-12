import { createResourceHandlers } from "@/lib/api/crud";
import { createCommonAreaSchema, patchCommonAreaSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "common_areas",
  createSchema: createCommonAreaSchema,
  patchSchema: patchCommonAreaSchema,
  filterColumns: ["property_id", "building_id"],
  defaultOrder: { column: "name" },
});

export const GET = handlers.list;
export const POST = handlers.create;
