"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { acceptInvite } from "@/lib/team-actions";
import { ACCOUNT_ROLE_LABELS, type AccountRole } from "@/lib/types";

/**
 * Shown on the dashboard when a pending invite matches the signed-in user's
 * email. Accepting switches their active account to the inviting org.
 */
export function JoinInviteBanner({ accountName, role }: { accountName: string; role: AccountRole }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [dismissed, setDismissed] = useState(false);

  if (dismissed) return null;

  function join() {
    setError(null);
    startTransition(async () => {
      const res = await acceptInvite();
      if (!res.ok) {
        setError(res.error ?? "Couldn't accept the invite. Try again.");
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="card flex flex-wrap items-center justify-between gap-3 border-brand bg-brand-50 p-5">
      <div>
        <p className="font-medium text-slate-900">
          You&apos;ve been invited to join <span className="font-semibold">{accountName}</span> as{" "}
          {ACCOUNT_ROLE_LABELS[role]}.
        </p>
        <p className="text-sm text-slate-600">
          Joining switches your workspace to their team account.
        </p>
        {error && <p className="mt-1 text-sm text-red-700">{error}</p>}
      </div>
      <div className="flex items-center gap-3">
        <button type="button" onClick={() => setDismissed(true)} className="btn-ghost" disabled={pending}>
          Not now
        </button>
        <button type="button" onClick={join} className="btn-primary" disabled={pending}>
          {pending ? "Joining…" : "Join team"}
        </button>
      </div>
    </div>
  );
}
