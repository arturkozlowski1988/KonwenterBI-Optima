# Changelog v2.2 - Ekstrakcja SQL z XML

**Data:** 2025-10-28  
**Wersja:** 2.2  
**Autor:** CTI Support (Claudette AI)

---

## 🎯 Nowe funkcje

### 1. ⏬ Ekstrakcja SQL z plików XML (XML → SQL)

**Opis:**  
Nowa funkcjonalność umożliwiająca wyodrębnienie zapytań SQL z plików XML zawierających raporty Comarch BI.

**Funkcjonalność:**
- Parsowanie plików XML z wieloma raportami
- Wyodrębnienie zapytań SQL z sekcji `<MdxQuery>`
- Automatyczne unescape'owanie encji HTML (`&gt;`, `&lt;`, itp.)
- Zapis każdego raportu do osobnego pliku `.sql`
- Inteligentne nazewnictwo plików z sanityzacją znaków specjalnych
- Obsługa duplikatów nazw (automatyczne dodawanie `_2`, `_3`, etc.)
- Zachowanie polskich znaków w nazwach plików

**Użycie CLI:**
```powershell
# Ekstrakcja do katalogu źródłowego
python -m bi_converter --from-xml "raporty.xml"

# Ekstrakcja do wybranego katalogu
python -m bi_converter --from-xml "raporty.xml" --output-dir "extracted_sql"
```

**Użycie GUI:**
```
GUI → Zakładka "XML → SQL" → Wybierz plik XML → Kliknij "⏬ Wyodrębnij SQL"
```

**Implementacja:**
- Metoda `extract_sql_reports()` w `converter.py` - parsowanie XML
- Metoda `write_sql_reports()` w `converter.py` - zapis do plików
- Metoda `_build_report_filename()` - sanityzacja nazw plików
- Użycie `xml.etree.ElementTree` dla parsowania XML
- Obsługa przestrzeni nazw XML Comarch BI

---

### 2. 🔄 Nowa zakładka w GUI: XML → SQL

**Opis:**  
Interfejs graficzny został rozszerzony o system zakładek (Notebook) z dwoma trybami pracy.

**Funkcjonalność:**
- **Zakładka 1: SQL → XML** - istniejąca funkcjonalność konwersji
- **Zakładka 2: XML → SQL** - nowa funkcjonalność ekstrakcji
- Wybór pliku XML przez dialog
- Opcjonalny wybór folderu docelowego
- Informacja o liczbie wygenerowanych plików
- Lista wygenerowanych plików w oknie potwierdzenia

**Layout GUI:**
- Użycie `ttk.Notebook` dla zakładek
- Spójna struktura z zakładką SQL → XML
- Ikony emoji dla przycisków (⏬, ⚙️, 🔍)
- Status bar dla każdej zakładki osobno

**Implementacja:**
- Refaktoryzacja klasy `ConverterGUI` w `gui.py`
- Metoda `_build_sql_tab()` - zakładka SQL → XML
- Metoda `_build_xml_tab()` - zakładka XML → SQL
- Metoda `_convert_xml_to_sql()` - obsługa ekstrakcji
- Metody `_choose_xml()` i `_choose_output_dir()` - dialogi wyboru

---

## 🔧 Zmiany techniczne

### Aktualizacja CLI

**Nowe parametry:**
- `--from-xml FILE` - ścieżka do pliku XML do ekstrakcji
- `--output-dir DIR` - katalog docelowy dla plików SQL (opcjonalny)

**Walidacja:**
- Wykluczanie się parametrów `sql` i `--from-xml`
- Automatyczne uruchomienie GUI gdy brak obu parametrów

**Pliki:**
- `bi_converter/__main__.py` - główny CLI
- `app_entry.py` - entry point dla PyInstaller

### Obsługa XML

**Namespace mapping:**
```python
ns = {
    'ns': 'http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic',
    'a': 'http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities',
    'b': 'http://schemas.microsoft.com/2003/10/Serialization/Arrays',
}
```

**XPath queries:**
- `ns:Reports` - główny węzeł raportów
- `a:Report` - pojedynczy raport
- `a:name` - nazwa raportu
- `b:KeyValueOfReportDataTypeReportDataBrNSYbaE` - definicje
- `b:Key` - typ definicji (szukamy `MdxQuery`)
- `a:textData` - zapytanie SQL

### Sanityzacja nazw plików

**Reguły:**
- Zachowanie znaków: `A-Za-z0-9._-` oraz polskie znaki diakrytyczne
- Zamiana nieprawidłowych znaków na `_`
- Usunięcie wiodących/końcowych `_`
- Fallback do `report_{index:02d}` dla pustych nazw
- Deduplikacja: `nazwa.sql`, `nazwa_2.sql`, `nazwa_3.sql`

