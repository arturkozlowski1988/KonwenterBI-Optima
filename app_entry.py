#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import sys
import os
from pathlib import Path
from bi_converter.converter import ComarchBIConverter, ConversionError
from bi_converter.gui import main as gui_main
from bi_converter.logging_conf import get_logger

# PyInstaller --windowed fix: restore sys.stdout/stderr if None
# This prevents AttributeError when argparse tries to print help
if sys.stdout is None:
    sys.stdout = open(os.devnull, "w")
if sys.stderr is None:
    sys.stderr = open(os.devnull, "w")

def main(argv=None):
    argv = argv or sys.argv[1:]
    parser = argparse.ArgumentParser(description="Comarch BI SQL -> XML Converter")
    parser.add_argument("sql", nargs="*", help="Path to .sql file(s). Multiple files will be combined into one XML")
    parser.add_argument("--server", default=r"SERWEROPTIMA\SUL02")
    parser.add_argument("--database", default="CDN_Ulex_2018_temp")
    parser.add_argument("--name", default="Ulex_2018_temp", help="Connection name")
    parser.add_argument("--conn-mode", choices=["auto", "embedded", "default"], default="auto", help="Connection embedding strategy")
    parser.add_argument("--gui", action="store_true", help="Launch GUI instead of CLI")
    parser.add_argument("--config", default=None, help="Path to config.json with overrides")
    parser.add_argument("--from-xml", dest="from_xml", default=None, help="Extract SQL reports from given XML file")
    parser.add_argument("--output-dir", dest="output_dir", default=None, help="Target directory for extracted SQL files")
    parser.add_argument("--output", "-o", dest="output", default=None, help="Output XML filename for multiple SQL files")

    args = parser.parse_args(argv)
    
    if args.sql and args.from_xml:
        parser.error("Provide either SQL input or --from-xml, not both.")
    
    logger = get_logger()

    if args.gui or (not args.sql and not args.from_xml):
        return gui_main()

    # XML → SQL extraction mode
    if args.from_xml:
        conv = ComarchBIConverter(logger=logger, config_path=Path(args.config) if args.config else None)
        try:
            outputs = conv.write_sql_reports(args.from_xml, args.output_dir)
        except ConversionError as e:
            logger.error(f"Extraction failed: {e}")
            print(f"Error: {e}", file=sys.stderr)
            return 1
        
        for out_path in outputs:
            print(out_path)
        return 0

    # SQL → XML conversion mode
    conv = ComarchBIConverter(logger=logger, config_path=Path(args.config) if args.config else None)
    try:
        conn_config = {
            'server': args.server, 
            'database': args.database, 
            'connection_name': args.name, 
            'mode': args.conn_mode
        }
        
        # Multiple files - use convert_multiple
        if len(args.sql) > 1:
            out = conv.convert_multiple(args.sql, conn_config, output_xml_path=args.output)
            print(out)
        # Single file - use standard convert
        elif len(args.sql) == 1:
            out = conv.convert(args.sql[0], conn_config)
            print(out)
        else:
            parser.error("No SQL file(s) provided")
            return 1
            
    except ConversionError as e:
        logger.error(f"Conversion failed: {e}")
        print(f"Error: {e}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
