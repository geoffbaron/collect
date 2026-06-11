"use client";

import { useTransition } from "react";
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
  const router = useRouter();

  function handleChange(next: WorkOrderStatus) {
    start(async () => {
      await updateWorkOrderStatus(workOrderId, propertyId, next);
      router.refresh();
    });
  }

  return (
    <div>
      <label className="label">Status</label>
      <select
        className="input max-w-xs"
        value={status}
        disabled={pending}
        onChange={(e) => handleChange(e.target.value as WorkOrderStatus)}
      >
        {STATUSES.map(([value, label]) => (
          <option key={value} value={value}>{label}</option>
        ))}
      </select>
    </div>
  );
}
