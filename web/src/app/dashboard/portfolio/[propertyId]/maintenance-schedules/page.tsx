import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getMaintenanceSchedules, getProperties } from "@/lib/data";
import {
  MAINTENANCE_FREQUENCY_LABELS,
  WORK_ORDER_CATEGORY_LABELS,
} from "@/lib/types";
import NewMaintenanceScheduleForm from "./NewMaintenanceScheduleForm";

export const dynamic = "force-dynamic";

export default async function PropertyMaintenanceSchedulesPage({
  params,
}: {
  params: { propertyId: string };
}) {
  const [properties, schedules, account] = await Promise.all([
    getProperties(),
    getMaintenanceSchedules({ propertyId: params.propertyId }),
    getAccount(),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property = properties.find((p) => p.id === params.propertyId);
  if (!property) notFound();

  const today = new Date().toISOString().slice(0, 10);

  return (
    <div className="space-y-6">
      <div>
        <div className="text-sm text-slate-500">
          <Link href="/dashboard" className="hover:underline">Portfolio</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}`} className="hover:underline">{property.name}</Link>
          <span className="mx-1">›</span>
          <span className="text-slate-900">Maintenance Schedules</span>
        </div>
        <h1 className="mt-1 text-2xl font-bold text-slate-900">Maintenance Schedules</h1>
      </div>

      <div className="card">
        <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">
          {schedules.length} schedule{schedules.length !== 1 ? "s" : ""}
        </div>
        {schedules.length === 0 ? (
          <div className="px-5 py-6 text-center text-slate-500">No maintenance schedules yet.</div>
        ) : (
          <ul className="divide-y divide-slate-100">
            {schedules.map((schedule) => {
              const overdue = schedule.active && schedule.next_due_date < today;
              return (
                <li key={schedule.id}>
                  <Link
                    href={`/dashboard/portfolio/${property.id}/maintenance-schedules/${schedule.id}`}
                    className="flex items-center justify-between px-5 py-4 hover:bg-slate-50"
                  >
                    <div>
                      <div className="font-medium text-slate-900">{schedule.title}</div>
                      <div className="text-sm text-slate-500">
                        {WORK_ORDER_CATEGORY_LABELS[schedule.category]} · {MAINTENANCE_FREQUENCY_LABELS[schedule.frequency]}
                        {!schedule.active && " · Inactive"}
                      </div>
                    </div>
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${overdue ? "bg-red-100 text-red-700" : "bg-slate-100 text-slate-700"}`}>
                      Due {new Date(schedule.next_due_date).toLocaleDateString()}
                    </span>
                  </Link>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <NewMaintenanceScheduleForm propertyId={property.id} />
    </div>
  );
}
