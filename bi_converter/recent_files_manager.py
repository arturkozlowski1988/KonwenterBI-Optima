import json
from pathlib import Path
from typing import List

class RecentFilesManager:
    def __init__(self, max_items: int = 10):
        self.max_items = max_items
        self.config_path = Path(__file__).parent / "recent_files.json"
        self._files: List[str] = self._load()

    def _load(self) -> List[str]:
        if not self.config_path.exists():
            return []
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get("recent_files", [])
        except Exception:
            return []

    def _save(self):
        try:
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump({"recent_files": self._files}, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    def add_file(self, path: str):
        path = str(Path(path).resolve())
        if path in self._files:
            self._files.remove(path)
        self._files.insert(0, path)
        if len(self._files) > self.max_items:
            self._files = self._files[:self.max_items]
        self._save()

    def get_files(self) -> List[str]:
        # Filter out files that don't exist anymore?
        # Optional, but good UX. However, network drives might be offline.
        # Let's keep them but maybe indicate if missing in UI.
        # For now, just return the list.
        return self._files

    def clear(self):
        self._files = []
        self._save()
