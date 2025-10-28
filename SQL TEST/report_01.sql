/*
* Raport Płatności 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.5.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--Wyliczanie Atrybutów Kontrahentów
DECLARE @atrybut_id int, @atrybut_kod nvarchar(50), @atrybut_typ int, @atrybut_format int, @atrybuty varchar(max), @atrybuty2 varchar(max), @sqlA nvarchar(max);

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
SET @atrybuty2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 1 BEGIN SET @atrybut_kod = @atrybut_kod + ' (T)' END
    IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
    SET @sqlA = N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpKonAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.KnA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'')  
          ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.KnA_WartoscTxt,'','',''.'') ELSE ATR.KnA_WartoscTxt END 
        END  
        FROM CDN.KntAtrybuty ATR 
        JOIN #tmpKonAtr TM ON ATR.KnA_PodmiotId = TM.KnA_PodmiotId AND ATR.KnA_PodmiotTyp = TM.KnA_PodmiotTyp
        WHERE ATR.KnA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Podmiot Pierwotny Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    SET @atrybuty2 = @atrybuty2 + N', [Podmiot Pierwotny Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr1.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Podmiot Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    SET @atrybuty2 = @atrybuty2 + N', [Podmiot Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'  
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Wyliczanie Atrybutów Dokumentów
DECLARE @atrybutyDok varchar(max), @atrybutyDok2 varchar(max);

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT DAt_DeAid FROM CDN.DokAtrybuty WHERE (DAt_TrNId IS NOT NULL) OR (DAt_VaNId IS NOT NULL))
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT * INTO #tmpDokAtr FROM
(SELECT DISTINCT DAt_TrNId FROM CDN.DokAtrybuty WHERE DAt_TrNId IS NOT NULL
UNION
SELECT DISTINCT DAt_VanId FROM CDN.DokAtrybuty WHERE DAt_VanId IS NOT NULL) a

SET @atrybutyDok = ''
SET @atrybutyDok2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
    IF @atrybut_typ = 1 BEGIN SET @atrybut_kod = @atrybut_kod + ' (T)' END
    SET @sqlA = N'ALTER TABLE #tmpDokAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpDokAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.DAt_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
          ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.DAt_WartoscTxt,'','',''.'') ELSE ATR.DAt_WartoscTxt END        
          END  
        FROM CDN.DokAtrybuty ATR 
        JOIN #tmpDokAtr TM ON COALESCE(ATR.DAt_TrNId,ATR.DAt_VaNId) = TM.DAt_TrNId 
        WHERE ATR.DAt_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyDok = @atrybutyDok + N', ISNULL(DokAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Dokument Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    SET @atrybutyDok2 = @atrybutyDok2 + N', [Dokument Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    
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
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 

--Tworzenie tabeli z serią dokumentów
SELECT DDf_DDfID, CASE 
     WHEN DDf_Numeracja like '@rejestr%' THEN 5
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 1) = '@rejestr' THEN 1
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 2) = '@rejestr' THEN 2
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 3) = '@rejestr' THEN 3
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 4) = '@rejestr' THEN 4
END [seria]  INTO #tmpSeria FROM CDN.DokDefinicje

--Liczba zapisów na raport
SELECT BZp_BRpID IDRaportu, COUNT(*) LiczbaZ
into #ZapisyLiczba
FROM 
cdn.BnkZapisy
LEFT JOIN CDN.BnkRaporty R1 ON BZp_BRpID = R1.BRp_BRpID
GROUP BY BZp_BRpID

--Właściwe zapytanie

DECLARE @select VARCHAR(MAX);


SELECT * INTO #TmpPrzeciw FROM (
SELECT 
BRKV_Numer1 Numer
,BRKV_Numer2 NumerPrz
,BRKV_PodmiotTyp1 PodTyp
,BRKV_PodmiotID1 PodId
,BRKV_Dokid1 DokId
,BRKV_Kwota1 Kwota
,BRKV_KwotaSys1 KwotaSys
,BRKV_KwotaRozSys1 KwotaRozSys
,BRKV_KwotaRozSys1 * (BRKV_KursM1/isnull(nullif(BRKV_KursL1,0),1)) KwotaRoz
FROM CDN.BnkRozKwotyView
UNION
SELECT 
BRKV_Numer2 
,BRKV_Numer1
,BRKV_PodmiotTyp2 PodTyp
,BRKV_PodmiotID2 PodId
,BRKV_Dokid2 DokId
,BRKV_Kwota2
,BRKV_KwotaSys2
,BRKV_KwotaRozSys2
,BRKV_KwotaRozSys2 * (BRKV_KursM2/isnull(nullif(BRKV_KursL2,0),1)) KwotaRoz
FROM CDN.BnkRozKwotyView
)x

SELECT COUNT(*) ilosc, Numer as Numer1,DokId dokid1 into #tmpIlosc from #TmpPrzeciw group by Numer,DokId

SET @select =' 
Declare @Wal VarChar(3); Set @Wal = cdn.Waluta('''')

SELECT 
"BO Rachunku Waluta" = borachunekwal,
"Waluta BO" = bowaluta,
    "Baza Firmowa" = bf, 
    "Zapisy/Zdarzenia" = zap,
    
    "Dokument Numer" = nr,
    "Dokument Symbol" = sy,  
    "Dokument Numer Pełny" = nrPelny, 
    "Dokument Opis" = op, 
    "Dokument MPP" = CASE mpp WHEN 1 THEN ''Tak'' ELSE ''Nie'' END,

    ds [Dokument Seria],
    Waluta = waluta, "Status" = sta, "Forma Płatności" = fp,
    "Raport KB" = raport, "BO Raportu" = boraportu, "BO Rachunku" = borachunku, "Raport KB Stan" = stanraportu, 

    "Dokument Ponaglenia Numer" = nrpon,
    "Dokument Ponaglenia Data Wystawienia" = datpon,
    
    "Podmiot Pierwotny Nazwa" = kon, 
    "Podmiot Pierwotny Kod" = konKod, 
    "Podmiot Pierwotny Typ" = konTyp, "Podmiot Pierwotny Rodzaj" = konRodz, "Podmiot Pierwotny Status" = konStatus,
    "Podmiot Pierwotny Grupa" = konGrupa, "Podmiot Pierwotny Opiekun" = konOpie,
    "Planowane/Zrealizowane" = zz, Rejestr = rachunek,"Rejestr Akronim" = rachAkronim, "Rejestr Symbol" = rachSymbol, "Kategoria Szczegółowa" = kat, "Kategoria Ogólna" = kat2, "Podmiot Pierwotny Województwo" = woj, 
    "Podmiot Pierwotny Miasto" = miasto,
    "Podmiot Pierwotny Kraj" = kraj,
    "Podmiot Pierwotny NIP" = nip,
    [Podmiot Nazwa],
    [Podmiot Kod], 
    [Podmiot Województwo], [Podmiot Miasto], [Podmiot Kraj], [Podmiot NIP],
    [Podmiot Grupa],  [Podmiot Kategoria], [Podmiot Opiekun], [Podmiot Status],
    [Podmiot Rodzaj], [Podmiot Typ],
    zakladSymbol as [Zakład Symbol],
    zakladNazwa as [Zakład Nazwa Firmy],
    opewkod as [Operator Wystawiający Kod],
    opewnazwa as [Operator Wystawiający Nazwa],
    opemkod as [Operator Modyfikujący Kod],
    opemnazwa as [Operator Modyfikujący Nazwa],
    "Stan" = stan, "Data Dokumentu" = dataD, "Data Rozliczenia" = dataRO, 
    "Data Realizacji" = dataRE, 
    "Termin Zapadalności" = termin, "Liczba Dni Przeterminowania" = liczbaDniP,
    "Przychód" = przychod/Isnull(ilosc,1), "Rozchód" = rozchod/Isnull(ilosc,1), "Przychód Waluta" = przychodWal/Isnull(ilosc,1), "Rozchód Waluta" = rozchodWal/Isnull(ilosc,1), 
    Saldo = (ISNULL(przychod,0) - ISNULL(rozchod,0)) /Isnull(ilosc,1), "Saldo Waluta" = (ISNULL(przychodWal,0) - ISNULL(rozchodWal,0))/Isnull(ilosc,1),
    "Przychód Nierozliczony" = (przychod/Isnull(ilosc,1)) - przychodNRoz, "Rozchód Nierozliczony" = (rozchod/Isnull(ilosc,1))-rozchodNRoz, "Saldo Nierozliczone" = ISNULL((przychod/Isnull(ilosc,1)) - przychodNRoz,0) - ISNULL((rozchod/Isnull(ilosc,1))-rozchodNRoz,0),
    "Przychód Nierozliczony Waluta" = (przychodWal/Isnull(ilosc,1)) - przychodNRozWal, "Rozchód Nierozliczony Waluta" = (rozchodWal/Isnull(ilosc,1))-rozchodNrozWal, "Saldo Nierozliczone Waluta" = ISNULL((przychodWal/Isnull(ilosc,1)) - przychodNRozWal,0) - ISNULL((rozchodWal/Isnull(ilosc,1))-rozchodNRozWal,0)
    ,"Różnica Kursowa Raportu" = RKursowaRaportu
    ,"Dokument Przeciwstawny" = DokPrz
    /*
    ----------DATY POINT
    ,"Termin Płatności" = REPLACE(CONVERT(VARCHAR(10), dataT, 111), ''/'', ''-'')
    ,"Data Operacji" = data
    */

    ----------DATY ANALIZY
    ,"Termin Płatności Dzień" = REPLACE(CONVERT(VARCHAR(10), dataT, 111), ''/'', ''-'')
    ,"Termin Płatności Miesiąc" =  MONTH(dataT)
    ,"Termin Płatności Kwartał" = DATEPART(quarter, dataT)
    ,"Termin Płatności Rok" = YEAR(dataT)
    ,"Data Operacji Dzień" = data
    ,"Data Operacji Miesiąc" = miesiac, "Data Operacji Kwartał" = kwartal
    ,"Data Operacji Rok" = rok, "Data Operacji Tydzień Roku" = tr
    ,"Data Analizy" = analizadata
    ----------KONTEKSTY
    ,nr_procid [Dokument Numer __PROCID__Platnosci__], nr_orgid [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,kon_procid [Podmiot Pierwotny Nazwa __PROCID__], kon_orgid [Podmiot Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Nazwa __DATABASE__]
    ,kon_procid [Podmiot Pierwotny Kod __PROCID__], kon_orgid [Podmiot Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__]
    ,[Podmiot Nazwa __PROCID__],  [Podmiot Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Nazwa __DATABASE__]
    ,[Podmiot Kod __PROCID__Kontrahenci__],  [Podmiot Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Kod __DATABASE__]

    ' + @atrybuty2 + @atrybutyDok2 + '
FROM
( SELECT
id = bzp_bzpid,
bf = BAZ.Baz_Nazwa,
nr = BZp_Numer,
zap = ''Zapisy'',

nrpon = ''(BRAK)'',
datpon = ''(BRAK)'',

sy = dd.DDf_Symbol,
op = ISNULL(NULLIF(BZp_Opis,''''),''(BRAK)''),
nrPelny =  BZp_NumerPelny ,
nr_procid = 23008, nr_orgid = BZp_BZpID,
    CASE 
    WHEN BZp_NumerPelny <> '''' THEN 
      CASE when isnull(ser.seria,0) = 5 then 
        substring(BZp_NumerPelny,0,CHARINDEX(''/'',BZp_NumerPelny,0))
      ELSE 
        ISNULL(PARSENAME(REPLACE(substring(BZp_NumerPelny,CHARINDEX(''/'',BZp_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
      END
    ELSE ''(BRAK)'' 
    END as [ds], 
mpp = BZp_SplitPay, 
waluta = CASE WHEN BZp_Waluta = '''' THEN @Wal ELSE BZp_Waluta END, 
sta = CASE 
    WHEN BZp_Rozliczono2=2 AND BZp_Rozliczono=2 THEN ''Zapisy Rozliczone'' 
    WHEN BZp_Rozliczono=1 THEN ''Zapisy Nierozliczone'' 
    WHEN BZp_Rozliczono2=0 AND BZp_Rozliczono=0 THEN ''Zapisy Nie podlega rozliczeniu''
    WHEN BZp_Rozliczono2=2 AND BZp_Rozliczono=1 THEN ''Zapisy Rozliczony częściowo'' END,
fp = CASE
    WHEN BZp_Typ = 1 THEN ''wpłata/wypłata gotówki'' 
    WHEN BZp_Typ = 2 THEN ''przelew na konto/z konta''
    WHEN BZp_Typ = 3 THEN ''obciążenie/uznanie karty'' END, 
raport = BRp_NumerPelny, 
boraportu = CASE 
    WHEN BRp_Zamkniety = 1 THEN BRp_SaldoBOSys 
    ELSE ISNULL((
        SELECT TOP 1 R2.BRp_SaldoBOSys + R2.BRp_PrzychodySys - R2.BRp_RozchodySys
        FROM CDN.BnkRaporty R2 
        WHERE R2.BRp_Zamkniety = 1 
            AND R1.BRp_BRaID = R2.BRp_BRaID 
            AND R2.BRp_DataZam <= R1.BRp_DataDok 
        ORDER BY R2.BRp_DataZam DESC
        ), 0) 
        +
        ISNULL((
        SELECT SUM(R2.BRp_PrzychodySys - R2.BRp_RozchodySys)
        FROM CDN.BnkRaporty R2 
        WHERE R1.BRp_BRaID = R2.BRp_BRaID 
            AND R2.BRp_DataZam <= R1.BRp_DataDok
            AND R2.BRp_DataZam > (SELECT TOP 1 R3.BRp_DataZam FROM CDN.BnkRaporty R3 WHERE R3.BRp_Zamkniety = 1 AND R1.BRp_BRaID = R3.BRp_BRaID AND R3.BRp_DataZam <= R1.BRp_DataDok ORDER BY R3.BRp_DataZam DESC) 
        ),0) 
    END, 
RKursowaRaportu =  BRp_RoznicaKursowaSysMW/LiczbaZ,
borachunku = BRa_SaldoBOSys, stanraportu = CASE WHEN BRp_Zamkniety = 0 THEN ''Otwarty'' ELSE ''Zamknięty'' END,
data = REPLACE(CONVERT(VARCHAR(10), BZp_DataDok, 111), ''/'', ''-''), 
dataD = REPLACE(CONVERT(VARCHAR(10), BZp_DataDok, 111), ''/'', ''-''), 
dataRO = REPLACE(CONVERT(VARCHAR(10), BZp_DataRoz, 111), ''/'', ''-''), 
dataRE = REPLACE(CONVERT(VARCHAR(10), BZp_DataRoz, 111), ''/'', ''-''), 
dataT = BZp_DataRoz, 
miesiac = MONTH(BZp_DataDok), kwartal = DATEPART(quarter, BZp_DataDok), rok = YEAR(BZp_DataDok), tr = (datepart(DY, datediff(d, 0, BZp_DataDok) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, BZp_DataDok)*/,
analizadata = GETDATE(),
kon = CASE 
    WHEN BZp_PodmiotTyp IN (1,2,3,5) THEN pod.Pod_Nazwa1 + '' '' + pod.Pod_Nazwa2
    ELSE ''(NIEOKREŚLONY)'' END,
kon_procid = CASE BZp_PodmiotTyp
    WHEN 1 THEN 20201
    WHEN 2 THEN 23002
    WHEN 3 THEN 24001
    WHEN 5 THEN 25005
    ELSE 20201
END, kon_orgid = BZp_PodmiotID,
konKod = CASE 
    WHEN BZp_PodmiotTyp IN (1,2,3,4,5) THEN pod.Pod_Kod
    ELSE ''(NIEOKREŚLONY)'' END,
konTyp = CASE 
    WHEN BZp_PodmiotTyp = 1 THEN ''Kontrahent''
    WHEN BZp_PodmiotTyp = 2 THEN ''Bank''
    WHEN BZp_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
    WHEN BZp_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END,
konRodz = CASE
    WHEN BZp_PodmiotTyp = 2 THEN ''Bank''
    WHEN BZp_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
    WHEN BZp_PodmiotTyp = 5 THEN ''Urząd''
    WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Dostawca = 1 AND knt1.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca/Dostawca''
    WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Dostawca = 1 THEN ''Dostawca''
    WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca''
    WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Konkurencja = 1 THEN ''Konkurencja''
    WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Partner = 1 THEN ''Partner''
    WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Potencjalny = 1 THEN ''Klient Potencjalny''
    ELSE ''(NIEOKREŚLONY)'' END,
konStatus = case knt1.knt_export
    when 0 then ''krajowy''
    when 1 then ''pozaunijny''
    when 2 then ''pozaunijny (zwrot VAT)''
    when 3 then ''wewnątrzunijny''
    when 4 then ''wewnątrzunijny trójstronny''
    when 5 then ''podatnikiem jest nabywca''
    when 6 then ''poza terytorium kraju''
    when 7 then ''poza terytorium kraju (stawka NP)''
    when 8 then ''wewnątrzunijny - podatnikiem jest nabywca''
    when 9 then ''pozaunijny- podatnikiem jest nabywca''
    ELSE ''(NIEOKREŚLONY)'' end,
konGrupa = CASE 
    WHEN BZp_PodmiotTyp = 1 THEN COALESCE(NULLIF(pod.Pod_Grupa, ''''), ''Pozostali'')   
    WHEN BZp_PodmiotTyp = 2 THEN ''Banki''
    WHEN BZp_PodmiotTyp = 3 THEN ''Pracownicy/Wspólnicy''
    WHEN BZp_PodmiotTyp = 5 THEN ''Urzędy''
    ELSE ''(NIEOKREŚLONY)'' END,
konOpie = CASE 
    WHEN knt1.Knt_OpiekunTyp = 3 THEN ISNULL(pod2.Pod_Kod, ''(NIEPRZYPISANE)'')
    WHEN knt1.Knt_OpiekunTyp = 8 THEN ISNULL(opk.Ope_Kod, ''(NIEPRZYPISANE)'')
    ELSE ''(NIEPRZYPISANE)'' END,
termin = ''1. Terminowe'', liczbaDniP = 0,
woj = pod.Pod_Wojewodztwo, miasto = pod.Pod_Miasto, kraj = pod.Pod_Kraj, nip = pod.Pod_NIP,
pod5.Pod_Nazwa1 [Podmiot Nazwa], 
    20201 [Podmiot Nazwa __PROCID__], pod5.Pod_PodId [Podmiot Nazwa __ORGID__],
    
    pod5.Pod_Kod [Podmiot Kod], 
    20201 [Podmiot Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Podmiot Kod __ORGID__],

    ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Podmiot Województwo], ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Podmiot Miasto],
    ISNULL(NULLIF(pod5.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Podmiot Kraj], ISNULL(NULLIF(pod5.Pod_NIP, ''''),''(BRAK)'') [Podmiot NIP],
    ISNULL(NULLIF(pod5.Pod_Grupa, ''''),''Pozostali'') [Podmiot Grupa], ISNULL(kat5.Kat_KodSzczegol, ''(PUSTA)'') [Podmiot Kategoria],
    CASE knt3.Knt_OpiekunTyp
        WHEN 3 THEN ISNULL(pod6.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN 8 THEN ISNULL(opk3.Ope_Kod, ''(NIEPRZYPISANE)'')
        ELSE ''(NIEPRZYPISANE)'' 
    END [Podmiot Opiekun],
    case knt3.knt_export
    when 0 then ''krajowy''
    when 1 then ''pozaunijny''
    when 2 then ''pozaunijny (zwrot VAT)''
    when 3 then ''wewnątrzunijny''
    when 4 then ''wewnątrzunijny trójstronny''
    when 5 then ''podatnikiem jest nabywca''
    when 6 then ''poza terytorium kraju''
    when 7 then ''poza terytorium kraju (stawka NP)''
    when 8 then ''wewnątrzunijny - podatnikiem jest nabywca''
    when 9 then ''pozaunijny- podatnikiem jest nabywca''
    ELSE ''(NIEOKREŚLONY)'' end [Podmiot Status],
    CASE 
            WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
            WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
            WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
            ELSE ''(NIEOKREŚLONY)'' 
        END [Podmiot Typ],
    CASE
            WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
            WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Dostawca = 1 AND knt3.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca/Dostawca''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Dostawca = 1 THEN ''Dostawca''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Konkurencja = 1 THEN ''Konkurencja''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Partner = 1 THEN ''Partner''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Potencjalny = 1 THEN ''Klient Potencjalny''
            ELSE ''(NIEOKREŚLONY)'' 
        END [Podmiot Rodzaj],
stan = ''Nie dotyczy'',
zz = ''Zrealizowane'', rachunek = BRa_Nazwa, rachAkronim = BRa_Akronim, rachSymbol= BRa_Symbol, kat = ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)''), kat2 = ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)''),
zakladSymbol = isnull(Zak_Symbol,''(NIEPRZYPISANY)''), 
zakladNazwa = isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)''), 
przychod = CASE WHEN BZp_Kierunek > 0 THEN ISNULL(KwotaSys,BZp_KwotaSys) ELSE NULL END, rozchod = CASE WHEN BZp_Kierunek < 0 THEN ISNULL(KwotaSys,BZp_KwotaSys) ELSE NULL END,
przychodWal = CASE WHEN BZp_Kierunek > 0 THEN ISNULL(Kwota,BZp_Kwota) ELSE NULL END, rozchodWal = CASE WHEN BZp_Kierunek < 0 THEN ISNULL(Kwota,BZp_Kwota) ELSE NULL END,
przychodNRoz = CASE WHEN BZp_Kierunek > 0 THEN ISNULL(KwotaRozSys,BZp_KwotaRozSys) ELSE NULL END, rozchodNroz = CASE WHEN BZp_Kierunek < 0 THEN ISNULL(KwotaRozSys,BZp_KwotaRozSys) ELSE NULL END,
przychodNRozWal = CASE WHEN BZp_Kierunek > 0 THEN ISNULL(KwotaRoz,BZp_KwotaRoz) ELSE NULL END, rozchodNrozWal = CASE WHEN BZp_Kierunek < 0 THEN ISNULL(KwotaRoz,BZp_KwotaRoz) ELSE NULL END,
borachunekwal = BRa_SaldoBO,
bowaluta = CASE WHEN Bra_Waluta = '''' THEN @Wal ELSE Bra_Waluta END,
opewkod = ISNULL(ow.Ope_Kod, ''ID:''+CAST(Bzp_OpeZalId as VARCHAR)),
opewnazwa = ISNULL(ow.Ope_Nazwisko, ''ID:''+CAST(Bzp_OpeZalId as VARCHAR)),
opemkod = ISNULL(om.Ope_Kod, ''ID:''+CAST(Bzp_OpeModId as VARCHAR)),
opemnazwa = ISNULL(om.Ope_Nazwisko, ''ID:''+CAST(Bzp_OpeModId as VARCHAR)),
DokPrz = NumerPrz
' + @atrybuty + @atrybutyDok + '
FROM
cdn.BnkZapisy
LEFT JOIN #tmpSeria ser ON BZp_DDfId = DDf_DDfID
LEFT JOIN CDN.DokDefinicje dd ON BZp_DDfId = dd.DDf_DDfID
LEFT JOIN CDN.BnkRachunki ON BZp_BRaID = BRa_BRaID
LEFT JOIN CDN.BnkRaporty R1 ON BZp_BRpID = R1.BRp_BRpID
LEFT JOIN CDN.PodmiotyView pod ON BZp_PodmiotID = pod.Pod_PodId AND BZp_PodmiotTyp = pod.Pod_PodmiotTyp
LEFT JOIN CDN.Kategorie kat1 ON BZp_KatID = kat1.Kat_KatID
LEFT JOIN #tmpKonAtr KonAtr ON pod.Pod_PodId = KonAtr.KnA_PodmiotId AND pod.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
LEFT JOIN #tmpDokAtr DokAtr ON 0  = 1
LEFT JOIN CDN.Kontrahenci knt1 ON BZp_PodmiotID=knt1.Knt_KntId AND BZp_PodmiotTyp = 1
LEFT JOIN ' + @Operatorzy + ' opk ON knt1.Knt_OpiekunId = opk.Ope_OpeId AND knt1.Knt_OpiekunTyp = 8
LEFT JOIN cdn.PodmiotyView pod2 ON knt1.Knt_OpiekunId = pod2.Pod_PodId AND knt1.Knt_OpiekunTyp = pod2.Pod_PodmiotTyp
LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod.Pod_GlID = pod5.Pod_PodId and pod.Pod_GlKod = pod5.Pod_Kod
LEFT OUTER JOIN CDN.Kontrahenci knt3 ON pod5.Pod_PodID=knt3.Knt_KntId AND pod5.Pod_PodmiotTyp = 1
LEFT OUTER JOIN CDN.Kategorie kat5 ON knt3.Knt_KatID=kat5.Kat_KatID
LEFT OUTER JOIN cdn.PodmiotyView pod6 ON knt3.Knt_OpiekunId = pod6.Pod_PodId AND knt3.Knt_OpiekunTyp = pod6.Pod_PodmiotTyp
LEFT JOIN ' + @Operatorzy + ' opk3 ON knt3.Knt_OpiekunId = opk3.Ope_OpeId AND knt3.Knt_OpiekunTyp = 8 
LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = BZp_ZakID
LEFT JOIN ' + @Operatorzy + ' ow on ow.Ope_OpeId = BZp_OpeZalId
LEFT JOIN ' + @Operatorzy + ' om on om.Ope_OpeId = BZp_OpeModId
LEFT JOIN  #ZapisyLiczba ON R1.BRp_BRpID = IDRaportu
LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'')
LEFT JOIN #TmpPrzeciw on 
PodTyp = bzP_podmiotTyp AND
PodID = bzP_podmiotID AND
Dokid = BZP_bzPid AND
Numer =  BZP_Numer 
UNION ALL 

SELECT
id = bzd_bzdid,
bf = BAZ.Baz_Nazwa,
nr = BZd_Numer,  -- Zdarzenia
zap = ''Zdarzenia'',

nrpon = ISNULL(pnr,''(BRAK)''),
datpon = ISNULL(REPLACE(CONVERT(VARCHAR(10), pdat, 111), ''/'', ''-''),''(BRAK)''),

sy = dd.DDf_Symbol,
op = ISNULL(NULLIF(BZd_Opis,''''),''(BRAK)''),
nrPelny =  BZd_NumerPelny ,
nr_procid = 23014, nr_orgid = BZd_BZdID,
 
        CASE 
        WHEN BZd_NumerPelny <> '''' THEN 
         CASE when isnull(ser.seria,0) = 5 then 
           substring(BZd_NumerPelny,0,CHARINDEX(''/'',BZd_NumerPelny,0))
         ELSE 
           ISNULL(PARSENAME(REPLACE(substring(BZd_NumerPelny,CHARINDEX(''/'',BZd_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
         END
         ELSE ''(BRAK)'' 
         END as [ds], 
mpp = BZd_SplitPay, 
waluta = CASE WHEN BZd_Waluta = '''' THEN @Wal ELSE BZd_Waluta END, 
sta = CASE
    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=1 THEN ''Zdarzenia Nierozliczone''
    WHEN BZd_Rozliczono=2 THEN ''Zdarzenia Rozliczone''
    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=2 THEN ''Zdarzenia Częściowo rozliczone''
    WHEN BZd_Rozliczono=0 AND BZd_Rozliczono2=0 THEN ''Zdarzenia Nie podlega rozliczeniu'' 
    WHEN BZd_Rozliczono=2 AND BZd_Rozliczono2=2 THEN ''Zdarzenia w rozliczeniu całości'' END,
fp = FPl_Nazwa, raport = ''Nie dotyczy'', boraportu = NULL, RKursowaRaportu =  null, borachunku = BRa_SaldoBOSys, stanraportu = ''Nie dotyczy'',
data = REPLACE(CONVERT(VARCHAR(10), BZd_DataReal, 111), ''/'', ''-''), 
dataD = REPLACE(CONVERT(VARCHAR(10), BZd_DataDok, 111), ''/'', ''-''), 
dataRO = REPLACE(CONVERT(VARCHAR(10), BZd_DataRoz, 111), ''/'', ''-''), 
dataRE = REPLACE(CONVERT(VARCHAR(10), BZd_DataReal, 111), ''/'', ''-''), 
dataT = BZd_Termin,
miesiac = MONTH(BZd_DataReal), kwartal = DATEPART(quarter, BZd_DataReal), rok = YEAR(BZd_DataReal), tr = (datepart(DY, datediff(d, 0, BZd_DataReal) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, BZd_DataReal)*/,
analizadata = GETDATE(),
kon = CASE 
    WHEN BZd_PodmiotTyp  IN (1,2,3,5) THEN pod.Pod_Nazwa1 + '' '' + pod.Pod_Nazwa2
    ELSE ''(NIEOKREŚLONY)'' END,
kon_procid = CASE BZd_PodmiotTyp
    WHEN 1 THEN 20201
    WHEN 2 THEN 23002
    WHEN 3 THEN 24001
    WHEN 5 THEN 25005
    ELSE 20201
END, kon_orgid = BZd_PodmiotID,
konKod = CASE 
    WHEN BZd_PodmiotTyp IN (1,2,3,4,5) THEN pod.Pod_Kod
    ELSE ''(NIEOKREŚLONY)'' END,
konTyp = CASE 
    WHEN BZd_PodmiotTyp = 1 THEN ''Kontrahent''
    WHEN BZd_PodmiotTyp = 2 THEN ''Bank''
    WHEN BZd_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
    WHEN BZd_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END,
konRodz = CASE
    WHEN BZd_PodmiotTyp = 2 THEN ''Bank''
    WHEN BZd_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
    WHEN BZd_PodmiotTyp = 5 THEN ''Urząd''
    WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Dostawca = 1 AND knt1.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca/Dostawca''
    WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Dostawca = 1 THEN ''Dostawca''
    WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca''
    WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Konkurencja = 1 THEN ''Konkurencja''
    WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Partner = 1 THEN ''Partner''
    WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Potencjalny = 1 THEN ''Klient Potencjalny''
    ELSE ''(NIEOKREŚLONY)'' END,
konStatus = case knt1.knt_export
    when 0 then ''krajowy''
    when 1 then ''pozaunijny''
    when 2 then ''pozaunijny (zwrot VAT)''
    when 3 then ''wewnątrzunijny''
    when 4 then ''wewnątrzunijny trójstronny''
    when 5 then ''podatnikiem jest nabywca''
    when 6 then ''poza terytorium kraju''
    when 7 then ''poza terytorium kraju (stawka NP)''
    when 8 then ''wewnątrzunijny - podatnikiem jest nabywca''
    when 9 then ''pozaunijny- podatnikiem jest nabywca''
    ELSE ''(NIEOKREŚLONY)'' end,
konGrupa = CASE 
    WHEN BZd_PodmiotTyp = 1 THEN COALESCE(NULLIF(pod.Pod_Grupa, ''''), ''Pozostali'')   
    WHEN BZd_PodmiotTyp = 2 THEN ''Banki''
    WHEN BZd_PodmiotTyp = 3 THEN ''Pracownicy/Wspólnicy''
    WHEN BZd_PodmiotTyp = 5 THEN ''Urzędy''
    ELSE ''(NIEOKREŚLONY)'' END,
konOpie = CASE 
    WHEN knt1.Knt_OpiekunTyp = 3 THEN ISNULL(pod2.Pod_Kod, ''(NIEPRZYPISANE)'')
    WHEN knt1.Knt_OpiekunTyp = 8 THEN ISNULL(opk.Ope_Kod, ''(NIEPRZYPISANE)'')
    ELSE ''(NIEPRZYPISANE)'' END,
termin = CASE
WHEN BZd_Rozliczono=1 THEN (CASE
    WHEN DATEDIFF(day, BZd_Termin, GETDATE()) < 1 THEN ''1. Terminowe''
    WHEN DATEDIFF(day, BZd_Termin, GETDATE()) BETWEEN 1 AND 5 THEN ''2. Przeterminowane nie więcej niż 5 dni''
    WHEN DATEDIFF(day, BZd_Termin, GETDATE()) BETWEEN 6 AND 30 THEN ''3. Przeterminowane od 6 do 30 dni''
    WHEN DATEDIFF(day, BZd_Termin, GETDATE()) BETWEEN 31 AND 60 THEN ''4. Przeterminowane od 31 do 60 dni''
    WHEN DATEDIFF(day, BZd_Termin, GETDATE()) BETWEEN 61 AND 120 THEN ''5. Przeterminowane od 60 do 120 dni''
    ELSE ''6. Przeterminowane powyżej 120 dni'' END)
WHEN BZd_Rozliczono=2 THEN (CASE 
    WHEN DATEDIFF(day, BZd_Termin, BZd_DataRoz) < 1 THEN ''1. Terminowe''
    WHEN DATEDIFF(day, BZd_Termin, BZd_DataRoz) BETWEEN 1 AND 5 THEN ''2. Przeterminowane nie więcej niż 5 dni''
    WHEN DATEDIFF(day, BZd_Termin, BZd_DataRoz) BETWEEN 6 AND 30 THEN ''3. Przeterminowane od 6 do 30 dni''
    WHEN DATEDIFF(day, BZd_Termin, BZd_DataRoz) BETWEEN 31 AND 60 THEN ''4. Przeterminowane od 31 do 60 dni''
    WHEN DATEDIFF(day, BZd_Termin, BZd_DataRoz) BETWEEN 61 AND 120 THEN ''5. Przeterminowane od 60 do 120 dni''
    ELSE ''6. Przeterminowane powyżej 120 dni'' END)
END,
liczbaDniP = CASE
    WHEN BZd_Rozliczono=1 THEN CASE WHEN DATEDIFF(day, BZd_Termin, GETDATE()) < 0 THEN 0 ELSE DATEDIFF(day, BZd_Termin, GETDATE()) END
    WHEN BZd_Rozliczono=2 THEN CASE WHEN DATEDIFF(day, BZd_Termin, BZd_DataRoz) < 0 THEN 0 ELSE DATEDIFF(day, BZd_Termin, BZd_DataRoz) END
    ELSE 0 END,
woj = pod.Pod_Wojewodztwo, miasto = pod.Pod_Miasto, kraj = pod.Pod_Kraj, nip = pod.Pod_NIP,     
pod5.Pod_Nazwa1 [Podmiot Nazwa], 
    20201 [Podmiot Nazwa __PROCID__], pod5.Pod_PodId [Podmiot Nazwa __ORGID__],
    
    pod5.Pod_Kod [Podmiot Kod], 
    20201 [Podmiot Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Podmiot Kod __ORGID__],

    ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Podmiot Województwo], ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Podmiot Miasto],
    ISNULL(NULLIF(pod5.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Podmiot Kraj], ISNULL(NULLIF(pod5.Pod_NIP, ''''),''(BRAK)'') [Podmiot NIP],
    ISNULL(NULLIF(pod5.Pod_Grupa, ''''),''Pozostali'') [Podmiot Grupa], ISNULL(kat5.Kat_KodSzczegol, ''(PUSTA)'') [Podmiot Kategoria],
    CASE knt3.Knt_OpiekunTyp
        WHEN 3 THEN ISNULL(pod6.Pod_Kod, ''(NIEPRZYPISANE)'')
        WHEN 8 THEN ISNULL(opk3.Ope_Kod, ''(NIEPRZYPISANE)'')
        ELSE ''(NIEPRZYPISANE)'' 
    END [Podmiot Opiekun],
    case knt3.knt_export
    when 0 then ''krajowy''
    when 1 then ''pozaunijny''
    when 2 then ''pozaunijny (zwrot VAT)''
    when 3 then ''wewnątrzunijny''
    when 4 then ''wewnątrzunijny trójstronny''
    when 5 then ''podatnikiem jest nabywca''
    when 6 then ''poza terytorium kraju''
    when 7 then ''poza terytorium kraju (stawka NP)''
    when 8 then ''wewnątrzunijny - podatnikiem jest nabywca''
    when 9 then ''pozaunijny- podatnikiem jest nabywca''
    ELSE ''(NIEOKREŚLONY)'' end [Podmiot Status],

    CASE 
            WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
            WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
            WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
            ELSE ''(NIEOKREŚLONY)'' 
        END [Podmiot Typ],
    CASE
            WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
            WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Dostawca = 1 AND knt3.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca/Dostawca''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Dostawca = 1 THEN ''Dostawca''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Konkurencja = 1 THEN ''Konkurencja''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Partner = 1 THEN ''Partner''
            WHEN pod5.Pod_PodmiotTyp = 1 AND knt3.Knt_Rodzaj_Potencjalny = 1 THEN ''Klient Potencjalny''
            ELSE ''(NIEOKREŚLONY)'' 
        END [Podmiot Rodzaj],
stan = CASE
    WHEN BZd_Stan = 0 THEN ''Bufor''
    WHEN BZd_Stan = 1 THEN ''Do realizacji''
    WHEN BZd_Stan = 2 THEN ''Wysłane''
    WHEN BZd_Stan = 3 THEN ''Zrealizowane''
    ELSE ''(NIEOKREŚLONY)'' END,
zz = ''Planowane'', rachunek = BRa_Nazwa, rachAkronim = BRa_Akronim, rachSymbol= BRa_Symbol, kat = ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)''), kat2 = ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)''),
zakladSymbol = ''(NIEPRZYPISANY)'', 
zakladNazwa = ''(NIEPRZYPISANY)'', 
przychod = CASE WHEN BZd_Kierunek > 0 THEN ISNULL(KwotaSys,BZd_KwotaSys) ELSE NULL END, rozchod = CASE WHEN BZd_Kierunek < 0 THEN ISNULL(KwotaSys,BZd_KwotaSys) ELSE NULL END,
przychodWal = CASE WHEN BZd_Kierunek > 0 THEN ISNULL(Kwota,BZd_Kwota) ELSE NULL END, rozchodWal = CASE WHEN BZd_Kierunek < 0 THEN ISNULL(Kwota,BZd_Kwota) ELSE NULL END,
przychodNRoz = CASE WHEN BZd_Kierunek > 0 
                    THEN ISNULL(KwotaRozSys,BZd_KwotaRozSys)                       
                    ELSE NULL END, 

rozchodNRoz = CASE WHEN BZd_Kierunek < 0 
                    THEN ISNULL(KwotaRozSys,BZd_KwotaRozSys)

                    ELSE NULL END, 
przychodNRozWal = CASE WHEN BZd_Kierunek > 0
                    THEN ISNULL(KwotaRoz,BZd_KwotaRoz)

                    ELSE NULL END, 
rozchodNRozWal = CASE WHEN BZd_Kierunek < 0 
                    THEN ISNULL(KwotaRoz,BZd_KwotaRoz)

                    ELSE NULL END ,
borachunekwal = BRa_SaldoBO,
bowaluta = CASE WHEN Bra_Waluta = '''' THEN @Wal ELSE Bra_Waluta END,
opewkod = ISNULL(ow.Ope_Kod, ''ID:''+CAST(Bzd_OpeZalId as VARCHAR)),
opewnazwa = ISNULL(ow.Ope_Nazwisko, ''ID:''+CAST(Bzd_OpeZalId as VARCHAR)),
opemkod = ISNULL(om.Ope_Kod, ''ID:''+CAST(Bzd_OpeModId as VARCHAR)),
opemnazwa = ISNULL(om.Ope_Nazwisko, ''ID:''+CAST(Bzd_OpeModId as VARCHAR)),
DokPrz = NumerPrz
' + @atrybuty + @atrybutyDok + '
FROM
cdn.BnkZdarzenia
LEFT JOIN #tmpSeria ser ON BZd_DDfId = DDf_DDfID
LEFT JOIN CDN.DokDefinicje dd ON BZd_DDfId = dd.DDf_DDfID
LEFT JOIN CDN.BnkRachunki ON BZd_BRaID = BRa_BRaID 
LEFT JOIN CDN.PodmiotyView pod ON BZd_PodmiotID = pod.Pod_PodId AND BZd_PodmiotTyp = pod.Pod_PodmiotTyp
LEFT JOIN CDN.Kategorie kat1 ON BZd_KatID = kat1.Kat_KatID
LEFT JOIN #tmpKonAtr KonAtr ON pod.Pod_PodId = KonAtr.KnA_PodmiotId AND pod.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
LEFT JOIN #tmpDokAtr DokAtr ON BZd_DokumentID  = DokAtr.DAt_TrNId AND BZd_DokumentTyp = 1
LEFT JOIN CDN.Kontrahenci knt1 ON BZd_PodmiotID=knt1.Knt_KntId AND BZd_PodmiotTyp = 1
LEFT JOIN ' + @Operatorzy + ' opk ON knt1.Knt_OpiekunId = opk.Ope_OpeId AND knt1.Knt_OpiekunTyp = 8
LEFT JOIN cdn.PodmiotyView pod2 ON knt1.Knt_OpiekunId = pod2.Pod_PodId AND knt1.Knt_OpiekunTyp = pod2.Pod_PodmiotTyp
LEFT JOIN CDN.FormyPlatnosci ON BZd_FPlId = FPl_FPlId
LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod.Pod_GlID = pod5.Pod_PodId and pod.Pod_GlKod = pod5.Pod_Kod
LEFT OUTER JOIN CDN.Kontrahenci knt3 ON pod5.Pod_PodID=knt3.Knt_KntId AND pod5.Pod_PodmiotTyp = 1
LEFT OUTER JOIN CDN.Kategorie kat5 ON knt3.Knt_KatID=kat5.Kat_KatID
LEFT OUTER JOIN cdn.PodmiotyView pod6 ON knt3.Knt_OpiekunId = pod6.Pod_PodId AND knt3.Knt_OpiekunTyp = pod6.Pod_PodmiotTyp
LEFT JOIN ' + @Operatorzy + ' opk3 ON knt3.Knt_OpiekunId = opk3.Ope_OpeId AND knt3.Knt_OpiekunTyp = 8 
LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
LEFT JOIN ' + @Operatorzy + ' ow on ow.Ope_OpeId = BZd_OpeZalId
LEFT JOIN ' + @Operatorzy + ' om on om.Ope_OpeId = BZd_OpeModId
LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'')
LEFT JOIN #TmpPrzeciw on 
PodTyp = bzD_podmiotTyp AND
PodID = bzD_podmiotID AND
Dokid = BZD_bzdid AND
Numer =  BZD_Numer 
LEFT JOIN
(
SELECT
BDE_DokId pzr,
MAX(BDN_NumerPelny) pnr,
MAX(BDN_DataDok) pdat
FROM
CDN.BnkDokElem 
JOIN CDN.BnkDokNag ON BDE_BDNId = BDN_BDNId AND BDN_Typ = 222 
GROUP BY BDE_DokId
) pon on pzr = BZd_DokumentID

) AS Kalendar 
LEFT JOIN #tmpIlosc on Numer1 = nr and dokid1 = id

'

PRINT(@select)
EXEC(@select)

DROP TABLE #tmpDokAtr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpSeria
DROP TABLE #ZapisyLiczba
DROP TABLE #TmpPrzeciw
DROP TABLE #tmpIlosc





