     SELECT count(*) as ilosc,PdE_TrEId INTO #TowCnt FROM cdn.ProdElem GROUP BY PdE_TrEId
    SELECT count(*) as ilosc,PdE_TrEIdRWS INTO #temprws FROM cdn.ProdElem GROUP BY PdE_TrEIdRWS

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--Wyliczanie poziomów grup produktów
WITH g(gid, gidTyp, kod, gidNumer, grONumer, poziom, sciezka)
AS
(
      SELECT TwG_TwGID, TwG_GIDTyp, TwG_Kod, TwG_GIDNumer, TwG_GrONumer, 0 as poziom, convert(nvarchar(1024), '') as sciezka
      FROM CDN.TwrGrupy
      WHERE TwG_TwGID = 0
      
      UNION ALL
      
      SELECT TwG_TwGID, TwG_GIDTyp, TwG_Kod, TwG_GIDNumer, TwG_GrONumer, p.poziom + 1 as poziom, convert(nvarchar(1024), p.sciezka + N'\' + c.TwG_Kod) as sciezka
      FROM g p
      JOIN CDN.TwrGrupy c
      ON c.TwG_GrONumer = p.gidNumer 
      WHERE c.TwG_TwGID <> 0 AND c.TwG_GIDTyp = -16
)     

SELECT * INTO #tmpTwrGr FROM g

DECLARE @poziom int
DECLARE @poziom_max int
DECLARE @sql nvarchar(max)
SELECT @poziom_max = MAX(poziom) FROM #tmpTwrGr
SET @poziom = @poziom_max
SET @sql = N''

WHILE @poziom >= 0  
BEGIN
    SET @sql = N'ALTER TABLE #tmpTwrGr ADD Poziom' + CAST(@poziom AS nvarchar) + N' nvarchar(50), ONr' + CAST(@poziom AS nvarchar) + N' nvarchar(50)'
    EXEC(@sql)
    
    IF @poziom = @poziom_max 
        BEGIN
            SET @sql = N'UPDATE #tmpTwrGr
                SET ONr' + CAST(@poziom AS nvarchar) +  '= grONumer '
            EXEC(@sql)
            
            SET @sql = N'UPDATE #tmpTwrGr
                SET Poziom' + CAST(@poziom AS nvarchar) + ' = kod'
            EXEC(@sql)
        END
    ELSE
        BEGIN 
            SET @sql = N'UPDATE c
                SET c.Poziom' + CAST(@poziom AS nvarchar) + N' = (
                    CASE WHEN c.poziom <=' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.kod AS nvarchar)
                    ELSE CAST(p.kod AS nvarchar) END)  
                FROM #tmpTwrGr c
                LEFT JOIN #tmpTwrGr p
                ON c.ONr' + CAST(@poziom + 1 AS nvarchar) + '= p.gidNumer '
            EXEC(@sql)
    
            SET @sql = N'UPDATE c
                SET c.ONr' + CAST(@poziom AS nvarchar) + N' = (
                    CASE WHEN c.poziom <=' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.grONumer AS nvarchar)
                    ELSE CAST(p.grONumer AS nvarchar) END)  
                FROM #tmpTwrGr c
                LEFT JOIN #tmpTwrGr p
                ON c.ONr' + CAST(@poziom + 1 AS nvarchar) + '= p.gidNumer '
                EXEC(@sql)
        END
    SET @poziom = @poziom - 1
END     

declare @select varchar(max)
declare @select2 varchar(max)
declare @kolumny varchar(max)
declare @i int

set @kolumny = ''
set @i=0
while (@i<=@poziom_max)
begin
    set @kolumny = @kolumny + ',"Produkt Grupa Poziom ' + LTRIM(@i) + '" = CASE WHEN Poz.Poziom' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' + LTRIM(@i) + ' END'
    set @i = @i + 1
end

--Wyliczanie Atrybutów Kontrahentów
DECLARE @atrybut_id int, @atrybut_kod nvarchar(50), @atrybut_typ int, @atrybut_format int, @atrybuty varchar(max), @sqlA nvarchar(max);

DECLARE @wersja float;
SET @wersja = (SELECT CONVERT(float, SYS_Wartosc) FROM CDN.SystemCDN WHERE SYS_ID = 3)

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT KnA_DeAid FROM CDN.KntAtrybuty)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT KnA_PodmiotId, KnA_PodmiotTyp INTO #tmpKonAtr FROM CDN.KntAtrybuty

