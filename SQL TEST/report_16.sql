/*
* Raport Środków Trwałych
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.1.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--Wyliczanie Atrybutów Środków Trwałych
DECLARE @atrybut_id int, @atrybut_kod nvarchar(50), @atrybut_typ int, @atrybut_format int, @atrybuty varchar(max), @atrybuty2 varchar(max), @sqlA nvarchar(max);

DECLARE @wersja float;
SET @wersja = (SELECT CONVERT(float, SYS_Wartosc) FROM CDN.SystemCDN WHERE SYS_ID = 3)

DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Bazy varchar(max);
DECLARE @Operatorzy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT SrA_DeAid FROM CDN.TrwaleAtrybuty)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT ISNULL(SrA_SrTId, SrA_WypId) SrA_SrTId, SrA_Typ INTO #tmpKonAtr FROM CDN.TrwaleAtrybuty

SET @atrybuty = ''
SET @atrybuty2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 1 BEGIN SET @atrybut_kod = @atrybut_kod + ' (T)' END
    IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
    SET @sqlA = N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpKonAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.SrA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.SrA_WartoscTxt,'','',''.'') ELSE ATR.SrA_WartoscTxt END
         END
        FROM CDN.TrwaleAtrybuty ATR 
        JOIN #tmpKonAtr TM ON ISNULL(ATR.SrA_SrTId, ATR.SrA_WypId) = TM.SrA_SrTId AND ATR.SrA_Typ = TM.SrA_Typ
        WHERE ATR.SrA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'  
    SET @atrybuty2 = @atrybuty2 + N', KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + ']'       
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

DECLARE @select varchar(max);
SET @select = 
'SELECT
BAZ.Baz_Nazwa [Baza Firmowa], SrT_Nazwa [Produkt Nazwa], SrT_NrInwent [Produkt Numer Inwentarzowy], SrT_KRST [KŚT],
REPLACE(CONVERT(VARCHAR(10), SrT_DataPrz, 111), ''/'', ''-'') [Data Przyjęcia Dzień], 
ISNULL(REPLACE(CONVERT(VARCHAR(10), SrT_DataLikw, 111), ''/'', ''-''), ''W użyciu'') [Data Likwidacji Dzień],
h1.SrH_Grupa [Produkt Grupa], YEAR(h1.SrH_DataOpe) [Data Amortyzacji Rok], MONTH(h1.SrH_DataOpe) [Data Amortyzacji Miesiąc], 
ISNULL((SELECT TOP 1 OO.SrOO_PrcImieNazwisko 
FROM CDN.TrwaleOsobyOdpowiedzialne OO 
WHERE OO.SrOO_SrTID = h1.SrH_SrTID
    AND 100*ISNULL(YEAR(SrOO_DataOd),0)+ISNULL(MONTH(SrOO_DataOd),0) <= 100*YEAR(h1.SrH_DataOpe)+MONTH(h1.SrH_DataOpe)
    AND 100*ISNULL(YEAR(SrOO_DataDo),9999)+ISNULL(MONTH(SrOO_DataDo),99) >= 100*YEAR(h1.SrH_DataOpe)+MONTH(h1.SrH_DataOpe)
ORDER BY OO.SrOO_DataOd DESC), ''Nieprzypisany'') [Osoba Odpowiedzialna],
ISNULL((SELECT TOP 1 MU.SrMU_Nazwa 
FROM CDN.TrwaleMiejscaUzytkowania MU
WHERE MU.SrMU_SrTID = h1.SrH_SrTID
    AND 100*ISNULL(YEAR(SrMU_DataOd),0)+ISNULL(MONTH(SrMU_DataOd),0) <= 100*YEAR(h1.SrH_DataOpe)+MONTH(h1.SrH_DataOpe)
    AND 100*ISNULL(YEAR(SrMU_DataDo),9999)+ISNULL(MONTH(SrMU_DataDo),99) >= 100*YEAR(h1.SrH_DataOpe)+MONTH(h1.SrH_DataOpe)
ORDER BY MU.SrMU_DataOd DESC), ''Nieprzypisany'') [Miejsce Użytkowania],
CASE 
    WHEN h1.SrH_Typ = 11 THEN ''Środek Trwały''
    WHEN h1.SrH_Typ = 12 THEN ''WNP''
    ELSE ''Inny'' 
END [Produkt Typ],
CASE 
    WHEN SrT_Stan = 0 THEN ''W użyciu''
    WHEN SrT_Stan = 1 THEN ''Zlikwidowany''
    WHEN SrT_Stan = 2 THEN ''Zbyty''
    ELSE ''Inny''
END [Produkt Stan], 
CASE
    WHEN SrH_Metoda = 0 THEN ''Nie amortyzować''
    WHEN SrH_Metoda = 1 THEN ''Metoda liniowa''
    WHEN SrH_Metoda = 2 THEN ''Metoda degresywna''
    WHEN SrH_Metoda = 3 THEN ''Odpis jednorazowy''
    WHEN SrH_Metoda = 4 THEN ''Metoda naturalna''
    ELSE ''Inna''
END [Metoda Amortyzacji],
isnull(ZakladStr.Zak_Symbol,''(NIEPRZYPISANY)'') as [Produkt Zakład Symbol],
isnull(ZakladStr.zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Produkt Zakład Nazwa Firmy],
isnull(ZakladDok.Zak_Symbol,''(NIEPRZYPISANY)'') as [Dokument Zakład Symbol],
isnull(ZakladDok.zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Dokument Zakład Nazwa Firmy],
 1 [Ilość],
IsNull(kat1.Kat_KodSzczegol,''NIEOKREŚLONA'') [Produkt Kategoria Amortyzacja], IsNull(kat2.Kat_KodSzczegol,''NIEOKREŚLONA'') [Produkt Kategoria],  
NULL [Wartość Nabycia], NULL [Wartość Nabycia Kosztowa], CASE WHEN SrH_TypDokumentu = 3 THEN h1.SrH_KwotaAm ELSE NULL END [Koszty Amortyzacji], NULL [Wartość Netto], NULL [Wartość Brutto],
(SELECT SUM(IsNull(h2.SrH_KwotaBilan - h2.SrH_KwotaUm, 0)) FROM CDN.TrwaleHist h2 WHERE h2.SrH_SrTID = h1.SrH_SrTID AND 100*YEAR(h2.SrH_DataOpe)+MONTH(h2.SrH_DataOpe) <= 100*YEAR(h1.SrH_DataOpe)+MONTH(h1.SrH_DataOpe)) [Wartość w Czasie Netto],
(SELECT SUM(IsNull(h2.SrH_KwotaBilan, 0)) FROM CDN.TrwaleHist h2 WHERE h2.SrH_SrTID = h1.SrH_SrTID AND 100*YEAR(h2.SrH_DataOpe)+MONTH(h2.SrH_DataOpe) <= 100*YEAR(h1.SrH_DataOpe)+MONTH(h1.SrH_DataOpe)) [Wartość w Czasie Brutto]
,cast(SrT_Stawka as nvarchar(50)) [Stawka amortyzacji Kosztowa]
,cast(SrT_StawkaBil as nvarchar(50)) [Stawka amortyzacji Bilansowa]
,cast(SrT_Wspolczynnik as nvarchar(50)) [Współczynnik amortyzacji Kosztowy]
,cast(SrT_WspolczynnikBil as nvarchar(50)) [Współczynnik amortyzacji Bilansowy]
,CASE WHEN SrH_TypDokumentu = 3 THEN h1.SrH_KwotaUm ELSE NULL END [Koszty Amortyzacji Bilansowe]
' + @atrybuty + '
,GETDATE() [Data Analizy]
  ,REPLACE(CONVERT(VARCHAR(10), SrH_DataOpe, 111), ''/'', ''-'') [Data Dokumentu Dzień] 
    ,(datepart(DY, datediff(d, 0, SrH_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataOpe)*/ [Data Dokumentu Tydzień Roku]
    ,MONTH(SrH_DataOpe) [Data Dokumentu Miesiąc], DATEPART(quarter, SrH_DataOpe) [Data Dokumentu Kwartał], YEAR(SrH_DataOpe) [Data Dokumentu Rok] 
 FROM CDN.TrwaleHist h1
