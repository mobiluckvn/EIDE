"""Ledger — nhật ký sự kiện append-only có chuỗi hash (SEC-25 §3, API-15 §5 ledger_events.json, DDD-14 decision_log).

Mỗi bản ghi: {seq, ts, kind, actor, data, prev_hash, hash}; hash = sha256(prev_hash + json(bản ghi không có hash)).
Kiểu sự kiện hợp lệ lấy từ docs/spec/api/ledger_events.json; kiểu lạ bị từ chối (E6001).
"""
from __future__ import annotations

import hashlib
import json
import re
import threading
from collections.abc import Callable
from datetime import UTC, datetime
from functools import lru_cache
from pathlib import Path
from typing import Any

from eide_core.errors import EideError
from eide_core.paths import spec_dir

GENESIS = "0" * 64

# API-15 §7: "bộ lọc che chuỗi giống khóa API (regex `sk-|AIza|Bearer `) trước khi ghi".
# Che ở TẦNG LEDGER chứ không ở từng chỗ gọi: ledger là append-only và chống sửa, nên một khóa
# lọt vào đây thì không gỡ ra được nữa mà không phá chuỗi hash — và vẫn phải đổi khóa. Chỗ duy
# nhất chặn được là ngay trước khi ghi.
RE_BI_MAT = re.compile(r"(sk-|AIza|Bearer )[A-Za-z0-9\-_\.]{8,}")


def che_bi_mat(x: Any) -> Any:
    """Thay chuỗi giống khóa bằng `<đã che>`, giữ 4 ký tự đầu để còn truy được là khóa nào."""
    if isinstance(x, str):
        return RE_BI_MAT.sub(lambda m: m.group(0)[:8] + "…<đã che>", x)
    if isinstance(x, dict):
        return {k: che_bi_mat(v) for k, v in x.items()}
    if isinstance(x, list):
        return [che_bi_mat(v) for v in x]
    return x


@lru_cache(maxsize=1)
def event_kinds() -> set[str]:
    kinds: set[str] = set()
    for e in json.loads((spec_dir() / "api" / "ledger_events.json").read_text(encoding="utf-8")):
        for k in e["kind"].split("/"):
            kinds.add(k.strip())
    return kinds


