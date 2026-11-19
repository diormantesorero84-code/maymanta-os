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