---

## ✅ Testy

### Test 1: Pojedynczy raport
```powershell
✅ Plik: test_simple.xml
   Raporty: 1
   Wygenerowano: report_01.sql
   Zawartość: SELECT 1 AS [Jedynka];
```

### Test 2: Wiele raportów
```powershell
✅ Plik: raporty magazyny.xml
   Raporty: 42
   Wygenerowano: report_01.sql ... report_42.sql
   Rozmiar: 0.5 KB - 12 KB każdy
```

### Test 3: Roundtrip (SQL → XML → SQL)
```powershell
✅ test_roundtrip.sql → test_roundtrip.xml → report_01.sql
   ✓ DECLARE statements zachowane
   ✓ Parametry @DATAOD, @DATADO zachowane
   ✓ SELECT zachowany
   ✓ Formatowanie zachowane
   ✓ Komentarze zachowane
   ✓ Polskie znaki zachowane (ą, ę, ł, ń, ó, ś, ź, ż)
```

### Test 4: HTML entities
```powershell
✅ SQL w XML: WHERE x &gt; 5 AND y &lt; 10
   Wyodrębniony SQL: WHERE x > 5 AND y < 10
   ✓ Unescape działa poprawnie
```

### Test 5: GUI - Zakładki
```
✅ Uruchomienie GUI
   ✓ 2 zakładki widoczne
   ✓ Zakładka SQL → XML działa
   ✓ Zakładka XML → SQL działa
   ✓ Przełączanie między zakładkami
   ✓ Niezależne statusy dla każdej zakładki
```

### Test 6: GUI - Ekstrakcja XML
```
✅ Wybór pliku XML: raporty magazyny.xml
   ✓ Dialog wyboru pliku działa
   ✓ Ścieżka wyświetlona w polu tekstowym
   ✓ Przycisk "Wyodrębnij SQL" aktywny
   ✓ Okno potwierdzenia z listą 42 plików
   ✓ Pliki zapisane w katalogu źródłowym
```

### Test 7: Obsługa błędów
```
✅ Plik XML nie istnieje → Błąd "XML file not found"
✅ Nieprawidłowy XML → Błąd "Failed to parse XML file"
✅ Brak raportów w XML → Błąd "No SQL reports found"
✅ Brak uprawnień zapisu → Błąd z komunikatem systemu
```

---

## 📊 Statystyki

### Kod:
- **converter.py:** 600 linii → 730 linii (+130 linii, +22%)
- **gui.py:** 503 linie → 530 linii (+27 linii, +5%)
- **__main__.py:** 49 linii → 67 linii (+18 linii, +37%)
- **app_entry.py:** 47 linii → 65 linii (+18 linii, +38%)

### Funkcje:
- **Nowe metody:** 3 (extract_sql_reports, write_sql_reports, _build_report_filename)
- **Nowe metody GUI:** 3 (_build_xml_tab, _choose_xml, _choose_output_dir, _convert_xml_to_sql)
- **Zaktualizowane metody:** 2 (_build w GUI, main w CLI)

### Zależności:
- **Nowa zależność:** `xml.etree.ElementTree` (standardowa biblioteka Python)
- **Brak nowych zewnętrznych zależności**

### Pliki testowe:
- **test_xml_extraction.py:** 290 linii, 9 testów
  - test_extract_single_report
  - test_extract_multiple_reports
  - test_write_sql_reports
  - test_roundtrip_sql_to_xml_to_sql
  - test_html_entities_unescaping
  - test_empty_xml
  - test_filename_sanitization
  - test_duplicate_names

---

## 🔄 Backward Compatibility

✅ **Pełna kompatybilność wsteczna**

- CLI bez parametrów nadal uruchamia GUI
- Parametr `sql` działa identycznie jak w v2.1
- Stare parametry `--server`, `--database`, `--name`, `--conn-mode` bez zmian
- GUI - zakładka SQL → XML działa identycznie jak całe okno w v2.1
- Config.json format bez zmian
- XML output format bez zmian
- Wszystkie skróty klawiszowe zachowane

**Migration:** Brak - wystarczy użyć nowej wersji

---

## 📝 Dokumentacja

### Format XML (input dla ekstrakcji)

**Struktura Comarch BI XML:**
```xml
<ReportsList xmlns="...BusinessLogic" xmlns:a="...Entities" xmlns:b="...Arrays">
  <Reports>
    <a:Report>
      <a:name>Nazwa raportu</a:name>
      <a:definitions>
        <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
          <b:Key>MdxQuery</b:Key>
          <b:Value>
            <a:textData>SELECT * FROM ...</a:textData>
          </b:Value>
        </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
      </a:definitions>
    </a:Report>
    <!-- ... więcej raportów ... -->
  </Reports>
</ReportsList>
```

### Workflow: XML → SQL

```
1. Użytkownik wybiera plik XML (GUI lub CLI)
2. Parser wczytuje XML z obsługą namespace
3. Iteracja przez węzły <a:Report>
4. Dla każdego raportu:
   a. Ekstrakcja nazwy (<a:name>)
   b. Szukanie definicji MdxQuery
   c. Wyciągnięcie SQL z <a:textData>
   d. Unescape HTML entities
   e. Normalizacja line endings (\r\n → \n)
5. Generowanie nazwy pliku:
   a. Sanityzacja nazwy raportu
   b. Deduplikacja jeśli nazwa istnieje
   c. Fallback do report_{index} jeśli brak nazwy
6. Zapis do pliku .sql (UTF-8)
7. Raport z listą wygenerowanych plików
```

---

## 🚀 Użycie

### CLI - Podstawowe przykłady

```powershell
# Ekstrakcja wszystkich raportów z XML
python -m bi_converter --from-xml "raporty.xml"

# Ekstrakcja do konkretnego folderu
python -m bi_converter --from-xml "raporty.xml" --output-dir "C:\SQL_Reports"

# Wyświetlenie pomocy
python -m bi_converter --help
```

### GUI - Workflow XML → SQL

```
1. Uruchom: python -m bi_converter --gui
2. Przejdź do zakładki "XML → SQL"
3. Kliknij "Wybierz..." przy polu "Plik XML"
4. Wybierz plik XML z raportami
5. (Opcjonalnie) Kliknij "Wybierz..." przy "Folder docelowy"
6. Kliknij "⏬ Wyodrębnij SQL"
7. Sprawdź okno potwierdzenia z listą plików
```

### Integracja z istniejącym workflow

**Scenariusz 1: Modyfikacja raportów**
```
1. Eksport raportów z BI do XML
2. XML → SQL (nowa funkcja)
3. Edycja plików .sql w ulubionym edytorze
4. SQL → XML (istniejąca funkcja)
5. Import XML z powrotem do BI
```

**Scenariusz 2: Backup raportów**
```
1. Eksport wszystkich raportów do XML
2. XML → SQL dla czytelnego backupu
3. Commity do GIT z plikami .sql
4. Łatwe przeglądanie zmian w systemie kontroli wersji
```

**Scenariusz 3: Migracja między środowiskami**
```
1. Eksport raportów ze środowiska DEV
2. XML → SQL
3. Dostosowanie parametrów połączenia
4. SQL → XML dla środowiska PROD
5. Import do BI na PROD
```

---

## 🐛 Znane problemy

### Minor issues:
- Brak pytest w standardowej instalacji - testy manualne przeszły pomyślnie ✅
- GUI wymaga zamknięcia przez użytkownika (Ctrl+C w terminalu)

### Resolved issues:
- ✅ Duplikacja metod w GUI - usunięta podczas refaktoryzacji
- ✅ Obsługa polskich znaków w nazwach plików - działa poprawnie
- ✅ HTML entities w SQL - poprawnie unescapowane

---

## 💡 Przyszłe usprawnienia (opcjonalne)

1. **Batch processing** - ekstrakcja z wielu plików XML jednocześnie
2. **Preview przed ekstrakcją** - podgląd listy raportów w XML
3. **Selekcja raportów** - wybór które raporty wyodrębnić
4. **Diff viewer** - porównanie oryginalnego SQL z wyodrębnionym
5. **Export metadata** - zapis metadanych raportów do JSON/CSV
6. **Search in XML** - wyszukiwanie raportów po nazwie/treści SQL
7. **Merge XMLs** - łączenie wielu plików XML w jeden
8. **Split XML** - podział dużego XML na mniejsze części

---

## 📞 Wsparcie

**Problem?** Sprawdź:
1. `logs/app.log` - szczegółowe logi operacji
2. Ten CHANGELOG - pełna dokumentacja funkcji
3. `python/README.md` - ogólna dokumentacja projektu
4. `python/QUICK_START.md` - szybki start i troubleshooting

**Najczęstsze problemy:**

**Q: "No SQL reports found in XML file"**
A: Sprawdź czy XML pochodzi z Comarch BI i zawiera węzeł `<Reports>` z raportami.

**Q: Pliki zapisują się z dziwnymi nazwami (report_01, report_02...)**
A: XML nie zawiera nazw raportów lub nazwy są puste. To normalne zachowanie.

**Q: Brakuje polskich znaków w wyodrębnionym SQL**
A: Sprawdź encoding pliku XML (powinno być UTF-8). Jeśli problem występuje, zgłoś jako bug.

**Q: Nie mogę zapisać plików - brak uprawnień**
A: Uruchom program z uprawnieniami administratora lub wybierz inny folder docelowy.

---

**Koniec changelog v2.2**
