import { createResourceHandlers } from "@/lib/api/crud";
import { createInspectionSchema, patchInspectionSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "inspections",
  createSchema: createInspectionSchema,
  patchSchema: patchInspectionSchema,
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
