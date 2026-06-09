import Link from "next/link";
import { SiteHeader } from "@/components/SiteHeader";
import {
  InspectionMockup,
  DiffMockup,
  ReportMockup,
  TurnBoardMockup,
} from "@/components/marketing/Frames";
import { getUser } from "@/lib/data";

export const metadata = {
  title: "Collect for Property Management — AI move-in/move-out inspections",
  description:
    "AI-documented unit inspections, automatic move-out vs. move-in condition diffs, and signature-ready deposit deduction reports. Built for multifamily portfolios.",
};

const personas = [
  {
    emoji: "🏢",
    who: "The portfolio director",
    units: "500–20,000 units",
    pain: "You can't see unit condition across the portfolio. Inspections live in binders, camera rolls, and the memory of whoever did the walk-through. When a deposit dispute escalates, the evidence is whatever someone happened to photograph.",
    fix: "Every inspection becomes structured, timestamped data: item-level condition per room per unit, consistent across every property and every tech. Disputes get answered with records, not recollections.",
  },
  {
    emoji: "🔑",
    who: "The independent landlord",
    units: "2–50 doors",
    pain: "You do your own move-outs with a phone camera and a checklist PDF. The photos are somewhere in your camera roll, undated and unlabeled, and writing the deduction letter takes a stressful evening.",
    fix: "Walk the unit once with Collect. The AI catalogs what's there and its condition, the diff against move-in is automatic, and the deduction report is generated — you just fill in the charges.",
  },
  {
    emoji: "🛠️",
    who: "The on-site team",
    units: "Leasing managers & techs",
    pain: "A thorough move-out walk takes an hour-plus with a clipboard, and turn season means dozens of them. Detail slips when you're rushing — and the missed blinds become next year's dispute.",
    fix: "Room-by-room guided flow: open the unit's inspection, tap a room, pan the camera. The AI does the itemizing. A full unit takes minutes, and nothing gets skipped.",
  },
];

const steps = [
  {
    n: "1",
    title: "Scan at move-in",
    body: "A tech walks the unit room by room. The AI records every item and its condition — appliances, fixtures, flooring, blinds — timestamped and tied to the unit.",
  },
  {
    n: "2",
    title: "Scan at move-out",
    body: "Same walk, same AI. Collect automatically diffs against the move-in baseline: what's damaged, what's missing, what's fine.",
  },
  {
    n: "3",
    title: "Generate the report",
    body: "A print-ready deposit deduction report — itemized findings by room, charge lines, and signature blocks for manager and tenant.",
  },
];

