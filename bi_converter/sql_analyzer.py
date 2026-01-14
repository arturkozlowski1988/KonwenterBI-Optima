# -*- coding: utf-8 -*-
"""
SQL Analysis module using sqlparse.
Provides robust extraction of columns and parameters, validation, and formatting.
"""
from __future__ import annotations
import re
from typing import List, Dict, Tuple, Set, Optional, Any
import sqlparse
from sqlparse.sql import IdentifierList, Identifier, Function, Where, Comparison, Token
from sqlparse.tokens import Keyword, DML, Name, Wildcard, Punctuation, Literal

from .logging_conf import get_logger

logger = get_logger()

def format_sql(sql_text: str) -> str:
    """
    Format SQL text using standard rules.
    """
    try:
        formatted = sqlparse.format(
            sql_text,
            reindent=True,
            keyword_case='upper',
            identifier_case=None,  # Keep original casing for identifiers
            strip_comments=False,
            use_space_around_operators=True
        )
        return formatted
    except Exception as e:
        logger.error(f"Error formatting SQL: {e}")
        return sql_text

def validate_sql(sql_text: str) -> Tuple[bool, List[str]]:
    """
    Validate SQL for basic syntax and forbidden commands.
    Returns (is_valid, warnings).
    """
    warnings = []

    # 1. Parse
    parsed = sqlparse.parse(sql_text)
    if not parsed:
        warnings.append("⚠️ Pusty plik lub błąd parsowania")
        return False, warnings

    statements = [stmt for stmt in parsed if stmt.get_type() != 'UNKNOWN']

    # Check 1: SELECT present
    has_select = any(stmt.get_type() == 'SELECT' for stmt in statements)
    if not has_select:
        # It might be a script with DECLAREs ending in SELECT, which sqlparse might treat as UNKNOWN or implicit
        # Let's check tokens of the last statement
        last_stmt = parsed[-1]
        if not any(t.ttype is DML and t.value.upper() == 'SELECT' for t in last_stmt.flatten()):
             warnings.append("⚠️ Brak instrukcji SELECT - to nie wygląda na zapytanie")

    # Check 2: Dangerous commands
    forbidden = {'DROP', 'TRUNCATE', 'DELETE', 'UPDATE', 'INSERT', 'ALTER', 'GRANT', 'REVOKE'}

    for stmt in parsed:
        # Check main statement type
        stmt_type = stmt.get_type().upper()
        if stmt_type in forbidden:
            # Special case for DELETE without WHERE is handled later, but DELETE generally is suspicious in reporting
            if stmt_type == 'DELETE':
                 warnings.append(f"🚨 UWAGA! Znaleziono komendę DELETE")
            else:
                 warnings.append(f"🚨 UWAGA! Niebezpieczne komendy: {stmt_type}")

        # recursive check for tokens (e.g. inside dynamic SQL strings or subqueries? dynamic SQL is hard)
        # We'll stick to top-level or clearly identifiable tokens
        for token in stmt.flatten():
            if token.ttype is Keyword.DDL and token.value.upper() in forbidden:
                 warnings.append(f"🚨 UWAGA! Niebezpieczne komendy DDL: {token.value.upper()}")

    # Check 3: Encoding (basic)
    if '\ufeff' in sql_text:
         warnings.append("ℹ️ Wykryto BOM (Byte Order Mark)")

    critical = any('🚨' in w for w in warnings)
    return not critical, warnings


def extract_columns(sql_text: str) -> List[Dict[str, str]]:
    """
    Extract columns (aliases) from the main SELECT statement.
    Returns list of dicts: {'name': 'Alias', 'source': 'original_col'}
    """
    parsed = sqlparse.parse(sql_text)
    if not parsed:
        return []

    # Find the first SELECT statement (or the main one)
    # In a script with DECLAREs, the SELECT usually comes last or after set up.
    # We look for the *last* SELECT statement which usually produces the result.
    select_stmt = None
    for stmt in reversed(parsed):
        if stmt.get_type() == 'SELECT':
            select_stmt = stmt
            break

    if not select_stmt:
        # Fallback: look for SELECT token inside
        for stmt in reversed(parsed):
             if any(t.ttype is DML and t.value.upper() == 'SELECT' for t in stmt.flatten()):
                 select_stmt = stmt
                 break

    if not select_stmt:
        return []

    # Extract identifiers from the SELECT list
    # The columns are between SELECT and FROM

    columns = []

    # Helper to clean identifier
    def clean_ident(val):
        return val.strip('[]"\'` ')

    # Iterate tokens to find the identifier list after SELECT
    # We find the SELECT token manually
    idx = -1
    for i, token in enumerate(select_stmt.tokens):
        if token.ttype is DML and token.value.upper() == 'SELECT':
            idx = i
            break

    if idx == -1:
        return []

    # Iterate tokens after SELECT
    # We expect Identifiers or IdentifierList until we hit FROM/INTO/WHERE/semicolon or end

    # Helpers
    def get_alias_manual(token):
        # sqlparse sometimes doesn't detect alias if it's single quoted or complex
        # Look for AS keyword inside tokens
        if not token.is_group:
            return None

        # Check standard alias
        if isinstance(token, Identifier):
             std_alias = token.get_alias()
             if std_alias: return std_alias

        # Manual scan inside identifier tokens
        tokens = token.flatten()
        found_as = False
        last_tok = None
        for t in tokens:
            if t.ttype is Keyword and t.value.upper() == 'AS':
                found_as = True
                continue
            if found_as:
                if t.ttype in (Name, Literal.String.Symbol, Literal.String.Single):
                     return t.value
            last_tok = t

        # If no AS, but last token is a string/identifier, it might be implicit alias
        # But this is risky (e.g. function call params). sqlparse usually handles 'col alias'
        # We'll stick to 'AS' search if standard fail
        return None

    def process_identifier(identifier):
        if isinstance(identifier, Identifier):
            alias = get_alias_manual(identifier)
            if not alias:
                alias = identifier.get_alias()

            if alias:
                columns.append(clean_ident(alias))
            else:
                name = identifier.get_real_name()
                if name:
                    columns.append(clean_ident(name))
                else:
                    columns.append(clean_ident(str(identifier)))
        elif isinstance(identifier, Function):
             alias = identifier.get_alias() or identifier.get_name()
             columns.append(clean_ident(alias))
        else:
             columns.append(clean_ident(str(identifier)))

    # Scan tokens after SELECT
    for i in range(idx + 1, len(select_stmt.tokens)):
        token = select_stmt.tokens[i]

        if token.is_whitespace or (token.ttype is Punctuation and token.value == ','):
            continue

        # Stop at FROM or other DML keywords
        if token.ttype is Keyword.DML or (token.ttype is Keyword and token.value.upper() in ('FROM', 'INTO', 'WHERE', 'GROUP BY')):
            break

        if isinstance(token, IdentifierList):
            for identifier in token.get_identifiers():
                process_identifier(identifier)
        elif isinstance(token, (Identifier, Function)):
            process_identifier(token)
        elif token.ttype is Wildcard:
            # * is usually ignored in column caption list unless aliased?
            # In BI we usually need named columns. * expands to many.
            # We skip * for now or add it as is
            pass
        elif token.is_group:
            # Sometimes a group that isn't IdentifierList (e.g. due to comments)
            # Treat as potential identifier
            # But ensure it's not a Comment
            if not isinstance(token, sqlparse.sql.Comment):
                 process_identifier(token)

    # Filter out technical columns
    valid_cols = []
    for name in columns:
        if _is_valid_column(name):
            valid_cols.append({'name': name, 'caption': name})

    return valid_cols

