import { notFound } from "next/navigation";
import {
  getAccount, getBuildings, getInspection, getInspectionDiff,
  getProperties, getUnits,
} from "@/lib/data";
import { INSPECTION_TYPE_LABELS } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function DepositReportPage({
  params,
}: {
  params: {
    propertyId: string;
    buildingId: string;
    unitId: string;
    inspectionId: string;
  };
}) {
  const [property_list, buildings, units, inspection, account] = await Promise.all([
    getProperties(),
    getBuildings(params.propertyId),
    getUnits({ buildingId: params.buildingId }),
    getInspection(params.inspectionId),
    getAccount(),
  ]);

  if (account?.product_mode !== "property_manager" || !inspection) notFound();
  if (inspection.status !== "completed" || inspection.inspection_type !== "move_out") notFound();

  const property = property_list.find((p) => p.id === params.propertyId);
  const building = buildings.find((b) => b.id === params.buildingId);
  const unit     = units.find((u) => u.id === params.unitId);
  if (!property || !building || !unit) notFound();

  const diff = await getInspectionDiff(inspection.id);
  const allItems = diff.rooms.flatMap((r) =>
    r.items.filter((i) => i.isDamaged || i.isMissing).map((i) => ({ ...i, roomName: r.roomName }))
  );
  const moveInInspection = inspection.baseline_inspection_id
    ? await getInspection(inspection.baseline_inspection_id)
    : null;

  const today = new Date().toLocaleDateString("en-US", { dateStyle: "long" });

  return (
    <div className="min-h-screen bg-white">
      {/* Print button — hidden when printing */}
      <div className="print:hidden sticky top-0 z-10 flex items-center justify-between border-b border-slate-200 bg-white px-6 py-3">
        <span className="text-sm text-slate-600">Deposit deduction report — print or save as PDF</span>
        <button
          onClick={undefined}
          className="btn-primary"
          // Use browser print via inline script
        >
          <span onClick={() => window.print()}>Print / Save PDF</span>
        </button>
      </div>

      <div className="mx-auto max-w-3xl px-8 py-10 print:px-6 print:py-0">
        {/* Header */}
        <div className="mb-8 border-b pb-6">
          <h1 className="text-2xl font-bold text-slate-900">Security Deposit Deduction Statement</h1>
          <p className="mt-1 text-slate-500">{today}</p>
        </div>

        {/* Property + Unit info */}
        <div className="mb-8 grid grid-cols-2 gap-6">
          <div>
            <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Property</h2>
            <p className="font-medium text-slate-900">{property.name}</p>
            {property.address && <p className="text-sm text-slate-600">{property.address}</p>}
            <p className="text-sm text-slate-600">{building.name}, Unit {unit.unit_number}</p>
          </div>
          <div>
            <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Tenant</h2>
            <p className="font-medium text-slate-900">{unit.current_tenant_name ?? "—"}</p>
            {unit.lease_start && <p className="text-sm text-slate-600">Lease: {unit.lease_start} – {unit.lease_end ?? "present"}</p>}
          </div>
          <div>
            <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Move-In Inspection</h2>
            <p className="text-sm text-slate-600">
              {moveInInspection
                ? new Date(moveInInspection.created_at).toLocaleDateString("en-US", { dateStyle: "long" })
                : "—"}
            </p>
          </div>
          <div>
            <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Move-Out Inspection</h2>
            <p className="text-sm text-slate-600">
              {inspection.completed_at
                ? new Date(inspection.completed_at).toLocaleDateString("en-US", { dateStyle: "long" })
                : today}
            </p>
          </div>
        </div>

        {/* Deductions table */}
        <h2 className="mb-3 text-lg font-semibold text-slate-900">Deductions</h2>
        {allItems.length === 0 ? (
          <p className="rounded bg-slate-50 p-4 text-slate-600">
            No damage or missing items flagged by the AI inspection.
          </p>
        ) : (
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr className="border-b-2 border-slate-900 text-left">
                <th className="pb-2 font-semibold text-slate-900">Room</th>
                <th className="pb-2 font-semibold text-slate-900">Item</th>
                <th className="pb-2 font-semibold text-slate-900">Issue</th>
                <th className="pb-2 font-semibold text-slate-900">Move-In</th>
                <th className="pb-2 font-semibold text-slate-900">Move-Out</th>
                <th className="pb-2 text-right font-semibold text-slate-900">Charge ($)</th>
              </tr>
            </thead>
            <tbody>
              {allItems.map((item, i) => (
                <tr key={i} className="border-b border-slate-200">
                  <td className="py-2 pr-3 text-slate-600">{item.roomName}</td>
                  <td className="py-2 pr-3 font-medium text-slate-900">{item.name}</td>
                  <td className="py-2 pr-3">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        item.isMissing ? "bg-red-100 text-red-700" : "bg-amber-100 text-amber-700"
                      }`}
                    >
                      {item.isMissing ? "Missing" : "Damaged"}
                    </span>
                  </td>
                  <td className="py-2 pr-3 text-slate-600">{item.moveInCondition ?? "—"}</td>
                  <td className="py-2 pr-3 text-slate-600">{item.moveOutCondition ?? "—"}</td>
                  {/* Charge cell is blank — PM fills in manually or prints and writes */}
                  <td className="py-2 text-right">
                    <span className="inline-block w-20 border-b border-slate-400 text-slate-300">___</span>
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="border-t-2 border-slate-900">
                <td colSpan={5} className="pt-3 font-semibold text-slate-900">Total deductions</td>
                <td className="pt-3 text-right">
                  <span className="inline-block w-20 border-b border-slate-900 text-slate-300">___</span>
                </td>
              </tr>
            </tfoot>
          </table>
        )}

        {/* Signature block */}
        <div className="mt-12 grid grid-cols-2 gap-8">
          <div>
            <div className="mb-6 border-b border-slate-400" />
            <p className="text-sm text-slate-600">Property Manager Signature</p>
            <p className="mt-1 text-xs text-slate-400">Date: _______________</p>
          </div>
          <div>
            <div className="mb-6 border-b border-slate-400" />
            <p className="text-sm text-slate-600">Tenant Signature</p>
            <p className="mt-1 text-xs text-slate-400">Date: _______________</p>
          </div>
        </div>

        {/* Footer */}
        <p className="mt-10 text-center text-xs text-slate-400 print:mt-6">
          Generated by Collect · AI-assisted condition documentation · {today}
        </p>
      </div>
    </div>
  );
}
