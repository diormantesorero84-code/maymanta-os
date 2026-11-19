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
