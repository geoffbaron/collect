"use client";

import { useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export function ForgotPasswordForm() {
  const [email, setEmail] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    setLoading(false);
    if (error) {
      setError(error.message);
      return;
    }
    // Supabase doesn't reveal whether the email is registered — show a
    // generic confirmation either way so we don't leak account existence.
    setSent(true);
  }

  return (
    <div className="mx-auto mt-16 max-w-sm px-4">
      <Link href="/" className="mb-8 flex items-center justify-center gap-2 font-bold text-slate-900">
        <span className="grid h-8 w-8 place-items-center rounded-lg bg-brand text-white">C</span>
        Collect
      </Link>
      <div className="card p-6">
        <h1 className="text-xl font-bold text-slate-900">Reset your password</h1>
        <p className="mt-1 text-sm text-slate-500">
          Enter the email on your account and we&apos;ll send you a link to reset your password.
        </p>

        {sent ? (
          <p className="mt-6 rounded-lg bg-green-50 px-3 py-3 text-sm text-green-700">
            If an account exists for <strong>{email}</strong>, we&apos;ve sent a link to reset your
            password. Check your inbox (and spam folder) — the link expires after a while, so use
            it soon.
          </p>
        ) : (
          <form onSubmit={handleSubmit} className="mt-6 space-y-4">
            <div>
              <label className="label">Email</label>
              <input
                className="input"
                type="email"
                required
                autoFocus
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
              />
            </div>

            {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}

            <button type="submit" disabled={loading} className="btn-primary w-full disabled:opacity-60">
              {loading ? "Sending…" : "Send reset link"}
            </button>
          </form>
        )}
      </div>

      <p className="mt-4 text-center text-sm text-slate-500">
        Remembered your password?{" "}
        <Link href="/login" className="font-medium text-brand-700">
          Log in
        </Link>
      </p>
    </div>
  );
}
