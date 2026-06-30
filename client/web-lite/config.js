// PWA-lite runtime config — dev default, checked into repo.
// Cloudflare Pages (or any host) may override this file per-environment
// without a source change. Loaded before the module script in index.html.
// Spec: docs/product/prompts/pwa-lite-phase3-deploy.md #2.
window.CESTOVNI_CONFIG = {
  apiBase: 'http://127.0.0.1:8787',
  allowDevTokenFallback: true,
};
