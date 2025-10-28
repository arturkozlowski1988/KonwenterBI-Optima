/*
* Raport Rejestrów VAT z Opisami analitycznymi
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.1.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @bazaFirmowa varchar(max);
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Bazy varchar(max);
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]'

--Wyliczanie Atrybutów Dokumentów
DECLARE @atrybut_id int, @atrybut_kod nvarchar(50), @atrybut_typ int, @sqlA nvarchar(max), @atrybutyDok varchar(max), @atrybut_format int;

DECLARE @wersja float;
SET @wersja = (SELECT CONVERT(float, SYS_Wartosc) FROM CDN.SystemCDN WHERE SYS_ID = 3)

SET @sqlA = 
'DECLARE atrybut_cursor CURSOR FOR
SELECT DeA_DeAId, REPLACE(DeA_Kod, '']'', ''_''), DeA_Typ, DeA_Format
FROM CDN.DefAtrybuty
WHERE DeA_DeAId in (SELECT DISTINCT DAt_DeAid FROM CDN.DokAtrybuty WHERE DAt_VaNID IS NOT NULL)
AND DeA_Format <> 5'
IF @wersja >= 2013 SET @sqlA = @sqlA + ' AND DeA_AnalizyBI = 1;'
EXEC(@sqlA)

OPEN atrybut_cursor;

FETCH NEXT FROM atrybut_cursor
INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;

SELECT DISTINCT DAt_VaNID INTO #tmpDokAtr FROM CDN.DokAtrybuty

SET @atrybutyDok = ''

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @atrybut_typ = 2 BEGIN SET @atrybut_kod = @atrybut_kod + ' (K)' END
    SET @sqlA = N'ALTER TABLE #tmpDokAtr ADD [' + CAST(@atrybut_kod AS nvarchar(50)) + N'] nvarchar(max)'
    EXEC(@sqlA)    
    SET @sqlA = N'UPDATE #tmpDokAtr
        SET [' + CAST(@atrybut_kod AS nvarchar(50)) +  '] = CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 4 THEN REPLACE(CONVERT(VARCHAR(10), DateAdd(day,convert(int,ATR.DAt_WartoscTxt),convert(datetime,''28-12-1800'',105)), 111), ''/'', ''-'') 
         ELSE CASE WHEN ' + convert(varchar,@atrybut_format) + ' = 2  THEN REPLACE(ATR.DAt_WartoscTxt,'','',''.'') ELSE ATR.DAt_WartoscTxt END        
        END 
        FROM CDN.DokAtrybuty ATR 
        JOIN #tmpDokAtr TM ON ATR.DAt_VaNID = TM.DAt_VaNID
        WHERE ATR.DAt_DeAId = ' + CAST(@atrybut_id AS nvarchar)
    EXEC(@sqlA)    
    
    SET @atrybutyDok = @atrybutyDok + N', ISNULL(DokAtr.[' +  CAST(@atrybut_kod AS nvarchar(50)) + '], ''(NIEPRZYPISANE)'') AS [Dokument Atrybut ' + CAST(@atrybut_kod AS nvarchar(50)) + ']'         
    FETCH NEXT FROM atrybut_cursor
    INTO @atrybut_id, @atrybut_kod, @atrybut_typ, @atrybut_format;
END

CLOSE atrybut_cursor;
DEALLOCATE atrybut_cursor;
 --Wyliczanie wymiarow

declare @dokumentTypFZ int, @dokumentTypFS int
set @dokumentTypFZ = 20 -- Rejestr vat zakupu
set @dokumentTypFS = 21 -- Rejestr vat sprzedaży

DECLARE @poziom int
DECLARE @poziom_max int
DECLARE @sql nvarchar(max)
SELECT Wyy_wyyid ID,isnull(wyy_nazwa,Wyy_Kod) Nazwa INTO #tmproots from cdn.Wymiary  where wyy_parentid = 0
declare @wymiary varchar(max)
SET @wymiary = ''

;WITH g(nazwa, kod, ID,parent,RootID,Wyy_D020,Wyy_D021,aktywny,poziom, sciezka,typsl)
AS
(
      SELECT wyy_nazwa, wyy_kod, Wyy_WyyID,Wyy_ParentID,Wyy_RootID,Wyy_D020,Wyy_D021,wyy_aktywny, 0 as poziom, convert(nvarchar(1024), '') as sciezka,Wyy_TypWymiaru
      FROM cdn.Wymiary 
      WHERE Wyy_ParentID = 0
      --and wyy_wyyid = @TableID
      UNION ALL
      
      SELECT wyy_nazwa, wyy_kod, Wyy_WyyID,Wyy_ParentID,Wyy_RootID,p.Wyy_D020,p.Wyy_D021,wyy_aktywny, p.poziom + 1 as poziom, convert(nvarchar(1024), p.sciezka + N'\' + c.wyy_kod) as sciezka,Wyy_TypWymiaru
      FROM g p
      JOIN cdn.Wymiary c
      ON c.Wyy_ParentID = p.ID 
      WHERE c.Wyy_ParentID <> 0 
)     SELECT * INTO #tmpWymiary  FROM(
SELECT  g.*,WyW_SlownikId,W.Wyw_wywID WYWID, VaN_VanID VaNID,0 VatLP, 
W.WyW_Kwota  Kwota, W.wyw_procent Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W2 where W2.WyW_DokumentId = W.WyW_DokumentId and W2.WyW_LpPozycji = W.WyW_LpPozycji and W2.WyW_WyyId = 0 ) IloscPozycji,
WyW_SourceType TypS,
CASE WyW_SourceType
            WHEN 1 THen 'Pozycja/Kwota dodatkowa'
            WHEN 2 THen 'Pozycja/Netto'
            WHEN 3 THen 'Pozycja/Koszt'
            WHEN 4 THen 'Pozycja/VAT_KOSZT'
            WHEN 5 THen 'Dokument/Netto'
            WHEN 6 THen 'Dokument/Koszt'
            WHEN 7 THen 'Dokument/VAT_Koszt'
       END [Typ ]
FROM g LEFT JOIN cdn.WymiaryWartosci W ON ID = WyW_WyyId
left JOIN CDN.VatNag ON VaN_VanID = W.WyW_DokumentId AND  W.WyW_LpPozycji = 0
WHERE  (Wyy_D020 = 1 or Wyy_D021 = 1)
UNION all

SELECT  g.*,WyW_SlownikId,W.Wyw_wywID WYWID,
Vat_VanID VaNID,VaT_Lp VatLP, 
W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where  W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji,
WyW_SourceType TypS,
CASE WyW_SourceType
            WHEN 1 THen 'Pozycja/Kwota dodatkowa'
            WHEN 2 THen 'Pozycja/Netto'
            WHEN 3 THen 'Pozycja/Koszt'
            WHEN 4 THen 'Pozycja/VAT_KOSZT'
            WHEN 5 THen 'Dokument/Netto'
            WHEN 6 THen 'Dokument/Koszt'
            WHEN 7 THen 'Dokument/VAT_Koszt'
       END [Typ ]
FROM g LEFT JOIN cdn.WymiaryWartosci W ON ID = WyW_WyyId
JOIN CDN.VatTab ON Vat_VanID = W.WyW_DokumentId and VaT_Lp = W.WyW_LpPozycji
WHERE  (Wyy_D020 = 1 or Wyy_D021 = 1)
)X 


insert into #tmpWymiary 
SELECT Coalesce(Knt_Nazwa1,Kat_KodSzczegol,Acc_Nazwa) nazwa ,Coalesce(Knt_Kod,Kat_KodOgolny,acc_numer) kod,ID-10000000,ID,RootID,Wyy_D020,Wyy_D021,aktywny,poziom + 1,sciezka +'\'+Coalesce(Knt_Kod,Kat_KodOgolny,acc_numer) sciezka,typsl,wyw_slownikid,wywid,vanid,vatlp,Kwota,Procent,GUID,IloscPozycji,TypS,Typ
FROM #tmpWymiary 
LEFT JOIN cdn.Konta on typsl = 3 and WyW_SlownikId = acc_accid
LEFT JOIN cdn.Kontrahenci on typsl = 4 and WyW_SlownikId = Knt_KntId
Left join cdn.Kategorie on typsl = 2 and WyW_SlownikId = kat_katid
WHERE typsl <> 1 and Wyw_SlownikId <>0


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
DECLARE @i int
set @i=0
while (@i<=@poziom_max)
begin

    set @wymiary = CONCAT(@wymiary , ',"',@TableName,' Poziom ', LTRIM(@i), '" = CASE WHEN WymV.Poziom' ,LTRIM(@i) ,'_',@TableID , ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE WymV.Poziom' , LTRIM(@i) ,'_',@TableID, ' END')
IF (@i=@poziom_max) 
	set @wymiary =CONCAT (@wymiary, ',"',@TableName,' Kompletny ', '" = CASE WHEN WymV.Poziom' ,LTRIM(@i) ,'_',@TableID ,'_path',' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE WymV.Poziom' , LTRIM(@i)  ,'_',@TableID ,'_path', ' END')
 
 set @i = @i + 1
end
    delete #tmproots
    where ID = @TableID

end
DROP TABLE #tmproots

delete from #tmpWymiary  where ID > 0 and typsl <> 1 and WyW_SlownikId <> 0

ALTER TABLE #tmpWymiary
DROP COLUMN nazwa,aktywny,kod,id,parent,rootID,Wyy_D021,Wyy_D020,poziom,sciezka,WYWID,TypS,Typ,typsl,wyw_slownikid
ALTER TABLE #tmpWymiary
ADD  [Ver] INT
UPDATE #tmpWymiary SET [Ver] = 1


DECLARE @ColNames VARCHAR(MAX)
DECLARE @SQLGrouper VARCHAR(MAX) 
SELECT @ColNames = COALESCE (@ColNames + ', ', '') + 'MAX(' + name +') AS ' +name
FROM    tempdb.sys.columns 
WHERE  object_id = Object_id('tempdb..#tmpWymiary')
AND column_id >21
and name <> 'Ver'


SET @SQLGrouper = 'SELECT VaNID,VatLP,Cast(Procent as decimal(19,2)) procent,Cast(Kwota as decimal(19,2)) kwota,Guid,IloscPozYcji, '+ @ColNames+' , ver+1  FROM #tmpWymiary 
GROUP BY Guid,VaNID,VatLP,Cast(Procent as decimal(19,2)),Cast(Kwota as decimal(19,2)),IloscPozYcji,ver'
INSERT  INTO #tmpWymiary exec (@SQLGrouper)

DELETE FROM #tmpWymiary WHERE [Ver] = 1

--Właściwe zapytanie
DECLARE @select varchar(max);

SET @select = 
'Declare @Wal VarChar(3); Set @Wal = cdn.Waluta('''')
SELECT BAZ.Baz_Nazwa [Baza Firmowa], 
    VaT_Lp [Pozycja Lp],
    VaN_Dokument AS [Dokument Numer],
    CASE VaT_RodzajZakupu WHEN 1 THEN ''Towary'' WHEN 2 THEN ''Inne'' WHEN 3 THEN ''Środki Trwałe'' WHEN 4 THEN ''Usługi'' WHEN 5 THEN ''Środki Transportu'' WHEN 6 THEN ''Nieruchomości'' WHEN 7 THEN ''Paliwo'' END AS [Rodzaj],
    CASE VaT_Flaga WHEN 1 THEN ''ZW'' WHEN 4 THEN ''NP'' ELSE convert(varchar,VaT_Stawka) + ''%'' END AS [Stawka VAT], VaN_Rejestr AS [Rejestr],
    CASE Vat_Odliczenia WHEN 0 then ''Nie''  WHEN 1 then ''Tak'' WHEN 2 then ''Warunkowo''  END [Odliczenia],
    ISNULL(kat1.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Elementu], ISNULL(kat3.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria 2 Szczegółowa z Elementu],
    ISNULL(kat2.Kat_KodSzczegol, ''(PUSTA)'') [Kategoria Szczegółowa z Nagłówka], ISNULL(kat2.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Nagłówka],
    ISNULL(VaN_Kategoria, ''(PUSTA)'') [Kategoria Opis z Nagłówka], ISNULL(VaT_KatOpis, ''(PUSTA)'') [Kategoria Opis z Elementu], ISNULL(VaT_Kat2Opis, ''(PUSTA)'') [Kategoria 2 Opis z Elementu],
    ISNULL(kat1.Kat_KodOgolny, ''(PUSTA)'') [Kategoria Ogólna z Elementu], ISNULL(kat3.Kat_KodOgolny, ''(PUSTA)'') [Kategoria 2 Ogólna z Elementu],
    CASE WHEN VaN_RozliczacVat7 = 1 THEN ''TAK'' ELSE ''NIE'' END [Rozliczać do Deklaracji VAT], 
    ISNULL(SUBSTRING(convert(varchar,VaN_DeklRokMies), 1,4), ''(NIEPRZYPISANE)'') [Data Rozliczenia w Deklaracji Rok], 
    ISNULL(SUBSTRING(convert(varchar,VaN_DeklRokMies), 5,6), ''(NIEPRZYPISANE)'') [Data Rozliczenia w Deklaracji Miesiąc],
        SUBSTRING(convert(varchar,
    CASE VaN_DeklRokMiesKasa
    WHEN 0 THEN NULL
    ELSE VaN_DeklRokMiesKasa END
    ), 1,4) [Data Rozliczenia wg Metody Kasowej Rok], 
 SUBSTRING(convert(varchar,
    CASE VaN_DeklRokMiesKasa
    WHEN 0 THEN NULL
    ELSE VaN_DeklRokMiesKasa END
    ), 5,6) [Data Rozliczenia wg Metody Kasowej Miesiąc], 
    CASE WHEN VaN_Waluta = '''' THEN @Wal ELSE VaN_Waluta END [Waluta],
    CASE WHEN VaT_Flaga = 1 THEN ''Zwolniona''
         WHEN VaT_Flaga = 2 THEN ''Opodatkowana''
         WHEN VaT_Flaga = 3 THEN ''Zaniżona''
         WHEN VaT_Flaga = 4 THEN ''Nie podlega''
    ELSE ''(NIEPRZYPISANE)'' END AS [Typ Stawki],
    CASE WHEN VaN_PodmiotTyp = 1 THEN ''Kontrahent''
         WHEN VaN_PodmiotTyp = 2 THEN ''Bank''
         WHEN VaN_PodmiotTyp = 3 THEN ''Pracownik''
         WHEN VaN_PodmiotTyp = 4 THEN ''Wspólnik''
         WHEN VaN_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END AS [Podmiot Pierwotny Typ], 
    Podmioty.Pod_Kod AS [Podmiot Pierwotny Kod], 
    Podmioty.Pod_Nazwa1 AS [Podmiot Pierwotny Nazwa], 
    Podmioty.Pod_NIP AS [Podmiot Pierwotny NIP],
    Podmioty.Pod_Kraj AS [Podmiot Pierwotny Kraj],
    Podmioty.Pod_Wojewodztwo AS [Podmiot Pierwotny Województwo], Podmioty.Pod_Powiat AS [Podmiot Pierwotny Powiat], Podmioty.Pod_Gmina AS [Podmiot Pierwotny Gmina],
    Podmioty.Pod_Miasto AS [Podmiot Pierwotny Miasto],
        CASE WHEN pod5.Pod_PodmiotTyp = 1 THEN ''Kontrahent''
        WHEN pod5.Pod_PodmiotTyp = 2 THEN ''Bank''
        WHEN pod5.Pod_PodmiotTyp = 3 THEN ''Pracownik''
        WHEN pod5.Pod_PodmiotTyp = 4 THEN ''Wspólnik''
        WHEN pod5.Pod_PodmiotTyp = 5 THEN ''Urząd''
    ELSE ''(NIEOKREŚLONY)'' END AS [Podmiot Typ], 
    pod5.Pod_Nazwa1 [Podmiot Nazwa],    
    pod5.Pod_Kod [Podmiot Kod], 
    pod5.Pod_NIP AS [Podmiot NIP],
    pod5.Pod_Kraj AS [Podmiot Kraj],
    ISNULL(NULLIF(pod5.Pod_Wojewodztwo, ''''),''(NIEPRZYPISANE)'') [Podmiot Województwo],
    "Podmiot Powiat" = CASE WHEN pod5.Pod_Powiat = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Powiat END,
    "Podmiot Gmina" = CASE WHEN pod5.Pod_Gmina = '''' THEN ''(NIEPRZYPISANE)'' ELSE pod5.Pod_Gmina END, 
    ISNULL(NULLIF(pod5.Pod_Miasto, ''''),''(NIEPRZYPISANE)'') [Podmiot Miasto],
    isnull(Zak_Symbol,''(NIEPRZYPISANY)'') as [Zakład Symbol],
    isnull(zak_NazwaFirmy,''(NIEPRZYPISANY)'') as [Zakład Nazwa Firmy],
    VaN_IdentKsieg AS [Id. Księgowy],
    (CASE WHEN VaN_Typ = 1 THEN VaT_VATDoVAT ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Zakupy VAT], (CASE WHEN VaN_Typ = 2 THEN VaT_VATDoVAT ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Sprzedaż VAT],
    (CASE WHEN VaN_Typ = 1 THEN VaT_NettoDoVAT + VaT_VATDoVAT ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Zakupy Brutto], (CASE WHEN VaN_Typ = 2 THEN VaT_VATDoVAT + VaT_NettoDoVAT ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Sprzedaż Brutto],
    (CASE WHEN VaN_Typ = 1 THEN VaT_NettoDoVAT ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Zakupy Netto], (CASE WHEN VaN_Typ = 2 THEN VaT_NettoDoVAT ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Sprzedaż Netto],
    (CASE WHEN VaN_Typ = 1 THEN VaT_VATWal ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Zakupy VAT Waluta], (CASE WHEN VaN_Typ = 2 THEN VaT_VATWal ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Sprzedaż VAT Waluta],
    (CASE WHEN VaN_Typ = 1 THEN VaT_NettoWal + VaT_VATWal ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Zakupy Brutto Waluta], (CASE WHEN VaN_Typ = 2 THEN VaT_NettoWal + VaT_VATWal ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Sprzedaż Brutto Waluta],
    (CASE WHEN VaN_Typ = 1 THEN VaT_NettoWal ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Zakupy Netto Waluta], (CASE WHEN VaN_Typ = 2 THEN VaT_NettoWal ELSE NULL END)*COALESCE(Kwota*0.01,1) AS [Kwota Sprzedaż Netto Waluta],
    CASE WHEN VaN_Typ = 2 AND VaN_Detal = 1 THEN ''Tak'' Else ''Nie'' END AS [Sprzedaż detaliczna],
    CASE VaN_Rozliczono WHEN 0 THEN ''Nie'' ELSE ''Tak'' END [Dokument Rozliczony],
    VaN_OpeModKod [Operator Modyfikujący],
    VaN_OpeZalKod [Operator Wprowadzający],
	Procent [Wymiar Wartość],
	Kwota [Wymiar Procent]
    /*
    ----------DATY POINT
    ,REPLACE(CONVERT(VARCHAR(10), VaN_DataWys, 111), ''/'', ''-'') AS [Data Wystawienia]
    ,REPLACE(CONVERT(VARCHAR(10), VaN_DataZap, 111), ''/'', ''-'') AS [Data Zapisu]
    ,REPLACE(CONVERT(VARCHAR(10), VaN_DataOpe, 111), ''/'', ''-'') AS [Data Operacji]
    ,REPLACE(CONVERT(VARCHAR(10), VaN_TS_Zal, 111), ''/'', ''-'') AS [Data Wprowadzenia]
    ,REPLACE(CONVERT(VARCHAR(10), VaN_TS_Mod, 111), ''/'', ''-'') AS [Data Modyfikacji]
    
    */
    ----------DATY ANALIZY
    ,REPLACE(CONVERT(VARCHAR(10), VaN_DataWys, 111), ''/'', ''-'') AS [Data Wystawienia Dzień], YEAR(VaN_DataWys) AS [Data Wystawienia Rok]
    ,DATEPART(quarter, VaN_DataWys) AS [Data Wystawienia Kwartał], MONTH(VaN_DataWys) AS [Data Wystawienia Miesiąc], (datepart(DY, datediff(d, 0, VaN_DataWys) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, VaN_DataWys)*/ [Data Wystawienia Tydzień Roku]
    ,REPLACE(CONVERT(VARCHAR(10), VaN_DataZap, 111), ''/'', ''-'') AS [Data Zapisu Dzień], YEAR(VaN_DataZap) AS [Data Zapisu Rok]
    ,DATEPART(quarter, VaN_DataZap) AS [Data Zapisu Kwartał], MONTH(VaN_DataZap) AS [Data Zapisu Miesiąc], (datepart(DY, datediff(d, 0, VaN_DataZap) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, VaN_DataZap)*/ [Data Zapisu Tydzień Roku]
    ,REPLACE(CONVERT(VARCHAR(10), VaN_DataOpe, 111), ''/'', ''-'') AS [Data Operacji Dzień], YEAR(VaN_DataOpe) AS [Data Operacji Rok] 
    ,DATEPART(quarter, VaN_DataOpe) AS [Data Operacji Kwartał], MONTH(VaN_DataOpe) AS [Data Operacji Miesiąc], (datepart(DY, datediff(d, 0, VaN_DataOpe) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, VaN_DataOpe)*/ [Data Operacji Tydzień Roku]
    ,REPLACE(CONVERT(VARCHAR(10), VaN_TS_Zal, 111), ''/'', ''-'') AS [Data Wprowadzenia Dzień], YEAR(VaN_TS_Zal) AS [Data Wprowadzenia Rok] 
    ,DATEPART(quarter, VaN_TS_Zal) AS [Data Wprowadzenia Kwartał], MONTH(VaN_TS_Zal) AS [Data Wprowadzenia Miesiąc], (datepart(DY, datediff(d, 0, VaN_TS_Zal) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, VaN_TS_Zal)*/ [Data Wprowadzenia Tydzień Roku]
    ,REPLACE(CONVERT(VARCHAR(10), VaN_TS_Mod, 111), ''/'', ''-'') AS [Data Modyfikacji Dzień], YEAR(VaN_TS_Mod) AS [Data Modyfikacji Rok] 
    ,DATEPART(quarter, VaN_TS_Mod) AS [Data Modyfikacji Kwartał], MONTH(VaN_TS_Mod) AS [Data Modyfikacji Miesiąc], (datepart(DY, datediff(d, 0, VaN_TS_Mod) / 7 * 7 + 3)+6) / 7 /*DATEPART(isowk, VaN_TS_Mod)*/ [Data Modyfikacji Tydzień Roku]
    ,GETDATE() [Data Analizy]
    ----------KONTEKSTY
    ,20101 [Dokument Numer __PROCID__VAT__], VaN_VaNId [Dokument Numer __ORGID__],'''+@bazaFirmowa+''' [Dokument Numer __DATABASE__]
    ,CASE Podmioty.Pod_PodmiotTyp
        WHEN 1 THEN 20201
        WHEN 2 THEN 23002
        WHEN 3 THEN 24001
        WHEN 5 THEN 25005
        ELSE 20201
    END [Podmiot Pierwotny Kod __PROCID__Kontrahenci__], Podmioty.Pod_PodId [Podmiot Pierwotny Kod __ORGID__], '''+@bazaFirmowa+''' [Podmiot Pierwotny Kod __DATABASE__]
    ,CASE Podmioty.Pod_PodmiotTyp
        WHEN 1 THEN 20201
        WHEN 2 THEN 23002
        WHEN 3 THEN 24001
        WHEN 5 THEN 25005
        ELSE 20201
    END [Podmiot Pierwotny Nazwa __PROCID__], Podmioty.Pod_PodId [Podmiot Pierwotny Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Pierwotny Nazwa __DATABASE__]
    ,20201 [Podmiot Nazwa __PROCID__], pod5.Pod_PodId [Podmiot Nazwa __ORGID__],'''+@bazaFirmowa+''' [Podmiot Nazwa __DATABASE__]
    ,CASE pod5.Pod_PodmiotTyp
        WHEN 1 THEN 20201
        WHEN 2 THEN 23002
        WHEN 3 THEN 24001
        WHEN 5 THEN 25005
        ELSE 20201
    END [Podmiot Kod __PROCID__Kontrahenci__], pod5.Pod_PodId [Podmiot Kod __ORGID__],'''+@bazaFirmowa+''' [Podmiot Kod __DATABASE__]

    '
    
    + @atrybutyDok + @wymiary +
' FROM CDN.VatNag
    JOIN CDN.VatTab ON VaN_VaNID = VaT_VaNID
    LEFT OUTER JOIN CDN.Kategorie kat1 ON VaT_KatID=kat1.Kat_KatID
    LEFT OUTER JOIN CDN.Kategorie kat2 ON VaN_KatID=kat2.Kat_KatID
    LEFT OUTER JOIN CDN.Kategorie kat3 ON VaT_Kat2ID=kat3.Kat_KatID
    LEFT OUTER JOIN CDN.PodmiotyView Podmioty ON VaN_PodID = Podmioty.Pod_PodId AND VaN_PodmiotTyp = Podmioty.Pod_PodmiotTyp
    LEFT JOIN #tmpDokAtr DokAtr ON VaT_VaNID  = DokAtr.DAt_VaNId
    LEFT OUTER JOIN cdn.PodmiotyView pod5 on Podmioty.Pod_GlID = pod5.Pod_PodId and Podmioty.Pod_GlKod = pod5.Pod_Kod
    LEFT OUTER JOIN CDN.Zaklady on ZAK_ZAkID = VaN_ZakID
    LEFT Outer JOIN #tmpWymiary WymV ON  VaN_VaNID = WymV.VaNID AND (WymV.VatLP=VaT_Lp or WymV.VatLP = 0)
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    '
exec(@select)

DROP TABLE #tmpDokAtr
drop table #tmpWymiary





