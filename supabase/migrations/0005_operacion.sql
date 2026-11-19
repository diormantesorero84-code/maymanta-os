-- ============================================================
-- MAYMANTA OS · 0005 operación (compras, inventario, kardex, ventas, %FC)
-- Todo con center_id (dato por sede).
-- ============================================================

create table public.purchases_history (
  id          uuid primary key default gen_random_uuid(),
  center_id   uuid not null references public.centers(id),
  date        date not null,
  product_id  uuid references public.products(id),
  supplier_id uuid references public.suppliers(id),
  qty         numeric,
  unit        text,
  amount      numeric(12,2),
  source_ref  text,
  created_at  timestamptz not null default now()
);
create index on public.purchases_history (center_id, date);

create table public.inventory_counts (
  id         uuid primary key default gen_random_uuid(),
  center_id  uuid not null references public.centers(id),
  date       date not null,
  status     text not null default 'borrador' check (status in ('borrador','cerrado')),
  source_ref text,
  created_at timestamptz not null default now()
);
create table public.inventory_lines (
  id         uuid primary key default gen_random_uuid(),
  count_id   uuid not null references public.inventory_counts(id) on delete cascade,
  product_id uuid references public.products(id),
  qty        numeric,
  unit       text,
  unit_cost  numeric(12,4),   -- valoración contra BDM
  value      numeric(12,2)
);
create index on public.inventory_lines (count_id);

create table public.kardex_movements (
  id         uuid primary key default gen_random_uuid(),
  center_id  uuid not null references public.centers(id),
  product_id uuid references public.products(id),
  date       date not null,
  type       text not null check (type in ('in','out','adjust')),
  qty        numeric,
  unit       text,
  ref        text,
  created_at timestamptz not null default now()
);
create index on public.kardex_movements (center_id, product_id, date);

create table public.abc_classification (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  center_id  uuid references public.centers(id),
  class      text check (class in ('A','B','C')),
  period     text,
  created_at timestamptz not null default now()
);

create table public.sales (
  id             uuid primary key default gen_random_uuid(),
  center_id      uuid not null references public.centers(id),
  date           date not null,
  revenue_center text default 'RVC27',   -- Simphony Maymanta
  dish_ref       text,
  units          numeric,
  amount         numeric(12,2),
  source_ref     text,
  created_at     timestamptz not null default now()
);
create index on public.sales (center_id, date);

create table public.food_cost_periods (
  id              uuid primary key default gen_random_uuid(),
  center_id       uuid not null references public.centers(id),
  period          text not null,
  sales           numeric(12,2),
  purchases       numeric(12,2),
  inventory_delta numeric(12,2),
  fc_theoretical  numeric(6,3),
  fc_real         numeric(6,3),
  deviation       numeric(6,3),
  created_at      timestamptz not null default now(),
  unique (center_id, period)
);
