export default function ModuleStub({ titulo, ico, desc }: { titulo: string; ico: string; desc: string }) {
  return (
    <>
      <h1 className="h1">{titulo}</h1>
      <p className="sub">{desc}</p>
      <div className="stub">
        <div className="big">{ico}</div>
        <div style={{ fontWeight: 600, fontSize: 16 }}>Módulo no implementado todavía</div>
        <div style={{ color: "var(--muted)", fontSize: 14, maxWidth: 460, marginTop: 6 }}>
          Está en el roadmap de MAYMANTA OS. Se construirá sobre las fuentes reales (BDM, maestro de eventos,
          panel %FC) tras validar el módulo de Eventos. No se muestran datos ficticios como reales.
        </div>
        <span className="soon-tag">En desarrollo</span>
      </div>
    </>
  );
}
