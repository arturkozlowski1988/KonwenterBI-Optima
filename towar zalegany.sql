
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
SET LOCK_TIMEOUT 15000;
-- ============================================
-- INICJALIZACJA ZMIENNYCH (nie edytuj)
-- ============================================
DECLARE @DataDoAnalizy DATE = CAST(GETDATE() AS DATE);

-- Obsługa parametru miesiąca (0 lub NULL = cały rok)
DECLARE @MiesiacOd INT = CASE WHEN @ParamMiesiacZakupu BETWEEN 1 AND 12 THEN @ParamMiesiacZakupu ELSE 1 END;
DECLARE @MiesiacDo INT = CASE WHEN @ParamMiesiacZakupu BETWEEN 1 AND 12 THEN @ParamMiesiacZakupu ELSE 12 END;

DECLARE @DataPoczatekRoku DATE = DATEFROMPARTS(@ParamRokZakupu, @MiesiacOd, 1);
DECLARE @DataKoniecRoku DATE = EOMONTH(DATEFROMPARTS(@ParamRokZakupu, @MiesiacDo, 1));

-- ============================================
-- GŁÓWNE ZAPYTANIE
-- ============================================
WITH
    -- Zakupy w analizowanym roku
    ZakupyWRoku
    AS
    (
        SELECT
            te.TrE_TwrId AS TwrId,
            SUM(te.TrE_Ilosc) AS IloscKupiona,
            SUM(te.TrE_WartoscNetto) AS WartoscKupiona,
            MIN(tn.TrN_DataOpe) AS PierwszyZakup,
            MAX(tn.TrN_DataOpe) AS OstatniZakup,
            COUNT(DISTINCT tn.TrN_TrNID) AS LiczbaFakturZakupu
        FROM CDN.TraElem te WITH (NOLOCK)
            JOIN CDN.TraNag tn WITH (NOLOCK) ON tn.TrN_TrNID = te.TrE_TrNId
        WHERE tn.TrN_TypDokumentu = 301 -- Faktury zakupu
            AND tn.TrN_DataOpe >= @DataPoczatekRoku
            AND tn.TrN_DataOpe <= @DataKoniecRoku
            AND tn.TrN_Bufor = 0
            AND tn.TrN_Anulowany = 0
            AND te.TrE_Aktywny = 1
            AND te.TrE_Ilosc > 0
        GROUP BY te.TrE_TwrId
    ),
    -- Sprzedaż od początku roku zakupu do daty analizy
    SprzedazOdRoku
    AS
    (
        SELECT
            te.TrE_TwrId AS TwrId,
            SUM(te.TrE_Ilosc) AS IloscSprzedana,
            SUM(te.TrE_WartoscNetto) AS WartoscSprzedana,
            MIN(tn.TrN_DataOpe) AS PierwszaSprzedaz,
            MAX(tn.TrN_DataOpe) AS OstatniaSprzedaz,
            COUNT(DISTINCT tn.TrN_TrNID) AS LiczbaFakturSprzedazy
        FROM CDN.TraElem te WITH (NOLOCK)
            JOIN CDN.TraNag tn WITH (NOLOCK) ON tn.TrN_TrNID = te.TrE_TrNId
        WHERE tn.TrN_TypDokumentu IN (302, 305) -- Faktury sprzedaży krajowe i eksportowe
            AND tn.TrN_DataOpe >= @DataPoczatekRoku
            AND tn.TrN_DataOpe <= @DataDoAnalizy
            AND tn.TrN_Bufor = 0
            AND tn.TrN_Anulowany = 0
            AND te.TrE_Aktywny = 1
            AND te.TrE_Ilosc > 0
        GROUP BY te.TrE_TwrId
    ),
    -- Aktualny stan magazynowy
    StanMag
    AS
    (
        SELECT
            tz.TwZ_TwrId AS TwrId,
            SUM(tz.TwZ_Ilosc) AS StanIlosc,
            SUM(tz.TwZ_Wartosc) AS StanWartosc
        FROM CDN.TwrZasoby tz WITH (NOLOCK)
        WHERE tz.TwZ_Ilosc > 0
        GROUP BY tz.TwZ_TwrId
    )

SELECT
    @ParamRokZakupu AS [Rok Zakupu],
    CONVERT(VARCHAR(10), @DataDoAnalizy, 23) AS [Data Analizy],

    -- Dane towaru
    t.Twr_Kod AS [Produkt Kod],
    t.Twr_Nazwa AS [Produkt Nazwa],
    t.Twr_Jm AS [Jednostka],

    -- Zakupy w analizowanym roku
    CAST(z.IloscKupiona AS DECIMAL(20, 4)) AS [Zakupiono Ilość],
    CAST(z.WartoscKupiona AS DECIMAL(20, 2)) AS [Zakupiono Wartość Netto],
    z.LiczbaFakturZakupu AS [Liczba Faktur Zakupu],
    CONVERT(VARCHAR(10), z.PierwszyZakup, 23) AS [Pierwszy Zakup w Roku],
    CONVERT(VARCHAR(10), z.OstatniZakup, 23) AS [Ostatni Zakup w Roku],

    -- Sprzedaż od roku zakupu
    CAST(ISNULL(s.IloscSprzedana, 0) AS DECIMAL(20, 4)) AS [Sprzedano Ilość],
    CAST(ISNULL(s.WartoscSprzedana, 0) AS DECIMAL(20, 2)) AS [Sprzedano Wartość Netto],
    ISNULL(s.LiczbaFakturSprzedazy, 0) AS [Liczba Faktur Sprzedaży],
    CONVERT(VARCHAR(10), s.PierwszaSprzedaz, 23) AS [Pierwsza Sprzedaż],
    CONVERT(VARCHAR(10), s.OstatniaSprzedaz, 23) AS [Ostatnia Sprzedaż],

    -- Bilans
    CAST(z.IloscKupiona - ISNULL(s.IloscSprzedana, 0) AS DECIMAL(20, 4)) AS [Niesprzedane Ilość],
    CAST(z.WartoscKupiona - ISNULL(s.WartoscSprzedana, 0) AS DECIMAL(20, 2)) AS [Niesprzedana Wartość],

    -- Procent sprzedaży
    CAST(
        CASE WHEN z.IloscKupiona > 0
             THEN (ISNULL(s.IloscSprzedana, 0) / z.IloscKupiona) * 100
             ELSE 0
        END AS DECIMAL(6, 2)
    ) AS [% Sprzedaży],

    -- Aktualny stan magazynowy
    CAST(ISNULL(sm.StanIlosc, 0) AS DECIMAL(20, 4)) AS [Aktualny Stan Ilość],
    CAST(ISNULL(sm.StanWartosc, 0) AS DECIMAL(20, 2)) AS [Aktualny Stan Wartość],

    -- Klasyfikacja
    CASE
        WHEN s.IloscSprzedana IS NULL THEN 'Bez sprzedaży'
        WHEN s.IloscSprzedana >= z.IloscKupiona THEN 'Sprzedane całkowicie'
        WHEN s.IloscSprzedana > 0 THEN 'Sprzedane częściowo'
        ELSE 'Bez sprzedaży'
    END AS [Status Sprzedaży],

    CASE
        WHEN s.OstatniaSprzedaz IS NOT NULL
        THEN DATEDIFF(DAY, s.OstatniaSprzedaz, @DataDoAnalizy)
        ELSE DATEDIFF(DAY, z.OstatniZakup, @DataDoAnalizy)
    END AS [Dni od Ostatniego Ruchu],

    -- Ocena zalegania
    CASE
        WHEN s.IloscSprzedana IS NULL AND DATEDIFF(DAY, z.OstatniZakup, @DataDoAnalizy) > 365
            THEN 'KRYTYCZNE - Brak sprzedaży ponad rok'
        WHEN s.IloscSprzedana IS NULL AND DATEDIFF(DAY, z.OstatniZakup, @DataDoAnalizy) > 180
            THEN 'WYSOKIE - Brak sprzedaży ponad 6 miesięcy'
        WHEN s.IloscSprzedana IS NULL
            THEN 'ŚREDNIE - Brak sprzedaży'
        WHEN z.IloscKupiona - ISNULL(s.IloscSprzedana, 0) > 0
        AND ISNULL(s.IloscSprzedana, 0) / z.IloscKupiona < 0.25
            THEN 'WYSOKIE - Sprzedano mniej niż 25%'
        WHEN z.IloscKupiona - ISNULL(s.IloscSprzedana, 0) > 0
        AND ISNULL(s.IloscSprzedana, 0) / z.IloscKupiona < 0.50
            THEN 'ŚREDNIE - Sprzedano mniej niż 50%'
        WHEN z.IloscKupiona - ISNULL(s.IloscSprzedana, 0) > 0
            THEN 'NISKIE - Sprzedano ponad 50%'
        ELSE 'OK - Sprzedane całkowicie'
    END AS [Ryzyko Zalegania]

FROM ZakupyWRoku z
    JOIN CDN.Towary t WITH (NOLOCK) ON t.Twr_TwrId = z.TwrId
    LEFT JOIN SprzedazOdRoku s ON s.TwrId = z.TwrId
    LEFT JOIN StanMag sm ON sm.TwrId = z.TwrId

-- POPRAWKA: Pokazuj tylko towary, które FIZYCZNIE zalegają w magazynie
-- Filtr po aktualnym stanie magazynowym zamiast po bilansie zakup-sprzedaż
WHERE ISNULL(sm.StanIlosc, 0) > 0.001
-- tolerancja dla zaokrągleń
-- To pokazuje produkty które NAPRAWDĘ są w magazynie (niezależnie od roku zakupu)

ORDER BY
    [Ryzyko Zalegania] DESC,
    [Niesprzedana Wartość] DESC;

SET NOCOUNT OFF;

