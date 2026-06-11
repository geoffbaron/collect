"use client";

import { useTransition } from "react";
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
  const router = useRouter();

  function handleChange(next: boolean) {
    start(async () => {
      await updateMaintenanceScheduleActive(scheduleId, propertyId, next);
      router.refresh();
    });
  }

  return (
    <div>
      <label className="label">Status</label>
      <select
        className="input max-w-xs"
        value={active ? "active" : "inactive"}
        disabled={pending}
        onChange={(e) => handleChange(e.target.value === "active")}
      >
        <option value="active">Active</option>
        <option value="inactive">Inactive</option>
      </select>
    </div>
  );
}
