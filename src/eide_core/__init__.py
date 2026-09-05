"""eide_core — lõi dùng chung của EIDE: registry năng lực, PolicyGate, ledger, cấu hình.

Nguồn thiết kế: EIDE-SAD-03 (kiến trúc), SDD-04 (mô-đun), APD-08/POL-17 (chính sách), API-15 (lỗi), DDD-14 (dữ liệu).
Không phụ thuộc giao diện; có thể tách thành package dùng chung với EAA-U.
"""
from eide_core.errors import EideError
from eide_core.registry import Registry, capability, get_registry

__all__ = ["EideError", "Registry", "capability", "get_registry"]
__version__ = "0.1.0"