LEFT OUTER JOIN CDN.Trwale ON h1.SrH_SrTID = SrT_SrTID
LEFT OUTER JOIN CDN.Kategorie kat1 ON kat1.Kat_KatId = h1.SrH_KatId
LEFT OUTER JOIN CDN.Kategorie kat2 ON kat2.Kat_KatId = SrT_KatId
LEFT JOIN #tmpKonAtr KonAtr ON SrT_SrTID = KonAtr.SrA_SrTId AND SrT_Typ = KonAtr.SrA_Typ
LEFT OUTER JOIN CDN.Zaklady ZakladDok on ZakladDok.ZAK_ZAkID = h1.SrH_ZakID
LEFT OUTER JOIN CDN.Zaklady ZakladStr on ZakladStr.ZAK_ZAkID = SrT_ZakID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
WHERE h1.SrH_DataOpe >= SrT_DataZak  and SrH_TypDokumentu NOT IN (4,6)

UNION ALL

SELECT
BAZ.Baz_Nazwa [Baza Firmowa], SrT_Nazwa [Produkt Nazwa], SrT_NrInwent [Produkt Numer Inwentarzowy], SrT_KRST [KŚT],
REPLACE(CONVERT(VARCHAR(10), SrT_DataPrz, 111), ''/'', ''-'') [Data Przyjęcia Dzień],
ISNULL(REPLACE(CONVERT(VARCHAR(10), SrT_DataLikw, 111), ''/'', ''-''), ''W użyciu'') [Data Likwidacji Dzień],
SrT_Grupa [Produkt Grupa], NULL [Data Amortyzacji Rok], NULL [Data Amortyzacji Miesiąc], 
ISNULL((SELECT TOP 1 OO.SrOO_PrcImieNazwisko 
 FROM CDN.TrwaleOsobyOdpowiedzialne OO 
 WHERE OO.SrOO_SrTID = MAX(h1.SrH_SrTID) 
 ORDER BY OO.SrOO_DataOd DESC), ''Nieprzypisany'') [Osoba Odpowiedzialna], 
