-- =====================================================
-- MAYMANTA OS - TODO EN UNO (re-ejecutable)
-- Pega este archivo completo en el SQL Editor de Supabase y pulsa RUN.
-- Incluye: limpieza + migraciones (en orden) + grants + seed.
-- Generado automaticamente; no editar a mano.
-- =====================================================

-- >>>>>>>>>> LIMPIEZA (idempotente) >>>>>>>>>>
drop table if exists
  public.audit_logs, public.approvals, public.documents, public.food_cost_periods,
  public.sales, public.abc_classification, public.kardex_movements, public.inventory_lines,
  public.inventory_counts, public.purchases_history, public.purchase_lines, public.purchase_orders,
  public.production_lines, public.production_orders, public.event_lines, public.events,
  public.rules, public.menu_engineering, public.cocktail_items, public.cocktails,
  public.dish_components, public.dishes, public.recipe_items, public.recipes,
  public.yields, public.supplier_prices, public.suppliers, public.product_aliases,
  public.products, public.user_center_roles, public.permissions, public.roles,
  public.users, public.centers
  cascade;
drop function if exists public.has_permission(text,text,uuid);
drop function if exists public.current_center_ids();
drop function if exists public.tg_set_updated_at();
drop function if exists public.tg_audit();


-- >>>>>>>>>> migrations/0001_core.sql >>>>>>>>>>

-- ============================================================
-- MAYMANTA OS · 0001 core
-- Sedes, usuarios, roles, permisos, aprobaciones, auditoría y helpers.
-- ============================================================
create extension if not exists pgcrypto;

