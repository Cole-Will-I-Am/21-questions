-- echo-api schema (Cloudflare D1 / SQLite).
-- Identity (anon device + optional Sign in with Apple) reuses the Negotiator/RUNG shape; the game
-- tables (echo_session / echo_turn) hold one self-portrait session and its 21 adaptive turns.
PRAGMA foreign_keys = ON;

-- ===== players / identity =====
CREATE TABLE IF NOT EXISTS players (
  id            TEXT    PRIMARY KEY,            -- 'p_' + random
  apple_sub     TEXT    UNIQUE,                 -- HMAC(sub) lookup key; nullable until SIWA
  display       TEXT    NOT NULL,
  is_anonymous  INTEGER NOT NULL DEFAULT 1,
  created_at    INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS device_links (
  device_id   TEXT PRIMARY KEY,
  player_id   TEXT NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  secret_hash TEXT NOT NULL,                    -- sha256(deviceSecret)
  created_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token       TEXT PRIMARY KEY,                 -- sha256(token)
  player_id   TEXT NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  created_at  INTEGER NOT NULL,
  expires_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_player ON sessions(player_id);

CREATE TABLE IF NOT EXISTS rate (
  k   TEXT PRIMARY KEY,
  n   INTEGER NOT NULL DEFAULT 0,
  exp INTEGER NOT NULL
);

-- ===== echo: one self-portrait session = one echo_session, up to 21 echo_turn =====
CREATE TABLE IF NOT EXISTS echo_session (
  id            TEXT PRIMARY KEY,               -- 'g_' + random
  player_id     TEXT NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  mode          TEXT NOT NULL DEFAULT 'mirror', -- mirror (build 1) | oracle | duet
  q_index       INTEGER NOT NULL DEFAULT 0,     -- questions answered so far (0..21)
  status        TEXT NOT NULL DEFAULT 'active', -- active | revealed | abandoned
  seal_hash     TEXT,                           -- SHA-256(hypothesis + salt), shown at Q3
  seal_salt     TEXT,
  seal_json     TEXT,                           -- the sealed hypothesis, opened only at the reveal
  portrait_json TEXT,                           -- the 4-part portrait, set at reveal
  rating        INTEGER,                        -- player's 1-5 accuracy rating
  started_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_echo_session_player ON echo_session(player_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS echo_turn (
  session_id        TEXT NOT NULL REFERENCES echo_session(id) ON DELETE CASCADE,
  turn_number       INTEGER NOT NULL,           -- 1..21
  reaction          TEXT NOT NULL DEFAULT '',   -- Echo's reflection on the PRIOR answer
  question          TEXT NOT NULL,
  answer_type       TEXT NOT NULL,              -- chips | slider | text
  options_json      TEXT,                       -- chips options
  slider_labels_json TEXT,                      -- [leftLabel, rightLabel]
  answer            TEXT,                        -- the player's answer (null until answered)
  created_at        INTEGER NOT NULL,
  PRIMARY KEY (session_id, turn_number)
);
