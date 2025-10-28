/*
* Raport Analiza opakowań na dzień
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
declare @select3 varchar(max)
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
	FETCH NEXT FROM atrybut_cursor
	INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;


--Wyliczanie Atrybutów Towarów
DECLARE @atrybutyTwr varchar(max), @atrybutyTwr2 varchar(max);

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
SET @atrybutyTwr2 = ''

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
	SET @atrybutyTwr2 = @atrybutyTwr2 + N', ''(NIEPRZYPISANE)'' [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
	FETCH NEXT FROM atrybut_cursor
	INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

----Wyliczanie stanu początkowego opakowań
select
sum((Case when Trn_typdokumentu = 313 then -1 else 1 end) * TrE_Ilosc) [Ilosc],
sum((Case when Trn_typdokumentu = 313 then -1 else 1 end) * TrE_WartoscBrutto) [Brutto],
sum((Case when Trn_typdokumentu = 313 then -1 else 1 end) * TrE_WartoscNetto) [Netto],
TrE_MagId MagId,
TrE_TwRID TwRID,
TrE_PodID PodID
into #tmpstan
from cdn.TraNag
left join cdn.TraElem on TrN_TrNID=TrE_TrNId
where TrN_TypDokumentu IN (314,313) AND TrE_DataDok < convert(datetime,@DataOd, 120) 
group by TrE_MagId,TrE_PodID,TrE_TwRID


--Właściwe zapytanie
set @select =
'SELECT
case when TrN_TypDokumentu = 313 then ''PKA'' else ''WKA'' end [Dokument Typ],
TrN_NumerPelny [Dokument Numer],
REPLACE(CONVERT(VARCHAR(10),  TrE_DataDok, 111), ''/'', ''-'') [Dokument Data],
Knt_Nazwa1 [Kontrahent Nazwa],
KnT_Kod [Kontrahent Kod],
(Case when Trn_typdokumentu = 313 then -1 else 1 end) * TrE_Ilosc [Opakowanie Ilość],
(Case when Trn_typdokumentu = 313 then -1 else 1 end) * TrE_WartoscBrutto [Opakowanie Wartość Brutto],
(Case when Trn_typdokumentu = 313 then -1 else 1 end) * TrE_WartoscNetto [Opakowanie Wartość Netto],
stany.ilosc [Opakowanie Stan Początkowy Ilość],
stany.Netto [Opakowanie Stan Początkowy Netto],
stany.Brutto [Opakowanie Stan Początkowy Brutto],
TrE_TwrNazwa [Produkt Nazwa],
TrE_TwrKod [Produkt Kod]

 '  + @kolumny + @atrybuty + @atrybutyTwr +'

FROM cdn.TraNag
LEFT JOIN cdn.TraElem ON TrN_TrNID=TrE_TrNId
LEFT JOIN cdn.Towary ON Tre_TwRID = TwR_TwRID
LEFT JOIN cdn.Kontrahenci ON Knt_KntId=TrN_PodID
LEFT JOIN #tmpKonAtr KonAtr ON Knt_KntId = KonAtr.KnA_PodmiotId
LEFT JOIN  #tmpTwrGr poz ON Twr_TwGGIDNumer = poz.gidNumer
LEFT JOIN #tmpTwrAtr twratr ON twratr.TwA_TwrId = TwR_TwRId
LEFT JOIN #tmpstan stany ON stany.MagId = TrE_MagId AND stany.podid = TrE_PodId AND stany.TwRId = TrE_TwRId

WHERE TrN_TypDokumentu IN (314,313) AND TrN_PodmiotTyp = 1 

AND TrE_DataDok <= convert(datetime,''' + convert(varchar, @DataDo, 120) + ''', 120) AND TrE_DataDok >= convert(datetime,''' + convert(varchar, @DataOd, 120) + ''', 120)'

EXEC(@select)

DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpStan
