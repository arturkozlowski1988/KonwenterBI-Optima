import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path


def get_logger(name: str = "bi-converter") -> logging.Logger:
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger

    logger.setLevel(logging.INFO)

    # Ensure logs directory exists relative to project root (two levels up possible)
    # Try workspace/docs/logs first
    base = Path(__file__).resolve().parents[2] if len(Path(__file__).resolve().parents) >= 3 else Path.cwd()
    logs_dir = base / 'logs'
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except Exception:
        logs_dir = Path.cwd() / 'logs'
        logs_dir.mkdir(parents=True, exist_ok=True)

    file_handler = RotatingFileHandler(logs_dir / 'app.log', maxBytes=1024 * 1024, backupCount=3, encoding='utf-8')
    file_formatter = logging.Formatter('%(asctime)s | %(levelname)s | %(name)s | %(message)s')
    file_handler.setFormatter(file_formatter)
    file_handler.setLevel(logging.INFO)

    console_handler = logging.StreamHandler()
    console_formatter = logging.Formatter('%(levelname)s: %(message)s')
    console_handler.setFormatter(console_formatter)
    console_handler.setLevel(logging.INFO)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    logger.propagate = False
    logger.info("Logger initialized")
    return logger
