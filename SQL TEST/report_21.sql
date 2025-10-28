/*
* Raport Wyników Ankiet 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

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
                SET ONr' + CAST(@poziom AS nvarchar) +  '= parId '
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
DECLARE @atrybut_id int, @atrybut_kod nvarchar(100), @atrybuty varchar(max), @sqlA nvarchar(max);

DECLARE atrybut_cursor CURSOR FOR
SELECT DISTINCT OAT_AtkId, REPLACE(OAT_NazwaKlasy, ']', '_')
FROM CDN.OAtrybuty
WHERE OAT_PrcId IS NOT NULL
AND OAT_AtkId IS NOT NULL;

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod;

SELECT DISTINCT OAT_PrcId INTO #tmpKonAtr FROM CDN.OAtrybuty

SET @atrybuty = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sqlA = N'ALTER TABLE #tmpKonAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpKonAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = ATR.ATH_Wartosc 
        FROM CDN.OAtrybutyHist ATR 
        JOIN CDN.OAtrybuty OA ON OA.OAT_OatId = ATR.ATH_OatId AND ATR.ATH_DataDo = (SELECT MAX(A1.ATH_DataDo) FROM CDN.OAtrybutyHist A1 WHERE A1.ATH_OatId = ATR.ATH_OatId)
        JOIN #tmpKonAtr TM ON OA.OAT_PrcId = TM.OAT_PrcId
        WHERE ATR.ATH_AtkId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Pracownik Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

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

-- zapytanie właściwe
SET @select =
' select 
 BAZ.Baz_Nazwa [Baza Firmowa],
 PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
 PRE_Kod [Pracownik Kod], 
 PRE_Plec as [Pracownik Płeć],
CASE WHEN Prc.PRI_Archiwalny = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Archiwalny],
CASE WHEN PRE_ETARodzajUmowy = '''' THEN ''(NIEPRZYPISANE)'' ELSE PRE_ETARodzajUmowy END [Rodzaj Umowy], 
CASE WHEN Prc.PRI_Typ = 1 THEN ''Pracownik'' ELSE ''Własciciel/Współpracownik'' END [Pracownik Typ],
    CASE 
        WHEN (SELECT SUM(PRI_Typ) FROM CDN.Pracidx WHERE PRE_PraId = PRI_PraId AND PRI_Typ > 2) = 10 THEN ''Etat''
        WHEN (SELECT SUM(PRI_Typ) FROM CDN.Pracidx WHERE PRE_PraId = PRI_PraId AND PRI_Typ > 2) = 20 THEN ''Umowa''
        WHEN (SELECT SUM(PRI_Typ) FROM CDN.Pracidx WHERE PRE_PraId = PRI_PraId AND PRI_Typ > 2) = 30 THEN ''Etat/Umowa''
        ELSE ''Bez Zatrudnienia'' END [Pracownik Typ Zatrudnienia], 
CASE WHEN sta.DKM_Nazwa IS NULL THEN ''(NIEPRZYPISANE)'' ELSE sta.DKM_Nazwa END [Pracownik Stanowisko], 
CNT_Kod as [Pracownik Centrum Kod] , 
CNT_Nazwa as [Pracownik Centrum Nazwa] , 
Kier.PRI_Kod as [Kierownik Kod],
Kier.PRI_Imie1 as [Kierownik Imię],
Kier.PRI_Nazwisko as [Kierownik Nazwisko],
A.SBL_Nazwa as [Ankieta Nazwa], 
SOB_Nazwa as [Ankieta Obszar Nazwa] ,
SSK_Nazwa as [Ankieta Skala Nagłówek],
NULL as [Ocena Pracownika Symbol],
NULL as [Ocena Kierownika Symbol],
--miary
SKF_SumaWag as [Ankieta Waga],
SAS_Nazwa as [Ankieta Sekcja], 
SAE_NazwaPozycji as [Ankieta Pytanie], 
SAE_Waga as [Ankieta Pytanie Waga],
SAE_Samoocena as [Ocena Pracownika Pozycji Ankiety Wartość] , 
case when SKF_SumaWag<>0 then (SAE_Samoocena*SAE_Waga)/SKF_SumaWag ELSE NULL END as [Ocena Pracownika Pozycji Ankiety] , 
(select SSE_Wartosc from [CDN].[EP_SzablonySkalaElem] where SSE_SkalaId = SN.SSK_Id and SSE_Waga = SAE_Samoocena) as [Ocena Pracownika Pozycji Symbol], 
SAE_OcenaKierownika as [Ocena Kierownika Pozycji Ankiety Wartość],
case when SKF_SumaWag<>0 then (SAE_OcenaKierownika*SAE_Waga)/SKF_SumaWag ELSE NULL END as [Ocena Kierownika Pozycji Ankiety] , 
(select SSE_Wartosc from [CDN].[EP_SzablonySkalaElem] where SSE_SkalaId = SN.SSK_Id and SSE_Waga = SAE_OcenaKierownika) as [Ocena Kierownika Pozycji Symbol], 
NULL as [Ocena Pracownika],
NULL as [Ocena Kierownika],
REPLACE(CONVERT(VARCHAR(10), POP_OkresOd, 111), ''/'', ''-'') as [Ankieta Za Okres OD],
REPLACE(CONVERT(VARCHAR(10), POP_OkresDo, 111), ''/'', ''-'') as [Ankieta Za Okres DO],
REPLACE(CONVERT(VARCHAR(10), POP_Termin, 111), ''/'', ''-'') as [Ankieta Termin Wykonania Dzień],
datepart(YEAR,POP_Termin) as [Ankieta Termin Wykonania Rok],
datepart(QUARTER, POP_Termin) as [Ankieta Termin Wykonania Kwartał],
datepart(MONTH, POP_Termin) as [Ankieta Termin Wykonania Miesiąc],
SAR_Id [Ankiety Ilość],
CASE WHEN POP_SamoocenaKompletna= 1 THEN SAR_Id ELSE NULL END [Ankiety Pracownik Ilość zatwierdzonych],
CASe WHEN POP_OcenaKierownikaKompletna= 1 THEN SAR_Id ELSE NULL END [Ankiety Kierownik Ilość zatwierdzonych],
case POP_StatusKierownik 
 when 0 then ''przypisane arkusze''
 when 1 then ''zatwierdzone przez przełożonego''
 when 2 then ''do zatwierdzenia''
 when 3 then ''zamknięte''
end as [Ankiety Kierownik Status],
case POP_StatusPracownik 
 when 0 then ''przypisane arkusze''
 when 1 then ''zatwierdzone przez podwladnego''
 when 2 then ''do zatwierdzenia''
 when 3 then ''zamknięte''
end as [Ankiety Pracownik Status]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]
,GETDATE() [Data Analizy]
----------KONTEKSTY
,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]
,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]

' + @kolumny + @atrybuty + '
from  
[CDN].[EP_PracOcenaPracownicza]
join [CDN].[Pracidx] Prc on POP_PrcId = Prc.PRI_PraId and Prc.PRI_Typ in (1,2)
join [CDN].[PracEtaty] on PRE_PraId = Prc.PRI_PraId and year(pre_datado) = 2999
LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko = sta.DKM_DkmId AND sta.DKM_Rodzaj = 1
join [CDN].[Centra] on  CNT_CntId = PRE_CntId
join [CDN].[CentraKierownicy] on  CNK_CntId = PRE_CntId
join [CDN].[Pracidx] as Kier on CNK_PraId = Kier.PRI_PraId and Kier.PRI_Typ in (1,2)
left outer join [CDN].[EP_PrcOcenaPracowniczaWagi] on OPW_PrcId = Prc.PRI_PraId
join [CDN].[EP_Szablony] as A on SBL_Id = POP_SzablonId
join [CDN].[EP_SzablonyObszar] on sbl_obszarid = SOB_Id
join [CDN].[EP_SzablonyKonfiguracja] on SKF_SzablonId = SBL_Id
join [CDN].[EP_SzablonySkalaNag] SN on SN.SSK_Id = SKF_SkalaId
join [CDN].[EP_SzablonyArkusze] on SAR_SzablonId = SBL_Id
join [CDN].[EP_SzablonyArkuszeSekcje] on SAS_ArkuszId = SAR_Id
join [CDN].[EP_SzablonyArkuszeSekcjeElem] on sae_sekcjaid = SAS_Id
    LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
    LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON PRE_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON PRE_OpeModID = mod.Ope_OpeId

union all -- ocena ankiety

 select 
 BAZ.Baz_Nazwa [Baza Firmowa],
 PRE_Nazwisko + '' '' + PRE_Imie1 [Pracownik Nazwa], 
 PRE_Kod [Pracownik Kod], 
PRE_Plec as [Pracownik Płeć],
CASE WHEN Prc.PRI_Archiwalny = 1 THEN ''Tak'' ELSE ''Nie'' END [Pracownik Archiwalny],
CASE WHEN PRE_ETARodzajUmowy = '''' THEN ''(NIEPRZYPISANE)'' ELSE PRE_ETARodzajUmowy END [Rodzaj Umowy], 
CASE WHEN Prc.PRI_Typ = 1 THEN ''Pracownik'' ELSE ''Własciciel/Współpracownik'' END [Pracownik Typ],
    CASE 
        WHEN (SELECT SUM(PRI_Typ) FROM CDN.Pracidx WHERE PRE_PraId = PRI_PraId AND PRI_Typ > 2) = 10 THEN ''Etat''
        WHEN (SELECT SUM(PRI_Typ) FROM CDN.Pracidx WHERE PRE_PraId = PRI_PraId AND PRI_Typ > 2) = 20 THEN ''Umowa''
        WHEN (SELECT SUM(PRI_Typ) FROM CDN.Pracidx WHERE PRE_PraId = PRI_PraId AND PRI_Typ > 2) = 30 THEN ''Etat/Umowa''
        ELSE ''Bez Zatrudnienia'' END [Pracownik Typ Zatrudnienia], 
CASE WHEN sta.DKM_Nazwa IS NULL THEN ''(NIEPRZYPISANE)'' ELSE sta.DKM_Nazwa END [Pracownik Stanowisko], 
CNT_Kod as [Pracownik Centrum Kod] , 
CNT_Nazwa as [Pracownik Centrum Nazwa] , 
Kier.PRI_Kod as [Kierownik Kod],
Kier.PRI_Imie1 as [Kierownik Imię],
Kier.PRI_Nazwisko as [Kierownik Nazwisko],
A.SBL_Nazwa as [Ankieta Nazwa], 
SOB_Nazwa as [Ankieta Obszar Nazwa] ,
SSK_Nazwa as [Ankieta Skala Nagłówek],
POP_SamoocenaSlownie as [Ocena Pracownika Symbol],
POP_OcenaKierownikaSlownie as [Ocena Kierownika Symbol],
--miary
SKF_SumaWag as [Ankieta Waga],
'' Ocena ankiety'' [Ankieta Sekcja], 
NULL as [Ankieta Pytanie], 
NULL as [Ankieta Pytanie Waga],
NULL as [Ocena Pracownika Pozycji Ankiety Wartość] , 
NULL as [Ocena Pracownika Pozycji Ankiety] , 
NULL as [Ocena Pracownika Pozycji Symbol], 
NULL as [Ocena Kierownika Pozycji Ankiety Wartość],
NULL as [Ocena Kierownika Pozycji Ankiety] , 
NULL as [Ocena Kierownika Pozycji Symbol], 
POP_Samoocena as [Ocena Pracownika],
POP_OcenaKierownika as [Ocena Kierownika],
REPLACE(CONVERT(VARCHAR(10), POP_OkresOd, 111), ''/'', ''-'') as [Ankieta Za Okres OD],
REPLACE(CONVERT(VARCHAR(10), POP_OkresDo, 111), ''/'', ''-'') as [Ankieta Za Okres DO],
REPLACE(CONVERT(VARCHAR(10), POP_Termin, 111), ''/'', ''-'') as [Ankieta Termin Wykonania Dzień],
datepart(YEAR,POP_Termin) as [Ankieta Termin Wykonania Rok],
datepart(QUARTER, POP_Termin) as [Ankieta Termin Wykonania Kwartał],
datepart(MONTH, POP_Termin) as [Ankieta Termin Wykonania Miesiąć],
NULL [Ankiety Ilość],
NULL [Ankiety Pracownik Ilość zatwierdzonych],
NULL [Ankiety Kierownik Ilość zatwierdzonych],
case POP_StatusKierownik 
 when 0 then ''przypisane arkusze''
 when 1 then ''zatwierdzone przez przełożonego''
 when 2 then ''do zatwierdzenia''
 when 3 then ''zamknięte''
end as [Ankiety Kierownik Status],
case POP_StatusPracownik 
 when 0 then ''przypisane arkusze''
 when 1 then ''zatwierdzone przez podwladnego''
 when 2 then ''do zatwierdzenia''
 when 3 then ''zamknięte''
end as [Ankiety Pracownik Status]
,zal.Ope_Kod [Operator Wprowadzający] 
,mod.Ope_Kod [Operator Modyfikujący]
,GETDATE() [Data Analizy]
----------KONTEKSTY
,24001 [Pracownik Nazwa __PROCID__], PRE_PraId [Pracownik Nazwa __ORGID__],'''+@bazaFirmowa+''' [Pracownik Nazwa __DATABASE__]
,24001 [Pracownik Kod __PROCID__Pracownicy__], PRE_PraId [Pracownik Kod __ORGID__],'''+@bazaFirmowa+''' [Pracownik Kod __DATABASE__]

' + @kolumny + @atrybuty + '
from  
[CDN].[EP_PracOcenaPracownicza]
join [CDN].[Pracidx] Prc on POP_PrcId = Prc.PRI_PraId and Prc.PRI_Typ in (1,2)
join [CDN].[PracEtaty] on PRE_PraId = Prc.PRI_PraId and year(pre_datado) = 2999
LEFT JOIN CDN.DaneKadMod sta ON PRE_ETADkmIdStanowisko = sta.DKM_DkmId AND sta.DKM_Rodzaj = 1
join [CDN].[Centra] on  CNT_CntId = PRE_CntId
join [CDN].[CentraKierownicy] on  CNK_CntId = PRE_CntId
join [CDN].[Pracidx] as Kier on CNK_PraId = Kier.PRI_PraId and Kier.PRI_Typ in (1,2)
left outer join [CDN].[EP_PrcOcenaPracowniczaWagi] on OPW_PrcId = Prc.PRI_PraId
join [CDN].[EP_Szablony] as A on SBL_Id = POP_SzablonId
join [CDN].[EP_SzablonyObszar] on sbl_obszarid = SOB_Id
join [CDN].[EP_SzablonyKonfiguracja] on SKF_SzablonId = SBL_Id
join [CDN].[EP_SzablonySkalaNag] SN on SN.SSK_Id = SKF_SkalaId
LEFT JOIN #tmpTwrGr Poz ON PRE_DzlId = Poz.gid
LEFT JOIN #tmpKonAtr KonAtr ON PRE_PraId = OAT_PrcId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON PRE_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON PRE_OpeModID = mod.Ope_OpeId
'

PRINT(@Select)
EXEC(@select)   

DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr




