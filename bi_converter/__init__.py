"""
bi_converter package: SQL -> XML converter for Comarch Analizy BI

Modules:
- converter: Core conversion logic with auto-detection of interactive params
- gui: Simple Tkinter GUI to select SQL and convert
- logging_conf: Logging configuration (rotating file logs)
"""

from .converter import ComarchBIConverter, ConversionError

__all__ = [
    "ComarchBIConverter",
    "ConversionError",
]
