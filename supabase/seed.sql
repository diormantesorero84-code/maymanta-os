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
