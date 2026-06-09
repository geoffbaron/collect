import Link from "next/link";
import { getAccount, getAssetsWithLocation, getProperties } from "@/lib/data";

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

  const totalValue = assets.reduce((s, a) => s + (a.estimated_value ?? 0) * (a.quantity ?? 1), 0);
  const activeListings = assets.filter(
    (a) => a.listing_status === "ready" || a.listing_status === "listed" || a.listing_status === "pending"
  ).length;
  const sold = assets.filter((a) => a.listing_status === "sold");
  const soldValue = sold.reduce((s, a) => s + (a.sold_price ?? 0), 0);
  const confirmed = assets.filter((a) => a.is_confirmed).length;

  // Group item counts per property name for the property list.
  const countByProperty = new Map<string, number>();
  for (const a of assets) {
    const key = a.property_name ?? "Unassigned";
    countByProperty.set(key, (countByProperty.get(key) ?? 0) + 1);
  }

  // Property managers care about coverage across the portfolio; homeowners
  // about resale. Same underlying data, different lens.
  const stats = isPM
    ? [
        { label: "Items", value: assets.length.toLocaleString() },
        { label: "Estimated value", value: fmt(totalValue) },
        { label: "Properties", value: properties.length.toLocaleString() },
        { label: "Confirmed", value: confirmed.toLocaleString() },
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
                <div>
                  <div className="font-medium text-slate-900">{p.name}</div>
                  {p.address && <div className="text-sm text-slate-500">{p.address}</div>}
                </div>
                <div className="text-sm text-slate-500">{countByProperty.get(p.name) ?? 0} items</div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
