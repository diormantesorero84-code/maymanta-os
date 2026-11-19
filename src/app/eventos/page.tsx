"use client";
import Link from "next/link";
import { useSede } from "@/components/AppShell";
import DemoBanner from "@/components/DemoBanner";
import { nombreSede } from "@/lib/sedes";
import { EVENTOS_DEMO, badgeClass } from "@/lib/demo";

export default function EventosPage() {
  const { sede } = useSede();
  const eventos = EVENTOS_DEMO.filter((e) => e.sede === sede);

  return (
    <>
      <div className="row-between">
        <div>
          <h1 className="h1">Eventos · {nombreSede(sede)}</h1>
          <p className="sub" style={{ margin: 0 }}>Orden de Servicio → producción + compra, con aprobación antes de emitir.</p>
        </div>
        <button className="btn">＋ Nueva OS</button>
      </div>
      <DemoBanner />

      <div className="panel" style={{ marginTop: 0 }}>
        <h3>Todos los eventos</h3>
        <table>
          <thead><tr><th>Evento</th><th>Cliente</th><th>Fecha</th><th>Pax</th><th>Datos faltantes</th><th>Estado</th></tr></thead>
          <tbody>
            {eventos.map((e) => (
              <tr key={e.id}>
                <td><Link href={`/eventos/${e.id}`} style={{ color: "var(--accent)", fontWeight: 600 }}>{e.id}</Link></td>
                <td>{e.cliente}</td>
                <td>{e.fecha}</td>
                <td>{e.pax}</td>
                <td>{e.faltantes > 0 ? <span style={{ color: "var(--warn)", fontWeight: 600 }}>{e.faltantes} ⚠</span> : <span style={{ color: "var(--good)" }}>0</span>}</td>
                <td><span className={`badge ${badgeClass(e.estado)}`}>{e.estado}</span></td>
              </tr>
            ))}
            {eventos.length === 0 && <tr><td colSpan={6} style={{ color: "var(--muted)" }}>Sin eventos en esta sede.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
