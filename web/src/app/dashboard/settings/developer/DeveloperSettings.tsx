"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createApiKey, revokeApiKey, type ApiKeyRow, type ApiKeyScope } from "@/lib/api-keys-actions";

export function DeveloperSettings({ keys }: { keys: ApiKeyRow[] }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [name, setName] = useState("");
  const [scope, setScope] = useState<ApiKeyScope>("read");
  const [newKey, setNewKey] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  function handleCreate(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    startTransition(async () => {
      const result = await createApiKey(name, scope);
      if (!result.ok) {
        setError(result.error);
        return;
      }
      setNewKey(result.key);
      setName("");
      setScope("read");
      router.refresh();
    });
  }

  function handleRevoke(id: string) {
    if (!confirm("Revoke this API key? Requests using it will start failing immediately.")) return;
    startTransition(async () => {
      const result = await revokeApiKey(id);
      if (!result.ok) {
        setError(result.error);
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="space-y-6">
      {newKey && (
        <div className="rounded-xl border border-brand-100 bg-brand-50 p-4">
          <p className="text-sm font-semibold text-brand-700">Your new API key</p>
          <p className="mt-1 text-sm text-slate-700">
            Copy it now — for security, you won&apos;t be able to see it again.
          </p>
          <div className="mt-2 flex items-center gap-2">
            <code className="flex-1 overflow-x-auto rounded-lg bg-white px-3 py-2 text-sm text-slate-900">
              {newKey}
            </code>
            <button
              type="button"
              className="btn-ghost shrink-0"
              onClick={() => navigator.clipboard.writeText(newKey)}
            >
              Copy
            </button>
          </div>
          <button type="button" className="mt-3 text-sm text-slate-500 hover:text-slate-700" onClick={() => setNewKey(null)}>
            Dismiss
          </button>
        </div>
      )}

      <section className="card p-5">
        <h2 className="font-semibold text-slate-900">Create API key</h2>
        <form onSubmit={handleCreate} className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-end">
          <div className="flex-1">
            <label className="mb-1 block text-sm font-medium text-slate-700">Name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder="Buildium sync"
              className="input w-full"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-slate-700">Scope</label>
            <select
              value={scope}
              onChange={(e) => setScope(e.target.value as ApiKeyScope)}
              className="input w-full"
            >
              <option value="read">Read only</option>
              <option value="read_write">Read &amp; write</option>
            </select>
          </div>
          <button type="submit" disabled={pending} className="btn-primary shrink-0">
            {pending ? "Creating…" : "Create key"}
          </button>
        </form>
        {error && <p className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-slate-900">API keys</h2>
        {keys.length === 0 ? (
          <p className="text-sm text-slate-500">No API keys yet.</p>
        ) : (
          <div className="card divide-y divide-slate-100">
            {keys.map((k) => (
              <div key={k.id} className="flex items-center justify-between gap-4 px-5 py-4">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-slate-900">{k.name}</span>
                    <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-semibold uppercase text-slate-600">
                      {k.scope === "read_write" ? "Read & write" : "Read only"}
                    </span>
                    {k.revoked_at && (
                      <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold uppercase text-red-700">
                        Revoked
                      </span>
                    )}
                  </div>
                  <p className="mt-1 text-sm text-slate-500">
                    <code>{k.key_prefix}…</code> · Created {new Date(k.created_at).toLocaleDateString()}
                    {k.last_used_at && <> · Last used {new Date(k.last_used_at).toLocaleString()}</>}
                  </p>
                </div>
                {!k.revoked_at && (
                  <button
                    type="button"
                    disabled={pending}
                    onClick={() => handleRevoke(k.id)}
                    className="btn-ghost shrink-0 text-red-600 hover:bg-red-50"
                  >
                    Revoke
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
