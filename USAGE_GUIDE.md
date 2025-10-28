# 📖 Comarch BI Converter v2.1 - Kompletny przewodnik użytkownika

## 🎯 Co robi ten program?

Konwertuje raporty SQL (T-SQL) na format XML do importu w **Comarch Analizy BI**.

**Automatycznie wykrywa:**
- ✅ Kolumny raportu (aliasy AS [Nazwa])
- ✅ Parametry interaktywne (które użytkownik może edytować)
- ✅ Typy danych (liczba/tekst/data)
- ✅ Formaty i agregacje

---

## 🚀 Szybki start (3 minuty)

### Krok 1: Otwórz GUI
```powershell
cd "d:\ERP SOLUTIONS\docs\python"
python -m bi_converter --gui
```

### Krok 2: Wybierz plik
![GUI Main](Kliknij "Wybierz..." i wskaż plik .sql)

**🆕 Nowość v2.4.1: Wieloplikowa konwersja**
- Użyj **Shift** lub **Ctrl** aby wybrać wiele plików SQL
- GUI pokaże: "X plików wybranych"
- Wszystkie pliki zostaną połączone w **jeden XML**
- Każdy plik = jeden raport w XML

### Krok 3A: Szybka konwersja (bez podglądu)
```
1. Sprawdź ustawienia połączenia (domyślnie OK)
2. Wybierz "Tryb połączenia":
  - auto: program sam zdecyduje czy dodać serwer/bazę do XML (gdy SQL używa kwalifikacji bazy/serwera)
  - embedded: zawsze wpisz serwer i bazę do XML (wymuszone połączenie)
  - default: nie wpisuj połączenia – BI użyje domyślnego połączenia środowiska
3. Kliknij "Konwertuj"
4. Gotowe! XML obok pliku SQL
```

### Krok 3B: Z podglądem (ZALECANE dla nowych raportów)
```
1. Kliknij "🔍 Podgląd metadanych"
   
   🆕 Dla wielu plików: Interfejs zakładkowy!
   - Każdy plik SQL = osobna zakładka
   - Tytuł okna: "Podgląd metadanych - X plików"
   - Przełączaj się między plikami aby zobaczyć ich metadane
   
2. Sprawdź zakładkę "Kolumny" - czy wszystkie są?
3. Sprawdź zakładkę "Parametry" - czy zaznaczenie OK?
4. Jeśli trzeba, kliknij na parametr aby zmienić ☐/☑
5. (Opcjonalnie) Użyj przycisków "💾 Eksportuj konfigurację" dla każdego pliku osobno
6. Zamknij podgląd
7. Kliknij "Konwertuj"
```

---

## 🔍 Podgląd metadanych - szczegóły

### Co widzisz w podglądzie?

**Zakładka "Kolumny (X)":**
```
┌─────────────────────┬──────────┬────────┬───────────┐
│ Nazwa kolumny       │ Typ      │ Format │ Agregacja │
├─────────────────────┼──────────┼────────┼───────────┤
│ Kod produktu        │ attribute│        │           │
│ Nazwa produktu      │ attribute│        │           │
│ Ilość sprzedana     │ measure  │ n2     │ Sum       │
│ Wartość brutto      │ measure  │ n2     │ Sum       │
└─────────────────────┴──────────┴────────┴───────────┘
```

**Zakładka "Parametry (Y)":**
```
┌──────────────┬─────────────────┬────────┬──────────┬───────────┐
│ Interaktywny │ Nazwa parametru │ Typ    │ Wartość  │ Źródło    │
├──────────────┼─────────────────┼────────┼──────────┼───────────┤
│ ☑            │ PARAMROKZAKUPU  │ Liczba │ 2024     │ DECLARE   │
│ ☐            │ DATADOANALIZY   │ Data   │ GETDATE()│ DECLARE   │
│ ☐            │ BAZAFIRMOWA     │ Tekst  │ 'ULEX'   │ DECLARE   │
└──────────────┴─────────────────┴────────┴──────────┴───────────┘
```

### Co oznacza zaznaczenie ☑/☐?

- **☑ Zaznaczony** = Parametr INTERAKTYWNY
  - Użytkownik będzie mógł go edytować przed uruchomieniem raportu w BI
  - Pojawi się okno z polem do wpisania wartości
  - Przykład: rok do analizy, data od/do, kod magazynu

- **☐ Odznaczony** = Parametr NIEINTERAKTYWNY
  - Wartość jest stała (z DECLARE lub domyślna)
  - Użytkownik NIE zobaczy tego parametru w BI
  - Przykład: nazwa bazy, dzisiejsza data, stałe techniczne

### Jak zmienić zaznaczenie?

