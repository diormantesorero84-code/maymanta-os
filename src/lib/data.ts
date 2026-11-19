// Lecturas de datos reales desde Supabase (solo tras iniciar sesión; RLS filtra).
import { supabase } from "./supabase";

export type Counts = { products: number; recipes: number; dishes: number; supplier_prices: number };

export async function getCounts(): Promise<Counts | null> {
  if (!supabase) return null;
  const tables = ["products", "recipes", "dishes", "supplier_prices"] as const;
  const out = { products: 0, recipes: 0, dishes: 0, supplier_prices: 0 } as Counts;
  await Promise.all(
    tables.map(async (t) => {
      const { count } = await supabase!.from(t).select("*", { count: "exact", head: true });
      out[t] = count ?? 0;
    })
  );
  return out;
}

export type RecipeRow = {
  code: string;
  name: string;
  type: string | null;
  cost_computed: number | null;
  cost_status: string;
  yield_unit: string | null;
};

export async function getRecipes(opts: { limit?: number; search?: string; type?: string } = {}): Promise<RecipeRow[]> {
  if (!supabase) return [];
  let q = supabase.from("recipes").select("code,name,type,cost_computed,cost_status,yield_unit");
  if (opts.type) q = q.eq("type", opts.type);
  if (opts.search) q = q.ilike("name", `%${opts.search}%`);
  const { data, error } = await q.order("name").limit(opts.limit ?? 100);
  if (error) throw new Error(error.message);
  return (data as RecipeRow[]) ?? [];
}

export const eur = (v: number | null): string =>
  v == null ? "—" : v.toLocaleString("es-ES", { style: "currency", currency: "EUR", maximumFractionDigits: 3 });
