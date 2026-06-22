export const config = Object.freeze({
  apiBaseUrl: (import.meta.env.VITE_API_BASE_URL || "http://localhost:8080").replace(/\/$/, ""),
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL || "",
  supabasePublishableKey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || "",
  previewMode: import.meta.env.VITE_PREVIEW_MODE === "true",
  goEasyHost: import.meta.env.VITE_GOEASY_HOST || "hangzhou.goeasy.io",
  goEasyAppKey: import.meta.env.VITE_GOEASY_APP_KEY || "",
});
