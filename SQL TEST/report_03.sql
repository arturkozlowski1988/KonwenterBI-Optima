/*
* Raport Sprzedaży Rok Do Roku 
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
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

--Wyliczanie poziomów grup produktów
;WITH g(gid, gidTyp, kod, gidNumer, grONumer, poziom, sciezka)
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
                SET ONr' + CAST(@poziom AS nvarchar) +  '= grONumer '
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
declare @kolumny varchar(max)
declare @kolumny2 varchar(max)
declare @kolumny3 varchar(max)
declare @i int

set @kolumny = ''
set @kolumny2 = ''
set @kolumny3 = ''
set @i=0
while (@i<=@poziom_max)
begin
    set @kolumny = @kolumny + ',"Produkt Grupa Poziom ' + LTRIM(@i) + '" = ISNULL(biezacy.Poziom' +LTRIM(@i) + ', ISNULL(poprzedni.Poziom' +LTRIM(@i) + ', ''(NIEPRZYPISANE)''))'
    set @kolumny2 = @kolumny2 + ',Poz.Poziom' +LTRIM(@i) 
    set @kolumny3 = @kolumny3 + ',Poz.Poziom' +LTRIM(@i) + ' as Poziom' + +LTRIM(@i)
    set @i = @i + 1
end;

--Właściwe Zapytanie
set @select = 
'with BU as
(
select 
SUM(TR.TrE_WartoscNetto) as Wartosc, SUM(TR.TrE_Ilosc) as Ilosc, YEAR(TRN.TrN_DataOpe)*100+ MONTH(TRN.TrN_DataOpe) as MR, Twr_TwrId as Produkt, Twr_Kod as Kod, Twr_Nazwa as Nazwa ' + @kolumny3 +
' from CDN.TraElem tr
JOIN CDN.TraNag trn on trn.TrN_TrNID=TR.TrE_TrNId
JOIN CDN.Towary ON TrE_TwrId=Twr_TwrId
LEFT OUTER JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = gidNumer
WHERE
(TrN_TypDokumentu=-1 OR CDN.TypSkojarzenia(TrN_TrNId)=302000 OR CDN.TypSkojarzenia(TrN_TrNId)=302306 OR CDN.TypSkojarzenia(TrN_TrNId)=305000 OR CDN.TypSkojarzenia(TrN_TrNId)=305302) 
AND TrN_Rodzaj NOT IN (302101,302102,302103)
AND TrN_Bufor<>-1
AND TR.TrE_Aktywny<>0
AND TR.TrE_UslugaZlozonaId = 0
group by  YEAR(TRN.TrN_DataOpe)*100+ MONTH(TRN.TrN_DataOpe), Twr_TwrId, Twr_Kod, Twr_Nazwa' + @kolumny2 +
') 
select 
"Baza Firmowa" = BAZ.Baz_Nazwa,
"Data Operacji Rok" = ISNULL(Miesiace.Rok, SUBSTRING(convert(varchar,poprzedni.MR+100), 0, 5)),
"Data Operacji Miesiąc" = ISNULL(Miesiace.Miesiac, SUBSTRING(convert(varchar,poprzedni.MR+100), 5,6)),
"Data Analizy" = GETDATE(),
"Sprzedaż Wartość Bieżący" = biezacy.Wartosc, "Sprzedaż Ilość Bieżący" = biezacy.Ilosc, "Sprzedaż Wartość Poprzedni" = poprzedni.Wartosc,   "Sprzedaż Ilość Poprzedni" = poprzedni.Ilosc, 
"Produkt Kod" = ISNULL(biezacy.Kod, ISNULL(poprzedni.Kod, ''(PUSTE)'')), 
"Produkt Nazwa" = ISNULL(biezacy.Nazwa, ISNULL(poprzedni.Nazwa, ''(PUSTE)''))
----------KONTEKSTY
,25003 [Produkt Kod __PROCID__Towary__], ISNULL(biezacy.Produkt,poprzedni.Produkt) [Produkt Kod __ORGID__], '''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
,25003 [Produkt Nazwa __PROCID__], ISNULL(biezacy.Produkt,poprzedni.Produkt) [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]'
+ @kolumny +
' from 
( 
    select 
            M.MR, SUBSTRING(convert(varchar,M.MR), 0, 5) as Rok, SUBSTRING(convert(varchar,M.MR), 5,6) as Miesiac
    from
            (
                select distinct YEAR(TR.TrN_DataOpe)*100+ MONTH(TR.TrN_DataOpe) as MR  from CDN.TraNag tr
                union
                select distinct YEAR(TR.TrN_DataOpe)*100+ MONTH(TR.TrN_DataOpe)+100 as MR  from CDN.Tranag tr
            )M
            
) as Miesiace
left outer join bu as biezacy on biezacy.MR=Miesiace.MR
full outer join bu as poprzedni on poprzedni.MR=Miesiace.MR-100 
                and isNull(biezacy.Produkt,1) = case when biezacy.Produkt is null then 1 else poprzedni.Produkt end
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0

'

exec(@select)

DROP TABLE #tmpTwrGr






