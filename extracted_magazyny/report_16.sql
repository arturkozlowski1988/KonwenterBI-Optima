/*
* Raport Dokumentów Magazynowych 
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
	SET @sqlA = N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS nvarchar) + N'] nvarchar(max)'
    EXEC(@sqlA)    
	SET @sqlA = N'UPDATE #tmpKonAtr
		SET [' + CAST(@atrybut_kod AS nvarchar) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.KnA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') ELSE ATR.KnA_WartoscTxt END  
		FROM CDN.KntAtrybuty ATR 
		JOIN #tmpKonAtr TM ON ATR.KnA_PodmiotId = TM.KnA_PodmiotId AND ATR.KnA_PodmiotTyp = TM.KnA_PodmiotTyp
		WHERE ATR.KnA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
	EXEC(@sqlA)    
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Atrybut ' + CAST(@atrybut_kod AS nvarchar) + ']'         
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
	SET @sqlA = N'ALTER TABLE #tmpDokAtr ADD [' + CAST(@atrybut_kod AS nvarchar) + N'] nvarchar(max)'
    EXEC(@sqlA)    
	SET @sqlA = N'UPDATE #tmpDokAtr
		SET [' + CAST(@atrybut_kod AS nvarchar) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.DAt_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') ELSE ATR.DAt_WartoscTxt END  
		FROM CDN.DokAtrybuty ATR 
		JOIN #tmpDokAtr TM ON ATR.DAt_TrNId = TM.DAt_TrNId 
		WHERE ATR.DAt_DeAId = ' + CAST(@atrybut_id AS nvarchar)
	EXEC(@sqlA)    
    
    SET @atrybutyDok = @atrybutyDok + N', ISNULL(DokAtr.[' +  CAST(@atrybut_kod AS nvarchar) + '], ''(NIEPRZYPISANE)'') AS [Dokument Atrybut ' + CAST(@atrybut_kod AS nvarchar) + ']'         
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
	SET @sqlA = N'ALTER TABLE #tmpTwrAtr ADD [' + CAST(@atrybut_kod AS nvarchar) + N'] nvarchar(max)'
    EXEC(@sqlA)    
	SET @sqlA = N'UPDATE #tmpTwrAtr
		SET [' + CAST(@atrybut_kod AS nvarchar) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TwA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') ELSE ATR.TwA_WartoscTxt END 
		FROM CDN.TwrAtrybuty ATR 
		JOIN #tmpTwrAtr TM ON ATR.TwA_TwrId = TM.TwA_TwrId 
		WHERE ATR.TwA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
	EXEC(@sqlA)    
    
    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' +  CAST(@atrybut_kod AS nvarchar) + '], ''(NIEPRZYPISANE)'') [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar) + ']'
	FETCH NEXT FROM atrybut_cursor
	INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;


--Wyliczanie Atrybutów Pozycji
DECLARE @atrybutyPoz varchar(max);

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_Typ = 1
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_format;

SET @atrybutyPoz = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @atrybutyPoz = @atrybutyPoz + N', 
	CASE 
		WHEN TrE_Atr1_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,TrE_Atr1_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') ELSE TrE_Atr1_Wartosc END 
		WHEN TrE_Atr2_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,TrE_Atr2_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') ELSE TrE_Atr2_Wartosc END 
		WHEN TrE_Atr3_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,TrE_Atr3_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') ELSE TrE_Atr3_Wartosc END  
		WHEN TrE_Atr4_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,TrE_Atr4_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') ELSE TrE_Atr4_Wartosc END  
		WHEN TrE_Atr5_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,TrE_Atr5_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') ELSE TrE_Atr5_Wartosc END  
		ELSE ''(NIEPRZYPISANE)''
	END AS [Pozycja Atrybut ' + CAST(@atrybut_kod AS nvarchar) + ']'
	FETCH NEXT FROM atrybut_cursor
	INTO @atrybut_id, @atrybut_kod, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;


--Połączenie do tabeli operatorów
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Operatorzy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 


--Właściwe zapytanie
set @select = 
'Declare @Wal VarChar(3); Set @Wal = cdn.Waluta('''')
SELECT DB_NAME() [Baza Firmowa], 

	TrN_NumerPelny [Dokument Numer], 
	CASE								
		WHEN TrN_TypDokumentu = 312 THEN 25034
		WHEN TrN_TypDokumentu = 303 THEN 25032
		WHEN TrN_TypDokumentu = 317 THEN 25045
		WHEN TrN_TypDokumentu = 307 THEN 25024
		WHEN TrN_TypDokumentu = 304 THEN 25030
		WHEN TrN_TypDokumentu = 318 THEN 25046
		WHEN TrN_TypDokumentu = 306 THEN 25022
		WHEN TrN_TypDokumentu = 313 THEN 25079
		WHEN TrN_TypDokumentu = 314 THEN 25078
	END [Dokument Numer __PROCID__WZ__], TrN_TrNId [Dokument Numer __ORGID__],


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
	
	pod1.Pod_Nazwa1 [Kontrahent Nazwa],
	20201 [Kontrahent Nazwa __PROCID__], pod1.Pod_PodId [Kontrahent Nazwa __ORGID__],
	
	pod1.Pod_Kod [Kontrahent Kod],
	20201 [Kontrahent Kod __PROCID__Kontrahenci__], pod1.Pod_PodId [Kontrahent Kod __ORGID__],
	
	 ISNULL(NULLIF(pod1.Pod_Wojewodztwo, ''''), ''(NIEPRZYPISANE)'') [Kontrahent Województwo],
	ISNULL(NULLIF(pod1.Pod_Miasto, ''''), ''(NIEPRZYPISANE)'') [Kontrahent Miasto], ISNULL(NULLIF(pod1.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Grupa], 
    CASE 
		WHEN Knt_OpiekunTyp = 3 THEN ISNULL(pod2.Pod_Kod, ''(NIEPRZYPISANE)'')
		WHEN Knt_OpiekunTyp = 8 THEN ISNULL(opk.Ope_Kod, ''(NIEPRZYPISANE)'')
	ELSE ''(NIEPRZYPISANE)'' END [Kontrahent Opiekun],
	zal.Ope_Kod [Operator Wprowadzający], mod.Ope_Kod [Operator Modyfikujący],
	ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Nagłówka], ISNULL(kat2.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Elementu],
	ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Nagłówka], ISNULL(kat2.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Elementu],
    
	Twr_Nazwa [Produkt Nazwa], 
	25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],
	
	Twr_Kod [Produkt Kod], 
	25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],
	
	poz.sciezka [Produkt Pełna Nazwa Grupy], Twr_Jm [Jednostka Miary], 
	
	ISNULL(Mag_Symbol, ''(NIEPRZYPISANE)'') [Magazyn Kod],
	29056 [Magazyn Kod __PROCID__Magazyny__], Mag_MagId [Magazyn Kod __ORGID__],

ISNULL(Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
    	CASE
		WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa Prosta''
		WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar Prosty''
		WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa Złożona''
		WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar Złożony''
		ELSE ''(NIEOKREŚLONY)''
	END [Produkt Typ], TwC_Wartosc [Cena Domyślna],
    REPLACE(CONVERT(VARCHAR(10), TrN_DataOpe, 111), ''/'', ''-'') [Data Operacji Dzień], (datepart(DY, datediff(d, 0, TrN_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataOpe)*/ [Data Operacji Tydzień Roku], 
    MONTH(TrN_DataOpe) [Data Operacji Miesiąc], DATEPART(quarter, TrN_DataOpe) [Data Operacji Kwartał], YEAR(TrN_DataOpe) [Data Operacji Rok], 
    TR.TrE_WartoscNetto [Wartość Netto], TR.TrE_WartoscBrutto [Wartość Brutto], TR.TrE_WartoscNettoWal [Wartość Waluta], TR.TrE_Ilosc [Ilość], 
    TR.TrE_WartoscNetto - (ISNULL(KosztWyliczony.Koszt ,0) + TR.TrE_KosztUslugi) [Marża], ISNULL(KosztWyliczony.Koszt ,0) + TR.TrE_KosztUslugi [Koszt Zakupu] '
    + @kolumny + @atrybuty + @atrybutyDok + @atrybutyTwr + @atrybutyPoz
       
