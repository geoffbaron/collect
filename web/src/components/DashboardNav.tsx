"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const links = [
  { href: "/dashboard", label: "Overview" },
  { href: "/dashboard/items", label: "Items" },
  { href: "/dashboard/listings", label: "Listings" },
  { href: "/dashboard/export", label: "Import / Export" },
  { href: "/download", label: "Download apps" },
];

export function DashboardNav({ email, plan }: { email?: string | null; plan?: string }) {
  const pathname = usePathname();

  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
        <div className="flex items-center gap-6">
          <Link href="/dashboard" className="flex items-center gap-2 font-bold text-slate-900">
            <span className="grid h-7 w-7 place-items-center rounded-lg bg-brand text-white">C</span>
            Collect
          </Link>
          <nav className="flex flex-wrap gap-1 text-sm">
            {links.map((l) => {
              const active = l.href === "/dashboard" ? pathname === l.href : pathname.startsWith(l.href);
              return (
                <Link
                  key={l.href}
                  href={l.href}
                  className={
                    "rounded-lg px-3 py-2 font-medium transition " +
                    (active ? "bg-brand-100 text-brand-700" : "text-slate-600 hover:bg-slate-100")
                  }
                >
                  {l.label}
                </Link>
              );
            })}
          </nav>
        </div>

        <div className="flex items-center gap-3 text-sm">
          <span className="hidden text-slate-500 sm:inline">{email}</span>
          {plan && plan !== "free" && (
            <span className="rounded-full bg-brand-100 px-2 py-0.5 text-xs font-semibold uppercase text-brand-700">
              {plan}
            </span>
          )}
          <form action="/auth/signout" method="post">
            <button type="submit" className="btn-ghost py-1.5">
              Sign out
            </button>
          </form>
        </div>
      </div>
    </header>
  );
}
