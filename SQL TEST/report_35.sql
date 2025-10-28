/*
* Raport Kurierów
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
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

SELECT DISTINCT KnA_PodmiotId, KnA_PodmiotTyp INTO #tmpKonAtr 
FROM CDN.KntAtrybuty

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
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']' 
    SET @atrybuty = @atrybuty + N', ISNULL(OdbAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Odbiorca Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
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
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TwA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TwA_WartoscTxt,'','',''.'') ELSE ATR.TwA_WartoscTxt END 
        END  
        FROM CDN.TwrAtrybuty ATR 
        JOIN #tmpTwrAtr TM ON ATR.TwA_TwrId = TM.TwA_TwrId 
        WHERE ATR.TwA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    SET @atrybutyTwr2 = @atrybutyTwr2 + N', ''(NIEPRZYPISANE)'' [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
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
SELECT DDf_DDfID, 
  CASE 
     WHEN DDf_Numeracja like '@rejestr%' THEN 5
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 1) = '@rejestr' THEN 1
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 2) = '@rejestr' THEN 2
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 3) = '@rejestr' THEN 3
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 4) = '@rejestr' THEN 4
    END  [seria]  INTO #tmpSeria FROM CDN.DokDefinicje

--Właściwe zapytanie
set @select = 
'SELECT
    BAZ.Baz_Nazwa AS [Baza Firmowa],
    CASE SZL_TypKuriera
        WHEN 2 THEN ''DPD''
        WHEN 3 THEN ''DHL''
        WHEN 4 THEN ''Poczta Polska''
        WHEN 5 THEN ''InPost Paczkomaty''
        WHEN 6 THEN ''InPost Allegro''
        ELSE ''(NIEZNANY)''
    END AS [Kurier Nazwa],
    SZL_NumerPelny AS [Dokument ZNP Numer],
    ISNULL(NULLIF(SZL_Uwagi, ''''), ''(BRAK)'') [Dokument ZNP Uwagi],
    CASE
        WHEN SZL_Bufor = 0 THEN ''Wysłane''
        WHEN SZL_Bufor = 1 THEN ''Niewysłane''
        ELSE ''(NIEZNANY)''
    END AS [Dokument ZNP Status],
    ISNULL(NULLIF(SZL_Status, ''''), ''(BRAK)'') AS [Dokument ZNP Status Przesyłki],
    ISNULL(NULLIF(SZL_NumerProtokoluOdbioru, ''''), ''(BRAK)'') AS [Dokument ZNP Nr Protokołu],
    ISNULL(NULLIF(SZL_NumerZleceniaOdbioru, ''''), ''(BRAK)'') AS [Dokument ZNP Nr Zlecenia Odbioru],
    ISNULL(NULLIF(SZL_ReferencjeTekst, ''''), ''(BRAK)'') AS [Dokument ZNP Referencje],
    CASE 
        WHEN SZL_DokumentyZwrotne = 1 THEN ISNULL(NULLIF(SZL_DokumentyZwrotneTekst, ''''), ''(BRAK)'')
        ELSE ''(BRAK)''
    END AS [Dokument ZNP Dokumenty Zwrotne],
    SZL_NumerPelny AS [Liczba Dokumentów ZNP],
    SAN_Kod AS [Nadawca Kod],
    SZL_SANNazwa AS [Nadawca Nazwa],
    ''ul. '' + ISNULL(NULLIF(SZL_SANUlica, ''''), ''(BRAK)'') +  '' '' + ISNULL(NULLIF(SZL_SANNrDomu, ''''), ''(BRAK)'') + CASE SZL_SANNrLokalu WHEN '''' THEN '''' ELSE ''/'' + SZL_SANNrLokalu END AS [Nadawca Adres],
    ISNULL(NULLIF(SZL_SANMiasto, ''''), ''(BRAK)'') AS [Nadawca Miasto],
    ISNULL(NULLIF(SZL_SANKodPocztowy, ''''), ''(BRAK)'') AS [Nadawca Kod Pocztowy],
    CASE SZL_OpiekunTyp
        WHEN 3 THEN Opiekun.PRI_Kod
        WHEN 8 THEN SZL_OpeModKod
        ELSE ''(NIEZNANY)''
    END AS [Nadawca Opiekun Kod],
    ISNULL(NULLIF(SZL_OpiekunNazwa, ''''), ''(BRAK)'') AS [Nadawca Osoba Kontaktowa],
    CASE 
        WHEN SZL_OdbiorcaTyp = 1 THEN ISNULL(NULLIF(Knt_Kod, ''''), ''(BRAK)'')
        WHEN SZL_OdbiorcaTyp = 2 THEN ISNULL(NULLIF(BNa_Akronim, ''''), ''(BRAK)'')
        WHEN SZL_OdbiorcaTyp = 3 THEN ISNULL(NULLIF(Odbiorca.PRI_Kod, ''''), ''(BRAK)'')
        WHEN SZL_OdbiorcaTyp = 5 THEN ISNULL(NULLIF(Urz_Akronim, ''''), ''(BRAK)'')
        WHEN SZL_OdbiorcaTyp IS NULL THEN ''(BRAK)''
        ELSE ''(NIEZNANY)''
    END AS [Obiorca Kod],
    ISNULL(NULLIF(SZL_OdbNazwa, ''''), ''(BRAK)'') AS [Odbiorca Nazwa],
    ''ul. '' + ISNULL(NULLIF(SZL_OdbUlica, ''''), ''(BRAK)'') +  '' '' + ISNULL(NULLIF(SZL_OdbNrDomu, ''''), ''(BRAK)'') + CASE SZL_OdbNrLokalu WHEN '''' THEN '''' ELSE ''/'' + SZL_OdbNrLokalu END AS [Odbiorca Adres],
    ISNULL(NULLIF(SZL_OdbMiasto, ''''), ''(BRAK)'') AS [Odbiorca Miasto],
    ISNULL(NULLIF(SZL_OdbKodPocztowy, ''''), ''(BRAK)'') AS [Odbiorca Kod Pocztowy],
    ISNULL(NULLIF(SZL_Odebral, ''''), ''(BRAK)'') AS [Odbiorca Osoba Kontaktowa],
    CASE 
        WHEN SPA_SPAID IS NULL THEN ''(BRAK)''
        ELSE SZL_NumerPelny + ''-'' + CONVERT(VARCHAR, SPA_SPAID)
    END AS [Paczka Numer],
    CASE 
        WHEN SZL_TypKuriera = 2 THEN ISNULL(NULLIF(SPA_Zawartosc, ''''), ''(BRAK)'')
        WHEN SZL_TypKuriera IN (3, 4) THEN ISNULL(NULLIF(SZL_ZawartoscTekst, ''''), ''(BRAK)'')
        ELSE ''(BRAK)''
    END AS [Paczka Zawartość],
    ISNULL(NULLIF(SPA_NumerListu, ''''), ''(BRAK)'') AS [Paczka Nr Listu Przewozowego],
    CASE 
        WHEN SZL_TypKuriera IN (2, 3) THEN 
            CASE 
                WHEN SPA_SposobPakowaniaKey = 0 THEN ''Standardowa''
                WHEN SPA_SposobPakowaniaKey = 1 THEN ''Kopertowa''
                WHEN SPA_SposobPakowaniaKey = 2 THEN ''Paletowa''
                WHEN SPA_SposobPakowaniaKey IS NULL THEN ''(BRAK)''
                ELSE ''(NIEZNANY)''
            END
        WHEN SZL_TypKuriera = 6 THEN 
            CASE SPA_SposobPakowaniaKey
                WHEN 0 THEN ''Paczkomaty 24/7''
                WHEN 1 THEN ''miniKurier24''
                WHEN 2 THEN ''Kurier24''
                ELSE ''(NIEZNANY)''
            END
        WHEN SZL_TypKuriera = 4 THEN 
            CASE SPA_SposobPakowaniaKey
                WHEN 0 THEN ''Pocztex''
                WHEN 1 THEN ''Pocztex Kurier 48''
                WHEN 2 THEN ''Usługa paczkowa''
                WHEN 3 THEN ''Paczka pocztowa''
                WHEN 4 THEN ''Przesyłka polecona''
                WHEN 5 THEN ''Przesyłka firmowa polecona''
                ELSE ''(NIEZNANY)''
            END
        ELSE ''(BRAK)''
    END AS [Paczka Rodzaj],
    CASE 
        WHEN SZL_OpcjePobranie = 1 THEN SZL_OpcjeKwotaPobrania / COUNT(SZL_NumerPelny) OVER(PARTITION BY SZL_NumerPelny)
        ELSE NULL
    END AS [Paczka Kwota Pobrania],
    CASE
        WHEN SZL_TypKuriera IN (2, 3, 5, 6) THEN 
            CASE 
                WHEN SZL_OpcjeUbezpieczenie = 1 THEN SZL_OpcjeKwotaUbezpieczenia / COUNT(SZL_NumerPelny) OVER(PARTITION BY SZL_NumerPelny)
                ELSE NULL
            END
        WHEN SZL_TypKuriera = 4 THEN NULLIF(SPA_DeklarowanaWartosc, 0)
        ELSE NULL
    END AS [Paczka Deklarowana Wartość],
    CASE
        WHEN SZL_TypKuriera IN (2, 3, 5, 6) THEN 
            CASE 
                WHEN SZL_OpcjeUbezpieczenie = 1 THEN SZL_OpcjeKwotaUbezpieczenia / COUNT(SZL_NumerPelny) OVER(PARTITION BY SZL_NumerPelny)
                ELSE NULL
            END
        WHEN SZL_TypKuriera = 4 THEN NULLIF(SPA_KwotaUbezpieczenia, 0) 
        ELSE NULL
    END AS [Paczka Kwota Ubezpieczenia],
    NULLIF(SPA_Waga, 0) AS [Paczka Waga],
    NULLIF(SPA_Wysokosc, 0) AS [Paczka Wysokość],
    NULLIF(SPA_Dlugosc, 0) AS [Paczka Długość],
    NULLIF(SPA_Szerokosc, 0) AS [Paczka Szerokość],
    CASE 
        WHEN SZL_TypKuriera = 4 AND SPA_SposobPakowaniaKey = 1 THEN 
            CASE SPA_Gabaryt
                WHEN 0 THEN ''XS''
                WHEN 1 THEN ''S''
                WHEN 2 THEN ''M''
                WHEN 3 THEN ''L''
                WHEN 4 THEN ''XL''
                WHEN 5 THEN ''XXL''
                ELSE ''(NIEZNANY)''
            END
        WHEN SZL_TypKuriera = 4 AND SPA_SposobPakowaniaKey = 3 THEN 
            CASE SPA_Gabaryt
                WHEN 0 THEN ''A''
                WHEN 1 THEN ''B''
                ELSE ''(NIEZNANY)''
            END
        WHEN SZL_TypKuriera = 4 AND SPA_SposobPakowaniaKey = 4 THEN 
            CASE SPA_Gabaryt
                WHEN 2 THEN ''S''
                WHEN 3 THEN ''M''
                WHEN 4 THEN ''L''
                ELSE ''(NIEZNANY)''
            END
        WHEN SZL_TypKuriera IN (5, 6) THEN 
            CASE SPA_Gabaryt
                WHEN 0 THEN ''A''
                WHEN 1 THEN ''B''
                WHEN 2 THEN ''C''
                ELSE ''(NIEZNANY)''
            END
        ELSE ''(BRAK)''
    END AS [Paczka Gabaryt],
    SPA_SPAID AS [Liczba Paczek],
    ISNULL(NULLIF(SZL_UrzadNadaniaKod, ''''), ''(BRAK)'') AS [Punkt Nadania Kod],
    ISNULL(NULLIF(SZL_UrzadNadaniaAdres, ''''), ''(BRAK)'') AS [Punkt Nadania Adres],
    ISNULL(NULLIF(SZL_OdbiorWPunkcieId, ''''), ''(BRAK)'') AS [Punkt Odbioru Kod],
    ISNULL(NULLIF(SZL_OdbiorWPunkcieAdres, ''''), ''(BRAK)'') AS [Punkt Odbioru Adres],
    ''(NIEPRZYPISANY)'' AS [Dokument Numer],
    ''(NIEPRZYPISANY)'' AS [Produkt Kod], 
    ''(NIEPRZYPISANY)'' AS [Produkt Nazwa],
    ''(NIEPRZYPISANY)'' AS [Kontrahent Kod],
    NULL AS [Sprzedaż Wartość Netto],
    NULL AS [Sprzedaż Wartość Brutto],
    NULL AS [Sprzedaż Ilość], 
        CASE WHEN DATEDIFF(day, SZL_DataKurierOD, GETDATE()) = 0 THEN ''TAK'' ELSE ''NIE'' END [Czas Nadania Dziś],
    CASE WHEN DATEDIFF(day, SZL_DataKurierOD, GETDATE() - 1) = 0 THEN ''TAK'' ELSE ''NIE'' END [Czas Nadania Wczoraj],
    CASE WHEN ((datepart(DY, datediff(d, 0, SZL_DataKurierOD) / 7 * 7 + 3) + 6) / 7 = (datepart(DY, datediff(d, 0, GETDATE()) / 7 * 7 + 3) + 6) / 7) AND (YEAR(SZL_DataKurierOD) = YEAR(GETDATE())) 
        THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Nadania Aktualny Tydzień],
    CASE WHEN (MONTH(SZL_DataKurierOD) = MONTH(GETDATE())) AND (YEAR(SZL_DataKurierOD) = YEAR(GETDATE())) THEN ''TAK'' ELSE ''NIE'' END [Czas Nadania Aktualny Miesiąc],
    CASE 
        WHEN (MONTH(SZL_DataKurierOD) = MONTH(GETDATE())-1) AND (YEAR(SZL_DataKurierOD) = YEAR(GETDATE())) THEN ''TAK'' 
        WHEN ((MONTH(SZL_DataKurierOD) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(SZL_DataKurierOD) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Nadania Poprzedni Miesiąc],
    zal.Ope_Kod [Operator Wprowadzający],
    mod.Ope_Kod [Operator Modyfikujący],

    /*
    ----------DATY POINT
    REPLACE(CONVERT(VARCHAR(10), SZL_DataDok, 111), ''/'', ''-'') [Data Wystawienia],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, REPLACE(CONVERT(VARCHAR(10), SZL_DataWyslania, 111), ''/'', ''-''))
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, REPLACE(CONVERT(VARCHAR(10), SZL_DataKurierOD, 111), ''/'', ''-''))
        ELSE ''(BRAK)''
    END AS [Data Nadania],
    */

    ----------DATY ANALIZY
    REPLACE(CONVERT(VARCHAR(10), SZL_DataDok, 111), ''/'', ''-'') [Data Wystawienia Dzień],
    (DATEPART(DY, DATEDIFF(d, 0, SZL_DataDok) / 7 * 7 + 3)+6) / 7 [Data Wystawienia Tydzień Roku],
    MONTH(SZL_DataDok) [Data Wystawienia Miesiąc],
    DATEPART(quarter, SZL_DataDok) [Data Wystawienia Kwartał],
    YEAR(SZL_DataDok) [Data Wystawienia Rok],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, REPLACE(CONVERT(VARCHAR(10), SZL_DataWyslania, 111), ''/'', ''-''))
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Dzień],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, (datepart(DY, datediff(d, 0, SZL_DataWyslania) / 7 * 7 + 3) + 6) / 7)
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Tydzień Roku],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, MONTH(SZL_DataWyslania))
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Miesiąc],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, DATEPART(quarter, SZL_DataWyslania))
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Kwartał],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, YEAR(SZL_DataWyslania))
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Rok],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, REPLACE(CONVERT(VARCHAR(10), SZL_DataKurierOD, 111), ''/'', ''-''))
        ELSE ''(BRAK)''
    END AS [Data Nadania Dzień],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, (datepart(DY, datediff(d, 0, SZL_DataKurierOD) / 7 * 7 + 3) + 6) / 7)
        ELSE ''(BRAK)''
    END AS [Data Nadania Tydzień Roku],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, MONTH(SZL_DataKurierOD))
        ELSE ''(BRAK)''
    END AS [Data Nadania Miesiąc],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, DATEPART(quarter, SZL_DataKurierOD))
        ELSE ''(BRAK)''
    END AS [Data Nadania Kwartał],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, YEAR(SZL_DataKurierOD))
        ELSE ''(BRAK)''
    END AS [Data Nadania Rok],
    GETDATE() [Data Analizy]
    
    ----------KONTEKSTY
    ,30392 [Dokument Numer __PROCID__Sprzedaz__], NULL [Dokument Numer __ORGID__],''' + @bazaFirmowa + ''' [Dokument Numer __DATABASE__]
    ,20201 [Kontrahent Kod __PROCID__Kontrahenci__], NULL [Kontrahent Kod __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Kod __DATABASE__]
    ,20201 [Odbiorca Nazwa __PROCID__], Odbiorca.PRI_PriId [Odbiorca Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Odbiorca Nazwa __DATABASE__]
    ,20201 [Odbiorca Kod __PROCID__], Odbiorca.PRI_PriId [Odbiorca Kod __ORGID__],''' + @bazaFirmowa + ''' [Odbiorca Kod __DATABASE__]
    ,30392 [Produkt Nazwa __PROCID__], NULL [Produkt Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Produkt Nazwa __DATABASE__]
    ,30392 [Produkt Kod __PROCID__Towary__], NULL [Produkt Kod __ORGID__],''' + @bazaFirmowa + ''' [Produkt Kod __DATABASE__]'

    + @kolumny + @atrybuty + @atrybutyDok + @atrybutyTwr + @atrybutyPoz

