import { createResourceHandlers } from "@/lib/api/crud";
import { createBuildingSchema, patchBuildingSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "buildings",
  createSchema: createBuildingSchema,
  patchSchema: patchBuildingSchema,
  filterColumns: ["property_id"],
  defaultOrder: { column: "name" },
});

export const GET = handlers.list;
export const POST = handlers.create;
