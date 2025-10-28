/*
* Raport Kadr i Płac 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.1.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @bazaFirmowa varchar(max);
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)

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
DECLARE @atrybut_id int, @atrybut_kod nvarchar(100), @atrybuty varchar(max), @sqlA nvarchar(max), @atrybut_Typ int, @atrybut_format nvarchar(21);

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

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sqlA = N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpKonAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = 
         CASE WHEN ' + convert(varchar,@atrybut_Typ) + ' = 3  THEN REPLACE(ATR.ATH_Wartosc,'','',''.'') ELSE ATR.ATH_Wartosc END          
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
          END       
        FROM CDN.OAtrybutyHist ATR 
        JOIN CDN.OAtrybuty OA ON OA.OAT_OatId = ATR.ATH_OatId AND ATR.ATH_DataDo = (SELECT MAX(A1.ATH_DataDo) FROM CDN.OAtrybutyHist A1 WHERE A1.ATH_OatId = ATR.ATH_OatId)
        JOIN #tmpKonAtr TM ON OA.OAT_PrcId = TM.OAT_PrcId
        WHERE ATR.ATH_AtkId = ' + CAST(@atrybut_id AS nvarchar)

    EXEC(@sqlA)    
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Pracownik Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod,@atrybut_Typ,@atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Wyliczanie wypłat
SELECT 
    WPL_WplId [wyplataID],
    SUM(CASE WHEN TWP_WchodziDoWyplaty = 1 OR TWP_Rodzajzrodla = 35 THEN
            CASE WHEN WPE_Wartosc < 0
                THEN 0 
                ELSE WPE_Wartosc
            END
            ELSE 0
        END) [brutto],
    SUM(CASE WHEN WPE_Nazwa = 'Dni pobytu za granicą (liczba diet)' THEN WPE_Wartosc*WPL_OddelegowanyDieta*WPL_KursLNalDieta/WPL_KursMNalDieta ELSE 0 END) [dieta],
    SUM(CASE WHEN WPE_Nazwa = 'Podstawa ZUS opodatk. zagr.' or WPE_Nazwa = 'Wyrównanie podstawy ZUS opodatk. zagr.' THEN WPE_Wartosc ELSE 0 END ) [podstawaOpodatkowania]
INTO #Wyplaty
FROM CDN.PracEtaty 
    JOIN CDN.Wyplaty ON WPL_PraId = PRE_PraId AND CAST(Pre_DataOd AS Date) <= CAST(GetDate() AS Date) AND CAST(Pre_DataDo AS Date) >= CAST(GetDate() AS Date)
    JOIN CDN.WypElementy ON WPE_WplId = WPL_WplId
    JOIN CDN.TypWyplata ON WPE_TwpId = TWP_TwpId
group by WPL_WplId

--Właściwe zapytanie
SET @select =
'SELECT 
    DB_NAME() [Baza Firmowa], 
    REPLACE(CONVERT(VARCHAR(10), WPL_DataOd, 111), ''/'', ''-'') [Data Od Wypłaty], REPLACE(CONVERT(VARCHAR(10), WPL_Datado, 111), ''/'', ''-'') [Data Do Wypłaty],
    WPL_Rok [Data Rok Deklaracji], WPL_Miesiac [Data Miesiąc Deklaracji], 
    WPL_NumerPelny [Dokument Numer],
    REPLACE(CONVERT(VARCHAR(10), PRE_ZatrudnionyOd, 111), ''/'', ''-'') [Data Zatrudnienia], 
    CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' ELSE REPLACE(CONVERT(VARCHAR(10), PRE_ZatrudnionyDo, 111), ''/'', ''-'') END [Data Zwolnienia],
    CASE WHEN PRE_ZatrudnionyDo = convert(datetime,''29991231'',112) THEN DATEDIFF(d,PRE_ZatrudnionyOd, GETDATE())+1 ELSE DATEDIFF(d,PRE_ZatrudnionyOd, PRE_ZatrudnionyDo)+1 END [Okres Zatrudnienia],
    PRE_Kod [Pracownik Kod],
    PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
    CASE WHEN PRE_ETARodzajUmowy = '''' THEN ''(NIEPRZYPISANE)'' ELSE PRE_ETARodzajUmowy END [Rodzaj Umowy], 
    CASE WHEN PRI_Archiwalny = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Archiwalny],
    CASE WHEN pr1.PRI_Typ = 1 THEN ''Pracownik'' ELSE ''Własciciel/Współpracownik'' END [Pracownik Typ],
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
    PRE_StNiepelnosp [Kod Stopnia Niepełnosprawności],
    PRE_PrawoER [Kod Prawa Do Emerytury/Renty],
    TYU_TyUb4 [Kod Tytułu Ubezpieczenia],
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
    LPL_NumerPelny [Lista Płac], DZL_Kod [Wydział z Wypłaty], Lok_Kod [Lokalizacja], DZL_AdresWezla [Wydział Adres Węzła], TWP_Nazwa [Element Wypłaty Typ], WPE_Nazwa [Element Wypłaty Nazwa],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') AS [Kategoria Szegółowa z Elementu], ISNULL(kat2.Kat_KodSzczegol, ''(PUSTA)'') AS [Kategoria Szegółowa z Nagłówka], 
    ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') AS [Kategoria Ogólna z Elementu], ISNULL(kat2.Kat_KodOgolny, ''(PUSTA)'') AS [Kategoria Ogólna z Nagłówka], 
    CASE WHEN TWP_WchodziDoWyplaty = 0 AND TWP_OpisAnalitCzasPracy = 0
        THEN ''NIE'' 
        ELSE ''TAK'' 
    END [Element Wypłaty Wpływ na Kwotę],
    CASE WHEN TWP_RodzajFIS = 1
        THEN ''NIE'' 
        ELSE ''TAK'' 
    END [Element Wypłaty Opodatkowany],
    ISNULL(OPP_Procent/100,1)*     CASE WHEN TWP_WchodziDoWyplaty = 1 THEN
        WPE_Wartosc - WPE_SklEmerPrac-WPE_SklRentPrac-WPE_SklChorPrac-WPE_SklWypadPrac-WPE_ZalFis-WPE_SklZdrowPrac-WPE_SklZdrowSuma-WPE_SklPPKPrac1-WPE_SklPPKPrac2 
    ELSE - WPE_SklEmerPrac-WPE_SklRentPrac-WPE_SklChorPrac-WPE_SklWypadPrac-WPE_ZalFis-WPE_SklZdrowPrac-WPE_SklZdrowSuma-WPE_SklPPKPrac1-WPE_SklPPKPrac2
    END 
    [Wypłata Wartość Netto],
    ISNULL(OPP_Procent/100,1)* CASE WHEN TWP_WchodziDoWyplaty = 1 OR TWP_Rodzajzrodla = 35 THEN
        CASE WHEN WPE_Wartosc < 0
            THEN 0 
            ELSE WPE_Wartosc
        END
    ELSE 0 END [Suma Elementów Wypłaty],
    ISNULL(OPP_Procent/100,1)* CASE WHEN TWP_RodzajZrodla <> 1 or TWP_WchodziDoWyplaty = 0 THEN 0 ELSE WPE_Wartosc END [Wypłata Wynagrodzenie Zasadnicze],
    ISNULL(OPP_Procent/100,1)*(WPE_SklEmerPrac + WPE_SklRentPrac + WPE_SklChorPrac + WPE_SklWypadPrac) [Składka ZUS U], 
    ISNULL(OPP_Procent/100,1)*(WPE_SklEmerFirma + WPE_SklRentFirma + WPE_SklChorFirma + WPE_SklWypadFirma + WPE_SklFP + WPE_SklFGSP) [Składka ZUS P],
    ISNULL(OPP_Procent/100,1)*CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklEmerFirma + WPE_SklRentFirma + WPE_SklChorFirma + WPE_SklWypadFirma + WPE_SklFP + WPE_SklFGSP END [Składka ZUS P bez Mac. i Wych.],
    ISNULL(OPP_Procent/100,1)*WPE_Koszty [Koszty Uzyskania], 
    ISNULL(OPP_Procent/100,1)*(WPE_ZalFis + WPE_SklZdrowPrac + WPE_SklZdrowSuma) [Zal. Podatku z Ubezp. Zdrow.],
    ISNULL(OPP_Procent/100,1)*WPE_Ulga [Ulga Podatkowa], 
    ISNULL(OPP_Procent/100,1)*WPE_ZalFis [Zaliczka Podatku do US], 
    ISNULL(OPP_Procent/100,1)*WPE_NalFis [Naliczona Zaliczka Podatku], 
    ISNULL(OPP_Procent/100,1)*WPE_PodstEmer [Podstawa Składki Emerytalnej], 
    ISNULL(OPP_Procent/100,1)*WPE_SklEmerPrac [Składka Emerytalna U],
    ISNULL(OPP_Procent/100,1)*WPE_SklEmerFirma [Składka Emerytalna P],
    ISNULL(OPP_Procent/100,1)*WPE_PodstRent [Podstawa Składki Rentowej],
    ISNULL(OPP_Procent/100,1)*WPE_SklRentPrac [Składka Rentowa U],
    ISNULL(OPP_Procent/100,1)*WPE_SklRentFirma [Składka Rentowa P],
    ISNULL(OPP_Procent/100,1)*WPE_PodstChor [Podstawa Składki Chorobowej], 
    ISNULL(OPP_Procent/100,1)*WPE_SklChorPrac [Składka Chorobowa U], 
    ISNULL(OPP_Procent/100,1)*WPE_SklChorFirma [Składka Chorobowa P], 
    ISNULL(OPP_Procent/100,1)*WPE_PodstWypad [Podstawa Składki Wypadkowej],
    ISNULL(OPP_Procent/100,1)*WPE_SklWypadPrac [Składka Wypadkowa U],
    ISNULL(OPP_Procent/100,1)*WPE_SklWypadFirma [Składka Wypadkowa P], 
    ISNULL(OPP_Procent/100,1)*WPE_PodstFP [Podstawa Składki na FP], 
    ISNULL(OPP_Procent/100,1)*WPE_SklFP [Składka na FP], 
    ISNULL(OPP_Procent/100,1)*WPE_PodstFGSP [Podstawa Składki na FGŚP], 
    ISNULL(OPP_Procent/100,1)*WPE_SklFGSP [Składka na FGŚP], 
    ISNULL(OPP_Procent/100,1)*WPE_PodstFEP [Podstawa Składki na FEP],
    ISNULL(OPP_Procent/100,1)*WPE_SklFEP [Składka na FEP],
    ISNULL(OPP_Procent/100,1)*WPE_PodstZdrow [Podstawa Składki Zdrowotnej], 
    ISNULL(OPP_Procent/100,1)*WPE_SklZdrowPrac [Składka Zdrowotna (odl.)],
    ISNULL(OPP_Procent/100,1)*WPE_SklZdrowSuma [Składka Zdrowotna (od netto)], 
    ISNULL(OPP_Procent/100,1)*WPE_SklZdrowPrac + WPE_SklZdrowSuma [Składka Zdrowotna (pob.) U], 
    ISNULL(OPP_Procent/100,1)*WPE_SklZdrowFirma [Składka Zdrowotna (pob.) P],
    ISNULL(OPP_Procent/100,1)*CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklEmerPrac END [Składka Emerytalna U bez Mac. i Wych.], 
    ISNULL(OPP_Procent/100,1)*CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklEmerFirma END [Składka Emerytalna P bez Mac. i Wych.],
    ISNULL(OPP_Procent/100,1)*CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklRentPrac END [Składka Rentowa U bez Mac. i Wych.],
    ISNULL(OPP_Procent/100,1)*CASE WHEN TWP_Nazwa LIKE ''Zasiłek wych%'' OR TWP_Nazwa LIKE ''Zasiłek mac%'' OR TWP_Nazwa LIKE ''Podwyższenie zasiłku mac%'' THEN NULL ELSE WPE_SklRentFirma END [Składka Rentowa P bez Mac. i Wych.],
    ISNULL(OPP_Procent/100,1)*WEP_KWOTa2 [Stawka Wyliczona ze Składników Zmiennych], -- dla elementu wypłaty "Wynagrodzenie za czas urlopu"
    ISNULL(OPP_Procent/100,1)*   CASE WHEN SUBSTRING(CAST(WPE_TyUb as nvarchar), 1,4) = ''1211'' OR SUBSTRING(CAST(WPE_TyUb as nvarchar), 1,4) = ''1240''  THEN 0 
	when 	TWP_PdzId IN (332,334,336,311,312,313,314,212,214,215,216,315,316,317,318,319,320,321,322,323,324,325,326,327,328,329) THEN 0
	ELSE  IIF(TWP_KosztFirma = 1, WPE_Wartosc, 0)  + WPE_SklEmerFirma + WPE_SklRentFirma +  WPE_SklWypadFirma + WPE_SklFP + WPE_SklFGSP + WPE_SklFEP  END  [Całkowity Koszt Zatrudnienia Pracownika],
      ISNULL(OPP_Procent/100,1)*case when PZE_czasWolne is not null then  (DATEDIFF(hour, ''18991230'', PZE_czasWolne)) else null end  as [Zestawienia Czas Wolny godziny],
      ISNULL(OPP_Procent/100,1)*case when PZE_Nadgodziny50 is not null then  (DATEDIFF(hour, ''18991230'', PZE_Nadgodziny50)) else null end  as [Zestawienia Nadgodziny 50 godziny],
      ISNULL(OPP_Procent/100,1)*case when PZE_Nadgodziny100 is not null then  (DATEDIFF(hour, ''18991230'', PZE_Nadgodziny100)) else null end  as [Zestawienia Nadgodziny 100 godziny],
      ISNULL(OPP_Procent/100,1)*case when PZE_NadgodzinySW is not null then  (DATEDIFF(hour, ''18991230'', PZE_NadgodzinySW)) else null end  as [Zestawienia Nadgodziny Święta godziny],
      ISNULL(OPP_Procent/100,1)*case when PZE_CzasSW is not null then  (DATEDIFF(hour, ''18991230'', PZE_CzasSW)) else null end  as [Zestawienia Czas Święta godziny]
      ,ISNULL(OPP_Procent/100,1)*WPE_PodstPPK [Podstawa Składki PPK]
      ,ISNULL(OPP_Procent/100,1)*WPE_SklPPKPrac1 [Składka PPK Podstawowa U]
      ,ISNULL(OPP_Procent/100,1)*WPE_SklPPKPrac2 [Składka PPK Dodatkowa U]
      ,ISNULL(OPP_Procent/100,1)*WPE_SklPPKFirma1 [Składka PPK Podstawowa P]
      ,ISNULL(OPP_Procent/100,1)*WPE_SklPPKFirma2 [Składka PPK Dodatkowa P]
      ,CASE WHEN (LPL_DekID is null and LPL_KPRID is null and LPL_PreDekID is null) THEN ''NIE'' ELSE ''TAK'' END [Lista Płace Zaksięgowana]
      ,case when opp_prjid is not null then PRJ_Kod else ''<BRAK>'' end [Opis Analityczny Projekt Kod]
      ,case when opp_prjid is not null then PRJ_Nazwa else ''<BRAK>'' end [Opis Analityczny Projekt Nazwa]
      ,case when opp_dzlid is not null then dzialy.Kod else ''<BRAK>'' end [Opis Analityczny Wydział Kod]
      ,case when opp_dzlid is not null then dzialy.Nazwa else ''<BRAK>'' end [Opis Analityczny Wydział Nazwa]
/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), LPL_DataDok, 111), ''/'', ''-'') [Data Wypłaty]
*/

