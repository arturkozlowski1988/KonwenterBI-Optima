import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from pathlib import Path
import threading

from ..converter import ComarchBIConverter
from ..logging_conf import get_logger
from ..settings import save_settings
from ..sql_analyzer import format_sql
from .progress_window import ProgressWindow
from .preview_windows import PreviewWindow

try:
    from tkinterdnd2 import DND_FILES
except ImportError:
    DND_FILES = None

class SQLTab:
    def __init__(self, notebook, settings, recent_manager=None):
        self.logger = get_logger()
        self.frame = tk.Frame(notebook)
        notebook.add(self.frame, text="SQL → XML")

        self.settings = settings
        self.recent_manager = recent_manager

        # Variables
        self.sql_var = tk.StringVar()
        self.sql_files = []
        self.server_var = tk.StringVar(value=settings.get("server", "SERWEROPTIMA\\SUL02"))
        self.db_var = tk.StringVar(value=settings.get("database", "CDN_Ulex_2018_temp"))
        self.conn_name_var = tk.StringVar(value=settings.get("connection_name", "Ulex_2018_temp"))
        self.conn_mode_var = tk.StringVar(value=settings.get("mode", "auto"))
        self.debug_var = tk.BooleanVar(value=settings.get("debug", "false").lower() in ("true", "1", "yes"))
        self.status_var = tk.StringVar(value="Gotowy.")

        self._build_ui()

    def _build_ui(self):
        pad = {"padx": 8, "pady": 6}

        # SQL file selection
        tk.Label(self.frame, text="Plik SQL:").grid(row=0, column=0, sticky="w", **pad)
        entry = tk.Entry(self.frame, textvariable=self.sql_var, width=48)
        entry.grid(row=0, column=1, sticky="ew", **pad)

        if DND_FILES:
            try:
                entry.drop_target_register(DND_FILES)
                entry.dnd_bind('<<Drop>>', self._on_drop)
            except Exception:
                pass

        ttk.Button(self.frame, text="Wybierz...", command=self._choose_sql).grid(row=0, column=2, **pad)

        # Connection fields
        tk.Label(self.frame, text="Serwer:").grid(row=1, column=0, sticky="w", **pad)
        tk.Entry(self.frame, textvariable=self.server_var).grid(row=1, column=1, sticky="ew", **pad)

        tk.Label(self.frame, text="Baza danych:").grid(row=2, column=0, sticky="w", **pad)
        tk.Entry(self.frame, textvariable=self.db_var).grid(row=2, column=1, sticky="ew", **pad)

        tk.Label(self.frame, text="Nazwa połączenia:").grid(row=3, column=0, sticky="w", **pad)
        tk.Entry(self.frame, textvariable=self.conn_name_var).grid(row=3, column=1, sticky="ew", **pad)

        # Connection mode
        tk.Label(self.frame, text="Tryb połączenia:").grid(row=4, column=0, sticky="w", **pad)
        ttk.Combobox(self.frame, textvariable=self.conn_mode_var, values=("auto", "embedded", "default"), state="readonly").grid(row=4, column=1, sticky="ew", **pad)

        # Debug toggle
        debug_frame = tk.Frame(self.frame)
        debug_frame.grid(row=5, column=0, columnspan=3, sticky="w", **pad)
        ttk.Checkbutton(debug_frame, text="Loguj debug", variable=self.debug_var, command=self._toggle_debug).pack(side=tk.LEFT)

        # Action buttons
        action_frame = tk.Frame(self.frame)
        action_frame.grid(row=6, column=0, columnspan=3, sticky="w", **pad)
        ttk.Button(action_frame, text="🔍 Podgląd metadanych", command=self._preview).pack(side=tk.LEFT, padx=(0, 8))
        ttk.Button(action_frame, text="🖋️ Formatuj SQL", command=self._format_sql).pack(side=tk.LEFT, padx=(0, 8))
        ttk.Button(action_frame, text="⚙️ Konwertuj", command=self.run_conversion).pack(side=tk.LEFT)

        # Status label
        tk.Label(self.frame, textvariable=self.status_var, fg="#555").grid(row=7, column=0, columnspan=3, sticky="w", **pad)

        self.frame.grid_columnconfigure(1, weight=1)

    def _on_drop(self, event):
        path = event.data
        if path:
            path = path.strip('{}')
            self.load_file(path)

    def load_file(self, path: str):
        path = str(Path(path).resolve())
        self.sql_files = [path]
        self.sql_var.set(path)
        self.status_var.set(f"Wczytano: {Path(path).name}")

        if self.recent_manager:
            self.recent_manager.add_file(path)
            if hasattr(self.recent_manager, 'on_update') and self.recent_manager.on_update:
                self.recent_manager.on_update()

    def _choose_sql(self):
        paths = filedialog.askopenfilenames(
            title="Wybierz plik(i) SQL (Shift/Ctrl dla wielu)",
            filetypes=[("SQL files", "*.sql"), ("All files", "*.*")]
        )
        if paths:
            self.sql_files = list(paths)
            if len(paths) == 1:
                self.load_file(paths[0])
            else:
                self.sql_var.set(f"{len(paths)} plików wybranych")
                self.status_var.set(f"Wybrano {len(paths)} plików SQL")
                if self.recent_manager:
                    for p in paths:
                         self.recent_manager.add_file(p)
                    if hasattr(self.recent_manager, 'on_update') and self.recent_manager.on_update:
                        self.recent_manager.on_update()

    def _toggle_debug(self):
        try:
            level = "DEBUG" if self.debug_var.get() else "INFO"
            import logging
            root_logger = logging.getLogger('bi-converter')
            for h in list(root_logger.handlers):
                h.setLevel(getattr(logging, level))
            root_logger.setLevel(getattr(logging, level))
            self.settings["debug"] = "true" if self.debug_var.get() else "false"
            save_settings(self.settings)
        except Exception:
            pass

    def _preview(self):
        if self.sql_files:
            sql_paths = self.sql_files
        else:
            sql_path = self.sql_var.get().strip()
            if not sql_path:
                messagebox.showwarning("Brak pliku", "Wskaż plik .sql")
                return
            sql_paths = [sql_path]

        try:
            conv = ComarchBIConverter(logger=self.logger)
            theme = self.settings.get("theme", "light")
            PreviewWindow(self.frame.winfo_toplevel(), sql_paths, conv, theme_name=theme)
        except Exception as e:
            self.logger.exception("Preview failed")
            messagebox.showerror("Błąd", f"Nie można otworzyć podglądu:\n{e}")

    def _format_sql(self):
        if not self.sql_files:
            sql_path = self.sql_var.get().strip()
            if not sql_path:
                messagebox.showwarning("Brak pliku", "Wskaż plik(i) .sql")
                return
            files = [sql_path]
        else:
            files = self.sql_files

        count = 0
        try:
            for fpath in files:
                p = Path(fpath)
                try:
                    text = p.read_text(encoding='utf-8')
                except Exception:
                    try:
                        text = p.read_text(encoding='cp1250')
                    except Exception:
                        continue

                formatted = format_sql(text)

                if formatted != text:
                    backup = p.with_suffix('.sql.bak')
                    p.write_text(text, encoding='utf-8')
                    p.rename(backup)
                    p.write_text(formatted, encoding='utf-8')
                    count += 1

            if count > 0:
                messagebox.showinfo("Sukces", f"Sformatowano {count} plików. Oryginały zapisano jako .bak")
                self.status_var.set(f"Sformatowano {count} plików.")
            else:
                 messagebox.showinfo("Info", "Pliki nie wymagały formatowania lub nie udało się ich odczytać.")

        except Exception as e:
            self.logger.error(f"Format failed: {e}")
            messagebox.showerror("Błąd", f"Błąd formatowania: {e}")

    def run_conversion(self):
        if not self.sql_files:
            sql_path = self.sql_var.get().strip()
            if not sql_path:
                messagebox.showwarning("Brak pliku", "Wskaż plik(i) .sql")
                return
            self.sql_files = [sql_path]

        if self.conn_mode_var.get().strip().lower() == 'embedded':
            if not self.server_var.get().strip() or not self.db_var.get().strip():
                messagebox.showerror("Brak danych połączenia", "W trybie 'embedded' wymagane są: Serwer i Baza danych.")
                return

        conv = ComarchBIConverter(logger=self.logger)
        validation_errors = []
        validation_warnings = []

        for sql_path in self.sql_files:
            try:
                sql_text = Path(sql_path).read_text(encoding='utf-8-sig')
            except Exception:
                try:
                    sql_text = Path(sql_path).read_text(encoding='cp1250', errors='replace')
                except Exception as e:
                    messagebox.showerror("Błąd", f"Nie można odczytać pliku {Path(sql_path).name}:\n{e}")
                    return

            is_valid, warnings = conv.validate_sql(sql_text)

            if not is_valid:
                validation_errors.append(f"{Path(sql_path).name}:\n  " + "\n  ".join(warnings))
            elif warnings:
                validation_warnings.append(f"{Path(sql_path).name}:\n  " + "\n  ".join(warnings))

        if validation_errors:
            error_text = "\n\n".join(validation_errors)
            messagebox.showerror("Błędy walidacji", f"Znaleziono krytyczne błędy w plikach SQL:\n\n{error_text}\n\nKonwersja anulowana.")
            self.status_var.set("Błędy walidacji - popraw SQL.")
            return

        if validation_warnings:
            warning_text = "\n\n".join(validation_warnings)
            proceed = messagebox.askyesno("Ostrzeżenia walidacji", f"Znaleziono ostrzeżenia:\n\n{warning_text}\n\nKontynuować konwersję?", icon='warning')
            if not proceed:
                self.status_var.set("Konwersja anulowana przez użytkownika.")
                return

        is_multi_file = len(self.sql_files) > 1
        file_count_text = f"{len(self.sql_files)} plików" if is_multi_file else "pliku"

        progress = ProgressWindow(self.frame.winfo_toplevel(), "Konwersja", f"Konwertowanie {file_count_text} SQL do XML...")

        result = {'success': False, 'output': None, 'error': None}

        def run_conversion_thread():
            try:
                conn_config = {
                    'server': self.server_var.get().strip(),
                    'database': self.db_var.get().strip(),
                    'connection_name': self.conn_name_var.get().strip(),
                    'mode': self.conn_mode_var.get().strip(),
                }

                if is_multi_file:
                    output_xml = Path(self.sql_files[0]).parent / "combined_reports.xml"
                    out = conv.convert_multiple(self.sql_files, conn_config, output_xml_path=str(output_xml))
                else:
                    out = conv.convert(self.sql_files[0], conn_config)

                result['success'] = True
                result['output'] = out
            except Exception as e:
                result['success'] = False
                result['error'] = e

        def check_completion():
            if thread.is_alive():
                self.frame.after(100, check_completion)
            else:
                progress.close()
                if result['success']:
                    try:
                        self.settings.update({
                            'server': self.server_var.get().strip(),
                            'database': self.db_var.get().strip(),
                            'connection_name': self.conn_name_var.get().strip(),
                            'mode': self.conn_mode_var.get().strip(),
                            'debug': str(self.debug_var.get()).lower(),
                        })
                        save_settings(self.settings)
                    except Exception:
                        pass

                    success_msg = f"Zapisano plik XML:\n{result['output']}"
                    if is_multi_file:
                        success_msg += f"\n\n({len(self.sql_files)} raportów SQL)"

                    messagebox.showinfo("Sukces", success_msg)
                    self.status_var.set(f"Zapisano: {Path(result['output']).name}")
                else:
                    self.logger.exception("Conversion failed", exc_info=result['error'])
                    messagebox.showerror("Błąd", f"Konwersja nie powiodła się:\n{result['error']}")
                    self.status_var.set("Błąd konwersji.")

        thread = threading.Thread(target=run_conversion_thread, daemon=True)
        thread.start()
        self.frame.after(100, check_completion)
