"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { GRANTABLE_ROLES, type AccountRole } from "@/lib/types";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isGrantableRole(role: string): role is (typeof GRANTABLE_ROLES)[number] {
  return (GRANTABLE_ROLES as readonly string[]).includes(role);
}

/** The caller's user id + active account id, or null if signed out. */
async function currentMembership() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data: profile } = await supabase
    .from("profiles")
    .select("account_id")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile?.account_id) return null;
  return { supabase, userId: user.id, accountId: profile.account_id as string };
}

/**
 * Invites an email address to the caller's account. RLS restricts inserts to
 * owners/admins. The invite is claimed automatically when that email signs
 * up, or via the dashboard join banner for existing users — no email is sent.
 */
export async function inviteMember(email: string, role: AccountRole) {
  const normalized = email.trim().toLowerCase();
  if (!EMAIL_RE.test(normalized)) return { ok: false, error: "Enter a valid email address." };
  if (!isGrantableRole(role)) return { ok: false, error: "Unknown role." };

  const ctx = await currentMembership();
  if (!ctx) return { ok: false, error: "Not signed in." };

  // Friendlier error than the unique-index violation for repeat invites.
  const { data: existing } = await ctx.supabase
    .from("account_invites")
    .select("id")
    .eq("account_id", ctx.accountId)
    .eq("email", normalized)
    .is("claimed_at", null)
    .is("revoked_at", null)
    .maybeSingle();
  if (existing) return { ok: false, error: "That email already has a pending invite." };

  const { error } = await ctx.supabase.from("account_invites").insert({
    account_id: ctx.accountId,
    email: normalized,
    role,
    invited_by: ctx.userId,
  });
  if (error) return { ok: false, error: error.message };

  revalidatePath("/dashboard/settings/team");
  return { ok: true, error: null };
}

export async function revokeInvite(id: string) {
  const supabase = createClient();
  const { data, error } = await supabase
    .from("account_invites")
    .update({ revoked_at: new Date().toISOString() })
    .eq("id", id)
    .is("claimed_at", null)
    .select("id");
  if (error) return { ok: false, error: error.message };
  if (!data || data.length === 0) {
    return { ok: false, error: "Invite not found or you don't have permission to revoke it." };
  }
  revalidatePath("/dashboard/settings/team");
  return { ok: true, error: null };
}

/** Changes a member's role. Owners can't be changed, and you can't change yourself. */
export async function updateMemberRole(userId: string, role: AccountRole) {
  if (!isGrantableRole(role)) return { ok: false, error: "Unknown role." };
  const ctx = await currentMembership();
  if (!ctx) return { ok: false, error: "Not signed in." };
  if (userId === ctx.userId) return { ok: false, error: "You can't change your own role." };

  const { data, error } = await ctx.supabase
    .from("account_members")
    .update({ role })
    .eq("account_id", ctx.accountId)
    .eq("user_id", userId)
    .neq("role", "owner")
    .select("user_id");
  if (error) return { ok: false, error: error.message };
  if (!data || data.length === 0) {
    return { ok: false, error: "Member not found, is an owner, or you don't have permission." };
  }
  revalidatePath("/dashboard/settings/team");
  return { ok: true, error: null };
}

/**
 * Removes a member from the caller's account via the remove_account_member
 * RPC, which also points the removed user's active account back at their
 * personal account so they aren't stranded. Owners can't be removed.
 */
export async function removeMember(userId: string) {
  const ctx = await currentMembership();
  if (!ctx) return { ok: false, error: "Not signed in." };
  if (userId === ctx.userId) return { ok: false, error: "You can't remove yourself here." };

  const { error } = await ctx.supabase.rpc("remove_account_member", {
    p_account_id: ctx.accountId,
    p_user_id: userId,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/dashboard/settings/team");
  return { ok: true, error: null };
}

/** Accepts the pending invite addressed to the signed-in user's email. */
export async function acceptInvite() {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("claim_my_invite");
  if (error) return { ok: false, error: error.message };
  if (!data) return { ok: false, error: "No pending invite found for your email." };
  revalidatePath("/dashboard", "layout");
  return { ok: true, error: null };
}
