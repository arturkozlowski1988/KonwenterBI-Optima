#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Phase 2 Testing - v2.4 UX Improvements
Tests SQL validation, XML preview, and progress bar functionality
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from bi_converter.converter import ComarchBIConverter

def test_sql_validation():
    """Test SQL validation functionality"""
    print("=" * 70)
    print("Phase 2 Testing - SQL Validation")
    print("=" * 70)
    
    converter = ComarchBIConverter()
    
    # Test 1: Valid SQL
    print("\n📝 Test 1: Valid SQL with columns and parameters")
    valid_sql = """
    DECLARE @DataOd DATE = '2024-01-01'
    DECLARE @DataDo DATE = '2024-12-31'
    
    SELECT 
        Kod AS [Kod produktu],
        Nazwa AS [Nazwa produktu],
        Ilosc AS [Ilość]
    FROM Produkty
    WHERE DataSprzedazy BETWEEN @DataOd AND @DataDo
    """
    is_valid, warnings = converter.validate_sql(valid_sql)
    print(f"  Valid: {is_valid}")
    print(f"  Warnings: {len(warnings)}")
    if warnings:
        for w in warnings:
            print(f"    - {w}")
    assert is_valid, "Valid SQL should be marked as valid"
    print("  ✅ PASSED")
    
    # Test 2: SQL without SELECT
    print("\n📝 Test 2: SQL without SELECT (critical error)")
    no_select_sql = """
    DECLARE @Test INT = 5
    SET @Test = 10
    """
    is_valid, warnings = converter.validate_sql(no_select_sql)
    print(f"  Valid: {is_valid}")
    print(f"  Warnings: {len(warnings)}")
    for w in warnings:
        print(f"    - {w}")
    assert not is_valid, "SQL without SELECT should be invalid"
    assert any('SELECT' in w for w in warnings), "Should warn about missing SELECT"
    print("  ✅ PASSED")
    
    # Test 3: SQL without column aliases
    print("\n📝 Test 3: SQL without column aliases")
    no_aliases_sql = """
    SELECT Kod, Nazwa, Ilosc
    FROM Produkty
    """
    is_valid, warnings = converter.validate_sql(no_aliases_sql)
    print(f"  Valid: {is_valid}")
    print(f"  Warnings: {len(warnings)}")
    for w in warnings:
        print(f"    - {w}")
    assert any('kolumn' in w.lower() for w in warnings), "Should warn about missing column aliases"
    print("  ✅ PASSED")
    
    # Test 4: Undeclared variables (not in known_params)
    print("\n📝 Test 4: Undeclared variables")
    undeclared_sql = """
    DECLARE @DataOd DATE = '2024-01-01'
    
    SELECT 
        Kod AS [Kod],
        Nazwa AS [Nazwa]
    FROM Produkty
    WHERE DataSprzedazy BETWEEN @DataOd AND @NiezadeklarowanaZmienna
        AND Status = @InnaZmienna
    """
    is_valid, warnings = converter.validate_sql(undeclared_sql)
    print(f"  Valid: {is_valid}")
    print(f"  Warnings: {len(warnings)}")
    for w in warnings:
        print(f"    - {w}")
    assert any('Niezadeklarowane' in w for w in warnings), "Should warn about undeclared variables"
    assert any('NIEZADEKLAROWANAZMIENNA' in w.upper() for w in warnings), "Should detect specific undeclared variable"
    print("  ✅ PASSED")
    
    # Test 5: Dangerous commands
    print("\n📝 Test 5: Dangerous commands (DROP TABLE)")
    dangerous_sql = """
    DROP TABLE TempTable
    
    SELECT 
        Kod AS [Kod]
    FROM Produkty
    """
    is_valid, warnings = converter.validate_sql(dangerous_sql)
    print(f"  Valid: {is_valid}")
    print(f"  Warnings: {len(warnings)}")
    for w in warnings:
        print(f"    - {w}")
    assert any('🚨' in w for w in warnings), "Should have critical warning for DROP"
    assert not is_valid, "SQL with DROP should be invalid"
    print("  ✅ PASSED")
    
    # Test 6: DELETE without WHERE
    print("\n📝 Test 6: DELETE without WHERE (dangerous)")
    delete_sql = """
    DELETE FROM TempTable
    
    SELECT 
        Kod AS [Kod]
    FROM Produkty
    """
    is_valid, warnings = converter.validate_sql(delete_sql)
    print(f"  Valid: {is_valid}")
    print(f"  Warnings: {len(warnings)}")
    for w in warnings:
        print(f"    - {w}")
    assert any('DELETE' in w for w in warnings), "Should warn about DELETE without WHERE"
    print("  ✅ PASSED")
    
    print("\n✅ All SQL validation tests PASSED")

