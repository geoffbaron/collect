/**
 * Device frames + stylized product mockups for the marketing pages.
 * These are hand-built recreations of real app screens — crisp at any size,
 * no image assets to maintain.
 */

export function PhoneFrame({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto w-[270px] rounded-[2.2rem] border-[6px] border-slate-900 bg-slate-900 shadow-2xl">
      <div className="overflow-hidden rounded-[1.85rem] bg-white">
        <div className="flex justify-center bg-white pt-2">
          <div className="h-5 w-24 rounded-full bg-slate-900" />
        </div>
        {children}
      </div>
    </div>
  );
}

export function BrowserFrame({ url, children }: { url: string; children: React.ReactNode }) {
  return (
    <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-xl">
      <div className="flex items-center gap-2 border-b border-slate-200 bg-slate-50 px-3 py-2">
        <span className="h-2.5 w-2.5 rounded-full bg-red-400" />
        <span className="h-2.5 w-2.5 rounded-full bg-amber-400" />
        <span className="h-2.5 w-2.5 rounded-full bg-green-400" />
        <span className="ml-2 flex-1 truncate rounded-md bg-white px-3 py-1 text-[11px] text-slate-400 ring-1 ring-slate-200">
          {url}
        </span>
      </div>
      {children}
    </div>
  );
}

/* ───────────────────────── Phone: AI room scan ───────────────────────── */

const scanItems = [
  { name: "Sectional sofa", cond: "Good", value: "$650" },
  { name: 'Samsung 55" TV', cond: "Excellent", value: "$420" },
  { name: "Coffee table, walnut", cond: "Fair", value: "$120" },
  { name: "Floor lamp", cond: "Good", value: "$45" },
];

export function ScanMockup() {
  return (
    <PhoneFrame>
      <div className="relative h-[300px] bg-gradient-to-br from-slate-300 via-slate-200 to-slate-400">
        {/* abstract "room" */}
        <div className="absolute bottom-10 left-4 h-20 w-32 rounded-lg bg-slate-500/40" />
        <div className="absolute bottom-12 right-6 h-24 w-16 rounded bg-slate-600/30" />
        <div className="absolute left-10 top-8 h-16 w-24 rounded bg-slate-100/60" />
        {/* detection boxes */}
        <div className="absolute bottom-9 left-3 h-[5.5rem] w-[8.5rem] rounded-lg border-2 border-brand">
          <span className="absolute -top-5 left-0 rounded bg-brand px-1.5 py-0.5 text-[9px] font-semibold text-white">
            Sofa · 96%
          </span>
        </div>
        <div className="absolute bottom-11 right-5 h-[6.5rem] w-[4.5rem] rounded border-2 border-green-500">
          <span className="absolute -top-5 right-0 rounded bg-green-500 px-1.5 py-0.5 text-[9px] font-semibold text-white">
            Lamp · 91%
          </span>
        </div>
        <div className="absolute inset-x-0 top-2 flex justify-center">
          <span className="rounded-full bg-slate-900/70 px-3 py-1 text-[10px] font-medium text-white">
            ● Scanning… 12 items found
          </span>
        </div>
      </div>
      <div className="space-y-1.5 p-3">
        {scanItems.map((i) => (
          <div key={i.name} className="flex items-center justify-between rounded-lg bg-slate-50 px-2.5 py-1.5">
            <div>
              <div className="text-[11px] font-semibold text-slate-900">{i.name}</div>
              <div className="text-[9px] text-slate-500">{i.cond} condition</div>
            </div>
            <div className="text-[11px] font-bold text-brand-700">{i.value}</div>
          </div>
        ))}
      </div>
    </PhoneFrame>
  );
}

/* ─────────────────── Phone: room-by-room inspection ─────────────────── */

const inspectionRooms = [
  { name: "Living room", done: true },
  { name: "Kitchen", done: true },
  { name: "Bedroom 1", done: true },
  { name: "Bedroom 2", done: false },
  { name: "Bathroom", done: false },
];

