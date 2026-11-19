// Cliente Supabase. Mientras no haya claves en .env.local, la app sigue funcionando
// como maqueta (supabase = null, supabaseConfigured = false).
import { createClient, SupabaseClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabaseConfigured: boolean = Boolean(url && anon);

export const supabase: SupabaseClient | null = supabaseConfigured
  ? createClient(url as string, anon as string)
  : null;
