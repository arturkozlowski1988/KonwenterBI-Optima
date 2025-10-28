#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test konwersji wielu plików SQL do jednego XML.
Weryfikuje nową funkcjonalność batch conversion.
"""

import sys
import tempfile
from pathlib import Path
from bi_converter.converter import ComarchBIConverter
from bi_converter.logging_conf import get_logger

def test_convert_multiple_files():
    """Test 1: Konwersja wielu plików SQL do jednego XML"""
    print("=" * 70)
    print("Test 1: Konwersja wielu plików SQL do jednego XML")
    print("=" * 70)
    
    logger = get_logger()
    conv = ComarchBIConverter(logger=logger)
    
    # Używamy istniejących plików testowych
    sql_files = [
        "report_01.sql",
        "report_02.sql",
        "report_03.sql"
    ]
    
    # Sprawdź, czy wszystkie pliki istnieją
    for sql_file in sql_files:
        if not Path(sql_file).exists():
            print(f"⚠️ Plik {sql_file} nie istnieje - pomijam test")
            return None
    
    conn_config = {
        'server': 'TESTSERVER',
        'database': 'TESTDB',
        'connection_name': 'TestConn',
        'mode': 'default'
    }
    
    # Tymczasowy plik wyjściowy
    with tempfile.NamedTemporaryFile(mode='w', suffix='.xml', delete=False) as f:
        output_xml = f.name
    
    try:
        # Konwersja wielu plików
        result = conv.convert_multiple(sql_files, conn_config, output_xml_path=output_xml)
        
        print(f"✅ Konwersja zakończona")
        print(f"   Plik wyjściowy: {result}")
        
        # Sprawdź, czy plik został utworzony
        output_path = Path(result)
        if not output_path.exists():
            print(f"❌ Plik wyjściowy nie istnieje: {result}")
            return False
        
        # Sprawdź rozmiar pliku
        file_size = output_path.stat().st_size
        print(f"   Rozmiar pliku: {file_size:,} bajtów")
        
        if file_size < 1000:
            print(f"❌ Plik wyjściowy jest za mały: {file_size} bajtów")
            return False
        
        # Sprawdź zawartość
        content = output_path.read_text(encoding='utf-8')
        
        # Powinien zawierać nagłówek ReportsList
        if '<ReportsList' not in content:
            print("❌ Brak nagłówka ReportsList w XML")
            return False
        
        # Policzy wystąpienia <a:Report
        report_count = content.count('<a:Report i:type="a:MdxSqlDevXpressReport">')
        print(f"   Liczba raportów w XML: {report_count}")
        
        if report_count != len(sql_files):
            print(f"❌ Oczekiwano {len(sql_files)} raportów, znaleziono {report_count}")
            return False
        
        # Sprawdź, czy każdy raport ma wypełnione mainLinkName (nazwę raportu)
        mainlink_count = content.count('<a:mainLinkName>')
        if mainlink_count != len(sql_files):
            print(f"❌ Oczekiwano {len(sql_files)} tagów <a:mainLinkName>, znaleziono {mainlink_count}")
            return False
        
        # Sprawdź, czy nie ma pustych nazw raportów
        if '<a:mainLinkName></a:mainLinkName>' in content:
            print("❌ Znaleziono puste tagi <a:mainLinkName>")
            return False
        
        print(f"✅ Test zaliczony: {len(sql_files)} raportów w jednym XML")
        return True
        
    finally:
        # Sprzątanie
        try:
            Path(output_xml).unlink(missing_ok=True)
        except:
            pass

def test_convert_single_vs_multiple():
    """Test 2: Porównanie convert() vs convert_multiple() dla jednego pliku"""
    print("\n" + "=" * 70)
    print("Test 2: Porównanie convert() vs convert_multiple() dla jednego pliku")
    print("=" * 70)
    
    logger = get_logger()
    conv = ComarchBIConverter(logger=logger)
    
    sql_file = "report_01.sql"
    
    if not Path(sql_file).exists():
        print(f"⚠️ Plik {sql_file} nie istnieje - pomijam test")
        return None
    
    conn_config = {
        'server': 'TESTSERVER',
        'database': 'TESTDB',
        'connection_name': 'TestConn',
        'mode': 'default'
    }
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='_single.xml', delete=False) as f:
        output_single = f.name
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='_multi.xml', delete=False) as f:
        output_multi = f.name
    
    try:
        # Konwersja przez convert()
        conv.convert(sql_file, conn_config)
        single_path = Path(sql_file).with_suffix('.xml')
        single_content = single_path.read_text(encoding='utf-8')
        single_size = len(single_content)
        
        # Konwersja przez convert_multiple()
        conv.convert_multiple([sql_file], conn_config, output_xml_path=output_multi)
        multi_content = Path(output_multi).read_text(encoding='utf-8')
        multi_size = len(multi_content)
        
        print(f"   Rozmiar convert():          {single_size:,} bajtów")
        print(f"   Rozmiar convert_multiple(): {multi_size:,} bajtów")
        
        # Oba powinny być podobnej wielkości
        size_diff_pct = abs(single_size - multi_size) / single_size * 100
        print(f"   Różnica: {size_diff_pct:.1f}%")
        
        if size_diff_pct > 10:
            print(f"❌ Zbyt duża różnica w rozmiarach: {size_diff_pct:.1f}%")
            return False
        
        # Oba powinny mieć 1 raport
        single_reports = single_content.count('<a:Report i:type="a:MdxSqlDevXpressReport">')
        multi_reports = multi_content.count('<a:Report i:type="a:MdxSqlDevXpressReport">')
        
        print(f"   Raporty convert():          {single_reports}")
        print(f"   Raporty convert_multiple(): {multi_reports}")
        
        if single_reports != 1 or multi_reports != 1:
            print(f"❌ Oba powinny mieć 1 raport")
            return False
        
        print("✅ Test zaliczony: Obie metody generują spójne XML dla jednego pliku")
        return True
        
    finally:
        # Sprzątanie
        try:
            Path(output_single).unlink(missing_ok=True)
            Path(output_multi).unlink(missing_ok=True)
            Path(sql_file).with_suffix('.xml').unlink(missing_ok=True)
        except:
            pass

def test_empty_file_list():
    """Test 3: Obsługa pustej listy plików"""
    print("\n" + "=" * 70)
    print("Test 3: Obsługa pustej listy plików")
    print("=" * 70)
    
    logger = get_logger()
    conv = ComarchBIConverter(logger=logger)
    
    conn_config = {
        'server': 'TESTSERVER',
        'database': 'TESTDB',
        'connection_name': 'TestConn',
        'mode': 'default'
    }
    
    try:
        result = conv.convert_multiple([], conn_config)
        print(f"❌ Powinien zgłosić błąd dla pustej listy, ale zwrócił: {result}")
        return False
    except Exception as e:
        if "No SQL files provided" in str(e):
            print(f"✅ Poprawnie zgłoszono błąd: {e}")
            return True
        else:
            print(f"❌ Niepoprawny błąd: {e}")
            return False

def test_nonexistent_file():
    """Test 4: Obsługa nieistniejącego pliku"""
    print("\n" + "=" * 70)
    print("Test 4: Obsługa nieistniejącego pliku w batch")
    print("=" * 70)
    
    logger = get_logger()
    conv = ComarchBIConverter(logger=logger)
    
    sql_files = [
        "report_01.sql",  # Istnieje
        "nonexistent_file_12345.sql",  # Nie istnieje
        "report_02.sql"  # Istnieje
    ]
    
    conn_config = {
        'server': 'TESTSERVER',
        'database': 'TESTDB',
        'connection_name': 'TestConn',
        'mode': 'default'
    }
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='.xml', delete=False) as f:
        output_xml = f.name
    
    try:
        # Powinien pominąć nieistniejący plik
        result = conv.convert_multiple(sql_files, conn_config, output_xml_path=output_xml)
        
        content = Path(result).read_text(encoding='utf-8')
        report_count = content.count('<a:Report i:type="a:MdxSqlDevXpressReport">')
        
        print(f"   Liczba raportów w XML: {report_count}")
        
        # Powinno być 2 raporty (pominięto nieistniejący)
        if report_count == 2:
            print("✅ Test zaliczony: Nieistniejący plik został pominięty")
            return True
        else:
            print(f"❌ Oczekiwano 2 raportów, znaleziono {report_count}")
            return False
        
    finally:
        try:
            Path(output_xml).unlink(missing_ok=True)
        except:
            pass

def main():
    """Uruchom wszystkie testy batch conversion"""
    print("\n" + "=" * 70)
    print(" TEST KONWERSJI WIELOPLIKOWEJ (BATCH CONVERSION) ".center(70, "="))
    print("=" * 70)
    
    tests = [
        ("Konwersja wielu plików", test_convert_multiple_files),
        ("Porównanie convert() vs convert_multiple()", test_convert_single_vs_multiple),
        ("Pusta lista plików", test_empty_file_list),
        ("Nieistniejący plik w batch", test_nonexistent_file),
    ]
    
    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print(f"\n❌ Test '{name}' wywołał wyjątek: {e}")
            import traceback
            traceback.print_exc()
            results.append((name, False))
    
    # Podsumowanie
    print("\n" + "=" * 70)
    print(" PODSUMOWANIE ".center(70, "="))
    print("=" * 70)
    
    passed = sum(1 for _, r in results if r is True)
    failed = sum(1 for _, r in results if r is False)
    skipped = sum(1 for _, r in results if r is None)
    total = len(results)
    
    for name, result in results:
        if result is True:
            print(f"✅ {name}")
        elif result is False:
            print(f"❌ {name}")
        else:
            print(f"⚠️ {name} (pominięty)")
    
    print("\n" + "=" * 70)
    print(f"Zaliczone: {passed}/{total - skipped}")
    print(f"Niezaliczone: {failed}/{total - skipped}")
    if skipped > 0:
        print(f"Pominięte: {skipped}/{total}")
    print("=" * 70)
    
    if failed == 0 and passed > 0:
        print("\n🎉 WSZYSTKIE TESTY BATCH CONVERSION ZALICZONE!")
        return 0
    else:
        print(f"\n⚠️ {failed} testów nie przeszło")
        return 1

if __name__ == '__main__':
    sys.exit(main())
