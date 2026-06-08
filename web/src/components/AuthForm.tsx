"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export function AuthForm({ mode }: { mode: "login" | "signup" }) {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get("next") || "/dashboard";

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setNotice(null);
    setLoading(true);
    const supabase = createClient();

    if (mode === "signup") {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { name } },
      });
      if (error) {
        setError(error.message);
        setLoading(false);
        return;
      }
      // If email confirmation is on, there's no active session yet.
      if (!data.session) {
        setNotice("Check your email to confirm your account, then log in.");
        setLoading(false);
        return;
      }
    } else {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) {
        setError(error.message);
        setLoading(false);
        return;
      }
    }

    router.push(next);
    router.refresh();
  }

  return (
    <div className="mx-auto mt-16 max-w-sm px-4">
      <Link href="/" className="mb-8 flex items-center justify-center gap-2 font-bold text-slate-900">
        <span className="grid h-8 w-8 place-items-center rounded-lg bg-brand text-white">C</span>
        Collect
      </Link>
      <div className="card p-6">
        <h1 className="text-xl font-bold text-slate-900">
          {mode === "signup" ? "Create your account" : "Welcome back"}
        </h1>
        <p className="mt-1 text-sm text-slate-500">
          Use the same account as the Collect app and extension.
        </p>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          {mode === "signup" && (
            <div>
              <label className="label">Name</label>
              <input className="input" value={name} onChange={(e) => setName(e.target.value)} placeholder="Jane Doe" />
            </div>
          )}
          <div>
            <label className="label">Email</label>
            <input
              className="input"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
            />
          </div>
          <div>
            <div className="flex items-center justify-between">
              <label className="label">Password</label>
              {mode === "login" && (
                <Link href="/forgot-password" className="mb-1 text-sm font-medium text-brand-700">
                  Forgot password?
                </Link>
              )}
            </div>
            <input
              className="input"
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
            />
          </div>

          {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>}
          {notice && <p className="rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700">{notice}</p>}

          <button type="submit" disabled={loading} className="btn-primary w-full disabled:opacity-60">
            {loading ? "Please wait…" : mode === "signup" ? "Create account" : "Log in"}
          </button>
        </form>
      </div>

      <p className="mt-4 text-center text-sm text-slate-500">
        {mode === "signup" ? (
          <>
            Already have an account?{" "}
            <Link href="/login" className="font-medium text-brand-700">
              Log in
            </Link>
          </>
        ) : (
          <>
            New to Collect?{" "}
            <Link href="/signup" className="font-medium text-brand-700">
              Create an account
            </Link>
          </>
        )}
      </p>
    </div>
  );
}
