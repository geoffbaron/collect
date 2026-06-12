import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getAccountMembers, getProperties, getUnits, getWorkOrder } from "@/lib/data";
import {
  WORK_ORDER_CATEGORY_LABELS,
  WORK_ORDER_PRIORITY_LABELS,
} from "@/lib/types";
import { formatDateOnly } from "@/lib/dates";
import StatusSelect from "./StatusSelect";
import EditWorkOrderForm from "./EditWorkOrderForm";

export const dynamic = "force-dynamic";

export default async function WorkOrderDetailPage({
  params,
}: {
  params: { propertyId: string; workOrderId: string };
}) {
  const [properties, workOrder, account, members] = await Promise.all([
    getProperties(),
    getWorkOrder(params.workOrderId),
    getAccount(),
    getAccountMembers(),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property = properties.find((p) => p.id === params.propertyId);
  if (!property || !workOrder || workOrder.property_id !== property.id) notFound();

  const assignee = workOrder.assigned_to
    ? members.find((m) => m.user_id === workOrder.assigned_to)
    : undefined;

  // Link back to the source inspection (path needs the unit's building).
  let inspectionHref: string | null = null;
  if (workOrder.source_inspection_id && workOrder.unit_id) {
    const units = await getUnits({ propertyId: property.id });
    const unit = units.find((u) => u.id === workOrder.unit_id);
    if (unit?.building_id) {
      inspectionHref = `/dashboard/portfolio/${property.id}/${unit.building_id}/${unit.id}/${workOrder.source_inspection_id}`;
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <div className="text-sm text-slate-500">
          <Link href="/dashboard" className="hover:underline">Portfolio</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}`} className="hover:underline">{property.name}</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}/work-orders`} className="hover:underline">Work Orders</Link>
          <span className="mx-1">›</span>
          <span className="text-slate-900">{workOrder.title}</span>
        </div>
        <h1 className="mt-1 text-2xl font-bold text-slate-900">{workOrder.title}</h1>
      </div>

      <div className="card p-5 space-y-4">
        {workOrder.description && (
          <p className="text-slate-700">{workOrder.description}</p>
        )}

        <dl className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <InfoItem label="Category" value={WORK_ORDER_CATEGORY_LABELS[workOrder.category]} />
          <InfoItem label="Priority" value={WORK_ORDER_PRIORITY_LABELS[workOrder.priority]} />
          <InfoItem
            label="Assigned To"
            value={workOrder.assigned_to ? assignee?.name || assignee?.email || "Unknown" : "Unassigned"}
          />
          {workOrder.due_date && (
            <InfoItem label="Due" value={formatDateOnly(workOrder.due_date)} />
          )}
          {workOrder.completed_at && (
            <InfoItem label="Completed" value={new Date(workOrder.completed_at).toLocaleDateString()} />
          )}
        </dl>

        {inspectionHref && (
          <Link href={inspectionHref} className="inline-block text-sm text-brand hover:underline">
            From inspection →
          </Link>
        )}

        <StatusSelect workOrderId={workOrder.id} propertyId={property.id} status={workOrder.status} />

        <EditWorkOrderForm workOrder={workOrder} propertyId={property.id} members={members} />
      </div>
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
