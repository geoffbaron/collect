import Link from "next/link";
import { redirect } from "next/navigation";
import { getProfile, getUser } from "@/lib/data";

export const dynamic = "force-dynamic";

const NAV = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/accounts", label: "Accounts" },
  { href: "/admin/users", label: "Users" },
];

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const user = await getUser();
  if (!user) redirect("/login");
  const profile = await getProfile();
  if (!profile?.is_super_admin) redirect("/dashboard");

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="border-b border-slate-200 bg-slate-900">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
          <div className="flex items-center gap-6">
            <Link href="/admin" className="flex items-center gap-2 font-bold text-white">
              <span className="grid h-7 w-7 place-items-center rounded-lg bg-brand text-white">C</span>
              Collect
              <span className="rounded-full bg-amber-400/20 px-2 py-0.5 text-xs font-semibold uppercase text-amber-300">
                Super Admin
              </span>
            </Link>
            <nav className="flex flex-wrap gap-1 text-sm">
              {NAV.map((l) => (
                <Link
                  key={l.href}
                  href={l.href}
                  className="rounded-lg px-3 py-2 font-medium text-slate-300 transition hover:bg-slate-800 hover:text-white"
                >
                  {l.label}
                </Link>
              ))}
            </nav>
          </div>
          <div className="flex items-center gap-3 text-sm">
            <span className="hidden text-slate-400 sm:inline">{profile.email}</span>
            <Link href="/dashboard" className="rounded-lg px-3 py-1.5 font-medium text-slate-300 hover:bg-slate-800 hover:text-white">
              Back to app
            </Link>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-8">{children}</main>
    </div>
  );
}
