#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
from pathlib import Path
from typing import Dict, Optional


DEFAULTS: Dict[str, str] = {
    "server": "SERWEROPTIMA\\SUL02",
    "database": "CDN_Ulex_2018_temp",
    "connection_name": "Ulex_2018_temp",
    "mode": "auto",
    "last_sql_path": "",
    "debug": "false",
}


def _settings_dir() -> Path:
    # Allow tests to isolate writes via env var
    env_dir = os.environ.get("BI_CONVERTER_SETTINGS_DIR")
    if env_dir:
        p = Path(env_dir)
        p.mkdir(parents=True, exist_ok=True)
        return p
    # Default: next to config.json (package dir)
    return Path(__file__).parent


def _settings_path() -> Path:
    return _settings_dir() / "settings.json"


def load_settings(logger: Optional[object] = None) -> Dict[str, str]:
    path = _settings_path()
    try:
        if path.exists():
            data = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                return DEFAULTS.copy()
            # Merge with defaults to fill missing keys
            merged = DEFAULTS.copy()
            merged.update({k: v for k, v in data.items() if isinstance(v, str)})
            return merged
    except Exception as e:
        if logger:
            try:
                logger.warning(f"Failed to load settings: {e}")
            except Exception:
                pass
    return DEFAULTS.copy()


def save_settings(data: Dict[str, str], logger: Optional[object] = None) -> None:
    # Keep only known keys and coerce to str for simplicity
    to_save = {k: str(data.get(k, DEFAULTS[k])) for k in DEFAULTS.keys()}
    path = _settings_path()
    try:
        path.write_text(json.dumps(to_save, ensure_ascii=False, indent=2), encoding="utf-8")
        if logger:
            try:
                logger.info(f"Saved settings: {path}")
            except Exception:
                pass
    except Exception as e:
        if logger:
            try:
                logger.error(f"Failed to save settings: {e}")
            except Exception:
                pass
