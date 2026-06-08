import Link from "next/link";

export function SiteHeader({ signedIn }: { signedIn?: boolean }) {
  return (
    <header className="sticky top-0 z-20 border-b border-slate-200 bg-white/80 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
        <Link href="/" className="flex items-center gap-2 font-bold text-slate-900">
          <span className="grid h-7 w-7 place-items-center rounded-lg bg-brand text-white">C</span>
          Collect
        </Link>
        <nav className="flex items-center gap-2 text-sm">
          <Link href="/download" className="hidden px-3 py-2 text-slate-600 hover:text-slate-900 sm:block">
            Download
          </Link>
          {signedIn ? (
            <Link href="/dashboard" className="btn-primary">
              Open Dashboard
            </Link>
          ) : (
            <>
              <Link href="/login" className="px-3 py-2 text-slate-600 hover:text-slate-900">
                Log in
              </Link>
              <Link href="/signup" className="btn-primary">
                Get started
              </Link>
            </>
          )}
        </nav>
      </div>
    </header>
  );
}
