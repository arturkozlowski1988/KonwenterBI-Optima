#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test Multi-File Preview Feature
Tests the tabbed preview interface for multiple SQL files
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from bi_converter.converter import ComarchBIConverter
from bi_converter.logging_conf import get_logger

def test_preview_window_single_file():
    """Test 1: Preview window with single file"""
    print("\n" + "=" * 70)
    print("Test 1: Preview window z pojedynczym plikiem")
    print("=" * 70)
    
    try:
        from bi_converter.gui import PreviewWindow
        import tkinter as tk
        
        # Create dummy root
        root = tk.Tk()
        root.withdraw()
        
        conv = ComarchBIConverter(logger=get_logger())
        sql_file = "report_01.sql"
        
        if not Path(sql_file).exists():
            print(f"  ⚠️ Plik {sql_file} nie istnieje - pomijam test")
            root.destroy()
            return None
        
        # Test single file as string
        print(f"  Tworzenie okna podglądu dla: {sql_file}")
        preview = PreviewWindow(root, sql_file, conv)
        
        if preview.window and preview.window.winfo_exists():
            print(f"  ✅ Okno utworzone")
            print(f"  ✅ Tytuł: {preview.window.title()}")
            print(f"  ✅ Plików w metadata: {len(preview.file_metadata)}")
            
            # Check metadata structure
            if preview.file_metadata:
                meta = preview.file_metadata[0]
                print(f"  ✅ Kolumn: {len(meta['columns'])}")
                print(f"  ✅ Parametrów: {len(meta['all_params'])}")
            
            preview.window.destroy()
            root.destroy()
            print("  ✅ PASSED")
            return True
        else:
            print("  ❌ Okno nie zostało utworzone")
            root.destroy()
            return False
            
    except Exception as e:
        print(f"  ❌ FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_preview_window_multiple_files():
    """Test 2: Preview window with multiple files"""
    print("\n" + "=" * 70)
    print("Test 2: Preview window z wieloma plikami (tab interface)")
    print("=" * 70)
    
    try:
        from bi_converter.gui import PreviewWindow
        import tkinter as tk
        
        # Create dummy root
        root = tk.Tk()
        root.withdraw()
        
        conv = ComarchBIConverter(logger=get_logger())
        sql_files = ["report_01.sql", "report_02.sql", "report_03.sql"]
        
        existing_files = [f for f in sql_files if Path(f).exists()]
        if len(existing_files) < 2:
            print(f"  ⚠️ Potrzebne co najmniej 2 pliki - znaleziono {len(existing_files)}")
            root.destroy()
            return None
        
        # Test multiple files as list
        print(f"  Tworzenie okna podglądu dla {len(existing_files)} plików")
        preview = PreviewWindow(root, existing_files, conv)
        
        if preview.window and preview.window.winfo_exists():
            print(f"  ✅ Okno utworzone")
            print(f"  ✅ Tytuł: {preview.window.title()}")
            print(f"  ✅ Plików w metadata: {len(preview.file_metadata)}")
            
            # Verify title contains file count
            expected_in_title = f"{len(existing_files)} plików"
            if expected_in_title in preview.window.title():
                print(f"  ✅ Tytuł zawiera liczbę plików: '{expected_in_title}'")
            else:
                print(f"  ⚠️ Tytuł nie zawiera oczekiwanego tekstu")
            
            # Check metadata for all files
            for idx, meta in enumerate(preview.file_metadata, 1):
                print(f"  ✅ Plik {idx}: {meta['path'].name}")
                print(f"      Kolumny: {len(meta['columns'])}, Parametry: {len(meta['all_params'])}")
            
            preview.window.destroy()
            root.destroy()
            print("  ✅ PASSED")
            return True
        else:
            print("  ❌ Okno nie zostało utworzone")
            root.destroy()
            return False
            
    except Exception as e:
        print(f"  ❌ FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_preview_backward_compatibility():
    """Test 3: Backward compatibility - string vs list"""
    print("\n" + "=" * 70)
    print("Test 3: Kompatybilność wsteczna (string vs lista)")
    print("=" * 70)
    
    try:
        from bi_converter.gui import PreviewWindow
        import tkinter as tk
        
        # Create dummy root
        root = tk.Tk()
        root.withdraw()
        
        conv = ComarchBIConverter(logger=get_logger())
        sql_file = "report_01.sql"
        
        if not Path(sql_file).exists():
            print(f"  ⚠️ Plik {sql_file} nie istnieje - pomijam test")
            root.destroy()
            return None
        
        # Test 1: Pass as string (old way)
        print(f"  Test A: Przekazanie jako string")
        preview1 = PreviewWindow(root, sql_file, conv)
        metadata_count_string = len(preview1.file_metadata) if preview1.window else 0
        if preview1.window:
            preview1.window.destroy()
        
        # Test 2: Pass as single-item list (new way)
        print(f"  Test B: Przekazanie jako lista [1 element]")
        preview2 = PreviewWindow(root, [sql_file], conv)
        metadata_count_list = len(preview2.file_metadata) if preview2.window else 0
        if preview2.window:
            preview2.window.destroy()
        
        root.destroy()
        
        # Both should work the same
        if metadata_count_string == 1 and metadata_count_list == 1:
            print(f"  ✅ Obie metody działają identycznie (1 plik w metadata)")
            print("  ✅ PASSED")
            return True
        else:
            print(f"  ❌ Niezgodność: string={metadata_count_string}, list={metadata_count_list}")
            return False
            
    except Exception as e:
        print(f"  ❌ FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_preview_error_handling():
    """Test 4: Error handling for missing files"""
    print("\n" + "=" * 70)
    print("Test 4: Obsługa błędów (brakujące pliki)")
    print("=" * 70)
    
    try:
        from bi_converter.gui import PreviewWindow
        import tkinter as tk
        
        # Create dummy root
        root = tk.Tk()
        root.withdraw()
        
        conv = ComarchBIConverter(logger=get_logger())
        
        # Mix of existing and non-existing files
        sql_files = ["report_01.sql", "nonexistent_file.sql", "report_02.sql"]
        existing = [f for f in sql_files if Path(f).exists()]
        
        if not existing:
            print(f"  ⚠️ Brak istniejących plików - pomijam test")
            root.destroy()
            return None
        
        print(f"  Tworzenie okna z listą zawierającą nieistniejące pliki")
        print(f"  Lista: {sql_files}")
        print(f"  Istniejące: {existing}")
        
        preview = PreviewWindow(root, sql_files, conv)
        
        if preview.window and preview.window.winfo_exists():
            print(f"  ✅ Okno utworzone pomimo błędów")
            print(f"  ✅ Załadowano {len(preview.file_metadata)} z {len(sql_files)} plików")
            
            # Should only load existing files
            if len(preview.file_metadata) == len(existing):
                print(f"  ✅ Pominięto nieistniejące pliki")
            else:
                print(f"  ⚠️ Oczekiwano {len(existing)}, otrzymano {len(preview.file_metadata)}")
            
            preview.window.destroy()
            root.destroy()
            print("  ✅ PASSED")
            return True
        else:
            print("  ❌ Okno nie zostało utworzone")
            root.destroy()
            return False
            
    except Exception as e:
        print(f"  ❌ FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run all tests"""
    print("=" * 70)
    print("MULTI-FILE PREVIEW TEST SUITE")
    print("=" * 70)
    
    tests = [
        ("Single file preview", test_preview_window_single_file),
        ("Multiple files preview", test_preview_window_multiple_files),
        ("Backward compatibility", test_preview_backward_compatibility),
        ("Error handling", test_preview_error_handling),
    ]
    
    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print(f"\n❌ Test '{name}' wywołał wyjątek: {e}")
            import traceback
            traceback.print_exc()
            results.append((name, False))
    
    # Summary
    print("\n" + "=" * 70)
    print("PODSUMOWANIE")
    print("=" * 70)
    
    passed = sum(1 for _, result in results if result is True)
    failed = sum(1 for _, result in results if result is False)
    skipped = sum(1 for _, result in results if result is None)
    
    for name, result in results:
        if result is True:
            print(f"✅ {name}")
        elif result is False:
            print(f"❌ {name}")
        else:
            print(f"⚠️  {name} (pominięty)")
    
    print(f"\nZaliczone: {passed}/{len(results)}")
    print(f"Niezaliczone: {failed}/{len(results)}")
    print(f"Pominięte: {skipped}/{len(results)}")
    
    if failed == 0 and passed > 0:
        print("\n🎉 WSZYSTKIE TESTY PREVIEW ZALICZONE!")
        return 0
    elif passed > 0:
        print("\n⚠️ Część testów zaliczonych")
        return 1
    else:
        print("\n❌ TESTY NIE PRZESZŁY")
        return 1

if __name__ == '__main__':
    sys.exit(main())
