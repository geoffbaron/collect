import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#7c3aed", // purple-600 — matches the app's accent
          50: "#f5f3ff",
          100: "#ede9fe",
          600: "#7c3aed",
          700: "#6d28d9",
        },
      },
    },
  },
  plugins: [],
};

export default config;
