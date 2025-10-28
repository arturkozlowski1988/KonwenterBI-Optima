
/*
* Raport Rozrachunków Księgowych na Dzień 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.1.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


DECLARE @kontoodidx VARCHAR(200) = (SELECT Acc_NumerIdx from CDN.Konta WHERE Acc_AccId = @KONTOOD)
DECLARE @kontodoidx VARCHAR(200) = (SELECT Acc_NumerIdx from CDN.Konta WHERE Acc_AccId = @KONTODO);
--Wyliczanie poziomów kont
WITH g(gid, kod, naz, parId, poziom, nazwa)
AS
(
      SELECT Acc_AccId, Acc_Segment, Acc_Nazwa, Acc_ParId, Acc_Poziom, convert(nvarchar(1024), Acc_Segment) as nazwa
      FROM CDN.Konta
      WHERE Acc_ParId IS NULL
      
      UNION ALL
      
      SELECT Acc_AccId, Acc_Segment, Acc_Nazwa, Acc_ParId, Acc_Poziom, convert(nvarchar(1024), p.nazwa + N'-' + c.Acc_Segment) as nazwa
      FROM g p
        JOIN CDN.Konta c ON c.Acc_ParId = p.gid 
      WHERE c.Acc_ParId IS NOT NULL 
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
                SET ONr' + CAST(@poziom AS nvarchar) +  '= parId '
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
declare @select1 varchar(max);
declare @select2 varchar(max);
declare @select3 varchar(max);
declare @select4 varchar(max);
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

--Właściwe zapytanie
DECLARE @DATAINT INT; 
SET @DATAINT = CONVERT(int, @DATA)
DECLARE @DATAODINT INT; 
SET @DATAODINT = CONVERT(int, @DATAOD)
DECLARE @DATADOINT INT; 
SET @DATADOINT = CONVERT(int, @DATADO)
DECLARE @TYPDATY INT;
SET @TYPDATY = (CASE WHEN @TERMINDATA = 'Terminu Płatności' THEN 1 ELSE 2 END)
DECLARE @OOID INT;
SET @OOID = (SELECT OOb_OObID FROM CDN.OkresyObrach WHERE OOb_Symbol=@OKRESOBRACHUNKOWY)
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
'SELECT 

BAZ.Baz_Nazwa [Baza Firmowa], 
    Dokument [Dokument Numer], 
    Opis [Dokument Opis], IdentKsieg [Identyfikator Księgowy], CASE WHEN Bufor = 1 THEN ''TAK'' ELSE ''NIE'' END [Dokument Bufor],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Elementu], ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Elementu],
    NrKsiegi [Dziennik Numer], NrDziennika [Dziennik Cząstkowy Numer], OOb_Symbol [Okres Obrachunkowy], Waluta [Waluta], 
    CASE WHEN ''' + @TERMINDATA + ''' = ''Terminu Płatności''
    THEN CASE
            WHEN DATEDIFF(day, TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) < 1 THEN ''1. W terminie''
            WHEN DATEDIFF(day, TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 AND ' + CONVERT(varchar, @PRZEDZIAL1) + ' THEN ''2.  Do ' + CONVERT(varchar, @PRZEDZIAL1) + ' dni''
            WHEN DATEDIFF(day, TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL1) + ' AND ' + CONVERT(varchar, @PRZEDZIAL2) + ' THEN ''3. Od ' + CONVERT(varchar, @PRZEDZIAL1 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL2) + ' dni''
            WHEN DATEDIFF(day, TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL2) + ' AND ' + CONVERT(varchar, @PRZEDZIAL3) + ' THEN ''4. Od ' + CONVERT(varchar, @PRZEDZIAL2 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL3) + ' dni''
            WHEN DATEDIFF(day, TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL3) + ' AND ' + CONVERT(varchar, @PRZEDZIAL4) + ' THEN ''5. Od ' + CONVERT(varchar, @PRZEDZIAL3 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL4) + ' dni''
            WHEN DATEDIFF(day, TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL4) + ' AND ' + CONVERT(varchar, @PRZEDZIAL5) + ' THEN ''6. Od ' + CONVERT(varchar, @PRZEDZIAL4 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
            ELSE ''7. Powyżej ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
        END
    ELSE CASE
            WHEN DATEDIFF(day, DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) < 1 THEN ''1. W terminie''
            WHEN DATEDIFF(day, DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 AND ' + CONVERT(varchar, @PRZEDZIAL1) + ' THEN ''2.  Do ' + CONVERT(varchar, @PRZEDZIAL1) + ' dni''
            WHEN DATEDIFF(day, DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL1) + ' AND ' + CONVERT(varchar, @PRZEDZIAL2) + ' THEN ''3. Od ' + CONVERT(varchar, @PRZEDZIAL1 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL2) + ' dni''
            WHEN DATEDIFF(day, DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL2) + ' AND ' + CONVERT(varchar, @PRZEDZIAL3) + ' THEN ''4. Od ' + CONVERT(varchar, @PRZEDZIAL2 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL3) + ' dni''
            WHEN DATEDIFF(day, DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL3) + ' AND ' + CONVERT(varchar, @PRZEDZIAL4) + ' THEN ''5. Od ' + CONVERT(varchar, @PRZEDZIAL3 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL4) + ' dni''
            WHEN DATEDIFF(day, DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL4) + ' AND ' + CONVERT(varchar, @PRZEDZIAL5) + ' THEN ''6. Od ' + CONVERT(varchar, @PRZEDZIAL4 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
            ELSE ''7. Powyżej ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
        END
    END [Termin Zapadalności], 
    KontoNumer [Konto Pełny Numer], KontoNazwa [Konto Nazwa], KontoPrzeciw [Konto Przeciwstawne],
    CASE WHEN PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN PodmiotTyp = 2 THEN ''Bank''
         WHEN PodmiotTyp = 3 THEN ''Pracownik''
         WHEN PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END [Podmiot Pierwotny Typ], 
    pod.Pod_NIP [Podmiot Pierwotny NIP],
    PodmiotKod [Podmiot Pierwotny Kod], 
    PodmiotNazwa [Podmiot Pierwotny Nazwa],
    CASE WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN pod5.Pod_PodmiotTyp= 2 THEN ''Bank''
         WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik''
         WHEN pod5.Pod_PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END [Podmiot Typ], 
    pod5.Pod_NIP [Podmiot NIP],
    pod5.Pod_Kod [Podmiot Kod], 
    pod5.Pod_Nazwa1 [Podmiot Nazwa],
    KwotaDok [Kwota Dokumentu], --KwotaDokWal [Kwota Dokumentu Waluta],
    NULLIF(PozostajeWN,0) [Kwota Pozostała Wn], --NULLIF(PozostajeWN_Wal,0) [Kwota Pozostała Wn Waluta], 
    NULLIF(PozostajeMA,0) [Kwota Pozostała Ma], --NULLIF(PozostajeMA_Wal,0) [Kwota Pozostała Ma Waluta],
    CASE WHEN PozostajeWN = 0 THEN NULL ELSE Zwloka END [Liczba Dni Przeterminowania Wn], 
    CASE WHEN PozostajeMA = 0 THEN NULL ELSE Zwloka END [Liczba Dni Przeterminowania Ma]
    ,CASE DeE_FPlID
    WHEN 1 THEN ''gotówka''
    WHEN 2 THEN ''czek''
    WHEN 3 THEN ''przelew''
    WHEN 4 THEN ''kredyt''
    ELSE ''inna'' END [Forma Płatności]
    ,''Przeterminowany'' AS [Status]
    ,zal.Ope_Kod [Operator Wprowadzający] 
    ,mod.Ope_Kod [Operator Modyfikujący]
    /*
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), DataDokumentu, 111), ''/'', ''-'') [Data Dokumentu]
    ,REPLACE(CONVERT(VARCHAR(10), TerminPlatnosci, 111), ''/'', ''-'') [Data Termin Płatności]
    ,REPLACE(CONVERT(VARCHAR(10), DataOpe, 111), ''/'', ''-'') [Data Operacji]
    ,REPLACE(CONVERT(VARCHAR(10), DataWystawienia, 111), ''/'', ''-'') [Data Wystawienia]
    */
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), DataDokumentu, 111), ''/'', ''-'') [Data Dokumentu Dzień], YEAR(DataDokumentu) [Data Dokumentu Rok]
    ,DATEPART(quarter, DataDokumentu) [Data Dokumentu Kwartał], MONTH(DataDokumentu) [Data Dokumentu Miesiąc]
    ,(datepart(DY, datediff(d, 0, DataDokumentu) / 7 * 7 + 3)+6) / 7 [Data Dokumentu Tydzień Roku]
    ,REPLACE(CONVERT(VARCHAR(10), TerminPlatnosci, 111), ''/'', ''-'') [Data Termin Płatności Dzień], YEAR(TerminPlatnosci) [Data Termin Płatności Rok] 
    ,DATEPART(quarter, TerminPlatnosci) [Data Termin Płatności Kwartał], MONTH(TerminPlatnosci) [Data Termin Płatności Miesiąc]
    ,(datepart(DY, datediff(d, 0, TerminPlatnosci) / 7 * 7 + 3)+6) / 7 [Data Termin Płatności Tydzień Roku]
    ,REPLACE(CONVERT(VARCHAR(10), DataOpe, 111), ''/'', ''-'') [Data Operacji Dzień]
    ,REPLACE(CONVERT(VARCHAR(10), DataWystawienia, 111), ''/'', ''-'') [Data Wystawienia Dzień]
    ,GETDATE() [Data Analizy]
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
    
    ' + @kolumny 
    SET @select1 = 
