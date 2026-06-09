import Link from "next/link";
import { SiteHeader } from "@/components/SiteHeader";
import { DownloadButtons } from "@/components/DownloadButtons";
import { ScanMockup, DiffMockup } from "@/components/marketing/Frames";
import { getUser } from "@/lib/data";

export default async function Home() {
  const user = await getUser();

  return (
    <div className="min-h-screen">
      <SiteHeader signedIn={!!user} />

      {/* Hero */}
      <section className="mx-auto max-w-6xl px-4 pb-12 pt-20 text-center">
        <p className="mb-4 inline-block rounded-full bg-brand-100 px-3 py-1 text-sm font-medium text-brand-700">
          AI condition &amp; inventory intelligence
        </p>
        <h1 className="mx-auto max-w-3xl text-4xl font-extrabold tracking-tight text-slate-900 sm:text-6xl">
          Point your phone at a room. Know everything in it.
        </h1>
        <p className="mx-auto mt-6 max-w-2xl text-lg text-slate-600">
          Collect&apos;s AI turns a 60-second scan into an itemized record — every object, its condition,
          and its value. Proof for your insurance company, your tenants, or your next garage sale.
        </p>
      </section>

      {/* Two-path split */}
      <section className="mx-auto max-w-6xl px-4 pb-20">
        <div className="grid gap-6 lg:grid-cols-2">
          {/* Homeowner path */}
          <div className="card relative overflow-hidden p-8">
            <p className="text-sm font-semibold uppercase tracking-wide text-brand-700">For your home</p>
            <h2 className="mt-2 text-2xl font-bold text-slate-900">
              Know what you own — and what it&apos;s worth
            </h2>
            <p className="mt-3 text-slate-600">
              Build a complete home inventory in an afternoon. Be ready for an insurance claim, a move,
              an estate — or finally sell the stuff in the garage.
            </p>
            <ul className="mt-4 space-y-2 text-sm text-slate-600">
              <li className="flex gap-2"><span className="text-brand">✓</span> Scan rooms with video or photos</li>
              <li className="flex gap-2"><span className="text-brand">✓</span> AI names, categorizes, and values every item</li>
              <li className="flex gap-2"><span className="text-brand">✓</span> One-click marketplace listings</li>
              <li className="flex gap-2"><span className="text-brand">✓</span> Export everything — no lock-in</li>
            </ul>
            <div className="mt-6 flex gap-3">
              <Link href="/homeowners" className="btn-primary">See how it works</Link>
              <Link href="/signup" className="btn-ghost">Start free</Link>
            </div>
            <div className="mt-8 origin-top-left scale-90">
              <ScanMockup />
            </div>
          </div>

          {/* PM path */}
          <div className="relative overflow-hidden rounded-xl border border-slate-800 bg-slate-900 p-8 text-white shadow-sm">
            <p className="text-sm font-semibold uppercase tracking-wide text-brand-100">For property managers</p>
            <h2 className="mt-2 text-2xl font-bold">
              Win every deposit dispute before it starts
            </h2>
            <p className="mt-3 text-slate-300">
              AI-documented move-in and move-out inspections for every unit. Side-by-side condition diffs,
              timestamped photos, and a signature-ready deduction report.
            </p>
            <ul className="mt-4 space-y-2 text-sm text-slate-300">
              <li className="flex gap-2"><span className="text-brand-100">✓</span> Room-by-room inspections in minutes, not hours</li>
              <li className="flex gap-2"><span className="text-brand-100">✓</span> Automatic move-out vs. move-in condition diff</li>
              <li className="flex gap-2"><span className="text-brand-100">✓</span> Print-ready deposit deduction reports</li>
              <li className="flex gap-2"><span className="text-brand-100">✓</span> Portfolio dashboard — vacancy, turns, every unit</li>
            </ul>
            <div className="mt-6 flex gap-3">
              <Link href="/property-management" className="btn bg-white text-slate-900 hover:bg-slate-100">
                Explore the platform
              </Link>
              <Link href="/pricing" className="btn border border-slate-600 text-white hover:bg-slate-800">
                Pricing
              </Link>
            </div>
            <div className="mt-8">
              <DiffMockup />
            </div>
          </div>
        </div>
      </section>

      {/* Shared engine */}
      <section className="border-t border-slate-200 bg-white">
        <div className="mx-auto max-w-6xl px-4 py-16">
          <h2 className="text-center text-2xl font-bold text-slate-900">One AI engine. Two superpowers.</h2>
          <p className="mx-auto mt-3 max-w-2xl text-center text-slate-600">
            The same computer vision that catalogs your living room documents a 200-unit move-out season.
          </p>
          <div className="mt-10 grid gap-6 sm:grid-cols-3">
            {[
              {
                icon: "📷",
                title: "Capture",
                body: "A quick video or a few photos per room. No clipboards, no typing, no forgetting the closet.",
              },
              {
                icon: "🧠",
                title: "Understand",
                body: "AI identifies every item with a name, category, condition grade, and estimated value — with confidence scores.",
              },
              {
                icon: "📄",
                title: "Prove",
                body: "Timestamped, exportable records: insurance inventories, deposit reports, marketplace listings, CSV exports.",
              },
            ].map((f) => (
              <div key={f.title} className="card p-6 text-center">
                <div className="mb-3 text-3xl">{f.icon}</div>
                <h3 className="text-lg font-semibold text-slate-900">{f.title}</h3>
                <p className="mt-2 text-sm text-slate-600">{f.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Download CTA */}
      <section className="border-t border-slate-200">
        <div className="mx-auto max-w-6xl px-4 py-16 text-center">
          <h2 className="text-2xl font-bold text-slate-900">Capture on your phone, manage from your desk</h2>
          <p className="mx-auto mt-3 max-w-xl text-slate-600">
            Get the iOS app to scan, the web dashboard to organize, and the Chrome extension to auto-fill
            marketplace listings.
          </p>
          <div className="mt-8 flex justify-center">
            <DownloadButtons />
          </div>
        </div>
      </section>

      <footer className="border-t border-slate-200 py-8 text-center text-sm text-slate-500">
        © {new Date().getFullYear()} Collect · Built for cataloging your world
      </footer>
    </div>
  );
}
