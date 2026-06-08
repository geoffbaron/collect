"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Status = "checking" | "ready" | "invalid";

/**
 * Lands here from the email link Supabase sends via resetPasswordForEmail.
 * The browser client picks up the recovery tokens from the URL automatically
 * and fires a PASSWORD_RECOVERY auth event, giving this page a temporary
 * session that's only good for setting a new password.
 */
export function ResetPasswordForm() {
  const router = useRouter();
  const [status, setStatus] = useState<Status>("checking");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);

  useEffect(() => {
    const supabase = createClient();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY") setStatus("ready");
    });

    // Belt-and-suspenders: if the event already fired before we subscribed,
    // or the link granted a session some other way, a session means we're good.
    // Otherwise give the URL a moment to be parsed before declaring it invalid.
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) {
        setStatus((s) => (s === "checking" ? "ready" : s));
      } else {
        setTimeout(() => setStatus((s) => (s === "checking" ? "invalid" : s)), 3000);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (password !== confirm) {
      setError("Passwords don't match.");
      return;
    }
    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.auth.updateUser({ password });
    setLoading(false);
    if (error) {
      setError(error.message);
      return;
    }
    setDone(true);
    setTimeout(() => {
      router.push("/dashboard");
      router.refresh();
    }, 1200);
  }

  return (
    <div className="mx-auto mt-16 max-w-sm px-4">
      <Link href="/" className="mb-8 flex items-center justify-center gap-2 font-bold text-slate-900">
        <span className="grid h-8 w-8 place-items-center rounded-lg bg-brand text-white">C</span>
        Collect
      </Link>
      <div className="card p-6">
        <h1 className="text-xl font-bold text-slate-900">Set a new password</h1>

        {status === "checking" && (
          <p className="mt-4 text-sm text-slate-500">Verifying your reset link…</p>
        )}

        {status === "invalid" && (
          <div className="mt-4 space-y-3">
            <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
              This reset link is invalid or has expired.
            </p>
            <Link href="/forgot-password" className="btn-primary w-full">
              Request a new link
            </Link>
          </div>
        )}

        {status === "ready" &&
          (done ? (
            <p className="mt-4 rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700">
              Password updated — taking you to your dashboard…
            </p>
          ) : (
            <form onSubmit={handleSubmit} className="mt-6 space-y-4">
              <div>
                <label className="label">New password</label>
                <input
                  className="input"
                  type="password"
                  required
                  minLength={6}
                  autoFocus
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                />
              </div>
              <div>
                <label className="label">Confirm password</label>
                <input
                  className="input"
                  type="password"
                  required
                  minLength={6}
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  placeholder="••••••••"
                />
              </div>

              {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}

              <button type="submit" disabled={loading} className="btn-primary w-full disabled:opacity-60">
                {loading ? "Saving…" : "Update password"}
              </button>
            </form>
          ))}
      </div>
    </div>
  );
}