export function InspectionMockup() {
  return (
    <PhoneFrame>
      <div className="border-b border-slate-100 px-4 py-3">
        <div className="text-[10px] font-medium uppercase tracking-wide text-slate-400">Unit 4B · Move-out</div>
        <div className="text-sm font-bold text-slate-900">Inspection</div>
        <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-slate-100">
          <div className="h-full w-3/5 rounded-full bg-brand" />
        </div>
        <div className="mt-1 text-[10px] text-slate-500">3 of 5 rooms scanned</div>
      </div>
      <div className="space-y-1.5 p-3 pb-5">
        {inspectionRooms.map((r) => (
          <div key={r.name} className="flex items-center justify-between rounded-lg border border-slate-100 px-2.5 py-2">
            <div className="flex items-center gap-2">
              <span
                className={`grid h-4 w-4 place-items-center rounded-full text-[9px] font-bold ${
                  r.done ? "bg-green-500 text-white" : "border-2 border-slate-300"
                }`}
              >
                {r.done ? "✓" : ""}
              </span>
              <span className="text-[11px] font-medium text-slate-900">{r.name}</span>
            </div>
            <span
              className={`rounded-md px-2 py-1 text-[10px] font-semibold ${
                r.done ? "text-slate-400" : "bg-brand text-white"
              }`}
            >
              {r.done ? "Re-scan" : "Scan"}
            </span>
          </div>
        ))}
      </div>
    </PhoneFrame>
  );
}

/* ──────────────── Browser: move-out vs move-in diff ──────────────── */

const diffRows = [
  { item: "Refrigerator", moveIn: "Excellent", moveOut: "Good", flag: null },
  { item: "Carpet — living room", moveIn: "Good", moveOut: "Damaged", flag: "damaged" as const },
  { item: "Window blinds (3)", moveIn: "Good", moveOut: "—", flag: "missing" as const },
  { item: "Stove / oven", moveIn: "Good", moveOut: "Good", flag: null },
  { item: "Bathroom vanity", moveIn: "Excellent", moveOut: "Damaged", flag: "damaged" as const },
];

