"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { updateMaintenanceScheduleActive } from "@/lib/actions";

export default function ActiveToggle({
  scheduleId,
  propertyId,
  active,
}: {
  scheduleId: string;
  propertyId: string;
  active: boolean;
}) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function handleChange(next: boolean) {
    setError(null);
    start(async () => {
      const result = await updateMaintenanceScheduleActive(scheduleId, propertyId, next);
      if (!result.ok) { setError(result.error ?? "Failed to update status."); return; }
      router.refresh();
    });
  }

  return (
    <div>
      <label className="label" htmlFor="ms-active">Status</label>
      <select
        id="ms-active"
        className="input max-w-xs"
        value={active ? "active" : "inactive"}
        disabled={pending}
        onChange={(e) => handleChange(e.target.value === "active")}
      >
        <option value="active">Active</option>
        <option value="inactive">Inactive</option>
      </select>
      {error && <p className="mt-1 text-sm text-red-600">{error}</p>}
    </div>
  );
}
