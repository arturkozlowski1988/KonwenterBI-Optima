
/*
* Raport Handlowy
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

declare @wartosc1 varchar(20);
set @wartosc1 = case when @wartosc = 'Wartość Netto' then 'Tre_WartoscNetto' else 'Tre_WartoscZakupu' end;

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
declare @kolumny varchar(max)
declare @kolumny2 varchar(max)
declare @i int

set @kolumny = ''
set @kolumny2 = ''
set @i=0
while (@i<=@poziom_max)
begin
    set @kolumny = @kolumny + ',"Produkt Grupa Poziom ' + LTRIM(@i) + '" = CASE WHEN Poz.Poziom' +LTRIM(@i) + ' IS NULL THEN ''(NIEPRZYPISANE)'' ELSE Poz.Poziom' + LTRIM(@i) + ' END'
    set @kolumny2 = @kolumny2 + ',Poz.Poziom' +LTRIM(@i)
    set @i = @i + 1
end

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

--Właściwe zapytanie
set @select =
'SELECT 
    BAZ.Baz_Nazwa [Baza Firmowa], 
    MAX(Twr_Kod) [Produkt Kod], 
    MAX(Twr_Nazwa) [Produkt Nazwa],
    CASE TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca], 
    CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny], 
    ISNULL(NULLIF(Twr_JMZ,''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza],
    MAX(CASE
        WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa Prosta''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar Prosty''
        WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa Złożona''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar Złożony''
        ELSE ''(NIEOKREŚLONY)''
    END) [Produkt Typ],
    --ISNULL(Mag_Symbol,''(BRAK)'') [Magazyn Nazwa],
    ISNULL(MAX(Kat_KodOgolny),''(NIEOKREŚLONA)'')  [Produkt Kategoria Ogólna], ISNULL(MAX(Kat_KodSzczegol),''(NIEOKREŚLONA)'') [Produkt Kategoria Szczegółowa], MAX(Twr_JM) [Jednostka Miary], 
    "Ilość Stan Początkowy H"=0, "Ilość Stan Początkowy M"=0, 
    "Ilość FZ"=SUM(IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu=301 THEN 1 ELSE 0 END), 
    "Ilość FS"=SUM(IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu=302 THEN 1 ELSE 0 END), 
    "Ilość PA"=SUM(IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu=305 THEN 1 ELSE 0 END), 
    "Ilość PZ"=SUM( IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu=307 THEN 1 ELSE 0 END),
    "Ilość PKA"=SUM( IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu=313 THEN 1 ELSE 0 END),
    "Ilość PW"=SUM( IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu IN (310,303,317) THEN 1 ELSE 0 END),
    "Ilość MM OL"= SUM( IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu = 312 AND TrN_Rodzaj = 312010 THEN 1 ELSE 0 END),
    "Ilość WZ"=SUM( IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu=306 THEN 1 ELSE 0 END),
    "Ilość WKA"=SUM( IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu=314 THEN 1 ELSE 0 END),
    "Ilość RW"=SUM( IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu IN (304,318) THEN 1 ELSE 0 END),
    "Ilość MM LO"= SUM( IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu = 312 AND TrN_Rodzaj = 312100 THEN 1 ELSE 0 END),
    "Ilość MM"= SUM( IsNull(TrE_Ilosc,0)*CASE WHEN TrE_TypDokumentu = 312 AND TrN_Rodzaj IN (312000,312001,312008) THEN 1 ELSE 0 END),
    "Ilość Stan Początkowy H Jednostka Pomocnicza"=0, "Ilość Stan Początkowy M Jednostka Pomocnicza"=0, 
    "Ilość FZ Jednostka Pomocnicza"=SUM(IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu=301 THEN 1 ELSE 0 END), 
    "Ilość FS Jednostka Pomocnicza"=SUM(IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu=302 THEN 1 ELSE 0 END), 
    "Ilość PA Jednostka Pomocnicza"=SUM(IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu=305 THEN 1 ELSE 0 END), 
    "Ilość PZ Jednostka Pomocnicza"=SUM( IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu=307 THEN 1 ELSE 0 END),
    "Ilość PKA Jednostka Pomocnicza"=SUM( IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu=313 THEN 1 ELSE 0 END),
    "Ilość PW Jednostka Pomocnicza"=SUM( IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu IN (310,303,317) THEN 1 ELSE 0 END),
    "Ilość MM OL Jednostka Pomocnicza"= SUM( IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu = 312 AND TrN_Rodzaj = 312010 THEN 1 ELSE 0 END),
    "Ilość WZ Jednostka Pomocnicza"=SUM( IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu=306 THEN 1 ELSE 0 END),
    "Ilość WKA Jednostka Pomocnicza"=SUM( IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu=314 THEN 1 ELSE 0 END),
    "Ilość RW Jednostka Pomocnicza"=SUM( IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu IN (304,318) THEN 1 ELSE 0 END),
    "Ilość MM LO Jednostka Pomocnicza"= SUM( IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu = 312 AND TrN_Rodzaj = 312100 THEN 1 ELSE 0 END),
    "Ilość MM Jednostka Pomocnicza"= SUM( IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu = 312 AND TrN_Rodzaj IN (312000,312001,312008) THEN 1 ELSE 0 END),
    "Wartość Stan Początkowy H"=0, "Wartość Stan Początkowy M"=0, 
    "Wartość FZ"=SUM(IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu=301 THEN 1 ELSE 0 END), 
    "Wartość FS"=SUM(IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu=302 THEN 1 ELSE 0 END), 
    "Wartość PA"=SUM(IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu=305 THEN 1 ELSE 0 END), 
    "Wartość PZ"=SUM( IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu=307 THEN 1 ELSE 0 END),
    "Wartość PKA"=SUM( IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu=313 THEN 1 ELSE 0 END),
    "Wartość PW"=SUM( IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu IN (310,303,317) THEN 1 ELSE 0 END),
    "Wartość MM OL"= SUM( IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu = 312 AND TrN_Rodzaj = 312010 THEN 1 ELSE 0 END),
    "Wartość WZ"=SUM( IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu=306 THEN 1 ELSE 0 END),
    "Wartość WKA"=SUM( IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu=314 THEN 1 ELSE 0 END),
    "Wartość RW"=SUM( IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu IN (304,318) THEN 1 ELSE 0 END),
    "Wartość MM LO"= SUM( IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu = 312 AND TrN_Rodzaj = 312100 THEN 1 ELSE 0 END),
    "Wartość MM"= SUM( IsNull(' + @wartosc1 + ',0)*CASE WHEN TrE_TypDokumentu = 312 AND TrN_Rodzaj IN (312000,312001,312008) THEN 1 ELSE 0 END),
    "Operator Wprowadzający" = zal.Ope_Kod,
    "Operator Modyfikujący" = mod.Ope_Kod,
    "Data Analizy" = GETDATE()
    ----------KONTEKSTY
    ,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__], '''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__],'''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]

' + @kolumny + 
' FROM CDN.Towary
    LEFT OUTER JOIN cdn.TraElem ON TrE_TwrID=Twr_TwrID
    LEFT OUTER JOIN cdn.TraNag  ON TrN_TrNID=TrE_TrNID
    LEFT OUTER JOIN cdn.Magazyny ON Mag_MagID=ISNULL([TrN_MagDocId],TrN_MagZrdID)
    LEFT OUTER JOIN cdn.Kategorie ON Kat_KatID=Twr_KatID
    LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
    LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON Twr_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON Twr_OpeModID = mod.Ope_OpeId
WHERE (TrN_Bufor<>-1  
--AND TrN_Korekta IN (0,1) 
OR TrN_TrNID IS NULL)
    AND (((TrE_TypDokumentu IN (302,304,305,306,314,318) OR TrN_Rodzaj IN (312100)
    OR ((TrE_TypDokumentu IN (301,310,303,307,313,317) OR TrN_Rodzaj IN (312010) OR TrN_Rodzaj IN (312000,312001,312008)) AND TrN_Bufor=0)) 
    AND TrE_Aktywny<>0) OR TrE_TrEID IS NULL)
    AND (TrN_DataOpe BETWEEN CONVERT(DATETIME,''' + CONVERT(VARCHAR,@DATAOD,120) + ''',120) AND CONVERT(DATETIME,''' + CONVERT(VARCHAR,@DATADO,120) + ''',120) OR TrE_TrEID IS NULL)  
GROUP BY BAZ.Baz_Nazwa, Twr_TwrID, Twr_NieAktywny, TWR_SWW, knt4.Knt_Kod, Twr_JMZ, Mag_Symbol, Mag_MagId, zal.Ope_Kod, mod.Ope_Kod' + @kolumny2 + '

UNION ALL

SELECT 
    BAZ.Baz_Nazwa [Baza Firmowa], 
    MAX(Twr_Kod) [Produkt Kod], 
    MAX(Twr_Nazwa) [Produkt Nazwa],
    CASE TWR_SWW WHEN '' '' THEN ''(NIEPRZYPISANE)'' ELSE ISNULL(TWR_SWW,''(NIEPRZYPISANE)'') END [Produkt PKWiU],
    ISNULL(knt4.Knt_Kod, ''(NIEPRZYPISANE)'')  [Produkt Dostawca],
    CASE Twr_NieAktywny WHEN 0 THEN ''Tak'' ELSE ''Nie'' END [Produkt Aktywny], 
    ISNULL(NULLIF(Twr_JMZ,''''), ''(BRAK)'') [Produkt Jednostka Miary Pomocnicza],
    MAX(CASE
        WHEN Twr_Typ = 0 AND Twr_Produkt = 0 THEN ''Usługa Prosta''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 0 THEN ''Towar Prosty''
        WHEN Twr_Typ = 0 AND Twr_Produkt = 1 THEN ''Usługa Złożona''
        WHEN Twr_Typ = 1 AND Twr_Produkt = 1 THEN ''Towar Złożony''
        ELSE ''(NIEOKREŚLONY)''
    END) [Produkt Typ],
    --ISNULL(Mag_Symbol,''(BRAK)'') [Magazyn Nazwa],
    ISNULL(MAX(Kat_KodOgolny),''(NIEOKREŚLONA)'') [Produkt Kategoria Ogólna], ISNULL(MAX(Kat_KodSzczegol),''(NIEOKREŚLONA)'')  [Produkt Kategoria Szczegółowa], MAX(Twr_JM) [Jednostka Miary], 
    "Ilość Stan Początkowy H"=SUM(IsNull(TrE_Ilosc,0)*CASE WHEN TRN_Rodzaj = 312010 then 1  WHEN TRN_Rodzaj = 312100 THEN -1 WHEN TrE_TypDokumentu=301 THEN 1 WHEN TrE_TypDokumentu IN (302,305) THEN -1 ELSE 0 END), 
    "Ilość Stan Początkowy M"=SUM(IsNull(TrE_Ilosc,0)*CASE WHEN TRN_Rodzaj = 312010 then 1  WHEN TRN_Rodzaj = 312100 THEN -1 WHEN TrE_TypDokumentu IN (310,303,307,313,317) THEN 1 WHEN TrE_TypDokumentu IN (301,302,305,312) THEN 0 ELSE -1 END), 
    "Ilość FZ"=0, "Ilość FS"=0, "Ilość PA"=0, "Ilość PZ"=0, "Ilość PKA"=0, "Ilość PW"=0, "Ilość MM OL"=0, "Ilość WZ"=0, "Ilość WKA"=0, "Ilość RW"=0, "Ilość MM LO"=0,
    "Ilość MM" = 0,
    "Ilość Stan Początkowy H Jednostka Pomocnicza"=SUM(IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TrE_TypDokumentu=301 THEN 1 WHEN TrE_TypDokumentu IN (302,305) THEN -1 ELSE 0 END),
     "Ilość Stan Początkowy M Jednostka Pomocnicza"=SUM(IsNull(TrE_Ilosc*Twr_JMPrzelicznikM/Twr_JMPrzelicznikL,0)*CASE WHEN TRN_Rodzaj = 312010 then 1  WHEN TRN_Rodzaj = 312100 THEN -1  WHEN TrE_TypDokumentu IN (310,303,307,313,317) THEN 1 WHEN TrE_TypDokumentu IN (301,302,305,312) THEN 0 ELSE -1 END),  
    "Ilość FZ Jednostka Pomocnicza"=0, "Ilość FS Jednostka Pomocnicza"=0,   "Ilość PA Jednostka Pomocnicza"=0, "Ilość PZ Jednostka Pomocnicza"=0,   "Ilość PKA Jednostka Pomocnicza"=0, "Ilość PW Jednostka Pomocnicza"=0, "Ilość MM OL Jednostka Pomocnicza"=0, 
    "Ilość WZ Jednostka Pomocnicza"=0,  "Ilość WKA Jednostka Pomocnicza"=0, "Ilość RW Jednostka Pomocnicza"=0, "Ilość MM LO Jednostka Pomocnicza"=0,
    "Ilość MM Jednostka Pomocnicza" = 0,
    "Wartość Stan Początkowy H"=SUM(IsNull(' + @wartosc1 + ',''0'')*CASE WHEN TrE_TypDokumentu=301 THEN 1 WHEN TrE_TypDokumentu IN (302,305) THEN -1 ELSE 0 END), 
    "Wartość Stan Początkowy M"=SUM(IsNull(' + @wartosc1 + ',''0'')*CASE WHEN TRN_Rodzaj = 312010 then 1  WHEN TRN_Rodzaj = 312100 THEN -1 WHEN TrE_TypDokumentu IN (310,303,307,313,317) THEN 1 WHEN TrE_TypDokumentu IN (301,302,305,312) THEN 0 ELSE -1 END), 
    "Wartość FZ"=0, "Wartość FS"=0, "Wartość PA"=0, "Wartość PZ"=0, "Wartość PKA"=0, "Wartość PW"=0, "Wartość MM OL"=0, "Wartość WZ"=0, "Wartość WKA"=0, "Wartość RW"=0, "Wartość MM LO"=0,
    "Wartość MM"=0,
    "Operator Wprowadzający" = zal.Ope_Kod,
    "Operator Modyfikujący" = mod.Ope_Kod,
    "Data Analizy" = GETDATE()
    ----------KONTEKSTY
    ,25003 [Produkt Kod __PROCID__Towary__], Twr_twrId [Produkt Kod __ORGID__], '''+@bazaFirmowa+''' [Produkt Kod __DATABASE__]
    ,25003 [Produkt Nazwa __PROCID__], Twr_twrId [Produkt Nazwa __ORGID__], '''+@bazaFirmowa+''' [Produkt Nazwa __DATABASE__]

' + @kolumny + 
' FROM CDN.Towary
    LEFT OUTER JOIN cdn.TraElem ON TrE_TwrID=Twr_TwrID
    LEFT OUTER JOIN cdn.TraNag  ON TrN_TrNID=TrE_TrNID
    LEFT OUTER JOIN cdn.Magazyny ON Mag_MagID=TrN_MagZrdID
    LEFT OUTER JOIN cdn.Kategorie ON Kat_KatID=Twr_KatID
    LEFT JOIN #tmpTwrGr Poz ON Twr_TwGGIDNumer = Poz.gidNumer
    LEFT JOIN CDN.Kontrahenci knt4 ON Twr_KntId = knt4.Knt_KntId
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
    LEFT JOIN ' + @Operatorzy + ' zal ON Twr_OpeZalID = zal.Ope_OpeId
    LEFT JOIN ' + @Operatorzy + ' mod ON Twr_OpeModID = mod.Ope_OpeId
WHERE (TrN_Bufor<>-1 
--AND TrN_Korekta IN (0,1) 
OR TrN_TrNID IS NULL)
    AND (((TrE_TypDokumentu IN (302,304,305,306,314,318) OR TrN_Rodzaj IN (312100)
    OR ((TrE_TypDokumentu IN (301,310,303,307,313,317) OR TrN_Rodzaj IN (312010) OR TrN_Rodzaj IN (312000,312001,312008)) AND TrN_Bufor=0)) 
    AND TrE_Aktywny<>0) OR TrE_TrEID IS NULL)
    AND (TrN_DataOpe < CONVERT(DATETIME,''' + CONVERT(VARCHAR,@DATAOD, 120) + ''',120) OR TrE_TrEID IS NULL)  
GROUP BY BAZ.Baz_Nazwa, Twr_TwrID, Twr_NieAktywny, TWR_SWW, knt4.Knt_Kod, Twr_JMZ, zal.Ope_Kod, mod.Ope_Kod' + @kolumny2

exec (@select)

DROP TABLE #tmpTwrGr




