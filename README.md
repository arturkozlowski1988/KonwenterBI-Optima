# Comarch BI Converter (Python package)

**Wersja 2.5** - Robust SQL Parsing & Formatting

This package provides a high-performance bidirectional converter for Comarch Analizy BI with professional user experience:

## 🎯 Funkcjonalności

### SQL → XML (Tworzenie raportów)
- **� Konwersja wieloplikowa** - wybierz wiele plików SQL (Shift/Ctrl) i połącz w jeden XML
- **�🔍 Podgląd metadanych** - preview columns and parameters for single or multiple files
- **🗂️ Interfejs zakładkowy** - podgląd wielu plików w osobnych zakładkach
- **💾 Eksport konfiguracji** - save custom interactive parameter selections (per file)
- Auto-detection of columns and their types
- Auto-detection of interactive parameters (heuristics + config overrides)
- Recognition of well-known BI params when not declared (e.g., DATAOD/DATADO)

### XML → SQL (Ekstrakcja raportów) 🆕
- **⏬ Wyodrębnianie SQL** z plików XML zawierających raporty BI
- **⚡ Zoptymalizowana wydajność** - 33x szybciej (97% redukcja czasu) w v2.3
- **💾 Stałe użycie pamięci** - obsługa plików >100MB bez problemów
- Obsługa wielu raportów w jednym pliku XML
- Automatyczne unescape'owanie encji HTML
- Inteligentne nazewnictwo plików z sanityzacją
- Zachowanie polskich znaków

### Interfejs
- Professional GUI (Tkinter) z dwoma zakładkami:
  - **SQL → XML** - konwersja zapytań do XML z walidacją
    - **Multi-select**: Wybierz wiele plików SQL jednocześnie (Shift/Ctrl)
    - **Batch conversion**: Automatyczna konwersja wielu plików do jednego XML
    - **Multi-file preview**: Podgląd metadanych wszystkich wybranych plików w zakładkach
    - **🖋️ Formatuj SQL**: Nowa funkcja formatowania kodu SQL w miejscu (tworzy kopię zapasową .bak)
  - **XML → SQL** - ekstrakcja zapytań z XML z podglądem
- **🔄 Progress bar** - wizualny feedback podczas operacji
- **✅ SQL validation** - pre-flight checks przed konwersją (teraz oparte na `sqlparse`)
- **🔍 XML preview** - podgląd zawartości przed ekstrakcją
- **Non-blocking GUI** - threading dla responsywności
- Logging to rotating file logs/app.log and console
- CLI entry point dla automatyzacji

---

## Co nowego w v2.5?

### 🛠️ Robust SQL Analysis (Solidna analiza SQL)

Wersja 2.5 wprowadza fundamentalne zmiany w silniku analizy SQL:

1.  **Nowy silnik parsowania (`sqlparse`)**
    *   Zastąpiono wyrażenia regularne profesjonalną biblioteką parsującą.
    *   Lepsza obsługa komentarzy wewnątrz zapytań.
    *   Precyzyjne wykrywanie aliasów kolumn i parametrów.
    *   Bezpieczniejsza walidacja składni.

2.  **🖋️ Formatowanie SQL**
    *   Przycisk "Formatuj SQL" w GUI.
    *   Automatycznie porządkuje wcięcia i wielkość liter (Keywords UPPERCASE).
    *   Tworzy kopię zapasową (`.bak`) przed zmianą pliku.

3.  **Refaktoryzacja kodu**
    *   Wydzielony moduł `sql_analyzer.py`.
    *   Poprawione testy jednostkowe.

---

## Co nowego w v2.4?

### 🎨 Phase 2 UX Improvements (Faza 2: Usprawnienia UX)

Wersja 2.4 wprowadza **profesjonalne funkcje UX** transformujące doświadczenie użytkownika:

**Nowe funkcje:**
1. **🔄 Progress Bar z Threading**
   - GUI nigdy się nie zamraża
   - Wizualny feedback podczas operacji
   - Non-blocking interface
   - Automatyczne zarządzanie wątkami

2. **✅ SQL Validation**
   - 6 kompleksowych sprawdzeń przed konwersją
   - System dwupoziomowy: błędy krytyczne (blokują) i ostrzeżenia
   - Wykrywanie: brak SELECT, brak aliasów, niezadeklarowane zmienne
   - Blokada niebezpiecznych komend: DROP, TRUNCATE, DELETE bez WHERE
   - Szczegółowe komunikaty błędów

3. **🔍 XML Preview**
   - Podgląd zawartości XML przed ekstrakcją
   - Treeview: index, nazwa, linie, rozmiar
   - Statystyki: suma raportów, suma linii, suma rozmiaru
   - Szybki (avg 0.018s dla 42 raportów)
   - Przycisk "🔍 Podgląd raportów" w GUI

