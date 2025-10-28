#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from pathlib import Path
from typing import List, Dict, Any, Callable
from .converter import ComarchBIConverter, ConversionError
from .logging_conf import get_logger
from .settings import load_settings, save_settings


class ProgressWindow:
    """Window displaying indeterminate progress bar during long operations"""
    
    def __init__(self, parent: tk.Tk, title: str, message: str):
        self.window = tk.Toplevel(parent)
        self.window.title(title)
        self.window.geometry("450x150")
        self.window.resizable(False, False)
        self.window.transient(parent)
        self.window.grab_set()
        
        # Center window
        self.window.update_idletasks()
        x = (self.window.winfo_screenwidth() // 2) - (450 // 2)
        y = (self.window.winfo_screenheight() // 2) - (150 // 2)
        self.window.geometry(f'450x150+{x}+{y}')
        
        # Message label
        self.message_label = tk.Label(
            self.window,
            text=message,
            font=("Arial", 10),
            wraplength=400
        )
        self.message_label.pack(pady=20)
        
        # Progress bar
        self.progress = ttk.Progressbar(
            self.window,
            mode='indeterminate',
            length=400
        )
        self.progress.pack(pady=10)
        self.progress.start(10)
        
        # Status label
        self.status_label = tk.Label(
            self.window,
            text="Przetwarzanie...",
            font=("Arial", 9),
            fg="#666"
        )
        self.status_label.pack(pady=5)
    
    def update_status(self, status: str):
        """Update status text"""
        self.status_label.config(text=status)
        self.window.update()
    
    def close(self):
        """Close progress window"""
        self.progress.stop()
        self.window.grab_release()
        self.window.destroy()


class XMLPreviewWindow:
    """Window showing preview of XML reports before extraction"""
    
    def __init__(self, parent: tk.Tk, xml_path: str, converter: ComarchBIConverter):
        self.parent = parent
        self.xml_path = Path(xml_path)
        self.converter = converter
        self.logger = converter.logger
        
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
    
    def __init__(self, parent, sql_paths, converter: ComarchBIConverter):
        """Initialize preview window
        
        Args:
            parent: Parent Tk window
            sql_paths: Single path string or list of path strings
            converter: ComarchBIConverter instance
        """
        self.parent = parent
        self.converter = converter
        self.logger = converter.logger
        
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
            pkg_dir = Path(__file__).parent
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



class ConverterGUI:
    def __init__(self):
        self.logger = get_logger()
        self.root = tk.Tk()
        self.root.title("Comarch BI Converter")
        self.root.geometry("820x480")
        
        # Variables for SQL → XML tab
        self.sql_var = tk.StringVar()
        self.sql_files = []  # List of selected SQL files for batch conversion
        self.server_var = tk.StringVar(value="SERWEROPTIMA\\SUL02")
        self.db_var = tk.StringVar(value="CDN_Ulex_2018_temp")
        self.conn_name_var = tk.StringVar(value="Ulex_2018_temp")
        self.conn_mode_var = tk.StringVar(value="auto")
        self.debug_var = tk.BooleanVar()
        self.sql_status_var = tk.StringVar(value="Gotowy.")
        
        # Variables for XML → SQL tab
        self.xml_file_var = tk.StringVar()
        self.output_dir_var = tk.StringVar()
        self.xml_status_var = tk.StringVar(value="Wybierz plik XML.")
        
        self._build()
        
        # Keyboard shortcuts
        self.root.bind_all("<Control-Return>", lambda e: self._run())
    
    def _build(self):
        """Build main window with notebook (tabs)"""
        # Create notebook for tabs
        notebook = ttk.Notebook(self.root)
        notebook.pack(fill=tk.BOTH, expand=True, padx=12, pady=10)
        
        # Tab 1: SQL → XML
        sql_frame = tk.Frame(notebook)
        notebook.add(sql_frame, text="SQL → XML")
        self._build_sql_tab(sql_frame)
        
        # Tab 2: XML → SQL
        xml_frame = tk.Frame(notebook)
        notebook.add(xml_frame, text="XML → SQL")
        self._build_xml_tab(xml_frame)
        
        # Load saved settings
        try:
            st = load_settings()
            if isinstance(st, dict):
                self.server_var.set(st.get("server", ""))
                self.db_var.set(st.get("database", ""))
                self.conn_name_var.set(st.get("connection_name", ""))
                self.conn_mode_var.set(st.get("mode", "auto"))
                dbg = str(st.get("debug", "false")).lower()
                self.debug_var.set(dbg in ("1", "true", "yes"))
                self._toggle_debug()
        except Exception:
            pass
    
    def _build_sql_tab(self, parent):
        """Build SQL → XML conversion tab"""
        pad = {"padx": 8, "pady": 6}
        frm = tk.Frame(parent)
        frm.pack(fill=tk.BOTH, expand=True)
        
        # SQL file selection
        tk.Label(frm, text="Plik SQL:").grid(row=0, column=0, sticky="w", **pad)
        tk.Entry(frm, textvariable=self.sql_var, width=48).grid(row=0, column=1, sticky="ew", **pad)
        ttk.Button(frm, text="Wybierz...", command=self._choose_sql).grid(row=0, column=2, **pad)
        
        # Connection fields
        tk.Label(frm, text="Serwer:").grid(row=1, column=0, sticky="w", **pad)
        tk.Entry(frm, textvariable=self.server_var).grid(row=1, column=1, sticky="ew", **pad)
        
        tk.Label(frm, text="Baza danych:").grid(row=2, column=0, sticky="w", **pad)
        tk.Entry(frm, textvariable=self.db_var).grid(row=2, column=1, sticky="ew", **pad)
        
        tk.Label(frm, text="Nazwa połączenia:").grid(row=3, column=0, sticky="w", **pad)
        tk.Entry(frm, textvariable=self.conn_name_var).grid(row=3, column=1, sticky="ew", **pad)
        
        # Connection mode
        tk.Label(frm, text="Tryb połączenia:").grid(row=4, column=0, sticky="w", **pad)
        ttk.Combobox(frm, textvariable=self.conn_mode_var, values=("auto", "embedded", "default"), state="readonly").grid(row=4, column=1, sticky="ew", **pad)
        
        # Debug toggle
        debug_frame = tk.Frame(frm)
        debug_frame.grid(row=5, column=0, columnspan=3, sticky="w", **pad)
        ttk.Checkbutton(debug_frame, text="Loguj debug", variable=self.debug_var, command=self._toggle_debug).pack(side=tk.LEFT)
        
        # Action buttons
        action_frame = tk.Frame(frm)
        action_frame.grid(row=6, column=0, columnspan=3, sticky="w", **pad)
        ttk.Button(action_frame, text="🔍 Podgląd metadanych", command=self._preview).pack(side=tk.LEFT, padx=(0, 8))
        ttk.Button(action_frame, text="⚙️ Konwertuj", command=self._run).pack(side=tk.LEFT)
        
        # Status label
        tk.Label(frm, textvariable=self.sql_status_var, fg="#555").grid(row=7, column=0, columnspan=3, sticky="w", **pad)
        
        frm.grid_columnconfigure(1, weight=1)
    
    def _build_xml_tab(self, parent):
        """Build XML → SQL extraction tab"""
        pad = {"padx": 8, "pady": 6}
        frm = tk.Frame(parent)
        frm.pack(fill=tk.BOTH, expand=True)
        
        # XML file selection
        tk.Label(frm, text="Plik XML:").grid(row=0, column=0, sticky="w", **pad)
        tk.Entry(frm, textvariable=self.xml_file_var, width=48).grid(row=0, column=1, sticky="ew", **pad)
        ttk.Button(frm, text="Wybierz...", command=self._choose_xml).grid(row=0, column=2, **pad)
        
        # Output directory (optional)
        tk.Label(frm, text="Folder docelowy (opcjonalnie):").grid(row=1, column=0, sticky="w", **pad)
        tk.Entry(frm, textvariable=self.output_dir_var).grid(row=1, column=1, sticky="ew", **pad)
        ttk.Button(frm, text="Wybierz...", command=self._choose_output_dir).grid(row=1, column=2, **pad)
        
        # Info label
        info_text = "💡 Jeśli nie wybierzesz folderu docelowego, pliki SQL zostaną zapisane w tym samym miejscu co plik XML."
        tk.Label(frm, text=info_text, fg="#555", wraplength=700, justify="left").grid(row=2, column=0, columnspan=3, sticky="w", **pad)
        
        # Action buttons
        action_frame = tk.Frame(frm)
        action_frame.grid(row=3, column=0, columnspan=3, sticky="w", **pad)
        ttk.Button(action_frame, text="🔍 Podgląd raportów", command=self._preview_xml).pack(side=tk.LEFT, padx=(0, 10))
        ttk.Button(action_frame, text="⏬ Wyodrębnij SQL", command=self._convert_xml_to_sql).pack(side=tk.LEFT)
        
        # Status label
        tk.Label(frm, textvariable=self.xml_status_var, fg="#555").grid(row=4, column=0, columnspan=3, sticky="w", **pad)
        
        frm.grid_columnconfigure(1, weight=1)
    
    def _choose_sql(self):
        paths = filedialog.askopenfilenames(
            title="Wybierz plik(i) SQL (Shift/Ctrl dla wielu)", 
            filetypes=[("SQL files", "*.sql"), ("All files", "*.*")]
        )
        if paths:
            self.sql_files = list(paths)
            if len(paths) == 1:
                self.sql_var.set(paths[0])
            else:
                self.sql_var.set(f"{len(paths)} plików wybranych")
                self.sql_status_var.set(f"Wybrano {len(paths)} plików SQL")
    
    def _choose_xml(self):
        path = filedialog.askopenfilename(title="Wybierz plik XML", filetypes=[("XML files", "*.xml"), ("All files", "*.*")])
        if path:
            self.xml_file_var.set(path)
    
    def _choose_output_dir(self):
        path = filedialog.askdirectory(title="Wybierz folder docelowy")
        if path:
            self.output_dir_var.set(path)
    
    def _convert_xml_to_sql(self):
        """Extract SQL reports from XML file with progress bar"""
        xml_path = self.xml_file_var.get().strip()
        if not xml_path:
            messagebox.showwarning("Brak pliku", "Wskaż plik .xml")
            return
        
        out_dir = self.output_dir_var.get().strip() or None
        
        # Show progress bar
        progress = ProgressWindow(self.root, "Ekstrakcja", "Ekstrakcja SQL z pliku XML...")
        
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
                self.root.after(100, check_completion)
            else:
                progress.close()
                
                if result['success']:
                    outputs = result['outputs']
                    paths_text = "\n".join(str(p) for p in outputs)
                    messagebox.showinfo("Sukces", f"Wygenerowano {len(outputs)} plików SQL:\n\n{paths_text}")
                    self.xml_status_var.set(f"Wygenerowano {len(outputs)} plików.")
                else:
                    self.logger.exception("XML extraction failed", exc_info=result['error'])
                    messagebox.showerror("Błąd", f"Nie można wyodrębnić SQL:\n{result['error']}")
                    self.xml_status_var.set("Błąd ekstrakcji.")
        
        thread = threading.Thread(target=run_extraction, daemon=True)
        thread.start()
        self.root.after(100, check_completion)
    
    def _preview_xml(self):
        """Show XML reports preview window"""
        xml_path = self.xml_file_var.get().strip()
        if not xml_path:
            messagebox.showwarning("Brak pliku", "Wskaż plik .xml")
            return
        
        try:
            conv = ComarchBIConverter(logger=self.logger)
            XMLPreviewWindow(self.root, xml_path, conv)
        except Exception as e:
            self.logger.exception("XML preview failed")
            messagebox.showerror("Błąd", f"Nie można otworzyć podglądu XML:\n{e}")
    
    def _preview(self):
        """Show metadata preview window for single or multiple files"""
        # Handle multiple file selection
        if self.sql_files:
            # Pass all selected files to preview window
            sql_paths = self.sql_files
        else:
            # Fallback to reading from display field (for backward compatibility)
            sql_path = self.sql_var.get().strip()
            if not sql_path:
                messagebox.showwarning("Brak pliku", "Wskaż plik .sql")
                return
            sql_paths = [sql_path]
        
        try:
            conv = ComarchBIConverter(logger=self.logger)
            PreviewWindow(self.root, sql_paths, conv)
        except Exception as e:
            self.logger.exception("Preview failed")
            messagebox.showerror("Błąd", f"Nie można otworzyć podglądu:\n{e}")
    
    def _run(self):
        """Convert SQL to XML with validation and progress bar"""
        # Check if we have any files selected
        if not self.sql_files:
            sql_path = self.sql_var.get().strip()
            if not sql_path:
                messagebox.showwarning("Brak pliku", "Wskaż plik(i) .sql")
                return
            self.sql_files = [sql_path]
        
        # Validate connection settings for embedded mode
        if self.conn_mode_var.get().strip().lower() == 'embedded':
            if not self.server_var.get().strip() or not self.db_var.get().strip():
                messagebox.showerror("Brak danych połączenia", "W trybie 'embedded' wymagane są: Serwer i Baza danych.")
                return
        
        # Pre-flight SQL validation for all files
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
        
        # Handle validation errors
        if validation_errors:
            error_text = "\n\n".join(validation_errors)
            messagebox.showerror(
                "Błędy walidacji",
                f"Znaleziono krytyczne błędy w plikach SQL:\n\n{error_text}\n\nKonwersja anulowana."
            )
            self.sql_status_var.set("Błędy walidacji - popraw SQL.")
            return
        
        # Handle validation warnings
        if validation_warnings:
            warning_text = "\n\n".join(validation_warnings)
            proceed = messagebox.askyesno(
                "Ostrzeżenia walidacji",
                f"Znaleziono ostrzeżenia:\n\n{warning_text}\n\nKontynuować konwersję?",
                icon='warning'
            )
            if not proceed:
                self.sql_status_var.set("Konwersja anulowana przez użytkownika.")
                return
        
        # Determine conversion mode
        is_multi_file = len(self.sql_files) > 1
        file_count_text = f"{len(self.sql_files)} plików" if is_multi_file else "pliku"
        
        # Run conversion in thread with progress bar
        progress = ProgressWindow(
            self.root, 
            "Konwersja", 
            f"Konwertowanie {file_count_text} SQL do XML..."
        )
        
        result = {'success': False, 'output': None, 'error': None}
        
        def run_conversion():
            try:
                conn_config = {
                    'server': self.server_var.get().strip(),
                    'database': self.db_var.get().strip(),
                    'connection_name': self.conn_name_var.get().strip(),
                    'mode': self.conn_mode_var.get().strip(),
                }
                
                if is_multi_file:
                    # Multiple files - combine into one XML
                    output_xml = Path(self.sql_files[0]).parent / "combined_reports.xml"
                    out = conv.convert_multiple(self.sql_files, conn_config, output_xml_path=str(output_xml))
                else:
                    # Single file - standard conversion
                    out = conv.convert(self.sql_files[0], conn_config)
                
                result['success'] = True
                result['output'] = out
            except Exception as e:
                result['success'] = False
                result['error'] = e
        
        def check_completion():
            if thread.is_alive():
                self.root.after(100, check_completion)
            else:
                progress.close()
                
                if result['success']:
                    # Persist settings
                    try:
                        save_settings({
                            'server': self.server_var.get().strip(),
                            'database': self.db_var.get().strip(),
                            'connection_name': self.conn_name_var.get().strip(),
                            'mode': self.conn_mode_var.get().strip(),
                            'debug': str(self.debug_var.get()).lower(),
                        })
                    except Exception:
                        pass
                    
                    success_msg = f"Zapisano plik XML:\n{result['output']}"
                    if is_multi_file:
                        success_msg += f"\n\n({len(self.sql_files)} raportów SQL)"
                    
                    messagebox.showinfo("Sukces", success_msg)
                    self.sql_status_var.set(f"Zapisano: {Path(result['output']).name}")
                else:
                    self.logger.exception("Conversion failed", exc_info=result['error'])
                    messagebox.showerror("Błąd", f"Konwersja nie powiodła się:\n{result['error']}")
                    self.sql_status_var.set("Błąd konwersji.")
        
        thread = threading.Thread(target=run_conversion, daemon=True)
        thread.start()
        self.root.after(100, check_completion)
    
    def run(self):
        self.root.mainloop()
    
    def _toggle_debug(self):
        """Switch console/file logger levels at runtime"""
        try:
            level = "DEBUG" if self.debug_var.get() else "INFO"
            for h in list(self.logger.handlers):
                h.setLevel(getattr(__import__('logging'), level))
            self.logger.setLevel(getattr(__import__('logging'), level))
            # Persist debug flag
            try:
                current = load_settings(logger=self.logger)
                current["debug"] = "true" if self.debug_var.get() else "false"
                save_settings(current, logger=self.logger)
            except Exception:
                pass
        except Exception:
            pass


def main():
    app = ConverterGUI()
    app.run()


if __name__ == "__main__":
    main()