N' FROM CDN.RozrachunkiNaDzien('
+ Convert(varchar,@DATAINT)
+ N', ' + Convert(varchar,@DATAODINT) + N', ' + Convert(varchar,@DATADOINT)
+ N', 1, 99999, '
+ Convert(varchar,@KONTOOD)
+ N','
+ Convert(varchar,@KONTODO)
+ N', 1, 3, ''-wszystkie-'','
+ Convert(varchar,@TYPDATY)
+','+Convert(varchar,@OOID)+')'

    SET @select2 =' 
    LEFT JOIN CDN.OkresyObrach ON IdOkresuObr = OOb_OObID
    LEFT JOIN CDN.DekretyElem ON DeE_DeEId = DeEId
    LEFT OUTER JOIN CDN.Kategorie kat1 ON DeE_KatId = kat1.Kat_KatID
    LEFT OUTER JOIN CDN.Konta k1 ON KontoIdx = k1.Acc_NumerIdx AND IdOkresuObr = k1.Acc_OObId
    LEFT OUTER JOIN CDN.Konta k2 ON KontoIdx = k2.Acc_NumerIdx AND IdOkresuObr + 1 = k2.Acc_OObId
    LEFT JOIN #tmpTwrGr Poz ON ISNULL(k1.Acc_AccId, k2.Acc_AccId) = Poz.gid 
    LEFT JOIN CDN.PodmiotyView pod ON k1.Acc_SlownikTyp = pod.Pod_PodmiotTyp And k1.Acc_SlownikId = pod.Pod_PodId
    LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod.Pod_GlID = pod5.Pod_PodId and pod.Pod_GlKod = pod5.Pod_Kod
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON k1.Acc_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON k1.Acc_OpeModID = mod.Ope_OpeId
WHERE DataDokumentu <= CONVERT(DATETIME,''' + @DATAANALIZY + ''')

