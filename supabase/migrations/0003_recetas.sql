-- ============================================================
-- MAYMANTA OS · 0003 recetas, sub-recetas y escandallos
-- De BDM: Recetas de producción / Producciones / Transformaciones /
--         Escandallo de carta / Resumen carta / Cócteles / Matriz Menú.
-- ============================================================

-- ---- Recetas / producciones / transformaciones ----
create table public.recipes (
  id                uuid primary key default gen_random_uuid(),
  code              text unique,                 -- PR-xxx / EV-xxx
  name              text not null,
  type              text,                         -- produccion | transformacion
  yield_qty         numeric,
  yield_unit        text,
  is_own_production boolean not null default true, -- propio vs comprado hecho
  cost_computed     numeric(12,4),
  cost_status       text not null default 'revisar' check (cost_status in ('ok','revisar')),
  source_ref        text,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid references public.users(id),
  updated_by        uuid references public.users(id)
);
create trigger t_recipes_upd before update on public.recipes
  for each row execute function public.tg_set_updated_at();

-- ---- BOM recursivo: una receta contiene productos y/o sub-recetas ----
-- Esto es lo que permite la "explosión de materias primas" (R08).
create table public.recipe_items (
  id             uuid primary key default gen_random_uuid(),
  recipe_id      uuid not null references public.recipes(id) on delete cascade,
  component_type text not null check (component_type in ('product','recipe')),
  product_id     uuid references public.products(id),
  child_recipe_id uuid references public.recipes(id),
  qty            numeric not null,
  unit           text,
  merma_pct      numeric not null default 0,
  created_at     timestamptz not null default now(),
  check (
    (component_type = 'product' and product_id is not null and child_recipe_id is null) or
    (component_type = 'recipe'  and child_recipe_id is not null and product_id is null)
  ),
  check (child_recipe_id is null or child_recipe_id <> recipe_id)  -- evita auto-referencia directa
);
create index on public.recipe_items (recipe_id);
create index on public.recipe_items (child_recipe_id);
-- Nota: los ciclos indirectos (A→B→A) deben evitarse en la app o con un trigger de validación (pendiente).

-- ---- Platos de carta / evento ----
create table public.dishes (
  id            uuid primary key default gen_random_uuid(),
  code          text unique,                    -- EV-xxx
  name          text not null,
  category      text,
  is_event      boolean not null default false,
  pvp           numeric(12,4),
  cost_computed numeric(12,4),
  cost_status   text not null default 'revisar' check (cost_status in ('ok','revisar')),
  source_ref    text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid references public.users(id),
  updated_by    uuid references public.users(id)
);
create trigger t_dishes_upd before update on public.dishes
  for each row execute function public.tg_set_updated_at();

create table public.dish_components (
  id               uuid primary key default gen_random_uuid(),
  dish_id          uuid not null references public.dishes(id) on delete cascade,
  component_type   text not null check (component_type in ('product','recipe')),
  product_id       uuid references public.products(id),
  recipe_id        uuid references public.recipes(id),
  qty_per_portion  numeric not null,
  unit             text,
  check (
    (component_type = 'product' and product_id is not null and recipe_id is null) or
    (component_type = 'recipe'  and recipe_id is not null and product_id is null)
  )
);
create index on public.dish_components (dish_id);

-- ---- Cócteles (mismo motor) ----
create table public.cocktails (
  id            uuid primary key default gen_random_uuid(),
  code          text unique,
  name          text not null,
  pvp           numeric(12,4),
  cost_computed numeric(12,4),
  cost_status   text not null default 'revisar' check (cost_status in ('ok','revisar')),
  source_ref    text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);
create table public.cocktail_items (
  id              uuid primary key default gen_random_uuid(),
  cocktail_id     uuid not null references public.cocktails(id) on delete cascade,
  product_id      uuid references public.products(id),
  qty             numeric not null,
  unit            text
);

-- ---- Ingeniería de menú (Matriz Menú) ----
create table public.menu_engineering (
  id         uuid primary key default gen_random_uuid(),
  dish_id    uuid not null references public.dishes(id) on delete cascade,
  center_id  uuid references public.centers(id),
  period     text,
  popularity numeric,
  margin     numeric,
  class      text check (class in ('estrella','caballo','enigma','perro')),
  created_at timestamptz not null default now()
);
