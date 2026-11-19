"use client";
import { createContext, useContext, useState, ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { SEDES, SedeId, nombreSede } from "@/lib/sedes";
import { NAV } from "@/lib/nav";

// ---- Contexto de sede (selector global) ----
const SedeCtx = createContext<{ sede: SedeId; setSede: (s: SedeId) => void }>({
  sede: "BCN",
  setSede: () => {},
});
export const useSede = () => useContext(SedeCtx);

export default function AppShell({ children }: { children: ReactNode }) {
  const [sede, setSede] = useState<SedeId>("BCN");
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const sections = ["Operación", "Datos", "Sistema"] as const;

  return (
    <SedeCtx.Provider value={{ sede, setSede }}>
      <div className="shell">
        <aside className={`sidebar${open ? " open" : ""}`}>
          <div className="brand"><span className="dot" /> Maymanta OS</div>
          <nav className="nav">
            {sections.map((sec) => (
              <div key={sec}>
                <div className="nav-section">{sec}</div>
                {NAV.filter((n) => n.section === sec).map((n) => {
                  const active = n.href === "/" ? pathname === "/" : pathname.startsWith(n.href);
                  return (
                    <Link key={n.href} href={n.href} className={active ? "active" : ""} onClick={() => setOpen(false)}>
                      <span className="ico">{n.ico}</span>
                      {n.label}
                      {n.soon && <span className="soon">pronto</span>}
                    </Link>
                  );
                })}
              </div>
            ))}
          </nav>
        </aside>

        <div className="main">
          <header className="topbar">
            <button className="menu-btn" onClick={() => setOpen((o) => !o)} aria-label="Menú">☰</button>
            <div className="search">
              <span>⌕</span>
              <input placeholder="Buscar eventos, platos, productos…" />
            </div>
            <div className="seg" role="group" aria-label="Sede">
              {SEDES.map((s) => (
                <button key={s.id} className={sede === s.id ? "on" : ""} onClick={() => setSede(s.id)}>
                  {s.nombre}
                </button>
              ))}
            </div>
            <div className="user">
              <span style={{ color: "var(--muted)" }}>{nombreSede(sede)}</span>
              <span className="avatar">M</span>
            </div>
          </header>
          <main className="content">{children}</main>
        </div>
      </div>
    </SedeCtx.Provider>
  );
}
