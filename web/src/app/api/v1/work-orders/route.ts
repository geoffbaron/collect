import { createResourceHandlers } from "@/lib/api/crud";
import { createWorkOrderSchema, patchWorkOrderSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "work_orders",
  createSchema: createWorkOrderSchema,
  patchSchema: patchWorkOrderSchema,
  filterColumns: ["property_id", "building_id", "unit_id", "common_area_id", "status", "priority", "category"],
  defaultOrder: { column: "created_at", ascending: false },
});

export const GET = handlers.list;
export const POST = handlers.create;
