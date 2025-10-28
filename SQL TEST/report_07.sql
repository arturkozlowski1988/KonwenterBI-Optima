/*
* Raport Księgowości (KK) 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @String varchar(1024)
DECLARE @Pos int
CREATE TABLE #Keywords (string varchar(100)) 
DECLARE @Key varchar(100)
SET @String = @OKRESOBRACHUNKOWY
SET @Pos = 1
WHILE (@Pos > 0)
BEGIN
    SET @Pos = PATINDEX('%,%', @String)
    SET @Key = SUBSTRING(@String, 0, @Pos)
    IF (@Pos = 0)
        BEGIN
            INSERT INTO #Keywords (string) VALUES(@String)
        END
    ELSE
        BEGIN
            INSERT INTO #Keywords (string) VALUES(@Key)
        END
    SET @String = SUBSTRING(@String, @Pos+1, (SELECT LEN(@String)))
END 


SELECT *,OOb_OObID oobid INTO  #oob FROM(
SELECT    SUBSTRING(string, 1, CHARINDEX(';', string) - 1) AS year,
    SUBSTRING(string, CHARINDEX(';', string) + 1, LEN(string)) AS db  FROM #Keywords 
  )OB
  JOIN CDN.OkresyObrach ON OOb_Symbol =  year 
  WHERE db = DB_NAME()

  Drop table #Keywords

--Wyliczanie poziomów kont
;WITH g(gid, kod, naz, nazB, parId, poziom, nazwa)
AS
(
      SELECT Acc_AccId, Acc_Segment, Acc_Nazwa,  Acc_Nazwa2, Acc_ParId, Acc_Poziom, convert(nvarchar(1024), Acc_Segment) as nazwa
      FROM CDN.Konta
      WHERE Acc_ParId IS NULL AND Acc_OObId IN (SELECT OOBID From #oob)
      
      UNION ALL
      
      SELECT Acc_AccId, Acc_Segment, Acc_Nazwa, Acc_Nazwa2, Acc_ParId, Acc_Poziom, convert(nvarchar(1024), p.nazwa + N'-' + c.Acc_Segment) as nazwa
      FROM g p
             JOIN CDN.Konta c ON c.Acc_ParId = p.gid 
      WHERE c.Acc_ParId IS NOT NULL AND  C.Acc_OObId IN (SELECT OOBID From #oob)
)     
SELECT * INTO #tmpTwrGr FROM g

DECLARE @poziom int
DECLARE @poziom_max int
DECLARE @sql nvarchar(max)
SELECT @poziom_max = MAX(poziom) FROM #tmpTwrGr
SET @poziom = @poziom_max
SET @sql = N''

WHILE @poziom > 0  
BEGIN
       SET @sql = N'ALTER TABLE #tmpTwrGr ADD Poziom' + CAST(@poziom AS nvarchar) + N' nvarchar(50), ONr' + CAST(@poziom AS nvarchar) + N' nvarchar(50), Nazwa' + CAST(@poziom AS nvarchar) + N' nvarchar(4000), NazwaB' + CAST(@poziom AS nvarchar) + N' nvarchar(4000)' 
    EXEC(@sql)

    
    IF @poziom = @poziom_max 
             BEGIN
                    SET @sql = N'UPDATE #tmpTwrGr
                           SET ONr' + CAST(@poziom AS nvarchar) +  '= parId '
                    EXEC(@sql)
                    
                    SET @sql = N'UPDATE #tmpTwrGr
                           SET Poziom' + CAST(@poziom AS nvarchar) + ' = CASE WHEN ' + CAST(@poziom AS nvarchar) + ' > poziom THEN ''('' + kod + '')'' ELSE kod END'
                    EXEC(@sql)
                    
                    SET @sql = N'UPDATE #tmpTwrGr
                           SET Nazwa' + CAST(@poziom AS nvarchar) + ' = CASE WHEN ' + CAST(@poziom AS nvarchar) + ' > poziom THEN ''('' + naz + '')'' ELSE naz END'
                    EXEC(@sql)

                    SET @sql = N'UPDATE #tmpTwrGr
                           SET NazwaB' + CAST(@poziom AS nvarchar) + ' = CASE WHEN ' + CAST(@poziom AS nvarchar) + ' > poziom THEN ''('' + nazB + '')'' ELSE nazB END'
                    EXEC(@sql)

             END
    ELSE
             BEGIN 
             SET @sql = N'UPDATE c
                           SET c.Poziom' + CAST(@poziom AS nvarchar) + N' = (
                                  CASE WHEN c.poziom =' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.kod AS nvarchar)
                                        WHEN c.poziom <' + CAST(@poziom AS nvarchar) + N' THEN ''('' + CAST(c.kod AS nvarchar) + '')''
                                        WHEN p.poziom <' + CAST(@poziom AS nvarchar) + N' THEN ''('' + CAST(p.kod AS nvarchar) + '')''
                                  ELSE p.kod END)  
                           FROM #tmpTwrGr c
                           LEFT JOIN #tmpTwrGr p
                           ON c.ONr' + CAST(@poziom + 1 AS nvarchar) + '= p.gid '
                    EXEC(@sql)
                    
                    SET @sql = N'UPDATE c
                           SET c.Nazwa' + CAST(@poziom AS nvarchar) + N' = (
                                  CASE WHEN c.poziom =' + CAST(@poziom AS nvarchar) + N' THEN c.naz
                                        WHEN c.poziom <' + CAST(@poziom AS nvarchar) + N' THEN ''('' + c.naz + '')''
                                        WHEN p.poziom <' + CAST(@poziom AS nvarchar) + N' THEN ''('' + p.naz + '')''
                                  ELSE p.naz END)  ,
                                  c.NazwaB' + CAST(@poziom AS nvarchar) + N' = (
                                  CASE WHEN c.poziom =' + CAST(@poziom AS nvarchar) + N' THEN c.nazB
                                        WHEN c.poziom <' + CAST(@poziom AS nvarchar) + N' THEN ''('' + c.nazB + '')''
                                        WHEN p.poziom <' + CAST(@poziom AS nvarchar) + N' THEN ''('' + p.nazB + '')''
                                  ELSE p.nazB END)  
                           FROM #tmpTwrGr c
                           LEFT JOIN #tmpTwrGr p
                           ON c.ONr' + CAST(@poziom + 1 AS nvarchar) + '= p.gid '
                    EXEC(@sql)
       
                    SET @sql = N'UPDATE c
                           SET c.ONr' + CAST(@poziom AS nvarchar) + N' = (
                                  CASE WHEN c.poziom <=' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.parId AS nvarchar)
                                  ELSE CAST(p.parId AS nvarchar) END)  
                           FROM #tmpTwrGr c
                           LEFT JOIN #tmpTwrGr p
                           ON c.ONr' + CAST(@poziom + 1 AS nvarchar) + '= p.gid '
                           EXEC(@sql)
             END
    SET @poziom = @poziom - 1
END

declare @select varchar(max), @select2 varchar(max), @select3 varchar(max);
declare @kolumny varchar(max), @kolumny2 varchar(max);
declare @i int

set @kolumny = ''
set @kolumny2 = ''

set @i=1
if @i<=@poziom_max  
begin
       set @kolumny = ', SUBSTRING(Poz.Poziom1, 1, 1) AS [Konto Grupa]'
       set @kolumny2 = ', [Konto Grupa]'
end
while (@i<=@poziom_max)
begin
       set @kolumny = @kolumny + ', CASE WHEN Poz.Poziom' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' + LTRIM(@i) + ' END [Konto Struktura Poziom ' + LTRIM(@i) + '] ' +
                                                 ', CASE WHEN Poz.Nazwa' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Nazwa' + LTRIM(@i) + ' END [Konto Nazwa Poziom ' + LTRIM(@i) + '] ' +
                                                 ', CASE WHEN Poz.NazwaB' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.NazwaB' + LTRIM(@i) + ' END [Konto Nazwa2 Poziom ' + LTRIM(@i) + '] '
       set @kolumny2 = @kolumny2 + ', [Konto Struktura Poziom ' + LTRIM(@i) + '] ' + ', [Konto Nazwa Poziom ' + LTRIM(@i) + '] ' + ', [Konto Nazwa2 Poziom ' + LTRIM(@i) + '] '
       set @i = @i + 1
end

--Połączenie do tabeli operatorów
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @bazaFirmowa varchar(max);
DECLARE @Operatorzy varchar(max);
DECLARE @Bazy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]'  
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

SET @select = 
'Declare @Wal VarChar(3); Set @Wal = cdn.Waluta('''')
SELECT 
    [Baza Firmowa],
    [Okres Obrachunkowy], 
    [Dokument Numer], 
    [Dokument Element Numer], [Dokument Bufor] [Zatwierdzone/Bufor], [Dziennik], [Dziennik Numer], [Identyfikator Księgowy],  [Konto Pełny Numer], 
    [Konto Przeciwstawne], [Kategoria Szczegółowa z Elementu], [Kategoria Szczegółowa z Nagłówka], [Kategoria Ogólna z Elementu], [Kategoria Ogólna z Nagłówka],
    [Dokument Opis z Elementu], [Dokument Opis z Nagłówka],
    [Podmiot Pierwotny Typ], 
    [Podmiot Pierwotny Kod],    
    [Podmiot Pierwotny Nazwa], 
    [Podmiot Pierwotny NIP],
    [Podmiot Pierwotny Kraj], [Podmiot Pierwotny Województwo], [Podmiot Pierwotny Powiat],  [Podmiot Pierwotny Gmina], [Podmiot Pierwotny Miasto], [Podmiot Pierwotny z Pozycji],
    [Podmiot Typ], [Podmiot Nazwa],
    [Podmiot Kod], 
    [Podmiot NIP],
    [Podmiot Kraj], [Podmiot Województwo],
    [Podmiot Powiat], [Podmiot Gmina],[Podmiot Miasto], [Podmiot z Pozycji],
    [Operator Wprowadzający],[Operator Modyfikujący],  
    [Rodzaj] [Bilans Otwarcia], [Konto Typ] [Typ Konta], [Konto Typy] [Typy Kont], [Kontrola budżetu] [Kontrola Budżetu], [Konto Rozrachunkowe], [Waluta],
    [Obroty Winien] [Obroty Wn], [Obroty Ma], [Obroty Winien Waluta] [Obroty Wn Waluta], [Obroty Ma Waluta],    
    [Bilans Otwarcia Ma], [Bilans Otwarcia Winien] [Bilans Otwarcia Wn], [Bilans Otwarcia Ma Waluta], [Bilans Otwarcia Winien Waluta] [Bilans Otwarcia Wn Waluta],
    [Plan Wn], [Plan Ma] 
    /*
    ----------DATY POINT
    ,[Data Księgowania Dzień]
    ,[Data Wystawienia Dzień]
    ,[Data Operacji Dzień]
    */
    ----------DATY ANALIZY
    ,[Data Księgowania Dzień], [Data Księgowania Rok], [Data Księgowania Kwartał], [Data Księgowania Miesiąc], [Data Księgowania Miesiąc Poprzedni], [Data Księgowania Miesiąc Bieżący]
    ,[Data Księgowania Tydzień Roku]
    ,[Data Wystawienia Dzień], [Data Wystawienia Rok], [Data Wystawienia Kwartał], [Data Wystawienia Miesiąc], [Data Wystawienia Miesiąc Poprzedni],[Data Wystawienia Miesiąc Bieżący]
    ,[Data Wystawienia Tydzień Roku]
    ,[Data Operacji Dzień], [Data Operacji Rok], [Data Operacji Kwartał], [Data Operacji Miesiąc], [Data Operacji Miesiąc Poprzedni],[Data Operacji Miesiąc Bieżący]
    ,[Data Operacji Tydzień Roku]
    ,[Data Analizy]
    
    ----------KONTEKSTY
    ,[Dokument Numer __PROCID__KH__], [Dokument Numer __ORGID__],[Dokument Numer __DATABASE__]
    ,[Podmiot Pierwotny Kod __PROCID__Kontrahenci__], [Podmiot Pierwotny Kod __ORGID__],[Podmiot Pierwotny Kod __DATABASE__]
    ,[Podmiot Pierwotny Nazwa __PROCID__], [Podmiot Pierwotny Nazwa __ORGID__],[Podmiot Pierwotny Nazwa __DATABASE__]
    ,[Podmiot Nazwa __PROCID__], [Podmiot Nazwa __ORGID__], [Podmiot Nazwa __DATABASE__]
    ,[Podmiot Kod __PROCID__Kontrahenci__], [Podmiot Kod __ORGID__], [Podmiot Kod __DATABASE__]
    
    ' + @kolumny2 +
