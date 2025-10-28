# Changelog v2.1 - Preview i Eksport Konfiguracji

**Data:** 2025-10-18  
**Wersja:** 2.1  
**Autor:** CTI Support (Claudette AI)

---

## 🎯 Nowe funkcje

### 1. 🔍 Podgląd metadanych przed konwersją

**Opis:**  
Nowe okno podglądu pozwala zobaczyć wszystkie wykryte kolumny i parametry PRZED konwersją.

**Funkcjonalność:**
- Zakładka "Kolumny" - tabela wszystkich wykrytych kolumn z:
  - Nazwa kolumny
  - Typ (measure/attribute)
  - Format (np. n2)
  - Agregacja (np. Sum)
- Zakładka "Parametry" - tabela wszystkich parametrów z:
  - Checkbox ☐/☑ (interaktywny/nieinteraktywny)
  - Nazwa parametru
  - Typ (Liczba/Tekst/Data)
  - Wartość domyślna
  - Źródło (DECLARE/Wykryty)
- Automatyczne zaznaczenie parametrów interaktywnych (heurystyka)
- Możliwość zmiany zaznaczenia przez kliknięcie na wiersz

**Użycie:**
```
GUI → Wybierz plik SQL → Kliknij "🔍 Podgląd metadanych"
```

**Implementacja:**
- Klasa `PreviewWindow` w `gui.py` (250+ linii)
- Tkinter `Toplevel` window (900x650px)
- Używa `ttk.Treeview` dla tabel
- Notebook (zakładki) dla kolumn i parametrów

---

### 2. 💾 Eksport konfiguracji do config.json

**Opis:**  
Możliwość zapisania własnego wyboru parametrów interaktywnych do pliku konfiguracyjnego.

**Funkcjonalność:**
- Przycisk "💾 Eksportuj konfigurację do config.json" w oknie podglądu
- Automatyczne tworzenie list include/exclude na podstawie:
  - **Include:** parametry zaznaczone ręcznie, ale NIE wykryte automatycznie
  - **Exclude:** parametry odznaczone ręcznie, ale BYŁY wykryte automatycznie
- Zapis do `python/bi_converter/config.json`
- Potwierdzenie sukcesu z liczbą parametrów w include/exclude

**Użycie:**
```
Podgląd → Zaznacz/odznacz parametry → Kliknij "Eksportuj konfigurację"
```

**Format config.json:**
```json
{
  "interactive_overrides": {
    "include": ["PARAM1", "PARAM2"],
    "exclude": ["PARAM3", "PARAM4"]
  }
}
```

**Implementacja:**
- Metoda `_export_config()` w klasie `PreviewWindow`
- Logika porównania auto-detected vs user selection
- JSON serialization z ensure_ascii=False, indent=2

---

## 🔧 Poprawki techniczne

### Naprawiono błąd składni w converter.py (linia 354)

**Problem:**
```python
xml_lines.append(f'<DefaultValue>{html.escape(str(def_val).strip("'\""))}</DefaultValue>')
```
Błąd: `SyntaxError: unexpected character after line continuation character`

**Rozwiązanie:**
```python
def_val_clean = str(def_val).strip("'\"")
xml_lines.append(f'<DefaultValue>{html.escape(def_val_clean)}</DefaultValue>')
```

Przeniesiono `strip("'\"")` poza f-string aby uniknąć problemów z escapowaniem.

---

## ✅ Testy

### Test 1: Preview functionality
```
✅ Plik: analiza_zakupow_rok_bez_sprzedazy_BI.sql
   Kolumny: 24
   Parametry: 4
   Interaktywne: 1 (PARAMROKZAKUPU)
```

### Test 2: Complex file preview
```
✅ Plik: 7.20 Zaleganie w przedziałach.sql
   Kolumny: 46
   Parametry: 26 total
   Interaktywne: 3 (PRZEDZIAL1, PRZEDZIAL2, PRZEDZIAL3)
```

### Test 3: Config include
```
✅ Dodano DATAPOCZATEKROKU do include
   Konwersja używa nowej konfiguracji
   Interactive: [PARAMROKZAKUPU, DATAPOCZATEKROKU]
```

### Test 4: Config exclude
```
✅ Dodano PRZEDZIAL2 do exclude
   Konwersja pomija PRZEDZIAL2
   Interactive: [PRZEDZIAL1, PRZEDZIAL3]
```

### Test 5: Full workflow
```
✅ User selection: tylko PRZEDZIAL1
   Config exported: exclude=[PRZEDZIAL2, PRZEDZIAL3]
   Conversion result: MdxParams zawiera tylko PRZEDZIAL1
   SQL verification: Wszystkie DECLARE zachowane
```