4. **📚 Multi-File Support** (NEW v2.4.1)
   - **Batch conversion**: Wybierz wiele plików SQL (Shift/Ctrl) i konwertuj do jednego XML
   - **Multi-file preview**: Podgląd metadanych wszystkich plików w interfejsie zakładkowym
   - **Per-file export**: Osobne przyciski eksportu konfiguracji dla każdego pliku
   - **File count**: Liczba plików w tytule okna ("Podgląd metadanych - 3 plików")
   - **Error handling**: Graceful degradation - pominięcie nieczytelnych plików z ostrzeżeniem

**Przykład użycia walidacji:**
```
⚠️ Nie znaleziono kolumn z aliasami (AS [nazwa]) - Comarch BI może nie działać
⚠️ Niezadeklarowane zmienne: @DATADO
🚨 UWAGA! Niebezpieczne komendy: DROP TABLE
```

**UX Impact:**
| Aspekt | Przed (v2.3) | Po (v2.4) | Poprawa |
|--------|--------------|-----------|---------|
| Responsywność GUI | Zamraża | Non-blocking | ✅ Threading |
| Wykrywanie błędów | Po konwersji | Przed konwersją | ✅ Walidacja |
| Podgląd XML | Brak | Pełny | ✅ Nowa funkcja |
| Feedback wizualny | Brak | Progress bar | ✅ Profesjonalny |
| Konwersja wieloplikowa | 1 plik | Wiele plików | ✅ Batch support |
| Podgląd wieloplikowy | Tylko 1. plik | Wszystkie w zakładkach | ✅ Tab interface |

**Szczegóły:** Zobacz [PHASE2_REPORT.md](PHASE2_REPORT.md) i [CHANGELOG_v2.4.md](CHANGELOG_v2.4.md)

---

## Co nowego w v2.3?

### 🚀 Phase 1 Performance Optimizations (Faza 1: Optymalizacja wydajności)

Wersja 2.3 wprowadza **dramatyczne usprawnienia wydajności** przy zachowaniu 100% kompatybilności wstecznej:

**Wyniki:**
- ⚡ **97% redukcja czasu przetwarzania** (33x szybciej!)
- 💾 **Stałe użycie pamięci** - obsługa plików dowolnej wielkości
- 📈 **66.67 MB/s** średnia przepustowość (peak: 78.60 MB/s)
- 🎯 **144.7% przyspieszenie** ładowania konfiguracji

**Implementacje:**
1. **Streaming XML Parser** - `iterparse` z inkrementalnym czyszczeniem pamięci
2. **Config Caching** - cache z automatyczną walidacją mtime
3. **Type Hints** - pełne pokrycie typów dla lepszej jakości kodu

**Projekcje wydajności:**
| Rozmiar pliku | v2.2 | v2.3 | Oszczędność |
|---------------|------|------|-------------|
| 2 MB | ~0.96s | 0.029s | 97% |
| 10 MB | ~5s | 0.15s | 97% |
| 50 MB | ~35s | 0.75s | 98% |
| 100 MB | ~70s | 1.50s | 98% |

**Szczegóły:** Zobacz [PHASE1_REPORT.md](PHASE1_REPORT.md) i [CHANGELOG_v2.3.md](CHANGELOG_v2.3.md)

---

## Co nowego w v2.2?

### Nowa funkcjonalność: XML → SQL

Możesz teraz wyodrębnić zapytania SQL z plików XML eksportowanych z Comarch BI:

```powershell
# CLI
python -m bi_converter --from-xml "raporty.xml" --output-dir "extracted_sql"

# GUI
Zakładka "XML → SQL" → Wybierz plik XML → Kliknij "⏬ Wyodrębnij SQL"
```

**Zastosowania:**
- Backup raportów w czytelnej formie
- Edycja zapytań SQL poza BI
- Kontrola wersji (GIT) z plikami .sql
- Migracja raportów między środowiskami

Szczegóły w [CHANGELOG_v2.2.md](CHANGELOG_v2.2.md)

---

## Co zostało naprawione w v2.0?

### Problem:
Import raportu w Comarch BI kończył się błędem:
```
System.Xml.XmlException: Brak elementu głównego.
```

### Przyczyna:
Gdy raport nie miał parametrów interaktywnych, stary konwerter zwracał **pusty string** w sekcji `<MdxParams>`, co powodowało błąd deserializacji XML.

### Rozwiązanie:
Nowy konwerter **zawsze** zwraca prawidny XML z głównym elementem `<ArrayOfMdxQueryParameter>`, nawet gdy lista parametrów jest pusta:

```xml
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfMdxQueryParameter xmlns:xsd="..." xmlns:xsi="...">
</ArrayOfMdxQueryParameter>
```

