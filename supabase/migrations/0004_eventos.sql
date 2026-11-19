-- ============================================================
-- MAYMANTA OS · 0004 eventos
-- De maestro: Evento-Producción / Compra / Catálogo / Reglas.
-- ============================================================

create table public.events (
  id             uuid primary key default gen_random_uuid(),
  center_id      uuid not null references public.centers(id),
  client         text,
  event_date     date,
  pax            integer,
  status         text not null default 'BORRADOR' check (status in
                   ('BORRADOR','OS_CARGADA','EXTRAIDO','MAPEADO','VALIDADO',
                    'CALCULADO','EN_APROBACION','APROBADO','ARCHIVADO')),
  os_document_id uuid,                 -- → documents.id (fk lógica; documents se crea en 0006)
  faltantes      integer not null default 0,
  source_ref     text,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid references public.users(id),
  updated_by     uuid references public.users(id)
);
create index on public.events (center_id, event_date);
create trigger t_events_upd before update on public.events
  for each row execute function public.tg_set_updated_at();

-- ---- Líneas extraídas de la OS ----
create table public.event_lines (
  id             uuid primary key default gen_random_uuid(),
  event_id       uuid not null references public.events(id) on delete cascade,
  raw_name       text not null,
  mapped_dish_id uuid references public.dishes(id),
  station        text,
  qty            numeric,
  unit           text,
  qty_source     text not null default 'orden' check (qty_source in ('orden','calculo')), -- R01
  estado         text not null default 'sin_casar' check (estado in ('mapeado','sin_casar','falta_dato')),
  created_at     timestamptz not null default now()
);
create index on public.event_lines (event_id);

-- ---- Orden de producción ----
create table public.production_orders (
  id                    uuid primary key default gen_random_uuid(),
  event_id              uuid not null references public.events(id) on delete cascade,
  center_id             uuid not null references public.centers(id),
  status                text not null default 'borrador' check (status in ('borrador','emitida')),
  generated_document_id uuid,
  version               integer not null default 1,
  created_at            timestamptz not null default now()
);
create table public.production_lines (
  id                  uuid primary key default gen_random_uuid(),
  production_order_id uuid not null references public.production_orders(id) on delete cascade,
  recipe_id           uuid references public.recipes(id),
  item_name           text,
  qty                 numeric,
  unit                text,
  own_vs_bought       text check (own_vs_bought in ('propio','comprado'))  -- R05/R06/R07
);
create index on public.production_lines (production_order_id);

-- ---- Orden de compra (nunca se envía al proveedor automáticamente) ----
create table public.purchase_orders (
  id                    uuid primary key default gen_random_uuid(),
  event_id              uuid references public.events(id) on delete cascade,
  center_id             uuid not null references public.centers(id),
  supplier_id           uuid references public.suppliers(id),
  status                text not null default 'borrador' check (status in ('borrador','aprobada','emitida')),
  generated_document_id uuid,
  version               integer not null default 1,
  created_at            timestamptz not null default now()
);
create table public.purchase_lines (
  id                uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id        uuid references public.products(id),
  qty               numeric,
  unit              text,
  delivery_date     date,              -- R04: desde la fecha real del evento
  price             numeric(12,4)
);
create index on public.purchase_lines (purchase_order_id);

-- ---- Reglas (espejo de reglas_maymanta.json) ----
create table public.rules (
  id         uuid primary key default gen_random_uuid(),
  code       text unique not null,      -- R01, R02…
  scope      text,
  state      text not null default 'PENDIENTE' check (state in ('CONFIRMADA','VALIDADA','PENDIENTE')),
  body       text not null,
  source     text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger t_rules_upd before update on public.rules
  for each row execute function public.tg_set_updated_at();