### Test 6: End-to-end conversion
```
✅ Pełna konwersja z custom config
   MdxParams: [PRZEDZIAL1] ✓
   SQL: 18 DECLARE statements ✓
   XML: Valid structure ✓
```

---

## 📝 Dokumentacja

### Zaktualizowane pliki:

**python/README.md:**
- Wersja 2.0 → 2.1
- Dodano sekcję "Nowe funkcje GUI" z workflow
- Dodano sekcję "Config.json Format"
- Przykłady użycia preview i export

**python/QUICK_START.md:**
- Dodano Metodę A z podglądem jako ZALECANA
- Rozszerzono "Najczęstsze problemy" o GUI solutions
- Dodano 3 przykładowe scenariusze użycia
- Wersja 2.0 → 2.1

**Nowe pliki:**
- `CHANGELOG_v2.1.md` (ten plik)

---

## 🎨 GUI Changes

### Główne okno (ConverterGUI):
- **Dodano:** Przycisk "🔍 Podgląd metadanych" (niebieski)
- **Zmieniono:** Przycisk "Konwertuj" → "⚙️ Konwertuj" (zielony)
- **Layout:** Przyciski obok siebie w action_frame
- **Import:** Dodano `ttk` i `json` do importów

### Nowe okno podglądu (PreviewWindow):
- **Rozmiar:** 900x650 pixels
- **Layout:** Notebook z 2 zakładkami
- **Tab 1:** Kolumny - Treeview 4 kolumny
- **Tab 2:** Parametry - Treeview 5 kolumn + checkbox logic
- **Footer:** Przycisk export + status label + zamknij
- **Interakcja:** Click na wiersz parametru → toggle ☐/☑

---

## 🚀 Użycie

### Podstawowy workflow:
```powershell
cd "d:\ERP SOLUTIONS\docs\python"
python -m bi_converter --gui
```

1. Wybierz plik SQL
2. Kliknij "Podgląd metadanych"
3. Przejrzyj kolumny i parametry
4. Zaznacz/odznacz według potrzeb
5. (Opcjonalnie) Kliknij "Eksportuj konfigurację"
6. Zamknij podgląd
7. Kliknij "Konwertuj"

### CLI bez zmian:
```powershell
python -m bi_converter "raport.sql"
```

---

## 📊 Statystyki

### Kod:
- **gui.py:** 89 linii → 374 linie (+285 linii, +320%)
- **converter.py:** 526 linii → 528 linii (+2 linie, fix)
- **README.md:** Rozszerzono o ~50 linii
- **QUICK_START.md:** Rozszerzono o ~40 linii

### Funkcje:
- **Nowe klasy:** 1 (PreviewWindow)
- **Nowe metody:** 6 (_build_ui, _build_columns_tab, _build_parameters_tab, _toggle_param_interactive, _export_config, _preview)
- **Nowe testy:** 6 scenariuszy walidacyjnych

### Zależności:
- **Brak nowych zależności** - używa tylko standardowej biblioteki Python
- Tkinter (już wymagany)
- ttk (część Tkinter)
- json (standardowa biblioteka)

---

## 🔄 Backward Compatibility

✅ **Pełna kompatybilność wsteczna**

- CLI działa identycznie jak v2.0
- Converter API bez zmian
- Stary workflow (bez podglądu) nadal działa
- Config.json format bez zmian
- XML output format bez zmian

**Migration:** Brak - wystarczy użyć nowej wersji

---

## 🐛 Znane problemy

### Minor issues:
- Unit test discovery na Windows - workaround: end-to-end testing ✅
- Preview window nie ma resize constraints - może być zbyt mała na bardzo małych ekranach

### Planned fixes:
- Brak (wszystko działa zgodnie z wymaganiami)

---

## 💡 Przyszłe usprawnienia (opcjonalne)

1. Batch preview - podgląd wielu plików jednocześnie
2. Column filtering w preview - ukryj techniczne kolumny
3. Parameter search/filter - dla raportów z >50 parametrami
4. Config templates - DEV/PROD/TEST presets
5. Visual diff - porównanie przed/po zmianie config
6. Export preview to Excel/CSV

---

## 📞 Wsparcie

**Problem?** Sprawdź:
1. `logs/app.log` - szczegółowe logi
2. `python/QUICK_START.md` - najczęstsze problemy
3. `python/README.md` - pełna dokumentacja

**Pytania?** CTI Support

---

**Koniec changelog v2.1**
