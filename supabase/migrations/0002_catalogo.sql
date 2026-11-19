-- ============================================================
-- MAYMANTA OS · 0002 catálogo maestro
-- De BDM: Materias primas / Maestro Productos / Historial Precios / Rendimientos.
-- Catálogo global (sin center_id); el precio puede llevar sede.
-- ============================================================

create table public.products (
  id              uuid primary key default gen_random_uuid(),
  code            text unique,
  name            text not null,
  canonical_name  text,
  unit_base       text,                       -- kg, ud, l…
  category        text,
  purchased_whole boolean not null default false,  -- se compra entero (R02/R05)
  source_ref      text,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  created_by      uuid references public.users(id),
  updated_by      uuid references public.users(id)
);
create trigger t_products_upd before update on public.products
  for each row execute function public.tg_set_updated_at();

create table public.product_aliases (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  alias      text not null,
  source     text,                            -- Equivalencias, Innovachef…
  unique (product_id, alias)
);
create index on public.product_aliases (alias);

create table public.suppliers (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  is_reference boolean not null default false, -- Innovachef = referencia
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

create table public.supplier_prices (
  id          uuid primary key default gen_random_uuid(),
  supplier_id uuid references public.suppliers(id) on delete set null,
  product_id  uuid not null references public.products(id) on delete cascade,
  center_id   uuid references public.centers(id),   -- null = precio general
  price       numeric(12,4),
  unit        text,
  valid_from  date,
  valid_to    date,
  source_ref  text,
  created_at  timestamptz not null default now()
);
create index on public.supplier_prices (product_id, valid_from desc);

create table public.yields (
  id           uuid primary key default gen_random_uuid(),
  product_id   uuid not null references public.products(id) on delete cascade,
  process      text,                          -- limpieza, fritura…
  yield_factor numeric,                        -- p. ej. 0,85
  merma_pct    numeric,                         -- p. ej. 20
  source_ref   text,
  created_at   timestamptz not null default now()
);
