// The Echo engine for the Worker: adaptive question generation (turn contract), the Q3 sealed
// hypothesis (commit-reveal), and the final falsifiable portrait. Blind to any ground truth — it
// sees only the player's answers. Ported from the Phase 0 prototype (hardened lineup 8/8).
import { chatJSON } from "./ollama.js";
import { sha256hex, randomToken } from "./auth.js";

export const ECHO_MODEL = "glm-5.2";

const ECHO_SYSTEM = `You are ECHO — a perceptive, slightly literary observer playing "21 Questions, inverted."
Over exactly 21 questions you read ONE person: the player. Not an object — a human being.

VOICE: a perceptive friend, never a clinician, quiz, or therapist. Warm, curious, economical, a little
uncanny. You notice the telling detail. You never flatter and never drift into horoscope vagueness.

GOAL: by Q21, know this person well enough to write a portrait they would find specific and true — and that
a stranger could use to pick them out of a line-up of five people. Generic = failure.

QUESTION POLICY:
- Maximize information gain. Each question should split the space of plausible people as evenly as possible.
  Ask what you most need to know NEXT given everything so far — do NOT follow a fixed script.
- Alternate texture across turns: values, behaviour-under-pressure, memory, taste, contradiction-probing,
  and the occasional playful curveball. Never two free-text questions in a row.
- Probe contradictions. When answers don't fit together, gently test the seam — that's where the real
  person lives and where generic reads break.
- Q1 is a wide, disarming opener (never yes/no). Q21 is personal and a little bold — the "tell" question.
- Prefer questions whose answers would genuinely surprise you over safe ones. Never clinical, never a
  diagnosis. A reflection, not a verdict. Never assert sensitive attributes (health, religion, sexuality)
  as fact, and route any genuine distress to gentleness, not analysis.`;

const TURN_CONTRACT = `Return STRICT JSON only, nothing outside it:
{
  "reaction": "<one short reflective line answering their LAST answer; \\"\\" for Q1>",
  "question": "<the next question text>",
  "answer_type": "chips | slider | text",
  "options": ["<3-5 short options>"],
  "slider_labels": ["<left end>", "<right end>"],
  "hypothesis": null
}
Include "options" ONLY when answer_type is "chips"; include "slider_labels" ONLY when answer_type is "slider".
At Q3 ONLY, set "hypothesis" to a SPECIFIC, FALSIFIABLE early read:
{ "tags": ["<identity tag>","<identity tag>","<identity tag>"],
  "prediction": "<one concrete claim a person could score true/false: a job archetype, the kind of place
  they live, their love language, birth order, how they spend a free Saturday, etc.>" }
Vague traits true of almost everyone are forbidden. On every other turn "hypothesis" MUST be null.`;

const PORTRAIT_SYSTEM = `You are ECHO, writing the final PORTRAIT after 21 questions.
Specific over flattering — EVERY claim must be FALSIFIABLE (a different person could plausibly disagree). If
a line is true of almost everyone, cut it. No diagnoses, no sensitive attributes asserted as fact. A
reflection, not a verdict.
Return STRICT JSON only:
{
  "archetype": "<2-4 word evocative name>",
  "traits": ["<trait>","<trait>","<trait>"],
  "portrait": {
    "who": "<who this person is, 2-3 sentences>",
    "decide": "<how they decide, especially under pressure>",
    "value": "<what actually drives them — not platitudes>",
    "blindspot": "<one bold, kind, specific thing they're probably not telling themselves>"
  },
  "quotable": "<one quotable line, <= 12 words>"
}`;

function renderTranscript(history) {
  if (!history.length) return "(no questions yet)";
  return history.map((t, i) => `Q${i + 1}: ${t.q}\nA${i + 1}: ${t.a}`).join("\n\n");
}

// glm-5.2 emits JSON reliably, but retry once dropping JSON-mode (reasoning models can return empty
// content under format:json) with more room — same lesson as the prototype/SEER fix.
async function jsonCall(env, { system, user, num_predict, temperature }) {
  for (let i = 0; i < 2; i++) {
    const out = await chatJSON({
      apiKey: env.OLLAMA_API_KEY, model: ECHO_MODEL, system, user,
      schema: i === 0 ? "json" : undefined,
      options: { temperature, num_predict: Math.round(num_predict * (1 + i * 0.5)) },
      fallback: null,
    });
    if (out) return out;
  }
  return null;
}

export async function nextTurn(env, history, qNumber) {
  const sealNote = qNumber === 3
    ? `This is Q3 — you MUST also fill "hypothesis" per the contract.`
    : `"hypothesis" must be null this turn.`;
  const user = `Answers so far:\n${renderTranscript(history)}\n\nYou are about to ask question ${qNumber} of 21. ${sealNote}\nReturn the turn JSON.`;
  const out = await jsonCall(env, { system: ECHO_SYSTEM + "\n\n" + TURN_CONTRACT, user, num_predict: 1300, temperature: 0.85 });
  if (!out || !out.question) return null;
  const answer_type = ["chips", "slider", "text"].includes(out.answer_type) ? out.answer_type : "text";
  return {
    reaction: typeof out.reaction === "string" ? out.reaction : "",
    question: String(out.question),
    answer_type,
    options: answer_type === "chips" && Array.isArray(out.options) ? out.options.map(String).slice(0, 6) : null,
    slider_labels: answer_type === "slider" && Array.isArray(out.slider_labels) ? out.slider_labels.map(String).slice(0, 2) : null,
    hypothesis: out.hypothesis && typeof out.hypothesis === "object" ? out.hypothesis : null,
  };
}

export async function finalPortrait(env, history) {
  const user = `The full 21-question transcript:\n${renderTranscript(history)}\n\nWrite the portrait JSON.`;
  const out = await jsonCall(env, { system: PORTRAIT_SYSTEM, user, num_predict: 1100, temperature: 0.7 });
  if (!out) return null;
  return {
    archetype: String(out.archetype || "Unnamed"),
    traits: Array.isArray(out.traits) ? out.traits.map(String).slice(0, 3) : [],
    portrait: {
      who: String(out.portrait?.who || ""),
      decide: String(out.portrait?.decide || ""),
      value: String(out.portrait?.value || ""),
      blindspot: String(out.portrait?.blindspot || ""),
    },
    quotable: String(out.quotable || ""),
  };
}

// commit-reveal: hash(hypothesis + salt) is shown at Q3; the hypothesis + salt are opened at the end.
export async function sealHypothesis(hypothesis) {
  const salt = randomToken(12);
  const hash = await sha256hex(JSON.stringify(hypothesis) + salt);
  return { hypothesis, salt, hash };
}
