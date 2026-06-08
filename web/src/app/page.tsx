import Link from "next/link";
import { SiteHeader } from "@/components/SiteHeader";
import { DownloadButtons } from "@/components/DownloadButtons";
import { getUser } from "@/lib/data";

const features = [
  {
    title: "Scan a room, get an inventory",
    body: "Record a quick video or snap photos. AI identifies every item — name, category, condition, and estimated value.",
    icon: "📷",
  },
  {
    title: "Manage everything from your desk",
    body: "Browse, search, and edit your whole inventory in the web dashboard. Fix values, tweak categories, organize by property and room.",
    icon: "🗂️",
  },
  {
    title: "Sell with one click",
    body: "Prep marketplace listings in the app, then publish to Facebook Marketplace or Craigslist with the Chrome extension's Fill button.",
    icon: "🏷️",
  },
  {
    title: "Your data, portable",
    body: "Export your full inventory to CSV or JSON anytime, and import a backup just as easily. No lock-in.",
    icon: "📦",
  },
];

export default async function Home() {
  const user = await getUser();

  return (
    <div className="min-h-screen">
      <SiteHeader signedIn={!!user} />

      {/* Hero */}
      <section className="mx-auto max-w-6xl px-4 py-20 text-center">
        <p className="mb-4 inline-block rounded-full bg-brand-100 px-3 py-1 text-sm font-medium text-brand-700">
          AI-powered home inventory
        </p>
        <h1 className="mx-auto max-w-3xl text-4xl font-extrabold tracking-tight text-slate-900 sm:text-6xl">
          Catalog everything you own — in minutes.
        </h1>
        <p className="mx-auto mt-6 max-w-2xl text-lg text-slate-600">
          Collect scans your rooms, identifies your stuff, estimates its value, and helps you sell what you
          don&apos;t need. Capture on your phone, manage on the web.
        </p>
        <div className="mt-8 flex flex-col items-center gap-4">
          <div className="flex flex-col gap-3 sm:flex-row">
            <Link href="/signup" className="btn-primary px-6 py-3 text-base">
              Get started — it&apos;s free
            </Link>
            <Link href="/download" className="btn-ghost px-6 py-3 text-base">
              Download the apps
            </Link>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="mx-auto max-w-6xl px-4 pb-20">
        <div className="grid gap-6 sm:grid-cols-2">
          {features.map((f) => (
            <div key={f.title} className="card p-6">
              <div className="mb-3 text-3xl">{f.icon}</div>
              <h3 className="text-lg font-semibold text-slate-900">{f.title}</h3>
              <p className="mt-2 text-slate-600">{f.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Download CTA */}
      <section className="border-t border-slate-200 bg-white">
        <div className="mx-auto max-w-6xl px-4 py-16 text-center">
          <h2 className="text-2xl font-bold text-slate-900">Capture on your phone, sell from your desktop</h2>
          <p className="mx-auto mt-3 max-w-xl text-slate-600">
            Get the iOS app to scan, and the Chrome extension to auto-fill marketplace listings.
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
