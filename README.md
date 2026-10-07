# Premarket Gauntlet

Automates as much of a premarket trading checklist as possible, every morning,
and hands back a short ranked watchlist of tickers that fit set parameters.

Standalone project. It depends on no other repo or application.

## The checklist, and what gets automated

| # | Checklist step | Automated? | Phase |
|---|---|---|---|
| 1 | Read the overnight tape: risk-on, risk-off, or chop | Data gathered and summarised; the call is yours | 6 |
| 2 | Check the economic calendar | Yes | 6 |
| 3 | Scan for gappers with volume and a real catalyst | Yes | 1, 2, 3 |
| 4 | Check liquidity: volume, spread, float | Yes | 2 |
| 5 | Mark levels | Yes | 4 |
| 6 | Cut to 3-5 names | Ranked automatically; final cut is yours | 5 |
| 7 | Write the plan: trigger, entry, stop, target, size | Drafted from levels and risk rules; you approve | 7 |
| 8 | Set alerts, then stop scanning | Yes | 7 |

## Ground rules

1. **It never places a trade.** Market data only. No order endpoints, ever.
2. **Fail closed.** Missing float, a stale quote, or a feed outage means reject
   or report `no_data`. An outage must never look like a quiet morning.
3. **Explain every drop.** Each rejected ticker is logged with the filter that
   removed it, so the screen can be audited instead of trusted.
4. **The ranking is a guess until proven.** Every list is logged against what
   the stocks did, and the weights are tuned on that record.
5. **Public repo.** No keys in git. Secrets go in `.env`.

## Phases

Progress is tracked in the [GitHub issues](../../issues), one per phase.
Screening (steps 3-6) is built first, then the market backdrop, then plans and alerts.

| Phase | What | Status |
|---|---|---|
| 0 | Foundation: repo, config, storage, validation | Code done; `.env` pending |
| 1 | Gap scan | Not started |
| 2 | Liquidity filters + rejection log | Not started |
| 3 | Catalyst lookup and classification | Not started |
| 4 | Key levels | Not started |
| 5 | Ranking, top 3-5, outcome log | Not started |
| 6 | Market backdrop + economic calendar | Not started |
| 7 | Trade plan drafts + alerts | Not started |
| 8 | Morning report, schedule, hardening | Not started |

## Layout

```
config/gauntlet.toml     thresholds and ranking weights
sql/001_schema.sql       SQLite tables (one local file, no server)
src/gauntlet/config.py   config loader with strict validation
tests/                   pytest suite
.env.example             the keys you will need, with no values
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
spread are two of the three liquidity filters. Until a consolidated (SIP) feed
is in place, treat volume as a relative ranking and not an absolute threshold.
