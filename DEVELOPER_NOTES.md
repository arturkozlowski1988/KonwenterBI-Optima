# Developer Notes

This project uses Python + Tkinter for the GUI and pytest for tests. Use `pyinstaller` to build standalone executables.

Key commands:

- Create venv: python -m venv .venv; .\.venv\Scripts\Activate.ps1
- Install deps: pip install -r requirements-dev.txt
- Run tests: pytest
- Build exe: pyinstaller --onefile --name app_entry app_entry.py
