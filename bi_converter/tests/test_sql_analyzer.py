#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import unittest
from bi_converter.sql_analyzer import extract_columns, extract_parameters, validate_sql

class TestSqlAnalyzer(unittest.TestCase):

    def test_extract_columns_simple(self):
        sql = "SELECT Col1 AS [Alias1], Col2 AS 'Alias2' FROM Table"
        cols = extract_columns(sql)
        names = [c['name'] for c in cols]
        self.assertEqual(names, ['Alias1', 'Alias2'])

    def test_extract_columns_no_as(self):
        sql = "SELECT Col1 [Alias1], Col2 FROM Table"
        cols = extract_columns(sql)
        # Col2 has no alias, so it takes 'Col2'
        self.assertEqual([c['name'] for c in cols], ['Alias1', 'Col2'])

    def test_extract_columns_with_comments(self):
        sql = """
        SELECT
            Col1 AS [Alias1], -- comment
            Col2 AS /* inline comment */ [Alias2]
        FROM Table
        """
        cols = extract_columns(sql)
        self.assertEqual([c['name'] for c in cols], ['Alias1', 'Alias2'])

    def test_extract_columns_complex(self):
        sql = """
        SELECT
             SUM(x) AS [Total],
             (SELECT TOP 1 Name FROM T2) AS [SubName]
        FROM T1
        """
        cols = extract_columns(sql)
        self.assertEqual([c['name'] for c in cols], ['Total', 'SubName'])

    def test_extract_parameters_declared(self):
        sql = """
        DECLARE @Param1 INT = 5;
        DECLARE @Param2 NVARCHAR(10) = 'Test';
        SELECT @Param1, @Param2
        """
        params = extract_parameters(sql)
        p_map = {p['name']: p for p in params}

        self.assertIn('PARAM1', p_map)
        self.assertTrue(p_map['PARAM1']['declared'])
        self.assertEqual(p_map['PARAM1']['sql_type'], 'INT')

        self.assertIn('PARAM2', p_map)
        self.assertEqual(p_map['PARAM2']['default'], "'Test'")

    def test_extract_parameters_inferred(self):
        sql = """
        SELECT * FROM Table WHERE Date > @DataOd AND Name LIKE @ParamName
        """
        params = extract_parameters(sql)
        p_names = [p['name'] for p in params]

        # DATAOD is a known param, PARAMNAME starts with PARAM
        self.assertIn('DATAOD', p_names)
        self.assertIn('PARAMNAME', p_names)

    def test_validate_sql_valid(self):
        sql = "SELECT * FROM Table"
        valid, warns = validate_sql(sql)
        self.assertTrue(valid)
        self.assertEqual(len(warns), 0)

    def test_validate_sql_missing_select(self):
        sql = "UPDATE Table SET x=1"
        valid, warns = validate_sql(sql)
        # Should warn about no select (depending on logic) and dangerous update
        self.assertFalse(valid) # Critical because update is dangerous/forbidden usually in reporting
        self.assertTrue(any('UPDATE' in w for w in warns))

    def test_validate_sql_dangerous(self):
        sql = "DROP TABLE Users"
        valid, warns = validate_sql(sql)
        self.assertFalse(valid)
        self.assertTrue(any('DROP' in w for w in warns))

if __name__ == '__main__':
    unittest.main()
