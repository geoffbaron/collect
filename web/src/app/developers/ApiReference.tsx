"use client";

import { useEffect } from "react";

const SWAGGER_VERSION = "5.17.14";

export function ApiReference() {
  useEffect(() => {
    const cssId = "swagger-ui-css";
    if (!document.getElementById(cssId)) {
      const link = document.createElement("link");
      link.id = cssId;
      link.rel = "stylesheet";
      link.href = `https://cdn.jsdelivr.net/npm/swagger-ui-dist@${SWAGGER_VERSION}/swagger-ui.css`;
      document.head.appendChild(link);
    }

    const scriptId = "swagger-ui-bundle";
    function init() {
      // @ts-expect-error -- loaded from CDN
      window.SwaggerUIBundle?.({
        url: "/openapi.yaml",
        domNode: document.getElementById("swagger-ui"),
        deepLinking: true,
        presets: [
          // @ts-expect-error -- loaded from CDN
          window.SwaggerUIBundle.presets.apis,
        ],
      });
    }

    if (document.getElementById(scriptId)) {
      init();
      return;
    }

    const script = document.createElement("script");
    script.id = scriptId;
    script.src = `https://cdn.jsdelivr.net/npm/swagger-ui-dist@${SWAGGER_VERSION}/swagger-ui-bundle.js`;
    script.onload = init;
    document.body.appendChild(script);
  }, []);

  return <div id="swagger-ui" />;
}
