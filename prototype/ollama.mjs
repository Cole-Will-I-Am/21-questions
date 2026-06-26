// Thin Ollama Cloud chat client for the Echo Phase 0 prototype.
const URL = "https://ollama.com/api/chat";
const KEY = process.env.OLLAMA_API_KEY;
if (!KEY) { console.error("Set OLLAMA_API_KEY (e.g. `set -a; . /root/.secrets/negotiator-ollama.env; set +a`)"); process.exit(1); }

export async function chat({ model, system, messages, json = false, think = false, num_predict = 1024, temperature = 0.7 }) {
  const msgs = [];
  if (system) msgs.push({ role: "system", content: system });
  msgs.push(...messages);
  const body = { model, messages: msgs, stream: false, think, options: { temperature, num_predict } };
  if (json) body.format = "json";
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(URL, {
        method: "POST",
        headers: { Authorization: `Bearer ${KEY}`, "content-type": "application/json", "user-agent": "Mozilla/5.0 echo-proto" },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const t = await res.text();
        if (res.status >= 500 && attempt < 2) { await sleep(1200); continue; }
        throw new Error(`ollama ${res.status}: ${t.slice(0, 300)}`);
      }
      const data = await res.json();
      return data.message?.content ?? "";
    } catch (e) {
      if (attempt < 2) { await sleep(1200); continue; }
      throw e;
    }
  }
}

export async function chatJSON(opts) {
  const base = opts.num_predict ?? 1024;
  let lastRaw = "";
  for (let attempt = 0; attempt < 3; attempt++) {
    // Attempt 0 uses JSON-mode; retries DROP it — reasoning models (gpt-oss, deepseek) can return
    // empty content under format:json, so fall back to free-form + salvage and give more room.
    const raw = await chat({ ...opts, json: attempt === 0, num_predict: Math.round(base * (1 + attempt * 0.6)) });
    lastRaw = raw;
    const cleaned = raw.replace(/```(?:json)?/gi, "").trim();
    try { return JSON.parse(cleaned); } catch {}
    const m = cleaned.match(/\{[\s\S]*\}/);
    if (m) { try { return JSON.parse(m[0]); } catch {} }
  }
  throw new Error("bad JSON from model: " + JSON.stringify(lastRaw.slice(0, 200)));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
