/*
* Raport Sprzedaży 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
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

    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' + CAST(@atrybut_kod AS NVARCHAR(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Pierwotny Atrybut ' + CAST(@atrybut_kod AS NVARCHAR(50)) + ']'
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr1.[' + CAST(@atrybut_kod AS NVARCHAR(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Atrybut ' + CAST(@atrybut_kod AS NVARCHAR(50)) + ']'
    SET @atrybuty = @atrybuty + N', ISNULL(OdbAtr.[' + CAST(@atrybut_kod AS NVARCHAR(50)) + '], ''(NIEPRZYPISANE)'') AS [Odbiorca Atrybut ' + CAST(@atrybut_kod AS NVARCHAR(50)) + ']'

    FETCH NEXT
    FROM atrybut_cursor
    INTO @atrybut_id
        ,@atrybut_kod
        ,@atrybut_typ
        ,@atrybut_format;
END

CLOSE atrybut_cursor;

DEALLOCATE atrybut_cursor;

--Wyliczanie Atrybutów Dokumentów
DECLARE @atrybutyDok VARCHAR(max);

SET @sqlA = 'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT DAt_DeAid FROM CDN.DokAtrybuty WHERE DAt_TrNId IS NOT NULL)
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

SELECT DISTINCT DAt_TrNId
INTO #tmpDokAtr
FROM CDN.DokAtrybuty

SET @atrybutyDok = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2
    BEGIN
        SET @atrybut_kod = @atrybut_kod + ' (K)'
    END

    IF @atrybut_typ = 1
    BEGIN
        SET @atrybut_kod = @atrybut_kod + ' (T)'
    END

    SET @sqlA = N'ALTER TABLE #tmpDokAtr ADD [' + CAST(@atrybut_kod AS NVARCHAR(50)) + N'] nvarchar(max)'

    EXEC (@sqlA)

    SET @sqlA = N'UPDATE #tmpDokAtr
        SET [' + CAST(@atrybut_kod AS NVARCHAR(50)) + '] = CASE WHEN ' + convert(VARCHAR, @atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.DAt_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
          ELSE CASE WHEN ' + convert(VARCHAR, @atrybut_format) + ' = 2  THEN REPLACE(ATR.DAt_WartoscTxt,'','',''.'') ELSE ATR.DAt_WartoscTxt END 
        END
        FROM CDN.DokAtrybuty ATR 
        JOIN #tmpDokAtr TM ON ATR.DAt_TrNId = TM.DAt_TrNId 
        WHERE ATR.DAt_DeAId = ' + CAST(@atrybut_id AS NVARCHAR)

    EXEC (@sqlA)

    SET @atrybutyDok = @atrybutyDok + N', ISNULL(DokAtr.[' + CAST(@atrybut_kod AS NVARCHAR(50)) + '], ''(NIEPRZYPISANE)'') AS [Dokument Atrybut ' + CAST(@atrybut_kod AS NVARCHAR(50)) + ']'

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

--Wyliczanie Atrybutów Pozycji
DECLARE @atrybutyPoz VARCHAR(max)
    ,@atrybutyPoz2 VARCHAR(max);

SET @sqlA = 'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT TrA_DeAId FROM CDN.TraElemAtr WHERE TrA_TrEId IS NOT NULL)
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

SELECT DISTINCT TrA_TrEId
INTO #tmpPozAtr
FROM CDN.TraElemAtr

SET @atrybutyPoz = ''
SET @atrybutyPoz2 = ''

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

    SET @sqlA = N'ALTER TABLE #tmpPozAtr ADD [' + CAST(@atrybut_kod AS NVARCHAR(50)) + N'] nvarchar(max)'

    EXEC (@sqlA)

    SET @sqlA = N'UPDATE #tmpPozAtr
        SET [' + CAST(@atrybut_kod AS NVARCHAR(50)) + '] = CASE WHEN ' + convert(VARCHAR, @atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TrA_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(VARCHAR, @atrybut_format) + ' = 2  THEN REPLACE(ATR.TrA_Wartosc,'','',''.'') ELSE ATR.TrA_Wartosc END 
        END  
        FROM CDN.TraElemAtr ATR 
        JOIN #tmpPozAtr TM ON ATR.TrA_TrEId = TM.TrA_TrEId
        WHERE ATR.TrA_DeAId = ' + CAST(@atrybut_id AS NVARCHAR)

    EXEC (@sqlA)

    SET @atrybutyPoz = @atrybutyPoz + N', ISNULL(PozAtr.[' + CAST(@atrybut_kod AS NVARCHAR(50)) + '], ''(NIEPRZYPISANE)'') [Pozycja Atrybut ' + CAST(@atrybut_kod AS NVARCHAR(50)) + ']'
    SET @atrybutyPoz2 = @atrybutyPoz2 + N', ''(NIEPRZYPISANE)'' [Pozycja Atrybut ' + CAST(@atrybut_kod AS NVARCHAR(50)) + ']'

    FETCH NEXT
    FROM atrybut_cursor
    INTO @atrybut_id
        ,@atrybut_kod
        ,@atrybut_typ
        ,@atrybut_format;
END

CLOSE atrybut_cursor;

DEALLOCATE atrybut_cursor;

--Połączenie do tabeli operatorów
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @bazaFirmowa varchar(max);
DECLARE @Operatorzy varchar(max);
DECLARE @Bazy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 

--Tworzenie tabeli z serią dokumentów
SELECT DDf_DDfID
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

SELECT *  INTO #tmpKosztyGraniczne FROM (
SELECT SUM(TEKG.TrE_WartoscNetto) KosztyGraniczne
    ,TEFS.TrE_TrEID ElemId
    ,TNFS.TrN_TrNID TransId
FROM cdn.tranag TNKG
JOIN cdn.traelem TEKG ON TEKG.tre_trnid = TNKG.TrN_TrNID
JOIN cdn.Tranag TNFZ ON TNFZ.Trn_trnid = TNKG.TrN_ZwrId
JOIN cdn.TranagRelacje ON TNFZ.Trn_trnid = TrR_TrNId
    AND TrR_FaTyp IN (
        302
        ,305
        )
JOIN cdn.Tranag TNFS ON TNFS.TrN_TrNID = TrR_FaId
JOIN cdn.TraElem TEFS ON TNFS.trn_trnid = TEFS.TrE_TrNId
    AND TEKG.TrE_Lp = TEFS.TrE_LpPow
WHERE TNKG.trn_rodzaj IN (
        301008
        ,301009
        ,301018
        )
GROUP BY TEFS.TrE_TrEID
    ,TNFS.TrN_TrNID

	UNION ALL
	
	 SELECT  SUM(TEKG.TrE_WartoscNetto) KosztyGraniczne
    ,TEFS.TrE_TrEID ElemId
    ,TEFS.TrE_TrNId TransId
    FROM CDN.TraElem TEFS
    JOIN CDN.tranagrelacje tr on tr.TrR_TrNID = TEFS.TrE_TrNID
    JOIN CDN.traelem TEWZ on tr.TrR_FaId = TEWZ.TrE_TrNID AND TEFS.TrE_Lppow = TEWZ.TrE_LpPow
    JOIN CDN.TraSElemDost TraSElemDost on TEWZ.TrE_TrEID = TsD_TrEID
	JOIN  CDN.TraSElem ON TsD_TrSIdDost = trs_trsid
	JOIN CDN.TraElem TEPZ on TrS_TrEId = TEPZ.TrE_TrEID
	JOIN CDN.TraNag  TNPZ on TEPZ.TrE_TrNId = TrN_TrNID
	JOIN CDN.TraNagRelacje TRFZ ON TRFZ.TrR_TrNId = TNPZ.TRN_TRNID 
	JOIN CDN.TraNag  TNFZ ON TNFZ.TrN_TrNID = TRFZ.TrR_FaId
	JOIN CDN.TraNag  TNKG ON TNFZ.TrN_TrNID = TNKG.TrN_ZwrId AND TNKG.TrN_Rodzaj = 301009 -- Korekty Graniczne
	join CDN.TraElem TEKG ON TEKG.TrE_TrNId = TNKG.TrN_TrNID AND TEKG.TrE_Lp = TEPZ.TrE_LpPow
	GROUP BY TEFS.TrE_TrNId,TEFS.TrE_TrEID

	)X


--Tworzenie tabelki pomocniczej do liczenia marży
 SELECT TRE.TrE_TrEId TRE, TRERel.TrE_TreId TRERel
                   INTO #tmpMarza   FROM cdn.TraElem TRE
                       JOIN cdn.TraNag TRN ON TRE.TrE_TrNId = TrN_TrNId
                       JOIN cdn.TraNagRelacje  ON TrN_TrNId = TrR_FaId AND TrR_Flaga <> 1
                       JOIN cdn.TraElem TRERel ON TRERel.Tre_trnid = TrR_TrnId AND TREREl.Tre_lppow= tre.tre_lppow AND TREREl.TrE_TwrID = tre.TrE_TwrID
                     WHERE TrR_FaId = TRE.TrE_TrNId  AND TRERel.TrE_TypDokumentu  NOT IN (
					318
						,309
						,308
						,301
						,304
						,317
						)
					AND NOT (
						TrR_FaTyp = 307
						AND TrR_TrNTyp = 306
						)
					AND NOT (
						TrR_FaTyp = 306
						AND TrR_TrNTyp = 307
						)
					AND TrR_FaTyp != 320

--Właściwe zapytanie
SET @select = 
    'Declare @Wal VarChar(3); Set @Wal = cdn.Waluta('''')

SELECT  BAZ.Baz_Nazwa [Baza Firmowa],  DB_NAME()+convert(Varchar(10),trn.TrN_TrNID) [Liczba Dokumentów],

    trn.TrN_NumerPelny [Dokument Numer],
    ISNULL(NULLIF(trn.TrN_Opis,''''), ''(BRAK)'') [Dokument Opis],
    dd.DDf_Symbol [Dokument Symbol],

    CASE when isnull(ser.seria,0) = 5 then 
        substring(trn.TrN_NumerPelny,0,CHARINDEX(''/'',trn.TrN_NumerPelny,0))
    ELSE 
        ISNULL(PARSENAME(REPLACE(substring(trn.TrN_NumerPelny,CHARINDEX(''/'',trn.TrN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
    END [Dokument Seria],

    CONVERT(VARCHAR(2),DATEPART(HOUR,trn.TrN_TS_Zal))+'':''+''00'' [Dokument Godzina Wystawienia],

    ISNULL(NULLIF(trn.TrN_Waluta, ''''),@Wal) [Waluta], FPl_Nazwa [Forma Płatności],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Nagłówka], ISNULL(kat2.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Pozycji],
    ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Nagłówka], ISNULL(kat2.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Pozycji],
    
    pod1.Pod_Nazwa1 [Kontrahent Pierwotny Nazwa], 
    pod1.Pod_Kod [Kontrahent Pierwotny Kod], 
        ISNULL(NULLIF(pod1.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Województwo], ISNULL(NULLIF(pod1.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Miasto],
    ISNULL(NULLIF(pod1.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Kraj], ISNULL(NULLIF(pod1.Pod_NIP, ''''),''(BRAK)'') [Kontrahent Pierwotny NIP],
    ISNULL(NULLIF(pod1.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Pierwotny Grupa], ISNULL(kat3.Kat_KodSzczegol, ''(PUSTA)'') [Kontrahent Pierwotny Kategoria],
    CASE knt1.Knt_OpiekunTyp
        WHEN 3 THEN ISNULL(pod2.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN 8 THEN ISNULL(opk.Ope_Kod, ''(NIEPRZYPISANE)'')
        ELSE ''(NIEPRZYPISANE)'' 
    END [Kontrahent Pierwotny Opiekun],
    
    reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE knt1.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Pierwotny Rodzaj],

    
    DB_NAME()+''_''+convert(Varchar(10),pod5.pod_PodmiotTyp)+''_''+convert(Varchar(10),pod5.Pod_PodId)  [Liczba Kontrahentów], 
    pod5.Pod_Nazwa1 [Kontrahent Nazwa], 
    pod5.Pod_Kod [Kontrahent Kod], 
    ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Kontrahent Województwo], ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Kontrahent Miasto],
    ISNULL(NULLIF(pod5.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Kontrahent Kraj], ISNULL(NULLIF(pod5.Pod_NIP, ''''),''(BRAK)'') [Kontrahent NIP],
    ISNULL(NULLIF(pod5.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Grupa], ISNULL(kat5.Kat_KodSzczegol, ''(PUSTA)'') [Kontrahent Kategoria],
    CASE knt3.Knt_OpiekunTyp
        WHEN 3 THEN ISNULL(pod6.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN 8 THEN ISNULL(opk3.Ope_Kod, ''(NIEPRZYPISANE)'')
        ELSE ''(NIEPRZYPISANE)'' 
    END [Kontrahent Opiekun],

    CONVERT(VARCHAR,ISNULL(Rab_Rabat,0))+''%'' [Kontrahent Rabat],
    
    reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE knt3.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Rodzaj],
    
    DB_NAME()+''_''+convert(Varchar(10),pod3.pod_PodmiotTyp)+''_''+convert(Varchar(10),pod3.Pod_PodId)  [Liczba Odbiorców], 
    pod3.Pod_Nazwa1 [Odbiorca Nazwa], 
    pod3.Pod_Kod [Odbiorca Kod], 
    ISNULL(NULLIF(pod3.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Odbiorca Województwo], ISNULL(NULLIF(pod3.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Odbiorca Miasto],
    ISNULL(NULLIF(pod3.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Odbiorca Kraj],
    ISNULL(NULLIF(pod3.Pod_Grupa, ''''),''Pozostali'') [Odbiorca Grupa], 
    CASE knt2.Knt_OpiekunTyp
        WHEN 3 THEN ISNULL(pod4.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN 8 THEN ISNULL(opk2.Ope_Kod, ''(NIEPRZYPISANE)'')
        ELSE ''(NIEPRZYPISANE)'' 
    END [Odbiorca Opiekun],
    zal.Ope_Kod [Operator Wprowadzający], mod.Ope_Kod [Operator Modyfikujący],

    DB_NAME()+''_''+convert(Varchar(10),Twr_twrId)  [Liczba Produktów], 
    ISNULL(kat4.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria],

    Twr_Nazwa [Produkt Nazwa],
    CASE ISNULL(esk.Udostepnij,0) WHEN 0 THEN ''Nie'' ELSE ''Tak'' END as [Produkt e-Sklep],
    TR.Tre_TwrNazwa [Produkt Nazwa z Faktury],
    CASE TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca], 
    CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny], 
    KCN_Kod [Produkt Kod CN],
    Twr_Kod [Produkt Kod], 
    Twr_NumerKat [Produkt Numer Katalogowy], CAST(Twr_Opis as VARCHAR(1024)) [Produkt Opis], poz.sciezka [Produkt Pełna Nazwa Grupy], 
    Tre_Lp [Produkt Lp.],
    CASE WHEN TrE_Kaucja = 1 THEN ''TAK'' ELSE ''NIE'' END [Produkt Kaucja], Twr_Jm [Jednostka Miary], 
    
    Mag_Symbol [Magazyn Nazwa],
    ISNULL(Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
    CASE 
        WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa prosta''
        WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa złożona''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar prosty''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar złożony''
    END [Produkt Typ],
    CASE WHEN DATEDIFF(day, trn.TrN_DataOpe, GETDATE()) = 0 THEN ''TAK'' ELSE ''NIE'' END [Czas Aktualny Dziś],
    CASE WHEN DATEDIFF(day, trn.TrN_DataOpe, GETDATE() - 1) = 0 THEN ''TAK'' ELSE ''NIE'' END [Czas Aktualny Wczoraj],
    CASE WHEN ((datepart(DY, datediff(d, 0, trn.TrN_DataOpe) / 7 * 7 + 3)+6) / 7 = (datepart(DY, datediff(d, 0, GETDATE()) / 7 * 7 + 3)+6) / 7) AND (YEAR(trn.TrN_DataOpe) = YEAR(GETDATE())) 
        THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Aktualny Tydzień],
    CASE WHEN (MONTH(trn.TrN_DataOpe) = MONTH(GETDATE())) AND (YEAR(trn.TrN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' ELSE ''NIE'' END [Czas Aktualny Miesiąc],
    CASE 
        WHEN (MONTH(trn.TrN_DataOpe) = MONTH(GETDATE())-1) AND (YEAR(trn.TrN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
        WHEN ((MONTH(trn.TrN_DataOpe) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(trn.TrN_DataOpe) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Aktualny Miesiąc Poprzedni],
    GETDATE() [Czas Aktualny Data],
    
    TR.TrE_WartoscNetto [Sprzedaż Wartość], TR.TrE_WartoscBrutto [Sprzedaż Wartość Brutto], TR.TrE_WartoscNettoWal [Sprzedaż Wartość Waluta], TR.TrE_Ilosc [Sprzedaż Ilość], 
    (CASE WHEN trn.TrN_Rodzaj IN (302101,302102,302103,305101) THEN -1 ELSE 1 END) * (ISNULL(KosztWyliczony.Koszt ,0) + TR.TrE_KosztUslugi) [Koszt Zakupu], 
    TR.TrE_WartoscNetto - (CASE WHEN trn.TrN_Rodzaj IN (302101,302102,302103,305101) THEN -1 ELSE 1 END *(ISNULL(KosztWyliczony.Koszt ,0) + TR.TrE_KosztUslugi)) [Sprzedaż Marża],
    TrE_Ilosc * (TrE_Cena0WD - ([TrE_CenaWWD]/ISNULL(NULLIF([TrE_JMPrzelicznikL],0),1)*[TrE_JMPrzelicznikM])) * TrE_KursL / ISNULL(NULLIF(TrE_KursM,0),1) [Sprzedaż Rabat] ,
    ISNULL(NULLIF(Twr_JMZ,''''), ''(BRAK)'') [Jednostka Miary Pomocnicza],
    ISNULL(Twr_EAN,''(BRAK)'') [Produkt EAN],
    ISNULL(Twr_KodDostawcy,''(BRAK)'') [Produkt Kod Dostawcy]
    ,TrE_Cena0WD AS [Cena początkowa]
    ,TrE_CenaWWD AS [Cena transakcyjna]
	
    ,CAST(TR.TrE_Ilosc/ ISNULL(NULLIF((Twr_JMPrzelicznikL/ISNULL(NULLIF(Twr_JMPrzelicznikM,0),1)),0),1) AS DECIMAL(26,10)) [Sprzedaż Ilość Jednostka Pomocnicza]
    ,TR.TrE_Lp  [Produkt Pozycja Dokumentu]
    ,KosztyGraniczne AS [Koszt Zakupu Koszty Graniczne]
    ,ISNULL(KosztWyliczony.TRE_Waluta, TR.TRE_Waluta) [Waluta Koszt Zakupu]
    ,ISNULL((CASE WHEN trn.TrN_Rodzaj IN (302101,302102,302103,305101) THEN -1 ELSE 1 END) * (ISNULL(KosztWyliczony.Koszt ,0) + TR.TrE_KosztUslugi) / ISNULL(NULLIF((KursZakL/ISNULL(NULLIF(KursZakM,0),1)),0),1),TR.TrE_KosztUslugi)[Koszt Zakupu Waluta]
    /*
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), trn.TrN_DataOpe, 111), ''/'', ''-'') [Data Operacji]
    ,REPLACE(CONVERT(VARCHAR(10), trn.TrN_DataWys, 111), ''/'', ''-'') [Data Wystawienia]
    ,REPLACE(CONVERT(VARCHAR(10), trn.TrN_Termin, 111), ''/'', ''-'') [Termin Płatności]
    */
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), trn.TrN_DataOpe, 111), ''/'', ''-'') [Data Operacji Dzień]
    ,(datepart(DY, datediff(d, 0, trn.TrN_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, trn.TrN_DataOpe)*/ [Data Operacji Tydzień Roku]
    ,MONTH(trn.TrN_DataOpe) [Data Operacji Miesiąc], DATEPART(quarter, trn.TrN_DataOpe) [Data Operacji Kwartał], YEAR(trn.TrN_DataOpe) [Data Operacji Rok]
    ,REPLACE(CONVERT(VARCHAR(10), trn.TrN_DataWys, 111), ''/'', ''-'') [Data Wystawienia Dzień]
    ,(datepart(DY, datediff(d, 0, trn.TrN_DataWys) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, trn.TrN_DataWys)*/ [Data Wystawienia Tydzień Roku] 
    ,MONTH(trn.TrN_DataWys) [Data Wystawienia Miesiąc], DATEPART(quarter, trn.TrN_DataWys) [Data Wystawienia Kwartał], YEAR(trn.TrN_DataWys) [Data Wystawienia Rok]
    ,REPLACE(CONVERT(VARCHAR(10), trn.TrN_Termin, 111), ''/'', ''-'') [Termin Płatności Dzień] 
    ,(datepart(DY, datediff(d, 0, trn.TrN_Termin) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, trn.TrN_Termin)*/ [Termin Płatności Tydzień Roku]
    ,MONTH(trn.TrN_Termin) [Termin Płatności Miesiąc], DATEPART(quarter, trn.TrN_Termin) [Termin Płatności Kwartał], YEAR(trn.TrN_Termin) [Termin Płatności Rok]
    ----------KONTEKSTY
    ,CASE WHEN trn.TrN_TypDokumentu = 305 THEN 29048 ELSE 25004 END [Dokument Numer __PROCID__Sprzedaz__], trn.TrN_TrNId [Dokument Numer __ORGID__],''' 
    + @bazaFirmowa + ''' [Dokument Numer __DATABASE__]
    ,20201 [Kontrahent Pierwotny Nazwa __PROCID__], pod1.Pod_PodId [Kontrahent Pierwotny Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Pierwotny Nazwa __DATABASE__]
    ,20201 [Kontrahent Pierwotny Kod __PROCID__], pod1.Pod_PodId [Kontrahent Pierwotny Kod __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Pierwotny Kod __DATABASE__]
    ,20201 [Kontrahent Nazwa __PROCID__], pod5.Pod_PodId [Kontrahent Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Nazwa __DATABASE__]
    ,20201 [Kontrahent Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Kontrahent Kod __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Kod __DATABASE__]
    ,20201 [Odbiorca Nazwa __PROCID__], pod3.Pod_PodId [Odbiorca Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Odbiorca Nazwa __DATABASE__]
    ,20201 [Odbiorca Kod __PROCID__], pod3.Pod_PodId [Odbiorca Kod __ORGID__],''' + @bazaFirmowa + ''' [Odbiorca Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],''' + 
    @bazaFirmowa + ''' [Produkt Nazwa __DATABASE__]
    ,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],''' + @bazaFirmowa + ''' [Produkt Kod __DATABASE__]
    ,29056 [Magazyn Nazwa __PROCID__Magazyny__], Mag_MagId [Magazyn Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Magazyn Nazwa __DATABASE__]

' + @kolumny + @atrybuty + @atrybutyDok + @atrybutyTwr + @atrybutyPoz
SET @select2 = 
    ' FROM cdn.TraNag trn
     JOIN cdn.TraElem TR ON TrE_TrNID=trn.TrN_TrNID 
     LEFT JOIN #tmpSeria ser ON trn.TrN_DDfId = DDf_DDfID
     LEFT JOIN CDN.DokDefinicje dd ON trn.TrN_DDfId = dd.DDf_DDfID
     left join (select * from cdn.tranag where TrN_TypDokumentu = 302 and trn_faid is not null) spFA on trn.trn_trnid = spFA.trn_faid and trn.trn_faid = spFA.trn_trnid and trn.TrN_TypDokumentu = 305
     LEFT OUTER JOIN CDN.Kontrahenci knt1 ON ISNULL(spFA.Trn_PodID,TrE_PodID)=knt1.Knt_KntId AND ISNULL(spFA.Trn_PodmiotTyp,TrE_PodmiotTyp) = 1
     LEFT OUTER JOIN CDN.PodmiotyView pod1 ON ISNULL(spFA.Trn_PodID,TrE_PodID)= pod1.Pod_PodId AND ISNULL(spFA.Trn_PodmiotTyp,TrE_PodmiotTyp) = pod1.Pod_PodmiotTyp
     LEFT OUTER JOIN CDN.PodmiotyView pod3 ON trn.TrN_OdbID= pod3.Pod_PodId AND trn.TrN_OdbiorcaTyp = pod3.Pod_PodmiotTyp
     LEFT OUTER JOIN cdn.PodmiotyView pod2 ON knt1.Knt_OpiekunId = pod2.Pod_PodId AND knt1.Knt_OpiekunTyp = pod2.Pod_PodmiotTyp
     LEFT OUTER JOIN CDN.Kontrahenci knt2 ON trn.TrN_OdbId = knt2.Knt_KntId AND trn.TrN_OdbiorcaTyp = 1
     LEFT OUTER JOIN cdn.PodmiotyView pod4 ON knt2.Knt_OpiekunId = pod4.Pod_PodId AND knt2.Knt_OpiekunTyp = pod4.Pod_PodmiotTyp
     JOIN CDN.Towary ON TrE_TwrId=Twr_TwrId
     LEFT JOIN CDN.KodyCN on Twr_KCNId = KCN_KCNId
     LEFT JOIN CDN.Producenci ON Prd_PrdId = Twr_PrdId
     LEFT JOIN CDN.Marki ON Mrk_MrkId = Twr_MrkId
     JOIN CDN.Magazyny ON TrE_MagId=Mag_MagId 
     LEFT OUTER JOIN CDN.Kategorie kat1 ON trn.TrN_KatID=kat1.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat2 ON TrE_KatID=kat2.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat3 ON knt1.Knt_KatID=kat3.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat4 ON Twr_KatID=kat4.Kat_KatID
     LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod1.Pod_GlID = pod5.Pod_PodId and pod1.Pod_GlKod = pod5.Pod_Kod and pod5.Pod_PodmiotTyp = pod1.Pod_PodmiotTyp
     LEFT OUTER JOIN CDN.Kontrahenci knt3 ON pod5.Pod_PodID=knt3.Knt_KntId AND pod5.Pod_PodmiotTyp = 1

     LEFT JOIN CDN.Rabaty on rab_podmiotid = knt3.knt_kntid and rab_typ = 2 AND trn.TrN_DataOpe BETWEEN Rab_DataOd AND Rab_DataDo

     LEFT OUTER JOIN CDN.Kategorie kat5 ON knt3.Knt_KatID=kat5.Kat_KatID
     LEFT OUTER JOIN cdn.PodmiotyView pod6 ON knt3.Knt_OpiekunId = pod6.Pod_PodId AND knt3.Knt_OpiekunTyp = pod6.Pod_PodmiotTyp
     LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
     LEFT JOIN #tmpKonAtr KonAtr ON pod1.Pod_PodId = KonAtr.KnA_PodmiotId AND pod1.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
     LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
     LEFT JOIN #tmpKonAtr OdbAtr ON pod3.Pod_PodId = OdbAtr.KnA_PodmiotId AND pod3.Pod_PodmiotTyp = OdbAtr.KnA_PodmiotTyp
     LEFT JOIN #tmpDokAtr DokAtr ON trn.TrN_TrNID  = DokAtr.DAt_TrNId
     LEFT JOIN #tmpTwrAtr TwrAtr ON TrE_TwrId  = TwrAtr.TwA_TwrId 
     LEFT JOIN #tmpPozatr PozAtr on PozAtr.TrA_TrEId = TrE_TrEId
     LEFT JOIN ' 
    + @Operatorzy + ' opk ON knt1.Knt_OpiekunId = opk.Ope_OpeId AND knt1.Knt_OpiekunTyp = 8 
     LEFT JOIN ' + @Operatorzy + ' opk2 ON knt2.Knt_OpiekunId = opk2.Ope_OpeId AND knt2.Knt_OpiekunTyp = 8 
     LEFT JOIN ' + @Operatorzy + ' zal ON trn.TrN_OpeZalID = zal.Ope_OpeId
     LEFT JOIN ' + @Operatorzy + ' mod ON trn.TrN_OpeModID = mod.Ope_OpeId
     LEFT JOIN ' + @Operatorzy + 
    ' opk3 ON knt3.Knt_OpiekunId = opk3.Ope_OpeId AND knt3.Knt_OpiekunTyp = 8 
     LEFT JOIN CDN.FormyPlatnosci ON trn.TrN_FPlId = FPl_FPlId
     LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
 LEFT OUTER JOIN ( 
            SELECT ISNULL(SUM(CASE  WHEN TrS_Rodzaj IN (
                            312000
                            ,312008
                            )
                        AND TrS_Ilosc < 0
                        AND TrS_ZwrId IS NULL
                        THEN 0
                    WHEN (
                            TrS_Rodzaj = 308000
                            OR TrS_Rodzaj = 308011
                            )
                        AND TrS_Ilosc < 0
                        THEN 0
                    ELSE TrS_Wartosc
                    END), 0) AS Koszt,
                           TRE.TrE_TrEID
						   	,TREWAL.TRE_Waluta
							,TREWAL.TrE_KursL KursZakL
							,TREWAL.Tre_KursM KursZakM
            FROM CDN.TraElem TRE
            JOIN ( SELECT TrE_TrEId as IdElem, TrE_TrEId as IdZwiaz
                   FROM CDN.TraElem
                   UNION ALL
                   SELECT TRE, TRERel
                     FROM #tmpMarza TRE
                 ) AS Elem ON TRE.Tre_TrEId = Elem.IdElem
            JOIN CDN.TraSElem TRS ON TRS.TrS_TrEId = Elem.IdZwiaz
			JOIN CDN.TraElem	AS TREWAL	ON TREWAL.TrE_TrEId = Elem.IdZwiaz
            GROUP BY TRE.TrE_TrEID,TREWAL.TRE_Waluta,TREWAL.TrE_KursL,TREWAL.Tre_KursM
    )KosztWyliczony  ON KosztWyliczony.TrE_TrEID = TR.TrE_TrEID


    LEFT JOIN (select distinct Twes_TwrId, MAX(Twes_Udostepnij) Udostepnij from cdn.TwrESklep group by Twes_TwrId) esk on esk.Twes_TwrId = Twr_TwrId
    LEFT JOIN #tmpKosztyGraniczne ON ElemId = TR.Tre_Treid
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
WHERE
trn.TrN_TypDokumentu IN (-1,302,305)
AND trn.TrN_Bufor<>-1
AND TrE_Aktywny<>0
AND TrE_UslugaZlozonaId = 0

UNION ALL

SELECT  BAZ.Baz_Nazwa [Baza Firmowa], DB_NAME()+convert(Varchar(10),TrN_TrNID) [Liczba dokumentów],

    TrN_NumerPelny [Dokument Numer],
    ISNULL(NULLIF(TrN_Opis,''''), ''(BRAK)'') [Dokument Opis],
    dd.DDf_Symbol [Dokument Symbol],
    CASE when isnull(ser.seria,0) = 5 then 
        substring(TrN_NumerPelny,0,CHARINDEX(''/'',TrN_NumerPelny,0))
    ELSE 
        ISNULL(PARSENAME(REPLACE(substring(TrN_NumerPelny,CHARINDEX(''/'',TrN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
    END [Dokument Seria],

    CONVERT(VARCHAR(2),DATEPART(HOUR,TrN_TS_Zal))+'':''+''00'' [Dokument Godzina Wystawienia],

    ISNULL(NULLIF(TrN_Waluta, ''''),@Wal) [Waluta], FPl_Nazwa [Forma Płatności],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Nagłówka], ''(PUSTA)'' [Kategoria Szczegółowa z Pozycji],
    ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Nagłówka], ''(PUSTA)'' [Kategoria Ogólna z Pozycji],
    
    pod1.Pod_Nazwa1 [Kontrahent Pierwotny Nazwa], 
    pod1.Pod_Kod [Kontrahent Pierwotny Kod], 
    ISNULL(NULLIF(pod1.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Województwo], ISNULL(NULLIF(pod1.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Miasto],
    ISNULL(NULLIF(pod1.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Kraj], ISNULL(NULLIF(pod1.Pod_NIP, ''''),''(BRAK)'') [Kontrahent Pierwotny NIP],
    ISNULL(NULLIF(pod1.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Pierwotny Grupa], ISNULL(kat3.Kat_KodSzczegol, ''(PUSTA)'') [Kontrahent Pierwotny Kategoria],
    CASE knt1.Knt_OpiekunTyp
        WHEN 3 THEN ISNULL(pod2.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN 8 THEN ISNULL(opk.Ope_Kod, ''(NIEPRZYPISANE)'')
        ELSE ''(NIEPRZYPISANE)'' 
    END [Kontrahent Pierwotny Opiekun],

    reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE knt1.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Pierwotny Rodzaj],

    DB_NAME()+''_''+convert(Varchar(10),pod5.pod_PodmiotTyp)+''_''+convert(Varchar(10),pod5.Pod_PodId) [Liczba Kontrahentów], 
    pod5.Pod_Nazwa1 [Kontrahent Nazwa], 
    pod5.Pod_Kod [Kontrahent Kod], 
    ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Kontrahent Województwo], ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Kontrahent Miasto],
    ISNULL(NULLIF(pod5.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Kontrahent Kraj], ISNULL(NULLIF(pod5.Pod_NIP, ''''),''(BRAK)'') [Kontrahent NIP],
    ISNULL(NULLIF(pod5.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Grupa], ISNULL(kat5.Kat_KodSzczegol, ''(PUSTA)'') [Kontrahent Kategoria],
    CASE knt3.Knt_OpiekunTyp
        WHEN 3 THEN ISNULL(pod6.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN 8 THEN ISNULL(opk3.Ope_Kod, ''(NIEPRZYPISANE)'')
        ELSE ''(NIEPRZYPISANE)'' 
    END [Kontrahent Opiekun],

    CONVERT(VARCHAR,ISNULL(Rab_Rabat,0))+''%'' [Kontrahent Rabat],

    reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE knt3.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Rodzaj],
    
    DB_NAME()+''_''+convert(Varchar(10),pod3.pod_PodmiotTyp)+''_''+convert(Varchar(10),pod3.Pod_PodId)  [Liczba Odbiorców], 
    pod3.Pod_Nazwa1 [Odbiorca Nazwa], 
    pod3.Pod_Kod [Odbiorca Kod], 
    ISNULL(NULLIF(pod3.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Odbiorca Województwo], ISNULL(NULLIF(pod3.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Odbiorca Miasto],
    ISNULL(NULLIF(pod3.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Odbiorca Kraj],
    ISNULL(NULLIF(pod3.Pod_Grupa, ''''),''Pozostali'') [Odbiorca Grupa], 
    CASE knt2.Knt_OpiekunTyp
        WHEN 3 THEN ISNULL(pod4.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN 8 THEN ISNULL(opk2.Ope_Kod, ''(NIEPRZYPISANE)'')
        ELSE ''(NIEPRZYPISANE)'' 
    END [Odbiorca Opiekun],

    zal.Ope_Kod [Operator Wprowadzający], mod.Ope_Kod [Operator Modyfikujący],
    null  [Liczba Produktów], 
    ''(PUSTA)'' [Produkt Kategoria],
    
    ''Korekta zbiorcza'' [Produkt Nazwa],
    ''Korekta zbiorcza'' [Produkt e-Sklep],
    ''Korekta zbiorcza'' [Produkt Nazwa z Faktury],
    ''(BRAK)'' [Produkt PKWiU], 
    ''(BRAK)'' [Produkt Dostawca],
    ''(BRAK)'' [Produkt Aktywny],
    ''(BRAK)'' [Produkt Kod CN],
    ''Korekta zbiorcza'' [Produkt Kod],     
    ''Korekta zbiorcza'' [Produkt Numer Katalogowy], ''Korekta zbiorcza'' [Produkt Opis], ''Korekta zbiorcza'' [Produkt Pełna Nazwa Grupy],
    NULL [Produkt Lp.],
    ''NIE'' [Produkt Kaucja], ''(BRAK)'' [Jednostka Miary], 
    
    ''(BRAK)'' [Magazyn Nazwa], 
    ''(BRAK)'' [Produkt Producent], ''(BRAK)'' [Produkt Marka], ''Korekta zbiorcza'' [Produkt Typ],
    CASE WHEN DATEDIFF(day, TrN_DataOpe, GETDATE()) = 0 THEN ''TAK'' ELSE ''NIE'' END [Czas Aktualny Dziś],
    CASE WHEN DATEDIFF(day, TrN_DataOpe, GETDATE() - 1) = 0 THEN ''TAK'' ELSE ''NIE'' END [Czas Aktualny Wczoraj],
    CASE WHEN ((datepart(DY, datediff(d, 0, TrN_DataOpe) / 7 * 7 + 3)+6) / 7 = (datepart(DY, datediff(d, 0, GETDATE()) / 7 * 7 + 3)+6) / 7) AND (YEAR(TrN_DataOpe) = YEAR(GETDATE())) 
        THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Aktualny Tydzień],
    CASE WHEN (MONTH(TrN_DataOpe) = MONTH(GETDATE())) AND (YEAR(TrN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' ELSE ''NIE'' END [Czas Aktualny Miesiąc],
    CASE 
        WHEN (MONTH(TrN_DataOpe) = MONTH(GETDATE())-1) AND (YEAR(TrN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
        WHEN ((MONTH(TrN_DataOpe) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(TrN_DataOpe) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Aktualny Miesiąc Poprzedni],
    GETDATE() [Czas Aktualny Data],
    TrN_RazemNetto [Sprzedaż Wartość], TrN_RazemBrutto [Sprzedaż Wartość Brutto], TrN_RazemNettoWal [Sprzedaż Wartość Waluta], 
    0 [Sprzedaż Ilość], KosztWyliczony.Koszt [Koszt Zakupu], TrN_RazemNetto - KosztWyliczony.Koszt [Sprzedaż Marża],
    TrN_RabatWartosc [Sprzedaż Rabat],
    ''(BRAK)'' [Jednostka Miary Pomocnicza],
    ''(BRAK)'' [Produkt EAN],
    ''(BRAK)'' [Produkt Kod Dostawcy]
    ,NULL AS [Cena początkowa]
    ,NULL AS [Cena transakcyjna]
    ,0 [Sprzedaż Ilość Jednostka Pomocnicza]
    ,NULL [Produkt Pozycja Dokumentu]
    ,KosztyGraniczne AS [Koszt Zakupu Koszty Graniczne]
    ,KosztWyliczony.TRE_Waluta [Waluta Koszt Zakupu]
    ,(CASE WHEN TrN_Rodzaj IN (302101,302102,302103,305101) THEN -1 ELSE 1 END) * (ISNULL(KosztWyliczony.Koszt ,0)) / ISNULL(NULLIF((KursZakL/ISNULL(NULLIF(KursZakM,0),1)),0),1)[Koszt Zakupu Waluta]
    /*
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), TrN_DataOpe, 111), ''/'', ''-'') [Data Operacji] 
    ,REPLACE(CONVERT(VARCHAR(10), TrN_DataWys, 111), ''/'', ''-'') [Data Wystawienia]
    ,REPLACE(CONVERT(VARCHAR(10), TrN_Termin, 111), ''/'', ''-'') [Termin Płatności]
    */
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), TrN_DataOpe, 111), ''/'', ''-'') [Data Operacji Dzień] 
    ,(datepart(DY, datediff(d, 0, TrN_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataOpe)*/ [Data Operacji Tydzień Roku]
    ,MONTH(TrN_DataOpe) [Data Operacji Miesiąc], DATEPART(quarter, TrN_DataOpe) [Data Operacji Kwartał], YEAR(TrN_DataOpe) [Data Operacji Rok] 
    ,REPLACE(CONVERT(VARCHAR(10), TrN_DataWys, 111), ''/'', ''-'') [Data Wystawienia Dzień]
    ,(datepart(DY, datediff(d, 0, TrN_DataWys) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataWys)*/ [Data Wystawienia Tydzień Roku]
    ,MONTH(TrN_DataWys) [Data Wystawienia Miesiąc], DATEPART(quarter, TrN_DataWys) [Data Wystawienia Kwartał], YEAR(TrN_DataWys) [Data Wystawienia Rok]
    ,REPLACE(CONVERT(VARCHAR(10), TrN_Termin, 111), ''/'', ''-'') [Termin Płatności Dzień]
    ,(datepart(DY, datediff(d, 0, TrN_Termin) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_Termin)*/ [Termin Płatności Tydzień Roku]
    ,MONTH(TrN_Termin) [Termin Płatności Miesiąc], DATEPART(quarter, TrN_Termin) [Termin Płatności Kwartał], YEAR(TrN_Termin) [Termin Płatności Rok] 
    ----------KONTEKSTY
    ,30392 [Dokument Numer __PROCID__Sprzedaz__], TrN_TrNId [Dokument Numer __ORGID__],''' 
    + @bazaFirmowa + ''' [Dokument Numer __DATABASE__]
    ,20201 [Kontrahent Pierwotny Nazwa __PROCID__], pod1.Pod_PodId [Kontrahent Pierwotny Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Pierwotny Nazwa __DATABASE__]
    ,20201 [Kontrahent Pierwotny Kod __PROCID__Kontrahenci__], pod1.Pod_PodId [Kontrahent Pierwotny Kod __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Pierwotny Kod __DATABASE__]
    ,20201 [Kontrahent Nazwa __PROCID__], pod5.Pod_PodId [Kontrahent Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Nazwa __DATABASE__]
    ,20201 [Kontrahent Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Kontrahent Kod __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Kod __DATABASE__]
    ,20201 [Odbiorca Nazwa __PROCID__], pod3.Pod_PodId [Odbiorca Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Odbiorca Nazwa __DATABASE__]
    ,20201 [Odbiorca Kod __PROCID__], pod3.Pod_PodId [Odbiorca Kod __ORGID__],''' + @bazaFirmowa + 
    ''' [Odbiorca Kod __DATABASE__]
    ,30392 [Produkt Nazwa __PROCID__], TrN_TrNId [Produkt Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Produkt Nazwa __DATABASE__]
    ,30392 [Produkt Kod __PROCID__Towary__], TrN_TrNId [Produkt Kod __ORGID__],''' + @bazaFirmowa + ''' [Produkt Kod __DATABASE__]
    ,30392 [Magazyn Nazwa __PROCID__Magazyny__], TrN_TrNId [Magazyn Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Magazyn Nazwa __DATABASE__]
' + @kolumny + @atrybuty + @atrybutyDok + @atrybutyTwr2 + @atrybutyPoz2
SET @select3 = 
    ' FROM cdn.TraNag 
     LEFT JOIN #tmpSeria ser ON TrN_DDfId = DDf_DDfID
     LEFT JOIN CDN.DokDefinicje dd ON TrN_DDfId = dd.DDf_DDfID
     LEFT OUTER JOIN CDN.Kontrahenci knt1 ON TrN_PodID=knt1.Knt_KntId AND TrN_PodmiotTyp = 1
     LEFT OUTER JOIN CDN.PodmiotyView pod1 ON TrN_PodID= pod1.Pod_PodId AND TrN_PodmiotTyp = pod1.Pod_PodmiotTyp
     LEFT OUTER JOIN CDN.PodmiotyView pod3 ON TrN_OdbID= pod3.Pod_PodId AND TrN_OdbiorcaTyp = pod3.Pod_PodmiotTyp
     LEFT OUTER JOIN cdn.PodmiotyView pod2 ON knt1.Knt_OpiekunId = pod2.Pod_PodId AND knt1.Knt_OpiekunTyp = pod2.Pod_PodmiotTyp
         LEFT OUTER JOIN CDN.Kontrahenci knt2 ON TrN_OdbId = knt2.Knt_KntId AND TrN_OdbiorcaTyp = 1
     LEFT OUTER JOIN cdn.PodmiotyView pod4 ON knt2.Knt_OpiekunId = pod4.Pod_PodId AND knt2.Knt_OpiekunTyp = pod4.Pod_PodmiotTyp
     LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod1.Pod_GlID = pod5.Pod_PodId and pod1.Pod_GlKod = pod5.Pod_Kod and pod5.Pod_PodmiotTyp = pod1.Pod_PodmiotTyp
     LEFT OUTER JOIN CDN.Kategorie kat1 ON TrN_KatID=kat1.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat3 ON knt1.Knt_KatID=kat3.Kat_KatID
     LEFT OUTER JOIN CDN.Kontrahenci knt3 ON pod5.Pod_PodID=knt3.Knt_KntId AND pod5.Pod_PodmiotTyp = 1

     LEFT JOIN CDN.Rabaty on rab_podmiotid = knt3.knt_kntid and rab_typ = 2 AND TrN_DataOpe BETWEEN Rab_DataOd AND Rab_DataDo

     LEFT OUTER JOIN CDN.Kategorie kat5 ON knt3.Knt_KatID=kat5.Kat_KatID
     LEFT OUTER JOIN cdn.PodmiotyView pod6 ON knt3.Knt_OpiekunId = pod6.Pod_PodId AND knt3.Knt_OpiekunTyp = pod6.Pod_PodmiotTyp
     LEFT JOIN #tmpKonAtr KonAtr ON pod1.Pod_PodId = KonAtr.KnA_PodmiotId AND pod1.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
     LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
     LEFT JOIN #tmpKonAtr OdbAtr ON pod3.Pod_PodId = OdbAtr.KnA_PodmiotId AND pod3.Pod_PodmiotTyp = OdbAtr.KnA_PodmiotTyp
     LEFT JOIN #tmpDokAtr DokAtr ON TrN_TrNID  = DokAtr.DAt_TrNId
     LEFT JOIN #tmpTwrGr Poz ON 0 = 1
     LEFT JOIN ' 
    + @Operatorzy + ' opk ON knt1.Knt_OpiekunId = opk.Ope_OpeId AND knt1.Knt_OpiekunTyp = 8 
     LEFT JOIN ' + @Operatorzy + ' opk2 ON knt2.Knt_OpiekunId = opk2.Ope_OpeId AND knt2.Knt_OpiekunTyp = 8
     LEFT JOIN ' + @Operatorzy + ' zal ON TrN_OpeZalID = zal.Ope_OpeId
     LEFT JOIN ' + @Operatorzy + ' mod ON TrN_OpeModID = mod.Ope_OpeId
     LEFT JOIN ' + @Operatorzy + ' opk3 ON knt3.Knt_OpiekunId = opk3.Ope_OpeId AND knt3.Knt_OpiekunTyp = 8 
     LEFT JOIN CDN.FormyPlatnosci ON TrN_FPlId = FPl_FPlId
     lEFT JOIN (SELECT  sum(KosztyGraniczne) AS KosztyGraniczne, TransID FROM #tmpKosztyGraniczne GROUP BY TransId)KosztyGran ON Trn_Trnid = TransID 
     LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'')
 LEFT OUTER JOIN ( 
            SELECT ISNULL(SUM(CASE  WHEN TrS_Rodzaj IN (
                            312000
                            ,312008
                            )
                        AND TrS_Ilosc < 0
                        AND TrS_ZwrId IS NULL
                        THEN 0
                    WHEN (
                            TrS_Rodzaj = 308000
                            OR TrS_Rodzaj = 308011
                            )
                        AND TrS_Ilosc < 0
                        THEN 0
                    ELSE TrS_Wartosc
                    END), 0) AS Koszt
						   	,TRE.TrE_TrNId
							,TREWAL.TRE_Waluta
							,TREWAL.TrE_KursL KursZakL
							,TREWAL.Tre_KursM KursZakM
            FROM CDN.TraElem TRE
            JOIN ( SELECT TrE_TrEId as IdElem, TrE_TrEId as IdZwiaz
                   FROM CDN.TraElem
                   UNION ALL
                   SELECT TRE, TRERel
                     FROM #tmpMarza TRE
                 ) AS Elem ON TRE.Tre_TrEId = Elem.IdElem
            JOIN CDN.TraSElem TRS ON TRS.TrS_TrEId = Elem.IdZwiaz
			JOIN CDN.TraElem	AS TREWAL	ON TREWAL.TrE_TrEId = Elem.IdZwiaz
            GROUP BY TRE.TrE_Trnid,TREWAL.TRE_Waluta,TREWAL.TrE_KursL,TREWAL.Tre_KursM
    )KosztWyliczony  ON KosztWyliczony.TrE_TrNId = Trn_Trnid
WHERE
TRN_Rodzaj = 302010
AND TrN_Bufor<>-1

'

PRINT (@select + @select2 + @select3)

EXEC (@select + @select2 + @select3)

DROP TABLE #tmpTwrGr

DROP TABLE #tmpKonAtr

DROP TABLE #tmpDokAtr

DROP TABLE #tmpTwrAtr

DROP TABLE #tmpSeria

DROP TABLE #tmppozatr

DROP TABLE #tmpKosztyGraniczne

DROP TABLE #tmpMarza








