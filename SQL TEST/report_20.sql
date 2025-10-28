
/** Raport Czasu Pracy
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.1.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


--Współczynnik urlopowy
DECLARE @Wspol VARCHAR(10)
SET @Wspol = CONVERT(VARCHAR(10), cast(@Wsp as decimal (10,2)))

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
	set @kolumny = @kolumny + ', CASE WHEN Poz.Poziom' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' + LTRIM(@i) + ' END [Wydział Pracownika Poziom ' + LTRIM(@i) + '] '
	set @i = @i + 1
end

--Wyliczanie Atrybutów Pracowników
DECLARE @atrybut_id int, @atrybut_kod nvarchar(100), @atrybuty varchar(max), @sqlA nvarchar(max), @atrybut_Typ int, @atrybut_format nvarchar(21);

DECLARE atrybut_cursor CURSOR FOR
SELECT DISTINCT OAT_AtkId, REPLACE(ATK_Nazwa, ']', '_'), ATK_Typ, ATK_Format
FROM CDN.OAtrybuty
JOIN CDN.OAtrybutyKlasy ON OAT_AtkId = ATK_AtkId
WHERE OAT_PrcId IS NOT NULL


OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_Typ,@atrybut_format;

SELECT DISTINCT OAT_PrcId INTO #tmpKonAtr FROM CDN.OAtrybuty

SET @atrybuty = ''

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @sqlA = N'ALTER TABLE #tmpKonAtr ADD [atr + ' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
	SET @sqlA = N'UPDATE #tmpKonAtr
		SET [atr + ' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = 
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
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[atr + ' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Pracownik Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
	FETCH NEXT FROM atrybut_cursor
	INTO @atrybut_id, @atrybut_kod, @atrybut_Typ,@atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Liczenie dni pracy pracownika
SELECT DISTINCT [Data], [PreId], [PraId] INTO #Daty
FROM(
	SELECT KAD_Data [Data], PRE_PreId [PreId], PRE_PraId [PraId]
	FROM CDN.KalendDni
	LEFT JOIN CDN.PracEtaty ON PRE_KalId = KAD_KalId AND KAD_Data >= PRE_DataOd AND KAD_Data <= PRE_DataDo
	WHERE KAD_Data BETWEEN @DATAOD AND @DATADO

	UNION ALL

	SELECT  PPL_Data [Data], PRE_PreId [PreId], PRE_PraId [PraId]
	FROM CDN.PracPlanDni
	LEFT JOIN CDN.PracEtaty ON PRE_PraId = PPL_PraId AND PPL_Data >= PRE_DataOd AND PPL_Data <= PRE_DataDo
	WHERE PPL_Data BETWEEN @DATAOD AND @DATADO

	UNION ALL

	SELECT  PPR_Data [Data], PRE_PreId [PreId], PRE_PraId [PraId]
	FROM CDN.PracPracaDni
	LEFT JOIN CDN.PracEtaty ON PRE_PraId = PPR_PraId AND PPR_Data >= PRE_DataOd AND PPR_Data <= PRE_DataDo
	WHERE PPR_Data BETWEEN @DATAOD AND @DATADO
)AS Daty

--Sprawdzenie ważności umów
select data [UData], praid [UPraId], count(umw_umwid) [UUmw] into #Umowy from #daty
left join cdn.umowy on umw_praid = praid and data >= UMW_DataOd and data <= umw_datado
group by data, PraId

--Daty zwolnienia i zatrudnienia
SELECT MAX(pre_zatrudnionydo) PZZwol, min(pre_zatrudnionyod) PZZat,pre_praid [PZPraId] into #PracZat from cdn.pracetaty where @DATAOD <= PRE_DataDo AND @DATADO >= PRE_DataOd group by pre_praid

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
	SUM(CASE WHEN WPE_Nazwa = 'Dni pobytu za granicą (liczba diet)' THEN WPE_Wartosc*WPL_OddelegowanyDieta*ISNULL(NULLIF(WPL_KursLNalDieta,0),1)/ISNULL(NULLIF(WPL_KursMNalDieta,0),1) ELSE 0 END) [dieta],
	SUM(CASE WHEN WPE_Nazwa = 'Podstawa ZUS opodatk. zagr.' or WPE_Nazwa = 'Wyrównanie podstawy ZUS opodatk. zagr.' THEN WPE_Wartosc ELSE 0 END ) [podstawaOpodatkowania]
INTO #Wyplaty
FROM CDN.PracEtaty 
	JOIN CDN.Wyplaty ON WPL_PraId = PRE_PraId AND CAST(Pre_DataOd AS Date) <= CAST(GetDate() AS Date) AND CAST(Pre_DataDo AS Date) >= CAST(GetDate() AS Date)
 	JOIN CDN.WypElementy ON WPE_WplId = WPL_WplId
	JOIN CDN.TypWyplata ON WPE_TwpId = TWP_TwpId
group by WPL_WplId


SELECT  TOP (DATEDIFF(DAY, @DATAOD, @DATADO) + 1)
        Date = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY a.object_id) - 1, @DATAOD)
		into #WszystkieDaty
FROM    sys.all_objects a
        CROSS JOIN sys.all_objects b
		;

WITH cte AS
(
   SELECT *,
         ROW_NUMBER() OVER (PARTITION BY PLN_PRAID,PLN_Lnbid ORDER BY PLN_Waznyod DESC) AS rn
   FROM Cdn.PracLimit WHERE PLN_WaznyOd < @DATADO AND PLN_Rok = YEAR(@DATADO)  
)
SELECT * INTO #AktualneLimity
FROM cte 
WHERE rn = 1




DECLARE @DataPocz DATETIME
SET @DataPocz =   DATEADD(yy, DATEDIFF(yy, 0, @DATADO), 0) 

SELECT  TOP (DATEDIFF(DAY, @DataPocz, @DATADO) + 1)
        Date = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY a.object_id) - 1, @DataPocz)
		into #WszystkieDatyDo
FROM    sys.all_objects a
        CROSS JOIN sys.all_objects b
		;

select DISTINCT Dzien into #Swieta from #WszystkieDatyDo  CROSS apply  cdn.DniSwiateczne(YEAR(Date))


		SELECT  (MONTH(@Datado) - MONTH(PLN_OkresOd) + 1.0) /12.0 IlMies, PLN_PlnId PLNID INTO #tmpmies FROM CDN.PRAClIMIT x
WHERE  (X.PLN_OkresOd BETWEEN  @DATAOD AND   @DATADO ) OR (X.PLN_OkresDo BETWEEN  @DATAOD AND  @DATADO)
	OR 
	(( @DATAOD  BETWEEN X.PLN_OkresOd AND X.PLN_OkresDo) OR ( @DATADO BETWEEN X.PLN_OkresOd AND X.PLN_OkresDo))

;WITH RankedData AS (
    SELECT 
        PLN_Praid, 
        Pln_lnbid, 
	PLN_PlnId,
        PLN_WaznyOd, 
        PLN_OkresOd, 
        PLN_OkresDo,
	LAG(PLN_OkresDo) OVER (PARTITION BY PLN_Praid, Pln_lnbid ORDER BY PLN_OkresDo) AS PrevValidTo,
        LEAD(PLN_WaznyOd) OVER (PARTITION BY PLN_Praid, Pln_lnbid ORDER BY PLN_WaznyOd) AS NextValidFrom
    FROM CDN.PracLimit
)
SELECT 
    PLN_Praid RzPra, 
    Pln_lnbid RzLNB, 
	PLN_PlnId RzPLN,
    PLN_WaznyOd AS ValidFrom, 
	NextValidFrom,
	PrevValidTo,
	ABS(datediff(day,lag(COALESCE(DATEADD(DAY, -1, NextValidFrom), PLN_OkresDo)) OVER (PARTITION BY PLN_Praid, Pln_lnbid ORDER BY COALESCE(DATEADD(DAY, -1, NextValidFrom), PLN_OkresDo)),PLN_WaznyOd)) as Roznica,
    COALESCE(DATEADD(DAY, -1, NextValidFrom), PLN_OkresDo) AS ValidTo  INTO #RzeczywisteObowiazywanieLimitow
FROM RankedData WHeRE YEAR(PLN_WaznyOd) = YEAR(@DATAOD) 


		SELECT COUNT(*) DniLim ,SUM(DATEPART(hour,pnb_Godz)) GodzLim,PNB_PraId Lim_praId,PLN_plnid Lim_PLNId,PLN_LNBId LIM_LNBId ,Roznica INTO #WykorzystaneDoDnia FROM #WszystkieDatyDo JOIN  CDN.PracNieobec on Date BETWEEN PNB_OkresOd and PNB_OkresDo
		JOIN cdn.TypNieobec ON TNB_TnbId = PNB_TnbId
		JOIN  CDN.PracLimit ON PLN_WaznyOd < @DATADO  AND PLN_Rok = YEAR(  @DATADO )  and PLN_PraId = PNB_PraId AND PLN_LnbId = TNB_LnbId
		LEFT JOIN CDN.PracEtaty ON PLN_PraId = PRE_PraId AND Date BETWEEN PRE_DataOd AND PRE_DataDo 
		LEFT JOIN CDN.PracPlanDni ON PPL_PraId = PNB_PraId AND PPL_Data = Date
		LEFT JOIN CDN.KalendDni ON Date = KAD_Data AND PRE_KalId = KAD_KalId
		LEFT JOIN #RzeczywisteObowiazywanieLimitow ON PLN_PlnId = RzPLN
		WHERE ( ISNULL(PPL_TypDnia,KAD_TypDnia) = 1 OR (ISNULL(PPL_TypDnia,KAD_TypDnia) is null and (DATEPART(dw,Date) NOT IN (1,7) ) AND DATE NOT IN (select dzien from #Swieta)))
		 and Date <=  ValidTo AND ValidFrom <> @DATAOD 
		and NOT((Date  BETWEEN @DATAOD AND @DATADO) and (Date  BETWEEN ValidFrom and ValidTo)) AND Roznica = 1 and PrevValidTo <> PRE_ZatrudnionyDo
		GROUP BY PNB_PraId, PLN_plnid,PLN_LNBId,Roznica

SELECT * INTO #IloscPrzedzialowPracy FROM (
SELECT COUNT(*) IloscKal ,Count(Case when DST_UwzglCzasPracy = 1 then 1 else null end) IloscStrefa,KDG_KadId PPrID,1 PPrTyp FROM CDN.KalendDniGodz  JOIN CDN.DefinicjeStref SPR ON SPR.DST_DstId = KDG_Strefa JOIN CDN.KalendDni ON KDG_KadId = KAD_KadId WHERE KAD_Data  BETWEEN @DATAOD AND @DATADO GROUP BY KDG_KadId
UNION ALL 
SELECT COUNT(*),Count(Case when DST_UwzglCzasPracy = 1 then 1 else null end)ilosc2,PGL_PplId,2 FROM CDN.PracPlanDniGodz JOIN CDN.DefinicjeStref  SPR ON SPR.DST_DstId =PGL_Strefa JOIN CDN.PracPlanDni on PGL_PplId = PPL_PplId WHERE PPL_Data BETWEEN @DATAOD AND @DATADO GROUP BY PGL_PplId
UNION ALL 
SELECT COUNT(*),Count(Case when DST_UwzglCzasPracy = 1 then 1 else null end)ilosc2,PGR_PprId,3 FROM CDN.PracPracaDniGodz JOIN CDN.DefinicjeStref SPR ON SPR.DST_DstId=PGR_Strefa JOIN CDN.PracPracaDni on PGR_PprId = PPR_PprId WHERE PPR_Data BETWEEN @DATAOD AND @DATADO GROUP BY PGR_PprId
)PPr


--Właściwe zapytanie
SET @select =
'
DECLARE @Wspolczynnik DECIMAL(10,2)
SET @Wspolczynnik = ' +@wspol+';
SELECT BAZ.Baz_Nazwa [Baza Firmowa], KAL_Akronim [Kalendarz], 
 case Isnull(PRA_Archiwalny,0)
 when 0 then ''NIE''
 else ''TAK''
 end [Pracownik Archiwalny],
PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
PRE_Kod [Pracownik Kod],
ISNULL(sta.DKM_Nazwa,''(NIEPRZYPISANE)'') [Pracownik Stanowisko],
	isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
	isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],
CONVERT(VARCHAR(5), COALESCE(PGL_OdGodziny,KDG_OdGodziny),108) [Data Godzina Od], CONVERT(VARCHAR(5), COALESCE(PGL_DoGodziny,KDG_DoGodziny),108)  [Data Godzina Do],
GETDATE() [Data Analizy],
SPL.DST_Akronim [Strefa],
CASE WHEN SPL.DST_Nazwa = '''' THEN ''(NIEPRZEPISANA)'' ELSE SPL.DST_Nazwa END [Strefa Nazwa],
DPL.DZL_Kod [Wydział], PPL.PRJ_Kod [Projekt],
--CASE WHEN PPL_TypDnia = 1 OR (PPL_PplId IS NULL AND KAD_TypDnia = 1) THEN ''TAK'' ELSE ''NIE'' END [Obecność],
CASE COALESCE(PPL_TypDnia,KAD_TypDnia)
	WHEN 1 THEN ''Pracy''
	WHEN 2 THEN ''Wolny''
	WHEN 3 THEN ''Święto''
END [Typ Dnia],

CASE WHEN SPL.DST_UwzglCzasPracy = 0 THEN NULL WHEN (KDG_OdGodziny=KDG_DoGodziny AND DATEPART(hour,KDG_OdGodziny)<>0) OR (PGL_OdGodziny=PGL_DoGodziny AND DATEPART(hour,PGL_OdGodziny) <>0) THEN
	24.0 ELSE
NULLIF((CASE WHEN PGL_OdGodziny IS NULL
	THEN case when KAL_UwzglWymiarEtatu = 1 THEN(Cast(PRE_ETAEtatL as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1)) else 1.0 end * 1.0*DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))/60
	ELSE 1.0*DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))/60
END),0) END [Wymiar Pracy w Godzinach],

CASE WHEN SPL.DST_UwzglCzasPracy = 0 THEN NULL WHEN(KDG_OdGodziny=KDG_DoGodziny AND DATEPART(hour,KDG_OdGodziny)<>0) OR (PGL_OdGodziny=PGL_DoGodziny AND DATEPART(hour,PGL_OdGodziny) <>0) THEN
	24.0*60 ELSE
NULLIF((CASE WHEN PGL_OdGodziny IS NULL
	THEN case when KAL_UwzglWymiarEtatu = 1 THEN(Cast(PRE_ETAEtatL as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1)) else 1.0 end * DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))
	ELSE DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))
END),0) END [Wymiar Pracy w Minutach],

CASE WHEN  SPL.DST_UwzglCzasPracy = 0 THEN NULL WHEN (KDG_OdGodziny=KDG_DoGodziny AND DATEPART(hour,KDG_OdGodziny)<>0) OR (PGL_OdGodziny=PGL_DoGodziny AND DATEPART(hour,PGL_OdGodziny) <>0) THEN
	''24:00'' ELSE
NULLIF((CASE WHEN PGL_OdGodziny IS NULL
	THEN CONVERT(VARCHAR, cast((case when KAL_UwzglWymiarEtatu = 1 THEN(Cast(PRE_ETAEtatL as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1)) else 1.0 end) * DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))/60 as int)) + '':'' + (CASE WHEN DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))%60 < 10 THEN ''0'' ELSE '''' END) + CONVERT(VARCHAR,DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))%60)
	ELSE CONVERT(VARCHAR,DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))/60) + '':'' + (CASE WHEN DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))%60 < 10 THEN ''0'' ELSE '''' END) + CONVERT(VARCHAR,DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))%60)
END),''0:00'') END [Wymiar Pracy],

CASE WHEN SPL.DST_UwzglCzasPracy = 0 THEN NULL WHEN (DATEDIFF(minute, PGL_OdGodziny, PGL_DoGodziny) <> 0) OR ((PGL_OdGodziny IS NULL) AND DATEDIFF(minute, KDG_OdGodziny, KDG_DoGodziny) <> 0)
	THEN 1.0/(CASE WHEN PGL_OdGodziny IS NULL
					THEN case when Pre_etaetatM IS NULL OR Pre_etaetatM = 0  THEN (SELECT COUNT(KDG_KdgId) FROM CDN.KalendDniGodz WHERE KDG_KadId = KAD_KadId) else (case when KAL_UwzglWymiarEtatu = 1 THEN(Cast(ISNULL(NULLIF(PRE_ETAEtatL,0),1) as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1)) else 1.0 end) END
					ELSE (SELECT COUNT(PGL_PglId) FROM CDN.PracPlanDniGodz WHERE PPL_PplId = PGL_PplId)
				  END)
	WHEN (KDG_OdGodziny=KDG_DoGodziny AND DATEPART(hour,KDG_OdGodziny)<>0) OR (PGL_OdGodziny=PGL_DoGodziny AND DATEPART(hour,PGL_OdGodziny) <>0) THEN 1.0
	ELSE NULL
END [Wymiar Pracy w Dniach],

NULL [Czas Pracy w Godzinach],  NULL [Czas Pracy w Minutach], ''Wymiar Pracy'' [Czas Pracy], NULL [Czas Pracy w Dniach],
ISNULL(TNB_Nazwa, ''Nie dotyczy'') [Nieobecność Typ], CASE WHEN TNB_Typ = 2 THEN ''NIE'' ELSE ''TAK'' END [Nieobecność Usprawiedliwiona],
CASE PNB_Przyczyna
	WHEN 1 THEN ''Nie dotyczy''
	WHEN 2 THEN ''Zwolnienie lekarskie''
	WHEN 3 THEN ''Wypadek w pracy/choroba zawodowa''
	WHEN 4 THEN ''Wypadek w drodze do/z pracy''
	WHEN 5 THEN ''Zwolnienie w okresie ciąży''
	WHEN 6 THEN ''Zwolnienie spowodowane gruźlicą''
	WHEN 7 THEN ''Nadużycie alkoholu''
	WHEN 8 THEN ''Przestępstwa/wykroczenie''
	WHEN 9 THEN ''Opieka nad dzieckiem do lat 14''
	WHEN 10 THEN ''Opieka nad inną osobą''
	WHEN 11 THEN ''Leczenie szpitalne''
	WHEN 12 THEN ''Badanie dawcy/pobranie organów'' 
	WHEN 13 THEN ''Urlop macierzyński 100%''
	WHEN 14 THEN ''Urlop macierzyński 80%''
	WHEN 15 THEN ''Urlop rodzicielski 80%''
	WHEN 16 THEN ''Urlop rodzicielski 60%''
	WHEN 17 THEN ''Urlop rodzicielski 100%''
	WHEN 19 THEN ''Niezdolność do pracy/kwarantanna służb medycznych''
	WHEN 20 THEN ''Niepoprawne wykorzystanie zwolnienia''
	WHEN 21 THEN ''Urlop macierzyński 81,5%''
	WHEN 22 THEN ''Urlop rodzicielski 81,5%''
	WHEN 23 THEN ''Urlop rodzicielski 70%''
	WHEN 24 THEN ''Urlop rodzicielski 70% (do 9 tygodni)''
	WHEN 25 THEN ''Urlop rodzicielski 70% (ustawa "Za życiem")''
	WHEN 22 THEN ''Urlop rodzicielski 81.5%''
	WHEN 26 THEN ''Urlop rodzicielski 81.5% (ustawa "Za życiem")''
	ELSE ''Nie dotyczy''
END [Nieobecność Przyczyna], 
CASE PNB_Tryb 
	WHEN 0 THEN ''Podstawowa''
	WHEN 1 THEN ''Anulowana''
	WHEN 2 THEN ''Korygująca''
	ELSE ''Nie dotyczy''
END [Nieobecność Status], 
CASE PNB_UrlopNaZadanie 
	WHEN 0 THEN ''NIE'' 
	WHEN 1 THEN ''TAK''
	ELSE ''Nie dotyczy''
END [Nieobecność Na Żądanie],
NULL [Nieobecności w Godzinach], NULL [Nieobecności w Dniach Kalendarzowych], NULL [Nieobecności w Dniach Pracy],
''Nie dotyczy'' [Limit Nieobecności Typ], 
''Nie dotyczy'' [Limit Nieobecności Od], ''Nie dotyczy'' [Limit Nieobecności Do],
''Nie dotyczy'' [Nieobecność Od], ''Nie dotyczy'' [Nieobecność Do],
NULL [Limit Nieobecności Należny Dni],
NULL [Limit Nieobecności Należny Godziny],
NULL [Limit Nieobecności Wykorzystany Dni],
NULL [Limit Nieobecności Wykorzystany Godziny],
NULL [Limit Nieobecności Pozostały Dni],
NULL [Limit Nieobecności Pozostały Godziny],
NULL [Limit Nieobecności Zaległy Dni],
NULL [Limit Nieobecności Zaległy Godziny],
NULL [Wypłata Wartość Netto], NULL [Suma Elementów Wypłaty], NULL [Wypłata Wynagrodzenie Zasadnicze],
NULL [Urlop Planowany Dni],
NULL [Urlop Wypoczynkowy Należny Dni],
NULL [Urlop Wypoczynkowy Pozostało Dni],
NULL [Przybliżona Rezerwa Urlopowa],
NULL  [Obowiązujący Limit Nieobecności Należny Dni ],
NULL[Obowiązujący Limit Nieobecności Należny Godziny ],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Dni ],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Godziny ], 
NULL  [Obowiązujący Limit Nieobecności Pozostały Dni ],
NULL [Obowiązujący Limit Nieobecności Pozostały Godziny ],
NULL  [Obowiązujący Limit Nieobecności Zaległy Dni ],
NULL [Obowiązujący Limit Nieobecności Zaległy Godziny ],
NULL [Obowiązujący Urlop Planowany Dni ],
NULL [Obowiązujący Urlop Wypoczynkowy Należny Dni ],
NULL[Obowiązujący Urlop Wypoczynkowy Pozostało Dni ],
NULL [Obowiązujący Limit Przybliżona Rezerwa Urlopowa ],
NULL [Limit Nieobecności Należny Cały Okres Dni],
NULL [Limit Nieobecności Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Pozostały Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Należny Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Pozostały Cały Okres Dni],
PRE_Kod [Liczba Pracowników]
,DZPR.DZL_Kod AS [Pracownik Wydział]
,CASE rob.DKM_Robotnicze WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Stanowisko Robotnicze]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZat, 111), ''/'', ''-''),''(BRAK)'') END [Data Zatrudnienia Dzień]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Miesiąc]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZat) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZat)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Tydzień Roku] 
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZat) AS VARCHAR(10)),''(BRAK)'') END AS [Data Zatrudnienia Kwartał]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Rok] 
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZwol, 111), ''/'', ''-''),''(BRAK)'') END [Data Zwolnienia Dzień]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Miesiąc]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZwol) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZwol)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Tydzień Roku]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Kwartał]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Rok]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE CASE WHEN PZZwol > GetDate() THEN CASE WHEN datediff(yy,PZZat,GetDate()) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,GetDate()) AS VARCHAR(10)),''(BRAK)'') END ELSE CASE WHEN datediff(yy,PZZat,PZZwol) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,PZZwol) AS VARCHAR(10)),''(BRAK)'') END END END [Pracownik Lata Pracy]
	  ,ISNULL(CAST (datediff(yy,PRE_DataUr,Data) AS VARCHAR(10)),''(BRAK)'') [Pracownik Wiek]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]

/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), Data, 111), ''/'', ''-'') [Data]
*/

