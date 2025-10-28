#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import sys
from pathlib import Path

from .converter import ComarchBIConverter, ConversionError
from .gui import main as gui_main
from .logging_conf import get_logger


def main(argv=None):
    argv = argv or sys.argv[1:]
    parser = argparse.ArgumentParser(description="Comarch BI SQL -> XML Converter")
    parser.add_argument("sql", nargs="?", help="Path to .sql file")
    parser.add_argument("--server", default="SERWEROPTIMA\\SUL02")
    parser.add_argument("--database", default="CDN_Ulex_2018_temp")
    parser.add_argument("--name", default="Ulex_2018_temp", help="Connection name")
    parser.add_argument("--conn-mode", choices=["auto", "embedded", "default"], default="auto", help="Connection embedding strategy: auto (infer), embedded (write server/db), default (leave empty and rely on BI default connection)")
    parser.add_argument("--gui", action="store_true", help="Launch GUI instead of CLI")
    parser.add_argument("--config", default=None, help="Path to config.json with overrides")
    parser.add_argument("--from-xml", dest="from_xml", default=None, help="Extract SQL reports from given XML file")
    parser.add_argument("--output-dir", dest="output_dir", default=None, help="Target directory for extracted SQL files")

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
        out = conv.convert(args.sql, {
            'server': args.server,
            'database': args.database,
            'connection_name': args.name,
            'mode': args.conn_mode,
        })
        print(out)
    except ConversionError as e:
        logger.error(f"Conversion failed: {e}")
        print(f"Error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
