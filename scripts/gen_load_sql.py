#!/usr/bin/env python3
"""
Genera supabase/load_bdm.sql a partir de los JSON de supabase/extract/out/.
El SQL se pega en el SQL Editor de Supabase (corre como admin, sin clave de servicio).
Re-ejecutable: borra las tablas hijas y hace upsert de products/recipes por code.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "supabase" / "extract" / "out"
DEST = ROOT / "supabase" / "load_bdm.sql"


def rd(name):
    return json.loads((OUT / f"{name}.json").read_text(encoding="utf-8"))


def s(v):
    if v is None or str(v).strip() == "":
        return "NULL"
    return "'" + str(v).strip().replace("'", "''") + "'"


def n(v, default="NULL"):
    if v is None or str(v).strip() == "":
        return default
    try:
        return repr(float(v))
    except (ValueError, TypeError):
        return default


def up(v):
    return str(v or "").strip().upper()


def kind(code):
    c = up(code)
    if c.startswith("MP-"):
        return "product"
    if c.startswith("TR-") or c.startswith("PR-"):
        return "recipe"
    return None


def values_block(rows, per=200):
    """Une tuplas en varios INSERT para no hacer una sentencia gigante."""
    out = []
    for i in range(0, len(rows), per):
        out.append(",\n".join(rows[i:i + per]))
    return out


lines = ["-- MAYMANTA OS - carga del BDM (pegar en SQL Editor y RUN). Re-ejecutable.",
         "-- Generado por scripts/gen_load_sql.py desde supabase/extract/out/.", ""]
lines.append("truncate table dish_components, recipe_items, supplier_prices, dishes cascade;")
lines.append("")

# 1) products (materias primas)
mp = rd("materias_primas")
prod_rows = []
for r in mp:
    code = up(r.get("id mp"))
    if not code.startswith("MP-"):
        continue
    prod_rows.append(f"({s(code)},{s(r.get('materia prima') or code)},{s(r.get('tipo'))},{s(r.get('unidad'))},'BDM:Materias primas')")
lines.append("-- products")
for blk in values_block(prod_rows):
    lines.append("insert into public.products (code,name,category,unit_base,source_ref) values")
    lines.append(blk)
    lines.append("on conflict (code) do nothing;")
lines.append("")

# 2) recipes (producciones PR + transformaciones TR)
rec_rows, seen = [], set()
for r in rd("producciones"):
    code = up(r.get("codigo pr"))
    if not code.startswith("PR-") or code in seen:
        continue
    seen.add(code)
    st = "'ok'" if "complet" in str(r.get("estado") or "").lower() else "'revisar'"
    rec_rows.append(f"({s(code)},{s(r.get('produccion') or code)},'produccion',{n(r.get('rendimiento'))},{s(r.get('unidad'))},true,{n(r.get('coste por unidad (€)'))},{st},'BDM:Producciones')")
for r in rd("transformaciones"):
    code = up(r.get("codigo"))
    if not code.startswith("TR-") or code in seen:
        continue
    seen.add(code)
    st = "'ok'" if "complet" in str(r.get("estado") or "").lower() else "'revisar'"
    rec_rows.append(f"({s(code)},{s(r.get('producto transformado') or code)},'transformacion',{n(r.get('rendimiento'))},{s(r.get('unidad'))},true,{n(r.get('coste (€/unidad)'))},{st},'BDM:Transformaciones')")
lines.append("-- recipes")
for blk in values_block(rec_rows):
    lines.append("insert into public.recipes (code,name,type,yield_qty,yield_unit,is_own_production,cost_computed,cost_status,source_ref) values")
    lines.append(blk)
    lines.append("on conflict (code) do nothing;")
lines.append("")

# 3) supplier_prices (coste de materias primas) via join por code
price_rows = []
for r in mp:
    code = up(r.get("id mp"))
    if not code.startswith("MP-") or n(r.get("coste (€/unidad)")) == "NULL":
        continue
    price_rows.append(f"({s(code)},{n(r.get('coste (€/unidad)'))},{s(r.get('unidad'))})")
lines.append("-- supplier_prices")
for blk in values_block(price_rows):
    lines.append("insert into public.supplier_prices (product_id,price,unit,source_ref)")
    lines.append("select p.id, v.price::numeric, v.unit, 'BDM:Materias primas'")
    lines.append("from (values\n" + blk + "\n) as v(code,price,unit) join public.products p on p.code=v.code;")
lines.append("")

# 4) dishes (platos únicos del escandallo)
esc = rd("escandallo_carta")
platos = []
seenp = set()
for r in esc:
    p = (r.get("plato") or "").strip()
    if p and p not in seenp:
        seenp.add(p)
        platos.append(p)
dish_rows = [f"({s(p)},{str('(EVENTO)' in p.upper()).lower()},'BDM:Escandallo de carta')" for p in platos]
lines.append("-- dishes")
for blk in values_block(dish_rows):
    lines.append("insert into public.dishes (name,is_event,source_ref) values")
    lines.append(blk)
    lines.append(";")
lines.append("")

# 5) recipe_items (BOM) - separar componente receta vs producto
ri = rd("recetas_items")
ri_rec, ri_prod = [], []
for r in ri:
    rc = up(r.get("codigo pr"))
    cc = up(r.get("codigo tr / pr"))
    k = kind(cc)
    if not rc.startswith("PR-") or not k:
        continue
    qty = n(r.get("cantidad"), "0")
    unit = s(r.get("unidad"))
    if k == "recipe":
        ri_rec.append(f"({s(rc)},{s(cc)},{qty},{unit})")
    else:
        ri_prod.append(f"({s(rc)},{s(cc)},{qty},{unit})")
lines.append("-- recipe_items (componente = receta)")
for blk in values_block(ri_rec):
    lines.append("insert into public.recipe_items (recipe_id,component_type,child_recipe_id,qty,unit)")
    lines.append("select r.id,'recipe',c.id,v.qty::numeric,v.unit")
    lines.append("from (values\n" + blk + "\n) as v(rc,cc,qty,unit) join public.recipes r on r.code=v.rc join public.recipes c on c.code=v.cc;")
lines.append("-- recipe_items (componente = producto)")
for blk in values_block(ri_prod):
    lines.append("insert into public.recipe_items (recipe_id,component_type,product_id,qty,unit)")
    lines.append("select r.id,'product',p.id,v.qty::numeric,v.unit")
    lines.append("from (values\n" + blk + "\n) as v(rc,cc,qty,unit) join public.recipes r on r.code=v.rc join public.products p on p.code=v.cc;")
lines.append("")

# 6) dish_components (escandallo de carta)
dc_rec, dc_prod = [], []
for r in esc:
    pl = (r.get("plato") or "").strip()
    cc = up(r.get("codigo"))
    k = kind(cc)
    if not pl or not k:
        continue
    qty = n(r.get("cantidad (receta)"), "0")
    if k == "recipe":
        dc_rec.append(f"({s(pl)},{s(cc)},{qty})")
    else:
        dc_prod.append(f"({s(pl)},{s(cc)},{qty})")
lines.append("-- dish_components (componente = receta)")
for blk in values_block(dc_rec):
    lines.append("insert into public.dish_components (dish_id,component_type,recipe_id,qty_per_portion)")
    lines.append("select d.id,'recipe',c.id,v.qty::numeric")
    lines.append("from (values\n" + blk + "\n) as v(pl,cc,qty) join public.dishes d on d.name=v.pl join public.recipes c on c.code=v.cc;")
lines.append("-- dish_components (componente = producto)")
for blk in values_block(dc_prod):
    lines.append("insert into public.dish_components (dish_id,component_type,product_id,qty_per_portion)")
    lines.append("select d.id,'product',p.id,v.qty::numeric")
    lines.append("from (values\n" + blk + "\n) as v(pl,cc,qty) join public.dishes d on d.name=v.pl join public.products p on p.code=v.cc;")
lines.append("")
lines.append("-- conteos")
lines.append("select 'products' t, count(*) from public.products union all select 'recipes', count(*) from public.recipes union all select 'supplier_prices', count(*) from public.supplier_prices union all select 'dishes', count(*) from public.dishes union all select 'recipe_items', count(*) from public.recipe_items union all select 'dish_components', count(*) from public.dish_components;")

DEST.write_text("\n".join(lines), encoding="utf-8")
print("Escrito:", DEST)
print("Tamaño:", round(DEST.stat().st_size / 1024, 1), "KB")
print("products:", len(prod_rows), "| recipes:", len(rec_rows), "| prices:", len(price_rows),
      "| dishes:", len(dish_rows), "| recipe_items:", len(ri_rec) + len(ri_prod),
      "| dish_components:", len(dc_rec) + len(dc_prod))
