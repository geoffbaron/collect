import Link from "next/link";
import { SiteHeader } from "@/components/SiteHeader";
import { DownloadButtons } from "@/components/DownloadButtons";
import { ScanMockup, DashboardMockup } from "@/components/marketing/Frames";
import { getUser } from "@/lib/data";

export const metadata = {
  title: "Collect for Homeowners — your whole home, itemized",
  description:
    "Build a complete home inventory in an afternoon. Insurance-ready documentation, estate cataloging, and one-click marketplace selling.",
};

const personas = [
  {
    emoji: "🔥",
    label: "The day you hope never comes",
    title: "Insurance claims run on proof you probably don't have",
    pain: "After a fire, flood, or break-in, your insurer asks for an itemized list of what you lost — make, model, condition, value. Most people reconstruct it from memory, weeks later, and leave thousands of dollars unclaimed.",
    fix: "A Collect inventory is that list, built before you needed it. Every item has a photo, a condition grade, an estimated value, and a timestamp. Export it to CSV and hand it to your adjuster.",
    cta: "Document your home this weekend",
  },
  {
    emoji: "📦",
    label: "The big transition",
    title: "Downsizing or settling an estate means cataloging a lifetime",
    pain: "A parent's house, a 30-year family home — thousands of items, and every one needs a decision: keep, sell, donate, toss. Doing it with a notepad takes weeks and starts arguments.",
    fix: "Walk each room with your phone. In an afternoon you have a shared, searchable catalog with values — so the family can divide, sell, and donate from facts instead of memory.",
    cta: "Catalog a whole house in a day",
  },
  {
    emoji: "💸",
    label: "The garage that owes you money",
    title: "Selling used stuff is profitable — listing it is the chore",
    pain: "Everyone has hundreds of dollars of unused gear sitting around. It stays there because every listing means photos, descriptions, pricing research, and re-typing it all into Marketplace.",
    fix: "Collect already has the photo, the description, and a price estimate. Prep the listing in the app, then the Chrome extension fills the Facebook Marketplace or Craigslist form in one click.",
    cta: "Turn clutter into cash",
  },
];

export default async function HomeownersPage() {
  const user = await getUser();

  return (
    <div className="min-h-screen">
      <SiteHeader signedIn={!!user} />

      {/* Hero */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <p className="mb-4 inline-block rounded-full bg-brand-100 px-3 py-1 text-sm font-medium text-brand-700">
              For homeowners
            </p>
            <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl">
              Your whole home, itemized in an afternoon.
            </h1>
            <p className="mt-6 text-lg text-slate-600">
              Record a quick video of each room. Collect&apos;s AI identifies every item, grades its
              condition, and estimates its value. You end up with the document everyone wishes they had —
              before the claim, the move, or the estate.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Link href="/signup" className="btn-primary px-6 py-3 text-base">
                Start free — 3 properties, 5 scans a month
              </Link>
              <Link href="/pricing" className="btn-ghost px-6 py-3 text-base">
                See pricing
              </Link>
            </div>
          </div>
          <ScanMockup />
        </div>
      </section>

      {/* Personas / problem spaces */}
      <section className="border-t border-slate-200 bg-white">
        <div className="mx-auto max-w-6xl px-4 py-16">
          <h2 className="text-center text-3xl font-bold text-slate-900">Three moments Collect was built for</h2>
          <div className="mt-12 space-y-8">
            {personas.map((p) => (
              <div key={p.title} className="card grid gap-6 p-8 lg:grid-cols-[auto_1fr_1fr]">
                <div className="text-4xl">{p.emoji}</div>
                <div>
                  <p className="text-xs font-semibold uppercase tracking-wide text-brand-700">{p.label}</p>
                  <h3 className="mt-1 text-xl font-bold text-slate-900">{p.title}</h3>
                  <p className="mt-3 text-slate-600">{p.pain}</p>
                </div>
                <div className="rounded-xl bg-brand-50 p-5">
                  <p className="text-sm font-semibold text-brand-700">How Collect fixes it</p>
                  <p className="mt-2 text-slate-700">{p.fix}</p>
                  <Link href="/signup" className="mt-3 inline-block text-sm font-semibold text-brand-700 hover:underline">
                    {p.cta} →
                  </Link>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Dashboard */}
      <section className="mx-auto max-w-6xl px-4 py-16">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <h2 className="text-3xl font-bold text-slate-900">Capture on the couch. Manage at your desk.</h2>
            <p className="mt-4 text-slate-600">
              Everything you scan syncs to the web dashboard: search across every room, fix values, tweak
              categories, and watch your home&apos;s total documented value add up.
            </p>
            <ul className="mt-6 space-y-3 text-slate-600">
              <li className="flex gap-3"><span className="text-brand">✓</span> Search and filter every item across properties and rooms</li>
              <li className="flex gap-3"><span className="text-brand">✓</span> Running total of your home&apos;s contents value</li>
              <li className="flex gap-3"><span className="text-brand">✓</span> Track listings from prepped → posted → sold</li>
              <li className="flex gap-3"><span className="text-brand">✓</span> Full CSV / JSON export anytime — your data stays yours</li>
            </ul>
          </div>
          <DashboardMockup />
        </div>
      </section>

      {/* CTA */}
      <section className="border-t border-slate-200 bg-white">
        <div className="mx-auto max-w-6xl px-4 py-16 text-center">
          <h2 className="text-2xl font-bold text-slate-900">Free to start. One scan to get hooked.</h2>
          <p className="mx-auto mt-3 max-w-xl text-slate-600">
            The free plan covers 3 properties and 5 scans a month — enough to document your most valuable
            rooms today.
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
