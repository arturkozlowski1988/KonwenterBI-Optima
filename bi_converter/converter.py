#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Enhanced Comarch BI SQL -> XML converter

Features:
- Universal extraction of columns (supports dynamic SQL in string literals)
- Auto-detection of interactive parameters (heuristics + optional overrides)
- Keeps all DECLAREs in SQL; only interactive params go to MdxParams
- Logging of all steps and outcomes
"""

from __future__ import annotations

import html
import json
import logging
import random
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional, Set, Tuple
from xml.etree import ElementTree as ET

from .logging_conf import get_logger
from .sql_analyzer import extract_columns as parse_columns, extract_parameters as parse_parameters, validate_sql as check_sql


class ConversionError(Exception):
    pass


@dataclass
class ColumnDef:
    name: str
    caption: str
    type: str  # 'measure' | 'attribute'
    formatString: str = ''
    aggregate: str = ''


@dataclass
class ParamDef:
    name: str
    label: str
    type: str  # 'Liczba' | 'Tekst' | 'Data'
    paramType: str  # 'Number' | 'Text' | 'Data'
    defaultValue: str = ''
    minValue: Optional[int] = None
    maxValue: Optional[int] = None
    precision: Optional[int] = None
    step: Optional[int] = None
    declared: bool = False  # Declared in SQL via DECLARE


class ComarchBIConverter:
    # Class-level cache for config files (shared across instances)
    _config_cache: Dict[str, Dict[str, Any]] = {}
    _config_mtime: Dict[str, float] = {}
    
    def __init__(self, logger: Optional[logging.Logger] = None, config_path: Optional[Path] = None):
        self.logger = logger or get_logger()
        self.config_path = config_path
        self.config = self._load_config_cached()
        # Well-known BI parameters that should be considered even when not DECLARE'd
        default_known_params = [
            'DATAOD', 'DATADO',
            'DATAPOCZATEKROKU', 'DATAKONIECROKU',
            'DATADOANALIZY', 'DATAODANALIZY',
            'DATRYBUTWR', 'ZTROWE', 'ZEROWE',  # Additional common BI params
            'MAGAZYN', 'KONTRAHENT', 'DOKUMENT'
        ]
        cfg_known = self.config.get('well_known_params') or []
        # Normalize to UPPER for comparisons - use config if available, else defaults
        if cfg_known:
            self.known_params: Set[str] = {p.upper() for p in cfg_known}
        else:
            self.known_params: Set[str] = {p.upper() for p in default_known_params}
        
        if self.known_params:
            self.logger.debug(f"Known params (for inference): {sorted(self.known_params)}")

    # ---------------------------
    # Configuration (with caching)
    # ---------------------------
    def _load_config_cached(self) -> Dict[str, Any]:
        """
        Load config with caching to avoid repeated file reads.
        Cache is invalidated automatically when file mtime changes.
        """
        # Determine config path
        if self.config_path is None:
            # Look for package-local config.json
            pkg_dir = Path(__file__).parent
            default_path = pkg_dir / 'config.json'
            if default_path.exists():
                self.config_path = default_path
        
        if self.config_path is None:
            return {"interactive_overrides": {"include": [], "exclude": []}}
        
        config_key = str(self.config_path)
        
        try:
            if not self.config_path.exists():
                return {"interactive_overrides": {"include": [], "exclude": []}}
            
            current_mtime = self.config_path.stat().st_mtime
            
            # Check cache: use if file hasn't changed
            if config_key in self._config_cache:
                cached_mtime = self._config_mtime.get(config_key, 0)
                if current_mtime <= cached_mtime:
                    self.logger.debug(f"Using cached config from {self.config_path}")
                    return self._config_cache[config_key]
            
            # Load from file
            with open(self.config_path, 'r', encoding='utf-8') as f:
                cfg = json.load(f)
            
            # Update cache
            self._config_cache[config_key] = cfg
            self._config_mtime[config_key] = current_mtime
            
            self.logger.info(f"Loaded config from {self.config_path}")
            return cfg
            
        except (OSError, json.JSONDecodeError) as e:
            self.logger.warning(f"Failed to load config from {self.config_path}: {e}")
            return {"interactive_overrides": {"include": [], "exclude": []}}
        return {"interactive_overrides": {"include": [], "exclude": []}}

    # ---------------------------
    # Helpers: detection
    # ---------------------------
    def _detect_column_type(self, column_name: str) -> str:
        name = column_name.lower()
        measure_keywords = [
            'ilość', 'ilosc', 'wartość', 'wartosc', 'suma', 'count', 'liczba',
            'dni', 'procent', '%', 'kwota', 'stan', 'saldo', 'wartosc', 'brutto', 'netto', 'cena'
        ]
        attribute_keywords = ['data', 'kod', 'nazwa', 'symbol', 'opis', 'status', 'ryzyko', 'magazyn', 'produkt']
        if any(k in name for k in measure_keywords):
            return 'measure'
        if any(k in name for k in attribute_keywords):
            return 'attribute'
        return 'attribute'

    def _filter_column_name(self, name: str) -> bool:
        # Exclude special technical columns and noise
        blocked_substrings = [
            '__PROCID__', '__ORGID__', '__DATABASE__',
        ]
        blocked_exact = {
            'Baza Firmowa',
        }
        if name in blocked_exact:
            return False
        for s in blocked_substrings:
            if s in name:
                return False
        return True

    def _unique_preserve(self, items: List[str]) -> List[str]:
        seen: Set[str] = set()
        out: List[str] = []
        for it in items:
            if it not in seen:
                seen.add(it)
                out.append(it)
        return out

    # ---------------------------
    # Extraction: columns
    # ---------------------------
    def extract_columns(self, sql_text: str) -> List[ColumnDef]:
        self.logger.debug("Extracting columns via sqlparse")

        raw_cols = parse_columns(sql_text)

        cols: List[ColumnDef] = []
        for c in raw_cols:
            name = c['name']
            if not self._filter_column_name(name):
                continue
            ctype = self._detect_column_type(name)
            cols.append(ColumnDef(
                name=name,
                caption=name,
                type=ctype,
                formatString='n2' if ctype == 'measure' else '',
                aggregate='Sum' if ctype == 'measure' else ''
            ))

        self.logger.info(f"Detected {len(cols)} columns")
        return cols

    # ---------------------------
    # Extraction: params
    # ---------------------------
    def _map_sql_type(self, sql_type: str) -> Tuple[str, str]:
        sql_type = sql_type.upper()
        if sql_type.startswith('INT') or sql_type.startswith('DECIMAL') or sql_type.startswith('NUMERIC'):
            return ('Liczba', 'Number')
        if sql_type.startswith('DATE') or sql_type.startswith('DATETIME'):
            return ('Data', 'Data')
        return ('Tekst', 'Text')

    def _is_literal_default(self, default: str) -> bool:
        # Number literal
        if re.fullmatch(r"[-+]?\d+(?:\.\d+)?", default.strip()):
            return True
        # Quoted string literal
        if re.fullmatch(r"'[^']*'", default.strip()):
            return True
        return False

    def _is_computed_default(self, default: str) -> bool:
        text = default.upper()
        if '@' in text:
            return True
        if any(fn in text for fn in ['GETDATE', 'CURRENT_TIMESTAMP', 'SELECT', 'DATEADD', 'DATEFROMPARTS', 'TRY_CONVERT', 'CONVERT', 'CAST', 'ISNULL', 'COALESCE']):
            return True
        return False

    def _infer_type_from_name(self, name: str) -> Tuple[str, str]:
        n = name.upper()
        if 'DATA' in n or 'DATE' in n:
            return ('Data', 'Data')
        if 'DZIE' in n:  # DZIEN/DZISIEJSZA
            return ('Data', 'Data')
        if 'PRZEDZIAL' in n or 'DNI' in n or 'ROK' in n or 'ILOSC' in n or 'LICZ' in n:
            return ('Liczba', 'Number')
        return ('Tekst', 'Text')

    def extract_parameters(self, sql_text: str) -> List[ParamDef]:
        self.logger.debug("Extracting parameters via sqlparse")

        raw_params = parse_parameters(sql_text)
        params: List[ParamDef] = []

        for p in raw_params:
            if p['declared']:
                p_type, p_bi = self._map_sql_type(p['sql_type'])
                params.append(ParamDef(
                    name=p['name'],
                    label=p['name'],
                    type=p_type,
                    paramType=p_bi,
                    defaultValue=p['default'],
                    minValue=0 if p_type == 'Liczba' else None,
                    maxValue=999999 if p_type == 'Liczba' else None,
                    precision=0 if p_type == 'Liczba' else None,
                    step=1 if p_type == 'Liczba' else None,
                    declared=True
                ))
            else:
                p_type, p_bi = self._infer_type_from_name(p['name'])
                params.append(ParamDef(
                    name=p['name'],
                    label=p['name'],
                    type=p_type,
                    paramType=p_bi,
                    defaultValue=p['default'],
                    minValue=0 if p_type == 'Liczba' else None,
                    maxValue=999999 if p_type == 'Liczba' else None,
                    precision=0 if p_type == 'Liczba' else None,
                    step=1 if p_type == 'Liczba' else None,
                    declared=False
                ))

        self.logger.info(f"Detected {len(params)} parameters")
        return params

    def detect_interactive_params(self, params: List[ParamDef]) -> List[ParamDef]:
        # Start with heuristics on declared params: literal defaults -> interactive
        interactive: List[ParamDef] = []
        for p in params:
            if p.declared:
                if self._is_literal_default(p.defaultValue) and not self._is_computed_default(p.defaultValue):
                    interactive.append(p)
            else:
                # Undeclared: include if they match PARAM* or PRZEDZIAL\d+ or are well-known BI params
                if p.name.startswith('PARAM') or re.fullmatch(r'PRZEDZIAL\d+', p.name) or p.name in self.known_params:
                    interactive.append(p)

    # Apply overrides from config
        overrides = self.config.get("interactive_overrides", {"include": [], "exclude": []})
        include = set(x.upper() for x in overrides.get("include", []))
        exclude = set(x.upper() for x in overrides.get("exclude", []))

        # Ensure includes are present (only if such param exists among parsed params)
        all_param_names = {p.name for p in params}
        for name in include:
            if name in all_param_names and not any(p.name == name for p in interactive):
                # try to infer type from pattern
                p_type, p_bi = self._infer_type_from_name(name)
                interactive.append(ParamDef(name=name, label=name, type=p_type, paramType=p_bi))

        # Apply exclude
        interactive = [p for p in interactive if p.name.upper() not in exclude]

        # De-duplicate by name preserving order
        seen: Set[str] = set()
        dedup: List[ParamDef] = []
        for p in interactive:
            if p.name not in seen:
                # Apply optional default values from config if empty
                if (p.defaultValue is None or str(p.defaultValue) == ''):
                    defaults_map = self.config.get('param_defaults', {}) or {}
                    if isinstance(defaults_map, dict):
                        dv = defaults_map.get(p.name) or defaults_map.get(p.name.upper())
                        if dv is not None:
                            p.defaultValue = str(dv)
                dedup.append(p)
                seen.add(p.name)

        self.logger.info(f"Interactive params selected: {[p.name for p in dedup]}")
        # Hint if we auto-added well-known date range params
        kn = {p.name for p in dedup} & self.known_params
        if kn:
            self.logger.debug(f"Included known BI params as interactive (no DECLARE found): {sorted(kn)}")
        return dedup

    # ---------------------------
    # XML building
    # ---------------------------
    def _create_metadata_xml(self, columns: List[ColumnDef]) -> str:
        xml_lines = ['&lt;?xml version="1.0" encoding="utf-16" standalone="yes"?&gt;']
        xml_lines.append('&lt;metadata&gt;')
        xml_lines.append('  &lt;columns&gt;')
        for col in columns:
            aggregate = f' aggregate="{col.aggregate}"' if col.aggregate else ''
            xml_lines.append(
                f'    &lt;column name="{col.name}" caption="{col.caption}" type="{col.type}" '
                f'formatString="{col.formatString}"{aggregate} /&gt;'
            )
        xml_lines.append('  &lt;/columns&gt;')
        xml_lines.append('&lt;/metadata&gt;')
        return '&#xD;\n'.join(xml_lines)

    def _create_parameters_xml(self, interactive_params: List[ParamDef]) -> str:
        # CRITICAL: Always return valid XML, even if empty
        # Comarch BI expects a root element, not an empty string
        xml_lines = ['&lt;?xml version="1.0" encoding="utf-16"?&gt;']
        xml_lines.append('&lt;ArrayOfMdxQueryParameter xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"&gt;')
        
        if not interactive_params:
            # Return empty but valid XML structure
            xml_lines.append('&lt;/ArrayOfMdxQueryParameter&gt;')
            return '&#xD;\n'.join(xml_lines)
        for p in interactive_params:
            xml_lines.append('  &lt;MdxQueryParameter&gt;')
            xml_lines.append(f'    &lt;Name&gt;{p.name}&lt;/Name&gt;')
            xml_lines.append(f'    &lt;Label&gt;{p.label}&lt;/Label&gt;')
            xml_lines.append('    &lt;Expression /&gt;')
            xml_lines.append(f'    &lt;Type&gt;{p.type}&lt;/Type&gt;')
            xml_lines.append(f'    &lt;ParamType&gt;{p.paramType}&lt;/ParamType&gt;')
            xml_lines.append('    &lt;DateFormat&gt;SQL&lt;/DateFormat&gt;')
            if p.minValue is not None:
                xml_lines.append(f'    &lt;MinimumValue&gt;{p.minValue}&lt;/MinimumValue&gt;')
                xml_lines.append(f'    &lt;MaximumValue&gt;{p.maxValue}&lt;/MaximumValue&gt;')
                xml_lines.append(f'    &lt;Precision&gt;{p.precision}&lt;/Precision&gt;')
                xml_lines.append(f'    &lt;Step&gt;{p.step}&lt;/Step&gt;')
            else:
                xml_lines.append('    &lt;MinimumValue&gt;0&lt;/MinimumValue&gt;')
                xml_lines.append('    &lt;MaximumValue&gt;0&lt;/MaximumValue&gt;')
                xml_lines.append('    &lt;Precision&gt;0&lt;/Precision&gt;')
                xml_lines.append('    &lt;Step&gt;0&lt;/Step&gt;')
            xml_lines.append('    &lt;Multiselect&gt;false&lt;/Multiselect&gt;')
            xml_lines.append('    &lt;Uppercase&gt;false&lt;/Uppercase&gt;')
            def_val = p.defaultValue
            # Remove quotes around default to keep consistent with previous behavior
            if def_val is None:
                def_val = ''
            # Strip quotes outside f-string to avoid escaping issues
            def_val_clean = str(def_val).strip("'\"")
            xml_lines.append(f'    &lt;DefaultValue&gt;{html.escape(def_val_clean)}&lt;/DefaultValue&gt;')
            xml_lines.append('    &lt;Redefined&gt;false&lt;/Redefined&gt;')
            xml_lines.append('  &lt;/MdxQueryParameter&gt;')
        xml_lines.append('&lt;/ArrayOfMdxQueryParameter&gt;')
        return '&#xD;\n'.join(xml_lines)

    # ---------------------------
    # Core convert
    # ---------------------------
    def _escape_sql_for_xml(self, sql_text: str) -> str:
        sql_escaped = html.escape(sql_text)
        sql_escaped = sql_escaped.replace('\n', '&#xD;\n')
        return sql_escaped

    def _extract_report_info(self, sql_text: str) -> Dict[str, str]:
        info = {
            'name': 'Nowa Analiza BI',
            'description': '',
            'version': '1.0',
            'author': 'CTI Support'
        }
        m = re.search(r"\*\s*Raport[:\s]+([^\n*]+)", sql_text)
        if m:
            info['name'] = m.group(1).strip()
        m = re.search(r"\*\s*CEL RAPORTU[:\s]+([^\n*]+)", sql_text)
        if m:
            info['description'] = m.group(1).strip()
        m = re.search(r"\*\s*Wersja[:\s]+([^\n*]+)", sql_text)
        if m:
            info['version'] = m.group(1).strip()
        return info

    def validate_sql(self, sql_text: str) -> Tuple[bool, List[str]]:
        """
        Perform pre-flight validation on SQL code.
        Returns (is_valid, list_of_warnings).
        """
        # Use sql_analyzer for validation
        is_valid, warnings = check_sql(sql_text)
        
        # Additional business logic check for columns
        columns = self.extract_columns(sql_text)
        if len(columns) == 0:
            warnings.append("⚠️ Nie znaleziono kolumn z aliasami (AS [nazwa]) - Comarch BI może nie działać")
            # If no columns are found, this is often critical for BI
            if is_valid: # Downgrade valid status if previously valid
                 # We consider it a soft warning unless it strictly breaks XML.
                 # But in previous code it was a warning.
                 pass

        if len(columns) > 0 and len(columns) < 3:
            warnings.append(f"ℹ️ Znaleziono tylko {len(columns)} kolumn - sprawdź czy to wystarczy")

        return is_valid, warnings

    def convert(self, sql_file_path: str, connection_config: Dict[str, str]) -> str:
        """
        Convert a single SQL file to XML format.
        This is a convenience wrapper around convert_multiple() for single files.
        """
        sql_path = Path(sql_file_path)
        if not sql_path.exists():
            raise ConversionError(f"SQL file not found: {sql_path}")

        self.logger.info(f"Converting file: {sql_path}")

        # Read SQL with BOM-aware encoding and fallback for legacy files
        try:
            sql_text = sql_path.read_text(encoding='utf-8-sig')
        except Exception:
            try:
                sql_text = sql_path.read_text(encoding='utf-8')
            except Exception:
                # Fallback for Windows-1250 encoded scripts
                sql_text = sql_path.read_text(encoding='cp1250', errors='replace')

        # Create single report XML fragment
        report_xml = self._create_single_report_xml(sql_text, sql_path, connection_config, report_index=1)
        
        # Wrap in ReportsList structure
        xml_content = f'''<ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
    <Reports xmlns:a="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities">
{report_xml}
    </Reports>
    <UsePasswordsEncryption>true</UsePasswordsEncryption>
</ReportsList>'''

        out_path = sql_path.with_suffix('.xml')
        out_path.write_text(xml_content, encoding='utf-8')
        self.logger.info(f"Wrote XML: {out_path}")
        return str(out_path)

    def _create_single_report_xml(
        self, 
        sql_text: str, 
        sql_path: Path,
        connection_config: Dict[str, str],
        report_index: int = 1
    ) -> str:
        """
        Create XML fragment for a single report.
        Used internally by both convert() and convert_multiple().
        """
        # Extract columns and parameters
        columns = self.extract_columns(sql_text)
        self.logger.info(f"Detected {len(columns)} columns")
        
        params_all = self.extract_parameters(sql_text)
        params_interactive = self.detect_interactive_params(params_all)
        self.logger.info(f"Detected {len(params_all)} parameters")
        self.logger.info(f"Interactive params selected: {[p.name for p in params_interactive]}")

        report_info = self._extract_report_info(sql_text)
        
        # Use filename if no report name found
        if report_info['name'] == 'Nowa Analiza BI':
            report_info['name'] = sql_path.stem

        # Build sections
        metadata_xml = self._create_metadata_xml(columns)
        params_xml = self._create_parameters_xml(params_interactive)
        sql_escaped = self._escape_sql_for_xml(sql_text)

        now = datetime.now()
        created_on = now.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3]
        report_id = random.randint(4000, 9999)

        # Connection handling strategy
        def requires_explicit_connection(sql: str) -> bool:
            s = sql
            if re.search(r"\[[^\]]+\]\.\[[^\]]+\]\.(?:\[[^\]]+\]\.?){1,2}", s):
                return True
            if re.search(r"\b[\w$]+\.[\w$]+\.[\w$]+(?:\.[\w$]+)?\b", s):
                return True
            if re.search(r"@SERWER|@SERWERKONF|@BAZA|@BAZAKONF|\[\s*'\s*\]\s*\+\s*@", s, re.IGNORECASE):
                return True
            return False

        conn_cfg_from_file = self.config.get('connection', {}) if isinstance(self.config, dict) else {}
        mode = (connection_config.get('mode') or conn_cfg_from_file.get('mode') or 'auto').lower()
        if mode not in {'auto', 'embedded', 'default'}:
            self.logger.warning(f"Unknown connection mode '{mode}', falling back to 'auto'")
            mode = 'auto'

        effective_mode = mode
        if mode == 'auto':
            effective_mode = 'embedded' if requires_explicit_connection(sql_text) else 'default'

        server_name = connection_config.get('server', '') if effective_mode == 'embedded' else ''
        catalog_name = connection_config.get('database', '') if effective_mode == 'embedded' else ''
        connection_name = connection_config.get('connection_name', '') if effective_mode == 'embedded' else ''

        # Build connections block only for embedded mode
        if effective_mode == 'embedded':
            connections_block = f'''      <a:connections>
                <a:ReportConnection>
                    <a:biType>0</a:biType>
                    <a:connectionType>MSSQL_User</a:connectionType>
                    <a:database>{catalog_name}</a:database>
                    <a:isDefault>true</a:isDefault>
                    <a:isDelated>false</a:isDelated>
                    <a:name>{connection_name}</a:name>
                    <a:openTimeout>-1</a:openTimeout>
                    <a:password>Sek33MacesM=</a:password>
                    <a:port>-1</a:port>
                    <a:queryTimeout>-1</a:queryTimeout>
                    <a:server>{server_name}</a:server>
                    <a:userId/>
                </a:ReportConnection>
            </a:connections>'''
        else:
            connections_block = '      <a:connections/>'

        # Return single report XML fragment
        report_xml = f'''        <a:Report i:type="a:MdxSqlDevXpressReport">
            <a:catalogName>{catalog_name}</a:catalogName>
            <a:createdOn>{created_on}</a:createdOn>
            <a:cubeName/>
            <a:definitions xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                    <b:Key>MdxQuery</b:Key>
                    <b:Value>
                        <a:binaryData/>
                        <a:textData>{sql_escaped}</a:textData>
                        <a:timestamp/>
                        <a:type>MdxQuery</a:type>
                    </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                <b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
                    <b:Key>SubCube</b:Key>
                    <b:Value>
                        <a:binaryData/>
                        <a:textData/>
                        <a:timestamp/>
                        <a:type>SubCube</a:type>
                    </b:Value>
                </b:KeyValueOfReportDataTypeReportDataBrNSYbaE>
            </a:definitions>
            <a:description>{report_info['description']}</a:description>
            <a:id>{report_id}</a:id>
            <a:isPredefinedReport>false</a:isPredefinedReport>
            <a:language>pl-PL</a:language>
            <a:mainLinkName>{report_info['name']}</a:mainLinkName>
            <a:modifiedOn>{created_on}</a:modifiedOn>
            <a:path xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays">
                <b:string>Raporty Zaimportowane</b:string>
            </a:path>
            <a:predefinedReport i:nil="true"/>
            <a:serverName>{server_name}</a:serverName>
            <a:sourceDbType>Main</a:sourceDbType>
            <a:standardReportHash i:nil="true"/>
            <a:standardReportId i:nil="true"/>
            <a:standardReportVersion i:nil="true"/>
            <a:type>DevXpressMdxSql</a:type>
            <a:useDefaultConnection>{'false' if effective_mode == 'embedded' else 'true'}</a:useDefaultConnection>
            <a:useInMemory>true</a:useInMemory>
            <a:viewType i:nil="true"/>
            <a:webServicePort>80</a:webServicePort>
            <a:contexts/>
{connections_block}
        </a:Report>'''
        
        return report_xml

    def convert_multiple(
        self,
        sql_file_paths: List[str],
        connection_config: Dict[str, str],
        output_xml_path: Optional[str] = None
    ) -> str:
        """
        Convert multiple SQL files to a single XML file with multiple reports.
        
        Args:
            sql_file_paths: List of paths to SQL files
            connection_config: Connection configuration dict
            output_xml_path: Optional output path. If None, uses first SQL filename with .xml
            
        Returns:
            Path to created XML file
        """
        if not sql_file_paths:
            raise ConversionError("No SQL files provided")
        
        self.logger.info(f"Converting {len(sql_file_paths)} SQL files to single XML")
        
        report_fragments = []
        
        for idx, sql_file in enumerate(sql_file_paths, start=1):
            sql_path = Path(sql_file)
            if not sql_path.exists():
                self.logger.warning(f"SQL file not found: {sql_path}, skipping")
                continue
            
            self.logger.info(f"Processing file {idx}/{len(sql_file_paths)}: {sql_path.name}")
            
            try:
                sql_text = sql_path.read_text(encoding='utf-8')
                # Remove BOM if present
                if sql_text.startswith('\ufeff'):
                    sql_text = sql_text[1:]
                    self.logger.debug("Removed BOM from SQL file")
                
                report_xml = self._create_single_report_xml(
                    sql_text, 
                    sql_path, 
                    connection_config,
                    report_index=idx
                )
                report_fragments.append(report_xml)
                
            except Exception as e:
                self.logger.error(f"Failed to process {sql_path.name}: {e}")
                raise ConversionError(f"Failed to process {sql_path.name}: {e}")
        
        if not report_fragments:
            raise ConversionError("No valid SQL files processed")
        
        # Build complete XML with all reports
        reports_section = '\n'.join(report_fragments)
        
        xml_content = f'''<ReportsList xmlns="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
    <Reports xmlns:a="http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities">
{reports_section}
    </Reports>
    <UsePasswordsEncryption>true</UsePasswordsEncryption>
</ReportsList>'''
        
        # Determine output path
        if output_xml_path:
            out_path = Path(output_xml_path)
        else:
            first_sql_path = Path(sql_file_paths[0])
            out_path = first_sql_path.parent / f"{first_sql_path.stem}_combined.xml"
        
        out_path.write_text(xml_content, encoding='utf-8')
        self.logger.info(f"Wrote combined XML with {len(report_fragments)} reports: {out_path}")
        return str(out_path)

    # ---------------------------
    # XML → SQL extraction (optimized with iterparse)
    # ---------------------------
    def extract_sql_reports(self, xml_file_path: str) -> List[Dict[str, str]]:
        """
        Extract SQL queries from Comarch BI XML file using streaming parser.
        Memory-efficient for large XML files (50MB+).
        Returns list of dicts with keys: 'index', 'name', 'sql'
        """
        xml_path = Path(xml_file_path)
        if not xml_path.exists():
            raise ConversionError(f"XML file not found: {xml_path}")
        
        # Define namespaces
        ns = {
            'ns': 'http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic',
            'a': 'http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities',
            'b': 'http://schemas.microsoft.com/2003/10/Serialization/Arrays',
        }
        
        # Build namespace-prefixed tags for faster matching
        report_tag = f"{{{ns['a']}}}Report"
        name_tag = f"{{{ns['a']}}}name"
        definitions_tag = f"{{{ns['a']}}}definitions"
        entry_tag = f"{{{ns['b']}}}KeyValueOfReportDataTypeReportDataBrNSYbaE"
        key_tag = f"{{{ns['b']}}}Key"
        value_tag = f"{{{ns['b']}}}Value"
        text_tag = f"{{{ns['a']}}}textData"
        
        try:
            # Use iterparse for memory-efficient streaming parsing
            context = ET.iterparse(str(xml_path), events=('end',))
            extracted: List[Dict[str, str]] = []
            idx = 0
            
            for event, elem in context:
                # Process only complete Report elements
                if elem.tag != report_tag:
                    continue
                
                idx += 1
                
                # Extract report name
                report_name = ''
                name_elem = elem.find(name_tag)
                if name_elem is not None and name_elem.text:
                    report_name = name_elem.text
                
                # Find MdxQuery definition
                sql_text = None
                definitions = elem.find(definitions_tag)
                
                if definitions is not None:
                    for entry in definitions.findall(entry_tag):
                        key_elem = entry.find(key_tag)
                        if key_elem is None or key_elem.text != 'MdxQuery':
                            continue
                        
                        value = entry.find(value_tag)
                        if value is None:
                            continue
                        
                        text_node = value.find(text_tag)
                        if text_node is None or text_node.text is None:
                            continue
                        
                        # Unescape HTML entities and normalize line endings
                        sql_text = html.unescape(text_node.text).replace('\r\n', '\n')
                        break
                
                if sql_text:
                    extracted.append({
                        'index': idx,
                        'name': report_name.strip(),
                        'sql': sql_text,
                    })
                else:
                    self.logger.warning(f"Skipping report {idx} ({report_name or 'unnamed'}): no SQL payload found")
                
                # CRITICAL: Clear processed element to free memory
                # This allows Python's garbage collector to reclaim memory during parsing
                elem.clear()
            
            self.logger.info(f"Extracted {len(extracted)} SQL reports from {xml_path}")
            return extracted
            
        except (ET.ParseError, OSError) as exc:
            self.logger.error(f"Failed to parse XML file '{xml_path}': {exc}")
            raise ConversionError(f"Failed to parse XML file: {exc}") from exc

    def get_xml_report_summary(self, xml_file_path: str) -> List[Dict[str, Any]]:
        """
        Get lightweight summary of reports in XML file without loading full SQL content.
        Returns list of dicts with keys: 'index', 'name', 'sql_lines', 'sql_size_kb'
        Useful for preview before extraction.
        """
        xml_path = Path(xml_file_path)
        if not xml_path.exists():
            raise ConversionError(f"XML file not found: {xml_path}")
        
        ns = {
            'ns': 'http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessLogic',
            'a': 'http://schemas.datacontract.org/2004/07/Comarch.Msp.ReportsBook.BusinessInterface.Entities',
            'b': 'http://schemas.microsoft.com/2003/10/Serialization/Arrays',
        }
        
        report_tag = f"{{{ns['a']}}}Report"
        name_tag = f"{{{ns['a']}}}name"
        definitions_tag = f"{{{ns['a']}}}definitions"
        entry_tag = f"{{{ns['b']}}}KeyValueOfReportDataTypeReportDataBrNSYbaE"
        key_tag = f"{{{ns['b']}}}Key"
        value_tag = f"{{{ns['b']}}}Value"
        text_tag = f"{{{ns['a']}}}textData"
        
        try:
            context = ET.iterparse(str(xml_path), events=('end',))
            summary: List[Dict[str, Any]] = []
            idx = 0
            
            for event, elem in context:
                if elem.tag != report_tag:
                    continue
                
                idx += 1
                
                # Extract report name
                report_name = ''
                name_elem = elem.find(name_tag)
                if name_elem is not None and name_elem.text:
                    report_name = name_elem.text
                
                # Get SQL size and line count
                sql_lines = 0
                sql_size = 0
                definitions = elem.find(definitions_tag)
                
                if definitions is not None:
                    for entry in definitions.findall(entry_tag):
                        key_elem = entry.find(key_tag)
                        if key_elem is None or key_elem.text != 'MdxQuery':
                            continue
                        
                        value = entry.find(value_tag)
                        if value is None:
                            continue
                        
                        text_node = value.find(text_tag)
                        if text_node is None or text_node.text is None:
                            continue
                        
                        sql_text = html.unescape(text_node.text)
                        sql_lines = sql_text.count('\n') + 1
                        sql_size = len(sql_text.encode('utf-8'))
                        break
                
                summary.append({
                    'index': idx,
                    'name': report_name.strip() or f'report_{idx:02d}',
                    'sql_lines': sql_lines,
                    'sql_size_kb': round(sql_size / 1024, 2),
                })
                
                elem.clear()
            
            self.logger.info(f"Retrieved summary for {len(summary)} reports from {xml_path}")
            return summary
            
        except (ET.ParseError, OSError) as exc:
            self.logger.error(f"Failed to parse XML file '{xml_path}': {exc}")
            raise ConversionError(f"Failed to parse XML file: {exc}") from exc

    def write_sql_reports(self, xml_file_path: str, output_dir: Optional[str] = None) -> List[Path]:
        """
        Extract SQL from XML and write each report to a separate .sql file.
        Returns list of created file paths.
        """
        reports = self.extract_sql_reports(xml_file_path)
        
        if not reports:
            raise ConversionError("No SQL reports found in XML file")
        
        # Determine output directory
        base_dir = Path(output_dir) if output_dir else Path(xml_file_path).parent
        base_dir.mkdir(parents=True, exist_ok=True)
        
        used_names: Set[str] = set()
        written: List[Path] = []
        
        for report in reports:
            filename = self._build_report_filename(report['name'], report['index'], used_names)
            target = base_dir / f"{filename}.sql"
            
            # Create SQL content with header containing report name
            sql_content = self._format_sql_with_header(
                report['sql'], 
                report['name'], 
                report['index'],
                xml_file_path
            )
            
            target.write_text(sql_content, encoding="utf-8")
            written.append(target)
            self.logger.info(f"Wrote SQL for report '{report['name'] or filename}' to {target}")
        
        return written

    def _build_report_filename(self, report_name: str, index: int, used: Set[str]) -> str:
        """
        Build safe filename from report name.
        Handles duplicates and empty names.
        """
        # Sanitize name: remove invalid chars, replace with underscore
        safe = re.sub(r'[^A-Za-z0-9._\-ąćęłńóśźżĄĆĘŁŃÓŚŹŻ ]+', '_', report_name).strip('_') if report_name else ''
        
        if not safe:
            safe = f"report_{index:02d}"
        
        # Handle duplicates
        candidate = safe
        counter = 2
        while candidate.lower() in used:
            candidate = f"{safe}_{counter}"
            counter += 1
        
        used.add(candidate.lower())
        return candidate

    def _format_sql_with_header(self, sql_text: str, report_name: str, report_index: int, source_xml: str) -> str:
        """
        Format SQL content with a header comment containing report metadata.
        
        Args:
            sql_text: The SQL query text
            report_name: Name of the report from XML
            report_index: Index/number of the report in the XML file
            source_xml: Path to source XML file
            
        Returns:
            Formatted SQL with header comment
        """
        # If report name is empty, try to extract from SQL metadata comments
        if not report_name or not report_name.strip():
            name_from_sql = self._extract_report_name_from_sql(sql_text)
            if name_from_sql:
                report_name = name_from_sql
        
        source_file = Path(source_xml).name
        extraction_date = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        # Build header comment
        header_lines = [
            "/*",
            " * =" * 40,
            f" * NAZWA RAPORTU: {report_name if report_name else '(bez nazwy)'}",
            f" * NUMER RAPORTU: {report_index}",
            f" * ŹRÓDŁO: {source_file}",
            f" * DATA EKSTRAKCJI: {extraction_date}",
            " * =" * 40,
            " */",
            ""
        ]
        
        header = "\n".join(header_lines)
        
        # Combine header with SQL
        return f"{header}\n{sql_text}"
    
    def _extract_report_name_from_sql(self, sql_text: str) -> Optional[str]:
        """
        Extract report name from SQL metadata comments if present.
        Looks for patterns like:
        * NAZWA_RAPORTU: Some Report Name
        * Raport: Some Report Name
        
        Args:
            sql_text: The SQL query text
            
        Returns:
            Extracted report name or None
        """
        # Try to find NAZWA_RAPORTU in comments
        match = re.search(r'\*\s*NAZWA_RAPORTU\s*:\s*([^\n]+)', sql_text, re.IGNORECASE)
        if match:
            return match.group(1).strip()
        
        # Try to find "Raport:" pattern
        match = re.search(r'\*\s*Raport\s*:\s*([^\n]+)', sql_text, re.IGNORECASE)
        if match:
            return match.group(1).strip()
        
        return None