----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), Data, 111), ''/'', ''-'') [Data Dzień], MONTH(Data) [Data Miesiąc], YEAR(Data) [Data Rok]
,CASE when MONTH(Data) <7 THEN ''I'' else ''II'' END AS [Data Półrocze]
,DATEPART(quarter, Data) AS [Data Kwartał] 

----------KONTEKSTY
,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]
,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]



' + @kolumny + @atrybuty + '
FROM #Daty
	LEFT JOIN CDN.PracEtaty ON PRE_PreId = PreId
	LEFT JOIN #PracZat on PZPraId = PRE_PraID
	LEFT JOIN #Umowy ON UPraId = PraId AND UData = Data
	LEFT JOIN CDN.KalendDni ON Data = KAD_Data AND PRE_KalId = KAD_KalId AND ((Data <= PZZwol AND Data >= PZZat) OR UUmw > 0)
	LEFT JOIN CDN.Kalendarze ON KAD_KalId = KAL_KalId
	LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko =  sta.DKM_DkmId AND  sta.DKM_Rodzaj = 1
	LEFT JOIN CDN.PracPlanDni ON PPL_PraId = PRE_PraId AND PPL_Data = Data
	LEFT JOIN CDN.KalendDniGodz ON KDG_KadId = KAD_KadId AND PPL_PplId IS NULL
	LEFT JOIN CDN.PracPlanDniGodz ON PPL_PplId = PGL_PplId
	LEFT JOIN CDN.DefinicjeStref SPL ON COALESCE(PGL_Strefa,KDG_Strefa) = SPL.DST_DstId
	LEFT JOIN CDN.Dzialy DPL ON COALESCE(PGL_DzlId,KDG_DzlId) = DPL.DZL_DzlId 
	LEFT JOIN CDN.DefProjekty PPL ON COALESCE(PGL_PrjId,KDG_PrjId) = PPL.PRJ_PrjId
	LEFT JOIN CDN.PracNieobec ON PNB_PraId = PRE_PraId AND Data >= PNB_OkresOd AND Data <= PNB_OkresDo AND PNB_Tryb <> 1
	LEFT JOIN CDN.TypNieobec ON PNB_TnbId = TNB_TnbId
	LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
	LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
	LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = PRE_ZakId
	LEFT JOIN CDN.PracKod on PRA_PraId = PRE_PraId
	LEFT JOIN cdn.DaneKadMod rob on PRE_ETADkmIdStanowisko = rob.DKM_DkmId
	LEFT JOIN cdn.Dzialy DZPR ON PRE_DzlId = DZPR.DZL_DzlId 
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
	LEFT JOIN ' + @Operatorzy + ' zal ON PRE_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON PRE_OpeModID = mod.Ope_OpeId
    WHERE ((PZZat <= convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)
	AND PZZwol >= convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120)) OR UUmw > 0)
	AND Data >= PZZat AND Data <= PZZwol
UNION ALL

SELECT BAZ.Baz_Nazwa [Baza Firmowa], KAL_Akronim [Kalendarz], 
case Isnull(PRA_Archiwalny,0)
 when 0 then ''NIE''
 else ''TAK''
 end [Pracownik Archiwalny],
PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
PRE_Kod [Pracownik Kod], 
ISNULL(sta.DKM_Nazwa,''(NIEPRZYPISANE)'') [Pracownik Stanowisko],
	isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
	isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],
