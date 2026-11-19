# MAYMANTA OS — Base de datos (Supabase / PostgreSQL)

Esquema **v0.1**, derivado de `Documentación/MAYMANTA_OS/03_Modelo_Datos.md` y `04_Matriz_Permisos.md`.

> ⚠️ **Todavía NO aplicado a ninguna base de datos.** Son ficheros de migración listos para cuando
> se dé de alta el proyecto Supabase (decisión D3). El Excel sigue siendo la fuente oficial hasta
> migrar y validar por módulo. Nada de esto toca los archivos originales.

## Orden de migraciones

| Fichero | Contenido |
|---|---|
| `migrations/0001_core.sql` | Extensiones, `centers`, `roles`, `permissions`, `users`, `user_center_roles`, `approvals`, `audit_logs`, funciones helper y triggers comunes |
| `migrations/0002_catalogo.sql` | `products`, `product_aliases`, `suppliers`, `supplier_prices`, `yields` |
| `migrations/0003_recetas.sql` | `recipes`, `recipe_items` (BOM recursivo), `dishes`, `dish_components`, `cocktails`, `cocktail_items`, `menu_engineering` |
| `migrations/0004_eventos.sql` | `events`, `event_lines`, `production_orders`, `production_lines`, `purchase_orders`, `purchase_lines`, `rules` |
| `migrations/0005_operacion.sql` | `purchases_history`, `inventory_counts`, `inventory_lines`, `kardex_movements`, `abc_classification`, `sales`, `food_cost_periods` |
| `migrations/0006_documentos.sql` | `documents` (originales inmutables + generados versionados) |
| `migrations/0007_rls_policies.sql` | Habilita RLS y define políticas por rol/módulo/acción y por sede |
| `seed.sql` | Sedes (BCN/IBZ/MEN), roles, matriz de permisos y reglas base (R01…) |

## Cómo aplicarlo (cuando exista el proyecto Supabase)

**Opción A — Supabase CLI** (recomendado):
```bash
supabase link --project-ref <ref>
supabase db push          # aplica migrations/ en orden
psql "$DATABASE_URL" -f supabase/seed.sql
```

**Opción B — SQL Editor del panel**: pegar cada fichero en orden (0001 → 0007), luego `seed.sql`.

## Decisiones de diseño (v0.1)

- **Catálogo global** (`products`, `recipes`, `dishes`): compartido entre sedes. Lo específico de sede
  (precios, inventario, ventas, eventos) lleva `center_id`. *A revisar si BCN/IBZ/MEN necesitan costes distintos por sede.*
- **RLS por sede**: cada fila operativa se filtra por las sedes del usuario (`user_center_roles`), no solo en la UI.
- **Append-only**: `audit_logs` y los documentos originales (`documents.is_original`) no se actualizan ni borran.
- **Baja lógica** (`is_active=false`) en vez de borrado físico.
- `source_ref` en cada tabla migrada → rastrea el origen del dato (BDM, maestro, etc.).