SET @atrybuty = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 1 BEGIN SET @atrybut_kod = @atrybut_kod + ' (T)' END
    IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
    SET @sqlA = N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpKonAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.KnA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.KnA_WartoscTxt,'','',''.'') ELSE ATR.KnA_WartoscTxt END 
        END  
        FROM CDN.KntAtrybuty ATR 
        JOIN #tmpKonAtr TM ON ATR.KnA_PodmiotId = TM.KnA_PodmiotId AND ATR.KnA_PodmiotTyp = TM.KnA_PodmiotTyp
        WHERE ATR.KnA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Pierwotny Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'     
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr1.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'      
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Wyliczanie Atrybutów Dokumentów
DECLARE @atrybutyDok varchar(max);

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT DAt_DeAid FROM CDN.DokAtrybuty WHERE DAt_TrNId IS NOT NULL)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT DAt_TrNId INTO #tmpDokAtr FROM CDN.DokAtrybuty

SET @atrybutyDok = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
    IF @atrybut_typ = 1 BEGIN SET @atrybut_kod = @atrybut_kod + ' (T)' END
    SET @sqlA = N'ALTER TABLE #tmpDokAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpDokAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.DAt_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
          ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.DAt_WartoscTxt,'','',''.'') ELSE ATR.DAt_WartoscTxt END 
        END  
        FROM CDN.DokAtrybuty ATR 
        JOIN #tmpDokAtr TM ON ATR.DAt_TrNId = TM.DAt_TrNId 
        WHERE ATR.DAt_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyDok = @atrybutyDok + N', ISNULL(DokAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Dokument Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Wyliczanie Atrybutów Towarów
DECLARE @atrybutyTwr varchar(max);

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT TwA_DeAid FROM CDN.TwrAtrybuty WHERE TwA_TwrId IS NOT NULL)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT TwA_TwrId INTO #tmpTwrAtr FROM CDN.TwrAtrybuty

SET @atrybutyTwr = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
    IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
    SET @sqlA = N'ALTER TABLE #tmpTwrAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpTwrAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TwA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TwA_WartoscTxt,'','',''.'') ELSE ATR.TwA_WartoscTxt END 
        END 
        FROM CDN.TwrAtrybuty ATR 
        JOIN #tmpTwrAtr TM ON ATR.TwA_TwrId = TM.TwA_TwrId 
        WHERE ATR.TwA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Wyliczanie Atrybutów Pozycji
DECLARE @atrybutyPoz varchar(max), @atrybutyPoz2 varchar(max);

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT TrA_DeAId FROM CDN.TraElemAtr WHERE TrA_TrEId IS NOT NULL)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT TrA_TrEId INTO #tmpPozAtr FROM CDN.TraElemAtr

SET @atrybutyPoz = ''
SET @atrybutyPoz2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
    IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
    SET @sqlA = N'ALTER TABLE #tmpPozAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpPozAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TrA_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TrA_Wartosc,'','',''.'') ELSE ATR.TrA_Wartosc END 
        END  
        FROM CDN.TraElemAtr ATR 
        JOIN #tmpPozAtr TM ON ATR.TrA_TrEId = TM.TrA_TrEId
        WHERE ATR.TrA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyPoz = @atrybutyPoz + N', ISNULL(PozAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') [Pozycja Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    SET @atrybutyPoz2 = @atrybutyPoz2 + N', ''(NIEPRZYPISANE)'' [Pozycja Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
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
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

--Tworzenie tabeli z serią dokumentów
SELECT DDf_DDfID, CASE 
     WHEN DDf_Numeracja like '@rejestr%' THEN 5
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 1) = '@rejestr' THEN 1
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 2) = '@rejestr' THEN 2
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 3) = '@rejestr' THEN 3
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 4) = '@rejestr' THEN 4
END [seria]  INTO #tmpSeria FROM CDN.DokDefinicje

