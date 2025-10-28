

/*
* Raport Stanów Magazynowych na Dzień
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
DECLARE @Operatorzy varchar(max);
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 

--Właściwe zapytanie
set @select =
'SELECT BAZ.Baz_Nazwa [Baza Firmowa], 

    Twr_Kod [Produkt Kod],  
    Twr_Nazwa [Produkt Nazwa], 
    CASE TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
    CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny],
    Twr_JM [Produkt Jednostka Miary], ISNULL(NULLIF(Twr_JMZ,''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza], CAST(Twr_Opis as VARCHAR(1024)) [Produkt Opis],
    Isnull(convert(varchar(15),twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG],
    Mag_Symbol [Magazyn Kod],
    CASE
        WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa Prosta''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar Prosty''
        WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa Złożona''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar Złożony''
        ELSE ''(NIEOKREŚLONY)''
    END [Produkt Typ], TwC_Wartosc [Cena Domyślna], ISNULL(Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
    ISNULL(kat.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria Szczegółowa], ISNULL(kat.Kat_KodOgolny, ''(PUSTA)'') [Produkt Kategoria Ogólna], 
    ISNULL(TwI_Ilosc, 0) [Ilość], 
    CASE WHEN Twr_JMPrzelicznikL <> 0 THEN CONVERT(DECIMAL(20,4),ISNULL(TwI_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0)) ELSE 0 END [Ilość Jednostka Pomocnicza], 
    ISNULL(TwI_Rezerwacje, 0) [Rezerwacje], 
    CASE WHEN Twr_JMPrzelicznikL <> 0 THEN CONVERT(DECIMAL(20,4),ISNULL(TwI_Rezerwacje*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0)) ELSE 0 END  [Rezerwacje Jednostka Pomocnicza], 
    ISNULL(TwI_Braki, 0) [Braki], 
    CASE WHEN Twr_JMPrzelicznikL <> 0 THEN CONVERT(DECIMAL(20,4),ISNULL(TwI_Braki*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0)) ELSE 0 END [Braki Jednostka Pomocnicza], 
    ISNULL(TwI_Zamowienia, 0) [Zamówienia],
    ISNULL(TwI_Wartosc, 0) [Zamówienia Wartość], 
    CASE WHEN Twr_JMPrzelicznikL <> 0 THEN CONVERT(DECIMAL(20,4),ISNULL(TwI_Zamowienia*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0)) ELSE 0 END [Zamówienia Jednostka Pomocnicza],
    ISNULL(TwI_Wartosc, 0) [Wartość Netto], ISNULL(TwI_Wartosc, 0 ) * (1 + Twr_Stawka/100) [Wartość Brutto],
    NULLIF(Twr_IloscMin,0) [Ilość Minimalna], NULLIF(Twr_IloscMax,0) [Ilość Maksymalna],
    SprzedazWartosc [Sprzedaż Wartość Netto], SprzedazIlosc [Sprzedaż Ilość]
    ,zal.Ope_Kod [Operator Wprowadzający] 
    ,mod.Ope_Kod [Operator Modyfikujący]
    ,GETDATE() [Data Analizy]
/*
    ----------KONTEKSTY
    ,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
    ,29056 [Magazyn Kod __PROCID__Magazyny__], Mag_MagId [Magazyn Kod __ORGID__],'''+@bazaFirmowa+''' [Magazyn Kod __DATABASE__]
*/
    ' + @kolumny + @atrybutyTwr + '
