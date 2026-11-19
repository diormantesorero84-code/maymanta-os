"use client";
import Link from "next/link";
import { use, useState } from "react";
import DemoBanner from "@/components/DemoBanner";
import { nombreSede } from "@/lib/sedes";
import { EVENTOS_DEMO, FLUJO_ESTADOS, badgeClass, estadoIdx, getDetalle } from "@/lib/demo";

type Tab = "resumen" | "lineas" | "produccion" | "compra";

const lineaEstado: Record<string, { cls: string; txt: string }> = {
  mapeado: { cls: "ok", txt: "Mapeado" },
  sin_casar: { cls: "bad", txt: "Sin casar" },
  falta_dato: { cls: "warn", txt: "Falta dato" },
};

export default function EventoDetalle({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [tab, setTab] = useState<Tab>("resumen");
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

  const idxActual = estadoIdx(e.estado);
  const det = getDetalle(e);

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

      <div className="tabs">
        {([["resumen", "Resumen"], ["lineas", "Líneas de la OS"], ["produccion", "Producción"], ["compra", "Compra"]] as [Tab, string][]).map(
          ([t, label]) => (
            <button key={t} className={tab === t ? "on" : ""} onClick={() => setTab(t)}>{label}</button>
          )
        )}
      </div>

      {tab === "resumen" && (
        <>
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
              <span className="muted" style={{ fontSize: 12, alignSelf: "center" }}>
                (maqueta sin lógica real · el sistema nunca envía pedidos a proveedor automáticamente)
              </span>
            </div>
          </div>
        </>
      )}

      {tab === "lineas" && (
        <div className="panel">
          <h3>Líneas extraídas de la Orden de Servicio</h3>
          {det.lineas ? (
            <table>
              <thead><tr><th>Nombre en la OS</th><th>Plato del catálogo</th><th>Estación</th><th>Cantidad</th><th>Estado</th></tr></thead>
              <tbody>
                {det.lineas.map((l, i) => (
                  <tr key={i}>
                    <td>{l.raw}</td>
                    <td>{l.plato ? <>{l.plato} <span className="muted">{l.codigo}</span></> : <span className="muted">— sin mapear —</span>}</td>
                    <td>{l.estacion ?? "—"}</td>
                    <td>{l.cantidad} {l.unidad} <span className="muted" style={{ fontSize: 11 }}>({l.fuente})</span></td>
                    <td><span className={`pill ${lineaEstado[l.estado].cls}`}>{lineaEstado[l.estado].txt}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <div className="empty">La OS aún no se ha extraído. Súbela y la IA leerá platos, estaciones y comensales.</div>
          )}
        </div>
      )}

      {tab === "produccion" && (
        <div className="panel">
          <h3>Orden de producción — propio vs comprado</h3>
          {det.produccion ? (
            <table>
              <thead><tr><th>Elaboración / ítem</th><th>Cantidad</th><th>Tipo</th></tr></thead>
              <tbody>
                {det.produccion.map((p, i) => (
                  <tr key={i}>
                    <td>{p.item} {p.codigo && <span className="muted">{p.codigo}</span>}</td>
                    <td>{p.cantidad} {p.unidad}</td>
                    <td><span className={`pill ${p.tipo === "propio" ? "propio" : ""}`}>{p.tipo === "propio" ? "Elaboración propia" : "Comprado hecho"}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <div className="empty">Aún sin calcular. Las necesidades se calculan tras validar las líneas (R01: la cantidad de la orden manda).</div>
          )}
        </div>
      )}

      {tab === "compra" && (
        <div className="panel">
          <h3>Orden de compra — por producto (en crudo, con fecha de entrega)</h3>
          {det.compra ? (
            <table>
              <thead><tr><th>Producto</th><th>Cantidad</th><th>Entrega</th><th>Precio ref.</th></tr></thead>
              <tbody>
                {det.compra.map((c, i) => (
                  <tr key={i}>
                    <td>{c.producto}</td>
                    <td>{c.cantidad} {c.unidad}</td>
                    <td>{c.entrega === "Ya" ? <span className="pill">Ya</span> : c.entrega}</td>
                    <td className="muted">{c.precio}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <div className="empty">Aún sin calcular. R02: no se descuenta stock; se compra entero. R04: fechas desde la fecha real del evento.</div>
          )}
        </div>
      )}
    </>
  );
}