ISNULL((SELECT TOP 1 MU.SrMU_Nazwa 
 FROM CDN.TrwaleMiejscaUzytkowania MU 
 WHERE MU.SrMU_SrTID = MAX(h1.SrH_SrTID) 
 ORDER BY MU.SrMU_DataOd DESC), ''Nieprzypisany'') [Miejsce Użytkowania], 
CASE 
    WHEN SrT_Typ = 11 THEN ''Środek Trwały''
    WHEN SrT_Typ = 12 THEN ''WNP''
    ELSE ''Inny'' 
END [Produkt Typ],
CASE 
    WHEN SrT_Stan = 0 THEN ''W użyciu''
    WHEN SrT_Stan = 1 THEN ''Zlikwidowany''
    WHEN SrT_Stan = 2 THEN ''Zbyty''
    ELSE ''Inny''
END [Produkt Stan], 
CASE
    WHEN SrT_Metoda = 0 THEN ''Nie amortyzować''
    WHEN SrT_Metoda = 1 THEN ''Metoda liniowa''
    WHEN SrT_Metoda = 2 THEN ''Metoda degresywna''
    WHEN SrT_Metoda = 3 THEN ''Odpis jednorazowy''
    WHEN SrT_Metoda = 4 THEN ''Metoda naturalna''
    ELSE ''Inna''
END [Metoda Amortyzacji],
isnull(ZakladStr.Zak_Symbol,''(NIEPRZYPISANY)'') as [Produkt Zakład Symbol],
isnull(ZakladStr.zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Produkt Zakład Nazwa Firmy],
isnull(ZakladDok.Zak_Symbol,''(NIEPRZYPISANY)'') as [Dokument Zakład Symbol],
isnull(ZakladDok.zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Dokument Zakład Nazwa Firmy],
 1 [Ilość],