FROM CDN.TwrIlosci
    LEFT OUTER JOIN CDN.Magazyny ON Mag_MagId = TwI_MagId
    JOIN CDN.Towary ON TwI_TwrId = Twr_TwrId
     LEFT JOIN CDN.Producenci ON Prd_PrdId = Twr_PrdId
     LEFT JOIN CDN.Marki ON Mrk_MrkId = Twr_MrkId
    LEFT JOIN CDN.TwrCeny ON Twr_TwrId = TwC_TwrID AND Twr_TwCNumer = TwC_TwCNumer
    LEFT OUTER JOIN CDN.Kategorie kat ON Twr_KatId=kat.Kat_KatID
    JOIN #TwrIlosci ON TwI_TId = TwI_TwrId AND TwI_OstatniaData = TwI_Data AND TwI_MId = TwI_MagId
    LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
    LEFT JOIN #tmpTwrAtr TwrAtr ON TwI_TwrId  = TwrAtr.TwA_TwrId
    LEFT OUTER JOIN #tmpSprzedaz ON TwI_MagId = TrE_MagId AND TwI_TwrId = TrE_TwrId
    LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON Twr_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON Twr_OpeModID = mod.Ope_OpeId
'

IF @ZEROWE = 'NIE' SET @select = @select + ' WHERE ISNULL(TwI_Ilosc, 0) <> 0'

SET @select = @select + '

UNION ALL