CONVERT(VARCHAR(5), COALESCE(PGR_OdGodziny,PGL_OdGodziny,KDG_OdGodziny),108) [Data Godzina Od], CONVERT(VARCHAR(5), COALESCE(PGR_DoGodziny,PGL_DoGodziny,KDG_DoGodziny),108) [Data Godzina Do],
GETDATE() [Data Analizy],
CASE WHEN Data > GETDATE() THEN NULL ELSE SPR.DST_Akronim END [Strefa], 
CASE WHEN Data > GETDATE() THEN NULL ELSE CASE WHEN SPR.DST_Nazwa = '''' THEN ''(NIEPRZEPISANA)'' ELSE SPR.DST_Nazwa END END [Strefa Nazwa], 
CASE WHEN Data > GETDATE() THEN NULL ELSE DPR.DZL_Kod END [Wydział], 
CASE WHEN Data > GETDATE() THEN NULL ELSE PPR.PRJ_Kod END [Projekt],
--CASE WHEN (PPL_TypDnia = 1 OR (PPL_PplId IS NULL AND KAD_TypDnia = 1)) AND (ISNULL(PNB_Calodzienna,0) = 0) THEN ''TAK'' ELSE ''NIE'' END [Obecność],
CASE COALESCE(PPL_TypDnia,KAD_TypDnia)
	WHEN 1 THEN ''Pracy''
	WHEN 2 THEN ''Wolny''
	WHEN 3 THEN ''Święto''
END [Typ Dnia],
NULL [Wymiar Pracy w Godzinach], NULL [Wymiar Pracy w Minutach],
''Czas Pracy'' [Wymiar Pracy],
 NULL [Wymiar Pracy w Dniach],
CASE WHEN Data > GETDATE() OR (PNB_Calodzienna = 1) OR SPR.DST_UwzglCzasPracy = 0  THEN NULL
ELSE NULLIF(CASE WHEN PGR_OdGodziny IS NULL
	THEN CASE WHEN PGL_OdGodziny IS NULL
			THEN
				CASE WHEN KDG_OdGodziny <> KDG_DoGodziny THEN
				case when KAL_UwzglWymiarEtatu = 1 THEN(Cast(PRE_ETAEtatL as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1)) else 1.0 end * 1.0*DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))/60
				WHEN DATEPART(hour,KDG_OdGodziny)<>0 THEN 24.0 END
			ELSE 
				CASE WHEN PGL_OdGodziny <> PGL_DoGodziny THEN
				1.0*DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))/60
				WHEN DATEPART(hour,PGL_OdGodziny)<>0 THEN 24.0 END
		END
	ELSE
		CASE WHEN PGR_OdGodziny <> PGR_DoGodziny THEN
		 1.0*DATEDIFF(minute,PGR_OdGodziny,(CASE WHEN PGR_OdGodziny > PGR_DoGodziny THEN DATEADD(day,1,PGR_DoGodziny) ELSE PGR_DoGodziny END))/60
		WHEN DATEPART(hour,PGR_OdGodziny)<>0 THEN 24.0 END
	END,0) 
END - CASE WHEN PGR_OdGodziny IS NULL THEN ISNULL(datediff(MI,CONVERT(DATETIME,''1899-12-30 00:00:00.000'',120),PNB_Godz),0)/60.0  else 0 end [Czas Pracy w Godzinach], 
CASE WHEN Data > GETDATE() OR (PNB_Calodzienna = 1) OR SPR.DST_UwzglCzasPracy = 0  THEN NULL
ELSE NULLIF(CASE WHEN PGR_OdGodziny IS NULL
	THEN CASE WHEN PGL_OdGodziny IS NULL
			THEN
				CASE WHEN KDG_OdGodziny <> KDG_DoGodziny THEN
				case when KAL_UwzglWymiarEtatu = 1 THEN(Cast(PRE_ETAEtatL as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1)) else 1.0 end * DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))
				WHEN DATEPART(hour,KDG_OdGodziny) <> 0 THEN 24.0*60 END
			ELSE 
				CASE WHEN PGL_OdGodziny <> PGL_DoGodziny THEN
				DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))
				WHEN DATEPART(hour,PGL_OdGodziny)<>0 THEN 24.0*60 END
		END
	ELSE 
		CASE WHEN PGR_OdGodziny <> PGR_DoGodziny THEN
		DATEDIFF(minute,PGR_OdGodziny,(CASE WHEN PGR_OdGodziny > PGR_DoGodziny THEN DATEADD(day,1,PGR_DoGodziny) ELSE PGR_DoGodziny END)) 
		WHEN DATEPART(hour,PGR_OdGodziny)<>0 THEN 24.0*60 END
	END,0) 
END - CASE WHEN PGR_OdGodziny IS NULL THEN ISNULL(datediff(MI,CONVERT(DATETIME,''1899-12-30 00:00:00.000'',120),PNB_Godz),0) ELSE 0 END [Czas Pracy w Minutach],
CASE WHEN Data > GETDATE() OR (PNB_Calodzienna = 1) OR SPR.DST_UwzglCzasPracy = 0  THEN NULL
	ELSE 
	CASE WHEN (PGR_OdGodziny=PGR_DoGodziny AND DATEPART(hour,PGR_OdGodziny)<>0) OR (PGL_OdGodziny=PGL_DoGodziny AND DATEPART(hour,PGL_OdGodziny)<>0) OR (KDG_OdGodziny=KDG_DoGodziny AND DATEPART(hour,KDG_OdGodziny)<>0) THEN
	''24:00'' ELSE
	NULLIF((CASE 
					WHEN PGR_OdGodziny IS NOT NULL THEN CONVERT(VARCHAR,DATEDIFF(minute,PGR_OdGodziny,(CASE WHEN PGR_OdGodziny > PGR_DoGodziny THEN DATEADD(day,1,PGR_DoGodziny) ELSE PGR_DoGodziny END))/60) + '':'' + (CASE WHEN DATEDIFF(minute,PGR_OdGodziny,(CASE WHEN PGR_OdGodziny > PGR_DoGodziny THEN DATEADD(day,1,PGR_DoGodziny) ELSE PGR_DoGodziny END))%60 < 10 THEN ''0'' ELSE '''' END) + CONVERT(VARCHAR,DATEDIFF(minute,PGR_OdGodziny,(CASE WHEN PGR_OdGodziny > PGR_DoGodziny THEN DATEADD(day,1,PGR_DoGodziny) ELSE PGR_DoGodziny END))%60)
					WHEN PGL_OdGodziny IS NOT NULL THEN CONVERT(VARCHAR,DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))/60-(ISNULL(datediff(MI,CONVERT(DATETIME,''1899-12-30 00:00:00.000'',120),PNB_Godz),0))/60) + '':'' + (CASE WHEN DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))%60 < 10 THEN ''0'' ELSE '''' END) + CONVERT(VARCHAR,DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END)-(ISNULL(datediff(MI,CONVERT(DATETIME,''1899-12-30 00:00:00.000'',120),PNB_Godz),0)))%60)
					ELSE  CONVERT(VARCHAR,CAST((case when KAL_UwzglWymiarEtatu = 1 THEN(Cast(PRE_ETAEtatL as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1)) else 1.0 end) * DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))/60 -(ISNULL(datediff(MI,CONVERT(DATETIME,''1899-12-30 00:00:00.000'',120),PNB_Godz),0))/60 AS INT))  + '':'' + (CASE WHEN DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))%60 < 10 THEN ''0'' ELSE '''' END) + CONVERT(VARCHAR,DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END)-(ISNULL(datediff(MI,CONVERT(DATETIME,''1899-12-30 00:00:00.000'',120),PNB_Godz),0)))%60) 
				END),''0:00'') 
				END
END [Czas Pracy],
CASE 
	WHEN Data > GETDATE() OR (PNB_Calodzienna = 1)  OR SPR.DST_UwzglCzasPracy = 0  THEN NULL
	WHEN (DATEDIFF(minute, PGR_OdGodziny, PGR_DoGodziny) <> 0) OR ((PGR_OdGodziny IS NULL) AND (DATEDIFF(minute, PGL_OdGodziny, PGL_DoGodziny) <> 0)) OR ((PGR_OdGodziny IS NULL) AND (PGL_OdGodziny IS NULL) AND (DATEDIFF(minute, KDG_OdGodziny, KDG_DoGodziny) <> 0)) THEN 1.0/
		(CASE 
			WHEN PGR_OdGodziny IS NOT NULL THEN (SELECT COUNT(PGR_PgrId) FROM CDN.PracPracaDniGodz WHERE PPR_PprId = PGR_PprId)
			WHEN PGL_OdGodziny IS NOT NULL THEN (SELECT COUNT(PGL_PglId) FROM CDN.PracPlanDniGodz WHERE PPL_PplId = PGL_PplId)
			ELSE  case when Pre_etaetatM IS NULL OR Pre_etaetatM = 0  THEN (SELECT COUNT(KDG_KdgId) FROM CDN.KalendDniGodz WHERE KDG_KadId = KAD_KadId) else (case when KAL_UwzglWymiarEtatu = 1 THEN(Cast(ISNULL(NULLIF(PRE_ETAEtatL,0),1) as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1)) else 1.0 end) END
		END)
	WHEN (PGR_OdGodziny=PGR_DoGodziny AND DATEPART(hour,PGR_OdGodziny)<>0) OR (PGL_OdGodziny=PGL_DoGodziny AND DATEPART(hour,PGL_OdGodziny)<>0) OR (KDG_OdGodziny=KDG_DoGodziny AND DATEPART(hour,KDG_OdGodziny)<>0) THEN 1.0
	ELSE NULL
END - CASE WHEN PGR_OdGodziny IS NULL THEN (ISNULL(datediff(MI,CONVERT(DATETIME,''1899-12-30 00:00:00.000'',120),PNB_Godz),0)/60.0)/8.0 ELSE 0 END [Czas Pracy w Dniach],
ISNULL(TNB_Nazwa, ''Nie dotyczy'') [Nieobecność Typ], CASE WHEN TNB_Typ = 2 THEN ''NIE'' ELSE ''TAK'' END [Nieobecność Usprawiedliwiona],
CASE PNB_Przyczyna
	WHEN 1 THEN ''Nie dotyczy''
	WHEN 2 THEN ''Zwolnienie lekarskie''
	WHEN 3 THEN ''Wypadek w pracy/choroba zawodowa''
	WHEN 4 THEN ''Wypadek w drodze do/z pracy''
	WHEN 5 THEN ''Zwolnienie w okresie ciąży''
	WHEN 6 THEN ''Zwolnienie spowodowane gruźlicą''
	WHEN 7 THEN ''Nadużycie alkoholu''
	WHEN 8 THEN ''Przestępstwa/wykroczenie''
	WHEN 9 THEN ''Opieka nad dzieckiem do lat 14''
	WHEN 10 THEN ''Opieka nad inną osobą''
	WHEN 11 THEN ''Leczenie szpitalne''
	WHEN 12 THEN ''Badanie dawcy/pobranie organów'' 
	WHEN 13 THEN ''Urlop macierzyński 100%''
	WHEN 14 THEN ''Urlop macierzyński 80%''
	WHEN 15 THEN ''Urlop rodzicielski 80%''
	WHEN 16 THEN ''Urlop rodzicielski 60%''
	WHEN 17 THEN ''Urlop rodzicielski 100%''
	WHEN 19 THEN ''Niezdolność do pracy/kwarantanna służb medycznych''
	WHEN 20 THEN ''Niepoprawne wykorzystanie zwolnienia''
	WHEN 21 THEN ''Urlop macierzyński 81,5%''
	WHEN 22 THEN ''Urlop rodzicielski 81,5%''
	WHEN 23 THEN ''Urlop rodzicielski 70%''
	WHEN 24 THEN ''Urlop rodzicielski 70% (do 9 tygodni)''
	WHEN 25 THEN ''Urlop rodzicielski 70% (ustawa "Za życiem")''
	WHEN 22 THEN ''Urlop rodzicielski 81.5%''
	WHEN 26 THEN ''Urlop rodzicielski 81.5% (ustawa "Za życiem")''
	ELSE ''Nie dotyczy''
END [Nieobecność Przyczyna],
CASE PNB_Tryb 
	WHEN 0 THEN ''Podstawowa''
	WHEN 1 THEN ''Anulowana''
	WHEN 2 THEN ''Korygująca''
	ELSE ''Nie dotyczy''
END [Nieobecność Status],
CASE PNB_UrlopNaZadanie 
	WHEN 0 THEN ''NIE'' 
	WHEN 1 THEN ''TAK''
	ELSE ''Nie dotyczy''
END [Nieobecność Na Żądanie],
NULL [Nieobecności w Godzinach],
NULL [Nieobecności w Dniach Kalendarzowych],
NULL [Nieobecności w Dniach Pracy],
''Nie dotyczy'' [Limit Nieobecności Typ], 
''Nie dotyczy'' [Limit Nieobecności Od], ''Nie dotyczy'' [Limit Nieobecności Do],
''Nie dotyczy'' [Nieobecność Od], ''Nie dotyczy'' [Nieobecność Do],
NULL [Limit Nieobecności Należny Dni],
NULL [Limit Nieobecności Należny Godziny],
NULL [Limit Nieobecności Wykorzystany Dni],
NULL [Limit Nieobecności Wykorzystany Godziny],
NULL [Limit Nieobecności Pozostały Dni],
NULL [Limit Nieobecności Pozostały Godziny],
NULL [Limit Nieobecności Zaległy Dni],
NULL [Limit Nieobecności Zaległy Godziny],
NULL [Wypłata Wartość Netto], NULL [Suma Elementów Wypłaty], NULL [Wypłata Wynagrodzenie Zasadnicze],
NULL [Urlop Planowany Dni],
NULL [Urlop Wypoczynkowy Należny Dni],
NULL [Urlop Wypoczynkowy Pozostało Dni],
NULL [Przybliżona Rezerwa Urlopowa],
NULL  [Obowiązujący Limit Nieobecności Należny Dni ],
NULL[Obowiązujący Limit Nieobecności Należny Godziny ],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Dni ],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Godziny ], 
NULL  [Obowiązujący Limit Nieobecności Pozostały Dni ],
NULL [Obowiązujący Limit Nieobecności Pozostały Godziny ],
NULL  [Obowiązujący Limit Nieobecności Zaległy Dni ],
NULL [Obowiązujący Limit Nieobecności Zaległy Godziny ],
NULL [Obowiązujący Urlop Planowany Dni ],
NULL [Obowiązujący Urlop Wypoczynkowy Należny Dni ],
NULL[Obowiązujący Urlop Wypoczynkowy Pozostało Dni ],
NULL [Obowiązujący Przybliżona Rezerwa Urlopowa ],
NULL [Limit Nieobecności Należny Cały Okres Dni],
NULL [Limit Nieobecności Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Pozostały Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Należny Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Pozostały Cały Okres Dni],
PRE_Kod [Liczba Pracowników]
,DZPR.DZL_Kod AS [Pracownik Wydział]
,CASE rob.DKM_Robotnicze WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Stanowisko Robotnicze]
	 ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZat, 111), ''/'', ''-''),''(BRAK)'') END [Data Zatrudnienia Dzień]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Miesiąc]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZat) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZat)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Tydzień Roku] 
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZat) AS VARCHAR(10)),''(BRAK)'') END AS [Data Zatrudnienia Kwartał]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Rok] 
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZwol, 111), ''/'', ''-''),''(BRAK)'') END [Data Zwolnienia Dzień]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Miesiąc]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZwol) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZwol)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Tydzień Roku]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Kwartał]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Rok]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE CASE WHEN PZZwol > GetDate() THEN CASE WHEN datediff(yy,PZZat,GetDate()) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,GetDate()) AS VARCHAR(10)),''(BRAK)'') END ELSE CASE WHEN datediff(yy,PZZat,PZZwol) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,PZZwol) AS VARCHAR(10)),''(BRAK)'') END END END [Pracownik Lata Pracy]
	  ,ISNULL(CAST (datediff(yy,PRE_DataUr,Data) AS VARCHAR(10)),''(BRAK)'') [Pracownik Wiek]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]

/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), Data, 111), ''/'', ''-'') [Data]
*/
----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), Data, 111), ''/'', ''-'') [Data Dzień], MONTH(Data) [Data Miesiąc], YEAR(Data) [Data Rok]
,CASE when MONTH(Data) <7 THEN ''I'' else ''II'' END AS [Data Półrocze]
,DATEPART(quarter, Data) AS [Data Kwartał] 

----------KONTEKSTY
,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]
,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]


