PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS sessions (
  id              TEXT PRIMARY KEY,
  started_at      INTEGER NOT NULL,
  ended_at        INTEGER,
  shell           TEXT NOT NULL,
  cwd_initial     TEXT NOT NULL,
  cwd_final       TEXT,
  host            TEXT NOT NULL,
  status          TEXT NOT NULL,
  exit_code       INTEGER,
  pinned          INTEGER NOT NULL DEFAULT 0,
  title           TEXT,
  bytes_in        INTEGER NOT NULL DEFAULT 0,
  bytes_out       INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_sessions_started ON sessions(started_at DESC);

CREATE TABLE IF NOT EXISTS events (
  session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  seq             INTEGER NOT NULL,
  ts              INTEGER NOT NULL,
  direction       TEXT NOT NULL,
  data            BLOB NOT NULL,
  PRIMARY KEY (session_id, seq)
);

CREATE VIRTUAL TABLE IF NOT EXISTS events_fts USING fts5(
  data, content='', tokenize='unicode61 remove_diacritics'
);

CREATE TABLE IF NOT EXISTS meta ( key TEXT PRIMARY KEY, value TEXT NOT NULL );

CREATE TRIGGER IF NOT EXISTS events_ai AFTER INSERT ON events BEGIN
  INSERT INTO events_fts(rowid, data) VALUES (new.rowid, CAST(new.data AS TEXT));
END;
CREATE TRIGGER IF NOT EXISTS events_ad AFTER DELETE ON events BEGIN
  DELETE FROM events_fts WHERE rowid = old.rowid;
END;
