"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createWorkOrder } from "@/lib/actions";
import {
  WORK_ORDER_CATEGORY_LABELS,
  WORK_ORDER_PRIORITY_LABELS,
  type WorkOrderCategory,
  type WorkOrderPriority,
} from "@/lib/types";

const CATEGORIES = Object.entries(WORK_ORDER_CATEGORY_LABELS) as [WorkOrderCategory, string][];
const PRIORITIES = Object.entries(WORK_ORDER_PRIORITY_LABELS) as [WorkOrderPriority, string][];

export default function NewWorkOrderForm({ propertyId }: { propertyId: string }) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<WorkOrderCategory>("other");
  const [priority, setPriority] = useState<WorkOrderPriority>("medium");
  const [dueDate, setDueDate] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const result = await createWorkOrder({
        propertyId,
        title,
        description,
        category,
        priority,
        dueDate: dueDate || null,
      });
      if (!result.ok) { setError(result.error ?? "Failed to create work order."); return; }
      setTitle("");
      setDescription("");
      setCategory("other");
      setPriority("medium");
      setDueDate("");
      router.refresh();
    });
  }

  return (
    <form onSubmit={handleSubmit} className="card space-y-4 p-5">
      <h2 className="font-semibold text-slate-900">New Work Order</h2>

      <div>
        <label className="label">Title</label>
        <input className="input" value={title} onChange={(e) => setTitle(e.target.value)} required />
      </div>

      <div>
        <label className="label">Description</label>
        <textarea className="input" rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div>
          <label className="label">Category</label>
          <select className="input" value={category} onChange={(e) => setCategory(e.target.value as WorkOrderCategory)}>
            {CATEGORIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label">Priority</label>
          <select className="input" value={priority} onChange={(e) => setPriority(e.target.value as WorkOrderPriority)}>
            {PRIORITIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label">Due Date</label>
          <input className="input" type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} />
        </div>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <button type="submit" disabled={pending} className="btn-primary">
        {pending ? "Creating…" : "Create Work Order"}
      </button>
    </form>
  );
}
