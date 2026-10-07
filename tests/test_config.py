import pytest

from gauntlet.config import DEFAULT_PATH, ConfigError, load


def _write(tmp_path, text):
    path = tmp_path / "gauntlet.toml"
    path.write_text(text, encoding="utf-8")
    return path


def test_shipped_config_loads():
    cfg = load()
    assert cfg.min_abs_gap_pct == 3.0
    assert cfg.filters.on_missing_float == "reject"
    assert abs(sum(cfg.weights.values()) - 1.0) < 1e-6


def test_missing_file(tmp_path):
    with pytest.raises(ConfigError, match="not found"):
        load(tmp_path / "nope.toml")


def test_weights_must_sum_to_one(tmp_path):
    text = DEFAULT_PATH.read_text(encoding="utf-8").replace(
        "gap_size = 0.15", "gap_size = 0.50"
    )
    with pytest.raises(ConfigError, match="sum to 1.0"):
        load(_write(tmp_path, text))


def test_bad_missing_policy(tmp_path):
    text = DEFAULT_PATH.read_text(encoding="utf-8").replace(
        'on_missing_float = "reject"', 'on_missing_float = "ignore"'
    )
    with pytest.raises(ConfigError, match="on_missing_float"):
        load(_write(tmp_path, text))


def test_negative_threshold(tmp_path):
    text = DEFAULT_PATH.read_text(encoding="utf-8").replace(
        "min_price = 5.0", "min_price = -5.0"
    )
    with pytest.raises(ConfigError, match="min_price"):
        load(_write(tmp_path, text))


def test_missing_key(tmp_path):
    text = DEFAULT_PATH.read_text(encoding="utf-8").replace("top_n = 5", "")
    with pytest.raises(ConfigError, match="missing config key"):
        load(_write(tmp_path, text))