export function DiffMockup() {
  return (
    <BrowserFrame url="collect.app/dashboard/portfolio/maple-court/bldg-a/4b/inspection">
      <div className="p-4">
        <div className="mb-3 flex items-center justify-between">
          <div>
            <div className="text-sm font-bold text-slate-900">Move-out inspection — Unit 4B</div>
            <div className="text-[11px] text-slate-500">Compared against move-in · Mar 12, 2025</div>
          </div>
          <span className="rounded-lg bg-brand px-2.5 py-1.5 text-[11px] font-semibold text-white">
            Generate deposit report
          </span>
        </div>
        <table className="w-full text-left text-[11px]">
          <thead>
            <tr className="border-b border-slate-200 text-[10px] uppercase tracking-wide text-slate-400">
              <th className="py-1.5 font-medium">Item</th>
              <th className="py-1.5 font-medium">Move-in</th>
              <th className="py-1.5 font-medium">Move-out</th>
              <th className="py-1.5 font-medium" />
            </tr>
          </thead>
          <tbody>
            {diffRows.map((r) => (
              <tr key={r.item} className="border-b border-slate-100">
                <td className="py-2 font-medium text-slate-900">{r.item}</td>
                <td className="py-2 text-slate-500">{r.moveIn}</td>
                <td className={`py-2 ${r.flag ? "font-semibold text-red-600" : "text-slate-500"}`}>{r.moveOut}</td>
                <td className="py-2 text-right">
                  {r.flag === "damaged" && (
                    <span className="rounded-full bg-red-100 px-2 py-0.5 text-[9px] font-semibold text-red-700">
                      DAMAGED
                    </span>
                  )}
                  {r.flag === "missing" && (
                    <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[9px] font-semibold text-amber-700">
                      MISSING
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </BrowserFrame>
  );
}

/* ──────────────── Browser: unit turn board ──────────────── */

const units = [
  { num: "1A", lease: "Occupied", color: "bg-green-100 text-green-700" },
  { num: "1B", lease: "Vacant", color: "bg-slate-100 text-slate-600", turn: "Needs turn" },
  { num: "2A", lease: "Occupied", color: "bg-green-100 text-green-700" },
  { num: "2B", lease: "Notice", color: "bg-amber-100 text-amber-700" },
  { num: "3A", lease: "Occupied", color: "bg-green-100 text-green-700" },
  { num: "3B", lease: "Vacant", color: "bg-slate-100 text-slate-600", turn: "In progress" },
];

export function TurnBoardMockup() {
  return (
    <BrowserFrame url="collect.app/dashboard/portfolio/maple-court/building-a">
      <div className="p-4">
        <div className="mb-3 flex items-center gap-2">
          <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[10px] font-semibold text-slate-700">24 units</span>
          <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[10px] font-semibold text-slate-700">3 vacant</span>
          <span className="rounded-full bg-green-100 px-2.5 py-1 text-[10px] font-semibold text-green-700">19 occupied</span>
          <span className="rounded-full bg-blue-100 px-2.5 py-1 text-[10px] font-semibold text-blue-700">2 need turn</span>
        </div>
        <div className="grid grid-cols-3 gap-1.5">
          {units.map((u) => (
            <div key={u.num} className="rounded-lg border border-slate-100 p-2.5">
              <div className="flex items-start justify-between">
                <span className="text-[11px] font-bold text-slate-900">Unit {u.num}</span>
                <span className={`rounded-full px-1.5 py-0.5 text-[8px] font-semibold ${u.color}`}>{u.lease}</span>
              </div>
              <div className="mt-1 text-[9px] text-slate-400">2bd · 1ba · 850 sqft</div>
              {u.turn && (
                <span className="mt-1 inline-block rounded-full bg-blue-100 px-1.5 py-0.5 text-[8px] font-semibold text-blue-700">
                  {u.turn}
                </span>
              )}
            </div>
          ))}
        </div>
      </div>
    </BrowserFrame>
  );
}

/* ──────────────── Browser: deposit deduction report ──────────────── */

export function ReportMockup() {
  return (
    <BrowserFrame url="collect.app/…/inspection/report">
      <div className="p-5">
        <div className="border-b-2 border-slate-900 pb-2">
          <div className="text-sm font-bold uppercase tracking-wide text-slate-900">
            Security Deposit Deduction Report
          </div>
          <div className="mt-0.5 text-[10px] text-slate-500">
            Maple Court Apartments · Unit 4B · Tenant: J. Rivera · Move-out: Jun 2, 2026
          </div>
        </div>
        <table className="mt-3 w-full text-left text-[10px]">
          <thead>
            <tr className="border-b border-slate-300 text-[9px] uppercase text-slate-400">
              <th className="py-1 font-medium">Room</th>
              <th className="py-1 font-medium">Item / condition</th>
              <th className="py-1 text-right font-medium">Charge</th>
            </tr>
          </thead>
          <tbody className="text-slate-700">
            <tr className="border-b border-slate-100">
              <td className="py-1.5">Living room</td>
              <td className="py-1.5">Carpet — damaged (stains, photo attached)</td>
              <td className="py-1.5 text-right text-slate-300">$ ______</td>
            </tr>
            <tr className="border-b border-slate-100">
              <td className="py-1.5">Living room</td>
              <td className="py-1.5">Window blinds ×3 — missing</td>
              <td className="py-1.5 text-right text-slate-300">$ ______</td>
            </tr>
            <tr>
              <td className="py-1.5">Bathroom</td>
              <td className="py-1.5">Vanity — damaged (cracked basin)</td>
              <td className="py-1.5 text-right text-slate-300">$ ______</td>
            </tr>
          </tbody>
        </table>
        <div className="mt-4 grid grid-cols-2 gap-6">
          <div>
            <div className="h-px bg-slate-400" />
            <div className="mt-1 text-[9px] text-slate-400">Property manager signature</div>
          </div>
          <div>
            <div className="h-px bg-slate-400" />
            <div className="mt-1 text-[9px] text-slate-400">Tenant signature</div>
          </div>
        </div>
      </div>
    </BrowserFrame>
  );
}

/* ──────────────── Browser: work order board ──────────────── */

const workOrders = [
  { title: "Leaking faucet — Unit 2B", category: "Plumbing", priority: "Urgent", priorityColor: "bg-red-100 text-red-700", status: "Open", statusColor: "bg-slate-100 text-slate-600" },
  { title: "AC not cooling — Unit 5A", category: "HVAC", priority: "High", priorityColor: "bg-orange-100 text-orange-700", status: "In Progress", statusColor: "bg-amber-100 text-amber-700" },
  { title: "Smoke detector chirping — Unit 1C", category: "Safety", priority: "Medium", priorityColor: "bg-blue-100 text-blue-700", status: "In Progress", statusColor: "bg-amber-100 text-amber-700" },
  { title: "Broken mailbox lock — Lobby", category: "Other", priority: "Low", priorityColor: "bg-slate-100 text-slate-500", status: "Completed", statusColor: "bg-green-100 text-green-700" },
];

export function WorkOrderMockup() {
  return (
    <BrowserFrame url="collect.app/dashboard/portfolio/maple-court/work-orders">
      <div className="p-4">
        <div className="mb-3 flex items-center justify-between">
          <div className="text-sm font-bold text-slate-900">Work Orders</div>
          <span className="rounded-lg bg-brand px-2.5 py-1.5 text-[11px] font-semibold text-white">+ New</span>
        </div>
        <div className="space-y-1.5">
          {workOrders.map((w) => (
            <div key={w.title} className="flex items-center justify-between rounded-lg border border-slate-100 px-3 py-2">
              <div>
                <div className="text-[11px] font-semibold text-slate-900">{w.title}</div>
                <div className="text-[9px] text-slate-400">{w.category}</div>
              </div>
              <div className="flex shrink-0 items-center gap-1.5">
                <span className={`rounded-full px-1.5 py-0.5 text-[9px] font-semibold ${w.priorityColor}`}>{w.priority}</span>
                <span className={`rounded-full px-1.5 py-0.5 text-[9px] font-semibold ${w.statusColor}`}>{w.status}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </BrowserFrame>
  );
}

/* ──────────────── Browser: preventive maintenance schedules ──────────────── */

const maintenanceItems = [
  { title: "HVAC filter replacement — Building A", frequency: "Quarterly", due: "Overdue 5 days", overdue: true },
  { title: "Gutter cleaning — Building A", frequency: "Semiannual", due: "Overdue 2 days", overdue: true },
  { title: "Fire extinguisher inspection", frequency: "Annual", due: "Due in 12 days", overdue: false },
  { title: "Elevator certification", frequency: "Annual", due: "Due in 64 days", overdue: false },
];

export function MaintenanceScheduleMockup() {
  return (
    <BrowserFrame url="collect.app/dashboard/portfolio/maple-court/maintenance-schedules">
      <div className="p-4">
        <div className="mb-3 flex items-center justify-between">
          <div className="text-sm font-bold text-slate-900">Maintenance Schedules</div>
          <span className="rounded-full bg-red-100 px-2.5 py-1 text-[10px] font-semibold text-red-700">2 overdue</span>
        </div>
        <div className="space-y-1.5">
          {maintenanceItems.map((m) => (
            <div key={m.title} className="flex items-center justify-between rounded-lg border border-slate-100 px-3 py-2">
              <div>
                <div className="text-[11px] font-semibold text-slate-900">{m.title}</div>
                <div className="text-[9px] text-slate-400">{m.frequency}</div>
              </div>
              <span className={`rounded-full px-1.5 py-0.5 text-[9px] font-semibold ${m.overdue ? "bg-red-100 text-red-700" : "bg-slate-100 text-slate-600"}`}>
                {m.due}
              </span>
            </div>
          ))}
        </div>
      </div>
    </BrowserFrame>
  );
}

/* ──────────────── Browser: capital asset register ──────────────── */

const capitalAssets = [
  { name: "Roof — Building A", type: "Roof", note: "Installed 2011 · 10 yrs left on 25-yr life", condition: "Fair", color: "bg-amber-100 text-amber-700" },
  { name: "Water Heater — Unit 1A", type: "Water Heater", note: "Installed 2010 · past expected lifespan", condition: "Needs Replacement", color: "bg-red-100 text-red-700" },
  { name: "HVAC — Unit 3B", type: "HVAC", note: "Installed 2024 · warranty until 2034", condition: "Excellent", color: "bg-green-100 text-green-700" },
  { name: "Elevator — Building A", type: "Elevator", note: "Last serviced Jan 2026", condition: "Good", color: "bg-green-100 text-green-700" },
];

export function CapitalAssetMockup() {
  return (
    <BrowserFrame url="collect.app/dashboard/portfolio/maple-court/capital-assets">
      <div className="p-4">
        <div className="mb-3 flex items-center justify-between">
          <div className="text-sm font-bold text-slate-900">Capital Asset Register</div>
          <span className="rounded-lg bg-brand px-2.5 py-1.5 text-[11px] font-semibold text-white">+ New</span>
        </div>
        <div className="space-y-1.5">
          {capitalAssets.map((a) => (
            <div key={a.name} className="flex items-center justify-between rounded-lg border border-slate-100 px-3 py-2">
              <div>
                <div className="text-[11px] font-semibold text-slate-900">{a.name}</div>
                <div className="text-[9px] text-slate-400">{a.note}</div>
              </div>
              <span className={`shrink-0 rounded-full px-1.5 py-0.5 text-[9px] font-semibold ${a.color}`}>{a.condition}</span>
            </div>
          ))}
        </div>
      </div>
    </BrowserFrame>
  );
}

/* ──────────────── Browser: portfolio operations dashboard ──────────────── */

const opsStats = [
  { label: "Properties", value: "8" },
  { label: "Vacant units", value: "6 / 142" },
  { label: "Open work orders", value: "14" },
  { label: "Overdue maintenance", value: "5" },
];

const opsWorkOrders = [
  { title: "AC not cooling — Unit 5A", tag: "Urgent", color: "bg-orange-100 text-orange-700" },
  { title: "Leaking faucet — Unit 2B", tag: "Urgent", color: "bg-orange-100 text-orange-700" },
];

const opsMaintenance = [
  { title: "HVAC filter replacement — Bldg A", due: "Overdue 5 days" },
  { title: "Gutter cleaning — Bldg A", due: "Overdue 2 days" },
];

export function OpsDashboardMockup() {
  return (
    <BrowserFrame url="collect.app/dashboard">
      <div className="p-4">
        <div className="mb-3 grid grid-cols-4 gap-1.5">
          {opsStats.map((s) => (
            <div key={s.label} className="rounded-lg bg-slate-50 px-2 py-2">
              <div className="text-[8px] uppercase tracking-wide text-slate-400">{s.label}</div>
              <div className="text-sm font-bold text-slate-900">{s.value}</div>
            </div>
          ))}
        </div>
        <div className="grid grid-cols-2 gap-2">
          <div className="rounded-lg border border-slate-100">
            <div className="border-b border-slate-100 px-2.5 py-1.5 text-[10px] font-semibold text-slate-700">
              Open Work Orders (14)
            </div>
            {opsWorkOrders.map((w) => (
              <div key={w.title} className="flex items-center justify-between px-2.5 py-1.5">
                <span className="text-[10px] font-medium text-slate-900">{w.title}</span>
                <span className={`rounded-full px-1.5 py-0.5 text-[8px] font-semibold ${w.color}`}>{w.tag}</span>
              </div>
            ))}
          </div>
          <div className="rounded-lg border border-slate-100">
            <div className="border-b border-slate-100 px-2.5 py-1.5 text-[10px] font-semibold text-slate-700">
              Overdue Maintenance (5)
            </div>
            {opsMaintenance.map((m) => (
              <div key={m.title} className="flex items-center justify-between px-2.5 py-1.5">
                <span className="text-[10px] font-medium text-slate-900">{m.title}</span>
                <span className="rounded-full bg-red-100 px-1.5 py-0.5 text-[8px] font-semibold text-red-700">{m.due}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </BrowserFrame>
  );
}

/* ──────────────── Browser: homeowner dashboard ──────────────── */

const dashItems = [
  { name: "KitchenAid stand mixer", room: "Kitchen", value: "$280" },
  { name: "Herman Miller chair", room: "Office", value: "$540" },
  { name: "DeWalt drill set", room: "Garage", value: "$110" },
  { name: "Vintage record player", room: "Living room", value: "$190" },
];

export function DashboardMockup() {
  return (
    <BrowserFrame url="collect.app/dashboard/items">
      <div className="p-4">
        <div className="mb-3 flex items-center justify-between">
          <div className="flex gap-3">
            <div className="rounded-lg bg-slate-50 px-3 py-2">
              <div className="text-[9px] uppercase text-slate-400">Items</div>
              <div className="text-sm font-bold text-slate-900">412</div>
            </div>
            <div className="rounded-lg bg-slate-50 px-3 py-2">
              <div className="text-[9px] uppercase text-slate-400">Total value</div>
              <div className="text-sm font-bold text-brand-700">$38,450</div>
            </div>
            <div className="rounded-lg bg-slate-50 px-3 py-2">
              <div className="text-[9px] uppercase text-slate-400">Rooms</div>
              <div className="text-sm font-bold text-slate-900">14</div>
            </div>
          </div>
          <span className="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[10px] font-semibold text-slate-600">
            Export CSV
          </span>
        </div>
        <div className="space-y-1.5">
          {dashItems.map((i) => (
            <div key={i.name} className="flex items-center justify-between rounded-lg border border-slate-100 px-3 py-2">
              <div className="flex items-center gap-2.5">
                <div className="h-7 w-7 rounded-md bg-gradient-to-br from-slate-200 to-slate-300" />
                <div>
                  <div className="text-[11px] font-semibold text-slate-900">{i.name}</div>
                  <div className="text-[9px] text-slate-400">{i.room}</div>
                </div>
              </div>
              <div className="text-[11px] font-bold text-slate-900">{i.value}</div>
            </div>
          ))}
        </div>
      </div>
    </BrowserFrame>
  );
}
