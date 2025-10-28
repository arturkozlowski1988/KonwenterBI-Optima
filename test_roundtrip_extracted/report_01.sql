-- Test raport dla roundtrip
DECLARE @DATAOD DATE = '2024-01-01';
DECLARE @DATADO DATE = '2024-12-31';

SELECT 
    KNT_Kod AS [Kod Kontrahenta],
    KNT_Nazwa AS [Nazwa Kontrahenta],
    COUNT(*) AS [Liczba Zamówień],
    SUM(ZAW_WartoscBrutto) AS [Wartość Brutto]
FROM 
    CDN.TraNag
    INNER JOIN CDN.Kontrahenci ON TrN_KntNumer = KNT_KntNumer
WHERE 
    TrN_Data2 >= @DATAOD
    AND TrN_Data2 <= @DATADO
GROUP BY 
    KNT_Kod, KNT_Nazwa
ORDER BY 
    [Wartość Brutto] DESC;
