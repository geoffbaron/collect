import { ImportPanel } from "./ImportPanel";

export const dynamic = "force-dynamic";

export default function ExportPage() {
  return (
    <div className="max-w-3xl space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Import / Export</h1>
        <p className="text-slate-500">Take your data with you — no lock-in.</p>
      </div>

      <section className="card p-6">
        <h2 className="text-lg font-semibold text-slate-900">Export</h2>
        <p className="mt-1 text-sm text-slate-600">
          Download your inventory. CSV is a flat list of items (great for spreadsheets); the JSON backup contains
          your full structure and can be re-imported.
        </p>
        <div className="mt-4 flex flex-wrap gap-3">
          <a href="/api/export/items" className="btn-primary">
            ⬇ Export items (CSV)
          </a>
          <a href="/api/export/backup" className="btn-ghost">
            ⬇ Export full backup (JSON)
          </a>
        </div>
      </section>

      <ImportPanel />
    </div>
  );
}
