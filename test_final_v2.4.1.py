#!/usr/bin/env python3
"""
Final Comprehensive Test Suite for v2.4.1
Tests all features including multi-file support
"""

import sys
import unittest
from pathlib import Path

# Add project to path
sys.path.insert(0, str(Path(__file__).parent))

from bi_converter.converter import ComarchBIConverter
from bi_converter.gui import PreviewWindow
import tkinter as tk

class TestAllFeatures(unittest.TestCase):
    """Comprehensive test of all v2.4.1 features"""
    
    @classmethod
    def setUpClass(cls):
        """Setup test environment"""
        cls.test_files = [
            Path("report_01.sql"),
            Path("report_02.sql"),
            Path("report_03.sql"),
        ]
        cls.converter = ComarchBIConverter()
        
    def test_1_single_file_conversion(self):
        """Test 1: Basic single file conversion"""
        print("\n" + "="*60)
        print("Test 1: Single file conversion")
        print("="*60)
        
        result = self.converter.convert(self.test_files[0], "test_output_single.xml")
        self.assertIsNotNone(result)
        print("✅ Single file conversion OK")
        
    def test_2_multi_file_conversion(self):
        """Test 2: Multi-file batch conversion"""
        print("\n" + "="*60)
        print("Test 2: Multi-file batch conversion")
        print("="*60)
        
        result = self.converter.convert_multiple(self.test_files, "test_output_multi.xml")
        self.assertIsNotNone(result)
        print(f"✅ Batch conversion OK: {len(self.test_files)} files → 1 XML")
        
    def test_3_preview_single(self):
        """Test 3: Preview window for single file"""
        print("\n" + "="*60)
        print("Test 3: Preview window (single file)")
        print("="*60)
        
        root = tk.Tk()
        root.withdraw()
        
        # Test string parameter (backward compatibility)
        window = PreviewWindow(root, str(self.test_files[0]), self.converter)
        
        self.assertEqual(len(window.file_metadata), 1)
        self.assertIn("report_01.sql", window.title())
        print(f"✅ Single file preview: {window.title()}")
        
        window.destroy()
        root.destroy()
        
    def test_4_preview_multiple(self):
        """Test 4: Preview window for multiple files (tabbed interface)"""
        print("\n" + "="*60)
        print("Test 4: Preview window (multiple files)")
        print("="*60)
        
        root = tk.Tk()
        root.withdraw()
        
        # Test list parameter
        sql_paths = [str(f) for f in self.test_files]
        window = PreviewWindow(root, sql_paths, self.converter)
        
        self.assertEqual(len(window.file_metadata), 3)
        self.assertIn("3 plików", window.title())
        
        # Verify metadata structure
        for i, metadata in enumerate(window.file_metadata):
            self.assertIn('path', metadata)
            self.assertIn('columns', metadata)
            self.assertIn('all_params', metadata)
            print(f"  File {i+1}: {metadata['path'].name} - {len(metadata['columns'])} cols, {len(metadata['all_params'])} params")
        
        print(f"✅ Multi-file preview: {window.title()}")
        
        window.destroy()
        root.destroy()
        
    def test_5_sql_validation(self):
        """Test 5: SQL validation feature"""
        print("\n" + "="*60)
        print("Test 5: SQL validation")
        print("="*60)
        
        sql_text = self.test_files[0].read_text(encoding="utf-8")
        is_valid, warnings = self.converter.validate_sql(sql_text)
        
        print(f"  Valid: {is_valid}")
        print(f"  Warnings: {len(warnings)}")
        for warn in warnings:
            print(f"    - {warn}")
        
        self.assertIsInstance(is_valid, bool)
        self.assertIsInstance(warnings, list)
        print("✅ SQL validation OK")
        
    def test_6_metadata_extraction(self):
        """Test 6: Column and parameter extraction"""
        print("\n" + "="*60)
        print("Test 6: Metadata extraction")
        print("="*60)
        
        sql_text = self.test_files[0].read_text(encoding="utf-8")
        columns = self.converter.extract_columns(sql_text)
        all_params, interactive_params = self.converter.extract_parameters(sql_text)
        
        print(f"  Columns: {len(columns)}")
        print(f"  Parameters: {len(all_params)} total, {len(interactive_params)} interactive")
        
        self.assertIsInstance(columns, list)
        self.assertIsInstance(all_params, list)
        self.assertIsInstance(interactive_params, list)
        print("✅ Metadata extraction OK")
        
    def test_7_error_handling(self):
        """Test 7: Error handling for missing files"""
        print("\n" + "="*60)
        print("Test 7: Error handling")
        print("="*60)
        
        # Test preview with missing file
        root = tk.Tk()
        root.withdraw()
        
        mixed_files = ["report_01.sql", "nonexistent.sql", "report_02.sql"]
        window = PreviewWindow(root, mixed_files, self.converter)
        
        # Should load 2 out of 3 files
        self.assertEqual(len(window.file_metadata), 2)
        print(f"  Loaded {len(window.file_metadata)}/3 files (1 missing - OK)")
        print("✅ Error handling OK - graceful degradation")
        
        window.destroy()
        root.destroy()
        
    def test_8_backward_compatibility(self):
        """Test 8: Backward compatibility of PreviewWindow"""
        print("\n" + "="*60)
        print("Test 8: Backward compatibility")
        print("="*60)
        
        root = tk.Tk()
        root.withdraw()
        
        # Test both string and list with 1 element
        window1 = PreviewWindow(root, "report_01.sql", self.converter)
        window2 = PreviewWindow(root, ["report_01.sql"], self.converter)
        
        self.assertEqual(len(window1.file_metadata), 1)
        self.assertEqual(len(window2.file_metadata), 1)
        print("  String parameter: 1 file loaded")
        print("  List parameter: 1 file loaded")
        print("✅ Backward compatibility OK")
        
        window1.destroy()
        window2.destroy()
        root.destroy()

def run_all_tests():
    """Run all tests with detailed output"""
    print("\n" + "="*60)
    print("FINAL COMPREHENSIVE TEST SUITE v2.4.1")
    print("="*60)
    print("\nTesting all features:")
    print("  1. Single file conversion")
    print("  2. Multi-file batch conversion")
    print("  3. Preview window (single)")
    print("  4. Preview window (multiple, tabbed)")
    print("  5. SQL validation")
    print("  6. Metadata extraction")
    print("  7. Error handling")
    print("  8. Backward compatibility")
    print("\n" + "="*60)
    
    # Create test suite
    suite = unittest.TestLoader().loadTestsFromTestCase(TestAllFeatures)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    
    total = result.testsRun
    passed = total - len(result.failures) - len(result.errors)
    failed = len(result.failures) + len(result.errors)
    
    print(f"\nTests run: {total}")
    print(f"✅ Passed: {passed}")
    if failed > 0:
        print(f"❌ Failed: {failed}")
    else:
        print("❌ Failed: 0")
    
    if result.wasSuccessful():
        print("\n🎉 ALL TESTS PASSED - v2.4.1 IS READY FOR PRODUCTION!")
    else:
        print("\n⚠️ Some tests failed - review above")
    
    return 0 if result.wasSuccessful() else 1

if __name__ == "__main__":
    sys.exit(run_all_tests())
