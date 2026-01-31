import json
import tkinter as tk
from tkinter import messagebox, ttk
from pathlib import Path

from ..converter import ComarchBIConverter
from ..theme_manager import ThemeManager
from .syntax_highlighter import SyntaxHighlighter

class XMLPreviewWindow:
    """Window showing preview of XML reports before extraction"""

    def __init__(self, parent: tk.Tk, xml_path: str, converter: ComarchBIConverter, theme_name="light"):
        self.parent = parent
        self.xml_path = Path(xml_path)
        self.converter = converter
        self.logger = converter.logger
        self.theme_name = theme_name

        # Get report summary
        try:
            self.reports = converter.get_xml_report_summary(str(xml_path))
        except Exception as e:
            messagebox.showerror("Błąd", f"Nie można odczytać pliku XML:\n{e}")
            return

        # Build window
        self.window = tk.Toplevel(parent)
        self.window.title(f"Podgląd raportów XML - {self.xml_path.name}")
        self.window.geometry("800x500")

        # Apply theme
        ThemeManager.apply_theme(self.window, self.theme_name)

        self._build_ui()

    def _build_ui(self):
        pad = {"padx": 8, "pady": 6}

        # Header
        header_frame = tk.Frame(self.window)
        header_frame.pack(fill=tk.X, **pad)

        tk.Label(
            header_frame,
            text=f"📄 {self.xml_path.name}",
            font=("Arial", 11, "bold")
        ).pack(anchor="w")

        tk.Label(
            header_frame,
            text=f"Znaleziono {len(self.reports)} raportów SQL",
            font=("Arial", 9),
            fg="#2196F3"
        ).pack(anchor="w")

        # Reports list
        list_frame = tk.Frame(self.window)
        list_frame.pack(fill=tk.BOTH, expand=True, **pad)

        # Treeview with columns
        columns = ("index", "name", "lines", "size")
        self.tree = ttk.Treeview(list_frame, columns=columns, show="headings", height=15)

        self.tree.heading("index", text="#")
        self.tree.heading("name", text="Nazwa raportu")
        self.tree.heading("lines", text="Linie SQL")
        self.tree.heading("size", text="Rozmiar (KB)")

        self.tree.column("index", width=50, anchor="center")
        self.tree.column("name", width=450, anchor="w")
        self.tree.column("lines", width=100, anchor="center")
        self.tree.column("size", width=100, anchor="center")

        # Scrollbar
        scrollbar = ttk.Scrollbar(list_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scrollbar.set)

        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Populate tree
        total_lines = 0
        total_size = 0
        for report in self.reports:
            self.tree.insert("", tk.END, values=(
                report['index'],
                report['name'],
                report['sql_lines'],
                f"{report['sql_size_kb']:.2f}"
            ))
            total_lines += report['sql_lines']
            total_size += report['sql_size_kb']

        # Summary footer
        footer_frame = tk.Frame(self.window)
        footer_frame.pack(fill=tk.X, **pad)

        summary_text = (
            f"📊 Suma: {len(self.reports)} raportów  |  "
            f"{total_lines:,} linii SQL  |  "
            f"{total_size:.2f} KB całkowity rozmiar"
        )
        tk.Label(
            footer_frame,
            text=summary_text,
            font=("Arial", 9, "bold"),
            fg="#4CAF50"
        ).pack(side=tk.LEFT)

        # Close button
        tk.Button(
            footer_frame,
            text="Zamknij",
            command=self.window.destroy
        ).pack(side=tk.RIGHT, padx=5)


