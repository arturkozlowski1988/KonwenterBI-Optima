/*
* Raport Operatorów
* Wersja raportu: 38.0
* Wersja baz OPTIMY: 2025.5000
* Wersja aplikacji OPTIMA: 2025.3.0
*/

DECLARE @sql nvarchar(max)
DECLARE @serwerKonf varchar(max);
DECLARE @bazaKonf varchar(max);
DECLARE @Operatorzy varchar(max);
DECLARE @BazModulyOperatora varchar(max);
DECLARE @Bazy varchar(max);
DECLARE @BazZakazy varchar(max);

SET @serwerKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1001)
SET @bazaKonf = (SELECT SYS_Wartosc FROM CDN.SystemCDN WHERE SYS_ID = 1002)
SET @Operatorzy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Operatorzy]' 
SET @BazModulyOperatora = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[BazModulyOperatora]' 
SET @Bazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[Bazy]' 
SET @BazZakazy = '[' + @serwerKonf + '].[' + @bazaKonf + '].[CDN].[BazZakazy]' 

SET @sql = N'
SELECT
    OPE.Ope_OpeID AS ''Ilość Wystapień'',
    OPE.Ope_Nazwisko AS ''Operator Imię i Nazwisko'',
    OPE.Ope_kod AS ''Operator Kod'',
    BMO.Baz_Nazwa AS ''Baza firmowa'',
    BMO.BMO_SerwerKlucza AS ''Serwer klucza'',
    CASE
        WHEN OPE.Ope_Administrator=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Administrator'',
    CASE 
        WHEN OPE.Ope_Nieaktywny=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Niektywny'',
    CASE 
        WHEN BMO.Ope_ModulKB=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Kasa Bank '',
    CASE 
        WHEN BMO.Ope_ModulKBP=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Kasa Bank Plus '',
    CASE 
        WHEN BMO.Ope_ModulFA=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Faktury'',
    CASE 
        WHEN BMO.Ope_ModulMAG=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Handel'',
    CASE 
        WHEN BMO.Ope_ModulHAP=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Handel Plus'',
    CASE 
        WHEN BMO.Ope_ModulCRM=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł CRM'',
    CASE 
        WHEN BMO.Ope_ModulCRMP=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł CRM Plus'',
    CASE 
        WHEN BMO.ope_ModulSRW=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Serwis'',
    CASE 
        WHEN BMO.Ope_ModulOBD=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Obieg dokumentów'',
    CASE 
        WHEN BMO.Ope_ModulKP=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Księga Podatkowa'',
    CASE 
        WHEN BMO.Ope_ModulST=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Środki Trwałe'',
    CASE 
        WHEN BMO.Ope_ModulKH=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Księga Handlowa'',
    CASE 
        WHEN BMO.Ope_ModulKHP=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Księga Handlowa Plus'',
    CASE 
        WHEN BMO.Ope_ModulPK=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Płace i Kadry'',
    CASE 
        WHEN BMO.Ope_ModulPKXL=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Płace i Kadry Plus'',
    CASE 
        WHEN BMO.Ope_ModulANL=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Analizy'',
    CASE 
        WHEN BMO.Ope_PelneMenu=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Pełne menu dla modułu Analizy'',
    CASE 
        WHEN BMO.Ope_ModulBIU=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Moduł Biuro Rachunkowe'',
    CASE 
        WHEN OPE.Ope_PrawoZmianyZapKBZamRapKB=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo zmiany zapisów k/b w zamkniętych raportach'',
    CASE 
        WHEN OPE.Ope_AkceptacjaDelegacji=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo do akceptowanie poleceń wyjazdu i rozliczenia delegacji'',
    CASE 
        WHEN OPE.Ope_KsiegaGlowna=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawa operacji na księdze głównej'',
    CASE 
        WHEN OPE.Ope_BuforVATSpr=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Księgowanie rejestrów sprzedaży przez bufor '',
    CASE 
        WHEN OPE.Ope_BuforVATZak=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Księgowanie rejestrów zakupów przez bufor '',
    CASE 
        WHEN OPE.Ope_BuforAmortyz=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Księgowanie amortyzacji przez bufor '',
    CASE 
        WHEN OPE.Ope_BuforPlace=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Księgowanie wypłat przez bufor '',
    CASE 
        WHEN OPE.Ope_BuforEwid=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Księgowanie innych ewidencji przez bufor'',
    CASE 
        WHEN OPE.Ope_ZmianyOffLine=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo zmiany dokumentów wyeksportowanych'',
    CASE 
        WHEN OPE.Ope_PrawoImportuZapKBOtwRapKB=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo importu zapisów k/b do otwartych raportów'',
    CASE 
        WHEN OPE.Ope_ModyfikacjaProcesow=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo modyfikacji procesów'',
    CASE 
        WHEN OPE.Ope_DostepDoSkrzynkiInnychOperatorow=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo dostępu do skrzynki innych operatorów'',
        CASE 
        WHEN OPE.Ope_KontrolaPlatnosciWZ=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Kontrola płatności na dokumentach WZ'',
        CASE 
        WHEN OPE.Ope_AnalizyBI_Administrator=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Administrator Analiz BI'',
        CASE 
        WHEN OPE.Ope_AnalizyBI_Subskrypcje=1 THEN ''Tak'' 
        WHEN OPE.Ope_AnalizyBI_Administrator=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Dostęp do subskrypcji Analiz BI'',
        CASE 
        WHEN OPE.Ope_AnalizyBI_DodawaniePol=1 THEN ''Tak''
        WHEN OPE.Ope_AnalizyBI_Administrator=1 THEN ''Tak''  
        ELSE ''Nie''
    END AS ''Prawo dodawania pól do Analiz BI '',
        CASE 
        WHEN OPE.Ope_AnalizyBI_Drukowanie=1 THEN ''Tak''
        WHEN OPE.Ope_AnalizyBI_Administrator=1 THEN ''Tak''  
        ELSE ''Nie''
    END AS ''Prawo drukowania Analiz BI '',
        CASE 
        WHEN OPE.Ope_AnalizyBI_Eksport=1 THEN ''Tak'' 
        WHEN OPE.Ope_AnalizyBI_Administrator=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo eksportu Analiz BI'',
        CASE 
        WHEN OPE.Ope_AnalizyBI_ModyfikacjaZapytania=1 THEN ''Tak''
        WHEN OPE.Ope_AnalizyBI_Administrator=1 THEN ''Tak''  
        ELSE ''Nie''
    END AS ''Prawo do modyfikacji treści zapytania Analizy BI'',
        CASE 
        WHEN OPE.Ope_AnalizyBI_ImportRaportu=1 THEN ''Tak'' 
        WHEN OPE.Ope_AnalizyBI_Administrator=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo do importu definicji raportu Analiz BI'',
        CASE 
        WHEN OPE.Ope_PrawoUsuwaniaMaili=1 THEN ''Tak'' 
        WHEN OPE.Ope_AnalizyBI_Administrator=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo do usuwania e-maili'',
        CASE 
        WHEN OPE.Ope_DostepDoKontInnychOperatorow=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Czy operator ma prawo dostępu do kont email innych operatorów'',
        CASE 
        WHEN OPE.Ope_OdblokowanieZlecen=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo do odblokowania zleceń'',
        CASE 
        WHEN OPE.Ope_KotrolaCzesciPobranych=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Kontrola części pobranych'',
    CASE 
        WHEN OPE.Ope_PrawoDoPobrCzesciMagSerw=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo do pobrania części z mag. serwisowego'',
    CASE 
        WHEN OPE.Ope_PrawoDoPobrCzesciMagLok=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo do pobrania części z mag. lokalnych'',
    CASE 
        WHEN OPE.Ope_BlokadaDokMMzMagMob=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Blokada wystawiania dokumentów MM z magazynu mobilnego'',
    CASE 
        WHEN OPE.Ope_PrawoEksportuJPK=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo eksportu plików JPK'',
    CASE 
        WHEN OPE.Ope_PrawoScalaniaKnt=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Prawo do łączenia kart kontrahentów'',
    CASE 
        WHEN OPE.Ope_ZmianaAtrNaZatwDok=1 THEN ''Tak'' 
        ELSE ''Nie''
    END AS ''Zmiana atrybutów na zatwierdzonym dokumencie '',
    CASE 
        WHEN OPE.Ope_BlokadaVatDoVat7=1 THEN ''ostrzeżenie''
        WHEN OPE.Ope_BlokadaVatDoVat7=1 THEN ''blokada''  
        ELSE ''brak''
    END AS ''Blokada zmiany dokumentów z VAT-7'',
    CASE 
        WHEN OPE.Ope_ZmianaProcesuDomyslnego=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Prawo zamiany procesu domyślnego'',
    CASE 
        WHEN OPE.Ope_AktualizacjaKntHaMag=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Aktualizacja kontrahenta na dokumencie'',
    CASE 
        WHEN OPE.Ope_BlokadaAnulowaniaHaMag=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada anulowania dokumentu'',
    CASE 
        WHEN OPE.Ope_BlokadaPonownejFiskFAPA=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada ponownej fiskalizacji FA i PA'',
    CASE 
        WHEN OPE.Ope_BlokadaFAPAdoBufora=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada zapisu FA i PA do bufora'',
    CASE 
        WHEN OPE.Ope_BlokadaZmianCenFA=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada zmiany cen FA, WZ, WKA'',
    CASE 
        WHEN OPE.Ope_BlokadaZmianCenFPF=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada zmiany cen PF'',
    CASE 
        WHEN OPE.Ope_BlokadaZmianCenFZ=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada zmiany cen FZ, PZ, PKA'',
    CASE 
        WHEN OPE.Ope_BlokadaZmianCenPA=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada zmiany cen PA'',
    CASE 
        WHEN OPE.Ope_BlokadaZmianCenRO=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada zmiany cen RO'',
    CASE 
        WHEN OPE.Ope_BlokadaZmianCenZD=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada zmiany cen ZD'',
    CASE 
        WHEN OPE.Ope_ZakazCenyZak=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Zakaz dostępu do cen zakupu'',
    CASE 
        WHEN OPE.Ope_BlokadaZmianyKwotyWplaty=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Blokada zmiany kwoty wpłaty do dokumentów '',
    CASE 
        WHEN OPE.Ope_RozliczanieZListyHaMag=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Rozliczanie dokumentów z poziomu listy'',
    CASE 
        WHEN OPE.Ope_PlatnoscNaWZ=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Płatność do WZ '',
    CASE 
        WHEN OPE.Ope_MinMarzaHaMag=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Sprzedaż poniżej min. marży / maks. marży'',
    CASE 
        WHEN OPE.Ope_ZapisFAPApoWydruku=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Zapisywanie FA i PA po wydruku na trwałe'',
    CASE 
        WHEN OPE.Ope_ZmianaLimituKred=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Zmiana Limitu kredytu na karcie kontrahenta'',
    CASE 
        WHEN OPE.Ope_ZmianaOpisuHaMag=1 THEN ''Tak''
        ELSE ''Nie''
    END AS ''Zmiana opisu i osoby odbierającej na dok.'',
    CASE 
        WHEN OPE.Ope_PlatnosciSprzedazTrwaly=0 THEN ''Ostrzeżenie''
        ELSE ''Blokada''
    END AS ''Kontrola płatności - Zapis na trwałe'',
    CASE 
        WHEN OPE.Ope_PlatnosciSprzedazBufor=0 THEN ''Ostrzeżenie''
        WHEN OPE.Ope_PlatnosciSprzedazBufor=1 THEN ''Blokada''
        ELSE ''Brak''
    END AS ''Kontrola płatności - Zapis do bufora'',
    GETDATE() AS ''Data Analizy''
