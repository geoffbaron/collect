import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getBuildings, getInspections, getProperties, getUnits, getWorkOrders } from "@/lib/data";
import { INSPECTION_STATUS_LABELS, INSPECTION_TYPE_LABELS, LEASE_STATUS_LABELS, TURN_STATUS_LABELS, WORK_ORDER_CATEGORY_LABELS, WORK_ORDER_STATUS_LABELS } from "@/lib/types";
import StartInspectionForm from "./StartInspectionForm";

export const dynamic = "force-dynamic";

export default async function UnitDetailPage({
  params,
}: {
  params: { propertyId: string; buildingId: string; unitId: string };
}) {
  const [properties, buildings, units, inspections, workOrders, account] = await Promise.all([
    getProperties(),
    getBuildings(params.propertyId),
    getUnits({ buildingId: params.buildingId }),
    getInspections(params.unitId),
    getWorkOrders({ propertyId: params.propertyId, unitId: params.unitId }),
    getAccount(),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property  = properties.find((p) => p.id === params.propertyId);
  const building  = buildings.find((b) => b.id === params.buildingId);
  const unit      = units.find((u) => u.id === params.unitId);
  if (!property || !building || !unit) notFound();

  const lastMoveIn = inspections.find(
    (i) => i.inspection_type === "move_in" && i.status === "completed"
  );

  return (
    <div className="space-y-6">
      {/* Breadcrumb */}
      <div>
        <div className="text-sm text-slate-500">
          <Link href="/dashboard" className="hover:underline">Portfolio</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}`} className="hover:underline">{property.name}</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}/${building.id}`} className="hover:underline">{building.name}</Link>
          <span className="mx-1">›</span>
          <span className="text-slate-900">Unit {unit.unit_number}</span>
        </div>
        <h1 className="mt-1 text-2xl font-bold text-slate-900">Unit {unit.unit_number}</h1>
        {unit.current_tenant_name && (
          <p className="text-slate-500">{unit.current_tenant_name}</p>
        )}
      </div>

      {/* Unit info cards */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <InfoCard label="Lease"   value={LEASE_STATUS_LABELS[unit.lease_status]} />
        <InfoCard label="Turn"    value={TURN_STATUS_LABELS[unit.turn_status]} />
        {unit.bedrooms != null && <InfoCard label="Beds/Baths" value={`${unit.bedrooms}bd / ${unit.bathrooms ?? "?"}ba`} />}
        {unit.sqft     != null && <InfoCard label="Size"       value={`${unit.sqft.toLocaleString()} sqft`} />}
      </div>

      {/* Lease details */}
      {(unit.lease_start || unit.lease_end || unit.monthly_rent) && (
        <div className="card p-5">
          <h2 className="mb-3 font-semibold text-slate-900">Lease</h2>
          <dl className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {unit.lease_start && <InfoItem label="Start"  value={unit.lease_start} />}
            {unit.lease_end   && <InfoItem label="End"    value={unit.lease_end} />}
            {unit.monthly_rent != null && (
              <InfoItem
                label="Rent"
                value={unit.monthly_rent.toLocaleString("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 })}
              />
            )}
          </dl>
        </div>
      )}

      {/* Inspection history */}
      <div className="card">
        <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">Inspections</div>
        {inspections.length === 0 ? (
          <div className="px-5 py-6 text-center text-slate-500">No inspections yet.</div>
        ) : (
          <ul className="divide-y divide-slate-100">
            {inspections.map((insp) => (
              <li key={insp.id} className="flex items-center justify-between px-5 py-4">
                <Link
                  href={`/dashboard/portfolio/${property.id}/${building.id}/${unit.id}/${insp.id}`}
                  className="flex flex-1 items-center justify-between hover:opacity-75"
                >
                  <div>
                    <div className="font-medium text-slate-900">
                      {INSPECTION_TYPE_LABELS[insp.inspection_type]}
                    </div>
                    <div className="text-sm text-slate-500">
                      {new Date(insp.created_at).toLocaleDateString()}
                    </div>
                  </div>
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      insp.status === "completed"
                        ? "bg-green-100 text-green-700"
                        : insp.status === "in_progress"
                        ? "bg-blue-100 text-blue-700"
                        : "bg-slate-100 text-slate-600"
                    }`}
                  >
                    {INSPECTION_STATUS_LABELS[insp.status]}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Start inspection */}
      <StartInspectionForm
        unitId={unit.id}
        propertyId={property.id}
        buildingId={building.id}
        lastMoveInId={lastMoveIn?.id ?? null}
      />

      {/* Work orders */}
      <div className="card">
        <div className="flex items-center justify-between border-b border-slate-200 px-5 py-3">
          <span className="font-semibold text-slate-900">Work Orders</span>
          <Link href={`/dashboard/portfolio/${property.id}/work-orders`} className="text-sm text-brand hover:underline">
            View all
          </Link>
        </div>
        {workOrders.length === 0 ? (
          <div className="px-5 py-6 text-center text-slate-500">No work orders for this unit yet.</div>
        ) : (
          <ul className="divide-y divide-slate-100">
            {workOrders.map((wo) => (
              <li key={wo.id}>
                <Link
                  href={`/dashboard/portfolio/${property.id}/work-orders/${wo.id}`}
                  className="flex items-center justify-between px-5 py-4 hover:bg-slate-50"
                >
                  <div>
                    <div className="font-medium text-slate-900">{wo.title}</div>
                    <div className="text-sm text-slate-500">{WORK_ORDER_CATEGORY_LABELS[wo.category]}</div>
                  </div>
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      wo.status === "completed"
                        ? "bg-green-100 text-green-700"
                        : wo.status === "in_progress"
                        ? "bg-blue-100 text-blue-700"
                        : wo.status === "open"
                        ? "bg-orange-100 text-orange-700"
                        : "bg-slate-100 text-slate-600"
                    }`}
                  >
                    {WORK_ORDER_STATUS_LABELS[wo.status]}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

function InfoCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="card p-4">
      <div className="text-xs text-slate-500">{label}</div>
      <div className="mt-1 font-semibold text-slate-900">{value}</div>
    </div>
  );
}

function InfoItem({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-slate-500">{label}</dt>
      <dd className="mt-0.5 font-medium text-slate-900">{value}</dd>
    </div>
  );
}
