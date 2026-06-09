"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { parseCSV } from "@/lib/csv";
import { importItemsFromCsv, type ImportCsvRow } from "@/lib/actions";

type FieldKey = keyof ImportCsvRow;

const FIELDS: { key: FieldKey; label: string; hint?: string; required?: boolean }[] = [
  { key: "name", label: "Item name", required: true },
  { key: "property", label: "Property", hint: 'Defaults to "Imported Items"' },
  { key: "floor", label: "Floor", hint: 'Defaults to "Main Floor"' },
  { key: "room", label: "Room", hint: 'Defaults to "Imported"' },
  { key: "category", label: "Category" },
  { key: "description", label: "Description" },
  { key: "condition", label: "Condition" },
  { key: "quantity", label: "Quantity" },
  { key: "estimated_value", label: "Estimated value" },
  { key: "listing_status", label: "Listing status" },
  { key: "asking_price", label: "Asking price" },
];

const DONT_IMPORT = "__skip__";

/** Best-effort guess of which CSV column maps to which field, based on header text. */
function guessMapping(headers: string[]): Record<FieldKey, number | null> {
  const norm = (s: string) => s.trim().toLowerCase().replace(/[^a-z0-9]/g, "");
  const aliases: Record<FieldKey, string[]> = {
    name: ["name", "item", "itemname", "title"],
    property: ["property", "home", "address", "propertyname"],
    floor: ["floor", "level"],
    room: ["room", "location", "roomname"],
    category: ["category", "type"],
    description: ["description", "desc", "notes"],
    condition: ["condition"],
    quantity: ["quantity", "qty", "count"],
    estimated_value: ["estimatedvalue", "value", "price", "worth"],
    listing_status: ["listingstatus", "status"],
    asking_price: ["askingprice", "askprice"],
  };

  const normalizedHeaders = headers.map(norm);
  const mapping = {} as Record<FieldKey, number | null>;
  for (const field of FIELDS) {
    const idx = normalizedHeaders.findIndex((h) => aliases[field.key].includes(h));
    mapping[field.key] = idx;
  }
  return mapping;
}

type Step = "upload" | "map" | "done";

