/*
* Raport Analiza PZ z wydaniami towaru 
* Wersja raportu: 37.0
* Wersja baz OPTIMY: 2025.3000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--Wyliczanie poziomów grup produktów
WITH g(gid, gidTyp, kod, gidNumer, grONumer, poziom, sciezka)
AS
(
      SELECT TwG_TwGID, TwG_GIDTyp, TwG_Kod, TwG_GIDNumer, TwG_GrONumer, 0 as poziom, convert(nvarchar(1024), '') as sciezka
      FROM CDN.TwrGrupy
      WHERE TwG_TwGID = 0
      
      UNION ALL
      
      SELECT TwG_TwGID, TwG_GIDTyp, TwG_Kod, TwG_GIDNumer, TwG_GrONumer, p.poziom + 1 as poziom, convert(nvarchar(1024), p.sciezka + N'\' + c.TwG_Kod) as sciezka
      FROM g p
      JOIN CDN.TwrGrupy c
      ON c.TwG_GrONumer = p.gidNumer 
      WHERE c.TwG_TwGID <> 0 AND c.TwG_GIDTyp = -16
)     

SELECT * INTO #tmpTwrGr FROM g

DECLARE @poziom int
DECLARE @poziom_max int
DECLARE @sql nvarchar(max)
SELECT @poziom_max = MAX(poziom) FROM #tmpTwrGr
SET @poziom = @poziom_max
SET @sql = N''

WHILE @poziom >= 0  
BEGIN
    SET @sql = N'ALTER TABLE #tmpTwrGr ADD Poziom' + CAST(@poziom AS nvarchar) + N' nvarchar(50), ONr' + CAST(@poziom AS nvarchar) + N' nvarchar(50)'
    EXEC(@sql)
    
    IF @poziom = @poziom_max 
        BEGIN
            SET @sql = N'UPDATE #tmpTwrGr
                SET ONr' + CAST(@poziom AS nvarchar) +  '= grONumer '
            EXEC(@sql)
            
            SET @sql = N'UPDATE #tmpTwrGr
                SET Poziom' + CAST(@poziom AS nvarchar) + ' = kod'
            EXEC(@sql)
        END
    ELSE
        BEGIN 
            SET @sql = N'UPDATE c
                SET c.Poziom' + CAST(@poziom AS nvarchar) + N' = (
                    CASE WHEN c.poziom <=' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.kod AS nvarchar)
                    ELSE CAST(p.kod AS nvarchar) END)  
                FROM #tmpTwrGr c
                LEFT JOIN #tmpTwrGr p
                ON c.ONr' + CAST(@poziom + 1 AS nvarchar) + '= p.gidNumer '
            EXEC(@sql)
    
            SET @sql = N'UPDATE c
                SET c.ONr' + CAST(@poziom AS nvarchar) + N' = (
                    CASE WHEN c.poziom <=' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.grONumer AS nvarchar)
                    ELSE CAST(p.grONumer AS nvarchar) END)  
                FROM #tmpTwrGr c
                LEFT JOIN #tmpTwrGr p
                ON c.ONr' + CAST(@poziom + 1 AS nvarchar) + '= p.gidNumer '
                EXEC(@sql)
        END
    SET @poziom = @poziom - 1
END     

declare @select varchar(max)
declare @select2 varchar(max)
declare @select3 varchar(max)
declare @kolumny varchar(max)
declare @i int

set @kolumny = ''
set @i=0
while (@i<=@poziom_max)
begin
    set @kolumny = @kolumny + ',"Produkt Grupa Poziom ' + LTRIM(@i) + '" = CASE WHEN Poz.Poziom' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' + LTRIM(@i) + ' END'
    set @i = @i + 1
end

--Wyliczanie Atrybutów Towarów
DECLARE @atrybut_id int, @atrybut_kod nvarchar(50), @atrybut_typ int, @atrybut_format int, @atrybuty varchar(max), @sqlA nvarchar(max);
DECLARE @atrybutyTwr varchar(max), @atrybutyTwr2 varchar(max);
DECLARE @wersja float;
SET @wersja = (SELECT CONVERT(float, SYS_Wartosc) FROM CDN.SystemCDN WHERE SYS_ID = 3)

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT TwA_DeAid FROM CDN.TwrAtrybuty WHERE TwA_TwrId IS NOT NULL)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT TwA_TwrId INTO #tmpTwrAtr FROM CDN.TwrAtrybuty

SET @atrybutyTwr = ''
SET @atrybutyTwr2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
    IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
    SET @sqlA = N'ALTER TABLE #tmpTwrAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpTwrAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TwA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TwA_WartoscTxt,'','',''.'') ELSE ATR.TwA_WartoscTxt END 
        END  
        FROM CDN.TwrAtrybuty ATR 
        JOIN #tmpTwrAtr TM ON ATR.TwA_TwrId = TM.TwA_TwrId 
        WHERE ATR.TwA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    SET @atrybutyTwr2 = @atrybutyTwr2 + N', ''(NIEPRZYPISANE)'' [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Połączenie do bazy firmowej
DECLARE @bazaFirmowa varchar(max);
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Bazy varchar(max);
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

--Właściwe zapytanie
set @select = 
'
SELECT
BAZ.Baz_Nazwa [Baza Firmowa]
,pz.trn_numerpelny [PZ Numer]
,twr_kod [Produkt Kod]
,twr_nazwa [Produkt Nazwa]
,pzs.trs_ilosc/(case wzile when 0 then 1 else isnull(wzile,1) end) [PZ Ilość]
,pzs.trs_wartosc/(case wzile when 0 then 1 else isnull(wzile,1) end) [PZ Wartość]
,pzs.TrS_TrSIdDost [Dostawa]
,Mag_Symbol [Magazyn Kod]
,Mag_Nazwa [Magazyn Nazwa]
,wznumer [WZ Numer]
,wzilosc [WZ Ilość]
,wzwartosc [WZ Wartość],
CASE WHEN (MONTH(PZ.TrN_DataOpe) = MONTH(GETDATE())) AND (YEAR(PZ.TrN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' ELSE ''NIE'' END [WZ Czas Aktualny Miesiąc],
    CASE 
        WHEN (MONTH(PZ.TrN_DataOpe) = MONTH(GETDATE())-1) AND (YEAR(PZ.TrN_DataOpe) = YEAR(GETDATE())) THEN ''TAK'' 
        WHEN ((MONTH(PZ.TrN_DataOpe) = 12) AND (MONTH(GETDATE()) = 1)) AND (YEAR(PZ.TrN_DataOpe) = YEAR(GETDATE()) - 1) THEN ''TAK'' 
        ELSE ''NIE'' 
    END [WZ Czas Aktualny Miesiąc Poprzedni]
/*
----------DATY POINT
,CONVERT(VARCHAR(10),wzddok,120) [WZ Data Dokumentu]
,CONVERT(VARCHAR(10),wzdope,120) [WZ Data Operacji]
,CONVERT(VARCHAR(10),pz.TrN_DataDok,120) [PZ Data Dokumentu]
,CONVERT(VARCHAR(10),pz.TrN_DataOpe,120) [PZ Data Operacji]
*/
----------DATY ANALIZY
,YEAR(wzddok) [WZ Data Dokumentu Rok]
,MONTH(wzddok) [WZ Data Dokumentu Miesiąc]
,CONVERT(VARCHAR(10),wzddok,120) [WZ Data Dokumentu Dzień]
,YEAR(wzdope) [WZ Data Operacji Rok]
,MONTH(wzdope) [WZ Data Operacji Miesiąc]
,CONVERT(VARCHAR(10),wzdope,120) [WZ Data Operacji Dzień]
,YEAR(pz.TrN_DataDok) [PZ Data Dokumentu Rok]
,MONTH(pz.TrN_DataDok) [PZ Data Dokumentu Miesiąc]
,CONVERT(VARCHAR(10),pz.TrN_DataDok,120) [PZ Data Dokumentu Dzień]
,YEAR(pz.TrN_DataOpe) [PZ Data Operacji Rok]
,MONTH(pz.TrN_DataOpe) [PZ Data Operacji Miesiąc]
,CONVERT(VARCHAR(10),pz.TrN_DataOpe,120) [PZ Data Operacji Dzień]
,Datediff(dd,pz.TrN_DataOpe,wzdope)+1 [Dni na Magazynie]

