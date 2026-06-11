import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getProperties, getWorkOrder } from "@/lib/data";
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
  const [properties, workOrder, account] = await Promise.all([
    getProperties(),
    getWorkOrder(params.workOrderId),
    getAccount(),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property = properties.find((p) => p.id === params.propertyId);
  if (!property || !workOrder || workOrder.property_id !== property.id) notFound();

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
          {workOrder.due_date && (
            <InfoItem label="Due" value={formatDateOnly(workOrder.due_date)} />
          )}
          {workOrder.completed_at && (
            <InfoItem label="Completed" value={new Date(workOrder.completed_at).toLocaleDateString()} />
          )}
        </dl>

        <StatusSelect workOrderId={workOrder.id} propertyId={property.id} status={workOrder.status} />

        <EditWorkOrderForm workOrder={workOrder} propertyId={property.id} />
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
