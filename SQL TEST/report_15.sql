/*
* Raport Serwisu
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--Połączenie do tabeli operatorów

DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Operatorzy varchar(max);
DECLARE @Bazy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

Declare @Wal VarChar(3); Set @Wal = cdn.Waluta('')

--Wyliczanie Atrybutów Urządzeń
DECLARE @atrybutySrsU varchar(max), @atrybutySrsU2 varchar(max), @sqlA varchar(max), @atrybut_id int, @atrybut_kod nvarchar(50), @atrybut_typ int, @atrybut_format int;
DECLARE @wersja float;
SET @wersja = (SELECT CONVERT(float, SYS_Wartosc) FROM CDN.SystemCDN WHERE SYS_ID = 3)

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT TwA_DeAid FROM CDN.TwrAtrybuty WHERE TwA_SrUId IS NOT NULL)
AND DeA_Format <> 5'

IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)
OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT TwA_SrUId INTO #tmpUrzAtr 
FROM CDN.TwrAtrybuty
JOIN CDN.SrsUrzadzenia on SrU_SrUId = TwA_SrUId

SET @atrybutySrsU = ''
SET @atrybutySrsU2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
    IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
    SET @sqlA = N'ALTER TABLE #tmpUrzAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpUrzAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TwA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
          ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TwA_WartoscTxt,'','',''.'') ELSE ATR.TwA_WartoscTxt END
        END 
        FROM CDN.TwrAtrybuty ATR 
        JOIN #tmpUrzAtr TM ON ATR.TwA_SrUId  = TM.TwA_SrUId 
        WHERE ATR.TwA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutySrsU = @atrybutySrsU + N', ISNULL(SrsUAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') [Urządzenie Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    SET @atrybutySrsU2 = @atrybutySrsU2 + N', ''(NIEPRZYPISANE)'' [Urządzenie Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END
print @atrybutySrsU
CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

-- atrybuty czynnosci
DECLARE   @atrybutyCzy varchar(max);

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId,DeA_Kod , DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT Tra_DeAId FROM cdn.TraElemAtr)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT TrA_DokId, Tra_Doktyp,TrA_DeAId  INTO #tmpCzyAtr FROM CDN.TraElemAtr 

SET @atrybutyCzy = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sqlA = N'ALTER TABLE #tmpCzyAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpCzyAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.Tra_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
          ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.Tra_Wartosc,'','',''.'') ELSE ATR.Tra_Wartosc END
        END  
        FROM CDN.TraElemAtr ATR 
        JOIN #tmpCzyAtr TM ON ATR.TrA_DokId = TM.TrA_DokId  AND ATR.TrA_DokTyp = TM.TrA_DokTyp AND ATR.TrA_DeAId = TM.TrA_DeAId
        WHERE ATR.TrA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyCzy = @atrybutyCzy + N', ISNULL(cza.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']' 
          
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Wyliczanie Atrybutów Kontrahentów
DECLARE   @atrybuty varchar(max);

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
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Podmiot Pierwotny Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']' 
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr1.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Podmiot Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'  
    SET @atrybuty = @atrybuty + N', ISNULL(Odb.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Odbiorca Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'            
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
WHERE DeA_DeAId in (SELECT DISTINCT DAt_DeAid FROM CDN.DokAtrybuty WHERE DAt_SrZId IS NOT NULL)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT DAt_SrZId INTO #tmpDokAtr FROM CDN.DokAtrybuty

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
        JOIN #tmpDokAtr TM ON ATR.DAt_SrZId = TM.DAt_SrZId 
        WHERE ATR.DAt_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    SET @atrybutyDok = @atrybutyDok + N', ISNULL(DokAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Dokument Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

SELECT COUNT(*) AS IloscAtr, TrA_DokTyp as TYP,TrA_DokId  AS idatr INTO #TmpAtrybutyIlosc FROM cdn.TraElemAtr JOIN CDN.DefAtrybuty on TrA_DeAId =DeA_DeAId where  DeA_AnalizyBI = 1  GROUP BY TrA_DokTyp,TrA_DokId

select  DoR_ParentID, TrE_TwrId, count(*)  as Ilosc
INTO #DokPowiazaneIlosc
from cdn.DokRelacje
JOIN cdn.TraNag ON TrN_TypDokumentu = DoR_DokumentTyp AND 
TrN_TrNId = DoR_DokumentId
JOIN
(select TrE_TrNId,TrE_TwrId, count(*) iloscd
FROM CDN.TraElem
GROUP BY TrE_TrNId,TrE_TwrId
)x on x.TrE_TrNId =TrN_TrNID
WHERE DoR_ParentTyp =900
GROUP BY  DoR_ParentId, TrE_TwrId

--Właściwe zapytanie
DECLARE @select varchar(max);
set @select = 
'SELECT

BAZ.Baz_Nazwa [Baza Firmowa],
''Czynność'' [Produkt Typ],
CASE
    WHEN SrY_SerwisantTyp = 3 THEN ISNULL(p1.PRA_Kod, ''(NIEPRZYPISANE)'')
    WHEN SrY_SerwisantTyp = 8 THEN ISNULL(o1.Ope_Kod, ''(NIEPRZYPISANE)'')
    ELSE ''(NIEPRZYPISANE)''
END [Serwisant Kod], 
ISNULL(SrY_TwrKod,Twr_Kod) [Produkt Kod], ISNULL(SrY_TwrNazwa,Twr_Nazwa) [Produkt Nazwa],
ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
CAST(Twr_Opis as VARCHAR(1024)) [Produkt Opis],
CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny], 
Mag_Symbol [Magazyn Kod],
SrZ_NumerPelny [Dokument Zlecenia Numer], SrZ_Opis [Dokument Zlecenia Opis], 
CASE WHEN (SrY_Fakturowac = 0 AND SrZ_ZbiorczeFaCzesci = 0) THEN ''NIE'' ELSE ''TAK'' END  [Produkt Fakturowanie],
Sry_Lp AS [Produkt Lp],
CASE
    WHEN SrZ_Stan = 0 THEN ''Do Realizacji''
    WHEN SrZ_Stan = 1 THEN ''W Realizacji''
    WHEN SrZ_Stan = 2 THEN ''Zrealizowane''
END [Dokument Zlecenia Stan],
CASE
    WHEN SrZ_ProwadzacyTyp = 3 THEN ISNULL(p2.PRA_Kod, ''(NIEPRZYPISANE)'')
    WHEN SrZ_ProwadzacyTyp = 8 THEN ISNULL(o2.Ope_Kod, ''(NIEPRZYPISANE)'')
    ELSE ''(NIEPRZYPISANE)''
END [Opiekun Kod], 
ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Dokument Zlecenia Kategoria Szczegółowa], ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Dokument Zlecenia Kategoria Ogólna],
pod1.Pod_Nazwa1 [Podmiot Pierwotny Nazwa], pod1.Pod_Kod [Podmiot Pierwotny Kod], 
pod5.Pod_Nazwa1 [Podmiot Nazwa], pod5.Pod_Kod [Podmiot Kod], 
CONVERT(DECIMAL(10,4),(SrY_WartoscNettoPLN/ISNULL(dokPow.Ilosc, 1)/ISNULL(il.iloscAtr,1))) [Wartość Netto], 
CONVERT(DECIMAL(10,4),(SrY_WartoscBruttoPLN/ISNULL(dokPow.Ilosc, 1)/ISNULL(il.iloscAtr,1))) [Wartość Brutto], 
CONVERT(DECIMAL(10,4),(SrY_WartoscNetto/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Wartość Netto Waluta],
CONVERT(DECIMAL(10,4),( SrY_WartoscBrutto/ISNULL(dokPow.Ilosc, 1)/ISNULL(il.iloscAtr,1))) [Wartość Brutto Waluta], 
CASE when isnull(SrY_Waluta,'''')='''' THEN '''+@wal+''' ELSE SrY_Waluta END [Waluta],
CONVERT(DECIMAL(10,4),(SrY_Ilosc/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Ilość], 
NULL [Ilość Pobrana],
NULL [Ilość Wydana],
CONVERT(DECIMAL(10,4),(SrY_KosztUslugi/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Koszt Własny], 
CONVERT(DECIMAL(10,4),((SrY_WartoscNetto - SrY_KosztUslugi)/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Marża Netto],
ISNULL(SrY_TwrKod,Twr_Kod) [Częstotliwość],

CASE WHEN SrY_Zakonczona = 0 THEN ''NIE'' ELSE ''TAK'' END [Czynność Zakończona],
ISNULL(REPLACE(CONVERT(VARCHAR(10), SrY_DataWykonania, 111), ''/'', ''-''), ''(BRAK)'') [Data Realizacji Czynności],
REPLACE(CONVERT(VARCHAR(10), SrY_TerminOd, 111), ''/'', ''-'') [Data Rozpoczęcia Czynności], 
REPLACE(CONVERT(VARCHAR(10), SrY_TerminDo, 111), ''/'', ''-'') [Data Zakończenia Czynności],
CONVERT (DECIMAL(15,2), (DATEDIFF(day, CONVERT(DATETIME,''1899-12-30'',120), SrY_CzasTrwania ) * 24 * 60
+ DATEPART(hh, SRY_CzasTrwania)*60 + DATEPART(mi, SrY_CzasTrwania) )/ISNULL(dokPow.Ilosc, 1)/ISNULL(il.iloscAtr, 1) ,2)[Czas Trwania Czynności],
sru_kod [Urządzenie Kod],
sru_nazwa [Urządzenie Nazwa], 
SrR_Kod [Urządzenie Rodzaj] 
,pod6.Pod_Nazwa1 as [Odbiorca Nazwa] 
,pod6.Pod_Kod  as [Odbiorca Kod] 

,SrZ_ZlecajacyNazwisko [Osoba Zlecająca Nazwa]
,SrZ_ZlecajacyTelefon [Osoba Zlecająca Telefon]
,''Nie Dotyczy'' [Status Pobrania]
,''Nie Dotyczy'' [Status Wydania]
,''Nie Dotyczy'' [Fakturować]
,DEt_Kod [Dokument Zlecenia Status]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]

/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataPrzyjecia, 111), ''/'', ''-'') [Data Przyjęcia Zlecenia] 
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataRealizacji, 111), ''/'', ''-'') [Data Realizacji Zlecenia] 
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataZamkniecia, 111), ''/'', ''-'') [Data Zamknięcia Zlecenia] 
*/
----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataPrzyjecia, 111), ''/'', ''-'') [Data Przyjęcia Zlecenia Dzień] 
,MONTH(SrZ_DataPrzyjecia) [Data Przyjęcia Zlecenia Miesiąc], (datepart(DY, datediff(d, 0, SrZ_DataPrzyjecia) / 7 * 7 + 3)+6) / 7 [Data Przyjęcia Zlecenia Tydzień Roku] 
,DATEPART(quarter, SrZ_DataPrzyjecia) AS [Data Przyjęcia Zlecenia Kwartał], YEAR(SrZ_DataPrzyjecia) [Data Przyjęcia Zlecenia Rok]
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataRealizacji, 111), ''/'', ''-'') [Data Realizacji Zlecenia Dzień] 
,MONTH(SrZ_DataRealizacji) [Data Realizacji Zlecenia Miesiąc], (datepart(DY, datediff(d, 0, SrZ_DataRealizacji) / 7 * 7 + 3)+6) / 7 [Data Realizacji Zlecenia Tydzień Roku] 
,DATEPART(quarter, SrZ_DataRealizacji) AS [Data Realizacji Zlecenia Kwartał], YEAR(SrZ_DataRealizacji) [Data Realizacji Zlecenia Rok] 
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataZamkniecia, 111), ''/'', ''-'') [Data Zamknięcia Zlecenia Dzień] 
,MONTH(SrZ_DataZamkniecia) [Data Zamknięcia Zlecenia Miesiąc], (datepart(DY, datediff(d, 0, SrZ_DataZamkniecia) / 7 * 7 + 3)+6) / 7 [Data Zamknięcia Zlecenia Tydzień Roku]
,DATEPART(quarter, SrZ_DataZamkniecia) AS [Data Zamknięcia Zlecenia Kwartał], YEAR(SrZ_DataZamkniecia) [Data Zamknięcia Zlecenia Rok]
,GETDATE() [Data Analizy]
,TrN_NumerPelny [Dokument Powiązany Numer],
CDN.TypDokumentu(TrN_TypDokumentu)  [Dokument Powiązany Typ]
' + @atrybutySrsU + @atrybuty + @atrybutyDok  + @atrybutyCzy + 
'

FROM CDN.SrSZlecenia
JOIN CDN.SrSCzynnosci ON SrZ_SrZId = SrY_SrZId
LEFT JOIN CDN.Towary ON SrY_TwrId = Twr_TwrId
LEFT JOIN CDN.PracKod p1 ON (SrY_SerwisantId = p1.Pra_PraId AND SrY_SerwisantTyp  = 3)
LEFT JOIN ' + @Operatorzy + ' o1 ON (SrY_SerwisantID = o1.Ope_OpeId AND SrY_SerwisantTyp = 8)
LEFT JOIN CDN.PracKod p2 ON (SrZ_ProwadzacyId = p2.Pra_PraId AND SrZ_ProwadzacyTyp  = 3)
LEFT JOIN ' + @Operatorzy + ' o2 ON (SrZ_ProwadzacyID = o2.Ope_OpeId AND SrZ_ProwadzacyTyp = 8)
LEFT JOIN CDN.Kategorie kat1 ON SrZ_KatID=kat1.Kat_KatID
LEFT JOIN CDN.PodmiotyView pod1 ON SrZ_PodmiotId= pod1.Pod_PodId AND Srz_PodmiotTyp = pod1.Pod_PodmiotTyp
LEFT JOIN CDN.Magazyny ON SrZ_MagId = Mag_MagId
LEFT JOIN CDN.SrsUrzadzenia on SrZ_SrUId = SrU_SrUId
LEFT JOIN CDN.SrsRodzajeU on SrR_SrRId = SrU_SrRId
LEFT JOIN #tmpUrzAtr as SrsUAtr on SrsUAtr.TwA_SrUId = SrU_SrUId
LEFT JOIN #tmpKonAtr KonAtr ON pod1.Pod_PodId = KonAtr.KnA_PodmiotId AND pod1.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
LEFT JOIN #tmpDokAtr DokAtr ON SrZ_SrZId  = DokAtr.DAt_SrZId
left join cdn.defetapy on srz_etapid=DEt_DEtId
LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod1.Pod_GlID = pod5.Pod_PodId and pod1.Pod_GlKod = pod5.Pod_Kod
LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
LEFT OUTER JOIN cdn.PodmiotyView pod6 on  SrZ_OdbID = pod6.Pod_PodId and SrZ_OdbiorcaTyp = pod6.Pod_PodmiotTyp
LEFT JOIN #tmpKonAtr Odb ON pod6.Pod_PodId = Odb.KnA_PodmiotId AND pod6.Pod_PodmiotTyp = Odb.KnA_PodmiotTyp
LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
LEFT JOIN (
    select  DoR_ParentID, TrE_TwrId, TrN_NumerPelny , TrN_TypDokumentu, TrN_Opis
    from cdn.DokRelacje
    JOIN cdn.TraNag ON TrN_TypDokumentu = DoR_DokumentTyp AND 
    TrN_TrNId = DoR_DokumentId
    JOIN CDN.TraElem ON 
     TrE_TrNId = TrN_TrNID
    WHERE DoR_ParentTyp = 900
) dokPowiazane ON dokPowiazane.DoR_ParentID = SrZ_SrZId 
    AND dokPowiazane.TrE_TwrId = SrY_TwrId
LEFT JOIN  #DokPowiazaneIlosc dokPow ON dokPow.DoR_ParentId = dokPowiazane.DoR_ParentID AND dokPow.TrE_TwrId = twr_twrid
    AND dokPow.TrE_TwrId = SrY_TwrId
        LEFT JOIN #tmpCzyAtr  cza ON SrY_sryid = cza.TrA_DOKID AND cza.TrA_DokTyp = 901
        LEFT JOIN #TmpAtrybutyIlosc il on il.idatr = SrY_sryid and il.TYP = 901
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
        LEFT JOIN ' + @Operatorzy + ' zal ON Twr_OpeZalID = zal.Ope_OpeId
        LEFT JOIN ' + @Operatorzy + ' mod ON Twr_OpeModID = mod.Ope_OpeId
        WHERE SrZ_DataPrzyjecia BETWEEN convert(datetime,''' + convert(varchar, @Dataod, 120) + ''', 120) and convert(datetime,''' + convert(varchar, @DataDO, 120) + ''', 120)

UNION
 
SELECT

BAZ.Baz_Nazwa [Baza Firmowa],
''Część'' [Produkt Typ],
CASE
    WHEN SrC_SerwisantTyp = 3 THEN ISNULL(p1.PRA_Kod, ''(NIEPRZYPISANE)'')
    WHEN SrC_SerwisantTyp = 8 THEN ISNULL(o1.Ope_Kod, ''(NIEPRZYPISANE)'')
    ELSE ''(NIEPRZYPISANE)''
