import Link from "next/link";
import { getAccount, getAssetsWithLocation, getBuildings, getOpenWorkOrders, getOverdueMaintenanceSchedules, getPortfolioVacancySummary, getProperties } from "@/lib/data";
import { WORK_ORDER_PRIORITY_LABELS } from "@/lib/types";

export const dynamic = "force-dynamic";

const fmt = (n: number) =>
  n.toLocaleString("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });

export default async function DashboardPage() {
  const [assets, properties, account] = await Promise.all([
    getAssetsWithLocation(),
    getProperties(),
    getAccount(),
  ]);
  const isPM = account?.product_mode === "property_manager";

  // For PM mode, fetch building counts per property in parallel
  const buildingCountMap = new Map<string, number>();
  let openWorkOrders: Awaited<ReturnType<typeof getOpenWorkOrders>> = [];
  let overdueMaintenance: Awaited<ReturnType<typeof getOverdueMaintenanceSchedules>> = [];
  let vacancy: Awaited<ReturnType<typeof getPortfolioVacancySummary>> = { total: 0, vacant: 0, occupied: 0, notice: 0 };
  if (isPM && properties.length > 0) {
    const [buildingArrays, openWO, overdueMS, vacancySummary] = await Promise.all([
      Promise.all(properties.map((p) => getBuildings(p.id))),
      getOpenWorkOrders(),
      getOverdueMaintenanceSchedules(),
      getPortfolioVacancySummary(),
    ]);
    properties.forEach((p, i) => buildingCountMap.set(p.id, buildingArrays[i].length));
    openWorkOrders = openWO;
    overdueMaintenance = overdueMS;
    vacancy = vacancySummary;
  }
  const propertyNameById = new Map(properties.map((p) => [p.id, p.name]));
  const totalValue = assets.reduce((s, a) => s + (a.estimated_value ?? 0) * (a.quantity ?? 1), 0);
  const activeListings = assets.filter(
    (a) => a.listing_status === "ready" || a.listing_status === "listed" || a.listing_status === "pending"
  ).length;
  const sold = assets.filter((a) => a.listing_status === "sold");
  const soldValue = sold.reduce((s, a) => s + (a.sold_price ?? 0), 0);

  // Group item counts per property name for the property list.
  const countByProperty = new Map<string, number>();
  for (const a of assets) {
    const key = a.property_name ?? "Unassigned";
    countByProperty.set(key, (countByProperty.get(key) ?? 0) + 1);
  }

  // Property managers care about operational health across the portfolio;
  // homeowners about resale. Same underlying data, different lens.
  const stats = isPM
    ? [
        { label: "Properties", value: properties.length.toLocaleString() },
        { label: "Vacant units", value: `${vacancy.vacant} / ${vacancy.total}` },
        { label: "Open work orders", value: openWorkOrders.length.toLocaleString() },
        { label: "Overdue maintenance", value: overdueMaintenance.length.toLocaleString() },
      ]
    : [
        { label: "Items", value: assets.length.toLocaleString() },
        { label: "Estimated value", value: fmt(totalValue) },
        { label: "Active listings", value: activeListings.toLocaleString() },
        { label: "Sold", value: `${sold.length} · ${fmt(soldValue)}` },
      ];

  return (
    <div className="space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{isPM ? "Portfolio" : "Overview"}</h1>
          <p className="text-slate-500">
            {isPM
              ? "Your properties and everything in them, at a glance."
              : "Everything you've collected, at a glance."}
          </p>
        </div>
        <Link href="/dashboard/items" className="btn-primary">
          {isPM ? "Manage inventory" : "Manage items"}
        </Link>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        {stats.map((s) => (
          <div key={s.label} className="card p-4">
            <div className="text-sm text-slate-500">{s.label}</div>
            <div className="mt-1 text-2xl font-bold text-slate-900">{s.value}</div>
          </div>
        ))}
      </div>

      {isPM && (openWorkOrders.length > 0 || overdueMaintenance.length > 0) && (
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="card">
            <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">
              Open Work Orders ({openWorkOrders.length})
            </div>
            {openWorkOrders.length === 0 ? (
              <div className="px-5 py-6 text-center text-slate-500">Nothing open across your portfolio.</div>
            ) : (
              <ul className="divide-y divide-slate-100">
                {openWorkOrders.slice(0, 5).map((wo) => (
                  <li key={wo.id}>
                    <Link
                      href={`/dashboard/portfolio/${wo.property_id}/work-orders/${wo.id}`}
                      className="flex items-center justify-between px-5 py-4 hover:bg-slate-50"
                    >
                      <div>
                        <div className="font-medium text-slate-900">{wo.title}</div>
                        <div className="text-sm text-slate-500">{propertyNameById.get(wo.property_id) ?? "Unknown property"}</div>
                      </div>
                      <span className="rounded-full bg-orange-100 px-2 py-0.5 text-xs font-medium text-orange-700">
                        {WORK_ORDER_PRIORITY_LABELS[wo.priority]}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="card">
            <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">
              Overdue Maintenance ({overdueMaintenance.length})
            </div>
            {overdueMaintenance.length === 0 ? (
              <div className="px-5 py-6 text-center text-slate-500">Nothing overdue across your portfolio.</div>
            ) : (
              <ul className="divide-y divide-slate-100">
                {overdueMaintenance.slice(0, 5).map((schedule) => (
                  <li key={schedule.id}>
                    <Link
                      href={`/dashboard/portfolio/${schedule.property_id}/maintenance-schedules/${schedule.id}`}
                      className="flex items-center justify-between px-5 py-4 hover:bg-slate-50"
                    >
                      <div>
                        <div className="font-medium text-slate-900">{schedule.title}</div>
                        <div className="text-sm text-slate-500">{propertyNameById.get(schedule.property_id) ?? "Unknown property"}</div>
                      </div>
                      <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-700">
                        Due {new Date(schedule.next_due_date).toLocaleDateString()}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      )}

      {assets.length === 0 ? (
        <div className="card p-10 text-center">
          <div className="text-4xl">📦</div>
          <h2 className="mt-3 text-lg font-semibold text-slate-900">No items yet</h2>
          <p className="mx-auto mt-1 max-w-md text-slate-500">
            Scan a room with the iOS app to start your inventory — it&apos;ll sync here automatically. Or import a
            backup.
          </p>
          <div className="mt-5 flex justify-center gap-3">
            <Link href="/download" className="btn-primary">
              Get the app
            </Link>
            <Link href="/dashboard/export" className="btn-ghost">
              Import a backup
            </Link>
          </div>
        </div>
      ) : (
        <div className="card">
          <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">Properties</div>
          <ul className="divide-y divide-slate-100">
            {properties.length === 0 && (
              <li className="px-5 py-4 text-slate-500">No properties found.</li>
            )}
            {properties.map((p) => (
              <li key={p.id} className="flex items-center justify-between px-5 py-4">
                {isPM ? (
                  <Link
                    href={`/dashboard/portfolio/${p.id}`}
                    className="flex w-full items-center justify-between hover:opacity-75"
                  >
                    <div>
                      <div className="font-medium text-slate-900">{p.name}</div>
                      {p.address && <div className="text-sm text-slate-500">{p.address}</div>}
                    </div>
                    <div className="text-right text-sm text-slate-500">
                      {buildingCountMap.get(p.id) ?? 0} building{buildingCountMap.get(p.id) !== 1 ? "s" : ""}
                    </div>
                  </Link>
                ) : (
                  <>
                    <div>
                      <div className="font-medium text-slate-900">{p.name}</div>
                      {p.address && <div className="text-sm text-slate-500">{p.address}</div>}
                    </div>
                    <div className="text-sm text-slate-500">{countByProperty.get(p.name) ?? 0} items</div>
                  </>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
