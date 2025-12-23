#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests for XML → SQL extraction functionality"""

from pathlib import Path
from textwrap import dedent

import pytest

from bi_converter.converter import ComarchBIConverter, ConversionError


def test_extract_single_report(tmp_path: Path):
    """Test extracting a single SQL report from XML"""
    xml_content = dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic"
                     xmlns:a="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities"
                     xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
          <Reports>
            <a:Report>
              <a:name>Test Raport</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT 1 AS [Wynik];</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
          </Reports>
        </ReportsList>
    """)
    
    xml_file = tmp_path / "test.xml"
    xml_file.write_text(xml_content, encoding="utf-8")
    
    conv = ComarchBIConverter()
    reports = conv.extract_sql_reports(str(xml_file))
    
    assert len(reports) == 1
    assert reports[0]['name'] == 'Test Raport'
    assert 'SELECT 1 AS [Wynik]' in reports[0]['sql']


def test_extract_multiple_reports(tmp_path: Path):
    """Test extracting multiple SQL reports from XML"""
    xml_content = dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic"
                     xmlns:a="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities"
                     xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
          <Reports>
            <a:Report>
              <a:name>Raport 1</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT 1;</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
            <a:Report>
              <a:name>Raport 2</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT 2;</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
          </Reports>
        </ReportsList>
    """)
    
    xml_file = tmp_path / "multi.xml"
    xml_file.write_text(xml_content, encoding="utf-8")
    
    conv = ComarchBIConverter()
    reports = conv.extract_sql_reports(str(xml_file))
    
    assert len(reports) == 2
    assert reports[0]['name'] == 'Raport 1'
    assert reports[1]['name'] == 'Raport 2'
    assert 'SELECT 1;' in reports[0]['sql']
    assert 'SELECT 2;' in reports[1]['sql']


def test_write_sql_reports(tmp_path: Path):
    """Test writing extracted SQL reports to files"""
    xml_content = dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic"
                     xmlns:a="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities"
                     xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
          <Reports>
            <a:Report>
              <a:name>Raport 1</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT 1;</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
            <a:Report>
              <a:name>Raport 2</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT 2;</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
          </Reports>
        </ReportsList>
    """)
    
    xml_file = tmp_path / "multi.xml"
    xml_file.write_text(xml_content, encoding="utf-8")
    
    output_dir = tmp_path / "sql_out"
    
    conv = ComarchBIConverter()
    outputs = conv.write_sql_reports(str(xml_file), str(output_dir))
    
    assert len(outputs) == 2
    assert all(p.exists() for p in outputs)
    
    # Check filenames and content
    extracted = {path.name: path.read_text(encoding="utf-8") for path in outputs}
    
    # Check that both files were created with expected names
    assert "Raport 1.sql" in extracted
    assert "Raport 2.sql" in extracted
    
    # Verify that report names appear in headers
    assert "NAZWA RAPORTU: Raport 1" in extracted["Raport 1.sql"]
    assert "NAZWA RAPORTU: Raport 2" in extracted["Raport 2.sql"]
    
    # Verify SQL content is present
    assert "SELECT 1;" in extracted["Raport 1.sql"]
    assert "SELECT 2;" in extracted["Raport 2.sql"]


def test_roundtrip_sql_to_xml_to_sql(tmp_path: Path):
    """Test complete roundtrip: SQL → XML → SQL"""
    sql_text = dedent("""\
        /* Raport testowy */
        DECLARE @PARAM1 INT = 100;
        
        SELECT
            @PARAM1 AS [Wartość],
            GETDATE() AS [Data];
    """)
    
    sql_file = tmp_path / "sample.sql"
    sql_file.write_text(sql_text, encoding="utf-8")
    
    # Step 1: SQL → XML
    conv = ComarchBIConverter()
    xml_path = Path(conv.convert(str(sql_file), {
        'server': 'SRV',
        'database': 'DB',
        'connection_name': 'NAME',
        'mode': 'default',
    }))
    
    assert xml_path.exists()
    
    # Step 2: XML → SQL
    output_dir = tmp_path / "out"
    outputs = conv.write_sql_reports(str(xml_path), str(output_dir))
    
    assert len(outputs) == 1
    extracted = outputs[0].read_text(encoding="utf-8").replace('\r\n', '\n')
    
    # Verify header with report name is present
    assert 'NAZWA RAPORTU:' in extracted
    
    # Verify content preserved (original SQL should be in the extracted file)
    assert 'DECLARE @PARAM1 INT = 100;' in extracted
    assert 'SELECT' in extracted
    assert '@PARAM1 AS [Wartość]' in extracted or '@PARAM1 AS [Wartosc]' in extracted  # encoding variations


def test_html_entities_unescaping(tmp_path: Path):
    """Test that HTML entities in SQL are properly unescaped"""
    xml_content = dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic"
                     xmlns:a="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities"
                     xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
          <Reports>
            <a:Report>
              <a:name>Test HTML</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT * FROM T WHERE x &gt; 5 AND y &lt; 10;</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
          </Reports>
        </ReportsList>
    """)
    
    xml_file = tmp_path / "html.xml"
    xml_file.write_text(xml_content, encoding="utf-8")
    
    conv = ComarchBIConverter()
    reports = conv.extract_sql_reports(str(xml_file))
    
    assert len(reports) == 1
    # HTML entities should be unescaped
    assert 'x > 5' in reports[0]['sql']
    assert 'y < 10' in reports[0]['sql']


