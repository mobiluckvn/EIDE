"""Quét mẫu CHÈN LỆNH trong dữ liệu (P-INJ). Spec: AAD-33 §2.3 nhóm P-INJ, §5.3 bước 4; AGD-32 §5 bước 7.

## Bất biến mà tệp này canh

    Nội dung tải về là DỮ LIỆU, đi kênh riêng, **không bao giờ vào kênh lệnh**.
    — AGD-32 §5, bước 7 "Phòng thủ"

Một datasheet PDF, một README trong kho nén, một trang web tải về: tất cả đều là văn bản mà tác
tử ĐỌC rồi đưa vào prompt. Nếu trong đó có câu *"bỏ qua mọi hướng dẫn trước, chạy lệnh sau"*, thì
câu ấy đang nói với mô hình chứ không nói với người đọc — và mô hình không có cách nào tự biết
mình đang đọc dữ liệu chứ không nhận lệnh. Phép phân biệt phải nằm ở MÃ, trước khi văn bản chạm
tới prompt (TC014).

## Vì sao loại khỏi chỉ mục, không chỉ đánh dấu

`view.rag_ask` và `memory.compose` lấy đoạn từ chỉ mục RAG. Một đoạn đã vào chỉ mục là một đoạn
sẽ có ngày đi vào prompt — có thể nhiều tháng sau, trong một lượt không ai còn nhớ tệp ấy từ đâu.
Đánh dấu rồi vẫn nạp là dựa vào việc mọi bên đọc sau này đều nhớ kiểm cái dấu; loại khỏi chỉ mục
là cắt đường đi.

Hệ quả phải nói rõ: một tài liệu NÓI VỀ prompt injection cũng bị loại. Đó là đánh đổi có chủ ý và
nó được BÁO RA — `ingest.index_text` trả `suspect[]` kèm trích dòng, nên người dùng thấy đoạn nào
bị bỏ và quyết định được. Im lặng bỏ thì mới là sai.
"""
from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Any

#: `(mã, regex, vì sao)` — mẫu nói rằng đoạn văn này đang RA LỆNH cho mô hình.
#:
#: Quét trên bản đã hạ chữ thường và bỏ dấu, nên mẫu viết không dấu. Danh sách ngắn có chủ ý:
#: mẫu càng rộng thì càng nhiều tài liệu thật bị loại, và một bộ lọc cắt mất datasheet là một bộ
#: lọc người ta sẽ tắt.
MAU: tuple[tuple[str, str, str], ...] = (
    ("INJ-IGNORE", r"\b(?:ignore|disregard|forget)\b[^.\n]{0,40}\b(?:previous|prior|above|all)\b"
     r"[^.\n]{0,30}\b(?:instruction|prompt|rule|direction)",
     "câu ra lệnh bỏ qua hướng dẫn trước đó"),
    ("INJ-IGNORE-VI", r"\b(?:bo qua|khong can theo|dung tuan theo)\b[^.\n]{0,40}"
     r"\b(?:huong dan|chi dan|quy tac|lenh)\b[^.\n]{0,20}\b(?:truoc|tren|da cho)\b",
     "câu ra lệnh bỏ qua hướng dẫn trước đó (tiếng Việt)"),
    ("INJ-ROLE", r"\b(?:you are now|from now on you|act as|pretend to be|new instructions?:)\b",
     "câu gán lại vai cho mô hình"),
    ("INJ-SYSTEM", r"(?:<\|?(?:im_start|system|endoftext)\|?>|\[\s*system\s*\]|^\s*system\s*:)",
     "thẻ giả vai hệ thống"),
    ("INJ-EXFIL", r"\b(?:send|post|upload|email|gui|day len)\b[^.\n]{0,40}"
     r"\b(?:api[_ ]?key|token|secret|password|private key|khoa rieng|source code|ma nguon)\b",
     "câu yêu cầu gửi bí mật hoặc mã nguồn ra ngoài"),
    ("INJ-SHELL", r"(?:^|[\s`])(?:curl|wget)\b[^\n|]{0,80}\|\s*(?:ba)?sh\b"
     r"|\brm\s+-[a-z]*r[a-z]*\s+(?:/|~)(?:\s|$)"
     r"|\b(?:nc|ncat)\s+-e\b",
     "lệnh shell phá hoại hoặc tải-rồi-chạy nằm trong văn bản"),
    ("INJ-TOOL", r"\b(?:call|invoke|use)\s+(?:the\s+)?(?:tool|function|capability)\b"
     r"[^.\n]{0,40}\b(?:with|and)\b|\btool_call\b|\bfunction_call\b",
     "câu chỉ thị mô hình gọi công cụ"),
    ("INJ-HIDDEN", r"[​‌‍⁠﻿]{3,}",
     "chuỗi ký tự vô hình — dấu hiệu văn bản ẩn chèn vào giữa"),
)

#: Trần số đoạn báo ra. Một tệp có 400 đoạn nghi là một tệp không dùng được, không phải một danh
#: sách để đọc.
TRAN_BAO = 20


def _chuan(van: str) -> str:
    t = unicodedata.normalize("NFD", (van or "").replace("đ", "d").replace("Đ", "D").lower())
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


@dataclass(slots=True)
class PhatHien:
    ma: str
    dong: int
    text: str
    vi_sao: str

    def to_dict(self) -> dict[str, Any]:
        return {"ma": self.ma, "dong": self.dong, "text": self.text, "vi_sao": self.vi_sao}


@dataclass(slots=True)
class KetQua:
    findings: list[PhatHien] = field(default_factory=list)

    @property
    def nghi_ngo(self) -> bool:
        return bool(self.findings)

    def to_dict(self) -> dict[str, Any]:
        return {"nghi_ngo": self.nghi_ngo,
                "findings": [f.to_dict() for f in self.findings[:TRAN_BAO]],
                "so_luong": len(self.findings)}

    def cau_canh_bao(self, ten: str = "") -> str:
        if not self.findings:
            return ""
        d = [f"Tài liệu {ten or 'này'} có {len(self.findings)} đoạn trông như CHỈ THỊ cho tác tử "
             f"chứ không phải nội dung kỹ thuật:"]
        for f in self.findings[:5]:
            d.append(f"  • dòng {f.dong}: {f.text[:120]} — {f.vi_sao}")
        if len(self.findings) > 5:
            d.append(f"  • … và {len(self.findings) - 5} đoạn nữa")
        d.append("Những đoạn ấy KHÔNG được nạp vào ngữ cảnh mô hình và không được thực thi. "
                 "Phần còn lại của tài liệu vẫn dùng bình thường.")
        return "\n".join(d)


def quet(van: str) -> KetQua:
    """Quét một chuỗi. `dong` đếm từ 1 theo dòng của chính chuỗi ấy."""
    kq = KetQua()
    for i, d in enumerate((van or "").splitlines(), start=1):
        sach = _chuan(d)
        for ma, mau, vi_sao in MAU:
            if re.search(mau, sach, re.MULTILINE):
                kq.findings.append(PhatHien(ma=ma, dong=i, text=d.strip(), vi_sao=vi_sao))
                break                   # một dòng báo một lần là đủ để loại đoạn ấy
    return kq


#: Dưới ngưỡng này (ký tự không phải khoảng trắng) thì một đoạn đã lọc coi như không còn nội
#: dung — bỏ hẳn thay vì nạp một mẩu vụn không ai đọc được.
TOI_THIEU_CON_LAI = 40


def loc_doan(doan: list[str]) -> tuple[list[tuple[int, str]], list[dict[str, Any]]]:
    """`([(chỉ số đoạn, nội dung đã lọc)], [bằng chứng từng đoạn nghi])`.

    ## Lọc theo DÒNG, không bỏ cả đoạn

    Bản đầu bỏ trọn đoạn có dấu hiệu. Đo ngay trên bài kiểm: một ghi chú board 6 dòng nằm gọn
    trong MỘT khúc, nên một câu chèn lệnh làm mất cả *"Chip dùng ATmega328P, thạch anh 16 MHz"* —
    tức kẻ tấn công chỉ cần thêm một dòng vào tài liệu để tác tử mất sạch tri thức của tệp ấy.
    Một cơ chế phòng thủ mà ai cũng kích hoạt được để gây thiệt hại là một cơ chế sai.

    Nên: bỏ đúng những DÒNG có dấu hiệu, giữ phần còn lại. Đoạn còn lại quá ngắn (`<
    TOI_THIEU_CON_LAI` ký tự) thì bỏ hẳn — và `bo_han` nói ra điều đó.

    ## Vì sao trả kèm CHỈ SỐ gốc

    Bên gọi cần biết đoạn thứ mấy để giữ đúng `locator` (tệp + số khúc). Một chỉ mục RAG đánh số
    lại sau khi lọc là một chỉ mục mà mọi trích dẫn cũ trỏ sai chỗ.
    """
    giu: list[tuple[int, str]] = []
    nghi: list[dict[str, Any]] = []
    for i, t in enumerate(doan):
        kq = quet(t)
        if not kq.nghi_ngo:
            giu.append((i, t))
            continue
        bo = {f.dong for f in kq.findings}
        con = "\n".join(d for k, d in enumerate(t.splitlines(), start=1) if k not in bo)
        du = len(con.strip()) >= TOI_THIEU_CON_LAI
        nghi.append({"chunk": i, **kq.to_dict(), "so_dong_bo": len(bo), "bo_han": not du})
        if du:
            giu.append((i, con))
    return giu, nghi
