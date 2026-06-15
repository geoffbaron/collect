import { createResourceHandlers } from "@/lib/api/crud";
import { createPropertySchema, patchPropertySchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "properties",
  createSchema: createPropertySchema,
  patchSchema: patchPropertySchema,
  defaultOrder: { column: "name" },
  userIdColumn: "user_id",
});

export const GET = handlers.list;
export const POST = handlers.create;
