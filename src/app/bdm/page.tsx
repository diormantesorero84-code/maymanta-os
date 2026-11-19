"use client";
import { useEffect, useState } from "react";
import ModuleStub from "@/components/ModuleStub";
import { supabaseConfigured } from "@/lib/supabase";
import { getRecipes, eur, RecipeRow } from "@/lib/data";

export default function BdmPage() {
  const [rows, setRows] = useState<RecipeRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [tipo, setTipo] = useState("");
  const [q, setQ] = useState("");

  useEffect(() => {
    if (!supabaseConfigured) { setLoading(false); return; }
    setLoading(true);
    getRecipes({ limit: 200, search: q || undefined, type: tipo || undefined })
      .then((r) => { setRows(r); setErr(null); })
      .catch((e) => setErr(e instanceof Error ? e.message : "Error"))
      .finally(() => setLoading(false));
  }, [q, tipo]);

  if (!supabaseConfigured) {
    return <ModuleStub titulo="BDM / Escandallos" ico="▧" desc="Materias primas, recetas, sub-recetas, costes por ración y mermas." />;
  }

  return (
    <>
      <h1 className="h1">BDM / Escandallos</h1>
      <p className="sub">Recetas y costes reales del MaymantaBDM (producciones y transformaciones).</p>

      <div className="filters">
        {[["", "Todas"], ["produccion", "Producciones"], ["transformacion", "Transformaciones"]].map(([v, label]) => (
          <button key={v} className={`chip${tipo === v ? " on" : ""}`} onClick={() => setTipo(v)}>{label}</button>
        ))}
        <form onSubmit={(e) => { e.preventDefault(); setQ(search); }} style={{ marginLeft: "auto", display: "flex", gap: 6 }}>
          <input className="search" style={{ padding: "6px 10px", maxWidth: 220 }} placeholder="Buscar receta…" value={search} onChange={(e) => setSearch(e.target.value)} />
          <button className="btn ghost" type="submit">Buscar</button>
        </form>
      </div>

      {err && <div className="login-err" style={{ textAlign: "left" }}>No se pudieron leer los datos: {err}</div>}

      <div className="panel" style={{ marginTop: 0 }}>
        <h3>{loading ? "Cargando…" : `${rows.length} receta${rows.length === 1 ? "" : "s"}`}</h3>
        <table>
          <thead><tr><th>Código</th><th>Receta</th><th>Tipo</th><th>Rend.</th><th>Coste/ud</th><th>Estado</th></tr></thead>
          <tbody>
            {loading && <tr><td colSpan={6} className="muted">Cargando…</td></tr>}
            {!loading && rows.map((r) => (
              <tr key={r.code}>
                <td className="muted">{r.code}</td>
                <td>{r.name}</td>
                <td>{r.type}</td>
                <td className="muted">{r.yield_unit ?? "—"}</td>
                <td>{eur(r.cost_computed)}</td>
                <td><span className={r.cost_status === "ok" ? "cost-ok" : "cost-rev"}>{r.cost_status === "ok" ? "OK" : "revisar"}</span></td>
              </tr>
            ))}
            {!loading && rows.length === 0 && !err && <tr><td colSpan={6} className="muted">Sin resultados.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
