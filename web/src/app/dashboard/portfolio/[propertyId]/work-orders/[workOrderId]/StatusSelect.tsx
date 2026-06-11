"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { updateWorkOrderStatus } from "@/lib/actions";
import { WORK_ORDER_STATUS_LABELS, type WorkOrderStatus } from "@/lib/types";

const STATUSES = Object.entries(WORK_ORDER_STATUS_LABELS) as [WorkOrderStatus, string][];

export default function StatusSelect({
  workOrderId,
  propertyId,
  status,
}: {
  workOrderId: string;
  propertyId: string;
  status: WorkOrderStatus;
}) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function handleChange(next: WorkOrderStatus) {
    setError(null);
    start(async () => {
      const result = await updateWorkOrderStatus(workOrderId, propertyId, next);
      if (!result.ok) { setError(result.error ?? "Failed to update status."); return; }
      router.refresh();
    });
  }

  return (
    <div>
      <label className="label" htmlFor="wo-status">Status</label>
      <select
        id="wo-status"
        className="input max-w-xs"
        value={status}
        disabled={pending}
        onChange={(e) => handleChange(e.target.value as WorkOrderStatus)}
      >
        {STATUSES.map(([value, label]) => (
          <option key={value} value={value}>{label}</option>
        ))}
      </select>
      {error && <p className="mt-1 text-sm text-red-600">{error}</p>}
    </div>
  );
}
