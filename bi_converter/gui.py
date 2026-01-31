#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import tkinter as tk
from tkinter import ttk
from pathlib import Path
from .logging_conf import get_logger
from .settings import load_settings, save_settings
from .recent_files_manager import RecentFilesManager
from .theme_manager import ThemeManager
from .gui_components.sql_tab import SQLTab
from .gui_components.xml_tab import XMLTab

# Try to import TkinterDnD
try:
    from tkinterdnd2 import TkinterDnD
    TK_ROOT = TkinterDnD.Tk
except ImportError:
    TK_ROOT = tk.Tk

class ConverterGUI:
    def __init__(self):
        self.logger = get_logger()
        self.root = TK_ROOT()
        self.root.title("Comarch BI Converter")
        self.root.geometry("820x480")
        
        self.settings = {}
        try:
            loaded = load_settings()
            if isinstance(loaded, dict):
                self.settings = loaded
        except Exception:
            pass

        self.recent_manager = RecentFilesManager()
        self.recent_manager.on_update = self._refresh_recent_menu
        
        # Theme
        self.current_theme = tk.StringVar(value=self.settings.get("theme", "light"))
        
        self._build()
        self._build_menu()

        # Apply initial theme
        self._apply_theme()
        
        # Keyboard shortcuts
        self.root.bind_all("<Control-Return>", self._handle_ctrl_enter)
    
    def _build(self):
        """Build main window with notebook (tabs)"""
        # Create notebook for tabs
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill=tk.BOTH, expand=True, padx=12, pady=10)
        
        # Tab 1: SQL → XML
        self.sql_tab = SQLTab(self.notebook, self.settings, self.recent_manager)
        
        # Tab 2: XML → SQL
        self.xml_tab = XMLTab(self.notebook, self.settings, self.recent_manager)
    
    def _build_menu(self):
        """Build main menu"""
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)
        
        # File Menu
        file_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Plik", menu=file_menu)
        
        # Recent Files Submenu
        self.recent_menu = tk.Menu(file_menu, tearoff=0)
        file_menu.add_cascade(label="Ostatnie pliki", menu=self.recent_menu)
        self._refresh_recent_menu()
        
        file_menu.add_separator()
        file_menu.add_command(label="Wyjdź", command=self.root.quit)
        
        # View Menu
        view_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Widok", menu=view_menu)
        
        view_menu.add_radiobutton(label="Jasny motyw", variable=self.current_theme, value="light", command=self._on_theme_change)
        view_menu.add_radiobutton(label="Ciemny motyw", variable=self.current_theme, value="dark", command=self._on_theme_change)

    def _refresh_recent_menu(self):
        """Re-populate recent files menu"""
        self.recent_menu.delete(0, tk.END)
        files = self.recent_manager.get_files()
        
        if not files:
            self.recent_menu.add_command(label="(brak)", state=tk.DISABLED)
            return

        for path in files:
            display_name = path
            if len(path) > 50:
                p = Path(path)
                display_name = f".../{p.parent.name}/{p.name}"
                
            self.recent_menu.add_command(
                label=display_name,
                command=lambda p=path: self._open_recent_file(p)
            )
        
        self.recent_menu.add_separator()
        self.recent_menu.add_command(label="Wyczyść historię", command=self._clear_recent)

    def _open_recent_file(self, path):
        """Handle opening a file from recent menu"""
        p = Path(path)
        if not p.exists():
            return
            
        suffix = p.suffix.lower()
        if suffix == '.sql':
            self.notebook.select(self.sql_tab.frame)
            self.sql_tab.load_file(path)
        elif suffix == '.xml':
            self.notebook.select(self.xml_tab.frame)
            self.xml_tab.load_file(path)
        else:
            self.notebook.select(self.sql_tab.frame)
            self.sql_tab.load_file(path)

    def _clear_recent(self):
        self.recent_manager.clear()
        self._refresh_recent_menu()
    
    def _on_theme_change(self):
        """Handle theme change event"""
        self._apply_theme()
        # Save settings
        self.settings["theme"] = self.current_theme.get()
        try:
            save_settings(self.settings)
        except Exception:
            pass

    def _apply_theme(self):
        """Apply current theme to all widgets"""
        theme = self.current_theme.get()
        ThemeManager.apply_theme(self.root, theme)

    def _handle_ctrl_enter(self, event):
        current = self.notebook.select()
        if current == self.sql_tab.frame._w:
            self.sql_tab.run_conversion()

    def run(self):
        self.root.mainloop()

def main():
    app = ConverterGUI()
    app.run()

if __name__ == "__main__":
    main()
