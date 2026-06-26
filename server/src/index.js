// echo-api Worker. Adaptive 21-question self-portrait engine over Ollama Cloud on D1.
// Identity (anon device + optional Sign in with Apple) + sessions reuse the Negotiator/RUNG spine;
// the session handlers run the Echo engine (echo.js) and persist the transcript + sealed read.

import {
  HttpError, sha256hex, hmacHex, randomToken, randomId,
  verifyAppleIdentityToken, createSession, authPlayer, constantTimeEqual,
} from "./auth.js";
import { nextTurn, finalPortrait, sealHypothesis, classicTurn, ECHO_MODEL } from "./echo.js";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization,content-type",
  "access-control-allow-methods": "GET,POST,DELETE,OPTIONS",
};
const json = (obj, status = 200, headers = {}) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json", ...CORS, ...headers } });
const ok = (obj, headers) => json(obj, 200, headers);
const fail = (status, error) => json({ error }, status);
async function readJson(req) { try { return await req.json(); } catch { return {}; } }
const nowS = () => Math.floor(Date.now() / 1000);

async function rateLimit(env, req, key, limit, windowSec) {
  const ip = req.headers.get("CF-Connecting-IP") || "0";
  const bucket = Math.floor(Date.now() / 1000 / windowSec);
  const k = `${key}:${ip}:${bucket}`;
  const row = await env.DB.prepare(
    "INSERT INTO rate(k,n,exp) VALUES(?,1,?) ON CONFLICT(k) DO UPDATE SET n=n+1 RETURNING n"
  ).bind(k, (bucket + 1) * windowSec).first();
  return (row?.n ?? 1) <= limit;
}

async function newPlayer(env, { apple_sub = null, isAnon = 1 }) {
  const id = randomId("p_");
  const code = randomToken(2).slice(0, 4).toUpperCase();
  await env.DB.prepare(
    "INSERT INTO players(id,apple_sub,display,is_anonymous,created_at) VALUES(?,?,?,?,?)"
  ).bind(id, apple_sub, "Seeker-" + code, isAnon, nowS()).run();
  return env.DB.prepare("SELECT * FROM players WHERE id=?").bind(id).first();
}
const playerView = (p) => ({ id: p.id, display: p.display, isAnonymous: !!p.is_anonymous });

async function requireAuth(req, env) {
  const p = await authPlayer(req, env);
  if (!p) throw new HttpError(401, "unauthorized");
  return p;
}

// ---------------- identity ----------------

async function hAccount(req, env) {
  if (!(await rateLimit(env, req, "acct", 30, 3600))) return fail(429, "rate_limited");
  const body = await readJson(req);

  if (body.appleIdentityToken) {
    if (!env.APPLE_SUB_PEPPER || !env.APPLE_BUNDLE_ID) return fail(501, "siwa_disabled");
    const sub = await verifyAppleIdentityToken(body.appleIdentityToken, body.nonce ?? null, env.APPLE_BUNDLE_ID);
    const subKey = await hmacHex(sub, env.APPLE_SUB_PEPPER);
    let p = await env.DB.prepare("SELECT * FROM players WHERE apple_sub=?").bind(subKey).first();
    if (!p && body.deviceId && body.deviceSecret) {
      const link = await env.DB.prepare("SELECT * FROM device_links WHERE device_id=?").bind(body.deviceId).first();
      if (link && link.secret_hash && constantTimeEqual(link.secret_hash, await sha256hex(body.deviceSecret))) {
        const anon = await env.DB.prepare("SELECT * FROM players WHERE id=? AND is_anonymous=1").bind(link.player_id).first();
        if (anon) {
          await env.DB.prepare("UPDATE players SET apple_sub=?, is_anonymous=0 WHERE id=?").bind(subKey, anon.id).run();
          p = await env.DB.prepare("SELECT * FROM players WHERE id=?").bind(anon.id).first();
        }
      }
    }
    if (!p) p = await newPlayer(env, { apple_sub: subKey, isAnon: 0 });
    const s = await createSession(env, p.id);
    return ok({ token: s.token, expiresAt: s.expiresAt, player: playerView(p) });
  }

  const deviceId = body.deviceId;
  if (!deviceId) return fail(400, "missing_deviceId");
  const link = await env.DB.prepare("SELECT * FROM device_links WHERE device_id=?").bind(deviceId).first();
  if (link) {
    if (!body.deviceSecret || !link.secret_hash ||
        !constantTimeEqual(link.secret_hash, await sha256hex(body.deviceSecret))) {
      return fail(401, "bad_device_secret");
    }
    const p = await env.DB.prepare("SELECT * FROM players WHERE id=?").bind(link.player_id).first();
    if (!p) return fail(401, "bad_device_secret");
    const s = await createSession(env, p.id);
    return ok({ token: s.token, expiresAt: s.expiresAt, player: playerView(p) });
  }
  const secret = randomToken(32);
  const p = await newPlayer(env, { isAnon: 1 });
  await env.DB.prepare("INSERT OR IGNORE INTO device_links(device_id,player_id,secret_hash,created_at) VALUES(?,?,?,?)")
    .bind(deviceId, p.id, await sha256hex(secret), nowS()).run();
  const s = await createSession(env, p.id);
  return ok({ token: s.token, expiresAt: s.expiresAt, player: playerView(p), deviceSecret: secret });
}

