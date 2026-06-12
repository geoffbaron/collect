"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { createWorkOrder } from "@/lib/actions";

/**
 * One-click work order from an inspection finding. Prefills the ticket from
 * the flagged item and links it back via source_inspection_id.
 */
export default function CreateWorkOrderButton({
  propertyId,
  buildingId,
  unitId,
  inspectionId,
  itemName,
  roomName,
  isMissing,
}: {
  propertyId: string;
  buildingId: string;
  unitId: string;
  inspectionId: string;
  itemName: string;
  roomName: string;
  isMissing: boolean;
}) {
  const [createdId, setCreatedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  function handleCreate() {
    setError(null);
    start(async () => {
      const result = await createWorkOrder({
        propertyId,
        buildingId,
        unitId,
        title: isMissing ? `Replace missing ${itemName}` : `Repair ${itemName}`,
        description: `${isMissing ? "Missing" : "Damaged"} at move-out inspection — ${roomName}.`,
        category: "other",
        priority: "medium",
        sourceInspectionId: inspectionId,
      });
      if (!result.ok || !result.workOrder) {
        setError(result.error ?? "Failed to create work order.");
        return;
      }
      setCreatedId(result.workOrder.id);
    });
  }

  if (createdId) {
    return (
      <Link
        href={`/dashboard/portfolio/${propertyId}/work-orders/${createdId}`}
        className="text-xs font-medium text-brand hover:underline"
      >
        View work order →
      </Link>
    );
  }

  return (
    <span className="inline-flex items-center gap-2">
      <button
        type="button"
        onClick={handleCreate}
        disabled={pending}
        className="rounded-md border border-slate-200 px-2 py-1 text-xs font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-60"
      >
        {pending ? "Creating…" : "Create work order"}
      </button>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </span>
  );
}
