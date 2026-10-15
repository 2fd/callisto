// @ts-check
import { defineConfig } from "astro/config";

import tailwindcss from "@tailwindcss/vite";

import { SITE_URL } from "./src/lib/constants";

// https://astro.build/config
export default defineConfig({
  site: SITE_URL,
  output: "static",
  vite: {
    plugins: [tailwindcss()],
    server: {
      allowedHosts: ["callisto.orb.local"],
    },
  },
});
