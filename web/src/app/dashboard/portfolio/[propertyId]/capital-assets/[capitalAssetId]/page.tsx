import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getCapitalAsset, getProperties } from "@/lib/data";
import {
  CAPITAL_ASSET_TYPE_LABELS,
} from "@/lib/types";
import { formatDateOnly } from "@/lib/dates";
import ConditionSelect from "./ConditionSelect";
import EditCapitalAssetForm from "./EditCapitalAssetForm";

export const dynamic = "force-dynamic";

export default async function CapitalAssetDetailPage({
  params,
}: {
  params: { propertyId: string; capitalAssetId: string };
}) {
  const [properties, capitalAsset, account] = await Promise.all([
    getProperties(),
    getCapitalAsset(params.capitalAssetId),
    getAccount(),
  ]);

  if (account?.product_mode !== "property_manager") notFound();

  const property = properties.find((p) => p.id === params.propertyId);
  if (!property || !capitalAsset || capitalAsset.property_id !== property.id) notFound();

  return (
    <div className="space-y-6">
      <div>
        <div className="text-sm text-slate-500">
          <Link href="/dashboard" className="hover:underline">Portfolio</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}`} className="hover:underline">{property.name}</Link>
          <span className="mx-1">›</span>
          <Link href={`/dashboard/portfolio/${property.id}/capital-assets`} className="hover:underline">Capital Assets</Link>
          <span className="mx-1">›</span>
          <span className="text-slate-900">{capitalAsset.name}</span>
        </div>
        <h1 className="mt-1 text-2xl font-bold text-slate-900">{capitalAsset.name}</h1>
      </div>

      <div className="card p-5 space-y-4">
        {capitalAsset.notes && (
          <p className="text-slate-700">{capitalAsset.notes}</p>
        )}

        <dl className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <InfoItem label="Type" value={CAPITAL_ASSET_TYPE_LABELS[capitalAsset.asset_type]} />
          {capitalAsset.manufacturer && <InfoItem label="Manufacturer" value={capitalAsset.manufacturer} />}
          {capitalAsset.model && <InfoItem label="Model" value={capitalAsset.model} />}
          {capitalAsset.serial_number && <InfoItem label="Serial Number" value={capitalAsset.serial_number} />}
          {capitalAsset.install_date && (
            <InfoItem label="Installed" value={formatDateOnly(capitalAsset.install_date)} />
          )}
          {capitalAsset.warranty_expires && (
            <InfoItem label="Warranty Expires" value={formatDateOnly(capitalAsset.warranty_expires)} />
          )}
          {capitalAsset.last_serviced_at && (
            <InfoItem label="Last Serviced" value={formatDateOnly(capitalAsset.last_serviced_at)} />
          )}
        </dl>

        <ConditionSelect capitalAssetId={capitalAsset.id} propertyId={property.id} condition={capitalAsset.condition} />

        <EditCapitalAssetForm capitalAsset={capitalAsset} propertyId={property.id} />
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
