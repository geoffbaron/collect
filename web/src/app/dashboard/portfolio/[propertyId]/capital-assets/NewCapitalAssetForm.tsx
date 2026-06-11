"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createCapitalAsset } from "@/lib/actions";
import {
  CAPITAL_ASSET_TYPE_LABELS,
  type CapitalAssetType,
} from "@/lib/types";

const TYPES = Object.entries(CAPITAL_ASSET_TYPE_LABELS) as [CapitalAssetType, string][];

export default function NewCapitalAssetForm({ propertyId }: { propertyId: string }) {
  const [name, setName] = useState("");
  const [assetType, setAssetType] = useState<CapitalAssetType>("other");
  const [manufacturer, setManufacturer] = useState("");
  const [model, setModel] = useState("");
  const [installDate, setInstallDate] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const result = await createCapitalAsset({
        propertyId,
        name,
        assetType,
        manufacturer,
        model,
        installDate: installDate || null,
      });
      if (!result.ok) { setError(result.error ?? "Failed to create asset."); return; }
      setName("");
      setAssetType("other");
      setManufacturer("");
      setModel("");
      setInstallDate("");
      router.refresh();
    });
  }

  return (
    <form onSubmit={handleSubmit} className="card space-y-4 p-5">
      <h2 className="font-semibold text-slate-900">New Capital Asset</h2>

      <div>
        <label className="label">Name</label>
        <input className="input" value={name} onChange={(e) => setName(e.target.value)} required />
      </div>

      <div className="grid gap-4 sm:grid-cols-4">
        <div>
          <label className="label">Type</label>
          <select className="input" value={assetType} onChange={(e) => setAssetType(e.target.value as CapitalAssetType)}>
            {TYPES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label">Manufacturer</label>
          <input className="input" value={manufacturer} onChange={(e) => setManufacturer(e.target.value)} />
        </div>
        <div>
          <label className="label">Model</label>
          <input className="input" value={model} onChange={(e) => setModel(e.target.value)} />
        </div>
        <div>
          <label className="label">Install Date</label>
          <input className="input" type="date" value={installDate} onChange={(e) => setInstallDate(e.target.value)} />
        </div>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <button type="submit" disabled={pending} className="btn-primary">
        {pending ? "Creating…" : "Create Asset"}
      </button>
    </form>
  );
}