' FROM 
(SELECT 
    BAZ.Baz_Nazwa [Baza Firmowa], REPLACE(CONVERT(VARCHAR(10), DeN_DataDok, 111), ''/'', ''-'') [Data Księgowania Dzień],  YEAR(DeN_DataDok) [Data Księgowania Rok], 
    DATEPART(quarter, DeN_DataDok) [Data Księgowania Kwartał], MONTH(DeN_DataDok) [Data Księgowania Miesiąc], 
    CASE 
     WHEN (MONTH(DeN_DataDok) = MONTH(GETDATE())-1) AND (YEAR(DeN_DataDok) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN ((MONTH(DeN_DataDok) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(DeN_DataDok) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Księgowania Miesiąc Poprzedni],
    CASE 
     WHEN (MONTH(DeN_DataDok) = MONTH(GETDATE())) AND (YEAR(DeN_DataDok) = YEAR(GETDATE())) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Księgowania Miesiąc Bieżący],

    (datepart(DY, datediff(d, 0, DeN_DataDok) / 7 * 7 + 3)+6) / 7 [Data Księgowania Tydzień Roku],
    REPLACE(CONVERT(VARCHAR(10), DeN_DataWys, 111), ''/'', ''-'') [Data Wystawienia Dzień],  YEAR(DeN_DataWys) [Data Wystawienia Rok], 
    DATEPART(quarter, DeN_DataWys) [Data Wystawienia Kwartał], MONTH(DeN_DataWys) [Data Wystawienia Miesiąc], 
    CASE 
     WHEN (MONTH(DeN_DataWys) = MONTH(GETDATE())-1) AND (YEAR(DeN_DataWys) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN ((MONTH(DeN_DataWys) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(DeN_DataWys) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Wystawienia Miesiąc Poprzedni],
    CASE 
     WHEN (MONTH(DeN_DataWys) = MONTH(GETDATE())) AND (YEAR(DeN_DataWys) = YEAR(GETDATE())) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Wystawienia Miesiąc Bieżący],
    (datepart(DY, datediff(d, 0, DeN_DataWys) / 7 * 7 + 3)+6) / 7 [Data Wystawienia Tydzień Roku],
    REPLACE(CONVERT(VARCHAR(10), DeN_DataOpe, 111), ''/'', ''-'') [Data Operacji Dzień],  YEAR(DeN_DataOpe) [Data Operacji Rok], 
    DATEPART(quarter, DeN_DataOpe) [Data Operacji Kwartał], MONTH(DeN_DataOpe) [Data Operacji Miesiąc], 
    CASE 
     WHEN (MONTH(DeN_DataOpe) = MONTH(GETDATE())-1) AND (YEAR(DeN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN ((MONTH(DeN_DataOpe) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(DeN_DataOpe) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Operacji Miesiąc Poprzedni],
    CASE 
     WHEN (MONTH(DeN_DataOpe) = MONTH(GETDATE())) AND (YEAR(DeN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Operacji Miesiąc Bieżący],
    (datepart(DY, datediff(d, 0, DeN_DataOpe) / 7 * 7 + 3)+6) / 7 [Data Operacji Tydzień Roku],
    GETDATE() [Data Analizy],
    OOb_Symbol [Okres obrachunkowy], 
    
    DeN_Dokument [Dokument Numer], 
    26002 [Dokument Numer __PROCID__KH__], DeN_DeNId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__],

    DeE_Dokument [Dokument Element Numer], CASE WHEN DeN_Bufor = 0  THEN ''Zatwierdzone'' ELSE ''Bufor'' END [Dokument Bufor], 
    Dzi_Symbol [Dziennik], CONVERT(VARCHAR(10),DeN_NrKsiegi) [Dziennik Numer],  DeN_IdentKsieg [Identyfikator Księgowy], poz.nazwa [Konto pełny numer], DeE_KontoMa [Konto Przeciwstawne],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Elementu], ISNULL(kat2.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Nagłówka], 
    ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Elementu], ISNULL(kat2.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Nagłówka],
    ISNULL(DeE_Kategoria, ''(PUSTY)'') [Dokument Opis z Elementu], ISNULL(DeN_Kategoria, ''(PUSTY)'') [Dokument Opis z Nagłówka],
    CASE WHEN DeN_PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN DeN_PodmiotTyp = 2 THEN ''Bank''
         WHEN DeN_PodmiotTyp = 3 THEN ''Pracownik''
         WHEN DeN_PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN DeN_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END [Podmiot Pierwotny Typ], 

    ISNULL(Podmioty.Pod_Kod, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Kod],
    20201 [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], Podmioty.Pod_PodId [Podmiot Pierwotny Kod __ORGID__], '''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__],
    
    ISNULL(Podmioty.Pod_Nazwa1, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Nazwa], 
    20201 [Podmiot Pierwotny Nazwa __PROCID__], Podmioty.Pod_PodId [Podmiot Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Nazwa __DATABASE__],
    
    ISNULL(Podmioty.Pod_NIP, ''(BRAK)'') [Podmiot Pierwotny NIP],
    ISNULL(Podmioty.Pod_Kraj, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Kraj],
    ISNULL(Podmioty.Pod_Wojewodztwo, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Województwo], ISNULL(Podmioty.Pod_Powiat, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Powiat], ISNULL(Podmioty.Pod_Gmina, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Gmina],
    ISNULL(Podmioty.Pod_Miasto, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Miasto], ISNULL(PodPoz.Pod_Kod, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny z Pozycji],
    CASE WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
        WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
        WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik''
        WHEN pod5.Pod_PodmiotTyp = 4 THEN ''Wspólnik''
        WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END AS [Podmiot Typ], 

    ISNULL(pod5.Pod_Nazwa1, ''(NIEPRZYPISANY)'')  [Podmiot Nazwa], 
    20201 [Podmiot Nazwa __PROCID__], pod5.Pod_PodId [Podmiot Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Nazwa __DATABASE__],
    
    ISNULL(pod5.Pod_Kod, ''(NIEPRZYPISANY)'')  [Podmiot Kod], 
    20201 [Podmiot Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Podmiot Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Kod __DATABASE__],

    ISNULL(pod5.Pod_NIP, ''(BRAK)'')  AS [Podmiot NIP],
    ISNULL(pod5.Pod_Kraj, ''(NIEPRZYPISANY)'')  AS [Podmiot Kraj],
    ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Podmiot Województwo],
    "Podmiot Powiat" = CASE WHEN pod5.Pod_Powiat = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Powiat END,
    "Podmiot Gmina" = CASE WHEN pod5.Pod_Gmina = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Gmina END, 
    ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Podmiot Miasto],
    ISNULL(pod6.Pod_Kod, ''(NIEPRZYPISANY)'') [Podmiot z Pozycji],

    ISNULL(op1.Ope_Kod, ''(NIEPRZYPISANY)'') [Operator Wprowadzający], ISNULL(op2.Ope_Kod, ''(NIEPRZYPISANY)'') [Operator Modyfikujący],
    ''NIE'' AS [Rodzaj],    
    CASE WHEN Acc_TypKonta = 6 THEN ''Pozabilansowe''
         WHEN Acc_TypKonta = 5 THEN ''Koszty''
         WHEN Acc_TypKonta = 4 THEN ''Przychody''
         WHEN Acc_TypKonta = 3 THEN ''Aktywno pasywne''
         WHEN Acc_TypKonta = 2 THEN ''Pasywa''
         WHEN Acc_TypKonta = 1 THEN ''Aktywa''
    ELSE ''(NIEPRZYPISANY)'' END AS [Konto Typ],
            CASE WHEN Acc_TypKonta = 6 THEN ''Pozabilansowe''
         WHEN Acc_TypKonta = 5 OR Acc_TypKonta = 4  THEN ''Wynikowe''
         WHEN Acc_TypKonta = 3 OR Acc_TypKonta = 2 OR Acc_TypKonta = 1 THEN ''Bilansowe''
    ELSE ''(NIEPRZYPISANY)'' END AS [Konto Typy],
    CASE WHEN Acc_KontrolaBudzetu = 0 THEN ''Brak''
         WHEN Acc_KontrolaBudzetu = 1 THEN ''Obroty Wn'' 
         WHEN Acc_KontrolaBudzetu = 2 Then ''obroty Ma''
    END [Kontrola budżetu],
    CASE WHEN Acc_Rozrachunkowe = 1 THEN ''TAK'' ELSE ''NIE'' END AS [Konto Rozrachunkowe],
    CASE WHEN DeE_Waluta = '''' THEN @Wal ELSE DeE_Waluta END [Waluta],
    CASE WHEN DeE_AccWnId IS NOT NULL THEN DeE_Kwota ELSE NULL END [Obroty Winien], NULL [Obroty Ma],
    CASE WHEN DeE_AccWnId IS NOT NULL THEN DeE_KwotaWal ELSE NULL END [Obroty Winien Waluta], NULL [Obroty Ma Waluta],
    NULL AS [Bilans Otwarcia Ma], NULL  AS [Bilans Otwarcia Winien],
    NULL [Bilans Otwarcia Ma Waluta], NULL [Bilans Otwarcia Winien Waluta],
    NULL [Plan Wn], NULL [Plan Ma]  '
    + @kolumny +
' FROM CDN.DekretyNag
    JOIN CDN.DekretyElem ON DeE_DeNId = DeN_DeNId AND DeE_AccWnId IS NOT NULL
    LEFT OUTER JOIN CDN.Kategorie kat1 ON DeE_KatId = kat1.Kat_KatID
    LEFT OUTER JOIN CDN.Kategorie kat2 ON DeN_KatId = kat2.Kat_KatID
    JOIN CDN.Dzienniki ON DeN_DziId = Dzi_DziId
    LEFT OUTER JOIN #tmpTwrGr Poz ON DeE_AccWnId = Poz.gid 
    LEFT OUTER JOIN CDN.Konta ON DeE_AccWnId = Acc_AccId
    JOIN CDN.OkresyObrach ON DeN_OObId = OOb_OObID
    LEFT OUTER JOIN CDN.PodmiotyView Podmioty ON DeN_PodmiotId = Podmioty.Pod_PodId AND DeN_PodmiotTyp = Podmioty.Pod_PodmiotTyp
    LEFT OUTER JOIN CDN.PodmiotyView PodPoz ON DeE_SlownikId = PodPoz.Pod_PodId and DeE_SlownikTyp = PodPoz.Pod_PodmiotTyp
    LEFT JOIN ' + @Operatorzy + ' op1 ON DeN_OpeZalID = op1.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' op2 ON DeN_OpeModID = op2.Ope_OpeId
    LEFT OUTER JOIN cdn.PodmiotyView pod5 on Podmioty.Pod_GlID = pod5.Pod_PodId and Podmioty.Pod_GlKod = pod5.Pod_Kod
    LEFT OUTER JOIN cdn.PodmiotyView pod6 on PodPoz.Pod_GlID = pod6.Pod_PodId and PodPoz.Pod_GlKod = pod6.Pod_Kod
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
  WHERE DeN_Typ <> 1
  AND Oob_OobId IN (SELECt OOBID FROM #OOB)
 
UNION ALL 

SELECT 
    BAZ.Baz_Nazwa [Baza Firmowa], REPLACE(CONVERT(VARCHAR(10), DeN_DataDok, 111), ''/'', ''-'') [Data Księgowania Dzień],  YEAR(DeN_DataDok) [Data Księgowania Rok], 
    DATEPART(quarter, DeN_DataDok) [Data Księgowania Kwartał], MONTH(DeN_DataDok) [Data Księgowania Miesiąc], 

    CASE 
     WHEN (MONTH(DeN_DataDok) = MONTH(GETDATE())-1) AND (YEAR(DeN_DataDok) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN ((MONTH(DeN_DataDok) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(DeN_DataDok) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Księgowania Miesiąc Poprzedni],
    CASE 
     WHEN (MONTH(DeN_DataDok) = MONTH(GETDATE())) AND (YEAR(DeN_DataDok) = YEAR(GETDATE())) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Księgowania Miesiąc Bieżący],

    (datepart(DY, datediff(d, 0, DeN_DataDok) / 7 * 7 + 3)+6) / 7 [Data Księgowania Tydzień Roku],
    REPLACE(CONVERT(VARCHAR(10), DeN_DataWys, 111), ''/'', ''-'') [Data Wystawienia Dzień],  YEAR(DeN_DataWys) [Data Wystawienia Rok], 
    DATEPART(quarter, DeN_DataWys) [Data Wystawienia Kwartał], MONTH(DeN_DataWys) [Data Wystawienia Miesiąc], 

    CASE 
     WHEN (MONTH(DeN_DataWys) = MONTH(GETDATE())-1) AND (YEAR(DeN_DataWys) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN ((MONTH(DeN_DataWys) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(DeN_DataWys) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Wystawienia Miesiąc Poprzedni],
    CASE 
     WHEN (MONTH(DeN_DataWys) = MONTH(GETDATE())) AND (YEAR(DeN_DataWys) = YEAR(GETDATE())) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Wystawienia Miesiąc Bieżący],

    (datepart(DY, datediff(d, 0, DeN_DataWys) / 7 * 7 + 3)+6) / 7 [Data Wystawienia Tydzień Roku],
    REPLACE(CONVERT(VARCHAR(10), DeN_DataOpe, 111), ''/'', ''-'') [Data Operacji Dzień],  YEAR(DeN_DataOpe) [Data Operacji Rok], 
    DATEPART(quarter, DeN_DataOpe) [Data Operacji Kwartał], MONTH(DeN_DataOpe) [Data Operacji Miesiąc], 

    CASE 
     WHEN (MONTH(DeN_DataOpe) = MONTH(GETDATE())-1) AND (YEAR(DeN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN ((MONTH(DeN_DataOpe) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(DeN_DataOpe) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Operacji Miesiąc Poprzedni],
    CASE 
     WHEN (MONTH(DeN_DataOpe) = MONTH(GETDATE())) AND (YEAR(DeN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Operacji Miesiąc Bieżący],
    (datepart(DY, datediff(d, 0, DeN_DataOpe) / 7 * 7 + 3)+6) / 7 [Data Operacji Tydzień Roku],
    GETDATE() [Data Analizy],
    OOb_Symbol [Okres obrachunkowy], 
    
    DeN_Dokument [Dokument Numer], 
    26002 [Dokument Numer __PROCID__KH__], DeN_DeNId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__],

    DeE_Dokument [Dokument Element Numer], CASE WHEN DeN_Bufor = 0  THEN ''Zatwierdzone'' ELSE ''Bufor'' END [Dokument Bufor],
    Dzi_Symbol [Dziennik], CONVERT(VARCHAR(10),DeN_NrKsiegi) [Dziennik Numer], DeN_IdentKsieg [Identyfikator Księgowy], poz.nazwa [Konto pełny numer], DeE_KontoWn [Konto Przeciwstawne],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Elementu], ISNULL(kat2.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Nagłówka], 
    ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Elementu], ISNULL(kat2.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Nagłówka],
    ISNULL(DeE_Kategoria, ''(PUSTY)'') [Dokument Opis z Elementu], ISNULL(DeN_Kategoria, ''(PUSTY)'') [Dokument Opis z Nagłówka],
    CASE WHEN DeN_PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN DeN_PodmiotTyp = 2 THEN ''Bank''
         WHEN DeN_PodmiotTyp = 3 THEN ''Pracownik''
         WHEN DeN_PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN DeN_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END [Podmiot Pierwotny Typ], 

    ISNULL(Podmioty.Pod_Kod, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Kod],
    20201 [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], Podmioty.Pod_PodId [Podmiot Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__],
    
    ISNULL(Podmioty.Pod_Nazwa1, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Nazwa], 
    20201 [Podmiot Pierwotny Nazwa __PROCID__], Podmioty.Pod_PodId [Podmiot Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Nazwa __DATABASE__],
    
    ISNULL(Podmioty.Pod_NIP, ''(BRAK)'') [Podmiot Pierwotny NIP],
    ISNULL(Podmioty.Pod_Kraj, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Kraj],
    ISNULL(Podmioty.Pod_Wojewodztwo, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Województwo], ISNULL(Podmioty.Pod_Powiat, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Powiat], ISNULL(Podmioty.Pod_Gmina, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Gmina],
    ISNULL(Podmioty.Pod_Miasto, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny Miasto], ISNULL(PodPoz.Pod_Kod, ''(NIEPRZYPISANY)'') [Podmiot Pierwotny z Pozycji], 
        CASE WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
        WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
        WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik''
        WHEN pod5.Pod_PodmiotTyp = 4 THEN ''Wspólnik''
        WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END AS [Podmiot Typ], 

    ISNULL(pod5.Pod_Nazwa1, ''(NIEPRZYPISANY)'') [Podmiot Nazwa], 
    20201 [Podmiot Nazwa __PROCID__], pod5.Pod_PodId [Podmiot Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Nazwa __DATABASE__],
    
    ISNULL(pod5.Pod_Kod, ''(NIEPRZYPISANY)'') [Podmiot Kod], 
    20201 [Podmiot Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Podmiot Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Kod __DATABASE__],

    ISNULL(pod5.Pod_NIP, ''(BRAK)'') AS [Podmiot NIP],
    ISNULL(pod5.Pod_Kraj, ''(NIEPRZYPISANY)'') AS [Podmiot Kraj],
    ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Podmiot Województwo],
    "Podmiot Powiat" = CASE WHEN pod5.Pod_Powiat = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Powiat END,
    "Podmiot Gmina" = CASE WHEN pod5.Pod_Gmina = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Gmina END, 
    ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Podmiot Miasto],
    ISNULL(pod6.Pod_Kod, ''(NIEPRZYPISANY)'') [Podmiot z Pozycji],
    ISNULL(op1.Ope_Kod, ''(NIEPRZYPISANY)'') [Operator Wprowadzający], ISNULL(op2.Ope_Kod, ''(NIEPRZYPISANY)'') [Operator Modyfikujący],
    ''NIE'' AS [Rodzaj], 
    CASE WHEN Acc_TypKonta = 6 THEN ''Pozabilansowe''
         WHEN Acc_TypKonta = 5 THEN ''Koszty''
         WHEN Acc_TypKonta = 4 THEN ''Przychody''
         WHEN Acc_TypKonta = 3 THEN ''Aktywno pasywne''
         WHEN Acc_TypKonta = 2 THEN ''Pasywa''
         WHEN Acc_TypKonta = 1 THEN ''Aktywa''
    ELSE ''(NIEPRZYPISANY)'' END AS [Konto Typ],
            CASE WHEN Acc_TypKonta = 6 THEN ''Pozabilansowe''
         WHEN Acc_TypKonta = 5 OR Acc_TypKonta = 4  THEN ''Wynikowe''
         WHEN Acc_TypKonta = 3 OR Acc_TypKonta = 2 OR Acc_TypKonta = 1 THEN ''Bilansowe''
    ELSE ''(NIEPRZYPISANY)'' END AS [Konto Typy],
    CASE WHEN Acc_KontrolaBudzetu = 0 THEN ''Brak''
         WHEN Acc_KontrolaBudzetu = 1 THEN ''Obroty Wn'' 
         WHEN Acc_KontrolaBudzetu = 2 Then ''obroty Ma''
    END [Kontrola budżetu],
    CASE WHEN Acc_Rozrachunkowe = 1 THEN ''TAK'' ELSE ''NIE'' END AS [Konto Rozrachunkowe],
    CASE WHEN DeE_Waluta = '''' THEN @Wal ELSE DeE_Waluta END [Waluta],
    NULL [Obroty Winien], CASE WHEN DeE_AccMaId IS NOT NULL THEN DeE_Kwota ELSE NULL END [Obroty Ma],
    NULL [Obroty Winien Waluta], CASE WHEN DeE_AccMaId IS NOT NULL THEN DeE_KwotaWal ELSE NULL END [Obroty Ma Waluta],
    NULL AS [Bilans Otwarcia Ma], NULL  AS [Bilans Otwarcia Winien],
    NULL [Bilans Otwarcia Ma Waluta], NULL [Bilans Otwarcia Winien Waluta],
    NULL [Plan Wn], NULL [Plan Ma] '
    + @kolumny +
' FROM CDN.DekretyNag
    JOIN CDN.DekretyElem ON DeE_DeNId = DeN_DeNId AND DeE_AccMaId IS NOT NULL
    LEFT OUTER JOIN CDN.Kategorie kat1 ON DeE_KatId = kat1.Kat_KatID
    LEFT OUTER JOIN CDN.Kategorie kat2 ON DeN_KatId = kat2.Kat_KatID
    JOIN CDN.Dzienniki ON DeN_DziId = Dzi_DziId
    LEFT OUTER JOIN #tmpTwrGr Poz ON DeE_AccMaId = Poz.gid 
    LEFT OUTER JOIN CDN.Konta ON DeE_AccMaId = Acc_AccId 
    JOIN CDN.OkresyObrach ON DeN_OObId = OOb_OObID
    LEFT OUTER JOIN CDN.PodmiotyView Podmioty ON DeN_PodmiotId = Podmioty.Pod_PodId AND DeN_PodmiotTyp = Podmioty.Pod_PodmiotTyp
    LEFT OUTER JOIN CDN.PodmiotyView PodPoz ON DeE_SlownikId = PodPoz.Pod_PodId and DeE_SlownikTyp = PodPoz.Pod_PodmiotTyp
    LEFT JOIN ' + @Operatorzy + ' op1 ON DeN_OpeZalID = op1.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' op2 ON DeN_OpeModID = op2.Ope_OpeId
    LEFT OUTER JOIN cdn.PodmiotyView pod5 on Podmioty.Pod_GlID = pod5.Pod_PodId and Podmioty.Pod_GlKod = pod5.Pod_Kod
    LEFT OUTER JOIN cdn.PodmiotyView pod6 on PodPoz.Pod_GlID = pod6.Pod_PodId and PodPoz.Pod_GlKod = pod6.Pod_Kod
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
  WHERE DeN_Typ <> 1
  AND Oob_OobId  IN (SELECT OOBID FROM #OOB)

UNION ALL

SELECT 
    BAZ.Baz_Nazwa [Baza Firmowa], NULL [Data Księgowania Dzień], ISNULL( SUBSTRING(convert(varchar,Obr_RokMies), 1,4), 0) [Data Księgowania Rok], 
    NULL [Data Księgowania Kwartał], ISNULL( SUBSTRING(convert(varchar,Obr_RokMies), 5,6), 0) [Data Księgowania Miesiąc], 
    CASE 
     WHEN (Obr_RokMies%100 = MONTH(GETDATE())-1) AND ((Obr_RokMies/100) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN (((Obr_RokMies%100) = 12) AND (MONTH(GETDATE()) = 1)) AND ((Obr_RokMies/100) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Księgowania Miesiąc Poprzedni],

    CASE WHEN Obr_RokMies = YEAR(GETDATE())*100 + MONTH(GETDATE()) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Księgowania Miesiąc Bieżący],


    NULL [Data Księgowania Tydzień Roku],
    NULL [Data Wystawienia Dzień],  NULL [Data Wystawienia Rok], 
    NULL [Data Wystawienia Kwartał], NULL [Data Wystawienia Miesiąc], NULL [Data Wystawienia Miesiąc Poprzedni], NULL [Data Wystawienia Miesiąc Bieżący],
    NULL [Data Wystawienia Tydzień Roku],
    NULL [Data Operacji Dzień], NULL [Data Operacji Rok], 
    NULL [Data Operacji Kwartał], NULL [Data Operacji Miesiąc], NULL [Data Operacji Miesiąc Poprzedni], NULL [Data Operacji Miesiąc Bieżący], 
    NULL [Data operacji Tydzień Roku],
    GETDATE() [Data Analizy],
    OOb_Symbol [Okres obrachunkowy], 

    NULL [Dokument Numer], 
    26006 [Dokument Numer __PROCID__KH__], Acc_AccId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__],

    NULL [Dokument Element Numer], CASE WHEN Obr_ObrotyWn = 0.0 AND Obr_ObrotyMa = 0.0 THEN ''Bufor'' ELSE ''Zatwierdzone'' END [Dokument Bufor],
    NULL [Dziennik], NULL [Dziennik Numer], NULL [Identyfikator Księgowy], poz.nazwa [Konto pełny numer], NULL [Konto Przeciwstawne],
    NULL [Kategoria Szczegółowa z Elementu], NULL [Kategoria Szczegółowa z Nagłówka], 
    NULL [Kategoria Ogólna z Elementu], NULL [Kategoria Ogólna z Nagłówka],
    NULL [Dokument Opis z Elementu], NULL [Dokument Opis z Nagłówka],
    NULL [Podmiot Pierwotny Typ], 
    
    NULL [Podmiot Pierwotny Kod], 
    26006 [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], Acc_AccId [Podmiot Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__],
    
    NULL [Podmiot Pierwotny Nazwa], 
    26006 [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], Acc_AccId [Podmiot Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Nazwa __DATABASE__],
    
    NULL [Podmiot Pierwotny NIP],
    NULL [Podmiot Pierwotny Kraj],
    NULL [Podmiot Pierwotny Województwo], NULL [Podmiot Pierwotny Powiat],NULL [Podmiot Pierwotny Gmina],
    NULL [Podmiot Pierwotny Miasto], NULL [Podmiot Pierwotny z Pozycji],    

    NULL [Podmiot Typ], 
    NULL [Podmiot Kod], 
    26006 [Podmiot Kod __PROCID__Kontrahenci__], Acc_AccId [Podmiot Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Kod __DATABASE__],
    NULL [Podmiot Nazwa], 
    26006 [Podmiot Nazwa __PROCID__Kontrahenci__], Acc_AccId [Podmiot Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Nazwa __DATABASE__],
    NULL [Podmiot NIP],
    NULL [Podmiot Kraj],
    NULL [Podmiot Województwo], NULL [Podmiot Powiat],NULL [Podmiot Gmina],
    NULL [Podmiot Miasto], NULL [Podmiot z Pozycji],

    NULL [Operator Wprowadzający], NULL [Operator Modyfikujący],
    CASE WHEN Obr_Typ = 0 THEN ''NIE'' WHEN Obr_Typ = 1 THEN ''TAK'' ELSE ''Korekta Bilansu Zamknięcia'' END AS [Rodzaj],
    CASE WHEN Acc_TypKonta = 6 THEN ''Pozabilansowe''
         WHEN Acc_TypKonta = 5 THEN ''Koszty''
         WHEN Acc_TypKonta = 4 THEN ''Przychody''
         WHEN Acc_TypKonta = 3 THEN ''Aktywno pasywne''
         WHEN Acc_TypKonta = 2 THEN ''Pasywa''
         WHEN Acc_TypKonta = 1 THEN ''Aktywa''
    ELSE ''(NIEPRZYPISANY)'' END AS [Konto Typ],
            CASE WHEN Acc_TypKonta = 6 THEN ''Pozabilansowe''
         WHEN Acc_TypKonta = 5 OR Acc_TypKonta = 4  THEN ''Wynikowe''
         WHEN Acc_TypKonta = 3 OR Acc_TypKonta = 2 OR Acc_TypKonta = 1 THEN ''Bilansowe''
    ELSE ''(NIEPRZYPISANY)'' END AS [Konto Typy],
    CASE WHEN Acc_KontrolaBudzetu = 0 THEN ''Brak''
         WHEN Acc_KontrolaBudzetu = 1 THEN ''Obroty Wn'' 
         WHEN Acc_KontrolaBudzetu = 2 Then ''obroty Ma''
    END [Kontrola budżetu],
    CASE WHEN Acc_Rozrachunkowe = 1 THEN ''TAK'' ELSE ''NIE'' END AS [Konto Rozrachunkowe],
    CASE WHEN Acc_Waluta = '''' THEN @Wal ELSE Acc_Waluta END [Waluta],
    NULL [Obroty Winien], NULL [Obroty Ma], NULL [Obroty Winien Waluta], NULL [Obroty Ma Waluta],
    CASE WHEN Obr_Typ = 1 THEN 
    CASE 
        WHEN Obr_ObrotyMa > 0 THEN Obr_ObrotyMa
        ELSE Obr_ObrotyMaBufor
    END 
    ELSE 0 END AS [Bilans Otwarcia Ma],
    CASE WHEN Obr_Typ = 1 THEN 
    CASE 
        WHEN Obr_ObrotyWn > 0 THEN Obr_ObrotyWn 
        ELSE Obr_ObrotyWnBufor
    END  
    ELSE 0 END  AS [Bilans Otwarcia Winien],
    CASE WHEN Obr_Typ = 1 THEN 
    CASE 
        WHEN Obr_ObrotyMaWal > 0 THEN Obr_ObrotyMaWal 
        ELSE Obr_ObrotyMaBuforWal
    END 
    ELSE 0 END AS [Bilans Otwarcia Ma Waluta],
    CASE WHEN Obr_Typ = 1 THEN 
    CASE 
        WHEN Obr_ObrotyWnWal > 0 THEN Obr_ObrotyWnWal 
        ELSE Obr_ObrotyWnBuforWal
    END  
    ELSE 0 END  AS [Bilans Otwarcia Winien Waluta],
    NULL [Plan Wn], 
    NULL [Plan Ma]
    
    ' + @kolumny +
' FROM [CDN].[Obroty]
    LEFT JOIN #tmpTwrGr Poz ON Obr_AccId = Poz.gid
    LEFT JOIN CDN.Konta ON Obr_AccId = Acc_AccId
    LEFT JOIN CDN.OkresyObrach ON Acc_OObId = OOb_OObID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    WHERE Oob_OobId  IN (SELECT OOBID FROM #OOB)
    
UNION ALL

SELECT 
    BAZ.Baz_Nazwa [Baza Firmowa], 
    CASE WHEN BuE_Miesiac IS NULL THEN NULL ELSE SUBSTRING(convert(varchar,BuE_Miesiac), 1,4) + ''-'' + SUBSTRING(convert(varchar,BuE_Miesiac), 5,6) + ''-01'' END [Data Księgowania Dzień],
    ISNULL( SUBSTRING(convert(varchar,BuE_Miesiac), 1,4), 0) [Data Księgowania Rok], 
    NULL [Data Księgowania Kwartał], ISNULL( SUBSTRING(convert(varchar,BuE_Miesiac), 5,6), 0) [Data Księgowania Miesiąc], 

    CASE 
     WHEN (BuE_Miesiac%100 = MONTH(GETDATE())-1) AND ((BuE_Miesiac/100) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN (((BuE_Miesiac%100) = 12) AND (MONTH(GETDATE()) = 1)) AND ((BuE_Miesiac/100) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Księgowania Miesiąc Poprzedni],

    CASE WHEN BuE_Miesiac = YEAR(GETDATE())*100 + MONTH(GETDATE()) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Księgowania Miesiąc Bieżący],

    NULL [Data Księgowania Tydzień Roku],
    NULL [Data Wystawienia Dzień],  NULL [Data Wystawienia Rok], 
    NULL [Data Wystawienia Kwartał], NULL [Data Wystawienia Miesiąc], NULL [Data Wystawienia Miesiąc Poprzedni], NULL [Data Wystawienia Miesiąc Bieżący],
    NULL [Data Wystawienia Tydzień Roku],
    NULL [Data Operacji Dzień], NULL [Data Operacji Rok], 
    NULL [Data Operacji Kwartał], NULL [Data Operacji Miesiąc], NULL [Data Operacji Miesiąc Poprzedni], NULL [Data Operacji Miesiąc Bieżący], 
    NULL [Data operacji Tydzień Roku],
    GETDATE() [Data Analizy],
    OOb_Symbol [Okres obrachunkowy], 
    
    NULL [Dokument Numer], 
    26006 [Dokument Numer __PROCID__KH__], Acc_AccId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__],
    
    NULL [Dokument Element Numer], ''Zatwierdzone'' [Dokument Bufor],
    NULL [Dziennik], NULL [Dziennik Numer], NULL [Identyfikator Księgowy], poz.nazwa [Konto pełny numer], NULL [Konto Przeciwstawne],
    NULL [Kategoria Szczegółowa z Elementu], NULL [Kategoria Szczegółowa z Nagłówka], 
    NULL [Kategoria Ogólna z Elementu], NULL [Kategoria Ogólna z Nagłówka],
    NULL [Dokument Opis z Elementu], NULL [Dokument Opis z Nagłówka],
    NULL [Podmiot Pierwotny Typ], 
    
    NULL [Podmiot Pierwotny Kod], 
    26006 [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], Acc_AccId [Podmiot Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__],
    
    NULL [Podmiot Pierwotny Nazwa], 
    26006 [Podmiot Pierwotny Nazwa __PROCID__Kontrahenci__], Acc_AccId [Podmiot Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Nazwa __DATABASE__],
    
    NULL [Podmiot Pierwotny NIP],
    NULL [Podmiot Pierwotny Kraj],
    NULL [Podmiot Pierwotny Województwo], NULL [Podmiot Pierwotny Powiat],NULL [Podmiot Pierwotny Gmina],
    NULL [Podmiot Pierwotny Miasto], NULL [Podmiot Pierwotny z Pozycji],
    NULL [Podmiot Typ], 
    NULL [Podmiot Kod], 
    26006 [Podmiot Kod __PROCID__Kontrahenci__], Acc_AccId [Podmiot Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Kod __DATABASE__],
    NULL [Podmiot Nazwa], 
    26006 [Podmiot Nazwa __PROCID__Kontrahenci__], Acc_AccId [Podmiot Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Nazwa __DATABASE__],
    NULL [Podmiot NIP],
    NULL [Podmiot Kraj],
    NULL [Podmiot Województwo], NULL [Podmiot Powiat],NULL [Podmiot Gmina],
    NULL [Podmiot Miasto], NULL [Podmiot z Pozycji],
    NULL [Operator Wprowadzający], NULL [Operator Modyfikujący],
    ''TAK'' AS [Rodzaj],
    CASE WHEN Acc_TypKonta = 6 THEN ''Pozabilansowe''
         WHEN Acc_TypKonta = 5 THEN ''Koszty''
         WHEN Acc_TypKonta = 4 THEN ''Przychody''
         WHEN Acc_TypKonta = 3 THEN ''Aktywno pasywne''
         WHEN Acc_TypKonta = 2 THEN ''Pasywa''
         WHEN Acc_TypKonta = 1 THEN ''Aktywa''
    ELSE ''(NIEPRZYPISANY)'' END AS [Konto Typ],
    CASE WHEN Acc_TypKonta = 6 THEN ''Pozabilansowe''
         WHEN Acc_TypKonta = 5 OR Acc_TypKonta = 4  THEN ''Wynikowe''
         WHEN Acc_TypKonta = 3 OR Acc_TypKonta = 2 OR Acc_TypKonta = 1 THEN ''Bilansowe''
    ELSE ''(NIEPRZYPISANY)'' END AS [Konto Typy],
    CASE WHEN Acc_KontrolaBudzetu = 0 THEN ''Brak''
         WHEN Acc_KontrolaBudzetu = 1 THEN ''Obroty Wn'' 
         WHEN Acc_KontrolaBudzetu = 2 Then ''obroty Ma''
    END [Kontrola budżetu],
    CASE WHEN Acc_Rozrachunkowe = 1 THEN ''TAK'' ELSE ''NIE'' END AS [Konto Rozrachunkowe],
    CASE WHEN Acc_Waluta = '''' THEN @Wal ELSE Acc_Waluta END [Waluta],
    NULL [Obroty Winien], NULL [Obroty Ma], NULL [Obroty Winien Waluta], NULL [Obroty Ma Waluta],
    NULL AS [Bilans Otwarcia Ma], NULL  AS [Bilans Otwarcia Winien],
    NULL [Bilans Otwarcia Ma Waluta], NULL [Bilans Otwarcia Winien Waluta],
    CASE WHEN Acc_KontrolaBudzetu = 1 THEN BuE_Kwota ELSE NULL END [Plan Wn], 
    CASE WHEN Acc_KontrolaBudzetu = 2 THEN BuE_Kwota ELSE NULL END [Plan Ma]
    ' + @kolumny +
' FROM CDN.Konta
    LEFT JOIN #tmpTwrGr Poz ON Acc_AccId = Poz.gid
    LEFT JOIN CDN.OkresyObrach ON Acc_OObId = OOb_OObID
    JOIN CDN.BudzetNag ON Acc_AccId = BuN_AccId
    JOIN CDN.BudzetElem ON BuE_BuNId = BuN_BuNId 
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    WHERE BuN_Finalny = 1
  AND Oob_OobId  IN (SELECT OOBID FROM #OOB)

) AS ks'

--print(@select)
exec(@select)

drop Table #tmpTwrGr    
drop Table #oob



