

/*
* Raport Dostawy produktów złożonych - różnice w recepturze
* Wersja raportu: 37.0
* Wersja baz OPTIMY: 2025.3000
* Wersja aplikacji OPTIMA: 2025.3.0.0
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

declare @select1 varchar(max)
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

--Tworzenie tabeli z serią dokumentów
SELECT DDf_DDfID, CASE 
    WHEN DDf_Numeracja like '@rejestr%' THEN 5 
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 1) = '@rejestr' THEN 1
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 2) = '@rejestr' THEN 2
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 3) = '@rejestr' THEN 3
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 4) = '@rejestr' THEN 4
END [seria]  INTO #tmpSeria FROM CDN.DokDefinicje

DECLARE @bazaFirmowa varchar(max);
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Bazy varchar(max);
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

--Właściwe zapytanie
set @select1 = '
SELECT BAZ.Baz_Nazwa [Baza Firmowa], 
       TrN_NumerPelny [Dokument Dostawy Numer],
       twr1.Twr_Kod [Produkt Kod], 
       twr1.Twr_Nazwa [Produkt Nazwa],
       CASE twr1.TWR_SWW
           WHEN '' ''
           THEN ''(NIEPRZYPISANE)''
           ELSE ISNULL(twr1.TWR_SWW, ''(NIEPRZYPISANE)'')
       END [Produkt PKWiU], 
       ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'') [Produkt Dostawca],
       CASE twr1.Twr_NieAktywny
           WHEN 0
           THEN ''Tak''
           ELSE ''Nie''
       END [Produkt Aktywny], 
       twr1.Twr_JM [Produkt Jednostka Miary], 
       ISNULL(NULLIF(twr1.Twr_JMZ, ''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza], 
       CAST(twr1.Twr_Opis as VARCHAR(1024)) [Produkt Opis],
       CASE
           WHEN twr1.Twr_Typ = 0
                AND twr1.Twr_Produkt = 0
           THEN ''Usługa Prosta''
           WHEN twr1.Twr_Typ = 1
                AND twr1.Twr_Produkt = 0
           THEN ''Towar Prosty''
           WHEN twr1.Twr_Typ = 0
                AND twr1.Twr_Produkt = 1
           THEN ''Usługa Złożona''
           WHEN twr1.Twr_Typ = 1
                AND twr1.Twr_Produkt = 1
           THEN ''Towar Złożony''
           ELSE ''(NIEOKREŚLONY)''
       END [Produkt Typ], 
       TwC_Wartosc [Cena Domyślna], 
       ISNULL(pdProdukt.Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], 
       ISNULL(mrkProdukt.Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka], 
       ISNULL(kat.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria Szczegółowa], 
       ISNULL(kat.Kat_KodOgolny, ''(PUSTA)'') [Produkt Kategoria Ogólna], 
       ISNULL(CONVERT(VARCHAR(15), twr1.twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG], 
       Mag_Symbol [Magazyn Kod],       
       ISNULL(knt.KnT_Kod, ''(NIEPRZYPISANY)'') [Dostawca Pierwotny Kod],    
       ISNULL(knt.Knt_Nazwa1, ''(NIEPRZYPISANY)'') [Dostawca Pierwotny Nazwa],      
       ISNULL(knt3.KnT_Kod, ''(NIEPRZYPISANY)'') [Dostawca Kod],       
       ISNULL(knt3.Knt_Nazwa1, ''(NIEPRZYPISANY)'') [Dostawca Nazwa],      
       ISNULL(twr2.Twr_Kod, twr1.Twr_Kod) [Składnik Kod],      
       ISNULL(twr2.Twr_Nazwa, twr1.Twr_Nazwa) [Składnik Nazwa],        
       CASE ISNULL(twr2.TWR_SWW, twr1.TWR_SWW)
           WHEN '' ''
           THEN ''(NIEPRZYPISANE)''
           ELSE COALESCE(twr2.TWR_SWW, twr1.TWR_SWW, ''(NIEPRZYPISANE)'')
       END [Składnik PKWiU], 
       COALESCE(kntSkl.Knt_Kod, knt4.Knt_Kod, ''(NIEPRZYPISANE)'') [Składnik Dostawca],
       CASE ISNULL(twr2.Twr_NieAktywny, twr1.Twr_NieAktywny)
           WHEN 0
           THEN ''Tak''
           ELSE ''Nie''
       END [Składnik Aktywny], 
       PdS_Jm [Składnik Jednostka Miary], 
       COALESCE(NULLIF(twr2.Twr_JMZ, ''''), NULLIF(twr1.Twr_JMZ, ''''), ''(BRAK)'') [Składnik Jednostka Miary Pomocnicza], 
       ISNULL(CAST(twr2.Twr_Opis as VARCHAR(1024)), CAST(twr1.Twr_Opis as VARCHAR(1024))) [Składnik Opis], 
       ISNULL(CONVERT(VARCHAR(15), ISNULL(twr2.twr_wagakg, twr1.twr_wagakg)), ''(NIEPRZYPISANE)'') [Składnik Waga KG], 
       COALESCE(pdSkladnik.Prd_Kod, pdProdukt.Prd_Kod, ''(NIEPRZYPISANE)'') [Składnik Producent], 
       COALESCE(mrkSkladnik.Mrk_Nazwa, mrkProdukt.Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Składnik Marka], 
       COALESCE(katSkladnik.Kat_KodSzczegol, kat.Kat_KodSzczegol, ''(PUSTA)'') [Składnik Kategoria Szczegółowa], 
       COALESCE(katSkladnik.Kat_KodOgolny, kat.Kat_KodOgolny, ''(PUSTA)'') [Składnik Kategoria Ogólna], 
       pdr_Kod [Receptura Kod], 
       pdr_Nazwa [Receptura Nazwa],
       --MIARY
       ISNULL(PdS_Ilosc, 0) [Receptura Składnik Ilość], 
       NULL [Dostawa Składnik Ilość]
/*     
       ----------DATY POINT
       ,REPLACE(CONVERT(VARCHAR(10), TrN_DataDok, 111), ''/'', ''-'') [Data Wystawienia] 
  */    
       ----------DATY ANALIZY
       ,REPLACE(CONVERT(VARCHAR(10), TrN_DataDok, 111), ''/'', ''-'') [Data Wystawienia Dzień] 
       ,(DATEPART(DY, DATEDIFF(d, 0, TrN_DataDok) / 7 * 7 + 3) + 6) / 7 [Data Wystawienia Tydzień Roku] 
       ,MONTH(TrN_DataDok) [Data Wystawienia Miesiąc] 
       ,DATEPART(quarter, TrN_DataDok) [Data Wystawienia Kwartał]
       ,YEAR(TrN_DataDok) [Data Wystawienia Rok] 

       ----------KONTEKSTY
        ,CASE
           WHEN TrN_TypDokumentu = 312
           THEN 25034
           WHEN TrN_TypDokumentu = 303
           THEN 25032
           WHEN TrN_TypDokumentu = 317
           THEN 25045
           WHEN TrN_TypDokumentu = 307
           THEN 25024
           WHEN TrN_TypDokumentu = 313
           THEN 25079
       END [Dokument Dostawy Numer __PROCID__PZ__], TrN_TrNId [Dokument Dostawy Numer __ORGID__], '''+@bazaFirmowa+''' [Dokument Dostawy Numer __DATABASE__]
       ,25003 [Produkt Kod __PROCID__Towary__], twr1.Twr_twrId [Produkt Kod __ORGID__], '''+@bazaFirmowa+''' [Produkt Kod __DATABASE__] 
       ,25003 [Produkt Nazwa __PROCID__], twr1.Twr_twrId [Produkt Nazwa __ORGID__], '''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
       ,29056 [Magazyn Kod __PROCID__Magazyny__], Mag_MagId [Magazyn Kod __ORGID__], '''+@bazaFirmowa+''' [Magazyn Kod __DATABASE__] 
       ,20201 [Dostawca Pierwotny Kod __PROCID__Kontrahenci__], knt.Knt_KntId [Dostawca Pierwotny Kod __ORGID__], '''+@bazaFirmowa+''' [Dostawca Pierwotny kod __DATABASE__]
       ,20201 [Dostawca Pierwotny Nazwa __PROCID__], knt.Knt_KntId [Dostawca Pierwotny Nazwa __ORGID__], '''+@bazaFirmowa+''' [Dostawca Pierwotny Nazwa __DATABASE__]
       ,20201 [Dostawca Kod __PROCID__Kontrahenci__], knt3.Knt_KntId [Dostawca Kod __ORGID__], '''+@bazaFirmowa+''' [Dostawca Kod __DATABASE__] 
       ,20201 [Dostawca Nazwa __PROCID__], knt3.Knt_KntId [Dostawca Nazwa __ORGID__], '''+@bazaFirmowa+''' [Dostawca Nazwa __DATABASE__] 
       ,25003 [Składnik Kod __PROCID__Towary__], ISNULL(twr2.Twr_Kod, twr1.Twr_Kod) [Składnik Kod __ORGID__], '''+@bazaFirmowa+''' [Składnik Kod __DATABASE__]
       ,25003 [Składnik Nazwa __PROCID__], ISNULL(twr2.Twr_Nazwa, twr1.Twr_Nazwa) [Składnik Nazwa __ORGID__], '''+@bazaFirmowa+''' [Składnik Nazwa __DATABASE__]

FROM CDN.TraElem trEl
     JOIN CDN.TraNag ON TrE_TrNId = TrN_TrNID
     JOIN CDN.Towary twr1 ON TrE_TwrId = Twr_TwrId
     LEFT JOIN CDN.Producenci pdProdukt ON Prd_PrdId = Twr_PrdId
     LEFT JOIN CDN.Marki mrkProdukt ON Mrk_MrkId = Twr_MrkId
     LEFT JOIN CDN.TwrCeny ON Twr_TwrId = TwC_TwrID
                              AND Twr_TwCNumer = TwC_TwCNumer
     LEFT OUTER JOIN CDN.Kategorie kat ON Twr_KatId = kat.Kat_KatID
     JOIN CDN.Magazyny magProdukt ON TrE_MagId = Mag_MagId
     LEFT JOIN CDN.Kontrahenci knt ON TrN_PodId = KnT_KnTId
                                      AND TrN_PodmiotTyp = 1
     LEFT JOIN CDN.Kontrahenci knt3 ON knt.Knt_GlID = knt3.Knt_KntId
     LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
     JOIN CDN.ProdReceptury recp ON TrE_PdRId = PdR_PdRId
     LEFT OUTER JOIN CDN.ProdSkladniki ON twr1.Twr_TwrId = PdS_ProdId
                                          AND PdR_PdRId = PdS_PdRId
     LEFT OUTER JOIN CDN.Towary twr2 ON PdS_TwrId = twr2.Twr_TwrId
     LEFT JOIN CDN.Producenci pdSkladnik ON pdSkladnik.Prd_PrdId = twr2.Twr_PrdId
     LEFT JOIN CDN.Marki mrkSkladnik ON mrkSkladnik.Mrk_MrkId = twr2.Twr_MrkId
     LEFT OUTER JOIN CDN.Kategorie katSkladnik ON twr2.Twr_KatId = katSkladnik.Kat_KatID
     LEFT JOIN CDN.Kontrahenci kntSkl ON twr2.Twr_KntId = kntSkl.Knt_KntId
     LEFT JOIN #tmpTwrGr Poz ON twr1.Twr_TwGGIDNumer = Poz.gidNumer
     LEFT JOIN #tmpTwrAtr TwrAtr ON twr1.TwR_TwrId  = TwrAtr.TwA_TwrId
     LEFT JOIN #tmpSeria ON TrN_DDfId = DDf_DDfID
     LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'')

WHERE EXISTS
(
    SELECT TrE_TrNId
    FROM [CDN].[TraElem] wew
         JOIN [CDN].[ProdElem] prodEl ON prodEl.PdE_TrEId = TrE_TrEID
         JOIN CDN.ProdReceptury recp ON TrE_PdRId = PdR_PdRId
         LEFT JOIN CDN.ProdSkladniki skl ON Tre_TwrId = PdS_ProdId
                                            AND PdS_TwrId = PdE_TwrId
                                            AND PdR_PdRId = PdS_PdRId
    WHERE(ISNULL(PdE_Ilosc / ISNULL(NULLIF(TrE_Ilosc,0),1), 0) <> ISNULL(PdS_Ilosc / ISNULL(NULLIF(PdR_Ilosc,0),1), 0)
          OR PdE_Jm <> PdS_JM)
         AND wew.TrE_TrNId = trEl.TrE_TrNId
    UNION
    SELECT TrE_TrNId
    FROM [CDN].[TraElem] wew
         JOIN CDN.ProdReceptury recp ON TrE_PdRId = PdR_PdRId
         JOIN CDN.ProdSkladniki skl ON Tre_TwrId = PdS_ProdId
                                       AND PdR_PdRId = PdS_PdRId
         LEFT JOIN [CDN].[ProdElem] prodEl ON prodEl.PdE_TrEId = TrE_TrEID
                                              AND PdS_TwrId = PdE_TwrId
    WHERE(ISNULL(PdE_Ilosc / ISNULL(NULLIF(TrE_Ilosc,0),1), 0) <> ISNULL(PdS_Ilosc / ISNULL(NULLIF(PdR_Ilosc,0),1), 0)
          OR PdE_Jm <> PdS_JM)
         AND wew.TrE_TrNId = trEl.TrE_TrNId
) AND
TrN_DataDok >=''' + CONVERT(VARCHAR,@Data, 112) + '''
UNION ALL
'
SET @select2 = '
SELECT BAZ.Baz_Nazwa [Baza Firmowa], 
      TrN_NumerPelny [Dokument Dostawy Numer],
       twr1.Twr_Kod [Produkt Kod], 
       twr1.Twr_Nazwa [Produkt Nazwa],
       CASE twr1.TWR_SWW
           WHEN '' ''
           THEN ''(NIEPRZYPISANE)''
           ELSE ISNULL(twr1.TWR_SWW, ''(NIEPRZYPISANE)'')
       END [Produkt PKWiU], 
       ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'') [Produkt Dostawca],
       CASE twr1.Twr_NieAktywny
           WHEN 0
           THEN ''Tak''
           ELSE ''Nie''
       END [Produkt Aktywny], 
       twr1.Twr_JM [Produkt Jednostka Miary], 
       ISNULL(NULLIF(twr1.Twr_JMZ, ''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza], 
       CAST(twr1.Twr_Opis as VARCHAR(1024)) [Produkt Opis],
       CASE
           WHEN twr1.Twr_Typ = 0
                AND twr1.Twr_Produkt = 0
           THEN ''Usługa Prosta''
           WHEN twr1.Twr_Typ = 1
                AND twr1.Twr_Produkt = 0
           THEN ''Towar Prosty''
           WHEN twr1.Twr_Typ = 0
                AND twr1.Twr_Produkt = 1
           THEN ''Usługa Złożona''
           WHEN twr1.Twr_Typ = 1
                AND twr1.Twr_Produkt = 1
           THEN ''Towar Złożony''
           ELSE ''(NIEOKREŚLONY)''
       END [Produkt Typ], 
       TwC_Wartosc [Cena Domyślna], 
       ISNULL(pdProdukt.Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], 
       ISNULL(mrkProdukt.Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka], 
       ISNULL(kat.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria Szczegółowa], 
       ISNULL(kat.Kat_KodOgolny, ''(PUSTA)'') [Produkt Kategoria Ogólna], 
       ISNULL(CONVERT(VARCHAR(15), twr1.twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG], 
       Mag_Symbol [Magazyn Kod], 
       ISNULL(knt.KnT_Kod, ''(NIEPRZYPISANY)'') [Dostawca Pierwotny Kod],       
       ISNULL(knt.Knt_Nazwa1, ''(NIEPRZYPISANY)'') [Dostawca Pierwotny Nazwa],   
       ISNULL(knt3.KnT_Kod, ''(NIEPRZYPISANY)'') [Dostawca Kod],        
       ISNULL(knt3.Knt_Nazwa1, ''(NIEPRZYPISANY)'') [Dostawca Nazwa],      
       ISNULL(twr2.Twr_Kod, twr1.Twr_Kod) [Składnik Kod],     
       ISNULL(twr2.Twr_Nazwa, twr1.Twr_Nazwa) [Składnik Nazwa],        
       CASE ISNULL(twr2.TWR_SWW, twr1.TWR_SWW)
           WHEN '' ''
           THEN ''(NIEPRZYPISANE)''
           ELSE COALESCE(twr2.TWR_SWW, twr1.TWR_SWW, ''(NIEPRZYPISANE)'')
       END [Składnik PKWiU], 
       COALESCE(kntSkl.Knt_Kod, knt4.Knt_Kod, ''(NIEPRZYPISANE)'') [Składnik Dostawca],
       CASE ISNULL(twr2.Twr_NieAktywny, twr1.Twr_NieAktywny)
           WHEN 0
           THEN ''Tak''
           ELSE ''Nie''
       END [Składnik Aktywny], 
       PdE_Jm [Składnik Jednostka Miary], 
       COALESCE(NULLIF(twr2.Twr_JMZ, ''''), NULLIF(twr1.Twr_JMZ, ''''), ''(BRAK)'') [Składnik Jednostka Miary Pomocnicza], 
       ISNULL(CAST(twr2.Twr_Opis as VARCHAR(1024)), CAST(twr1.Twr_Opis as VARCHAR(1024))) [Składnik Opis], 
       ISNULL(CONVERT(VARCHAR(15), ISNULL(twr2.twr_wagakg, twr1.twr_wagakg)), ''(NIEPRZYPISANE)'') [Składnik Waga KG], 
       COALESCE(pdSkladnik.Prd_Kod, pdProdukt.Prd_Kod, ''(NIEPRZYPISANE)'') [Składnik Producent], 
       COALESCE(mrkSkladnik.Mrk_Nazwa, mrkProdukt.Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Składnik Marka], 
       COALESCE(katSkladnik.Kat_KodSzczegol, kat.Kat_KodSzczegol, ''(PUSTA)'') [Składnik Kategoria Szczegółowa], 
       COALESCE(katSkladnik.Kat_KodOgolny, kat.Kat_KodOgolny, ''(PUSTA)'') [Składnik Kategoria Ogólna], 
       pdr_Kod [Receptura Kod], 
       pdr_Nazwa [Receptura Nazwa],
       --MIARY
       NULL [Receptrura Składnik Ilość], 
       ISNULL(PdE_Ilosc /ISNULL(NULLIF( TrE_Ilosc,0),1), 0) [Dostawa Składnik Ilość]
    /*  
      ----------DATY POINT
       ,REPLACE(CONVERT(VARCHAR(10), TrN_DataDok, 111), ''/'', ''-'') [Data Wystawienia] 
      */
       ----------DATY ANALIZY
       ,REPLACE(CONVERT(VARCHAR(10), TrN_DataDok, 111), ''/'', ''-'') [Data Wystawienia Dzień] 
       ,(DATEPART(DY, DATEDIFF(d, 0, TrN_DataDok) / 7 * 7 + 3) + 6) / 7 [Data Wystawienia Tydzień Roku]
       ,MONTH(TrN_DataDok) [Data Wystawienia Miesiąc] 
       ,DATEPART(quarter, TrN_DataDok) [Data Wystawienia Kwartał]
       ,YEAR(TrN_DataDok) [Data Wystawienia Rok] 

       ----------KONTEKSTY
        ,CASE
           WHEN TrN_TypDokumentu = 312
           THEN 25034
           WHEN TrN_TypDokumentu = 303
           THEN 25032
           WHEN TrN_TypDokumentu = 317
           THEN 25045
           WHEN TrN_TypDokumentu = 307
           THEN 25024
           WHEN TrN_TypDokumentu = 313
           THEN 25079
       END [Dokument Dostawy Numer __PROCID__PZ__], TrN_TrNId [Dokument Dostawy Numer __ORGID__], '''+@bazaFirmowa+''' [Dokument Dostawy Numer __DATABASE__]
       ,25003 [Produkt Kod __PROCID__Towary__], twr1.Twr_twrId [Produkt Kod __ORGID__], '''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
       ,25003 [Produkt Nazwa __PROCID__], twr1.Twr_twrId [Produkt Nazwa __ORGID__], '''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__] 
       ,29056 [Magazyn Kod __PROCID__Magazyny__], Mag_MagId [Magazyn Kod __ORGID__], '''+@bazaFirmowa+''' [Magazyn Kod __DATABASE__]
       ,20201 [Dostawca Pierwotny Kod __PROCID__Kontrahenci__], knt.Knt_KntId [Dostawca Pierwotny Kod __ORGID__], '''+@bazaFirmowa+''' [Dostawca Pierwotny kod __DATABASE__] 
       ,20201 [Dostawca Pierwotny Nazwa __PROCID__], knt.Knt_KntId [Dostawca Pierwotny Nazwa __ORGID__], '''+@bazaFirmowa+''' [Dostawca Pierwotny Nazwa __DATABASE__] 
       ,20201 [Dostawca Kod __PROCID__Kontrahenci__], knt3.Knt_KntId [Dostawca Kod __ORGID__], '''+@bazaFirmowa+''' [Dostawca Kod __DATABASE__]
       ,20201 [Dostawca Nazwa __PROCID__], knt3.Knt_KntId [Dostawca Nazwa __ORGID__], '''+@bazaFirmowa+''' [Dostawca Nazwa __DATABASE__] 
       ,25003 [Składnik Kod __PROCID__Towary__], ISNULL(twr2.Twr_Kod, twr1.Twr_Kod) [Składnik Kod __ORGID__], '''+@bazaFirmowa+''' [Składnik Kod __DATABASE__] 
       ,25003 [Składnik Nazwa __PROCID__], ISNULL(twr2.Twr_Nazwa, twr1.Twr_Nazwa) [Składnik Nazwa __ORGID__], '''+@bazaFirmowa+''' [Składnik Nazwa __DATABASE__]

FROM CDN.TraElem trEl
     JOIN CDN.TraNag ON TrE_TrNId = TrN_TrNID
     JOIN CDN.Towary twr1 ON TrE_TwrId = Twr_TwrId
     LEFT JOIN CDN.Producenci pdProdukt ON Prd_PrdId = Twr_PrdId
     LEFT JOIN CDN.Marki mrkProdukt ON Mrk_MrkId = Twr_MrkId
     LEFT JOIN CDN.TwrCeny ON Twr_TwrId = TwC_TwrID
                              AND Twr_TwCNumer = TwC_TwCNumer
     LEFT OUTER JOIN CDN.Kategorie kat ON Twr_KatId = kat.Kat_KatID
     JOIN CDN.Magazyny magProdukt ON TrE_MagId = Mag_MagId
     LEFT JOIN CDN.Kontrahenci knt ON TrN_PodId = KnT_KnTId
                                      AND TrN_PodmiotTyp = 1
     LEFT JOIN CDN.Kontrahenci knt3 ON knt.Knt_GlID = knt3.Knt_KntId
     LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
     LEFT JOIN [CDN].[ProdElem] prodEl ON prodEl.PdE_TrEId = TrE_TrEID
     JOIN CDN.ProdReceptury recp ON TrE_PdRId = PdR_PdRId
     LEFT OUTER JOIN CDN.Towary twr2 ON [PdE_TwrId] = twr2.Twr_TwrId
     LEFT JOIN CDN.Producenci pdSkladnik ON pdSkladnik.Prd_PrdId = twr2.Twr_PrdId
     LEFT JOIN CDN.Marki mrkSkladnik ON mrkSkladnik.Mrk_MrkId = twr2.Twr_MrkId
     LEFT OUTER JOIN CDN.Kategorie katSkladnik ON twr2.Twr_KatId = katSkladnik.Kat_KatID
     LEFT JOIN CDN.Kontrahenci kntSkl ON twr2.Twr_KntId = kntSkl.Knt_KntId
     LEFT JOIN #tmpTwrGr Poz ON twr1.Twr_TwGGIDNumer = Poz.gidNumer
     LEFT JOIN #tmpTwrAtr TwrAtr ON twr1.TwR_TwrId  = TwrAtr.TwA_TwrId
     LEFT JOIN #tmpSeria ON TrN_DDfId = DDf_DDfID
     LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'')

WHERE EXISTS
(
    SELECT TrE_TrNId
    FROM [CDN].[TraElem] wew
         JOIN [CDN].[ProdElem] prodEl ON prodEl.PdE_TrEId = TrE_TrEID
         JOIN CDN.ProdReceptury recp ON TrE_PdRId = PdR_PdRId
         LEFT JOIN CDN.ProdSkladniki skl ON Tre_TwrId = PdS_ProdId
                                            AND PdS_TwrId = PdE_TwrId
                                            AND PdR_PdRId = PdS_PdRId
    WHERE(ISNULL(PdE_Ilosc / ISNULL(NULLIF(TrE_Ilosc,0),1), 0) <> ISNULL(PdS_Ilosc / ISNULL(NULLIF(PdR_Ilosc,0),1), 0)
          OR PdE_Jm <> PdS_JM)
         AND wew.TrE_TrNId = trEl.TrE_TrNId
    UNION
    SELECT TrE_TrNId
    FROM [CDN].[TraElem] wew
         JOIN CDN.ProdReceptury recp ON TrE_PdRId = PdR_PdRId
         JOIN CDN.ProdSkladniki skl ON Tre_TwrId = PdS_ProdId
                                       AND PdR_PdRId = PdS_PdRId
         LEFT JOIN [CDN].[ProdElem] prodEl ON prodEl.PdE_TrEId = TrE_TrEID
                                              AND PdS_TwrId = PdE_TwrId
    WHERE(ISNULL(PdE_Ilosc / ISNULL(NULLIF(TrE_Ilosc,0),1), 0) <> ISNULL(PdS_Ilosc / ISNULL(NULLIF(PdR_Ilosc,0),1), 0)
          OR PdE_Jm <> PdS_JM)
         AND wew.TrE_TrNId = trEl.TrE_TrNId
) AND
TrN_DataDok >=''' + CONVERT(VARCHAR,@Data, 112) + '''
'
print @select1 
print @select2
exec (@select1 + @select2)

DROP TABLE #tmpTwrGr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpSeria






