"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { deleteUnit, updateUnit } from "@/lib/actions";
import type { Unit } from "@/lib/types";

/**
 * Edit a unit's details and lease/tenant fields (tenant name, lease dates,
 * rent) — the only place lease renewals and tenant changes are recorded.
 */
export default function EditUnitForm({
  unit,
  propertyId,
  buildingId,
}: {
  unit: Unit;
  propertyId: string;
  buildingId: string;
}) {
  const [editing, setEditing] = useState(false);
  const [unitNumber, setUnitNumber] = useState(unit.unit_number);
  const [floorNumber, setFloorNumber] = useState(unit.floor_number?.toString() ?? "");
  const [sqft, setSqft] = useState(unit.sqft?.toString() ?? "");
  const [bedrooms, setBedrooms] = useState(unit.bedrooms?.toString() ?? "");
  const [bathrooms, setBathrooms] = useState(unit.bathrooms?.toString() ?? "");
  const [tenantName, setTenantName] = useState(unit.current_tenant_name ?? "");
  const [leaseStart, setLeaseStart] = useState(unit.lease_start ?? "");
  const [leaseEnd, setLeaseEnd] = useState(unit.lease_end ?? "");
  const [monthlyRent, setMonthlyRent] = useState(unit.monthly_rent?.toString() ?? "");
  const [notes, setNotes] = useState(unit.notes ?? "");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  const num = (s: string) => (s.trim() === "" ? null : Number(s));

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const result = await updateUnit(unit.id, propertyId, buildingId, {
        unitNumber,
        floorNumber: num(floorNumber),
        sqft: num(sqft),
        bedrooms: num(bedrooms),
        bathrooms: num(bathrooms),
        currentTenantName: tenantName || null,
        leaseStart: leaseStart || null,
        leaseEnd: leaseEnd || null,
        monthlyRent: num(monthlyRent),
        notes,
      });
      if (!result.ok) { setError(result.error ?? "Failed to update unit."); return; }
      setEditing(false);
      router.refresh();
    });
  }

  function handleDelete() {
    if (!confirm(`Delete Unit ${unit.unit_number}? Its history will no longer appear in the portfolio.`)) return;
    setError(null);
    start(async () => {
      const result = await deleteUnit(unit.id, propertyId, buildingId);
      if (!result.ok) { setError(result.error ?? "Failed to delete unit."); return; }
      router.push(`/dashboard/portfolio/${propertyId}/${buildingId}`);
    });
  }

  if (!editing) {
    return (
      <div className="flex items-center gap-2">
        <button type="button" onClick={() => setEditing(true)} className="btn-ghost">Edit unit</button>
        <button type="button" onClick={handleDelete} disabled={pending} className="btn-ghost text-red-600">
          {pending ? "Deleting…" : "Delete"}
        </button>
        {error && <p className="text-sm text-red-600">{error}</p>}
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="card w-full space-y-4 p-5">
      <h2 className="font-semibold text-slate-900">Edit Unit</h2>

      <div className="grid gap-4 sm:grid-cols-3">
        <div>
          <label className="label" htmlFor="unit-number">Unit number</label>
          <input id="unit-number" className="input" value={unitNumber} onChange={(e) => setUnitNumber(e.target.value)} required />
        </div>
        <div>
          <label className="label" htmlFor="unit-floor">Floor</label>
          <input id="unit-floor" className="input" type="number" value={floorNumber} onChange={(e) => setFloorNumber(e.target.value)} />
        </div>
        <div>
          <label className="label" htmlFor="unit-sqft">Sqft</label>
          <input id="unit-sqft" className="input" type="number" min="0" value={sqft} onChange={(e) => setSqft(e.target.value)} />
        </div>
        <div>
          <label className="label" htmlFor="unit-bedrooms">Bedrooms</label>
          <input id="unit-bedrooms" className="input" type="number" min="0" step="0.5" value={bedrooms} onChange={(e) => setBedrooms(e.target.value)} />
        </div>
        <div>
          <label className="label" htmlFor="unit-bathrooms">Bathrooms</label>
          <input id="unit-bathrooms" className="input" type="number" min="0" step="0.5" value={bathrooms} onChange={(e) => setBathrooms(e.target.value)} />
        </div>
      </div>

      <div className="border-t border-slate-100 pt-4">
        <h3 className="mb-3 text-sm font-semibold text-slate-700">Lease &amp; tenant</h3>
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label className="label" htmlFor="unit-tenant">Tenant name</label>
            <input id="unit-tenant" className="input" value={tenantName} onChange={(e) => setTenantName(e.target.value)} />
          </div>
          <div>
            <label className="label" htmlFor="unit-rent">Monthly rent ($)</label>
            <input id="unit-rent" className="input" type="number" min="0" step="0.01" value={monthlyRent} onChange={(e) => setMonthlyRent(e.target.value)} />
          </div>
          <div>
            <label className="label" htmlFor="unit-lease-start">Lease start</label>
            <input id="unit-lease-start" className="input" type="date" value={leaseStart} onChange={(e) => setLeaseStart(e.target.value)} />
          </div>
          <div>
            <label className="label" htmlFor="unit-lease-end">Lease end</label>
            <input id="unit-lease-end" className="input" type="date" value={leaseEnd} onChange={(e) => setLeaseEnd(e.target.value)} />
          </div>
        </div>
      </div>

      <div>
        <label className="label" htmlFor="unit-notes">Notes</label>
        <textarea id="unit-notes" className="input" rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} />
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="flex items-center gap-3">
        <button type="submit" disabled={pending || !unitNumber.trim()} className="btn-primary">
          {pending ? "Saving…" : "Save"}
        </button>
        <button type="button" onClick={() => setEditing(false)} className="btn-ghost">Cancel</button>
      </div>
    </form>
  );
}