END [Serwisant Kod], 
ISNULL(SrC_TwrKod,Twr_Kod) [Produkt Kod], ISNULL(SrC_TwrNazwa,Twr_Nazwa) [Produkt Nazwa],
ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
CAST(Twr_Opis as VARCHAR(1024)) [Produkt Opis],
CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny], 
Mag_Symbol [Magazyn Kod],
SrZ_NumerPelny [Dokument Zlecenia Numer], SrZ_Opis [Dokument Zlecenia Opis], 
CASE WHEN (SrC_Fakturowac = 0 AND SrZ_ZbiorczeFaCzesci = 0) THEN ''NIE'' ELSE ''TAK'' END [Produkt Fakturowanie],
Src_Lp AS [Produkt Lp],
CASE
    WHEN SrZ_Stan = 0 THEN ''Do Realizacji''
    WHEN SrZ_Stan = 1 THEN ''W Realizacji''
    WHEN SrZ_Stan = 2 THEN ''Zrealizowane''
END [Dokument Zlecenia Stan],
CASE
    WHEN SrZ_ProwadzacyTyp = 3 THEN ISNULL(p2.PRA_Kod, ''(NIEPRZYPISANE)'')
    WHEN SrZ_ProwadzacyTyp = 8 THEN ISNULL(o2.Ope_Kod, ''(NIEPRZYPISANE)'')
    ELSE ''(NIEPRZYPISANE)''