def test_empty_xml(tmp_path: Path):
    """Test handling of XML with no reports"""
    xml_content = dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic">
          <Reports>
          </Reports>
        </ReportsList>
    """)
    
    xml_file = tmp_path / "empty.xml"
    xml_file.write_text(xml_content, encoding="utf-8")
    
    conv = ComarchBIConverter()
    
    # extract_sql_reports should return empty list
    reports = conv.extract_sql_reports(str(xml_file))
    assert reports == []
    
    # write_sql_reports should raise error
    with pytest.raises(ConversionError, match="No SQL reports found"):
        conv.write_sql_reports(str(xml_file))


def test_filename_sanitization(tmp_path: Path):
    """Test that special characters in report names are sanitized"""
    xml_content = dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic"
                     xmlns:a="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities"
                     xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
          <Reports>
            <a:Report>
              <a:name>Raport / Analiza: test &lt;wersja&gt;</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT 1;</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
          </Reports>
        </ReportsList>
    """)
    
    xml_file = tmp_path / "special.xml"
    xml_file.write_text(xml_content, encoding="utf-8")
    
    conv = ComarchBIConverter()
    outputs = conv.write_sql_reports(str(xml_file), str(tmp_path))
    
    assert len(outputs) == 1
    # Check that filename is sanitized (no /, :, <, >)
    filename = outputs[0].name
    assert '/' not in filename
    assert ':' not in filename
    assert '<' not in filename
    assert '>' not in filename
    # Should contain safe characters
    assert '_' in filename or filename.startswith('report_')


def test_duplicate_names(tmp_path: Path):
    """Test handling of duplicate report names"""
    xml_content = dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic"
                     xmlns:a="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities"
                     xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
          <Reports>
            <a:Report>
              <a:name>Raport</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT 1;</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
            <a:Report>
              <a:name>Raport</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT 2;</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
          </Reports>
        </ReportsList>
    """)
    
    xml_file = tmp_path / "dupe.xml"
    xml_file.write_text(xml_content, encoding="utf-8")
    
    conv = ComarchBIConverter()
    outputs = conv.write_sql_reports(str(xml_file), str(tmp_path))
    
    assert len(outputs) == 2
    # Should have unique filenames
    filenames = [p.name for p in outputs]
    assert len(set(filenames)) == 2  # All unique
    # One should be "Raport.sql", other "Raport_2.sql"
    assert "Raport.sql" in filenames
    assert "Raport_2.sql" in filenames


def test_report_header_format(tmp_path: Path):
    """Test that extracted SQL files contain properly formatted header with report name"""
    xml_content = dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic"
                     xmlns:a="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities"
                     xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
          <Reports>
            <a:Report>
              <a:name>Analiza Sprzedaży Q1 2024</a:name>
              <a:definitions>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                  <b:Key>MdxQuery</b:Key>
                  <b:Value>
                    <a:textData>SELECT TOP 10 * FROM Sprzedaz WHERE Data &gt;= '2024-01-01';</a:textData>
                  </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
              </a:definitions>
            </a:Report>
          </Reports>
        </ReportsList>
    """)
    
    xml_file = tmp_path / "test_header.xml"
    xml_file.write_text(xml_content, encoding="utf-8")
    
    conv = ComarchBIConverter()
    outputs = conv.write_sql_reports(str(xml_file), str(tmp_path))
    
    assert len(outputs) == 1
    content = outputs[0].read_text(encoding="utf-8")
    
    # Verify header structure
    assert content.startswith("/*")
    assert "NAZWA RAPORTU: Analiza Sprzedaży Q1 2024" in content
    assert "NUMER RAPORTU: 1" in content
    assert "ŹRÓDŁO: test_header.xml" in content
    assert "DATA EKSTRAKCJI:" in content
    assert "*/" in content
    
    # Verify SQL content after header
    assert "SELECT TOP 10 * FROM Sprzedaz WHERE Data >= '2024-01-01';" in content
    
    # Verify the header comes before the SQL
    header_end = content.index("*/")
    sql_start = content.index("SELECT")
    assert header_end < sql_start
