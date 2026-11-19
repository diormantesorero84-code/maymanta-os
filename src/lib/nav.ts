// Navegación de módulos. "soon" = aún no implementado (se muestra como "en desarrollo").
export type NavItem = {
  href: string;
  label: string;
  ico: string;
  soon?: boolean;
  section: "Operación" | "Datos" | "Sistema";
};

export const NAV: NavItem[] = [
  { href: "/", label: "Dashboard", ico: "◧", section: "Operación" },
  { href: "/eventos", label: "Eventos", ico: "◆", section: "Operación" },
  { href: "/calendario", label: "Calendario", ico: "◳", section: "Operación" },
  { href: "/produccion", label: "Producción", ico: "▣", soon: true, section: "Operación" },
  { href: "/compras", label: "Compras", ico: "▤", soon: true, section: "Operación" },
  { href: "/food-cost", label: "Food Cost %FC", ico: "◉", soon: true, section: "Datos" },
  { href: "/kardex", label: "Kardex / Inventario", ico: "▦", soon: true, section: "Datos" },
  { href: "/bdm", label: "BDM / Escandallos", ico: "▧", section: "Datos" },
  { href: "/auditoria", label: "Auditoría", ico: "◎", soon: true, section: "Sistema" },
];
