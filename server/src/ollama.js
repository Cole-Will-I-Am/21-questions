// Ollama Cloud client for the negotiator-api Worker. Same wire format as the Phase 0
// prototype, parameterized by an API key (from env, not a file) and with a streaming
// callback so the gatekeeper's content can be piped to the HTTP client as it arrives.
//   - chat streams NDJSON: {message:{content, thinking?}, done, done_reason?}
//   - think:true emits message.thinking deltas BEFORE message.content; we discard thinking.
//   - format:<schema> is honored loosely (field names not guaranteed) -> parse leniently.

const ENDPOINT = "https://ollama.com/api/chat";

function headers(apiKey) {
  return { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" };
}

// Streaming chat for the gatekeeper. Calls onDelta(text) for each message.content chunk,
// discards message.thinking, and returns the full accumulated { content, doneReason }.
export async function streamGatekeeper({ apiKey, model, messages, options = {}, think = false, onDelta, signal }) {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: headers(apiKey),
    signal,
    body: JSON.stringify({ model, messages, stream: true, think, options }),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Ollama ${res.status}: ${body.slice(0, 300)}`);
  }
  const reader = res.body.getReader();
  const dec = new TextDecoder();
  let buf = "", content = "", doneReason = null;
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    const lines = buf.split("\n");
    buf = lines.pop();
    for (const ln of lines) {
      const s = ln.trim();
      if (!s) continue;
      let o;
      try { o = JSON.parse(s); } catch { continue; }
      const m = o.message || {};
      if (m.content) { content += m.content; if (onDelta) onDelta(m.content); }
      if (o.done) doneReason = o.done_reason || null;
    }
  }
  return { content, doneReason };
}

// Non-streaming structured call for the cheap roles (classifier / evaluator / judge).
// `format` is a hint; the caller normalizes loose output. Returns parsed object or `fallback`.
export async function chatJSON({ apiKey, model, system, user, schema, options = {}, fallback = null, think = false }) {
  let raw = "";
  try {
    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: headers(apiKey),
      body: JSON.stringify({
        model,
        stream: false,
        think,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
        ...(schema ? { format: schema } : {}),
        options: { temperature: 0, num_predict: 400, ...options },
      }),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => "");
      throw new Error(`Ollama ${res.status}: ${body.slice(0, 200)}`);
    }
    const j = await res.json();
    raw = (j.message && j.message.content) || "";
  } catch (e) {
    console.error("[chatJSON]", e.message);
    return fallback;
  }
  const parsed = parseLooseJSON(raw);
  return parsed == null ? fallback : parsed;
}

// Lenient JSON extraction: strips code fences, then takes the first balanced {...}.
export function parseLooseJSON(text) {
  if (!text) return null;
  let t = String(text).trim();
  t = t.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
  try { return JSON.parse(t); } catch {}
  const start = t.indexOf("{");
  if (start === -1) return null;
  let depth = 0, inStr = false, esc = false;
  for (let i = start; i < t.length; i++) {
    const c = t[i];
    if (inStr) {
      if (esc) esc = false;
      else if (c === "\\") esc = true;
      else if (c === '"') inStr = false;
    } else {
      if (c === '"') inStr = true;
      else if (c === "{") depth++;
      else if (c === "}") { depth--; if (depth === 0) {
        const cand = t.slice(start, i + 1);
        try { return JSON.parse(cand); } catch { return null; }
      } }
    }
  }
  return null;
}
