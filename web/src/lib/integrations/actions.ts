"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getWorkOrder } from "@/lib/data";
import { CONNECTORS } from "./index";
import type { IntegrationProvider, IntegrationRow } from "./types";

const SETTINGS_PATH = "/dashboard/settings/integrations";

export async function getIntegrations(): Promise<IntegrationRow[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("integrations")
    .select("id, account_id, provider, status, config, last_synced_at, last_sync_error, created_at, updated_at")
    .order("provider");
  return (data as IntegrationRow[]) ?? [];
}

/**
 * Tests the supplied credentials against the provider's API and, if they
 * work, upserts the integration row as `connected`. RLS restricts this to
 * account owners/admins.
 */
export async function connectIntegration(
  provider: IntegrationProvider,
  config: Record<string, string>
) {
  const connector = CONNECTORS[provider];
  const result = await connector.testConnection(config);

  const supabase = createClient();

  if (!result.ok) {
    const { error } = await supabase
      .from("integrations")
      .upsert({ provider, status: "error", config, last_sync_error: result.error }, { onConflict: "account_id,provider" });
    if (error) return { ok: false as const, error: error.message };
    revalidatePath(SETTINGS_PATH);
    return { ok: false as const, error: result.error };
  }

  const { error } = await supabase
    .from("integrations")
    .upsert({ provider, status: "connected", config, last_sync_error: null }, { onConflict: "account_id,provider" });

  if (error) return { ok: false as const, error: error.message };

  revalidatePath(SETTINGS_PATH);
  return { ok: true as const };
}

export async function disconnectIntegration(provider: IntegrationProvider) {
  const supabase = createClient();
  const { error } = await supabase
    .from("integrations")
    .update({ status: "disconnected", config: {}, last_sync_error: null })
    .eq("provider", provider);

  if (error) return { ok: false as const, error: error.message };

  revalidatePath(SETTINGS_PATH);
  return { ok: true as const };
}

/**
 * Pulls units for a property from the connected provider and upserts them.
 * Sync is on-demand (no background jobs yet) — triggered from the settings UI.
 */
export async function syncIntegration(provider: IntegrationProvider, propertyId: string) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false as const, error: "Not signed in." };

  const { data: integration, error: integrationError } = await supabase
    .from("integrations")
    .select("account_id, config, status")
    .eq("provider", provider)
    .maybeSingle();

  if (integrationError) return { ok: false as const, error: integrationError.message };
  if (!integration || integration.status !== "connected") {
    return { ok: false as const, error: "This integration is not connected." };
  }

  const connector = CONNECTORS[provider];
  const result = await connector.syncUnits(integration.account_id, propertyId, integration.config);

  if (!result.ok) {
    await supabase
      .from("integrations")
      .update({ status: "error", last_sync_error: result.error })
      .eq("provider", provider);
    revalidatePath(SETTINGS_PATH);
    return { ok: false as const, error: result.error };
  }

  await supabase
    .from("integrations")
    .update({ last_synced_at: new Date().toISOString(), last_sync_error: null })
    .eq("provider", provider);

  revalidatePath(SETTINGS_PATH);
  return { ok: true as const, created: result.created, updated: result.updated };
}

/**
 * Pushes a work order to the connected provider's maintenance/task system.
 */
export async function pushWorkOrderToIntegration(provider: IntegrationProvider, workOrderId: string) {
  const supabase = createClient();

  const { data: integration, error: integrationError } = await supabase
    .from("integrations")
    .select("config, status")
    .eq("provider", provider)
    .maybeSingle();

  if (integrationError) return { ok: false as const, error: integrationError.message };
  if (!integration || integration.status !== "connected") {
    return { ok: false as const, error: "This integration is not connected." };
  }

  const workOrder = await getWorkOrder(workOrderId);
  if (!workOrder) return { ok: false as const, error: "Work order not found." };

  const connector = CONNECTORS[provider];
  const result = await connector.pushWorkOrder(workOrder, integration.config);
  if (!result.ok) return { ok: false as const, error: result.error };

  return { ok: true as const };
}
