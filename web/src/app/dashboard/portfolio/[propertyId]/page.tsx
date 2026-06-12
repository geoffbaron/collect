import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getBuildings, getCommonAreas, getProperties, getPropertyVacancySummary } from "@/lib/data";
import { createBuilding } from "@/lib/actions";
import AddBuildingForm from "./AddBuildingForm";
import PropertyActions from "./PropertyActions";
import CommonAreasSection from "./CommonAreasSection";

export const dynamic = "force-dynamic";

export default async function PropertyPortfolioPage({
  params,
}: {
  params: { propertyId: string };
}) {
  const [properties, buildings, account, commonAreas] = await Promise.all([
    getProperties(),
    getBuildings(params.propertyId),
    getAccount(),
    getCommonAreas(params.propertyId),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property = properties.find((p) => p.id === params.propertyId);
  if (!property) notFound();

  // Vacancy summary per building — one query per building (N is small per property)
  const summaries = await Promise.all(
    buildings.map(async (b) => {
      const { data } = await import("@/lib/supabase/server").then(({ createClient }) =>
        createClient()
          .from("units")
          .select("lease_status")
          .eq("building_id", b.id)
          .is("deleted_at", null)
      );
      const rows = data ?? [];
      return {
        buildingId: b.id,
        total: rows.length,
        vacant: rows.filter((r: any) => r.lease_status === "vacant").length,
      };
    })
  );
  const summaryMap = new Map(summaries.map((s) => [s.buildingId, s]));

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="text-sm text-slate-500">
            <Link href="/dashboard" className="hover:underline">Portfolio</Link>
            <span className="mx-1">›</span>
            <span className="text-slate-900">{property.name}</span>
          </div>
          <h1 className="mt-1 text-2xl font-bold text-slate-900">{property.name}</h1>
          {property.address && (
            <p className="text-slate-500">{property.address}</p>
          )}
        </div>
        <div className="flex gap-2">
          <Link href={`/dashboard/portfolio/${property.id}/capital-assets`} className="btn-ghost">
            Capital Assets
          </Link>
          <Link href={`/dashboard/portfolio/${property.id}/maintenance-schedules`} className="btn-ghost">
            Maintenance
          </Link>
          <Link href={`/dashboard/portfolio/${property.id}/work-orders`} className="btn-ghost">
            Work Orders
          </Link>
        </div>
      </div>

      <PropertyActions property={property} />

      <div className="card">
        <div className="flex items-center justify-between border-b border-slate-200 px-5 py-3">
          <span className="font-semibold text-slate-900">Buildings</span>
          <span className="text-sm text-slate-500">{buildings.length} building{buildings.length !== 1 ? "s" : ""}</span>
        </div>

        {buildings.length === 0 ? (
          <div className="px-5 py-8 text-center text-slate-500">
            No buildings yet. Add one below.
          </div>
        ) : (
          <ul className="divide-y divide-slate-100">
            {buildings.map((b) => {
              const s = summaryMap.get(b.id);
              return (
                <li key={b.id}>
                  <Link
                    href={`/dashboard/portfolio/${property.id}/${b.id}`}
                    className="flex items-center justify-between px-5 py-4 hover:bg-slate-50"
                  >
                    <div>
                      <div className="font-medium text-slate-900">{b.name}</div>
                      {b.address && (
                        <div className="text-sm text-slate-500">{b.address}</div>
                      )}
                    </div>
                    <div className="text-right">
                      {s && s.total > 0 ? (
                        <>
                          <div className="text-sm font-medium text-slate-900">{s.total} units</div>
                          <div className="text-xs text-slate-500">{s.vacant} vacant</div>
                        </>
                      ) : (
                        <div className="text-sm text-slate-400">No units</div>
                      )}
                    </div>
                  </Link>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <AddBuildingForm propertyId={property.id} />

      <CommonAreasSection propertyId={property.id} commonAreas={commonAreas} />
    </div>
  );
}
