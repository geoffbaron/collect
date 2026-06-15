import { randomUUID } from "crypto";
import { createServiceClient } from "@/lib/supabase/service";
import type { WorkOrder } from "@/lib/types";
import type { Connector, ConnectorResult, SyncUnitsResult } from "./types";

const BASE_URL = "https://api.buildium.com/v1";

function headers(config: Record<string, string>) {
  return {
    "x-buildium-client-id": config.clientId ?? "",
    "x-buildium-client-secret": config.clientSecret ?? "",
    "Content-Type": "application/json",
  };
}

type BuildiumUnit = {
  Id: number;
  UnitNumber: string;
  UnitSize: number | null;
  UnitBedrooms: string | null;
  UnitBathrooms: string | null;
};

// Buildium represents bedroom/bathroom counts as enum-like strings
// (e.g. "Studio", "OneBed", "TwoBath"). This maps the common cases to numbers.
function parseBedrooms(value: string | null): number | null {
  if (!value) return null;
  if (value === "Studio") return 0;
  const match = value.match(/^(\w+)Bed/);
  const words: Record<string, number> = {
    One: 1, Two: 2, Three: 3, Four: 4, Five: 5, Six: 6, Seven: 7, Eight: 8, Nine: 9,
  };
  return match ? words[match[1]] ?? null : null;
}

function parseBathrooms(value: string | null): number | null {
  if (!value) return null;
  const match = value.match(/^(\w+?)(Half)?Bath/);
  const words: Record<string, number> = {
    One: 1, Two: 2, Three: 3, Four: 4, Five: 5, Six: 6, Seven: 7, Eight: 8, Nine: 9,
  };
  if (!match) return null;
  const whole = words[match[1]] ?? 0;
  return match[2] ? whole + 0.5 : whole;
}

async function testConnection(config: Record<string, string>): Promise<ConnectorResult> {
  if (!config.clientId || !config.clientSecret) {
    return { ok: false, error: "Client ID and client secret are required." };
  }

  try {
    const res = await fetch(`${BASE_URL}/rentals/properties?limit=1`, {
      headers: headers(config),
    });
    if (!res.ok) {
      return { ok: false, error: `Buildium returned ${res.status}: ${await res.text()}` };
    }
    return { ok: true };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : "Connection failed." };
  }
}

async function syncUnits(
  accountId: string,
  propertyId: string,
  config: Record<string, string>
): Promise<SyncUnitsResult> {
  const supabase = createServiceClient();

  // Resolve the Buildium property id from the connected property's metadata.
  const { data: property, error: propertyError } = await supabase
    .from("properties")
    .select("id, account_id")
    .eq("id", propertyId)
    .eq("account_id", accountId)
    .maybeSingle();

  if (propertyError) return { ok: false, error: propertyError.message };
  if (!property) return { ok: false, error: "Property not found." };

  const buildiumPropertyId = config[`buildiumPropertyId:${propertyId}`];
  if (!buildiumPropertyId) {
    return {
      ok: false,
      error: "No Buildium property mapping configured for this property.",
    };
  }

  let units: BuildiumUnit[];
  try {
    const res = await fetch(
      `${BASE_URL}/rentals/units?propertyids=${encodeURIComponent(buildiumPropertyId)}&limit=1000`,
      { headers: headers(config) }
    );
    if (!res.ok) {
      return { ok: false, error: `Buildium returned ${res.status}: ${await res.text()}` };
    }
    units = await res.json();
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : "Sync failed." };
  }

  let created = 0;
  let updated = 0;

  for (const unit of units) {
    const unitNumber = unit.UnitNumber ?? String(unit.Id);

    const { data: existing, error: existingError } = await supabase
      .from("units")
      .select("id")
      .eq("account_id", accountId)
      .eq("property_id", propertyId)
      .eq("unit_number", unitNumber)
      .is("deleted_at", null)
      .maybeSingle();

    if (existingError) return { ok: false, error: existingError.message };

    const fields = {
      sqft: unit.UnitSize,
      bedrooms: parseBedrooms(unit.UnitBedrooms),
      bathrooms: parseBathrooms(unit.UnitBathrooms),
    };

    if (existing) {
      const { error } = await supabase.from("units").update(fields).eq("id", existing.id);
      if (error) return { ok: false, error: error.message };
      updated += 1;
    } else {
      const { error } = await supabase.from("units").insert({
        id: randomUUID(),
        account_id: accountId,
        property_id: propertyId,
        unit_number: unitNumber,
        lease_status: "vacant",
        turn_status: "ready",
        notes: "",
        ...fields,
      });
      if (error) return { ok: false, error: error.message };
      created += 1;
    }
  }

  return { ok: true, created, updated };
}

async function pushWorkOrder(
  workOrder: WorkOrder,
  config: Record<string, string>
): Promise<ConnectorResult> {
  const buildiumPropertyId = workOrder.property_id
    ? config[`buildiumPropertyId:${workOrder.property_id}`]
    : undefined;

  if (!buildiumPropertyId) {
    return {
      ok: false,
      error: "No Buildium property mapping configured for this work order's property.",
    };
  }

  try {
    const res = await fetch(`${BASE_URL}/tasks/todorequests`, {
      method: "POST",
      headers: headers(config),
      body: JSON.stringify({
        PropertyId: Number(buildiumPropertyId),
        Title: workOrder.title,
        Description: workOrder.description,
        Priority: workOrder.priority === "urgent" ? "High" : workOrder.priority === "low" ? "Low" : "Normal",
      }),
    });

    if (!res.ok) {
      return { ok: false, error: `Buildium returned ${res.status}: ${await res.text()}` };
    }
    return { ok: true };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : "Push failed." };
  }
}

export const buildiumConnector: Connector = {
  provider: "buildium",
  displayName: "Buildium",
  available: true,
  configFields: [
    { key: "clientId", label: "Client ID", type: "text" },
    { key: "clientSecret", label: "Client Secret", type: "password" },
  ],
  testConnection,
  syncUnits,
  pushWorkOrder,
};