----------KONTEKSTY
,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
,29056 [Magazyn Nazwa __PROCID__Magazyny__], Mag_MagId [Magazyn Nazwa __ORGID__],'''+@bazaFirmowa+''' [Magazyn Nazwa __DATABASE__]
,29056 [Magazyn Kod __PROCID__Magazyny__], Mag_MagId [Magazyn Kod __ORGID__],'''+@bazaFirmowa+''' [Magazyn Kod __DATABASE__]
'
+ @kolumny + @atrybutyTwr + '
from cdn.tranag pz --dokumenty PZ
left join cdn.traelem pze on pze.tre_trnid = pz.trn_trnid
left join cdn.traselem pzs on pzs.trs_treid = pze.tre_treid
left join --join do WZ
(
select wz.trn_numerpelny wznumer, wze.TrE_TwrKod wzkod, wzs.trs_ilosc wzilosc, wzs.trs_wartosc wzwartosc, wzs.TrS_TrSIdDost wzdost, wz.trn_datadok wzddok, wz.trn_dataope wzdope from cdn.tranag wz
left join cdn.traelem wze on wze.tre_trnid = wz.trn_trnid
left join cdn.traselem wzs on wzs.trs_treid = wze.tre_treid
where wz.TrN_TypDokumentu = 306
) dost on dost.wzdost = pzs.TrS_TrSIdDost

left join --join do ilości WZ spiętych dostawami z PZ
(
select pz.TrN_TrNID wzid, pze.TrE_TwrId wztwrid, count(wznumer) wzile from cdn.tranag pz
left join cdn.traelem pze on pze.tre_trnid = pz.trn_trnid
left join cdn.traselem pzs on pzs.trs_treid = pze.tre_treid
left join
(
select wz.trn_numerpelny wznumer, wze.TrE_TwrKod wzkod, wzs.trs_ilosc wzilosc, wzs.trs_wartosc wzwartosc, wzs.TrS_TrSIdDost wzdost from cdn.tranag wz
left join cdn.traelem wze on wze.tre_trnid = wz.trn_trnid
left join cdn.traselem wzs on wzs.trs_treid = wze.tre_treid
where wz.TrN_TypDokumentu = 306
) dost on dost.wzdost = pzs.TrS_TrSIdDost
group by pz.TrN_TrNID, pze.TrE_TwrId 

) x on wzid = pz.trn_trnid and wztwrid = pze.TrE_TwrId
left join cdn.magazyny on pzs.TrS_MagId = mag_magid
left join cdn.towary on Twr_TwrId = pze.tre_twrid

LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
LEFT JOIN #tmpTwrAtr TwrAtr ON TrE_TwrId  = TwrAtr.TwA_TwrId 
LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
where pz.TrN_TypDokumentu = 307 and pz.TrN_ZwrId is null

'
exec(@select)

DROP TABLE #tmpTwrGr
DROP TABLE #tmpTwrAtr