def _is_valid_column(name: str) -> bool:
    blocked = {'__PROCID__', '__ORGID__', '__DATABASE__', 'Baza Firmowa'}
    if name in blocked:
        return False
    for b in blocked:
        if b in name and b.startswith('__'):
             return False
    return True

def extract_parameters(sql_text: str) -> List[Dict[str, Any]]:
    """
    Extract declared variables and inferred parameters.
    """
    params = []
    declared_names = set()

    # 1. Parse DECLARE statements using regex is still often more reliable for T-SQL 'DECLARE'
    # because sqlparse splits them in ways that vary.
    # However, we can use sqlparse to find variables more robustly.

    # We will stick to the regex logic for DECLARE because it captures type and default value
    # in one go which is complex in sqlparse (it treats data types as Keywords or Names).
    # But we can use sqlparse to find *used* variables that are NOT declared.

    # Regex for DECLARE (reusing logic from original but isolated here)
    for m in re.finditer(r"(?im)^\s*DECLARE\s+(.+?)(?:;|$)", sql_text):
        decl_body = m.group(1)
        # Parse individual declarations in the body
        for tok in re.finditer(r"@(?P<name>\w+)\s+(?P<type>[A-Za-z]+(?:\([^\)]*\))?)\s*(?:=\s*(?P<default>[^,\n;]+))?", decl_body):
            name = tok.group('name').upper()
            sql_type = tok.group('type')
            default = (tok.group('default') or '').strip()

            params.append({
                'name': name,
                'sql_type': sql_type,
                'default': default,
                'declared': True
            })
            declared_names.add(name)

    # 2. Find usage of variables using sqlparse
    parsed = sqlparse.parse(sql_text)
    used_vars = set()

    def walk_tokens(tokens):
        for token in tokens:
            if token.ttype == Name and token.value.startswith('@'):
                used_vars.add(token.value[1:].upper()) # strip @
            if token.is_group:
                walk_tokens(token.tokens)

    for stmt in parsed:
        walk_tokens(stmt.flatten())

    # Filter for potential parameters
    potential = used_vars - declared_names

    # Filter known exclusions
    exclusions = {
        'BAZAFIRMOWA', 'INPUT', 'DZISIEJSZADATA', 'SQL', 'SQLA', 'SQLB', 'SELECT',
        'KOLUMNY', 'I', 'WERSJA', 'OPERATORZY', 'BAZY', 'SERWERKONF', 'BAZAKONF',
        'POZIOM', 'POZIOM_MAX', 'FETCH_STATUS', 'ATRYBUT_ID', 'ATRYBUT_KOD',
        'ATRYBUT_TYP', 'ATRYBUT_FORMAT', 'ATRYBUTYTWR', 'ATRYBUTYZAS', 'ATRYBUTYZAS2', 'BRAK'
    }

    for var in potential:
        if var in exclusions:
            continue

        # Heuristics for "Is this a parameter?"
        # 1. Starts with PARAM
        # 2. Is PRZEDZIALn
        # 3. Is known BI param (DATAOD, DATADO etc - these are handled by converter logic usually,
        #    but we can emit them here as inferred)

        is_param = (var.startswith('PARAM') or
                    re.fullmatch(r'PRZEDZIAL\d+', var) or
                    var in {'DATAOD', 'DATADO', 'DATAPOCZATEKROKU', 'DATAKONIECROKU'})

        if is_param:
            params.append({
                'name': var,
                'sql_type': 'NVARCHAR', # default assumption
                'default': '',
                'declared': False
            })

    return params
