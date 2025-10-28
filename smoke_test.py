#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Quick smoke test for v2.2"""

from bi_converter.converter import ComarchBIConverter

print("🔍 Testing v2.2 functionality...")

# Test 1: Import
try:
    c = ComarchBIConverter()
    print("✅ Import OK")
except Exception as e:
    print(f"❌ Import failed: {e}")
    exit(1)

# Test 2: Extract from XML
try:
    reports = c.extract_sql_reports('test_simple.xml')
    print(f"✅ Extracted {len(reports)} reports")
    assert len(reports) == 1, "Expected 1 report"
except Exception as e:
    print(f"❌ Extraction failed: {e}")
    exit(1)

# Test 3: Check report content
try:
    assert reports[0]['name'] == '', "Expected empty name"
    assert 'SELECT 1' in reports[0]['sql'], "Expected SELECT 1 in SQL"
    print("✅ Report content OK")
except Exception as e:
    print(f"❌ Content check failed: {e}")
    exit(1)

# Test 4: Write to files
try:
    import tempfile
    with tempfile.TemporaryDirectory() as tmpdir:
        outputs = c.write_sql_reports('test_simple.xml', tmpdir)
        assert len(outputs) == 1, "Expected 1 output file"
        print(f"✅ Write OK: {outputs[0].name}")
except Exception as e:
    print(f"❌ Write failed: {e}")
    exit(1)

print("\n🎉 All tests passed! v2.2 is working correctly.")
