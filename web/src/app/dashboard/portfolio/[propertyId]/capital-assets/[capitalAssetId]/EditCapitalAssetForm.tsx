"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { deleteCapitalAsset, updateCapitalAsset } from "@/lib/actions";
import {
  CAPITAL_ASSET_TYPE_LABELS,
  type CapitalAsset,
  type CapitalAssetType,
} from "@/lib/types";

const TYPES = Object.entries(CAPITAL_ASSET_TYPE_LABELS) as [CapitalAssetType, string][];

export default function EditCapitalAssetForm({ capitalAsset, propertyId }: { capitalAsset: CapitalAsset; propertyId: string }) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(capitalAsset.name);
  const [assetType, setAssetType] = useState<CapitalAssetType>(capitalAsset.asset_type);
  const [manufacturer, setManufacturer] = useState(capitalAsset.manufacturer);
  const [model, setModel] = useState(capitalAsset.model);
  const [serialNumber, setSerialNumber] = useState(capitalAsset.serial_number);
  const [installDate, setInstallDate] = useState(capitalAsset.install_date ?? "");
  const [warrantyExpires, setWarrantyExpires] = useState(capitalAsset.warranty_expires ?? "");
  const [lastServicedAt, setLastServicedAt] = useState(capitalAsset.last_serviced_at ?? "");
  const [notes, setNotes] = useState(capitalAsset.notes);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const result = await updateCapitalAsset(capitalAsset.id, propertyId, {
        name,
        assetType,
        manufacturer,
        model,
        serialNumber,
        installDate: installDate || null,
        warrantyExpires: warrantyExpires || null,
        lastServicedAt: lastServicedAt || null,
        notes,
      });
      if (!result.ok) { setError(result.error ?? "Failed to update asset."); return; }
      setEditing(false);
      router.refresh();
    });
  }

  function handleDelete() {
    if (!confirm("Delete this capital asset? This cannot be undone.")) return;
    setError(null);
    start(async () => {
      const result = await deleteCapitalAsset(capitalAsset.id, propertyId);
      if (!result.ok) { setError(result.error ?? "Failed to delete asset."); return; }
      router.push(`/dashboard/portfolio/${propertyId}/capital-assets`);
    });
  }

  if (!editing) {
    return (
      <div className="flex items-center gap-3">
        <button type="button" onClick={() => setEditing(true)} className="btn-ghost">Edit</button>
        <button type="button" onClick={handleDelete} disabled={pending} className="btn-ghost text-red-600">
          {pending ? "Deleting…" : "Delete"}
        </button>
        {error && <p className="text-sm text-red-600">{error}</p>}
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4 border-t border-slate-200 pt-4">
      <div>
        <label className="label" htmlFor="edit-ca-name">Name</label>
        <input id="edit-ca-name" className="input" value={name} onChange={(e) => setName(e.target.value)} required />
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div>
          <label className="label" htmlFor="edit-ca-type">Type</label>
          <select id="edit-ca-type" className="input" value={assetType} onChange={(e) => setAssetType(e.target.value as CapitalAssetType)}>
            {TYPES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="edit-ca-manufacturer">Manufacturer</label>
          <input id="edit-ca-manufacturer" className="input" value={manufacturer} onChange={(e) => setManufacturer(e.target.value)} />
        </div>
        <div>
          <label className="label" htmlFor="edit-ca-model">Model</label>
          <input id="edit-ca-model" className="input" value={model} onChange={(e) => setModel(e.target.value)} />
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label className="label" htmlFor="edit-ca-serial">Serial Number</label>
          <input id="edit-ca-serial" className="input" value={serialNumber} onChange={(e) => setSerialNumber(e.target.value)} />
        </div>
        <div>
          <label className="label" htmlFor="edit-ca-install-date">Install Date</label>
          <input id="edit-ca-install-date" className="input" type="date" value={installDate} onChange={(e) => setInstallDate(e.target.value)} />
        </div>
        <div>
          <label className="label" htmlFor="edit-ca-warranty">Warranty Expires</label>
          <input id="edit-ca-warranty" className="input" type="date" value={warrantyExpires} onChange={(e) => setWarrantyExpires(e.target.value)} />
        </div>
        <div>
          <label className="label" htmlFor="edit-ca-last-serviced">Last Serviced</label>
          <input id="edit-ca-last-serviced" className="input" type="date" value={lastServicedAt} onChange={(e) => setLastServicedAt(e.target.value)} />
        </div>
      </div>

      <div>
        <label className="label" htmlFor="edit-ca-notes">Notes</label>
        <textarea id="edit-ca-notes" className="input" rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} />
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="flex items-center gap-3">
        <button type="submit" disabled={pending} className="btn-primary">
          {pending ? "Saving…" : "Save"}
        </button>
        <button type="button" onClick={() => setEditing(false)} className="btn-ghost">Cancel</button>
      </div>
    </form>
  );
}