--Tabela dla RWS
SELECT 
TrN_TrNID [id],
COUNT(Twr_TwrId) [tow],
TrE_TrEIdProd [idtre]
INTO #towile 

FROM cdn.TraNag TW
JOIN cdn.TraElem TRW ON TRW.TrE_TrNID=TW.TrN_TrNID AND TW.TrN_TypDokumentu = 318
LEFT OUTER JOIN CDN.Towary T2 ON TRW.TrE_TwrId=T2.Twr_TwrId
GROUP BY TrN_TrNID, TrE_TrEIdProd

--Liczba dokuemntów RWS w relacji z PWP
SELECT pw.TrN_TrNID [idpw], COUNT(pw.TrN_TrNID) [rwscount]
INTO #tmpRwsCount
FROM cdn.TraNag pw
LEFT JOIN CDN.TraNagRelacje ON pw.TrN_TrNID = TrR_TrNId
LEFT JOIN cdn.TraNag rw ON TrR_FaId = rw.TrN_TrNID AND rw.TrN_TypDokumentu = 318 
WHERE pw.TrN_TypDokumentu = 317 
GROUP BY pw.TrN_TrNID

--Wyliczanie Atrybutów Zasobów
DECLARE @atrybutyZas varchar(max);
DECLARE @atrybutyZas2 varchar(max);

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in 
(
SELECT DISTINCT TsC_Cecha1_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
UNION ALL
SELECT DISTINCT TsC_Cecha2_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
UNION ALL
SELECT DISTINCT TsC_Cecha3_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
UNION ALL
SELECT DISTINCT TsC_Cecha4_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
UNION ALL
SELECT DISTINCT TsC_Cecha5_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
UNION ALL
SELECT DISTINCT TsC_Cecha6_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
UNION ALL
SELECT DISTINCT TsC_Cecha7_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
UNION ALL
SELECT DISTINCT TsC_Cecha8_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
UNION ALL
SELECT DISTINCT TsC_Cecha9_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
UNION ALL
SELECT DISTINCT TsC_Cecha10_DeAId FROM CDN.TraSElemCechy
    join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
    join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
    WHERE TrE_TypDokumentu IN (317,318)
)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT TsC_TrSID 
INTO #tmpZasAtr 
FROM CDN.TraSElemCechy
join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
WHERE TrE_TypDokumentu = 317

SELECT DISTINCT TsC_TrSID 
INTO #tmpZasAtrRWS
FROM CDN.TraSElemCechy
join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
WHERE TrE_TypDokumentu = 318

