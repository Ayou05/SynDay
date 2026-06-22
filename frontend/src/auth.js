import { createClient } from "@supabase/supabase-js";
import { config } from "./config.js";

const storage = {
  getItem: (key) => localStorage.getItem(key),
  setItem: (key, value) => localStorage.setItem(key, value),
  removeItem: (key) => localStorage.removeItem(key),
};

export const supabase =
  config.supabaseUrl && config.supabasePublishableKey
    ? createClient(config.supabaseUrl, config.supabasePublishableKey, {
        auth: {
          storage,
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: false,
        },
      })
    : null;

export async function currentSession() {
  if (config.previewMode) {
    return { access_token: "preview-token", user: { id: "preview", email: "preview@synday.local" } };
  }
  if (!supabase) return null;
  const { data } = await supabase.auth.getSession();
  return data.session;
}

export async function signIn(email, password) {
  if (!supabase) {
    throw new Error("尚未配置 Supabase");
  }
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data.session;
}

export async function signUp(email, password, displayName) {
  if (!supabase) {
    throw new Error("尚未配置 Supabase");
  }
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { display_name: displayName },
    },
  });
  if (error) throw error;
  return data.session;
}

export async function signOut() {
  if (supabase) {
    await supabase.auth.signOut();
  }
}
