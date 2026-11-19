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
