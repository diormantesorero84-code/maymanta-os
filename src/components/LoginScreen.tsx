"use client";
import { useState } from "react";
import { supabase } from "@/lib/supabase";

export default function LoginScreen() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!supabase) return;
    setBusy(true);
    setErr(null);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setErr(error.message === "Invalid login credentials" ? "Email o contraseña incorrectos." : error.message);
    setBusy(false);
  }

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={submit}>
        <div className="brand"><span className="dot" /> Maymanta OS</div>
        <h2>Iniciar sesión</h2>
        <p className="hint">Entra con tu email y contraseña de Maymanta.</p>
        {err && <div className="login-err">{err}</div>}
        <div className="field">
          <label htmlFor="email">Email</label>
          <input id="email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
        </div>
        <div className="field">
          <label htmlFor="pw">Contraseña</label>
          <input id="pw" type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" required />
        </div>
        <button className="btn" type="submit" disabled={busy}>{busy ? "Entrando…" : "Entrar"}</button>
      </form>
    </div>
  );
}
