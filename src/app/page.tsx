"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useSede } from "@/components/AppShell";
import DemoBanner from "@/components/DemoBanner";
import { supabaseConfigured } from "@/lib/supabase";
import { getCounts, getRecipes, eur, Counts, RecipeRow } from "@/lib/data";
import { nombreSede } from "@/lib/sedes";
import { EVENTOS_DEMO, KPIS_DEMO, badgeClass } from "@/lib/demo";

export default function Dashboard() {
  const { sede } = useSede();

  // ---- Modo conectado: datos reales del BDM ----
  const [counts, setCounts] = useState<Counts | null>(null);
  const [recipes, setRecipes] = useState<RecipeRow[]>([]);
  const [loading, setLoading] = useState(supabaseConfigured);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!supabaseConfigured) return;
    (async () => {
      try {
        const [c, r] = await Promise.all([getCounts(), getRecipes({ limit: 12 })]);
        setCounts(c);
        setRecipes(r);
      } catch (e) {
        setErr(e instanceof Error ? e.message : "Error al leer datos");
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  if (supabaseConfigured) {
    return (
      <>
        <h1 className="h1">Dashboard</h1>
        <p className="sub">Datos reales del BDM (MaymantaBDM). La seguridad por sede ya está activa.</p>
        {err && <div className="login-err" style={{ textAlign: "left" }}>No se pudieron leer los datos: {err}</div>}

        <div className="cards">
          <div className="card"><div className="k">Materias primas</div><div className="v">{loading ? "…" : counts?.products ?? 0}</div><div className="d">productos en el catálogo</div></div>
          <div className="card"><div className="k">Recetas</div><div className="v">{loading ? "…" : counts?.recipes ?? 0}</div><div className="d">producciones + transformaciones</div></div>
          <div className="card"><div className="k">Platos</div><div className="v">{loading ? "…" : counts?.dishes ?? 0}</div><div className="d">escandallos de carta</div></div>
          <div className="card"><div className="k">Precios cargados</div><div className="v">{loading ? "…" : counts?.supplier_prices ?? 0}</div><div className="d">costes de materia prima</div></div>
        </div>

        <div className="panel">
          <h3>Recetas (muestra)</h3>
          <table>
            <thead><tr><th>Código</th><th>Receta</th><th>Tipo</th><th>Coste/ud</th><th>Estado</th></tr></thead>
            <tbody>
              {loading && <tr><td colSpan={5} className="muted">Cargando…</td></tr>}
              {!loading && recipes.map((r) => (
                <tr key={r.code}>
                  <td className="muted">{r.code}</td>
                  <td>{r.name}</td>
                  <td>{r.type}</td>
                  <td>{eur(r.cost_computed)}</td>
                  <td><span className={r.cost_status === "ok" ? "cost-ok" : "cost-rev"}>{r.cost_status === "ok" ? "OK" : "revisar"}</span></td>
                </tr>
              ))}
              {!loading && recipes.length === 0 && !err && <tr><td colSpan={5} className="muted">Sin recetas (¿cargaste el BDM?).</td></tr>}
            </tbody>
          </table>
        </div>
        <p className="sub" style={{ marginTop: 16 }}>
          <Link href="/bdm" style={{ color: "var(--accent)", fontWeight: 600 }}>Ver todas las recetas y escandallos →</Link>
        </p>
      </>
    );
  }

  // ---- Modo maqueta (sin claves): datos de ejemplo ----
  const k = KPIS_DEMO[sede];
  const proximos = EVENTOS_DEMO.filter((e) => e.sede === sede && e.estado !== "ARCHIVADO");
  return (
    <>
      <h1 className="h1">Dashboard · {nombreSede(sede)}</h1>
      <p className="sub">Resumen operativo de la sede seleccionada.</p>
      <DemoBanner />
      <div className="cards">
        <div className="card"><div className="k">Eventos abiertos</div><div className="v">{k.eventosAbiertos}</div><div className="d">en esta sede</div></div>
        <div className="card"><div className="k">Pend. aprobación</div><div className="v">{k.pendAprob}</div><div className="d">requieren tu OK</div></div>
        <div className="card"><div className="k">%FC teórico</div><div className="v">{k.fcTeorico}</div><div className="d">periodo actual</div></div>
        <div className="card"><div className="k">Compras del mes</div><div className="v">{k.comprasMes}</div><div className="d">acumulado</div></div>
      </div>
      <div className="panel">
        <h3>Próximos eventos</h3>
        <table>
          <thead><tr><th>Evento</th><th>Cliente</th><th>Fecha</th><th>Pax</th><th>Estado</th></tr></thead>
          <tbody>
            {proximos.map((e) => (
              <tr key={e.id}>
                <td><Link href={`/eventos/${e.id}`} style={{ color: "var(--accent)", fontWeight: 600 }}>{e.id}</Link></td>
                <td>{e.cliente}</td><td>{e.fecha}</td><td>{e.pax}</td>
                <td><span className={`badge ${badgeClass(e.estado)}`}>{e.estado}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
