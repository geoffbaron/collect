"use client";

import { useMemo, useState } from "react";
import type { AssetWithLocation, ListingStatus } from "@/lib/types";
import { LISTING_LABELS } from "@/lib/types";
import { updateAsset, deleteAsset } from "@/lib/actions";

const fmt = (n: number) =>
  n.toLocaleString("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });

const STATUSES: ListingStatus[] = ["not_listed", "ready", "listed", "pending", "sold"];

export function ItemsTable({ initialAssets }: { initialAssets: AssetWithLocation[] }) {
  const [assets, setAssets] = useState(initialAssets);
  const [query, setQuery] = useState("");
  const [propertyFilter, setPropertyFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [editing, setEditing] = useState<AssetWithLocation | null>(null);

  const properties = useMemo(
    () => Array.from(new Set(assets.map((a) => a.property_name).filter(Boolean))) as string[],
    [assets]
  );

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return assets.filter((a) => {
      if (propertyFilter !== "all" && a.property_name !== propertyFilter) return false;
      if (statusFilter !== "all" && a.listing_status !== statusFilter) return false;
      if (!q) return true;
      return (
        a.name.toLowerCase().includes(q) ||
        a.category.toLowerCase().includes(q) ||
        (a.asset_description ?? "").toLowerCase().includes(q)
      );
    });
  }, [assets, query, propertyFilter, statusFilter]);

  const totalValue = filtered.reduce((s, a) => s + (a.estimated_value ?? 0) * (a.quantity ?? 1), 0);

  async function handleSave(updated: AssetWithLocation) {
    setAssets((prev) => prev.map((a) => (a.id === updated.id ? updated : a)));
    setEditing(null);
    await updateAsset(updated.id, {
      name: updated.name,
      category: updated.category,
      asset_description: updated.asset_description,
      condition: updated.condition,
      quantity: updated.quantity,
      estimated_value: updated.estimated_value,
      listing_status: updated.listing_status,
      asking_price: updated.asking_price,
    });
  }

  async function handleDelete(id: string) {
    if (!confirm("Delete this item? This removes it from your inventory.")) return;
    setAssets((prev) => prev.filter((a) => a.id !== id));
    await deleteAsset(id);
  }

  return (
    <div className="space-y-4">
      {/* Controls */}
      <div className="flex flex-wrap items-center gap-3">
        <input
          className="input max-w-xs"
          placeholder="Search name, category, description…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <select className="input max-w-[180px]" value={propertyFilter} onChange={(e) => setPropertyFilter(e.target.value)}>
          <option value="all">All properties</option>
          {properties.map((p) => (
            <option key={p} value={p}>
              {p}
            </option>
          ))}
        </select>
        <select className="input max-w-[160px]" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="all">All statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>
              {LISTING_LABELS[s]}
            </option>
          ))}
        </select>
        <div className="ml-auto text-sm text-slate-500">
          {filtered.length} items · <span className="font-semibold text-slate-700">{fmt(totalValue)}</span>
        </div>
      </div>

      {/* Table */}
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="border-b border-slate-200 text-left text-slate-500">
            <tr>
              <th className="px-4 py-3 font-medium">Item</th>
              <th className="px-4 py-3 font-medium">Category</th>
              <th className="px-4 py-3 font-medium">Location</th>
              <th className="px-4 py-3 text-right font-medium">Qty</th>
              <th className="px-4 py-3 text-right font-medium">Value</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtered.map((a) => (
              <tr key={a.id} className="hover:bg-slate-50">
                <td className="px-4 py-3">
                  <div className="flex items-center gap-3">
                    {a.thumb_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={a.thumb_url} alt="" className="h-10 w-10 rounded-lg object-cover" />
                    ) : (
                      <div className="grid h-10 w-10 place-items-center rounded-lg bg-slate-100 text-slate-400">
                        📦
                      </div>
                    )}
                    <div>
                      <div className="font-medium text-slate-900">{a.name}</div>
                      {a.condition && <div className="text-xs text-slate-500">{a.condition}</div>}
                    </div>
                  </div>
                </td>
                <td className="px-4 py-3 text-slate-600">{a.category}</td>
                <td className="px-4 py-3 text-slate-500">
                  {[a.property_name, a.room_name].filter(Boolean).join(" · ") || "—"}
                </td>
                <td className="px-4 py-3 text-right text-slate-600">{a.quantity}</td>
                <td className="px-4 py-3 text-right text-slate-900">
                  {a.estimated_value != null ? fmt(a.estimated_value) : "—"}
                </td>
                <td className="px-4 py-3">
                  <StatusBadge status={a.listing_status} />
                </td>
                <td className="px-4 py-3 text-right whitespace-nowrap">
                  <button onClick={() => setEditing(a)} className="text-brand-700 hover:underline">
                    Edit
                  </button>
                  <button onClick={() => handleDelete(a.id)} className="ml-3 text-red-600 hover:underline">
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                  No items match your filters.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {editing && <EditModal asset={editing} onCancel={() => setEditing(null)} onSave={handleSave} />}
    </div>
  );
}

