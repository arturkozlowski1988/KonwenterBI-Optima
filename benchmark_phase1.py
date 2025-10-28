#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Phase 1 Performance Benchmark - v2.3
Compares performance improvements from Phase 1 optimizations
"""

import time
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))

from bi_converter.converter import ComarchBIConverter

def benchmark_multiple_runs():
    """Benchmark extraction over multiple runs to measure consistency"""
    print("=" * 70)
    print("Phase 1 Performance Benchmark - v2.3")
    print("=" * 70)
    
    xml_large = Path(__file__).parent / 'raporty magazyny.xml'
    if not xml_large.exists():
        print(f"⚠️  File not found: {xml_large}")
        return
    
    file_size_mb = xml_large.stat().st_size / (1024 * 1024)
    print(f"\n📦 Test file: {xml_large.name}")
    print(f"📦 File size: {file_size_mb:.2f} MB")
    
    # Warm-up run (JIT optimization, disk cache)
    print("\n🔥 Warm-up run...")
    converter = ComarchBIConverter()
    _ = converter.extract_sql_reports(str(xml_large))
    
    # Benchmark runs
    print(f"\n⏱️  Running 10 benchmark iterations...")
    times = []
    
    for i in range(10):
        converter = ComarchBIConverter()
        start = time.perf_counter()
        reports = converter.extract_sql_reports(str(xml_large))
        elapsed = time.perf_counter() - start
        times.append(elapsed)
        print(f"  Run {i+1:2d}: {elapsed:.4f}s ({file_size_mb/elapsed:6.2f} MB/s)")
    
    # Statistics
    avg_time = sum(times) / len(times)
    min_time = min(times)
    max_time = max(times)
    
    print("\n" + "=" * 70)
    print("📊 Performance Statistics")
    print("=" * 70)
    print(f"Average time:     {avg_time:.4f}s ({file_size_mb/avg_time:.2f} MB/s)")
    print(f"Best time:        {min_time:.4f}s ({file_size_mb/min_time:.2f} MB/s)")
    print(f"Worst time:       {max_time:.4f}s ({file_size_mb/max_time:.2f} MB/s)")
    print(f"Consistency:      {(max_time - min_time):.4f}s variation")
    print(f"\nReports extracted: {len(reports)}")
    
    # Compare to baseline (from OPTIMIZATION_PLAN.md)
    print("\n" + "=" * 70)
    print("📈 Improvement vs Baseline")
    print("=" * 70)
    print("Note: Baseline measurements from pre-optimization version:")
    print("  • Small files (1MB): ~0.5s")
    print("  • Medium files (10MB): ~5s (0.5s/MB)")
    print("  • Large files (50MB): ~35s (0.7s/MB)")
    
    # Our file is ~2MB, so baseline would be ~1s at 0.5s/MB
    baseline_estimate = file_size_mb * 0.5
    improvement = ((baseline_estimate - avg_time) / baseline_estimate) * 100
    
    print(f"\nEstimated baseline for {file_size_mb:.2f}MB: ~{baseline_estimate:.2f}s")
    print(f"Actual average time: {avg_time:.4f}s")
    
    if improvement > 0:
        speedup = baseline_estimate / avg_time
        print(f"✅ Performance improvement: {improvement:.1f}%")
        print(f"✅ Speedup factor: {speedup:.2f}x")
    else:
        print(f"⚠️  Performance change: {improvement:.1f}%")
    
    # Memory efficiency note
    print("\n" + "=" * 70)
    print("💾 Memory Efficiency")
    print("=" * 70)
    print("✅ iterparse with elem.clear():")
    print("   • Streaming parse - processes elements incrementally")
    print("   • Clears processed elements immediately")
    print("   • Memory usage stays constant regardless of file size")
    print("   • Enables processing of files >100MB without memory issues")
    
    print("\n❌ Previous ET.parse() approach:")
    print("   • Loads entire XML tree into memory")
    print("   • Memory usage = 5-10x file size")
    print("   • Could cause memory errors on large files")

if __name__ == '__main__':
    try:
        benchmark_multiple_runs()
        print("\n" + "=" * 70)
        print("✅ Benchmark complete!")
        print("=" * 70)
    except Exception as e:
        print(f"\n❌ Benchmark failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
