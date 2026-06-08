import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Collect — AI room & asset inventory",
  description:
    "Scan any room with your phone and let AI catalog everything in it. Manage your inventory, value your stuff, and list it for sale.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
