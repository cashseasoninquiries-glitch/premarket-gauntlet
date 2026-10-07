"""Load and validate config/gauntlet.toml.

Validation is strict on purpose: a typo in a threshold should stop the run,
not silently loosen a filter.
"""

from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path

DEFAULT_PATH = Path(__file__).resolve().parents[2] / "config" / "gauntlet.toml"
MISSING_POLICIES = {"reject", "pass"}
WEIGHT_KEYS = {
    "gap_size",
    "relative_volume",
    "catalyst_quality",
    "liquidity",
    "room_to_level",
}


class ConfigError(ValueError):
    """Raised when the config file is missing a value or holds a bad one."""


@dataclass(frozen=True)
class Filters:
    min_price: float
    max_spread_pct: float
    min_premarket_volume: int
    min_relative_volume: float
    min_float_shares: int
    on_missing_float: str
    on_missing_quote: str
    max_quote_age_seconds: int


@dataclass(frozen=True)
class Config:
    timezone: str
    run_times: tuple[str, ...]
    min_abs_gap_pct: float
    filters: Filters
    catalyst_lookback_hours: int
    require_catalyst: bool
    top_n: int
    weights: dict[str, float]


def _positive(name: str, value: float) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0:
        raise ConfigError(f"{name} must be a positive number, got {value!r}")


def load(path: Path | str = DEFAULT_PATH) -> Config:
    path = Path(path)
    if not path.is_file():
        raise ConfigError(f"config file not found: {path}")
    with path.open("rb") as fh:
        raw = tomllib.load(fh)

    try:
        f = raw["filters"]
        filters = Filters(
            min_price=f["min_price"],
            max_spread_pct=f["max_spread_pct"],
            min_premarket_volume=f["min_premarket_volume"],
            min_relative_volume=f["min_relative_volume"],
            min_float_shares=f["min_float_shares"],
            on_missing_float=f["on_missing_float"],
            on_missing_quote=f["on_missing_quote"],
            max_quote_age_seconds=f["max_quote_age_seconds"],
        )
        cfg = Config(
            timezone=raw["schedule"]["timezone"],
            run_times=tuple(raw["schedule"]["run_times"]),
            min_abs_gap_pct=raw["gap"]["min_abs_pct"],
            filters=filters,
            catalyst_lookback_hours=raw["catalyst"]["lookback_hours"],
            require_catalyst=raw["catalyst"]["require_catalyst"],
            top_n=raw["ranking"]["top_n"],
            weights=dict(raw["ranking"]["weights"]),
        )
    except KeyError as exc:
        raise ConfigError(f"missing config key: {exc}") from exc

    _validate(cfg)
    return cfg


def _validate(cfg: Config) -> None:
    f = cfg.filters
    _positive("gap.min_abs_pct", cfg.min_abs_gap_pct)
    _positive("filters.min_price", f.min_price)
    _positive("filters.max_spread_pct", f.max_spread_pct)
    _positive("filters.min_premarket_volume", f.min_premarket_volume)
    _positive("filters.min_relative_volume", f.min_relative_volume)
    _positive("filters.min_float_shares", f.min_float_shares)
    _positive("filters.max_quote_age_seconds", f.max_quote_age_seconds)
    _positive("catalyst.lookback_hours", cfg.catalyst_lookback_hours)
    _positive("ranking.top_n", cfg.top_n)

    for name, policy in (
        ("on_missing_float", f.on_missing_float),
        ("on_missing_quote", f.on_missing_quote),
    ):
        if policy not in MISSING_POLICIES:
            raise ConfigError(f"filters.{name} must be 'reject' or 'pass', got {policy!r}")

    if not cfg.run_times:
        raise ConfigError("schedule.run_times must list at least one time")

    if set(cfg.weights) != WEIGHT_KEYS:
        raise ConfigError(
            f"ranking.weights must have exactly {sorted(WEIGHT_KEYS)}, got {sorted(cfg.weights)}"
        )
    for key, value in cfg.weights.items():
        if not isinstance(value, (int, float)) or isinstance(value, bool) or value < 0:
            raise ConfigError(f"ranking.weights.{key} must be >= 0, got {value!r}")
    total = sum(cfg.weights.values())
    if abs(total - 1.0) > 1e-6:
        raise ConfigError(f"ranking.weights must sum to 1.0, got {total:.4f}")
