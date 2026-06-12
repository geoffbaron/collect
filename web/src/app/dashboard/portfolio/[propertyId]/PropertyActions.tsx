"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { deleteProperty, updateProperty } from "@/lib/actions";
import type { Property } from "@/lib/types";

/** Edit/delete controls for a property, shown on its portfolio page. */
export default function PropertyActions({ property }: { property: Property }) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(property.name);
  const [address, setAddress] = useState(property.address);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const result = await updateProperty(property.id, { name, address });
      if (!result.ok) { setError(result.error ?? "Failed to update property."); return; }
      setEditing(false);
      router.refresh();
    });
  }

  function handleDelete() {
    if (!confirm(`Delete ${property.name}? Its buildings, units, and history will no longer appear in the portfolio.`)) return;
    setError(null);
    start(async () => {
      const result = await deleteProperty(property.id);
      if (!result.ok) { setError(result.error ?? "Failed to delete property."); return; }
      router.push("/dashboard");
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
        <label className="label" htmlFor="edit-property-name">Name</label>
        <input id="edit-property-name" className="input" value={name} onChange={(e) => setName(e.target.value)} required />
      </div>
      <div className="min-w-48 flex-1">
        <label className="label" htmlFor="edit-property-address">Address</label>
        <input id="edit-property-address" className="input" value={address} onChange={(e) => setAddress(e.target.value)} />
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
