/*
* Raport Księgowości (ER) 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--Połączenie do tabeli stawek i operatorów
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Stawki varchar(max), @Stawki2 varchar(max), @Operatorzy varchar(max), @sql varchar(max);
DECLARE @Bazy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

SET @Stawki2 = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[CfgWartosci]'
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 

--Właściwe zapytanie
SET @sql =
'SELECT * INTO #tmpStawki FROM [' +
(SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001) + '].[' + 
(SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002) + '].[CDN].[CfgKlucze]

SELECT  BAZ.Baz_Nazwa [Baza Firmowa], 
    CASE 
     WHEN (MONTH(RYC_DataPrz) = MONTH(GETDATE())-1) AND (YEAR(RYC_DataPrz) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN ((MONTH(RYC_DataPrz) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(RYC_DataPrz) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Przychodu Miesiąc Poprzedni],
   CASE 
     WHEN (MONTH(RYC_DataPrz) = MONTH(GETDATE())) AND (YEAR(RYC_DataPrz) = YEAR(GETDATE())) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Przychodu Miesiąc Bieżący],

    CASE 
     WHEN (MONTH(RYC_DataWpi) = MONTH(GETDATE())-1) AND (YEAR(RYC_DataWpi) = YEAR(GETDATE())) THEN ''TAK'' 
     WHEN ((MONTH(RYC_DataWpi) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(RYC_DataWpi) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Wpisu Miesiąc Poprzedni],
   CASE 
     WHEN (MONTH(RYC_DataWpi) = MONTH(GETDATE())) AND (YEAR(RYC_DataWpi) = YEAR(GETDATE())) THEN ''TAK'' 
     ELSE ''NIE'' 
    END [Data Wpisu Miesiąc Bieżący],
    RYC_Dokument AS [Dokument Numer], 
    ISNULL(RYC_Kategoria , ''(NIEPRZYPISANY)'') [Kategoria Opis], CASE WHEN RYC_Bufor = 0  THEN ''Ewidencja'' ELSE ''Bufor'' END AS [Ewidencja/Bufor], 
    CASE WHEN Kategorie.Kat_KodSzczegol IS NULL THEN ''(PUSTA)'' ELSE Kategorie.Kat_KodSzczegol END AS [Kategoria Szczegółowa],
    CASE WHEN Kategorie.Kat_KodOgolny IS NULL THEN ''(PUSTA)'' ELSE Kategorie.Kat_KodOgolny END AS [Kategoria Ogólna],
    ISNULL(op1.Ope_Kod, ''(NIEPRZYPISANY)'') AS [Operator Wprowadzający], ISNULL(op2.Ope_Kod, ''(NIEPRZYPISANY)'') AS [Operator Modyfikujący],
    RYC_Przychod1 AS [Sprzedaż wg Stawki 3], RYC_Przychod2 AS [Sprzedaż wg Stawki 4], RYC_Przychod3 AS [Sprzedaż wg Stawki 5],
    RYC_Przychod4 AS [Sprzedaż wg Stawki 1], RYC_Przychod5 AS [Sprzedaż wg Stawki 2], RYC_Przychod6 AS [Sprzedaż wg Stawki 6],
    RYC_Przychod7 AS [Sprzedaż wg Stawki 7], RYC_Przychod8 AS [Sprzedaż wg Stawki 8], RYC_Przychod9 AS [Sprzedaż wg Stawki 9],
    RYC_Przychod10 AS [Sprzedaż wg Stawki 10], RYC_Przychod11 AS [Sprzedaż wg Stawki 11],
    RYC_Przychod1 + RYC_Przychod2 + RYC_Przychod3 + RYC_Przychod4 + RYC_Przychod5 + RYC_Przychod6 + RYC_Przychod7 + RYC_Przychod8 + RYC_Przychod9 + RYC_Przychod10 + RYC_Przychod11 AS [Przychód],
    (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 1'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 1 Wartości],
    (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 2'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 2 Wartości],
    (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 3'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 3 Wartości],
    (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 4'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 4 Wartości],            
    (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 5'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 5 Wartości],
    (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 6'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 6 Wartości],
        (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 7'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 7 Wartości],
        (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 8'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 8 Wartości],
        (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 9'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 9 Wartości],
        (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 10'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 10 Wartości],
        (SELECT CFW_Wartosc FROM #tmpStawki
         JOIN ' + @stawki2 + ' ON CFK_CfkId = CFW_CfkId 
     WHERE CFK_Nazwa = ''Ryczałt 11'' AND (RYC_DataPrz BETWEEN CFK_OkresOd AND (CFK_OkresDo - 1))) + ''%'' AS [Stawka 11 Wartości]  
     /*
     ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), RYC_DataPrz, 111), ''/'', ''-'') AS [Data Przychodu]
    ,REPLACE(CONVERT(VARCHAR(10), RYC_DataWpi, 111), ''/'', ''-'') AS [Data Wpisu]
    */
     ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), RYC_DataPrz, 111), ''/'', ''-'') AS [Data Przychodu Dzień], YEAR(RYC_DataPrz) AS [Data Przychodu Rok]
    ,DATEPART(quarter, RYC_DataPrz) AS [Data Przychodu Kwartał], MONTH(RYC_DataPrz) AS [Data Przychodu Miesiąc] 
    ,(datepart(DY, datediff(d, 0, RYC_DataPrz) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, RYC_DataPrz)*/ [Data Przychodu Tydzień Roku]   
    ,REPLACE(CONVERT(VARCHAR(10), RYC_DataWpi, 111), ''/'', ''-'') AS [Data Wpisu Dzień]
    ,YEAR(RYC_DataWpi) AS [Data Wpisu Rok],     DATEPART(quarter, RYC_DataWpi) AS [Data Wpisu Kwartał], MONTH(RYC_DataWpi) AS [Data Wpisu Miesiąc]
    ,(datepart(DY, datediff(d, 0, RYC_DataWpi) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, RYC_DataWpi)*/ [Data Wpisu Tydzień Roku]
    ,GETDATE() [Data Analizy]
FROM CDN.Ryczalt
    LEFT OUTER JOIN CDN.Kategorie Kategorie ON RYC_KatID = Kategorie.Kat_KatID
    LEFT JOIN ' + @Operatorzy + ' op1 ON RYC_OpeZalID = op1.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' op2 ON RYC_OpeModID = op2.Ope_OpeId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
WHERE
    RYC_Skreslony = 0

DROP TABLE #tmpStawki'

exec(@sql)








