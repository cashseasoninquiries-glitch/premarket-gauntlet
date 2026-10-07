-- Premarket Gauntlet: SQLite schema. One local file, no server.
-- Timestamps are ISO-8601 UTC text. JSON columns hold JSON text.

PRAGMA foreign_keys = ON;

-- One row per scan (e.g. the 08:00 ET run on a given day).
CREATE TABLE IF NOT EXISTS scan_runs (
    id              INTEGER PRIMARY KEY,
    trade_date      TEXT NOT NULL,
    scheduled_for   TEXT NOT NULL,
    started_at      TEXT NOT NULL,
    finished_at     TEXT,
    -- 'no_data' means a feed was down. It must never look like a quiet morning.
    status          TEXT NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'ok', 'no_data', 'failed')),
    data_feed       TEXT NOT NULL,
    config_snapshot TEXT NOT NULL,
    universe_size   INTEGER,
    error           TEXT,
    UNIQUE (trade_date, scheduled_for)
);

-- Tickers that passed every hard filter.
CREATE TABLE IF NOT EXISTS candidates (
    id               INTEGER PRIMARY KEY,
    scan_run_id      INTEGER NOT NULL REFERENCES scan_runs (id) ON DELETE CASCADE,
    ticker           TEXT NOT NULL,
    prior_close      REAL NOT NULL,
    premarket_price  REAL NOT NULL,
    gap_pct          REAL NOT NULL,
    spread_pct       REAL,
    premarket_volume INTEGER,
    relative_volume  REAL,
    float_shares     INTEGER,
    levels           TEXT,
    score            REAL,
    score_breakdown  TEXT,
    rank             INTEGER,
    UNIQUE (scan_run_id, ticker)
);

-- Every ticker that gapped but was dropped, and the filter that dropped it.
CREATE TABLE IF NOT EXISTS rejections (
    id          INTEGER PRIMARY KEY,
    scan_run_id INTEGER NOT NULL REFERENCES scan_runs (id) ON DELETE CASCADE,
    ticker      TEXT NOT NULL,
    filter_name TEXT NOT NULL,
    observed    TEXT,
    threshold   TEXT,
    reason      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS rejections_run_idx ON rejections (scan_run_id);

-- News / earnings / analyst actions found for a candidate, plus the label.
CREATE TABLE IF NOT EXISTS catalysts (
    id            INTEGER PRIMARY KEY,
    candidate_id  INTEGER NOT NULL REFERENCES candidates (id) ON DELETE CASCADE,
    source        TEXT NOT NULL,
    published_at  TEXT,
    headline      TEXT NOT NULL,
    url           TEXT,
    catalyst_type TEXT,
    direction     TEXT CHECK (direction IN ('bullish', 'bearish', 'neutral', 'unclear')),
    strength      INTEGER CHECK (strength BETWEEN 0 AND 5),
    model         TEXT,
    raw_label     TEXT
);
CREATE INDEX IF NOT EXISTS catalysts_candidate_idx ON catalysts (candidate_id);

-- What each candidate actually did that day. The ranking is tuned on this.
CREATE TABLE IF NOT EXISTS outcomes (
    candidate_id      INTEGER PRIMARY KEY REFERENCES candidates (id) ON DELETE CASCADE,
    open_price        REAL,
    high_price        REAL,
    low_price         REAL,
    close_price       REAL,
    max_favorable_pct REAL,
    max_adverse_pct   REAL,
    recorded_at       TEXT NOT NULL
);