SET @atrybutyZas = ''
SET @atrybutyZas2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
       IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
       IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
       --cechy dla PWP
       SET @sqlA = N'ALTER TABLE #tmpZasAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
       EXEC(@sqlA)    
       --cechy dla RWS
       SET @sqlA = N'ALTER TABLE #tmpZasAtrRWS ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
       EXEC(@sqlA)   
       --cechy dla PWP
       SET @sqlA = N'UPDATE #tmpZasAtr
             SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = 
             CASE
                    WHEN ATR.TsC_Cecha1_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha1_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      else  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha1_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha1_Wartosc END END
                    WHEN ATR.TsC_Cecha2_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha2_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha2_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha2_Wartosc END END
                    WHEN ATR.TsC_Cecha3_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha3_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha3_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha3_Wartosc END END 
                    WHEN ATR.TsC_Cecha4_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha4_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha4_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha4_Wartosc END END 
                    WHEN ATR.TsC_Cecha5_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha5_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha5_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha5_Wartosc END END
                    WHEN ATR.TsC_Cecha6_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha6_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha6_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha6_Wartosc END END
                    WHEN ATR.TsC_Cecha7_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha7_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha7_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha7_Wartosc END END
                    WHEN ATR.TsC_Cecha8_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha8_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha8_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha8_Wartosc END END
                    WHEN ATR.TsC_Cecha9_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha9_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha9_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha9_Wartosc END END
                    WHEN ATR.TsC_Cecha10_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha10_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha10_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha10_Wartosc END END
             ELSE ''(NIEPRZYPISANE)'' END
             FROM CDN.TraSElemCechy ATR 
             JOIN #tmpZasAtr TM ON ATR.TsC_TrSID = TM.TsC_TrSID
             WHERE ATR.TsC_Cecha1_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha2_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha3_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha4_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha5_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha6_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha7_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha8_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha9_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha10_DeAId = ' + CAST(@atrybut_id AS nvarchar)
       
       EXEC(@sqlA)    
    --cechy dla RWS
           SET @sqlA = N'UPDATE  #tmpZasAtrRWS
             SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = 
             CASE
                    WHEN ATR.TsC_Cecha1_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha1_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      else  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha1_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha1_Wartosc END END
                    WHEN ATR.TsC_Cecha2_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha2_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha2_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha2_Wartosc END END
                    WHEN ATR.TsC_Cecha3_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha3_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha3_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha3_Wartosc END END 
                    WHEN ATR.TsC_Cecha4_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha4_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha4_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha4_Wartosc END END 
                    WHEN ATR.TsC_Cecha5_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha5_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha5_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha5_Wartosc END END
                    WHEN ATR.TsC_Cecha6_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha6_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha6_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha6_Wartosc END END
                    WHEN ATR.TsC_Cecha7_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha7_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha7_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha7_Wartosc END END
                    WHEN ATR.TsC_Cecha8_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha8_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha8_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha8_Wartosc END END
                    WHEN ATR.TsC_Cecha9_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha9_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha9_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha9_Wartosc END END
                    WHEN ATR.TsC_Cecha10_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha10_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha10_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha10_Wartosc END END
             ELSE ''(NIEPRZYPISANE)'' END
             FROM CDN.TraSElemCechy ATR 
             JOIN  #tmpZasAtrRWS TM ON ATR.TsC_TrSID = TM.TsC_TrSID
             WHERE ATR.TsC_Cecha1_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha2_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha3_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha4_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha5_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha6_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha7_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha8_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha9_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' OR 
             ATR.TsC_Cecha10_DeAId = ' + CAST(@atrybut_id AS nvarchar)
       
       EXEC(@sqlA)   
    --atrbuty dok PWP
    SET @atrybutyZas = @atrybutyZas + N', ISNULL(ZasAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Zasoby Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    --atrybuty dok RWS
    SET @atrybutyZas2 = @atrybutyZas2 + N', ISNULL(ZasAtrRWS.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Zasoby Składnik Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'

       FETCH NEXT FROM atrybut_cursor
       INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

SELECT DISTINCT TrE_TrEID TREID,
(select count(*) from Cdn.TraSelem TrS2 where trS2.TrS_TrEId = TrE_TrEID) TRSCount
 INTO #tmpTrSCount
FROM CDN.TraSElem Trs1 
join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
WHERE TrE_TypDokumentu IN (317,318)