'
SET @select3 ='
UNION ALL 
SELECT 
BAZ.Baz_Nazwa [Baza Firmowa], 
    KRo_Dokument [Dokument Numer], 
    KRo_Opis [Dokument Opis], KRo_IdentKsieg [Identyfikator Księgowy], CASE WHEN KRo_Bufor = 1 THEN ''TAK'' ELSE ''NIE'' END [Dokument Bufor],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Elementu], ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Elementu],
    KRo_NrKsiegi [Dziennik Numer], KRo_NrDziennika [Dziennik Cząstkowy Numer], OOb_Symbol [Okres Obrachunkowy], KRo_Waluta [Waluta], 
    CASE WHEN ''' + @TERMINDATA + ''' = ''Terminu Płatności''
    THEN CASE
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) < 1 THEN ''1. W terminie''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 AND ' + CONVERT(varchar, @PRZEDZIAL1) + ' THEN ''2.  Do ' + CONVERT(varchar, @PRZEDZIAL1) + ' dni''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL1) + ' AND ' + CONVERT(varchar, @PRZEDZIAL2) + ' THEN ''3. Od ' + CONVERT(varchar, @PRZEDZIAL1 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL2) + ' dni''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL2) + ' AND ' + CONVERT(varchar, @PRZEDZIAL3) + ' THEN ''4. Od ' + CONVERT(varchar, @PRZEDZIAL2 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL3) + ' dni''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL3) + ' AND ' + CONVERT(varchar, @PRZEDZIAL4) + ' THEN ''5. Od ' + CONVERT(varchar, @PRZEDZIAL3 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL4) + ' dni''
            WHEN DATEDIFF(day, KRo_TerminPlatnosci, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL4) + ' AND ' + CONVERT(varchar, @PRZEDZIAL5) + ' THEN ''6. Od ' + CONVERT(varchar, @PRZEDZIAL4 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
            ELSE ''7. Powyżej ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
        END
    ELSE CASE
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) < 1 THEN ''1. W terminie''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 AND ' + CONVERT(varchar, @PRZEDZIAL1) + ' THEN ''2.  Do ' + CONVERT(varchar, @PRZEDZIAL1) + ' dni''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL1) + ' AND ' + CONVERT(varchar, @PRZEDZIAL2) + ' THEN ''3. Od ' + CONVERT(varchar, @PRZEDZIAL1 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL2) + ' dni''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL2) + ' AND ' + CONVERT(varchar, @PRZEDZIAL3) + ' THEN ''4. Od ' + CONVERT(varchar, @PRZEDZIAL2 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL3) + ' dni''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL3) + ' AND ' + CONVERT(varchar, @PRZEDZIAL4) + ' THEN ''5. Od ' + CONVERT(varchar, @PRZEDZIAL3 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL4) + ' dni''
            WHEN DATEDIFF(day, KRo_DataDokumentu, CONVERT(DATETIME,''' + @DATAANALIZY + ''')) BETWEEN 1 + ' + CONVERT(varchar, @PRZEDZIAL4) + ' AND ' + CONVERT(varchar, @PRZEDZIAL5) + ' THEN ''6. Od ' + CONVERT(varchar, @PRZEDZIAL4 + 1) + ' do ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
            ELSE ''7. Powyżej ' + CONVERT(varchar, @PRZEDZIAL5) + ' dni''
        END
    END [Termin Zapadalności], 
    KRo_Konto [Konto Pełny Numer], k1.Acc_Nazwa [Konto Nazwa], KRo_KontoPrzeciw [Konto Przeciwstawne],
    CASE WHEN DeN_PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN DeN_PodmiotTyp = 2 THEN ''Bank''
         WHEN DeN_PodmiotTyp = 3 THEN ''Pracownik''
         WHEN DeN_PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN DeN_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END [Podmiot Pierwotny Typ], 
    pod.Pod_NIP [Podmiot Pierwotny NIP],
    pod.Pod_Kod [Podmiot Pierwotny Kod], 
    pod.Pod_Nazwa1 [Podmiot Pierwotny Nazwa],
    CASE WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN pod5.Pod_PodmiotTyp= 2 THEN ''Bank''
         WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik''
         WHEN pod5.Pod_PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END [Podmiot Typ], 
    pod5.Pod_NIP [Podmiot NIP],
    pod5.Pod_Kod [Podmiot Kod], 
    pod5.Pod_Nazwa1 [Podmiot Nazwa],
    KRo_KwotaDok [Kwota Dokumentu], --KwotaDokWal [Kwota Dokumentu Waluta],
    0 [Kwota Pozostała Wn], --NULLIF(PozostajeWN_Wal,0) [Kwota Pozostała Wn Waluta], 
    0 [Kwota Pozostała Ma], --NULLIF(PozostajeMA_Wal,0) [Kwota Pozostała Ma Waluta],
    NULL [Liczba Dni Przeterminowania Wn], 
    NULL [Liczba Dni Przeterminowania Ma]
    ,CASE DeE_FPlID
    WHEN 1 THEN ''gotówka''
    WHEN 2 THEN ''czek''
    WHEN 3 THEN ''przelew''
    WHEN 4 THEN ''kredyt''
    ELSE ''inna'' END [Forma Płatności]
    ,''Rozrachowany'' AS [Status]
    ,zal.Ope_Kod [Operator Wprowadzający] 
    ,mod.Ope_Kod [Operator Modyfikujący]
    /*
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), KRo_DataDokumentu, 111), ''/'', ''-'') [Data Dokumentu]
    ,REPLACE(CONVERT(VARCHAR(10), KRo_TerminPlatnosci, 111), ''/'', ''-'') [Data Termin Płatności]
    ,REPLACE(CONVERT(VARCHAR(10), KRo_DataOperacji, 111), ''/'', ''-'') [Data Operacji]
    ,REPLACE(CONVERT(VARCHAR(10), KRo_DataOperacji, 111), ''/'', ''-'') [Data Wystawienia]
    */
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), KRo_DataDokumentu, 111), ''/'', ''-'') [Data Dokumentu Dzień], YEAR(KRo_DataDokumentu) [Data Dokumentu Rok]
    ,DATEPART(quarter, KRo_DataDokumentu) [Data Dokumentu Kwartał], MONTH(KRo_DataDokumentu) [Data Dokumentu Miesiąc]
    ,(datepart(DY, datediff(d, 0, KRo_DataDokumentu) / 7 * 7 + 3)+6) / 7 [Data Dokumentu Tydzień Roku]
    ,REPLACE(CONVERT(VARCHAR(10), KRo_TerminPlatnosci, 111), ''/'', ''-'') [Data Termin Płatności Dzień], YEAR(KRo_TerminPlatnosci) [Data Termin Płatności Rok] 
    ,DATEPART(quarter, KRo_TerminPlatnosci) [Data Termin Płatności Kwartał], MONTH(KRo_TerminPlatnosci) [Data Termin Płatności Miesiąc]
    ,(datepart(DY, datediff(d, 0, KRo_TerminPlatnosci) / 7 * 7 + 3)+6) / 7 [Data Termin Płatności Tydzień Roku]
    ,REPLACE(CONVERT(VARCHAR(10), KRo_DataOperacji, 111), ''/'', ''-'') [Data Operacji Dzień]
    ,REPLACE(CONVERT(VARCHAR(10), KRo_DataOperacji, 111), ''/'', ''-'') [Data Wystawienia Dzień]
    ,GETDATE() [Data Analizy]
    ----------KONTEKSTY
    ,26002 [Dokument Numer __PROCID__Rozrachunki__], DeE_DeNId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,CASE DeN_PodmiotTyp
        WHEN 1 THEN 20201
        WHEN 2 THEN 23002
        WHEN 3 THEN 24001
        WHEN 5 THEN 25005
        ELSE 20201
    END [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], pod.Pod_PodId [Podmiot Pirwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__]
    ,CASE DeN_PodmiotTyp
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
    
    ' + @kolumny + '
 FROM CDN.KsiRozrachunki
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
    WHERE KRo_KwotaDok-KRo_SumRozliczen = 0
    AND OOb_OObID = '+Convert(varchar,@OOID)+'
    AND k1.Acc_NumerIdx BETWEEN '''+ Convert(varchar,@kontoodidx)+ ''' AND '''+ Convert(varchar,@kontodoidx)+'''
'

print(@select)
EXEC(@select+@select1+@select2+@select3)
DROP TABLE #tmpTwrGr













