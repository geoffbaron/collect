"use client";

import { useMemo, useState } from "react";
import type { AssetWithLocation, ListingStatus } from "@/lib/types";
import { LISTING_LABELS } from "@/lib/types";
import { updateAsset } from "@/lib/actions";

const fmt = (n: number) =>
  n.toLocaleString("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });

const TABS: { key: ListingStatus | "all"; label: string }[] = [
  { key: "all", label: "All" },
  { key: "ready", label: "Ready" },
  { key: "listed", label: "Listed" },
  { key: "pending", label: "Pending" },
  { key: "sold", label: "Sold" },
];

const NEXT_STATUSES: ListingStatus[] = ["ready", "listed", "pending", "sold", "not_listed"];

export function ListingsBoard({ initialListings }: { initialListings: AssetWithLocation[] }) {
  const [listings, setListings] = useState(initialListings);
  const [tab, setTab] = useState<ListingStatus | "all">("all");

  const filtered = useMemo(
    () => (tab === "all" ? listings : listings.filter((a) => a.listing_status === tab)),
    [listings, tab]
  );

  const activeValue = listings
    .filter((a) => a.listing_status === "ready" || a.listing_status === "listed" || a.listing_status === "pending")
    .reduce((s, a) => s + (a.asking_price ?? a.estimated_value ?? 0), 0);
  const soldValue = listings
    .filter((a) => a.listing_status === "sold")
    .reduce((s, a) => s + (a.sold_price ?? 0), 0);

  async function changeStatus(asset: AssetWithLocation, status: ListingStatus) {
    setListings((prev) =>
      prev.map((a) => (a.id === asset.id ? { ...a, listing_status: status } : a))
    );
    await updateAsset(asset.id, { listing_status: status });
  }

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-4 sm:max-w-md">
        <div className="card p-4">
          <div className="text-sm text-slate-500">Active value</div>
          <div className="mt-1 text-2xl font-bold text-blue-700">{fmt(activeValue)}</div>
        </div>
        <div className="card p-4">
          <div className="text-sm text-slate-500">Sold</div>
          <div className="mt-1 text-2xl font-bold text-green-700">{fmt(soldValue)}</div>
        </div>
      </div>

      <div className="flex flex-wrap gap-1">
        {TABS.map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={
              "rounded-lg px-3 py-1.5 text-sm font-medium transition " +
              (tab === t.key ? "bg-brand-100 text-brand-700" : "text-slate-600 hover:bg-slate-100")
            }
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="border-b border-slate-200 text-left text-slate-500">
            <tr>
              <th className="px-4 py-3 font-medium">Item</th>
              <th className="px-4 py-3 font-medium">Location</th>
              <th className="px-4 py-3 text-right font-medium">Price</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Ad</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtered.map((a) => (
              <tr key={a.id} className="hover:bg-slate-50">
                <td className="px-4 py-3">
                  <div className="font-medium text-slate-900">{a.listing_title || a.name}</div>
                  <div className="text-xs text-slate-500">{a.category}</div>
                </td>
                <td className="px-4 py-3 text-slate-500">
                  {[a.property_name, a.room_name].filter(Boolean).join(" · ") || "—"}
                </td>
                <td className="px-4 py-3 text-right text-slate-900">
                  {a.listing_status === "sold"
                    ? a.sold_price != null
                      ? fmt(a.sold_price)
                      : "—"
                    : a.asking_price != null
                      ? fmt(a.asking_price)
                      : a.estimated_value != null
                        ? fmt(a.estimated_value)
                        : "—"}
                </td>
                <td className="px-4 py-3">
                  <select
                    className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm"
                    value={a.listing_status}
                    onChange={(e) => changeStatus(a, e.target.value as ListingStatus)}
                  >
                    {NEXT_STATUSES.map((s) => (
                      <option key={s} value={s}>
                        {LISTING_LABELS[s]}
                      </option>
                    ))}
                  </select>
                </td>
                <td className="px-4 py-3">
                  {a.listing_url ? (
                    <a href={a.listing_url} target="_blank" rel="noreferrer" className="text-brand-700 hover:underline">
                      View ↗
                    </a>
                  ) : (
                    <span className="text-slate-400">—</span>
                  )}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                  Nothing here yet. Prepare a listing in the app to see it appear.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