' + @kolumny + @atrybuty + '
FROM #Daty
	LEFT JOIN CDN.PracEtaty ON PRE_PreId = PreId
	LEFT JOIN #PracZat on PZPraId = PRE_PraID
	LEFT JOIN #Umowy ON UPraId = PraId AND UData = Data
	LEFT JOIN CDN.KalendDni ON Data = KAD_Data AND PRE_KalId = KAD_KalId AND ((Data <= PZZwol AND Data >= PZZat) OR UUmw > 0)
	LEFT JOIN CDN.Kalendarze ON KAD_KalId = KAL_KalId 
	LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko =  sta.DKM_DkmId AND  sta.DKM_Rodzaj = 1
	LEFT JOIN CDN.PracPlanDni ON PPL_PraId = PRE_PraId AND PPL_Data = Data
	LEFT JOIN CDN.PracPracaDni ON PPR_PraId = PRE_PraId AND PPR_Data = Data
	LEFT JOIN CDN.KalendDniGodz ON KDG_KadId = KAD_KadId AND PPL_PplId IS NULL AND PPR_PprId IS NULL
	LEFT JOIN CDN.PracPlanDniGodz ON PPL_PplId = PGL_PplId AND PPR_PprId IS NULL
	LEFT JOIN CDN.PracPracaDniGodz ON PPR_PprId = PGR_PprId
	LEFT JOIN CDN.DefinicjeStref SPR ON COALESCE(PGR_Strefa,PGL_Strefa,KDG_Strefa) = SPR.DST_DstId
	LEFT JOIN CDN.Dzialy DPR ON COALESCE(PGR_DzlId,PGL_DzlId,KDG_DzlId) = DPR.DZL_DzlId 
	LEFT JOIN CDN.DefProjekty PPR ON COALESCE(PGR_PrjId,PGL_PrjId,KDG_PrjId) = PPR.PRJ_PrjId
	LEFT JOIN CDN.PracNieobec ON PNB_PraId = PRE_PraId AND Data >= PNB_OkresOd AND Data <= PNB_OkresDo AND PNB_Tryb <> 1
	LEFT JOIN CDN.TypNieobec ON PNB_TnbId = TNB_TnbId
	LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
	LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
	LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = PRE_ZakId
	LEFT JOIN CDN.PracKod on PRA_PraId = PRE_PraId
	LEFT JOIN cdn.DaneKadMod rob on PRE_ETADkmIdStanowisko = rob.DKM_DkmId
	LEFT JOIN cdn.Dzialy DZPR ON PRE_DzlId = DZPR.DZL_DzlId 
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
	LEFT JOIN ' + @Operatorzy + ' zal ON PRE_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON PRE_OpeModID = mod.Ope_OpeId
	LEFT JOIN #IloscPrzedzialowPracy  ON (PPRID = KAD_KadId AND PPL_PplId IS NULL AND PPR_PprId IS NULL AND PPRTYP = 1)or( PPL_PplId = PPRID AND PPR_PprId IS NULL and PPRTYP = 2 ) OR ( PPR_PprId = PPRID and PPRTYP = 3)
    WHERE ((PZZat <= convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)
	AND PZZwol >= convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120)) OR UUmw > 0)
		AND Data >= PZZat AND Data <= PZZwol
UNION ALL

SELECT BAZ.Baz_Nazwa [Baza Firmowa], ''Nie dotyczy'' [Kalendarz],
case Isnull(PRA_Archiwalny,0)
 when 0 then ''NIE''
 else ''TAK''
 end [Pracownik Archiwalny],
PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
PRE_Kod [Pracownik Kod], 
ISNULL(sta.DKM_Nazwa,''(NIEPRZYPISANE)'') [Pracownik Stanowisko],
	isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
	isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],
''Nie dotyczy'' [Data Godzina Od], ''Nie dotyczy'' [Data Godzina Do], GETDATE() [Data Analizy], ''Nie dotyczy'' [Strefa],''Nie dotyczy'' [Strefa Nazwa],''Nie dotyczy'' [Wydział], ''Nie dotyczy'' [Projekt],
--CASE WHEN (PPL_TypDnia = 1 OR (PPL_PplId IS NULL AND KAD_TypDnia = 1)) AND (ISNULL(PNB_Calodzienna,0) = 0) THEN ''TAK'' ELSE ''NIE'' END [Obecność],
''Nie dotyczy'' [Typ Dnia], NULL [Wymiar Pracy w Godzinach], NULL [Wymiar Pracy w Minutach], NULL [Wymiar Pracy], NULL [Wymiar Pracy w Dniach],
NULL [Czas Pracy w Godzinach], NULL [Czas Pracy w Minutach], NULL [Czas Pracy], NULL [Czas Pracy w Dniach],
''Nie dotyczy'' [Nieobecność Typ], ''Nie dotyczy'' [Nieobecność Usprawiedliwiona], ''Nie dotyczy'' [Nieobecność Przyczyna], ''Nie dotyczy'' [Nieobecność Status],
''Nie dotyczy'' [Nieobecność Na Żądanie], NULL [Nieobecności w Godzinach], NULL [Nieobecności w Dniach Kalendarzowych], NULL [Nieobecności w Dniach Pracy],
LNB_Nazwa [Limit Nieobecności Typ], 
REPLACE(CONVERT(VARCHAR(10), X.PLN_OkresOd, 111), ''/'', ''-'') [Limit Nieobecności Od], REPLACE(CONVERT(VARCHAR(10), X.PLN_OkresDo, 111), ''/'', ''-'') [Limit Nieobecności Do],
''Nie dotyczy'' [Nieobecność Od], ''Nie dotyczy'' [Nieobecność Do],

ISNULL(Y.PLN_NalezneLacznieF, X.PLN_NalezneLacznieF) [Limit Nieobecności Należny Dni],
DATEDIFF(hour,convert(datetime,''18991230'',112),ISNULL(Y.PLN_NalezneLacznieCzas,X.PLN_NalezneLacznieCzas)) [Limit Nieobecności Należny Godziny],

NULL [Limit Nieobecności Wykorzystany Dni],
NULL [Limit Nieobecności Wykorzystany Godziny],

ISNULL(Y.PLN_NalezneLacznieF, X.PLN_NalezneLacznieF) - ISNULL(ISNULL(DNILIM,0),0) - CASE WHEN GodzLIM IS NULL THEN 0 ELSE (GodzLIM/8)/isnull(NUllif((cast(PRE_ETAEtatL as decimal)/cast(isnull(NUllif(PRE_ETAEtatM,0),1) as decimal)),0),1) END - X.PLN_EkwiwalentF [Limit Nieobecności Pozostały Dni],
DATEDIFF(hour,convert(datetime,''18991230'',112),ISNULL(Y.PLN_NalezneLacznieCzas,X.PLN_NalezneLacznieCzas)) - isnull(GodzLim,0)  - case when ISNULL(DNILIM,0) IS NULL THEN 0 ELSE (ISNULL(DNILIM,0) * 8 / ISNULL(NULLIF(cast(PRE_ETAEtatL as decimal)/cast(ISNULL(NULLIF(PRE_ETAEtatM,0),1) as decimal),0),1)) END  -  DATEDIFF(hour, convert(datetime,''1899-12-30 00:00:00.000'',120),X.PLN_EkwiwalentCzas) [Limit Nieobecności Pozostały Godziny],
ISNULL(Y.PLN_PrzeniesienieF,X.PLN_PrzeniesienieF) [Limit Nieobecności Zaległy Dni],
DATEDIFF(hour,convert(datetime,''18991230'',112),ISNULL(Y.PLN_PrzeniesienieCzas,X.PLN_PrzeniesienieCzas))[Limit Nieobecności Zaległy Godziny],
NULL [Wypłata Wartość Netto], NULL [Suma Elementów Wypłaty], NULL [Wypłata Wynagrodzenie Zasadnicze], 
ISNULL(X.PLN_PlanowanyF, Y.PLN_PlanowanyF) [Urlop Planowany Dni],
CASE 
WHEN  ISNULL(Y.PLN_LNBId, X.PLN_LNBId)  NOT IN (1,3,6) OR ISNULL(Y.PLN_LNBId, X.PLN_LNBId) IS NULL THEN NULL
ELSE ISNULL(X.PLN_NalezneLacznieF, Y.PLN_NalezneLacznieF) END AS [Urlop Wypoczynkowy Należny Dni],
CASE 
WHEN  ISNULL(Y.PLN_LNBId, X.PLN_LNBId)  NOT IN (1,3,6) OR ISNULL(Y.PLN_LNBId, X.PLN_LNBId) IS NULL THEN NULL
ELSE ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF) END 
- CASE WHEN LIM_LNBID NOT IN (1,3,6) or LIM_LNBID IS NULL THEN 0 ELSE 
ISNULL(DNILIM,0) + (CASE WHEN GodzLIM IS NULL THEN 0 ELSE (GodzLIM/8)/ISNULL(NULLIF((cast(PRE_ETAEtatL as decimal)/cast(ISNULL(NULLIF(PRE_ETAEtatM,0),1) as decimal)),0),1) end) END - X.PLN_EkwiwalentF
AS [Urlop Wypoczynkowy Pozostało Dni],
CASE 
WHEN  ISNULL(Y.PLN_LNBId, X.PLN_LNBId)  NOT IN (1,3,6) THEN 0
When Rezerwa = 0 THEN 0
WHEN PRE_ETAEtatL=3 AND PRE_ETAEtatM=4 THEN ((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0) - X.PLN_EkwiwalentF)*IlMies)/'+ @wspol +'/0.75 * NULLIF(Rezerwa,0)
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=2 THEN ((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0))*IlMies - X.PLN_EkwiwalentF)/'+ @wspol +'/0.5 * NULLIF(Rezerwa,0)
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=3 THEN ((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0))*IlMies - X.PLN_EkwiwalentF)/'+ @wspol +'/0.33 * NULLIF(Rezerwa,0)
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=4 THEN ((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0))*IlMies- X.PLN_EkwiwalentF )/'+ @wspol +'/0.25 * NULLIF(Rezerwa,0)
ELSE  ((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)*IlMies)/'+ @wspol +' * NULLIF(Rezerwa,0) END [Przybliżona Rezerwa Urlopowa],
NULL  [Obowiązujący Limit Nieobecności Należny Dni ],
NULL[Obowiązujący Limit Nieobecności Należny Godziny ],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Dni ],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Godziny ], 
NULL  [Obowiązujący Limit Nieobecności Pozostały Dni ],
NULL [Obowiązujący Limit Nieobecności Pozostały Godziny ],
NULL  [Obowiązujący Limit Nieobecności Zaległy Dni ],
NULL [Obowiązujący Limit Nieobecności Zaległy Godziny ],
NULL [Obowiązujący Urlop Planowany Dni ],
NULL [Obowiązujący Urlop Wypoczynkowy Należny Dni ],
NULL[Obowiązujący Urlop Wypoczynkowy Pozostało Dni ],
NULL [Obowiązujący Przybliżona Rezerwa Urlopowa ],
NULL [Limit Nieobecności Należny Cały Okres Dni],
NULL [Limit Nieobecności Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Pozostały Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Należny Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Pozostały Cały Okres Dni],

PRE_Kod [Liczba Pracowników]
,DZPR.DZL_Kod AS [Pracownik Wydział]
,CASE rob.DKM_Robotnicze WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Stanowisko Robotnicze]
		,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZat, 111), ''/'', ''-''),''(BRAK)'') END [Data Zatrudnienia Dzień]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Miesiąc]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZat) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZat)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Tydzień Roku] 
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZat) AS VARCHAR(10)),''(BRAK)'') END AS [Data Zatrudnienia Kwartał]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Rok] 
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZwol, 111), ''/'', ''-''),''(BRAK)'') END [Data Zwolnienia Dzień]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Miesiąc]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZwol) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZwol)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Tydzień Roku]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Kwartał]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Rok]
	 ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE CASE WHEN PZZwol > GetDate() THEN CASE WHEN datediff(yy,PZZat,GetDate()) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,GetDate()) AS VARCHAR(10)),''(BRAK)'') END ELSE CASE WHEN datediff(yy,PZZat,PZZwol) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,PZZwol) AS VARCHAR(10)),''(BRAK)'') END END END [Pracownik Lata Pracy]
	  ,ISNULL(CAST (datediff(yy,PRE_DataUr,X.PLN_WaznyOd) AS VARCHAR(10)),''(BRAK)'') [Pracownik Wiek]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]
/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), X.PLN_WaznyOd, 111), ''/'', ''-'') [Data]
*/

----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), X.PLN_WaznyOd, 111), ''/'', ''-'') [Data Dzień], MONTH(X.PLN_WaznyOd) [Data Miesiąc], YEAR(X.PLN_WaznyOd) [Data Rok]
,CASE when MONTH( X.PLN_WaznyOd) <7 THEN ''I'' else ''II'' END AS [Data Półrocze]
,DATEPART(quarter,  X.PLN_WaznyOd) AS [Data Kwartał] 

----------KONTEKSTY
,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]
,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]

' + @kolumny + @atrybuty + '
FROM CDN.LimitNieobec
	JOIN CDN.PracLimit X ON X.PLN_LnbId = LNB_LnbId  AND X.PLN_PierwszaPraca = 0
	LEFT JOIN CDN.PracLimit Y ON X.PLN_PlnId = Y.PLN_ParentId  AND y.PLN_PierwszaPraca = 0
	LEFT JOIN CDN.PracEtaty ON PRE_PreId = (SELECT TOP 1 PRE_PreId FROM CDN.PracEtaty WHERE PRE_PraId = X.PLN_PraId AND 
	((((PRE_DataOd Between X.PLN_WaznyOd AND X.PLN_OkresDo) AND (PRE_DataDo Between X.PLN_WaznyOd AND X.PLN_OkresDo ))
	OR ((X.PLN_WaznyOd BETWEEN PRE_DataOd AND PRE_DataDo)AND(X.PLN_OkresDo BETWEEN PRE_DataOd AND PRE_DataDo)))
	OR (YEAR(X.PLN_OkresDo) = YEAR (PRE_DataDo) )
	OR (YEAR(X.PLN_WAZNYOD) = YEAR (PRE_Dataod) )
	) ORDER BY PRE_PreId DESC)		LEFT JOIN #PracZat on PZPraId = PRE_PraID
	LEFT JOIN CDN.PracKod on PRA_PraId = PRE_PraId
	LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko =  sta.DKM_DkmId AND  sta.DKM_Rodzaj = 1
	LEFT JOIN (
		SELECT AVG(Rezerwa) Rezerwa, WPL_PraId from	
		(	
		SELECT SUM(WPE_Wartosc) [Rezerwa], WPL_PraId, WPL_DataDok FROM CDN.Wyplaty
	LEFT JOIN CDN.WypElementy ON WPL_WplId = WPE_WplId 
	JOIN CDN.TypWyplata ON WPE_TwpId = TWP_TwpId AND TWP_AlgPotracenie = 0 AND TWP_WchodziDoWyplaty = 1	and TWP_WliczEkwiwal IN (1,3)
	WHERE WPL_DataDok > DATEADD(m, -3, convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)) and WPL_DataDok <= convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120) GROUP BY WPL_PraId, WPL_DataDok	
	) x group by WPL_PraId	
	)R ON R.WPL_PraId = X.PLN_PraId
	LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
	LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
	LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = PRE_ZakId
	LEFT JOIN cdn.DaneKadMod rob on PRE_ETADkmIdStanowisko = rob.DKM_DkmId
	LEFT JOIN cdn.Dzialy DZPR ON PRE_DzlId = DZPR.DZL_DzlId 
	LEFT JOIN (SELECT COUNT(*) IloscLimitow,PLN_PraId Prac FROM CDN.PracLimit JOIN CDN.PracKod on PLN_PraId = PRA_PraId WHERE PLN_LNBId in (1,3,6) and (PLN_OkresOd BETWEEN convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) AND  convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)  OR PLN_OkresDo BETWEEN  convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) AND  convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)) GROUP BY PLN_PraId)illim ON Prac = PRE_PraID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON PRE_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON PRE_OpeModID = mod.Ope_OpeId
	LEFT JOIN #WykorzystaneDoDnia ON LIM_plnid = X.pln_plnid AND  Lim_praId = X.PLN_PraId AND X.PLN_LNBId = LIM_lnbid
	LEFT JOIN #tmpmies mies on X.PLN_PlnID = mies.PLNID
	WHERE  ((X.PLN_OkresOd BETWEEN convert(datetime, ''' + convert(varchar, @DATAOD, 120) + ''', 120) AND  convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120))  OR (X.PLN_OkresDo BETWEEN  convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) AND  convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)))
	OR (( convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) BETWEEN X.PLN_OkresOd AND X.PLN_OkresDo) OR ( convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120) BETWEEN X.PLN_OkresOd AND X.PLN_OkresDo))

		UNION ALL
		