-- ---- Sedes (Barcelona / Ibiza / Menorca) ----
create table public.centers (
  id         uuid primary key default gen_random_uuid(),
  code       text unique not null,                 -- BCN, IBZ, MEN
  name       text not null,
  timezone   text not null default 'Europe/Madrid',
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---- Usuarios (perfil espejo de auth.users) ----
create table public.users (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  full_name  text,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---- Roles ----
create table public.roles (
  id   uuid primary key default gen_random_uuid(),
  code text unique not null,   -- admin, chef_corp, resp_cocina, resp_compras, resp_eventos, consulta
  name text not null
);

-- ---- Permisos (rol × módulo × acción) ----
create table public.permissions (
  id      uuid primary key default gen_random_uuid(),
  role_id uuid not null references public.roles(id) on delete cascade,
  module  text not null check (module in
            ('eventos','produccion','compras','bdm','foodcost','kardex','auditoria','usuarios','config')),
  action  text not null check (action in ('ver','crear','editar','aprobar')),
  unique (role_id, module, action)
);

-- ---- Rol por usuario y sede ----
create table public.user_center_roles (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  center_id  uuid not null references public.centers(id) on delete cascade,
  role_id    uuid not null references public.roles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, center_id, role_id)
);

-- ---- Aprobaciones de cambios sensibles ----
create table public.approvals (
  id           uuid primary key default gen_random_uuid(),
  center_id    uuid references public.centers(id),
  entity_type  text not null,
  entity_id    uuid not null,
  requested_by uuid references public.users(id),
  approver_id  uuid references public.users(id),
  status       text not null default 'pendiente' check (status in ('pendiente','aprobado','rechazado')),
  comment      text,
  requested_at timestamptz not null default now(),
  decided_at   timestamptz
);

-- ---- Registro de auditoría (append-only) ----
create table public.audit_logs (
  id          bigint generated always as identity primary key,
  actor_id    uuid,
  center_id   uuid,
  entity_type text not null,
  entity_id   uuid,
  action      text not null,
  before      jsonb,
  after       jsonb,
  at          timestamptz not null default now()
);
create index on public.audit_logs (entity_type, entity_id);
create index on public.audit_logs (center_id, at desc);

-- ============================================================
-- Helpers de autorización (usados por las políticas RLS)
-- ============================================================

-- Sedes a las que pertenece el usuario actual
create or replace function public.current_center_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select center_id from public.user_center_roles where user_id = auth.uid();
$$;

-- ¿El usuario actual tiene permiso (módulo, acción) en una sede?
-- _center null => vale cualquier sede (para catálogo global).
create or replace function public.has_permission(_module text, _action text, _center uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.user_center_roles ucr
    join public.permissions p on p.role_id = ucr.role_id
    where ucr.user_id = auth.uid()
      and p.module = _module
      and p.action = _action
      and (_center is null or ucr.center_id = _center)
  );
$$;

-- ============================================================
-- Triggers comunes
-- ============================================================

-- updated_at automático
create or replace function public.tg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end; $$;

-- Auditoría genérica (lee center_id vía jsonb; funciona aunque la tabla no lo tenga)
create or replace function public.tg_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  _row jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  insert into public.audit_logs (actor_id, center_id, entity_type, entity_id, action, before, after)
  values (
    auth.uid(),
    nullif(_row ->> 'center_id','')::uuid,
    tg_table_name,
    nullif(_row ->> 'id','')::uuid,
    lower(tg_op),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end
  );
  return coalesce(new, old);
end; $$;


-- >>>>>>>>>> migrations/0002_catalogo.sql >>>>>>>>>>

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


-- >>>>>>>>>> migrations/0003_recetas.sql >>>>>>>>>>

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


-- >>>>>>>>>> migrations/0004_eventos.sql >>>>>>>>>>

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


-- >>>>>>>>>> migrations/0005_operacion.sql >>>>>>>>>>

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


-- >>>>>>>>>> migrations/0006_documentos.sql >>>>>>>>>>

-- ============================================================
-- MAYMANTA OS · 0006 gestión documental
-- Originales inmutables (OS, facturas) + generados versionados.
-- Ficheros físicos en Supabase Storage; aquí solo los metadatos.
-- ============================================================

create table public.documents (
  id           uuid primary key default gen_random_uuid(),
  center_id    uuid references public.centers(id),
  kind         text not null check (kind in
                 ('os_original','produccion','compra','escandallo','ficha','factura')),
  entity_type  text,                 -- 'event', 'purchase_order'…
  entity_id    uuid,
  storage_path text not null,        -- ruta en Supabase Storage
  version      integer not null default 1,
  is_original  boolean not null default false,  -- true => inmutable
  source_ref   text,
  created_at   timestamptz not null default now(),
  created_by   uuid references public.users(id)
);
create index on public.documents (entity_type, entity_id);
create index on public.documents (center_id, kind);


-- >>>>>>>>>> migrations/0007_rls_policies.sql >>>>>>>>>>

-- ============================================================
-- MAYMANTA OS · 0007 Row Level Security
-- Seguridad por sede y por permiso (rol × módulo × acción), aplicada en la BD.
-- Sin política = acceso denegado por defecto. No se definen políticas de DELETE
-- (baja lógica con is_active); audit_logs y documentos originales son append-only.
-- ============================================================

-- ---------- Referencia / sistema ----------
alter table public.centers enable row level security;
create policy centers_sel on public.centers for select using (auth.uid() is not null);
create policy centers_ins on public.centers for insert with check (public.has_permission('usuarios','crear',null));
create policy centers_upd on public.centers for update using (public.has_permission('usuarios','editar',null));

alter table public.roles enable row level security;
create policy roles_sel on public.roles for select using (auth.uid() is not null);
create policy roles_wr  on public.roles for insert with check (public.has_permission('usuarios','crear',null));
create policy roles_upd on public.roles for update using (public.has_permission('usuarios','editar',null));

alter table public.permissions enable row level security;
create policy perms_sel on public.permissions for select using (auth.uid() is not null);
create policy perms_ins on public.permissions for insert with check (public.has_permission('usuarios','crear',null));
create policy perms_upd on public.permissions for update using (public.has_permission('usuarios','editar',null));

alter table public.users enable row level security;
create policy users_sel on public.users for select using (id = auth.uid() or public.has_permission('usuarios','ver',null));
create policy users_upd on public.users for update using (id = auth.uid() or public.has_permission('usuarios','editar',null))
  with check (id = auth.uid() or public.has_permission('usuarios','editar',null));
create policy users_ins on public.users for insert with check (public.has_permission('usuarios','crear',null));

alter table public.user_center_roles enable row level security;
create policy ucr_sel on public.user_center_roles for select using (user_id = auth.uid() or public.has_permission('usuarios','ver',null));
create policy ucr_ins on public.user_center_roles for insert with check (public.has_permission('usuarios','crear',null));
create policy ucr_upd on public.user_center_roles for update using (public.has_permission('usuarios','editar',null));

alter table public.approvals enable row level security;
create policy appr_sel on public.approvals for select using (center_id in (select public.current_center_ids()));
create policy appr_ins on public.approvals for insert with check (center_id in (select public.current_center_ids()));
create policy appr_upd on public.approvals for update using (center_id in (select public.current_center_ids()));

alter table public.audit_logs enable row level security;
create policy audit_sel on public.audit_logs for select using (
  public.has_permission('auditoria','ver',center_id)
  or (center_id is null and public.has_permission('auditoria','ver',null))
);  -- inserción solo vía trigger tg_audit (security definer)

alter table public.rules enable row level security;
create policy rules_sel on public.rules for select using (auth.uid() is not null);
create policy rules_ins on public.rules for insert with check (public.has_permission('config','crear',null));
create policy rules_upd on public.rules for update using (public.has_permission('config','editar',null));

-- ---------- Catálogo global (módulo bdm) ----------
do $$
declare t text;
begin
  foreach t in array array['products','product_aliases','suppliers','supplier_prices','yields',
                           'recipes','recipe_items','dishes','dish_components','cocktails','cocktail_items']
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('create policy %I on public.%I for select using (public.has_permission(''bdm'',''ver'',null));', t||'_sel', t);
    execute format('create policy %I on public.%I for insert with check (public.has_permission(''bdm'',''crear'',null));', t||'_ins', t);
    execute format('create policy %I on public.%I for update using (public.has_permission(''bdm'',''editar'',null)) with check (public.has_permission(''bdm'',''editar'',null));', t||'_upd', t);
  end loop;
end $$;

alter table public.menu_engineering enable row level security;
create policy menu_sel on public.menu_engineering for select using (public.has_permission('foodcost','ver',null));
create policy menu_ins on public.menu_engineering for insert with check (public.has_permission('foodcost','editar',null));

-- ---------- Eventos (por sede) ----------
alter table public.events enable row level security;
create policy events_sel on public.events for select using (center_id in (select public.current_center_ids()));
create policy events_ins on public.events for insert with check (public.has_permission('eventos','crear',center_id));
create policy events_upd on public.events for update using (public.has_permission('eventos','editar',center_id))
  with check (public.has_permission('eventos','editar',center_id));

alter table public.event_lines enable row level security;
create policy el_sel on public.event_lines for select using (
  exists (select 1 from public.events e where e.id = event_id and e.center_id in (select public.current_center_ids())));
create policy el_ins on public.event_lines for insert with check (
  exists (select 1 from public.events e where e.id = event_id and public.has_permission('eventos','editar',e.center_id)));
create policy el_upd on public.event_lines for update using (
  exists (select 1 from public.events e where e.id = event_id and public.has_permission('eventos','editar',e.center_id)));

-- ---------- Producción (por sede) ----------
alter table public.production_orders enable row level security;
create policy po_sel on public.production_orders for select using (center_id in (select public.current_center_ids()));
create policy po_ins on public.production_orders for insert with check (public.has_permission('produccion','crear',center_id));
create policy po_upd on public.production_orders for update using (public.has_permission('produccion','editar',center_id));

alter table public.production_lines enable row level security;
create policy pl_sel on public.production_lines for select using (
  exists (select 1 from public.production_orders o where o.id = production_order_id and o.center_id in (select public.current_center_ids())));
create policy pl_wr on public.production_lines for insert with check (
  exists (select 1 from public.production_orders o where o.id = production_order_id and public.has_permission('produccion','editar',o.center_id)));
create policy pl_upd on public.production_lines for update using (
  exists (select 1 from public.production_orders o where o.id = production_order_id and public.has_permission('produccion','editar',o.center_id)));

-- ---------- Compras (por sede) ----------
alter table public.purchase_orders enable row level security;
create policy puo_sel on public.purchase_orders for select using (center_id in (select public.current_center_ids()));
create policy puo_ins on public.purchase_orders for insert with check (public.has_permission('compras','crear',center_id));
create policy puo_upd on public.purchase_orders for update using (public.has_permission('compras','editar',center_id));

alter table public.purchase_lines enable row level security;
create policy pul_sel on public.purchase_lines for select using (
  exists (select 1 from public.purchase_orders o where o.id = purchase_order_id and o.center_id in (select public.current_center_ids())));
create policy pul_wr on public.purchase_lines for insert with check (
  exists (select 1 from public.purchase_orders o where o.id = purchase_order_id and public.has_permission('compras','editar',o.center_id)));
create policy pul_upd on public.purchase_lines for update using (
  exists (select 1 from public.purchase_orders o where o.id = purchase_order_id and public.has_permission('compras','editar',o.center_id)));

alter table public.purchases_history enable row level security;
create policy ph_sel on public.purchases_history for select using (center_id in (select public.current_center_ids()));
create policy ph_ins on public.purchases_history for insert with check (public.has_permission('compras','crear',center_id));
create policy ph_upd on public.purchases_history for update using (public.has_permission('compras','editar',center_id));

-- ---------- Inventario / Kardex (por sede) ----------
alter table public.inventory_counts enable row level security;
create policy ic_sel on public.inventory_counts for select using (center_id in (select public.current_center_ids()));
create policy ic_ins on public.inventory_counts for insert with check (public.has_permission('kardex','crear',center_id));
create policy ic_upd on public.inventory_counts for update using (public.has_permission('kardex','editar',center_id));

alter table public.inventory_lines enable row level security;
create policy il_sel on public.inventory_lines for select using (
  exists (select 1 from public.inventory_counts c where c.id = count_id and c.center_id in (select public.current_center_ids())));
create policy il_wr on public.inventory_lines for insert with check (
  exists (select 1 from public.inventory_counts c where c.id = count_id and public.has_permission('kardex','editar',c.center_id)));
create policy il_upd on public.inventory_lines for update using (
  exists (select 1 from public.inventory_counts c where c.id = count_id and public.has_permission('kardex','editar',c.center_id)));

alter table public.kardex_movements enable row level security;
create policy km_sel on public.kardex_movements for select using (center_id in (select public.current_center_ids()));
create policy km_ins on public.kardex_movements for insert with check (public.has_permission('kardex','crear',center_id));

alter table public.abc_classification enable row level security;
create policy abc_sel on public.abc_classification for select using (
  center_id is null or center_id in (select public.current_center_ids()));
create policy abc_ins on public.abc_classification for insert with check (public.has_permission('kardex','editar',center_id));

-- ---------- Ventas y %FC (por sede) ----------
alter table public.sales enable row level security;
create policy sales_sel on public.sales for select using (center_id in (select public.current_center_ids()));
create policy sales_ins on public.sales for insert with check (public.has_permission('foodcost','crear',center_id));
create policy sales_upd on public.sales for update using (public.has_permission('foodcost','editar',center_id));

alter table public.food_cost_periods enable row level security;
create policy fc_sel on public.food_cost_periods for select using (center_id in (select public.current_center_ids()));
create policy fc_ins on public.food_cost_periods for insert with check (public.has_permission('foodcost','editar',center_id));
create policy fc_upd on public.food_cost_periods for update using (public.has_permission('foodcost','editar',center_id));

-- ---------- Documentos (por sede; originales append-only) ----------
alter table public.documents enable row level security;
create policy doc_sel on public.documents for select using (
  center_id is null or center_id in (select public.current_center_ids()));
create policy doc_ins on public.documents for insert with check (
  center_id is null or center_id in (select public.current_center_ids()));
-- sin update/delete: los originales son inmutables; lo generado se versiona creando filas nuevas.

-- ---------- Auditoría: adjuntar trigger a tablas sensibles ----------
do $$
declare t text;
begin
  foreach t in array array['events','production_orders','purchase_orders','recipes','dishes',
                           'products','rules','supplier_prices','inventory_counts','approvals']
  loop
    execute format('create trigger t_audit_%1$s after insert or update or delete on public.%1$I
                    for each row execute function public.tg_audit();', t);
  end loop;
end $$;


-- >>>>>>>>>> migrations/0008_grants.sql >>>>>>>>>>

-- ============================================================
-- MAYMANTA OS · 0008 grants
-- Permisos base de acceso a las tablas para los roles del API de Supabase
-- (anon = no logueado, authenticated = logueado). La seguridad REAL la hace
-- RLS fila a fila (migración 0007); estos GRANT solo permiten tocar la tabla.
-- Sin esto, la API responde "permission denied for table ...".
-- ============================================================

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on all tables in schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
grant execute on all functions in schema public to anon, authenticated;

-- Para las tablas/secuencias que se creen en el futuro
alter default privileges in schema public grant select, insert, update, delete on tables to anon, authenticated;
alter default privileges in schema public grant usage, select on sequences to anon, authenticated;
alter default privileges in schema public grant execute on functions to anon, authenticated;


-- >>>>>>>>>> seed.sql >>>>>>>>>>

-- ============================================================
-- MAYMANTA OS · seed
-- Sedes, roles, matriz de permisos (doc 04) y reglas base (doc Eventos).
-- Ejecutar como admin/postgres (omite RLS). Idempotente por 'on conflict'.
-- ============================================================

-- ---- Sedes ----
insert into public.centers (code, name) values
  ('BCN','Barcelona'),
  ('IBZ','Ibiza'),
  ('MEN','Menorca')
on conflict (code) do nothing;

-- ---- Roles ----
insert into public.roles (code, name) values
  ('admin','Administrador del sistema'),
  ('chef_corp','Chef corporativo'),
  ('resp_cocina','Responsable de cocina'),
  ('resp_compras','Responsable de compras'),
  ('resp_eventos','Responsable de eventos'),
  ('consulta','Usuario de consulta')
on conflict (code) do nothing;

-- ---- Permisos ----
-- admin: todo (auditoría solo ver)
insert into public.permissions (role_id, module, action)
select r.id, m.module, a.action
from public.roles r
cross join (values ('eventos'),('produccion'),('compras'),('bdm'),('foodcost'),('kardex'),('auditoria'),('usuarios'),('config')) m(module)
cross join (values ('ver'),('crear'),('editar'),('aprobar')) a(action)
where r.code = 'admin'
  and not (m.module = 'auditoria' and a.action <> 'ver')
on conflict do nothing;

-- chef_corp: acceso total a los módulos operativos/datos; auditoría y usuarios solo ver
insert into public.permissions (role_id, module, action)
select r.id, m.module, a.action
from public.roles r
cross join (values ('eventos'),('produccion'),('compras'),('bdm'),('foodcost'),('kardex'),('config')) m(module)
cross join (values ('ver'),('crear'),('editar'),('aprobar')) a(action)
where r.code = 'chef_corp'
on conflict do nothing;
insert into public.permissions (role_id, module, action)
select r.id, v.module, v.action
from public.roles r
join (values ('auditoria','ver'),('usuarios','ver')) v(module, action) on true
where r.code = 'chef_corp'
on conflict do nothing;

-- resto de roles: matriz explícita
insert into public.permissions (role_id, module, action)
select r.id, v.module, v.action
from public.roles r
join (values
  -- resp_cocina
  ('resp_cocina','eventos','ver'),('resp_cocina','eventos','crear'),('resp_cocina','eventos','editar'),
  ('resp_cocina','produccion','ver'),('resp_cocina','produccion','crear'),('resp_cocina','produccion','editar'),('resp_cocina','produccion','aprobar'),
  ('resp_cocina','compras','ver'),
  ('resp_cocina','bdm','ver'),('resp_cocina','bdm','crear'),('resp_cocina','bdm','editar'),
  ('resp_cocina','foodcost','ver'),
  ('resp_cocina','kardex','ver'),('resp_cocina','kardex','crear'),('resp_cocina','kardex','editar'),
  ('resp_cocina','config','ver'),
  -- resp_compras
  ('resp_compras','eventos','ver'),
  ('resp_compras','produccion','ver'),
  ('resp_compras','compras','ver'),('resp_compras','compras','crear'),('resp_compras','compras','editar'),('resp_compras','compras','aprobar'),
  ('resp_compras','bdm','ver'),('resp_compras','bdm','editar'),
  ('resp_compras','foodcost','ver'),
  ('resp_compras','kardex','ver'),('resp_compras','kardex','crear'),('resp_compras','kardex','editar'),('resp_compras','kardex','aprobar'),
  ('resp_compras','config','ver'),
  -- resp_eventos
  ('resp_eventos','eventos','ver'),('resp_eventos','eventos','crear'),('resp_eventos','eventos','editar'),
  ('resp_eventos','produccion','ver'),('resp_eventos','produccion','crear'),
  ('resp_eventos','compras','ver'),('resp_eventos','compras','crear'),
  ('resp_eventos','bdm','ver'),
  ('resp_eventos','foodcost','ver'),
  ('resp_eventos','kardex','ver'),
  ('resp_eventos','config','ver'),
  -- consulta (solo lectura)
  ('consulta','eventos','ver'),('consulta','produccion','ver'),('consulta','compras','ver'),
  ('consulta','bdm','ver'),('consulta','foodcost','ver'),('consulta','kardex','ver'),('consulta','config','ver')
) v(role, module, action) on r.code = v.role
on conflict do nothing;

-- ---- Reglas base (de REGLAS_MAYMANTA / reglas_maymanta.json) ----
insert into public.rules (code, scope, state, body, source) values
  ('R01','eventos','CONFIRMADA','La cantidad de la orden MANDA sobre el cálculo pax×1,25.','Mauro 20-10'),
  ('R02','eventos','CONFIRMADA','No se asume stock: la materia prima se calcula y se compra entera.','Mauro 19-10'),
  ('R03','eventos','CONFIRMADA','Paella de mariscos: la cantidad de la orden es nº de paellas familiares (ref. 1/10 pax).','Mauro 20-10'),
  ('R04','eventos','CONFIRMADA','Fechas de entrega desde la fecha real del evento; frescos X días antes, congelados/secos = "Ya".','maestro + 22-10'),
  ('R05','eventos','CONFIRMADA','Se compran hechos (no se producen): macedonia, dulce de leche, croqueta, calamar congelado, pan bao, nori, papel de arroz, zamburiña, ostra, magret, panceta.','Productos'),
  ('R06','eventos','CONFIRMADA','Croqueta de pollo de evento: siempre comprada, 1 ud/bocado.','Mauro 20-10'),
  ('R07','eventos','CONFIRMADA','Elaboración propia (no se compran hechas): char siu, alfajor, chicharrón de calamar, salsa lomo saltado, alioli de yuzu, kiupe, ponzu, causa de remolacha, milhoja de boniato, cremoso de aguacate, anticuchera, chimichurri, leches de tigre, confit de pato.','BDM + Mauro 22-10'),
  ('R08','eventos','PENDIENTE','Una elaboración propia debe generar la compra de sus materias primas (explosión de MP). Resuelto de diseño con recipe_items recursivo; validar.','diagnóstico 22-10'),
  ('R11','eventos','CONFIRMADA','Micromezclún: comprar un 20% menos (merma 0,8). Permanente, afecta a todas las recetas con micromezclún.','Mauro 22-10')
on conflict (code) do nothing;
