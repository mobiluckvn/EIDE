"""Lớp L2 — cổng hội thoại và hiểu ngôn ngữ tự nhiên. AAD-33 §2.

Bốn khối của lớp này, theo thứ tự chạy trong một lượt gõ::

    N0  normalize.py   chuẩn hoá câu (NFC, không dấu, tách mệnh đề)   0 token
    DX  dx.py          trích đường dẫn / chip / số / URL / mã / nháy   0 token
    S0  (backref.py + eide_core.request_ops)  chặn xác định            0 token
    S1  (eide.caps.chat)                      hiểu ý định              có mô hình

Ranh giới của cả gói: **không một hàm nào ở đây gọi mô hình**. Đó là quyết định kiến trúc số
một của AAD-33 §1.1 — *"mọi việc có thể làm bằng mã thì làm bằng mã"* — và nó có một lý do đo
được: ngày 23/09/2026, TC042 và TC043 là hai câu cùng hình dạng, cùng tệp, cùng một phút chạy;
một ca nạp được tệp, ca kia không. Chỗ khác nhau duy nhất là mô hình có điền `slots.path` hay
không. Một biểu thức chính quy đọc chính câu chữ thì cho cùng một kết quả mọi lần.

Vì vậy mọi thứ trong gói này phải kiểm được bằng unit test không cần mạng, không cần khoá API,
không cần store. Hàm nào cần store (tra mã hiện vật, kiểm tệp có thật) thì nhận đường dẫn gốc
làm THAM SỐ và trả `None` khi không có — không tự đi tìm.
"""
from __future__ import annotations

from eide.nlu.dx import DXResult, extract
from eide.nlu.normalize import Utterance, normalize

__all__ = ["DXResult", "Utterance", "extract", "normalize"]
