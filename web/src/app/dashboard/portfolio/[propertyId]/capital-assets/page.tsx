import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getBuildings, getCapitalAssets, getCommonAreas, getProperties, getUnits } from "@/lib/data";
import {
  CAPITAL_ASSET_CONDITION_LABELS,
  CAPITAL_ASSET_TYPE_LABELS,
} from "@/lib/types";
import { formatDateOnly } from "@/lib/dates";
import NewCapitalAssetForm from "./NewCapitalAssetForm";

export const dynamic = "force-dynamic";

const CONDITION_STYLES: Record<string, string> = {
  excellent: "bg-green-100 text-green-700",
  good: "bg-blue-100 text-blue-700",
  fair: "bg-orange-100 text-orange-700",
  poor: "bg-red-100 text-red-700",
  needs_replacement: "bg-red-100 text-red-700",
};

export default async function PropertyCapitalAssetsPage({
  params,
  searchParams,
}: {
  params: { propertyId: string };
  searchParams: { unitId?: string };
}) {
  const unitId = searchParams.unitId;
  const [properties, capitalAssets, account, buildings, units, commonAreas] = await Promise.all([
    getProperties(),
    getCapitalAssets({ propertyId: params.propertyId, unitId }),
    getAccount(),
    getBuildings(params.propertyId),
    getUnits({ propertyId: params.propertyId }),
    getCommonAreas(params.propertyId),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property = properties.find((p) => p.id === params.propertyId);
  if (!property) notFound();

  const unit = unitId ? units.find((u) => u.id === unitId) : undefined;

  return (
    <div className="space-y-6">
      <div>
        <div className="text-sm text-slate-500">
          <Link href="/dashboard" className="hover:underline">Portfolio</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}`} className="hover:underline">{property.name}</Link>
          <span className="mx-1">›</span>
          <span className="text-slate-900">Capital Assets</span>
        </div>
        <h1 className="mt-1 text-2xl font-bold text-slate-900">Capital Assets</h1>
      </div>

      {unit && (
        <div className="flex items-center justify-between rounded-md bg-slate-100 px-4 py-2 text-sm text-slate-700">
          <span>Showing capital assets for Unit {unit.unit_number}</span>
          <Link href={`/dashboard/portfolio/${property.id}/capital-assets`} className="text-brand hover:underline">
            Clear filter
          </Link>
        </div>
      )}

      <div className="card">
        <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">
          {capitalAssets.length} asset{capitalAssets.length !== 1 ? "s" : ""}
        </div>
        {capitalAssets.length === 0 ? (
          <div className="px-5 py-6 text-center text-slate-500">No capital assets yet.</div>
        ) : (
          <ul className="divide-y divide-slate-100">
            {capitalAssets.map((asset) => (
              <li key={asset.id}>
                <Link
                  href={`/dashboard/portfolio/${property.id}/capital-assets/${asset.id}`}
                  className="flex items-center justify-between px-5 py-4 hover:bg-slate-50"
                >
                  <div>
                    <div className="font-medium text-slate-900">{asset.name}</div>
                    <div className="text-sm text-slate-500">
                      {CAPITAL_ASSET_TYPE_LABELS[asset.asset_type]}
                      {asset.manufacturer && ` · ${asset.manufacturer}`}
                      {asset.install_date && ` · Installed ${formatDateOnly(asset.install_date)}`}
                    </div>
                  </div>
                  <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${CONDITION_STYLES[asset.condition]}`}>
                    {CAPITAL_ASSET_CONDITION_LABELS[asset.condition]}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </div>

      <NewCapitalAssetForm propertyId={property.id} buildings={buildings} units={units} commonAreas={commonAreas} />
    </div>
  );
}
