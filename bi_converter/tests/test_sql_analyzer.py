import unittest
from bi_converter.sql_analyzer import extract_columns, extract_parameters, validate_sql

class TestSqlAnalyzer(unittest.TestCase):
    def test_extract_simple_columns(self):
        sql = "SELECT col1 AS [Kolumna 1], col2 AS 'Kolumna 2', col3 Kolumna3 FROM table"
        cols = extract_columns(sql)
        self.assertEqual(len(cols), 3)
        self.assertEqual(cols[0]['name'], 'Kolumna 1')
        self.assertEqual(cols[1]['name'], 'Kolumna 2')
        self.assertEqual(cols[2]['name'], 'Kolumna3')

    def test_extract_no_alias(self):
        sql = "SELECT col1, col2 FROM table"
        cols = extract_columns(sql)
        self.assertEqual(len(cols), 2)
        self.assertEqual(cols[0]['name'], 'col1')
        self.assertEqual(cols[1]['name'], 'col2')

    def test_extract_with_expression(self):
        sql = "SELECT SUM(x) AS Suma, CAST(y AS INT) AS [Y Int] FROM table"
        cols = extract_columns(sql)
        self.assertEqual(len(cols), 2)
        self.assertEqual(cols[0]['name'], 'Suma')
        self.assertEqual(cols[1]['name'], 'Y Int')

    def test_extract_multiline(self):
        sql = """
        SELECT
            t.col1 AS [C1],
            -- comment
            t.col2 AS [C2]
        FROM table t
        """
        cols = extract_columns(sql)
        self.assertEqual(len(cols), 2)
        self.assertEqual(cols[0]['name'], 'C1')
        self.assertEqual(cols[1]['name'], 'C2')

    def test_extract_cte(self):
        sql = """
        WITH CTE AS (SELECT x FROM t)
        SELECT x AS [Wynik] FROM CTE
        """
        cols = extract_columns(sql)
        self.assertEqual(len(cols), 1)
        self.assertEqual(cols[0]['name'], 'Wynik')

    def test_extract_params_declare(self):
        sql = """
        DECLARE @P1 INT = 1;
        DECLARE @P2 VARCHAR(10) = 'test';
        SELECT @P1;
        """
        params = extract_parameters(sql)
        names = {p['name'] for p in params}
        self.assertIn('P1', names)
        self.assertIn('P2', names)

        p1 = next(p for p in params if p['name'] == 'P1')
        self.assertTrue(p1['declared'])
        self.assertEqual(p1['default'], '1')

    def test_extract_params_inferred(self):
        sql = "SELECT * FROM t WHERE date > @DATAOD"
        params = extract_parameters(sql)
        names = {p['name'] for p in params}
        self.assertIn('DATAOD', names)

        p = next(p for p in params if p['name'] == 'DATAOD')
        self.assertFalse(p['declared'])

if __name__ == '__main__':
    unittest.main()