SELECT BAZ.Baz_Nazwa [Baza Firmowa], ''Nie dotyczy'' [Kalendarz],
case Isnull(PRA_Archiwalny,0)
 when 0 then ''NIE''
 else ''TAK''
 end [Pracownik Archiwalny],
PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
PRE_Kod [Pracownik Kod], 
ISNULL(sta.DKM_Nazwa,''(NIEPRZYPISANE)'') [Pracownik Stanowisko],
	isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
	isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],
''Nie dotyczy'' [Data Godzina Od], ''Nie dotyczy'' [Data Godzina Do], GETDATE() [Data Analizy], ''Nie dotyczy'' [Strefa],''Nie dotyczy'' [Strefa Nazwa],''Nie dotyczy'' [Wydział], ''Nie dotyczy'' [Projekt],
--CASE WHEN (PPL_TypDnia = 1 OR (PPL_PplId IS NULL AND KAD_TypDnia = 1)) AND (ISNULL(PNB_Calodzienna,0) = 0) THEN ''TAK'' ELSE ''NIE'' END [Obecność],
''Nie dotyczy'' [Typ Dnia], NULL [Wymiar Pracy w Godzinach], NULL [Wymiar Pracy w Minutach], NULL [Wymiar Pracy], NULL [Wymiar Pracy w Dniach],
NULL [Czas Pracy w Godzinach], NULL [Czas Pracy w Minutach], NULL [Czas Pracy], NULL [Czas Pracy w Dniach],
''Nie dotyczy'' [Nieobecność Typ], ''Nie dotyczy'' [Nieobecność Usprawiedliwiona], ''Nie dotyczy'' [Nieobecność Przyczyna], ''Nie dotyczy'' [Nieobecność Status],
''Nie dotyczy'' [Nieobecność Na Żądanie], NULL [Nieobecności w Godzinach], NULL [Nieobecności w Dniach Kalendarzowych], NULL [Nieobecności w Dniach Pracy],
LNB_Nazwa [Limit Nieobecności Typ], 
REPLACE(CONVERT(VARCHAR(10), PP.PLN_OkresOd, 111), ''/'', ''-'') [Limit Nieobecności Od], REPLACE(CONVERT(VARCHAR(10), PP.PLN_OkresDo, 111), ''/'', ''-'') [Limit Nieobecności Do],
''Nie dotyczy'' [Nieobecność Od], ''Nie dotyczy'' [Nieobecność Do],

CASE WHEN PLN_PierwszaPraca = 1 THEN  PP.PLN_NalezneLacznieF else null end as [Limit Nieobecności Należny Dni],
CASE WHEN PLN_PierwszaPraca = 1 THEN  DATEDIFF(hour,convert(datetime,''18991230'',112),PP.PLN_NalezneLacznieCzas) else null end as [Limit Nieobecności Należny Godziny],

NULL [Limit Nieobecności Wykorzystany Dni],
NULL [Limit Nieobecności Wykorzystany Godziny],

CASE WHEN PLN_PierwszaPraca = 1 THEN PP.PLN_NalezneLacznieF else null end - ISNULL(ISNULL(DNILIM,0),0) - CASE WHEN GodzLIM IS NULL THEN 0 ELSE (GodzLIM/8)/(cast(ISNULL(NULLIF(PRE_ETAEtatL,0),1) as decimal)/cast(ISNULL(NULLIF(PRE_ETAEtatM,0),1) as decimal)) END - PP.PLN_EkwiwalentF as [Limit Nieobecności Pozostały Dni],
CASE WHEN PLN_PierwszaPraca = 1 THEN DATEDIFF(hour,convert(datetime,''18991230'',112),PP.PLN_NalezneLacznieCzas) else null end - ISNULL(Godzlim,0) -  DATEDIFF(hour, convert(datetime,''1899-12-30 00:00:00.000'',120),PP.PLN_EkwiwalentCzas) as [Limit Nieobecności Pozostały Godziny],
CASE WHEN PLN_PierwszaPraca = 1 THEN PP.PLN_PrzeniesienieF else null end as [Limit Nieobecności Zaległy Dni],
CASE WHEN PLN_PierwszaPraca = 1 THEN DATEDIFF(hour,convert(datetime,''18991230'',112),PP.PLN_PrzeniesienieCzas) else null end as [Limit Nieobecności Zaległy Godziny],
NULL [Wypłata Wartość Netto], NULL [Suma Elementów Wypłaty], NULL [Wypłata Wynagrodzenie Zasadnicze], 
CASE WHEN PLN_PierwszaPraca = 1 THEN PP.PLN_PlanowanyF  else null end as [Urlop Planowany Dni],

CASE 
WHEN  PP.PLN_LNBId NOT IN (1,3,6)  THEN NULL
WHEN  PP.PLN_PierwszaPraca = 1 THEN PP.PLN_NalezneLacznieF
else  NULL end AS [Urlop Wypoczynkowy Należny Dni],
CASE 
WHEN  PP.PLN_LNBId NOT IN (1,3,6)  THEN NULL
WHEN  PP.PLN_PierwszaPraca = 1 THEN PP.PLN_NalezneLacznieF
else  NULL end
-
CASE WHEN lim_lnbid not in (1,3,6) then 0 ELSE ISNULL(DNILIM,0) END 
- CASE  WHEN lim_lnbid not in (1,3,6) then 0 
WHEN GodzLIM IS NULL THEN 0 
ELSE (GodzLIM/8)/ISNULL(NULLIF((cast(PRE_ETAEtatL as decimal)/cast(ISNULL(NULLIF(PRE_ETAEtatM,0),1) as decimal)),0),1) END -PP.PLN_EkwiwalentF
AS [Urlop Wypoczynkowy Pozostało Dni],

CASE 
WHEN  PP.PLN_LNBId  NOT IN (1,3,6) THEN 0
WHEN PP.PLN_PierwszaPraca = 0 then null
When Rezerwa = 0 THEN 0
WHEN PRE_ETAEtatL=3 AND PRE_ETAEtatM=4 THEN ((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies)/'+ @wspol +'/0.75 * nullif(Rezerwa,0)
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=2 THEN ((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies)/'+ @wspol +'/0.5 * nullif(Rezerwa,0)
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=3 THEN ((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies)/'+ @wspol +'/0.33 * nullif(Rezerwa,0)
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=4 THEN((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies)/'+ @wspol +'/0.25 * nullif(Rezerwa,0)
ELSE ((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies) /'+ @wspol +' * nullif(Rezerwa,0) END [Przybliżona Rezerwa Urlopowa],

PLN_NalezneLacznieF  [Obowiązujący Limit Nieobecności Należny Dni ],
DATEDIFF(hour,convert(datetime,''18991230'',112),PP.PLN_NalezneLacznieCzas) [Obowiązujący Limit Nieobecności Należny Godziny ],
DniLim [Obowiązujący Limit Nieobecności Wykorzystany Dni ],
GodzLIM [Obowiązujący Limit Nieobecności Wykorzystany Godziny ], 
PP.PLN_NalezneLacznieF - isnull(ISNULL(DNILIM,0),0)  - CASE WHEN GodzLIM IS NULL THEN 0 ELSE (GodzLIM/8)/(cast(ISNULL(NULLIF(PRE_ETAEtatL,0),1) as decimal)/cast(ISNULL(NULLIF(PRE_ETAEtatm,0),1) as decimal)) END - PP.PLN_EkwiwalentF [Obowiązujący Limit Nieobecności Pozostały Dni ],
DATEDIFF(hour,convert(datetime,''18991230'',112),PP.PLN_NalezneLacznieCzas )  - ISNULL(GodzLIM,0) - case when ISNULL(DNILIM,0) IS NULL THEN 0 ELSE (ISNULL(DNILIM,0) * 8 / cast(ISNULL(NULLIF(PRE_ETAEtatL,0),1) as decimal)/cast(ISNULL(NULLIF(PRE_ETAEtatM,0),1) as decimal)) END - DATEDIFF(hour, convert(datetime,''1899-12-30 00:00:00.000'',120),PP.PLN_EkwiwalentCzas) [Obowiązujący Limit Nieobecności Pozostały Godziny ],
PP.PLN_PrzeniesienieF  [Obowiązujący Limit Nieobecności Zaległy Dni ],
DATEDIFF(hour,convert(datetime,''18991230'',112),PP.PLN_PrzeniesienieCzas) [Obowiązujący Limit Nieobecności Zaległy Godziny ],
PP.PLN_PlanowanyF [Obowiązujący Urlop Planowany Dni ],
CASE 
WHEN  PP.PLN_LNBId NOT IN (1,3,6)  THEN NULL
else  PP.PLN_NalezneLacznieF end  -PP.PLN_EkwiwalentF AS [Obowiązujący  Urlop Wypoczynkowy Należny Dni ],
CASE 
WHEN  PP.PLN_LNBId NOT IN (1,3,6)  THEN NULL
else PP.PLN_NalezneLacznieF end - 
CASE WHEN LIM_LNBID NOT IN (1,3,6) or LIM_LNBID IS NULL THEN 0 ELSE 
ISNULL(DNILIM,0) + (case when GodzLim is null then 0 else (GodzLIM/8)/(cast(ISNULL(NULLIF(PRE_ETAEtatL,0),1) as decimal)/cast(ISNULL(NULLIF(PRE_ETAEtatm,0),1) as decimal)) END) END
AS [Obowiązujący Urlop Wypoczynkowy Pozostało Dni ],

CASE 
WHEN  PP.PLN_LNBId  NOT IN (1,3,6) THEN 0
When Rezerwa = 0 THEN 0
WHEN PRE_ETAEtatL=3 AND PRE_ETAEtatM=4 THEN ((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies)/'+ @wspol +'/0.75 * nullif(Rezerwa,0)
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=2 THEN ((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies)/'+ @wspol +'/0.5 * nullif(Rezerwa,0)
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=3 THEN ((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies)/'+ @wspol +'/0.33 * nullif(Rezerwa,0)
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=4 THEN ((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies)/'+ @wspol +'/0.25 * nullif(Rezerwa,0)
ELSE ((PLN_NalezneLacznieF-ISNULL(DNILIM,0)- PLN_EkwiwalentF)*IlMies) /'+ @wspol +' * nullif(Rezerwa,0) END [Obowiązujący Przybliżona Rezerwa Urlopowa ],
PLN_NalezneLacznieF [Limit Nieobecności Należny Cały Okres Dni],
PLN_WykorzystaneF [Limit Nieobecności Wykorzystany Cały Okres Dni],
PLN_PozostaloF [Limit Nieobecności Pozostały Cały Okres Dni],
CASE 
WHEN  PP.PLN_LNBId  NOT IN (1,3,6) THEN 0 ELSE PLN_NalezneLacznieF END[Limit Nieobecności Urlop Wypoczynkowy Należny Cały Okres Dni],
CASE 
WHEN  PP.PLN_LNBId  NOT IN (1,3,6) THEN 0 ELSE PLN_WykorzystaneF END[Limit Nieobecności Urlop Wypoczynkowy Wykorzystany Cały Okres Dni],
CASE 
WHEN  PP.PLN_LNBId  NOT IN (1,3,6) THEN 0 ELSE PLN_PozostaloF END[Limit Nieobecności Urlop Wypoczynkowy Pozostały Cały Okres Dni],
PRE_Kod [Liczba Pracowników]
,DZPR.DZL_Kod AS [Pracownik Wydział]
,CASE rob.DKM_Robotnicze WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Stanowisko Robotnicze]
		,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZat, 111), ''/'', ''-''),''(BRAK)'') END [Data Zatrudnienia Dzień]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Miesiąc]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZat) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZat)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Tydzień Roku] 
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZat) AS VARCHAR(10)),''(BRAK)'') END AS [Data Zatrudnienia Kwartał]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Rok] 
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZwol, 111), ''/'', ''-''),''(BRAK)'') END [Data Zwolnienia Dzień]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Miesiąc]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZwol) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZwol)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Tydzień Roku]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Kwartał]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Rok]
	 ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE CASE WHEN PZZwol > GetDate() THEN CASE WHEN datediff(yy,PZZat,GetDate()) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,GetDate()) AS VARCHAR(10)),''(BRAK)'') END ELSE CASE WHEN datediff(yy,PZZat,PZZwol) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,PZZwol) AS VARCHAR(10)),''(BRAK)'') END END END [Pracownik Lata Pracy]
	  ,ISNULL(CAST (datediff(yy,PRE_DataUr,PP.PLN_OkresOd) AS VARCHAR(10)),''(BRAK)'') [Pracownik Wiek]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]

/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), PLN_WaznyOd, 111), ''/'', ''-'') [Data]
*/

----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), PLN_WaznyOd, 111), ''/'', ''-'') [Data Dzień], MONTH(PLN_WaznyOd) [Data Miesiąc], YEAR(PLN_WaznyOd) [Data Rok]
,CASE when MONTH( PLN_WaznyOd) <7 THEN ''I'' else ''II'' END AS [Data Półrocze]
,DATEPART(quarter,  PLN_WaznyOd) AS [Data Kwartał] 

----------KONTEKSTY
,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]
,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]


