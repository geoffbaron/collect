import { z } from "zod";

// Zod request schemas for /api/v1/*. Field names mirror the Postgres
// columns (snake_case) in web/src/lib/types.ts. `create*` schemas require
// the columns that are NOT NULL without a default; `patch*` schemas make
// every field optional via .partial().

const uuid = z.string().uuid();
const dateStr = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Expected YYYY-MM-DD");
const datetimeStr = z.string().datetime({ offset: true });

const workOrderCategory = z.enum([
  "plumbing", "electrical", "hvac", "appliance", "structural", "pest", "safety", "cosmetic", "other",
]);
const workOrderPriority = z.enum(["low", "medium", "high", "urgent"]);
const workOrderStatus = z.enum(["open", "in_progress", "completed", "cancelled"]);
const capitalAssetType = z.enum([
  "hvac", "roof", "water_heater", "appliance", "electrical_panel", "plumbing", "elevator", "structural", "other",
]);
const capitalAssetCondition = z.enum(["excellent", "good", "fair", "poor", "needs_replacement"]);
const maintenanceFrequency = z.enum(["daily", "weekly", "monthly", "quarterly", "semiannual", "annual"]);
const leaseStatus = z.enum(["vacant", "occupied", "notice", "eviction"]);
const turnStatus = z.enum(["clean", "needs_turn", "in_progress", "turned"]);
const areaType = z.enum(["lobby", "gym", "pool", "hallway", "laundry", "parking", "office", "other"]);
const inspectionType = z.enum(["move_in", "move_out", "routine", "turn"]);
const inspectionStatus = z.enum(["in_progress", "completed", "cancelled"]);

// ── Properties ─────────────────────────────────────────────
export const createPropertySchema = z.object({
  name: z.string().min(1),
  address: z.string().min(1),
});
export const patchPropertySchema = createPropertySchema.partial();

// ── Buildings ──────────────────────────────────────────────
export const createBuildingSchema = z.object({
  property_id: uuid,
  name: z.string().min(1),
  address: z.string().optional(),
  floor_count: z.number().int().nullable().optional(),
  year_built: z.number().int().nullable().optional(),
});
export const patchBuildingSchema = createBuildingSchema.partial();

// ── Units ──────────────────────────────────────────────────
export const createUnitSchema = z.object({
  property_id: uuid,
  building_id: uuid.nullable().optional(),
  unit_number: z.string().min(1),
  floor_number: z.number().int().nullable().optional(),
  sqft: z.number().nullable().optional(),
  bedrooms: z.number().int().nullable().optional(),
  bathrooms: z.number().nullable().optional(),
  lease_status: leaseStatus.optional(),
  turn_status: turnStatus.optional(),
  current_tenant_name: z.string().nullable().optional(),
  lease_start: dateStr.nullable().optional(),
  lease_end: dateStr.nullable().optional(),
  monthly_rent: z.number().nullable().optional(),
  notes: z.string().optional(),
});
export const patchUnitSchema = createUnitSchema.partial();

// ── Common areas ───────────────────────────────────────────
export const createCommonAreaSchema = z.object({
  property_id: uuid,
  building_id: uuid.nullable().optional(),
  name: z.string().min(1),
  area_type: areaType.optional(),
});
export const patchCommonAreaSchema = createCommonAreaSchema.partial();

// ── Rooms ──────────────────────────────────────────────────
export const createRoomSchema = z.object({
  floor_id: uuid.nullable().optional(),
  unit_id: uuid.nullable().optional(),
  common_area_id: uuid.nullable().optional(),
  name: z.string().min(1),
});
export const patchRoomSchema = createRoomSchema.partial();

// ── Assets ─────────────────────────────────────────────────
export const createAssetSchema = z.object({
  collection_id: uuid,
  name: z.string().min(1),
  category: z.string().optional(),
  asset_description: z.string().optional(),
  condition: z.string().nullable().optional(),
  quantity: z.number().int().optional(),
  estimated_value: z.number().nullable().optional(),
  is_confirmed: z.boolean().optional(),
});
export const patchAssetSchema = createAssetSchema.partial();

// ── Inspections ────────────────────────────────────────────
export const createInspectionSchema = z.object({
  unit_id: uuid,
  inspection_type: inspectionType,
  status: inspectionStatus.optional(),
  inspector_id: uuid.nullable().optional(),
  scheduled_at: datetimeStr.nullable().optional(),
  completed_at: datetimeStr.nullable().optional(),
  notes: z.string().optional(),
  baseline_inspection_id: uuid.nullable().optional(),
});
export const patchInspectionSchema = createInspectionSchema.partial();

// ── Work orders ────────────────────────────────────────────
export const createWorkOrderSchema = z.object({
  property_id: uuid,
  building_id: uuid.nullable().optional(),
  unit_id: uuid.nullable().optional(),
  common_area_id: uuid.nullable().optional(),
  title: z.string().min(1),
  description: z.string().optional(),
  category: workOrderCategory.optional(),
  priority: workOrderPriority.optional(),
  status: workOrderStatus.optional(),
  assigned_to: uuid.nullable().optional(),
  reported_by: uuid.nullable().optional(),
  due_date: dateStr.nullable().optional(),
  completed_at: datetimeStr.nullable().optional(),
  source_inspection_id: uuid.nullable().optional(),
});
export const patchWorkOrderSchema = createWorkOrderSchema.partial();

// ── Capital assets ─────────────────────────────────────────
export const createCapitalAssetSchema = z.object({
  property_id: uuid,
  building_id: uuid.nullable().optional(),
  unit_id: uuid.nullable().optional(),
  common_area_id: uuid.nullable().optional(),
  name: z.string().min(1),
  asset_type: capitalAssetType.optional(),
  manufacturer: z.string().optional(),
  model: z.string().optional(),
  serial_number: z.string().optional(),
  install_date: dateStr.nullable().optional(),
  expected_lifespan_years: z.number().int().nullable().optional(),
  purchase_cost: z.number().nullable().optional(),
  condition: capitalAssetCondition.optional(),
  warranty_expires: dateStr.nullable().optional(),
  last_serviced_at: dateStr.nullable().optional(),
  notes: z.string().optional(),
});
export const patchCapitalAssetSchema = createCapitalAssetSchema.partial();

// ── Maintenance schedules ──────────────────────────────────
export const createMaintenanceScheduleSchema = z.object({
  property_id: uuid,
  building_id: uuid.nullable().optional(),
  unit_id: uuid.nullable().optional(),
  common_area_id: uuid.nullable().optional(),
  title: z.string().min(1),
  description: z.string().optional(),
  category: workOrderCategory.optional(),
  frequency: maintenanceFrequency,
  next_due_date: dateStr,
  last_completed_at: datetimeStr.nullable().optional(),
  assigned_to: uuid.nullable().optional(),
  active: z.boolean().optional(),
});
export const patchMaintenanceScheduleSchema = createMaintenanceScheduleSchema.partial();
