import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from pathlib import Path
import threading

from ..converter import ComarchBIConverter
from ..logging_conf import get_logger
from .progress_window import ProgressWindow
from .preview_windows import XMLPreviewWindow

try:
    from tkinterdnd2 import DND_FILES
except ImportError:
    DND_FILES = None

class XMLTab:
    def __init__(self, notebook, settings, recent_manager=None):
        self.logger = get_logger()
        self.frame = tk.Frame(notebook)
        notebook.add(self.frame, text="XML → SQL")

        self.settings = settings
        self.recent_manager = recent_manager

        # Variables
        self.xml_file_var = tk.StringVar()
        self.output_dir_var = tk.StringVar()
        self.status_var = tk.StringVar(value="Wybierz plik XML.")

        self._build_ui()

    def _build_ui(self):
        pad = {"padx": 8, "pady": 6}

        # XML file selection
        tk.Label(self.frame, text="Plik XML:").grid(row=0, column=0, sticky="w", **pad)
        entry = tk.Entry(self.frame, textvariable=self.xml_file_var, width=48)
        entry.grid(row=0, column=1, sticky="ew", **pad)

        if DND_FILES:
            try:
                entry.drop_target_register(DND_FILES)
                entry.dnd_bind('<<Drop>>', self._on_drop_xml)
            except Exception:
                pass

        ttk.Button(self.frame, text="Wybierz...", command=self._choose_xml).grid(row=0, column=2, **pad)

        # Output directory (optional)
        tk.Label(self.frame, text="Folder docelowy (opcjonalnie):").grid(row=1, column=0, sticky="w", **pad)
        out_entry = tk.Entry(self.frame, textvariable=self.output_dir_var)
        out_entry.grid(row=1, column=1, sticky="ew", **pad)

        if DND_FILES:
            try:
                out_entry.drop_target_register(DND_FILES)
                out_entry.dnd_bind('<<Drop>>', self._on_drop_dir)
            except Exception:
                pass

        ttk.Button(self.frame, text="Wybierz...", command=self._choose_output_dir).grid(row=1, column=2, **pad)

        # Info label
        info_text = "💡 Jeśli nie wybierzesz folderu docelowego, pliki SQL zostaną zapisane w tym samym miejscu co plik XML."
        tk.Label(self.frame, text=info_text, fg="#555", wraplength=700, justify="left").grid(row=2, column=0, columnspan=3, sticky="w", **pad)

        # Action buttons
        action_frame = tk.Frame(self.frame)
        action_frame.grid(row=3, column=0, columnspan=3, sticky="w", **pad)
        ttk.Button(action_frame, text="🔍 Podgląd raportów", command=self._preview_xml).pack(side=tk.LEFT, padx=(0, 10))
        ttk.Button(action_frame, text="⏬ Wyodrębnij SQL", command=self._convert_xml_to_sql).pack(side=tk.LEFT)

        # Status label
        tk.Label(self.frame, textvariable=self.status_var, fg="#555").grid(row=4, column=0, columnspan=3, sticky="w", **pad)

        self.frame.grid_columnconfigure(1, weight=1)

    def _on_drop_xml(self, event):
        path = event.data
        if path:
            path = path.strip('{}')
            self.load_file(path)

    def _on_drop_dir(self, event):
        path = event.data
        if path:
            path = path.strip('{}')
            if Path(path).is_dir():
                self.output_dir_var.set(path)

    def load_file(self, path: str):
        """Load a file programmatically"""
        path = str(Path(path).resolve())
        self.xml_file_var.set(path)
        self.status_var.set(f"Wczytano: {Path(path).name}")

        if self.recent_manager:
            self.recent_manager.add_file(path)
            if hasattr(self.recent_manager, 'on_update') and self.recent_manager.on_update:
                self.recent_manager.on_update()

    def _choose_xml(self):
        path = filedialog.askopenfilename(title="Wybierz plik XML", filetypes=[("XML files", "*.xml"), ("All files", "*.*")])
        if path:
            self.load_file(path)

    def _choose_output_dir(self):
        path = filedialog.askdirectory(title="Wybierz folder docelowy")
        if path:
            self.output_dir_var.set(path)

    def _preview_xml(self):
        """Show XML reports preview window"""
        xml_path = self.xml_file_var.get().strip()
        if not xml_path:
            messagebox.showwarning("Brak pliku", "Wskaż plik .xml")
            return

        try:
            conv = ComarchBIConverter(logger=self.logger)
            theme = self.settings.get("theme", "light")
            XMLPreviewWindow(self.frame.winfo_toplevel(), xml_path, conv, theme_name=theme)
        except Exception as e:
            self.logger.exception("XML preview failed")
            messagebox.showerror("Błąd", f"Nie można otworzyć podglądu XML:\n{e}")

    def _convert_xml_to_sql(self):
        """Extract SQL reports from XML file with progress bar"""
        xml_path = self.xml_file_var.get().strip()
        if not xml_path:
            messagebox.showwarning("Brak pliku", "Wskaż plik .xml")
            return

        out_dir = self.output_dir_var.get().strip() or None

        progress = ProgressWindow(self.frame.winfo_toplevel(), "Ekstrakcja", "Ekstrakcja SQL z pliku XML...")

        result = {'success': False, 'outputs': None, 'error': None}

        def run_extraction():
            try:
                conv = ComarchBIConverter(logger=self.logger)
                outputs = conv.write_sql_reports(xml_path, out_dir)
                result['success'] = True
                result['outputs'] = outputs
            except Exception as e:
                result['success'] = False
                result['error'] = e

        def check_completion():
            if thread.is_alive():
                self.frame.after(100, check_completion)
            else:
                progress.close()
                if result['success']:
                    outputs = result['outputs']
                    paths_text = "\n".join(str(p) for p in outputs)
                    messagebox.showinfo("Sukces", f"Wygenerowano {len(outputs)} plików SQL:\n\n{paths_text}")
                    self.status_var.set(f"Wygenerowano {len(outputs)} plików.")
                else:
                    self.logger.exception("XML extraction failed", exc_info=result['error'])
                    messagebox.showerror("Błąd", f"Nie można wyodrębnić SQL:\n{result['error']}")
                    self.status_var.set("Błąd ekstrakcji.")

        thread = threading.Thread(target=run_extraction, daemon=True)
        thread.start()
        self.frame.after(100, check_completion)
