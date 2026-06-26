# Echo — Phase 0 prototype

> *It's not a game where the AI guesses what you're thinking. It's a game where the AI guesses **who you are** — and gets it unsettlingly right.*

Phase 0 exists to answer the one question the whole product rests on **before any app is built**: does the read feel uncanny **and specific** — or is it a horoscope? (See the blueprint, §6 and §10.)

## The bar (and how we make it runnable)

The honest test of "specific, not generic" is the **lineup test**: write a person's portrait, hand it to someone (or something) blind to the truth alongside decoy portraits, and see if they can pick the real person well above chance. Real users can't give us ground truth cheaply at Phase 0, so we use **LLM-simulated personas**:

- **5 distinct ground-truth personas** (`personas.mjs`) — a burned-out ER nurse, an anxious indie game dev, a steady rural teacher, a relentless founder, a precarious artist. Only the *answerer* sees each dossier.
- **The answerer** (`gpt-oss:120b`) role-plays a persona answering Echo's questions, in character.
- **Echo** (`glm-5.2`, `echo.mjs`) is **blind to the dossier** — it only sees answers. It asks 21 adaptive questions (JSON turn contract), seals a hypothesis at Q3 (SHA-256 commit-reveal), and writes a 4-part falsifiable portrait.
- **The judge** (`deepseek-v4-pro`, `lineup.mjs`) is a **third independent model** that sees only the portrait + all five short persona tags, and must pick which person it describes.

Three different model families (Echo / answerer / judge) keep the test from grading its own homework.

**Pass = lineup accuracy well above chance (20% for 5) AND average self-rating ≥ 4/5.**

## Run it

```bash
set -a; . /root/.secrets/negotiator-ollama.env; set +a   # OLLAMA_API_KEY
node run-session.mjs nurse     # one full session, prints transcript + sealed read + portrait
node lineup.mjs                # the Phase 0 bar across all 5 personas
```

## Files

| File | Role |
| --- | --- |
| `echo.mjs` | The Echo brain — adaptive question policy, Q3 seal, final portrait |
| `personas.mjs` | Ground-truth personas + the in-character answerer |
| `run-session.mjs` | One persona → full 21-question session → portrait |
| `lineup.mjs` | The lineup test (independent judge) + self-rating; prints the Phase 0 result |
| `ollama.mjs` | Ollama Cloud client (JSON mode, retries) |

## Status — Phase 0 PASS ✅

Lineup test, 5 personas, independent `deepseek-v4-pro` judge (blind to ground truth):

```
Lineup accuracy : 5/5 = 100%   (chance = 20%), every match @95% confidence
Avg self-rating : 4.40/5
```

The reads are specific enough that a blind third model picks the right person out of a five-way lineup **every time**. Sample portraits in `samples/` (e.g. nurse → *"The Load-Bearing Wall"*, founder → *"The Indispensable Sprinter"*, dev → *"The Reluctant Polisher"*).

**Honest caveat.** The personas are deliberately distinct, which is an easier setting than real humans who cluster. The next rigor steps before over-trusting the number: (a) add near-duplicate "hard" personas (e.g. two anxious creatives) to stress discrimination, and (b) validate with real users. But the defined Phase 0 bar — uncanny *and specific*, provable via the lineup — is met decisively.
