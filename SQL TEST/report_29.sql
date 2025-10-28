/*
* Raport Kontrahentów
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.5.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
--Wyliczanie poziomów grup produktów
WITH g (
    gid
    ,gidTyp
    ,kod
    ,gidNumer
    ,grONumer
    ,poziom
    ,sciezka
    )
AS (
    SELECT TwG_TwGID
        ,TwG_GIDTyp
        ,TwG_Kod
        ,TwG_GIDNumer
        ,TwG_GrONumer
        ,0 AS poziom
        ,convert(NVARCHAR(1024), '') AS sciezka
    FROM CDN.TwrGrupy
    WHERE TwG_TwGID = 0
    
    UNION ALL
    
    SELECT TwG_TwGID
        ,TwG_GIDTyp
        ,TwG_Kod
        ,TwG_GIDNumer
        ,TwG_GrONumer
        ,p.poziom + 1 AS poziom
        ,convert(NVARCHAR(1024), p.sciezka + N'\' + c.TwG_Kod) AS sciezka
    FROM g p
    JOIN CDN.TwrGrupy c ON c.TwG_GrONumer = p.gidNumer
    WHERE c.TwG_TwGID <> 0
        AND c.TwG_GIDTyp = - 16
    )
SELECT *
INTO #tmpTwrGr
FROM g

DECLARE @poziom INT
DECLARE @poziom_max INT
DECLARE @sql NVARCHAR(max)

SELECT @poziom_max = MAX(poziom)
FROM #tmpTwrGr

SET @poziom = @poziom_max
SET @sql = N''

WHILE @poziom >= 0
BEGIN
    SET @sql = N'ALTER TABLE #tmpTwrGr ADD Poziom' + CAST(@poziom AS NVARCHAR) + N' nvarchar(50), ONr' + CAST(@poziom AS NVARCHAR) + N' nvarchar(50)'

    EXEC (@sql)

    IF @poziom = @poziom_max
    BEGIN
        SET @sql = N'UPDATE #tmpTwrGr
                SET ONr' + CAST(@poziom AS NVARCHAR) + '= grONumer '

        EXEC (@sql)

        SET @sql = N'UPDATE #tmpTwrGr
                SET Poziom' + CAST(@poziom AS NVARCHAR) + ' = kod'

        EXEC (@sql)
    END
    ELSE
    BEGIN
        SET @sql = N'UPDATE c
                SET c.Poziom' + CAST(@poziom AS NVARCHAR) + N' = (
                    CASE WHEN c.poziom <=' + CAST(@poziom AS NVARCHAR) + N' THEN CAST(c.kod AS nvarchar)
                    ELSE CAST(p.kod AS nvarchar) END)  
                FROM #tmpTwrGr c
                LEFT JOIN #tmpTwrGr p
                ON c.ONr' + CAST(@poziom + 1 AS NVARCHAR) + '= p.gidNumer '

        EXEC (@sql)

        SET @sql = N'UPDATE c
                SET c.ONr' + CAST(@poziom AS NVARCHAR) + N' = (
                    CASE WHEN c.poziom <=' + CAST(@poziom AS NVARCHAR) + N' THEN CAST(c.grONumer AS nvarchar)
                    ELSE CAST(p.grONumer AS nvarchar) END)  
                FROM #tmpTwrGr c
                LEFT JOIN #tmpTwrGr p
                ON c.ONr' + CAST(@poziom + 1 AS NVARCHAR) + '= p.gidNumer '

        EXEC (@sql)
    END

    SET @poziom = @poziom - 1
END

DECLARE @select VARCHAR(max)
DECLARE @select2 VARCHAR(max)
DECLARE @select3 VARCHAR(max)
DECLARE @kolumny VARCHAR(max)
DECLARE @i INT

SET @kolumny = ''
SET @i = 0

WHILE (@i <= @poziom_max)
BEGIN
    SET @kolumny = @kolumny + ',"Produkt Grupa Poziom ' + LTRIM(@i) + '" = CASE WHEN Poz.Poziom' + LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' + LTRIM(@i) + ' END'
    SET @i = @i + 1
END

--Wyliczanie Atrybutów Kontrahentów
DECLARE @atrybut_id INT
    ,@atrybut_kod NVARCHAR(50)
    ,@atrybut_typ INT
    ,@atrybut_format INT
    ,@atrybuty VARCHAR(max)
    ,@sqlA NVARCHAR(max);
DECLARE @wersja FLOAT;

SET @wersja = (
        SELECT CONVERT(FLOAT, SYS_Wartosc)
        FROM CDN.SystemCDN
        WHERE SYS_ID = 3
        )
SET @sqlA = 'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT KnA_DeAid FROM CDN.KntAtrybuty)
AND DeA_Format <> 5'

IF @wersja >= 2013
    SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'

EXEC (@sqlA)

OPEN atrybut_cursor;

FETCH NEXT
FROM atrybut_cursor
INTO @atrybut_id
    ,@atrybut_kod
    ,@atrybut_typ
    ,@atrybut_format;

SELECT DISTINCT KnA_PodmiotId
    ,KnA_PodmiotTyp
INTO #tmpKonAtr
FROM CDN.KntAtrybuty

SET @atrybuty = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 1
    BEGIN
        SET @atrybut_kod = @atrybut_kod + ' (T)'
    END

    IF @atrybut_typ = 4
    BEGIN
        SET @atrybut_kod = @atrybut_kod + ' (D)'
    END

    SET @sqlA = N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS NVARCHAR(50)) + N'] nvarchar(max)'

    EXEC (@sqlA)

    SET @sqlA = N'UPDATE #tmpKonAtr
        SET [' + CAST(@atrybut_kod AS NVARCHAR(50)) + '] = CASE WHEN ' + convert(VARCHAR, @atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.KnA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
          ELSE CASE WHEN ' + convert(VARCHAR, @atrybut_format) + ' = 2  THEN REPLACE(ATR.KnA_WartoscTxt,'','',''.'') ELSE ATR.KnA_WartoscTxt END 
        END    
        FROM CDN.KntAtrybuty ATR 
        JOIN #tmpKonAtr TM ON ATR.KnA_PodmiotId = TM.KnA_PodmiotId AND ATR.KnA_PodmiotTyp = TM.KnA_PodmiotTyp
        WHERE ATR.KnA_DeAId = ' + CAST(@atrybut_id AS NVARCHAR)

    EXEC (@sqlA)

    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' + CAST(@atrybut_kod AS NVARCHAR(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Atrybut ' + CAST(@atrybut_kod AS NVARCHAR(50)) + ']'

    FETCH NEXT
    FROM atrybut_cursor
    INTO @atrybut_id
        ,@atrybut_kod
        ,@atrybut_typ
        ,@atrybut_format;
END

CLOSE atrybut_cursor;

DEALLOCATE atrybut_cursor;


--Wyliczanie Atrybutów Towarów
DECLARE @atrybutyTwr VARCHAR(max)
    ,@atrybutyTwr2 VARCHAR(max);

SET @sqlA = 'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT TwA_DeAid FROM CDN.TwrAtrybuty WHERE TwA_TwrId IS NOT NULL)
AND DeA_Format <> 5'

IF @wersja >= 2013
    SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'

EXEC (@sqlA)

OPEN atrybut_cursor;

FETCH NEXT
FROM atrybut_cursor
INTO @atrybut_id
    ,@atrybut_kod
    ,@atrybut_typ
    ,@atrybut_format;

SELECT DISTINCT TwA_TwrId
INTO #tmpTwrAtr
FROM CDN.TwrAtrybuty

SET @atrybutyTwr = ''
SET @atrybutyTwr2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2
    BEGIN
        SET @atrybut_kod = @atrybut_kod + ' (K)'
    END

    IF @atrybut_typ = 4
    BEGIN
        SET @atrybut_kod = @atrybut_kod + ' (D)'
    END

    SET @sqlA = N'ALTER TABLE #tmpTwrAtr ADD [' + CAST(@atrybut_kod AS NVARCHAR(50)) + N'] nvarchar(max)'

    EXEC (@sqlA)

    SET @sqlA = N'UPDATE #tmpTwrAtr
        SET [' + CAST(@atrybut_kod AS NVARCHAR(50)) + '] = CASE WHEN ' + convert(VARCHAR, @atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TwA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(VARCHAR, @atrybut_format) + ' = 2  THEN REPLACE(ATR.TwA_WartoscTxt,'','',''.'') ELSE ATR.TwA_WartoscTxt END 
        END  
        FROM CDN.TwrAtrybuty ATR 
        JOIN #tmpTwrAtr TM ON ATR.TwA_TwrId = TM.TwA_TwrId 
        WHERE ATR.TwA_DeAId = ' + CAST(@atrybut_id AS NVARCHAR)

    EXEC (@sqlA)

    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' + CAST(@atrybut_kod AS NVARCHAR(50)) + '], ''(NIEPRZYPISANE)'') [Produkt Atrybut ' + CAST(@atrybut_kod AS NVARCHAR(50)) + ']'
    SET @atrybutyTwr2 = @atrybutyTwr2 + N', ''(NIEPRZYPISANE)'' [Produkt Atrybut ' + CAST(@atrybut_kod AS NVARCHAR(50)) + ']'

    FETCH NEXT
    FROM atrybut_cursor
    INTO @atrybut_id
        ,@atrybut_kod
        ,@atrybut_typ
        ,@atrybut_format;
END

CLOSE atrybut_cursor;

DEALLOCATE atrybut_cursor;

DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @bazaFirmowa varchar(max);
DECLARE @Bazy varchar(max);
DECLARE @Operatorzy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 

SELECT ISNULL(SUM(CASE WHEN TrS_Rodzaj in (312000,312008) AND TrS_Ilosc < 0 AND TrS_ZwrId IS NULL THEN 0
                                   WHEN (TrS_Rodzaj = 308000 OR TrS_Rodzaj = 308011) AND TrS_Ilosc < 0 THEN 0
                                   ELSE TrS_Wartosc
                              END),0) as Koszt,
                           TRE.TrE_TrEID
                           INTO #KosztZakupu
            FROM CDN.TraElem TRE
            JOIN ( SELECT TrE_TrEId as IdElem, TrE_TrEId as IdZwiaz
                   FROM CDN.TraElem
                   UNION ALL
                   SELECT TRE.TrE_TrEId, TRERel.TrE_TreId
                     FROM cdn.TraElem TRE
                       JOIN cdn.TraNag TRN ON TRE.TrE_TrNId = TrN_TrNId
                       JOIN cdn.TraNagRelacje  ON TrN_TrNId = TrR_FaId AND TrR_Flaga <> 1
                       JOIN cdn.TraElem TRERel ON TRERel.Tre_trnid = TrR_TrnId AND TREREl.Tre_lppow= tre.tre_lppow AND TREREl.TrE_TwrID = TRE.TrE_TwrID
                     WHERE TrR_FaId = TRE.TrE_TrNId  AND TRERel.TrE_TypDokumentu NOT IN ( 318,309,308,301 )
                 ) AS Elem ON TRE.Tre_TrEId = Elem.IdElem
            JOIN CDN.TraSElem TRS ON TRS.TrS_TrEId = Elem.IdZwiaz
            GROUP BY TRE.TrE_TrEID

--DECLARE @select VARCHAR(MAX);
--DECLARE @select2 VARCHAR(MAX);

--Wyliczenie miar sprzedaży dla kontrahentów
SELECT
dd.DDf_Symbol DDf_Symbol,
knt.Knt_KntId [knt_id],
trn.TrN_TrNID,
sum(TR.TrE_WartoscNetto) [sprzedazWartosc],
sum(TR.TrE_Ilosc ) [ilosc],
sum(TR.TrE_WartoscBrutto) [sprzedazWartoscBrutto],
sum(TR.TrE_WartoscNettoWal) [sprzedazWartoscWaluta],
sum(TR.TrE_WartoscNetto - (CASE WHEN TrN_Rodzaj IN (302101,302102,302103,305101) THEN -1 ELSE 1 END *(ISNULL(KosztWyliczony.Koszt ,0) + TR.TrE_KosztUslugi))) marza
,trn.TrN_DataOpe dataop
,TrE_TwrId Towar
INTO #tmpKntSprz

FROM cdn.Kontrahenci knt
left join cdn.tranag trn ON trn.TrN_PodID=Knt_KntId  AND TrN_PodmiotTyp = 1
left join cdn.TraElem TR ON TR.TrE_TrNID=trn.TrN_TrNID 
LEFT JOIN #KosztZakupu KosztWyliczony  ON KosztWyliczony.TrE_TrEID = TR.TrE_TrEID 
LEFT JOIN CDN.DokDefinicje dd ON trn.TrN_DDfId = dd.DDf_DDfID
WHERE
trn.TrN_TypDokumentu IN (-1,302,305)
AND trn.TrN_Bufor<>-1
 AND  TRN_Rodzaj NOT IN (302200,302202)
--AND TrE_Aktywny<>0
--AND TrE_UslugaZlozonaId = 0
GROUP BY Knt_KntId,trn.TrN_DataOpe,TrE_TwrId,DDf_Symbol,trn.TrN_TrNID
SELECT DDf_DDfID ddfid
    ,CASE 
        WHEN DDf_Numeracja LIKE '@rejestr%'
            THEN 5
        WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja, CHARINDEX('/', ddf_numeracja, 0) + 1, 50), '@brak/', ''), '/@brak', ''), '/', '.'), 1) = '@rejestr'
            THEN 1
        WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja, CHARINDEX('/', ddf_numeracja, 0) + 1, 50), '@brak/', ''), '/@brak', ''), '/', '.'), 2) = '@rejestr'
            THEN 2
        WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja, CHARINDEX('/', ddf_numeracja, 0) + 1, 50), '@brak/', ''), '/@brak', ''), '/', '.'), 3) = '@rejestr'
            THEN 3
        WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja, CHARINDEX('/', ddf_numeracja, 0) + 1, 50), '@brak/', ''), '/@brak', ''), '/', '.'), 4) = '@rejestr'
            THEN 4
        END [seria]
INTO #tmpSeria
FROM CDN.DokDefinicje

set @select = 
' 
SELECT
BAZ.Baz_Nazwa [Baza Firmowa],
DDf_Symbol [Dokument Symbol],
TrN_TrNID [Liczba dokumentów],
KNT.knt_nazwa1 [Kontrahent Nazwa], 
KNT.knt_kod [Kontrahent Kod],
reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE KNT.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE KNT.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE KNT.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE KNT.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE KNT.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Rodzaj],
CASE WHEN g.id IS NULL THEN ''Nie'' ELSE ''Tak'' END [Kontrahent ze Sprzedażą/Zakupem],
CASE KNT.Knt_Nieaktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Kontrahent Aktywny],
DB_NAME()+''_''+convert(Varchar(10),KNT.knt_PodmiotTyp)+''_''+convert(Varchar(10),KNT.Knt_KntId)  [Liczba Kontrahentów],
CASE WHEN g.id IS NULL THEN NULL ELSE sprzedazWartosc END [Sprzedaż Wartość Suma],
CASE WHEN g.id IS NULL THEN NULL ELSE ilosc END [Sprzedaż Ilość Suma],
CASE WHEN g.id IS NULL THEN NULL ELSE sprzedazWartoscBrutto END [Sprzedaż Wartość Brutto Suma],
CASE WHEN g.id IS NULL THEN NULL ELSE sprzedazWartoscWaluta END [Sprzedaż Wartość Waluta Suma],
CASE WHEN g.id IS NULL THEN NULL ELSE marza END [Sprzedaż Marża Suma],
NULL [Pierwsza Sprzedaż Wartość],
NULL [Pierwsza Sprzedaż Ilość],
NULL [Pierwsza Sprzedaż Wartość Brutto],
NULL [Pierwsza Sprzedaż Wartość Waluta],
NULL [Pierwsza Sprzedaż Marża],
ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca], 
Twr_Kod [Produkt Kod],
ISNULL(Twr_EAN,''(BRAK)'') [Produkt EAN],
ISNULL(Twr_KodDostawcy,''(BRAK)'') [Produkt Kod Dostawcy],
zal.Ope_Kod [Operator Wprowadzający], 
mod.Ope_Kod [Operator Modyfikujący]
,ISNULL(opk3.Ope_Kod, ''(NIEPRZYPISANE)'') [Kontrahent Opiekun]
,CONVERT(VARCHAR,ISNULL(Rab_Rabat,0))+''%'' [Kontrahent Rabat]
,KNT.KNT_Kraj [Kontrahent Kraj]
,KNT.KNT_Miasto [Kontrahent Miasto]
,KNT.Knt_Wojewodztwo [Kontrahent Województwo]
,KNT.KNT_pOWIAT [Kontrahent Powiat]
,KNT.KNT_KodPocztowy [Kontrahent Kod Pocztowy]
,KNT.Knt_Ulica [Kontrahent Ulica]
,''(BRAK)'' [Dokument Seria]
/*
--------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), pierwsza, 111), ''/'', ''-'') [Data Pierwszej Operacji] 
,REPLACE(CONVERT(VARCHAR(10), ostatnia, 111), ''/'', ''-'') [Data Ostatniej Operacji]
,REPLACE(CONVERT(VARCHAR(10), dataop, 111), ''/'', ''-'') [Data Operacji] 
*/
----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), pierwsza, 111), ''/'', ''-'') [Data Pierwszej Operacji Dzień] 
,(datepart(DY, datediff(d, 0, pierwsza) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, pierwsza)*/ [Data Pierwszej Operacji Tydzień Roku]
,MONTH(pierwsza) [Data Pierwszej Operacji Miesiąc], DATEPART(quarter, pierwsza) [Data Pierwszej Operacji Kwartał], YEAR(pierwsza) [Data Pierwszej Operacji Rok] 
,REPLACE(CONVERT(VARCHAR(10), ostatnia, 111), ''/'', ''-'') [Data Ostatniej Operacji Dzień]
,(datepart(DY, datediff(d, 0, ostatnia) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, ostatnia)*/ [Data Ostatniej Operacji Tydzień Roku]
,MONTH(ostatnia) [Data Ostatniej Operacji Miesiąc], DATEPART(quarter, ostatnia) [Data Ostatniej Operacji Kwartał], YEAR(ostatnia) [Data Ostatniej Operacji Rok]

,REPLACE(CONVERT(VARCHAR(10), dataop, 111), ''/'', ''-'') [Data Operacji Dzień]
,(datepart(DY, datediff(d, 0, dataop) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, ostatnia)*/ [Data Operacji Tydzień Roku]
,MONTH(dataop) [Data Operacji Miesiąc], DATEPART(quarter, dataop) [Data Operacji Kwartał], YEAR(dataop) [Data Operacji Rok]

,REPLACE(CONVERT(VARCHAR(10), knt.Knt_ts_zAL, 111), ''/'', ''-'') [Data Dodania Kontrahenta Dzień]
,(datepart(DY, datediff(d, 0, knt.Knt_ts_zAL) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, ostatnia)*/ [Data Dodania Kontrahenta Tydzień Roku]
,MONTH(knt.Knt_ts_zAL) [Data Dodania Kontrahenta Miesiąc], DATEPART(quarter, knt.Knt_ts_zAL) [Data Dodania Kontrahenta Kwartał], YEAR(knt.Knt_ts_zAL) [Data Dodania Kontrahenta Rok]



,GETDATE() [Data Analizy]
----------KONTEKSTY
,20201 [Kontrahent Nazwa __PROCID__], KNT.Knt_KntId [Kontrahent Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Nazwa __DATABASE__]
,20201 [Kontrahent Kod __PROCID__Kontrahenci__], KNT.Knt_KntId [Kontrahent Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Kod __DATABASE__]

' + @kolumny + @atrybuty  + @atrybutyTwr 
set @select2 = 
'

from cdn.kontrahenci KNT

Left join
(
Select distinct 
TrN_PodID [id],
MIN(TrN_DataOpe) OVER(PARTITION BY TrN_PodID) AS pierwsza, 
MAX(TrN_DataOpe) OVER(PARTITION BY TrN_PodID) AS ostatnia  
from
cdn.tranag  WHERE TrN_TypDokumentu IN (302,305) AND TRN_Bufor = 0 AND  TRN_Rodzaj NOT IN (302200,302202)
GROUP BY TrN_PodID,TrN_DataOpe) g ON g.id = KNT.Knt_KntID
left join #tmpKntSprz a ON KNT.Knt_KntID = a.knt_id

     LEFT JOIN CDN.Towary ON towar=Twr_TwrId
	 LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
     LEFT JOIN #tmpKonAtr KonAtr ON KNT.knt_kntid = KonAtr.KnA_PodmiotId AND KNT.knt_PodmiotTyp = KonAtr.KnA_PodmiotTyp
     LEFT JOIN #tmpTwrAtr TwrAtr ON towar  = TwrAtr.TwA_TwrId 

     LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId


    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON KNT.Knt_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON KNT.Knt_OpeModID = mod.Ope_OpeId
LEFT JOIN CDN.Rabaty on rab_podmiotid = knt.knt_kntid and rab_typ = 2 AND dataop BETWEEN Rab_DataOd AND Rab_DataDo
     LEFT JOIN ' + @Operatorzy + ' opk3 ON knt.Knt_OpiekunId = opk3.Ope_OpeId AND knt.Knt_OpiekunTyp = 8 


UNION ALL 

SELECT  

BAZ.Baz_Nazwa  [Baza Firmowa],
DDf_Symbol [Dokument Symbol],
TrN_TrNID [Liczba dokumentów],
KNT.knt_nazwa1 [Kontrahent Nazwa], 
KNT.knt_kod [Kontrahent Kod],
reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE KNT.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE KNT.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE KNT.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE KNT.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE KNT.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Rodzaj],
''Tak''  [Kontrahent ze Sprzedażą/Zakupem],
CASE KNT.Knt_Nieaktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Kontrahent Aktywny],
DB_NAME()+''_''+convert(Varchar(10),KNT.knt_PodmiotTyp)+''_''+convert(Varchar(10),KNT.Knt_KntId)  [Liczba Kontrahentów],
NULL [Sprzedaż Wartość Suma],
NULL [Sprzedaż Ilość Suma],
NULL [Sprzedaż Wartość Brutto Suma],
NULL [Sprzedaż Wartość Waluta Suma],
NULL [Sprzedaż Marża Suma],
TrE_WartoscNetto [Pierwsza Sprzedaż Wartość],
TrE_Ilosc [Pierwsza Sprzedaż Ilość],
TrE_WartoscBrutto [Pierwsza Sprzedaż Wartość Brutto],
TrE_WartoscNettoWal [Pierwsza Sprzedaż Wartość Waluta],
TrE_WartoscNetto - (CASE WHEN TrN_Rodzaj IN (302101,302102,302103,305101) THEN -1 ELSE 1 END *(ISNULL(KosztWyliczony.Koszt ,0) + TR.TrE_KosztUslugi)) [Pierwsza Sprzedaż Marża],
ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca], 
Twr_Kod [Produkt Kod],
ISNULL(Twr_EAN,''(BRAK)'') [Produkt EAN],
ISNULL(Twr_KodDostawcy,''(BRAK)'') [Produkt Kod Dostawcy],
zal.Ope_Kod [Operator Wprowadzający], 
mod.Ope_Kod [Operator Modyfikujący]
,ISNULL(opk3.Ope_Kod, ''(NIEPRZYPISANE)'') [Kontrahent Opiekun]
,CONVERT(VARCHAR,ISNULL(Rab_Rabat,0))+''%'' [Kontrahent Rabat]
,KNT.KNT_Kraj [Kontrahent Kraj]
,KNT.KNT_Miasto [Kontrahent Miasto]
,KNT.Knt_Wojewodztwo [Kontrahent Województwo]
,KNT.KNT_pOWIAT [Kontrahent Powiat]
,KNT.KNT_KodPocztowy [Kontrahent Kod Pocztowy]
,KNT.Knt_Ulica [Kontrahent Ulica]

    ,CASE when isnull(ser.seria,0) = 5 then 
        substring(TrN_NumerPelny,0,CHARINDEX(''/'',TrN_NumerPelny,0))
    ELSE 
        ISNULL(PARSENAME(REPLACE(substring(TrN_NumerPelny,CHARINDEX(''/'',TrN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
    END [Dokument Seria]

/*
--------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), pierwsza, 111), ''/'', ''-'') [Data Pierwszej Operacji] 
,REPLACE(CONVERT(VARCHAR(10), ostatnia, 111), ''/'', ''-'') [Data Ostatniej Operacji]
,REPLACE(CONVERT(VARCHAR(10), pierwsza, 111), ''/'', ''-'') [Data Operacji] 
*/
----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), pierwsza, 111), ''/'', ''-'') [Data Pierwszej Operacji Dzień] 
,(datepart(DY, datediff(d, 0, pierwsza) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, pierwsza)*/ [Data Pierwszej Operacji Tydzień Roku]
,MONTH(pierwsza) [Data Pierwszej Operacji Miesiąc], DATEPART(quarter, pierwsza) [Data Pierwszej Operacji Kwartał], YEAR(pierwsza) [Data Pierwszej Operacji Rok] 
,REPLACE(CONVERT(VARCHAR(10), ostatnia, 111), ''/'', ''-'') [Data Ostatniej Operacji Dzień]
,(datepart(DY, datediff(d, 0, ostatnia) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, ostatnia)*/ [Data Ostatniej Operacji Tydzień Roku]
,MONTH(ostatnia) [Data Ostatniej Operacji Miesiąc], DATEPART(quarter, ostatnia) [Data Ostatniej Operacji Kwartał], YEAR(ostatnia) [Data Ostatniej Operacji Rok]

,REPLACE(CONVERT(VARCHAR(10), pierwsza, 111), ''/'', ''-'') [Data Operacji Dzień]
,(datepart(DY, datediff(d, 0, pierwsza) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, ostatnia)*/ [Data Operacji Tydzień Roku]
,MONTH(pierwsza) [Data Operacji Miesiąc], DATEPART(quarter, pierwsza) [Data Operacji Kwartał], YEAR(pierwsza) [Data Operacji Rok]

,REPLACE(CONVERT(VARCHAR(10), knt.Knt_ts_zAL, 111), ''/'', ''-'') [Data Dodania Kontrahenta Dzień]
,(datepart(DY, datediff(d, 0, knt.Knt_ts_zAL) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, ostatnia)*/ [Data Dodania Kontrahenta Tydzień Roku]
,MONTH(knt.Knt_ts_zAL) [Data Dodania Kontrahenta Miesiąc], DATEPART(quarter, knt.Knt_ts_zAL) [Data Dodania Kontrahenta Kwartał], YEAR(knt.Knt_ts_zAL) [Data Dodania Kontrahenta Rok]

,GETDATE() [Data Analizy]
----------KONTEKSTY
,20201 [Kontrahent Nazwa __PROCID__], KNT.Knt_KntId [Kontrahent Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Nazwa __DATABASE__]
,20201 [Kontrahent Kod __PROCID__Kontrahenci__], KNT.Knt_KntId [Kontrahent Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Kod __DATABASE__]
' + @kolumny + @atrybuty  + @atrybutyTwr +'
FROM 
(
SELECT Trn_trnid id, MIN(TrN_DataOpe) OVER(PARTITION BY TrN_PodID) AS pierwsza, MAX(TrN_DataOpe) OVER(PARTITION BY TrN_PodID) AS ostatnia  
FROM CDN.Tranag WHERE TrN_TypDokumentu IN (302,305) AND TRN_Bufor = 0 AND  TRN_Rodzaj NOT IN (302200,302202))x 
JOIN cdn.tranag ON id = TrN_TrNID and pierwsza = TrN_DataOpe
left join cdn.TraElem TR ON TR.TrE_TrNID=TrN_TrNID 
LEFT JOIN cdn.Kontrahenci KNT ON TrN_PodID=KNT.Knt_KntId  AND TrN_PodmiotTyp = 1
     JOIN CDN.Towary ON TrE_TwrId=Twr_TwrId
	 LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
     LEFT JOIN #tmpKonAtr KonAtr ON KNT.knt_kntid = KonAtr.KnA_PodmiotId AND KNT.knt_PodmiotTyp = KonAtr.KnA_PodmiotTyp
     LEFT JOIN #tmpTwrAtr TwrAtr ON TrE_TwrId  = TwrAtr.TwA_TwrId 

     LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
     LEFT JOIN #KosztZakupu KosztWyliczony  ON KosztWyliczony.TrE_TrEID = TR.TrE_TrEID 
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
     LEFT JOIN ' + @Operatorzy + ' zal ON knt4.Knt_OpeZalID = zal.Ope_OpeId
     LEFT JOIN ' + @Operatorzy + ' mod ON knt4.Knt_OpeModID = mod.Ope_OpeId
	 LEFT JOIN CDN.Rabaty on rab_podmiotid = knt.knt_kntid and rab_typ = 2 AND pierwsza BETWEEN Rab_DataOd AND Rab_DataDo
	      LEFT JOIN ' + @Operatorzy + ' opk3 ON knt.Knt_OpiekunId = opk3.Ope_OpeId AND knt.Knt_OpiekunTyp = 8 
     LEFT JOIN CDN.DokDefinicje  ON TrN_DDfId = DDf_DDfID
	  LEFT JOIN #tmpSeria ser ON TrN_DDfId = ddfid
'

print (@select + @select2)
exec (@select + @select2)

drop table #tmpKntSprz
Drop Table #KosztZakupu
DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpSeria






