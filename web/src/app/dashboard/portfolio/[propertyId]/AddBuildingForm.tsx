"use client";

import { useTransition } from "react";
import { createBuilding } from "@/lib/actions";
import { useRouter } from "next/navigation";

export default function AddBuildingForm({ propertyId }: { propertyId: string }) {
  const [pending, start] = useTransition();
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const name = (fd.get("name") as string).trim();
    if (!name) return;
    start(async () => {
      const result = await createBuilding(propertyId, name, (fd.get("address") as string) ?? "");
      if (result.ok && result.building) {
        router.push(`/dashboard/portfolio/${propertyId}/${result.building.id}`);
      }
    });
  }

  return (
    <div className="card p-5">
      <h2 className="mb-4 font-semibold text-slate-900">Add Building</h2>
      <form onSubmit={handleSubmit} className="flex flex-col gap-3 sm:flex-row sm:items-end">
        <div className="flex-1">
          <label className="mb-1 block text-sm font-medium text-slate-700">Name</label>
          <input
            name="name"
            required
            placeholder="Building A"
            className="input w-full"
          />
        </div>
        <div className="flex-1">
          <label className="mb-1 block text-sm font-medium text-slate-700">Address (optional)</label>
          <input
            name="address"
            placeholder="123 Main St"
            className="input w-full"
          />
        </div>
        <button type="submit" disabled={pending} className="btn-primary shrink-0">
          {pending ? "Adding…" : "Add Building"}
        </button>
      </form>
    </div>
  );
}
