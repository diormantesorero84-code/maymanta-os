# MAYMANTA OS — App web

Plataforma de gestión operativa de Maymanta. **Fase 2: maqueta navegable** (Next.js + TypeScript + Tailwind, App Router).
Módulo guía: **Eventos**. Resto de módulos = *en desarrollo*.

> Documentación y planificación: `../Documentación/MAYMANTA_OS/` (índice `00_INDICE.md`).

## Cómo arrancar

```bash
npm install     # solo la primera vez
npm run dev      # http://localhost:3000
npm run build    # compila y type-check
```

## Estado actual

- Navegación lateral por módulos + selector de sede **Barcelona / Ibiza / Menorca**.
- Dashboard y Eventos con **datos de ejemplo claramente marcados (DEMO)** — no son datos reales.
- Detalle de evento con la **máquina de estados** (BORRADOR → … → APROBADO → ARCHIVADO).
- Aún **sin base de datos, sin login real y sin lógica de cálculo**: eso llega en Fase 3–4 (Supabase + motor de reglas).

## ⚠️ Importante — está dentro de OneDrive

Este proyecto vive dentro del vault sincronizado (decisión del 19-11-2026). Para evitar que OneDrive
corrompa el build:

- `node_modules/` y `.next/` están en `.gitignore` (git no los versiona).
- **Recomendado:** en Ajustes de OneDrive → *Elegir carpetas* / *Copia de seguridad*, **excluir**
  `maymanta-os/node_modules` y `maymanta-os/.next` de la sincronización. OneDrive no respeta `.gitignore`.
- Si el build se comporta raro: cerrar OneDrive un momento, borrar `.next`, y `npm run build` de nuevo.

## Estructura

```
src/
  app/            rutas (dashboard, eventos, eventos/[id], módulos stub)
  components/     AppShell (sidebar + topbar + contexto de sede), DemoBanner, ModuleStub
  lib/            sedes, nav, demo (datos de ejemplo)
```
