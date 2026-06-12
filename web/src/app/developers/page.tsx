import Link from "next/link";
import { SiteHeader } from "@/components/SiteHeader";
import { getUser } from "@/lib/data";
import { ApiReference } from "./ApiReference";

export const metadata = {
  title: "Collect Developers — Public REST API",
  description:
    "Authenticate with an API key and connect Collect's REST API to your property management software — properties, units, inspections, work orders, capital assets, and maintenance schedules.",
};

export default async function DevelopersPage() {
  const user = await getUser();

  return (
    <div className="min-h-screen">
      <SiteHeader signedIn={!!user} />

      <section className="border-b border-slate-200 bg-slate-900 text-white">
        <div className="mx-auto max-w-6xl px-4 py-16">
          <p className="mb-3 inline-block rounded-full bg-brand px-3 py-1 text-sm font-medium text-white">
            Public API
          </p>
          <h1 className="text-4xl font-extrabold tracking-tight sm:text-5xl">Collect Public API</h1>
          <p className="mt-4 max-w-2xl text-lg text-slate-300">
            A REST API covering your full property hierarchy — properties, buildings, units, common
            areas, rooms, assets, inspections, work orders, capital assets, and maintenance schedules.
            Use it to connect Collect to your existing PM software.
          </p>

          <div className="mt-8 max-w-2xl rounded-xl border border-slate-700 bg-slate-800 p-5">
            <h2 className="font-semibold text-white">Authentication</h2>
            <p className="mt-2 text-sm text-slate-300">
              Every request needs an API key sent as a bearer token:
            </p>
            <pre className="mt-3 overflow-x-auto rounded-lg bg-slate-950 p-3 text-sm text-slate-200">
              <code>Authorization: Bearer ck_live_xxxxxxxxxxxxxxxx</code>
            </pre>
            <p className="mt-3 text-sm text-slate-300">
              Create and manage keys from{" "}
              {user ? (
                <Link href="/dashboard/settings/developer" className="underline hover:text-white">
                  Settings → Developer
                </Link>
              ) : (
                <span className="font-medium">Dashboard → Settings → Developer</span>
              )}
              . Keys are either <code className="rounded bg-slate-950 px-1 py-0.5">read</code> (list/get
              only) or <code className="rounded bg-slate-950 px-1 py-0.5">read_write</code> (full CRUD).
            </p>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-10">
        <ApiReference />
      </section>

      <footer className="border-t border-slate-200 py-8 text-center text-sm text-slate-500">
        © {new Date().getFullYear()} Collect · Built for cataloging your world
      </footer>
    </div>
  );
}
