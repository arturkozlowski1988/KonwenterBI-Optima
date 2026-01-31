# -*- coding: utf-8 -*-
"""
SQL Analysis module using sqlparse.
Provides robust extraction of columns and parameters, validation, and formatting.
"""
from __future__ import annotations
import re
from typing import List, Dict, Tuple, Set, Optional, Any
import sqlparse
from sqlparse.sql import IdentifierList, Identifier, Function, Where, Comparison, Token, Comment
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
            identifier_case=None,
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

    parsed = sqlparse.parse(sql_text)
    if not parsed:
        warnings.append("⚠️ Pusty plik lub błąd parsowania")
        return False, warnings

    statements = [stmt for stmt in parsed if stmt.get_type() != 'UNKNOWN']

    # Check 1: SELECT present
    has_select = any(stmt.get_type() == 'SELECT' for stmt in statements)
    if not has_select:
        # Check tokens of the last statement
        last_stmt = parsed[-1]
        if not any(t.ttype is DML and t.value.upper() == 'SELECT' for t in last_stmt.flatten()):
             warnings.append("⚠️ Brak instrukcji SELECT - to nie wygląda na zapytanie")

    # Check 2: Dangerous commands
    forbidden = {'DROP', 'TRUNCATE', 'DELETE', 'UPDATE', 'INSERT', 'ALTER', 'GRANT', 'REVOKE'}

    for stmt in parsed:
        stmt_type = stmt.get_type().upper()
        if stmt_type in forbidden:
            if stmt_type == 'DELETE':
                 warnings.append(f"🚨 UWAGA! Znaleziono komendę DELETE")
            else:
                 warnings.append(f"🚨 UWAGA! Niebezpieczne komendy: {stmt_type}")

        for token in stmt.flatten():
            if token.ttype is Keyword.DDL and token.value.upper() in forbidden:
                 warnings.append(f"🚨 UWAGA! Niebezpieczne komendy DDL: {token.value.upper()}")

    if '\ufeff' in sql_text:
         warnings.append("ℹ️ Wykryto BOM (Byte Order Mark)")

    critical = any('🚨' in w for w in warnings)
    return not critical, warnings


def extract_columns(sql_text: str) -> List[Dict[str, str]]:
    """
    Extract columns (aliases) from the main SELECT statement.
    Returns list of dicts: {'name': 'Alias', 'caption': 'Alias'}
    """
    parsed = sqlparse.parse(sql_text)
    if not parsed:
        return []

    # Find the main SELECT statement (usually the last one)
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

    columns = []

    def clean_ident(val):
        return val.strip('[]"\'` ')

    def get_alias_safe(token):
        # built-in get_alias is good, but sometimes misses manual AS
        alias = token.get_alias()
        if alias:
            return alias

        # Manual check for AS pattern if sqlparse missed it
        if token.is_group:
            tokens = list(token.flatten())
            for i, t in enumerate(tokens):
                if t.ttype is Keyword and t.value.upper() == 'AS':
                    # The next significant token is the alias
                    for next_t in tokens[i+1:]:
                        if not next_t.is_whitespace and not isinstance(next_t, Comment):
                            return next_t.value
        return None

    def process_identifier(identifier):
        alias = get_alias_safe(identifier)
        if not alias:
            # If no alias, use the name (e.g. col1)
            # But sqlparse might return full string if complex
            alias = identifier.get_real_name() or identifier.get_name()

        if alias:
            name = clean_ident(alias)
            if _is_valid_column(name):
                columns.append({'name': name, 'caption': name})

    # Iterate tokens after SELECT until FROM
    # We find the SELECT token
    idx_select = -1
    idx_end = len(select_stmt.tokens)

    for i, token in enumerate(select_stmt.tokens):
        if token.ttype is DML and token.value.upper() == 'SELECT':
            idx_select = i
            continue

        # Check for end of column list (FROM, WHERE, etc)
        # Note: FROM might be inside a subquery, so we check top-level tokens
        if idx_select != -1:
            if token.ttype is Keyword and token.value.upper() in ('FROM', 'INTO', 'WHERE', 'GROUP BY', 'HAVING'):
                idx_end = i
                break
            if token.ttype is DML: # another SELECT or UPDATE?
                 pass

    if idx_select == -1:
        return []

    for i in range(idx_select + 1, idx_end):
        token = select_stmt.tokens[i]

        if token.is_whitespace or (token.ttype is Punctuation and token.value == ','):
            continue

        if isinstance(token, IdentifierList):
            for identifier in token.get_identifiers():
                process_identifier(identifier)
        elif isinstance(token, (Identifier, Function)):
            process_identifier(token)
        elif token.is_group and not isinstance(token, Comment):
             # Try to treat as identifier
             process_identifier(token)

    return columns

def _is_valid_column(name: str) -> bool:
    if not name: return False
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

    # 1. Regex for DECLARE (most reliable for T-SQL variable declarations)
    for m in re.finditer(r"(?im)^\s*DECLARE\s+(.+?)(?:;|$)", sql_text):
        decl_body = m.group(1)
        # Parse individual declarations
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
                used_vars.add(token.value[1:].upper())
            if token.is_group:
                walk_tokens(token.tokens)

    for stmt in parsed:
        walk_tokens(stmt.flatten())

    # Filter for potential parameters
    potential = used_vars - declared_names

    exclusions = {
        'BAZAFIRMOWA', 'INPUT', 'DZISIEJSZADATA', 'SQL', 'SQLA', 'SQLB', 'SELECT',
        'KOLUMNY', 'I', 'WERSJA', 'OPERATORZY', 'BAZY', 'SERWERKONF', 'BAZAKONF',
        'POZIOM', 'POZIOM_MAX', 'FETCH_STATUS', 'ATRYBUT_ID', 'ATRYBUT_KOD',
        'ATRYBUT_TYP', 'ATRYBUT_FORMAT', 'ATRYBUTYTWR', 'ATRYBUTYZAS', 'ATRYBUTYZAS2', 'BRAK'
    }

    for var in potential:
        if var in exclusions:
            continue

        # Heuristics
        is_param = (var.startswith('PARAM') or
                    re.fullmatch(r'PRZEDZIAL\d+', var) or
                    var in {'DATAOD', 'DATADO', 'DATAPOCZATEKROKU', 'DATAKONIECROKU'})

        if is_param:
            params.append({
                'name': var,
                'sql_type': 'NVARCHAR', # default
                'default': '',
                'declared': False
            })

    return params