export function CsvImportWizard() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("upload");
  const [headers, setHeaders] = useState<string[]>([]);
  const [dataRows, setDataRows] = useState<string[][]>([]);
  const [mapping, setMapping] = useState<Record<FieldKey, number | null>>(
    {} as Record<FieldKey, number | null>
  );
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(null);
    setResult(null);

    try {
      const text = await file.text();
      const rows = parseCSV(text);
      if (rows.length < 2) {
        setError("That CSV needs a header row and at least one item row.");
        return;
      }
      const [header, ...body] = rows;
      setHeaders(header);
      setDataRows(body);
      setMapping(guessMapping(header));
      setStep("map");
    } catch {
      setError("Couldn't read that file.");
    } finally {
      e.target.value = "";
    }
  }

  const previewRows = useMemo(() => dataRows.slice(0, 5), [dataRows]);

  const mappedRows = useMemo<ImportCsvRow[]>(() => {
    const get = (cells: string[], field: FieldKey) => {
      const idx = mapping[field];
      return idx == null || idx < 0 ? "" : (cells[idx] ?? "");
    };
    return dataRows.map((cells) => ({
      property: get(cells, "property"),
      floor: get(cells, "floor"),
      room: get(cells, "room"),
      name: get(cells, "name"),
      category: get(cells, "category"),
      description: get(cells, "description"),
      condition: get(cells, "condition"),
      quantity: get(cells, "quantity"),
      estimated_value: get(cells, "estimated_value"),
      listing_status: get(cells, "listing_status"),
      asking_price: get(cells, "asking_price"),
    }));
  }, [dataRows, mapping]);

  const nameMapped = mapping.name != null && mapping.name >= 0;
  const itemCount = mappedRows.filter((r) => r.name.trim()).length;

  function handleImport() {
    setError(null);
    startTransition(async () => {
      const res = await importItemsFromCsv(mappedRows);
      if (!res.ok) {
        setError(res.error ?? "Import failed.");
        return;
      }
      const c = res.counts!;
      const extras: string[] = [];
      if (c.newProperties) extras.push(`${c.newProperties} new propert${c.newProperties === 1 ? "y" : "ies"}`);
      if (c.newFloors) extras.push(`${c.newFloors} new floor${c.newFloors === 1 ? "" : "s"}`);
      if (c.newRooms) extras.push(`${c.newRooms} new room${c.newRooms === 1 ? "" : "s"}`);
      setResult(
        `Imported ${c.items} item${c.items === 1 ? "" : "s"}` +
          (extras.length ? ` — created ${extras.join(", ")}.` : ".")
      );
      setStep("done");
      router.refresh();
    });
  }

  function reset() {
    setStep("upload");
    setHeaders([]);
    setDataRows([]);
    setMapping({} as Record<FieldKey, number | null>);
    setError(null);
    setResult(null);
  }

  return (
    <section className="card p-6">
      <h2 className="text-lg font-semibold text-slate-900">Import items from CSV</h2>
      <p className="mt-1 text-sm text-slate-600">
        Bring in items from a spreadsheet or another inventory tool. Upload a CSV, match its columns to
        Collect&apos;s fields, and we&apos;ll create any properties, floors, or rooms that don&apos;t
        exist yet.
      </p>

      {step === "upload" && (
        <label className="mt-4 inline-flex cursor-pointer items-center gap-2 rounded-lg border border-dashed border-slate-300 bg-slate-50 px-4 py-3 text-sm font-medium text-slate-700 hover:bg-slate-100">
          <input type="file" accept=".csv,text/csv" className="hidden" onChange={handleFile} />
          Choose a CSV file
        </label>
      )}

      {step === "map" && (
        <div className="mt-4 space-y-5">
          <div>
            <h3 className="text-sm font-semibold text-slate-900">1. Match your columns</h3>
            <p className="mt-0.5 text-xs text-slate-500">
              We guessed based on your headers — adjust anything that&apos;s wrong. &quot;Item name&quot;
              is required.
            </p>
            <div className="mt-3 grid gap-2.5 sm:grid-cols-2">
              {FIELDS.map((f) => (
                <div key={f.key} className="flex items-center justify-between gap-3 rounded-lg border border-slate-200 px-3 py-2">
                  <div>
                    <div className="text-sm font-medium text-slate-900">
                      {f.label}
                      {f.required && <span className="text-red-500"> *</span>}
                    </div>
                    {f.hint && <div className="text-xs text-slate-400">{f.hint}</div>}
                  </div>
                  <select
                    className="input w-40 shrink-0"
                    value={mapping[f.key] ?? -1}
                    onChange={(e) =>
                      setMapping((m) => ({ ...m, [f.key]: e.target.value === DONT_IMPORT ? -1 : Number(e.target.value) }))
                    }
                  >
                    <option value={DONT_IMPORT}>Don&apos;t import</option>
                    {headers.map((h, i) => (
                      <option key={i} value={i}>
                        {h || `Column ${i + 1}`}
                      </option>
                    ))}
                  </select>
                </div>
              ))}
            </div>
          </div>

          <div>
            <h3 className="text-sm font-semibold text-slate-900">2. Preview</h3>
            <p className="mt-0.5 text-xs text-slate-500">
              {dataRows.length} row{dataRows.length === 1 ? "" : "s"} found
              {itemCount !== dataRows.length ? `, ${itemCount} have an item name` : ""}.
            </p>
            <div className="mt-2 overflow-x-auto rounded-lg border border-slate-200">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-50 text-slate-500">
                  <tr>
                    {FIELDS.map((f) => (
                      <th key={f.key} className="whitespace-nowrap px-2.5 py-2 font-medium">{f.label}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {previewRows.map((cells, i) => {
                    const get = (field: FieldKey) => {
                      const idx = mapping[field];
                      return idx == null || idx < 0 ? "" : (cells[idx] ?? "");
                    };
                    return (
                      <tr key={i} className="border-t border-slate-100">
                        {FIELDS.map((f) => (
                          <td key={f.key} className="max-w-[10rem] truncate px-2.5 py-1.5 text-slate-700">{get(f.key)}</td>
                        ))}
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>

          {!nameMapped && (
            <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
              Map a column to &quot;Item name&quot; to continue.
            </p>
          )}
          {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}

          <div className="flex gap-3">
            <button onClick={reset} className="btn-ghost" disabled={isPending}>
              Start over
            </button>
            <button onClick={handleImport} className="btn-primary" disabled={!nameMapped || isPending}>
              {isPending ? "Importing…" : `Import ${itemCount} item${itemCount === 1 ? "" : "s"}`}
            </button>
          </div>
        </div>
      )}

      {step === "done" && (
        <div className="mt-4 space-y-3">
          {result && <p className="rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700">{result}</p>}
          <button onClick={reset} className="btn-ghost">
            Import another file
          </button>
        </div>
      )}
    </section>
  );
}
