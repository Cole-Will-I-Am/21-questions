// Run ONE persona through a full 21-question Echo session and print the transcript, the sealed
// hypothesis (verified), and the final portrait. Usage: node run-session.mjs [personaId]
import { nextTurn, finalPortrait, sealHypothesis, verifySeal } from "./echo.mjs";
import { PERSONAS, answerAs } from "./personas.mjs";

export async function runSession(persona, { log = () => {} } = {}) {
  const history = [];
  let seal = null;
  for (let q = 1; q <= 21; q++) {
    const turn = await nextTurn(history, q);
    const answer = await answerAs(persona, turn);
    history.push({ q: turn.question, a: answer, type: turn.answer_type, reaction: turn.reaction || "" });
    log(`\nQ${q} [${turn.answer_type}] ${turn.question}`);
    if (turn.options?.length) log(`   (${turn.options.join(" · ")})`);
    log(`A${q}: ${answer}`);
    if (turn.reaction) log(`   ↪ ${turn.reaction}`);
    if (q === 3 && turn.hypothesis) {
      seal = sealHypothesis(turn.hypothesis);
      log(`\n   🔒 SEALED @Q3  hash=${seal.hash.slice(0, 16)}…  (opens at the end)`);
    }
  }
  const portrait = await finalPortrait(history);
  return { history, seal, portrait };
}

// CLI
if (import.meta.url === `file://${process.argv[1]}`) {
  const id = process.argv[2] || PERSONAS[0].id;
  const persona = PERSONAS.find((p) => p.id === id) || PERSONAS[0];
  console.log(`\n=== ECHO · Mirror session ===\nGround truth (hidden from Echo): ${persona.tag}\n`);
  const { seal, portrait } = await runSession(persona, { log: (s) => console.log(s) });

  console.log(`\n────────── THE REVEAL ──────────`);
  console.log(`ARCHETYPE: ${portrait.archetype}`);
  console.log(`TRAITS: ${(portrait.traits || []).join(" · ")}`);
  console.log(`\nWHO YOU ARE\n${portrait.portrait?.who}`);
  console.log(`\nHOW YOU DECIDE\n${portrait.portrait?.decide}`);
  console.log(`\nWHAT YOU VALUE\n${portrait.portrait?.value}`);
  console.log(`\nWHAT YOU'RE NOT TELLING YOURSELF\n${portrait.portrait?.blindspot}`);
  console.log(`\n“${portrait.quotable}”`);

  if (seal) {
    console.log(`\n────────── THE SEAL (opened) ──────────`);
    console.log(`verified: ${verifySeal(seal) ? "✅ matches the hash shown at Q3" : "❌ MISMATCH"}`);
    console.log(`tags: ${(seal.hypothesis.tags || []).join(", ")}`);
    console.log(`prediction: ${seal.hypothesis.prediction}`);
  }
  console.log(`\n(compare against ground truth above — was the read specific & right?)\n`);
}
