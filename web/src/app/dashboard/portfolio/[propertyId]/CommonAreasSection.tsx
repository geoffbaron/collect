"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createCommonArea, deleteCommonArea, updateCommonArea } from "@/lib/actions";
import { AREA_TYPE_LABELS, type AreaType, type CommonArea } from "@/lib/types";

const AREA_TYPES = Object.entries(AREA_TYPE_LABELS) as [AreaType, string][];

/**
 * Manage a property's common areas (lobby, gym, laundry…). These were
 * previously selectable in work-order/asset forms but had no management UI.
 */
export default function CommonAreasSection({
  propertyId,
  commonAreas,
}: {
  propertyId: string;
  commonAreas: CommonArea[];
}) {
  const [name, setName] = useState("");
  const [areaType, setAreaType] = useState<AreaType>("other");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [editType, setEditType] = useState<AreaType>("other");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function run(action: () => Promise<{ ok: boolean; error?: string | null }>) {
    setError(null);
    start(async () => {
      const result = await action();
      if (!result.ok) { setError(result.error ?? "Something went wrong."); return; }
      router.refresh();
    });
  }

  function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    run(async () => {
      const result = await createCommonArea({ propertyId, name, areaType });
      if (result.ok) { setName(""); setAreaType("other"); }
      return result;
    });
  }

  return (
    <div className="card">
      <div className="flex items-center justify-between border-b border-slate-200 px-5 py-3">
        <span className="font-semibold text-slate-900">Common Areas</span>
        <span className="text-sm text-slate-500">
          {commonAreas.length} area{commonAreas.length !== 1 ? "s" : ""}
        </span>
      </div>

      {commonAreas.length > 0 && (
        <ul className="divide-y divide-slate-100">
          {commonAreas.map((area) => (
            <li key={area.id} className="flex flex-wrap items-center justify-between gap-3 px-5 py-3">
              {editingId === area.id ? (
                <form
                  className="flex flex-1 flex-wrap items-center gap-2"
                  onSubmit={(e) => {
                    e.preventDefault();
                    run(async () => {
                      const result = await updateCommonArea(area.id, propertyId, { name: editName, areaType: editType });
                      if (result.ok) setEditingId(null);
                      return result;
                    });
                  }}
                >
                  <input
                    className="input max-w-56"
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    aria-label="Common area name"
                    required
                  />
                  <select className="input max-w-40" value={editType} onChange={(e) => setEditType(e.target.value as AreaType)} aria-label="Common area type">
                    {AREA_TYPES.map(([value, label]) => (
                      <option key={value} value={value}>{label}</option>
                    ))}
                  </select>
                  <button type="submit" disabled={pending} className="btn-primary py-1.5">Save</button>
                  <button type="button" onClick={() => setEditingId(null)} className="btn-ghost py-1.5">Cancel</button>
                </form>
              ) : (
                <>
                  <div>
                    <div className="font-medium text-slate-900">{area.name}</div>
                    <div className="text-sm text-slate-500">{AREA_TYPE_LABELS[area.area_type]}</div>
                  </div>
                  <div className="flex items-center gap-2 text-sm">
                    <button
                      type="button"
                      className="btn-ghost py-1"
                      onClick={() => {
                        setEditingId(area.id);
                        setEditName(area.name);
                        setEditType(area.area_type);
                      }}
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      disabled={pending}
                      className="btn-ghost py-1 text-red-600"
                      onClick={() => {
                        if (confirm(`Delete ${area.name}?`)) run(() => deleteCommonArea(area.id, propertyId));
                      }}
                    >
                      Delete
                    </button>
                  </div>
                </>
              )}
            </li>
          ))}
        </ul>
      )}

      <form onSubmit={handleAdd} className="flex flex-wrap items-end gap-3 border-t border-slate-100 px-5 py-4">
        <div className="min-w-48 flex-1">
          <label className="label" htmlFor="new-area-name">New common area</label>
          <input id="new-area-name" className="input" placeholder="e.g. North Lobby" value={name} onChange={(e) => setName(e.target.value)} required />
        </div>
        <div>
          <label className="label" htmlFor="new-area-type">Type</label>
          <select id="new-area-type" className="input" value={areaType} onChange={(e) => setAreaType(e.target.value as AreaType)}>
            {AREA_TYPES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <button type="submit" disabled={pending || !name.trim()} className="btn-primary">
          {pending ? "Adding…" : "Add"}
        </button>
        {error && <p className="w-full text-sm text-red-600">{error}</p>}
      </form>
    </div>
  );
}