async function hDeleteAccount(req, env, player) {
  await env.DB.batch([
    env.DB.prepare("DELETE FROM echo_turn WHERE session_id IN (SELECT id FROM echo_session WHERE player_id=?)").bind(player.id),
    env.DB.prepare("DELETE FROM echo_session WHERE player_id=?").bind(player.id),
    env.DB.prepare("DELETE FROM sessions WHERE player_id=?").bind(player.id),
    env.DB.prepare("DELETE FROM device_links WHERE player_id=?").bind(player.id),
    env.DB.prepare("DELETE FROM players WHERE id=?").bind(player.id),
  ]);
  return ok({ deleted: true });
}

// ---------------- echo session ----------------

function historyFrom(turns) {
  return turns.filter((t) => t.answer != null).map((t) => ({ q: t.question, a: t.answer }));
}
function turnView(n, t) {
  return {
    n, reaction: t.reaction || "", question: t.question, answer_type: t.answer_type,
    options: t.options || null, slider_labels: t.slider_labels || null,
  };
}
function rowTurnView(t) {
  return {
    n: t.turn_number, reaction: t.reaction || "", question: t.question, answer_type: t.answer_type,
    options: t.options_json ? JSON.parse(t.options_json) : null,
    slider_labels: t.slider_labels_json ? JSON.parse(t.slider_labels_json) : null,
  };
}

async function insertTurn(env, sid, n, turn, now) {
  await env.DB.prepare(
    `INSERT INTO echo_turn(session_id,turn_number,reaction,question,answer_type,options_json,slider_labels_json,created_at)
     VALUES(?,?,?,?,?,?,?,?)`
  ).bind(sid, n, turn.reaction || "", turn.question, turn.answer_type,
         turn.options ? JSON.stringify(turn.options) : null,
         turn.slider_labels ? JSON.stringify(turn.slider_labels) : null, now).run();
}

async function hSessionStart(req, env, player) {
  if (!(await rateLimit(env, req, "start", 60, 3600))) return fail(429, "rate_limited");
  const body = await readJson(req);
  const mode = body.mode === "classic" ? "classic" : "mirror";
  const turn = mode === "classic" ? await classicTurn(env, [], 1) : await nextTurn(env, [], 1);
  if (!turn) return fail(503, "echo_unavailable");
  const id = randomId("g_");
  const now = nowS();
  await env.DB.prepare(
    `INSERT INTO echo_session(id,player_id,mode,q_index,status,started_at,updated_at)
     VALUES(?,?,?,0,'active',?,?)`
  ).bind(id, player.id, mode, now, now).run();
  await insertTurn(env, id, 1, turn, now);
  return ok({ sessionId: id, mode, total: 21, turn: turnView(1, turn) });
}

