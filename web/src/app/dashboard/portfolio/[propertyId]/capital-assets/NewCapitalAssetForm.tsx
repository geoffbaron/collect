"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createCapitalAsset } from "@/lib/actions";
import {
  CAPITAL_ASSET_TYPE_LABELS,
  type Building,
  type CapitalAssetType,
  type CommonArea,
  type Unit,
} from "@/lib/types";
import LocationSelect, { parseLocationValue } from "@/components/LocationSelect";

const TYPES = Object.entries(CAPITAL_ASSET_TYPE_LABELS) as [CapitalAssetType, string][];

export default function NewCapitalAssetForm({
  propertyId,
  buildings,
  units,
  commonAreas,
}: {
  propertyId: string;
  buildings: Building[];
  units: Unit[];
  commonAreas: CommonArea[];
}) {
  const [name, setName] = useState("");
  const [assetType, setAssetType] = useState<CapitalAssetType>("other");
  const [manufacturer, setManufacturer] = useState("");
  const [model, setModel] = useState("");
  const [installDate, setInstallDate] = useState("");
  const [location, setLocation] = useState("property");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const target = parseLocationValue(location, units, commonAreas);
      const result = await createCapitalAsset({
        propertyId,
        name,
        assetType,
        manufacturer,
        model,
        installDate: installDate || null,
        ...target,
      });
      if (!result.ok) { setError(result.error ?? "Failed to create asset."); return; }
      setName("");
      setAssetType("other");
      setManufacturer("");
      setModel("");
      setInstallDate("");
      setLocation("property");
      router.refresh();
    });
  }

  return (
    <form onSubmit={handleSubmit} className="card space-y-4 p-5">
      <h2 className="font-semibold text-slate-900">New Capital Asset</h2>

      <div>
        <label className="label" htmlFor="ca-name">Name</label>
        <input id="ca-name" className="input" value={name} onChange={(e) => setName(e.target.value)} required />
      </div>

      <div className="grid gap-4 sm:grid-cols-4">
        <div>
          <label className="label" htmlFor="ca-type">Type</label>
          <select id="ca-type" className="input" value={assetType} onChange={(e) => setAssetType(e.target.value as CapitalAssetType)}>
            {TYPES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="ca-manufacturer">Manufacturer</label>
          <input id="ca-manufacturer" className="input" value={manufacturer} onChange={(e) => setManufacturer(e.target.value)} />
        </div>
        <div>
          <label className="label" htmlFor="ca-model">Model</label>
          <input id="ca-model" className="input" value={model} onChange={(e) => setModel(e.target.value)} />
        </div>
        <div>
          <label className="label" htmlFor="ca-install-date">Install Date</label>
          <input id="ca-install-date" className="input" type="date" value={installDate} onChange={(e) => setInstallDate(e.target.value)} />
        </div>
      </div>

      <LocationSelect
        value={location}
        onChange={setLocation}
        buildings={buildings}
        units={units}
        commonAreas={commonAreas}
      />

      {error && <p className="text-sm text-red-600">{error}</p>}

      <button type="submit" disabled={pending} className="btn-primary">
        {pending ? "Creating…" : "Create Asset"}
      </button>
    </form>
  );
}