' + @kolumny + @atrybuty + '
FROM #AktualneLimity PP
JOIN CDN.LimitNieobec ON PLN_LnbID = LNB_LNBID
	JOIN CDN.PracEtaty ON PRE_PreId = (SELECT TOP 1 PRE_PreId FROM CDN.PracEtaty WHERE PRE_PraId = PP.PLN_PraId AND 
	((((PRE_DataOd Between PP.PLN_WaznyOd AND PP.PLN_OkresDo) AND (PRE_DataDo Between PP.PLN_WaznyOd AND PP.PLN_OkresDo ))
	OR ((PP.PLN_WaznyOd BETWEEN PRE_DataOd AND PRE_DataDo)AND(PP.PLN_OkresDo BETWEEN PRE_DataOd AND PRE_DataDo)))
	OR (YEAR(PP.PLN_OkresDo) = YEAR (PRE_DataDo) )
	OR (YEAR(PP.PLN_WAZNYOD) = YEAR (PRE_Dataod) )
	) ORDER BY PRE_PreId DESC)		
	
	LEFT JOIN #PracZat on PZPraId = PRE_PraID
	LEFT JOIN CDN.PracKod on PRA_PraId = PRE_PraId
	LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko =  sta.DKM_DkmId AND  sta.DKM_Rodzaj = 1
	LEFT JOIN (
		SELECT AVG(Rezerwa) Rezerwa, WPL_PraId from	
		(	
		SELECT SUM(WPE_Wartosc) [Rezerwa], WPL_PraId, WPL_DataDok FROM CDN.Wyplaty
	LEFT JOIN CDN.WypElementy ON WPL_WplId = WPE_WplId 
	JOIN CDN.TypWyplata ON WPE_TwpId = TWP_TwpId AND TWP_AlgPotracenie = 0 AND TWP_WchodziDoWyplaty = 1	and TWP_WliczEkwiwal IN (1,3)
	WHERE WPL_DataDok > DATEADD(m, -3, convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)) and WPL_DataDok <= convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120) GROUP BY WPL_PraId, WPL_DataDok	
	) x group by WPL_PraId	
	)R ON R.WPL_PraId = PP.PLN_PraId 
	LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
	LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
	LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = PRE_ZakId
	LEFT JOIN cdn.DaneKadMod rob on PRE_ETADkmIdStanowisko = rob.DKM_DkmId
	LEFT JOIN cdn.Dzialy DZPR ON PRE_DzlId = DZPR.DZL_DzlId 
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
	LEFT JOIN ' + @Operatorzy + ' zal ON PRE_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON PRE_OpeModID = mod.Ope_OpeId
	LEFT JOIN #WykorzystaneDoDnia ON LIM_plnid = pln_plnid AND  Lim_praId = PLN_PraId AND PLN_LNBId = LIM_lnbid
	LEFT JOIN #tmpmies mies on PP.PLN_PlnID = mies.PLNID
   WHERE  (PLN_OkresOd BETWEEN  convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) AND  convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120))  OR (PLN_OkresDo BETWEEN  convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) AND convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120))
   	OR (( convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) BETWEEN PLN_OkresOd AND PLN_OkresDo) OR ( convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120) BETWEEN PLN_OkresOd AND PLN_OkresDo))

UNION ALL
SELECT BAZ.Baz_Nazwa [Baza Firmowa], ''Nie dotyczy'' [Kalendarz],
case Isnull(PRA_Archiwalny,0)
 when 0 then ''NIE''
 else ''TAK''
 end [Pracownik Archiwalny],
PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
PRE_Kod [Pracownik Kod], 
ISNULL(sta.DKM_Nazwa,''(NIEPRZYPISANE)'') [Pracownik Stanowisko],
	isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
	isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],
''Nie dotyczy'' [Data Godzina Od], ''Nie dotyczy'' [Data Godzina Do], GETDATE() [Data Analizy], ''Nie dotyczy'' [Strefa],''Nie dotyczy'' [Strefa Nazwa],''Nie dotyczy'' [Wydział], ''Nie dotyczy'' [Projekt],
--CASE WHEN (PPL_TypDnia = 1 OR (PPL_PplId IS NULL AND KAD_TypDnia = 1)) AND (ISNULL(PNB_Calodzienna,0) = 0) THEN ''TAK'' ELSE ''NIE'' END [Obecność],
''Nie dotyczy'' [Typ Dnia], NULL [Wymiar Pracy w Godzinach], NULL [Wymiar Pracy w Minutach], NULL [Wymiar Pracy], NULL [Wymiar Pracy w Dniach],
NULL [Czas Pracy w Godzinach], NULL [Czas Pracy w Minutach], NULL [Czas Pracy], NULL [Czas Pracy w Dniach],
''Nie dotyczy'' [Nieobecność Typ], ''Nie dotyczy'' [Nieobecność Usprawiedliwiona], ''Nie dotyczy'' [Nieobecność Przyczyna], ''Nie dotyczy'' [Nieobecność Status],
''Nie dotyczy'' [Nieobecność Na Żądanie], NULL [Nieobecności w Godzinach], NULL [Nieobecności w Dniach Kalendarzowych], NULL [Nieobecności w Dniach Pracy],
LNB_Nazwa [Limit Nieobecności Typ], 
REPLACE(CONVERT(VARCHAR(10), isnull(X.PLN_OkresOd,OkresOd), 111), ''/'', ''-'') [Limit Nieobecności Od], REPLACE(CONVERT(VARCHAR(10), ISNULL(X.PLN_OkresDo,OkresDo), 111), ''/'', ''-'') [Limit Nieobecności Do],
''Nie dotyczy'' [Nieobecność Od], ''Nie dotyczy'' [Nieobecność Do],

NULL [Limit Nieobecności Należny Dni],
NULL [Limit Nieobecności Należny Godziny],

CASE WHEN Dni IS NULL THEN 0 
WHEN Godziny <> 0 THEN 1.0/(8.0/isnull(NULLIF(Godziny,0),1))
ELSE CAST(sumGodz/8.0 AS DECIMAL(18,4)) END AS [Limit Nieobecności Wykorzystany Dni],
CASE WHEN Godziny IS NOT NULL AND Godziny <> 0 
THEN Godziny
ELSE CAST(sumGodz AS DECIMAL(18,4)) END AS [Limit Nieobecności Wykorzystany Godziny],

CASE WHEN Dni IS NULL THEN 0 
WHEN Godziny <> 0 THEN -1.0/(8.0/isnull(NULLIF(Godziny,0),1))
ELSE -CAST(sumGodz/8.0 AS DECIMAL(18,4)) END AS  [Limit Nieobecności Pozostały Dni],
CASE WHEN Godziny IS NOT NULL AND Godziny <> 0 
THEN -Godziny
ELSE -CAST(sumGodz AS DECIMAL(18,4)) END AS [Limit Nieobecności Pozostały Godziny],
NULL [Limit Nieobecności Zaległy Dni],
NULL [Limit Nieobecności Zaległy Godziny],
NULL [Wypłata Wartość Netto], NULL [Suma Elementów Wypłaty], NULL [Wypłata Wynagrodzenie Zasadnicze], 
NULL [Urlop Planowany Dni],
NULL [Urlop Wypoczynkowy Należny Dni],
CASE WHEN Dni IS NULL THEN 0 
WHEN  ISNULL(Y.PLN_LNBId, X.PLN_LNBId)  NOT IN (1,3,6) OR ISNULL(Y.PLN_LNBId, X.PLN_LNBId) IS NULL THEN null
WHEN Godziny <> 0 THEN -1.0/(8.0/isnull(NULLIF(Godziny,0),1))
ELSE -CAST(sumGodz/8.0 AS DECIMAL(18,4)) END AS  [Urlop Wypoczynkowy Pozostało Dni],
CASE 
WHEN  ISNULL(Y.PLN_LNBId, X.PLN_LNBId)  NOT IN (1,3,6) OR ISNULL(Y.PLN_LNBId, X.PLN_LNBId) IS NULL THEN 0
WHEN Dni IS NULL THEN 0
WHEN Rezerwa = 0 THEN 0
WHEN ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF) = 0 THEN 0 
WHEN Godziny <> 0 THEN - (((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +'* 1.0/(8.0/isnull(NULLIF(Godziny,0),1)) * Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0)) * IlMies
WHEN PRE_ETAEtatL=3 AND PRE_ETAEtatM=4 THEN -(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +' *Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0))* IlMies
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=2 THEN -(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +' *Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0))* IlMies
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=3 THEN -(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +'* Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0))* IlMies
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=4 THEN -(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +' *Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0))* IlMies
ELSE- (((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +' * Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0)) * IlMies  END AS[Przybliżona Rezerwa Urlopowa],
NULL  [Limit Nieobecności Należny Dni ],
NULL[Limit Nieobecności Należny Godziny ],
CASE
when akt.PLN_PLNID IS NULL THEN NULL 
WHEN Dni IS NULL THEN 0 
WHEN Godziny <> 0 THEN 1.0/(8.0/isnull(NULLIF(Godziny,0),1))
ELSE CAST(sumGodz/8.0 AS DECIMAL(18,4)) END AS [Obowiązujący Limit Nieobecności Wykorzystany Dni ],
CASE when akt.PLN_PLNID IS NULL THEN NULL
WHEN Godziny IS NOT NULL AND Godziny <> 0 
THEN Godziny
ELSE CAST(sumGodz AS DECIMAL(18,4)) END AS [Obowiązujący Limit Nieobecności Wykorzystany Godziny ], 

CASE when akt.PLN_PLNID IS NULL THEN NULL
WHEN Dni IS NULL THEN 0 
WHEN Godziny <> 0 THEN -1.0/(8.0/isnull(NULLIF(Godziny,0),1))
ELSE -CAST(sumGodz/8.0 AS DECIMAL(18,4)) END  AS  [Obowiązujący Limit Nieobecności Pozostały Dni ],
CASE when akt.PLN_PLNID IS NULL THEN NULL
WHEN Godziny IS NOT NULL AND Godziny <> 0 
THEN -Godziny
ELSE -CAST(sumGodz AS DECIMAL(18,4)) END  AS [Obowiązujący Limit Nieobecności Pozostały Godziny ],
NULL  [Obowiązujący Limit Nieobecności Zaległy Dni ],
NULL [Obowiązujący Limit Nieobecności Zaległy Godziny ],
NULL [Obowiązujący Urlop Planowany Dni ],
NULL [Obowiązujący Urlop Wypoczynkowy Należny Dni ],
CASE WHEN  ISNULL(Y.PLN_LNBId, X.PLN_LNBId)  NOT IN (1,3,6) OR ISNULL(Y.PLN_LNBId, X.PLN_LNBId) IS NULL THEN NULL 
when akt.PLN_PLNID IS NULL THEN NULL
WHEN Dni IS NULL THEN 0 
WHEN Godziny <> 0 THEN -1.0/(8.0/isnull(NULLIF(Godziny,0),1))
ELSE -CAST(sumGodz/8.0 AS DECIMAL(18,4)) END 
[Obowiązujący Urlop Wypoczynkowy Pozostało Dni ],
CASE 
WHEN  akt.PLN_PLNID IS NULL THEN 0 
WHEN ISNULL(Y.PLN_LNBId, X.PLN_LNBId)  NOT IN (1,3,6) OR ISNULL(Y.PLN_LNBId, X.PLN_LNBId) IS NULL THEN 0
WHEN Dni IS NULL THEN 0
WHEN Rezerwa = 0 THEN 0
WHEN ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF) = 0 THEN 0 
WHEN Godziny <> 0 THEN - (((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +'* 1.0/(8.0/isnull(NULLIF(Godziny,0),1)) * Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0)) * IlMies
WHEN PRE_ETAEtatL=3 AND PRE_ETAEtatM=4 THEN -(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +' *Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0)) * IlMies
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=2 THEN -(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +' *Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0)) * IlMies
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=3 THEN -(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +' *Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0)) * IlMies
WHEN PRE_ETAEtatL=1 AND PRE_ETAEtatM=4 THEN -(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +' *Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0)) * IlMies
ELSE- (((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF))/'+ @wspol +' * Rezerwa/NULLIF(((ISNULL(Y.PLN_NalezneLacznieF,X.PLN_NalezneLacznieF)-ISNULL(DNILIM,0)- X.PLN_EkwiwalentF)),0)) * IlMies  END AS   [Obowiązujący Przybliżona Rezerwa Urlopowa ],
NULL [Limit Nieobecności Należny Cały Okres Dni],
NULL [Limit Nieobecności Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Pozostały Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Należny Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Pozostały Cały Okres Dni],
PRE_Kod [Liczba Pracowników]
,DZPR.DZL_Kod AS [Pracownik Wydział]
,CASE rob.DKM_Robotnicze WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Stanowisko Robotnicze]
		,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZat, 111), ''/'', ''-''),''(BRAK)'') END [Data Zatrudnienia Dzień]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Miesiąc]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZat) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZat)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Tydzień Roku] 
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZat) AS VARCHAR(10)),''(BRAK)'') END AS [Data Zatrudnienia Kwartał]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Rok] 
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZwol, 111), ''/'', ''-''),''(BRAK)'') END [Data Zwolnienia Dzień]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Miesiąc]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZwol) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZwol)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Tydzień Roku]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Kwartał]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Rok]
	 ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE CASE WHEN PZZwol > GetDate() THEN CASE WHEN datediff(yy,PZZat,GetDate()) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,GetDate()) AS VARCHAR(10)),''(BRAK)'') END ELSE CASE WHEN datediff(yy,PZZat,PZZwol) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,PZZwol) AS VARCHAR(10)),''(BRAK)'') END END END [Pracownik Lata Pracy]
	  ,ISNULL(CAST (datediff(yy,PRE_DataUr,Date) AS VARCHAR(10)),''(BRAK)'') [Pracownik Wiek]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]

/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), Date, 111), ''/'', ''-'') [Data]

*/
----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), Date, 111), ''/'', ''-'') [Data Dzień], MONTH(Date) [Data Miesiąc], YEAR(Date) [Data Rok]
,CASE when MONTH(Date) <7 THEN ''I'' else ''II'' END AS [Data Półrocze]
,DATEPART(quarter, Date) AS [Data Kwartał] 

----------KONTEKSTY
,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]
,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]

' + @kolumny + @atrybuty + '
FROM
(SELECT  PNB_PraId,TNB_lnbId,COUNT(*) AS dni, SUM(Godziny) AS Godziny, Date,
CASE WHEN ISNULL(PGL_OdGodziny,KDG_OdGodziny) > ISNULL(PGL_DoGodziny,KDG_DoGodziny)
THEN SUM(DATEDIFF(MINUTE,ISNULL(PGL_OdGodziny,KDG_OdGodziny),ISNULL(Dateadd(day,1,PGL_DoGodziny),Dateadd(day,1,KDG_DoGodziny))))
ELSE SUM(DATEDIFF(MINUTE,ISNULL(PGL_OdGodziny,KDG_OdGodziny),ISNULL(PGL_DoGodziny,KDG_DoGodziny))) END  /60.0 AS sumGodz,
CASE WHEN ISNULL(PGL_OdGodziny,KDG_OdGodziny) > ISNULL(PGL_DoGodziny,KDG_DoGodziny)
THEN SUM(DATEDIFF(MINUTE,ISNULL(PGL_OdGodziny,KDG_OdGodziny),ISNULL(Dateadd(day,1,PGL_DoGodziny),Dateadd(day,1,KDG_DoGodziny))))
ELSE SUM(DATEDIFF(MINUTE,ISNULL(PGL_OdGodziny,KDG_OdGodziny),ISNULL(PGL_DoGodziny,KDG_DoGodziny))) END AS sumMin
 FROM
		(
		 select DISTINCT
				Date,
				nieob.PNB_PraId,
				typ.TNB_lnbId,
				nieob.PNB_OkresOd AS OkresOd,
				nieob.PNB_OkresDo AS OkresDo,
				isnull(DATEDIFF(n,convert(datetime ,''1899-12-30 00:00:00.000'',120),nieob.PNB_Godz)/(60), 0) Godziny

				
			from
				#WszystkieDaty  
				join CDN.PracNieobec nieob ON [Date] between nieob.PNB_OkresOd and nieob.PNB_OkresDo 
				join CDN.TypNieobec typ ON nieob.Pnb_TnbId = typ.TNB_TnbId
			where
				(nieob.PNB_Tryb = 0 or nieob.PNB_Tryb = 2) 
		
		)Lmt 
		LEFT JOIN CDN.PracEtaty ON PRE_PraId = PNB_PraId  AND Date Between  PRE_DataOd AND  PRE_DataDo
		LEFT JOIN CDN.PracPlanDni ON PPL_PraId = PNB_PraId AND PPL_Data = Date
		LEFT JOIN CDN.PracPlanDniGodz on PPL_PplId = PGL_PplId
		LEFT JOIN CDN.KalendDni ON Date = KAD_Data AND PRE_KalId = KAD_KalId
		LEFT JOIN CDN.KalendDniGodz ON  KAD_KadId = KDG_KadId
		WHERE ISNULL(PPL_TypDnia,KAD_TypDnia) = 1 OR (ISNULL(PPL_TypDnia,KAD_TypDnia) is null and (DATEPART(dw,Date) NOT IN (1,7) ) AND DATE NOT IN (select dzien from #Swieta))
		GROUP BY PNB_PraId,TNB_lnbId,Date,PGL_OdGodziny,KDG_OdGodziny,PGL_DoGodziny,KDG_DoGodziny)LmtSum 
		LEFT JOIN CDN.LimitNieobec ON LmtSum.TNB_lnbId =lnb_lnbid 
		LEFT JOIN CDN.PracLimit X ON X.PLN_LnbId = LNB_LnbId AND (X.PLN_OkresOd <= date AND X.PLN_OkresDo >= date) AND X.PLN_PraId = PNB_PraId AND (X.PLN_PierwszaPraca = 0 or date between X.PLN_WaznyOd  AND X.PLN_OkresDo  )
		LEFT JOIN CDN.PracEtaty ON LmtSum.PNB_PraId = PRE_PraID AND PRE_PreId = (SELECT TOP 1 PRE_PreId FROM CDN.PracEtaty WHERE PRE_PraId = LmtSum.PNB_PraId AND  Date Between  PRE_DataOd AND  PRE_DataDo ORDER BY PRE_PreId DESC)
		LEFT JOIN CDN.PracLimit Y ON X.PLN_PlnId = Y.PLN_ParentId AND (Y.PLN_OkresOd <= date AND Y.PLN_OkresDo >= date) AND Y.PLN_PraId = PNB_PraId
		LEFT JOIN #PracZat on PZPraId = PRE_PraID
		LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko =  sta.DKM_DkmId AND  sta.DKM_Rodzaj = 1
		LEFT JOIN cdn.DaneKadMod rob on PRE_ETADkmIdStanowisko = rob.DKM_DkmId
		LEFT JOIN cdn.Dzialy DZPR ON PRE_DzlId = DZPR.DZL_DzlId 
		LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
		LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
		LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = PRE_ZakId
		LEFT JOIN CDN.PracKod on PRA_PraId = PRE_PraId
		LEFT JOIN (
		SELECT AVG(Rezerwa) Rezerwa, WPL_PraId from	
		(	
		SELECT SUM(WPE_Wartosc) [Rezerwa], WPL_PraId, WPL_DataDok FROM CDN.Wyplaty
	LEFT JOIN CDN.WypElementy ON WPL_WplId = WPE_WplId 
	JOIN CDN.TypWyplata ON WPE_TwpId = TWP_TwpId AND TWP_AlgPotracenie = 0 AND TWP_WchodziDoWyplaty = 1	and TWP_WliczEkwiwal IN (1,3)
	WHERE WPL_DataDok > DATEADD(m, -3, convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)) and WPL_DataDok <= convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120) GROUP BY WPL_PraId, WPL_DataDok	
	) x group by WPL_PraId	
	)R ON R.WPL_PraId = PRE_PraId
	LEFT JOIN (SELECT COUNT(*) IloscLimitow,PLN_PraId Prac FROM CDN.PracLimit JOIN CDN.PracKod on PLN_PraId = PRA_PraId WHERE PLN_LNBId in (1,3,6) and (PLN_OkresOd BETWEEN  convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) AND  convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)  OR PLN_OkresDo BETWEEN  convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) AND convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)) AND PLN_PierwszaPraca = 0 GROUP BY PLN_PraId)illim ON Prac = PRE_PraID
	LEFT JOIN (select MIN(PLN_OkresOd) OkresOd ,MAX(PLN_OkresDo) OkresDo ,PLN_PraId PPraid ,PLN_LnbId PLnbId from cdn.PracLimit WHERE PLN_PierwszaPraca = 1 AND (PLN_OkresOd BETWEEN  convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) AND  convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)  OR PLN_OkresDo BETWEEN  convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) AND convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120))  GROUP BY PLN_PraId,PLN_LnbId) Pprac ON lnb_lnbid = PLnbId and PRE_PraID = PPraid
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON PRE_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON PRE_OpeModID = mod.Ope_OpeId
	LEFT JOIN #AktualneLimity AKT on X.PLN_Plnid = AKT.PLN_plnid
	LEFT JOIN #WykorzystaneDoDnia ON LIM_plnid = X.pln_plnid AND  Lim_praId = X.PLN_PraId AND X.PLN_LNBId = LIM_lnbid
    LEFT JOIN #tmpmies mies on X.PLN_PlnID = mies.PLNID
	LEFT JOIN #RzeczywisteObowiazywanieLimitow on X.PLN_PlnId = RzPLN
	WHERE   
		LmtSum.TNB_lnbId IS NOT NULL  And Date Between ValidFrom AND ValidTo 

UNION ALL

SELECT BAZ.Baz_Nazwa [Baza Firmowa], ''Nie dotyczy'' [Kalendarz], 
case Isnull(PRA_Archiwalny,0)
 when 0 then ''NIE''
 else ''TAK''
 end [Pracownik Archiwalny],
PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
PRE_Kod [Pracownik Kod], 
ISNULL(sta.DKM_Nazwa,''(NIEPRZYPISANE)'') [Pracownik Stanowisko],
	isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
	isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],
''Nie dotyczy'' [Data Godzina Od], ''Nie dotyczy'' [Data Godzina Do], GETDATE() [Data Analizy], ''Nie dotyczy'' [Strefa],''Nie dotyczy'' [Strefa Nazwa], DZL.DZL_Kod [Wydział], ''Nie dotyczy'' [Projekt],
--CASE WHEN (PPL_TypDnia = 1 OR (PPL_PplId IS NULL AND KAD_TypDnia = 1)) AND (ISNULL(PNB_Calodzienna,0) = 0) THEN ''TAK'' ELSE ''NIE'' END [Obecność],
''Nie dotyczy'' [Typ Dnia], NULL [Wymiar Pracy w Godzinach], NULL [Wymiar Pracy w Minutach], NULL [Wymiar Pracy], NULL [Wymiar Pracy w Dniach],
NULL [Czas Pracy w Godzinach], NULL [Czas Pracy w Minutach], NULL [Czas Pracy], NULL [Czas Pracy w Dniach],
''Nie dotyczy'' [Nieobecność Typ], ''Nie dotyczy'' [Nieobecność Usprawiedliwiona], ''Nie dotyczy'' [Nieobecność Przyczyna], ''Nie dotyczy'' [Nieobecność Status],
''Nie dotyczy'' [Nieobecność Na Żądanie], NULL [Nieobecności w Godzinach], NULL [Nieobecności w Dniach Kalendarzowych], NULL [Nieobecności w Dniach Pracy],
''Nie dotyczy'' [Limit Nieobecności Typ], 
''Nie dotyczy'' [Limit Nieobecności Od], ''Nie dotyczy'' [Limit Nieobecności Do],
''Nie dotyczy'' [Nieobecność Od], ''Nie dotyczy'' [Nieobecność Do],
NULL [Limit Nieobecności Należny Dni],
NULL [Limit Nieobecności Należny Godziny],
NULL [Limit Nieobecności Wykorzystany Dni],
NULL [Limit Nieobecności Wykorzystany Godziny],
NULL [Limit Nieobecności Pozostały Dni],
NULL [Limit Nieobecności Pozostały Godziny],
NULL [Limit Nieobecności Zaległy Dni],
NULL [Limit Nieobecności Zaległy Godziny],

CASE WHEN TWP_WchodziDoWyplaty = 1 OR TWP_Rodzajzrodla = 35 THEN
		CASE WHEN PRE_Oddelegowany = 0 THEN CASE WHEN TWP_Rodzajzrodla = 35 THEN 0 ELSE WPE_Wartosc END - WPE_SklEmerPrac-WPE_SklRentPrac-WPE_SklChorPrac-WPE_SklWypadPrac-WPE_ZalFis-WPE_SklZdrowPrac-WPE_SklZdrowSuma-WPE_SklPPKPrac1-WPE_SklPPKPrac2 ELSE
			CASE WHEN TWP_RodzajZrodla = 1  THEN 
				CASE WHEN brutto - dieta < podstawaOpodatkowania THEN
					WPE_Wartosc - (podstawaOpodatkowania - podstawaOpodatkowania*0.1371)*0.09 - podstawaOpodatkowania*0.1371
				ELSE
					WPE_Wartosc - (brutto - dieta - (brutto - dieta)*0.1371)*0.09 - (brutto - dieta)*0.1371
				END ELSE WPE_Wartosc 
			END
		END ELSE 0
	END [Wypłata Wartość Netto],
	CASE WHEN TWP_WchodziDoWyplaty = 1 OR TWP_Rodzajzrodla = 35 THEN
		CASE WHEN WPE_Wartosc < 0
			THEN 0 
			ELSE WPE_Wartosc
		END
	ELSE 0 END [Suma Elementów Wypłaty],
	CASE WHEN TWP_RodzajZrodla <> 1 or TWP_WchodziDoWyplaty = 0 THEN 0 ELSE WPE_Wartosc END [Wypłata Wynagrodzenie Zasadnicze],
NULL [Urlop Planowany Dni],
NULL [Urlop Wypoczynkowy Należny Dni],
NULL [Urlop Wypoczynkowy Pozostało Dni],
NULL [Przybliżona Rezerwa Urlopowa],
NULL  [Obowiązujący Limit Nieobecności Należny Dni ],
NULL[Obowiązujący Limit Nieobecności Należny Godziny ],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Dni ],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Godziny ], 
NULL  [Obowiązujący Limit Nieobecności Pozostały Dni ],
NULL [Obowiązujący Limit Nieobecności Pozostały Godziny ],
NULL  [Obowiązujący Limit Nieobecności Zaległy Dni ],
NULL [Obowiązujący Limit Nieobecności Zaległy Godziny ],
NULL [Obowiązujący Urlop Planowany Dni ],
NULL [Obowiązujący Urlop Wypoczynkowy Należny Dni ],
NULL[Obowiązujący Urlop Wypoczynkowy Pozostało Dni ],
NULL [Obowiązujący Przybliżona Rezerwa Urlopowa ],
NULL [Limit Nieobecności Należny Cały Okres Dni],
NULL [Limit Nieobecności Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Pozostały Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Należny Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Pozostały Cały Okres Dni],
PRE_Kod [Liczba Pracowników]
,DZPR.DZL_Kod AS [Pracownik Wydział]
,CASE rob.DKM_Robotnicze WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Stanowisko Robotnicze]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZat, 111), ''/'', ''-''),''(BRAK)'') END [Data Zatrudnienia Dzień]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Miesiąc]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZat) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZat)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Tydzień Roku] 
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZat) AS VARCHAR(10)),''(BRAK)'') END AS [Data Zatrudnienia Kwartał]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Rok] 
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZwol, 111), ''/'', ''-''),''(BRAK)'') END [Data Zwolnienia Dzień]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Miesiąc]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZwol) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZwol)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Tydzień Roku]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Kwartał]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Rok]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE CASE WHEN PZZwol > GetDate() THEN CASE WHEN datediff(yy,PZZat,GetDate()) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,GetDate()) AS VARCHAR(10)),''(BRAK)'') END ELSE CASE WHEN datediff(yy,PZZat,PZZwol) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,PZZwol) AS VARCHAR(10)),''(BRAK)'') END END END [Pracownik Lata Pracy]
	  ,ISNULL(CAST (datediff(yy,PRE_DataUr,WPL_DataDok) AS VARCHAR(10)),''(BRAK)'') [Pracownik Wiek]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]

/*
----------DATY POINT
,NULL [Data]
*/

----------DATY ANALIZY
,''Nie dotyczy'' [Data Dzień], WPL_Miesiac [Data Miesiąc], WPL_Rok [Data Rok]
, CASE WHEN WPL_Miesiac < 7 THEN ''I'' else ''II'' END AS [Data Półrocze]
,DATEPART(quarter, WPL_DataDok) AS [Data Kwartał] 

----------KONTEKSTY
,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]
,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]


' + @kolumny + @atrybuty + '
FROM CDN.WypElementy
JOIN #Wyplaty On WPE_WplId = wyplataID
	JOIN CDN.Wyplaty ON WPE_WplId = WPL_WplId
	JOIN CDN.TypWyplata ON WPE_TwpId = TWP_TwpId
	JOIN CDN.PracEtaty ON WPL_PraId = PRE_PraId AND WPL_DataDok >= PRE_DataOd AND WPL_DataDok <= PRE_DataDo
	LEFT JOIN #PracZat on PZPraId = PRE_PraID
	LEFT JOIN CDN.PracKod on PRA_PraId = PRE_PraId
	LEFT JOIN CDN.Dzialy DZL ON WPL_DzlId = DZL_DzlId
	LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko =  sta.DKM_DkmId AND  sta.DKM_Rodzaj = 1
	LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
	LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
	LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = PRE_ZakId
	LEFT JOIN cdn.DaneKadMod rob on PRE_ETADkmIdStanowisko = rob.DKM_DkmId
	LEFT JOIN cdn.Dzialy DZPR ON PRE_DzlId = DZPR.DZL_DzlId 
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON PRE_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON PRE_OpeModID = mod.Ope_OpeId
WHERE
	WPL_DataOd >= convert(datetime,''' + convert(varchar, @DATAOD, 120) + ''', 120) 
	AND WPL_DataDo <= convert(datetime,''' + convert(varchar, @DATADO, 120) + ''', 120)

		UNION ALL

SELECT BAZ.Baz_Nazwa [Baza Firmowa], KAL_Akronim [Kalendarz], 
case Isnull(PRA_Archiwalny,0)
 when 0 then ''NIE''
 else ''TAK''
 end [Pracownik Archiwalny],
PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
PRE_Kod [Pracownik Kod], 
ISNULL(sta.DKM_Nazwa,''(NIEPRZYPISANE)'') [Pracownik Stanowisko],
	isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
	isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],

