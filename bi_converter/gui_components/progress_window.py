import tkinter as tk
from tkinter import ttk

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
        try:
            x = (self.window.winfo_screenwidth() // 2) - (450 // 2)
            y = (self.window.winfo_screenheight() // 2) - (150 // 2)
            self.window.geometry(f'450x150+{x}+{y}')
        except Exception:
            pass # Fallback if screen info unavailable

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