NULL [Produkt Kategoria Amortyzacja], IsNull(kat2.Kat_KodSzczegol,''NIEOKREŚLONA'') [Produkt Kategoria],  
case when SrH_TypDokumentu IN (4,6) THEN NULL else  MAX(SrT_WartoscBilan) END [Wartość Nabycia] , 
case when SrH_TypDokumentu IN (4,6) THEN NULL else MAX(SrT_WartoscKoszt) END [Wartość Nabycia Kosztowa], 
NULL [Koszty Amortyzacji],
case when SrH_TypDokumentu IN (4,6) THEN NULL else SUM(IsNull(h1.SrH_KwotaBilan - h1.SrH_KwotaUm, 0)) END [Wartość Netto], 
case when SrH_TypDokumentU IN (4,6) THEN NULL else SUM(IsNull(h1.SrH_KwotaBilan, 0)) END [Wartość Brutto],
NULL [Wartość w Czasie Netto], NULL [Wartość w Czasie Brutto]
,case when SrH_TypDokumentu IN (4,6) THEN NULL else cast(SrT_Stawka as nvarchar(50)) END [Stawka amortyzacji Kosztowa]
,case when SrH_TypDokumentu IN (4,6) THEN NULL else cast(SrT_StawkaBil as nvarchar(50)) END [Stawka amortyzacji Bilansowa]
,case when SrH_TypDokumentu IN (4,6) THEN NULL else cast(SrT_Wspolczynnik as nvarchar(50)) END [Współczynnik amortyzacji Kosztowy]
,case when SrH_TypDokumentu IN (4,6) THEN NULL else cast(SrT_WspolczynnikBil as nvarchar(50)) END [Współczynnik amortyzacji Bilansowy]
, NULL  [Koszty Amortyzacji Bilansowe]

