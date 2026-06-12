import { createResourceHandlers } from "@/lib/api/crud";
import { createMaintenanceScheduleSchema, patchMaintenanceScheduleSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "maintenance_schedules",
  createSchema: createMaintenanceScheduleSchema,
  patchSchema: patchMaintenanceScheduleSchema,
  filterColumns: ["property_id", "building_id", "unit_id", "common_area_id", "frequency", "active"],
  defaultOrder: { column: "next_due_date" },
});

export const GET = handlers.list;
export const POST = handlers.create;
