# Dar de alta Supabase — guía paso a paso

Objetivo: crear el proyecto Supabase (gratis), aplicar el esquema y conectar la app.
**Coste: 0 €** en el plan Free (suficiente para validar varios meses).
Lo que tú haces: crear la cuenta y el proyecto (yo no puedo hacerlo por ti). El resto está preparado.

---

## 1. Crear cuenta y proyecto

1. Entra en **https://supabase.com** → **Start your project** → inicia sesión (con GitHub o email).
2. **New project**:
   - **Name:** `maymanta-os`
   - **Database Password:** genera una fuerte y **guárdala en tu gestor de contraseñas** (la necesitarás).
   - **Region:** **Europe (Frankfurt)** `eu-central-1` (la más cercana a España).
   - **Plan:** Free.
3. Pulsa **Create** y espera ~2 min a que el proyecto arranque.

## 2. Aplicar el esquema (tablas + seguridad)

**Opción A — SQL Editor (lo más simple):**
En el panel, menú lateral → **SQL Editor** → **New query**. Pega y ejecuta **en este orden**,
uno por uno (el contenido está en `supabase/migrations/`):

1. `0001_core.sql`
2. `0002_catalogo.sql`
3. `0003_recetas.sql`
4. `0004_eventos.sql`
5. `0005_operacion.sql`
6. `0006_documentos.sql`
7. `0007_rls_policies.sql`

Luego el seed (sedes, roles, permisos, reglas): pega y ejecuta `seed.sql`.

**Opción B — CLI** (si instalas la Supabase CLI):
```bash
supabase link --project-ref <tu-ref>
supabase db push
psql "<CONNECTION_STRING>" -f supabase/seed.sql
```

> Si algún paso da error, cópiame el mensaje y lo corrijo: el esquema está escrito pero
> aún no probado contra una base de datos real (esta es su primera ejecución).

## 3. Crear tu usuario admin

1. Menú lateral → **Authentication** → **Users** → **Add user** → **Create new user**:
   pon tu **email** y una **contraseña**. (Esto es tu login a la plataforma.)
2. Vuelve al **SQL Editor** y ejecuta esto (cambia el email por el tuyo):

```sql
-- enlaza tu usuario de auth con el perfil y te da rol admin en las 3 sedes
insert into public.users (id, email, full_name)
select id, email, 'Mauro' from auth.users where email = 'TU-EMAIL@ejemplo.com'
on conflict (id) do nothing;

insert into public.user_center_roles (user_id, center_id, role_id)
select u.id, c.id, r.id
from public.users u, public.centers c, public.roles r
where u.email = 'TU-EMAIL@ejemplo.com' and r.code = 'admin'
on conflict do nothing;
```

## 4. Coger las claves y conectarlas a la app

1. Menú lateral → **Project Settings** → **API**. Copia:
   - **Project URL**
   - **anon public** key  (es pública, va en el navegador — segura con RLS)
   - ⚠️ La **service_role** key es **secreta**: NO la pongas en la app web ni la compartas.
2. En la carpeta `maymanta-os`, copia `.env.example` a **`.env.local`** y rellena:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
   ```
   `.env.local` **nunca** se sube a git (ya está en `.gitignore`).
3. Reinicia el dev server (`npm run dev`). La app detecta las claves automáticamente.

## 5. Cargar el BDM y validar (siguiente paso, ya conmigo)

Cuando el esquema esté aplicado, hago el **script de carga** que mete los CSV de
`supabase/extract/out/` en las tablas, y **validamos**: recalcular ~10 platos y cuadrar el
coste con el BDM antes de dar la base de datos por buena (regla: el Excel sigue siendo oficial
hasta validar).

---

### Qué necesito de ti para seguir
- Confírmame cuando el proyecto esté **creado** y el **esquema aplicado** (o pásame cualquier error).
- No necesito tus claves: las pones tú en `.env.local`. Si quieres, puedo guiarte en videollamada-estilo paso a paso.