set @select2 = 
' FROM [CDN].[SenditZleceniePrzesylki] 
LEFT JOIN [CDN].[SenditPaczki] ON SZL_SZLID = SPA_SZLID 
LEFT JOIN [CDN].[SenditAdresyNadawcze] ON SZL_SANID = SAN_SANID
LEFT JOIN ' + @Operatorzy + ' ON SZL_OpiekunId = Ope_OpeID
LEFT JOIN [CDN].[PracIdx] Opiekun ON SZL_OpiekunId = Opiekun.PRI_PriId
LEFT JOIN [CDN].[Kontrahenci] ON SZL_OdbID = Knt_KntId AND SZL_OdbiorcaTyp = 1
LEFT JOIN [CDN].[BnkNazwy] ON SZL_OdbID = BNa_BNaId AND SZL_OdbiorcaTyp = 2
LEFT JOIN [CDN].[PracIdx] Odbiorca ON SZL_OdbID = Odbiorca.PRI_PriId AND SZL_OdbiorcaTyp = 3
LEFT JOIN [CDN].[Urzedy] ON SZL_OdbID = Urz_UrzId AND SZL_OdbiorcaTyp = 5
LEFT JOIN #tmpTwrGr Poz ON 0 = 1
LEFT JOIN #tmpTwrAtr TwrAtr ON 0 = 1
LEFT JOIN #tmpPozAtr PozAtr ON 0 = 1
LEFT JOIN #tmpKonAtr KonAtr ON 0 = 1
LEFT JOIN #tmpKonAtr OdbAtr ON 0 = 1
LEFT JOIN #tmpDokAtr DokAtr ON 0 = 1
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON Knt_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON Knt_OpeModID = mod.Ope_OpeId

