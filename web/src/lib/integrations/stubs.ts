import type { Connector, ConnectorResult, SyncUnitsResult } from "./types";

/**
 * Yardi, AppFolio, and RealPage all require a partner/reseller API agreement
 * before any integration can be built. These stubs implement the shared
 * Connector interface so the settings UI can list them alongside Buildium,
 * but every method returns a "requires partner agreement" error.
 */
function unavailable(displayName: string): ConnectorResult {
  return {
    ok: false,
    error: `${displayName} integration requires a partner API agreement — contact us to enable.`,
  };
}

function makeStubConnector(provider: Connector["provider"], displayName: string): Connector {
  return {
    provider,
    displayName,
    available: false,
    configFields: [],
    async testConnection(): Promise<ConnectorResult> {
      return unavailable(displayName);
    },
    async syncUnits(): Promise<SyncUnitsResult> {
      return unavailable(displayName);
    },
    async pushWorkOrder(): Promise<ConnectorResult> {
      return unavailable(displayName);
    },
  };
}

export const yardiConnector = makeStubConnector("yardi", "Yardi");
export const appfolioConnector = makeStubConnector("appfolio", "AppFolio");
export const realpageConnector = makeStubConnector("realpage", "RealPage");
