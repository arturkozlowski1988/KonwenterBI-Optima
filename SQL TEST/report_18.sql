/*
* Raport CRM
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
declare @kolumny varchar(max)
declare @i int

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
             SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.KnA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
               ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.KnA_WartoscTxt,'','',''.'') ELSE ATR.KnA_WartoscTxt END
              END  
             FROM CDN.KntAtrybuty ATR 
             JOIN #tmpKonAtr TM ON ATR.KnA_PodmiotId = TM.KnA_PodmiotId AND ATR.KnA_PodmiotTyp = TM.KnA_PodmiotTyp
             WHERE ATR.KnA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
       EXEC(@sqlA)    
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Pierwotny Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'        
       SET @atrybuty = @atrybuty + N', ISNULL(KonAtr1.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'      
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
WHERE DeA_DeAId in (SELECT DISTINCT DAt_DeAid FROM CDN.DokAtrybuty WHERE DAt_crkId IS NOT NULL)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT DAt_crkId INTO #tmpDokAtr FROM CDN.DokAtrybuty

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
             JOIN #tmpDokAtr TM ON ATR.DAt_crkId = TM.DAt_crkId 
             WHERE ATR.DAt_DeAId = ' + CAST(@atrybut_id AS nvarchar)
       EXEC(@sqlA)    
    
    SET @atrybutyDok = @atrybutyDok + N', ISNULL(DokAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Dokument Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
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

select count(*) as Ilosc, DoR_ParentId
INTO #DokPowiazaneIlosc
from cdn.DokRelacje
WHERE DoR_ParentTyp=700 
GROUP BY  DoR_ParentId

-- 
--Właściwe zapytanie
DECLARE @select varchar(max);
SET @select =
'SELECT  
       BAZ.Baz_Nazwa [Baza Firmowa], 
       pod1.Pod_NIP [Kontrahent Pierwotny NIP],       
       pod1.Pod_Kod [Kontrahent Pierwotny Kod],     
       pod1.Pod_Nazwa1 [Kontrahent Pierwotny Nazwa], 
       pod5.Pod_NIP [Kontrahent NIP],  
       pod5.Pod_Kod [Kontrahent Kod],        
       pod5.Pod_Nazwa1 [Kontrahent Nazwa],        
       k1.CRK_NumerPelny [Dokument Numer],      
       k1.CRK_OsobaNazwisko [Kontrahent Pierwotny Osoba Kontaktowa],
       k1.CRK_OsobaNazwisko [Kontrahent Osoba Kontaktowa],
       k1.CRK_Temat [Dokument Temat], ISNULL(DEt_Kod, ''(NIEPRZYPISANY)'') [Etap Realizacji], COALESCE(NULLIF(pod1.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Pierwotny Grupa],
       COALESCE(NULLIF(pod5.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Grupa],
       CASE 
             WHEN k1.CRK_OpiekunTyp = 3 THEN ISNULL(pod2.Pod_Kod, ''(NIEPRZYPISANY)'')
             WHEN k1.CRK_OpiekunTyp = 8 THEN ISNULL(ope.Ope_Kod, ''(NIEPRZYPISANY)'')
             ELSE ''(NIEPRZYPISANE)'' 
       END [Kontrahent Pierwotny Opiekun],
       CASE 
             WHEN k1.CRK_OpiekunTyp = 3 THEN ISNULL(pod2.Pod_Kod, ''(NIEPRZYPISANY)'')
             WHEN k1.CRK_OpiekunTyp = 8 THEN ISNULL(ope.Ope_Kod, ''(NIEPRZYPISANY)'')
             ELSE ''(NIEPRZYPISANE)'' 
       END [Kontrahent Opiekun],
       isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
       isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],
       CASE
             WHEN k1.CRK_Priorytet = 1 THEN ''Najwyższy'' 
              WHEN k1.CRK_Priorytet = 2 THEN ''Wysoki'' 
             WHEN k1.CRK_Priorytet = 3 THEN ''Niski''
             ELSE ''Najniższy''
       END [Zadanie Priorytet],
       CASE 
             WHEN k1.CRK_Zadanie = 1 THEN ''Zadanie''
             ELSE ''Kontakt''
       END [Rodzaj],
       CASE
             WHEN k1.CRK_Obsluga = 0 THEN ''Przed Sprzedażą''
             ELSE ''Po Sprzedaży''
       END [Obsługa],
       CASE
             WHEN k1.CRK_Bufor = -1 THEN ''Anulowany''
             WHEN k1.CRK_Bufor = 0 THEN ''Zamknięty''
             ELSE ''Niezamknięty''
       END [Dokument Realizacja],
       CASE
             WHEN DATEDIFF(day, k1.CRK_TerminOd, GETDATE()) = 0 THEN ''Dziejsze''
             WHEN DATEDIFF(day, k1.CRK_TerminOd, GETDATE() + 1) = 0 THEN ''Jutrzejsze''
             WHEN DATEDIFF(day, k1.CRK_TerminOd, GETDATE()) > 0 THEN ''Przeterminowane''
             ELSE ''Późniejsze''
       END [Termin Zadania],
       k2.CRK_NumerPelny [Wątek Numer], k2.CRK_Temat [Wątek Temat], 
        REPLACE(CONVERT(VARCHAR(10), k1.CRK_TerminOd, 111), ''/'', ''-'') [Termin Od Dzień], SUBSTRING(CONVERT(VARCHAR,k1.CRK_TerminOd,108),1,5) [Termin Od Godzina],
       REPLACE(CONVERT(VARCHAR(10), k1.CRK_TerminDo, 111), ''/'', ''-'') [Termin Do Dzień], SUBSTRING(CONVERT(VARCHAR,k1.CRK_TerminDo,108),1,5) [Termin Do Godzina],
       (DATEDIFF(mi, CONVERT(DATETIME,''1899-12-30'',120), k1.CRK_CzasKontaktu) +  DATEDIFF(mi, CONVERT(DATETIME,''1899-12-30'',120), k1.CRK_CzasOpracow ) + DATEDIFF(mi, CONVERT(DATETIME,''1899-12-30'',120), k1.CRK_CzasPrzygot))/(24*60) [Czas Kontaktu Dni],
       ((DATEDIFF(mi, CONVERT(DATETIME,''1899-12-30'',120), k1.CRK_CzasKontaktu) +  DATEDIFF(mi, CONVERT(DATETIME,''1899-12-30'',120), k1.CRK_CzasOpracow ) + DATEDIFF(mi, CONVERT(DATETIME,''1899-12-30'',120), k1.CRK_CzasPrzygot))/60)%24 [Czas Kontaktu Godziny],
       (DATEPART(mi, k1.CRK_CzasPrzygot) + DATEPART(mi, k1.CRK_CzasOpracow) + DATEPART(mi, k1.CRK_CzasKontaktu))%60 [Czas Kontaktu Minuty],
       DATEDIFF(day, CONVERT(DATETIME,''1899-12-30'',120), k1.CRK_CzasPrzygot ) [Czas Przygotowania Dni],
       DATEPART(hh, k1.CRK_CzasPrzygot)%24 [Czas Przygotowania Godziny],
       DATEPART(mi, k1.CRK_CzasPrzygot)%60 [Czas Przygotowania Minuty],
       DATEDIFF(day, CONVERT(DATETIME,''1899-12-30'',120), k1.CRK_CzasOpracow ) [Czas Opracowania Dni],
       DATEPART(hh, k1.CRK_CzasOpracow)%24 [Czas Opracowania Godziny],
       DATEPART(mi, k1.CRK_CzasOpracow)%60 [Czas Opracowania Minuty],
       DATEDIFF(day, CONVERT(DATETIME,''1899-12-30'',120), k1.CRK_CzasKontaktu ) [Czas Rozmowy Dni],
       DATEPART(hh, k1.CRK_CzasKontaktu)%24 [Czas Rozmowy Godziny],
       DATEPART(mi, k1.CRK_CzasKontaktu)%60 [Czas Rozmowy Minuty],
       1.0/ISNULL(ilosc,1) [Liczba Dokumentów],
       case when dor_dokumenttyp=700 then k3.crk_numerpelny 
           when dor_dokumenttyp=1007 then srh_numer
           when dor_dokumenttyp=999 then  van_dokument
           when dor_dokumenttyp=900 then srz_numerpelny
           when dor_dokumenttyp=302 then trn_numerpelny
           when dor_dokumenttyp=304 then trn_numerpelny
           when dor_dokumenttyp=303 then trn_numerpelny
             when dor_dokumenttyp=301 then trn_numerpelny
             when dor_dokumenttyp=305 then trn_numerpelny
             when dor_dokumenttyp=320 then trn_numerpelny
             when dor_dokumenttyp=308 then trn_numerpelny
             when dor_dokumenttyp=309 then trn_numerpelny
             when dor_dokumenttyp=322 then trn_numerpelny
             when dor_dokumenttyp=321 then trn_numerpelny
             when dor_dokumenttyp=350 then trn_numerpelny
             when dor_dokumenttyp=345 then trn_numerpelny
             when dor_dokumenttyp=306 then trn_numerpelny
             when dor_dokumenttyp=307 then trn_numerpelny
             when dor_dokumenttyp=304 then trn_numerpelny
             when dor_dokumenttyp=303 then trn_numerpelny
             when dor_dokumenttyp=312 then trn_numerpelny
             when dor_dokumenttyp=310 then trn_numerpelny
             when dor_dokumenttyp=311 then trn_numerpelny
             when dor_dokumenttyp=317 then trn_numerpelny
             when dor_dokumenttyp=318 then trn_numerpelny
             when dor_dokumenttyp=314 then trn_numerpelny
             when dor_dokumenttyp=313 then trn_numerpelny
           else ''Brak Powiązanych''  end  [Dokumenty Powiazane],
       case 
           when dor_dokumenttyp=1007 then convert(float,SrH_KwotaAm)
           when dor_dokumenttyp=999 then  convert(float,van_razemnetto)
           when dor_dokumenttyp=900 then convert(float,srz_wartoscnetto)
             when dor_dokumenttyp=302 then convert(float,trn_razemnetto)
           when dor_dokumenttyp=304 then convert(float,trn_razemnetto)
           when dor_dokumenttyp=303 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=301 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=305 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=320 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=308 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=309 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=322 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=321 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=350 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=345 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=306 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=307 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=304 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=303 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=312 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=310 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=311 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=317 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=318 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=314 then convert(float,trn_razemnetto)
             when dor_dokumenttyp=313 then convert(float,trn_razemnetto)
         else null end [Dokumenty Powiązane Wartość]
       ,CASE when dor_dokumenttyp=700 then 1
             when dor_dokumenttyp=1007 then 1
             when dor_dokumenttyp=999 then  1
             when dor_dokumenttyp=900 then 1
             when dor_dokumenttyp=302 then 1
             when dor_dokumenttyp=304 then 1
             when dor_dokumenttyp=303 then 1
             when dor_dokumenttyp=301 then 1
             when dor_dokumenttyp=305 then 1
             when dor_dokumenttyp=320 then 1
             when dor_dokumenttyp=308 then 1
             when dor_dokumenttyp=309 then 1
             when dor_dokumenttyp=322 then 1
             when dor_dokumenttyp=321 then 1
             when dor_dokumenttyp=350 then 1
             when dor_dokumenttyp=345 then 1
             when dor_dokumenttyp=306 then 1
             when dor_dokumenttyp=307 then 1
             when dor_dokumenttyp=304 then 1
             when dor_dokumenttyp=303 then 1
             when dor_dokumenttyp=312 then 1
             when dor_dokumenttyp=310 then 1
             when dor_dokumenttyp=311 then 1
             when dor_dokumenttyp=317 then 1
             when dor_dokumenttyp=318 then 1
             when dor_dokumenttyp=314 then 1
             when dor_dokumenttyp=313 then 1
     else NULL end  [Dokumenty Powiązane Liczba] 
     ,zal.Ope_Kod [Operator Wprowadzający] 
     ,mod.Ope_Kod [Operator Modyfikujący]
     /*
     ----------DATY POINT
      ,REPLACE(CONVERT(VARCHAR(10), k1.CRK_DataDok, 111), ''/'', ''-'') [Data Dokumentu]
     */
     ----------DATY ANALIZY
      ,REPLACE(CONVERT(VARCHAR(10), k1.CRK_DataDok, 111), ''/'', ''-'') [Data Dokumentu Dzień], (datepart(DY, datediff(d, 0, k1.CRK_DataDok) / 7 * 7 + 3)+6) / 7 [Data Dokumentu Tydzień Roku]
      ,MONTH(k1.CRK_DataDok) [Data Dokumentu Miesiąc], DATEPART(quarter, k1.CRK_DataDok) [Data Dokumentu Kwartał], YEAR(k1.CRK_DataDok) [Data Dokumentu Rok]
      ,GETDATE() [Data Analizy]
     ----------KONTEKSTY
       ,20201 [Kontrahent Pierwotny Kod __PROCID__Kontrahenci__], pod1.Pod_PodId [Kontrahent Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Pierwotny Kod __DATABASE__]
       ,20201 [Kontrahent Pierwotny Nazwa __PROCID__], pod1.Pod_PodId [Kontrahent Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Pierwotny Nazwa __DATABASE__]
       ,20201 [Kontrahent Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Kontrahent Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Kod __DATABASE__]
       ,20201 [Kontrahent Nazwa __PROCID__], pod5.Pod_PodId [Kontrahent Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Nazwa __DATABASE__]
       ,29095 [Dokument Numer __PROCID__Sprzedaz__], k1.CRK_CRKId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    
     ' + @atrybuty + @atrybutyDok + '              
       FROM 
       cdn.CRMKontakty k1 
       JOIN cdn.PodmiotyView pod1 ON pod1.Pod_PodmiotTyp = k1.CrK_PodmiotTyp AND pod1.Pod_PodId = k1.CrK_PodId
       LEFT OUTER JOIN cdn.PodmiotyView pod2 ON CRK_OpiekunId = pod2.Pod_PodId AND k1.CRK_OpiekunTyp = pod2.Pod_PodmiotTyp
       LEFT JOIN ' + @Operatorzy + ' ope ON k1.CRK_OpiekunId = Ope_OpeId AND k1.CRK_OpiekunTyp = 8
       LEFT JOIN CDN.DefEtapy on k1.CRK_EtapRealizacji = DEt_DEtId AND DEt_Typ = 2
       LEFT JOIN cdn.CRMKontakty k2 ON k1.CRK_WatekId = k2.CRK_CRKId    
       LEFT JOIN #tmpKonAtr KonAtr ON pod1.Pod_PodId = KonAtr.KnA_PodmiotId AND pod1.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
       LEFT JOIN #tmpDokAtr DokAtr ON k1.CRK_CRKId  = DokAtr.DAt_crkId
       left join cdn.DokRelacje d1 on d1.DoR_ParentId=k1.Crk_WatekId and d1.DoR_ParentTyp=700 
    left join cdn.tranag on d1.dor_dokumentid=trn_trnid and dor_dokumenttyp <>999  and dor_dokumenttyp <>1007  and dor_dokumenttyp <>900 and dor_dokumenttyp <>700
    left join cdn.vatnag on d1.dor_dokumentid=van_vanid AND dor_dokumenttyp = 999
    left join CDN.TrwaleHist on d1.dor_dokumentid=srh_srhid AND dor_dokumenttyp = 1007
    left join CDN.srszlecenia on d1.dor_dokumentid=srz_srzid AND dor_dokumenttyp = 900
    left join cdn.CRMKontakty k3 on d1.dor_dokumentid=k3.CRK_CRKId AND dor_dokumenttyp = 700
    LEFT JOIN #DokPowiazaneIlosc as dokpowI on dokpowI.DoR_ParentId = k1.Crk_WatekId
    LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod1.Pod_GlID = pod5.Pod_PodId and pod1.Pod_GlKod = pod5.Pod_Kod
    LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
    LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = coalesce(VaN_ZakID,srh_zakID)
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON k1.CRK_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON k1.CRK_OpeModID = mod.Ope_OpeId
    WHERE k1.CRK_Anulowany = 0' 

EXEC(@select)
DROP TABLE #tmpKonAtr
DROP TABLE #tmpDokAtr
DROP TABLE #DokPowiazaneIlosc





