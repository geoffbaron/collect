import Link from "next/link";
import { notFound } from "next/navigation";
import {
  getAccount, getBuildings, getInspection, getInspectionDiff,
  getProperties, getUnits,
} from "@/lib/data";
import { completeInspection } from "@/lib/actions";
import { INSPECTION_TYPE_LABELS, INSPECTION_STATUS_LABELS } from "@/lib/types";
import CompleteButton from "./CompleteButton";
import CreateWorkOrderButton from "./CreateWorkOrderButton";

export const dynamic = "force-dynamic";

export default async function InspectionDetailPage({
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

  const property = property_list.find((p) => p.id === params.propertyId);
  const building = buildings.find((b) => b.id === params.buildingId);
  const unit     = units.find((u) => u.id === params.unitId);
  if (!property || !building || !unit) notFound();

  const isMoveOut = inspection.inspection_type === "move_out" && inspection.baseline_inspection_id;
  const diff = isMoveOut ? await getInspectionDiff(inspection.id) : null;
  const damagedCount = diff?.rooms.flatMap((r) => r.items).filter((i) => i.isDamaged || i.isMissing).length ?? 0;

  return (
    <div className="space-y-6">
      {/* Breadcrumb */}
      <div>
        <div className="text-sm text-slate-500">
          <Link href="/dashboard" className="hover:underline">Portfolio</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}`} className="hover:underline">{property.name}</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}/${building.id}`} className="hover:underline">{building.name}</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}/${building.id}/${unit.id}`} className="hover:underline">Unit {unit.unit_number}</Link>
          <span className="mx-1">›</span>
          <span className="text-slate-900">{INSPECTION_TYPE_LABELS[inspection.inspection_type]}</span>
        </div>
        <div className="mt-1 flex items-center gap-3">
          <h1 className="text-2xl font-bold text-slate-900">
            {INSPECTION_TYPE_LABELS[inspection.inspection_type]} Inspection
          </h1>
          <span
            className={`rounded-full px-2 py-0.5 text-xs font-medium ${
              inspection.status === "completed"
                ? "bg-green-100 text-green-700"
                : "bg-blue-100 text-blue-700"
            }`}
          >
            {INSPECTION_STATUS_LABELS[inspection.status]}
          </span>
        </div>
        <p className="text-slate-500">
          Unit {unit.unit_number} · {new Date(inspection.created_at).toLocaleDateString("en-US", { dateStyle: "long" })}
        </p>
      </div>

      {/* Action bar */}
      <div className="flex items-center gap-3">
        {inspection.status === "in_progress" && (
          <CompleteButton inspectionId={inspection.id} unitId={unit.id} />
        )}
        {inspection.status === "completed" && isMoveOut && (
          <Link
            href={`/dashboard/portfolio/${property.id}/${building.id}/${unit.id}/${inspection.id}/report`}
            className="btn-primary"
          >
            Generate Deposit Report
          </Link>
        )}
        {inspection.status === "in_progress" && (
          <p className="text-sm text-slate-500">
            Scan rooms with the iOS app, then mark complete to generate the report.
          </p>
        )}
      </div>

      {/* Diff (move_out with baseline) */}
      {isMoveOut && diff && (
        <div className="space-y-4">
          {damagedCount > 0 && (
            <div className="rounded-lg bg-amber-50 p-4 text-amber-800">
              <strong>{damagedCount} item{damagedCount !== 1 ? "s" : ""}</strong> flagged as damaged or missing vs. move-in.
            </div>
          )}

          {diff.rooms.map((room) => (
            <div key={room.roomName} className="card overflow-hidden">
              <div className="border-b border-slate-200 bg-slate-50 px-5 py-3 font-semibold text-slate-700">
                {room.roomName}
              </div>
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-100 text-xs text-slate-500">
                    <th className="px-5 py-2 text-left font-medium">Item</th>
                    <th className="px-4 py-2 text-left font-medium">Move-In</th>
                    <th className="px-4 py-2 text-left font-medium">Move-Out</th>
                    <th className="px-4 py-2 text-left font-medium">Flag</th>
                    <th className="px-4 py-2 text-left font-medium">Action</th>
                  </tr>
                </thead>
                <tbody>
                  {room.items.map((item, i) => (
                    <tr
                      key={i}
                      className={`border-b border-slate-50 last:border-0 ${
                        item.isDamaged || item.isMissing ? "bg-red-50" : ""
                      }`}
                    >
                      <td className="px-5 py-3 font-medium text-slate-900">{item.name}</td>
                      <td className="px-4 py-3 text-slate-600">{item.moveInCondition ?? "—"}</td>
                      <td className="px-4 py-3 text-slate-600">{item.moveOutCondition ?? "—"}</td>
                      <td className="px-4 py-3">
                        {item.isMissing && (
                          <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-700">Missing</span>
                        )}
                        {item.isDamaged && !item.isMissing && (
                          <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-700">Damaged</span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        {(item.isDamaged || item.isMissing) && (
                          <CreateWorkOrderButton
                            propertyId={property.id}
                            buildingId={building.id}
                            unitId={unit.id}
                            inspectionId={inspection.id}
                            itemName={item.name}
                            roomName={room.roomName}
                            isMissing={item.isMissing}
                          />
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}

          {diff.rooms.length === 0 && (
            <div className="card p-8 text-center text-slate-500">
              No items scanned yet. Scan rooms with the iOS app.
            </div>
          )}
        </div>
      )}

      {/* Non-move_out: show note */}
      {!isMoveOut && (
        <div className="card p-8 text-center text-slate-500">
          {inspection.inspection_type === "move_in"
            ? "Scan rooms with the iOS app to capture move-in condition. The data will be used as a baseline for future move-out comparisons."
            : "Scan rooms with the iOS app to document this inspection."}
        </div>
      )}
    </div>
  );
}
