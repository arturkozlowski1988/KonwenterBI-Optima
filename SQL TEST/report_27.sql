/*
* Raport Obiegu Dokumentów
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @bazaFirmowa varchar(max);
DECLARE @Etapy varchar(max);
DECLARE @Operatorzy varchar(max), @sql varchar(max);
DECLARE @Bazy varchar(max);
SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @bazaFirmowa = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1)
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]'
SET @Etapy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[SekEtapy]'
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 

--Tworzenie tabeli z serią dokumentów
SELECT DDf_DDfID, 
  CASE 
     WHEN DDf_Numeracja like '@rejestr%' THEN 5
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 1) = '@rejestr' THEN 1
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 2) = '@rejestr' THEN 2
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 3) = '@rejestr' THEN 3
     WHEN PARSENAME(REPLACE(REPLACE(REPLACE(substring(ddf_numeracja,CHARINDEX('/',ddf_numeracja,0)+1,50), '@brak/',''), '/@brak',''), '/', '.'), 4) = '@rejestr' THEN 4
    END  [seria]  INTO #tmpSeria FROM CDN.DokDefinicje

SET @sql =
'
----ETAPY

SELECT 
BAZ.Baz_Nazwa [Baza Firmowa],
[Dokument Obiegu Seria] =
CASE when isnull(ser.seria,0) = 5 then 
substring(DoN_NumerPelny,0,CHARINDEX(''/'',DoN_NumerPelny,0))
ELSE 
ISNULL(PARSENAME(REPLACE(substring(DoN_NumerPelny,CHARINDEX(''/'',DoN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
END,
[Dokument Obiegu Numer] = DoN_NumerPelny,
[Dokument Obiegu Data Wprowadzenia] = CONVERT(VARCHAR(10), DoN_DataDok, 20),
[Dokument Obiegu Tytuł] = ISNULL(DoN_Tytul,''(BRAK)''),
[Dokument Obiegu Opis] = ISNULL(DoN_Dotyczy,''(BRAK)''),
[Dokument Obiegu Typ] = CASE DoN_Typ WHEN 1 THEN ''Firmowy'' ELSE ''Wspólny'' END,
[Dokument Obiegu Proces Obiegu] = ISNULL(DoN_ProcesKod,''(BRAK)''),
[Dokument Obiegu Numer Obcy] = ISNULL(DoN_NumerObcy,''(BRAK)''),
[Operator Tworzący Zapis] = DoN_OpeModKod,
[Operator Modyfikujący Zapis] = DoN_OpeZalKod,
[Dokument Obiegu Ilość] = NULL,
[Dokument Obiegu Ilość Dokumentów Powiązanych] = NULL,
[Dokument Obiegu Ilość Kontrahentów] = NULL,
[Kontrahent Kod] = NULL,
[Kontrahent Nazwa] = NULL,
[Dokument Powiązany Typ] = NULL,
[Dokument Powiązany Numer] = NULL,
[Dokument Powiązany Wartość] = NULL,
---ETAP BIEŻĄCY
[Etap Symbol] = eb2.SE_Symbol,
[Etap Nazwa] = eb2.SE_Nazwa,
[Etap Poziom] = CASE DnPr_Poziom WHEN 1 THEN ''Główny'' ELSE ''Powiązany'' END,
[Etap Obowiązkowy] = CASE DnE_Obowiazkowy WHEN 0 THEN ''Nie'' ELSE ''Tak'' END,
[Etap Wykonany] = CASE DnE_Wykonany WHEN 0 THEN ''Nie'' WHEN 1 THEN ''Tak'' WHEN 3 THEN ''Bieżący'' ELSE ''Pominięty'' END,
[Etap Bieżący Symbol] = eb1.SE_Symbol,
[Etap Bieżący Nazwa] = eb1.SE_Nazwa,
[Etap Termin Wykonania] = CONVERT(VARCHAR(10), DnE_TerminWykonania, 20),
[Etap Data Rozpoczęcia] = CONVERT(VARCHAR(10), Data1, 20),
[Etap Data Zakończenia] = CONVERT(VARCHAR(10), Data2, 20),
[Etap Czas Trwania] = CzasEtapu,
[Etap Ilość] = EtapIlosc,
---HISTORIA
[Etap Data Zmiany] = NULL,
[Operator Kod] = DoN_OpeModKod,
[Operator Komentarz] = NULL,
[Etap Przed Zmianą] = NULL,
[Etap Po Zmianie] = NULL,
[Operacja Typ] = NULL,
[Operacja Ilość] = NULL,
[Operator Wprowadzający] = zal.Ope_Kod,
[Operator Modyfikujący] = mod.Ope_Kod,
[Data Analizy] = GETDATE()
----------KONTEKSTY
,[Dokument Obiegu Numer __PROCID__] = 25106
,[Dokument Obiegu Numer __ORGID__] = DoN_DoNID

FROM CDN.DokNag
LEFT JOIN #tmpSeria ser ON DoN_DDfId = DDf_DDfID
left join CDN.DokNagProcesEtapy ON DnPr_DoNID = DoN_DoNID 
left join CDN.DokNagEtapy ON DnPr_DnPrID = DnE_DnPrID 
left join ' + @Etapy + ' eb1 ON eb1.SE_SEID = DoN_EtapBiezacyLp 
left join ' + @Etapy + ' eb2 ON eb2.SE_SEID = DnE_EtapID
left join ' + @Operatorzy + ' ON DnE_OpeId = Ope_OpeID
left join (SELECT
[EtapIleID] = DnE_DnEId,
[EtapIlosc] = COUNT(DnE_DnEId)
FROM CDN.DokNag
left join CDN.DokNagProcesEtapy ON DnPr_DoNID = DoN_DoNID 
left join CDN.DokNagEtapy ON DnPr_DnPrID = DnE_DnPrID
GROUP BY DnE_DnEId) h ON EtapIleID = DnE_DnEId

left join
-----WYLICZENIE CZASU TRWANIA ETAPU
(
SELECT * FROM
(
SELECT 
[EtapID] = DnE_DnEId,
[DokID] = DoN_DoNID,
[Data1] = CASE WHEN DnE_EtapID=1 AND DnE_Wykonany=1 THEN DnE_TerminOd WHEN DnE_EtapID<>1 AND DnE_Wykonany=1 THEN Data1 ELSE NULL END,
[Data2] = Data2,
[CzasEtapu] = CASE
WHEN eb2.SE_Symbol = DnEH_SymbolPrzed AND DnE_EtapID=1 THEN DATEDIFF(hh,DnE_TerminOd,Data2)
WHEN eb2.SE_Symbol = DnEH_SymbolPrzed AND DnE_EtapID<>1 THEN DATEDIFF(hh,Data1,Data2)
END
FROM CDN.DokNag
left join CDN.DokNagEtapyHistoria ON DnEH_DoNID = DoN_DoNID 
left join CDN.DokNagProcesEtapy ON DnPr_DoNID = DoN_DoNID 
left join CDN.DokNagEtapy ON DnPr_DnPrID = DnE_DnPrID
left join ' + @Etapy + ' eb2 ON eb2.SE_SEID = DnE_EtapID
left join
(
SELECT
[D2ID] = DnE_DnEId,
[D2DokID] = DoN_DoNID,
[Data2] = MAX(DnEH_DataZmiany)
FROM CDN.DokNag
left join CDN.DokNagEtapyHistoria ON DnEH_DoNID = DoN_DoNID 
left join CDN.DokNagProcesEtapy ON DnPr_DoNID = DoN_DoNID 
left join CDN.DokNagEtapy ON DnPr_DnPrID = DnE_DnPrID
left join ' + @Etapy + ' eb2 ON eb2.SE_SEID = DnE_EtapID
left join CDN.DokNagEtapyKolejne ON DnEK_DnPrID = DnPr_DnPrID AND DnEK_DnPrID = DnE_DnPrID
WHERE (DnEH_Typ IN(3,5) AND DnE_Wykonany = 1 AND eb2.SE_Symbol = DnEH_SymbolPrzed)
GROUP BY DnE_DnEId, DoN_DoNID
) f ON DnE_DnEId = D2ID AND D2DokID = DoN_DoNID
left join 
( 
SELECT
[D1ID] = DnE_DnEId,
[D1DokID] = DoN_DoNID,
[Data1] = MIN(DnEH_DataZmiany)
FROM CDN.DokNag
left join CDN.DokNagEtapyHistoria ON DnEH_DoNID = DoN_DoNID 
left join CDN.DokNagProcesEtapy ON DnPr_DoNID = DoN_DoNID 
left join CDN.DokNagEtapy ON DnPr_DnPrID = DnE_DnPrID
left join ' + @Etapy + ' eb2 ON eb2.SE_SEID = DnE_EtapID
WHERE DnEH_Typ IN(3,5) AND DnE_Wykonany = 1 AND eb2.SE_Symbol = DnEH_Symbolpo
GROUP BY DnE_DnEId, DoN_DoNID
) j ON DnE_DnEId = D1ID AND D1DokID = DoN_DoNID
WHERE DnEH_Typ IN(3,5) AND DnE_Wykonany = 1 
) 
g WHERE [CzasEtapu] IS NOT NULL)
j ON EtapID = DnE_DnEId AND DokID = DoN_DoNID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON DoN_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON DoN_OpeModID = mod.Ope_OpeId

UNION

----ETAPY HIST

SELECT 
BAZ.Baz_Nazwa [Baza Firmowa],
[Dokument Obiegu Seria] =
CASE when isnull(ser.seria,0) = 5 then 
substring(DoN_NumerPelny,0,CHARINDEX(''/'',DoN_NumerPelny,0))
ELSE 
ISNULL(PARSENAME(REPLACE(substring(DoN_NumerPelny,CHARINDEX(''/'',DoN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
END,
[Dokument Obiegu Numer] = DoN_NumerPelny,
[Dokument Obiegu Data Wprowadzenia] = CONVERT(VARCHAR(10), DoN_DataDok, 20),
[Dokument Obiegu Tytuł] = ISNULL(DoN_Tytul,''(BRAK)''),
[Dokument Obiegu Opis] = ISNULL(DoN_Dotyczy,''(BRAK)''),
[Dokument Obiegu Typ] = CASE DoN_Typ WHEN 1 THEN ''Firmowy'' ELSE ''Wspólny'' END,
[Dokument Obiegu Proces Obiegu] = ISNULL(DoN_ProcesKod,''(BRAK)''),
[Dokument Obiegu Numer Obcy] = ISNULL(DoN_NumerObcy,''(BRAK)''),
[Operator Tworzący Zapis] = DoN_OpeModKod,
[Operator Modyfikujący Zapis] = DoN_OpeZalKod,
[Dokument Obiegu Ilość] = NULL,
[Dokument Obiegu Ilość Dokumentów Powiązanych] = NULL,
[Dokument Obiegu Ilość Kontrahentów] = NULL,
[Kontrahent Kod] = NULL,
[Kontrahent Nazwa] = NULL,
[Dokument Powiązany Typ] = NULL,
[Dokument Powiązany Numer] = NULL,
[Dokument Powiązany Wartość] = NULL,
---ETAP BIEŻĄCY
[Etap Symbol] = NULL,
[Etap Nazwa] = NULL,
[Etap Poziom] = NULL,
[Etap Obowiązkowy] = NULL,
[Etap Wykonany] = NULL,
[Etap Bieżący Symbol] = eb1.SE_Symbol,
[Etap Bieżący Nazwa] = eb1.SE_Nazwa,
[Etap Termin Wykonania] = NULL,
[Etap Data Rozpoczęcia] = NULL,
[Etap Data Zakończenia] = NULL,
[Etap Czas Trwania] = NULL,
[Etap Ilość] = NULL,
---HISTORIA
[Etap Data Zmiany] = CONVERT(VARCHAR(10), DnEH_DataZmiany, 20),
[Operator Kod] = DnEH_OpeKod,
[Operator Komentarz] = DnEH_Komentarz,
[Etap Przed Zmianą] = DnEH_SymbolPrzed,
[Etap Po Zmianie] = DnEH_SymbolPo,
[Operacja Typ] = CASE DnEH_Typ
WHEN 1 THEN ''Dodanie nowego etapu''
WHEN 2 THEN ''Wycofanie do poprzedniego etapu''
WHEN 3 THEN ''Przejście do kolejnego etapu''
WHEN 4 THEN ''Powrót do poprzedniego etapu''
WHEN 5 THEN ''Zakończenie procesu''
END,
[Operacja Ilość] = ZmianaIlosc,
[Operator Wprowadzający] = zal.Ope_Kod,
[Operator Modyfikujący] = mod.Ope_Kod,
[Data Analizy] = GETDATE()

----------KONTEKSTY
,[Dokument Obiegu Numer __PROCID__] = 25106
,[Dokument Obiegu Numer __ORGID__] = DoN_DoNID

FROM CDN.DokNag
LEFT JOIN #tmpSeria ser ON DoN_DDfId = DDf_DDfID
left join CDN.DokNagEtapyHistoria ON DnEH_DoNID = DoN_DoNID 
left join CDN.DokNagProcesEtapy ON DnPr_DoNID = DoN_DoNID 
left join CDN.DokNagEtapy ON DnPr_DnPrID = DnE_DnPrID
left join ' + @Etapy + ' eb1 ON eb1.SE_SEID = DoN_EtapBiezacyLp 
left join ' + @Etapy + ' eb2 ON eb2.SE_SEID = DnE_EtapID
left join (SELECT
[ZmianaIleID] = DnEH_DnEHID,
[ZmianaIlosc] = COUNT(DnEH_DnEHID)
FROM CDN.DokNag
left join CDN.DokNagEtapyHistoria ON DnEH_DoNID = DoN_DoNID 
GROUP BY DnEH_DnEHID) h ON ZmianaIleID = DnEH_DnEHID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON DoN_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON DoN_OpeModID = mod.Ope_OpeId
WHERE DnEH_DnEHID IS NOT NULL

UNION ALL

----DOKUMENTY OBD

SELECT
BAZ.Baz_Nazwa [Baza Firmowa],
[Dokument Obiegu Seria] =
CASE when isnull(ser.seria,0) = 5 then 
substring(DoN_NumerPelny,0,CHARINDEX(''/'',DoN_NumerPelny,0))
ELSE 
ISNULL(PARSENAME(REPLACE(substring(DoN_NumerPelny,CHARINDEX(''/'',DoN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
END,
[Dokument Obiegu Numer] = DoN_NumerPelny,
[Dokument Obiegu Data Wprowadzenia] = CONVERT(VARCHAR(10), DoN_DataDok, 20),
[Dokument Obiegu Tytuł] = ISNULL(DoN_Tytul,''(BRAK)''),
[Dokument Obiegu Opis] = ISNULL(DoN_Dotyczy,''(BRAK)''),
[Dokument Obiegu Typ] = CASE DoN_Typ WHEN 1 THEN ''Firmowy'' ELSE ''Wspólny'' END,
[Dokument Obiegu Proces Obiegu] = ISNULL(DoN_ProcesKod,''(BRAK)''),
[Dokument Obiegu Numer Obcy] = ISNULL(DoN_NumerObcy,''(BRAK)''),
[Operator Tworzący Zapis] = DoN_OpeModKod,
[Operator Modyfikujący Zapis] = DoN_OpeZalKod,
[Dokument Obiegu Ilość] = OBDIle,
[Dokument Obiegu Ilość Dokumentów Powiązanych] = NULL,
[Dokument Obiegu Ilość Kontrahentów] = NULL,
[Kontrahent Kod] = NULL,
[Kontrahent Nazwa] = NULL,
[Dokument Powiązany Typ] = NULL,
[Dokument Powiązany Numer] = NULL,
[Dokument Powiązany Wartość] = NULL,
---ETAP BIEŻĄCY
[Etap Symbol] = NULL,
[Etap Nazwa] = NULL,
[Etap Poziom] = NULL,
[Etap Obowiązkowy] = NULL,
[Etap Wykonany] = NULL,
[Etap Bieżący Symbol] = eb1.SE_Symbol,
[Etap Bieżący Nazwa] = eb1.SE_Nazwa,
[Etap Termin Wykonania] = NULL,
[Etap Data Rozpoczęcia] = NULL,
[Etap Data Zakończenia] = NULL,
[Etap Czas Trwania] = NULL,
[Etap Ilość] = NULL,
---HISTORIA
[Etap Data Zmiany] = NULL,
[Operator Kod] = NULL,
[Operator Komentarz] = NULL,
[Etap Przed Zmianą] = NULL,
[Etap Po Zmianie] = NULL,
[Operacja Typ] = NULL,
[Operacja Ilość] = NULL,
[Operator Wprowadzający] = zal.Ope_Kod,
[Operator Modyfikujący] = mod.Ope_Kod,
[Data Analizy] = GETDATE()
----------KONTEKSTY
,[Dokument Obiegu Numer __PROCID__] = 25106
,[Dokument Obiegu Numer __ORGID__] = DoN_DoNID

FROM CDN.DokNag
LEFT JOIN #tmpSeria ser ON DoN_DDfId = DDf_DDfID
left join ' + @Etapy + ' eb1 ON eb1.SE_SEID = DoN_EtapBiezacyLp 
left join
(SELECT [OBDIleID] = DoN_DoNID,[OBDIle] = COUNT(DoN_DoNID) FROM CDN.DokNag GROUP BY DoN_DoNID) a ON OBDIleID = DoN_DoNID
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON DoN_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON DoN_OpeModID = mod.Ope_OpeId

UNION ALL

----DOKUMENTY POWIĄZANE I ICH WARTOŚCI
SELECT
BAZ.Baz_Nazwa [Baza Firmowa],
[Dokument Obiegu Seria] =
CASE when isnull(ser.seria,0) = 5 then 
substring(DoN_NumerPelny,0,CHARINDEX(''/'',DoN_NumerPelny,0))
ELSE 
ISNULL(PARSENAME(REPLACE(substring(DoN_NumerPelny,CHARINDEX(''/'',DoN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
END,
[Dokument Obiegu Numer] = DoN_NumerPelny,
[Dokument Obiegu Data Wprowadzenia] = CONVERT(VARCHAR(10), DoN_DataDok, 20),
[Dokument Obiegu Tytuł] = ISNULL(DoN_Tytul,''(BRAK)''),
[Dokument Obiegu Opis] = ISNULL(DoN_Dotyczy,''(BRAK)''),
[Dokument Obiegu Typ] = CASE DoN_Typ WHEN 1 THEN ''Firmowy'' ELSE ''Wspólny'' END,
[Dokument Obiegu Proces Obiegu] = ISNULL(DoN_ProcesKod,''(BRAK)''),
[Dokument Obiegu Numer Obcy] = ISNULL(DoN_NumerObcy,''(BRAK)''),
[Operator Tworzący Zapis] = DoN_OpeModKod,
[Operator Modyfikujący Zapis] = DoN_OpeZalKod,
[Dokument Obiegu Ilość] = NULL,
[Dokument Obiegu Ilość Dokumentów Powiązanych] = DokIlosc,
[Dokument Obiegu Ilość Kontrahentów] = NULL,
[Kontrahent Kod] = NULL,
[Kontrahent Nazwa] = NULL,
[Dokument Powiązany Typ] = 
CASE DoR_DokumentTyp
WHEN 302 THEN ''Fak. sprzedaży'' WHEN 301 THEN ''Fak. zakupu'' WHEN 305 THEN ''Paragon'' WHEN 320 THEN ''Faktura pro forma'' WHEN 308 THEN ''Rezerwacja obiorcy''
WHEN 309 THEN ''Zamówienie dostawcy'' WHEN 322 THEN ''Faktura wewnętrzna sprzedaży'' WHEN 321 THEN ''Faktura wewnętrzna zakupu'' WHEN 350 THEN ''Faktura rolnik rycza?towy'' 
WHEN 345 THEN ''Tax Free'' WHEN 306 THEN ''Wydanie zewnętrzne'' WHEN 307 THEN ''Przyjęcie zewnętrzne'' WHEN 304 THEN ''Rozchód wewnętrzny'' WHEN 303 THEN ''Przyjęcie wewnętrzne''
WHEN 312 THEN ''Przesunięcie między-magazynowe'' WHEN 310 THEN ''Bilnas otwarcia magazynu'' WHEN 311 THEN ''Arkusz inwentaryzacyjny'' WHEN 317 THEN ''Przyjęcie wewnętrzne produktu''
WHEN 318 THEN ''Rozchód wewnętrzny produktu'' WHEN 314 THEN ''Wydanie kaucji'' WHEN 313 THEN ''Przyjęcie kaucji'' WHEN 380 THEN ''Awizo ECOD'' WHEN 700 THEN ''Kontakt CRM'' 
WHEN 999 THEN ''Rejestr VAT'' WHEN 900 THEN ''Zlecenie serwisowe''  
WHEN 1003 THEN ''Ewidencja dodatkowa'' WHEN 1004 THEN ''Środek Trwały'' WHEN 1005 THEN ''Wyposażenie'' WHEN 1122 THEN ''Raport KB'' WHEN 1000 THEN ''Zapis kasowy'' WHEN 1001 THEN ''Zdarzenie w preliminarzu''
WHEN 1145 THEN ''Kompensata'' WHEN 1002 THEN ''Ponaglenie zapłaty KB'' WHEN 223 THEN ''Potwierdzenie salda KB'' WHEN 111 THEN ''Nota odsetkowa KB'' WHEN 114 THEN ''Delegacja'' 
WHEN 112 THEN ''Ponaglenie zapłaty KH'' WHEN 113 THEN ''Nota odsetkowa KH'' WHEN 111 THEN ''Potwierdzenie salda KH'' ELSE ''(BRAK)'' END,
[Dokument Powiązany Numer] = CASE DoR_DokumentTyp
WHEN 900 THEN SrZ_NumerPelny 
WHEN 700 THEN CRK_NumerPelny 
WHEN 999 THEN VaN_Dokument 
WHEN 1003 THEN EDN_NumerPelny
WHEN 1004 THEN SrT_NrInwent
WHEN 1005 THEN Wyp_NrInwent
WHEn 1122 THEN BRp_NumerPelny
WHEN 1000 THEN BZp_NumerPelny
WHEN 1001 THEN BZd_NumerPelny
WHEN 1145 THEN KPN_NumerPelny
WHEN 1002 THEN BDN_NumerPelny
WHEN 223 THEN BDN_NumerPelny
WHEN 221 THEN NON_NumerPelny
WHEN 114 THEN DLN_NumerPelny
WHEN 111 THEN KDN_NumerPelny
WHEN 112 THEN KDN_NumerPelny
WHEN 113 THEN KDN_NumerPelny
ELSE TrN_NumerPelny END,
[Dokument Powiązany Wartość] = CASE DoR_DokumentTyp
WHEN 900 THEN SrZ_WartoscNetto
WHEN 700 THEN 0 
WHEN 999 THEN VaN_WartoscZak
WHEN 1003 THEN EDN_KwotaRazem
WHEN 1004 THEN SrT_WartoscBilan
WHEN 1005 THEN Wyp_WartoscZakup
WHEn 1122 THEN BRp_Przychody
WHEN 1000 THEN BZp_Kwota
WHEN 1001 THEN BZd_Kwota
WHEN 1145 THEN KPN_RazemKwotaRoz
WHEN 1002 THEN BDN_RazemKwota2
WHEN 223 THEN BDN_RazemKwota2
WHEN 221 THEN NON_RazemKwota
WHEN 114 THEN DLN_KwotaWal
WHEN 111 THEN KDN_RazemKwota2
WHEN 112 THEN KDN_RazemKwota2
WHEN 113 THEN KDN_RazemKwota2
ELSE TrN_RazemNetto END,
---ETAP BIEŻĄCY
[Etap Symbol] = NULL,
[Etap Nazwa] = NULL,
[Etap Poziom] = NULL,
[Etap Obowiązkowy] = NULL,
[Etap Wykonany] = NULL,
[Etap Bieżący Symbol] = eb1.SE_Symbol,
[Etap Bieżący Nazwa] = eb1.SE_Nazwa,
[Etap Termin Wykonania] = NULL,
[Etap Data Rozpoczęcia] = NULL,
[Etap Data Zakończenia] = NULL,
[Etap Czas Trwania] = NULL,
[Etap Ilość] = NULL,
---HISTORIA
[Etap Data Zmiany] = NULL,
[Operator Kod] = NULL,
[Operator Komentarz] = NULL,
[Etap Przed Zmianą] = NULL,
[Etap Po Zmianie] = NULL,
[Operacja Typ] = NULL,
[Operacja Ilość] = NULL,
[Operator Wprowadzający] = zal.Ope_Kod,
[Operator Modyfikujący] = mod.Ope_Kod,
[Data Analizy] = GETDATE()
----------KONTEKSTY
,[Dokument Obiegu Numer __PROCID__] = 25106
,[Dokument Obiegu Numer __ORGID__] = DoN_DoNID

FROM CDN.DokNag
LEFT JOIN #tmpSeria ser ON DoN_DDfId = DDf_DDfID
left join CDN.DokRelacje ON DoR_ParentId = DoN_DoNID AND DoR_ParentTyp=750
left join CDN.SrsZlecenia ON SrZ_SrZId=DoR_DokumentId
left join CDN.CRMKontakty ON CRK_CRKId=DoR_DokumentId
left join CDN.VatNag ON VaN_VaNID=DoR_DokumentId
left join CDN.Tranag ON TrN_TrNID=DoR_DokumentId
left join CDN.EwidDodNag ON EDN_EDNID=DoR_DokumentId
left join CDN.Trwale ON SrT_SrTID=DoR_DokumentId
left join CDN.Wyposazenie ON Wyp_WypID=DoR_DokumentId
left join CDN.BnkRaporty ON BRp_BRpID=DoR_DokumentId
left join CDN.BnkZapisy ON BZp_BZpID=DoR_DokumentId
left join CDN.BnkZdarzenia ON BZd_BZdID=DoR_DokumentId
left join CDN.KompensatyNag ON KPN_KPNID=DoR_DokumentId
left join CDN.NotyOdsNag ON NON_NONId=DoR_DokumentId
left join CDN.DlgNag ON DLN_DLNId=DoR_DokumentId
left join CDN.BnkDokNag ON BDN_BDNId=DoR_DokumentId
left join CDN.KsiDokNag ON KDN_KDNId=DoR_DokumentId
left join
(---ILOŚC DOKUMENTÓW POWIĄZANYCH Z OBD
SELECT
[DokIleID] = DoR_DoRId,
[DokIlosc] = COUNT(DoR_DokumentId)
FROM CDN.DokNag
left join CDN.DokRelacje ON DoR_ParentId = DoN_DoNID AND DoR_ParentTyp=750
GROUP BY DoR_DoRId) b ON DokIleID = DoR_DoRId
left join ' + @Etapy + ' eb1 ON eb1.SE_SEID = DoN_EtapBiezacyLp 
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON DoN_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON DoN_OpeModID = mod.Ope_OpeId
WHERE DoR_DokumentId IS NOT NULL

UNION ALL

----KONTRAHENCI
SELECT
BAZ.Baz_Nazwa [Baza Firmowa],
[Dokument Obiegu Seria] =
CASE when isnull(ser.seria,0) = 5 then 
substring(DoN_NumerPelny,0,CHARINDEX(''/'',DoN_NumerPelny,0))
ELSE 
ISNULL(PARSENAME(REPLACE(substring(DoN_NumerPelny,CHARINDEX(''/'',DoN_NumerPelny,0)+1,50), ''/'', ''.''), ser.seria),''(BRAK)'') 
END,
[Dokument Obiegu Numer] = DoN_NumerPelny,
[Dokument Obiegu Data Wprowadzenia] = CONVERT(VARCHAR(10), DoN_DataDok, 20),
[Dokument Obiegu Tytuł] = ISNULL(DoN_Tytul,''(BRAK)''),
[Dokument Obiegu Opis] = ISNULL(DoN_Dotyczy,''(BRAK)''),
[Dokument Obiegu Typ] = CASE DoN_Typ WHEN 1 THEN ''Firmowy'' ELSE ''Wspólny'' END,
[Dokument Obiegu Proces Obiegu] = ISNULL(DoN_ProcesKod,''(BRAK)''),
[Dokument Obiegu Numer Obcy] = ISNULL(DoN_NumerObcy,''(BRAK)''),
[Operator Tworzący Zapis] = DoN_OpeModKod,
[Operator Modyfikujący Zapis] = DoN_OpeZalKod,
[Dokument Obiegu Ilość] = NULL,
[Dokument Obiegu Ilość Dokumentów Powiązanych] = NULL,
[Dokument Obiegu Ilość Kontrahentów] = KntIlosc,
[Kontrahent Kod] = Pod_Kod,
[Kontrahent Nazwa] = Pod_Nazwa1,
[Dokument Powiązany Typ] = NULL,
[Dokument Powiązany Numer] = NULL,
[Dokument Powiązany Wartość] = NULL,
---ETAP BIEŻĄCY
[Etap Symbol] = NULL,
[Etap Nazwa] = NULL,
[Etap Poziom] = NULL,
[Etap Obowiązkowy] = NULL,
[Etap Wykonany] = NULL,
[Etap Bieżący Symbol] = eb1.SE_Symbol,
[Etap Bieżący Nazwa] = eb1.SE_Nazwa,
[Etap Termin Wykonania] = NULL,
[Etap Data Rozpoczęcia] = NULL,
[Etap Data Zakończenia] = NULL,
[Etap Czas Trwania] = NULL,
[Etap Ilość] = NULL,
---HISTORIA
[Etap Data Zmiany] = NULL,
[Operator Kod] = NULL,
[Operator Komentarz] = NULL,
[Etap Przed Zmianą] = NULL,
[Etap Po Zmianie] = NULL,
[Operacja Typ] = NULL,
[Operacja Ilość] = NULL,
[Operator Wprowadzający] = zal.Ope_Kod,
[Operator Modyfikujący] = mod.Ope_Kod,
[Data Analizy] = GETDATE()
----------KONTEKSTY
,[Dokument Obiegu Numer __PROCID__] = 25106
,[Dokument Obiegu Numer __ORGID__] = DoN_DoNID

FROM CDN.DokNag
LEFT JOIN #tmpSeria ser ON DoN_DDfId = DDf_DDfID
left join CDN.DokPodmioty ON DoP_DoNID = DoN_DoNID
left join CDN.PodmiotyView ON DoP_PodmiotID = Pod_PodId and Pod_PodmiotTyp = DoP_PodmiotTyp
left join 
(---ILOŚC KONTRAHENTÓW DLA OBD
SELECT
[KntIleID] = DoP_DoPId,
[KntIlosc] = COUNT(Pod_Kod)
FROM CDN.DokNag
left join CDN.DokPodmioty ON DoP_DoNID = DoN_DoNID
left join CDN.PodmiotyView ON DoP_PodmiotID = Pod_PodId and Pod_PodmiotTyp = DoP_PodmiotTyp
GROUP BY DoP_DoPId) c ON KntIleID = DoP_DoPId
left join ' + @Etapy + ' eb1 ON eb1.SE_SEID = DoN_EtapBiezacyLp 
    LEFT JOIN '+ @Bazy +' BAZ ON DB_NAME() = BAZ.Baz_NazwaBazy AND BAZ.Baz_NazwaSerwera = SERVERPROPERTY(''ServerName'') and baz.baz_nieaktywna = 0
LEFT JOIN ' + @Operatorzy + ' zal ON DoN_OpeZalID = zal.Ope_OpeId
LEFT JOIN ' + @Operatorzy + ' mod ON DoN_OpeModID = mod.Ope_OpeId
WHERE DoP_DoPId IS NOT NULL

'
exec(@sql)
drop table #tmpseria





















