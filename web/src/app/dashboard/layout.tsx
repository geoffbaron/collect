import { redirect } from "next/navigation";
import { getProfile, getUser } from "@/lib/data";
import { DashboardNav } from "@/components/DashboardNav";

export const dynamic = "force-dynamic";

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const user = await getUser();
  if (!user) redirect("/login");
  const profile = await getProfile();

  return (
    <div className="min-h-screen bg-slate-50">
      <DashboardNav email={profile?.email ?? user.email} plan={profile?.plan} />
      <main className="mx-auto max-w-6xl px-4 py-8">{children}</main>
    </div>
  );
}
