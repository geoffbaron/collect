import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getMaintenanceSchedule, getProperties } from "@/lib/data";
import {
  MAINTENANCE_FREQUENCY_LABELS,
  WORK_ORDER_CATEGORY_LABELS,
} from "@/lib/types";
import { formatDateOnly } from "@/lib/dates";
import ActiveToggle from "./ActiveToggle";
import EditMaintenanceScheduleForm from "./EditMaintenanceScheduleForm";

export const dynamic = "force-dynamic";

export default async function MaintenanceScheduleDetailPage({
  params,
}: {
  params: { propertyId: string; maintenanceScheduleId: string };
}) {
  const [properties, schedule, account] = await Promise.all([
    getProperties(),
    getMaintenanceSchedule(params.maintenanceScheduleId),
    getAccount(),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property = properties.find((p) => p.id === params.propertyId);
  if (!property || !schedule || schedule.property_id !== property.id) notFound();

  return (
    <div className="space-y-6">
      <div>
        <div className="text-sm text-slate-500">
          <Link href="/dashboard" className="hover:underline">Portfolio</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}`} className="hover:underline">{property.name}</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}/maintenance-schedules`} className="hover:underline">Maintenance Schedules</Link>
          <span className="mx-1">›</span>
          <span className="text-slate-900">{schedule.title}</span>
        </div>
        <h1 className="mt-1 text-2xl font-bold text-slate-900">{schedule.title}</h1>
      </div>

      <div className="card p-5 space-y-4">
        {schedule.description && (
          <p className="text-slate-700">{schedule.description}</p>
        )}

        <dl className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <InfoItem label="Category" value={WORK_ORDER_CATEGORY_LABELS[schedule.category]} />
          <InfoItem label="Frequency" value={MAINTENANCE_FREQUENCY_LABELS[schedule.frequency]} />
          <InfoItem label="Next Due" value={formatDateOnly(schedule.next_due_date)} />
          {schedule.last_completed_at && (
            <InfoItem label="Last Completed" value={formatDateOnly(schedule.last_completed_at)} />
          )}
        </dl>

        <ActiveToggle scheduleId={schedule.id} propertyId={property.id} active={schedule.active} />

        <EditMaintenanceScheduleForm schedule={schedule} propertyId={property.id} />
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
