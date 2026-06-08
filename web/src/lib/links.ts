/** Download link config — driven by env vars, with safe fallbacks. */
export const downloadLinks = {
  /** iOS app (TestFlight/App Store). Empty string → show "coming soon". */
  ios: process.env.NEXT_PUBLIC_IOS_APP_URL || "",
  /** Chrome Web Store listing for the extension, if published. */
  extensionStore: process.env.NEXT_PUBLIC_EXTENSION_STORE_URL || "",
  /** Self-hosted extension bundle, always available. */
  extensionZip: "/downloads/collect-extension.zip",
};