async function hAnswer(req, env, player) {
  if (!(await rateLimit(env, req, "answer", 600, 3600))) return fail(429, "rate_limited");
  const body = await readJson(req);
  const sid = String(body.sessionId || "");
  const answer = String(body.answer ?? "").slice(0, 2000).trim();
  if (!answer) return fail(400, "empty_answer");
  const sess = await env.DB.prepare("SELECT * FROM echo_session WHERE id=? AND player_id=?").bind(sid, player.id).first();
  if (!sess) return fail(404, "no_session");
  if (sess.status !== "active") return fail(409, "not_active");

  const turns = (await env.DB.prepare("SELECT * FROM echo_turn WHERE session_id=? ORDER BY turn_number").bind(sid).all()).results || [];
  const current = turns[turns.length - 1];
  if (!current || current.answer != null) return fail(409, "no_open_turn");
  const now = nowS();
  await env.DB.prepare("UPDATE echo_turn SET answer=? WHERE session_id=? AND turn_number=?").bind(answer, sid, current.turn_number).run();
  current.answer = answer;
  const answered = current.turn_number;            // questions answered so far
  const history = historyFrom(turns);

  // CLASSIC mode: Echo is guessing the player's secret. A confirmed guess wins; running out at 21 = stumped.
  if (sess.mode === "classic") {
    const wasGuess = current.answer_type === "guess";
    const correct = /^\s*(yes|correct|that'?s it|got it|right|yep|yeah)\b/i.test(answer);
    if (wasGuess && correct) {
      await env.DB.prepare("UPDATE echo_session SET status='solved', q_index=?, updated_at=? WHERE id=?").bind(answered, now, sid).run();
      return ok({ done: true, mode: "classic", outcome: "solved", progress: { answered, total: 21 } });
    }
    if (answered >= 21) {                            // the forced 21st guess was wrong
      await env.DB.prepare("UPDATE echo_session SET status='stumped', q_index=?, updated_at=? WHERE id=?").bind(answered, now, sid).run();
      return ok({ done: true, mode: "classic", outcome: "stumped", progress: { answered, total: 21 } });
    }
    const nextNum = answered + 1;
    const turn = await classicTurn(env, history, nextNum);
    if (!turn) return fail(503, "echo_unavailable");
    await insertTurn(env, sid, nextNum, turn, now);
    await env.DB.prepare("UPDATE echo_session SET q_index=?, updated_at=? WHERE id=?").bind(answered, now, sid).run();
    return ok({ done: false, mode: "classic", progress: { answered, total: 21 }, turn: turnView(nextNum, turn) });
  }

  // MIRROR mode: final question answered -> write the portrait, open the seal
  if (answered >= 21) {
    const portrait = await finalPortrait(env, history);
    if (!portrait) return fail(503, "echo_unavailable");
    await env.DB.prepare("UPDATE echo_session SET status='revealed', q_index=?, portrait_json=?, updated_at=? WHERE id=?")
      .bind(answered, JSON.stringify(portrait), now, sid).run();
    const seal = sess.seal_json ? { hypothesis: JSON.parse(sess.seal_json), salt: sess.seal_salt, hash: sess.seal_hash } : null;
    return ok({ done: true, progress: { answered, total: 21 }, portrait, seal });
  }

  // otherwise generate the next question
  const nextNum = answered + 1;
  const turn = await nextTurn(env, history, nextNum);
  if (!turn) return fail(503, "echo_unavailable");
  let sealOut = null;
  if (nextNum === 3 && turn.hypothesis && !sess.seal_json) {
    const seal = await sealHypothesis(turn.hypothesis);
    await env.DB.prepare("UPDATE echo_session SET seal_hash=?, seal_salt=?, seal_json=? WHERE id=?")
      .bind(seal.hash, seal.salt, JSON.stringify(seal.hypothesis), sid).run();
    sealOut = { hash: seal.hash };       // shown as the sealed envelope; opened only at the reveal
  }
  await insertTurn(env, sid, nextNum, turn, now);
  await env.DB.prepare("UPDATE echo_session SET q_index=?, updated_at=? WHERE id=?").bind(answered, now, sid).run();
  return ok({ done: false, progress: { answered, total: 21 }, turn: turnView(nextNum, turn), seal: sealOut });
}

async function hRate(req, env, player) {
  const body = await readJson(req);
  const sid = String(body.sessionId || "");
  const rating = Math.max(1, Math.min(5, parseInt(body.rating, 10) || 0));
  if (!rating) return fail(400, "bad_rating");
  const r = await env.DB.prepare("UPDATE echo_session SET rating=? WHERE id=? AND player_id=?").bind(rating, sid, player.id).run();
  return ok({ saved: (r.meta?.changes ?? 0) > 0 });
}

async function hSessionGet(req, env, player, id) {
  const sess = await env.DB.prepare("SELECT * FROM echo_session WHERE id=? AND player_id=?").bind(id, player.id).first();
  if (!sess) return fail(404, "no_session");
  const turns = (await env.DB.prepare("SELECT * FROM echo_turn WHERE session_id=? ORDER BY turn_number").bind(id).all()).results || [];
  const open = turns.find((t) => t.answer == null);
  const revealed = sess.status === "revealed";
  return ok({
    sessionId: id, status: sess.status, progress: { answered: sess.q_index, total: 21 },
    turns: turns.map((t) => ({ ...rowTurnView(t), answer: t.answer })),
    currentTurn: open ? rowTurnView(open) : null,
    seal: sess.seal_hash
      ? (revealed ? { hypothesis: JSON.parse(sess.seal_json), salt: sess.seal_salt, hash: sess.seal_hash } : { hash: sess.seal_hash })
      : null,
    portrait: sess.portrait_json ? JSON.parse(sess.portrait_json) : null,
    rating: sess.rating ?? null,
  });
}

async function hHealth(req, env) {
  let db = "ok";
  try { await env.DB.prepare("SELECT 1").first(); } catch { db = "down"; }
  return ok({ ok: true, db, model: ECHO_MODEL, ts: nowS() });
}
function hLanding() {
  return new Response("Echo API — the AI that reads who you are. See echo://app.", {
    headers: { "content-type": "text/plain", ...CORS },
  });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const path = url.pathname;
    const method = req.method;
    if (method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    try {
      if (path === "/healthz") return hHealth(req, env);
      if (path === "/" && method === "GET") return hLanding();

      if (path === "/v1/account" && method === "POST") return hAccount(req, env);
      if (path === "/v1/account" && method === "DELETE") return hDeleteAccount(req, env, await requireAuth(req, env));
      if (path === "/v1/session/start" && method === "POST") return hSessionStart(req, env, await requireAuth(req, env));
      if (path === "/v1/session/answer" && method === "POST") return hAnswer(req, env, await requireAuth(req, env));
      if (path === "/v1/session/rate" && method === "POST") return hRate(req, env, await requireAuth(req, env));
      const m = path.match(/^\/v1\/session\/([A-Za-z0-9_-]+)$/);
      if (m && method === "GET") return hSessionGet(req, env, await requireAuth(req, env), m[1]);

      return fail(404, "not_found");
    } catch (e) {
      if (e instanceof HttpError) return fail(e.status, e.message);
      console.error("[echo]", e && e.stack || e);
      return fail(500, "server_error");
    }
  },
};