**Krok 1:** Kliknij na wiersz parametru w tabeli  
**Efekt:** ☐ zmienia się na ☑ (lub odwrotnie)  
**Krok 2:** Kliknij ponownie aby przełączyć z powrotem

---

## 💾 Eksport konfiguracji - po co i jak?

### Po co eksportować?

**Scenariusz:** Masz 10 podobnych raportów z tymi samymi parametrami.

**Bez exportu:**
- Dla każdego raportu musisz klikać podgląd i zaznaczać te same parametry
- Czasochłonne i podatne na błędy

**Z exportem:**
1. Pierwszy raport: ustaw parametry w podglądzie
2. Kliknij "💾 Eksportuj konfigurację"
3. Następne raporty: automatycznie używają tej samej konfiguracji
4. Oszczędność czasu!

### Jak eksportować?

**Krok 1:** W oknie podglądu ustaw parametry według potrzeb  
**Krok 2:** Kliknij "💾 Eksportuj konfigurację do config.json"  
**Krok 3:** Pojawi się komunikat:
```
Konfiguracja zapisana:
D:\ERP SOLUTIONS\docs\python\bi_converter\config.json

Include: 1 parametrów
Exclude: 2 parametrów
```

**Krok 4:** Od teraz wszystkie konwersje używają tej konfiguracji!

### Co jest zapisywane w config.json?

**Przykład:**
```json
{
  "interactive_overrides": {
    "include": [
      "DATAPOCZATEKROKU"
    ],
    "exclude": [
      "BAZAFIRMOWA",
      "DZISIEJSZADATA"
    ]
  }
}
```

**Wyjaśnienie:**
- **include**: parametry które program NIE wykrył automatycznie, ale TY chcesz aby były interaktywne
- **exclude**: parametry które program wykrył automatycznie, ale TY chcesz aby NIE były interaktywne

### Jak wyedytować config.json ręcznie?

**Krok 1:** Otwórz `python/bi_converter/config.json` w edytorze  
**Krok 2:** Dodaj/usuń nazwy parametrów w listach include/exclude  
**Krok 3:** Zapisz plik  
**Krok 4:** Następna konwersja użyje nowej konfiguracji

**Wskazówka:** Nazwy parametrów muszą być WIELKIE LITERY (jak w SQL)

---

## 🎨 Przykładowe scenariusze

### Scenariusz 1: Pierwszy raz konwertuję raport

**Cel:** Sprawdzić czy wszystko jest OK przed importem do BI

**Workflow:**
```
1. python -m bi_converter --gui
2. Wybierz raport.sql
3. Kliknij "Podgląd metadanych"
4. Zakładka "Kolumny":
   - Czy są wszystkie kolumny? (np. 24 kolumny)
   - Czy typy są OK? (measure dla liczb, attribute dla opisów)
5. Zakładka "Parametry":
   - Czy parametry interaktywne są zaznaczone? (np. ROK, DATA_OD)
   - Czy parametry techniczne są odznaczone? (np. BAZAFIRMOWA)
6. Jeśli wszystko OK → Zamknij podgląd → Konwertuj
7. Importuj XML do Comarch BI
8. Test: uruchom raport, sprawdź czy działa
```

### Scenariusz 2: Raport ma za dużo parametrów interaktywnych

**Problem:** Program wykrył 10 parametrów jako interaktywne, ale tylko 3 powinny być

**Rozwiązanie:**
```
1. Otwórz podgląd metadanych
2. Zakładka "Parametry"
3. Kliknij na parametry które NIE powinny być interaktywne (☑ → ☐)
4. Przykład: odznacz BAZAFIRMOWA, DZISIEJSZADATA, INPUT
5. Kliknij "Eksportuj konfigurację" (aby zapamiętać)
6. Zamknij → Konwertuj
7. Następne podobne raporty będą używać tej konfiguracji
```

### Scenariusz 3: Raport bez parametrów (tylko dane)

**Cel:** Prosty raport z danymi, bez możliwości filtrowania

**Workflow:**
```
1. Wybierz raport.sql
2. (Opcjonalnie) Otwórz podgląd → zakładka "Parametry"
3. Jeśli są parametry: odznacz wszystkie ☐
4. Konwertuj
5. W Comarch BI raport uruchomi się od razu bez pytania o parametry
```

### Scenariusz 4: Batch - 20 podobnych raportów

**Cel:** Szybka konwersja wielu raportów z tą samą konfiguracją

**Workflow:**
```
1. Pierwszy raport:
   - Otwórz podgląd
   - Ustaw parametry
   - Eksportuj konfigurację
   - Konwertuj

2. Następne 19 raportów:
   - Wybierz plik
   - Konwertuj (bez podglądu, używa zapisanej konfiguracji)
   - Powtórz dla każdego pliku
```

