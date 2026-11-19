"use client";
import {
  MES, EVENTOS_NOV, DIAS_SEMANA, offsetInicio, diasEnMes, eventoDe,
  cierreInfo, resumenMes, CalEvento,
} from "@/lib/calendario";

function Celda({ dia }: { dia: number | null }) {
  if (dia === null) return <div className="cell empty" />;
  const e = eventoDe(dia);
  return (
    <div className="cell">
      <div className="num">{dia}</div>
      {e && (
        <div className={`ev c-${e.cierre}`}>
          <span className="cli">{e.cliente}{e.tentativo && <span className="tt"> · tentativo</span>}</span>
          <span className="mt">{e.tipoEvento}{e.pax ? ` · ${e.pax} pax` : ""}</span><br />
          <span className="mt">{e.horario}</span>
        </div>
      )}
    </div>
  );
}

export default function CalendarioPage() {
  const r = resumenMes();
  const off = offsetInicio();
  const total = diasEnMes();
  const celdas: (number | null)[] = [
    ...Array(off).fill(null),
    ...Array.from({ length: total }, (_, i) => i + 1),
  ];
  while (celdas.length % 7 !== 0) celdas.push(null);

  const agenda = [...EVENTOS_NOV].sort((a, b) => a.dia - b.dia);

  return (
    <>
      <h1 className="h1">Calendario · {MES.nombre}</h1>
      <p className="sub">Eventos, privatizaciones y cierres del restaurante. Fuente: <em>Calendario eventos Noviembre.pdf</em> (la fuente no distingue sede).</p>

      <div className="cards">
        <div className="card"><div className="k">Eventos</div><div className="v">{r.eventos}</div><div className="d">este mes</div></div>
        <div className="card"><div className="k">Comensales</div><div className="v">{r.pax}</div><div className="d">pax confirmados</div></div>
        <div className="card"><div className="k">Cierres totales</div><div className="v">{r.cierresTotales}</div><div className="d">restaurante cerrado</div></div>
        <div className="card"><div className="k">Tentativos</div><div className="v">{r.tentativos}</div><div className="d">por confirmar</div></div>
      </div>

      <div className="legend">
        {(["total", "noche", "sin_cierre", "reservas21"] as const).map((c) => (
          <span className="l" key={c}><span className={`sw c-${c}`} />{cierreInfo[c].txt}</span>
        ))}
      </div>

      <div className="cal-wrap">
        <div className="cal">
          {DIAS_SEMANA.map((d) => <div className="dow" key={d}>{d}</div>)}
          {celdas.map((dia, i) => <Celda key={i} dia={dia} />)}
        </div>
      </div>

      <div className="panel">
        <h3>Agenda del mes</h3>
        <table>
          <thead><tr><th>Día</th><th>Cliente</th><th>Evento</th><th>Pax</th><th>Horario</th><th>Cierre</th></tr></thead>
          <tbody>
            {agenda.map((e: CalEvento) => (
              <tr key={e.dia + e.cliente}>
                <td style={{ fontWeight: 600 }}>{e.dia} nov</td>
                <td>{e.cliente}{e.tentativo && <span className="pill warn" style={{ marginLeft: 6 }}>tentativo</span>}</td>
                <td>{e.tipoEvento}</td>
                <td>{e.pax ?? "—"}</td>
                <td className="muted">{e.horario}</td>
                <td><span className={`pill ${cierreInfo[e.cierre].cls}`}>{cierreInfo[e.cierre].txt}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
