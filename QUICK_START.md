# 🚀 Comarch BI Converter - Szybki Start

## Instalacja

**Wymagania:** Python 3.7+ (bez dodatkowych bibliotek)

Projekt gotowy do użycia - wystarczy Python!

---

# Wersja portable .exe

Jak przekazać koledze:
1. Wymagania: Windows 10/11, **brak potrzeby instalacji Pythona**
2. W folderze `dist` znajdziesz plik `ComarchBIConverter.exe` (gotowy do uruchomienia)
3. Przekaż plik `ComarchBIConverter.exe` koledze (np. przez mail, Teams, dysk sieciowy)
4. Kolega **dwuklikiem otwiera plik** – automatycznie uruchamia się GUI
5. Lub uruchamia przez cmd/powershell:
   - `ComarchBIConverter.exe` (tryb graficzny - domyślnie)
   - `ComarchBIConverter.exe --gui` (tryb graficzny - jawnie)
   - `ComarchBIConverter.exe "ścieżka\do\raportu.sql" --conn-mode embedded ...` (tryb CLI)

**Wszystkie funkcje działają bez instalacji!** ✅
- ✅ GUI z podglądem metadanych
- ✅ CLI dla automatyzacji
- ✅ Zapamiętywanie ustawień (server, baza, nazwa połączenia)
- ✅ Tryb debug z szczegółowymi logami
- ✅ Obsługa różnych kodowań (UTF-8, cp1250)
- ✅ Konwersja SQL → XML w kilka kliknięć

Jeśli pojawią się problemy:
- Sprawdź logi: `d:\ERP SOLUTIONS\docs\logs\app.log`
- Upewnij się, że plik .exe ma dostęp do plików SQL
- Zweryfikuj połączenie do bazy danych

Wersja portable: v2.1 | Data: 2025-10-18 | Status: ✅ Testowane i gotowe do dystrybucji
- ✅ Naprawiono błędy argparse dla --windowed w PyInstaller
- ✅ Pełna obsługa GUI, CLI, zapamiętywania ustawień, debugowania

---

## 📋 Krok 1: Konwersja pierwszego raportu

### Metoda A: GUI z podglądem (ZALECANA) ✨

```powershell
cd "d:\ERP SOLUTIONS\docs\python"
python -m bi_converter --gui
```

**Workflow:**
1. Kliknij **"Wybierz..."** i wskaż plik .sql
2. Kliknij **"🔍 Podgląd metadanych"** aby zobaczyć:
   - ✅ Wszystkie wykryte kolumny
   - ✅ Wszystkie parametry z automatycznym zaznaczeniem interaktywnych
3. **Opcjonalnie:** Kliknij na parametry aby zmienić ☐/☑ (interaktywny/nie)
4. **Opcjonalnie:** Kliknij **"💾 Eksportuj konfigurację"** aby zapisać swój wybór
5. Zamknij podgląd i kliknij **"⚙️ Konwertuj"**
6. Gotowe! XML jest obok pliku SQL

**Skróty klawiaturowe:**
- Ctrl+P → Podgląd metadanych
- Ctrl+Enter (także Enter z klawiatury numerycznej) → Konwertuj

**Zapamiętywanie ustawień:**
- Program zapamiętuje ostatnio użyte: Serwer, Bazę, Nazwę połączenia, Tryb połączenia oraz ostatnią ścieżkę do pliku SQL.
- Ustawienia są zapisywane do `python/bi_converter/settings.json` i wczytywane przy starcie.

**Tryb debug:**
- Zaznacz opcję „Tryb debug (szczegółowe logi)”, aby zwiększyć szczegółowość logów.
- Flaga debug jest zapamiętywana w `settings.json` między uruchomieniami.

### Metoda B: GUI bez podglądu (szybka)

1. Wybierz plik SQL
2. Sprawdź/popraw dane połączenia (domyślnie: SERWEROPTIMA\SUL02)
3. Kliknij **"Konwertuj"**
4. Gotowe!

