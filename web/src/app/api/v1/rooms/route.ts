import { createResourceHandlers } from "@/lib/api/crud";
import { createRoomSchema, patchRoomSchema } from "@/lib/api/schemas";

const handlers = createResourceHandlers({
  table: "rooms",
  createSchema: createRoomSchema,
  patchSchema: patchRoomSchema,
  filterColumns: ["floor_id", "unit_id", "common_area_id"],
  defaultOrder: { column: "name" },
  userIdColumn: "user_id",
});

export const GET = handlers.list;
export const POST = handlers.create;
