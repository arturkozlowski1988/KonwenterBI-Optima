/*
* Raport Płatności na Dzień 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
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
(SELECT DISTINCT DAt_TrNId, 1 as DokTyp FROM CDN.DokAtrybuty WHERE DAt_TrNId IS NOT NULL
UNION
SELECT DISTINCT DAt_VanId, 2 as DokTyp FROM CDN.DokAtrybuty WHERE DAt_VanId IS NOT NULL) a

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

--Tworzenie tabeli z serią dokumentów
SELECT DDf_DDfID, CASE 
    WHEN DDf_Numeracja like '@rejestr%' THEN 5
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 1) = '@rejestr' THEN 1
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 2) = '@rejestr' THEN 2
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 3) = '@rejestr' THEN 3
    WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 4) = '@rejestr' THEN 4
END [seria]  INTO #tmpSeria FROM CDN.DokDefinicje

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

--Właściwe zapytanie
DECLARE @select VARCHAR(MAX);
DECLARE @select2 VARCHAR(MAX);
DECLARE @select3 VARCHAR(MAX);
DECLARE @select4 VARCHAR(MAX);
DECLARE @select5 VARCHAR(MAX);

SET @select =' 
DECLARE @Wal VARCHAR(3); SET @Wal = CDN.Waluta('''')

SELECT 
    --Wymiary
    bf [Baza Firmowa], 
    dokumentNumer [Dokument Numer], 
    dokumentSymbol [Dokument Symbol],
    dokumentNumerPelny [Dokument Numer Pełny], 
    dokumentOpis [Dokument Opis],
    CASE mpp WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Dokument MPP],

    nrpon [Dokument Ponaglenia Numer],
    datpon [Dokument Ponaglenia Data Wystawienia],

    opewkod [Operator Wystawiający Kod],
    opewnazwa [Operator Wystawiający Nazwa],
    opemkod as [Operator Modyfikujący Kod],
    opemnazwa as [Operator Modyfikujący Nazwa], 
    ds [Dokument Seria],
    zapisyZdarzenia [Zapisy/Zdarzenia], waluta [Waluta], fp [Forma Płatności],
    kontrahentNazwa [Podmiot Nazwa], 
    kontrahentKod [Podmiot Kod],
    kontrahentLimit [Podmiot Limit],
    kontrahentWartośćLimitu [Podmiot Wartość Limitu],
    kontrahentTermin [Podmiot Termin],
    kontrahentTyp [Podmiot Typ], kontrahentRodzaj [Podmiot Rodzaj], kontrahentStatus [Podmiot Status], kontrahentGrupa [Podmiot Grupa],
    kontrahentWojewodztwo [Podmiot Województwo], kontrahentMiasto [Podmiot Miasto],kontrahentKraj [Podmiot Kraj], kontrahentNIP [Podmiot NIP],
    kontrahentpierwotnyNazwa [Podmiot Pierwotny Nazwa],     
    kontrahentPierwotnyKod [Podmiot Pierwotny Kod], 
    kontrahentPierwotnyTyp [Podmiot Pierwotny Typ], kontrahentPierwotnyRodzaj [Podmiot Pierwotny Rodzaj], kontrahentPierwotnyStatus [Podmiot Pierwotny Status], kontrahentPierwotnyGrupa [Podmiot Pierwotny Grupa],
    kontrahentPierwotnyWojewodztwo [Podmiot Pierwotny Województwo], kontrahentPierwotnyMiasto [Podmiot Pierwotny Miasto],kontrahentPierwotnyKraj [Podmiot Pierwotny Kraj], kontrahentPierwotnyNIP [Podmiot Pierwotny NIP],
    kategoriaSzczegolowa [Kategoria Szczegółowa], kategoriaOgolna [Kategoria Ogólna], rachunek [Rejestr], rachAkronim [Rejestr Akronim], rachSymbol [Rejestr Symbol] ,
    statusDokumentu [Status Aktualny], 
    statusDokumentuDzien [Status na Dzień Analizy], 
    stanDokumentu [Stan Aktualny], 
    terminZapadalnosci [Termin Zapadalności],
    zakladSymbol as [Zakład Symbol],
    zakladNazwa as [Zakład Nazwa Firmy], 
    --Miary
    CASE WHEN (liczbaDniPrzeterminowaniaNaleznosci < 0)
        THEN 0 
        ELSE liczbaDniPrzeterminowaniaNaleznosci
    END [Liczba Dni Przeterminowania Należności],
    CASE WHEN (liczbaDniPrzeterminowaniaZobowiazania < 0)
        THEN 0 
        ELSE liczbaDniPrzeterminowaniaZobowiazania
    END [Liczba Dni Przeterminowania Zobowiązań],
    case when convert(datetime,dataDokumentu, 120)  < convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120) 
         and convert(datetime,dataDokumentu, 120) > DATEADD(mm, DATEDIFF(m,0,convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)),0) 
         then naleznosci else null end  [Sprzedaż brutto],
    NULLIF(naleznosci,0) [Należności],
    NULLIF(zobowiazania,0) [Zobowiązania], 
    NULLIF(naleznosciWaluta,0) [Należności Waluta], 
    NULLIF(zobowiazaniaWaluta,0) [Zobowiązania Waluta], 
    NULLIF(naleznosciNieRozliczone,0) [Należności Nierozliczone], 
    NULLIF(zobowiazaniaNieRozliczone,0) [Zobowiązania Nierozliczone],
    NULLIF(naleznosciNieRozliczoneWaluta,0) [Należności Nierozliczone Waluta], 
    NULLIF(zobowiazaniaNieRozliczoneWaluta,0) [Zobowiązania Nierozliczone Waluta] ,
    czyRozliczony [Rozliczone/Nierozliczone]
/*
    ----------DATY POINT
    ,dataDokumentu [Data Dokumentu]
    ,dataTerminPlatnosci [Data Termin Płatności]
    ,dataRozliczenia [Data Rozliczenia], dataRealizacji [Data Realizacji]
    */
    ----------DATY ANALIZY
    ,dataDokumentu [Data Dokumentu Dzień], dataDokumentuMiesiac [Data Dokumentu Miesiąc], dataDokumentuKwartal [Data Dokumentu Kwartał], dataDokumentuRok [Data Dokumentu Rok], dataDokumentuTydzienRoku [Data Dokumentu Tydzień Roku]
    ,dataTerminPlatnosci [Data Termin Płatności Dzień], dataTerminPlatnosciMiesiac [Data Termin Płatności Miesiąc], dataTerminPlatnosciKwartal [Data Termin Płatności Kwartał], dataTerminPlatnosciRok [Data Termin Płatności Rok], dataTerminPlatnosciTydzienRoku [Data Termin Płatności Tydzień Roku]
    ,dataRozliczenia [Data Rozliczenia Dzień], dataRealizacji [Data Realizacji Dzień] 
    ,analizaData [Data Analizy]

    ----------KONTEKSTY
    ,dokumentNumer_procid [Dokument Numer __PROCID__Platnosci__], dokumentNumer_orgid [Dokument Numer __ORGID__], '''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,dokumentNumer_procid [Dokument Numer Pełny __PROCID__], dokumentNumer_orgid [Dokument Numer Pełny __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer Pełny __DATABASE__]
    ,kon_procid [Podmiot Nazwa __PROCID__], kon_orgid [Podmiot Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Nazwa __DATABASE__]
    ,kon_procid [Podmiot Kod __PROCID__Kontrahenci__], kon_orgid [Podmiot Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Kod __DATABASE__]
    ,konPierwotny_procid [Podmiot Pierwotny Nazwa __PROCID__], konPierwotny_orgid [Podmiot Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Nazwa __DATABASE__]
    ,konPierwotny_procid [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], konPierwotny_orgid [Podmiot Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__]
    
    ' + @atrybuty2 + @atrybutyDok2 + '
FROM ( 
    SELECT
        BAZ.Baz_Nazwa bf, 
        
        BZp_Numer [dokumentNumer], 
        dokumentNumer_procid = 23008, dokumentNumer_orgid = BZp_BZpID,

        nrpon = ''(BRAK)'',
        datpon = ''(BRAK)'',

        opewkod = ISNULL(ow.Ope_Kod, ''ID:''+CAST(Bzp_OpeZalId as VARCHAR)),
        opewnazwa = ISNULL(ow.Ope_Nazwisko, ''ID:''+CAST(Bzp_OpeZalId as VARCHAR)),
        opemkod = ISNULL(om.Ope_Kod, ''ID:''+CAST(Bzp_OpeModId as VARCHAR)),
        opemnazwa = ISNULL(om.Ope_Nazwisko, ''ID:''+CAST(Bzp_OpeModId as VARCHAR)),

        dd.DDf_Symbol [dokumentSymbol], 
        BZp_NumerPelny [dokumentNumerPelny],
        ISNULL(NULLIF(BZp_Opis,''''),''(BRAK)'') [dokumentOpis],
        
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

         ''Zapisy k/b'' [zapisyZdarzenia], CASE WHEN BZp_Waluta = '''' THEN @Wal ELSE BZp_Waluta END [waluta], 
        CASE
            WHEN BZp_Typ = 1 THEN ''wpłata/wypłata gotówki'' 
            WHEN BZp_Typ = 2 THEN ''przelew na konto/z konta''
            WHEN BZp_Typ = 3 THEN ''obciążenie/uznanie karty'' 
        END [fp], 
        REPLACE(CONVERT(VARCHAR(10), BZp_DataDok, 111), ''/'', ''-'') [dataDokumentu], MONTH(BZp_DataDok) [dataDokumentuMiesiac], DATEPART(quarter, BZp_DataDok) [dataDokumentuKwartal], YEAR(BZp_DataDok) [dataDokumentuRok], (datepart(DY, datediff(d, 0, BZp_DataDok) / 7 * 7 + 3)+6) / 7 [dataDokumentuTydzienRoku]/*DATEPART(isowk, BZp_DataDok)*/,
        REPLACE(CONVERT(VARCHAR(10), BZp_DataDok, 111), ''/'', ''-'') [dataTerminPlatnosci], MONTH(BZp_DataDok) [dataTerminPlatnosciMiesiac], DATEPART(quarter, BZp_DataDok) [dataTerminPlatnosciKwartal], YEAR(BZp_DataDok) [dataTerminPlatnosciRok], (datepart(DY, datediff(d, 0, BZp_DataDok) / 7 * 7 + 3)+6) / 7 [dataTerminPlatnosciTydzienRoku]/*DATEPART(isowk, BZp_DataDok)*/,
        REPLACE(CONVERT(VARCHAR(10), BZp_DataRoz, 111), ''/'', ''-'') [dataRozliczenia], REPLACE(CONVERT(VARCHAR(10), BZp_DataRoz, 111), ''/'', ''-'') [dataRealizacji],  
        GETDATE() [analizaData],
        CASE WHEN pod5.Pod_Nazwa1 IS NULL AND pod5.Pod_Nazwa2 IS NULL THEN ''(NIEOKREŚLONY)'' ELSE pod5.Pod_Nazwa1 + '' '' + pod5.Pod_Nazwa2 END [kontrahentNazwa], 
        kon_procid = CASE pod5.Pod_PodmiotTyp
            WHEN 1 THEN 20201
            WHEN 2 THEN 23002
            WHEN 3 THEN 24001
            WHEN 5 THEN 25005
            ELSE 20201
        END, kon_orgid = pod5.Pod_PodId,
        

        pod5.Pod_Kod [kontrahentKod],
        CASE 
            WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
            WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
            WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentTyp],
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
        END [kontrahentRodzaj],

        CASE WHEN knt3.Knt_LimitFlag = 1 THEN ''Tak'' ELSE ''Nie'' END [kontrahentLimit],
        knt3.Knt_LimitKredytu [kontrahentWartośćLimitu],
        CASE WHEN knt3.Knt_Termin > 7 THEN ''ponad 7 dni'' ELSE ''mniej niż 7 dni'' END [kontrahentTermin],

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
            ELSE ''(NIEOKREŚLONY)'' 
        end [kontrahentStatus],
        CASE 
            WHEN pod5.Pod_PodmiotTyp = 1 THEN COALESCE(NULLIF(pod5.Pod_Grupa, ''''), ''Pozostali'') 
            WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Banki''
            WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownicy/Wspólnicy''
            WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urzędy''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentGrupa],
        pod5.Pod_Wojewodztwo [kontrahentWojewodztwo], pod5.Pod_Miasto [kontrahentMiasto],pod5.Pod_Kraj [kontrahentKraj], pod5.Pod_NIP [kontrahentNIP],

        CASE WHEN pod.Pod_Nazwa1 IS NULL AND pod.Pod_Nazwa2 IS NULL THEN ''(NIEOKREŚLONY)'' ELSE pod.Pod_Nazwa1 + '' '' + pod.Pod_Nazwa2 END [kontrahentPierwotnyNazwa], 
        konPierwotny_procid = CASE BZp_PodmiotTyp
            WHEN 1 THEN 20201
            WHEN 2 THEN 23002
            WHEN 3 THEN 24001
            WHEN 5 THEN 25005
            ELSE 20201
        END, konPierwotny_orgid = BZp_PodmiotID,
        
        pod.Pod_Kod [kontrahentPierwotnyKod],
        CASE 
            WHEN BZp_PodmiotTyp = 1 THEN ''Kontrahent''
            WHEN BZp_PodmiotTyp = 2 THEN ''Bank''
            WHEN BZp_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN BZp_PodmiotTyp = 5 THEN ''Urząd''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentPierwotnyTyp],
        CASE
            WHEN BZp_PodmiotTyp = 2 THEN ''Bank''
            WHEN BZp_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN BZp_PodmiotTyp = 5 THEN ''Urząd''
            WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Dostawca = 1 AND knt1.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca/Dostawca''
            WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Dostawca = 1 THEN ''Dostawca''
            WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca''
            WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Konkurencja = 1 THEN ''Konkurencja''
            WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Partner = 1 THEN ''Partner''
            WHEN BZp_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Potencjalny = 1 THEN ''Klient Potencjalny''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentPierwotnyRodzaj],
        case knt1.knt_export
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
            ELSE ''(NIEOKREŚLONY)'' 
        end [kontrahentPierwotnyStatus],

        CASE 
            WHEN BZp_PodmiotTyp = 1 THEN COALESCE(NULLIF(pod.Pod_Grupa, ''''), ''Pozostali'')   
            WHEN BZp_PodmiotTyp = 2 THEN ''Banki''
            WHEN BZp_PodmiotTyp = 3 THEN ''Pracownicy/Wspólnicy''
            WHEN BZp_PodmiotTyp = 5 THEN ''Urzędy''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentPierwotnyGrupa],
        pod.Pod_Wojewodztwo [kontrahentPierwotnyWojewodztwo], pod.Pod_Miasto [kontrahentPierwotnyMiasto],pod.Pod_Kraj [kontrahentPierwotnyKraj], pod.Pod_NIP [kontrahentPierwotnyNIP],

        ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [kategoriaSzczegolowa], 
        zakladSymbol = isnull(Zak_Symbol,''(NIEPRZYPISANY)''), 
        zakladNazwa = isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)''), '
SET @select2 = '
        ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [kategoriaOgolna], BRa_Nazwa [rachunek], BRa_Akronim [rachAkronim], BRa_Symbol [rachSymbol],
        CASE 
            WHEN BZp_Rozliczono2=2 AND BZp_Rozliczono=2 THEN ''Rozliczony'' 
            WHEN BZp_Rozliczono2=2 AND BZp_Rozliczono=1 THEN ''Częściowo Rozliczony'' 
            WHEN BZp_Rozliczono=1 THEN ''Nierozliczony'' 
            WHEN BZp_Rozliczono2=0 AND BZp_Rozliczono=0 THEN ''Nie Podlega Rozliczeniu''

        END [statusDokumentu],
        CASE
            WHEN BZp_Rozliczono=0 AND BZp_Rozliczono2=0 THEN ''Nie Podlega Rozliczeniu'' 
            WHEN ISNULL(BRK_KwotaSys,0) = 0 THEN ''Nierozliczony''
            ELSE ''Częściowo Rozliczony''                   
        END [statusDokumentuDzien],
        ''Nie dotyczy'' [stanDokumentu],
        CASE
            WHEN ''' + @ZAPISYWTERMINIE + ''' = ''T'' THEN ''1. Terminowe''
            WHEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) < 1 THEN ''1. Terminowe''
            WHEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN 1 AND ' + convert(varchar, @PRZEDZIAL1) + ' THEN ''2. Przeterminowane do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL1) + ') + '' dni''
            WHEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL1) + '+1 AND ' + convert(varchar, @PRZEDZIAL2) + ' THEN ''3. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL1) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL2) + ') + '' dni''
            WHEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL2) + '+1 AND ' + convert(varchar, @PRZEDZIAL3) + ' THEN ''4. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL2) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL3) + ') + '' dni''
            WHEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL3) + '+1 AND ' + convert(varchar, @PRZEDZIAL4) + ' THEN ''5. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL3) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL4) + ') + '' dni''
            WHEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL4) + '+1 AND ' + convert(varchar, @PRZEDZIAL5) + ' THEN ''6. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL4) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL5) + ') + '' dni''
            ELSE ''7. Przeterminowane powyżej '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL5) + ') + '' dni'' 
        END [terminZapadalnosci],
        CASE
            WHEN BZp_Kierunek > 0 THEN NULL
            WHEN ''' + @ZAPISYWTERMINIE + ''' = ''T'' THEN 0
            WHEN BZp_Rozliczono=1 THEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
            WHEN BZp_Rozliczono2=2 AND BZp_Rozliczono=1 THEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
            WHEN BZp_Rozliczono2=0 AND BZp_Rozliczono=0 THEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
            WHEN BZp_Rozliczono2=2 AND BZp_Rozliczono=2 THEN 
                CASE 
                    WHEN BZp_DataRoz > convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120) THEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZp_DataRoz > BZp_DataDok THEN DATEDIFF(day, BZp_DataDok, BZp_DataRoz) 
                    ELSE 0
                END
            ELSE 0
        END [liczbaDniPrzeterminowaniaNaleznosci],
        CASE
            WHEN BZp_Kierunek < 0 THEN NULL
            WHEN ''' + @ZAPISYWTERMINIE + ''' = ''T'' THEN 0
            WHEN BZp_Rozliczono=1 THEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
            WHEN BZp_Rozliczono2=2 AND BZp_Rozliczono=1 THEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
            WHEN BZp_Rozliczono2=0 AND BZp_Rozliczono=0 THEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
            WHEN BZp_Rozliczono2=2 AND BZp_Rozliczono=2 THEN 
                CASE 
                    WHEN BZp_DataRoz > convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120) THEN DATEDIFF(day, BZp_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZp_DataRoz > BZp_DataDok THEN DATEDIFF(day, BZp_DataDok, BZp_DataRoz) 
                    ELSE 0
                END
            ELSE 0
        END [liczbaDniPrzeterminowaniaZobowiazania],
CASE WHEN BZp_Kierunek < 0 THEN BZp_KwotaSys ELSE NULL END [naleznosci], 
CASE WHEN BZp_Kierunek > 0 THEN BZp_KwotaSys ELSE NULL END [zobowiazania],
CASE WHEN BZp_Kierunek < 0 THEN BZp_Kwota ELSE NULL END [naleznosciWaluta], 
CASE WHEN BZp_Kierunek > 0 THEN BZp_Kwota ELSE NULL END [zobowiazaniaWaluta],
CASE WHEN BZp_Kierunek < 0 THEN ISNULL(BZp_KwotaSys - IsNull(BRK_KwotaSys,0),0) ELSE NULL END [naleznosciNieRozliczone], 
CASE WHEN BZp_Kierunek > 0 THEN ISNULL(BZp_KwotaSys - IsNull(BRK_KwotaSys,0),0) ELSE NULL END [zobowiazaniaNieRozliczone],
CASE WHEN BZp_Kierunek < 0 THEN ISNULL(BZp_Kwota - IsNull(BRK_Kwota,0),0) ELSE NULL END [naleznosciNieRozliczoneWaluta], 
CASE WHEN BZp_Kierunek > 0 THEN ISNULL(BZp_Kwota - IsNull(BRK_Kwota,0),0) ELSE NULL END [zobowiazaniaNieRozliczoneWaluta],
CASE WHEN BZp_KwotaSys - BRK_KwotaSys = 0 THEN ''Tak'' ELSE ''Nie'' END [czyRozliczony]
        ' + @atrybuty + @atrybutyDok + '
    FROM
        CDN.BnkZapisy
        LEFT JOIN #tmpSeria ser ON BZp_DDfId = DDf_DDfID
        LEFT JOIN CDN.DokDefinicje dd ON BZp_DDfId = dd.DDf_DDfID
        LEFT JOIN CDN.BnkRachunki ON BZp_BRaID = BRa_BRaID
        LEFT JOIN CDN.PodmiotyView pod ON BZp_PodmiotID = pod.Pod_PodId AND BZp_PodmiotTyp = pod.Pod_PodmiotTyp
        LEFT JOIN CDN.Kontrahenci knt1 ON BZp_PodmiotID=knt1.Knt_KntId AND BZp_PodmiotTyp = 1
        LEFT JOIN CDN.Kategorie kat1 ON BZp_KatID = kat1.Kat_KatID
        LEFT OUTER JOIN (
            SELECT
                BRK_KwotaSys = SUM(CASE WHEN BRR_ZDokTyp = BRK_LDokTyp AND BRR_ZDokID = BRK_LDokID THEN BRK_KwotaSysL ELSE BRK_KwotaSysP END),
                BRK_Kwota = SUM(CASE WHEN BRR_ZDokTyp = BRK_LDokTyp AND BRR_ZDokID = BRK_LDokID THEN BRK_Kwota ELSE BRK_Kwota END),
                BRR_ZDokId, BRR_ZDokTyp
            FROM CDN.BnkRozKwoty JOIN CDN.BnkRozRelacje ON BRK_BRKId = BRR_BRKId
            WHERE BRK_DataDok <= convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)
            GROUP BY BRR_ZDokId, BRR_ZDokTyp
        ) AS Rozliczenia ON BRR_ZDokTyp = BZp_TypDokumentuKB AND BRR_ZDokId = BZp_BZpID
        LEFT JOIN #tmpKonAtr KonAtr ON pod.Pod_PodId = KonAtr.KnA_PodmiotId AND pod.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
        LEFT JOIN #tmpDokAtr DokAtr ON 0  = 1
        LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod.Pod_GlID = pod5.Pod_PodId and pod.Pod_GlKod = pod5.Pod_Kod
        LEFT OUTER JOIN CDN.Kontrahenci knt3 ON pod5.Pod_PodID=knt3.Knt_KntId AND pod5.Pod_PodmiotTyp = 1
        LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
        LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = BZp_ZakID
        LEFT JOIN ' + @Operatorzy + ' ow on ow.Ope_OpeId = BZp_OpeZalId
        LEFT JOIN ' + @Operatorzy + ' om on om.Ope_OpeId = BZp_OpeModId
        LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'')'

SET @select3='
UNION ALL 

    SELECT
        BAZ.Baz_Nazwa bf, 
    
        BZd_Numer [dokumentNumer], 
        dokumentNumer_procid = 23014, dokumentNumer_orgid = BZd_BZdID,
        nrpon = ISNULL(pnr,''(BRAK)''),
        datpon = ISNULL(REPLACE(CONVERT(VARCHAR(10), pdat, 111), ''/'', ''-''),''(BRAK)''),
        opewkod = ISNULL(ow.Ope_Kod, ''ID:''+CAST(Bzd_OpeZalId as VARCHAR)),
        opewnazwa = ISNULL(ow.Ope_Nazwisko, ''ID:''+CAST(Bzd_OpeZalId as VARCHAR)),
        opemkod = ISNULL(om.Ope_Kod, ''ID:''+CAST(Bzd_OpeModId as VARCHAR)),
        opemnazwa = ISNULL(om.Ope_Nazwisko, ''ID:''+CAST(Bzd_OpeModId as VARCHAR)),

        dd.DDf_Symbol [Dokument Symbol],
        BZd_NumerPelny [dokumentNumerPelny],
        ISNULL(NULLIF(BZd_Opis,''''), ''(BRAK)'') [dokumentOpis],
        
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

        ''Zdarzenia k/b'' [zapisyZdarzenia], CASE WHEN BZd_Waluta = '''' THEN @Wal ELSE BZd_Waluta END [waluta], fp = FPl_Nazwa,
        REPLACE(CONVERT(VARCHAR(10), BZd_DataDok, 111), ''/'', ''-'') [dataDokumentu], MONTH(BZd_DataDok) [dataDokumentuMiesiac], DATEPART(quarter, BZd_DataDok) [dataDokumentuKwartal], YEAR(BZd_DataDok) [dataDokumentuRok], (datepart(DY, datediff(d, 0, BZd_DataDok) / 7 * 7 + 3)+6) / 7 [dataDokumentuTydzienRoku]/*DATEPART(isowk, BZp_DataDok)*/,
        REPLACE(CONVERT(VARCHAR(10), BZd_Termin, 111), ''/'', ''-'') [dataTerminPlatnosci], MONTH(BZd_Termin) [dataTerminPlatnosciMiesiac], DATEPART(quarter, BZd_Termin) [dataTerminPlatnosciKwartal], YEAR(BZd_Termin) [dataTerminPlatnosciRok], (datepart(DY, datediff(d, 0, BZd_Termin) / 7 * 7 + 3)+6) / 7 [dataTerminPlatnosciTydzienRoku]/*DATEPART(isowk, BZp_DataDok)*/,
        REPLACE(CONVERT(VARCHAR(10), BZd_DataRoz, 111), ''/'', ''-'') [dataRozliczenia], REPLACE(CONVERT(VARCHAR(10), BZd_DataReal, 111), ''/'', ''-'') [dataRealizacji],  
        GETDATE() [analizaData],
                CASE WHEN pod5.Pod_Nazwa1 IS NULL AND pod5.Pod_Nazwa2 IS NULL THEN ''(NIEOKREŚLONY)'' ELSE pod5.Pod_Nazwa1 + '' '' + pod5.Pod_Nazwa2 END [kontrahentNazwa], 
        kon_procid = CASE pod5.Pod_PodmiotTyp
            WHEN 1 THEN 20201
            WHEN 2 THEN 23002
            WHEN 3 THEN 24001
            WHEN 5 THEN 25005
            ELSE 20201
        END, kon_orgid = pod5.Pod_PodId,
        
        pod5.Pod_Kod [kontrahentKod],
        CASE 
            WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
            WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
            WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentTyp],
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
        END [kontrahentRodzaj],
        
        CASE WHEN knt3.Knt_LimitFlag = 1 THEN ''Tak'' ELSE ''Nie'' END [kontrahentLimit],
        knt3.Knt_LimitKredytu [kontrahentWartośćLimitu],
        CASE WHEN knt3.Knt_Termin > 7 THEN ''ponad 7 dni'' ELSE ''mniej niż 7 dni'' END [kontrahentTermin],

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
            ELSE ''(NIEOKREŚLONY)'' 
        end [kontrahentStatus],
        CASE 
            WHEN pod5.Pod_PodmiotTyp = 1 THEN COALESCE(NULLIF(pod5.Pod_Grupa, ''''), ''Pozostali'') 
            WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Banki''
            WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownicy/Wspólnicy''
            WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urzędy''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentGrupa],
        pod5.Pod_Wojewodztwo [kontrahent\Wojewodztwo], pod5.Pod_Miasto [kontrahentMiasto],pod5.Pod_Kraj [kontrahentKraj], pod5.Pod_NIP [kontrahentNIP],
        
        CASE WHEN pod.Pod_Nazwa1 IS NULL AND pod.Pod_Nazwa2 IS NULL THEN ''(NIEOKREŚLONY)'' ELSE pod.Pod_Nazwa1 + '' '' + pod.Pod_Nazwa2 END [kontrahentPierwotnyNazwa], 
        konPierwotny_procid = CASE BZd_PodmiotTyp
            WHEN 1 THEN 20201
            WHEN 2 THEN 23002
            WHEN 3 THEN 24001
            WHEN 5 THEN 25005
            ELSE 20201
        END, konPierwotny_orgid = BZd_PodmiotID,
        
        pod.Pod_Kod [kontrahentPierwotnyKod],
        CASE 
            WHEN BZd_PodmiotTyp = 1 THEN ''Kontrahent''
            WHEN BZd_PodmiotTyp = 2 THEN ''Bank''
            WHEN BZd_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN BZd_PodmiotTyp = 5 THEN ''Urząd''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentPierwotnyTyp],
        CASE
            WHEN BZd_PodmiotTyp = 2 THEN ''Bank''
            WHEN BZd_PodmiotTyp = 3 THEN ''Pracownik/Wspólnik''
            WHEN BZd_PodmiotTyp = 5 THEN ''Urząd''
            WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Dostawca = 1 AND knt1.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca/Dostawca''
            WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Dostawca = 1 THEN ''Dostawca''
            WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Odbiorca = 1 THEN ''Odbiorca''
            WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Konkurencja = 1 THEN ''Konkurencja''
            WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Partner = 1 THEN ''Partner''
            WHEN BZd_PodmiotTyp = 1 AND knt1.Knt_Rodzaj_Potencjalny = 1 THEN ''Klient Potencjalny''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentPierwotnyRodzaj],
        case knt1.knt_export
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
            ELSE ''(NIEOKREŚLONY)'' 
        end [kontrahentPierwotnyStatus],
        CASE 
            WHEN BZd_PodmiotTyp = 1 THEN COALESCE(NULLIF(pod.Pod_Grupa, ''''), ''Pozostali'')   
            WHEN BZd_PodmiotTyp = 2 THEN ''Banki''
            WHEN BZd_PodmiotTyp = 3 THEN ''Pracownicy/Wspólnicy''
            WHEN BZd_PodmiotTyp = 5 THEN ''Urzędy''
            ELSE ''(NIEOKREŚLONY)'' 
        END [kontrahentPierwotnyGrupa],
        pod.Pod_Wojewodztwo [kontrahentPierwotnyWojewodztwo], pod.Pod_Miasto [kontrahentPierwotnyMiasto],pod.Pod_Kraj [kontrahentPierwotnyKraj], pod.Pod_NIP [kontrahentPierwotnyNIP],
        ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [kategoriaSzczegolowa], 
        zakladSymbol = ''(NIEPRZYPISANY)'', 
        zakladNazwa = ''(NIEPRZYPISANY)'', 
        ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [kategoriaOgolna], BRa_Nazwa [rachunek], BRa_Akronim [rachAkronim], BRa_Symbol [rachSymbol],
        CASE
            WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=1 THEN ''Nierozliczony''
            WHEN BZd_Rozliczono=2 THEN ''Rozliczony''
            WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=2 THEN ''Częściowo Rozliczony''
            WHEN BZd_Rozliczono=0 AND BZd_Rozliczono2=0 THEN ''Nie Podlega Rozliczeniu'' 
            WHEN BZd_Rozliczono=2 AND BZd_Rozliczono2=2 THEN ''W Rozliczeniu Całości''
        END [statusDokumentu],
        CASE
            WHEN BZd_Rozliczono=0 AND BZd_Rozliczono2=0 THEN ''Nie Podlega Rozliczeniu'' 
            WHEN ISNULL(BRK_KwotaSys,0) = 0 THEN ''Nierozliczony''
            ELSE ''Częściowo Rozliczony''
        END [statusDokumentuDzien],
        CASE
            WHEN BZd_Stan = 0 THEN ''Bufor''
            WHEN BZd_Stan = 1 THEN ''Do Realizacji''
            WHEN BZd_Stan = 2 THEN ''Wysłane''
            WHEN BZd_Stan = 3 THEN ''Zrealizowane''
            ELSE ''(NIEOKREŚLONY)'' 
        END [stanDokumentu],'
SET @select4 = '
        CASE 
            WHEN ''' + @TERMINDATA + ''' = ''D'' THEN
                CASE
                    WHEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) < 1 THEN ''1. Terminowe''
                    WHEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN 1 AND ' + convert(varchar, @PRZEDZIAL1) + ' THEN ''2. Przeterminowane do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL1) + ') + '' dni''
                    WHEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL1) + '+1 AND ' + convert(varchar, @PRZEDZIAL2) + ' THEN ''3. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL1) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL2) + ') + '' dni''
                    WHEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL2) + '+1 AND ' + convert(varchar, @PRZEDZIAL3) + ' THEN ''4. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL2) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL3) + ') + '' dni''
                    WHEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL3) + '+1 AND ' + convert(varchar, @PRZEDZIAL4) + ' THEN ''5. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL3) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL4) + ') + '' dni''
                    WHEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL4) + '+1 AND ' + convert(varchar, @PRZEDZIAL5) + ' THEN ''6. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL4) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL5) + ') + '' dni''
                    ELSE ''7. Przeterminowane powyżej '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL5) + ') + '' dni'' 
                END
            ELSE
                CASE
                    WHEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) < 1 THEN ''1. Terminowe''
                    WHEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN 1 AND ' + convert(varchar, @PRZEDZIAL1) + ' THEN ''2. Przeterminowane do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL1) + ') + '' dni''
                    WHEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL1) + '+1 AND ' + convert(varchar, @PRZEDZIAL2) + ' THEN ''3. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL1) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL2) + ') + '' dni''
                    WHEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL2) + '+1 AND ' + convert(varchar, @PRZEDZIAL3) + ' THEN ''4. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL2) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL3) + ') + '' dni''
                    WHEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL3) + '+1 AND ' + convert(varchar, @PRZEDZIAL4) + ' THEN ''5. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL3) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL4) + ') + '' dni''
                    WHEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)) BETWEEN ' + convert(varchar, @PRZEDZIAL4) + '+1 AND ' + convert(varchar, @PRZEDZIAL5) + ' THEN ''6. Przeterminowane od '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL4) + ' + 1) + '' do '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL5) + ') + '' dni''
                    ELSE ''7. Przeterminowane powyżej '' + CONVERT(VARCHAR,' + convert(varchar, @PRZEDZIAL5) + ') + '' dni'' 
                END 
        END [terminZapadalnosci],
        CASE 
            WHEN ''' + @TERMINDATA + ''' = ''D'' THEN       
                CASE
                    WHEN BZd_Kierunek < 0 THEN NULL
                    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=1 THEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZd_Rozliczono=2 THEN 
                        CASE
                            WHEN BZd_DataRoz > convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120) THEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                            WHEN BZd_DataRoz > BZd_DataDok THEN DATEDIFF(day, BZd_DataDok, BZd_DataRoz) 
                            ELSE 0 
                        END
                    WHEN BZd_Rozliczono=2 AND BZd_Rozliczono2=2 THEN DATEDIFF(day, BZd_DataDok, BZd_DataRoz)
                    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=2 THEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZd_Rozliczono=0 AND BZd_Rozliczono2=0 THEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    ELSE 0 
                END 
            ELSE
                CASE
                    WHEN BZd_Kierunek < 0 THEN NULL
                    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=1 THEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZd_Rozliczono=2 THEN 
                        CASE
                            WHEN BZd_DataRoz > convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120) THEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                            WHEN BZd_DataRoz > BZd_Termin THEN DATEDIFF(day, BZd_Termin, BZd_DataRoz) 
                            ELSE 0 
                        END
                    WHEN BZd_Rozliczono=2 AND BZd_Rozliczono2=2 THEN DATEDIFF(day, BZd_Termin, BZd_DataRoz)
                    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=2 THEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZd_Rozliczono=0 AND BZd_Rozliczono2=0 THEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    ELSE 0
                END 
        END [liczbaDniPrzeterminowaniaNaleznosci],'
SET @select5 = '

        CASE 
            WHEN ''' + @TERMINDATA + ''' = ''D'' THEN               
                CASE
                    WHEN BZd_Kierunek > 0 THEN NULL
                    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=1 THEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZd_Rozliczono=2 THEN 
                        CASE
                            WHEN BZd_DataRoz > convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120) THEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                            WHEN BZd_DataRoz > BZd_DataDok THEN DATEDIFF(day, BZd_DataDok, BZd_DataRoz)                         
                            ELSE 0
                        END
                    WHEN BZd_Rozliczono=2 AND BZd_Rozliczono2=2 THEN DATEDIFF(day, BZd_DataDok, BZd_DataRoz)
                    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=2 THEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZd_Rozliczono=0 AND BZd_Rozliczono2=0 THEN DATEDIFF(day, BZd_DataDok, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    ELSE 0 
                END
            ELSE
                CASE
                    WHEN BZd_Kierunek > 0 THEN NULL
                    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=1 THEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZd_Rozliczono=2 THEN 
                        CASE
                            WHEN BZd_DataRoz > convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120) THEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                            WHEN BZd_DataRoz > BZd_Termin THEN DATEDIFF(day, BZd_Termin, BZd_DataRoz) 
                            ELSE 0
                        END
                    WHEN BZd_Rozliczono=2 AND BZd_Rozliczono2=2 THEN DATEDIFF(day, BZd_Termin, BZd_DataRoz)
                    WHEN BZd_Rozliczono=1 AND BZd_Rozliczono2=2 THEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    WHEN BZd_Rozliczono=0 AND BZd_Rozliczono2=0 THEN DATEDIFF(day, BZd_Termin, convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120))
                    ELSE 0 
                END
        END [liczbaDniPrzeterminowaniaZobowiazania],
        CASE WHEN BZd_Kierunek > 0 THEN BZd_KwotaSys ELSE NULL END [naleznosci], 
        CASE WHEN BZd_Kierunek < 0 THEN BZd_KwotaSys ELSE NULL END [zobowiazania],
        CASE WHEN BZd_Kierunek > 0 THEN BZd_Kwota ELSE NULL END [naleznosciWaluta], 
        CASE WHEN BZd_Kierunek < 0 THEN BZd_Kwota ELSE NULL END [zobowiazaniaWaluta],
        CASE WHEN BZd_Kierunek > 0 THEN ISNULL(BZd_KwotaSys - IsNull(BRK_KwotaSys,0),0) ELSE NULL END [naleznosciNieRozliczone], 
        CASE WHEN BZd_Kierunek < 0 THEN ISNULL(BZd_KwotaSys - IsNull(BRK_KwotaSys,0),0) ELSE NULL END [zobowiazaniaNieRozliczone],
        CASE WHEN BZd_Kierunek > 0 THEN ISNULL(BZd_Kwota - IsNull(BRK_Kwota,0),0) ELSE NULL END [naleznosciNieRozliczoneWaluta], 
        CASE WHEN BZd_Kierunek < 0 THEN ISNULL(BZd_Kwota - IsNull(BRK_Kwota,0),0) ELSE NULL END [zobowiazaniaNieRozliczoneWaluta],
        CASE WHEN BZd_KwotaSys - BRK_KwotaSys = 0 THEN ''Tak'' ELSE ''Nie'' END [czyRozliczony]
        ' + @atrybuty + @atrybutyDok + '
    FROM
        CDN.BnkZdarzenia
        LEFT JOIN #tmpSeria ser ON BZd_DDfId = DDf_DDfID
        LEFT JOIN CDN.DokDefinicje dd ON BZd_DDfId = dd.DDf_DDfID
        LEFT JOIN CDN.BnkRachunki ON BZd_BRaID = BRa_BRaID
        LEFT JOIN CDN.PodmiotyView pod ON BZd_PodmiotID = pod.Pod_PodId AND BZd_PodmiotTyp = pod.Pod_PodmiotTyp
        LEFT JOIN CDN.Kontrahenci knt1 ON BZd_PodmiotID=knt1.Knt_KntId AND BZd_PodmiotTyp = 1
        LEFT JOIN CDN.Kategorie kat1 ON BZd_KatID = kat1.Kat_KatID
        LEFT OUTER JOIN (
            SELECT
                BRK_KwotaSys = SUM(CASE WHEN BRR_ZDokTyp = BRK_LDokTyp AND BRR_ZDokID = BRK_LDokID THEN BRK_KwotaSysL ELSE BRK_KwotaSysP END),
                BRK_Kwota = SUM(CASE WHEN BRR_ZDokTyp = BRK_LDokTyp AND BRR_ZDokID = BRK_LDokID THEN BRK_Kwota ELSE BRK_Kwota END),
                BRR_ZDokId, BRR_ZDokTyp
            FROM CDN.BnkRozKwoty JOIN CDN.BnkRozRelacje ON BRK_BRKId = BRR_BRKId
            WHERE BRK_DataDok <= convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)
            GROUP BY BRR_ZDokId, BRR_ZDokTyp
        ) AS Rozliczenia ON BRR_ZDokTyp = BZd_TypDokumentuKB AND BRR_ZDokId = BZd_BZdID
        LEFT JOIN #tmpKonAtr KonAtr ON pod.Pod_PodId = KonAtr.KnA_PodmiotId AND pod.Pod_PodmiotTyp = KonAtr.KnA_PodmiotTyp
        LEFT JOIN #tmpDokAtr DokAtr ON BZd_DokumentID  = DokAtr.DAt_TrNId AND BZd_DokumentTyp = DokAtr.DokTyp
        LEFT JOIN CDN.FormyPlatnosci ON BZd_FPlId = FPl_FPlId
        LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod.Pod_GlID = pod5.Pod_PodId and pod.Pod_GlKod = pod5.Pod_Kod
        LEFT OUTER JOIN CDN.Kontrahenci knt3 ON pod5.Pod_PodID=knt3.Knt_KntId AND pod5.Pod_PodmiotTyp = 1
        LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
        LEFT JOIN (
SELECT
BDE_DokId pzr,
MAX(BDN_NumerPelny) pnr,
MAX(BDN_DataDok) pdat
FROM
CDN.BnkDokElem 
JOIN CDN.BnkDokNag ON BDE_BDNId = BDN_BDNId AND BDN_Typ = 222 
GROUP BY BDE_DokId
) pon on pzr = BZd_DokumentID
LEFT JOIN ' + @Operatorzy + ' ow on ow.Ope_OpeId = BZd_OpeZalId
LEFT JOIN ' + @Operatorzy + ' om on om.Ope_OpeId = BZd_OpeModId
LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'')
) AS Kalendar 
WHERE convert(datetime,dataDokumentu, 111) <= convert(datetime,''' + convert(varchar, @DATA, 120) + ''', 120)'

IF @ROZLICZONE = 'NIE' SET @select5 = @select5 + 
' AND ((NULLIF(naleznosciNieRozliczone,0) IS NOT NULL) OR (NULLIF(zobowiazaniaNieRozliczone,0) IS NOT NULL))'

EXEC(@select + @select2 + @select3 + @select4 + @select5)

DROP TABLE #tmpDokAtr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpSeria  









