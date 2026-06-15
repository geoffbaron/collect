import Link from "next/link";
import { notFound } from "next/navigation";
import { getAccount, getProperties } from "@/lib/data";
import { getIntegrations } from "@/lib/integrations/actions";
import { IntegrationsSettings } from "./IntegrationsSettings";

export const dynamic = "force-dynamic";

export default async function IntegrationsSettingsPage() {
  const account = await getAccount();
  if (account?.product_mode !== "property_manager") notFound();

  const [integrations, properties] = await Promise.all([getIntegrations(), getProperties()]);

  return (
    <div className="space-y-6">
      <div>
        <Link href="/dashboard/settings" className="text-sm text-slate-500 hover:text-slate-700">
          ← Settings
        </Link>
        <h1 className="mt-2 text-2xl font-bold text-slate-900">Integrations</h1>
        <p className="text-slate-500">
          Connect Collect to your property management software to sync units and push work orders.
        </p>
      </div>

      <IntegrationsSettings integrations={integrations} properties={properties} />
    </div>
  );
}