def test_xml_preview():
    """Test XML report preview/summary functionality"""
    print("\n" + "=" * 70)
    print("Phase 2 Testing - XML Preview")
    print("=" * 70)
    
    # Test with test_simple.xml
    print("\n📝 Test 1: Small XML file (test_simple.xml)")
    xml_file = Path(__file__).parent / 'test_simple.xml'
    if not xml_file.exists():
        print(f"  ⚠️  File not found: {xml_file}")
    else:
        converter = ComarchBIConverter()
        summary = converter.get_xml_report_summary(str(xml_file))
        
        print(f"  Reports found: {len(summary)}")
        assert len(summary) == 1, "test_simple.xml should contain 1 report"
        
        report = summary[0]
        print(f"  Report 1:")
        print(f"    - Index: {report['index']}")
        print(f"    - Name: {report['name']}")
        print(f"    - Lines: {report['sql_lines']}")
        print(f"    - Size: {report['sql_size_kb']} KB")
        
        assert report['index'] == 1, "First report should have index 1"
        assert report['sql_lines'] > 0, "Report should have SQL content"
        assert report['sql_size_kb'] > 0, "Report should have size"
        print("  ✅ PASSED")
    
    # Test with large XML file
    print("\n📝 Test 2: Large XML file (raporty magazyny.xml)")
    xml_large = Path(__file__).parent / 'raporty magazyny.xml'
    if not xml_large.exists():
        print(f"  ⚠️  File not found: {xml_large}")
    else:
        converter = ComarchBIConverter()
        summary = converter.get_xml_report_summary(str(xml_large))
        
        print(f"  Reports found: {len(summary)}")
        assert len(summary) == 42, "raporty magazyny.xml should contain 42 reports"
        
        total_lines = sum(r['sql_lines'] for r in summary)
        total_size = sum(r['sql_size_kb'] for r in summary)
        
        print(f"  Total statistics:")
        print(f"    - Total lines: {total_lines:,}")
        print(f"    - Total size: {total_size:.2f} KB")
        print(f"    - Average lines per report: {total_lines // len(summary):,}")
        print(f"    - Average size per report: {total_size / len(summary):.2f} KB")
        
        # Verify structure
        for i, report in enumerate(summary[:3], 1):
            print(f"  Report {i}: {report['name']} ({report['sql_lines']} lines, {report['sql_size_kb']} KB)")
        
        assert all('index' in r for r in summary), "All reports should have index"
        assert all('name' in r for r in summary), "All reports should have name"
        assert all('sql_lines' in r for r in summary), "All reports should have line count"
        assert all('sql_size_kb' in r for r in summary), "All reports should have size"
        print("  ✅ PASSED")
    
    print("\n✅ All XML preview tests PASSED")