FROM ' +@Operatorzy +' OPE
LEFT JOIN (
SELECT  OPE.Ope_OpeID,
        null as Bmo_SerwerKlucza,
        BAZ.Baz_Nazwa,
        OPE.Ope_ModulKB,
        OPE.Ope_ModulKBP,
        OPE.Ope_ModulFA,
        OPE.Ope_ModulMAG,
        OPE.Ope_ModulHAP,
        OPE.Ope_ModulCRM,
        OPE.Ope_ModulCRMP,
        OPE.ope_ModulSRW,
        OPE.Ope_ModulOBD,
        OPE.Ope_ModulKP,
        OPE.Ope_ModulST,
        OPE.Ope_ModulKH,
        OPE.Ope_ModulKHP,
        OPE.Ope_ModulPK,
        OPE.Ope_ModulPKXL,
        OPE.Ope_ModulANL,
        OPE.Ope_PelneMenu,
        OPE.Ope_ModulBIU

FROM ' +@Operatorzy +' OPE
CROSS JOIN '+ @Bazy +' BAZ
LEFT JOIN '+ @BazZakazy +' BZA ON OPE.Ope_OpeID = BZA.BZa_OpeID AND BAZ.Baz_BazID = BZA.BZa_BazID
LEFT JOIN '+ @BazModulyOperatora +' BMO ON OPE.Ope_OpeID = BMO.Bmo_OpeID AND BAZ.Baz_BazID = BMO.Bmo_BazID
WHERE BZA.BZa_BZaID IS NULL AND BMO_BmoId IS NULL

UNION 

SELECT  OPE.Ope_OpeID,
        BMO.BMO_SerwerKlucza,
        BAZ.Baz_Nazwa,
        BMO.Bmo_ModulKB,
        BMO.Bmo_ModulKBP,
        BMO.Bmo_ModulFA,
        BMO.BMO_ModulHA,
        BMO.Bmo_ModulHAP,
        BMO.Bmo_ModulCRM,
        BMO.Bmo_ModulCRMP,
        BMO.Bmo_ModulSRW,
        BMO.Bmo_ModulOBD,
        BMO.Bmo_ModulKP,
        BMO.Bmo_ModulST,
        BMO.Bmo_ModulKH,
        BMO.Bmo_ModulKHP,
        BMO.Bmo_ModulPK,
        BMO.BMO_ModulPKP,
        BMO.BMO_ModulANL,
        BMO.BMO_ModulANLP,
        OPE.Ope_ModulBIU

FROM ' +@Operatorzy +' OPE
JOIN '+ @BazModulyOperatora +' BMO ON OPE.Ope_OpeID = BMO.Bmo_OpeID
JOIN '+ @Bazy +' BAZ ON BMO.BMO_BazID = BAZ.Baz_BazID
) BMO ON OPE.Ope_OpeID = BMO.Ope_OpeID'

PRINT(@SQL)
EXEC(@SQL)







