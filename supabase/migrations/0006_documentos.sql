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