class PreviewWindow:
    """Window displaying metadata preview with config export capability

    Supports both single and multiple file preview with tabs.
    """

    def __init__(self, parent, sql_paths, converter: ComarchBIConverter, theme_name="light"):
        """Initialize preview window

        Args:
            parent: Parent Tk window
            sql_paths: Single path string or list of path strings
            converter: ComarchBIConverter instance
            theme_name: Current theme ("light" or "dark")
        """
        self.parent = parent
        self.converter = converter
        self.logger = converter.logger
        self.theme_name = theme_name

        # Normalize to list of paths
        if isinstance(sql_paths, (str, Path)):
            self.sql_paths = [Path(sql_paths)]
        else:
            self.sql_paths = [Path(p) for p in sql_paths]

        # Extract metadata for all files
        self.file_metadata = []
        failed_files = []

        for sql_path in self.sql_paths:
            try:
                # Read SQL text BOM-aware and with cp1250 fallback
                try:
                    sql_text = sql_path.read_text(encoding='utf-8-sig')
                except Exception:
                    try:
                        sql_text = sql_path.read_text(encoding='utf-8')
                    except Exception:
                        sql_text = sql_path.read_text(encoding='cp1250', errors='replace')

                columns = converter.extract_columns(sql_text)
                all_params = converter.extract_parameters(sql_text)
                auto_detected_interactive = converter.detect_interactive_params(all_params)

                self.file_metadata.append({
                    'path': sql_path,
                    'sql_text': sql_text,
                    'columns': columns,
                    'all_params': all_params,
                    'auto_detected_interactive': auto_detected_interactive
                })
            except Exception as e:
                self.logger.error(f"Failed to read {sql_path.name}: {e}")
                failed_files.append((sql_path.name, str(e)))

        if not self.file_metadata:
            messagebox.showerror("Błąd", "Nie można odczytać żadnego z wybranych plików")
            return

        if failed_files:
            error_msg = "Nie można odczytać następujących plików:\n\n" + \
                       "\n".join([f"• {name}: {err}" for name, err in failed_files])
            messagebox.showwarning("Ostrzeżenie", error_msg)

        # Build window
        self.window = tk.Toplevel(parent)

        # Set title based on file count
        if len(self.file_metadata) == 1:
            self.window.title(f"Podgląd metadanych - {self.file_metadata[0]['path'].name}")
        else:
            self.window.title(f"Podgląd metadanych - {len(self.file_metadata)} plików")

        self.window.geometry("920x680")

        # Apply theme
        ThemeManager.apply_theme(self.window, self.theme_name)

        self._build_ui()

    def _build_ui(self):
        """Build UI - either single file or multi-file tabbed interface"""
        pad = {"padx": 8, "pady": 6}

        if len(self.file_metadata) == 1:
            # Single file - use original layout
            self._build_single_file_ui(self.file_metadata[0], self.window, pad)
        else:
            # Multiple files - create file tabs
            self._build_multi_file_ui(pad)

    def _build_single_file_ui(self, metadata, parent, pad):
        """Build UI for single file preview"""
        # Header
        header_frame = tk.Frame(parent)
        header_frame.pack(fill=tk.X, **pad)
        tk.Label(
            header_frame,
            text=f"📄 {metadata['path'].name}",
            font=("Arial", 11, "bold")
        ).pack(anchor="w")

        # Notebook for tabs (columns/parameters)
        notebook = ttk.Notebook(parent)
        notebook.pack(fill=tk.BOTH, expand=True, **pad)

        # Tab 1: Columns
        col_frame = tk.Frame(notebook)
        notebook.add(col_frame, text=f"Kolumny ({len(metadata['columns'])})")
        self._build_columns_tab(col_frame, metadata)

        # Tab 2: Parameters
        param_frame = tk.Frame(notebook)
        notebook.add(param_frame, text=f"Parametry ({len(metadata['all_params'])})")
        self._build_parameters_tab(param_frame, metadata)

        # Tab 3: SQL Source
        sql_frame = tk.Frame(notebook)
        notebook.add(sql_frame, text="Kod SQL")
        self._build_source_tab(sql_frame, metadata)

        # Footer with actions
        self._build_footer(parent, pad, metadata)

    def _build_multi_file_ui(self, pad):
        """Build UI for multiple file preview with file tabs"""
        # Info header
        header_frame = tk.Frame(self.window)
        header_frame.pack(fill=tk.X, **pad)
        tk.Label(
            header_frame,
            text=f"📚 Podgląd {len(self.file_metadata)} plików SQL",
            font=("Arial", 11, "bold"),
            fg="#2196F3"
        ).pack(anchor="w")

        # Main notebook for files
        file_notebook = ttk.Notebook(self.window)
        file_notebook.pack(fill=tk.BOTH, expand=True, **pad)

        # Create tab for each file
        for idx, metadata in enumerate(self.file_metadata, 1):
            file_frame = tk.Frame(file_notebook)
            file_name = metadata['path'].stem
            if len(file_name) > 20:
                file_name = file_name[:17] + "..."
            file_notebook.add(file_frame, text=f"{idx}. {file_name}")

            # Build content for this file
            self._build_file_content(file_frame, metadata, pad)

        # Footer with global actions
        footer_frame = tk.Frame(self.window)
        footer_frame.pack(fill=tk.X, **pad)

        total_cols = sum(len(m['columns']) for m in self.file_metadata)
        total_params = sum(len(m['all_params']) for m in self.file_metadata)

        summary_text = f"📊 Łącznie: {total_cols} kolumn, {total_params} parametrów"
        tk.Label(footer_frame, text=summary_text, fg="#555", font=("Arial", 9)).pack(side=tk.LEFT, **pad)

        tk.Button(
            footer_frame,
            text="Zamknij",
            command=self.window.destroy,
            padx=12,
            pady=6
        ).pack(side=tk.RIGHT, **pad)

    def _build_file_content(self, parent, metadata, pad):
        """Build columns/parameters tabs for a single file within multi-file view"""
        # File header
        info_frame = tk.Frame(parent)
        info_frame.pack(fill=tk.X, **pad)
        tk.Label(
            info_frame,
            text=f"📄 {metadata['path'].name}",
            font=("Arial", 10, "bold")
        ).pack(anchor="w")

        # Notebook for columns/parameters
        content_notebook = ttk.Notebook(parent)
        content_notebook.pack(fill=tk.BOTH, expand=True, **pad)

        # Tab 1: Columns
        col_frame = tk.Frame(content_notebook)
        content_notebook.add(col_frame, text=f"Kolumny ({len(metadata['columns'])})")
        self._build_columns_tab(col_frame, metadata)

        # Tab 2: Parameters
        param_frame = tk.Frame(content_notebook)
        content_notebook.add(param_frame, text=f"Parametry ({len(metadata['all_params'])})")
        self._build_parameters_tab(param_frame, metadata)

        # Tab 3: SQL Source
        sql_frame = tk.Frame(content_notebook)
        content_notebook.add(sql_frame, text="Kod SQL")
        self._build_source_tab(sql_frame, metadata)

        # Mini footer with export for this file
        mini_footer = tk.Frame(parent)
        mini_footer.pack(fill=tk.X, **pad)

        tk.Button(
            mini_footer,
            text="💾 Eksportuj konfigurację",
            command=lambda: self._export_config_for_file(metadata),
            bg="#4CAF50",
            fg="white",
            padx=8,
            pady=4
        ).pack(side=tk.LEFT, **pad)

    def _build_footer(self, parent, pad, metadata):
        """Build footer with export button for single file view"""
        footer_frame = tk.Frame(parent)
        footer_frame.pack(fill=tk.X, **pad)

        tk.Button(
            footer_frame,
            text="💾 Eksportuj konfigurację do config.json",
            command=lambda: self._export_config_for_file(metadata),
            bg="#4CAF50",
            fg="white",
            padx=12,
            pady=6
        ).pack(side=tk.LEFT, **pad)

        self.status_label = tk.Label(footer_frame, text="", fg="#555")
        self.status_label.pack(side=tk.LEFT, **pad)

        tk.Button(
            footer_frame,
            text="Zamknij",
            command=self.window.destroy
        ).pack(side=tk.RIGHT, **pad)

    def _build_columns_tab(self, parent, metadata):
        """Build columns tab for given file metadata"""
        pad = {"padx": 8, "pady": 6}

        columns = metadata['columns']

        # Info label
        info_text = "Kolumny wykryte automatycznie z zapytania SQL (aliasy AS [Nazwa])"
        tk.Label(parent, text=info_text, fg="#555", wraplength=850, justify="left").pack(anchor="w", **pad)

        # Treeview for columns
        tree_frame = tk.Frame(parent)
        tree_frame.pack(fill=tk.BOTH, expand=True, **pad)

        cols = ("name", "type", "format", "aggregate")
        tree = ttk.Treeview(tree_frame, columns=cols, show="headings", height=20)

        tree.heading("name", text="Nazwa kolumny")
        tree.heading("type", text="Typ")
        tree.heading("format", text="Format")
        tree.heading("aggregate", text="Agregacja")

        tree.column("name", width=400)
        tree.column("type", width=100)
        tree.column("format", width=100)
        tree.column("aggregate", width=100)

        # Add scrollbar
        scrollbar = ttk.Scrollbar(tree_frame, orient=tk.VERTICAL, command=tree.yview)
        tree.configure(yscroll=scrollbar.set)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # Populate
        for col in columns:
            tree.insert("", tk.END, values=(
                col.name,
                col.type,
                col.formatString,
                col.aggregate
            ))

        # Summary
        summary_text = f"✅ Wykryto {len(columns)} kolumn"
        if not columns:
            summary_text = "⚠️ Nie wykryto kolumn - sprawdź, czy zapytanie używa aliasów AS [Nazwa]"
        tk.Label(parent, text=summary_text, fg="#2196F3", font=("Arial", 10, "bold")).pack(anchor="w", **pad)

    def _build_parameters_tab(self, parent, metadata):
        """Build parameters tab for given file metadata"""
        pad = {"padx": 8, "pady": 6}

        all_params = metadata['all_params']
        auto_detected_interactive = metadata['auto_detected_interactive']

        # Info label
        info_text = "Zaznacz parametry, które mają być interaktywne (użytkownik będzie mógł je edytować w BI).\nAutomatycznie wykryte parametry interaktywne są już zaznaczone."
        tk.Label(parent, text=info_text, fg="#555", wraplength=850, justify="left").pack(anchor="w", **pad)

        # Treeview for parameters
        tree_frame = tk.Frame(parent)
        tree_frame.pack(fill=tk.BOTH, expand=True, **pad)

        columns = ("interactive", "name", "type", "default", "declared")
        param_tree = ttk.Treeview(tree_frame, columns=columns, show="tree headings", height=20)

        param_tree.heading("#0", text="")
        param_tree.heading("interactive", text="Interaktywny")
        param_tree.heading("name", text="Nazwa parametru")
        param_tree.heading("type", text="Typ")
        param_tree.heading("default", text="Wartość domyślna")
        param_tree.heading("declared", text="Źródło")

        param_tree.column("#0", width=30)
        param_tree.column("interactive", width=100)
        param_tree.column("name", width=250)
        param_tree.column("type", width=100)
        param_tree.column("default", width=200)
        param_tree.column("declared", width=120)

        # Add scrollbar
        scrollbar = ttk.Scrollbar(tree_frame, orient=tk.VERTICAL, command=param_tree.yview)
        param_tree.configure(yscroll=scrollbar.set)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        param_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # Store param tree reference for this metadata
        if not hasattr(metadata, 'param_tree'):
            metadata['param_tree'] = param_tree
            metadata['param_items'] = {}

        # Populate with checkable items
        auto_interactive_names = {p.name for p in auto_detected_interactive}

        for param in all_params:
            is_interactive = param.name in auto_interactive_names
            check_mark = "☑" if is_interactive else "☐"
            source = "DECLARE" if param.declared else "Wykryty"

            item_id = param_tree.insert("", tk.END, values=(
                check_mark,
                param.name,
                param.type,
                param.defaultValue,
                source
            ))
            metadata['param_items'][item_id] = {
                'param': param,
                'interactive': is_interactive
            }

        # Bind click to toggle checkbox
        param_tree.bind("<Button-1>", lambda e: self._toggle_param_interactive(e, metadata))

        # Summary
        interactive_count = len([p for p in metadata['param_items'].values() if p['interactive']])
        summary_text = f"✅ {len(all_params)} parametrów (zadeklarowanych: {sum(1 for p in all_params if p.declared)}, wykrytych: {sum(1 for p in all_params if not p.declared)})\n"
        summary_text += f"📝 Interaktywnych: {interactive_count}"
        tk.Label(parent, text=summary_text, fg="#2196F3", font=("Arial", 10, "bold"), justify="left").pack(anchor="w", **pad)

    def _build_source_tab(self, parent, metadata):
        """Build SQL source tab with syntax highlighting"""
        pad = {"padx": 8, "pady": 6}

        text_frame = tk.Frame(parent)
        text_frame.pack(fill=tk.BOTH, expand=True, **pad)

        scrollbar = ttk.Scrollbar(text_frame)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Create text widget
        text_widget = tk.Text(text_frame, wrap=tk.NONE, yscrollcommand=scrollbar.set, font=("Consolas", 10))
        text_widget.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=text_widget.yview)

        # Insert SQL
        text_widget.insert("1.0", metadata['sql_text'])
        text_widget.config(state=tk.DISABLED) # Read-only

        # Highlight
        highlighter = SyntaxHighlighter(text_widget, theme=self.theme_name)
        highlighter.highlight()

    def _toggle_param_interactive(self, event, metadata):
        """Toggle interactive checkbox when clicking on parameter row"""
        param_tree = metadata['param_tree']
        param_items = metadata['param_items']

        region = param_tree.identify("region", event.x, event.y)
        if region == "cell" or region == "tree":
            item_id = param_tree.identify_row(event.y)
            if item_id in param_items:
                # Toggle state
                current = param_items[item_id]['interactive']
                new_state = not current
                param_items[item_id]['interactive'] = new_state

                # Update display
                values = list(param_tree.item(item_id, 'values'))
                values[0] = "☑" if new_state else "☐"
                param_tree.item(item_id, values=values)

                self.logger.info(f"Parameter {param_items[item_id]['param'].name} interactive: {new_state}")

    def _export_config_for_file(self, metadata):
        """Export current interactive parameter selection to config.json for specific file"""
        try:
            # Check if param_items exists (user needs to open parameters tab first)
            if 'param_items' not in metadata or not metadata['param_items']:
                messagebox.showwarning(
                    "Brak danych",
                    "Otwórz zakładkę 'Parametry' dla tego pliku przed eksportem konfiguracji."
                )
                return

            # Determine include/exclude lists
            include_list = []
            exclude_list = []

            auto_interactive_names = {p.name for p in metadata['auto_detected_interactive']}

            for item_data in metadata['param_items'].values():
                param = item_data['param']
                is_interactive = item_data['interactive']

                # If manually set to interactive but NOT auto-detected -> include
                if is_interactive and param.name not in auto_interactive_names:
                    include_list.append(param.name)

                # If manually set to non-interactive but WAS auto-detected -> exclude
                if not is_interactive and param.name in auto_interactive_names:
                    exclude_list.append(param.name)

            # Build config structure
            config = {
                "interactive_overrides": {
                    "include": sorted(include_list),
                    "exclude": sorted(exclude_list)
                }
            }

            # Write to config.json in package directory
            pkg_dir = Path(__file__).parent.parent # Go up to bi_converter
            config_path = pkg_dir / 'config.json'

            with open(config_path, 'w', encoding='utf-8') as f:
                json.dump(config, f, ensure_ascii=False, indent=2)

            if hasattr(self, 'status_label'):
                self.status_label.config(text=f"✅ Zapisano do {config_path.name}", fg="green")

            self.logger.info(f"Exported config for {metadata['path'].name}: include={include_list}, exclude={exclude_list}")

            messagebox.showinfo(
                "Sukces",
                f"Konfiguracja zapisana:\n{config_path}\n\n"
                f"Include: {len(include_list)} parametrów\n"
                f"Exclude: {len(exclude_list)} parametrów"
            )

        except Exception as e:
            self.logger.exception("Failed to export config")
            messagebox.showerror("Błąd", f"Nie można zapisać konfiguracji:\n{e}")
