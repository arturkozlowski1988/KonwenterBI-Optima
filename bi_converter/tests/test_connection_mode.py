#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import tempfile
from pathlib import Path

from bi_converter.converter import ComarchBIConverter


SIMPLE_SQL = "SELECT 1 AS [One];\n"


def read_xml(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_use_default_connection_flag_default(tmp_path: Path):
    sql = tmp_path / "simple.sql"
    sql.write_text(SIMPLE_SQL, encoding="utf-8")
    conv = ComarchBIConverter()
    out = Path(conv.convert(str(sql), {
        'server': 'X', 'database': 'Y', 'connection_name': 'Z', 'mode': 'default'
    }))
    xml = read_xml(out)
    assert "<a:useDefaultConnection>true</a:useDefaultConnection>" in xml
    # default should not embed connections block with values
    assert "<a:connections/>" in xml


def test_use_default_connection_flag_embedded(tmp_path: Path):
    sql = tmp_path / "simple.sql"
    sql.write_text(SIMPLE_SQL, encoding="utf-8")
    conv = ComarchBIConverter()
    out = Path(conv.convert(str(sql), {
        'server': 'SRV', 'database': 'DB', 'connection_name': 'NAME', 'mode': 'embedded'
    }))
    xml = read_xml(out)
    assert "<a:useDefaultConnection>false</a:useDefaultConnection>" in xml
    assert "<a:connections>" in xml
    assert "<a:server>SRV</a:server>" in xml
    assert "<a:database>DB</a:database>" in xml
    assert "<a:name>NAME</a:name>" in xml
