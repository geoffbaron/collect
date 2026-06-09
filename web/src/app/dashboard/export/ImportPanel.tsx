"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { importBackup } from "@/lib/actions";

export function ImportPanel() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setBusy(true);
    setResult(null);
    setError(null);

    try {
      const text = await file.text();
      const res = await importBackup(text);
      if (!res.ok) {
        setError(res.error ?? "Import failed.");
      } else {
        const c = res.counts!;
        setResult(
          `Imported ${c.assets} items across ${c.properties} properties, ${c.rooms} rooms.`
        );
        router.refresh();
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not read that file.");
    } finally {
      setBusy(false);
      e.target.value = "";
    }
  }

  return (
    <section className="card p-6">
      <h2 className="text-lg font-semibold text-slate-900">Restore from backup</h2>
      <p className="mt-1 text-sm text-slate-600">
        Restore a full JSON backup exported from Collect. New IDs are generated, so importing never overwrites
        existing data — it adds a fresh copy. (Photos aren&apos;t included in JSON backups.)
      </p>

      <label className="mt-4 inline-flex cursor-pointer items-center gap-2 rounded-lg border border-dashed border-slate-300 bg-slate-50 px-4 py-3 text-sm font-medium text-slate-700 hover:bg-slate-100">
        <input type="file" accept="application/json,.json" className="hidden" onChange={handleFile} disabled={busy} />
        {busy ? "Importing…" : "Choose a backup file (.json)"}
      </label>

      {result && <p className="mt-3 rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700">{result}</p>}
      {error && <p className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}
    </section>
  );
}
