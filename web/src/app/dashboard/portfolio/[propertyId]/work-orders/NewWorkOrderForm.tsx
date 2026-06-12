"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createWorkOrder } from "@/lib/actions";
import {
  WORK_ORDER_CATEGORY_LABELS,
  WORK_ORDER_PRIORITY_LABELS,
  type Building,
  type CommonArea,
  type TeamMember,
  type Unit,
  type WorkOrderCategory,
  type WorkOrderPriority,
} from "@/lib/types";
import LocationSelect, { parseLocationValue } from "@/components/LocationSelect";

const CATEGORIES = Object.entries(WORK_ORDER_CATEGORY_LABELS) as [WorkOrderCategory, string][];
const PRIORITIES = Object.entries(WORK_ORDER_PRIORITY_LABELS) as [WorkOrderPriority, string][];

export default function NewWorkOrderForm({
  propertyId,
  buildings,
  units,
  commonAreas,
  members,
}: {
  propertyId: string;
  buildings: Building[];
  units: Unit[];
  commonAreas: CommonArea[];
  members: TeamMember[];
}) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<WorkOrderCategory>("other");
  const [priority, setPriority] = useState<WorkOrderPriority>("medium");
  const [dueDate, setDueDate] = useState("");
  const [assignedTo, setAssignedTo] = useState("");
  const [location, setLocation] = useState("property");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const target = parseLocationValue(location, units, commonAreas);
      const result = await createWorkOrder({
        propertyId,
        title,
        description,
        category,
        priority,
        dueDate: dueDate || null,
        assignedTo: assignedTo || null,
        ...target,
      });
      if (!result.ok) { setError(result.error ?? "Failed to create work order."); return; }
      setTitle("");
      setDescription("");
      setCategory("other");
      setPriority("medium");
      setDueDate("");
      setAssignedTo("");
      setLocation("property");
      router.refresh();
    });
  }

  return (
    <form onSubmit={handleSubmit} className="card space-y-4 p-5">
      <h2 className="font-semibold text-slate-900">New Work Order</h2>

      <div>
        <label className="label" htmlFor="wo-title">Title</label>
        <input id="wo-title" className="input" value={title} onChange={(e) => setTitle(e.target.value)} required />
      </div>

      <div>
        <label className="label" htmlFor="wo-description">Description</label>
        <textarea id="wo-description" className="input" rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div>
          <label className="label" htmlFor="wo-category">Category</label>
          <select id="wo-category" className="input" value={category} onChange={(e) => setCategory(e.target.value as WorkOrderCategory)}>
            {CATEGORIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="wo-priority">Priority</label>
          <select id="wo-priority" className="input" value={priority} onChange={(e) => setPriority(e.target.value as WorkOrderPriority)}>
            {PRIORITIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="wo-due-date">Due Date</label>
          <input id="wo-due-date" className="input" type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} />
        </div>
      </div>

      <div>
        <label className="label" htmlFor="wo-assignee">Assign To</label>
        <select id="wo-assignee" className="input" value={assignedTo} onChange={(e) => setAssignedTo(e.target.value)}>
          <option value="">Unassigned</option>
          {members.map((m) => (
            <option key={m.user_id} value={m.user_id}>{m.name || m.email || "Unknown"}</option>
          ))}
        </select>
      </div>

      <LocationSelect
        value={location}
        onChange={setLocation}
        buildings={buildings}
        units={units}
        commonAreas={commonAreas}
      />

      {error && <p className="text-sm text-red-600">{error}</p>}

      <button type="submit" disabled={pending} className="btn-primary">
        {pending ? "Creating…" : "Create Work Order"}
      </button>
    </form>
  );
}