def test_validation_integration():
    """Test validation integration with existing functionality"""
    print("\n" + "=" * 70)
    print("Phase 2 Testing - Integration Tests")
    print("=" * 70)
    
    # Test with real SQL file
    print("\n📝 Test 1: Validate test_simple.sql")
    test_sql = Path(__file__).parent / 'test_simple.sql'
    if not test_sql.exists():
        print(f"  ⚠️  File not found: {test_sql}")
    else:
        converter = ComarchBIConverter()
        sql_text = test_sql.read_text(encoding='utf-8-sig')
        
        is_valid, warnings = converter.validate_sql(sql_text)
        print(f"  Valid: {is_valid}")
        print(f"  Warnings: {len(warnings)}")
        for w in warnings:
            print(f"    - {w}")
        
        # File should be valid (used in existing tests)
        assert is_valid, "test_simple.sql should be valid"
        print("  ✅ PASSED")
    
    # Test validation doesn't break conversion
    print("\n📝 Test 2: Validation + Conversion roundtrip")
    if test_sql.exists():
        converter = ComarchBIConverter()
        sql_text = test_sql.read_text(encoding='utf-8-sig')
        
        # Validate first
        is_valid, warnings = converter.validate_sql(sql_text)
        print(f"  Validation: {'✅ Valid' if is_valid else '❌ Invalid'}")
        
        # Then convert (should still work)
        try:
            xml_output = converter.convert(str(test_sql), {
                'server': 'TEST',
                'database': 'TEST_DB',
                'connection_name': 'TEST',
                'mode': 'auto'
            })
            print(f"  Conversion: ✅ Success")
            print(f"  Output: {xml_output}")
            
            # Verify output exists
            output_path = Path(xml_output)
            assert output_path.exists(), "Output XML file should exist"
            assert output_path.stat().st_size > 0, "Output file should not be empty"
            print("  ✅ PASSED")
        except Exception as e:
            print(f"  ❌ Conversion failed: {e}")
            raise
    
    print("\n✅ All integration tests PASSED")

def test_performance_impact():
    """Verify Phase 2 doesn't degrade Phase 1 performance"""
    print("\n" + "=" * 70)
    print("Phase 2 Testing - Performance Regression Check")
    print("=" * 70)
    
    import time
    
    xml_file = Path(__file__).parent / 'raporty magazyny.xml'
    if not xml_file.exists():
        print(f"  ⚠️  File not found: {xml_file}")
        return
    
    converter = ComarchBIConverter()
    
    # Test extraction performance (should still be fast)
    print("\n📝 Extraction performance (3 runs):")
    times = []
    for i in range(3):
        start = time.perf_counter()
        reports = converter.extract_sql_reports(str(xml_file))
        elapsed = time.perf_counter() - start
        times.append(elapsed)
        print(f"  Run {i+1}: {elapsed:.4f}s ({len(reports)} reports)")
    
    avg_time = sum(times) / len(times)
    print(f"  Average: {avg_time:.4f}s")
    
    # Should still be under 0.05s (50ms)
    assert avg_time < 0.05, f"Performance regression detected: {avg_time:.4f}s > 0.05s"
    print("  ✅ Performance maintained")
    
    # Test preview performance
    print("\n📝 Preview summary performance (3 runs):")
    times = []
    for i in range(3):
        start = time.perf_counter()
        summary = converter.get_xml_report_summary(str(xml_file))
        elapsed = time.perf_counter() - start
        times.append(elapsed)
        print(f"  Run {i+1}: {elapsed:.4f}s ({len(summary)} reports)")
    
    avg_time = sum(times) / len(times)
    print(f"  Average: {avg_time:.4f}s")
    
    # Preview should be even faster (no full SQL content)
    assert avg_time < 0.05, f"Preview too slow: {avg_time:.4f}s > 0.05s"
    print("  ✅ Preview is fast")
    
    print("\n✅ No performance regression detected")

if __name__ == '__main__':
    try:
        test_sql_validation()
        test_xml_preview()
        test_validation_integration()
        test_performance_impact()
        
        print("\n" + "=" * 70)
        print("🎉 Phase 2 Testing Complete!")
        print("=" * 70)
        print("\n✅ SQL validation: Working")
        print("✅ XML preview: Working")
        print("✅ Integration: Working")
        print("✅ Performance: Maintained")
        print("✅ All tests PASSED")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
