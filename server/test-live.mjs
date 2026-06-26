// End-to-end smoke test against the LIVE echo-api: account -> start -> 21 answers -> portrait.
// A persona (gpt-oss answerer from the prototype) answers each real question; verifies the Q3
// seal hash and that the opened seal matches at the reveal.
import crypto from "node:crypto";
import { PERSONAS, answerAs } from "../prototype/personas.mjs";

const API = "https://echo-api.manticthink.com";
const UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0) AppleWebKit/605.1.15";
const persona = PERSONAS.find((p) => p.id === (process.argv[2] || "founder2")) || PERSONAS[0];

async function post(path, body, token) {
  const r = await fetch(API + path, {
    method: "POST",
    headers: { "content-type": "application/json", "user-agent": UA, ...(token ? { authorization: "Bearer " + token } : {}) },
    body: JSON.stringify(body),
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`${path} -> ${r.status}: ${t.slice(0, 200)}`);
  return JSON.parse(t);
}

console.log(`\n=== echo-api LIVE test · persona: ${persona.id} ===`);
const acct = await post("/v1/account", { deviceId: "echotest-" + Date.now() });
console.log("account:", acct.player?.display, "token?", !!acct.token);

const start = await post("/v1/session/start", {}, acct.token);
console.log("session:", start.sessionId, "| total", start.total);
let turn = start.turn;
let sealHash = null;

for (let i = 1; i <= 21; i++) {
  const answer = await answerAs(persona, turn);
  console.log(`Q${turn.n} [${turn.answer_type}] ${turn.question.slice(0, 70)}…\n   A: ${answer.slice(0, 80)}`);
  const res = await post("/v1/session/answer", { sessionId: start.sessionId, answer }, acct.token);
  if (res.seal?.hash) { sealHash = res.seal.hash; console.log(`   🔒 SEAL hash=${sealHash.slice(0, 16)}…`); }
  if (res.done) {
    const p = res.portrait;
    console.log(`\n────── PORTRAIT ──────`);
    console.log(`${p.archetype}  ·  ${(p.traits || []).join(" · ")}`);
    console.log(`WHO: ${p.portrait.who}`);
    console.log(`BLINDSPOT: ${p.portrait.blindspot}`);
    console.log(`“${p.quotable}”`);
    const s = res.seal;
    if (s) {
      const recomputed = crypto.createHash("sha256").update(JSON.stringify(s.hypothesis) + s.salt).digest("hex");
      const okSeal = recomputed === s.hash && (!sealHash || sealHash === s.hash);
      console.log(`\nSEAL opened — verify: ${okSeal ? "✅ matches the hash shown at Q3" : "❌ MISMATCH"}`);
      console.log(`  prediction: ${s.hypothesis.prediction}`);
    }
    console.log(`\nground truth: ${persona.tag}`);
    break;
  }
  turn = res.turn;
}
