import { redirect } from "next/navigation";
import { getAccount, getProfile, getUser } from "@/lib/data";
import { DashboardNav } from "@/components/DashboardNav";

export const dynamic = "force-dynamic";

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const user = await getUser();
  if (!user) redirect("/login");
  const [profile, account] = await Promise.all([getProfile(), getAccount()]);

  return (
    <div className="min-h-screen bg-slate-50">
      <DashboardNav
        email={profile?.email ?? user.email}
        plan={account?.plan ?? profile?.plan}
        productMode={account?.product_mode ?? "homeowner"}
        isSuperAdmin={profile?.is_super_admin ?? false}
      />
      <main className="mx-auto max-w-6xl px-4 py-8">{children}</main>
    </div>
  );
}
