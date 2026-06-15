import Link from "next/link";
import { getAccountMembers, getMyRole, getPendingInvites, getUser } from "@/lib/data";
import { TeamSettings } from "./TeamSettings";

export const dynamic = "force-dynamic";

export default async function TeamSettingsPage() {
  const [user, myRole, members, invites] = await Promise.all([
    getUser(),
    getMyRole(),
    getAccountMembers(),
    getPendingInvites(),
  ]);
  const canManage = myRole === "owner" || myRole === "admin";

  return (
    <div className="space-y-6">
      <div>
        <Link href="/dashboard/settings" className="text-sm text-slate-500 hover:text-slate-700">
          ← Settings
        </Link>
        <h1 className="mt-2 text-2xl font-bold text-slate-900">Team</h1>
        <p className="text-slate-500">
          Invite teammates and control what they can do. Maintenance staff see their assigned work
          orders in the mobile app.
        </p>
      </div>

      <TeamSettings
        members={members}
        invites={invites}
        currentUserId={user?.id ?? ""}
        canManage={canManage}
      />
    </div>
  );
}
