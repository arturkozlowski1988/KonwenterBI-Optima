import tkinter as tk
import sqlparse
from sqlparse import tokens

class SyntaxHighlighter:
    def __init__(self, text_widget, theme="light"):
        self.text_widget = text_widget
        self.theme = theme
        self._configure_tags()

    def _configure_tags(self):
        # Colors for light/dark themes
        colors = {
            "light": {
                "keyword": "#0000FF",    # Blue
                "name": "#000000",       # Black
                "string": "#008000",     # Green
                "number": "#800080",     # Purple
                "comment": "#808080",    # Gray
                "operator": "#A52A2A",   # Brown
                "punctuation": "#000000" # Black
            },
            "dark": {
                "keyword": "#569CD6",    # Light Blue
                "name": "#D4D4D4",       # Light Gray
                "string": "#CE9178",     # Orange/Red
                "number": "#B5CEA8",     # Light Green
                "comment": "#6A9955",    # Green
                "operator": "#D4D4D4",   # Light Gray
                "punctuation": "#D4D4D4" # Light Gray
            }
        }

        c = colors.get(self.theme, colors["light"])

        font_family = "Consolas" if "Consolas" in tk.font.families() else "Courier New"
        base_font = (font_family, 10)
        bold_font = (font_family, 10, "bold")

        self.text_widget.tag_config("keyword", foreground=c["keyword"], font=bold_font)
        self.text_widget.tag_config("name", foreground=c["name"], font=base_font)
        self.text_widget.tag_config("string", foreground=c["string"], font=base_font)
        self.text_widget.tag_config("number", foreground=c["number"], font=base_font)
        self.text_widget.tag_config("comment", foreground=c["comment"], font=base_font)
        self.text_widget.tag_config("operator", foreground=c["operator"], font=base_font)
        self.text_widget.tag_config("punctuation", foreground=c["punctuation"], font=base_font)

    def highlight(self):
        content = self.text_widget.get("1.0", "end-1c")

        # Remove existing tags
        for tag in ["keyword", "name", "string", "number", "comment", "operator", "punctuation"]:
            self.text_widget.tag_remove(tag, "1.0", "end")

        # Parse and highlight
        row = 1
        col = 0

        # Use sqlparse lexer
        try:
            for token in sqlparse.lex(content):
                token_type, value = token
                tag = None

                if token_type in tokens.Keyword:
                    tag = "keyword"
                elif token_type in tokens.Name:
                    tag = "name"
                elif token_type in tokens.Literal.String:
                    tag = "string"
                elif token_type in tokens.Literal.Number:
                    tag = "number"
                elif token_type in tokens.Comment:
                    tag = "comment"
                elif token_type in tokens.Operator:
                    tag = "operator"
                elif token_type in tokens.Punctuation:
                    tag = "punctuation"

                # Calculate end position
                lines = value.split('\n')
                if len(lines) > 1:
                    end_row = row + len(lines) - 1
                    end_col = len(lines[-1])
                else:
                    end_row = row
                    end_col = col + len(value)

                start_idx = f"{row}.{col}"
                end_idx = f"{end_row}.{end_col}"

                if tag:
                    self.text_widget.tag_add(tag, start_idx, end_idx)

                row = end_row
                col = end_col

        except Exception:
            pass
