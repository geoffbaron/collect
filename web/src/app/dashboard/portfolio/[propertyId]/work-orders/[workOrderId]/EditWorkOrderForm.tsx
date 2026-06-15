"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { deleteWorkOrder, updateWorkOrder } from "@/lib/actions";
import {
  WORK_ORDER_CATEGORY_LABELS,
  WORK_ORDER_PRIORITY_LABELS,
  type TeamMember,
  type WorkOrder,
  type WorkOrderCategory,
  type WorkOrderPriority,
} from "@/lib/types";

const CATEGORIES = Object.entries(WORK_ORDER_CATEGORY_LABELS) as [WorkOrderCategory, string][];
const PRIORITIES = Object.entries(WORK_ORDER_PRIORITY_LABELS) as [WorkOrderPriority, string][];

export default function EditWorkOrderForm({
  workOrder,
  propertyId,
  members,
}: {
  workOrder: WorkOrder;
  propertyId: string;
  members: TeamMember[];
}) {
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState(workOrder.title);
  const [description, setDescription] = useState(workOrder.description);
  const [category, setCategory] = useState<WorkOrderCategory>(workOrder.category);
  const [priority, setPriority] = useState<WorkOrderPriority>(workOrder.priority);
  const [dueDate, setDueDate] = useState(workOrder.due_date ?? "");
  const [assignedTo, setAssignedTo] = useState(workOrder.assigned_to ?? "");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const result = await updateWorkOrder(workOrder.id, propertyId, {
        title,
        description,
        category,
        priority,
        dueDate: dueDate || null,
        assignedTo: assignedTo || null,
      });
      if (!result.ok) { setError(result.error ?? "Failed to update work order."); return; }
      setEditing(false);
      router.refresh();
    });
  }

  function handleDelete() {
    if (!confirm("Delete this work order? This cannot be undone.")) return;
    setError(null);
    start(async () => {
      const result = await deleteWorkOrder(workOrder.id, propertyId);
      if (!result.ok) { setError(result.error ?? "Failed to delete work order."); return; }
      router.push(`/dashboard/portfolio/${propertyId}/work-orders`);
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
        <label className="label" htmlFor="edit-wo-title">Title</label>
        <input id="edit-wo-title" className="input" value={title} onChange={(e) => setTitle(e.target.value)} required />
      </div>

      <div>
        <label className="label" htmlFor="edit-wo-description">Description</label>
        <textarea id="edit-wo-description" className="input" rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div>
          <label className="label" htmlFor="edit-wo-category">Category</label>
          <select id="edit-wo-category" className="input" value={category} onChange={(e) => setCategory(e.target.value as WorkOrderCategory)}>
            {CATEGORIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="edit-wo-priority">Priority</label>
          <select id="edit-wo-priority" className="input" value={priority} onChange={(e) => setPriority(e.target.value as WorkOrderPriority)}>
            {PRIORITIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="edit-wo-due-date">Due Date</label>
          <input id="edit-wo-due-date" className="input" type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} />
        </div>
      </div>

      <div>
        <label className="label" htmlFor="edit-wo-assignee">Assign To</label>
        <select id="edit-wo-assignee" className="input" value={assignedTo} onChange={(e) => setAssignedTo(e.target.value)}>
          <option value="">Unassigned</option>
          {members.map((m) => (
            <option key={m.user_id} value={m.user_id}>{m.name || m.email || "Unknown"}</option>
          ))}
        </select>
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
