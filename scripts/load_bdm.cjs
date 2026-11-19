/**
 * MAYMANTA OS - Carga del BDM en Supabase.
 * Lee los JSON de supabase/extract/out/ y los sube a las tablas.
 *
 * Necesita la CLAVE DE SERVICIO (secreta) en .env.local como:
 *   SUPABASE_SERVICE_ROLE_KEY=...        (NO lleva NEXT_PUBLIC_, es solo local)
 * La clave de servicio salta la seguridad RLS para poder cargar en masa.
 * Se queda en tu PC; nunca se sube a git (.env.local está en .gitignore).
 *
 * Uso:  node scripts/load_bdm.cjs
 */
const fs = require("fs");
const path = require("path");
const { createClient } = require("@supabase/supabase-js");

const ROOT = path.resolve(__dirname, "..");
const OUT = path.join(ROOT, "supabase", "extract", "out");

// --- leer .env.local ---
const env = fs.readFileSync(path.join(ROOT, ".env.local"), "utf8");
const envGet = (k) => { const m = env.match(new RegExp("^" + k + "=(.*)$", "m")); return m ? m[1].trim() : ""; };
const URL = envGet("NEXT_PUBLIC_SUPABASE_URL");
const SERVICE = envGet("SUPABASE_SERVICE_ROLE_KEY");
if (!URL || !SERVICE) {
  console.error("\n[!] Falta la clave de servicio.\n" +
    "    Añade a maymanta-os/.env.local esta línea (con tu clave service_role / secret):\n" +
    "    SUPABASE_SERVICE_ROLE_KEY=...\n");
  process.exit(1);
}
const sb = createClient(URL, SERVICE, { auth: { persistSession: false } });

// --- helpers ---
const read = (f) => JSON.parse(fs.readFileSync(path.join(OUT, f + ".json"), "utf8"));
const num = (v) => { if (v === "" || v == null) return null; const n = Number(v); return Number.isFinite(n) ? n : null; };
const txt = (v) => (v == null ? null : String(v).trim() || null);
const up = (s) => String(s || "").trim().toUpperCase();

async function chunkedInsert(table, rows, { upsert = false, onConflict } = {}) {
  const SIZE = 500;
  let done = 0;
  for (let i = 0; i < rows.length; i += SIZE) {
    const slice = rows.slice(i, i + SIZE);
    const q = upsert ? sb.from(table).upsert(slice, { onConflict }) : sb.from(table).insert(slice);
    const { error } = await q;
    if (error) throw new Error(`${table}: ${error.message}`);
    done += slice.length;
  }
  return done;
}
async function deleteAll(table) {
  const { error } = await sb.from(table).delete().not("id", "is", null);
  if (error) throw new Error(`delete ${table}: ${error.message}`);
}
async function codeMap(table) {
  const map = {};
  let from = 0; const PAGE = 1000;
  for (;;) {
    const { data, error } = await sb.from(table).select("id,code").range(from, from + PAGE - 1);
    if (error) throw new Error(`map ${table}: ${error.message}`);
    for (const r of data) if (r.code) map[up(r.code)] = r.id;
    if (data.length < PAGE) break;
    from += PAGE;
  }
  return map;
}
const comp = (code) => {
  const c = up(code);
  if (c.startsWith("MP-")) return { type: "product", code: c };
  if (c.startsWith("TR-") || c.startsWith("PR-")) return { type: "recipe", code: c };
  return null;
};

