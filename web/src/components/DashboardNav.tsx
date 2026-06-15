"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ProductMode } from "@/lib/types";

type NavLink = { href: string; label: string };

// The two products share most routes but differ in labels and which sections
// appear — property managers don't run a resale marketplace, homeowners don't
// think in "portfolio" terms.
const NAV_BY_MODE: Record<ProductMode, NavLink[]> = {
  homeowner: [
    { href: "/dashboard", label: "Overview" },
    { href: "/dashboard/items", label: "Items" },
    { href: "/dashboard/listings", label: "Listings" },
    { href: "/dashboard/export", label: "Import / Export" },
    { href: "/dashboard/settings", label: "Settings" },
    { href: "/download", label: "Download apps" },
  ],
  property_manager: [
    { href: "/dashboard", label: "Portfolio" },
    { href: "/dashboard/work-orders", label: "Work Orders" },
    { href: "/dashboard/items", label: "Inventory" },
    { href: "/dashboard/export", label: "Import / Export" },
    { href: "/dashboard/settings", label: "Settings" },
    { href: "/download", label: "Download apps" },
  ],
};

export function DashboardNav({
  email,
  plan,
  productMode = "homeowner",
  isSuperAdmin = false,
}: {
  email?: string | null;
  plan?: string;
  productMode?: ProductMode;
  isSuperAdmin?: boolean;
}) {
  const pathname = usePathname();
  const links = NAV_BY_MODE[productMode];

  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
        <div className="flex items-center gap-6">
          <Link href="/dashboard" className="flex items-center gap-2 font-bold text-slate-900">
            <span className="grid h-7 w-7 place-items-center rounded-lg bg-brand text-white">C</span>
            Collect
            {productMode === "property_manager" && (
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-600">
                Property
              </span>
            )}
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
          {isSuperAdmin && (
            <Link
              href="/admin"
              className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold uppercase text-amber-700 hover:bg-amber-200"
            >
              Admin
            </Link>
          )}
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
