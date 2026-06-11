"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { deleteMaintenanceSchedule, updateMaintenanceSchedule } from "@/lib/actions";
import {
  MAINTENANCE_FREQUENCY_LABELS,
  WORK_ORDER_CATEGORY_LABELS,
  type MaintenanceFrequency,
  type MaintenanceSchedule,
  type WorkOrderCategory,
} from "@/lib/types";

const CATEGORIES = Object.entries(WORK_ORDER_CATEGORY_LABELS) as [WorkOrderCategory, string][];
const FREQUENCIES = Object.entries(MAINTENANCE_FREQUENCY_LABELS) as [MaintenanceFrequency, string][];

export default function EditMaintenanceScheduleForm({ schedule, propertyId }: { schedule: MaintenanceSchedule; propertyId: string }) {
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState(schedule.title);
  const [description, setDescription] = useState(schedule.description);
  const [category, setCategory] = useState<WorkOrderCategory>(schedule.category);
  const [frequency, setFrequency] = useState<MaintenanceFrequency>(schedule.frequency);
  const [nextDueDate, setNextDueDate] = useState(schedule.next_due_date);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const result = await updateMaintenanceSchedule(schedule.id, propertyId, {
        title,
        description,
        category,
        frequency,
        nextDueDate,
      });
      if (!result.ok) { setError(result.error ?? "Failed to update schedule."); return; }
      setEditing(false);
      router.refresh();
    });
  }

  function handleDelete() {
    if (!confirm("Delete this maintenance schedule? This cannot be undone.")) return;
    setError(null);
    start(async () => {
      const result = await deleteMaintenanceSchedule(schedule.id, propertyId);
      if (!result.ok) { setError(result.error ?? "Failed to delete schedule."); return; }
      router.push(`/dashboard/portfolio/${propertyId}/maintenance-schedules`);
    });
  }

  if (!editing) {
    return (
      <div className="flex items-center gap-3">
        <button type="button" onClick={() => setEditing(true)} className="btn-ghost">Edit</button>
        <button type="button" onClick={handleDelete} disabled={pending} className="btn-ghost text-red-600">
          {pending ? "Deleting…" : "Delete"}
        </button>
        {error && <p className="text-sm text-red-600">{error}</p>}
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4 border-t border-slate-200 pt-4">
      <div>
        <label className="label" htmlFor="edit-ms-title">Title</label>
        <input id="edit-ms-title" className="input" value={title} onChange={(e) => setTitle(e.target.value)} required />
      </div>

      <div>
        <label className="label" htmlFor="edit-ms-description">Description</label>
        <textarea id="edit-ms-description" className="input" rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div>
          <label className="label" htmlFor="edit-ms-category">Category</label>
          <select id="edit-ms-category" className="input" value={category} onChange={(e) => setCategory(e.target.value as WorkOrderCategory)}>
            {CATEGORIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="edit-ms-frequency">Frequency</label>
          <select id="edit-ms-frequency" className="input" value={frequency} onChange={(e) => setFrequency(e.target.value as MaintenanceFrequency)}>
            {FREQUENCIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="edit-ms-next-due">Next Due Date</label>
          <input id="edit-ms-next-due" className="input" type="date" value={nextDueDate} onChange={(e) => setNextDueDate(e.target.value)} required />
        </div>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="flex items-center gap-3">
        <button type="submit" disabled={pending} className="btn-primary">
          {pending ? "Saving…" : "Save"}
        </button>
        <button type="button" onClick={() => setEditing(false)} className="btn-ghost">Cancel</button>
      </div>
    </form>
  );
}