----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), LPL_DataDok, 111), ''/'', ''-'') [Data Wypłaty Dzień], MONTH(LPL_DataDok) [Data Wypłaty Miesiąc]
,(datepart(DY, datediff(d, 0, LPL_DataDok) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, LPL_DataDok)*/ [Data Wypłaty Tydzień Roku]
,DATEPART(quarter, LPL_DataDok) AS [Data Wypłaty Kwartał], YEAR(LPL_DataDok) [Data Wypłaty Rok]
,GETDATE() [Data Analizy]
      ----------KONTEKSTY
    ,24020 [Dokument Numer __PROCID__], WPL_WplId [Dokument Numer __ORGID__], '''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]
    ,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]

    ' + @kolumny + @atrybuty + '
 FROM CDN.WypElementy
 left join cdn.OpisPlace on OPP_WPEID = WPE_WPEID
    JOIN CDN.Wyplaty ON WPE_WplId = WPL_WplId
    JOIN #Wyplaty WPTM On WPE_WplId = wyplataID
    JOIN CDN.ListyPlac ON WPL_LplId = LPL_LplId 
    JOIN CDN.PracEtaty ON WPL_PraId = PRE_PraId AND CAST(Pre_DataOd AS Date) <= CAST(GetDate() AS Date) AND CAST(Pre_DataDo AS Date) >= CAST(GetDate() AS Date)
    JOIN CDN.Pracidx pr1 ON PRE_PraId = pr1.PRI_PraId AND pr1.PRI_Typ < 10
    JOIN CDN.Dzialy dz ON WPL_DzlId = dz.DZL_DzlId 
    JOIN CDN.Lokalizacje ON DZL_LokId = Lok_LokId
    JOIN CDN.TypWyplata ON WPE_TwpId = TWP_TwpId
    LEFT JOIN CDN.WypSkladniki ON WPE_WpeId = WPS_WpeId and PRE_PraId = WPS_PraId and TWP_TwpId = WPS_TwpId
    LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko = sta.DKM_DkmId AND sta.DKM_Rodzaj = 1
    LEFT JOIN CDN.DaneKadMod zwo ON PRE_ETADkmIdWypowPowod = zwo.DKM_DkmId AND zwo.DKM_Rodzaj = 3
    LEFT OUTER JOIN CDN.Kategorie kat1 ON WPE_KatId = kat1.Kat_KatID
    LEFT OUTER JOIN CDN.Kategorie kat2 ON WPL_KatId = kat2.Kat_KatID
    left join cdn.PracZestaw zestaw on pze_praid = wpl_praid and wpl_dataod = pze_okresod and wpl_datado = pze_okresdo and wpe_twpid = 1
    LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
    LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
    LEFT OUTER JOIN CDN.Zaklady ZakListPlac on ZAkListPlac.ZAK_ZAkID = LPL_ZakId
    LEFT OUTER JOIN CDN.Zaklady ZakPracownik on ZakPracownik.ZAK_ZAkID = PRE_ZakId
    LEFT OUTER JOIN [CDN].[WypElementyPodstawa] ON WEP_WpeId = WPE_WpeId AND WPE_TwpID = 70
    LEFT JOIN CDN.TyTUbezp ON TyU_TyUId = PRE_UBZTyuId
    LEFT JOIN CDN.Centra ON CNT_CntId = PRE_CntId
    left join cdn.DefProjekty on opp_prjid = prj_prjid
    left join (select distinct dzl_dzlid as id, dzl_kod as kod,dzl_nazwa as nazwa from cdn.Dzialy) dzialy on opp_dzlid = dzialy.id
WHERE
    WPL_Tryb<>1 AND WPL_Tryb<>2 AND TWP_Wskaznik <> 1     '

PRINT(@Select)
EXEC(@select)   

DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #Wyplaty











