"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { deleteBuilding, updateBuilding } from "@/lib/actions";
import type { Building } from "@/lib/types";

/** Edit/delete controls for a building, shown on its detail page. */
export default function BuildingActions({ building, propertyId }: { building: Building; propertyId: string }) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(building.name);
  const [address, setAddress] = useState(building.address);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const result = await updateBuilding(building.id, propertyId, { name, address });
      if (!result.ok) { setError(result.error ?? "Failed to update building."); return; }
      setEditing(false);
      router.refresh();
    });
  }

  function handleDelete() {
    if (!confirm(`Delete ${building.name}? Its units will no longer appear in the portfolio.`)) return;
    setError(null);
    start(async () => {
      const result = await deleteBuilding(building.id, propertyId);
      if (!result.ok) { setError(result.error ?? "Failed to delete building."); return; }
      router.push(`/dashboard/portfolio/${propertyId}`);
    });
  }

  if (!editing) {
    return (
      <div className="flex items-center gap-2">
        <button type="button" onClick={() => setEditing(true)} className="btn-ghost">Edit</button>
        <button type="button" onClick={handleDelete} disabled={pending} className="btn-ghost text-red-600">
          {pending ? "Deleting…" : "Delete"}
        </button>
        {error && <p className="text-sm text-red-600">{error}</p>}
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="card flex w-full flex-wrap items-end gap-3 p-4">
      <div className="min-w-48 flex-1">
        <label className="label" htmlFor="edit-building-name">Name</label>
        <input id="edit-building-name" className="input" value={name} onChange={(e) => setName(e.target.value)} required />
      </div>
      <div className="min-w-48 flex-1">
        <label className="label" htmlFor="edit-building-address">Address</label>
        <input id="edit-building-address" className="input" value={address} onChange={(e) => setAddress(e.target.value)} />
      </div>
      <div className="flex items-center gap-2">
        <button type="submit" disabled={pending || !name.trim()} className="btn-primary">
          {pending ? "Saving…" : "Save"}
        </button>
        <button type="button" onClick={() => setEditing(false)} className="btn-ghost">Cancel</button>
      </div>
      {error && <p className="w-full text-sm text-red-600">{error}</p>}
    </form>
  );
}