set @select = 
'Declare @Wal VarChar(3); Set @Wal = cdn.Waluta('''')
  select
  BAZ.Baz_Nazwa [Baza Firmowa], 
    RWSNag.TrN_NumerPelny [Dokument RWS],
    PWPNAG.TrN_NumerPelny [Dokument Numer],

    dd.DDf_Symbol [Dokument Symbol],
    ISNULL(NULLIF(PWPNag.TrN_Opis,''''), ''(BRAK)'') [Dokument Opis],
    CASE when isnull(ser.seria,0) = 5 then 
        substring(PWPNag.TrN_NumerPelny,0,CHARINDEX(''/'',PWPNag.TrN_NumerPelny,0))
    ELSE 
        ISNULL(PARSENAME(REPLACE(substring(PWPNag.TrN_NumerPelny,CHARINDEX(''/'',PWPNag.TrN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
    END [Dokument Seria],   
    pod1.Pod_Nazwa1 [Kontrahent Pierwotny Nazwa],   
    pod1.Pod_Kod [Kontrahent Pierwotny Kod],
     ISNULL(NULLIF(pod1.Pod_Wojewodztwo, ''''), ''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Województwo],
     ISNULL(NULLIF(pod1.Pod_Powiat, ''''), ''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Powiat],
    ISNULL(NULLIF(pod1.Pod_Miasto, ''''), ''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Miasto], 
    ISNULL(NULLIF(pod1.Pod_Kraj, ''''), ''(NIEPRZYPISANE)'') [Kontrahent Pierwotny Kraj], 
    ISNULL(NULLIF(pod1.Pod_NIP, ''''), ''(BRAK)'') [Kontrahent Pierwotny NIP], 
    ISNULL(NULLIF(pod1.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Pierwotny Grupa], 
    CASE 
        WHEN knt1.Knt_OpiekunTyp = 3 THEN ISNULL(pod2.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN knt1.Knt_OpiekunTyp = 8 THEN ISNULL(opk.Ope_Kod, ''(NIEPRZYPISANE)'')
    ELSE ''(NIEPRZYPISANE)'' END [Kontrahent Pierwotny Opiekun],
    pod5.Pod_Nazwa1 [Kontrahent Nazwa], 
    pod5.Pod_Kod [Kontrahent Kod], 
    ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Kontrahent Województwo],
    ISNULL(NULLIF(pod5.Pod_Powiat, ''''),''(NIEPRZYPISANE)'') [Kontrahent Powiat], ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Kontrahent Miasto],
    ISNULL(NULLIF(pod5.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Kontrahent Kraj],
    ISNULL(NULLIF(pod5.Pod_NIP, ''''),''(BRAK)'') [Kontrahent NIP],
    ISNULL(NULLIF(pod5.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Grupa],
    CASE knt3.Knt_OpiekunTyp
        WHEN 3 THEN ISNULL(pod6.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN 8 THEN ISNULL(opk3.Ope_Kod, ''(NIEPRZYPISANE)'')
        ELSE ''(NIEPRZYPISANE)'' 
    END [Kontrahent Opiekun],
    pod7.Pod_Nazwa1 [Odbiorca Nazwa],   
    pod7.Pod_Kod [Odbiorca Kod], 
    ISNULL(NULLIF(pod7.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Odbiorca Województwo],
    ISNULL(NULLIF(pod7.Pod_Powiat, ''''),''(NIEPRZYPISANE)'') [Odbiorca Powiat], ISNULL(NULLIF(pod7.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Odbiorca Miasto],
    ISNULL(NULLIF(pod7.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Odbiorca Kraj],
    ISNULL(NULLIF(pod7.Pod_NIP, ''''),''(BRAK)'') [Odbiorca NIP],
    ISNULL(NULLIF(pod7.Pod_Grupa, ''''),''Pozostali'') [Odbiorca Grupa],    
    zal.Ope_Kod [Operator Wprowadzający], mod.Ope_Kod [Operator Modyfikujący],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Nagłówka], ISNULL(kat2.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Elementu],
    ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Nagłówka], ISNULL(kat2.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Elementu],   
    T.Twr_Nazwa [Produkt Nazwa],
    CASE T.TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(T.TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca], 
    CASE T.Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny],   
    T.Twr_Kod [Produkt Kod],    
    poz.sciezka [Produkt Pełna Nazwa Grupy], "Produkt Opis" = CAST(t.Twr_Opis as VARCHAR(1024)), T.Twr_Jm [Jednostka Miary], 
    Isnull(convert(varchar(15),T.twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG],   
     ISNULL(Mag.Mag_Symbol, ''(NIEPRZYPISANE)'') [Magazyn Kod],
     ISNULL(MagDoc.Mag_Symbol, ''(NIEPRZYPISANE)'') [Magazyn Docelowy Kod],
     T2.Twr_Kod [Składnik Kod],
     T2.Twr_Nazwa [Składnik Nazwa],
ISNULL(Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
        CASE
        WHEN T.Twr_Typ = 0 AND T.Twr_Produkt = 0 THEN ''Usługa Prosta''
        WHEN T.Twr_Typ = 1 AND T.Twr_Produkt = 0 THEN ''Towar Prosty''
        WHEN T.Twr_Typ = 0 AND T.Twr_Produkt = 1 THEN ''Usługa Złożona''
        WHEN T.Twr_Typ = 1 AND T.Twr_Produkt = 1 THEN ''Towar Złożony''
        ELSE ''(NIEOKREŚLONY)''
    END [Produkt Typ], TwC_Wartosc [Cena Domyślna],




   CAST(PWPElem.TrE_WartoscNetto/cnt.ilosc / ISNULL(TCount.TRSCount,1.0) / ISNULL(TCountRWS.TRSCount,1.0) AS DECIMAL(19,10)) [Wartość Netto], 
	 CAST(PWPElem.TrE_WartoscBrutto/cnt.ilosc / ISNULL(TCount.TRSCount,1.0) / ISNULL(TCountRWS.TRSCount,1.0) AS DECIMAL(19,10))[Wartość Brutto], 
	 CAST(PWPElem.TrE_WartoscNettoWal/cnt.ilosc  / ISNULL(TCount.TRSCount,1.0) / ISNULL(TCountRWS.TRSCount,1.0) AS DECIMAL(19,10))[Wartość Waluta],
	 CAST(PWPElem.TrE_Ilosc/cnt.ilosc  / ISNULL(TCount.TRSCount,1.0) / ISNULL(TCountRWS.TRSCount,1.0) AS DECIMAL(19,10))[Ilość], 
	 CAST( RWSSklad.TrE_WartoscNetto/rws.ilosc  / ISNULL(TCount.TRSCount,1.0) / ISNULL(TCountRWS.TRSCount,1.0)AS DECIMAL(19,10)) [Składnik Wartość Netto], 
	 CAST(RWSSklad.TrE_WartoscBrutto/rws.ilosc  / ISNULL(TCount.TRSCount,1.0) / ISNULL(TCountRWS.TRSCount,1.0) AS DECIMAL(19,10))[Składnik Wartość Brutto], 
	 CAST(RWSSklad.TrE_WartoscNettoWal/rws.ilosc  / ISNULL(TCount.TRSCount,1.0) / ISNULL(TCountRWS.TRSCount,1.0)AS DECIMAL(19,10)) [Składnik Wartość Waluta],
	 CAST(RWSSklad.TrE_Ilosc/rws.ilosc  / ISNULL(TCount.TRSCount,1.0) / ISNULL(TCountRWS.TRSCount,1.0) AS DECIMAL(19,10))[Składnik Ilość] 
    /*
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), PWPNag.TrN_DataOpe, 111), ''/'', ''-'') [Data Operacji]
    ,REPLACE(CONVERT(VARCHAR(10), PWPNag.TrN_DataWys, 111), ''/'', ''-'') [Data Wystawienia]
*/
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), PWPNag.TrN_DataOpe, 111), ''/'', ''-'') [Data Operacji Dzień], (datepart(DY, datediff(d, 0, PWPNag.TrN_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PWPNag.TrN_DataOpe)*/ [Data Operacji Tydzień Roku] 
    ,MONTH(PWPNag.TrN_DataOpe) [Data Operacji Miesiąc], DATEPART(quarter, PWPNag.TrN_DataOpe) [Data Operacji Kwartał], YEAR(PWPNag.TrN_DataOpe) [Data Operacji Rok] 
    ,REPLACE(CONVERT(VARCHAR(10), PWPNag.TrN_DataWys, 111), ''/'', ''-'') [Data Wystawienia Dzień], (datepart(DY, datediff(d, 0, PWPNag.TrN_DataWys) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PWPNag.TrN_DataWys)*/ [Data Wystawienia Tydzień Roku] 
    ,MONTH(PWPNag.TrN_DataWys) [Data Wystawienia Miesiąc], DATEPART(quarter, PWPNag.TrN_DataWys) [Data Wystawienia Kwartał], YEAR(PWPNag.TrN_DataWys) [Data Wystawienia Rok] 

    ----------KONTEKSTY
    ,CASE WHEN PWPNag.TrN_TypDokumentu = 317 THEN 25045 END [Dokument Numer __PROCID__WZ__], PWPNag.TrN_TrNId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,20201 [Kontrahent Pierwotny Nazwa __PROCID__], pod1.Pod_PodId [Kontrahent Pierwotny  Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Pierwotny Nazwa __DATABASE__]
    ,20201 [Kontrahent Pierwotny Kod __PROCID__], pod1.Pod_PodId [Kontrahent Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Pierwotny Kod __DATABASE__]
    ,20201 [Kontrahent Nazwa __PROCID__], pod5.Pod_PodId [Kontrahent Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Nazwa __DATABASE__]
    ,20201 [Kontrahent Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Kontrahent Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], T.Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
    ,25003 [Produkt Kod __PROCID__Towary__], T.Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
    ,29056 [Magazyn Kod __PROCID__Magazyny__],  Mag.Mag_MagId [Magazyn Kod __ORGID__], '''+@bazaFirmowa+''' [Magazyn Kod __DATABASE__]
    ,29056 [Magazyn Docelowy Kod __PROCID__Magazyny__],  MagDoc.Mag_MagId [Magazyn Docelowy Kod __ORGID__], '''+@bazaFirmowa+''' [Magazyn Docelowy Kod __DATABASE__]   

    '
    + @kolumny + @atrybuty + @atrybutyDok + @atrybutyTwr + @atrybutyPoz + @atrybutyZas + @atrybutyZas2
       
       
set @select2 = 
'
   from  cdn.ProdElem PE
   left join cdn.traelem PWPElem on PdE_TrEId = PWPElem.TrE_TrEId
   LEFT JOIN cdn.Tranag PWPNag ON PWPElem.TrE_TrNId = PWPNAG.TrN_TrNID
   left join cdn.traelem  RWSSklad on pe.PdE_TrEIdRWS = RWSSklad.TrE_TrEID
   left join cdn.tranag RWSNag on RWSNag.TrN_TrNID = RWSSklad.tre_trnid
  LEFT JOIN #TowCnt cnt ON cnt.PdE_TrEId = PWPElem.TrE_TrEID
  LEFT JOIN #temprws rws on RWs.PdE_TrEIdRWS = RWSSklad.TrE_TrEID

     LEFT JOIN #tmpSeria ser ON PWPNag.TrN_DDfId = DDf_DDfID
     LEFT JOIN CDN.DokDefinicje dd ON PWPNag.TrN_DDfId = dd.DDf_DDfID
     LEFT OUTER JOIN CDN.Kontrahenci knt1 ON PWPElem.TrE_PodID=Knt_KntId AND PWPElem.TrE_PodmiotTyp = 1
     LEFT OUTER JOIN CDN.PodmiotyView pod1 ON PWPElem.TrE_PodID= pod1.Pod_PodId AND PWPElem.TrE_PodmiotTyp = pod1.Pod_PodmiotTyp
     LEFT OUTER JOIN cdn.PodmiotyView pod2 ON Knt_OpiekunId = pod2.Pod_PodId AND Knt_OpiekunTyp = pod2.Pod_PodmiotTyp
     LEFT OUTER JOIN CDN.Towary T ON PWPElem.TrE_TwrId=T.Twr_TwrId
     LEFT JOIN CDN.Producenci ON Prd_PrdId = T.Twr_PrdId
     LEFT JOIN CDN.Marki ON Mrk_MrkId = T.Twr_MrkId
     LEFT JOIN CDN.TwrCeny ON T.Twr_TwrId = TwC_TwrID AND T.Twr_TwCNumer = TwC_TwCNumer
     LEFT OUTER JOIN CDN.Magazyny Mag ON (CASE WHEN PWPNag.TrN_TypDokumentu = 318 THEN PWPNag.TrN_MagZrdId ELSE ISNULL(PWPElem.TrE_MagId,PWPNag.TrN_MagZrdId) END) = Mag.Mag_MagId 
     LEFT OUTER JOIN CDN.Magazyny MagDoc ON MagDoc.Mag_MagId = PWPNag.TrN_MagDocId
     LEFT OUTER JOIN CDN.Kategorie kat1 ON PWPNag.TrN_KatID=kat1.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat2 ON PWPElem.TrE_KatID=kat2.Kat_KatID
     LEFT JOIN #tmpTwrGr Poz ON T.Twr_TwGGIDNumer = Poz.gidNumer
     LEFT JOIN #tmpKonAtr KonAtr ON pod1.Pod_PodId = KonAtr.KnA_PodmiotId AND pod1.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
     LEFT JOIN #tmpDokAtr DokAtr ON PWPNag.TrN_TrNID  = DokAtr.DAt_TrNId
     LEFT JOIN #tmpTwrAtr TwrAtr ON PWPElem.TrE_TwrId  = TwrAtr.TwA_TwrId 
     LEFT JOIN ' + @Operatorzy + ' opk ON Knt_OpiekunId = opk.Ope_OpeId AND Knt_OpiekunTyp = 8 
     LEFT JOIN ' + @Operatorzy + ' zal ON PWPNag.TrN_OpeZalID = zal.Ope_OpeId
     LEFT JOIN ' + @Operatorzy + ' mod ON PWPNag.TrN_OpeModID = mod.Ope_OpeId
     LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod1.Pod_GlID = pod5.Pod_PodId and pod1.Pod_GlKod = pod5.Pod_Kod
     LEFT OUTER JOIN CDN.Kontrahenci knt3 ON pod5.Pod_PodID=knt3.Knt_KntId AND pod5.Pod_PodmiotTyp = 1
     LEFT OUTER JOIN CDN.Kategorie kat5 ON knt3.Knt_KatID=kat5.Kat_KatID
     LEFT OUTER JOIN cdn.PodmiotyView pod6 ON knt3.Knt_OpiekunId = pod6.Pod_PodId AND knt3.Knt_OpiekunTyp = pod6.Pod_PodmiotTyp
     LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
     LEFT OUTER JOIN CDN.PodmiotyView pod7 ON PWPNag.TrN_OdbID = pod7.Pod_PodId AND PWPNag.TrN_OdbiorcaTyp = pod7.Pod_PodmiotTyp
     LEFT JOIN ' + @Operatorzy + ' opk3 ON knt3.Knt_OpiekunId = opk3.Ope_OpeId AND knt3.Knt_OpiekunTyp = 8 
     LEFT JOIN CDN.Kontrahenci knt4 ON T.Twr_KntId = knt4.Knt_KntId 
     LEFT OUTER JOIN CDN.Towary  T2 ON RWSSklad.TrE_TwrId=T2.Twr_TwrId

      LEFT JOIN #tmpPozatr PozAtr on PozAtr.TrA_TrEId = PWPElem.TrE_TrEId
     LEFT JOIN CDN.TraSElem  PWPTRS ON PWPTRS.TrS_TreID = PWPElem.TrE_TreId
     LEFT JOIN #tmpZasAtr ZasAtr ON PWPTRS.Trs_TrSId = ZasAtr.TsC_TrSID
     LEFT JOIN CDN.TraSElem  RWSTRS ON  RWSSklad.TrE_TreId=RWSTRS.TrS_TreID 
     LEFT JOIN #tmpZasAtrRWS ZasAtrRWS ON RWSTRS.Trs_TrSId = ZasAtrRWS.TsC_TrSID
    
     LEFT OUTER JOIN #tmpTrSCount TCount ON 
     PWPElem.TrE_TreId = TCount.TREID 
     LEFT OUTER JOIN #tmpTrSCount TCountRWS ON 
      RWSSklad.TrE_TreId = TCountRWS.TREID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
   where  RWSSklad.Tre_TypDokumentu = 318 AND RWSNag.TrN_TypDokumentu = 318
  and PWPNag.TrN_Bufor<>-1
AND PWPElem.TrE_Aktywny<>0

AND PWPNag.TrN_DataDok between convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) and convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)
'

exec (@select + @select2)

DROP TABLE #tmpTrSCount
DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpDokAtr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpPozAtr
DROP TABLE #tmpSeria
DROP TABLE #towile
DROP TABLE #tmpZasAtr
DROP TABLE #tmpZasAtrRWS
DROP TABLE #tmpRwsCount
drop table #TowCnt
DROP TABLE #temprws


