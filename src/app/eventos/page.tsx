"use client";
import Link from "next/link";
import { useState } from "react";
import { useSede } from "@/components/AppShell";
import DemoBanner from "@/components/DemoBanner";
import { nombreSede } from "@/lib/sedes";
import { EVENTOS_DEMO, badgeClass } from "@/lib/demo";

const GRUPOS = [
  { id: "todos", label: "Todos", test: () => true },
  { id: "abiertos", label: "Abiertos", test: (s: string) => s !== "ARCHIVADO" },
  { id: "aprob", label: "Pend. aprobación", test: (s: string) => s === "EN_APROBACION" },
  { id: "archivo", label: "Archivados", test: (s: string) => s === "ARCHIVADO" },
] as const;

export default function EventosPage() {
  const { sede } = useSede();
  const [filtro, setFiltro] = useState<string>("todos");
  const grupo = GRUPOS.find((g) => g.id === filtro)!;
  const eventos = EVENTOS_DEMO.filter((e) => e.sede === sede && grupo.test(e.estado));

  return (
    <>
      <div className="row-between">
        <div>
          <h1 className="h1">Eventos · {nombreSede(sede)}</h1>
          <p className="sub" style={{ margin: 0 }}>Orden de Servicio → producción + compra, con aprobación antes de emitir.</p>
        </div>
        <Link href="/eventos/nueva" className="btn">＋ Nueva OS</Link>
      </div>
      <DemoBanner />

      <div className="filters">
        {GRUPOS.map((g) => (
          <button key={g.id} className={`chip${filtro === g.id ? " on" : ""}`} onClick={() => setFiltro(g.id)}>{g.label}</button>
        ))}
        <span className="count">{eventos.length} evento{eventos.length === 1 ? "" : "s"}</span>
      </div>

      <div className="panel" style={{ marginTop: 0 }}>
        <h3>Eventos</h3>
        <table>
          <thead><tr><th>Evento</th><th>Cliente</th><th>Fecha</th><th>Pax</th><th>Datos faltantes</th><th>Estado</th></tr></thead>
          <tbody>
            {eventos.map((e) => (
              <tr key={e.id}>
                <td><Link href={`/eventos/${e.id}`} style={{ color: "var(--accent)", fontWeight: 600 }}>{e.id}</Link></td>
                <td>{e.cliente}</td>
                <td>{e.fecha}</td>
                <td>{e.pax}</td>
                <td>{e.faltantes > 0 ? <span className="pill warn">{e.faltantes} ⚠</span> : <span className="pill ok">0</span>}</td>
                <td><span className={`badge ${badgeClass(e.estado)}`}>{e.estado}</span></td>
              </tr>
            ))}
            {eventos.length === 0 && <tr><td colSpan={6} className="muted">Sin eventos con este filtro en {nombreSede(sede)}.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
