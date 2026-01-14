#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Kompleksowy test wszystkich funkcji programu KonwenterBI-Optima.
Testuje wszystkie dostępne pliki XML oraz funkcjonalności konwersji.
"""

import sys
import tempfile
import time
from pathlib import Path
from bi_converter.converter import ComarchBIConverter, ConversionError
from bi_converter.logging_conf import get_logger


class TestResults:
    """Klasa do zbierania wyników testów"""
    def __init__(self):
        self.tests = []
        self.passed = 0
        self.failed = 0
        self.skipped = 0
    
    def add_test(self, name, result, details=""):
        """Dodaj wynik testu: True (pass), False (fail), None (skip)"""
        self.tests.append((name, result, details))
        if result is True:
            self.passed += 1
        elif result is False:
            self.failed += 1
        else:
            self.skipped += 1
    
    def print_summary(self):
        """Wyświetl podsumowanie"""
        print("\n" + "=" * 80)
        print(" PODSUMOWANIE TESTÓW ".center(80, "="))
        print("=" * 80)
        
        for name, result, details in self.tests:
            if result is True:
                status = "✅"
            elif result is False:
                status = "❌"
            else:
                status = "⚠️"
            
            print(f"{status} {name}")
            if details:
                print(f"   {details}")
        
        print("\n" + "=" * 80)
        total = len(self.tests)
        total_run = self.passed + self.failed
        print(f"Zaliczone:    {self.passed}/{total_run}")
        print(f"Niezaliczone: {self.failed}/{total_run}")
        if self.skipped > 0:
            print(f"Pominięte:    {self.skipped}/{total}")
        print("=" * 80)
        
        if self.failed == 0 and self.passed > 0:
            print("\n🎉 WSZYSTKIE TESTY ZALICZONE!")
            return 0
        else:
            print(f"\n⚠️ {self.failed} testów nie przeszło")
            return 1


def test_xml_extraction(xml_file, results, logger):
    """Test ekstrakcji SQL z pliku XML"""
    test_name = f"XML→SQL: {xml_file}"
    
    if not Path(xml_file).exists():
        results.add_test(test_name, None, f"Plik nie istnieje")
        return
    
    try:
        conv = ComarchBIConverter(logger=logger)
        
        # Test 1: Ekstrakcja raportów
        start_time = time.time()
        reports = conv.extract_sql_reports(xml_file)
        extract_time = time.time() - start_time
        
        if not reports:
            results.add_test(test_name, False, "Nie wyodrębniono żadnych raportów")
            return
        
        # Test 2: Zapis do plików
        with tempfile.TemporaryDirectory() as tmpdir:
            outputs = conv.write_sql_reports(xml_file, tmpdir)
            
            if len(outputs) != len(reports):
                results.add_test(test_name, False, 
                    f"Zapisano {len(outputs)} plików, ale wyodrębniono {len(reports)} raportów")
                return
            
            # Test 3: Sprawdzenie zawartości plików
            for output_file in outputs:
                if not output_file.exists():
                    results.add_test(test_name, False, f"Nie utworzono pliku {output_file.name}")
                    return
                
                content = output_file.read_text(encoding='utf-8')
                if not content or len(content) < 10:
                    results.add_test(test_name, False, f"Plik {output_file.name} jest pusty lub zbyt mały")
                    return
        
        file_size_mb = Path(xml_file).stat().st_size / (1024 * 1024)
        details = f"{len(reports)} raportów, {file_size_mb:.2f} MB, {extract_time:.3f}s"
        results.add_test(test_name, True, details)
        
    except Exception as e:
        results.add_test(test_name, False, f"Błąd: {str(e)}")


def test_sql_to_xml_conversion(results, logger):
    """Test konwersji SQL→XML"""
    test_name = "SQL→XML: Konwersja pojedynczego pliku"
    
    # Znajdź przykładowy plik SQL
    sql_files = list(Path("extracted_magazyny").glob("*.sql"))
    if not sql_files:
        results.add_test(test_name, None, "Brak plików SQL do testowania")
        return
    
    sql_file = sql_files[0]
    
    try:
        conv = ComarchBIConverter(logger=logger)
        
        conn_config = {
            'server': 'TESTSERVER',
            'database': 'TESTDB',
            'connection_name': 'TestConn',
            'mode': 'default'
        }
        
        # Test konwersji
        with tempfile.NamedTemporaryFile(mode='w', suffix='.xml', delete=False) as f:
            output_xml = f.name
        
        try:
            # Użyj convert_multiple z jednym plikiem
            result = conv.convert_multiple([str(sql_file)], conn_config, output_xml_path=output_xml)
            
            if not Path(result).exists():
                results.add_test(test_name, False, "Nie utworzono pliku XML")
                return
            
            # Sprawdź zawartość
            content = Path(result).read_text(encoding='utf-8')
            
            if '<ReportsList' not in content:
                results.add_test(test_name, False, "Brak nagłówka ReportsList")
                return
            
            if '<a:Report' not in content:
                results.add_test(test_name, False, "Brak raportów w XML")
                return
            
            file_size_kb = Path(result).stat().st_size / 1024
            details = f"Plik: {sql_file.name}, XML: {file_size_kb:.1f} KB"
            results.add_test(test_name, True, details)
            
        finally:
            Path(output_xml).unlink(missing_ok=True)
        
    except Exception as e:
        results.add_test(test_name, False, f"Błąd: {str(e)}")


def test_sql_to_xml_multiple(results, logger):
    """Test konwersji wielu plików SQL→XML"""
    test_name = "SQL→XML: Konwersja wielu plików (batch)"
    
    # Znajdź kilka plików SQL
    sql_files = list(Path("extracted_magazyny").glob("*.sql"))[:3]
    if len(sql_files) < 2:
        results.add_test(test_name, None, "Za mało plików SQL do testowania batch")
        return
    
    try:
        conv = ComarchBIConverter(logger=logger)
        
        conn_config = {
            'server': 'TESTSERVER',
            'database': 'TESTDB',
            'connection_name': 'TestConn',
            'mode': 'default'
        }
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.xml', delete=False) as f:
            output_xml = f.name
        
        try:
            # Konwersja wielu plików
            result = conv.convert_multiple([str(f) for f in sql_files], conn_config, 
                                          output_xml_path=output_xml)
            
            if not Path(result).exists():
                results.add_test(test_name, False, "Nie utworzono pliku XML")
                return
            
            # Sprawdź zawartość
            content = Path(result).read_text(encoding='utf-8')
            
            report_count = content.count('<a:Report i:type="a:MdxSqlDevXpressReport">')
            
            if report_count != len(sql_files):
                results.add_test(test_name, False, 
                    f"Oczekiwano {len(sql_files)} raportów, znaleziono {report_count}")
                return
            
            file_size_kb = Path(result).stat().st_size / 1024
            details = f"{len(sql_files)} plików SQL → {file_size_kb:.1f} KB XML"
            results.add_test(test_name, True, details)
            
        finally:
            Path(output_xml).unlink(missing_ok=True)
        
    except Exception as e:
        results.add_test(test_name, False, f"Błąd: {str(e)}")


def test_roundtrip_conversion(results, logger):
    """Test konwersji XML→SQL→XML (roundtrip)"""
    test_name = "Roundtrip: XML→SQL→XML"
    
    xml_file = "test_simple.xml"
    
    if not Path(xml_file).exists():
        results.add_test(test_name, None, "Plik test_simple.xml nie istnieje")
        return
    
    try:
        conv = ComarchBIConverter(logger=logger)
        
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            
            # Krok 1: XML → SQL
            outputs = conv.write_sql_reports(xml_file, tmpdir)
            
            if not outputs:
                results.add_test(test_name, False, "Nie wyodrębniono plików SQL")
                return
            
            # Krok 2: SQL → XML
            conn_config = {
                'server': 'TESTSERVER',
                'database': 'TESTDB',
                'connection_name': 'TestConn',
                'mode': 'default'
            }
            
            output_xml = str(tmpdir_path / "roundtrip.xml")
            result = conv.convert_multiple([str(f) for f in outputs], conn_config, 
                                          output_xml_path=output_xml)
            
            if not Path(result).exists():
                results.add_test(test_name, False, "Nie utworzono pliku XML w roundtrip")
                return
            
            # Krok 3: Sprawdzenie spójności
            content = Path(result).read_text(encoding='utf-8')
            
            if '<ReportsList' not in content or '<a:Report' not in content:
                results.add_test(test_name, False, "Nieprawidłowa struktura XML po roundtrip")
                return
            
            report_count = content.count('<a:Report i:type="a:MdxSqlDevXpressReport">')
            
            if report_count != len(outputs):
                results.add_test(test_name, False, 
                    f"Liczba raportów się zmieniła: {len(outputs)} → {report_count}")
                return
            
            details = f"{len(outputs)} raportów przeszło przez cykl konwersji"
            results.add_test(test_name, True, details)
        
    except Exception as e:
        results.add_test(test_name, False, f"Błąd: {str(e)}")


def test_column_detection(results, logger):
    """Test wykrywania kolumn w SQL"""
    test_name = "Analiza SQL: Wykrywanie kolumn"
    
    sql_sample = """
    SELECT 
        t.Kod AS [Kod Produktu],
        t.Nazwa AS [Nazwa Produktu],
        SUM(e.Ilosc) AS [Suma Ilość],
        COUNT(*) AS [Liczba Transakcji]
    FROM Towary t
    JOIN Elementy e ON e.TwrId = t.TwrId
    GROUP BY t.Kod, t.Nazwa
    """
    
    try:
        conv = ComarchBIConverter(logger=logger)
        columns = conv.extract_columns(sql_sample)
        
        if not columns:
            results.add_test(test_name, False, "Nie wykryto żadnych kolumn")
            return
        
        expected_columns = ["Kod Produktu", "Nazwa Produktu", "Suma Ilość", "Liczba Transakcji"]
        found_columns = [c.name for c in columns]
        
        for expected in expected_columns:
            if expected not in found_columns:
                results.add_test(test_name, False, f"Nie znaleziono kolumny: {expected}")
                return
        
        details = f"Wykryto {len(columns)} kolumn: {', '.join(found_columns)}"
        results.add_test(test_name, True, details)
        
    except Exception as e:
        results.add_test(test_name, False, f"Błąd: {str(e)}")


def test_parameter_detection(results, logger):
    """Test wykrywania parametrów w SQL"""
    test_name = "Analiza SQL: Wykrywanie parametrów"
    
    sql_sample = """
    DECLARE @DataOd DATE = '2024-01-01';
    DECLARE @DataDo DATE = '2024-12-31';
    DECLARE @Magazyn INT = 1;
    
    SELECT *
    FROM Dokumenty
    WHERE Data >= @DataOd AND Data <= @DataDo
      AND MagazynId = @Magazyn
    """
    
    try:
        conv = ComarchBIConverter(logger=logger)
        params = conv.extract_parameters(sql_sample)
        
        if not params:
            results.add_test(test_name, False, "Nie wykryto żadnych parametrów")
            return
        
        expected_params = ["DATAOD", "DATADO", "MAGAZYN"]
        found_params = [p.name for p in params]
        
        for expected in expected_params:
            if expected not in found_params:
                results.add_test(test_name, False, f"Nie znaleziono parametru: {expected}")
                return
        
        # Test wykrywania parametrów interaktywnych
        interactive = conv.detect_interactive_params(params)
        interactive_names = [p.name for p in interactive]
        
        details = f"Wykryto {len(params)} parametrów, {len(interactive)} interaktywnych"
        results.add_test(test_name, True, details)
        
    except Exception as e:
        results.add_test(test_name, False, f"Błąd: {str(e)}")


def test_sql_validation(results, logger):
    """Test walidacji SQL"""
    test_name = "Walidacja SQL: Sprawdzanie poprawności"
    
    # Test 1: Poprawny SQL
    valid_sql = "SELECT Kolumna AS [Nazwa], Kolumna2 AS [Nazwa2], Kolumna3 AS [Nazwa3] FROM Tabela"
    
    # Test 2: SQL bez SELECT
    invalid_sql = "UPDATE Tabela SET Kolumna = 1"
    
    try:
        conv = ComarchBIConverter(logger=logger)
        
        # Sprawdź poprawny SQL - validate_sql zwraca (is_valid, warnings)
        # gdzie is_valid=True oznacza brak błędów krytycznych
        is_valid, warnings = conv.validate_sql(valid_sql)
        
        if not is_valid:
            results.add_test(test_name, False, f"Nieprawidłowe błędy dla poprawnego SQL: warnings={warnings}")
            return
        
        # Sprawdź niepoprawny SQL - powinien zwrócić is_valid=False
        is_valid2, warnings2 = conv.validate_sql(invalid_sql)
        
        if is_valid2:
            results.add_test(test_name, False, "Nie wykryto błędów w SQL bez SELECT")
            return
        
        details = "Poprawnie wykrywa błędy i ostrzeżenia"
        results.add_test(test_name, True, details)
        
    except Exception as e:
        results.add_test(test_name, False, f"Błąd: {str(e)}")


def test_config_loading(results, logger):
    """Test ładowania konfiguracji"""
    test_name = "Konfiguracja: Ładowanie config.json"
    
    try:
        conv = ComarchBIConverter(logger=logger)
        
        # Sprawdź, czy konfiguracja została załadowana
        if not hasattr(conv, 'config'):
            results.add_test(test_name, False, "Brak atrybutu config")
            return
        
        # Sprawdź, czy known_params jest ustawione
        if not hasattr(conv, 'known_params'):
            results.add_test(test_name, False, "Brak atrybutu known_params")
            return
        
        details = f"{len(conv.known_params)} znanych parametrów BI"
        results.add_test(test_name, True, details)
        
    except Exception as e:
        results.add_test(test_name, False, f"Błąd: {str(e)}")


def main():
    """Główna funkcja testująca"""
    print("\n" + "=" * 80)
    print(" KOMPLEKSOWY TEST PROGRAMU KONWERTERBI-OPTIMA ".center(80, "="))
    print("=" * 80)
    print("\nTest wszystkich funkcji programu i dostępnych plików XML...\n")
    
    logger = get_logger()
    results = TestResults()
    
    # Lista plików XML do testowania
    xml_files = [
        "test_simple.xml",
        "test_roundtrip.xml",
        "combined_reports.xml",
        "raporty magazyny.xml",
        "raporty zakupy.xml",
        "raporty wzorcowe optima.xml",
        "Magaqzyn.xml",
        "Sprzedaż.xml",
        "raporty sprzedaży.xml"
    ]
    
    print("=" * 80)
    print(" TESTY EKSTRAKCJI XML → SQL ".center(80))
    print("=" * 80)
    
    for xml_file in xml_files:
        test_xml_extraction(xml_file, results, logger)
    
    print("\n" + "=" * 80)
    print(" TESTY KONWERSJI SQL → XML ".center(80))
    print("=" * 80)
    
    test_sql_to_xml_conversion(results, logger)
    test_sql_to_xml_multiple(results, logger)
    
    print("\n" + "=" * 80)
    print(" TESTY ROUNDTRIP (XML → SQL → XML) ".center(80))
    print("=" * 80)
    
    test_roundtrip_conversion(results, logger)
    
    print("\n" + "=" * 80)
    print(" TESTY ANALIZY SQL ".center(80))
    print("=" * 80)
    
    test_column_detection(results, logger)
    test_parameter_detection(results, logger)
    test_sql_validation(results, logger)
    
    print("\n" + "=" * 80)
    print(" TESTY KONFIGURACJI ".center(80))
    print("=" * 80)
    
    test_config_loading(results, logger)
    
    # Wyświetl podsumowanie
    return results.print_summary()


if __name__ == '__main__':
    sys.exit(main())
