import Link from "next/link";
import { SiteHeader } from "@/components/SiteHeader";
import { getUser } from "@/lib/data";

export const metadata = {
  title: "Collect Pricing — Free, Pro, and Enterprise",
  description:
    "Start free with 3 properties and 5 scans a month. Go Pro for unlimited scanning. Enterprise for multifamily portfolios with team roles and volume pricing.",
};

const tiers = [
  {
    name: "Free",
    price: "$0",
    period: "forever",
    tagline: "Document your most valuable rooms today.",
    audience: "For getting started",
    features: [
      "3 properties",
      "5 AI scans per month",
      "60-second video scans",
      "Up to 25 items per scan",
      "Web dashboard + iOS app",
      "CSV / JSON export",
    ],
    cta: { label: "Start free", href: "/signup" },
    highlight: false,
  },
  {
    name: "Pro",
    price: "$12",
    period: "per month",
    tagline: "The whole house, the rental, the storage unit — all of it.",
    audience: "For homeowners & independent landlords",
    features: [
      "Unlimited properties",
      "Unlimited AI scans",
      "3-minute video scans",
      "Up to 100 items per scan",
      "Marketplace listing tools + Chrome extension",
      "Buildings, units & inspections",
      "Move-out diff + deposit reports",
      "Priority support",
    ],
    cta: { label: "Go Pro", href: "/signup" },
    highlight: true,
  },
  {
    name: "Enterprise",
    price: "Custom",
    period: "per-unit volume pricing",
    tagline: "Inspection infrastructure for your whole portfolio.",
    audience: "For multifamily operators",
    features: [
      "Everything in Pro, unlimited",
      "Team accounts with owner / admin / manager / member roles",
      "Bulk unit onboarding via CSV",
      "Portfolio-wide vacancy & turn dashboards",
      "Billed directly — no app store required",
      "Dedicated onboarding for your sites",
      "SSO, audit log & PM-software integrations (roadmap)",
    ],
    cta: { label: "Talk to us", href: "mailto:geoffbaron@gmail.com?subject=Collect%20Enterprise" },
    highlight: false,
    dark: true,
  },
];

const faqs = [
  {
    q: "Which plan do I need for move-in/move-out inspections?",
    a: "Inspections, condition diffs, and deposit reports are included in Pro and Enterprise. Pro fits independent landlords managing their own doors; Enterprise adds team roles, bulk onboarding, and volume pricing for portfolios.",
  },
  {
    q: "Is my data locked in?",
    a: "No. Every plan — including Free — can export the full inventory to CSV or JSON at any time, and import it back.",
  },
  {
    q: "How does Enterprise billing work?",
    a: "Per-unit, billed directly to your organization — outside the App Store — so it fits your existing vendor and procurement process.",
  },
  {
    q: "Can one account be both homeowner and property manager?",
    a: "An account runs in one mode at a time, and you can switch in Settings. Most people keep personal and portfolio inventories in separate accounts.",
  },
];

export default async function PricingPage() {
  const user = await getUser();

  return (
    <div className="min-h-screen">
      <SiteHeader signedIn={!!user} />

      <section className="mx-auto max-w-6xl px-4 py-20 text-center">
        <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl">
          Start free. Scale to the whole portfolio.
        </h1>
        <p className="mx-auto mt-4 max-w-2xl text-lg text-slate-600">
          One platform, two products: a home inventory that pays for itself at the first claim or garage
          sale, and inspection infrastructure that pays for itself at the first deposit dispute.
        </p>
      </section>

      <section className="mx-auto max-w-6xl px-4 pb-16">
        <div className="grid gap-6 lg:grid-cols-3">
          {tiers.map((t) => (
            <div
              key={t.name}
              className={`relative flex flex-col rounded-xl border p-8 shadow-sm ${
                t.highlight ? "border-brand ring-2 ring-brand/30" : ""
              } ${t.dark ? "border-slate-800 bg-slate-900 text-white" : "border-slate-200 bg-white"}`}
            >
              {t.highlight && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-brand px-3 py-0.5 text-xs font-semibold text-white">
                  Most popular
                </span>
              )}
              <p className={`text-xs font-semibold uppercase tracking-wide ${t.dark ? "text-brand-100" : "text-brand-700"}`}>
                {t.audience}
              </p>
              <h2 className={`mt-1 text-2xl font-bold ${t.dark ? "" : "text-slate-900"}`}>{t.name}</h2>
              <div className="mt-3 flex items-baseline gap-1.5">
                <span className={`text-4xl font-extrabold ${t.dark ? "" : "text-slate-900"}`}>{t.price}</span>
                <span className={`text-sm ${t.dark ? "text-slate-400" : "text-slate-500"}`}>{t.period}</span>
              </div>
              <p className={`mt-2 text-sm ${t.dark ? "text-slate-300" : "text-slate-600"}`}>{t.tagline}</p>
              <ul className={`mt-6 flex-1 space-y-2.5 text-sm ${t.dark ? "text-slate-300" : "text-slate-600"}`}>
                {t.features.map((f) => (
                  <li key={f} className="flex gap-2.5">
                    <span className={t.dark ? "text-brand-100" : "text-brand"}>✓</span>
                    {f}
                  </li>
                ))}
              </ul>
              <Link
                href={t.cta.href}
                className={`mt-8 ${
                  t.dark
                    ? "btn bg-white text-slate-900 hover:bg-slate-100"
                    : t.highlight
                      ? "btn-primary"
                      : "btn-ghost"
                } justify-center py-2.5`}
              >
                {t.cta.label}
              </Link>
            </div>
          ))}
        </div>
      </section>

      {/* FAQ */}
      <section className="border-t border-slate-200 bg-white">
        <div className="mx-auto max-w-3xl px-4 py-16">
          <h2 className="text-center text-2xl font-bold text-slate-900">Questions, answered</h2>
          <div className="mt-8 space-y-6">
            {faqs.map((f) => (
              <div key={f.q} className="card p-6">
                <h3 className="font-semibold text-slate-900">{f.q}</h3>
                <p className="mt-2 text-sm text-slate-600">{f.a}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <footer className="border-t border-slate-200 py-8 text-center text-sm text-slate-500">
        © {new Date().getFullYear()} Collect · Built for cataloging your world
      </footer>
    </div>
  );
}