function StatusBadge({ status }: { status: ListingStatus }) {
  const colors: Record<ListingStatus, string> = {
    not_listed: "bg-slate-100 text-slate-500",
    ready: "bg-purple-100 text-purple-700",
    listed: "bg-blue-100 text-blue-700",
    pending: "bg-amber-100 text-amber-700",
    sold: "bg-green-100 text-green-700",
  };
  return (
    <span className={"rounded-full px-2 py-0.5 text-xs font-medium " + colors[status]}>
      {LISTING_LABELS[status]}
    </span>
  );
}

function EditModal({
  asset,
  onCancel,
  onSave,
}: {
  asset: AssetWithLocation;
  onCancel: () => void;
  onSave: (a: AssetWithLocation) => void;
}) {
  const [draft, setDraft] = useState<AssetWithLocation>({ ...asset });
  const set = (patch: Partial<AssetWithLocation>) => setDraft((d) => ({ ...d, ...patch }));

  return (
    <div className="fixed inset-0 z-30 flex items-center justify-center bg-black/40 p-4" onClick={onCancel}>
      <div className="card w-full max-w-lg p-6" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-lg font-bold text-slate-900">Edit item</h2>
        <div className="mt-4 grid grid-cols-2 gap-4">
          <div className="col-span-2">
            <label className="label">Name</label>
            <input className="input" value={draft.name} onChange={(e) => set({ name: e.target.value })} />
          </div>
          <div>
            <label className="label">Category</label>
            <input className="input" value={draft.category} onChange={(e) => set({ category: e.target.value })} />
          </div>
          <div>
            <label className="label">Condition</label>
            <input
              className="input"
              value={draft.condition ?? ""}
              onChange={(e) => set({ condition: e.target.value || null })}
            />
          </div>
          <div>
            <label className="label">Quantity</label>
            <input
              className="input"
              type="number"
              min={1}
              value={draft.quantity}
              onChange={(e) => set({ quantity: parseInt(e.target.value) || 1 })}
            />
          </div>
          <div>
            <label className="label">Estimated value (USD)</label>
            <input
              className="input"
              type="number"
              step="1"
              value={draft.estimated_value ?? ""}
              onChange={(e) => set({ estimated_value: e.target.value === "" ? null : parseFloat(e.target.value) })}
            />
          </div>
          <div className="col-span-2">
            <label className="label">Description</label>
            <textarea
              className="input"
              rows={3}
              value={draft.asset_description ?? ""}
              onChange={(e) => set({ asset_description: e.target.value })}
            />
          </div>
          <div className="col-span-2">
            <label className="label">Listing status</label>
            <select
              className="input"
              value={draft.listing_status}
              onChange={(e) => set({ listing_status: e.target.value as ListingStatus })}
            >
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {LISTING_LABELS[s]}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="mt-6 flex justify-end gap-3">
          <button onClick={onCancel} className="btn-ghost">
            Cancel
          </button>
          <button onClick={() => onSave(draft)} className="btn-primary">
            Save changes
          </button>
        </div>
      </div>
    </div>
  );
}
