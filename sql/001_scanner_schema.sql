-- Premarket Gauntlet: Postgres schema.
-- Everything lives in its own `scanner` schema. The gauntlet role can write here
-- and nowhere else, so it has no path to Apex Engine's orders or risk tables.
--
-- NOT YET APPLIED ANYWHERE. Review, set a real password, then run by hand.

CREATE SCHEMA IF NOT EXISTS scanner;

-- One row per scheduled scan (e.g. the 08:00 ET run on a given day).
CREATE TABLE IF NOT EXISTS scanner.scan_runs (
    id              BIGSERIAL PRIMARY KEY,
    trade_date      DATE        NOT NULL,
    scheduled_for   TIMESTAMPTZ NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at     TIMESTAMPTZ,
    -- 'running' | 'ok' | 'no_data' | 'failed'
    -- 'no_data' means a feed was down. It must never look like a quiet morning.
    status          TEXT        NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'ok', 'no_data', 'failed')),
    data_feed       TEXT        NOT NULL,
    config_snapshot JSONB       NOT NULL,
    universe_size   INTEGER,
    error           TEXT,
    UNIQUE (trade_date, scheduled_for)
);

-- Tickers that passed every hard filter.
CREATE TABLE IF NOT EXISTS scanner.candidates (
    id                BIGSERIAL PRIMARY KEY,
    scan_run_id       BIGINT  NOT NULL REFERENCES scanner.scan_runs (id) ON DELETE CASCADE,
    ticker            TEXT    NOT NULL,
    prior_close       NUMERIC NOT NULL,
    premarket_price   NUMERIC NOT NULL,
    gap_pct           NUMERIC NOT NULL,
    spread_pct        NUMERIC,
    premarket_volume  BIGINT,
    relative_volume   NUMERIC,
    float_shares      BIGINT,
    levels            JSONB,
    score             NUMERIC,
    score_breakdown   JSONB,
    rank              INTEGER,
    UNIQUE (scan_run_id, ticker)
);

-- Every ticker that gapped but was dropped, and the filter that dropped it.
CREATE TABLE IF NOT EXISTS scanner.rejections (
    id           BIGSERIAL PRIMARY KEY,
    scan_run_id  BIGINT NOT NULL REFERENCES scanner.scan_runs (id) ON DELETE CASCADE,
    ticker       TEXT   NOT NULL,
    filter_name  TEXT   NOT NULL,
    observed     TEXT,
    threshold    TEXT,
    reason       TEXT   NOT NULL
);
CREATE INDEX IF NOT EXISTS rejections_run_idx ON scanner.rejections (scan_run_id);

-- News / earnings / analyst actions found for a candidate, plus the LLM's label.
CREATE TABLE IF NOT EXISTS scanner.catalysts (
    id            BIGSERIAL PRIMARY KEY,
    candidate_id  BIGINT NOT NULL REFERENCES scanner.candidates (id) ON DELETE CASCADE,
    source        TEXT   NOT NULL,
    published_at  TIMESTAMPTZ,
    headline      TEXT   NOT NULL,
    url           TEXT,
    catalyst_type TEXT,
    direction     TEXT CHECK (direction IN ('bullish', 'bearish', 'neutral', 'unclear')),
    strength      SMALLINT CHECK (strength BETWEEN 0 AND 5),
    model         TEXT,
    raw_label     JSONB
);
CREATE INDEX IF NOT EXISTS catalysts_candidate_idx ON scanner.catalysts (candidate_id);

-- What each candidate actually did that day. This is what the ranking is tuned on.
CREATE TABLE IF NOT EXISTS scanner.outcomes (
    candidate_id     BIGINT PRIMARY KEY REFERENCES scanner.candidates (id) ON DELETE CASCADE,
    open_price       NUMERIC,
    high_price       NUMERIC,
    low_price        NUMERIC,
    close_price      NUMERIC,
    max_favorable_pct NUMERIC,
    max_adverse_pct   NUMERIC,
    recorded_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Dedicated role: full access inside `scanner`, nothing else.
-- DO $$ BEGIN
--     CREATE ROLE gauntlet_rw LOGIN PASSWORD 'CHANGE_ME';
-- EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- GRANT USAGE ON SCHEMA scanner TO gauntlet_rw;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA scanner TO gauntlet_rw;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA scanner TO gauntlet_rw;
