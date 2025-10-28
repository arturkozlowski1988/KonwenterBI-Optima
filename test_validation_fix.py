#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test walidacji SQL po naprawie błędów.
Weryfikuje:
1. Poprawne rozpoznawanie znanych parametrów BI (@DATAOD, @DATADO)
2. Ignorowanie DROP TABLE dla tabel tymczasowych (#tmp)
3. Poprawne działanie na prawdziwych plikach SQL z repozytorium
"""

import sys
from pathlib import Path
from bi_converter.converter import ComarchBIConverter
from bi_converter.logging_conf import get_logger

def test_known_params_initialization():
    """Test 1: Czy known_params są poprawnie inicjalizowane?"""
    print("=" * 60)
    print("Test 1: Inicjalizacja known_params")
    print("=" * 60)
    
    conv = ComarchBIConverter(logger=get_logger())
    
    # Sprawdź, czy mamy domyślne parametry
    expected_params = {'DATAOD', 'DATADO', 'DATAPOCZATEKROKU', 'DATAKONIECROKU', 
                       'DATADOANALIZY', 'DATAODANALIZY', 'DATRYBUTWR', 'ZTROWE',
                       'MAGAZYN', 'KONTRAHENT', 'DOKUMENT'}
    
    print(f"Oczekiwane parametry: {sorted(expected_params)}")
    print(f"Znalezione parametry: {sorted(conv.known_params)}")
    
    if expected_params.issubset(conv.known_params):
        print("✅ Known params poprawnie zainicjalizowane")
        return True
    else:
        missing = expected_params - conv.known_params
        print(f"❌ Brakujące parametry: {missing}")
        return False

def test_temp_table_drop():
    """Test 2: Czy DROP TABLE #tmp nie jest oznaczany jako niebezpieczny?"""
    print("\n" + "=" * 60)
    print("Test 2: DROP TABLE dla tabel tymczasowych")
    print("=" * 60)
    
    conv = ComarchBIConverter(logger=get_logger())
    
    # SQL z DROP TABLE #tmp (prawidłowy)
    sql_with_temp_drop = """
    SELECT TOP 10 * INTO #tmpData FROM CDN.Towary
    
    -- Cleanup
    DROP TABLE #tmpData
    DROP TABLE #tmpGrupy
    """
    
    is_valid, warnings = conv.validate_sql(sql_with_temp_drop)
    
    print(f"SQL z DROP TABLE #tmp:")
    print(f"  Czy poprawny: {is_valid}")
    print(f"  Ostrzeżenia: {warnings}")
    
    # Nie powinno być ostrzeżenia o DROP
    has_drop_warning = any('DROP' in w for w in warnings)
    
    if not has_drop_warning:
        print("✅ DROP TABLE #tmp poprawnie ignorowany")
        return True
    else:
        print("❌ DROP TABLE #tmp błędnie oznaczony jako niebezpieczny")
        return False

def test_permanent_table_drop():
    """Test 3: Czy DROP TABLE dla stałych tabel jest wykrywany?"""
    print("\n" + "=" * 60)
    print("Test 3: DROP TABLE dla stałych tabel")
    print("=" * 60)
    
    conv = ComarchBIConverter(logger=get_logger())
    
    # SQL z DROP TABLE bez # (niebezpieczny)
    sql_with_perm_drop = """
    SELECT TOP 10 * FROM CDN.Towary
    
    -- DANGER!
    DROP TABLE Towary
    """
    
    is_valid, warnings = conv.validate_sql(sql_with_perm_drop)
    
    print(f"SQL z DROP TABLE Towary:")
    print(f"  Czy poprawny: {is_valid}")
    print(f"  Ostrzeżenia: {warnings}")
    
    # Powinno być ostrzeżenie o DROP i is_valid = False
    has_drop_warning = any('DROP' in w and '🚨' in w for w in warnings)
    
    if has_drop_warning and not is_valid:
        print("✅ DROP TABLE Towary poprawnie wykryty jako niebezpieczny")
        return True
    else:
        print("❌ DROP TABLE Towary nie został wykryty")
        return False

def test_real_sql_file():
    """Test 4: Czy report_10.sql przechodzi walidację?"""
    print("\n" + "=" * 60)
    print("Test 4: Walidacja prawdziwego pliku SQL (report_10.sql)")
    print("=" * 60)
    
    conv = ComarchBIConverter(logger=get_logger())
    
    sql_path = Path("report_10.sql")
    if not sql_path.exists():
        print(f"⚠️ Plik {sql_path} nie istnieje - pomijam test")
        return None
    
    with open(sql_path, 'r', encoding='utf-8') as f:
        sql_content = f.read()
    
    is_valid, warnings = conv.validate_sql(sql_content)
    
    print(f"Plik: {sql_path}")
    print(f"  Rozmiar: {len(sql_content)} znaków")
    print(f"  Czy poprawny: {is_valid}")
    print(f"  Liczba ostrzeżeń: {len(warnings)}")
    
    if warnings:
        print("  Ostrzeżenia:")
        for w in warnings:
            print(f"    - {w}")
    
    # report_10.sql powinien być poprawny (is_valid=True)
    # Może mieć ostrzeżenia non-critical, ale nie critical
    has_critical = any('🚨' in w for w in warnings)
    
    if is_valid and not has_critical:
        print("✅ report_10.sql przechodzi walidację")
        return True
    else:
        print("❌ report_10.sql ma błędy krytyczne lub jest niepoprawny")
        return False

def test_bi_params_not_flagged():
    """Test 5: Czy parametry BI nie są oznaczane jako niezadeklarowane?"""
    print("\n" + "=" * 60)
    print("Test 5: Parametry BI w zapytaniu")
    print("=" * 60)
    
    conv = ComarchBIConverter(logger=get_logger())
    
    # SQL używający parametrów BI (bez DECLARE)
    sql_with_bi_params = """
    SELECT 
        Twr_Kod AS [Kod],
        Twr_Nazwa AS [Nazwa],
        TrE_DataOpe AS [Data]
    FROM CDN.Towary T
    JOIN CDN.TraElem TE ON T.Twr_TwrId = TE.TrE_TwrId
    WHERE TrE_DataOpe BETWEEN @DATAOD AND @DATADO
        AND Twr_Magazyn = @MAGAZYN
    """
    
    is_valid, warnings = conv.validate_sql(sql_with_bi_params)
    
    print(f"SQL z parametrami BI (@DATAOD, @DATADO, @MAGAZYN):")
    print(f"  Czy poprawny: {is_valid}")
    print(f"  Ostrzeżenia: {warnings}")
    
    # Nie powinno być ostrzeżenia o niezadeklarowanych zmiennych dla znanych parametrów
    has_undeclared_warning = any('Niezadeklarowane zmienne' in w for w in warnings)
    
    if not has_undeclared_warning:
        print("✅ Parametry BI nie są błędnie oznaczane jako niezadeklarowane")
        return True
    else:
        print("❌ Parametry BI są błędnie oznaczane jako niezadeklarowane")
        print(f"    Ostrzeżenia: {warnings}")
        return False

def test_actual_undeclared_vars():
    """Test 6: Czy prawdziwe niezadeklarowane zmienne są wykrywane?"""
    print("\n" + "=" * 60)
    print("Test 6: Prawdziwe niezadeklarowane zmienne")
    print("=" * 60)
    
    conv = ComarchBIConverter(logger=get_logger())
    
    # SQL z prawdziwie niezadeklarowaną zmienną
    sql_with_undeclared = """
    SELECT 
        Twr_Kod AS [Kod],
        Twr_Nazwa AS [Nazwa]
    FROM CDN.Towary
    WHERE Twr_Kategoria = @NIEZNANA_ZMIENNA
        AND Twr_Status = @INNA_NIEZNANA
    """
    
    is_valid, warnings = conv.validate_sql(sql_with_undeclared)
    
    print(f"SQL z @NIEZNANA_ZMIENNA, @INNA_NIEZNANA:")
    print(f"  Czy poprawny: {is_valid}")
    print(f"  Ostrzeżenia: {warnings}")
    
    # Powinno być ostrzeżenie o niezadeklarowanych zmiennych
    has_undeclared_warning = any('Niezadeklarowane zmienne' in w for w in warnings)
    has_correct_vars = any('NIEZNANA_ZMIENNA' in w and 'INNA_NIEZNANA' in w for w in warnings)
    
    if has_undeclared_warning and has_correct_vars:
        print("✅ Prawdziwe niezadeklarowane zmienne poprawnie wykryte")
        return True
    else:
        print("❌ Niezadeklarowane zmienne nie zostały wykryte")
        return False

def main():
    """Uruchom wszystkie testy walidacji"""
    print("\n" + "=" * 70)
    print(" TEST NAPRAWY WALIDACJI SQL ".center(70, "="))
    print("=" * 70)
    
    tests = [
        ("Inicjalizacja known_params", test_known_params_initialization),
        ("DROP TABLE #tmp (dozwolony)", test_temp_table_drop),
        ("DROP TABLE stałe (zabroniony)", test_permanent_table_drop),
        ("Prawdziwy plik SQL", test_real_sql_file),
        ("Parametry BI (dozwolone)", test_bi_params_not_flagged),
        ("Niezadeklarowane zmienne (wykrywane)", test_actual_undeclared_vars),
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
        print("\n🎉 WSZYSTKIE TESTY ZALICZONE!")
        return 0
    else:
        print(f"\n⚠️ {failed} testów nie przeszło")
        return 1

if __name__ == '__main__':
    sys.exit(main())
