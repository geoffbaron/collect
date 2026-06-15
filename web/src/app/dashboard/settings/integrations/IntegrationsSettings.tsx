"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  connectIntegration,
  disconnectIntegration,
  syncIntegration,
} from "@/lib/integrations/actions";
import { CONNECTORS, PROVIDER_ORDER } from "@/lib/integrations";
import type { IntegrationProvider, IntegrationRow } from "@/lib/integrations";
import type { Property } from "@/lib/types";

export function IntegrationsSettings({
  integrations,
  properties,
}: {
  integrations: IntegrationRow[];
  properties: Property[];
}) {
  return (
    <div className="space-y-4">
      {PROVIDER_ORDER.map((provider) => (
        <ProviderCard
          key={provider}
          provider={provider}
          integration={integrations.find((i) => i.provider === provider) ?? null}
          properties={properties}
        />
      ))}
    </div>
  );
}

function ProviderCard({
  provider,
  integration,
  properties,
}: {
  provider: IntegrationProvider;
  integration: IntegrationRow | null;
  properties: Property[];
}) {
  const connector = CONNECTORS[provider];
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [form, setForm] = useState<Record<string, string>>(integration?.config ?? {});
  const [propertyId, setPropertyId] = useState(properties[0]?.id ?? "");

  const connected = integration?.status === "connected";

  if (!connector.available) {
    return (
      <div className="card p-5">
        <div className="flex items-center justify-between">
          <h3 className="font-semibold text-slate-900">{connector.displayName}</h3>
          <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-semibold uppercase text-slate-500">
            Coming soon
          </span>
        </div>
        <p className="mt-1 text-sm text-slate-500">
          {connector.displayName} requires a partner API agreement.{" "}
          <a href="mailto:hello@collect.app?subject=PM%20integration%20request" className="text-brand-700 hover:underline">
            Contact us
          </a>{" "}
          to request access.
        </p>
      </div>
    );
  }

  function handleConnect() {
    setError(null);
    setMessage(null);
    startTransition(async () => {
      const res = await connectIntegration(provider, form);
      if (!res.ok) {
        setError(res.error ?? "Couldn't connect. Check your credentials.");
        return;
      }
      setMessage("Connected.");
      router.refresh();
    });
  }

  function handleDisconnect() {
    setError(null);
    setMessage(null);
    startTransition(async () => {
      const res = await disconnectIntegration(provider);
      if (!res.ok) {
        setError(res.error ?? "Couldn't disconnect.");
        return;
      }
      setForm({});
      router.refresh();
    });
  }

  function handleSync() {
    if (!propertyId) return;
    setError(null);
    setMessage(null);
    startTransition(async () => {
      const res = await syncIntegration(provider, propertyId);
      if (!res.ok) {
        setError(res.error ?? "Sync failed.");
        return;
      }
      setMessage(`Synced — ${res.created} created, ${res.updated} updated.`);
      router.refresh();
    });
  }

  return (
    <div className="card p-5 space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="font-semibold text-slate-900">{connector.displayName}</h3>
        <span
          className={
            "rounded-full px-2 py-0.5 text-xs font-semibold uppercase " +
            (connected
              ? "bg-emerald-100 text-emerald-700"
              : integration?.status === "error"
                ? "bg-red-100 text-red-700"
                : "bg-slate-100 text-slate-500")
          }
        >
          {integration?.status ?? "disconnected"}
        </span>
      </div>

      {!connected && (
        <div className="space-y-3">
          {connector.configFields.map((field) => (
            <label key={field.key} className="block text-sm">
              <span className="text-slate-600">{field.label}</span>
              <input
                type={field.type}
                value={form[field.key] ?? ""}
                onChange={(e) => setForm((f) => ({ ...f, [field.key]: e.target.value }))}
                placeholder={field.placeholder}
                className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm"
              />
            </label>
          ))}
          <button
            type="button"
            onClick={handleConnect}
            disabled={pending}
            className="rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700 disabled:opacity-60"
          >
            Connect
          </button>
        </div>
      )}

      {connected && (
        <div className="space-y-3">
          {integration?.last_synced_at && (
            <p className="text-sm text-slate-500">
              Last synced {new Date(integration.last_synced_at).toLocaleString()}
            </p>
          )}

          {properties.length > 0 && (
            <div className="flex flex-wrap items-end gap-2">
              <label className="block text-sm">
                <span className="text-slate-600">Property</span>
                <select
                  value={propertyId}
                  onChange={(e) => setPropertyId(e.target.value)}
                  className="mt-1 block w-56 rounded-lg border border-slate-200 px-3 py-2 text-sm"
                >
                  {properties.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
              </label>
              <button
                type="button"
                onClick={handleSync}
                disabled={pending}
                className="rounded-lg border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700 hover:border-slate-300 disabled:opacity-60"
              >
                Sync units now
              </button>
            </div>
          )}

          <button
            type="button"
            onClick={handleDisconnect}
            disabled={pending}
            className="text-sm font-medium text-red-600 hover:text-red-700 disabled:opacity-60"
          >
            Disconnect
          </button>
        </div>
      )}

      {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}
      {message && <p className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">{message}</p>}
    </div>
  );
}