async function main() {
  console.log("Cargando BDM en Supabase…\n");

  // 1) PRODUCTS (materias primas)
  const mp = read("materias_primas");
  const products = mp.filter((r) => up(r["id mp"]).startsWith("MP-")).map((r) => ({
    code: up(r["id mp"]),
    name: txt(r["materia prima"]) || up(r["id mp"]),
    category: txt(r["tipo"]),
    unit_base: txt(r["unidad"]),
    source_ref: "BDM:Materias primas",
  }));
  console.log("1) products …", await chunkedInsert("products", products, { upsert: true, onConflict: "code" }), "filas");
  const productMap = await codeMap("products");

  // 2) RECIPES (producciones PR + transformaciones TR)
  const prod = read("producciones");
  const recProd = prod.filter((r) => up(r["codigo pr"]).startsWith("PR-")).map((r) => ({
    code: up(r["codigo pr"]),
    name: txt(r["produccion"]) || up(r["codigo pr"]),
    type: "produccion",
    yield_qty: num(r["rendimiento"]),
    yield_unit: txt(r["unidad"]),
    is_own_production: true,
    cost_computed: num(r["coste por unidad (€)"]),
    cost_status: /complet/i.test(String(r["estado"] || "")) ? "ok" : "revisar",
    source_ref: "BDM:Producciones",
  }));
  const tr = read("transformaciones");
  const recTr = tr.filter((r) => up(r["codigo"]).startsWith("TR-")).map((r) => ({
    code: up(r["codigo"]),
    name: txt(r["producto transformado"]) || up(r["codigo"]),
    type: "transformacion",
    yield_qty: num(r["rendimiento"]),
    yield_unit: txt(r["unidad"]),
    is_own_production: true,
    cost_computed: num(r["coste (€/unidad)"]),
    cost_status: /complet|ok/i.test(String(r["estado"] || "")) ? "ok" : "revisar",
    source_ref: "BDM:Transformaciones",
  }));
  // dedup por code (nos quedamos con el primero)
  const seen = new Set();
  const recipes = [...recProd, ...recTr].filter((r) => (seen.has(r.code) ? false : seen.add(r.code)));
  console.log("2) recipes …", await chunkedInsert("recipes", recipes, { upsert: true, onConflict: "code" }), "filas");
  const recipeMap = await codeMap("recipes");

  // 3) SUPPLIER_PRICES (coste de materias primas)
  await deleteAll("supplier_prices");
  const prices = mp.filter((r) => productMap[up(r["id mp"])] && num(r["coste (€/unidad)"]) != null).map((r) => ({
    product_id: productMap[up(r["id mp"])],
    price: num(r["coste (€/unidad)"]),
    unit: txt(r["unidad"]),
    source_ref: "BDM:Materias primas/" + (txt(r["origen del precio"]) || ""),
  }));
  console.log("3) supplier_prices …", await chunkedInsert("supplier_prices", prices), "filas");

  // 4) DISHES (platos únicos del escandallo de carta)
  await deleteAll("dish_components");
  await deleteAll("dishes");
  const esc = read("escandallo_carta");
  const platos = [...new Set(esc.map((r) => txt(r["plato"])).filter(Boolean))];
  const dishes = platos.map((p) => ({
    name: p,
    is_event: /\(EVENTO\)/i.test(p),
    source_ref: "BDM:Escandallo de carta",
  }));
  console.log("4) dishes …", await chunkedInsert("dishes", dishes), "filas");
  // mapa nombre->id
  const dishMap = {};
  { let from = 0; const PAGE = 1000;
    for (;;) { const { data, error } = await sb.from("dishes").select("id,name").range(from, from + PAGE - 1);
      if (error) throw new Error("map dishes: " + error.message);
      for (const d of data) dishMap[d.name] = d.id;
      if (data.length < PAGE) break; from += PAGE; } }

  // 5) RECIPE_ITEMS (BOM de las producciones)
  await deleteAll("recipe_items");
  const ri = read("recetas_items");
  const riRows = [];
  let riSkip = 0;
  for (const r of ri) {
    const recipeId = recipeMap[up(r["codigo pr"])];
    const c = comp(r["codigo tr / pr"]);
    if (!recipeId || !c) { riSkip++; continue; }
    if (c.type === "recipe" && recipeMap[c.code]) {
      riRows.push({ recipe_id: recipeId, component_type: "recipe", child_recipe_id: recipeMap[c.code], qty: num(r["cantidad"]) ?? 0, unit: txt(r["unidad"]) });
    } else if (c.type === "product" && productMap[c.code]) {
      riRows.push({ recipe_id: recipeId, component_type: "product", product_id: productMap[c.code], qty: num(r["cantidad"]) ?? 0, unit: txt(r["unidad"]) });
    } else { riSkip++; }
  }
  console.log("5) recipe_items …", await chunkedInsert("recipe_items", riRows), "filas", `(${riSkip} sin resolver)`);

  // 6) DISH_COMPONENTS (escandallo de carta)
  const dcRows = [];
  let dcSkip = 0;
  for (const r of esc) {
    const dishId = dishMap[txt(r["plato"])];
    const c = comp(r["codigo"]);
    if (!dishId || !c) { dcSkip++; continue; }
    if (c.type === "recipe" && recipeMap[c.code]) {
      dcRows.push({ dish_id: dishId, component_type: "recipe", recipe_id: recipeMap[c.code], qty_per_portion: num(r["cantidad (receta)"]) ?? 0, unit: null });
    } else if (c.type === "product" && productMap[c.code]) {
      dcRows.push({ dish_id: dishId, component_type: "product", product_id: productMap[c.code], qty_per_portion: num(r["cantidad (receta)"]) ?? 0, unit: null });
    } else { dcSkip++; }
  }
  console.log("6) dish_components …", await chunkedInsert("dish_components", dcRows), "filas", `(${dcSkip} sin resolver)`);

  console.log("\n✓ Carga terminada.");
}

main().catch((e) => { console.error("\n[ERROR]", e.message); process.exit(1); });
