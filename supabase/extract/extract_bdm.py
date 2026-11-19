#!/usr/bin/env python3
"""
MAYMANTA OS - Extracción del BDM (SOLO LECTURA).

Vuelca las hojas clave del MaymantaBDM a CSV + JSON para la futura carga en
Supabase (ver supabase/README.md y Documentación/MAYMANTA_OS/03_Modelo_Datos.md).

NO modifica el Excel original: abre con read_only=True y nunca guarda.
Uso:
    python extract_bdm.py                # usa la ruta por defecto
    python extract_bdm.py "ruta\\al\\BDM.xlsx"
Salida en:  supabase/extract/out/
"""
import csv
import json
import sys
import unicodedata
from datetime import datetime, date
from pathlib import Path

try:
    import openpyxl
except ImportError:
    sys.exit("Falta openpyxl. Instala con:  python -m pip install openpyxl")

DEFAULT_BDM = r"C:\Users\HP\OneDrive\Maymanta Nuevo\Costos\MaymantaBDM_escandallos_BCN_IBZ.xlsx"
OUT_DIR = Path(__file__).resolve().parent / "out"

# (hoja, token_de_cabecera, nombre_salida, destino_en_la_BD)
EXTRACTS = [
    ("Materias primas",        "id mp",                 "materias_primas",      "products (materias primas) + supplier_prices"),
    ("Maestro Productos",      "id producto",           "maestro_productos",    "products + suppliers"),
    ("Producciones",           "codigo pr",             "producciones",         "recipes (type=produccion)"),
    ("Recetas de producción",  "ingrediente",           "recetas_items",        "recipe_items (BOM)"),
    ("Transformaciones",       "producto transformado", "transformaciones",     "recipes (type=transformacion) + yields"),
    ("Escandallo de carta",    "plato",                 "escandallo_carta",     "dishes + dish_components"),
    ("Historial Precios",      "fecha",                 "historial_precios",    "supplier_prices (histórico)"),
    ("Rendimientos",           "bruto total",           "rendimientos",         "yields"),
    ("List Auxiliar",          "unidad de medida",      "list_auxiliar",        "products / product_aliases (diccionario)"),
]


def norm(s):
    if s is None:
        return ""
    s = str(s).strip().lower()
    s = "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")
    return " ".join(s.split())


def cell(v):
    if v is None:
        return ""
    if isinstance(v, (datetime, date)):
        return v.isoformat()[:19]
    return v


def find_header(ws, token, scan=12):
    """Devuelve (indice_fila, lista_cabeceras) de la primera fila que contiene token."""
    for i, row in enumerate(ws.iter_rows(min_row=1, max_row=scan, values_only=True)):
        if any(token in norm(c) for c in row):
            # ancho = última celda no vacía de la cabecera
            last = max((j for j, c in enumerate(row) if norm(c)), default=-1)
            headers = [norm(c) or f"col_{j}" for j, c in enumerate(row[: last + 1])]
            return i + 1, headers  # 1-based para openpyxl
    return None, None


def extract_sheet(ws, token):
    hrow, headers = find_header(ws, token)
    if hrow is None:
        return headers, []
    width = len(headers)
    rows, empties = [], 0
    for row in ws.iter_rows(min_row=hrow + 1, values_only=True):
        vals = list(row[:width]) + [None] * (width - len(row))
        if all(norm(c) == "" for c in vals):
            empties += 1
            if empties >= 40:   # corta colas largas de filas vacías
                break
            continue
        empties = 0
        rows.append([cell(c) for c in vals])
    return headers, rows


def main():
    bdm = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(DEFAULT_BDM)
    if not bdm.exists():
        sys.exit(f"No encuentro el BDM: {bdm}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Leyendo (solo lectura): {bdm.name}")
    wb = openpyxl.load_workbook(bdm, read_only=True, data_only=True)

    manifest = {"fuente": bdm.name, "generado": datetime.now().isoformat()[:19], "tablas": []}
    for sheet, token, out, destino in EXTRACTS:
        if sheet not in wb.sheetnames:
            print(f"  [!] hoja no encontrada: {sheet}")
            continue
        headers, rows = extract_sheet(wb[sheet], token)
        if headers is None:
            print(f"  [!] sin cabecera en: {sheet}")
            continue
        with open(OUT_DIR / f"{out}.csv", "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(headers)
            w.writerows(rows)
        with open(OUT_DIR / f"{out}.json", "w", encoding="utf-8") as f:
            json.dump([dict(zip(headers, r)) for r in rows], f, ensure_ascii=False, indent=0)
        manifest["tablas"].append({"hoja": sheet, "salida": out, "filas": len(rows),
                                   "columnas": len(headers), "destino_bd": destino})
        print(f"  OK  {sheet:24s} -> {out:20s} {len(rows):5d} filas x {len(headers)} col")
    wb.close()

    with open(OUT_DIR / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"\nSalida en: {OUT_DIR}")
    print("El BDM original NO se ha modificado (solo lectura).")


if __name__ == "__main__":
    main()
