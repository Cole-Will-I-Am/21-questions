// THE PHASE 0 BAR. Run every persona through a full Echo session, then have an INDEPENDENT judge
// (a third model, blind to ground truth) match each portrait to the right person among all the
// personas as decoys. Generic reads can't beat chance; specific reads can. Also collects a
// persona self-rating. Usage: node lineup.mjs
import { runSession } from "./run-session.mjs";
import { PERSONAS } from "./personas.mjs";
import { chatJSON } from "./ollama.mjs";

const JUDGE_MODEL = "deepseek-v4-pro";   // independent of Echo (glm) and the answerer (gpt-oss)
const RATER_MODEL = "gpt-oss:120b";

function portraitText(p) {
  return `Archetype: ${p.archetype}\nTraits: ${(p.traits || []).join(", ")}\nWho they are: ${p.portrait?.who}\nHow they decide: ${p.portrait?.decide}\nWhat they value: ${p.portrait?.value}\nBlind spot: ${p.portrait?.blindspot}\nQuotable: ${p.quotable}`;
}
function shuffle(a) { const x = [...a]; for (let i = x.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [x[i], x[j]] = [x[j], x[i]]; } return x; }

async function judgeMatch(portrait, lineup) {
  const list = lineup.map((p, i) => `${i + 1}. ${p.tag}`).join("\n");
  const user = `A psychological portrait was written about exactly ONE of the people below. Read it, then pick which single person it describes.\n\nPORTRAIT:\n${portraitText(portrait)}\n\nPEOPLE:\n${list}\n\nReturn STRICT JSON: {"choice": <number 1-${lineup.length}>, "confidence": <0-100>, "why": "<one short line>"}.`;
  return chatJSON({ model: JUDGE_MODEL, system: "You match a portrait to the one person it best describes. Decide on the evidence in the portrait; pick the single best match.", messages: [{ role: "user", content: user }], num_predict: 300, temperature: 0.2 });
}
async function selfRate(persona, portrait) {
  const user = `WHO YOU ARE (private):\n${persona.dossier}\n\nSomeone wrote this portrait of you:\n${portraitText(portrait)}\n\nHow accurately does it capture YOU specifically — not just anyone? Return STRICT JSON: {"rating": <1-5>, "note": "<one short line>"}.`;
  return chatJSON({ model: RATER_MODEL, system: "You rate how well a portrait matches you, the specific person described. 5 = uncannily specific and true; 1 = generic or wrong.", messages: [{ role: "user", content: user }], num_predict: 160, temperature: 0.3 });
}

console.log(`\n=== ECHO · Phase 0 lineup test (${PERSONAS.length} personas) ===`);
console.log(`Running ${PERSONAS.length} full sessions in parallel… (~a few minutes)\n`);

const sessions = await Promise.all(PERSONAS.map(async (persona) => {
  try {
    const { portrait } = await runSession(persona);
    console.log(`  · session done: ${persona.id} → "${portrait.archetype}"`);
    return { persona, portrait };
  } catch (e) {
    console.log(`  · session FAILED: ${persona.id} — ${e.message}`);
    return null;
  }
})).then((r) => r.filter(Boolean));

let correct = 0, ratingSum = 0, ratingN = 0;
console.log(`\n────────── lineup ──────────`);
for (const { persona, portrait } of sessions) {
  const lineup = shuffle(PERSONAS.map((p) => ({ id: p.id, tag: p.tag })));
  const [match, rate] = await Promise.all([judgeMatch(portrait, lineup), selfRate(persona, portrait)]);
  const picked = lineup[(match.choice || 1) - 1];
  const hit = picked?.id === persona.id;
  if (hit) correct++;
  if (rate?.rating != null) { ratingSum += Number(rate.rating); ratingN++; }
  console.log(`${hit ? "✅" : "❌"} ${persona.id.padEnd(8)} → judge picked "${picked?.id}" @${match.confidence}%  | self-rating ${rate?.rating}/5  | "${portrait.archetype}"`);
}

const n = sessions.length;
const acc = n ? Math.round((100 * correct) / n) : 0;
const chance = Math.round(100 / PERSONAS.length);
const avgRate = ratingN ? (ratingSum / ratingN).toFixed(2) : "n/a";
console.log(`\n══════════ PHASE 0 RESULT ══════════`);
console.log(`Lineup accuracy : ${correct}/${n} = ${acc}%   (chance = ${chance}%)`);
console.log(`Avg self-rating : ${avgRate}/5`);
console.log(`Bar: lineup well above ${chance}% AND avg rating ≥ 4/5  →  ${acc > chance * 2 && Number(avgRate) >= 4 ? "PASS ✅" : "not yet"}`);