### Metoda C: Linia komend

```powershell
cd "d:\ERP SOLUTIONS\docs\python"
python -m bi_converter "ścieżka\do\raportu.sql"
```

**Tryby połączenia (CLI):**
- `--conn-mode default` → korzysta z domyślnego połączenia BI (connections pusty)
- `--conn-mode embedded` → wpisuje serwer/bazę do XML (useDefaultConnection=false)
- `--conn-mode auto` (domyślnie) → wykrywa potrzebę embed w oparciu o treść SQL

Przykłady:
```powershell
# embedowane połączenie do testowej bazy
python -m bi_converter "raport.sql" --conn-mode embedded --server TESTSRV\\SQLEXPRESS --database CDN_Test --name TEST_CONN

# wymuszenie default (bez sekcji connections)
python -m bi_converter "raport.sql" --conn-mode default
```

## ⚡ Najczęstsze problemy

### Błąd "Brak elementu głównego"
✅ Naprawione w v2.0! Użyj: `python -m bi_converter` (nowa wersja)
❌ NIE używaj: `python comarch_bi_converter.py` (stara wersja)

### Za dużo/mało parametrów interaktywnych

**Opcja 1: GUI (najłatwiejsza) ✨**
1. Otwórz podgląd metadanych
2. Kliknij na parametry aby zaznaczyć/odznaczyć ☐/☑
3. Kliknij "Eksportuj konfigurację"

**Opcja 2: Ręcznie**
Edytuj `python/bi_converter/config.json`:
```json
{
  "interactive_overrides": {
Sprawdź: `d:\ERP SOLUTIONS\docs\logs\app.log`
    "exclude": ["PARAM_KTORY_NIE_MA_BYC_INTERAKTYWNY"]
  },
  "well_known_params": ["DATAOD", "DATADO"],
  "param_defaults": { "DATAOD": "2025-01-01", "DATADO": "2025-12-31" }
}
```

### Brak kolumn w podglądzie
⚠️ Sprawdź czy zapytanie SQL używa aliasów:
- ✅ Poprawnie: `SELECT column AS [Nazwa Kolumny]`
- ❌ Źle: `SELECT column` (bez aliasu)

### Parametr nie wykrywa się automatycznie
💡 Dodaj ręcznie w podglądzie:
1. Otwórz podgląd → zakładka "Parametry"
2. Znajdź parametr na liście
3. Kliknij aby zaznaczyć ☑
4. Eksportuj konfigurację

## � Logi
Sprawdź: `d:\ERP SOLUTIONS\docs\logs\app.log`

---

## 🎯 Przykładowe scenariusze

### Scenariusz 1: Pierwszy raport - sprawdzenie co wykryto
```
1. Wybierz plik SQL
2. Kliknij "Podgląd metadanych"
3. Sprawdź zakładki:
   - "Kolumny (X)" - lista wszystkich wykrytych kolumn
   - "Parametry (Y)" - lista parametrów z zaznaczonymi interaktywnymi
4. Jeśli wszystko OK, zamknij i kliknij "Konwertuj"
```

### Scenariusz 2: Dostosowanie parametrów dla wielu raportów
```
1. Otwórz pierwszy raport w podglądzie
2. Zaznacz/odznacz parametry według potrzeb
3. Kliknij "Eksportuj konfigurację" → zapisuje config.json
4. Konwertuj kolejne raporty - będą używać tej samej konfiguracji
5. W razie potrzeby edytuj config.json ręcznie
```

### Scenariusz 3: Raport bez parametrów (tylko dane)
```
1. Wybierz plik SQL
2. Kliknij "Konwertuj" (podgląd opcjonalny)
3. W Comarch BI raport zadziała bez pytania o parametry
4. ✅ Pustych MdxParams nie powoduje już błędu!
```

---

**Wersja:** 2.1 | **Autor:** CTI Support
