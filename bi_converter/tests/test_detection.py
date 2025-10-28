#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import unittest
from bi_converter.converter import ComarchBIConverter


SQL_SAMPLE = r"""
/* Raport: Test Raport */
DECLARE @ParamRokZakupu INT = 2024;
DECLARE @DataDoAnalizy DATE = CAST(GETDATE() AS DATE);
DECLARE @Input NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@ParamRokZakupu)), '');

SELECT t.Twr_Kod AS [Produkt Kod],
       t.Twr_Nazwa AS [Produkt Nazwa],
       SUM(te.TrE_Ilosc) AS [Ilość Sprzedana],
       GETDATE() [Data Analizy]
FROM CDN.TraElem te
JOIN CDN.Towary t ON t.Twr_TwrId = te.TrE_TwrId
GROUP BY t.Twr_Kod, t.Twr_Nazwa;
"""


class TestDetection(unittest.TestCase):
    def setUp(self):
        self.conv = ComarchBIConverter()

    def test_extract_columns(self):
        cols = self.conv.extract_columns(SQL_SAMPLE)
        names = [c.name for c in cols]
        self.assertIn('Produkt Kod', names)
        self.assertIn('Produkt Nazwa', names)
        self.assertIn('Ilość Sprzedana', names)
        self.assertIn('Data Analizy', names)

    def test_extract_params_and_interactive(self):
        params = self.conv.extract_parameters(SQL_SAMPLE)
        pnames = [p.name for p in params]
        self.assertIn('PARAMROKZAKUPU', pnames)
        self.assertIn('DATADOANALIZY', pnames)
        inter = self.conv.detect_interactive_params(params)
        inames = [p.name for p in inter]
        # By heuristics: PARAMROKZAKUPU is literal -> interactive
        self.assertIn('PARAMROKZAKUPU', inames)
        # DATADOANALIZY has computed default -> not interactive
        self.assertNotIn('DATADOANALIZY', inames)


if __name__ == '__main__':
    unittest.main()
