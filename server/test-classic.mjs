// Play CLASSIC mode against the live API: a "thinker" model picks a secret and answers Echo's
// yes/no questions truthfully; we see if Echo guesses it within 21. Usage: node test-classic.mjs "guitar"
import { chatJSON } from "../prototype/ollama.mjs";
const API = "https://echo-api.manticthink.com";
const UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0) AppleWebKit/605.1.15";
const SECRET = process.argv[2] || "guitar";
const THINKER = "glm-5.2";   // reliable JSON, non-reasoning (no empty-content)

async function post(path, body, token) {
  const r = await fetch(API + path, { method: "POST",
    headers: { "content-type": "application/json", "user-agent": UA, ...(token ? { authorization: "Bearer " + token } : {}) },
    body: JSON.stringify(body) });
  const t = await r.text();
  if (!r.ok) throw new Error(`${path} -> ${r.status}: ${t.slice(0,200)}`);
  return JSON.parse(t);
}
async function answerAbout(turn) {
  if (turn.answer_type === "guess") {                       // deterministic: did the guess name the secret?
    return turn.question.toLowerCase().includes(SECRET.toLowerCase()) ? "Yes" : "No";
  }
  try {
    const out = await chatJSON({
      model: THINKER,
      system: `You secretly chose "${SECRET}". Answer the yes/no question about it truthfully and briefly. Reply JSON {"answer":"Yes"|"No"|"Sometimes"|"Unsure"}.`,
      messages: [{ role: "user", content: `Question: "${turn.question}"` }], num_predict: 150, temperature: 0,
    });
    return out?.answer || "Unsure";
  } catch { return "Unsure"; }
}

console.log(`\n=== CLASSIC · secret = "${SECRET}" (hidden from Echo) ===`);
const acct = await post("/v1/account", { deviceId: "classic-" + Date.now() });
const start = await post("/v1/session/start", { mode: "classic" }, acct.token);
let turn = start.turn;
for (let i = 1; i <= 21; i++) {
  const ans = await answerAbout(turn);
  const tag = turn.answer_type === "guess" ? "GUESS" : "Q";
  console.log(`${tag}${turn.n}: ${turn.question}\n     → ${ans}${turn.reaction ? `   (${turn.reaction})` : ""}`);
  const res = await post("/v1/session/answer", { sessionId: start.sessionId, answer: ans }, acct.token);
  if (res.done) {
    console.log(`\n${res.outcome === "solved" ? "🎯 ECHO GUESSED IT" : "🙅 STUMPED"} after ${res.progress.answered} turns. (secret: "${SECRET}")`);
    break;
  }
  turn = res.turn;
}