export default async function PropertyManagementPage() {
  const user = await getUser();

  return (
    <div className="min-h-screen">
      <SiteHeader signedIn={!!user} />

      {/* Hero */}
      <section className="bg-slate-900 text-white">
        <div className="mx-auto max-w-6xl px-4 py-20">
          <div className="grid items-center gap-12 lg:grid-cols-2">
            <div>
              <p className="mb-4 inline-block rounded-full bg-brand px-3 py-1 text-sm font-medium text-white">
                For property managers
              </p>
              <h1 className="text-4xl font-extrabold tracking-tight sm:text-5xl">
                The deposit dispute ends when the evidence is this good.
              </h1>
              <p className="mt-6 text-lg text-slate-300">
                Collect turns move-in and move-out inspections into AI-documented, timestamped condition
                records — then diffs them automatically and writes the deduction report for you.
              </p>
              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <Link href="/signup" className="btn bg-white px-6 py-3 text-base text-slate-900 hover:bg-slate-100">
                  Start with one building
                </Link>
                <Link href="/pricing" className="btn border border-slate-600 px-6 py-3 text-base text-white hover:bg-slate-800">
                  Enterprise pricing
                </Link>
              </div>
            </div>
            <DiffMockup />
          </div>
        </div>
      </section>

      {/* Personas */}
      <section className="mx-auto max-w-6xl px-4 py-16">
        <h2 className="text-center text-3xl font-bold text-slate-900">Built for the people who do the turns</h2>
        <div className="mt-12 grid gap-6 lg:grid-cols-3">
          {personas.map((p) => (
            <div key={p.who} className="card flex flex-col p-7">
              <div className="text-3xl">{p.emoji}</div>
              <h3 className="mt-3 text-lg font-bold text-slate-900">{p.who}</h3>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-400">{p.units}</p>
              <p className="mt-4 text-sm text-slate-600">{p.pain}</p>
              <div className="mt-4 rounded-xl bg-brand-50 p-4">
                <p className="text-xs font-semibold uppercase tracking-wide text-brand-700">With Collect</p>
                <p className="mt-1.5 text-sm text-slate-700">{p.fix}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* How it works */}
      <section className="border-t border-slate-200 bg-white">
        <div className="mx-auto max-w-6xl px-4 py-16">
          <h2 className="text-center text-3xl font-bold text-slate-900">
            Move-in to deduction report in three steps
          </h2>
          <div className="mt-12 grid items-start gap-10 lg:grid-cols-[1fr_auto]">
            <div className="space-y-8">
              {steps.map((s) => (
                <div key={s.n} className="flex gap-5">
                  <div className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-brand text-lg font-bold text-white">
                    {s.n}
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-slate-900">{s.title}</h3>
                    <p className="mt-1 text-slate-600">{s.body}</p>
                  </div>
                </div>
              ))}
              <div className="rounded-xl border border-brand-100 bg-brand-50 p-5">
                <p className="text-sm text-slate-700">
                  <span className="font-semibold text-brand-700">Why it holds up:</span> every finding is
                  backed by a photo, a timestamp, and an AI condition grade recorded at the scene — not
                  reconstructed afterward. The report shows tenants exactly what changed and when.
                </p>
              </div>
            </div>
            <InspectionMockup />
          </div>
        </div>
      </section>

      {/* Report */}
      <section className="mx-auto max-w-6xl px-4 py-16">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <h2 className="text-3xl font-bold text-slate-900">
              The deduction letter that writes itself
            </h2>
            <p className="mt-4 text-slate-600">
              Damaged and missing items flow straight from the inspection diff into a print-ready report —
              organized by room, with charge lines ready for your numbers and signature blocks for both
              parties. What used to be an evening of letter-writing is a print button.
            </p>
            <ul className="mt-6 space-y-3 text-slate-600">
              <li className="flex gap-3"><span className="text-brand">✓</span> Itemized findings grouped by room</li>
              <li className="flex gap-3"><span className="text-brand">✓</span> Damaged vs. missing clearly flagged</li>
              <li className="flex gap-3"><span className="text-brand">✓</span> Manager and tenant signature blocks</li>
              <li className="flex gap-3"><span className="text-brand">✓</span> Print-optimized — hand it over or file it</li>
            </ul>
          </div>
          <ReportMockup />
        </div>
      </section>

      {/* Portfolio ops */}
      <section className="border-t border-slate-200 bg-white">
        <div className="mx-auto max-w-6xl px-4 py-16">
          <div className="grid items-center gap-12 lg:grid-cols-2">
            <TurnBoardMockup />
            <div>
              <h2 className="text-3xl font-bold text-slate-900">
                Your whole portfolio, at a glance
              </h2>
              <p className="mt-4 text-slate-600">
                Properties, buildings, and units in one hierarchy. Lease status and turn status on every
                unit, vacancy counts on every building, and CSV import to onboard an entire property in
                minutes.
              </p>
              <ul className="mt-6 space-y-3 text-slate-600">
                <li className="flex gap-3"><span className="text-brand">✓</span> Vacant / occupied / notice / eviction on every unit</li>
                <li className="flex gap-3"><span className="text-brand">✓</span> Turn tracking: needs turn → in progress → turned</li>
                <li className="flex gap-3"><span className="text-brand">✓</span> Bulk unit import from CSV</li>
                <li className="flex gap-3"><span className="text-brand">✓</span> Inspection history on every unit</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="bg-slate-900 text-white">
        <div className="mx-auto max-w-6xl px-4 py-16 text-center">
          <h2 className="text-3xl font-bold">Prove one building. Then roll it out.</h2>
          <p className="mx-auto mt-3 max-w-xl text-slate-300">
            Start with a single property this turn season. When the first dispute closes with a Collect
            report, you&apos;ll know what to do next.
          </p>
          <div className="mt-8 flex justify-center gap-3">
            <Link href="/signup" className="btn bg-white px-6 py-3 text-base text-slate-900 hover:bg-slate-100">
              Get started
            </Link>
            <Link href="/pricing" className="btn border border-slate-600 px-6 py-3 text-base text-white hover:bg-slate-800">
              Talk to us about enterprise
            </Link>
          </div>
        </div>
      </section>

      <footer className="border-t border-slate-200 py-8 text-center text-sm text-slate-500">
        © {new Date().getFullYear()} Collect · Built for cataloging your world
      </footer>
    </div>
  );
}