SELECT BAZ.Baz_Nazwa [Baza Firmowa], 
    
    Twr_Kod [Produkt Kod], 
    Twr_Nazwa [Produkt Nazwa],
    CASE TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
    CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny],
    Twr_JM [Produkt Jednostka Miary], ISNULL(NULLIF(Twr_JMZ,''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza], CAST(Twr_Opis as VARCHAR(1024)) [Produkt Opis],
    Isnull(convert(varchar(15),twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG],
    ''(Korekta Braków)'' [Magazyn Kod],
    CASE
        WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa Prosta''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar Prosty''
        WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa Złożona''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar Złożony''
        ELSE ''(NIEOKREŚLONY)''
    END [Produkt Typ], TwC_Wartosc [Cena Domyślna], ISNULL(Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
    ISNULL(kat.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria Szczegółowa], ISNULL(kat.Kat_KodOgolny, ''(PUSTA)'') [Produkt Kategoria Ogólna], 
    NULL [Ilość], 
    NULL [Ilość Jednostka Pomocnicza], 
    NULL [Rezerwacje], 
    NULL  [Rezerwacje Jednostka Pomocnicza], 
    Braki [Braki], 
    CASE WHEN Twr_JMPrzelicznikL <> 0 THEN CONVERT(DECIMAL(20,4),ISNULL(Braki*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0)) ELSE 0 END [Braki Jednostka Pomocnicza], 
    NULL[Zamówienia], 
    NULL [Zamówienia Wartość], 
    NULL [Zamówienia Jednostka Pomocnicza],
    NULL [Wartość Netto], NULL [Wartość Brutto],
    NULLIF(Twr_IloscMin,0) [Ilość Minimalna], NULLIF(Twr_IloscMax,0) [Ilość Maksymalna],
    NULL [Sprzedaż Wartość Netto], NULL [Sprzedaż Ilość]
    ,zal.Ope_Kod [Operator Wprowadzający] 
    ,mod.Ope_Kod [Operator Modyfikujący]
    ,GETDATE() [Data Analizy]
/*
    ----------KONTEKSTY
    ,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
    ,29056 [Magazyn Kod __PROCID__Magazyny__], 1 [Magazyn Kod __ORGID__],'''+@bazaFirmowa+''' [Magazyn Kod __DATABASE__]
*/
    ' + @kolumny + @atrybutyTwr + '
FROM CDN.Towary
     LEFT JOIN CDN.Producenci ON Prd_PrdId = Twr_PrdId
     LEFT JOIN CDN.Marki ON Mrk_MrkId = Twr_MrkId
    LEFT JOIN CDN.TwrCeny ON Twr_TwrId = TwC_TwrID AND Twr_TwCNumer = TwC_TwCNumer
    LEFT OUTER JOIN CDN.Kategorie kat ON Twr_KatId=kat.Kat_KatID
    JOIN #TwrBraki ON TwI_TId = Twr_TwrId AND Braki <> 0
    LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
    LEFT JOIN #tmpTwrAtr TwrAtr ON Twr_TwrId  = TwrAtr.TwA_TwrId
    LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON Twr_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON Twr_OpeModID = mod.Ope_OpeId
'

    IF @ZEROWE = 'TAK' SET @select = @select +
'
UNION ALL
SELECT BAZ.Baz_Nazwa [Baza Firmowa], 
    Twr_Kod [Produkt Kod], 
    Twr_Nazwa [Produkt Nazwa],
    CASE TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
    CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny],
    Twr_JM [Produkt Jednostka Miary], ISNULL(NULLIF(Twr_JMZ,''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza], CAST(Twr_Opis as VARCHAR(1024)) [Produkt Opis],
    Isnull(convert(varchar(15),twr_wagakg), ''(NIEPRZYPISANE)'') [Produkt Waga KG],
    ''(Korekta Braków)'' [Magazyn Kod],
    CASE
        WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa Prosta''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar Prosty''
        WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa Złożona''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar Złożony''
        ELSE ''(NIEOKREŚLONY)''
    END [Produkt Typ], TwC_Wartosc [Cena Domyślna], ISNULL(Prd_Kod, ''(NIEPRZYPISANE)'') [Produkt Producent], ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)'') [Produkt Marka],
    ISNULL(kat.Kat_KodSzczegol, ''(PUSTA)'') [Produkt Kategoria Szczegółowa], ISNULL(kat.Kat_KodOgolny, ''(PUSTA)'') [Produkt Kategoria Ogólna], 
    0 [Ilość], 
    0 [Ilość Jednostka Pomocnicza], 
    0 [Rezerwacje], 
    0  [Rezerwacje Jednostka Pomocnicza], 
    0 AS [Braki], 
    CASE WHEN Twr_JMPrzelicznikL <> 0 THEN CONVERT(DECIMAL(20,4),ISNULL(0*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL, 0)) ELSE 0 END [Braki Jednostka Pomocnicza], 
    0[Zamówienia], 
    0 [Zamówienia Wartość], 
    0 [Zamówienia Jednostka Pomocnicza],
    0 [Wartość Netto], 0 [Wartość Brutto],
    NULLIF(Twr_IloscMin,0) [Ilość Minimalna], NULLIF(Twr_IloscMax,0) [Ilość Maksymalna],
    NULL [Sprzedaż Wartość Netto], NULL [Sprzedaż Ilość]
    ,zal.Ope_Kod [Operator Wprowadzający] 
    ,mod.Ope_Kod [Operator Modyfikujący]
,GETDATE() [Data Analizy]
/*
    ----------KONTEKSTY
    ,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
    ,29056 [Magazyn Kod __PROCID__Magazyny__], 1 [Magazyn Kod __ORGID__],'''+@bazaFirmowa+''' [Magazyn Kod __DATABASE__]
*/
    ' + @kolumny + @atrybutyTwr + '
FROM CDN.Towary
     LEFT JOIN CDN.Producenci ON Prd_PrdId = Twr_PrdId
     LEFT JOIN CDN.Marki ON Mrk_MrkId = Twr_MrkId
    LEFT JOIN CDN.TwrCeny ON Twr_TwrId = TwC_TwrID AND Twr_TwCNumer = TwC_TwCNumer
    LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
    LEFT OUTER JOIN CDN.Kategorie kat ON Twr_KatId=kat.Kat_KatID
    LEFT OUTER JOIN #tmpSprzedaz s ON  Twr_TwrId = s.TrE_TwrId
    LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
    LEFT JOIN #tmpTwrAtr TwrAtr ON Twr_TwrId  = TwrAtr.TwA_TwrId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON Twr_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON Twr_OpeModID = mod.Ope_OpeId
WHERE Twr_TwrId NOT IN (SELECT TwI_TwrId  FROM CDN.TwrIlosci)
'
--IF @ZEROWE = 'NIE' SET @select = @select + ' WHERE ISNULL(TwI_Ilosc, 0) <> 0'
    
EXEC(@select)

DROP TABLE #TwrIlosci
DROP TABLE #TwrBraki
DROP TABLE #tmpTwrGr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpSprzedaz








