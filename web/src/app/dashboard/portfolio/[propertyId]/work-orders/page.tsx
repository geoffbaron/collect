import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getBuildings, getCommonAreas, getProperties, getUnits, getWorkOrders } from "@/lib/data";
import {
  WORK_ORDER_CATEGORY_LABELS,
  WORK_ORDER_PRIORITY_LABELS,
  WORK_ORDER_STATUS_LABELS,
} from "@/lib/types";
import { formatDateOnly } from "@/lib/dates";
import NewWorkOrderForm from "./NewWorkOrderForm";

export const dynamic = "force-dynamic";

const STATUS_STYLES: Record<string, string> = {
  open: "bg-orange-100 text-orange-700",
  in_progress: "bg-blue-100 text-blue-700",
  completed: "bg-green-100 text-green-700",
  cancelled: "bg-slate-100 text-slate-600",
};

export default async function PropertyWorkOrdersPage({
  params,
  searchParams,
}: {
  params: { propertyId: string };
  searchParams: { unitId?: string };
}) {
  const unitId = searchParams.unitId;
  const [properties, workOrders, account, buildings, units, commonAreas] = await Promise.all([
    getProperties(),
    getWorkOrders({ propertyId: params.propertyId, unitId }),
    getAccount(),
    getBuildings(params.propertyId),
    getUnits({ propertyId: params.propertyId }),
    getCommonAreas(params.propertyId),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property = properties.find((p) => p.id === params.propertyId);
  if (!property) notFound();

  const unit = unitId ? units.find((u) => u.id === unitId) : undefined;

  return (
    <div className="space-y-6">
      <div>
        <div className="text-sm text-slate-500">
          <Link href="/dashboard" className="hover:underline">Portfolio</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}`} className="hover:underline">{property.name}</Link>
          <span className="mx-1">›</span>
          <span className="text-slate-900">Work Orders</span>
        </div>
        <h1 className="mt-1 text-2xl font-bold text-slate-900">Work Orders</h1>
      </div>

      {unit && (
        <div className="flex items-center justify-between rounded-md bg-slate-100 px-4 py-2 text-sm text-slate-700">
          <span>Showing work orders for Unit {unit.unit_number}</span>
          <Link href={`/dashboard/portfolio/${property.id}/work-orders`} className="text-brand hover:underline">
            Clear filter
          </Link>
        </div>
      )}

      <div className="card">
        <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">
          {workOrders.length} ticket{workOrders.length !== 1 ? "s" : ""}
        </div>
        {workOrders.length === 0 ? (
          <div className="px-5 py-6 text-center text-slate-500">No work orders yet.</div>
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
                    <div className="text-sm text-slate-500">
                      {WORK_ORDER_CATEGORY_LABELS[wo.category]} · {WORK_ORDER_PRIORITY_LABELS[wo.priority]} priority
                      {wo.due_date && ` · Due ${formatDateOnly(wo.due_date)}`}
                    </div>
                  </div>
                  <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_STYLES[wo.status]}`}>
                    {WORK_ORDER_STATUS_LABELS[wo.status]}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </div>

      <NewWorkOrderForm propertyId={property.id} buildings={buildings} units={units} commonAreas={commonAreas} />
    </div>
  );
}
