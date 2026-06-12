import { createResourceHandlers } from "@/lib/api/crud";
import { createInspectionSchema, patchInspectionSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "inspections",
  createSchema: createInspectionSchema,
  patchSchema: patchInspectionSchema,
  filterColumns: ["unit_id", "status", "inspection_type"],
  defaultOrder: { column: "created_at", ascending: false },
});

export const GET = handlers.list;
export const POST = handlers.create;
