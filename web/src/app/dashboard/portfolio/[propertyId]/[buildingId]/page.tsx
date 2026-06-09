import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAccount, getBuildings, getProperties, getUnits } from "@/lib/data";
import { LEASE_STATUS_LABELS, TURN_STATUS_LABELS } from "@/lib/types";
import type { Unit } from "@/lib/types";
import UnitActions from "./UnitActions";

export const dynamic = "force-dynamic";

const LEASE_COLORS: Record<string, string> = {
  vacant:   "bg-slate-100 text-slate-600",
  occupied: "bg-green-100 text-green-700",
  notice:   "bg-amber-100 text-amber-700",
  eviction: "bg-red-100 text-red-700",
};

const TURN_COLORS: Record<string, string> = {
  clean:       "bg-green-100 text-green-700",
  needs_turn:  "bg-amber-100 text-amber-700",
  in_progress: "bg-blue-100 text-blue-700",
  turned:      "bg-green-100 text-green-700",
};

export default async function BuildingDetailPage({
  params,
}: {
  params: { propertyId: string; buildingId: string };
}) {
  const [properties, buildings, units, account] = await Promise.all([
    getProperties(),
    getBuildings(params.propertyId),
    getUnits({ buildingId: params.buildingId }),
    getAccount(),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property = properties.find((p) => p.id === params.propertyId);
  const building = buildings.find((b) => b.id === params.buildingId);
  if (!property || !building) notFound();

  const vacant   = units.filter((u) => u.lease_status === "vacant").length;
  const occupied = units.filter((u) => u.lease_status === "occupied").length;
  const notice   = units.filter((u) => u.lease_status === "notice").length;
  const needsTurn = units.filter((u) =>
    u.turn_status === "needs_turn" || u.turn_status === "in_progress"
  ).length;

  return (
    <div className="space-y-6">
      {/* Breadcrumb + header */}
      <div>
        <div className="text-sm text-slate-500">
          <Link href="/dashboard" className="hover:underline">Portfolio</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}`} className="hover:underline">{property.name}</Link>
          <span className="mx-1">›</span>
          <span className="text-slate-900">{building.name}</span>
        </div>
        <h1 className="mt-1 text-2xl font-bold text-slate-900">{building.name}</h1>
        {building.address && <p className="text-slate-500">{building.address}</p>}
      </div>

      {/* Summary chips */}
      {units.length > 0 && (
        <div className="flex flex-wrap gap-2">
          <span className="rounded-full bg-slate-100 px-3 py-1 text-sm font-medium text-slate-700">
            {units.length} units
          </span>
          <span className="rounded-full bg-slate-100 px-3 py-1 text-sm font-medium text-slate-700">
            {vacant} vacant
          </span>
          <span className="rounded-full bg-green-100 px-3 py-1 text-sm font-medium text-green-700">
            {occupied} occupied
          </span>
          {notice > 0 && (
            <span className="rounded-full bg-amber-100 px-3 py-1 text-sm font-medium text-amber-700">
              {notice} notice
            </span>
          )}
          {needsTurn > 0 && (
            <span className="rounded-full bg-blue-100 px-3 py-1 text-sm font-medium text-blue-700">
              {needsTurn} need turn
            </span>
          )}
        </div>
      )}

      {/* Units grid */}
      <div className="card">
        <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">Units</div>
        {units.length === 0 ? (
          <div className="px-5 py-8 text-center text-slate-500">
            No units yet. Add one below or import from CSV.
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-px bg-slate-100 sm:grid-cols-2 lg:grid-cols-3">
            {units.map((unit) => (
              <UnitCard
                key={unit.id}
                unit={unit}
                propertyId={property.id}
                buildingId={building.id}
              />
            ))}
          </div>
        )}
      </div>

      {/* Add unit + CSV import */}
      <UnitActions
        propertyId={property.id}
        buildingId={building.id}
      />
    </div>
  );
}

function UnitCard({
  unit,
  propertyId,
  buildingId,
}: {
  unit: Unit;
  propertyId: string;
  buildingId: string;
}) {
  return (
    <Link
      href={`/dashboard/portfolio/${propertyId}/${buildingId}/${unit.id}`}
      className="block bg-white p-4 hover:bg-slate-50"
    >
    <div className="flex items-start justify-between gap-2">
        <div>
          <div className="font-semibold text-slate-900">Unit {unit.unit_number}</div>
          {(unit.bedrooms != null || unit.bathrooms != null || unit.sqft != null) && (
            <div className="text-sm text-slate-500">
              {[
                unit.bedrooms != null ? `${unit.bedrooms}bd` : null,
                unit.bathrooms != null ? `${unit.bathrooms}ba` : null,
                unit.sqft != null ? `${unit.sqft.toLocaleString()} sqft` : null,
              ]
                .filter(Boolean)
                .join(" · ")}
            </div>
          )}
        </div>
        <div className="flex flex-col items-end gap-1">
          <span
            className={`rounded-full px-2 py-0.5 text-xs font-medium ${LEASE_COLORS[unit.lease_status] ?? LEASE_COLORS.vacant}`}
          >
            {LEASE_STATUS_LABELS[unit.lease_status]}
          </span>
          {unit.turn_status !== "clean" && (
            <span
              className={`rounded-full px-2 py-0.5 text-xs font-medium ${TURN_COLORS[unit.turn_status] ?? TURN_COLORS.clean}`}
            >
              {TURN_STATUS_LABELS[unit.turn_status]}
            </span>
          )}
        </div>
      </div>
      {unit.current_tenant_name && (
        <div className="mt-1 text-xs text-slate-500 truncate">{unit.current_tenant_name}</div>
      )}
    </Link>
  );
}
