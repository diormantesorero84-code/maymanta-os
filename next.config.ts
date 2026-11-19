import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* Maqueta cliente-interactiva: desactivamos Cache Components (modo experimental
     de Next 16) para comportamiento convencional. Reevaluar al migrar a datos reales. */
  cacheComponents: false,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
