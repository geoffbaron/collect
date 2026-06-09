import { getAdminStats } from "@/lib/data";

export const dynamic = "force-dynamic";

export default async function AdminOverviewPage() {
  const stats = await getAdminStats();

  if (!stats) {
    return (
      <div className="card p-6">
        <p className="text-slate-500">Couldn&apos;t load platform stats.</p>
      </div>
    );
  }

  const topStats = [
    { label: "Total accounts", value: stats.total_accounts },
    { label: "Total users", value: stats.total_users },
    { label: "Properties", value: stats.total_properties },
    { label: "Items", value: stats.total_assets },
  ];

  const signupStats = [
    { label: "Signups (7 days)", value: stats.signups_last_7_days },
    { label: "Signups (30 days)", value: stats.signups_last_30_days },
  ];

  const breakdownStats = [
    { label: "Homeowner accounts", value: stats.homeowner_accounts },
    { label: "Property manager accounts", value: stats.property_mgr_accounts },
    { label: "Free plan", value: stats.free_accounts },
    { label: "Pro plan", value: stats.pro_accounts },
    { label: "Enterprise plan", value: stats.enterprise_accounts },
  ];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Platform overview</h1>
        <p className="text-slate-500">Headline numbers across every account.</p>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        {topStats.map((s) => (
          <div key={s.label} className="card p-4">
            <div className="text-sm text-slate-500">{s.label}</div>
            <div className="mt-1 text-2xl font-bold text-slate-900">{s.value.toLocaleString()}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-2">
        {signupStats.map((s) => (
          <div key={s.label} className="card p-4">
            <div className="text-sm text-slate-500">{s.label}</div>
            <div className="mt-1 text-2xl font-bold text-slate-900">{s.value.toLocaleString()}</div>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">Account breakdown</div>
        <ul className="divide-y divide-slate-100">
          {breakdownStats.map((s) => (
            <li key={s.label} className="flex items-center justify-between px-5 py-3">
              <span className="text-slate-600">{s.label}</span>
              <span className="font-semibold text-slate-900">{s.value.toLocaleString()}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
