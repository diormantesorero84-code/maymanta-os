// Sedes operativas de Maymanta (decidido 2026-11-19).
// "Keipa" es marca / segundo local, NO sede.
export type SedeId = "BCN" | "IBZ" | "MEN";

export const SEDES: { id: SedeId; nombre: string }[] = [
  { id: "BCN", nombre: "Barcelona" },
  { id: "IBZ", nombre: "Ibiza" },
  { id: "MEN", nombre: "Menorca" },
];

export const nombreSede = (id: SedeId) =>
  SEDES.find((s) => s.id === id)?.nombre ?? id;
