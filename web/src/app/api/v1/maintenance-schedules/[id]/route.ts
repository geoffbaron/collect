import { createResourceHandlers } from "@/lib/api/crud";
import { createMaintenanceScheduleSchema, patchMaintenanceScheduleSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "maintenance_schedules",
  createSchema: createMaintenanceScheduleSchema,
  patchSchema: patchMaintenanceScheduleSchema,
});

export async function GET(request: Request, { params }: { params: { id: string } }) {
  return handlers.get(request, params.id);
}
export async function PATCH(request: Request, { params }: { params: { id: string } }) {
  return handlers.patch(request, params.id);
}
export async function DELETE(request: Request, { params }: { params: { id: string } }) {
  return handlers.remove(request, params.id);
}
