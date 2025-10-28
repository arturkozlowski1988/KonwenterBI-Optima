/*
* Raport Produktów z dostaw
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
    
    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

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

SET @atrybutyZas = ''
SET @atrybutyZas2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
       IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
       IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
       SET @sqlA = N'ALTER TABLE #tmpZasAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
       SET @sqlA = N'UPDATE #tmpZasAtr
             SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = 
             CASE
                WHEN ATR.TsC_Cecha1_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha1_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha1_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha1_Wartosc END END
                WHEN ATR.TsC_Cecha2_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha2_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha2_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha2_Wartosc END END
                WHEN ATR.TsC_Cecha3_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha3_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha3_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha3_Wartosc END END 
                WHEN ATR.TsC_Cecha4_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha4_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha4_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha4_Wartosc END END 
                WHEN ATR.TsC_Cecha5_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha5_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha5_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha5_Wartosc END END
                WHEN ATR.TsC_Cecha6_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha6_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha6_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha6_Wartosc END END
                WHEN ATR.TsC_Cecha7_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha7_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha7_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha7_Wartosc END END
                WHEN ATR.TsC_Cecha8_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha8_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha8_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha8_Wartosc END END
                WHEN ATR.TsC_Cecha9_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha9_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha9_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha9_Wartosc END END
                WHEN ATR.TsC_Cecha10_DeAId = ' + CAST(@atrybut_id AS nvarchar) + ' THEN  case WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TsC_Cecha10_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
                    ELSE  CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TsC_Cecha10_Wartosc,'','',''.'') ELSE ATR.TsC_Cecha10_Wartosc END END
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
    
    SET @atrybutyZas = @atrybutyZas + N', ISNULL(ZasAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Zasoby Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'

       FETCH NEXT FROM atrybut_cursor
       INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Tworzenie tabeli z serią dokumentów
SELECT DDf_DDfID, CASE 
    WHEN DDf_Numeracja like '@rejestr%' THEN 5
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 1) = '@rejestr' THEN 1
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 2) = '@rejestr' THEN 2
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 3) = '@rejestr' THEN 3
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 4) = '@rejestr' THEN 4
END [seria]  INTO #tmpSeria FROM CDN.DokDefinicje

DECLARE @bazaFirmowa varchar(max);
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)

DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Bazy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

--Właściwe zapytanie
set @select = 
'SELECT BAZ.Baz_Nazwa [Baza Firmowa],
    TrN_NumerPelny [Dokument Dostawy Numer], 
    CASE when isnull(ser.seria,0) = 5 then 
        substring(TrN_NumerPelny,0,CHARINDEX(''/'',TrN_NumerPelny,0))
    ELSE 
        ISNULL(PARSENAME(REPLACE(substring(TrN_NumerPelny,CHARINDEX(''/'',TrN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
    END [Dokument Seria],
    Twr_Kod [Produkt Kod], 
    Twr_Nazwa [Produkt Nazwa],
    CASE TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
    CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny],     
    Twr_JM [Produkt Jednostka Miary], ISNULL(NULLIF(Twr_JMZ,''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza], CAST(Twr_Opis as VARCHAR(1024)) [Produkt Opis],
    CASE
        WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa Prosta''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar Prosty''
        WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa Złożona''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar Złożony''
        ELSE ''(NIEOKREŚLONY)''
    END [Produkt Typ], TwC_Wartosc [Cena Domyślna], ISNULL(Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
    ISNULL(kat.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria Szczegółowa], ISNULL(kat.Kat_KodOgolny, ''(PUSTA)'') [Produkt Kategoria Ogólna], 
    Isnull(convert(varchar(15),twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG],
    Mag_Symbol [Magazyn Kod],
    ISNULL(knt.KnT_Kod, ''(NIEPRZYPISANY)'') [Dostawca Pierwotny Kod],  
    ISNULL(knt.Knt_Nazwa1, ''(NIEPRZYPISANY)'') [Dostawca Pierwotny Nazwa], 
    ISNULL(knt3.KnT_Kod, ''(NIEPRZYPISANY)'') [Dostawca Kod],   
    ISNULL(knt3.Knt_Nazwa1, ''(NIEPRZYPISANY)'') [Dostawca Nazwa], 
    TwZ_Ilosc [Ilość], 
    CASE WHEN Twr_JMPrzelicznikL <> 0 THEN CONVERT(DECIMAL(20,4),TwZ_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL) ELSE 0 END [Ilość Jednostka Pomocnicza], 
    TrE_Ilosc [Ilość w Dostawie],
    Twr_IloscMin [Ilość Minimalna], Twr_IloscMax [Ilość Maksymalna],
    TwZ_Wartosc [Wartość Netto], TwZ_Wartosc * (1 + Twr_Stawka/100) [Wartość Brutto], TwZ_Cena [Cena Zakupu] 
    ,DATEDIFF(day, TwZ_Data, GETDATE()) AS [Liczba dni zalegania]

    ,CASE WHEN (MONTH(TwZ_Data) = MONTH(GETDATE())) AND (YEAR(TwZ_Data) = YEAR(GETDATE())) THEN ''TAK'' ELSE ''NIE'' END [Czas Aktualny Miesiąc],
    CASE 
        WHEN (MONTH(TwZ_Data) = MONTH(GETDATE())-1) AND (YEAR(TwZ_Data) = YEAR(GETDATE())) THEN ''TAK'' 
        WHEN ((MONTH(TwZ_Data) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(TwZ_Data) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Aktualny Miesiąc Poprzedni]
/*
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), TwZ_Data, 111), ''/'', ''-'') [Data Dostawy]
*/
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), TwZ_Data, 111), ''/'', ''-'') [Data Dostawy Dzień], (datepart(DY, datediff(d, 0, TwZ_Data) / 7 * 7 + 3)+6) / 7 [Data Dostawy Tydzień Roku] 
    ,MONTH(TwZ_Data) [Data Dostawy Miesiąc],    DATEPART(quarter, TwZ_Data) [Data Dostawy Kwartał], YEAR(TwZ_Data) [Data Dostawy Rok]   

    ----------KONTEKSTY
                        ,CASE                               
        WHEN TrN_TypDokumentu = 312 THEN 25034
        WHEN TrN_TypDokumentu = 303 THEN 25032
        WHEN TrN_TypDokumentu = 317 THEN 25045
        WHEN TrN_TypDokumentu = 307 THEN 25024
        WHEN TrN_TypDokumentu = 313 THEN 25079
    END [Dokument Dostawy Numer __PROCID__PZ__], TrN_TrNId [Dokument Dostawy Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Dostawy Numer __DATABASE__]
    ,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
    ,29056 [Magazyn Kod __PROCID__Magazyny__], Mag_MagId [Magazyn Kod __ORGID__],'''+@bazaFirmowa+''' [Magazyn Kod __DATABASE__]
    ,20201 [Dostawca Pierwotny Kod __PROCID__Kontrahenci__], knt.Knt_KntId [Dostawca Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Dostawca Pierwotny kod __DATABASE__]
    ,20201 [Dostawca Pierwotny Nazwa __PROCID__], knt.Knt_KntId [Dostawca Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Dostawca Pierwotny Nazwa __DATABASE__]
    ,20201 [Dostawca Kod __PROCID__Kontrahenci__], knt3.Knt_KntId [Dostawca Kod __ORGID__],'''+@bazaFirmowa+''' [Dostawca Kod __DATABASE__]
    ,20201 [Dostawca Nazwa __PROCID__], knt3.Knt_KntId [Dostawca Nazwa __ORGID__],'''+@bazaFirmowa+''' [Dostawca Nazwa __DATABASE__]

    ' + @kolumny + @atrybutyTwr + @atrybutyZas + '
 FROM CDN.TwrZasoby
    JOIN CDN.Towary ON TwZ_TwrId = Twr_TwrId
     LEFT JOIN CDN.Producenci ON Prd_PrdId = Twr_PrdId
     LEFT JOIN CDN.Marki ON Mrk_MrkId = Twr_MrkId
    LEFT JOIN CDN.TwrCeny ON Twr_TwrId = TwC_TwrID AND Twr_TwCNumer = TwC_TwCNumer
    LEFT OUTER JOIN CDN.Kategorie kat ON Twr_KatId=kat.Kat_KatID
    JOIN CDN.Magazyny ON TwZ_MagId = Mag_MagId
    JOIN CDN.TraSElem ON TwZ_TrSIdDost = TrS_TrSID and TwZ_MagId = TrS_MagId
    JOIN CDN.TraElem ON TrS_TrEId = TrE_TrEID
    JOIN CDN.TraNag ON TrE_TrNId = TrN_TrNID
LEFT JOIN #tmpSeria ser ON TrN_DDfId = DDf_DDfID
    LEFT JOIN CDN.Kontrahenci knt ON TrN_PodId = KnT_KnTId AND TrN_PodmiotTyp = 1
    LEFT JOIN CDN.Kontrahenci knt3 ON knt.Knt_GlID=knt3.Knt_KntId
    LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
    LEFT JOIN #tmpTwrAtr TwrAtr ON TwR_TwrId  = TwrAtr.TwA_TwrId
    LEFT JOIN #tmpZasAtr ZasAtr ON Trs_TrSId = ZasAtr.TsC_TrSID
    LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0 ' 
exec (@select)

DROP TABLE #tmpTwrGr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpSeria
DROP TABLE #tmpZasAtr







