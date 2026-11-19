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