**Wskazówka:** Można zautomatyzować przez CLI:
```powershell
foreach ($file in Get-ChildItem *.sql) {
    python -m bi_converter $file.FullName
}
```

### Scenariusz 5: Różne środowiska (DEV/TEST/PROD)

**Cel:** Różne ustawienia połączenia dla różnych środowisk

**Opcja A - GUI:**
```
DEV:  Server: DEVSERVER\SQL01,  Database: CDN_DEV
TEST: Server: TESTSERVER\SQL02, Database: CDN_TEST
PROD: Server: PRODSERVER\SQL03, Database: CDN_PROD

Zmień wartości w GUI przed konwersją
```

**Opcja B - CLI:**
```powershell
# DEV
python -m bi_converter raport.sql --server "DEVSERVER\SQL01" --database "CDN_DEV" --conn-mode embedded

# PROD
python -m bi_converter raport.sql --server "PRODSERVER\SQL03" --database "CDN_PROD" --conn-mode embedded
```

### Kiedy który tryb połączenia?

- auto (domyślny): bezpieczny – jeśli SQL zawiera odwołania typu [Serwer].[Baza].[CDN].Tabele lub 3/4-członowe nazwy, program doda połączenie; w przeciwnym razie pozostawi puste i BI użyje połączenia domyślnego.
- embedded: wymuś konkretne połączenie w raporcie – przydatne gdy raport ma działać niezależnie od domyślnego połączenia BI albo SQL używa wielobazowych referencji.
- default: nie dodawaj połączenia do XML – polegaj na domyślnym połączeniu skonfigurowanym w BI. Dobre dla raportów "czystych" bez kwalifikacji bazy/serwera.

---

## ⚠️ Częste problemy i rozwiązania

### Problem 1: "Brak elementu głównego" przy imporcie XML

**Przyczyna:** Używasz starej wersji konwertera

**Rozwiązanie:**
```powershell
# ✅ POPRAWNIE - nowa wersja
cd "d:\ERP SOLUTIONS\docs\python"
python -m bi_converter raport.sql

# ❌ ŹLE - stara wersja
python comarch_bi_converter.py raport.sql
```

### Problem 2: Brak kolumn w podglądzie (0 kolumn wykrytych)

**Przyczyna:** SQL nie używa aliasów AS [Nazwa]

**Sprawdź SQL:**
```sql
-- ❌ ŹLE (nie wykryje)
SELECT TwrKod, TwrNazwa, SUM(IleSpr)
FROM ...

-- ✅ DOBRZE (wykryje 3 kolumny)
SELECT 
    TwrKod AS [Kod produktu],
    TwrNazwa AS [Nazwa produktu],
    SUM(IleSpr) AS [Ilość sprzedana]
FROM ...
```

**Rozwiązanie:** Dodaj aliasy AS [Nazwa] w zapytaniu SQL

### Problem 3: Parametr nie wykrywa się automatycznie

**Przyczyna:** Nie pasuje do wzorców PARAM* lub PRZEDZIAL*

**Przykład:**
```sql
DECLARE @RokDoAnalizy INT = 2024  -- Nie wykryje (nie zaczyna się od PARAM)
DECLARE @PARAMROK INT = 2024       -- Wykryje (PARAM*)
```

**Rozwiązanie:**
1. Otwórz podgląd
2. Znajdź parametr na liście
3. Kliknij aby zaznaczyć ☑
4. Eksportuj konfigurację

### Problem 4: Za wolna konwersja

**Pytanie:** Czy muszę zawsze otwierać podgląd?

**Odpowiedź:** NIE!
- Podgląd jest opcjonalny
- Potrzebny tylko gdy:
  - Pierwszy raz konwertujesz dany typ raportu
  - Coś nie działa i chcesz sprawdzić co wykryto
  - Chcesz zmienić konfigurację
- Dla rutynowych konwersji: Wybierz plik → Konwertuj

### Problem 5: Config.json nie działa

**Sprawdź:**
```
1. Czy plik istnieje?
   → D:\ERP SOLUTIONS\docs\python\bi_converter\config.json

2. Czy format JSON jest poprawny?
   → Otwórz w edytorze, sprawdź nawiasy i przecinki

3. Czy nazwy parametrów są WIELKIE LITERY?
   → "PARAMROK" ✅ nie "paramrok" ❌

4. Czy program wczytuje config?
   → Sprawdź logi: logs/app.log
   → Szukaj: "Loaded config from ..."
```

---

## 📊 Logi i diagnostyka

### Gdzie są logi?

**Lokalizacja:** `d:\ERP SOLUTIONS\docs\logs\app.log`

