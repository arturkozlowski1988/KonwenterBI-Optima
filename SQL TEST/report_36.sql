/*
* Raport Struktury Zatrudnienia
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

CREATE TABLE #daty
(dzien DATE
);
DECLARE @dzien DATETIME;
SET @dzien = @DataOd;
WHILE @dzien <= @DataDo
    BEGIN
        INSERT INTO #daty(dzien)
               SELECT @dzien;
        SET @dzien = @dzien + 1;
    END;

DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Bazy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

DECLARE @bazaFirmowa VARCHAR(MAX);
SET @bazaFirmowa =
(
    SELECT SYS_Wartosc
    FROM CDN.SystemCDN
    WHERE SYS_ID = 1
);

SELECT PID,MIN(DataOstatnia) AS DataOstatnia,SUM(iloscUmow) as iloscUmow    into #tempPrzedluzenia from(
 SELECT 
 PRE_Praid AS PID,
 count(pre_praid) AS iloscUmow,
 CASE WHEN PRE_ZatrudnionyDo = '2999-12-31 00:00:00.000' THEN  MIN(PRE_ZatrudnionyDo)
 ELSE 
 MAX(PRE_ZatrudnionyDo)end AS DataOstatnia

 FROM cdn.pracetaty
group by  PRE_Praid,PRE_ZatrudnionyDo
)x GROUP BY PID

SELECT ZatrudnionyOd,ZatrudnionyDo,Praid, Dzien data INTO #temp FROM (select PRE_ZatrudnionyOd ZatrudnionyOd,MAX(PRE_ZatrudnionyDo) ZatrudnionyDo ,PRE_PraId Praid  from CDN.pracetaty  
WHERE PRE_ZatrudnionyOd IS NOT NULL 
AND PRE_ZatrudnionyOd <> '1899-12-30 00:00:00.000' 
and PRE_ZatrudnionyDo IS NOT NULL 
GROUP BY PRE_PraId,PRE_ZatrudnionyOd 
)X JOIN #daty ON ZatrudnionyOd = dzien OR ZatrudnionyDo = dzien


DECLARE @select varchar(max)
SET @select = 
'

SELECT  
--WYMIARY
BAZ.Baz_Nazwa [Baza Firmowa] 
/*
----------DATY POINT
,REPLACE(CONVERT(VARCHAR(10), dzien, 111), ''/'', ''-'') [Data Dzień]
*/
---------DATY ANALIZY
,YEAR(dzien) [Data Rok]
,CASE when MONTH(dzien) <7 THEN ''I'' else ''II'' END AS [Data Półrocze]
,DATEPART(quarter, dzien) AS [Data Kwartał] 
,MONTH(dzien) [Data Miesiąc]
,REPLACE(CONVERT(VARCHAR(10), dzien, 111), ''/'', ''-'') [Data Dzień]

,CONVERT(NVARCHAR, dzien, 112) AS [Dzień Miara], 
CASE WHEN  dzien = Data AND dzien = Cast(ZatrudnionyOd as date)  THEN 1 ELSE 0 end AS [Pracownik Zatrudnienie],
CASE WHEN  dzien = Data AND dzien = Cast(zatrudnionyDo as date) THEN 1 ELSE 0 end AS [Pracownik Zwolnienie],
CASE WHEN iloscUmow > 1 and PRE_ETARodzajUmowy = ''na okres próbny'' AND CAST(PRE_DataDo AS DATE) = dzien THEN 1 else 0 END AS [Pracownik Umowa Próbna Przedłużenie],
BAZ.Baz_Nazwa+'':''+PRE_Kod [Liczba Pracowników],
CASE
    WHEN PRE_ETARodzajUmowy = ''''
    THEN ''(NIEPRZYPISANE)''
    ELSE PRE_ETARodzajUmowy
END [Rodzaj Umowy],
CASE
    WHEN sta.DKM_Nazwa IS NULL
    THEN ''(NIEPRZYPISANE)''
    ELSE sta.DKM_Nazwa
END [Pracownik Stanowisko], 
CNT_Kod [Centrum Kod], 
CNT_Nazwa [Centrum Nazwa],


CASE
    WHEN PRE_ZatrudnionyDo = CONVERT(DATETIME, ''29991231'', 112)
    THEN DATEDIFF(d, PRE_ZatrudnionyOd, GETDATE()) + 1
    ELSE DATEDIFF(d, PRE_ZatrudnionyOd, PRE_ZatrudnionyDo) + 1
END [Okres Zatrudnienia], 
PRE_Kod [Pracownik Kod],
CASE
    WHEN
(
    SELECT SUM(PRI_Typ)
    FROM CDN.Pracidx
    WHERE PRE_PraId = PRI_PraId
          AND PRI_Typ > 2
) = 10
    THEN ''Etat''
    WHEN
(
    SELECT SUM(PRI_Typ)
    FROM CDN.Pracidx
    WHERE PRE_PraId = PRI_PraId
          AND PRI_Typ > 2
) = 20
    THEN ''Umowa''
    WHEN
(
    SELECT SUM(PRI_Typ)
    FROM CDN.Pracidx
    WHERE PRE_PraId = PRI_PraId
          AND PRI_Typ > 2
) = 30
    THEN ''Etat/Umowa''
    ELSE ''Bez Zatrudnienia''
END [Typ Zatrudnienia],
CASE PRE_KodWyksztal
    WHEN ''11''
    THEN ''Wykształcenie niepełne podstawowe''
    WHEN ''12''
    THEN ''Wykształcenie podstawowe ukończone''
    WHEN ''20''
    THEN ''Wykształcenie zasadnicze zawodowe''
    WHEN ''31''
    THEN ''Wykształcenie średnie zawodowe/techniczne''
    WHEN ''32''
    THEN ''Wykształcenie średnie ogólnokształcące''
    WHEN ''40''
    THEN ''Wykształcenie policealne''
    WHEN ''50''
    THEN ''Wykształcenie wyższe (w tym licencjat)''
    ELSE ''Brak danych''
END [Pracownik Wykształcenie],
CASE
    WHEN pr1.PRI_Typ = 1
    THEN ''Pracownik''
    ELSE ''Własciciel/Współpracownik''
END [Pracownik Typ], 
PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa],
--MIARY
CASE
    WHEN((pre_ubztyuid >= 110
          AND pre_ubztyuid <= 200
          AND (pre_ubztyuid <> 120
               AND pre_ubztyuid <> 121
               AND pre_ubztyuid <> 122
               AND pre_ubztyuid <> 123))
         OR pre_ubztyuid = 80000)
    THEN CASE
             WHEN ISNULL(pra_parentid, 0) = 0
             THEN 1
             ELSE 0
         END
    ELSE NULL
END AS [Osoby Pracownicy],
CASE
    WHEN(pre_ubztyuid >= 510
         AND pre_ubztyuid <= 600)
    THEN CASE
             WHEN ISNULL(pra_parentid, 0) = 0
             THEN 1
             ELSE 0
         END
    ELSE NULL
END AS [Osoby Właściciele],
CASE
    WHEN(PRE_ETARODZAJZATRUDNIENIA IN(4, 7))
    THEN CASE
             WHEN ISNULL(pra_parentid, 0) = 0
             THEN 1
             ELSE 0
         END
    ELSE NULL
END AS [Osoby Uczniowie 1 kl],
CASE
    WHEN(PRE_ETARODZAJZATRUDNIENIA IN(5))
    THEN CASE
             WHEN ISNULL(pra_parentid, 0) = 0
             THEN 1
             ELSE 0
         END
    ELSE NULL
END AS [Osoby Uczniowie 2 kl],
CASE
    WHEN(PRE_ETARODZAJZATRUDNIENIA IN(6))
    THEN CASE
             WHEN ISNULL(pra_parentid, 0) = 0
             THEN 1
             ELSE 0
         END
    ELSE NULL
END AS [Osoby Uczniowie 3 kl], 
SUM(CAST(CASE
             WHEN pre_ubztyuid >    = 510
                  AND pre_ubztyuid <= 600
             THEN 1
             ELSE 0
         END AS DECIMAL) / CAST(CASE
                                    WHEN pre_ubztyuid >= 510
                                         AND pre_ubztyuid <= 600
                                    THEN 1
                                    ELSE 1
                                END AS DECIMAL)) AS [Etaty Właściciele], 
SUM(CAST(CASE
             WHEN((pre_ubztyuid >    = 110
                   AND pre_ubztyuid <= 200)
                  OR pre_ubztyuid = 80000)
                 AND (PRE_ETARODZAJZATRUDNIENIA NOT IN(4, 5, 6, 7))
             THEN pre_etaetatl
             ELSE 0
         END AS DECIMAL) / CAST(CASE
                                    WHEN((pre_ubztyuid >= 110
                                          AND pre_ubztyuid <= 200)
                                         OR pre_ubztyuid = 80000)
                                        AND (PRE_ETARODZAJZATRUDNIENIA NOT IN(4, 5, 6, 7))
                                    THEN pre_etaetatm
                                    ELSE 1
                                END AS DECIMAL)) AS [Etaty Pracownicy], 
SUM(CAST(CASE
             WHEN PRE_ETARODZAJZATRUDNIENIA IN(4, 5, 6, 7)
             THEN pre_etaetatl
             ELSE 0
         END AS DECIMAL) / CAST(CASE
                                    WHEN PRE_ETARODZAJZATRUDNIENIA IN(4, 5, 6, 7)
                                    THEN pre_etaetatm
                                    ELSE 1
                                END AS DECIMAL)) AS [Etaty Uczniowie], 
Wyplata [Suma Elementów Wypłaty],
  DZL_Nazwa AS [Wydział Nazwa],
  DZL_Kod AS [Wydział Kod]
FROM #daty
     JOIN cdn.pracetaty ON dzien between PRE_DataOd and PRE_DataDo
	 --AND dzien between PRE_ZatrudnionyOd and PRE_ZatrudnionyDo
	 
	 --PRE_DataOd <= dzien
  --                         AND (PRE_DataDo IS NULL
  --                              OR PRE_DataDo >= dzien)
  --                         AND PRE_ZatrudnionyOd <= dzien
  --                         AND (PRE_ZatrudnionyDo IS NULL
  --                              OR PRE_ZatrudnionyDo >= dzien)
     JOIN cdn.prackod ON pra_praid = pre_praid
                         AND PRA_Archiwalny = 0
     JOIN CDN.Pracidx pr1 ON PRE_PraId = pr1.PRI_PraId
                             AND pr1.PRI_Typ < 10
     LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko = sta.DKM_DkmId
                                     AND sta.DKM_Rodzaj = 1
     LEFT OUTER JOIN CDN.Zaklady ZakPracownik ON ZakPracownik.ZAK_ZAkID = PRE_ZakId
     LEFT JOIN CDN.Centra ON CNT_CntId = PRE_CntId
     LEFT JOIN  CDN.Dzialy on PRE_DzlId = DZL_DzlId 
     LEFT JOIN #tempPrzedluzenia tp ON tp.PID=PRE_praid
     LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
	 LEFT JOIN #temp tep on data = dzien and pre_praid = praid  and (dzien = zatrudnionyOd OR dzien = ZatrudnionyDo)

	 LEFT JOIN (select SUM(WPE_Wartosc) Wyplata,WPL_DataDok,Wpl_Praid from cdn.Wyplaty JOIN  cdn.WypElementy ON WPE_WplId = WPL_WplId Group by Wpl_Praid,WPL_DataDok)WPL 
	 ON PRE_praid = WPL_Praid and dzien = WPL_DataDok

GROUP BY BAZ.Baz_Nazwa,
         pre_ubztyuid, 
         dzien, 
		 [data],
         PRE_ETARodzajZatrudnienia, 
         PRE_ETARodzajUmowy, 
         DKM_Nazwa, 
         CNT_Kod, 
         CNT_Nazwa, 
         PRE_ZatrudnionyOd, 
         PRE_ZatrudnionyDo, 
         PRE_Kod, 
         PRE_PraId, 
         PRE_KodWyksztal, 
         PRI_Typ, 
         PRE_Nazwisko, 
         PRE_Imie1, 
         PRA_ParentId, 
         PRA_PraId, 
         PRA_Nadrzedny,
         DZL_Kod,
         DZL_Nazwa,
         DataOstatnia,
         iloscUmow,
         PRE_DataDo,
		 ZatrudnionyOd,
		 Zatrudnionydo,
		 PRAID,Wyplata
		

'

EXEC (@select)
DROP TABLE #daty
DROP TABLE #tempPrzedluzenia
DROP TABLE #temp