END [Opiekun Kod], 
ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Dokument Zlecenia Kategoria Szczegółowa], ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Dokument Zlecenia Kategoria Ogólna],
pod1.Pod_Nazwa1 [Podmiot Pierwotny Nazwa], pod1.Pod_Kod [Podmiot Pierwotny Kod], 
pod5.Pod_Nazwa1 [Podmiot Nazwa], pod5.Pod_Kod [Podmiot Kod], 
CONVERT(DECIMAL(10,4),(SrC_WartoscNettoPLN/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Wartość Netto], 
CONVERT(DECIMAL(10,4),(SrC_WartoscBruttoPLN/ISNULL(dokPow.Ilosc, 1)/ISNULL(il.iloscAtr,1))) [Wartość Brutto], 
CONVERT(DECIMAL(10,4),(SrC_WartoscNetto/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Wartość Netto Waluta],
CONVERT(DECIMAL(10,4),( SrC_WartoscBrutto/ISNULL(dokPow.Ilosc, 1)/ISNULL(il.iloscAtr,1))) [Wartość Brutto Waluta], 
CASE when isnull(SrC_Waluta,'''')='''' THEN '''+@wal+''' ELSE SrC_Waluta END [Waluta],
CONVERT(DECIMAL(10,4),(SrC_Ilosc/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Ilość],
CONVERT(DECIMAL(10,4),(SrC_IloscPobieranaDisp/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Ilość Pobrana],
CONVERT(DECIMAL(10,4),(SRC_IloscWydanaDisp/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Ilość Wydana],
CONVERT(DECIMAL(10,4), (SrC_WartoscZakupu/ISNULL(dokPow.Ilosc, 1) /ISNULL(il.iloscAtr,1)))[Koszt Własny], 
CONVERT(DECIMAL(10,4), ((SrC_WartoscNetto - SrC_WartoscZakupu)/ISNULL(dokPow.Ilosc, 1)/ISNULL(il.iloscAtr,1))) [Marża Netto],
ISNULL(SrC_TwrKod,Twr_Kod) [Częstotliwość],

''Nie Dotyczy'' [Czynność Zakończona],
''Nie Dotyczy'' [Data Realizacji Czynności],
''Nie Dotyczy'' [Data Rozpoczęcia Czynności] ,
''Nie Dotyczy'' [Data Zakończenia Czynności],
NULL [Czas Trwania Czynności],
sru_kod [Urządzenie Kod],
sru_nazwa [Urządzenie Nazwa], 
SrR_Kod [Urządzenie Rodzaj] 
,pod6.Pod_Nazwa1 as [Odbiorca Nazwa] 
,pod6.Pod_Kod  as [Odbiorca Kod] 
,SrZ_ZlecajacyNazwisko [osoba Zlecająca Nazwa]
,SrZ_ZlecajacyTelefon [Osoba Zlecająca Telefon]
,CASE SrC_Status
WHEN 0 THEN ''Nie pobrano''
WHEN 1 THEN ''Pobrano''
WHEN 2 THEN ''Nie pobrano, zamówiono''
WHEN 3 THEN ''Pobrano, zamówiono'' END [Status pobrania],
CASE WHEN CDN.TeRStatusString(902, Src_srcID, 0) Like ''%WZ''
THEN
''WZ''
ELSE 
''Nie wydano''END
 [Status Wydania]
 ,CASE SrC_Fakturowac 
WHEN 0 THEN ''Nie''
ELSE ''Tak'' END [Fakturować]
,DEt_Kod [Dokument Zlecenia Status]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]

/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataPrzyjecia, 111), ''/'', ''-'') [Data Przyjęcia Zlecenia] 
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataRealizacji, 111), ''/'', ''-'') [Data Realizacji Zlecenia] 
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataZamkniecia, 111), ''/'', ''-'') [Data Zamknięcia Zlecenia]
*/
----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataPrzyjecia, 111), ''/'', ''-'') [Data Przyjęcia Zlecenia Dzień] 
,MONTH(SrZ_DataPrzyjecia) [Data Przyjęcia Zlecenia Miesiąc], (datepart(DY, datediff(d, 0, SrZ_DataPrzyjecia) / 7 * 7 + 3)+6) / 7 [Data Przyjęcia Zlecenia Tydzień Roku]
,DATEPART(quarter, SrZ_DataPrzyjecia) AS [Data Przyjęcia Zlecenia Kwartał], YEAR(SrZ_DataPrzyjecia) [Data Przyjęcia Zlecenia Rok]
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataRealizacji, 111), ''/'', ''-'') [Data Realizacji Zlecenia Dzień] 
,MONTH(SrZ_DataRealizacji) [Data Realizacji Zlecenia Miesiąc], (datepart(DY, datediff(d, 0, SrZ_DataRealizacji) / 7 * 7 + 3)+6) / 7 [Data Realizacji Zlecenia Tydzień Roku]
,DATEPART(quarter, SrZ_DataRealizacji) AS [Data Realizacji Zlecenia Kwartał], YEAR(SrZ_DataRealizacji) [Data Realizacji Zlecenia Rok] 
,REPLACE(CONVERT(VARCHAR(10), SrZ_DataZamkniecia, 111), ''/'', ''-'') [Data Zamknięcia Zlecenia Dzień]
,MONTH(SrZ_DataZamkniecia) [Data Zamknięcia Zlecenia Miesiąc], (datepart(DY, datediff(d, 0, SrZ_DataZamkniecia) / 7 * 7 + 3)+6) / 7 [Data Zamknięcia Zlecenia Tydzień Roku]
,DATEPART(quarter, SrZ_DataZamkniecia) AS [Data Zamknięcia Zlecenia Kwartał], YEAR(SrZ_DataZamkniecia) [Data Zamknięcia Zlecenia Rok]
,GETDATE() [Data Analizy]
,TrN_NumerPelny [Dokument Powiązany Numer],
CDN.TypDokumentu(TrN_TypDokumentu)  [Dokument Powiązany Typ]
' + @atrybutySrsU + @atrybuty + @atrybutyDok + @atrybutyCzy +
'

FROM CDN.SrSZlecenia
JOIN CDN.SrSCzesci ON SrZ_SrZId = SrC_SrZId
LEFT JOIN CDN.Towary ON SrC_TwrId = Twr_TwrId
LEFT JOIN CDN.PracKod p1 ON (SrC_SerwisantId = p1.Pra_PraId AND SrC_SerwisantTyp  = 3)
LEFT JOIN ' + @Operatorzy + ' o1 ON (SrC_SerwisantId = o1.Ope_OpeId AND SrC_SerwisantTyp = 8)
LEFT JOIN CDN.PracKod p2 ON (SrZ_ProwadzacyId = p2.Pra_PraId AND SrZ_ProwadzacyTyp  = 3)
LEFT JOIN ' + @Operatorzy + ' o2 ON (SrZ_ProwadzacyID = o2.Ope_OpeId AND SrZ_ProwadzacyTyp = 8)
LEFT JOIN CDN.Kategorie kat1 ON SrZ_KatID=kat1.Kat_KatID
LEFT JOIN CDN.PodmiotyView pod1 ON SrZ_PodmiotId= pod1.Pod_PodId AND Srz_PodmiotTyp = pod1.Pod_PodmiotTyp
LEFT JOIN CDN.Magazyny ON SrC_MagId = Mag_MagId
LEFT JOIN CDN.SrsUrzadzenia on SrZ_SrUId = SrU_SrUId
LEFT JOIN CDN.SrsRodzajeU as rodzurz on SrR_SrRId = SrU_SrRId
LEFT JOIN #tmpUrzAtr as SrsUAtr on SrsUAtr.TwA_SrUId = SrU_SrUId
LEFT JOIN #tmpKonAtr KonAtr ON pod1.Pod_PodId = KonAtr.KnA_PodmiotId AND pod1.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
LEFT JOIN #tmpDokAtr DokAtr ON SrZ_SrZId  = DokAtr.DAt_SrZId
left join cdn.defetapy on srz_etapid=DEt_DEtId
LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod1.Pod_GlID = pod5.Pod_PodId and pod1.Pod_GlKod = pod5.Pod_Kod
LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
LEFT OUTER JOIN cdn.PodmiotyView pod6 on  SrZ_OdbID = pod6.Pod_PodId and SrZ_OdbiorcaTyp = pod6.Pod_PodmiotTyp
LEFT JOIN #tmpKonAtr Odb ON pod6.Pod_PodId = Odb.KnA_PodmiotId AND pod6.Pod_PodmiotTyp = Odb.KnA_PodmiotTyp
LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
LEFT JOIN (
    select  DoR_ParentID, TrE_TwrId, TrN_NumerPelny , TrN_TypDokumentu, TrN_Opis, tre_treid
    from cdn.DokRelacje
    JOIN cdn.TraNag ON TrN_TypDokumentu = DoR_DokumentTyp AND 
    TrN_TrNId = DoR_DokumentId
    JOIN CDN.TraElem ON 
     TrE_TrNId = TrN_TrNID
    WHERE DoR_ParentTyp = 900
) dokPowiazane ON dokPowiazane.DoR_ParentID = SrZ_SrZId
    AND dokPowiazane.TrE_TwrId = SrC_TwrId 
LEFT JOIN  #DokPowiazaneIlosc dokPow ON dokPow.DoR_ParentId = dokPowiazane.DoR_ParentID 
    AND dokPow.TrE_TwrId = SrC_TwrId AND dokPow.TrE_TwrId = twr_twrid
        LEFT JOIN #tmpCzyAtr  cza ON SrC_srcid = cza.TrA_DOKID AND cza.TrA_DokTyp = 902
    LEFT JOIN #TmpAtrybutyIlosc il on il.idatr = SrC_srcid and il.TYP = 902
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON Twr_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON Twr_OpeModID = mod.Ope_OpeId
    WHERE SrZ_DataPrzyjecia BETWEEN convert(datetime,''' + convert(varchar, @Dataod, 120) + ''', 120) and convert(datetime,''' + convert(varchar, @DataDO, 120) + ''', 120)
'

PRINT(@select);
EXEC(@select);
DROP TABLE #tmpUrzAtr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpDokAtr
DROP TABLE #DokPowiazaneIlosc
DROP TABLE #TmpAtrybutyIlosc
DROP TABLE #tmpCzyAtr













