import { SiteHeader } from "@/components/SiteHeader";
import { downloadLinks } from "@/lib/links";
import { getUser } from "@/lib/data";

export default async function DownloadPage() {
  const user = await getUser();
  const { ios, extensionStore, extensionZip } = downloadLinks;

  return (
    <div className="min-h-screen">
      <SiteHeader signedIn={!!user} />
      <main className="mx-auto max-w-3xl px-4 py-16">
        <h1 className="text-3xl font-bold text-slate-900">Get Collect</h1>
        <p className="mt-2 text-slate-600">Scan on your phone, sell from your desktop.</p>

        {/* iOS */}
        <section className="card mt-8 p-6">
          <h2 className="text-xl font-semibold"> Collect for iPhone</h2>
          <p className="mt-2 text-slate-600">
            Scan rooms with video or photos, let AI catalog your items, and prepare marketplace listings.
          </p>
          <div className="mt-4">
            {ios ? (
              <a href={ios} target="_blank" rel="noreferrer" className="btn-primary">
                Download on the App Store
              </a>
            ) : (
              <span className="btn-ghost cursor-default opacity-70">Coming soon to the App Store</span>
            )}
          </div>
        </section>

        {/* Extension */}
        <section className="card mt-6 p-6">
          <h2 className="text-xl font-semibold">🧩 Chrome Extension</h2>
          <p className="mt-2 text-slate-600">
            Auto-fills Facebook Marketplace and Craigslist listing forms with your prepared items — title,
            description, price, and photos — in one click.
          </p>

          <div className="mt-4 flex flex-wrap gap-3">
            {extensionStore && (
              <a href={extensionStore} target="_blank" rel="noreferrer" className="btn-primary">
                Add to Chrome
              </a>
            )}
            <a href={extensionZip} download className="btn-ghost">
              ⬇ Download .zip
            </a>
          </div>

          <div className="mt-6 rounded-lg bg-slate-50 p-4 text-sm text-slate-600">
            <p className="font-medium text-slate-800">Install the .zip manually</p>
            <ol className="mt-2 list-decimal space-y-1 pl-5">
              <li>Download and unzip the file above.</li>
              <li>
                Open <code className="rounded bg-slate-200 px-1">chrome://extensions</code> and turn on{" "}
                <strong>Developer mode</strong> (top-right).
              </li>
              <li>
                Click <strong>Load unpacked</strong> and select the unzipped <code>Collect Extension</code> folder.
              </li>
              <li>Open the extension and sign in with your Collect account.</li>
            </ol>
          </div>
        </section>
      </main>
    </div>
  );
}
