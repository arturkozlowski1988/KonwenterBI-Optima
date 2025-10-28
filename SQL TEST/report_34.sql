/*
* Raport Opisów Analitycznych
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SELECT Wyy_wyyid ID,isnull(wyy_nazwa,Wyy_Kod) Nazwa INTO #tmproots from cdn.Wymiary  where wyy_parentid = 0
declare @kolumny varchar(max)
SET @kolumny = ''

;WITH g(nazwa, kod, ID,parent,RootID,aktywny, poziom, sciezka,typsl)
AS
(
      SELECT wyy_nazwa, wyy_kod, Wyy_WyyID,Wyy_ParentID,Wyy_RootID,wyy_aktywny, 0 as poziom, convert(nvarchar(1024), '') as sciezka,Wyy_TypWymiaru
      FROM cdn.Wymiary 
      WHERE Wyy_ParentID = 0
      --and wyy_wyyid = @TableID
      UNION ALL
      
      SELECT wyy_nazwa, wyy_kod, Wyy_WyyID,Wyy_ParentID,Wyy_RootID,wyy_aktywny, p.poziom + 1 as poziom, convert(nvarchar(1024), p.sciezka + N'\' + c.wyy_kod) as sciezka,Wyy_TypWymiaru
      FROM g p
      JOIN cdn.Wymiary c
      ON c.Wyy_ParentID = p.ID 
      WHERE c.Wyy_ParentID <> 0 
)     
SELECT  g.*,WyW_SlownikId, WyW_DokumentId, WyW_LpPozycji, WYW_GUID, WyW_DokumentTyp INTO #tmpWymiary FROM g LEFT JOIN cdn.WymiaryWartosci ON ID = WyW_WyyId


insert into #tmpWymiary 
SELECT Coalesce(Knt_Nazwa1,Kat_KodSzczegol,Acc_Nazwa) nazwa ,Coalesce(Knt_Kod,Kat_KodOgolny,acc_numer) kod,ID-10000000,ID,RootID,aktywny,poziom + 1,sciezka +'\'+Coalesce(Knt_Kod,Kat_KodOgolny,acc_numer) sciezka,typsl,wyw_slownikid,WyW_DokumentId,WyW_LpPozycji,WyW_GUID,WyW_DokumentTyp
FROM #tmpWymiary 
LEFT JOIN cdn.Konta on Typsl = 3 and WyW_SlownikId = acc_accid
LEFT JOIN cdn.Kontrahenci on Typsl = 4 and WyW_SlownikId = Knt_KntId
Left join cdn.Kategorie on Typsl = 2 and WyW_SlownikId = kat_katid
WHERE Typsl <> 1 and Wyw_SlownikId <>0

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

DECLARE @poziom int
DECLARE @poziom_max int
DECLARE @sql nvarchar(max)
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

declare @i int

set @i=0
while (@i<=@poziom_max)
begin

    set @kolumny =CONCAT (@kolumny, ',"',@TableName,' Poziom ' , LTRIM(@i) , '" = CASE WHEN Poz.Poziom' ,LTRIM(@i) ,'_',@TableID ,' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' , LTRIM(@i)  ,'_',@TableID , ' END')
   
      IF (@i=@poziom_max) 
	set @kolumny =CONCAT (@kolumny, ',"',@TableName,' Kompletny ', '" = CASE WHEN Poz.Poziom' ,LTRIM(@i) ,'_',@TableID ,'_path',' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' , LTRIM(@i)  ,'_',@TableID ,'_path', ' END')
   
   set @i = @i + 1
end
    delete #tmproots
    where ID = @TableID

end

DROP TABLE #tmproots
delete from #tmpWymiary  where ID > 0 and typsl <> 1 and WyW_SlownikId <> 0

ALTER TABLE #tmpWymiary
DROP COLUMN nazwa,kod,id,parent,rootID,aktywny,poziom,sciezka,Wyw_DokumentTyp,typsl,WyW_SlownikId
ALTER TABLE #tmpWymiary
ADD  [Ver] INT
UPDATE #tmpWymiary SET [Ver] = 1

DECLARE @ColNames VARCHAR(MAX)
DECLARE @SQLGrouper VARCHAR(MAX) 
SELECT @ColNames = COALESCE (@ColNames + ', ', '') + 'MAX(' + name +') AS ' +name
FROM    tempdb.sys.columns 
WHERE  object_id = Object_id('tempdb..#tmpWymiary')
AND column_id >14
and name <> 'Ver'

SET @SQLGrouper = 'SELECT WyW_DokumentId,WyW_LpPozycji,WYW_GUID, '+ @ColNames+' , ver+1  FROM #tmpWymiary 
GROUP BY  WYW_GUID,WyW_DokumentId,WyW_LpPozycji,ver'
INSERT  INTO #tmpWymiary exec (@SQLGrouper)

DELETE FROM #tmpWymiary WHERE [Ver] = 1

declare @dokumentTypFZ int, @dokumentTypFS int
declare @dokumentTyp int

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

set @dokumentTyp = 1 -- Faktury zakupu

select 1 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
29047 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Faktura zakupu') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp PodmiotTyp, TrN_PodID PodmiotID
,CAST (NULL AS VARCHAR(100)) AS Projekt
,CAST (NULL AS VARCHAR(100)) AS Dzial
INTO #tmpTrNWym
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and TrN_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 2 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
29047 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Faktura zakupu' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and TrN_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 2 -- Faktury sprzedazy

INSERT INTO #tmpTrNWym
select 3 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
CASE WHEN TrN_TypDokumentu = 305 THEN 29048 ELSE 25004 END [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Faktura sprzedaży' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,Tre_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and TrN_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 4 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
CASE WHEN TrN_TypDokumentu = 305 THEN 29048 ELSE 25004 END [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__], W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota  Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ , 'Faktura sprzedaży' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and TrN_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 19 -- Polecenie księgowania

INSERT INTO #tmpTrNWym
select 5 as Paczka, CAST(DeN_Dokument AS nvarchar(260)) [Dokument Numer],   
26002 [Dokument Numer __PROCID__], DeN_DeNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,DeE_DeNId DENID ,DeE_Lp DeELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 
and W.WyW_SlownikId = W1.WyW_SlownikId and W.WyW_SourceType = W1.WyW_SourceType
) IloscPozycji
--,isnull(W.WyW_SlownikId,0) kontoID ,  W.WyW_SourceType TypS, 'Pozycja/Wartość' Typ, 'Polecenie księgowania' TypDokumentu 
,W.WyW_SlownikId kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Polecenie księgowania' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
 ,YEAR(Den_DataDok) DokumentRok ,MONTH(Den_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Den_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Den_DataOpe) PlatnoscRok,MONTH(DeN_DataOpe) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), DeN_DataOpe, 111), '/', '-')  AS PlatnoscDzien
,DeE_Kwota AS WartoscCalk
,DeN_PodmiotTyp, DeN_PodmiotID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.DekretyElem ON DeE_DeNId = W.WyW_DokumentId and DeE_Lp = W.WyW_LpPozycji
JOIN CDN.DekretyNag ON DeE_DeNId = DeN_DeNId AND DeE_AccWnId IS NOT NULL
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and DeN_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTypFZ = 20 -- Rejestr vat zakupu
set @dokumentTypFS = 21 -- Rejestr vat sprzedaży

INSERT INTO #tmpTrNWym 
select 6 as Paczka, VaN_Dokument AS [Dokument Numer],
20101 [Dokument Numer __PROCID__], VaN_VaNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
W.WyW_Wartosc WymiarWartosc,

W.Wyw_wywID WYWID,Vat_VanID VaNID,VaT_Lp VatLP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp in (@dokumentTypFZ, @dokumentTypFS) and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji,
0 KontoID,
WyW_SourceType TypS,
CASE WyW_SourceType
            WHEN 1 THen 'Pozycja/Kwota dodtakowa'
            WHEN 2 THen 'Pozycja/Netto'
            WHEN 3 THen 'Pozycja/Koszt'
            WHEN 4 THen 'Pozycja/VAT_KOSZT'
            WHEN 5 THen 'Dokument/Netto'
            WHEN 6 THen 'Dokument/Koszt'
            WHEN 7 THen 'Dokument/VAT_Koszt'
       END [Typ ]
, CASE W.WyW_DokumentTyp
           WHEN 20 THEN 'Rejestr vat zakupu'
           WHEN 21 THEN 'Rejestr vat sprzedaży'
    END TypDokumentu
    , W.WyW_DokumentTyp DokumentTyp
    ,YEAR(VaN_DataWys) DokumentRok ,MONTH(VaN_DataWys) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), VaN_DataWys, 111), '/', '-')  AS DokumentDzien
,YEAR(VaN_Termin) PlatnoscRok,MONTH(VaN_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), VaN_Termin, 111), '/', '-')  AS PlatnoscDzien
,Vat_netto + Vat_vat AS WartoscCalk
    ,Van_PodmiotTyp, VaN_PodID
    ,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.VatTab ON Vat_VanID = W.WyW_DokumentId and VaT_Lp = W.WyW_LpPozycji
JOIN CDN.VatNag ON VaN_VaNID = VaT_VaNID
where W.WyW_DokumentTyp in (@dokumentTypFZ, @dokumentTypFS) and W.WyW_WyyId = 0 and WyW_SourceType in (2,3,4)
and VaN_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

union all

select 6 as Paczka, CAST(VaN_Dokument AS nvarchar(260)) AS [Dokument Numer],
20101 [Dokument Numer __PROCID__], VaN_VaNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
W.WyW_Wartosc WymiarWartosc,

W.Wyw_wywID WYWID,
VaN_VanID VaNID,0 VatLP, 
W.WyW_Kwota / ISNULL((select count(*) FROM cdn.VatTab W1 where VaT_VaNID = VaN_VaNID),1.0) Kwota, W.wyw_procent / ISNULL((select count(*) FROM cdn.VatTab W1 where VaT_VaNID = VaN_VaNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W2 where W2.WyW_DokumentTyp in (@dokumentTypFZ, @dokumentTypFS) and W2.WyW_DokumentId = W.WyW_DokumentId and W2.WyW_LpPozycji = W.WyW_LpPozycji and W2.WyW_WyyId = 0 ) IloscPozycji,
0 KontoID,WyW_SourceType TypS,
CASE WyW_SourceType
            WHEN 1 THen 'Pozycja/Kwota dodatkowa'
            WHEN 2 THen 'Pozycja/Netto'
            WHEN 3 THen 'Pozycja/Koszt'
            WHEN 4 THen 'Pozycja/VAT_KOSZT'
            WHEN 5 THen 'Dokument/Netto'
            WHEN 6 THen 'Dokument/Koszt'
            WHEN 7 THen 'Dokument/VAT_Koszt'
       END [Typ ]
       , CASE W.WyW_DokumentTyp
           WHEN 20 THEN 'Rejestr vat zakupu'
           WHEN 21 THEN 'Rejestr vat sprzedaży'
    END TypDokumentu
    , W.WyW_DokumentTyp DokumentTyp
    ,YEAR(VaN_DataWys) DokumentRok ,MONTH(VaN_DataWys) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), VaN_DataWys, 111), '/', '-')  AS DokumentDzien
,YEAR(VaN_Termin) PlatnoscRok,MONTH(VaN_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), VaN_Termin, 111), '/', '-')  AS PlatnoscDzien
,VaN_RazemBrutto AS WartoscCalk
    ,Van_PodmiotTyp, Van_PodID
    ,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.VatNag ON VaN_VanID = W.WyW_DokumentId
where W.WyW_DokumentTyp in (@dokumentTypFZ, @dokumentTypFS) and W.WyW_WyyId = 0 and WyW_SourceType in (5,6,7)
and not exists (select * from cdn.WymiaryWartosci W2 where W2.WyW_DokumentTyp in (@dokumentTypFZ, @dokumentTypFS) and W2.WyW_DokumentId =  W.WyW_DokumentId and W2.WyW_WyyId = 0 and W2.WyW_LpPozycji<>0)
and VaN_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

--2019------------------------------------------------------------------------------------------------------------------------------

set @dokumentTyp = 3 -- Dokumenty wewnętrzne zakupu --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 7 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
29121 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Dokument wewnętrzny zakupu') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 8 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
29121 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Dokument wewnętrzny zakupu' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 4 -- Dokumenty wewnętrzne sprzedaży --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 9 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
29120 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Dokument wewnętrzny sprzedaży') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 10 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
29120 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Dokument wewnętrzny sprzedaży' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 5 -- Dokumenty TaxFree --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 11 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
29159 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Dokument TaxFree') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 12 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
29159 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Dokument TaxFree' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 6 -- Paragony --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 13 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
29048 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Paragon') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 14 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
29048 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Paragon' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 9 -- Przesunięcia międzymagazynowe --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 15 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
25034 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Przesunięcie międzymagazynowe') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 16 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
25034 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Przesunięcie międzymagazynowe' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 11 -- Przyjęcie wewnętrzne --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 17 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
25032 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Przyjęcie wewnętrzne') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 18 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
25032 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Przyjęcie wewnętrzne' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 12 -- Przyjęcie zewnętrzne --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 19 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
25024 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Przyjęcie zewnętrzne') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 20 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
25024 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Przyjęcie zewnętrzne' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 13 -- Rozchód wewnętrzny --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 21 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
25030 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Rozchód wewnętrzny') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 22 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
25030 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Rozchód wewnętrzny' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 14 -- Wydanie kaucji --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 23 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
25078 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Wydanie kaucji') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 24 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
25078 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Wydanie kaucji' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 15 -- Wydanie zewnętrzne --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 25 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
25022 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Wydanie zewnętrzne') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 26 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
25022 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Wydanie zewnętrzne' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 10 -- Przyjęcie kaucji --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 28 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
25079 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Przyjęcie kaucji') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 29 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
25079 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Przyjęcie kaucji' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 7 -- Kompletacja przyjęcie składników --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 30 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
25045 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Kompletacja przyjęcie składników') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 31 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
25045 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Kompletacja przyjęcie składników' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 8 -- Kompletacja rozchód składników --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 32 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer],
25046 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrE_TrNID TRNID,TrE_Lp TRELP, W.WyW_Kwota Kwota, W.wyw_procent  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.WymiaryWartosci W1 where W1.WyW_DokumentTyp =  @dokumentTyp and W1.WyW_DokumentId = W.WyW_DokumentId and W1.WyW_LpPozycji = W.WyW_LpPozycji and W1.WyW_WyyId = 0 ) IloscPozycji
,0 kontoID, W.WyW_SourceType TypS, 
CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, convert(varchar(100),'Kompletacja rozchód składników') TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrE_WartoscBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraElem ON TrE_TrNID = W.WyW_DokumentId and TrE_Lp = W.WyW_LpPozycji
JOIN CDN.TRaNag on TRN_TrNID = TRE_TRNID 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

INSERT INTO #tmpTrNWym
select 33 as Paczka, CAST(TrN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
25046 [Dokument Numer __PROCID__], TrN_TrNId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,TrN_TrNID TRNID,0 TRELP, W.WyW_Kwota Kwota ,
W.wyw_procent / ISNULL((select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID),1.0)  Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.TraElem W1 where TrE_TrNId = TrN_TrNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 1 THEN convert(varchar(100),'Pozycja/Wartość')
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Kompletacja rozchód składników' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(Trn_DataDok) DokumentRok ,MONTH(Trn_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), Trn_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(Trn_Termin) PlatnoscRok,MONTH(Trn_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), Trn_Termin, 111), '/', '-')  AS PlatnoscDzien
,TrN_RazemBrutto AS WartoscCalk
,TrN_PodmiotTyp, TrN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.TraNag ON TrN_TrNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and Trn_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 16 -- Ewidencja przychodów --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 34 as Paczka, CAST(EDN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
20116 [Dokument Numer __PROCID__], EDN_EDNID [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,EDN_EDNID TRNID,0 EDELP, W.WyW_Kwota Kwota ,
W.wyw_procent Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.EwidDodElem W1 where EDE_EDNID = EDN_EDNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Ewidencja przychodów' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(EDN_DataDok) DokumentRok ,MONTH(EDN_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), EDN_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(EDN_Termin) PlatnoscRok,MONTH(EDN_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), EDN_Termin, 111), '/', '-')  AS PlatnoscDzien
,EDN_KwotaRazemSys AS WartoscCalk
,EDN_PodmiotTyp, EDN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.EwidDodNag ON EDN_EDNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and EDN_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

set @dokumentTyp = 17 -- Ewidencja kosztów --------------------------------------------------------------------------------

INSERT INTO #tmpTrNWym
select 35 as Paczka, CAST(EDN_NumerPelny AS nvarchar(260)) [Dokument Numer], 
20116 [Dokument Numer __PROCID__], EDN_EDNID [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
 W.WyW_Wartosc WymiarWartosc,
W.Wyw_wywID WYWID,EDN_EDNID TRNID,0 EDELP, W.WyW_Kwota Kwota ,
W.wyw_procent Procent, W.Wyw_GUID as [GUID]
,(select count(*) FROM cdn.EwidDodElem W1 where EDE_EDNID = EDN_EDNID) Iloscpozycji
,0 kontoID, W.WyW_SourceType TypS, CASE W.WyW_SourceType
 WHEN 2 THEN  convert(varchar(100),'Dokument/Wartość') 
END Typ, 'Ewidencja kosztów' TypDokumentu , W.WyW_DokumentTyp DokumentTyp
,YEAR(EDN_DataDok) DokumentRok ,MONTH(EDN_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), EDN_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(EDN_Termin) PlatnoscRok,MONTH(EDN_Termin) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), EDN_Termin, 111), '/', '-')  AS PlatnoscDzien
,EDN_KwotaRazemSys AS WartoscCalk
,EDN_PodmiotTyp, EDN_PodID
,NULL AS Projekt
,NULL AS Dzial
FROM cdn.WymiaryWartosci W
JOIN CDN.EwidDodNag ON EDN_EDNID = W.WyW_DokumentId 
where W.WyW_DokumentTyp =  @dokumentTyp and W.WyW_WyyId = 0
and W.WYW_SourceType = 2
and EDN_DataOpe BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

--Wypłaty

INSERT INTO #tmpTrNWym
select 36 as Paczka, CAST(WPL_NumerPelny AS nvarchar(260)) [Dokument Numer], 
24020  [Dokument Numer __PROCID__], WPL_WplId [Dokument Numer __ORGID__],@bazaFirmowa [Dokument Numer __DATABASE__],
WPE_Nazwa WymiarWartosc,
0 WYWID,0 TRNID,0 EDELP, OPP_Brutto Kwota ,
opp_procent Procent, 0 as [GUID]
,1 Iloscpozycji
,0 kontoID, NULL TypS, 'Dokument/Wartość'
, 'Wypłata' TypDokumentu , NULL DokumentTyp
,YEAR(WPL_DataDok) DokumentRok ,MONTH(WPL_DataDok) DokumentMiesiac,REPLACE(CONVERT(VARCHAR(10), WPL_DataDok, 111), '/', '-')  AS DokumentDzien
,YEAR(WPL_DataDok) PlatnoscRok,MONTH(WPL_DataDok) PlatnoscMiesiac ,REPLACE(CONVERT(VARCHAR(10), WPL_DataDok, 111), '/', '-')  AS PlatnoscDzien
,Wpe_Wartosc AS WartoscCalk
,0, 0
,Prj_Nazwa AS  Projekt
,DZL_Nazwa AS  Dzial

from cdn.OpisPlace JOIN cdn.WypElementy ON OPP_WpeId = WPE_WpeId
join cdn.Wyplaty on WPL_WplId = WPE_WplId 
join cdn.DefProjekty  ON OPP_PrjId = PRJ_PrjId
JOIN cdn.Dzialy ON OPP_DzlId = DZL_DzlId
and WPL_DataDok BETWEEN convert(datetime,convert(varchar, @DATAOD, 120), 120)  AND convert(datetime,convert(varchar, @DATADO, 120), 120)

declare @sqlTxt nvarchar(max)

set @sqlTxt = N'select BAZ.Baz_Nazwa [Baza Firmowa], [Dokument Numer], WymiarWartosc as [Pozycja],Dzial AS [Dział], Projekt AS [Projekt],
Kwota as [Wartość],Procent as [Wymiar Procent], Typ as [Typ Pozycji], TypDokumentu as [Typ Dokumentu]
, DokumentRok as [Data Dokumentu Rok],DokumentMiesiac as [Data Dokumentu Miesiąc],DokumentMiesiac as [Data Dokumentu Dzień]
, PlatnoscRok as [Data Termin Płatności Rok],PlatnoscMiesiac as [Data Termin Płatności Miesiąc],PlatnoscDzien as [Data Termin Płatności Dzień], 
Knt_Kod [Kontrahent Kod], Knt_Nazwa1 [Kontrahent Nazwa],zal.Ope_Kod [Operator Wprowadzający],mod.Ope_Kod [Operator Modyfikujący],GETDATE() [Data Analizy]
 

----------KONTEKSTY
, [Dokument Numer __PROCID__], [Dokument Numer __ORGID__], [Dokument Numer __DATABASE__] 

'+@kolumny + '
from #tmpTrNWym
left join  #tmpWymiary Poz on WyW_DokumentId = TrNID  and WYW_GUID = GUID and WyW_LpPozycji =  TRELp 
left join CDN.Kontrahenci on Knt_KntId = PodmiotID and Knt_Podmiottyp = PodmiotTyp
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON Knt_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON Knt_OpeModID = mod.Ope_OpeId

order by TRNID, TRELP'

exec (@sqlTxt)

DROP TABLE #tmpWymiary
drop table #tmpTrNWym 