set @select2 = 
' FROM cdn.TraNag 
     JOIN cdn.TraElem TR ON TrE_TrNID=TrN_TrNID 
     LEFT OUTER JOIN CDN.Kontrahenci ON TrE_PodID=Knt_KntId AND TrE_PodmiotTyp = 1
     LEFT OUTER JOIN CDN.PodmiotyView pod1 ON TrE_PodID= pod1.Pod_PodId AND TrE_PodmiotTyp = pod1.Pod_PodmiotTyp
     LEFT OUTER JOIN cdn.PodmiotyView pod2 ON Knt_OpiekunId = pod2.Pod_PodId AND Knt_OpiekunTyp = pod2.Pod_PodmiotTyp
     LEFT OUTER JOIN CDN.Towary ON TrE_TwrId=Twr_TwrId
	 LEFT JOIN CDN.Producenci ON Prd_PrdId = Twr_PrdId
	 LEFT JOIN CDN.Marki ON Mrk_MrkId = Twr_MrkId
     LEFT JOIN CDN.TwrCeny ON Twr_TwrId = TwC_TwrID AND Twr_TwCNumer = TwC_TwCNumer
     LEFT OUTER JOIN CDN.Magazyny ON TrE_MagId=Mag_MagId 
     LEFT OUTER JOIN CDN.Kategorie kat1 ON TrN_KatID=kat1.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat2 ON TrE_KatID=kat2.Kat_KatID
     LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
     LEFT JOIN #tmpKonAtr KonAtr ON pod1.Pod_PodId = KonAtr.KnA_PodmiotId AND pod1.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
     LEFT JOIN #tmpDokAtr DokAtr ON TrN_TrNID  = DokAtr.DAt_TrNId
     LEFT JOIN #tmpTwrAtr TwrAtr ON TrE_TwrId  = TwrAtr.TwA_TwrId 
     LEFT JOIN ' + @Operatorzy + ' opk ON Knt_OpiekunId = opk.Ope_OpeId AND Knt_OpiekunTyp = 8 
	 LEFT JOIN ' + @Operatorzy + ' zal ON TrN_OpeZalID = zal.Ope_OpeId
	 LEFT JOIN ' + @Operatorzy + ' mod ON TrN_OpeModID = mod.Ope_OpeId
     LEFT OUTER JOIN ( 
			SELECT ISNULL(SUM(CASE WHEN TrS_Rodzaj = 312000 AND TrS_Ilosc < 0 AND TrS_ZwrId IS NULL THEN 0
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
                       JOIN cdn.TraElem TRERel ON TRERel.Tre_trnid = TrR_TrnId AND TREREl.Tre_lppow= tre.tre_lppow
                     WHERE TrR_FaId = TRE.TrE_TrNId  AND TRERel.TrE_TypDokumentu NOT IN ( 318,309,308 )
                 ) AS Elem ON TRE.Tre_TrEId = Elem.IdElem
            JOIN CDN.TraSElem TRS ON TRS.TrS_TrEId = Elem.IdZwiaz
            GROUP BY TRE.TrE_TrEID
	)KosztWyliczony  ON KosztWyliczony.TrE_TrEID = TR.TrE_TrEID
WHERE
TrN_TypDokumentu IN ( 303, 304, 306, 307, 312, 313, 314, 317, 318)
AND TrN_Bufor<>-1
AND TrE_Aktywny<>0'

exec (@select + @select2)

DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpDokAtr
DROP TABLE #tmpTwrAtr