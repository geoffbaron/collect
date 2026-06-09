"use client";

import { useState, useTransition } from "react";
import { createInspection } from "@/lib/actions";
import type { InspectionType } from "@/lib/types";
import { useRouter } from "next/navigation";

const TYPES: { value: InspectionType; label: string; desc: string }[] = [
  { value: "move_in",  label: "Move-In",  desc: "Document unit condition at tenant move-in" },
  { value: "move_out", label: "Move-Out", desc: "Compare against move-in to find damage" },
  { value: "routine",  label: "Routine",  desc: "Scheduled periodic walkthrough" },
  { value: "turn",     label: "Turn",     desc: "Between-tenant cleaning and prep check" },
];

export default function StartInspectionForm({
  unitId,
  propertyId,
  buildingId,
  lastMoveInId,
}: {
  unitId: string;
  propertyId: string;
  buildingId: string;
  lastMoveInId: string | null;
}) {
  const [type, setType] = useState<InspectionType>("move_in");
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function handleStart() {
    setError(null);
    const baselineId = type === "move_out" ? lastMoveInId : null;
    start(async () => {
      const result = await createInspection(unitId, type, baselineId);
      if (!result.ok) { setError(result.error ?? "Failed to start inspection."); return; }
      router.push(`/dashboard/portfolio/${propertyId}/${buildingId}/${unitId}/${result.inspection.id}`);
    });
  }

  return (
    <div className="card p-5">
      <h2 className="mb-4 font-semibold text-slate-900">Start New Inspection</h2>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 mb-4">
        {TYPES.map((t) => (
          <button
            key={t.value}
            type="button"
            onClick={() => setType(t.value)}
            className={`rounded-lg border p-3 text-left transition-colors ${
              type === t.value
                ? "border-brand bg-brand/5 ring-2 ring-brand"
                : "border-slate-200 hover:border-slate-300"
            }`}
          >
            <div className="font-medium text-slate-900">{t.label}</div>
            <div className="mt-0.5 text-xs text-slate-500">{t.desc}</div>
          </button>
        ))}
      </div>

      {type === "move_out" && !lastMoveInId && (
        <p className="mb-3 rounded bg-amber-50 px-3 py-2 text-sm text-amber-700">
          No completed move-in inspection found. The report won't have a baseline to diff against.
        </p>
      )}
      {type === "move_out" && lastMoveInId && (
        <p className="mb-3 rounded bg-green-50 px-3 py-2 text-sm text-green-700">
          Will diff against the last completed move-in inspection.
        </p>
      )}

      {error && <p className="mb-3 text-sm text-red-600">{error}</p>}

      <button onClick={handleStart} disabled={pending} className="btn-primary">
        {pending ? "Starting…" : "Start Inspection"}
      </button>
    </div>
  );
}
