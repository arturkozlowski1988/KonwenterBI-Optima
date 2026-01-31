import tkinter as tk
from tkinter import ttk

class ThemeManager:
    THEMES = {
        "light": {
            "bg": "#f0f0f0", "fg": "#000000",
            "entry_bg": "#ffffff", "entry_fg": "#000000",
            "text_bg": "#ffffff", "text_fg": "#000000",
            "select_bg": "#e1e1e1", "select_fg": "#000000",
            "active_bg": "#c1c1c1",
        },
        "dark": {
            "bg": "#2d2d2d", "fg": "#e0e0e0",
            "entry_bg": "#3d3d3d", "entry_fg": "#e0e0e0",
            "text_bg": "#1e1e1e", "text_fg": "#e0e0e0",
            "select_bg": "#505050", "select_fg": "#ffffff",
            "active_bg": "#404040",
        }
    }

    @staticmethod
    def apply_theme(root, theme_name="light"):
        colors = ThemeManager.THEMES.get(theme_name, ThemeManager.THEMES["light"])

        # Configure ttk style
        style = ttk.Style(root)
        try:
            # 'clam' is usually available and customizable on all platforms
            style.theme_use('clam')
        except Exception:
            pass

        style.configure(".", background=colors["bg"], foreground=colors["fg"], fieldbackground=colors["entry_bg"])
        style.configure("TLabel", background=colors["bg"], foreground=colors["fg"])
        style.configure("TFrame", background=colors["bg"])
        style.configure("TButton", background=colors["entry_bg"], foreground=colors["fg"], borderwidth=1)
        style.map("TButton", background=[("active", colors["active_bg"]), ("pressed", colors["select_bg"])])

        style.configure("TNotebook", background=colors["bg"], tabmargins=[2, 5, 2, 0])
        style.configure("TNotebook.Tab", background=colors["bg"], foreground=colors["fg"], padding=[10, 2])
        style.map("TNotebook.Tab", background=[("selected", colors["select_bg"])], foreground=[("selected", colors["select_fg"])])

        style.configure("Treeview", background=colors["entry_bg"], foreground=colors["entry_fg"], fieldbackground=colors["entry_bg"])
        style.map("Treeview", background=[("selected", colors["select_bg"])], foreground=[("selected", colors["select_fg"])])
        style.configure("Treeview.Heading", background=colors["bg"], foreground=colors["fg"])

        # Recursively configure tk widgets
        def configure_widget(widget):
            try:
                w_type = widget.winfo_class()
                # print(f"Configuring {w_type}") # debug

                if w_type in ('Label', 'Frame', 'Toplevel', 'Tk'):
                    widget.configure(bg=colors["bg"])
                    if w_type == 'Label':
                        widget.configure(fg=colors["fg"])

                elif w_type in ('Entry', 'Text', 'Listbox'):
                    widget.configure(
                        bg=colors["entry_bg"],
                        fg=colors["entry_fg"],
                        insertbackground=colors["fg"]
                    )

                elif w_type == 'Button':
                    widget.configure(bg=colors["entry_bg"], fg=colors["fg"])

                elif w_type == 'Checkbutton':
                    widget.configure(
                        bg=colors["bg"],
                        fg=colors["fg"],
                        selectcolor=colors["entry_bg"],
                        activebackground=colors["active_bg"],
                        activeforeground=colors["fg"]
                    )

            except Exception:
                pass

            # Recurse
            for child in widget.winfo_children():
                configure_widget(child)

        configure_widget(root)
