import { getAdminAccounts } from "@/lib/data";

export const dynamic = "force-dynamic";

const fmtDate = (iso: string) =>
  new Date(iso).toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });

export default async function AdminAccountsPage() {
  const accounts = await getAdminAccounts();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Accounts</h1>
        <p className="text-slate-500">{accounts.length.toLocaleString()} accounts across the platform.</p>
      </div>

      <div className="card overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-100 text-sm">
          <thead>
            <tr className="text-left text-slate-500">
              <th className="px-5 py-3 font-medium">Account</th>
              <th className="px-5 py-3 font-medium">Owner</th>
              <th className="px-5 py-3 font-medium">Mode</th>
              <th className="px-5 py-3 font-medium">Plan</th>
              <th className="px-5 py-3 font-medium">Members</th>
              <th className="px-5 py-3 font-medium">Properties</th>
              <th className="px-5 py-3 font-medium">Items</th>
              <th className="px-5 py-3 font-medium">Created</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {accounts.length === 0 && (
              <tr>
                <td colSpan={8} className="px-5 py-6 text-center text-slate-500">
                  No accounts found.
                </td>
              </tr>
            )}
            {accounts.map((a) => (
              <tr key={a.id}>
                <td className="px-5 py-3 font-medium text-slate-900">
                  {a.name}
                  {a.is_personal && (
                    <span className="ml-2 rounded-full bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-500">
                      personal
                    </span>
                  )}
                </td>
                <td className="px-5 py-3 text-slate-600">{a.owner_email ?? "—"}</td>
                <td className="px-5 py-3 text-slate-600">
                  {a.product_mode === "property_manager" ? "Property manager" : "Homeowner"}
                </td>
                <td className="px-5 py-3">
                  <span className="rounded-full bg-brand-100 px-2 py-0.5 text-xs font-semibold uppercase text-brand-700">
                    {a.plan}
                  </span>
                </td>
                <td className="px-5 py-3 text-slate-600">{a.member_count.toLocaleString()}</td>
                <td className="px-5 py-3 text-slate-600">{a.property_count.toLocaleString()}</td>
                <td className="px-5 py-3 text-slate-600">{a.asset_count.toLocaleString()}</td>
                <td className="px-5 py-3 text-slate-600">{fmtDate(a.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
