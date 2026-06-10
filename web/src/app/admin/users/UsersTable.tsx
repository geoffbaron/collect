"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { setSuperAdmin } from "@/lib/actions";
import type { AdminUserRow } from "@/lib/data";

const fmtDate = (iso: string) =>
  new Date(iso).toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });

export function UsersTable({ users }: { users: AdminUserRow[] }) {
  const router = useRouter();
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  function toggle(user: AdminUserRow) {
    const nextValue = !user.is_super_admin;
    const verb = nextValue ? "promote" : "demote";
    if (!confirm(`Are you sure you want to ${verb} ${user.email ?? user.id} ${nextValue ? "to" : "from"} super admin?`)) {
      return;
    }
    setError(null);
    setPendingId(user.id);
    startTransition(async () => {
      const res = await setSuperAdmin(user.id, nextValue);
      setPendingId(null);
      if (!res.ok) {
        setError(res.error ?? "Something went wrong.");
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="space-y-3">
      {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}

      <div className="card overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-100 text-sm">
          <thead>
            <tr className="text-left text-slate-500">
              <th className="px-5 py-3 font-medium">Name</th>
              <th className="px-5 py-3 font-medium">Email</th>
              <th className="px-5 py-3 font-medium">Joined</th>
              <th className="px-5 py-3 font-medium">Super admin</th>
              <th className="px-5 py-3 font-medium"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {users.length === 0 && (
              <tr>
                <td colSpan={5} className="px-5 py-6 text-center text-slate-500">
                  No users found.
                </td>
              </tr>
            )}
            {users.map((u) => (
              <tr key={u.id}>
                <td className="px-5 py-3 font-medium text-slate-900">{u.name ?? "—"}</td>
                <td className="px-5 py-3 text-slate-600">{u.email ?? "—"}</td>
                <td className="px-5 py-3 text-slate-600">{fmtDate(u.created_at)}</td>
                <td className="px-5 py-3">
                  {u.is_super_admin ? (
                    <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold uppercase text-amber-700">
                      Super admin
                    </span>
                  ) : (
                    <span className="text-slate-400">—</span>
                  )}
                </td>
                <td className="px-5 py-3 text-right">
                  <button
                    type="button"
                    onClick={() => toggle(u)}
                    disabled={isPending && pendingId === u.id}
                    className="btn-ghost py-1.5 text-xs disabled:opacity-50"
                  >
                    {isPending && pendingId === u.id
                      ? "Saving…"
                      : u.is_super_admin
                        ? "Demote"
                        : "Promote"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
