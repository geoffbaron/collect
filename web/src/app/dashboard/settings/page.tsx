import { getAccount } from "@/lib/data";
import { AccountSettings } from "@/components/AccountSettings";

export const dynamic = "force-dynamic";

export default async function SettingsPage() {
  const account = await getAccount();
  return <AccountSettings account={account} />;
}
