// Calendario de eventos — NOVIEMBRE 2026.
// Fuente: "Calendario eventos Noviembre.pdf" (calendario del restaurante).
// La fuente no distingue sede; se asume el restaurante principal.
export type Cierre = "total" | "noche" | "sin_cierre" | "reservas21";

export type CalEvento = {
  dia: number;
  cliente: string;
  tipoEvento: string;
  pax?: number;
  horario: string;
  cierre: Cierre;
  tentativo?: boolean;
  nota?: string;
};

export const MES = { anio: 2026, mes: 10, nombre: "Noviembre 2026" }; // mes 10 = noviembre (0-index)

export const EVENTOS_NOV: CalEvento[] = [
  { dia: 3, cliente: "GOOGLE", tipoEvento: "Closing Party", pax: 280, horario: "19:00–23:30", cierre: "total" },
  { dia: 4, cliente: "OMNICON", tipoEvento: "Cocktail Dinner", pax: 100, horario: "19:00–21:00", cierre: "noche" },
  { dia: 5, cliente: "PRINCIPAL GLOBAL", tipoEvento: "Lunch", pax: 30, horario: "12:30–14:30", cierre: "sin_cierre" },
  { dia: 7, cliente: "ADRY & LAURA", tipoEvento: "Cocktail Dinner", pax: 100, horario: "19:00–21:00", cierre: "reservas21", nota: "Reservas desde 21:00" },
  { dia: 9, cliente: "KATIE", tipoEvento: "Cena", pax: 20, horario: "18:30–20:30", cierre: "sin_cierre" },
  { dia: 10, cliente: "STATION 70 INC", tipoEvento: "Seated Dinner", pax: 40, horario: "19:30–22:30", cierre: "sin_cierre" },
  { dia: 12, cliente: "EXTE CARMEN", tipoEvento: "Cocktail Dinner", pax: 250, horario: "19:00–00:00", cierre: "total" },
  { dia: 16, cliente: "HYATT REGENCY", tipoEvento: "Cena", horario: "19:00–00:00", cierre: "noche", tentativo: true },
  { dia: 17, cliente: "CLOUD ROCK BUCHI", tipoEvento: "Cocktail Dinner", pax: 100, horario: "19:00–22:00", cierre: "noche" },
  { dia: 18, cliente: "INVISORS", tipoEvento: "Cocktail Dinner", horario: "18:00–21:00", cierre: "noche" },
  { dia: 23, cliente: "GE VERNOVA", tipoEvento: "Cocktail Dinner", pax: 80, horario: "20:00–22:00", cierre: "noche", tentativo: true },
];

export const cierreInfo: Record<Cierre, { cls: string; txt: string }> = {
  total: { cls: "bad", txt: "Cierre total" },
  noche: { cls: "warn", txt: "Cierre noche" },
  sin_cierre: { cls: "ok", txt: "Abierto" },
  reservas21: { cls: "propio", txt: "Reservas desde 21:00" },
};

export const DIAS_SEMANA = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"];

// offset (celdas vacías) antes del día 1, con semana empezando en lunes
export const offsetInicio = () => {
  const d = new Date(MES.anio, MES.mes, 1).getDay(); // 0=domingo
  return (d + 6) % 7;
};
export const diasEnMes = () => new Date(MES.anio, MES.mes + 1, 0).getDate();

export const eventoDe = (dia: number) => EVENTOS_NOV.find((e) => e.dia === dia);

export const resumenMes = () => ({
  eventos: EVENTOS_NOV.length,
  pax: EVENTOS_NOV.reduce((a, e) => a + (e.pax ?? 0), 0),
  cierresTotales: EVENTOS_NOV.filter((e) => e.cierre === "total").length,
  tentativos: EVENTOS_NOV.filter((e) => e.tentativo).length,
});
