"use client";

import { useRef, useState, useTransition } from "react";
import { createUnit, importUnitsFromCsv } from "@/lib/actions";
import { useRouter } from "next/navigation";

export default function UnitActions({
  propertyId,
  buildingId,
}: {
  propertyId: string;
  buildingId: string;
}) {
  const router = useRouter();
  const [addPending, startAdd] = useTransition();
  const [csvPending, startCsv] = useTransition();
  const [addError, setAddError] = useState<string | null>(null);
  const [csvResult, setCsvResult] = useState<{ ok: boolean; message: string } | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  async function handleAddUnit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setAddError(null);
    const fd = new FormData(e.currentTarget);
    const unitNumber = (fd.get("unit_number") as string).trim();
    if (!unitNumber) return;
    startAdd(async () => {
      const result = await createUnit({
        propertyId,
        buildingId,
        unitNumber,
        floorNumber: fd.get("floor_number") ? Number(fd.get("floor_number")) : null,
        bedrooms: fd.get("bedrooms") ? Number(fd.get("bedrooms")) : null,
        bathrooms: fd.get("bathrooms") ? Number(fd.get("bathrooms")) : null,
        sqft: fd.get("sqft") ? Number(fd.get("sqft")) : null,
      });
      if (!result.ok) setAddError(result.error ?? "Failed to add unit.");
      else (e.target as HTMLFormElement).reset();
    });
  }

  async function handleCsvImport(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setCsvResult(null);
    const text = await file.text();
    startCsv(async () => {
      const result = await importUnitsFromCsv(propertyId, buildingId, text);
      setCsvResult({
        ok: result.ok,
        message: result.ok
          ? `Imported ${result.count} unit${result.count !== 1 ? "s" : ""} successfully.`
          : result.error ?? "Import failed.",
      });
      if (fileRef.current) fileRef.current.value = "";
    });
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2">
      {/* Add single unit */}
      <div className="card p-5">
        <h2 className="mb-4 font-semibold text-slate-900">Add Unit</h2>
        <form onSubmit={handleAddUnit} className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Unit #</label>
              <input name="unit_number" required placeholder="101" className="input w-full" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Floor</label>
              <input name="floor_number" type="number" placeholder="1" className="input w-full" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Beds</label>
              <input name="bedrooms" type="number" step="0.5" placeholder="2" className="input w-full" />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Baths</label>
              <input name="bathrooms" type="number" step="0.5" placeholder="1" className="input w-full" />
            </div>
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Sqft (optional)</label>
            <input name="sqft" type="number" placeholder="850" className="input w-full" />
          </div>
          {addError && <p className="text-sm text-red-600">{addError}</p>}
          <button type="submit" disabled={addPending} className="btn-primary w-full">
            {addPending ? "Adding…" : "Add Unit"}
          </button>
        </form>
      </div>

      {/* CSV bulk import */}
      <div className="card p-5">
        <h2 className="mb-1 font-semibold text-slate-900">Bulk Import via CSV</h2>
        <p className="mb-4 text-sm text-slate-500">
          CSV columns (header required):{" "}
          <code className="rounded bg-slate-100 px-1 text-xs">
            unit_number, floor_number, bedrooms, bathrooms, sqft
          </code>
        </p>
        <a
          href="data:text/csv;charset=utf-8,unit_number%2Cfloor_number%2Cbedrooms%2Cbathrooms%2Csqft%0A101%2C1%2C2%2C1%2C750%0A102%2C1%2C1%2C1%2C600"
          download="units_template.csv"
          className="mb-4 inline-block text-sm text-brand hover:underline"
        >
          Download template
        </a>
        <label className="block">
          <input
            ref={fileRef}
            type="file"
            accept=".csv,text/csv"
            onChange={handleCsvImport}
            disabled={csvPending}
            className="block w-full text-sm text-slate-600
              file:mr-3 file:cursor-pointer file:rounded file:border-0
              file:bg-slate-100 file:px-3 file:py-1.5 file:text-sm
              file:font-medium file:text-slate-700
              hover:file:bg-slate-200"
          />
        </label>
        {csvPending && <p className="mt-2 text-sm text-slate-500">Importing…</p>}
        {csvResult && (
          <p className={`mt-2 text-sm ${csvResult.ok ? "text-green-700" : "text-red-600"}`}>
            {csvResult.message}
          </p>
        )}
      </div>
    </div>
  );
}
