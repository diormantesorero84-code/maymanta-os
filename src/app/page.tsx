"use client";
import Link from "next/link";
import { useSede } from "@/components/AppShell";
import DemoBanner from "@/components/DemoBanner";
import { nombreSede } from "@/lib/sedes";
import { EVENTOS_DEMO, KPIS_DEMO, badgeClass } from "@/lib/demo";

export default function Dashboard() {
  const { sede } = useSede();
  const k = KPIS_DEMO[sede];
  const delaSede = EVENTOS_DEMO.filter((e) => e.sede === sede);
  const proximos = delaSede.filter((e) => e.estado !== "ARCHIVADO");

  const alertas = [
    ...delaSede.filter((e) => e.estado === "EN_APROBACION").map((e) => ({ tipo: "info" as const, txt: `${e.id} · ${e.cliente} espera aprobación`, tag: "Aprobar" })),
    ...delaSede.filter((e) => e.faltantes > 0).map((e) => ({ tipo: "warn" as const, txt: `${e.id} · ${e.cliente}: ${e.faltantes} dato(s) faltante(s) bloquean el cálculo`, tag: "Revisar" })),
  ];

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
        <h3>Alertas</h3>
        {alertas.length ? (
          <div className="alerts">
            {alertas.map((a, i) => (
              <div key={i} className={`alert ${a.tipo}`}>
                <span>{a.tipo === "warn" ? "⚠️" : "🔔"}</span>
                {a.txt}
                <span className="tag">{a.tag}</span>
              </div>
            ))}
          </div>
        ) : (
          <div className="empty">Sin alertas en esta sede.</div>
        )}
      </div>

      <div className="panel">
        <h3>Próximos eventos</h3>
        <table>
          <thead><tr><th>Evento</th><th>Cliente</th><th>Fecha</th><th>Pax</th><th>Estado</th></tr></thead>
          <tbody>
            {proximos.map((e) => (
              <tr key={e.id}>
                <td><Link href={`/eventos/${e.id}`} style={{ color: "var(--accent)", fontWeight: 600 }}>{e.id}</Link></td>
                <td>{e.cliente}</td>
                <td>{e.fecha}</td>
                <td>{e.pax}</td>
                <td><span className={`badge ${badgeClass(e.estado)}`}>{e.estado}</span></td>
              </tr>
            ))}
            {proximos.length === 0 && <tr><td colSpan={5} className="muted">Sin eventos abiertos en esta sede.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
