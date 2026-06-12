import { createResourceHandlers } from "@/lib/api/crud";
import { createUnitSchema, patchUnitSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "units",
  createSchema: createUnitSchema,
  patchSchema: patchUnitSchema,
  filterColumns: ["property_id", "building_id", "lease_status", "turn_status"],
  defaultOrder: { column: "unit_number" },
});

export const GET = handlers.list;
export const POST = handlers.create;
