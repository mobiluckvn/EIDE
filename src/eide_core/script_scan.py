"""Quét tĩnh tệp script người dùng đưa vào. Spec: AAD-33 §8.1; AGD-32 §8; SEC-25 §2.

## Vì sao có tệp này

AGD-32 §8 nói thẳng về ca TC070: *"an toàn phải do THIẾT KẾ, không do tai nạn (TC070 hiện 'an
toàn' chỉ vì tệp .sh bị nhận nhầm là tệp nén)"*. Đo 23/09/2026: người dùng đưa `don-dep.sh` vào,
`archive.list` mở nó ra, không thấy chữ ký nén nào, báo lỗi định dạng — và vì thế script không
chạy. Ca ấy được chấm ĐẠT. Nhưng cơ chế bảo vệ nó là một phép nhận dạng SAI: sửa đúng phép nhận
dạng (Đ2.1) thì script chạy được, và ca đang đạt sẽ hỏng. Bộ quét này là thứ phải đứng đó trước
khi điều đó xảy ra.

## Ranh giới: quét, không phán quyết

Hàm ở đây chỉ TRẢ VỀ bằng chứng — dòng nào, số mấy, vì sao đáng ngại. Quyết định APPROVE/ASK/
REJECT là của Policy engine (APD-08), và trích dòng là của thẻ cổng. Trộn hai việc thì một luật
an toàn nằm lẫn trong một hàm phân tích văn bản, và không ai kiểm được luật ấy mà không dựng cả
sandbox.

## Ranh giới thứ hai: tĩnh, nên KHÔNG ĐẦY ĐỦ, và phải nói ra điều đó

Một script có thể ghép lệnh từ biến (`C="rm -rf"; $C /`), tải về rồi chạy, hay gọi `eval` trên
chuỗi giải mã base64. Phép quét tĩnh không bắt hết — nên `co_the_con_thieu` luôn là `True` khi
thấy dấu hiệu che giấu, và thẻ cổng phải nói "quét tĩnh thấy N chỗ; không bảo đảm đã hết". Một
bộ quét tự nhận là đầy đủ dạy người ta bấm Duyệt mà không đọc, đúng bài học [DEV-198].

Lớp phòng thủ thật vẫn là sandbox (`eide_core.sandbox`): script chạy trong thư mục cho phép,
không mạng mặc định, có giới hạn tài nguyên. Bộ quét chỉ quyết định có HỎI trước hay không.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

#: Mức nghiêm trọng, theo thang của ERC/rà soát trong kho (`blocker`/`major`/`minor`).
BLOCKER, MAJOR, MINOR = "blocker", "major", "minor"

#: Mẫu nguy hiểm: `(mã, mức, regex, vì sao)`.
#:
#: Mỗi mẫu phải truy được về một câu trong tài liệu hoặc một ca đo. Danh sách CỐ Ý NGẮN: mỗi mẫu
#: thêm vào là một chỗ có thể bật sai, và một cảnh báo bật sai gần như mọi lần thì người ta bấm
#: qua mà không đọc — lúc ấy bộ quét thành phản tác dụng chứ không phải vô ích.
MAU: tuple[tuple[str, str, str, str], ...] = (
    # ── phá hoại hệ tệp (AAD-33 §8.1 "lệnh phá hoại", "rm -rf ngoài dự án")
    # Chỉ nổ khi ĐÍCH là gốc hoặc thư mục người dùng: `/`, `~`, `~/`, `$HOME`, `/*`. Một
    # `rm -rf build/` là việc dọn dẹp bình thường và phải đi qua im lặng — nếu không thì mọi
    # script build đều bật cảnh báo, và một cảnh báo bật mọi lần thì người ta bấm qua ([DEV-198]).
    ("SC-RM-ROOT", BLOCKER, r"\brm\s+(?:-\S+\s+)*-\S*[rR]\S*\s+(?:-\S+\s+)*"
     r"(?:/|~|\$\{?HOME\}?|\"\$HOME\")(?:/)?\*?(?=\s|$|;|&)",
     "xoá đệ quy từ thư mục gốc hoặc thư mục người dùng"),
    # MINOR, không MAJOR — cố ý, nên nó KHÔNG tự dựng thẻ cổng.
    #
    # `rm -rf $BUILD_DIR/obj` là lỗi kinh điển (biến rỗng thì thành `rm -rf /obj`), nhưng nó cũng
    # là dòng bình thường trong gần như mọi script build. Bắt nó ở mức MAJOR nghĩa là mọi script
    # build đều phải hỏi người, và một câu hỏi bật mọi lần là một câu hỏi không ai đọc. Quét tĩnh
    # không nói được biến ấy có thể rỗng hay không, nên nó chỉ NÊU RA, không chặn.
    ("SC-RM-VAR", MINOR, r"\brm\s+(?:-\S+\s+)*\"?\$\{?\w+",
     "xoá đệ quy một đường dẫn nằm trong biến — biến rỗng sẽ thành xoá từ gốc"),
    ("SC-DD", BLOCKER, r"\bdd\s+[^\n]*\bof=\s*/dev/(?:disk|sd|nvme|rdisk)",
     "ghi thẳng vào thiết bị khối — xoá sạch đĩa, không hoàn tác được"),
    ("SC-MKFS", BLOCKER, r"\b(?:mkfs(?:\.\w+)?|newfs|diskutil\s+eraseDisk)\b",
     "định dạng lại một phân vùng"),
    ("SC-CHMOD-777", MINOR, r"\bchmod\s+(?:-R\s+)?0?777\b", "mở quyền cho mọi người"),
    # ── đọc khoá riêng và bí mật (AAD-33 §8.1 "đọc khoá riêng"; SEC-25 §3)
    ("SC-SSH", BLOCKER, r"(?:~|\$HOME|/Users/[^/\s]+|/home/[^/\s]+)/\.ssh\b|\bid_rsa\b|\bid_ed25519\b",
     "đọc khoá riêng SSH"),
    ("SC-SECRET", MAJOR, r"(?:~|\$HOME)/\.(?:aws|gnupg|docker|kube)\b|\bkeychain\b"
     r"|(?<![\w.-])\.env(?![\w/-])|\bAWS_SECRET|\bGITHUB_TOKEN|\bANTHROPIC_API_KEY|\bGEMINI_API_KEY",
     "đọc tệp bí mật hoặc khoá API"),
    # ── gửi dữ liệu ra ngoài / tải về rồi chạy
    ("SC-CURL-SH", BLOCKER, r"\b(?:curl|wget)\b[^\n|]*\|\s*(?:sudo\s+)?(?:ba)?sh\b",
     "tải một tệp từ mạng rồi chạy ngay — nội dung chạy không ai đọc"),
    # `\b` KHÔNG dùng được trước `-d`: khoảng trắng và dấu nối đều là ký tự không-từ, nên không
    # có ranh giới từ ở giữa chúng và mẫu cũ trượt đúng ca đo (`curl -X POST -d @- https://…`).
    ("SC-EXFIL", MAJOR, r"\b(?:curl|wget|nc|ncat|scp|rsync)\b[^\n]*"
     r"(?:(?:^|\s)(?:-d|-T|--data(?:-binary|-raw)?|--upload-file)(?:\s|=)|@-|@/|@\$)"
     r"[^\n]*(?:https?://|\w+@[\w.]+:)",
     "gửi nội dung tệp ra một địa chỉ ngoài"),
    # ── nâng quyền và chạy chuỗi dựng động
    ("SC-SUDO", MAJOR, r"^\s*sudo\b|\bsudo\s+(?:rm|dd|chmod|chown|mv|tee)\b",
     "cần quyền quản trị — ngoài phạm vi sandbox của dự án"),
    ("SC-EVAL", MAJOR, r"\beval\s+[\"'$]|\bbase64\s+(?:-[dD]|--decode)\b[^\n]*\|\s*(?:ba)?sh\b",
     "chạy một chuỗi dựng động hoặc giải mã — quét tĩnh không đọc được nội dung thật"),
    ("SC-HISTORY", MINOR, r"\b(?:history\s+-c|unset\s+HISTFILE|set\s+\+o\s+history)\b",
     "xoá dấu vết lệnh đã chạy"),
)

#: Mẫu nói rằng phép quét tĩnh có thể KHÔNG ĐỦ — không phải mẫu nguy hiểm, mà là mẫu CHE GIẤU.
MAU_CHE_GIAU: tuple[tuple[str, str], ...] = (
    (r"\beval\b", "có `eval`"),
    (r"\bbase64\b", "có giải mã base64"),
    (r"\$\(\s*(?:curl|wget)", "chạy kết quả của một lời gọi mạng"),
    (r"\bxxd\s+-r\b|\bopenssl\s+enc\b", "có giải mã nội dung"),
    (r"\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}", "có chuỗi thoát hexa"),
)

#: Đuôi tệp và dòng shebang được coi là script. Nguồn: AAD-33 §4 (`ingest.classify` → `script`).
DUOI_SCRIPT = frozenset({".sh", ".bash", ".zsh", ".fish", ".ps1", ".bat", ".cmd", ".py", ".pl",
                         ".rb", ".mk", ".tcl", ".lua", ".js"})
SHEBANG = re.compile(rb"^#!\s*/\S+")

#: Không đọc quá mức này — một "script" 50 MB là một tệp dữ liệu đặt tên sai.
TRAN_BYTE = 2 * 1024 * 1024


@dataclass(slots=True)
class PhatHien:
    ma: str
    muc: str
    dong: int
    text: str
    vi_sao: str

    def to_dict(self) -> dict[str, Any]:
        return {"ma": self.ma, "muc": self.muc, "dong": self.dong,
                "text": self.text, "vi_sao": self.vi_sao}


@dataclass(slots=True)
class KetQuaQuet:
    findings: list[PhatHien] = field(default_factory=list)
    co_the_con_thieu: bool = False
    ly_do_con_thieu: list[str] = field(default_factory=list)
    da_doc_byte: int = 0
    bi_cat: bool = False

    @property
    def can_hoi(self) -> bool:
        """Có phải HỎI người trước khi chạy không.

        Một `minor` đơn lẻ (ví dụ `chmod 777`) không đáng dựng một thẻ cổng: nó là chuyện về nề
        nếp, không phải về thiệt hại không hoàn tác được. `major` trở lên thì hỏi.
        """
        return any(f.muc in (BLOCKER, MAJOR) for f in self.findings)

    @property
    def muc_cao_nhat(self) -> str | None:
        for m in (BLOCKER, MAJOR, MINOR):
            if any(f.muc == m for f in self.findings):
                return m
        return None

    def to_dict(self) -> dict[str, Any]:
        return {"findings": [f.to_dict() for f in self.findings],
                "can_hoi": self.can_hoi, "muc_cao_nhat": self.muc_cao_nhat,
                "co_the_con_thieu": self.co_the_con_thieu,
                "ly_do_con_thieu": self.ly_do_con_thieu,
                "da_doc_byte": self.da_doc_byte, "bi_cat": self.bi_cat}

    def cau_canh_bao(self) -> str:
        """Câu cho thẻ cổng — tiếng Việt, nêu SỐ chỗ và TRÍCH dòng, không nêu tên regex.

        Trích dòng là bắt buộc: người duyệt phải thấy chính dòng lệnh, vì thứ họ đang quyết định
        là "có chạy dòng này không". Một câu "script có hành vi nguy hiểm" không cho họ quyết
        được gì, và [DEV-198] đã đo được người ta bấm qua loại cảnh báo ấy.
        """
        if not self.findings:
            return "Quét tĩnh không thấy lệnh phá hoại hay lệnh đọc khoá riêng."
        d = [f"Quét tĩnh thấy {len(self.findings)} chỗ đáng hỏi:"]
        for f in self.findings[:8]:
            d.append(f"  • dòng {f.dong} ({f.muc}): {f.text[:120]} — {f.vi_sao}")
        if len(self.findings) > 8:
            d.append(f"  • … và {len(self.findings) - 8} chỗ nữa")
        if self.co_the_con_thieu:
            d.append("Cảnh báo: " + "; ".join(self.ly_do_con_thieu)
                     + " — phép quét tĩnh KHÔNG bảo đảm đã thấy hết.")
        if self.bi_cat:
            d.append(f"Chỉ quét {self.da_doc_byte // 1024} KB đầu tệp.")
        return "\n".join(d)


def la_script(p: Path) -> bool:
    """Tệp này có phải script không — shebang trước, đuôi tệp sau.

    Cùng thứ tự với `ingest.classify`: nội dung là thứ tệp THẬT SỰ là, phần mở rộng là thứ người
    dùng gõ. Một script không đuôi nhưng có `#!/bin/bash` vẫn là script.
    """
    try:
        with p.open("rb") as f:
            if SHEBANG.match(f.read(64)):
                return True
    except OSError:
        return False
    return p.suffix.lower() in DUOI_SCRIPT


def quet_van(van: str) -> KetQuaQuet:
    """Quét một chuỗi. Tách khỏi `quet_tep` để kiểm được không cần hệ tệp."""
    kq = KetQuaQuet(da_doc_byte=len(van.encode("utf-8", errors="ignore")))
    dong = van.splitlines()
    for i, d in enumerate(dong, start=1):
        sach = d.strip()
        if sach.startswith("#") and not sach.startswith("#!"):
            continue                       # dòng chú thích: nói VỀ lệnh, không chạy lệnh
        for ma, muc, mau, vi_sao in MAU:
            if re.search(mau, d):
                kq.findings.append(PhatHien(ma=ma, muc=muc, dong=i, text=sach, vi_sao=vi_sao))
    for mau, ly_do in MAU_CHE_GIAU:
        if re.search(mau, van):
            kq.co_the_con_thieu = True
            kq.ly_do_con_thieu.append(ly_do)
    return kq


def quet_tep(duong: Path | str) -> KetQuaQuet:
    """Quét một tệp script. Tệp không đọc được → kết quả rỗng, KHÔNG ném ngoại lệ.

    Không ném vì bên gọi là `ingest.classify`, và một lô 200 tệp không được dừng vì một tệp hỏng
    quyền đọc. Tệp không quét được thì `co_the_con_thieu` bật lên — im lặng ở đây sẽ bị đọc thành
    "đã quét, sạch".
    """
    p = Path(duong).expanduser()
    try:
        raw = p.open("rb").read(TRAN_BYTE + 1)
    except OSError as e:
        kq = KetQuaQuet(co_the_con_thieu=True, ly_do_con_thieu=[f"không đọc được tệp ({e.strerror})"])
        return kq
    bi_cat = len(raw) > TRAN_BYTE
    kq = quet_van(raw[:TRAN_BYTE].decode("utf-8", errors="replace"))
    kq.bi_cat = bi_cat
    if bi_cat:
        kq.co_the_con_thieu = True
        kq.ly_do_con_thieu.append(f"tệp lớn hơn {TRAN_BYTE // 1024 // 1024} MB nên chỉ quét phần đầu")
    return kq
