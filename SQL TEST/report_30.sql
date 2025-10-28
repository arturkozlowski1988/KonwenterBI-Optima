
/*
* Raport Rozrachunków Księgowych na Dzień 
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
;WITH g(gid, kod, naz, parId, poziom, nazwa)
AS
(
      SELECT Acc_AccId, Acc_Segment, Acc_Nazwa, Acc_ParId, Acc_Poziom, convert(nvarchar(1024), Acc_Segment) as nazwa
      FROM CDN.Konta
      WHERE Acc_ParId IS NULL AND Acc_OObId IN (select oobid from #oob)
      
      UNION ALL
      
      SELECT Acc_AccId, Acc_Segment, Acc_Nazwa, Acc_ParId, Acc_Poziom, convert(nvarchar(1024), p.nazwa + N'-' + c.Acc_Segment) as nazwa
      FROM g p
        JOIN CDN.Konta c ON c.Acc_ParId = p.gid 
      WHERE c.Acc_ParId IS NOT NULL AND c.Acc_OObId IN (select oobid from #oob)
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
    SET @sql = N'ALTER TABLE #tmpTwrGr ADD Poziom' + CAST(@poziom AS nvarchar) + N' nvarchar(50), ONr' + CAST(@poziom AS nvarchar) + N' nvarchar(50), Nazwa' + CAST(@poziom AS nvarchar) + N' nvarchar(4000)'
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
                    ELSE p.naz END)  
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

declare @select varchar(max);
declare @select2 varchar(max);
declare @kolumny varchar(max);
declare @i int

set @kolumny = ''

set @i=1
if @i<=@poziom_max  
begin
    set @kolumny = ', SUBSTRING(Poz.Poziom1, 1, 1) AS [Konto Grupa]'
end
while (@i<=@poziom_max)
begin
    set @kolumny = @kolumny + ', CASE WHEN Poz.Poziom' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' + LTRIM(@i) + ' END [Konto Struktura Poziom ' + LTRIM(@i) + '] ' +
                              ', CASE WHEN Poz.Nazwa' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Nazwa' + LTRIM(@i) + ' END [Konto Nazwa Poziom ' + LTRIM(@i) + '] '
    set @i = @i + 1
end

CREATE UNIQUE CLUSTERED INDEX in1 ON #tmpTwrGr(gid)

DECLARE @DATAANALIZY VARCHAR(MAX);
SET @DATAANALIZY = CONVERT(VARCHAR, @DATA);

DECLARE @bazaFirmowa varchar(max);
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Bazy varchar(max);
DECLARE @Operatorzy varchar(max);
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 

SET @select = 
N'SELECT 

BAZ.Baz_Nazwa [Baza Firmowa],
    KRo_Dokument [Dokument Numer], 
    NULL [Dokument Opis], KRo_IdentKsieg [Identyfikator Księgowy], CASE WHEN KRo_Bufor = 1 THEN ''TAK'' ELSE ''NIE'' END [Dokument Bufor],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Elementu], ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Elementu],
    KRo_NrKsiegi [Dziennik Numer], KRo_NrDziennika [Dziennik Cząstkowy Numer], OOb_Symbol [Okres Obrachunkowy], KRo_Waluta [Waluta], 
    REPLACE(CONVERT(VARCHAR(10), KRo_DataDokumentu, 111), ''/'', ''-'') [Data Dokumentu Dzień], YEAR(KRo_DataDokumentu) [Data Dokumentu Rok], 
    DATEPART(quarter, KRo_DataDokumentu) [Data Dokumentu Kwartał], MONTH(KRo_DataDokumentu) [Data Dokumentu Miesiąc], 
    (datepart(DY, datediff(d, 0, KRo_DataDokumentu) / 7 * 7 + 3)+6) / 7 [Data Dokumentu Tydzień Roku],
    REPLACE(CONVERT(VARCHAR(10), KRo_TerminPlatnosci, 111), ''/'', ''-'') [Data Termin Płatności Dzień], YEAR(KRo_TerminPlatnosci) [Data Termin Płatności Rok], 
    DATEPART(quarter, KRo_TerminPlatnosci) [Data Termin Płatności Kwartał], MONTH(KRo_TerminPlatnosci) [Data Termin Płatności Miesiąc], 
    (datepart(DY, datediff(d, 0, KRo_TerminPlatnosci) / 7 * 7 + 3)+6) / 7 [Data Termin Płatności Tydzień Roku],
    REPLACE(CONVERT(VARCHAR(10), KRo_DataOperacji, 111), ''/'', ''-'') [Data Operacji Dzień],
    REPLACE(CONVERT(VARCHAR(10), KRo_DataOperacji, 111), ''/'', ''-'') [Data Wystawienia Dzień],
    CASE WHEN ''' + @TERMINDATA + ''' = ''Terminu Płatności''
    THEN CASE
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) < 1 THEN ''1. W terminie''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 AND ' + CONVERT(varchar, @PRZEDZIAL1) + ' THEN ''2.  Do ' + CONVERT(varchar, @PRZEDZIAL1) + ' dni''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL1) + ' AND ' + CONVERT(varchar, @PRZEDZIAL2) + ' THEN ''3. Od ' + CONVERT(varchar, @PRZEDZIAL1 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL2) + ' dni''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL2) + ' AND ' + CONVERT(varchar, @PRZEDZIAL3) + ' THEN ''4. Od ' + CONVERT(varchar, @PRZEDZIAL2 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL3) + ' dni''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL3) + ' AND ' + CONVERT(varchar, @PRZEDZIAL4) + ' THEN ''5. Od ' + CONVERT(varchar, @PRZEDZIAL3 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL4) + ' dni''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL4) + ' AND ' + CONVERT(varchar, @PRZEDZIAL5) + ' THEN ''6. Od ' + CONVERT(varchar, @PRZEDZIAL4 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
            ELSE ''7. Powyżej ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
        END
    ELSE CASE
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) < 1 THEN ''1. W terminie''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 AND ' + CONVERT(varchar, @PRZEDZIAL1) + ' THEN ''2.  Do ' + CONVERT(varchar, @PRZEDZIAL1) + ' dni''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL1) + ' AND ' + CONVERT(varchar, @PRZEDZIAL2) + ' THEN ''3. Od ' + CONVERT(varchar, @PRZEDZIAL1 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL2) + ' dni''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL2) + ' AND ' + CONVERT(varchar, @PRZEDZIAL3) + ' THEN ''4. Od ' + CONVERT(varchar, @PRZEDZIAL2 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL3) + ' dni''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL3) + ' AND ' + CONVERT(varchar, @PRZEDZIAL4) + ' THEN ''5. Od ' + CONVERT(varchar, @PRZEDZIAL3 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL4) + ' dni''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL4) + ' AND ' + CONVERT(varchar, @PRZEDZIAL5) + ' THEN ''6. Od ' + CONVERT(varchar, @PRZEDZIAL4 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
            ELSE ''7. Powyżej ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
        END
    END [Termin Zapadalności], 
    KRo_Konto [Konto Pełny Numer], k1.Acc_Nazwa [Konto Nazwa], KRo_KontoPrzeciw [Konto Przeciwstawne],
    CASE WHEN pod.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN pod.Pod_PodmiotTyp = 2 THEN ''Bank''
         WHEN pod.Pod_PodmiotTyp = 3 THEN ''Pracownik''
         WHEN pod.Pod_PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN pod.Pod_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END [Podmiot Pierwotny Typ], 
    pod.Pod_NIP [Podmiot Pierwotny NIP],
    pod.Pod_Kod [Podmiot Pierwotny Kod], 
        pod.Pod_Nazwa1[Podmiot Pierwotny Nazwa],
    CASE WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN pod5.Pod_PodmiotTyp= 2 THEN ''Bank''
         WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik''
         WHEN pod5.Pod_PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END [Podmiot Typ], 
    pod5.Pod_NIP [Podmiot NIP],
    pod5.Pod_Kod [Podmiot Kod], 
    pod5.Pod_Nazwa1 [Podmiot Nazwa],
    KRo_KwotaDok [Kwota Dokumentu], --KRo_KwotaWal [Kwota Dokumentu Waluta],
    CASE KRo_Strona WHEN 1 THEN NULLIF(KRo_KwotaDok-KRo_SumRozliczen,0) END [Kwota Pozostała Wn], --CASE KRo_Strona WHEN 1 THEN NULLIF(KRo_KwotaDokWal-KRo_SumRozliczenWal,0) END [Kwota Pozostała Wn Waluta], 
    CASE KRo_Strona WHEN 2 THEN NULLIF(KRo_KwotaDok-KRo_SumRozliczen,0) END [Kwota Pozostała Ma], --CASE KRo_Strona WHEN 2 THEN NULLIF(KRo_KwotaDokWal-KRo_SumRozliczenWal,0) END [Kwota Pozostała Ma Waluta],
    CASE KRo_Strona WHEN 1 THEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) END [Liczba Dni Przeterminowania Wn], 
    CASE KRo_Strona WHEN 2 THEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) END [Liczba Dni Przeterminowania Ma],
    zal.Ope_Kod [Operator Wprowadzający], 
    mod.Ope_Kod [Operator Modyfikujący],
    GETDATE() [Data Analizy]
    
    ----------KONTEKSTY
    ,26002 [Dokument Numer __PROCID__Rozrachunki__], DeE_DeNId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,CASE pod.Pod_PodmiotTyp
        WHEN 1 THEN 20201
        WHEN 2 THEN 23002
        WHEN 3 THEN 24001
        WHEN 5 THEN 25005
        ELSE 20201
    END [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], pod.Pod_PodId [Podmiot Pirwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__]
    ,CASE pod.Pod_PodmiotTyp
        WHEN 1 THEN 20201
        WHEN 2 THEN 23002
        WHEN 3 THEN 24001
        WHEN 5 THEN 25005
        ELSE 20201
    END [Podmiot Pierwotny Nazwa __PROCID__], pod.Pod_PodId [Podmiot Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Nazwa __DATABASE__]
    ,CASE pod5.Pod_PodmiotTyp
        WHEN 1 THEN 20201
        WHEN 2 THEN 23002
        WHEN 3 THEN 24001
        WHEN 5 THEN 25005
        ELSE 20201
    END [Podmiot Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Podmiot Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Kod __DATABASE__]
    ,CASE pod5.Pod_PodmiotTyp
        WHEN 1 THEN 20201
        WHEN 2 THEN 23002
        WHEN 3 THEN 24001
        WHEN 5 THEN 25005
        ELSE 20201
    END [Podmiot Nazwa __PROCID__], pod.Pod_PodId [Podmiot Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Nazwa __DATABASE__]
    
    ' + @kolumny + 
' FROM CDN.KsiRozrachunki
    LEFT JOIN CDN.OkresyObrach ON KRo_OObId = OOb_OObID
    LEFT JOIN CDN.DekretyElem ON DeE_DeEId = KRo_DeEId
    LEFT JOIN CDN.DekretyNag on DeE_DeNId = DeN_DeNId
    LEFT OUTER JOIN CDN.Kategorie kat1 ON DeE_KatId = kat1.Kat_KatID
    LEFT OUTER JOIN CDN.Konta k1 ON KRo_KontoIdx = k1.Acc_NumerIdx AND KRo_OObId = k1.Acc_OObId
    LEFT OUTER JOIN CDN.Konta k2 ON KRo_KontoIdx = k2.Acc_NumerIdx AND KRo_OObId + 1 = k2.Acc_OObId
    LEFT JOIN #tmpTwrGr Poz ON ISNULL(k1.Acc_AccId, k2.Acc_AccId) = Poz.gid 
    LEFT JOIN CDN.PodmiotyView pod ON DeN_PodmiotId = pod.Pod_PodId AND DeN_PodmiotTyp = pod.Pod_PodmiotTyp
    LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod.Pod_GlID = pod5.Pod_PodId and pod.Pod_GlKod = pod5.Pod_Kod
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON k1.Acc_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON k1.Acc_OpeModID = mod.Ope_OpeId
WHERE Kro_DataRoz IS NULL AND KRo_DataDokumentu <= CONVERT(DATETIME,''' + @DATAANALIZY + ''') and OOB_OOBID IN (select oobid from #oob)'


EXEC(@select)
--PRINT(@select)
DROP TABLE #tmpTwrGr
DROP TABLE #OOB