' + @atrybuty + '
,GETDATE() [Data Analizy]
  ,REPLACE(CONVERT(VARCHAR(10), SrH_DataOpe, 111), ''/'', ''-'') [Data Dokumentu Dzień] 
    ,(datepart(DY, datediff(d, 0, SrH_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataOpe)*/ [Data Dokumentu Tydzień Roku]
    ,MONTH(SrH_DataOpe) [Data Dokumentu Miesiąc], DATEPART(quarter, SrH_DataOpe) [Data Dokumentu Kwartał], YEAR(SrH_DataOpe) [Data Dokumentu Rok] 
FROM CDN.TrwaleHist h1
LEFT OUTER JOIN CDN.Trwale ON h1.SrH_SrTID = SrT_SrTID
LEFT OUTER JOIN CDN.Kategorie kat2 ON kat2.Kat_KatId = SrT_KatId
LEFT JOIN #tmpKonAtr KonAtr ON SrT_SrTID = KonAtr.SrA_SrTId AND SrT_Typ = KonAtr.SrA_Typ

LEFT OUTER JOIN CDN.Zaklady ZakladDok on ZakladDok.ZAK_ZAkID = h1.SrH_ZakID
LEFT OUTER JOIN CDN.Zaklady ZakladStr on ZakladStr.ZAK_ZAkID = SrT_ZakID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0


GROUP BY BAZ.Baz_Nazwa, SrT_Nazwa, SrT_NrInwent, SrT_KRST, SrT_DataPrz, SrT_DataLikw, SrT_Grupa, SrT_Typ, SrT_Stan, SrT_Metoda, kat2.Kat_KodSzczegol, 
ZakladDok.Zak_Symbol,ZakladDok.zak_NazwaFirmy,ZakladStr.Zak_Symbol,ZakladStr.zak_NazwaFirmy,SrT_Stawka,SrT_StawkaBil,SrT_Wspolczynnik,SrT_WspolczynnikBil,
SrH_TypDokumentu,SrH_DataOpe ' + @atrybuty2 + '

UNION ALL

SELECT
BAZ.Baz_Nazwa [Baza Firmowa], Wyp_Nazwa [Produkt Nazwa], Wyp_NrInwent [Produkt Numer Inwentarzowy], ''Nie dotyczy'' [KŚT],
REPLACE(CONVERT(VARCHAR(10), Wyp_DataZak, 111), ''/'', ''-'') [Data Przyjęcia Dzień],
ISNULL(REPLACE(CONVERT(VARCHAR(10), Wyp_DataLikw, 111), ''/'', ''-''), ''W użyciu'') [Data Likwidacji Dzień],
''Nie dotyczy'' [Produkt Grupa], NULL [Data Amortyzacji Rok], NULL [Data Amortyzacji Miesiąc], 
ISNULL((SELECT TOP 1 OO.WyOO_PrcImieNazwisko 
 FROM CDN.WyposazenieOsobyOdpowiedzialne OO 
 WHERE OO.WyOO_WypID = Wyp_WypID
 ORDER BY OO.WyOO_DataOd DESC), ''Nieprzypisany'') [Osoba Odpowiedzialna], 
ISNULL((SELECT TOP 1 MU.WyMU_Nazwa 
 FROM CDN.WyposazenieMiejscaUzytkowania MU 
 WHERE MU.WyMU_WypID = Wyp_WypID 
 ORDER BY MU.WyMU_DataOd DESC), ''Nieprzypisany'') [Miejsce Użytkowania], 
''Wyposażenie'' [Produkt Typ],
CASE 
    WHEN Wyp_Stan = 0 THEN ''W użyciu''
    WHEN Wyp_Stan = 1 THEN ''Zlikwidowany''
    WHEN Wyp_Stan = 2 THEN ''Zbyty''
    ELSE ''Inny''
END [Produkt Stan], 
''Nie dotyczy'' [Metoda Amortyzacji], 
''(NIEPRZYPISANY)'' as [Produkt Zakład Symbol],
''(NIEPRZYPISANY)'' as [Produkt Zakład Nazwa Firmy],
''(NIEPRZYPISANY)'' as [Dokument Zakład Symbol],
''(NIEPRZYPISANY)'' as [Dokument Zakład Nazwa Firmy],

Wyp_Ilosc [Ilość],
NULL [Produkt Kategoria Amortyzacja], IsNull(kat2.Kat_KodSzczegol,''NIEOKREŚLONA'') [Produkt Kategoria],  
Wyp_WartoscZakup [Wartość Nabycia], Wyp_WartoscZakup [Wartość Nabycia Kosztowa], NULL [Koszty Amortyzacji],
Wyp_WartoscZakup [Wartość Netto], Wyp_WartoscZakup [Wartość Brutto],
NULL [Wartość w Czasie Netto], NULL [Wartość w Czasie Brutto]
,cast(''<BRAK>'' as nvarchar(50)) [Stawka amortyzacji Kosztowa]
,cast(''<BRAK>'' as nvarchar(50)) [Stawka amortyzacji Bilansowa]
,cast(''<BRAK>'' as nvarchar(50)) [Współczynnik amortyzacji Kosztowy]
,cast(''<BRAK>'' as nvarchar(50)) [Współczynnik amortyzacji Bilansowy]
, NULL  [Koszty Amortyzacji Bilansowe]

' + @atrybuty + '
,GETDATE() [Data Analizy]
    ,REPLACE(CONVERT(VARCHAR(10), WyP_DataZak, 111), ''/'', ''-'') [Data Dokumentu Dzień] 
    ,(datepart(DY, datediff(d, 0, WyP_DataZak) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataOpe)*/ [Data Dokumentu Tydzień Roku]
    ,MONTH(WyP_DataZak) [Data Dokumentu Miesiąc], DATEPART(quarter, WyP_DataZak) [Data Dokumentu Kwartał], YEAR(WyP_DataZak) [Data Dokumentu Rok] 
 FROM CDN.Wyposazenie
LEFT OUTER JOIN CDN.Kategorie kat2 ON kat2.Kat_KatId = Wyp_KatId
LEFT JOIN #tmpKonAtr KonAtr ON Wyp_WypID  = KonAtr.SrA_SrTId AND 13 = KonAtr.SrA_Typ
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0

'

EXEC(@select)
DROP TABLE #tmpKonAtr





