"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { inviteMember, removeMember, revokeInvite, updateMemberRole } from "@/lib/team-actions";
import {
  ACCOUNT_ROLE_LABELS,
  GRANTABLE_ROLES,
  type AccountInvite,
  type AccountRole,
  type TeamMember,
} from "@/lib/types";

export function TeamSettings({
  members,
  invites,
  currentUserId,
  canManage,
}: {
  members: TeamMember[];
  invites: AccountInvite[];
  currentUserId: string;
  canManage: boolean;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteRole, setInviteRole] = useState<AccountRole>("maintenance");

  function run(action: () => Promise<{ ok: boolean; error?: string | null }>) {
    setError(null);
    startTransition(async () => {
      const res = await action();
      if (!res.ok) {
        setError(res.error ?? "Something went wrong. Try again.");
        return;
      }
      router.refresh();
    });
  }

  function submitInvite(e: React.FormEvent) {
    e.preventDefault();
    if (!inviteEmail.trim() || pending) return;
    const email = inviteEmail;
    run(async () => {
      const res = await inviteMember(email, inviteRole);
      if (res.ok) setInviteEmail("");
      return res;
    });
  }

  return (
    <div className="space-y-8">
      {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">Members ({members.length})</h2>
        <div className="card divide-y divide-slate-100">
          {members.map((m) => {
            const isSelf = m.user_id === currentUserId;
            const editable = canManage && !isSelf && m.role !== "owner";
            return (
              <div key={m.user_id} className="flex flex-wrap items-center justify-between gap-3 px-5 py-4">
                <div className="min-w-0">
                  <div className="font-medium text-slate-900">
                    {m.name || m.email || "Unknown"}
                    {isSelf && <span className="ml-2 text-xs font-normal text-slate-400">(you)</span>}
                  </div>
                  {m.name && m.email && <div className="truncate text-sm text-slate-500">{m.email}</div>}
                </div>
                <div className="flex items-center gap-3">
                  {editable ? (
                    <select
                      value={m.role}
                      disabled={pending}
                      onChange={(e) => run(() => updateMemberRole(m.user_id, e.target.value as AccountRole))}
                      className="rounded-lg border border-slate-200 px-2 py-1.5 text-sm"
                      aria-label={`Role for ${m.name || m.email}`}
                    >
                      {GRANTABLE_ROLES.map((r) => (
                        <option key={r} value={r}>
                          {ACCOUNT_ROLE_LABELS[r]}
                        </option>
                      ))}
                    </select>
                  ) : (
                    <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-semibold uppercase text-slate-600">
                      {ACCOUNT_ROLE_LABELS[m.role]}
                    </span>
                  )}
                  {editable && (
                    <button
                      type="button"
                      disabled={pending}
                      onClick={() => {
                        if (confirm(`Remove ${m.name || m.email} from the team?`)) {
                          run(() => removeMember(m.user_id));
                        }
                      }}
                      className="text-sm text-red-600 hover:text-red-700 disabled:opacity-60"
                    >
                      Remove
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {canManage && (
        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-slate-900">Invite a teammate</h2>
          <form onSubmit={submitInvite} className="card flex flex-wrap items-end gap-3 p-5">
            <div className="min-w-56 flex-1">
              <label htmlFor="invite-email" className="mb-1 block text-sm font-medium text-slate-700">
                Email
              </label>
              <input
                id="invite-email"
                type="email"
                required
                value={inviteEmail}
                onChange={(e) => setInviteEmail(e.target.value)}
                placeholder="tech@example.com"
                className="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm"
              />
            </div>
            <div>
              <label htmlFor="invite-role" className="mb-1 block text-sm font-medium text-slate-700">
                Role
              </label>
              <select
                id="invite-role"
                value={inviteRole}
                onChange={(e) => setInviteRole(e.target.value as AccountRole)}
                className="rounded-lg border border-slate-200 px-3 py-2 text-sm"
              >
                {GRANTABLE_ROLES.map((r) => (
                  <option key={r} value={r}>
                    {ACCOUNT_ROLE_LABELS[r]}
                  </option>
                ))}
              </select>
            </div>
            <button type="submit" disabled={pending || !inviteEmail.trim()} className="btn-primary">
              {pending ? "Inviting…" : "Invite"}
            </button>
            <p className="w-full text-sm text-slate-500">
              No email is sent yet — ask them to sign up at collect with this address and they&apos;ll
              join automatically. Already have an account? They&apos;ll see a join banner on their
              dashboard.
            </p>
          </form>

          {invites.length > 0 && (
            <div className="card divide-y divide-slate-100">
              <div className="px-5 py-3 text-sm font-semibold text-slate-900">
                Pending invites ({invites.length})
              </div>
              {invites.map((inv) => (
                <div key={inv.id} className="flex items-center justify-between px-5 py-3">
                  <div>
                    <div className="text-sm font-medium text-slate-900">{inv.email}</div>
                    <div className="text-xs text-slate-500">{ACCOUNT_ROLE_LABELS[inv.role]}</div>
                  </div>
                  <button
                    type="button"
                    disabled={pending}
                    onClick={() => run(() => revokeInvite(inv.id))}
                    className="text-sm text-red-600 hover:text-red-700 disabled:opacity-60"
                  >
                    Revoke
                  </button>
                </div>
              ))}
            </div>
          )}
        </section>
      )}

      <section className="space-y-2 text-sm text-slate-500">
        <h2 className="text-lg font-semibold text-slate-900">What each role can do</h2>
        <ul className="list-inside list-disc space-y-1">
          <li><span className="font-medium text-slate-700">Owner</span> — everything, including billing and the team.</li>
          <li><span className="font-medium text-slate-700">Admin</span> — everything except removing the owner.</li>
          <li><span className="font-medium text-slate-700">Manager</span> — manage properties, units, inspections, and work orders.</li>
          <li><span className="font-medium text-slate-700">Member</span> — view everything, report issues, and update work orders assigned to them.</li>
          <li><span className="font-medium text-slate-700">Maintenance</span> — like Member, with a work-order-first view in the mobile app.</li>
        </ul>
      </section>
    </div>
  );
}