CONVERT(VARCHAR(5), COALESCE(PGR_OdGodziny,PGL_OdGodziny,KDG_OdGodziny),108) [Data Godzina Od], CONVERT(VARCHAR(5), COALESCE(PGR_DoGodziny,PGL_DoGodziny,KDG_DoGodziny),108) [Data Godzina Do],
GETDATE() [Data Analizy],
CASE WHEN Data > GETDATE() THEN NULL ELSE SPR.DST_Akronim END [Strefa], 
CASE WHEN Data > GETDATE() THEN NULL ELSE CASE WHEN SPR.DST_Nazwa = '''' THEN ''(NIEPRZEPISANA)'' ELSE SPR.DST_Nazwa END END [Strefa Nazwa], 
CASE WHEN Data > GETDATE() THEN NULL ELSE DPR.DZL_Kod END [Wydział], 
CASE WHEN Data > GETDATE() THEN NULL ELSE PPR.PRJ_Kod END [Projekt],
--CASE WHEN (PPL_TypDnia = 1 OR (PPL_PplId IS NULL AND KAD_TypDnia = 1)) AND (ISNULL(PNB_Calodzienna,0) = 0) THEN ''TAK'' ELSE ''NIE'' END [Obecność],
CASE COALESCE(PPL_TypDnia,KAD_TypDnia)
	WHEN 1 THEN ''Pracy''
	WHEN 2 THEN ''Wolny''
	WHEN 3 THEN ''Święto''
END [Typ Dnia],
NULL [Wymiar Pracy w Godzinach], NULL [Wymiar Pracy w Minutach],
''Czas Pracy'' [Wymiar Pracy],
 NULL [Wymiar Pracy w Dniach],
NULL [Czas Pracy w Godzinach], 
NULL [Czas Pracy w Minutach],
NULL [Czas Pracy],
NULL [Czas Pracy w Dniach],
ISNULL(TNB_Nazwa, ''Nie dotyczy'') [Nieobecność Typ], CASE WHEN TNB_Typ = 2 THEN ''NIE'' ELSE ''TAK'' END [Nieobecność Usprawiedliwiona],
CASE PNB_Przyczyna
	WHEN 1 THEN ''Nie dotyczy''
	WHEN 2 THEN ''Zwolnienie lekarskie''
	WHEN 3 THEN ''Wypadek w pracy/choroba zawodowa''
	WHEN 4 THEN ''Wypadek w drodze do/z pracy''
	WHEN 5 THEN ''Zwolnienie w okresie ciąży''
	WHEN 6 THEN ''Zwolnienie spowodowane gruźlicą''
	WHEN 7 THEN ''Nadużycie alkoholu''
	WHEN 8 THEN ''Przestępstwa/wykroczenie''
	WHEN 9 THEN ''Opieka nad dzieckiem do lat 14''
	WHEN 10 THEN ''Opieka nad inną osobą''
	WHEN 11 THEN ''Leczenie szpitalne''
	WHEN 12 THEN ''Badanie dawcy/pobranie organów'' 
	WHEN 13 THEN ''Urlop macierzyński 100%''
	WHEN 14 THEN ''Urlop macierzyński 80%''
	WHEN 15 THEN ''Urlop rodzicielski 80%''
	WHEN 16 THEN ''Urlop rodzicielski 60%''
	WHEN 17 THEN ''Urlop rodzicielski 100%''
	WHEN 19 THEN ''Niezdolność do pracy/kwarantanna służb medycznych''
	WHEN 20 THEN ''Niepoprawne wykorzystanie zwolnienia''
	WHEN 21 THEN ''Urlop macierzyński 81,5%''
	WHEN 22 THEN ''Urlop rodzicielski 81,5%''
	WHEN 23 THEN ''Urlop rodzicielski 70%''
	WHEN 24 THEN ''Urlop rodzicielski 70% (do 9 tygodni)''
	WHEN 25 THEN ''Urlop rodzicielski 70% (ustawa "Za życiem")''
	WHEN 22 THEN ''Urlop rodzicielski 81.5%''
	WHEN 26 THEN ''Urlop rodzicielski 81.5% (ustawa "Za życiem")''

	ELSE ''Nie dotyczy''
END [Nieobecność Przyczyna],
CASE PNB_Tryb 
	WHEN 0 THEN ''Podstawowa''
	WHEN 1 THEN ''Anulowana''
	WHEN 2 THEN ''Korygująca''
	ELSE ''Nie dotyczy''
END [Nieobecność Status],
CASE PNB_UrlopNaZadanie 
	WHEN 0 THEN ''NIE'' 
	WHEN 1 THEN ''TAK''
	ELSE ''Nie dotyczy''
END [Nieobecność Na Żądanie],
CASE WHEN SPR.DST_UwzglCzasPracy = 0 THEN NULL
	WHEN PNB_Calodzienna = 0 THEN DATEDIFF(MI,convert(datetime,''18991230''),PNB_Godz)  / 60.0
	WHEN PNB_Calodzienna = 1 AND COALESCE(PPL_TypDnia,KAD_TypDnia) <> 1 THEN NULL
	WHEN PNB_Calodzienna = 1 THEN NULLIF(CASE WHEN PGR_OdGodziny IS NULL
	THEN CASE WHEN PGL_OdGodziny IS NULL
			THEN 1.0*DATEDIFF(minute,KDG_OdGodziny,(CASE WHEN KDG_OdGodziny > KDG_DoGodziny THEN DATEADD(day,1,KDG_DoGodziny) ELSE KDG_DoGodziny END))/60
			ELSE 1.0*DATEDIFF(minute,PGL_OdGodziny,(CASE WHEN PGL_OdGodziny > PGL_DoGodziny THEN DATEADD(day,1,PGL_DoGodziny) ELSE PGL_DoGodziny END))/60
		END
	ELSE 1.0*DATEDIFF(minute,PGR_OdGodziny,(CASE WHEN PGR_OdGodziny > PGR_DoGodziny THEN DATEADD(day,1,PGR_DoGodziny) ELSE PGR_DoGodziny END))/60
	END,0)
	ELSE NULL
END /isnull(nullif(IloscStrefa,0),1) [Nieobecności w Godzinach],
CASE WHEN PNB_PnbId IS NULL THEN NULL
WHEN PNB_Calodzienna = 1 THEN 1.0
ELSE (1/(8*(Cast(PRE_ETAEtatL as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1))))*((datepart(MINUTE,PNB_Godz)/60.0) + (datepart(HOUR,PNB_Godz))) 
END /isnull(nullif(IloscKal,0),1) [Nieobecności w Dniach Kalendarzowych],
CASE WHEN PNB_PnbId IS NULL THEN NULL
WHEN SPR.DST_UwzglCzasPracy = 0 THEN NULL 
WHEN PNB_Calodzienna = 1 THEN 1.0
ELSE (1/(8*(Cast(PRE_ETAEtatL as decimal)/ISNULL(NULLIF(Pre_etaetatM,0),1))))*((datepart(MINUTE,PNB_Godz)/60.0) + (datepart(HOUR,PNB_Godz))) 
END /isnull(nullif(IloscStrefa,0),1) [Nieobecności w Dniach Pracy],
''Nie dotyczy'' [Limit Nieobecności Typ], 
''Nie dotyczy'' [Limit Nieobecności Od], ''Nie dotyczy'' [Limit Nieobecności Do],
REPLACE(CONVERT(VARCHAR(10), PNB_OkresOd, 111), ''/'', ''-'') [Nieobecność Od], REPLACE(CONVERT(VARCHAR(10), PNB_OkresDo, 111), ''/'', ''-'')  [Nieobecność Do],
NULL [Limit Nieobecności Należny Dni],
NULL [Limit Nieobecności Należny Godziny],
NULL [Limit Nieobecności Wykorzystany Dni],
NULL [Limit Nieobecności Wykorzystany Godziny],
NULL [Limit Nieobecności Pozostały Dni],
NULL [Limit Nieobecności Pozostały Godziny],
NULL [Limit Nieobecności Zaległy Dni],
NULL [Limit Nieobecności Zaległy Godziny],
NULL [Wypłata Wartość Netto], NULL [Suma Elementów Wypłaty], NULL [Wypłata Wynagrodzenie Zasadnicze],
NULL [Urlop Planowany Dni],
NULL [Urlop Wypoczynkowy Należny Dni],
NULL [Urlop Wypoczynkowy Pozostało Dni],
NULL [Przybliżona Rezerwa Urlopowa],
NULL  [Obowiązujący Limit Nieobecności Należny Dni ],
NULL [Obowiązujący Limit Nieobecności Należny Godziny],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Dni ],
NULL [Obowiązujący Limit Nieobecności Wykorzystany Godziny ], 
NULL  [Obowiązujący Limit Nieobecności Pozostały Dni ],
NULL [Obowiązujący Limit Nieobecności Pozostały Godziny ],
NULL  [Obowiązujący Limit Nieobecności Zaległy Dni ],
NULL [Obowiązujący  Limit Nieobecności Zaległy Godziny ],
NULL [Obowiązujący Urlop Planowany Dni ],
NULL [Obowiązujący  Urlop Wypoczynkowy Należny Dni ],
NULL[Obowiązujący  Urlop Wypoczynkowy Pozostało Dni ],
NULL [Obowiązujący Limit Przybliżona Rezerwa Urlopowa ],
NULL [Limit Nieobecności Należny Cały Okres Dni],
NULL [Limit Nieobecności Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Pozostały Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Należny Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Wykorzystany Cały Okres Dni],
NULL [Limit Nieobecności Urlop Wypoczynkowy Pozostały Cały Okres Dni],

PRE_Kod [Liczba Pracowników]
,DZPR.DZL_Kod AS [Pracownik Wydział]
,CASE rob.DKM_Robotnicze WHEN 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Stanowisko Robotnicze]
	 ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZat, 111), ''/'', ''-''),''(BRAK)'') END [Data Zatrudnienia Dzień]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Miesiąc]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZat) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZat)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Tydzień Roku] 
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZat) AS VARCHAR(10)),''(BRAK)'') END AS [Data Zatrudnienia Kwartał]
	  ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZat) AS VARCHAR(10)),''(BRAK)'') END [Data Zatrudnienia Rok] 
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(REPLACE(CONVERT(VARCHAR(10), PZZwol, 111), ''/'', ''-''),''(BRAK)'') END [Data Zwolnienia Dzień]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(MONTH(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Miesiąc]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST((datepart(DY, datediff(d, 0, PZZwol) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, PZZwol)*/ AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Tydzień Roku]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(DATEPART(quarter, PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Kwartał]
	  ,CASE WHEN PZZwol = convert(datetime,''29991231'',112) THEN ''Czas nieokreślony'' WHEN PZZwol = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE ISNULL(CAST(YEAR(PZZwol) AS VARCHAR(10)),''(BRAK)'') END [Data Zwolnienia Rok]
	 ,CASE WHEN PZZat = convert(datetime,''18991230'',112) THEN ''(BRAK)'' ELSE CASE WHEN PZZwol > GetDate() THEN CASE WHEN datediff(yy,PZZat,GetDate()) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,GetDate()) AS VARCHAR(10)),''(BRAK)'') END ELSE CASE WHEN datediff(yy,PZZat,PZZwol) = 0 THEN ''Poniżej roku'' ELSE ISNULL(CAST(datediff(yy,PZZat,PZZwol) AS VARCHAR(10)),''(BRAK)'') END END END [Pracownik Lata Pracy]
	  ,ISNULL(CAST (datediff(yy,PRE_DataUr,Data) AS VARCHAR(10)),''(BRAK)'') [Pracownik Wiek]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]

/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), Data, 111), ''/'', ''-'') [Data]
*/

----------DATY ANALIZY
,REPLACE(CONVERT(VARCHAR(10), Data, 111), ''/'', ''-'') [Data Dzień], MONTH(Data) [Data Miesiąc], YEAR(Data) [Data Rok]
,CASE when MONTH(Data) <7 THEN ''I'' else ''II'' END AS [Data Półrocze]
,DATEPART(quarter, Data) AS [Data Kwartał] 

----------KONTEKSTY
,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]
,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]

' + @kolumny + @atrybuty + '
FROM #Daty
	LEFT JOIN CDN.PracEtaty ON PRE_PreId = PreId
	LEFT JOIN #PracZat on PZPraId = PRE_PraID
	LEFT JOIN #Umowy ON UPraId = PraId AND UData = Data
	LEFT JOIN CDN.KalendDni ON Data = KAD_Data AND PRE_KalId = KAD_KalId
	LEFT JOIN CDN.Kalendarze ON KAD_KalId = KAL_KalId
	LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko =  sta.DKM_DkmId AND  sta.DKM_Rodzaj = 1
	LEFT JOIN CDN.PracPlanDni ON PPL_PraId = PRE_PraId AND PPL_Data = Data
	LEFT JOIN CDN.PracPracaDni ON PPR_PraId = PRE_PraId AND PPR_Data = Data
	LEFT JOIN CDN.KalendDniGodz ON KDG_KadId = KAD_KadId AND PPL_PplId IS NULL AND PPR_PprId IS NULL
	LEFT JOIN CDN.PracPlanDniGodz ON PPL_PplId = PGL_PplId AND PPR_PprId IS NULL
	LEFT JOIN CDN.PracPracaDniGodz ON PPR_PprId = PGR_PprId
	LEFT JOIN CDN.DefinicjeStref SPR ON COALESCE(PGR_Strefa,PGL_Strefa,KDG_Strefa) = SPR.DST_DstId
	LEFT JOIN CDN.Dzialy DPR ON COALESCE(PGR_DzlId,PGL_DzlId,KDG_DzlId) = DPR.DZL_DzlId 
	LEFT JOIN CDN.DefProjekty PPR ON COALESCE(PGR_PrjId,PGL_PrjId,KDG_PrjId) = PPR.PRJ_PrjId
	LEFT JOIN CDN.PracNieobec ON PNB_PraId = PRE_PraId AND Data >= PNB_OkresOd AND Data <= PNB_OkresDo AND PNB_Tryb <> 1
	LEFT JOIN CDN.TypNieobec ON PNB_TnbId = TNB_TnbId
	LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
	LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
	LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = PRE_ZakId
	LEFT JOIN CDN.PracKod on PRA_PraId = PRE_PraId
	LEFT JOIN cdn.DaneKadMod rob on PRE_ETADkmIdStanowisko = rob.DKM_DkmId
	LEFT JOIN cdn.Dzialy DZPR ON PRE_DzlId = DZPR.DZL_DzlId 
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON PRE_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON PRE_OpeModID = mod.Ope_OpeId
	LEFT JOIN #IloscPrzedzialowPracy  ON (PPRID = KAD_KadId AND PPL_PplId IS NULL AND PPR_PprId IS NULL AND PPRTYP = 1)or( PPL_PplId = PPRID AND PPR_PprId IS NULL and PPRTYP = 2 ) OR ( PPR_PprId = PPRID and PPRTYP = 3)
	WHERE ((Data <= PZZwol AND Data >= PZZat) OR UUmw > 0) 


	'

PRINT(@Select)
EXEC(@select)	


DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #Daty
DROP TABLE #Umowy
DROP TABLE #PracZat
DROP TABLE #Wyplaty
DROP TABLE #WszystkieDaty
DROP TABLE #AktualneLimity
DROP TABLE #Swieta
DROP TABLE #WszystkieDatyDo
DROP TABLE #WykorzystaneDoDnia
DROP TABLE #tmpmies
DROP TABLE #RzeczywisteObowiazywanieLimitow
DROP TABLE #IloscPrzedzialowPracy








