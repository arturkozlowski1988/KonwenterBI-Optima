/*
* Raport Księgowości (KP) 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--Połączenie do tabeli operatorów
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @bazaFirmowa varchar(max);
DECLARE @Operatorzy varchar(max), @sql varchar(max);
DECLARE @Bazy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]'  
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

SET @sql=
'SELECT BAZ.Baz_Nazwa [Baza Firmowa], 
    CASE 
     WHEN (MONTH(KPR_DataOpe) = MONTH(GETDATE())-1) AND (YEAR(KPR_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN ((MONTH(KPR_DataOpe) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(KPR_DataOpe) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Operacji Miesiąc Poprzedni],
   CASE 
     WHEN (MONTH(KPR_DataOpe) = MONTH(GETDATE())) AND (YEAR(KPR_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Operacji Miesiąc Bieżący],
    KPR_Dokument AS [Dokument Numer], 
    KPR_Kategoria AS [Kategoria Opis], CASE WHEN KPR_Bufor = 0  THEN ''KPiR Księga'' ELSE ''KPiR Bufor'' END AS [KPiR Księga/KPiR Bufor], 
    CASE WHEN Kategorie.Kat_KodSzczegol IS NULL THEN ''(PUSTA)'' ELSE Kategorie.Kat_KodSzczegol END AS [Kategoria Szeczegółowa],
    CASE WHEN Kategorie.Kat_KodOgolny IS NULL THEN ''(PUSTA)'' ELSE Kategorie.Kat_KodOgolny END AS [Kategoria Ogólna],
    ISNULL(op1.Ope_Kod, ''(NIEPRZYPISANY)'') AS [Operator Wprowadzający], ISNULL(op2.Ope_Kod, ''(NIEPRZYPISANY)'') AS [Operator Modyfikujący],
    CASE WHEN KPR_PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN KPR_PodmiotTyp = 2 THEN ''Bank''
         WHEN KPR_PodmiotTyp = 3 THEN ''Pracownik''
         WHEN KPR_PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN KPR_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END AS [Podmiot Pierwotny Typ], 
    Podmioty.Pod_Kod AS [Podmiot Pierwotny Kod], 
    Podmioty.Pod_Nazwa1 AS [Podmiot Pierwotny Nazwa], 
    Podmioty.Pod_NIP AS [Podmiot Pierwotny NIP],    
    Podmioty.Pod_Kraj AS [Podmiot Pierwotny Kraj],
    Podmioty.Pod_Wojewodztwo AS [Podmiot Pierwotny Województwo], Podmioty.Pod_Powiat AS [Podmiot Pierwotny Powiat], Podmioty.Pod_Gmina AS [Podmiot Pierwotny Gmina],
    Podmioty.Pod_Miasto AS [Podmiot Pierwotny Miasto],
    CASE WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
        WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
        WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik''
        WHEN pod5.Pod_PodmiotTyp = 4 THEN ''Wspólnik''
        WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END AS [Podmiot Typ], 
    pod5.Pod_Nazwa1 [Podmiot Nazwa], 
    pod5.Pod_Kod [Podmiot Kod], 
    ISNULL(NULLIF(pod5.Pod_NIP, ''''),''(BRAK)'') [Podmiot NIP],
    pod5.Pod_Kraj AS [Podmiot Kraj],
    ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Podmiot Województwo],
    "Podmiot Powiat" = CASE WHEN pod5.Pod_Powiat = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Powiat END,
    "Podmiot Gmina" = CASE WHEN pod5.Pod_Gmina = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Gmina END, 
    ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Podmiot Miasto],
    isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
    isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],
    KPR_Sprzedaz AS [Sprzedaż], KPR_Pozostale AS [Pozostałe Przychody], KPR_Towary AS [Zakup Towarów], 
    KPR_Uboczne AS [Koszty Uboczne], KPR_Reklama AS [Reklama],  KPR_Wynagrodz AS [Wynagrodzenia], KPR_Inne AS [Pozostałe Koszty], KPR_Zaszlosci AS [Zaszłości],
    KPR_Sprzedaz + KPR_Pozostale AS [Przychód],  KPR_Towary + KPR_Uboczne + KPR_Reklama + KPR_Wynagrodz + KPR_Inne AS [Rozchód], 
    (KPR_Sprzedaz + KPR_Pozostale) - (KPR_Towary + KPR_Uboczne + KPR_Reklama + KPR_Wynagrodz + KPR_Inne) AS [Saldo] 
    /*
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), KPR_DataOpe, 111), ''/'', ''-'') AS [Data Operacji]
    */
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), KPR_DataOpe, 111), ''/'', ''-'') AS [Data Operacji Dzień], YEAR(KPR_DataOpe) AS [Data Operacji Rok]
    ,DATEPART(quarter, KPR_DataOpe) AS [Data Operacji Kwartał]
    ,MONTH(KPR_DataOpe) AS [Data Operacji Miesiąc]
    ,(datepart(DY, datediff(d, 0, KPR_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, KPR_DataOpe)*/ [Data Operacji Tydzień Roku]
    ,GETDATE() [Data Analizy]

    ----------KONTEKSTY
    ,20121 [Dokument Numer __PROCID__KP__], KPR_KPRID [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,20201 [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], Podmioty.Pod_PodId [Podmiot Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__]
    ,20201 [Podmiot Pierwotny Nazwa __PROCID__], Podmioty.Pod_PodId [Podmiot Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Nazwa __DATABASE__]
    ,20201 [Podmiot Nazwa __PROCID__], pod5.Pod_PodId [Podmiot Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Nazwa __DATABASE__]
    ,20201 [Podmiot Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Podmiot Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Kod __DATABASE__]

FROM CDN.ZapisyKPR
    LEFT OUTER JOIN CDN.PodmiotyView Podmioty ON KPR_PodID = Podmioty.Pod_PodId AND KPR_PodmiotTyp = Podmioty.Pod_PodmiotTyp
    LEFT OUTER JOIN CDN.Kategorie Kategorie ON KPR_KatID = Kategorie.Kat_KatID
    LEFT JOIN ' + @Operatorzy + ' op1 ON KPR_OpeZalID = op1.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' op2 ON KPR_OpeModID = op2.Ope_OpeId
    LEFT OUTER JOIN cdn.PodmiotyView pod5 on Podmioty.Pod_GlID = pod5.Pod_PodId and Podmioty.Pod_GlKod = pod5.Pod_Kod
    LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = KPR_ZakID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
WHERE
    KPR_Skreslony = 0'

EXEC(@sql)













