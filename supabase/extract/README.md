# Extracción del BDM (solo lectura)

`extract_bdm.py` vuelca las hojas clave del **MaymantaBDM** a CSV + JSON para la futura
carga en Supabase. **No modifica el Excel original** (lo abre con `read_only=True` y nunca guarda).

## Uso

```bash
cd supabase/extract
python extract_bdm.py            # ruta por defecto al BDM en Costos/
# o: python extract_bdm.py "ruta\al\BDM.xlsx"
```

Requiere `openpyxl` (`python -m pip install openpyxl`). Salida en `out/` (no versionada).

## Qué extrae y a dónde va (destino en la BD)

| CSV / JSON | Hoja BDM | Filas* | Destino (ver `../README.md`, migraciones) |
|---|---|---|---|
| `materias_primas` | Materias primas | 990 | `products` (MP) + `supplier_prices` |
| `maestro_productos` | Maestro Productos | 2928 | `products` + `suppliers` |
| `producciones` | Producciones | 328 | `recipes` (type=produccion) |
| `recetas_items` | Recetas de producción | 2065 | `recipe_items` (BOM; códigos TR/PR) |
| `transformaciones` | Transformaciones | 1094 | `recipes` (type=transformacion) + `yields` |
| `escandallo_carta` | Escandallo de carta | 763 | `dishes` + `dish_components` |
| `historial_precios` | Historial Precios | **0** | `supplier_prices` — hoja **vacía** (plantilla sin usar) |
| `rendimientos` | Rendimientos | 9 | `yields` |
| `list_auxiliar` | List Auxiliar | 1420 | diccionario nombre→código→unidad (`products`/`product_aliases`) |

\* Conteo del 2026-11-19; se regenera con cada ejecución (ver `out/manifest.json`).

## Notas

- Las cabeceras se normalizan (minúsculas, sin acentos). El cruce fino de columnas → tablas
  se hará en el script de **carga** (load), que todavía no existe (llega al crear Supabase).
- Los costes vienen **ya calculados** (`data_only=True` lee el valor, no la fórmula XLOOKUP).
- Algunos costes están en estado "Revisar"/"Pendiente de precio" en el BDM: se copian tal cual;
  limpiarlos es parte de la validación de Fase 3, no se inventan.
- `out/` está en `.gitignore` (contiene precios y recetas); solo `manifest.json` se puede versionar.
