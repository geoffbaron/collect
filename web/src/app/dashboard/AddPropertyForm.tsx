"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createProperty } from "@/lib/actions";

/** PM dashboard: create a property without needing the iOS app. */
export default function AddPropertyForm() {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [address, setAddress] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  if (!open) {
    return (
      <button type="button" onClick={() => setOpen(true)} className="btn-ghost">
        Add property
      </button>
    );
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const result = await createProperty(name, address);
      if (!result.ok) { setError(result.error ?? "Failed to create property."); return; }
      setName("");
      setAddress("");
      setOpen(false);
      router.refresh();
    });
  }

  return (
    <form onSubmit={handleSubmit} className="card flex w-full flex-wrap items-end gap-3 p-4">
      <div className="min-w-48 flex-1">
        <label className="label" htmlFor="new-property-name">Name</label>
        <input id="new-property-name" className="input" value={name} onChange={(e) => setName(e.target.value)} required />
      </div>
      <div className="min-w-48 flex-1">
        <label className="label" htmlFor="new-property-address">Address (optional)</label>
        <input id="new-property-address" className="input" value={address} onChange={(e) => setAddress(e.target.value)} />
      </div>
      <div className="flex items-center gap-2">
        <button type="submit" disabled={pending || !name.trim()} className="btn-primary">
          {pending ? "Adding…" : "Add"}
        </button>
        <button type="button" onClick={() => setOpen(false)} className="btn-ghost">Cancel</button>
      </div>
      {error && <p className="w-full text-sm text-red-600">{error}</p>}
    </form>
  );
}
