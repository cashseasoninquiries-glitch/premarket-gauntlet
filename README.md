# Premarket Gauntlet

A premarket scanner that turns "what gapped overnight?" into a short, ranked,
explained watchlist. Built as a read-only feature of the Apex Executions Cockpit.

```
all US stocks
  -> gap >= 3% vs prior close
  -> hard filters: price, spread, premarket volume, float
  -> catalyst lookup: news, earnings, analyst actions
  -> LLM classification: type, direction, strength
  -> weighted score
  -> top 5, with every rejected ticker logged and explained
```

## Ground rules

1. **Read-only.** The gauntlet writes to its own `scanner` Postgres schema and
   nothing else. It has no path to order routing or risk gates. A ranked name
   only becomes a trade if a human places it.
2. **Fail closed.** Missing float, stale quote, or a feed outage means reject or
   report `no_data`. An outage must never look like a quiet morning.
3. **Explain every drop.** Each rejected ticker is logged with the filter that
   killed it, so the gauntlet can be audited instead of trusted.
4. **Not validated strategy output.** These picks have not been through DSR, PBO
   or CPCV. Keep them out of Apex Engine's trial counts and lineage.
5. **Public repo.** No keys, DSNs, or account details in git. Secrets go in `.env`.

## Phases

Progress is tracked in the [GitHub issues](../../issues), one per phase.

| Phase | What | Status |
|---|---|---|
| 0 | Foundation: repo, config, schema, validation | Done |
| 1 | Gap scan: universe + premarket price vs prior close | Not started |
| 2 | Hard filters + rejection log | Not started |
| 3 | Catalyst lookup: news, earnings, analyst actions | Not started |
| 4 | LLM catalyst classification | Not started |
| 5 | Ranking + outcome logging | Not started |
| 6 | Cockpit panel, scheduler, voice brief | Not started |
| 7 | Hardening: halts, corporate actions, rate limits, outages | Not started |

## Layout

```
config/gauntlet.toml         thresholds and ranking weights
sql/001_scanner_schema.sql   Postgres tables (review before applying)
src/gauntlet/config.py       config loader with strict validation
tests/                       pytest suite
.env.example                 the secrets you will need, with no values
```

## Setup (Windows, PowerShell)

```powershell
cd "C:\Dev\premarket-gauntlet"
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"
pytest
```

Then copy the env template and fill it in:

```powershell
cd "C:\Dev\premarket-gauntlet"
Copy-Item .env.example .env
```

## Known limitation

Alpaca's free feed covers a single exchange (IEX), so premarket volume reads far
below the true figure and spreads can look wider than they are. Volume and
spread are two of the three hard filters. Until a consolidated (SIP) feed is in
place, treat volume as a relative ranking and not an absolute threshold.
