"use client";
import Link from "next/link";
import { use } from "react";
import DemoBanner from "@/components/DemoBanner";
import { nombreSede } from "@/lib/sedes";
import { EVENTOS_DEMO, FLUJO_ESTADOS, badgeClass } from "@/lib/demo";

export default function EventoDetalle({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const e = EVENTOS_DEMO.find((x) => x.id === id);

  if (!e) {
    return (
      <>
        <Link href="/eventos" className="back">← Eventos</Link>
        <h1 className="h1" style={{ marginTop: 12 }}>Evento no encontrado</h1>
        <p className="sub">El evento {id} no existe en los datos de ejemplo.</p>
      </>
    );
  }

  const idxActual = FLUJO_ESTADOS.indexOf(e.estado);

  return (
    <>
      <Link href="/eventos" className="back">← Eventos</Link>
      <div className="row-between" style={{ marginTop: 12 }}>
        <div>
          <h1 className="h1">{e.id} · {e.cliente}</h1>
          <p className="sub" style={{ margin: 0 }}>{nombreSede(e.sede)} · {e.fecha} · {e.pax} pax</p>
        </div>
        <span className={`badge ${badgeClass(e.estado)}`}>{e.estado}</span>
      </div>
      <DemoBanner />

      <div className="panel" style={{ marginTop: 0 }}>
        <h3>Flujo del evento</h3>
        <div style={{ padding: "16px 18px" }}>
          <div className="timeline">
            {FLUJO_ESTADOS.map((s, i) => (
              <span key={s} className={`step${i < idxActual ? " done" : i === idxActual ? " now" : ""}`}>{s}</span>
            ))}
          </div>
        </div>
      </div>

      <div className="cards" style={{ marginTop: 18 }}>
        <div className="card"><div className="k">Datos faltantes</div><div className="v" style={{ color: e.faltantes ? "var(--warn)" : "var(--good)" }}>{e.faltantes}</div><div className="d">{e.faltantes ? "bloquean el cálculo (no se inventan)" : "listo para calcular"}</div></div>
        <div className="card"><div className="k">OS original</div><div className="v" style={{ fontSize: 18 }}>PDF ✓</div><div className="d">conservado inmutable</div></div>
        <div className="card"><div className="k">Documentos</div><div className="v" style={{ fontSize: 18 }}>{e.estado === "APROBADO" ? "v1" : "—"}</div><div className="d">producción + compra (versionados)</div></div>
      </div>

      <div className="panel">
        <h3>Acciones</h3>
        <div style={{ padding: "16px 18px", display: "flex", gap: 10, flexWrap: "wrap" }}>
          <button className="btn ghost">Revisar mapeo</button>
          <button className="btn ghost">Calcular necesidades</button>
          <button className="btn" disabled={e.faltantes > 0} title={e.faltantes ? "Hay datos faltantes" : ""}>Enviar a aprobación</button>
          <span style={{ color: "var(--muted)", fontSize: 12, alignSelf: "center" }}>
            (maqueta sin lógica real todavía · el sistema nunca envía pedidos a proveedor automáticamente)
          </span>
        </div>
      </div>
    </>
  );
}
