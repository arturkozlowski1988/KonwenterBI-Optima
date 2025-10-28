/*
* Raport Stanów Magazynowych w Zakresie Dat 
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


--Wyliczanie Atrybutów Towarów
DECLARE @atrybut_id int, @atrybut_kod nvarchar(50), @atrybut_typ int, @atrybut_format int, @sqlA nvarchar(max), @atrybutyTwr varchar(max);

DECLARE @wersja float;
SET @wersja = (SELECT CONVERT(float, SYS_Wartosc) FROM CDN.SystemCDN WHERE SYS_ID = 3)

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
    
    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' +  CAST(@atrybut_kod AS nvarchar) + '], ''(NIEPRZYPISANE)'') AS [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar) + ']'         
	FETCH NEXT FROM atrybut_cursor
	INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;


--Tworzenie tabeli tymczasowej dat
DECLARE @tmpDataOd DATETIME;
SET @tmpDataOd = @DataOd
CREATE TABLE #TmpDates (Data DATETIME)

WHILE @tmpDataOd<=@DataDo
BEGIN
	INSERT INTO #TmpDates VALUES (@tmpDataOd)
	SET @tmpDataOd = @tmpDataOd + 1
END					
	
CREATE UNIQUE CLUSTERED INDEX bu ON #TmpDates ([Data])


--Tworzenie tabeli tymczasowej z warością sprzedaży
SELECT TrE_MagId, TrE_TwrId, TrE_DataOpe, SUM(TrE_WartoscNetto) SprzedazWartosc, SUM(TrE_Ilosc) SprzedazIlosc
INTO #tmpSprzedaz 
FROM CDN.TraElem
WHERE TrE_Aktywny <> 0 
	AND TrE_TypDokumentu IN (-1, 302, 305) 
	AND TrE_DataOpe BETWEEN @DataOd AND @DataDo
GROUP BY TrE_MagId, TrE_TwrId, TrE_DataOpe 	


--Właściwe zapytanie	
set @select =
'DECLARE @IloscDni INT; SET @IloscDni = DATEDIFF ( D, ''' + convert(varchar, @DataOd) + ''', ''' + convert(varchar, @DataDo) + ''') + 1;					
SELECT DB_NAME() [Baza Firmowa], REPLACE(CONVERT(VARCHAR(10), twi3.data, 111), ''/'', ''-'') [Data Dzień], (datepart(DY, datediff(d, 0, twi3.data) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, twi3.data)*/ [Data Tydzień Roku], 
    MONTH(twi3.data) [Data Miesiąc], DATEPART(quarter, twi3.data) [Data Kwartał], YEAR(twi3.data) [Data Rok], 

	Twr_Kod [Produkt Kod], 
	25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],
	
	Twr_Nazwa [Produkt Nazwa], 
	25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],
	
	Twr_JM [Produkt Jednostka Miary], ISNULL(NULLIF(Twr_JMZ,''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza], 
	
	Mag_Symbol [Magazyn Kod],
	29056 [Magazyn Kod __PROCID__Magazyny__], Mag_MagId [Magazyn Kod __ORGID__],

	CASE
		WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa Prosta''
		WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar Prosty''
		WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa Złożona''
		WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar Złożony''
		ELSE ''(NIEOKREŚLONY)''
	END [Produkt Typ], TwC_Wartosc [Cena Domyślna], ISNULL(Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
	ISNULL(kat.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria Szczegółowa], ISNULL(kat.Kat_KodOgolny, ''(PUSTA)'') [Produkt Kategoria Ogólna], 
	ISNULL(TWI.TwI_Ilosc, 0) [Ilość], 
	CASE WHEN Twr_JMPrzelicznikL <> 0 THEN ISNULL(TWI.TwI_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0) ELSE 0 END [Ilość Jednostka Pomocnicza], 
	ISNULL(TWI.TwI_Rezerwacje, 0) [Rezerwacje], 
	CASE WHEN Twr_JMPrzelicznikL <> 0 THEN ISNULL(TWI.TwI_Rezerwacje*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0) ELSE 0 END [Rezerwacje Jednostka Pomocnicza], 
	ISNULL(TWI.TwI_Braki, 0) [Braki], 
	CASE WHEN Twr_JMPrzelicznikL <> 0 THEN ISNULL(TWI.TwI_Braki*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0) ELSE 0 END [Braki Jednostka Pomocnicza], 
	ISNULL(TWI.TwI_Zamowienia, 0) [Zamówienia], 
	CASE WHEN Twr_JMPrzelicznikL <> 0 THEN ISNULL(TWI.TwI_Zamowienia*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0) ELSE 0 END [Zamówienia Jednostka Pomocnicza],
	ISNULL(TWI.TwI_Wartosc, 0) [Wartość Netto], 
	ISNULL(TWI.TwI_Wartosc, 0 ) * (1 + Twr_Stawka/100) [Wartość Brutto], @IloscDni [Liczba Dni],
	NULLIF(Twr_IloscMin,0) [Ilość Minimalna], NULLIF(Twr_IloscMax,0) [Ilość Maksymalna],
	CASE WHEN twi3.data = convert(datetime,''' + convert(varchar, @DataDo, 120) + ''', 120) THEN TWI.TwI_Ilosc ELSE 0 END [Ilość Ostatni Dzień],
	SprzedazWartosc [Sprzedaż Wartość Netto], SprzedazIlosc [Sprzedaż Ilość]
	' + @kolumny + @atrybutyTwr + '										
FROM cdn.TwrIlosci TWI
	JOIN (
		SELECT MAX(TwI_Data) as MaxData, TwI_MagId, TwI_TwrId, Data 
		FROM CDN.TwrIlosci TWI2
		CROSS JOIN #TmpDates 
		WHERE TWI2.TwI_MagId IS NOT NULL AND TWI2.TwI_Data <= Data
		GROUP BY  TWI2.TwI_MagId, TWI2.TwI_TwrId, data 
	)TWI3 ON TWI3.TwI_TwrId = TWI.TwI_TwrId	AND TWI3.TwI_MagId = TWI.TwI_MagId AND TWI3.MaxData = TWI.TwI_Data	
	JOIN CDN.Towary ON TWI.TwI_TwrId = Twr_TwrId	
	 LEFT JOIN CDN.Producenci ON Prd_PrdId = Twr_PrdId
	 LEFT JOIN CDN.Marki ON Mrk_MrkId = Twr_MrkId
	LEFT JOIN CDN.TwrCeny ON Twr_TwrId = TwC_TwrID AND Twr_TwCNumer = TwC_TwCNumer
	JOIN CDN.Magazyny ON TWI.TwI_MagId = Mag_MagId	
	LEFT OUTER JOIN CDN.Kategorie kat ON Twr_KatId=kat.Kat_KatID
	LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
    LEFT JOIN #tmpTwrAtr TwrAtr ON TWI.TwI_TwrId  = TwrAtr.TwA_TwrId 
    LEFT OUTER JOIN #tmpSprzedaz ON TWI.TwI_MagId = TrE_MagId AND TWI.TwI_TwrId = TrE_TwrId AND twi3.data = TrE_DataOpe
WHERE TWI.TwI_MagId IS NOT NULL'

IF @ZEROWE = 'NIE' SET @select = @select + ' AND ISNULL(TwI_Ilosc, 0) <> 0'

EXEC(@select)

DROP TABLE #tmpTwrGr
DROP TABLE #tmpTwrAtr
DROP TABLE #TmpDates
DROP TABLE #tmpSprzedaz
