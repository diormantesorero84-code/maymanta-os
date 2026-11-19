"use client";
import Link from "next/link";
import { useSede } from "@/components/AppShell";
import DemoBanner from "@/components/DemoBanner";
import { nombreSede } from "@/lib/sedes";

const PASOS: [string, string][] = [
  ["Subir la Orden de Servicio (PDF)", "Se conserva el PDF original intacto (inmutable)."],
  ["Extracción con IA", "Fecha, hora, comensales, platos y estaciones. No se inventan datos ausentes."],
  ["Mapeo nombre → catálogo", "Contra el diccionario de equivalencias; lo que no casa se marca, no se adivina."],
  ["Validar faltantes", "Los datos críticos ausentes (gramajes, rendimientos…) bloquean esa línea hasta validarla."],
  ["Calcular necesidades", "R01: la cantidad de la orden manda. R02: se compra entero, no se descuenta stock."],
  ["Separar compra / propio", "Qué se compra hecho vs qué es elaboración propia (con explosión de materias primas)."],
  ["Revisar y aprobar", "El responsable aprueba antes de emitir; queda registrado quién y cuándo."],
  ["Generar documentos", "Orden de producción + orden de compra (+ escandallo), versionados."],
  ["Archivar con trazabilidad", "Nunca se envía el pedido al proveedor automáticamente."],
];

export default function NuevaOS() {
  const { sede } = useSede();
  return (
    <>
      <Link href="/eventos" className="back">← Eventos</Link>
      <h1 className="h1" style={{ marginTop: 12 }}>Nueva Orden de Servicio · {nombreSede(sede)}</h1>
      <p className="sub">Flujo de un evento, de la OS a las órdenes de producción y compra.</p>
      <DemoBanner />

      <div className="dropzone">
        <div className="big">⬆️</div>
        <div style={{ fontWeight: 600, marginTop: 6 }}>Arrastra aquí el PDF de la Orden de Servicio</div>
        <div style={{ marginTop: 4 }}>o</div>
        <button className="btn ghost" style={{ marginTop: 8 }} disabled>Seleccionar archivo</button>
        <div style={{ marginTop: 10, fontSize: 12 }}>(carga y extracción reales llegan en Fase 4, con el motor conectado)</div>
      </div>

      <div className="panel">
        <h3>Qué hará el sistema con la OS</h3>
        <div style={{ padding: "6px 18px 14px" }}>
          <div className="stepper">
            {PASOS.map(([t, d], i) => (
              <div className="s" key={i}>
                <div className="n">{i + 1}</div>
                <div>
                  <div className="t">{t}</div>
                  <div className="dz">{d}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}
