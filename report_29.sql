/*
* Raport Stanów Magazynowych na Dzień z uwględnieniem receptury
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
    SET @sql = N'ALTER TABLE #tmpTwrGr ADD Poziom' + CAST(@poziom AS nvarchar) + N' nvarchar(40), ONr' + CAST(@poziom AS nvarchar) + N' nvarchar(40)'
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
declare @select1 varchar(max)
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
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TwA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
          ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TwA_WartoscTxt,'','',''.'') ELSE ATR.TwA_WartoscTxt END 
        END 
        FROM CDN.TwrAtrybuty ATR 
        JOIN #tmpTwrAtr TM ON ATR.TwA_TwrId = TM.TwA_TwrId 
        WHERE ATR.TwA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Liczenie ostatniej daty w bazie
SELECT TwI_TwrId [TwI_TId], ISNULL(TwI_MagId,0) [TwI_MId], MAX(TwI_Data) [TwI_OstatniaData] INTO #TwrIlosci
FROM CDN.TwrIlosci
WHERE TwI_Data <= @DATA
GROUP BY TwI_TwrId, TwI_MagId

--Liczenie korekty braków
SELECT TwI_TwrId [TwI_TId], SUM((CASE WHEN TwI_MagId IS NULL THEN 1 ELSE -1 END)*TwI_Braki) [Braki] INTO #TwrBraki
FROM CDN.TwrIlosci
JOIN #TwrIlosci TI ON TI.TwI_TId = TwI_TwrId AND TI.TwI_MId=ISNULL(TwI_MagId,0) AND TI.TwI_OstatniaData = TwI_Data
GROUP BY TwI_TwrId

--Tworzenie tabeli tymczasowej z warością sprzedaży
SELECT TrE_MagId, TrE_TwrId, SUM(TrE_WartoscNetto) SprzedazWartosc, SUM(TrE_Ilosc) SprzedazIlosc
INTO #tmpSprzedaz 
FROM CDN.TraElem
WHERE TrE_Aktywny <> 0 
    AND TrE_TypDokumentu IN (-1, 302, 305) 
    AND TrE_DataOpe = @Data
GROUP BY TrE_MagId, TrE_TwrId   

DECLARE @bazaFirmowa varchar(max);
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Bazy varchar(max);
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

--Właściwe zapytanie
set @select =
'SELECT BAZ.Baz_Nazwa [Baza Firmowa], 

twr1.Twr_Kod [Produkt Kod],     
twr1.Twr_Nazwa [Produkt Nazwa], 
CASE twr1.TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(twr1.TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
CASE twr1.Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny],    
twr1.Twr_JM [Produkt Jednostka Miary], 
ISNULL(NULLIF(twr1.Twr_JMZ,''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza], 
CAST(twr1.Twr_Opis as VARCHAR(1024)) [Produkt Opis],
Isnull(convert(varchar(15),twr1.twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG],
magTwr.Mag_Symbol [Produkt Magazyn Kod],
CASE
    WHEN twr1.Twr_Typ = 0 AND twr1.Twr_Produkt = 0 THEN ''Usługa Prosta''
    WHEN twr1.Twr_Typ = 1 AND twr1.Twr_Produkt = 0 THEN ''Towar Prosty''
    WHEN twr1.Twr_Typ = 0 AND twr1.Twr_Produkt = 1 THEN ''Usługa Złożona''
    WHEN twr1.Twr_Typ = 1 AND twr1.Twr_Produkt = 1 THEN ''Towar Złożony''
    ELSE ''(NIEOKREŚLONY)''
END [Produkt Typ],  
ISNULL(pdProdukt.Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], 
ISNULL(mrkProdukt.Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
ISNULL(kat.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria Szczegółowa],
ISNULL(kat.Kat_KodOgolny, ''(PUSTA)'') [Produkt Kategoria Ogólna], 
ISNULL(twr2.Twr_Kod,twr1.Twr_Kod ) [Składnik Kod],
ISNULL(twr2.Twr_Nazwa,twr1.Twr_Nazwa) [Składnik Nazwa],
CASE ISNULL(twr2.TWR_SWW, twr1.TWR_SWW) WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE COALESCE(twr2.TWR_SWW,twr1.TWR_SWW,''(NIEPRZYPISANE)'') END [Składnik PKWiU],
COALESCE(kntSkl.Knt_Kod,knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Składnik Dostawca],
CASE ISNULL(twr2.Twr_NieAktywny, twr1.Twr_NieAktywny) WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Składnik Aktywny],
PdS_Jm [Składnik Jednostka Miary],  
COALESCE(NULLIF(twr2.Twr_JMZ,''),NULLIF(twr1.Twr_JMZ,''), ''(BRAK)'') [Składnik Jednostka Miary Pomocnicza], 
ISNULL(CAST(twr2.Twr_Opis as VARCHAR(1024)), CAST(twr1.Twr_Opis as VARCHAR(1024))) [Składnik Opis],
ISNULL(convert(varchar(15), ISNULL(twr2.twr_wagakg, twr1.twr_wagakg)), ''(NIEPRZYPISANE)'') [Składnik Waga KG],
COALESCE(pdSkladnik.Prd_Kod,pdProdukt.Prd_Kod, ''(NIEPRZYPISANE)'') [Składnik Producent], 
COALESCE(mrkSkladnik.Mrk_Nazwa,mrkProdukt.Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Składnik Marka],
COALESCE(katSkladnik.Kat_KodSzczegol,kat.Kat_KodSzczegol, ''(PUSTA)'') [Składnik Kategoria Szczegółowa],
COALESCE(katSkladnik.Kat_KodOgolny,kat.Kat_KodOgolny, ''(PUSTA)'') [Składnik Kategoria Ogólna], 
--MIARY
ISNULL(PdS_Ilosc, 0)  [Receptura Składnik Ilość],
COALESCE(twI1.TwI_Ilosc*PdS_Ilosc, twI1.TwI_Ilosc, 0) [Składnik Ilość], 
ISNULL(twI1.TwI_Ilosc, 0) [Produkt Ilość], 
COALESCE(twI1.TwI_Rezerwacje*PdS_Ilosc, twI1.TwI_Rezerwacje, 0) [Składnik Rezerwacje], 
COALESCE(twI1.TwI_Braki*PdS_Ilosc, twI1.TwI_Braki, 0) [Składnik Braki],
COALESCE(twI1.TwI_Zamowienia*PdS_Ilosc,twI1.TwI_Zamowienia, 0) [Składnik Zamówienia]

----------KONTEKSTY
,25003 [Produkt Kod __PROCID__Towary__], twr1.Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
,25003 [Produkt Nazwa __PROCID__], twr1.Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
,29056 [Produkt Magazyn Kod __PROCID__Magazyny__], magTwr.Mag_MagId [Produkt Magazyn Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Magazyn Kod __DATABASE__]
,25003 [Składnik Kod __PROCID__Towary__], ISNULL(twr2.Twr_Kod,twr1.Twr_Kod ) [Składnik Kod __ORGID__],'''+@bazaFirmowa+''' [Składnik Kod __DATABASE__]
,25003 [Składnik Nazwa __PROCID__], ISNULL(twr2.Twr_Nazwa,twr1.Twr_Nazwa) [Składnik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Składnik Nazwa __DATABASE__]

    ' + @kolumny + @atrybutyTwr + '
FROM CDN.TwrIlosci twI1
    LEFT OUTER JOIN CDN.Magazyny magTwr ON Mag_MagId = TwI_MagId
    JOIN CDN.Towary twr1 ON TwI_TwrId = Twr_TwrId
     LEFT JOIN CDN.Producenci pdProdukt ON pdProdukt.Prd_PrdId = twr1.Twr_PrdId
     LEFT JOIN CDN.Marki mrkProdukt ON mrkProdukt.Mrk_MrkId = twr1.Twr_MrkId
    LEFT OUTER JOIN CDN.Kategorie kat ON Twr_KatId=kat.Kat_KatID
    JOIN #TwrIlosci prd ON prd.TwI_TId = twI1.TwI_TwrId AND prd.TwI_OstatniaData = twI1.TwI_Data AND prd.TwI_MId =  twI1.TwI_MagId
    LEFT JOIN CDN.ProdReceptury ON PdR_TwrId = twr1.Twr_TwrId AND PdR_Domyslna = 1
    LEFT OUTER JOIN CDN.ProdSkladniki ON twr1.Twr_TwrId = PdS_ProdId AND PdR_PdRId = PdS_PdRId
    LEFT JOIN CDN.Towary twr2 ON PdS_TwrId=twr2.Twr_TwrId --AND twr2.Twr_Typ <> 0
    LEFT JOIN CDN.Producenci pdSkladnik ON pdSkladnik.Prd_PrdId = twr2.Twr_PrdId
    LEFT JOIN CDN.Marki mrkSkladnik ON mrkSkladnik.Mrk_MrkId = twr2.Twr_MrkId
    LEFT OUTER JOIN CDN.Kategorie katSkladnik ON twr2.Twr_KatId=katSkladnik.Kat_KatID
    LEFT JOIN CDN.Kontrahenci knt4 ON twr1.Twr_KntId = knt4.Knt_KntId 
    LEFT JOIN CDN.Kontrahenci kntSkl ON twr2.Twr_KntId = kntSkl.Knt_KntId 
    LEFT JOIN #tmpTwrGr Poz ON  Poz.gidNumer = ISNULL(twr2.Twr_TwGGIDNumer, twr1.Twr_TwGGIDNumer)
    LEFT JOIN #tmpTwrAtr TwrAtr ON  TwrAtr.TwA_TwrId = ISNULL(twr2.Twr_TwGGIDNumer, twr1.Twr_TwGGIDNumer)
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0

    '

IF @ZEROWE = 'NIE' SET @select = @select + ' WHERE ISNULL(twI1.TwI_Ilosc, 0) <> 0
AND 
ISNULL(twr2.Twr_Typ,1) <> 0 '

SET @select1 = '

UNION ALL

    SELECT BAZ.Baz_Nazwa [Baza Firmowa], 
    twr1.Twr_Kod [Produkt Kod],     
    twr1.Twr_Nazwa [Produkt Nazwa], 
    CASE twr1.TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(twr1.TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
    CASE twr1.Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny],    
    twr1.Twr_JM [Produkt Jednostka Miary], 
    ISNULL(NULLIF(twr1.Twr_JMZ,''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza], 
    CAST(twr1.Twr_Opis as VARCHAR(1024)) [Produkt Opis],
    Isnull(convert(varchar(15),twr1.twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG],
    ''(Korekta Braków)'' [Produkt Magazyn Kod],
    CASE
    WHEN twr1.Twr_Typ = 0 AND twr1.Twr_Produkt = 0 THEN ''Usługa Prosta''
    WHEN twr1.Twr_Typ = 1 AND twr1.Twr_Produkt = 0 THEN ''Towar Prosty''
    WHEN twr1.Twr_Typ = 0 AND twr1.Twr_Produkt = 1 THEN ''Usługa Złożona''
    WHEN twr1.Twr_Typ = 1 AND twr1.Twr_Produkt = 1 THEN ''Towar Złożony''
    ELSE ''(NIEOKREŚLONY)''
    END [Produkt Typ],  
    ISNULL(pdProdukt.Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], 
    ISNULL(mrkProdukt.Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
    ISNULL(kat.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria Szczegółowa],
    ISNULL(kat.Kat_KodOgolny, ''(PUSTA)'') [Produkt Kategoria Ogólna], 
    ISNULL(twr2.Twr_Kod,twr1.Twr_Kod ) [Składnik Kod],
    ISNULL(twr2.Twr_Nazwa,twr1.Twr_Nazwa) [Składnik Nazwa],
    CASE ISNULL(twr2.TWR_SWW, twr1.TWR_SWW) WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE COALESCE(twr2.TWR_SWW,twr1.TWR_SWW,''(NIEPRZYPISANE)'') END [Składnik PKWiU],
    COALESCE(kntSkl.Knt_Kod,knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Składnik Dostawca],
    CASE ISNULL(twr2.Twr_NieAktywny, twr1.Twr_NieAktywny) WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Składnik Aktywny],
    PdS_Jm [Składnik Jednostka Miary],  
    COALESCE(NULLIF(twr2.Twr_JMZ,''),NULLIF(twr1.Twr_JMZ,''), ''(BRAK)'') [Składnik Jednostka Miary Pomocnicza], 
    ISNULL(CAST(twr2.Twr_Opis as VARCHAR(1024)), CAST(twr1.Twr_Opis as VARCHAR(1024))) [Składnik Opis],
    ISNULL(convert(varchar(15), ISNULL(twr2.twr_wagakg, twr1.twr_wagakg)), ''(NIEPRZYPISANE)'') [Składnik Waga KG],
    COALESCE(pdSkladnik.Prd_Kod,pdProdukt.Prd_Kod, ''(NIEPRZYPISANE)'') [Składnik Producent], 
    COALESCE(mrkSkladnik.Mrk_Nazwa,mrkProdukt.Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Składnik Marka],
    COALESCE(katSkladnik.Kat_KodSzczegol,kat.Kat_KodSzczegol, ''(PUSTA)'') [Składnik Kategoria Szczegółowa],
    COALESCE(katSkladnik.Kat_KodOgolny,kat.Kat_KodOgolny, ''(PUSTA)'') [Składnik Kategoria Ogólna], 
    --MIARY
    ISNULL(PdS_Ilosc, 0)  [Receptrura Składnik Ilość],
    NULL [Składnik Ilość], 
    NULL [Produkt Ilość], 
    NULL [Składnik Rezerwacje], 
    COALESCE(brakiSkl.Braki*PdS_Ilosc, brakiPrd.Braki, 0) [Składnik Braki],
    NULL [Składnik Zamówienia]

    ----------KONTEKSTY
    ,25003 [Produkt Kod __PROCID__Towary__], twr1.Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], twr1.Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
    ,29056 [Produkt Magazyn Kod __PROCID__Magazyny__], 1 [Produkt Magazyn Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Magazyn Kod __DATABASE__]
    ,25003 [Składnik Kod __PROCID__Towary__], ISNULL(twr2.Twr_Kod,twr1.Twr_Kod ) [Składnik Kod __ORGID__],'''+@bazaFirmowa+''' [Składnik Kod __DATABASE__]
    ,25003 [Składnik Nazwa __PROCID__], ISNULL(twr2.Twr_Nazwa,twr1.Twr_Nazwa) [Składnik Nazwa __ORGID__],'''+@bazaFirmowa+'''[Składnik Nazwa __DATABASE__]

    ' + @kolumny + @atrybutyTwr + '
FROM 
CDN.Towary twr1 
     LEFT JOIN CDN.Producenci pdProdukt ON pdProdukt.Prd_PrdId = twr1.Twr_PrdId
     LEFT JOIN CDN.Marki mrkProdukt ON mrkProdukt.Mrk_MrkId = twr1.Twr_MrkId
    LEFT OUTER JOIN CDN.Kategorie kat ON Twr_KatId=kat.Kat_KatID
    JOIN #TwrBraki brakiPrd ON TwI_TId = Twr_TwrId AND Braki <> 0
    LEFT JOIN CDN.ProdReceptury ON PdR_TwrId = twr1.Twr_TwrId AND PdR_Domyslna = 1
    LEFT OUTER JOIN CDN.ProdSkladniki ON twr1.Twr_TwrId = PdS_ProdId AND PdR_PdRId = PdS_PdRId
    LEFT OUTER JOIN CDN.Towary twr2 ON PdS_TwrId=twr2.Twr_TwrId
    LEFT JOIN #TwrBraki brakiSkl ON brakiSkl.TwI_TId = twr2.Twr_TwrId AND brakiSkl.Braki <> 0
    LEFT JOIN CDN.Producenci pdSkladnik ON pdSkladnik.Prd_PrdId = twr2.Twr_PrdId
    LEFT JOIN CDN.Marki mrkSkladnik ON mrkSkladnik.Mrk_MrkId = twr2.Twr_MrkId
    LEFT OUTER JOIN CDN.Kategorie katSkladnik ON twr2.Twr_KatId=katSkladnik.Kat_KatID
    LEFT JOIN CDN.Kontrahenci knt4 ON twr1.Twr_KntId = knt4.Knt_KntId 
    LEFT JOIN CDN.Kontrahenci kntSkl ON twr2.Twr_KntId = kntSkl.Knt_KntId   
    LEFT JOIN #tmpTwrGr Poz ON  Poz.gidNumer = ISNULL(twr2.Twr_TwGGIDNumer, twr1.Twr_TwGGIDNumer)
    LEFT JOIN #tmpTwrAtr TwrAtr ON  TwrAtr.TwA_TwrId = ISNULL(twr2.Twr_TwGGIDNumer, twr1.Twr_TwGGIDNumer)   
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0

    '

--print(@select)    
--print(@select1)
EXEC(@select + @select1)

DROP TABLE #TwrIlosci
DROP TABLE #TwrBraki
DROP TABLE #tmpTwrGr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpSprzedaz





