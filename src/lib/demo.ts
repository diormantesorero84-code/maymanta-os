// ⚠️ DATOS DE EJEMPLO (DEMO) — no son datos reales de Maymanta.
// Sirven solo para validar el aspecto y el flujo de la maqueta (Fase 2).
// La fuente real seguirá siendo el BDM y el maestro de eventos hasta migrar y validar.
import type { SedeId } from "./sedes";

export type EstadoEvento =
  | "BORRADOR" | "OS_CARGADA" | "EXTRAIDO" | "MAPEADO" | "VALIDADO"
  | "CALCULADO" | "EN_APROBACION" | "APROBADO" | "ARCHIVADO";

export const FLUJO_ESTADOS: EstadoEvento[] = [
  "BORRADOR", "OS_CARGADA", "EXTRAIDO", "MAPEADO", "VALIDADO",
  "CALCULADO", "EN_APROBACION", "APROBADO", "ARCHIVADO",
];

export type EventoDemo = {
  id: string;
  sede: SedeId;
  cliente: string;
  fecha: string;
  pax: number;
  estado: EstadoEvento;
  faltantes: number; // datos críticos pendientes (P01..)
};

export const EVENTOS_DEMO: EventoDemo[] = [
  { id: "EVT-0012", sede: "BCN", cliente: "KINAXIS (reproceso)", fecha: "2026-11-26", pax: 120, estado: "APROBADO", faltantes: 0 },
  { id: "EVT-0013", sede: "BCN", cliente: "Tech Summit BCN", fecha: "2026-12-03", pax: 80, estado: "EN_APROBACION", faltantes: 0 },
  { id: "EVT-0014", sede: "IBZ", cliente: "Boda Villa Cala", fecha: "2026-12-07", pax: 150, estado: "CALCULADO", faltantes: 2 },
  { id: "EVT-0015", sede: "MEN", cliente: "Corporativo Puerto", fecha: "2026-12-12", pax: 45, estado: "VALIDADO", faltantes: 1 },
  { id: "EVT-0016", sede: "IBZ", cliente: "Lanzamiento Marca X", fecha: "2026-12-18", pax: 200, estado: "EXTRAIDO", faltantes: 4 },
  { id: "EVT-0017", sede: "BCN", cliente: "Cena fin de año", fecha: "2026-12-31", pax: 60, estado: "BORRADOR", faltantes: 0 },
];

export const KPIS_DEMO = {
  BCN: { eventosAbiertos: 3, pendAprob: 1, fcTeorico: "28,4%", comprasMes: "12.350 €" },
  IBZ: { eventosAbiertos: 2, pendAprob: 0, fcTeorico: "31,1%", comprasMes: "8.900 €" },
  MEN: { eventosAbiertos: 1, pendAprob: 0, fcTeorico: "26,7%", comprasMes: "3.420 €" },
} as const;

export const badgeClass = (e: EstadoEvento): string => {
  if (e === "BORRADOR") return "b-borrador";
  if (e === "APROBADO") return "b-ok";
  if (e === "EN_APROBACION") return "b-aprob";
  if (e === "ARCHIVADO") return "b-archivo";
  return "b-proceso";
};

export const estadoIdx = (e: EstadoEvento) => FLUJO_ESTADOS.indexOf(e);

// ---- Detalle de un evento (líneas de la OS → producción → compra) ----
export type LineaOS = {
  raw: string; plato?: string; codigo?: string; estacion?: string;
  cantidad: number; unidad: string; fuente: "orden" | "calculo";
  estado: "mapeado" | "sin_casar" | "falta_dato";
};
export type LineaProd = { item: string; codigo?: string; cantidad: number; unidad: string; tipo: "propio" | "comprado" };
export type LineaCompra = { producto: string; cantidad: number; unidad: string; entrega: string; precio?: string };

const LINEAS_SAMPLE: LineaOS[] = [
  { raw: "Croqueta limeña", plato: "Croqueta de pollo limeña", codigo: "EV-008", estacion: "Pasapalos", cantidad: 150, unidad: "bocados", fuente: "orden", estado: "mapeado" },
  { raw: "Carpaccio de pulpo c/tartar", plato: "Carpaccio de pulpo ahumado", codigo: "EV-027", estacion: "Fría", cantidad: 120, unidad: "bocados", fuente: "orden", estado: "mapeado" },
  { raw: "Paella de mariscos", plato: "Paella de mariscos (familiar)", codigo: "EV-051", estacion: "Arroces", cantidad: 12, unidad: "paellas", fuente: "orden", estado: "mapeado" },
  { raw: "Crujiente de algas", plato: "Crujiente de nori", codigo: "EV-033", estacion: "Asia", cantidad: 40, unidad: "bocados", fuente: "orden", estado: "falta_dato" },
  { raw: "Mini alfajor", estacion: "Dulce", cantidad: 100, unidad: "uds", fuente: "orden", estado: "sin_casar" },
];
const PROD_SAMPLE: LineaProd[] = [
  { item: "Salsa anticuchera", codigo: "PR-112", cantidad: 2.4, unidad: "kg", tipo: "propio" },
  { item: "Alioli de yuzu", codigo: "PR-263", cantidad: 4.8, unidad: "kg", tipo: "propio" },
  { item: "Croqueta de pollo", cantidad: 150, unidad: "uds", tipo: "comprado" },
  { item: "Arroz bomba", cantidad: 6, unidad: "kg", tipo: "comprado" },
];
const COMPRA_SAMPLE: LineaCompra[] = [
  { producto: "Pulpo cocido", cantidad: 4.5, unidad: "kg", entrega: "2026-11-24", precio: "18,90 €/kg" },
  { producto: "Mejillón / almeja (marisco paella)", cantidad: 9, unidad: "kg", entrega: "2026-11-24", precio: "7,20 €/kg" },
  { producto: "Micromezclún", cantidad: 0.8, unidad: "kg", entrega: "2026-11-25", precio: "—" },
  { producto: "Croqueta de pollo (congelada)", cantidad: 150, unidad: "uds", entrega: "Ya", precio: "0,42 €/ud" },
];

export type Detalle = { lineas: LineaOS[] | null; produccion: LineaProd[] | null; compra: LineaCompra[] | null };

export function getDetalle(e: EventoDemo): Detalle {
  const i = estadoIdx(e.estado);
  const extraido = i >= estadoIdx("EXTRAIDO");
  const calculado = i >= estadoIdx("CALCULADO");
  return {
    lineas: extraido ? LINEAS_SAMPLE : null,
    produccion: calculado ? PROD_SAMPLE : null,
    compra: calculado ? COMPRA_SAMPLE : null,
  };
}

export const prodBadge = (t: "propio" | "comprado") => (t === "propio" ? "propio" : "");
