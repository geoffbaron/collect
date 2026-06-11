"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createMaintenanceSchedule } from "@/lib/actions";
import {
  MAINTENANCE_FREQUENCY_LABELS,
  WORK_ORDER_CATEGORY_LABELS,
  type Building,
  type CommonArea,
  type MaintenanceFrequency,
  type Unit,
  type WorkOrderCategory,
} from "@/lib/types";
import { localDateString } from "@/lib/dates";
import LocationSelect, { parseLocationValue } from "@/components/LocationSelect";

const CATEGORIES = Object.entries(WORK_ORDER_CATEGORY_LABELS) as [WorkOrderCategory, string][];
const FREQUENCIES = Object.entries(MAINTENANCE_FREQUENCY_LABELS) as [MaintenanceFrequency, string][];

export default function NewMaintenanceScheduleForm({
  propertyId,
  buildings,
  units,
  commonAreas,
}: {
  propertyId: string;
  buildings: Building[];
  units: Unit[];
  commonAreas: CommonArea[];
}) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<WorkOrderCategory>("other");
  const [frequency, setFrequency] = useState<MaintenanceFrequency>("monthly");
  const [nextDueDate, setNextDueDate] = useState("");
  const [location, setLocation] = useState("property");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    start(async () => {
      const target = parseLocationValue(location, units, commonAreas);
      const result = await createMaintenanceSchedule({
        propertyId,
        title,
        description,
        category,
        frequency,
        nextDueDate: nextDueDate || localDateString(),
        ...target,
      });
      if (!result.ok) { setError(result.error ?? "Failed to create schedule."); return; }
      setTitle("");
      setDescription("");
      setCategory("other");
      setFrequency("monthly");
      setNextDueDate("");
      setLocation("property");
      router.refresh();
    });
  }

  return (
    <form onSubmit={handleSubmit} className="card space-y-4 p-5">
      <h2 className="font-semibold text-slate-900">New Maintenance Schedule</h2>

      <div>
        <label className="label" htmlFor="ms-title">Title</label>
        <input id="ms-title" className="input" value={title} onChange={(e) => setTitle(e.target.value)} required />
      </div>

      <div>
        <label className="label" htmlFor="ms-description">Description</label>
        <input id="ms-description" className="input" value={description} onChange={(e) => setDescription(e.target.value)} />
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div>
          <label className="label" htmlFor="ms-category">Category</label>
          <select id="ms-category" className="input" value={category} onChange={(e) => setCategory(e.target.value as WorkOrderCategory)}>
            {CATEGORIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="ms-frequency">Frequency</label>
          <select id="ms-frequency" className="input" value={frequency} onChange={(e) => setFrequency(e.target.value as MaintenanceFrequency)}>
            {FREQUENCIES.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label" htmlFor="ms-next-due">Next Due</label>
          <input id="ms-next-due" className="input" type="date" value={nextDueDate} onChange={(e) => setNextDueDate(e.target.value)} />
        </div>
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
        {pending ? "Creating…" : "Create Schedule"}
      </button>
    </form>
  );
}
