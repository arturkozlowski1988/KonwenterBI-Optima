/*
* Raport Kadr i Płac 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @bazaFirmowa varchar(max);
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
DECLARE @bazaKonf varchar(max)
SET @bazaKonf = (Select SYS_Wartosc from cdn.SystemCDN WHERE SYS_ID = 1002)
DECLARE @serwerKonf varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
DECLARE @Bazy varchar(max);
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 
DECLARE @Operatorzy varchar(max);
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 


--Wyliczanie wymiaru etatu
select PRE_PraId PrId,
PRE_DataOd as PrData,
PRE_EtaStawka PrStawka,
CONVERT(VARCHAR(2),PRE_ETAEtatL) + '/' + CONVERT(VARCHAR(2),PRE_ETAEtatM) PrWymiar,
PRE_WaznoscBadanOkres PrBad
into #tmpetat
from CDN.PracEtaty r
join
(select PRE_PraId PrId,
MAX(PRE_DataOd) as PrData
from CDN.PracEtaty
where PRE_ETAEtatL <> 0 and PRE_ETAEtatM <> 0
group by PRE_PraId ) e on e.PrId = r.PRE_PraId and e.PrData = r.PRE_DataOd
order by PRE_PraId

--Wybór dat obowiązywania z najnowszych umów
SELECT DISTINCT * INTO #tmpUmowy FROM(
SELECT WPL_WplId as UMW_WplId, UMW_PraId, UMW_UmwId, UMW_DataOd, UMW_DataDo, UMW_NumerPelny, RANK() OVER(PARTITION BY UMW_PraId, WPL_WplId ORDER BY UMW_UmwId DESC) rank
FROM CDN.Wyplaty
JOIN CDN.Umowy 
    ON WPL_PraId = UMW_PraId 
    AND CAST(UMW_DataOd AS Date) <= CAST(WPL_DataDo AS Date) 
    AND CAST(UMW_DataDo AS Date) >= CAST( WPL_DataOd AS Date)
WHERE UMW_UmwId is not null) umowy WHERE rank = 1

--Wyliczanie hierarchii wydziałów
SELECT DZL_DzlId [gid], DZL_Kod [kod], DZL_ParentId [parId], DZL_Poziom [poziom] INTO #tmpTwrGr FROM CDN.Dzialy

DECLARE @poziom int
DECLARE @poziom_max int
DECLARE @sql nvarchar(max)
SELECT @poziom_max = MAX(poziom) FROM #tmpTwrGr
SET @poziom = @poziom_max
SET @sql = N''

WHILE @poziom > 0  
BEGIN
    SET @sql = N'ALTER TABLE #tmpTwrGr ADD Poziom' + CAST(@poziom AS nvarchar) + N' nvarchar(100), ONr' + CAST(@poziom AS nvarchar) + N' nvarchar(100)'
    EXEC(@sql)

    
    IF @poziom = @poziom_max 
        BEGIN
            SET @sql = N'UPDATE #tmpTwrGr
                SET ONr' + CAST(@poziom AS nvarchar) +  '= parId '
            EXEC(@sql)
            
            SET @sql = N'UPDATE #tmpTwrGr
                SET Poziom' + CAST(@poziom AS nvarchar) + ' = CASE WHEN ' + CAST(@poziom AS nvarchar) + ' > poziom THEN ''('' + kod + '')'' ELSE kod END'
            EXEC(@sql)
        END
    ELSE
        BEGIN 
            SET @sql = N'UPDATE c
                SET c.Poziom' + CAST(@poziom AS nvarchar) + N' = (
                    CASE WHEN c.poziom =' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.kod AS nvarchar)
                         WHEN c.poziom <' + CAST(@poziom AS nvarchar) + N' THEN ''('' + CAST(c.kod AS nvarchar) + '')''
                         WHEN p.poziom <' + CAST(@poziom AS nvarchar) + N' THEN ''('' + CAST(p.kod AS nvarchar) + '')''
                    ELSE p.kod END)  
                FROM #tmpTwrGr c
                LEFT JOIN #tmpTwrGr p
                ON c.ONr' + CAST(@poziom + 1 AS nvarchar) + '= p.gid '
            EXEC(@sql)
            
            SET @sql = N'UPDATE c
                SET c.ONr' + CAST(@poziom AS nvarchar) + N' = (
                    CASE WHEN c.poziom <=' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.parId AS nvarchar)
                    ELSE CAST(p.parId AS nvarchar) END)  
                FROM #tmpTwrGr c
                LEFT JOIN #tmpTwrGr p
                ON c.ONr' + CAST(@poziom + 1 AS nvarchar) + '= p.gid '
                EXEC(@sql)
        END
    SET @poziom = @poziom - 1
END

declare @select varchar(max);
declare @kolumny varchar(max);
declare @i int

set @kolumny = ''

set @i=1
while (@i<=@poziom_max)
begin
    set @kolumny = @kolumny + ', CASE WHEN Poz.Poziom' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' + LTRIM(@i) + ' END [Wydział Poziom ' + LTRIM(@i) + '] '
    set @i = @i + 1
end

--Wyliczanie Atrybutów Pracowników
DECLARE @atrybut_id int, @atrybut_kod nvarchar(100), @atrybuty varchar(max), @sqlA nvarchar(max), @atrybut_Typ int, @atrybut_format nvarchar(21),
@atrybutyDataOd varchar(max), @atrybutyDataDo varchar(max);

DECLARE atrybut_cursor CURSOR FOR
SELECT DISTINCT OAT_AtkId, REPLACE(ATK_Nazwa, ']', '_'), ATK_Typ, ATK_Format
FROM CDN.OAtrybuty
JOIN CDN.OAtrybutyKlasy ON OAT_AtkId = ATK_AtkId
WHERE OAT_PrcId IS NOT NULL;
--AND OAT_AtkId IS NOT NULL;

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_Typ,@atrybut_format;

SELECT DISTINCT OAT_PrcId INTO #tmpKonAtr FROM CDN.OAtrybuty

SET @atrybuty = ''
SET @atrybutyDataOd = ''
SET @atrybutyDataDo = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sqlA = N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    SET @sqlA = @sqlA + N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N' Od] nvarchar(max)'
    SET @sqlA = @sqlA + N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N' Do] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpKonAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = 
         CASE WHEN ' + convert(varchar,@atrybut_Typ) + ' = 3  THEN REPLACE(ATR.ATH_Wartosc,'','',''.'') ELSE ATR.ATH_Wartosc END,
        [' + CAST(@atrybut_kod AS nvarchar(50)) +  ' Od] = REPLACE(CONVERT(VARCHAR(10), OAT_OkresOd, 111), ''/'', ''-''),
        [' + CAST(@atrybut_kod AS nvarchar(50)) +  ' Do] = REPLACE(CONVERT(VARCHAR(10), OAT_OkresDo, 111), ''/'', ''-'')
        FROM CDN.OAtrybutyHist ATR 
        JOIN CDN.OAtrybuty OA ON OA.OAT_OatId = ATR.ATH_OatId AND ATR.ATH_DataDo = (SELECT MAX(A1.ATH_DataDo) FROM CDN.OAtrybutyHist A1 WHERE A1.ATH_OatId = ATR.ATH_OatId)
        JOIN #tmpKonAtr TM ON OA.OAT_PrcId = TM.OAT_PrcId
        WHERE ATR.ATH_AtkId = ' + CAST(@atrybut_id AS nvarchar)

    SET @sqlA = N'UPDATE #tmpKonAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = 
          CASE WHEN ' + convert(varchar,@atrybut_Typ) + ' = 3 AND ''' + convert(varchar,@atrybut_Format) + ''' <> ''Data'' THEN REPLACE(ATR.ATH_Wartosc,'','',''.'') ELSE 
           CASE WHEN ' + convert(varchar,@atrybut_Typ) + ' = 3 AND ''' + convert(varchar,@atrybut_Format) + ''' = ''Data'' THEN 
             REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.ATH_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'')
             ELSE ATR.ATH_Wartosc  END
          END,
        [' + CAST(@atrybut_kod AS nvarchar(50)) +  ' Od] = REPLACE(CONVERT(VARCHAR(10), OAT_OkresOd, 111), ''/'', ''-''),
        [' + CAST(@atrybut_kod AS nvarchar(50)) +  ' Do] = REPLACE(CONVERT(VARCHAR(10), OAT_OkresDo, 111), ''/'', ''-'')
        FROM CDN.OAtrybutyHist ATR 
        JOIN CDN.OAtrybuty OA ON OA.OAT_OatId = ATR.ATH_OatId AND ATR.ATH_DataDo = (SELECT MAX(A1.ATH_DataDo) FROM CDN.OAtrybutyHist A1 WHERE A1.ATH_OatId = ATR.ATH_OatId)
        JOIN #tmpKonAtr TM ON OA.OAT_PrcId = TM.OAT_PrcId
        WHERE ATR.ATH_AtkId = ' + CAST(@atrybut_id AS nvarchar)

    EXEC(@sqlA)    
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Pracownik Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    SET @atrybutyDataOd = @atrybutyDataOd + N', KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + ' Od] AS [Pracownik Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ' Data Od]'         
    SET @atrybutyDataDo = @atrybutyDataDo + N', KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + ' Do] AS [Pracownik Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ' Data Do]'         
    
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod,@atrybut_Typ,@atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

SELECT PLN_praid,PLN_Rok, sum(PLN_WykorzystaneF) Wykorzystane, PLN_LnbId into #tmpLimityRoczne FROM Cdn.PracLimit group by PLN_praid, PLN_Rok, PLN_LnbId order by pln_praid asc, PLN_ROk asc
SELECT TNB_TwpId,TNB_LnbId,TNB_TyuId,TNB_TnkId ,sum(tnb_TYP) as pomocnikGrupowania INTO #tmpLimity FROM CDN.TypNieobec   GROUP BY TNB_TwpId,TNB_LnbId,TNB_TyuId,TNB_TnkId   order by TNB_TwpId asc

--Wyliczenie wypłaty
SELECT 
    WPL_WplId [wyplataID],
    SUM(CASE WHEN TWP_WchodziDoWyplaty = 1 OR TWP_Rodzajzrodla = 35 OR WPE_Nazwa like 'Przychód PPK dla umów%' THEN
            CASE WHEN WPE_Wartosc < 0
                THEN 0 
                ELSE WPE_Wartosc
            END
            ELSE 0
        END) [brutto],
    SUM(CASE WHEN WPE_Nazwa = 'Dni pobytu za granicą (liczba diet)' THEN WPE_Wartosc*WPL_OddelegowanyDieta*WPL_KursLNalDieta/ISNULL(NULLIF(WPL_KursMNalDieta,0),1) ELSE 0 END) [dieta],
    SUM(CASE WHEN WPE_Nazwa = 'Podstawa ZUS opodatk. zagr.' or WPE_Nazwa = 'Wyrównanie podstawy ZUS opodatk. zagr.' THEN WPE_Wartosc ELSE 0 END ) [podstawaOpodatkowania]
INTO #Wyplaty
FROM CDN.PracEtaty 
    JOIN CDN.Wyplaty ON WPL_PraId = PRE_PraId AND CAST(Pre_DataOd AS Date) <= CAST(GetDate() AS Date) AND CAST(Pre_DataDo AS Date) >= CAST(GetDate() AS Date)
    JOIN CDN.WypElementy ON WPE_WplId = WPL_WplId
    JOIN CDN.TypWyplata ON WPE_TwpId = TWP_TwpId
group by WPL_WplId

SELECT *,
Gotowka/Suma * 100.0 GotowkaProcent,
Ror/Suma * 100.0 RorProcent
INTO #ProcentRor from (SELECT BZd_DokumentID,SUM(BZd_KwotaSys) Suma, 
SUM(CASE WHEN BZd_FPlId = 1 then BZd_KwotaSys else 0 end) as Gotowka,
SUM(CASE WHEN BZd_FPlId = 3 then BZd_KwotaSys else 0 end) as Ror 
FROM CDN.BnkZdarzenia WHERE BZd_DokumentTyp = 8 group by BZd_DokumentID)t
--Właściwe zapytanie
SET @select =
'SELECT 
    BAZ.Baz_Nazwa [Baza Firmowa], 
    WPL_NumerPelny [Dokument Numer],
    CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN DATEDIFF(d,PRE_ZatrudnionyOd, GETDATE())+1 ELSE DATEDIFF(d,PRE_ZatrudnionyOd, PRE_ZatrudnionyDo)+1 END [Okres Zatrudnienia w Dniach],
    PRE_Kod [Pracownik Kod],
    PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
    CASE WHEN PRE_ETARodzajUmowy = '''' THEN ''(NIEPRZYPISANE)'' ELSE PRE_ETARodzajUmowy END [Rodzaj Umowy], 
    CASE WHEN PRI_Archiwalny = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Archiwalny],
    CASE WHEN pr1.PRI_Typ = 1 THEN ''Pracownik'' ELSE ''Własciciel/Współpracownik'' END [Pracownik Typ],
    PrWymiar [Pracownik Etat],
    CASE 
        WHEN (SELECT SUM(PRI_Typ) FROM CDN.Pracidx WHERE PRE_PraId = PRI_PraId AND PRI_Typ > 2) = 10 THEN ''Etat'' 
        WHEN (SELECT SUM(PRI_Typ) FROM CDN.Pracidx WHERE PRE_PraId = PRI_PraId AND PRI_Typ > 2) = 20 THEN ''Umowa''
        WHEN (SELECT SUM(PRI_Typ) FROM CDN.Pracidx WHERE PRE_PraId = PRI_PraId AND PRI_Typ > 2) = 30 THEN ''Etat/Umowa''
        ELSE ''Bez Zatrudnienia'' END [Typ Zatrudnienia], 
    CASE WHEN sta.DKM_Nazwa IS NULL THEN ''(NIEPRZYPISANE)'' ELSE sta.DKM_Nazwa END [Pracownik Stanowisko], 
    CASE WHEN zwo.DKM_Nazwa IS NULL THEN ''(NIEPRZYPISANE)'' ELSE zwo.DKM_Nazwa END [Pracownik Przyczyna Zwolnienia], 
    isnull(ZakPracownik.Zak_Symbol,''(NIEPRZYPISANY)'') as [Pracownik Zakład Symbol],
    isnull(ZakPracownik.Zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Pracownik Zakład Nazwa Firmy],
    isnull(ZakListPlac.Zak_Symbol,''(NIEPRZYPISANY)'') as [Wypłata Zakład Symbol],
    isnull(ZakListPlac.Zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Wypłata Zakład Nazwa Firmy],
    CNT_Kod [Centrum Kod],
    CNT_Nazwa [Centrum Nazwa],

    CAST(ISNULL(NULLIF(CAST(PRE_KodZawoduSymbol AS VARCHAR(15)),''''),''(NIEPRZYPISANY)'')AS Varchar(15)) [Kod Zawodu],
    ISNULL(KZIS_Nazwa,''(NIEPRZYPISANY)'') AS [Kod Zawodu Nazwa],
    ISNULL(PRE_StNiepelnosp,''(NIEPRZYPISANY)'') [Kod Stopnia Niepełnosprawności],
    ISNULL(PRE_PrawoER,''(NIEPRZYPISANY)'') [Kod Prawa Do Emerytury/Renty],
    CASE WHEN u2.TYU_TyUb4 IS NOT NULL  THEN u2.TYU_TyUb4
    WHEN u1.TYU_TyUb4 IS NULL THEN ''(NIEPRZYPISANY)''
    ELSE u1.TYU_TyUb4 END AS [Kod Tytułu Ubezpieczenia],    
    CASE PRE_KodWyksztal
    WHEN ''11'' THEN ''Wykształcenie niepełne podstawowe''
    WHEN ''12'' THEN ''Wykształcenie podstawowe ukończone''
    WHEN ''20'' THEN ''Wykształcenie zasadnicze zawodowe''
    WHEN ''31'' THEN ''Wykształcenie średnie zawodowe/techniczne''
    WHEN ''32'' THEN ''Wykształcenie średnie ogólnokształcące''
    WHEN ''40'' THEN ''Wykształcenie policealne''
    WHEN ''50'' THEN ''Wykształcenie wyższe (w tym licencjat)''
    ELSE ''Brak danych'' END  [Pracownik Wykształcenie],

    CASE WHEN WPS_RodzajZrodla=4 THEN ''Tak'' ELSE ''Nie'' END [Element z Listy Dodatków],
    CASE TWP_AlgPotracenie WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Element Wypłaty Potrącenie],

    DATEDIFF(hour, ''18991230'',WPS_OkresCzas)  [Element Wypłaty Liczba Godzin],
    WPS_OkresDni [Element Wypłaty Liczba Dni],

    CASE 
        WHEN PRE_ETARodzajZatrudnienia = 0 THEN ''Pracownik''
        WHEN PRE_ETARodzajZatrudnienia = 1 THEN ''Właściciel''
        WHEN PRE_ETARodzajZatrudnienia = 2 THEN ''Osoba współpracująca''
        WHEN PRE_ETARodzajZatrudnienia = 4 THEN ''Uczeń I klasa''
        WHEN PRE_ETARodzajZatrudnienia = 5 THEN ''Uczeń II klasa''
        WHEN PRE_ETARodzajZatrudnienia = 6 THEN ''Uczeń III klasa''
        WHEN PRE_ETARodzajZatrudnienia = 7 THEN ''Młodociany''
    ELSE ''(NIEPRZYPISANE)'' END [Rodzaj Zatrudnienia], PRE_Kod [Liczba Pracowników],       
    LPL_NumerPelny [Lista Płac],
    DZL_Kod [Wydział z Wypłaty], Lok_Kod [Lokalizacja], DZL_AdresWezla [Wydział Adres Węzła], TWP_Nazwa [Element Wypłaty Typ], WPE_Nazwa [Element Wypłaty Nazwa],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') AS [Kategoria Szegółowa z Elementu], ISNULL(kat2.Kat_KodSzczegol, ''(PUSTA)'') AS [Kategoria Szegółowa z Nagłówka], 
    ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') AS [Kategoria Ogólna z Elementu], ISNULL(kat2.Kat_KodOgolny, ''(PUSTA)'') AS [Kategoria Ogólna z Nagłówka], 
    CASE WHEN TWP_WchodziDoWyplaty = 0 AND TWP_OpisAnalitCzasPracy = 0
        THEN ''NIE'' 
        ELSE ''TAK'' 
    END [Element Wypłaty Wpływ na Kwotę],
 CASE WHEN TWP_RodzajFIS = 1
        THEN ''NIE'' 
	WHEN TWP_RodzajFIS = 2 AND WPE_Wartosc = WPE_SwiadZwol
	THEN ''NIE''
	WHEN TWP_RodzajFIS = 2 AND WPE_Wartosc <> WPE_SwiadZwol
	THEN ''TAK''
        ELSE ''TAK'' 
    END [Element Wypłaty Opodatkowany],    
/*  
CASE WHEN TWP_WchodziDoWyplaty = 1 OR TWP_Rodzajzrodla = 35 OR WPE_Nazwa like ''Przychód PPK dla umów%'' THEN
        CASE WHEN PRE_Oddelegowany = 0 THEN CASE WHEN TWP_Rodzajzrodla = 35 OR WPE_Nazwa like ''Przychód PPK dla umów%'' THEN 0 ELSE WPE_Wartosc END - WPE_SklEmerPrac-WPE_SklRentPrac-WPE_SklChorPrac-WPE_SklWypadPrac-WPE_ZalFis-WPE_SklZdrowPrac-WPE_SklZdrowSuma-WPE_SklPPKPrac1-WPE_SklPPKPrac2 ELSE
            CASE WHEN TWP_RodzajZrodla IN (1, 14) THEN 
                CASE WHEN brutto - WPLE.dieta < WPLE.podstawaOpodatkowania THEN
                    WPE_Wartosc - (WPLE.podstawaOpodatkowania - WPLE.podstawaOpodatkowania*0.1371)*0.09 - WPLE.podstawaOpodatkowania*0.1371
                ELSE
                    WPE_Wartosc - (WPLE.brutto - WPLE.dieta - (WPLE.brutto - WPLE.dieta)*0.1371)*0.09 - (WPLE.brutto - WPLE.dieta)*0.1371
                END ELSE WPE_Wartosc 
            END
        END ELSE 0
    END [Wypłata Wartość Netto],
    CASE WHEN TWP_WchodziDoWyplaty = 1 OR TWP_Rodzajzrodla = 35 OR WPE_Nazwa like ''Przychód PPK dla umów%'' THEN WPE_Wartosc
    ELSE 0 END [Suma Elementów Wypłaty],
*/
    CASE WHEN TWP_WchodziDoWyplaty = 1 THEN
        WPE_Wartosc - WPE_SklEmerPrac-WPE_SklRentPrac-WPE_SklChorPrac-WPE_SklWypadPrac-WPE_ZalFis-WPE_SklZdrowPrac-WPE_SklZdrowSuma-WPE_SklPPKPrac1-WPE_SklPPKPrac2 
    ELSE - WPE_SklEmerPrac-WPE_SklRentPrac-WPE_SklChorPrac-WPE_SklWypadPrac-WPE_ZalFis-WPE_SklZdrowPrac-WPE_SklZdrowSuma-WPE_SklPPKPrac1-WPE_SklPPKPrac2
    END 
    [Wypłata Wartość Netto],

    CASE WHEN PRE_Oddelegowany = 1 AND TWP_WchodziDoWyplaty = 0 THEN 0 ELSE
    WPE_Wartosc 
    END [Suma Elementów Wypłaty],

    CASE WHEN TWP_RodzajZrodla <> 1 or TWP_WchodziDoWyplaty = 0 THEN 0 ELSE WPE_Wartosc END [Wypłata Wynagrodzenie Zasadnicze],

    WPE_SklEmerPrac + WPE_SklRentPrac + WPE_SklChorPrac + WPE_SklWypadPrac [Składka ZUS U], 
    WPE_SklEmerFirma + WPE_SklRentFirma + WPE_SklChorFirma + WPE_SklWypadFirma + WPE_SklFP + WPE_SklFGSP [Składka ZUS P],
    CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklEmerFirma + WPE_SklRentFirma + WPE_SklChorFirma + WPE_SklWypadFirma + WPE_SklFP + WPE_SklFGSP END [Składka ZUS P bez Mac. i Wych.],
    WPE_Koszty [Koszty Uzyskania], WPE_ZalFis + WPE_SklZdrowPrac + WPE_SklZdrowSuma [Zal. Podatku z Ubezp. Zdrow.],
    WPE_Ulga [Ulga Podatkowa], WPE_ZalFis [Zaliczka Podatku do US], WPE_NalFis [Naliczona Zaliczka Podatku], WPE_PodstEmer [Podstawa Składki Emerytalnej], 
    WPE_SklEmerPrac [Składka Emerytalna U], WPE_SklEmerFirma [Składka Emerytalna P],    WPE_PodstRent [Podstawa Składki Rentowej],
    WPE_SklRentPrac [Składka Rentowa U], WPE_SklRentFirma [Składka Rentowa P], WPE_PodstChor [Podstawa Składki Chorobowej], 
    WPE_SklChorPrac [Składka Chorobowa U], WPE_SklChorFirma [Składka Chorobowa P], WPE_PodstWypad [Podstawa Składki Wypadkowej],
    WPE_SklWypadPrac [Składka Wypadkowa U],WPE_SklWypadFirma [Składka Wypadkowa P], WPE_PodstFP [Podstawa Składki na FP], 
    WPE_SklFP [Składka na FP], WPE_PodstFGSP [Podstawa Składki na FGŚP], WPE_SklFGSP [Składka na FGŚP], WPE_PodstFEP [Podstawa Składki na FEP],
    WPE_SklFEP [Składka na FEP], WPE_PodstZdrow [Podstawa Składki Zdrowotnej], WPE_SklZdrowPrac [Składka Zdrowotna (odl.)],
    WPE_SklZdrowSuma [Składka Zdrowotna (od netto)], WPE_SklZdrowPrac + WPE_SklZdrowSuma [Składka Zdrowotna (pob.) U], WPE_SklZdrowFirma [Składka Zdrowotna (pob.) P],
    CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklEmerPrac END [Składka Emerytalna U bez Mac. i Wych.], 
    CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklEmerFirma END [Składka Emerytalna P bez Mac. i Wych.],
    CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklRentPrac END [Składka Rentowa U bez Mac. i Wych.],
    CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklRentFirma END [Składka Rentowa P bez Mac. i Wych.]
    ,WEP_KWOTa2 [Stawka Wyliczona ze Składników Zmiennych], -- dla elementu wypłaty "Wynagrodzenie za czas urlopu"
    --wg Barbary Maciołek z optimy,liczac koszty na pewno wyłączyć składki zapisane w elementach wypłaty mających kod ubezpieczenia (WPE_TyUb) 1211xx, 1240xx (gdzie te dwa ostanie znaki xx to dowolne dwie cyfry),
    -- bo są finansowane przez budżet państwa, i być może dla kodów 05xxxx (zapisywane w wypłacie jako liczba 5 cyfrowa zaczynająca się od 5), bo to są wypłaty właścicieli i osób z nimi współpracujących, których składki są finansowane przez właściciela
    CASE WHEN SUBSTRING(CAST(WPE_TyUb as nvarchar), 1,4) = ''1211'' OR SUBSTRING(CAST(WPE_TyUb as nvarchar), 1,4) = ''1240''  THEN 0 
	when 	TWP_PdzId IN (332,334,336,311,312,313,314,212,214,215,216,315,316,317,318,319,320,321,322,323,324,325,326,327,328,329) THEN 0
	ELSE  IIF(TWP_KosztFirma = 1, WPE_Wartosc, 0)  + WPE_SklEmerFirma + WPE_SklRentFirma +  WPE_SklWypadFirma + WPE_SklFP + WPE_SklFGSP + WPE_SklFEP  END [Całkowity Koszt Zatrudnienia Pracownika],
    case when zestaw.PZE_czasWolne is not null then  (DATEDIFF(hour, ''18991230'', zestaw.PZE_czasWolne)) 
    WHEN pzepraid IS NOT NULL THEN czasWolne else null end  as [Zestawienia Czas Wolny godziny], 
    case when zestaw.PZE_Nadgodziny50 is not null then  (DATEDIFF(hour, ''18991230'', zestaw.PZE_Nadgodziny50)) 
    WHEN pzepraid IS NOT NULL THEN Nadgodziny50 else null end  as [Zestawienia Nadgodziny 50 godziny],
    case when zestaw.PZE_Nadgodziny100 is not null then  (DATEDIFF(hour, ''18991230'', zestaw.PZE_Nadgodziny100)) 
    WHEN pzepraid IS NOT NULL THEN Nadgodziny100 else null end  as [Zestawienia Nadgodziny 100 godziny],
    case when zestaw.PZE_NadgodzinySW is not null then  (DATEDIFF(hour, ''18991230'', zestaw.PZE_NadgodzinySW)) 
    WHEN pzepraid IS NOT NULL THEN NadgodzinySW else null end  as [Zestawienia Nadgodziny Święta godziny],
    case when zestaw.PZE_CzasSW is not null then  (DATEDIFF(hour, ''18991230'', zestaw.PZE_CzasSW)) 
    WHEN pzepraid IS NOT NULL THEN PZE_CzasSW else null end  as [Zestawienia Czas Święta godziny]
    ,WPE_PodstPPK [Podstawa Składki PPK]
    ,WPE_SklPPKPrac1 [Składka PPK Podstawowa U]
    ,WPE_SklPPKPrac2 [Składka PPK Dodatkowa U]
    ,WPE_SklPPKFirma1 [Składka PPK Podstawowa P]
    ,WPE_SklPPKFirma2 [Składka PPK Dodatkowa P]
    ,CASE WHEN (LPL_DekID is null and LPL_KPRID is null and LPL_PreDekID is null) THEN ''NIE'' ELSE ''TAK'' END [Lista Płac Zaksięgowana]
    ,lpl.DDF_Symbol [Lista Płac Typ]
    ,CASE WHEN PRE_ETAMinimalna = 0 THEN Cast(PRE_EtaStawka as varchar) ELSE CFW_Wartosc END [Pracownik Stawka]
    ,CASE rob.DKM_Robotnicze WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Stanowisko Robotnicze]
    ,CASE WHEN PRE_ZatrudnionyOd = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE CASE WHEN PRE_ZatrudnionyDo > GetDate() THEN CASE WHEN datediff(yy,PRE_ZatrudnionyOd,GetDate()) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PRE_ZatrudnionyOd,GetDate()) AS VARCHAR(10)),''(BRAK)'') END ELSE CASE WHEN datediff(yy,PRE_ZatrudnionyOd,PRE_ZatrudnionyDo) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PRE_ZatrudnionyOd,PRE_ZatrudnionyDo) AS VARCHAR(10)),''(BRAK)'') END END END [Pracownik Lata Pracy]
    ,ISNULL(CAST (datediff(yy,PRE_DataUr,GetDate()) AS VARCHAR(10)),''(BRAK)'') [Pracownik Wiek]
    ,ISNULL(NULLIF(PRE_Pesel, ''''), ''(BRAK)'') [Pracownik PESEL]
    ,CASE PRE_Plec 
        WHEN ''K'' THEN ''Kobieta''
        WHEN ''M'' THEN ''Mężczyzna''
        ELSE ''(BRAK)''
    END [Pracownik Płeć]
    ,CASE PRE_Plec
        WHEN ''K'' THEN
            CASE
                WHEN CAST(datediff(yy,PRE_DataUr,GetDate()) AS INT) >= 56 THEN ''Tak''
                WHEN CAST(datediff(yy,PRE_DataUr,GetDate()) AS INT) < 56 THEN ''Nie''
                ELSE ''(BRAK)''
            END
        WHEN ''M'' THEN 
            CASE
                WHEN CAST(datediff(yy,PRE_DataUr,GetDate()) AS INT) >= 61 THEN ''Tak'' 
                WHEN CAST(datediff(yy,PRE_DataUr,GetDate()) AS INT) < 61 THEN ''Nie''
                ELSE ''(BRAK)''
            END
        ELSE ''(BRAK)''
    END [Pracownik Wiek Przedemerytalny]
    ,CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN
        CASE WHEN DATEDIFF(year,PRE_ZatrudnionyOd, GETDATE()) % 5 = 0 AND DATEDIFF(year,PRE_ZatrudnionyOd, GETDATE()) >= 5
            THEN CAST(DATEDIFF(year,PRE_ZatrudnionyOd, GETDATE()) AS VARCHAR(3))
            ELSE ''(BRAK)''
        END
    ELSE
        CASE WHEN DATEDIFF(year,PRE_ZatrudnionyOd, PRE_ZatrudnionyDo) % 5 = 0 AND DATEDIFF(year,PRE_ZatrudnionyOd, PRE_ZatrudnionyDo) >= 5
            THEN CAST(DATEDIFF(year,PRE_ZatrudnionyOd, PRE_ZatrudnionyDo) AS VARCHAR(3))
            ELSE ''(BRAK)''
        END
    END [Pracownik Jubileusz]
    ,ISNULL(NULLIF(PRE_RachunekNr, ''''), ''(BRAK)'') [Pracownik Nr Konta Bankowego]
    ,ISNULL(NULLIF(PRE_Obywatelstwo, ''''), ''(BRAK)'') [Pracownik Obywatelstwo]
    ,''ul. '' + ISNULL(NULLIF(PRE_MLDUlica, ''''), ''(BRAK)'')
        + '' '' + ISNULL(NULLIF(PRE_MLDNrDomu, ''''), ''(BRAK)'')
        + CASE WHEN NULLIF(PRE_MLDNrLokalu, '''') IS NULL THEN '''' ELSE ''/'' + PRE_MLDNrLokalu END
        + '', '' + ISNULL(NULLIF(PRE_MLDKodPocztowy, ''''), ''(BRAK)'')
        + '' '' +  ISNULL(NULLIF(PRE_MLDMiasto, ''''), ''(BRAK)'') [Pracownik Dane Adresowe]
    ,ISNULL(NULLIF(PRE_HDKPrawoJazdyKat, ''''), ''(BRAK)'') [Pracownik Kategoria Prawa Jazdy]
    ,CASE WHEN PRE_HDKPrawoJazdy = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Prawo Jazdy]
    ,ISNULL(NULLIF(PRE_Opis, ''''), ''(BRAK)'') [Pracownik Opis]
    ,ISNULL(NULLIF(PRE_HDKEmail, ''''), ''(BRAK)'') [Pracownik Dane Kontaktowe E-mail]
    ,ISNULL(NULLIF(PRE_HDKTelefon1, ''''), ''(BRAK)'') [Pracownik Dane Kontaktowe Telefon]
    ,ISNULL(NULLIF(PRE_NipE, ''''), ''(BRAK)'') [Pracownik NIP]
    ,CASE PRE_PODKosztyTytul
        WHEN 0 THEN ''(BRAK)''
        WHEN 1 THEN ''Z jednego stosunku pracy''
        WHEN 2 THEN ''Z więcej niż jednego stosunku pracy''
        WHEN 3 THEN ''Z jednego stosunku pracy, podwyższone o 25%''
        WHEN 4 THEN ''Z więcej niż jednego stosunku pracy, podwyższone o 25%''
        WHEN 5 THEN ''Na podstawie wydatków faktycznie poniesionych''
    END [Pracownik Koszty Uzyskania z Tytułu]
    ,ISNULL(NULLIF(PRE_ETAMiejsce, ''''), ''(BRAK)'') [Pracownik Miejsce Pracy]
    ,CASE PRE_ETAWymiar
        WHEN 1 THEN ''Stawka miesięczna''
        WHEN 2 THEN ''Stawka godzinowa''
    END [Pracownik Rodzaj Stawki]
    ,ISNULL(NULLIF(CONVERT(VARCHAR, PRE_KodKasyChorych), ''''), ''(BRAK)'') [Pracownik Kod NFZ]
    ,CASE WHEN PRE_UBZJestEmerytal = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Ubezpieczenie Emerytalne]
    ,CASE WHEN PRE_UBZJestRentowe = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Ubezpieczenie Rentowe]
    ,CASE WHEN PRE_UBZJestChorobowe = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Ubezpieczenie Chorobowe]
    ,CASE WHEN PRE_UBZJestWypad = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Ubezpieczenie Wypadkowe]
    ,ISNULL(NULLIF(PRE_WarSzczegolne, ''''), ''(BRAK)'') [Pracownik Ubezpieczenie Kod Pracy w Warunkach Szczególnych]
    ,CASE WHEN ISNULL(PRE_PrzekroczInformacja, 0) = 0 THEN ''Nie'' ELSE ''Tak'' END [Pracownik Ubezpieczenie Przekroczenie Podstawy Składek]
    ,CASE WHEN PRE_HDKGUSGlowneMiejscePracy = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik GUS Główne Miejsce Pracy]
    ,CASE WHEN PRE_HDKGUSPierwszaPraca = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik GUS Pierwsza Praca]
    ,CASE WHEN PRE_HDKGUSPoraNocna = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik GUS Praca w Porze Nocnej]
    ,CASE WHEN PRE_HDKGUSPracSezonowy = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik GUS Pracownik Sezonowy]
    ,ISNULL(NULLIF(UMW_NumerPelny, ''''), ''(BRAK)'') [Umowa Numer],
    WPE_SklEmerPrac + WPE_SklRentPrac + WPE_SklChorPrac + WPE_SklWypadPrac [Suma składek ZUS],
    Case when (WPE_SklEmerPracOpodat + WPE_SklRentPracOpodat + WPE_SklChorPracOpodat) = 0 then WPE_SklEmerPrac + WPE_SklRentPrac + WPE_SklChorPrac + WPE_SklWypadPrac
    ELSE (WPE_SklEmerPrac + WPE_SklRentPrac + WPE_SklChorPrac + WPE_SklWypadPrac)-((WPE_SklEmerPrac + WPE_SklRentPrac + WPE_SklChorPrac + WPE_SklWypadPrac)-(WPE_SklEmerPracOpodat + WPE_SklRentPracOpodat + WPE_SklChorPracOpodat)) END AS [Składki ZUS podlegające odliczeniu od podstawy opodatkowania]
    ,WPS_Nazwa as [Składnik Wypłaty Nazwa]
    ,WPS_Wartosc as [Składnik Wypłaty Wartość]
    ,Datediff(hh,''1899-12-30 00:00:00.000'',WPS_OkresCzas) [Składnik Wypłaty Godziny]
    ,WPL_ProcentPodat1 AS [Procent Podatku]
    ,zal.Ope_Kod [Operator Wprowadzający] 
    ,mod.Ope_Kod [Operator Modyfikujący]
    ,Case when TWP_Wskaznik = 1 then ''TAK'' ELSE ''NIE'' end as [Typ Wypłaty Wskaźnik]
	,GotowkaProcent [Procent Wypłaty Gotówka]
    ,RorProcent [Procent Wypłaty ROR]
    /*
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), LPL_DataDok, 111), ''/'', ''-'') [Data]
    ,REPLACE(CONVERT(VARCHAR(10), PRE_DataUr, 111), ''/'', ''-'') [Data Urodzenia]
    ,REPLACE(CONVERT(VARCHAR(10), WPL_DataOd, 111), ''/'', ''-'') [Data Od Wypłaty]
    ,REPLACE(CONVERT(VARCHAR(10), WPL_Datado, 111), ''/'', ''-'') [Data Do Wypłaty]
    ,CONVERT(VARCHAR(4), WPL_Rok) + ''-'' + RIGHT(''0'' + CONVERT(VARCHAR(2), WPL_Miesiac), 2) + ''-01'' [Data Deklaracji]
    ,CASE WHEN PrBad < PRE_ZatrudnionyOd THEN NULL ELSE REPLACE(CONVERT(VARCHAR(10), PrBad, 111), ''/'', ''-'') END [Data Ważności Badań]
    ,CASE WHEN PRE_ZatrudnionyOd = convert(datetime,''18991230'',112) THEN NULL ELSE REPLACE(CONVERT(VARCHAR(10), PRE_ZatrudnionyOd, 111), ''/'', ''-'') END [Data Zatrudnienia]
    ,CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN NULL WHEN PRE_ZatrudnionyDo = convert(datetime,''18991230'',112) THEN NULL ELSE REPLACE(CONVERT(VARCHAR(10), PRE_ZatrudnionyDo, 111), ''/'', ''-'') END [Data Zwolnienia]
    ,REPLACE(CONVERT(VARCHAR(10), UMW_DataOd, 111), ''/'', ''-'') [Data Rozpoczęcia Umowy]
    ,CASE WHEN UMW_DataDo = convert(datetime,''29991231'',112) THEN NULL ELSE REPLACE(CONVERT(VARCHAR(10), UMW_DataDo, 111), ''/'', ''-'') END [Data Zakończenia Umowy]
    ,REPLACE(CONVERT(VARCHAR(10), PRE_PPKOkresOd, 111), ''/'', ''-'') [Data Przystąpienia do PPK]
    ,REPLACE(CONVERT(VARCHAR(10), PRE_PPKOkresDo, 111), ''/'', ''-'') [Data Rezygnacji z PPK]
    */
    
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), LPL_DataDok, 111), ''/'', ''-'') [Data Wypłaty Dzień]
    ,MONTH(LPL_DataDok) [Data Wypłaty Miesiąc]
    ,(datepart(DY, datediff(d, 0, LPL_DataDok) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, LPL_DataDok)*/ [Data Wypłaty Tydzień Roku]
    ,DATEPART(quarter, LPL_DataDok) AS [Data Wypłaty Kwartał], YEAR(LPL_DataDok) [Data Wypłaty Rok]

        ,REPLACE(CONVERT(VARCHAR(10), WPL_DataOd, 111), ''/'', ''-'') [Data Od Wypłaty Dzień]
    ,MONTH(WPL_DataOd) [Data Od Wypłaty Miesiąc]
    ,(datepart(DY, datediff(d, 0, WPL_DataOd) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, WPL_DataOd)*/ [Data Od Wypłaty Tydzień Roku]
    ,DATEPART(quarter, WPL_DataOd) AS [Data Od Wypłaty Kwartał], YEAR(WPL_DataOd) [Data Od Wypłaty Rok]

        ,REPLACE(CONVERT(VARCHAR(10), WPL_Datado, 111), ''/'', ''-'') [Data Do Wypłaty Dzień]
    ,MONTH(WPL_Datado) [Data Do Wypłaty Miesiąc]
    ,(datepart(DY, datediff(d, 0, WPL_Datado) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, WPL_Datado)*/ [Data Do Wypłaty Tydzień Roku]
    ,DATEPART(quarter, WPL_Datado) AS [Data Do Wypłaty Kwartał], YEAR(WPL_Datado) [Data Do Wypłaty Rok]

    ,WPL_Rok [Data Rok Deklaracji]
    ,WPL_Miesiac [Data Miesiąc Deklaracji]
    ,CASE WHEN PrBad < PRE_ZatrudnionyOd THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PrBad) AS VARCHAR(10)),''(BRAK)'') END [Data Ważności Badań Miesiąc]
    ,CASE WHEN PrBad < PRE_ZatrudnionyOd THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PrBad) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PrBad)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Ważności Badań Tydzień Roku]
    ,CASE WHEN PrBad < PRE_ZatrudnionyOd THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PrBad) AS VARCHAR(10)),''(BRAK)'') END [Data Ważności Badań Kwartał]
    ,CASE WHEN PrBad < PRE_ZatrudnionyOd THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PrBad) AS VARCHAR(10)),''(BRAK)'') END [Data Ważności Badań Rok]
    ,CASE WHEN PRE_ZatrudnionyOd = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PRE_ZatrudnionyOd, 111), ''/'', ''-''),''(BRAK)'') END [Data Zatrudnienia Dzień]
    ,CASE WHEN PRE_ZatrudnionyOd = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PRE_ZatrudnionyOd) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Miesiąc]
    ,CASE WHEN PRE_ZatrudnionyOd = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PRE_ZatrudnionyOd) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PRE_ZatrudnionyOd)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Tydzień Roku] 
    ,CASE WHEN PRE_ZatrudnionyOd = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PRE_ZatrudnionyOd) AS VARCHAR(10)),''(BRAK)'') END AS [Data Zatrudnienia Kwartał]
    ,CASE WHEN PRE_ZatrudnionyOd = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PRE_ZatrudnionyOd) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Rok] 
    ,CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PRE_ZatrudnionyDo = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PRE_ZatrudnionyDo, 111), ''/'', ''-''),''(BRAK)'') END [Data Zwolnienia Dzień]
    ,CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PRE_ZatrudnionyDo = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PRE_ZatrudnionyDo) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Miesiąc]
    ,CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PRE_ZatrudnionyDo = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PRE_ZatrudnionyDo) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PRE_ZatrudnionyDo)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Tydzień Roku]
    ,CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PRE_ZatrudnionyDo = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PRE_ZatrudnionyDo) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Kwartał]
    ,CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PRE_ZatrudnionyDo = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PRE_ZatrudnionyDo) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Rok]
    ,GETDATE() [Data Analizy]
    ----------KONTEKSTY
    ,24020 [Dokument Numer __PROCID__], WPL_WplId [Dokument Numer __ORGID__], '''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]
    ,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__] 
    
    ' + @kolumny + @atrybuty + @atrybutyDataOd + @atrybutyDataDo + '

 FROM CDN.WypElementy
    JOIN CDN.Wyplaty ON WPE_WplId = WPL_WplId
    JOIN #Wyplaty WPLE On WPE_WplId = wyplataID
    JOIN CDN.ListyPlac ON WPL_LplId = LPL_LplId 
    JOIN (SELECT * FROM (SELECT PRE.*, WPL_WplId Wpl, ROW_NUMBER() OVER(PARTITION BY WPL_WplID ORDER BY PRE_PreId DESC) as row
        FROM CDN.Wyplaty WPL
        JOIN CDN.PracEtaty PRE ON WPL_PraId = PRE_PraId 
            AND CAST(Pre_DataOd AS Date) <= CAST(WPL_DataDo AS Date) 
            AND CAST(Pre_DataDo AS Date) >= CAST(WPL_DataOd AS Date)) s WHERE row = 1) PRE ON WPL_WplId = Wpl AND CAST(Pre_DataOd AS Date) <= CAST(WPL_DataDo AS Date) AND CAST(Pre_DataDo AS Date) >= CAST(WPL_DataOd AS Date)
    JOIN CDN.Pracidx pr1 ON PRE_PraId = pr1.PRI_PraId AND pr1.PRI_Typ < 10
    JOIN CDN.Dzialy ON WPL_DzlId = DZL_DzlId 
    JOIN CDN.Lokalizacje ON DZL_LokId = Lok_LokId
    JOIN CDN.TypWyplata ON WPE_TwpId = TWP_TwpId
    LEFT JOIN CDN.WypSkladniki ON WPE_WpeId = WPS_WpeId and PRE_PraId = WPS_PraId and TWP_TwpId = WPS_TwpId
    LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko = sta.DKM_DkmId AND sta.DKM_Rodzaj = 1
    LEFT JOIN CDN.DaneKadMod zwo ON PRE_ETADkmIdWypowPowod = zwo.DKM_DkmId AND zwo.DKM_Rodzaj = 3
    LEFT JOIN CDN.Kategorie kat1 ON WPE_KatId = kat1.Kat_KatID
    LEFT JOIN CDN.Kategorie kat2 ON WPL_KatId = kat2.Kat_KatID
    LEFT JOIN CDN.PracZestaw zestaw ON zestaw.PZE_praid = wpl_praid AND wpl_dataod = zestaw.PZE_okresod AND wpl_datado = zestaw.PZE_okresdo AND wpe_twpid = 1 
    LEFT JOIN ( select 
    SUM((DATEDIFF(hour, ''18991230'', PZE_czasWolne))) czasWolne
    ,SUM((DATEDIFF(hour, ''18991230'', PZE_Nadgodziny50))) Nadgodziny50
    ,SUM((DATEDIFF(hour, ''18991230'', PZE_Nadgodziny100))) Nadgodziny100
    ,SUM((DATEDIFF(hour, ''18991230'', PZE_NadgodzinySW))) NadgodzinySW
    ,SUM((DATEDIFF(hour, ''18991230'', PZE_CzasSW))) CzasSW
     ,PZE_praid pzepraid
     ,MONTH(PZE_okresod) okresodM,YEAR(PZE_okresod) okresodY
     ,MONTH(PZE_okresdo) okresDoM,YEAR(PZE_okresdo) okresDoY
     from cdn.PracZestaw 
    GROUP BY PZE_praid  ,MONTH(PZE_okresod),YEAR(PZE_okresod)
     ,MONTH(PZE_okresdo),YEAR(PZE_okresdo)
    )ZestGrp ON PZE_PzeID IS NULL AND  wpl_praid = pzepraid AND MONTH(wpl_dataod) = okresodM AND MONTH(wpl_datado) = okresDoM 
    AND YEAR(wpl_dataod) = okresodY AND YEAR(wpl_datado) = okresDoY
    AND wpe_twpid = 1 
    LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
    LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
    LEFT JOIN CDN.Zaklady ZakListPlac ON ZAkListPlac.ZAK_ZAkID = LPL_ZakId
    LEFT JOIN CDN.Zaklady ZakPracownik ON ZakPracownik.ZAK_ZAkID = PRE_ZakId
    LEFT JOIN CDN.WypElementyPodstawa ON WEP_WpeId = WPE_WpeId AND WPE_TwpID = 70
    LEFT JOIN CDN.TyTUbezp u1 ON u1.TyU_TyUId = PRE_UBZTyuId
    LEFT JOIN CDN.Centra ON CNT_CntId = PRE_CntId
    LEFT JOIN #tmpetat ON PrId = Pre_PraId
    LEFT JOIN cdn.DaneKadMod rob ON PRE_ETADkmIdStanowisko = rob.DKM_DkmId
    LEFT JOIN cdn.DokDefinicje lpl ON LPL_DdfId = lpl.DDf_DDfID
    LEFT JOIN #tmpUmowy umowy ON WPL_WplId = umowy.UMW_WplId    
    LEFT JOIN #tmpLimityRoczne ON PLN_praid = WPL_PraId AND Wykorzystane <> 0 and WPL_Rok = PLN_Rok and pln_lnbid=1
    LEFT JOIN #tmpLimity on (TNB_tyuid <> 99999 OR PLN_LnbId=TNB_LnbId) AND  TWP_TwpId = TNB_TwpId 
    LEFT JOIN CDN.TyTUbezp u2 ON TNB_TyuId = u2.TYU_TyuId 
    LEFT JOIN '+@bazaKonf+'.CDN.KZIS ON KZIS_Symbol = PRE_KodZawoduSymbol
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON WPL_OpeZalId = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON WPL_OpeModId = mod.Ope_OpeId
	LEFT JOIN '+@bazaKonf+'.cdn.CfgKlucze ON LPL_DataDok Between CFK_OkresOd AND CFK_OkresDo  AND CFK_Nazwa = ''Najniższe wynagrodzenie''  
	LEFT JOIN  '+@bazaKonf+'.cdn.cfgwartosci on CFW_CfkId=CFK_CfkId
	LEFT JOIN #ProcentRor ON wpl_wplid = bzd_dokumentid

WHERE
    WPL_Tryb <> 1 
    AND WPL_Tryb <> 2 
'
PRINT(@select)
EXEC(@select)   

DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpetat
DROP TABLE #tmpUmowy
DROP TABLE #Wyplaty
DROP TABLE #tmpLimityRoczne
DROP TABLE #tmpLimity
DROP TABLE #ProcentRor





















