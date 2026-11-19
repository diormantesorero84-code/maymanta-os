// Cliente Supabase. Mientras no haya claves en .env.local, la app sigue funcionando
// como maqueta (supabase = null, supabaseConfigured = false).
// Acepta la clave nueva (publishable, sb_...) o la clásica (anon, eyJ...).
import { createClient, SupabaseClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabaseConfigured: boolean = Boolean(url && key);

export const supabase: SupabaseClient | null = supabaseConfigured
  ? createClient(url as string, key as string)
  : null;
