import Link from "next/link";
import { getApiKeys } from "@/lib/api-keys-actions";
import { DeveloperSettings } from "./DeveloperSettings";

export const dynamic = "force-dynamic";

export default async function DeveloperSettingsPage() {
  const keys = await getApiKeys();

  return (
    <div className="space-y-6">
      <div>
        <Link href="/dashboard/settings" className="text-sm text-slate-500 hover:text-slate-700">
          ← Settings
        </Link>
        <h1 className="mt-2 text-2xl font-bold text-slate-900">Developer</h1>
        <p className="text-slate-500">
          Manage API keys for the{" "}
          <Link href="/developers" className="text-brand-700 underline hover:text-brand-800">
            Collect Public API
          </Link>
          .
        </p>
      </div>

      <DeveloperSettings keys={keys} />
    </div>
  );
}
