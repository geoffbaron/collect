import { buildiumConnector } from "./buildium";
import { appfolioConnector, realpageConnector, yardiConnector } from "./stubs";
import type { Connector, IntegrationProvider } from "./types";

export const CONNECTORS: Record<IntegrationProvider, Connector> = {
  buildium: buildiumConnector,
  yardi: yardiConnector,
  appfolio: appfolioConnector,
  realpage: realpageConnector,
};

export const PROVIDER_ORDER: IntegrationProvider[] = ["buildium", "yardi", "appfolio", "realpage"];

export type { Connector, ConnectorConfigField, ConnectorResult, IntegrationProvider, IntegrationRow, IntegrationStatus, SyncUnitsResult } from "./types";