UNION ALL

SELECT
    BAZ.Baz_Nazwa AS [Baza Firmowa],
    CASE SZL_TypKuriera
        WHEN 2 THEN ''DPD''
        WHEN 3 THEN ''DHL''
        WHEN 4 THEN ''Poczta Polska''
        WHEN 5 THEN ''InPost Paczkomaty''
        WHEN 6 THEN ''InPost Allegro''
        ELSE ''(NIEZNANY)''
    END AS [Kurier Nazwa],
    SZL_NumerPelny AS [Dokument ZNP Numer],
    ISNULL(NULLIF(SZL_Uwagi, ''''), ''(BRAK)'') [Dokument ZNP Uwagi],
    CASE
        WHEN SZL_Bufor = 0 THEN ''Wysłane''
        WHEN SZL_Bufor = 1 THEN ''Niewysłane''
        ELSE ''(NIEZNANY)''
    END AS [Dokument ZNP Status],
    ISNULL(NULLIF(SZL_Status, ''''), ''(BRAK)'') AS [Dokument ZNP Status Przesyłki],
    ISNULL(NULLIF(SZL_NumerProtokoluOdbioru, ''''), ''(BRAK)'') AS [Dokument ZNP Nr Protokołu],
    ISNULL(NULLIF(SZL_NumerZleceniaOdbioru, ''''), ''(BRAK)'') AS [Dokument ZNP Nr Zlecenia Odbioru],
    ISNULL(NULLIF(SZL_ReferencjeTekst, ''''), ''(BRAK)'') AS [Dokument ZNP Referencje],
    CASE 
        WHEN SZL_DokumentyZwrotne = 1 THEN ISNULL(NULLIF(SZL_DokumentyZwrotneTekst, ''''), ''(BRAK)'')
        ELSE ''(BRAK)''
    END AS [Dokument ZNP Dokumenty Zwrotne],
    SZL_NumerPelny AS [Liczba Dokumentów ZNP],
    SAN_Kod AS [Nadawca Kod],
    SZL_SANNazwa AS [Nadawca Nazwa],
    ''ul. '' + ISNULL(NULLIF(SZL_SANUlica, ''''), ''(BRAK)'') +  '' '' + ISNULL(NULLIF(SZL_SANNrDomu, ''''), ''(BRAK)'') + CASE SZL_SANNrLokalu WHEN '''' THEN '''' ELSE ''/'' + SZL_SANNrLokalu END AS [Nadawca Adres],
    ISNULL(NULLIF(SZL_SANMiasto, ''''), ''(BRAK)'') AS [Nadawca Miasto],
    ISNULL(NULLIF(SZL_SANKodPocztowy, ''''), ''(BRAK)'') AS [Nadawca Kod Pocztowy],
    CASE SZL_OpiekunTyp
        WHEN 3 THEN Opiekun.PRI_Kod
        WHEN 8 THEN SZL_OpeModKod
        ELSE ''(NIEZNANY)''
    END AS [Nadawca Opiekun Kod],
    ISNULL(NULLIF(SZL_OpiekunNazwa, ''''), ''(BRAK)'') AS [Nadawca Osoba Kontaktowa],
    CASE 
        WHEN SZL_OdbiorcaTyp = 1 THEN ISNULL(NULLIF(Knt1.Knt_Kod, ''''), ''(BRAK)'')
        WHEN SZL_OdbiorcaTyp = 2 THEN ISNULL(NULLIF(BNa_Akronim, ''''), ''(BRAK)'')
        WHEN SZL_OdbiorcaTyp = 3 THEN ISNULL(NULLIF(Odbiorca.PRI_Kod, ''''), ''(BRAK)'')
        WHEN SZL_OdbiorcaTyp = 5 THEN ISNULL(NULLIF(Urz_Akronim, ''''), ''(BRAK)'')
        WHEN SZL_OdbiorcaTyp IS NULL THEN ''(BRAK)''
        ELSE ''(NIEZNANY)''
    END AS [Obiorca Kod],
    ISNULL(NULLIF(SZL_OdbNazwa, ''''), ''(BRAK)'') AS [Odbiorca Nazwa],
    ''ul. '' + ISNULL(NULLIF(SZL_OdbUlica, ''''), ''(BRAK)'') +  '' '' + ISNULL(NULLIF(SZL_OdbNrDomu, ''''), ''(BRAK)'') + CASE SZL_OdbNrLokalu WHEN '''' THEN '''' ELSE ''/'' + SZL_OdbNrLokalu END AS [Odbiorca Adres],
    ISNULL(NULLIF(SZL_OdbMiasto, ''''), ''(BRAK)'') AS [Odbiorca Miasto],
    ISNULL(NULLIF(SZL_OdbKodPocztowy, ''''), ''(BRAK)'') AS [Odbiorca Kod Pocztowy],
    ISNULL(NULLIF(SZL_Odebral, ''''), ''(BRAK)'') AS [Odbiorca Osoba Kontaktowa],
    ''(NIEPRZYPISANY)'' AS [Paczka Numer],
    ''(NIEPRZYPISANY)'' AS [Paczka Zawartość],
    ''(NIEPRZYPISANY)'' AS [Paczka Nr Listu Przewozowego],
    ''(NIEPRZYPISANY)'' AS [Paczka Rodzaj],
    NULL AS [Paczka Kwota Pobrania],
    NULL AS [Paczka Deklarowana Wartość],
    NULL AS [Paczka Kwota Ubezpieczenia],
    NULL AS [Paczka Waga],
    NULL AS [Paczka Wysokość],
    NULL AS [Paczka Długość],
    NULL AS [Paczka Szerokość],
    ''(NIEPRZYPISANY)'' AS [Paczka Gabaryt],
    NULL AS [Liczba Paczek],
    ISNULL(NULLIF(SZL_UrzadNadaniaKod, ''''), ''(BRAK)'') AS [Punkt Nadania Kod],
    ISNULL(NULLIF(SZL_UrzadNadaniaAdres, ''''), ''(BRAK)'') AS [Punkt Nadania Adres],
    ISNULL(NULLIF(SZL_OdbiorWPunkcieId, ''''), ''(BRAK)'') AS [Punkt Odbioru Kod],
    ISNULL(NULLIF(SZL_OdbiorWPunkcieAdres, ''''), ''(BRAK)'') AS [Punkt Odbioru Adres],
    ISNULL(NULLIF(TrN_NumerPelny, ''''), ''(BRAK)'') AS [Dokument Numer],
    Twr_Kod AS [Produkt Kod], 
    Twr_Nazwa AS [Produkt Nazwa],
    Knt2.Knt_Kod AS [Kontrahent Kod],
    TrE_WartoscNetto AS [Sprzedaż Wartość Netto], 
    TrE_WartoscBrutto AS [Sprzedaż Wartość Brutto], 
    TrE_Ilosc AS [Sprzedaż Ilość], 
    CASE WHEN DATEDIFF(day, SZL_DataKurierOD, GETDATE()) = 0 THEN ''TAK'' ELSE ''NIE'' END [Czas Nadania Dziś],
    CASE WHEN DATEDIFF(day, SZL_DataKurierOD, GETDATE() - 1) = 0 THEN ''TAK'' ELSE ''NIE'' END [Czas Nadania Wczoraj],
    CASE WHEN ((datepart(DY, datediff(d, 0, SZL_DataKurierOD) / 7 * 7 + 3) + 6) / 7 = (datepart(DY, datediff(d, 0, GETDATE()) / 7 * 7 + 3) + 6) / 7) AND (YEAR(SZL_DataKurierOD) = YEAR(GETDATE())) 
        THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Nadania Aktualny Tydzień],
    CASE WHEN (MONTH(SZL_DataKurierOD) = MONTH(GETDATE())) AND (YEAR(SZL_DataKurierOD) = YEAR(GETDATE())) THEN ''TAK'' ELSE ''NIE'' END [Czas Nadania Aktualny Miesiąc],
    CASE 
        WHEN (MONTH(SZL_DataKurierOD) = MONTH(GETDATE())-1) AND (YEAR(SZL_DataKurierOD) = YEAR(GETDATE())) THEN ''TAK'' 
        WHEN ((MONTH(SZL_DataKurierOD) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(SZL_DataKurierOD) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
        ELSE ''NIE'' 
    END [Czas Nadania Poprzedni Miesiąc],
    zal.Ope_Kod [Operator Wprowadzający], 
    mod.Ope_Kod [Operator Modyfikujący],

    /*
    ----------DATY POINT
    REPLACE(CONVERT(VARCHAR(10), SZL_DataDok, 111), ''/'', ''-'') [Data Wystawienia],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, REPLACE(CONVERT(VARCHAR(10), SZL_DataWyslania, 111), ''/'', ''-''))
    END AS [Data Zgłoszenia],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, REPLACE(CONVERT(VARCHAR(10), SZL_DataKurierOD, 111), ''/'', ''-''))
    END AS [Data Nadania],
    */

    ----------DATY ANALIZY
    REPLACE(CONVERT(VARCHAR(10), SZL_DataDok, 111), ''/'', ''-'') [Data Wystawienia Dzień],
    (DATEPART(DY, DATEDIFF(d, 0, SZL_DataDok) / 7 * 7 + 3)+6) / 7 [Data Wystawienia Tydzień Roku],
    MONTH(SZL_DataDok) [Data Wystawienia Miesiąc],
    DATEPART(quarter, SZL_DataDok) [Data Wystawienia Kwartał],
    YEAR(SZL_DataDok) [Data Wystawienia Rok],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, REPLACE(CONVERT(VARCHAR(10), SZL_DataWyslania, 111), ''/'', ''-''))
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Dzień],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, (datepart(DY, datediff(d, 0, SZL_DataWyslania) / 7 * 7 + 3) + 6) / 7)
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Tydzień Roku],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, MONTH(SZL_DataWyslania))
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Miesiąc],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, DATEPART(quarter, SZL_DataWyslania))
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Kwartał],
    CASE 
        WHEN SZL_DataWyslania > ''1900-01-01'' THEN CONVERT(VARCHAR, YEAR(SZL_DataWyslania))
        ELSE ''(BRAK)''
    END AS [Data Zgłoszenia Rok],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, REPLACE(CONVERT(VARCHAR(10), SZL_DataKurierOD, 111), ''/'', ''-''))
        ELSE ''(BRAK)''
    END AS [Data Nadania Dzień],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, (datepart(DY, datediff(d, 0, SZL_DataKurierOD) / 7 * 7 + 3) + 6) / 7)
        ELSE ''(BRAK)''
    END AS [Data Nadania Tydzień Roku],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, MONTH(SZL_DataKurierOD))
        ELSE ''(BRAK)''
    END AS [Data Nadania Miesiąc],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, DATEPART(quarter, SZL_DataKurierOD))
        ELSE ''(BRAK)''
    END AS [Data Nadania Kwartał],
    CASE 
        WHEN SZL_DataKurierOD > ''1900-01-01'' THEN CONVERT(VARCHAR, YEAR(SZL_DataKurierOD))
        ELSE ''(BRAK)''
    END AS [Data Nadania Rok],
    GETDATE() [Data Analizy]
    
    ----------KONTEKSTY
    ,30392 [Dokument Numer __PROCID__Sprzedaz__], TrN_TrNId [Dokument Numer __ORGID__],''' + @bazaFirmowa + ''' [Dokument Numer __DATABASE__]
    ,20201 [Kontrahent Kod __PROCID__Kontrahenci__], Knt2.Knt_KntId [Kontrahent Kod __ORGID__],''' + @bazaFirmowa + ''' [Kontrahent Kod __DATABASE__]
    ,20201 [Odbiorca Nazwa __PROCID__], Odbiorca.PRI_PriId [Odbiorca Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Odbiorca Nazwa __DATABASE__]
    ,20201 [Odbiorca Kod __PROCID__], Odbiorca.PRI_PriId [Odbiorca Kod __ORGID__],''' + @bazaFirmowa + ''' [Odbiorca Kod __DATABASE__]
    ,30392 [Produkt Nazwa __PROCID__], Twr_TwrId [Produkt Nazwa __ORGID__],''' + @bazaFirmowa + ''' [Produkt Nazwa __DATABASE__]
    ,30392 [Produkt Kod __PROCID__Towary__], Twr_TwrId [Produkt Kod __ORGID__],''' + @bazaFirmowa + ''' [Produkt Kod __DATABASE__]'

    + @kolumny + @atrybuty + @atrybutyDok + @atrybutyTwr + @atrybutyPoz

set @select3 = 
' FROM [CDN].[SenditZleceniePrzesylki] 
LEFT JOIN [CDN].[SenditAdresyNadawcze] ON SZL_SANID = SAN_SANID
LEFT JOIN ' + @Operatorzy + ' ON SZL_OpiekunId = Ope_OpeID
LEFT JOIN [CDN].[PracIdx] Opiekun ON SZL_OpiekunId = Opiekun.PRI_PriId
LEFT JOIN [CDN].[Kontrahenci] Knt1 ON SZL_OdbID = Knt1.Knt_KntId AND SZL_OdbiorcaTyp = 1
LEFT JOIN [CDN].[BnkNazwy] ON SZL_OdbID = BNa_BNaId AND SZL_OdbiorcaTyp = 2
LEFT JOIN [CDN].[PracIdx] Odbiorca ON SZL_OdbID = Odbiorca.PRI_PriId AND SZL_OdbiorcaTyp = 3
LEFT JOIN [CDN].[Urzedy] ON SZL_OdbID = Urz_UrzId AND SZL_OdbiorcaTyp = 5
JOIN [CDN].[TraNag] ON TrN_TypDokumentu = SZL_DokZrodloweTyp AND TrN_TrNID = SZL_DokZrodlowe
LEFT JOIN [CDN].[TraElem] ON TrE_TrNID = TrN_TrNID
LEFT JOIN [CDN].[Towary] ON TrE_TwrId = Twr_TwrId
LEFT JOIN [CDN].[Kontrahenci] Knt2 ON TrN_PodID = Knt2.Knt_KntId AND TrN_PodmiotTyp = 1
LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
LEFT JOIN #tmpTwrAtr TwrAtr ON TrE_TwrId = TwrAtr.TwA_TwrId 
LEFT JOIN #tmpPozatr PozAtr ON TrE_TrEId = PozAtr.TrA_TrEId
LEFT JOIN #tmpKonAtr KonAtr ON TrN_PodID = KonAtr.KnA_PodmiotId AND TrN_PodmiotTyp = KonAtr.KnA_PodmiotTyp
LEFT JOIN #tmpKonAtr OdbAtr ON SZL_OdbID = OdbAtr.KnA_PodmiotId AND SZL_OdbiorcaTyp = OdbAtr.KnA_PodmiotTyp
LEFT JOIN #tmpDokAtr DokAtr ON TrN_TrNID = DokAtr.DAt_TrNId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON SZL_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON SZL_OpeModID = mod.Ope_OpeId
'

print (@select + @select2 + @select3)
exec (@select + @select2 + @select3)

DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpDokAtr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpSeria
DROP TABLE #tmpPozAtr




