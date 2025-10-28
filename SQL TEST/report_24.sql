/*
* Raport Zakupów z Opisami Analitycznymi
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.1.0
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
declare @i int

set @kolumny = ''
set @i=0
while (@i<=@poziom_max)
begin
    set @kolumny = @kolumny + ',"Produkt Grupa Poziom ' + LTRIM(@i) + '" = CASE WHEN Poz.Poziom' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' + LTRIM(@i) + ' END'
    set @i = @i + 1
end

--Wyliczanie Atrybutów Kontrahentów
DECLARE @atrybut_id int, @atrybut_kod nvarchar(50), @atrybut_typ int, @atrybut_format int, @atrybuty varchar(max), @sqlA nvarchar(max);

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
    
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Pierwotny Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']' 
    SET @atrybuty = @atrybuty + N', ISNULL(KonAtr1.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Kontrahent Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Wyliczanie Atrybutów Dokumentów
DECLARE @atrybutyDok varchar(max);

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT DAt_DeAid FROM CDN.DokAtrybuty WHERE DAt_TrNId IS NOT NULL)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT DAt_TrNId INTO #tmpDokAtr FROM CDN.DokAtrybuty

SET @atrybutyDok = ''

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
        JOIN #tmpDokAtr TM ON ATR.DAt_TrNId = TM.DAt_TrNId 
        WHERE ATR.DAt_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyDok = @atrybutyDok + N', ISNULL(DokAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Dokument Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Wyliczanie Atrybutów Towarów
DECLARE @atrybutyTwr varchar(max);

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

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
    IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
    SET @sqlA = N'ALTER TABLE #tmpTwrAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpTwrAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TwA_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
          ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TwA_WartoscTxt,'','',''.'') ELSE ATR.TwA_WartoscTxt END 
        END 
        FROM CDN.TwrAtrybuty ATR 
        JOIN #tmpTwrAtr TM ON ATR.TwA_TwrId = TM.TwA_TwrId 
        WHERE ATR.TwA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyTwr = @atrybutyTwr + N', ISNULL(TwrAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') [Produkt Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;

--Wyliczanie Atrybutów Pozycji
DECLARE @atrybutyPoz varchar(max), @atrybutyPoz2 varchar(max);

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT TrA_DeAId FROM CDN.TraElemAtr WHERE TrA_TrEId IS NOT NULL)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT TrA_TrEId INTO #tmpPozAtr FROM CDN.TraElemAtr

SET @atrybutyPoz = ''
SET @atrybutyPoz2 = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
    IF @atrybut_typ = 4 BEGIN SET @atrybut_kod = @atrybut_kod + ' (D)' END
    SET @sqlA = N'ALTER TABLE #tmpPozAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpPozAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.TrA_Wartosc),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.TrA_Wartosc,'','',''.'') ELSE ATR.TrA_Wartosc END 
        END  
        FROM CDN.TraElemAtr ATR 
        JOIN #tmpPozAtr TM ON ATR.TrA_TrEId = TM.TrA_TrEId
        WHERE ATR.TrA_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyPoz = @atrybutyPoz + N', ISNULL(PozAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') [Pozycja Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
    SET @atrybutyPoz2 = @atrybutyPoz2 + N', ''(NIEPRZYPISANE)'' [Pozycja Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'
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
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

--Tworzenie tabeli z serią dokumentów
SELECT DDf_DDfID, CASE 
     WHEN DDf_Numeracja like '@rejestr%' THEN 5
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 1) = '@rejestr' THEN 1
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 2) = '@rejestr' THEN 2
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 3) = '@rejestr' THEN 3
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 4) = '@rejestr' THEN 4
END [seria]  INTO #tmpSeria FROM CDN.DokDefinicje

--Wyliczanie wymiarow na dokumentach

declare @dokumentTyp int

SELECT Wyy_wyyid ID, isnull(wyy_nazwa,Wyy_Kod) Nazwa INTO #tmproots from cdn.Wymiary  where wyy_parentid = 0
declare @wymiary varchar(max)
SET @wymiary = ''

;WITH g(nazwa, kod, ID,parent,RootID,Wyy_D001,aktywny, poziom, sciezka,typ)
AS
(
      SELECT wyy_nazwa, wyy_kod, Wyy_WyyID,Wyy_ParentID,Wyy_RootID,Wyy_D001,wyy_aktywny, 0 as poziom, convert(nvarchar(1024), '') as sciezka,Wyy_TypWymiaru
      FROM cdn.Wymiary 
      WHERE Wyy_ParentID = 0
      --and wyy_wyyid = @TableID
      UNION ALL
      
      SELECT wyy_nazwa, wyy_kod, Wyy_WyyID,Wyy_ParentID,Wyy_RootID,p.Wyy_D001,wyy_aktywny, p.poziom + 1 as poziom, convert(nvarchar(1024), p.sciezka + N'\' + c.wyy_kod) as sciezka,Wyy_TypWymiaru
      FROM g p
      JOIN cdn.Wymiary c
      ON c.Wyy_ParentID = p.ID 
      WHERE c.Wyy_ParentID <> 0 
)     
SELECT  g.*,WyW_SlownikId, WyW_DokumentId, WyW_LpPozycji, WYW_GUID, WyW_DokumentTyp,WyW_Procent,WyW_Kwota
,(select count(*) FROM cdn.WymiaryWartosci W1 where  W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
INTO #tmpWymiary FROM g LEFT JOIN cdn.WymiaryWartosci W ON ID = WyW_WyyId
WHERE Wyy_D001 = 1

insert into #tmpWymiary 
SELECT Coalesce(Knt_Nazwa1,Kat_KodSzczegol,Acc_Nazwa) nazwa ,Coalesce(Knt_Kod,Kat_KodOgolny,acc_numer) kod,ID-10000000,ID,RootID,Wyy_D001,aktywny,poziom + 1,sciezka +'\'+Coalesce(Knt_Kod,Kat_KodOgolny,acc_numer) sciezka,typ,wyw_slownikid,WyW_DokumentId,WyW_LpPozycji,WyW_GUID,WyW_DokumentTyp,wyw_procent,wyw_kwota,IloscPozycji 
FROM #tmpWymiary 
LEFT JOIN cdn.Konta on Typ = 3 and WyW_SlownikId = acc_accid
LEFT JOIN cdn.Kontrahenci on typ = 4 and WyW_SlownikId = Knt_KntId
Left join cdn.Kategorie on typ = 2 and WyW_SlownikId = kat_katid
WHERE typ <> 1 and Wyw_SlownikId <>0

update X
set X.IloscPozycji = (select count(*) from #tmpWymiary X1 where X1.WYW_GUID = X.WYW_GUID) --X.IloscPozycji * 
from  #tmpWymiary X
where WyW_LpPozycji = 0

update X
set X.IloscPozycji = 1
from  #tmpWymiary X
where  X.IloscPozycji = 0

while exists (select * from #tmproots)
begin
declare @TableID int
declare @TableName Varchar(100)

    select top 1 @TableID = ID
    from #tmproots
    order by ID asc

     Select top 1 @TableName = Nazwa
    from #tmproots
    order by ID asc

SELECT @poziom_max = MAX(poziom) FROM #tmpWymiary
SET @poziom = @poziom_max
SET @sql = N''

WHILE @poziom >= 0  
BEGIN
    SET @sql = N'ALTER TABLE #tmpWymiary ADD Poziom' + CAST(@poziom AS nvarchar)+'_'+CAST(@TableID AS nvarchar) + N' nvarchar(50), ONr' + CAST(@poziom AS nvarchar)+'_'+CAST(@TableID AS nvarchar) + N' nvarchar(50)'
    EXEC(@sql)
    

    IF @poziom = @poziom_max 
        BEGIN
            SET @sql = N'UPDATE #tmpWymiary
                SET ONr' + CAST(@poziom AS nvarchar) +'_'+CAST(@TableID AS nvarchar)+ '= Parent WHERE RootID='+CAST(@TableID AS nvarchar)
            EXEC(@sql)

            SET @sql = N'UPDATE #tmpWymiary
                SET Poziom' + CAST(@poziom AS nvarchar) +'_'+CAST(@TableID AS nvarchar)+ ' = kod WHERE RootID='+CAST(@TableID AS nvarchar)
            EXEC(@sql)

			SET @sql = N' ALTER TABLE #tmpWymiary ADD Poziom' + CAST(@poziom AS nvarchar) +'_'+CAST(@TableID AS nvarchar)+ '_path Varchar(200)'
            EXEC(@sql)

			SET @sql = N'UPDATE #tmpWymiary
                SET Poziom' + CAST(@poziom AS nvarchar) +'_'+CAST(@TableID AS nvarchar)+ '_path = sciezka WHERE RootID='+CAST(@TableID AS nvarchar)
            EXEC(@sql)
        END
    ELSE
        BEGIN 
            SET @sql = N'UPDATE c
                SET c.Poziom' + CAST(@poziom AS nvarchar)+'_'+CAST(@TableID AS nvarchar) + N' = (
                    CASE WHEN c.poziom <=' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.kod AS nvarchar)
                    ELSE CAST(p.kod AS nvarchar) END)  
                FROM #tmpWymiary c
                LEFT JOIN #tmpWymiary p
                ON c.ONr' + CAST(@poziom + 1 AS nvarchar)+'_'+CAST(@TableID AS nvarchar) + '= p.ID 
                WHERE p.RootID='+CAST(@TableID AS nvarchar)+'AND c.RootID='+CAST(@TableID AS nvarchar)
            EXEC(@sql)

                SET @sql = N'UPDATE c
                SET c.ONr' + CAST(@poziom AS nvarchar)+'_'+CAST(@TableID AS nvarchar) + N' = (
                    CASE WHEN c.poziom <=' + CAST(@poziom AS nvarchar) + N' THEN CAST(c.parent AS nvarchar)
                    ELSE CAST(p.parent AS nvarchar) END)  
                FROM #tmpWymiary c
                LEFT JOIN #tmpWymiary p
                ON c.ONr' + CAST(@poziom + 1 AS nvarchar) +'_'+CAST(@TableID AS nvarchar)+ '= p.id 
                WHERE p.RootID='+CAST(@TableID AS nvarchar)+'AND c.RootID='+CAST(@TableID AS nvarchar)
                EXEC(@sql)

        END
    SET @poziom = @poziom - 1
END     

set @i=0
while (@i<=@poziom_max)
begin

    SET @wymiary = CONCAT(@wymiary,',"',@TableName,' Poziom ',LTRIM(@i),'" = CASE WHEN Wym.Poziom',LTRIM(@i),'_',@TableID,' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Wym.Poziom', LTRIM(@i),'_',@TableID,' END')
IF (@i=@poziom_max) 
	set @wymiary=CONCAT (@wymiary, ',"',@TableName,' Kompletny ', '" = CASE WHEN Wym.Poziom' ,LTRIM(@i) ,'_',@TableID ,'_path',' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Wym.Poziom' , LTRIM(@i)  ,'_',@TableID ,'_path', ' END')
       
    set @i = @i + 1
end
    delete #tmproots
    where ID = @TableID

end
DROP TABLE #tmproots

delete from #tmpWymiary  where ID > 0 and typ <> 1 and WyW_SlownikId <> 0

ALTER TABLE #tmpWymiary
DROP COLUMN nazwa,aktywny,kod,id,parent,rootID,Wyy_D001,poziom,sciezka,Wyw_DokumentTyp,typ,wyw_slownikid
ALTER TABLE #tmpWymiary
ADD  [Ver] INT
UPDATE #tmpWymiary SET [Ver] = 1


DECLARE @ColNames VARCHAR(MAX)
DECLARE @SQLGrouper VARCHAR(MAX) 
SELECT @ColNames = COALESCE (@ColNames + ', ', '') + 'MAX(' + name +') AS ' +name
FROM    tempdb.sys.columns 
WHERE  object_id = Object_id('tempdb..#tmpWymiary')
AND column_id >18
and name <> 'Ver'

SET @SQLGrouper = 'SELECT Wyw_DokumentID,Wyw_LPPozycji,Wyw_Guid,Wyw_Procent,Wyw_Kwota,IloscPozYcji, '+ @ColNames+' , ver+1  FROM #tmpWymiary 
GROUP BY Wyw_Guid,Wyw_DokumentID,Wyw_LPPozycji,Wyw_Procent,Wyw_Kwota,IloscPozYcji,ver'
INSERT  INTO #tmpWymiary exec (@SQLGrouper)

DELETE FROM #tmpWymiary WHERE [Ver] = 1
--Właściwe zapytanie
set @select = 
'Declare @Wal VarChar(3); Set @Wal = cdn.Waluta('''')
SELECT  DB_NAME()+convert(Varchar(10),TrN_TrNID) [Liczba Dokumentów],
    "Dokument Numer" = TrN_NumerPelny, 
    "Dokument Opis" = ISNULL(NULLIF(TrN_Opis,''''),''(BRAK)''),
    "Dokument Symbol" = dd.DDf_Symbol,  
    CASE when isnull(ser.seria,0) = 5 then 
        substring(TrN_NumerPelny,0,CHARINDEX(''/'',TrN_NumerPelny,0))
    ELSE 
        ISNULL(PARSENAME(REPLACE(substring(TrN_NumerPelny,CHARINDEX(''/'',TrN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
    END [Dokument Seria],
    CONVERT(VARCHAR(2),DATEPART(HOUR,TrN_TS_Zal))+'':''+''00'' [Dokument Godzina Wystawienia],
Waluta = CASE WHEN TrN_Waluta = '''' THEN @Wal ELSE TrN_Waluta END,     
    "Kontrahent Pierwotny Nazwa" = pod1.Pod_Nazwa1, 
    "Kontrahent Pierwotny Kod" = pod1.Pod_Kod, 
    "Kategoria Szczegółowa z Nagłówka" = ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)''), "Kategoria Szczegółowa z Pozycji" = ISNULL(kat2.Kat_KodSzczegol, ''(PUSTA)''),
    "Kategoria Ogólna z Nagłówka" = ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)''), "Kategoria Ogólna z Pozycji" = ISNULL(kat2.Kat_KodOgolny, ''(PUSTA)''),       
       "Kontrahent Pierwotny Województwo" = CASE WHEN pod1.Pod_Wojewodztwo = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod1.Pod_Wojewodztwo END, 
       "Kontrahent Pierwotny Powiat" = CASE WHEN pod1.Pod_Powiat = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod1.Pod_Powiat END,
       "Kontrahent Pierwotny Gmina" = CASE WHEN pod1.Pod_Gmina = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod1.Pod_Gmina END, 
       "Kontrahent Pierwotny Miasto" = CASE WHEN pod1.Pod_Miasto = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod1.Pod_Miasto END, 
       "Kontrahent Pierwotny Kraj" = CASE WHEN pod1.Pod_Kraj = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod1.Pod_Kraj END, 
       "Kontrahent Pierwotny NIP" = CASE WHEN pod1.Pod_NIP = '''' THEN ''(BRAK)'' ELSE pod1.Pod_NIP END, 
       "Kontrahent Pierwotny Grupa" = COALESCE(NULLIF(pod1.Pod_Grupa, ''''), ''Pozostali''),

                                reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE knt.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE knt.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE knt.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE knt.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE knt.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Pierwotny Rodzaj],
        DB_NAME()+''_''+convert(Varchar(10),pod5.pod_PodmiotTyp)+''_''+convert(Varchar(10),pod5.Pod_PodId)  [Liczba Kontrahentów], 
        pod5.Pod_Nazwa1 [Kontrahent Nazwa],     
        pod5.Pod_Kod [Kontrahent Kod], 
        ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Kontrahent Województwo],
        "Kontrahent Powiat" = CASE WHEN pod5.Pod_Powiat = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Powiat END,
        "Kontrahent Gmina" = CASE WHEN pod5.Pod_Gmina = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Gmina END, 
        ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Kontrahent Miasto],
        ISNULL(NULLIF(pod5.Pod_Kraj, ''''),''(NIEPRZYPISANE)'') [Kontrahent Kraj],
        ISNULL(NULLIF(pod5.Pod_NIP, ''''),''(BRAK)'') [Kontrahent NIP],
        ISNULL(NULLIF(pod5.Pod_Grupa, ''''),''Pozostali'') [Kontrahent Grupa], ISNULL(kat5.Kat_KodSzczegol, ''(PUSTA)'') [Kontrahent Kategoria],
        CONVERT(VARCHAR,ISNULL(Rab_Rabat,0))+''%'' [Kontrahent Rabat],
        reverse(stuff(reverse(CONVERT(varchar(100),RTRIM(
    (CASE knt3.Knt_Rodzaj_Dostawca WHEN 1 THEN ''Dostawca, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Odbiorca WHEN 1 THEN ''Odbiorca, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Konkurencja WHEN 1 THEN ''Konkurencja, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Partner WHEN 1 THEN ''Partner, '' else '''' END) +
    (CASE knt3.Knt_Rodzaj_Potencjalny WHEN 1 THEN ''Klient potencjalny,'' else '''' END)))), 1, 1, '''')) AS [Kontrahent Rodzaj],
       "Kontrahent Pierwotny Kategoria" = CASE WHEN kat3.Kat_KodSzczegol IS NULL THEN ''(PUSTA)'' ELSE kat3.Kat_KodSzczegol END, "Produkt Kategoria" = CASE WHEN kat4.Kat_KodSzczegol IS NULL THEN ''(PUSTA)'' ELSE kat4.Kat_KodSzczegol END,
       DB_NAME()+''_''+convert(Varchar(10),Twr_twrId)  [Liczba Produktów], 
       "Produkt Nazwa" = Twr_Nazwa,
         CASE ISNULL(esk.Udostepnij,0) WHEN 0 THEN ''Nie'' ELSE ''Tak'' END as [Produkt e-Sklep],
       "Produkt Nazwa z Faktury" = Tre_TwrNazwa,
       "Produkt PKWiU" = CASE TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(TWR_SWW,''(NIEPRZYPISANE)'') END,
       ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
       CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny],    
       "Produkt Kod" = Twr_Kod,        
       "Produkt Pełna Nazwa Grupy" = poz.sciezka, "Produkt Opis" = CAST(Twr_Opis as VARCHAR(1024)),  "Jednostka Miary" = Twr_Jm, "Magazyn Nazwa" = Mag_Symbol,
"Produkt Producent" = ISNULL(Prd_Kod, ''(NIEPRZYPISANE)''), "Produkt Marka" = ISNULL(Mrk_Nazwa, ''(NIEPRZYPISANE)''),
       "Produkt Typ" = CASE 
            WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa prosta''
            WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa złożona''
            WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar prosty''
            WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar złożony''
       END,
       "Zakupy Wartość" = TrE_WartoscNetto*coalesce(Wym.Wyw_procent*0.01,1.0), "Zakupy Wartość Brutto" = TrE_WartoscBrutto*coalesce(Wym.Wyw_procent*0.01,1.0),
        "Zakupy Wartość Waluta" = TrE_WartoscNettoWal*coalesce(Wym.Wyw_procent*0.01,1.0), "Zakupy Ilość" = TrE_Ilosc*coalesce(Wym.Wyw_procent*0.01,1.0),
        ISNULL(NULLIF(Twr_JMZ,''''), ''(BRAK)'') [Jednostka Miary Pomocnicza]
        ,CAST(TrE_Lp AS VARCHAR(5)) [Produkt Pozycja Dokumentu]
        ,wym.Wyw_Procent AS [Wymiar Procent]
        ,wym.WyW_Kwota AS [Wymiar Wartość]
    /*
    ----------DATY POINT
    ,"Data Operacji" = REPLACE(CONVERT(VARCHAR(10), TrN_DataOpe, 111), ''/'', ''-'')
    ,"Data Wystawienia" = REPLACE(CONVERT(VARCHAR(10), TrN_DataWys, 111), ''/'', ''-'')
    ,"Termin Płatności" = REPLACE(CONVERT(VARCHAR(10), TrN_Termin, 111), ''/'', ''-'')
    */
    ----------DATY ANALIZY
    ,"Data Operacji Dzień" = REPLACE(CONVERT(VARCHAR(10), TrN_DataOpe, 111), ''/'', ''-''), "Data Operacji Tydzień Roku" = (datepart(DY, datediff(d, 0, TrN_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataOpe)*/ 
    ,"Data Operacji Miesiąc" = MONTH(TrN_DataOpe), "Data Operacji Kwartał" = DATEPART(quarter, TrN_DataOpe), "Data Operacji Rok" = YEAR(TrN_DataOpe)  
    ,"Data Wystawienia Dzień" = REPLACE(CONVERT(VARCHAR(10), TrN_DataWys, 111), ''/'', ''-''), "Data Wystawienia Tydzień Roku" = (datepart(DY, datediff(d, 0, TrN_DataWys) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_DataWys)*/
    ,"Data Wystawienia Miesiąc" = MONTH(TrN_DataWys), "Data Wystawienia Kwartał" = DATEPART(quarter, TrN_DataWys), "Data Wystawienia Rok" = YEAR(TrN_DataWys)      
    ,"Termin Płatności Dzień" = REPLACE(CONVERT(VARCHAR(10), TrN_Termin, 111), ''/'', ''-''), "Termin Płatności Tydzień Roku" = (datepart(DY, datediff(d, 0, TrN_Termin) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, TrN_Termin)*/
    ,"Termin Płatności Miesiąc" = MONTH(TrN_Termin), "Termin Płatności Kwartał" = DATEPART(quarter, TrN_Termin), "Termin Płatności Rok" = YEAR(TrN_Termin)      
    ,"Data Analizy" = GETDATE()
        ----------KONTEKSTY
    ,29047 [Dokument Numer __PROCID__Zakupy__], TrN_TrNId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,20201 [Kontrahent Pierwotny Nazwa __PROCID__], pod1.Pod_PodId [Kontrahent Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Pierwotny Nazwa __DATABASE__]
    ,20201 [Kontrahent Pierwotny Kod __PROCID__Kontrahenci__], pod1.Pod_PodId [Kontrahent Pierwotny Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Pierwotny Kod __DATABASE__]
    ,20201 [Kontrahent Nazwa __PROCID__], pod5.Pod_PodId [Kontrahent Nazwa __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Nazwa __DATABASE__]
    ,20201 [Kontrahent Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Kontrahent Kod __ORGID__],'''+@bazaFirmowa+''' [Kontrahent Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]
    ,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__],'''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]

        ' + @kolumny + @atrybuty + @atrybutyDok + @atrybutyTwr + @atrybutyPoz + @wymiary 
      
     
set @select2 = 
' FROM cdn.TraNag 
     JOIN cdn.TraElem ON TrE_TrNID=TrN_TrNID 
     LEFT JOIN #tmpSeria ser ON TrN_DDfId = DDf_DDfID
     LEFT JOIN CDN.DokDefinicje dd ON TrN_DDfId = dd.DDf_DDfID
     LEFT OUTER JOIN CDN.Kontrahenci knt ON TrE_PodID=Knt_KntId AND TrE_PodmiotTyp = 1
     JOIN CDN.Towary ON TrE_TwrId=Twr_TwrId
     LEFT JOIN CDN.Producenci ON Prd_PrdId = Twr_PrdId
     LEFT JOIN CDN.Marki ON Mrk_MrkId = Twr_MrkId
     JOIN CDN.Magazyny ON TrE_MagId=Mag_MagId 
     LEFT OUTER JOIN CDN.Kategorie kat1 ON TrN_KatID=kat1.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat2 ON TrE_KatID=kat2.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat3 ON Knt_KatID=kat3.Kat_KatID
     LEFT OUTER JOIN CDN.Kategorie kat4 ON Twr_KatID=kat4.Kat_KatID
     LEFT OUTER JOIN CDN.PodmiotyView pod1 ON TrE_PodID= pod1.Pod_PodId AND TrE_PodmiotTyp = pod1.Pod_PodmiotTyp
     LEFT OUTER JOIN cdn.PodmiotyView pod2 ON Knt_OpiekunId = pod2.Pod_PodId AND knt.Knt_OpiekunTyp = pod2.Pod_PodmiotTyp

     LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
     LEFT JOIN #tmpKonAtr KonAtr ON Knt_KntId = KonAtr.KnA_PodmiotId
     LEFT JOIN #tmpDokAtr DokAtr ON TrN_TrNID  = DokAtr.DAt_TrNId 
     LEFT JOIN #tmpTwrAtr TwrAtr ON TrE_TwrId  = TwrAtr.TwA_TwrId 
     LEFT JOIN #tmpPozatr PozAtr on PozAtr.TrA_TrEId = TrE_TrEId
     LEFT OUTER JOIN cdn.PodmiotyView pod5 on pod1.Pod_GlID = pod5.Pod_PodId and pod1.Pod_GlKod = pod5.Pod_Kod
    LEFT OUTER JOIN CDN.Kontrahenci knt3 ON pod5.Pod_PodID=knt3.Knt_KntId AND pod5.Pod_PodmiotTyp = 1
    LEFT JOIN CDN.Rabaty on rab_podmiotid = knt3.knt_kntid and rab_typ = 2
    LEFT OUTER JOIN CDN.Kategorie kat5 ON knt3.Knt_KatID=kat5.Kat_KatID
    LEFT OUTER JOIN cdn.PodmiotyView pod6 ON knt3.Knt_OpiekunId = pod6.Pod_PodId AND knt3.Knt_OpiekunTyp = pod6.Pod_PodmiotTyp
    LEFT JOIN #tmpKonAtr KonAtr1 ON pod5.Pod_PodId = KonAtr1.KnA_PodmiotId AND pod5.Pod_PodmiotTyp = KonAtr1.KnA_PodmiotTyp
    LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
    LEFT JOIN (select distinct Twes_TwrId, MAX(Twes_Udostepnij) Udostepnij from cdn.TwrESklep group by Twes_TwrId) esk on esk.Twes_TwrId = Twr_TwrId
    LEFT JOIN #tmpWymiary wym on wym.WyW_DokumentId = TrN_TrNID and (wym.WyW_LpPozycji =  Tre_Lp  or  wym.WyW_LpPozycji = 0)
WHERE TrN_TypDokumentu=301 AND TrN_Bufor<>-1 AND TrE_Aktywny<>0
--and TrN_TRNID = 16870
'

exec (@select  + @select2)

DROP TABLE #tmpTwrGr
DROP TABLE #tmpKonAtr
DROP TABLE #tmpDokAtr
DROP TABLE #tmpTwrAtr
DROP TABLE #tmpSeria
drop table #tmpWymiary
DROP TABLE #tmpPozatr






