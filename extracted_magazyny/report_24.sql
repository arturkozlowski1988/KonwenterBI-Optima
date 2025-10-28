

/*
* Raport Dokumentów Magazynowych z cechami dostaw
* Wersja raportu: 37.0
* Wersja baz OPTIMY: 2025.3000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

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
                SET ONr' + CAST(@poziom AS nvarchar) +  '= grONumer '
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
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.KnA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.KnA_WartoscTxt,'','',''.'') ELSE ATR.KnA_WartoscTxt END 
        END  
        FROM CDN.KntAtrybuty ATR 
        JOIN #tmpKonAtr TM ON ATR.KnA_PodmiotId = TM.KnA_PodmiotId AND ATR.KnA_PodmiotTyp = TM.KnA_PodmiotTyp
        WHERE ATR.KnA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Pierwotny Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'     
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr1.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'      
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
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.DAt_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
          ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.DAt_WartoscTxt,'','',''.'') ELSE ATR.DAt_WartoscTxt END 
        END  
        FROM CDN.DokAtrybuty ATR 
        JOIN #tmpDokAtr TM ON ATR.DAt_TrNId = TM.DAt_TrNId 
        WHERE ATR.DAt_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyDok = @atrybutyDok + N', ISNULL(DokAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Dokument Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
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
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TwA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TwA_WartoscTxt,'','',''.'') ELSE ATR.TwA_WartoscTxt END 
        END 
        FROM CDN.TwrAtrybuty ATR 
        JOIN #tmpTwrAtr TM ON ATR.TwA_TwrId = TM.TwA_TwrId 
        WHERE ATR.TwA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
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
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TrA_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TrA_Wartosc,'','',''.'') ELSE ATR.TrA_Wartosc END 
        END  
        FROM CDN.TraElemAtr ATR 
        JOIN #tmpPozAtr TM ON ATR.TrA_TrEId = TM.TrA_TrEId
        WHERE ATR.TrA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyPoz = @atrybutyPoz + N', ISNULL(PozAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') [Pozycja Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
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
END [seria]  INTO #tmpSeria FROM CDN.DokDefinicje


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
UNION ALL
SELECT DISTINCT TsC_Cecha2_DeAId FROM CDN.TraSElemCechy
UNION ALL
SELECT DISTINCT TsC_Cecha3_DeAId FROM CDN.TraSElemCechy
UNION ALL
SELECT DISTINCT TsC_Cecha4_DeAId FROM CDN.TraSElemCechy
UNION ALL
SELECT DISTINCT TsC_Cecha5_DeAId FROM CDN.TraSElemCechy
UNION ALL
SELECT DISTINCT TsC_Cecha6_DeAId FROM CDN.TraSElemCechy
UNION ALL
SELECT DISTINCT TsC_Cecha7_DeAId FROM CDN.TraSElemCechy
UNION ALL
SELECT DISTINCT TsC_Cecha8_DeAId FROM CDN.TraSElemCechy
UNION ALL
SELECT DISTINCT TsC_Cecha9_DeAId FROM CDN.TraSElemCechy
UNION ALL
SELECT DISTINCT TsC_Cecha10_DeAId FROM CDN.TraSElemCechy
)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT TsC_TrSID INTO #tmpZasAtr FROM CDN.TraSElemCechy
join CDN.TraSElem Trs1 on Trs1.TrS_TrSID = TsC_TrSID
join CDN.TraElem on TrE_TrEID = Trs1.TrS_TrEId
WHERE 
Trs1.TrS_DataOpe between convert(datetime,convert(varchar, @DATAOD, 120) , 120) and convert(datetime, convert(varchar, @DATADO, 120) , 120)

SET @atrybutyZas = ''
SET @atrybutyZas2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
         IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
       IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
       --cechy dla PWP
       SET @sqlA = N'ALTER TABLE #tmpZasAtr ADD [' + CAST(@atrybut_kod AS Varchar(50)) + N'] nvarchar(max)'
       EXEC(@sqlA)    
       --cechy dla PWP

DECLARE @sqlB varchar(max), @sqlC Varchar(Max)
       SET @sqlA =  CONCAT('UPDATE #tmpZasAtr
             SET [' ,@atrybut_kod  ,  '] = 
             CASE
                    WHEN ATR.TsC_Cecha1_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha1_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      else  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha1_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha1_Wartosc END END
                    WHEN ATR.TsC_Cecha2_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha2_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha2_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha2_Wartosc END END
                    WHEN ATR.TsC_Cecha3_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha3_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha3_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha3_Wartosc END END 
                    WHEN ATR.TsC_Cecha4_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha4_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha4_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha4_Wartosc END END 
                    WHEN ATR.TsC_Cecha5_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha5_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha5_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha5_Wartosc END END
                    WHEN ATR.TsC_Cecha6_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha6_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha6_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha6_Wartosc END END
                    WHEN ATR.TsC_Cecha7_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha7_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha7_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha7_Wartosc END END
                    WHEN ATR.TsC_Cecha8_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha8_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha8_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha8_Wartosc END END
                    WHEN ATR.TsC_Cecha9_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha9_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha9_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha9_Wartosc END END
                    WHEN ATR.TsC_Cecha10_DeAId = ' ,@atrybut_id, ' THEN  case WHEN ' ,@atrybut_format ,' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha10_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                      ELSE  CASE WHEN ' ,@atrybut_format ,' = 2  THEN REPLACE(ATR.TsC_Cecha10_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha10_Wartosc END END
             ELSE ''(NIEPRZYPISANE)'' END')
           SET @sqlB =  CONCAT(   ' FROM CDN.TraSElemCechy ATR 
             JOIN #tmpZasAtr TM ON ATR.TsC_TrSID = TM.TsC_TrSID
             WHERE ATR.TsC_Cecha1_DeAId = ' ,@atrybut_id, ' OR 
             ATR.TsC_Cecha2_DeAId = ' ,@atrybut_id, ' OR 
             ATR.TsC_Cecha3_DeAId = ' ,@atrybut_id, ' OR 
             ATR.TsC_Cecha4_DeAId = ' ,@atrybut_id, ' OR 
             ATR.TsC_Cecha5_DeAId = ' ,@atrybut_id, ' OR 
             ATR.TsC_Cecha6_DeAId = ' ,@atrybut_id, ' OR 
             ATR.TsC_Cecha7_DeAId = ' ,@atrybut_id, ' OR 
             ATR.TsC_Cecha8_DeAId = ' ,@atrybut_id, ' OR ')
             SET @sqlC =  CONCAT( 'ATR.TsC_Cecha9_DeAId = ', @atrybut_id, ' OR 
             ATR.TsC_Cecha10_DeAId = ' ,@atrybut_id
       ) 

EXEC(@sqlA+@sqlB+@sqlC)
    
    SET @atrybutyZas = @atrybutyZas + N', ISNULL(ZasAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Zasoby Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'

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

WHERE 
TrS_DataOpe between convert(datetime,convert(varchar, @DATAOD, 120) , 120) and convert(datetime, convert(varchar, @DATADO, 120) , 120)

--Właściwe zapytanie
set @select = 
'Declare @Wal VarChar(3); Set @Wal = cdn.Waluta('''')
SELECT BAZ.Baz_Nazwa [Baza Firmowa], 
    TrN_NumerPelny [Dokument Numer],
    dd.DDf_Symbol [Dokument Symbol],
    ISNULL(NULLIF(TrN_Opis,''''),''(BRAK)'') [Dokument Opis],
ISNULL(NULLIF(TrN_Waluta, ''''), @Wal) [Waluta], 
    CASE                                
        WHEN TrN_TypDokumentu = 312 THEN ''MM''
        WHEN TrN_TypDokumentu = 303 THEN ''PW''
        WHEN TrN_TypDokumentu = 317 THEN ''PWP''
        WHEN TrN_TypDokumentu = 307 THEN ''PZ''
        WHEN TrN_TypDokumentu = 304 THEN ''RW''
        WHEN TrN_TypDokumentu = 318 THEN ''RWS''
        WHEN TrN_TypDokumentu = 306 THEN ''WZ''
        WHEN TrN_TypDokumentu = 313 THEN ''PKA''
        WHEN TrN_TypDokumentu = 314 THEN ''WKA''
    ELSE ''(NIEPRZYPISANY)'' END [Dokument Typ],
    CASE when isnull(ser.seria,0) = 5 then 
        substring(TrN_NumerPelny,0,CHARINDEX(''/'',TrN_NumerPelny,0))
    ELSE 
        ISNULL(PARSENAME(REPLACE(substring(TrN_NumerPelny,CHARINDEX(''/'',TrN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
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
    reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE knt1.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE knt1.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Pierwotny Rodzaj],
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
    reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE knt3.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Rodzaj],
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
    Twr_Nazwa [Produkt Nazwa],
    CASE TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
    ISNULL(knt5.Knt_Nazwa1, ''(NIEPRZYPISANE)'')  [Produkt Dostawca Nazwa],
    ISNULL(knt6.Knt_Nazwa1, ''(NIEPRZYPISANE)'')  [Produkt Producent Nazwa],
    CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny],     
    Twr_Kod [Produkt Kod],  
    poz.sciezka [Produkt Pełna Nazwa Grupy], "Produkt Opis" = CAST(Twr_Opis as VARCHAR(1024)), Twr_Jm [Jednostka Miary], 
    Isnull(convert(varchar(15),twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG],
     ISNULL(Mag.Mag_Symbol, ''(NIEPRZYPISANE)'') [Magazyn Kod],
     ISNULL(MagDoc.Mag_Symbol, ''(NIEPRZYPISANE)'') [Magazyn Docelowy Kod],
ISNULL(Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
        CASE
        WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa Prosta''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar Prosty''
        WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa Złożona''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar Złożony''
        ELSE ''(NIEOKREŚLONY)''
    END [Produkt Typ], TwC_Wartosc [Cena Domyślna],
      TR.TrE_WartoscNetto/ISNULL(TCount.TRSCount,1.0) [Wartość Netto], TR.TrE_WartoscBrutto/ISNULL(TCount.TRSCount,1.0) [Wartość Brutto], TR.TrE_WartoscNettoWal/ISNULL(TCount.TRSCount,1.0) [Wartość Waluta], ISNULL(Trs_Ilosc,TR.TrE_Ilosc/ISNULL(TCount.TRSCount,1.0)) [Ilość], 
    (TR.TrE_WartoscNetto - (ISNULL(KosztWyliczony.Koszt ,0) + TR.TrE_KosztUslugi))/ISNULL(TCount.TRSCount,1.0) [Marża], (ISNULL(KosztWyliczony.Koszt ,0) + TR.TrE_KosztUslugi)/ISNULL(TCount.TRSCount,1.0) [Koszt Zakupu]
        ,CASE WHEN (MONTH(TrN_DataOpe) = MONTH(GETDATE())) AND (YEAR(TrN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' ELSE ''NIE'' END [Czas Aktualny Miesiąc],
    CASE 
        WHEN (MONTH(TrN_DataOpe) = MONTH(GETDATE())-1) AND (YEAR(TrN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
        WHEN ((MONTH(TrN_DataOpe) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(TrN_DataOpe) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Aktualny Miesiąc Poprzedni]

/*  
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), TrN_DataOpe, 111), ''/'', ''-'') [Data Operacji]  
    ,REPLACE(CONVERT(VARCHAR(10), TrN_DataWys, 111), ''/'', ''-'') [Data Wystawienia]
*/
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), TrN_DataOpe, 111), ''/'', ''-'') [Data Operacji Dzień], (datepart(DY, datediff(d, 0, TrN_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataOpe)*/ [Data Operacji Tydzień Roku] 
    ,MONTH(TrN_DataOpe) [Data Operacji Miesiąc], DATEPART(quarter, TrN_DataOpe) [Data Operacji Kwartał], YEAR(TrN_DataOpe) [Data Operacji Rok]  
    ,REPLACE(CONVERT(VARCHAR(10), TrN_DataWys, 111), ''/'', ''-'') [Data Wystawienia Dzień], (datepart(DY, datediff(d, 0, TrN_DataWys) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataWys)*/ [Data Wystawienia Tydzień Roku]
    ,MONTH(TrN_DataWys) [Data Wystawienia Miesiąc], DATEPART(quarter, TrN_DataWys) [Data Wystawienia Kwartał], YEAR(TrN_DataWys) [Data Wystawienia Rok]  

    ----------KONTEKSTY
                                    ,CASE                               
        WHEN TrN_TypDokumentu = 312 THEN 25034
        WHEN TrN_TypDokumentu = 303 THEN 25032
        WHEN TrN_TypDokumentu = 317 THEN 25045
        WHEN TrN_TypDokumentu = 307 THEN 25024
        WHEN TrN_TypDokumentu = 304 THEN 25030
        WHEN TrN_TypDokumentu = 318 THEN 25046
        WHEN TrN_TypDokumentu = 306 THEN 25022
        WHEN TrN_TypDokumentu = 313 THEN 25079
        WHEN TrN_TypDokumentu = 314 THEN 25078
    END [Dokument Numer __PROCID__WZ__], TrN_TrNId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,20201 [Kontrahent Pierwotny Nazwa __PROCID__], pod1.Pod_PodId [Kontrahent Pierwotny  Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Pierwotny Nazwa __DATABASE__]
    ,20201 [Kontrahent Pierwotny Kod __PROCID__], pod1.Pod_PodId [Kontrahent Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Pierwotny Kod __DATABASE__]
    ,20201 [Kontrahent Nazwa __PROCID__], pod5.Pod_PodId [Kontrahent Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Nazwa __DATABASE__]
    ,20201 [Kontrahent Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Kontrahent Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
    ,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
    ,29056 [Magazyn Kod __PROCID__Magazyny__], Mag.Mag_MagId [Magazyn Kod __ORGID__], '''+@bazaFirmowa+''' [Magazyn Kod __DATABASE__]
    ,29056 [Magazyn Docelowy Kod __PROCID__Magazyny__],  MagDoc.Mag_MagId [Magazyn Docelowy Kod __ORGID__], '''+@bazaFirmowa+''' [Magazyn Docelowy Kod __DATABASE__]
    
    '
    + @kolumny + @atrybuty + @atrybutyDok + @atrybutyTwr + @atrybutyPoz+ @atrybutyZas
       
set @select2 = 
' FROM cdn.TraNag 
     JOIN cdn.TraElem TR ON TrE_TrNID=TrN_TrNID 
     LEFT JOIN #tmpSeria ser ON TrN_DDfId = DDf_DDfID
     LEFT JOIN CDN.DokDefinicje dd ON TrN_DDfId = dd.DDf_DDfID
     LEFT OUTER JOIN CDN.Kontrahenci knt1 ON TrE_PodID=Knt_KntId AND TrE_PodmiotTyp = 1
     LEFT OUTER JOIN CDN.PodmiotyView pod1 ON TrE_PodID= pod1.Pod_PodId AND TrE_PodmiotTyp = pod1.Pod_PodmiotTyp
     LEFT OUTER JOIN cdn.PodmiotyView pod2 ON Knt_OpiekunId = pod2.Pod_PodId AND Knt_OpiekunTyp = pod2.Pod_PodmiotTyp
     LEFT OUTER JOIN CDN.Towary ON TrE_TwrId=Twr_TwrId
     LEFT JOIN CDN.Producenci ON Prd_PrdId = Twr_PrdId
     LEFT JOIN CDN.Marki ON Mrk_MrkId = Twr_MrkId
     LEFT JOIN CDN.TwrCeny ON Twr_TwrId = TwC_TwrID AND Twr_TwCNumer = TwC_TwCNumer
     LEFT OUTER JOIN CDN.Magazyny Mag ON (CASE WHEN TrN_TypDokumentu = 318 THEN TrN_MagZrdId ELSE ISNULL(TrE_MagId,TrN_MagZrdId) END) = Mag.Mag_MagId 
     LEFT OUTER JOIN CDN.Magazyny MagDoc ON MagDoc.Mag_MagId = TrN_MagDocId
     LEFT OUTER JOIN CDN.Kategorie kat1 ON TrN_KatID=kat1.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat2 ON TrE_KatID=kat2.Kat_KatID
     LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
     LEFT JOIN #tmpKonAtr KonAtr ON pod1.Pod_PodId = KonAtr.KnA_PodmiotId AND pod1.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
     LEFT JOIN #tmpDokAtr DokAtr ON TrN_TrNID  = DokAtr.DAt_TrNId
     LEFT JOIN #tmpTwrAtr TwrAtr ON TrE_TwrId  = TwrAtr.TwA_TwrId 
     LEFT JOIN #tmpPozatr PozAtr on PozAtr.TrA_TrEId = TrE_TrEId
     LEFT JOIN ' + @Operatorzy + ' opk ON Knt_OpiekunId = opk.Ope_OpeId AND Knt_OpiekunTyp = 8 
     LEFT JOIN ' + @Operatorzy + ' zal ON TrN_OpeZalID = zal.Ope_OpeId
     LEFT JOIN ' + @Operatorzy + ' mod ON TrN_OpeModID = mod.Ope_OpeId
     LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod1.Pod_GlID = pod5.Pod_PodId and pod1.Pod_GlKod = pod5.Pod_Kod
     LEFT OUTER JOIN CDN.Kontrahenci knt3 ON pod5.Pod_PodID=knt3.Knt_KntId AND pod5.Pod_PodmiotTyp = 1
     LEFT OUTER JOIN CDN.Kategorie kat5 ON knt3.Knt_KatID=kat5.Kat_KatID
     LEFT OUTER JOIN cdn.PodmiotyView pod6 ON knt3.Knt_OpiekunId = pod6.Pod_PodId AND knt3.Knt_OpiekunTyp = pod6.Pod_PodmiotTyp
     LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
     LEFT JOIN ' + @Operatorzy + ' opk3 ON knt3.Knt_OpiekunId = opk3.Ope_OpeId AND knt3.Knt_OpiekunTyp = 8 
     LEFT OUTER JOIN CDN.PodmiotyView pod7 ON TrN_OdbID = pod7.Pod_PodId AND TrN_OdbiorcaTyp = pod7.Pod_PodmiotTyp
     LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
     LEFT JOIN CDN.Kontrahenci knt5 ON Twr_KntId = knt5.Knt_KntId
     LEFT JOIN CDN.Kontrahenci knt6 ON Twr_PrdId = knt6.Knt_KntId
LEFT OUTER JOIN ( 
            SELECT ISNULL(SUM(CASE WHEN TrS_Rodzaj in (312000,312008) AND TrS_Ilosc < 0 AND TrS_ZwrId IS NULL THEN 0
                                   WHEN (TrS_Rodzaj = 308000 OR TrS_Rodzaj = 308011) AND TrS_Ilosc < 0 THEN 0
                                   ELSE TrS_Wartosc
                              END),0) as Koszt,
                           TRE.TrE_TrEID
            FROM CDN.TraElem TRE
            JOIN ( SELECT TrE_TrEId as IdElem, TrE_TrEId as IdZwiaz
                   FROM CDN.TraElem
                   UNION ALL
                   SELECT TRE.TrE_TrEId, TRERel.TrE_TreId
                     FROM cdn.TraElem TRE
                       JOIN cdn.TraNag TRN ON TRE.TrE_TrNId = TrN_TrNId
                       JOIN cdn.TraNagRelacje  ON TrN_TrNId = TrR_FaId AND TrR_Flaga <> 1
                       JOIN cdn.TraElem TRERel ON TRERel.Tre_trnid = TrR_TrnId AND TREREl.Tre_lppow= tre.tre_lppow AND TREREl.TrE_TwrID = TRE.TrE_TwrID
                                  WHERE TrR_FaId = TRE.TrE_TrNId  AND ((TRN.TRN_TypDokumentu = 307 AND TRERel.TrE_TypDokumentu NOT IN ( 318,309,308,301,306)) OR (TRN.TRN_TypDokumentu <> 307 AND TRERel.TrE_TypDokumentu NOT IN ( 318,309,308,301)))
                 ) AS Elem ON TRE.Tre_TrEId = Elem.IdElem
            JOIN CDN.TraSElem TRS ON TRS.TrS_TrEId = Elem.IdZwiaz
            GROUP BY TRE.TrE_TrEID
    )KosztWyliczony  ON KosztWyliczony.TrE_TrEID = TR.TrE_TrEID
    LEFT JOIN CDN.TraSElem ON TrS_TreID = TR.TrE_TreId
    LEFT JOIN #tmpZasAtr ZasAtr ON Trs_TrSId = ZasAtr.TsC_TrSID
    LEFT OUTER JOIN #tmpTrSCount TCount ON TR.TRE_TREID = TREID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
WHERE
TrN_TypDokumentu IN ( 303, 304, 306, 307, 312, 313, 314, 317, 318)
AND TrN_Bufor<>-1
AND TrE_Aktywny<>0
AND TrN_DataOpe BETWEEN convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120)  AND convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)'

exec (@select + @select2)

DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpDokAtr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpSeria
DROP TABLE #tmpZasAtr
DROP TABLE #tmpTrSCount
DROP TABLE #tmpPozatr








