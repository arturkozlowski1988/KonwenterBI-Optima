#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from pathlib import Path

from bi_converter.settings import load_settings, save_settings, DEFAULTS


def test_settings_round_trip(tmp_path: Path, monkeypatch):
    # Redirect settings location to temporary folder
    monkeypatch.setenv("BI_CONVERTER_SETTINGS_DIR", str(tmp_path))

    # Initially defaults
    st = load_settings()
    assert st["server"] == DEFAULTS["server"]

    # Save modified values
    updated = st.copy()
    updated.update({
        'server': 'TESTSRV',
        'database': 'TESTDB',
        'connection_name': 'TESTCONN',
        'mode': 'embedded',
        'last_sql_path': str(tmp_path / 'file.sql'),
    })
    save_settings(updated)

    # Load again and verify
    st2 = load_settings()
    assert st2['server'] == 'TESTSRV'
    assert st2['database'] == 'TESTDB'
    assert st2['connection_name'] == 'TESTCONN'
    assert st2['mode'] == 'embedded'
    assert st2['last_sql_path'].endswith('file.sql')
