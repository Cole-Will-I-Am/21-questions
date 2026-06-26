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

## Status

Engine works end to end; single-session reads are specific and seam-probing (e.g. the nurse persona → *"The Triage Operator… her entire hierarchy of people is sorted by usefulness when it counts"*, with the Q3 seal hash-verified). Lineup-test numbers are being measured — that result is the gate for everything after Phase 0.
