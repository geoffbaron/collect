import type { WorkOrder } from "@/lib/types";

export type IntegrationProvider = "buildium" | "yardi" | "appfolio" | "realpage";

export type IntegrationStatus = "disconnected" | "connected" | "error";

export type IntegrationRow = {
  id: string;
  account_id: string;
  provider: IntegrationProvider;
  status: IntegrationStatus;
  config: Record<string, string>;
  last_synced_at: string | null;
  last_sync_error: string | null;
  created_at: string;
  updated_at: string;
};

/** Describes one credential field a connector's config form needs to collect. */
export type ConnectorConfigField = {
  key: string;
  label: string;
  type: "text" | "password";
  placeholder?: string;
};

export type ConnectorResult = { ok: true } | { ok: false; error: string };

export type SyncUnitsResult =
  | { ok: true; created: number; updated: number }
  | { ok: false; error: string };

/**
 * Common interface every PM-software connector implements. Connectors for
 * providers without a self-serve API (Yardi, AppFolio, RealPage) implement
 * this interface but return a "requires partner agreement" error from every
 * method until a real integration is built.
 */
export type Connector = {
  provider: IntegrationProvider;
  displayName: string;
  /** Whether this connector has a real implementation (vs. a stub). */
  available: boolean;
  configFields: ConnectorConfigField[];
  /** Verify the supplied credentials work against the provider's API. */
  testConnection(config: Record<string, string>): Promise<ConnectorResult>;
  /** Pull units for a property from the provider and upsert into `units`. */
  syncUnits(
    accountId: string,
    propertyId: string,
    config: Record<string, string>
  ): Promise<SyncUnitsResult>;
  /** Push a work order to the provider's maintenance/task system. */
  pushWorkOrder(workOrder: WorkOrder, config: Record<string, string>): Promise<ConnectorResult>;
};
