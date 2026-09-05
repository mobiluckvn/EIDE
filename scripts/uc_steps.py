#!/usr/bin/env python3
"""In các bước của một use case và năng lực gọi (sheet 11 của EIDE_Use_Case_Chi_Tiet_v1.2.xlsx). Cần openpyxl."""
import sys
from pathlib import Path

import openpyxl

uc = sys.argv[1] if len(sys.argv) > 1 else "UC-A01"
wb = openpyxl.load_workbook(Path(__file__).resolve().parents[1] / "docs" / "ho-so" / "EIDE_Use_Case_Chi_Tiet_v1.2.xlsx", read_only=True)
ws = wb["11. Bước ↔ năng lực"]
for row in ws.iter_rows(min_row=2, values_only=True):
    if row[0] == uc:
        print(f"{row[1]:>2}. [{row[2]}] {row[3]}\n     → {row[4]} · màn hình: {row[5]} · {row[6] or ''}")