✅ **Teraz wszystkie raporty importują się bez błędów!**

---

## Structure

- bi_converter/
  - converter.py — core logic with SQL↔XML conversion
  - gui.py — Tkinter UI with tabs, preview window and config export
  - logging_conf.py — logging setup
  - __main__.py — CLI entry
  - config.json — optional overrides for interactive params (auto-created by export)
  - tests/ — basic unit tests

## Config.json Format

Plik konfiguracyjny pozwala na nadpisanie automatycznej detekcji parametrów interaktywnych:

```json
{
  "interactive_overrides": {
    "include": ["PARAMROKZAKUPU", "DATAPOCZATEKROKU"],
    "exclude": ["BAZAFIRMOWA", "DZISIEJSZADATA"]
  },
  "well_known_params": ["DATAOD", "DATADO", "DATAPOCZATEKROKU", "DATAKONIECROKU", "DATADOANALIZY", "DATAODANALIZY"],
  "param_defaults": {
    "DATAOD": "2025-01-01",
    "DATADO": "2025-12-31"
  }
}
```

- **include**: parametry które MUSZĄ być interaktywne (nawet jeśli auto-detekcja ich nie wykryła)
- **exclude**: parametry które NIE MOGĄ być interaktywne (nawet jeśli auto-detekcja je wykryła)
 - **well_known_params**: lista znanych parametrów BI (np. DATAOD/DATADO), które będą wykrywane nawet bez `DECLARE`
 - **param_defaults**: opcjonalne wartości domyślne dla parametrów interaktywnych (wpisane do MdxParams)

**Automatyczne tworzenie:**
Użyj GUI → Podgląd → zaznacz/odznacz parametry → Eksportuj konfigurację

## Install & Run

No external dependencies required (Tkinter comes with standard Python on Windows).

### Run GUI

```powershell
python -m bi_converter --gui
```

**Nowe funkcje GUI:**

1. **🔍 Podgląd metadanych** - kliknij "Podgląd metadanych" aby zobaczyć:
   - Wszystkie wykryte kolumny (nazwa, typ, format, agregacja)
   - Wszystkie parametry (nazwa, typ, wartość domyślna, źródło)
   - Automatycznie wykryte parametry interaktywne (zaznaczone ☑)

2. **✏️ Edycja parametrów interaktywnych** - w oknie podglądu:
   - Kliknij na parametr aby przełączyć ☐/☑ (interaktywny/nieinteraktywny)
   - Dostosuj które parametry użytkownik będzie mógł edytować w BI

3. **💾 Eksport konfiguracji** - kliknij "Eksportuj konfigurację do config.json":
   - Zapisuje Twój wybór parametrów interaktywnych
   - Tworzy/nadpisuje `bi_converter/config.json` z listami include/exclude
   - Kolejne konwersje będą używać Twojej konfiguracji

**Przykładowy workflow:**
```
1. Wybierz plik SQL
2. Kliknij "Podgląd metadanych"
3. Przejrzyj kolumny i parametry
4. Zaznacz/odznacz parametry według potrzeb
5. Kliknij "Eksportuj konfigurację" (opcjonalnie)
6. Zamknij podgląd i kliknij "Konwertuj"
```

### Run CLI

```powershell
python -m bi_converter "path\to\report.sql" --server "SERWEROPTIMA\\SUL02" --database "CDN_Ulex_2018_temp" --name "Ulex_2018_temp"
```

Optionally load overrides:

```powershell
python -m bi_converter "report.sql" --config "python/bi_converter/config.json"
```

The XML will be written next to the input SQL file.

## Logging

- Console: INFO level summary
- File: `logs/app.log` (rotating up to ~1MB x 3 backups)
- Wszystkie konwersje są logowane (sukces i błędy)

Przykładowy log:
```
2025-10-18 14:23:45 | INFO | bi-converter | Logger initialized
2025-10-18 14:23:45 | INFO | bi-converter | Loaded config from D:\...\config.json
2025-10-18 14:23:45 | INFO | bi-converter | Converting file: e-sklep.sql
2025-10-18 14:23:45 | INFO | bi-converter | Detected 0 columns
2025-10-18 14:23:45 | INFO | bi-converter | Detected 13 parameters (declared: 13, inferred: 0)
2025-10-18 14:23:45 | INFO | bi-converter | Interactive params selected: []
2025-10-18 14:23:45 | INFO | bi-converter | Wrote XML: e-sklep.xml
```

## Tests

```powershell
python -m unittest discover -s python/bi_converter/tests -t python
```

## Notes

- All DECLARE statements remain in SQL; only interactive parameters are exported to MdxParams.
- Special columns like "Baza Firmowa" or technical context columns containing __PROCID__/__ORGID__/__DATABASE__ are ignored in metadata.