class Ledger:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._last_hash = GENESIS
        self._seq = 0
        # Người quan sát — gọi SAU khi bản ghi đã xuống đĩa và chuỗi băm đã nối.
        #
        # Đây là chỗ duy nhất trong hệ thống thấy được MỌI việc đã xảy ra, nên nó là chỗ đúng để
        # daemon phái sinh sự kiện `event.*` (API-15 §1) cho panel. Cách còn lại — rắc lời gọi
        # "phát sự kiện" vào từng năng lực — thì mỗi năng lực mới là một chỗ có thể quên, và
        # panel sẽ im lặng bỏ sót đúng việc vừa thêm.
        self._quan_sat: list[Callable[[dict[str, Any]], None]] = []
        # Các bộ theo dõi TỆP do chính sổ cái này tạo ra. Giữ tham chiếu để `append()` đánh dấu
        # `seq` đã phát — xem giải thích ở `append()`.
        self._tep: list[TheoDoiTep] = []
        if self.path.exists():
            for line in self.path.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    rec = json.loads(line)
                    self._last_hash, self._seq = rec["hash"], rec["seq"]

    def append(self, kind: str, data: dict[str, Any], actor: str = "agent") -> dict[str, Any]:
        if kind not in event_kinds():
            raise EideError("E6001", f"Kiểu sự kiện ledger không có trong API-15: {kind}")
        self._seq += 1
        rec = {"seq": self._seq, "ts": datetime.now(UTC).isoformat(), "kind": kind, "actor": actor,
               "data": che_bi_mat(data), "prev_hash": self._last_hash}
        rec["hash"] = _hash(rec)
        with self.path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False, sort_keys=True) + "\n")
        self._last_hash = rec["hash"]
        # ĐÁNH DẤU `seq` cho mọi bộ theo dõi tệp TRƯỚC khi phát in-process.
        #
        # Hai đường cùng dẫn tới một người nhận: `_quan_sat` chạy ngay, bộ theo dõi tệp đọc lại
        # chính dòng vừa ghi sau ~0,4 s. `TheoDoiTep._goi` có lọc theo `seq`, nhưng nó chỉ biết
        # một `seq` SAU KHI tự đọc dòng ấy — tức là sau khi đã phát lần hai. Nên phép lọc chưa
        # bao giờ chặn được đường này, dù docstring của `TheoDoiTep` khẳng định nó chặn.
        #
        # Đo 17/09/2026 trên một lượt `chat.send`: 29 thông báo `event.run.progress` lên giao
        # diện cho 15 bản ghi sổ cái — MỌI việc của chính daemon đi lên hai lần. Không ai thấy
        # vì các thẻ khoá theo `run_id` và mọi phép cập nhật đều luỹ đẳng; nó chỉ lộ ra khi thẻ
        # Run bắt đầu ĐẾM bước.
        #
        # Chỉ đánh dấu cho bộ theo dõi nào có CÙNG hàm nhận với một người quan sát in-process.
        # Khử trùng cho tất cả là sai: ai chỉ đăng ký `theo_doi_tep()` thì bộ theo dõi tệp là
        # đường DUY NHẤT tới họ, và đánh dấu ở đây sẽ nuốt mất bản ghi thay vì khử một bản sao.
        #
        # `==` chứ KHÔNG `is`. Người gọi thường truyền cùng một phương thức ràng buộc cho cả hai
        # đường (`self.ledger.theo_doi(self._f)` rồi `self.ledger.theo_doi_tep(self._f)`), mà
        # mỗi lần truy cập một phương thức ràng buộc lại sinh một ĐỐI TƯỢNG MỚI — nên `is` luôn
        # sai và phép khử trùng im lặng không chạy. Bản vá đầu của chính mục này dùng `is`, và
        # nó qua được toàn bộ 1 612 bài kiểm trong khi trên daemon thật vẫn phát đôi.
        for td in self._tep:
            if any(q == td.f for q in self._quan_sat):
                td.danh_dau(rec["seq"])
        # Người quan sát KHÔNG được làm hỏng việc ghi sổ. Một panel đã đóng ống dẫn, một
        # `BrokenPipeError` từ stdout — không lý do nào trong số đó đáng để mất một dòng sổ cái.
        # Sổ cái là bằng chứng; thông báo cho giao diện thì không.
        for f in self._quan_sat:
            try:
                f(rec)
            except Exception:  # noqa: BLE001 — xem giải thích ngay trên
                pass
        return rec

    def theo_doi(self, f: Callable[[dict[str, Any]], None]) -> None:
        """Đăng ký một người quan sát. Gọi sau khi bản ghi đã an toàn trên đĩa."""
        self._quan_sat.append(f)

    def theo_doi_tep(self, f: Callable[[dict[str, Any]], None], *,
                     phat_lai: int = 0, chu_ky: float = 0.4) -> TheoDoiTep:
        """Theo dõi TỆP sổ cái — thấy cả bản ghi do tiến trình KHÁC ghi.

        `theo_doi()` ở trên chỉ gọi cho bản ghi do chính tiến trình này ghi, và với một sổ cái
        thì đó là nửa sự thật: cùng một dự án có thể có một daemon phục vụ giao diện, một CLI
        người dùng gõ, và một tác tử chạy nền — cả ba ghi vào CÙNG một tệp. Đo 14/09/2026: tác
        tử chạy 28 lời gọi năng lực và ghi 105 sự kiện, trong khi cửa sổ EIDE đang mở không
        hiện một dòng nào, vì nó chỉ nghe chính nó.

        Trả về một `TheoDoiTep` để người gọi `dung()` khi đóng. Luồng là daemon nên tiến trình
        vẫn thoát được kể cả khi ai đó quên dừng.

        `phat_lai` là số bản ghi cuối phát lại ngay khi bắt đầu — mở giao diện sau khi tác tử
        đã chạy thì vẫn thấy nó vừa làm gì. 0 nghĩa là chỉ nghe từ nay trở đi.
        """
        td = TheoDoiTep(self.path, f, phat_lai=phat_lai, chu_ky=chu_ky)
        td.bat_dau()
        self._tep.append(td)
        return td

    def verify(self) -> tuple[bool, int]:
        """Kiểm chuỗi hash; trả (ok, seq lỗi đầu tiên hoặc 0)."""
        prev = GENESIS
        for line in self.path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            rec = json.loads(line)
            h = rec.pop("hash")
            if rec["prev_hash"] != prev or _hash(rec) != h:
                return False, rec["seq"]
            prev = h
        return True, 0

    def records(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        return [json.loads(x) for x in self.path.read_text(encoding="utf-8").splitlines() if x.strip()]


def _hash(rec: dict[str, Any]) -> str:
    body = json.dumps({k: v for k, v in rec.items() if k != "hash"}, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256((rec["prev_hash"] + body).encode("utf-8")).hexdigest()


class TheoDoiTep:
    """Đọc phần đuôi `ledger.jsonl` và gọi một hàm cho mỗi bản ghi mới.

    Thứ này đứng giữa sổ cái và giao diện, nên nó phải chịu được mọi kiểu hỏng mà **không dừng
    lại**: một lần dừng im lặng nghĩa là người dùng nhìn một màn hình đứng yên và tưởng tác tử
    chưa làm gì. Bốn tình huống có thật, xử lý từng cái:

    1. **Tệp chưa tồn tại.** Dự án mới chưa có sổ cái, và giao diện mở trước lời gọi đầu tiên là
       chuyện thường. Đợi, không nổ.
    2. **Dòng viết dở.** `append()` ghi bằng một lần `write` nhưng hệ tệp không hứa nguyên tử,
       nên đọc giữa chừng có thể được nửa dòng. Chỉ xử lý phần tới dấu `\\n` cuối cùng và giữ
       phần đuôi lại cho vòng sau.
    3. **Tệp ngắn đi.** Ai đó xoay vòng, xoá, hay chép đè sổ cái. Kích thước nhỏ hơn chỗ đã đọc
       là dấu hiệu chắc chắn; đọc lại từ đầu thay vì trượt vào giữa một bản ghi.
    4. **Hàm nhận ném lỗi.** Panel đóng ống, JSON không tuần tự hoá được — không lý do nào đáng
       để mất những bản ghi còn lại. Bắt và đi tiếp, đúng như `append()` làm với `_quan_sat`.

    Lọc theo `seq` chứ không theo vị trí byte: cùng một daemon vừa ghi qua `append()` (và đã
    phát cho `_quan_sat`) vừa đọc tệp này, nên nếu không lọc thì mọi việc của chính nó lên giao
    diện HAI lần.
    """

    def __init__(self, path: Path, f: Callable[[dict[str, Any]], None], *,
                 phat_lai: int = 0, chu_ky: float = 0.4) -> None:
        self.path = path
        self.f = f
        self.phat_lai = max(0, phat_lai)
        self.chu_ky = chu_ky
        self._dung = threading.Event()
        self._luong: threading.Thread | None = None
        self._da_thay: set[int] = set()
        self._vi_tri = 0
        self._du = ""
        self._inode: int | None = None

    def bat_dau(self) -> None:
        # Phát lại lịch sử TRƯỚC khi luồng chạy, và trong chính luồng gọi: người gọi vì thế
        # chắc chắn thấy đủ quá khứ trước khi thấy bản ghi mới đầu tiên. Làm trong luồng nền thì
        # hai nguồn ấy đua nhau và dòng thời gian trên giao diện ra sai thứ tự.
        self._khoi_dau()
        self._luong = threading.Thread(target=self._vong, daemon=True,
                                       name=f"ledger-tail:{self.path.name}")
        self._luong.start()

    def dung(self, cho: float = 1.0) -> None:
        self._dung.set()
        if self._luong is not None:
            self._luong.join(timeout=cho)

    # ---- nội bộ

    def _khoi_dau(self) -> None:
        """Ghi nhận mọi bản ghi hiện có là "đã thấy", và phát lại `phat_lai` cái cuối.

        Phát lại đi qua `_phat()` chứ không qua `_goi()`: `_goi` lọc theo `_da_thay`, mà ở đây
        mọi bản ghi đều sắp được đánh dấu là đã thấy — lọc trước rồi phát thì phát ra rỗng.
        """
        ban_ghi = self._doc_tat_ca()
        if self.phat_lai:
            for r in ban_ghi[-self.phat_lai:]:
                self._phat(r)
        for r in ban_ghi:
            if isinstance(r.get("seq"), int):
                self._da_thay.add(r["seq"])

    def _doc_tat_ca(self) -> list[dict[str, Any]]:
        try:
            van = self.path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            return []
        self._vi_tri = len(van.encode("utf-8"))
        ra = []
        for dong in van.splitlines():
            if (r := _doc_dong(dong)) is not None:
                ra.append(r)
        return ra

    def _vong(self) -> None:
        while not self._dung.is_set():
            try:
                self._doc_moi()
            except Exception:  # noqa: BLE001 — một vòng hỏng không được giết cả người theo dõi
                pass
            self._dung.wait(self.chu_ky)

    def _doc_moi(self) -> None:
        try:
            st = self.path.stat()
        except OSError:
            return                       # (1) tệp chưa có, hoặc vừa bị xoá — đợi
        co = st.st_size
        if self._inode is not None and st.st_ino != self._inode:
            # (3a) TỆP KHÁC, không phải tệp cũ ngắn đi: ai đó `rm` rồi dự án ghi lại từ đầu.
            # Sổ cái mới đánh số `seq` lại từ 1, nên `_da_thay` cũ biến mọi bản ghi mới thành
            # "đã thấy" và người theo dõi câm vĩnh viễn. Quên hết là câu trả lời đúng.
            self._da_thay.clear()
            self._vi_tri, self._du = 0, ""
        elif co < self._vi_tri:
            # (3b) CÙNG tệp nhưng ngắn đi — bị cắt bớt hoặc ghi đè. Đọc lại từ đầu nhưng GIỮ
            # `_da_thay`: các seq cũ vẫn là seq cũ, và phát lại chúng là nói dối về thứ tự.
            self._vi_tri, self._du = 0, ""
        self._inode = st.st_ino
        if co == self._vi_tri:
            return
        with self.path.open("rb") as fp:
            fp.seek(self._vi_tri)
            khuc = fp.read()
        self._vi_tri += len(khuc)
        van = self._du + khuc.decode("utf-8", errors="replace")
        # (2) chỉ xử lý tới dấu xuống dòng cuối; phần sau nó có thể là một bản ghi đang được ghi
        if "\n" not in van:
            self._du = van
            return
        xong, _, self._du = van.rpartition("\n")
        for dong in xong.splitlines():
            if (r := _doc_dong(dong)) is not None:
                self._goi(r)

    def danh_dau(self, seq: int) -> None:
        """Ghi nhận một `seq` đã được phát bằng đường khác — xem `Ledger.append`."""
        if isinstance(seq, int):
            self._da_thay.add(seq)

    def _goi(self, r: dict[str, Any]) -> None:
        """Phát một bản ghi MỚI — lọc trùng theo `seq` trước."""
        seq = r.get("seq")
        if isinstance(seq, int):
            if seq in self._da_thay:
                return
            self._da_thay.add(seq)
        self._phat(r)

    def _phat(self, r: dict[str, Any]) -> None:
        """Gửi thẳng cho hàm nhận, không lọc. Lỗi của bên nhận không lan ra."""
        try:
            self.f(r)
        except Exception:  # noqa: BLE001 — xem docstring, mục (4)
            pass


def _doc_dong(dong: str) -> dict[str, Any] | None:
    """Một dòng JSONL → bản ghi, hoặc None nếu dòng rỗng/hỏng.

    Dòng hỏng KHÔNG dừng việc đọc: sổ cái là chỉ-thêm nên một dòng hỏng là dấu hiệu ghi dở hoặc
    đĩa lỗi, và những dòng SAU nó vẫn đọc được. `verify()` mới là chỗ nói ra chuyện chuỗi băm
    gãy — người theo dõi này chỉ có việc đưa tin.
    """
    dong = dong.strip()
    if not dong:
        return None
    try:
        r = json.loads(dong)
    except (ValueError, TypeError):
        return None
    return r if isinstance(r, dict) else None