**Format:**
```
2025-10-18 15:30:12 | INFO | bi-converter | Logger initialized
2025-10-18 15:30:12 | INFO | bi-converter | Loaded config from D:\...\config.json
2025-10-18 15:30:12 | INFO | bi-converter | Converting file: raport.sql
2025-10-18 15:30:12 | INFO | bi-converter | Detected 24 columns
2025-10-18 15:30:12 | INFO | bi-converter | Detected 4 parameters (declared: 4, inferred: 0)
2025-10-18 15:30:12 | INFO | bi-converter | Interactive params selected: ['PARAMROKZAKUPU']
2025-10-18 15:30:13 | INFO | bi-converter | Wrote XML: raport.xml
```

### Co sprawdzać w logach?

**1. Wykryto kolumny:**
```
INFO | Detected 24 columns
```
Jeśli 0 → brak aliasów AS [Nazwa] w SQL

**2. Wykryto parametry:**
```
INFO | Detected 4 parameters (declared: 4, inferred: 0)
```
- declared: parametry z DECLARE
- inferred: parametry użyte ale nie zadeklarowane

**3. Parametry interaktywne:**
```
INFO | Interactive params selected: ['PARAMROKZAKUPU']
```
Sprawdź czy lista się zgadza z oczekiwaniami

**4. Błędy:**
```
ERROR | Conversion error: File not found
ERROR | Failed to parse SQL
```
Szczegóły problemu + stack trace

### Rotacja logów

- Maksymalny rozmiar: 1 MB
- Kopie zapasowe: 3 (app.log.1, app.log.2, app.log.3)
- Automatyczne czyszczenie starych logów

---

## 🔧 Zaawansowane

### CLI - wszystkie opcje

```powershell
# Podstawowe użycie
python -m bi_converter "raport.sql"

# Z custom ustawieniami
python -m bi_converter "raport.sql" \
    --server "SERWEROPTIMA\SUL02" \
    --database "CDN_Ulex_2018" \
  --name "Ulex_2018" \
  --conn-mode auto

# Z custom config
python -m bi_converter "raport.sql" \
    --config "path/to/custom_config.json"

# GUI
python -m bi_converter --gui
```

Uwaga: Domyślny tryb połączenia można też ustawić w config.json:

```json
{
  "connection": { "mode": "auto" }
}
```

### Batch processing (PowerShell)

**Konwersja wszystkich .sql w folderze:**
```powershell
cd "d:\ERP SOLUTIONS\docs\Customers\ULEX\Analizy Bi"

Get-ChildItem -Filter *.sql | ForEach-Object {
    Write-Host "Converting: $($_.Name)"
    python -m bi_converter $_.FullName
}

Write-Host "Done! Converted $((Get-ChildItem -Filter *.xml).Count) files"
```

**Z walidacją:**
```powershell
$errors = @()

Get-ChildItem -Filter *.sql | ForEach-Object {
    try {
        python -m bi_converter $_.FullName 2>&1 | Out-Null
        Write-Host "✅ $($_.Name)" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($_.Name)" -ForegroundColor Red
        $errors += $_.Name
    }
}

if ($errors.Count -gt 0) {
    Write-Host "`nErrors in:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" }
}
```

---

## 💡 Porady

### Dobre praktyki:

1. **Pierwszy raz:** Zawsze użyj podglądu dla nowego typu raportu
2. **Batch:** Ustaw config raz, konwertuj wiele bez podglądu
3. **Nazwy:** Używaj opisowych nazw dla parametrów (PARAMROK, nie @X)
4. **Aliasy:** Zawsze używaj AS [Nazwa czytelna] dla kolumn
5. **Testy:** Zawsze testuj pierwszy skonwertowany raport w BI przed masową konwersją

### Optymalizacja:

- GUI szybszy dla 1-5 plików (wizualna kontrola)
- CLI szybszy dla >5 plików (batch processing)
- Preview potrzebny ~raz na typ raportu (potem używaj config)

### Bezpieczeństwo:

- Config.json NIE zawiera haseł (używa domyślnego połączenia BI)
- Logi NIE zawierają danych wrażliwych (tylko struktury)
- Oryginalne pliki .sql NIE są modyfikowane (XML tworzone obok)

---

## 📞 Pomoc i wsparcie

**Szybkie rozwiązania:**
1. Sprawdź `QUICK_START.md` - najczęstsze problemy
2. Sprawdź `logs/app.log` - szczegółowe informacje o błędach
3. Sprawdź `README.md` - pełna dokumentacja techniczna
4. Sprawdź `CHANGELOG_v2.1.md` - lista zmian i poprawek

**Pytania? Problemy?**
→ CTI Support

---

**Wersja:** 2.1  
**Data:** 2025-10-18  
**Autor:** CTI Support (Claudette AI)

**Powodzenia z konwersjami! 🚀**
