"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { setProductMode } from "@/lib/actions";
import type { Account, ProductMode } from "@/lib/types";

const MODES: { value: ProductMode; title: string; blurb: string }[] = [
  {
    value: "homeowner",
    title: "Homeowner",
    blurb: "Catalog what you own, track value, and list items for sale.",
  },
  {
    value: "property_manager",
    title: "Property manager",
    blurb: "Manage units across properties, inspections, and turnovers.",
  },
];

export function AccountSettings({ account }: { account: Account | null }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [current, setCurrent] = useState<ProductMode>(account?.product_mode ?? "homeowner");
  const [error, setError] = useState<string | null>(null);

  function choose(mode: ProductMode) {
    if (mode === current || pending) return;
    const previous = current;
    setCurrent(mode);
    setError(null);
    startTransition(async () => {
      const res = await setProductMode(mode);
      if (!res.ok) {
        setCurrent(previous);
        setError(res.error ?? "Couldn't update. Try again.");
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Settings</h1>
        <p className="text-slate-500">Manage how your Collect account works.</p>
      </div>

      <section className="space-y-3">
        <div>
          <h2 className="text-lg font-semibold text-slate-900">Product</h2>
          <p className="text-sm text-slate-500">
            Choose the experience that fits how you use Collect. You can switch anytime.
          </p>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          {MODES.map((m) => {
            const active = current === m.value;
            return (
              <button
                key={m.value}
                type="button"
                onClick={() => choose(m.value)}
                disabled={pending}
                aria-pressed={active}
                className={
                  "card p-5 text-left transition disabled:opacity-60 " +
                  (active
                    ? "ring-2 ring-brand ring-offset-1"
                    : "hover:border-slate-300")
                }
              >
                <div className="flex items-center justify-between">
                  <span className="font-semibold text-slate-900">{m.title}</span>
                  {active && (
                    <span className="rounded-full bg-brand-100 px-2 py-0.5 text-xs font-semibold uppercase text-brand-700">
                      Current
                    </span>
                  )}
                </div>
                <p className="mt-1 text-sm text-slate-500">{m.blurb}</p>
              </button>
            );
          })}
        </div>

        {error && (
          <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">Account</h2>
        <div className="card divide-y divide-slate-100">
          <Row label="Name" value={account?.name || "—"} />
          <Row label="Plan" value={(account?.plan ?? "free").toUpperCase()} />
          <Row label="Type" value={account?.is_personal ? "Personal" : "Organization"} />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">Developer</h2>
        <Link href="/dashboard/settings/developer" className="card flex items-center justify-between p-5 hover:border-slate-300">
          <div>
            <p className="font-medium text-slate-900">API keys</p>
            <p className="text-sm text-slate-500">
              Connect the <span className="font-medium">Collect Public API</span> to your other systems.
            </p>
          </div>
          <span className="text-slate-400">→</span>
        </Link>
      </section>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between px-5 py-4">
      <span className="text-sm text-slate-500">{label}</span>
      <span className="text-sm font-medium text-slate-900">{value}</span>
    </div>
  );
}
