"""JSON-RPC 2.0 daemon — API-15 §1 (docs/spec/api/openrpc.json). Sprint 1: stdio, tập con phương thức.

Phương thức đã có: plane.hello, caps.list, caps.describe, caps.invoke, queue.list, autonomy.get, autonomy.set, stop,
project.list. Tên/tham số/kết quả bám openrpc.json; test_specs_consistency kiểm tra mọi tên đăng ký đều có trong spec.
"""
from __future__ import annotations

import json
import secrets
import threading
from collections.abc import Callable
from dataclasses import asdict
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any, TextIO

import yaml

from eide import __version__
from eide_core.errors import EideError, error_table
from eide_core.ledger import Ledger, TheoDoiTep
from eide_core.paths import user_log
from eide_core.policy import PolicyGate
from eide_core.registry import get_registry
from eide_core.router import Context, Router
from eide_core.undo import UndoService

API_VERSION = "1.2"


# Sổ cái ghi gì → panel nhận sự kiện nào (API-15 §1 `event.*`).
#
# Phái sinh từ SỔ CÁI chứ không rắc lời gọi "phát sự kiện" vào từng năng lực, và đó là quyết
# định thiết kế chính của kênh này: sổ cái là chỗ duy nhất thấy được MỌI việc đã xảy ra, nên
# một chỗ móc ở đó phủ cả 197 năng lực hiện có lẫn mọi năng lực thêm sau. Cách kia thì mỗi năng
# lực mới là một chỗ có thể quên, và panel sẽ im lặng bỏ sót đúng việc vừa thêm.
#
# Hệ quả kèm theo — đáng giá hơn chính kênh này: một sự kiện panel nhìn thấy là một sự kiện ĐÃ
# NẰM TRONG CHUỖI BĂM. Không có đường nào để giao diện hiện một việc mà sổ cái không có.
SU_KIEN: dict[str, str] = {
    "cap.run.start": "event.run.progress",
    "cap.run.finish": "event.run.progress",
    "gate.decision": "event.gate.opened",
    "gate.human": "event.queue.changed",
    "undo.register": "event.undo.registered",
    "undo.apply": "event.undo.registered",
    "undo.expire": "event.undo.expired",
    "autonomy.change": "event.autonomy.changed",
    "stop": "event.autonomy.changed",
    "policy.escalate": "event.notice",
    "policy.sign": "event.notice",
    "store.write": "event.knowledge.changed",
    "store.migrate": "event.knowledge.changed",
    "acq.state": "event.knowledge.changed",
    "discover.result": "event.discover.changed",
    "project.state": "event.project.changed",
    "model.call": "event.model.call",
    "tool.report": "event.tool.report",
    "question": "event.chat.question",
    "answer": "event.chat.restated",
    "report": "event.chat.report",
    "intent": "event.chat.intent",
    "error": "event.notice",
}

# Daemon KHÔNG tự phát lại lịch sử khi mở. Giao diện HỎI, bằng `view.timeline`.
#
# Bản đầu (14/09/2026) phát lại 200 bản ghi ngay trong `__init__`, và nó **treo daemon**: stdio
# là một ống có đệm hữu hạn — 64 KB trên macOS — còn client chỉ đọc khi đang chờ câu trả lời của
# một lời gọi. Phát một lúc 200 sự kiện trước khi client gửi gì là ghi vào một ống không ai đọc,
# và `write` chặn vĩnh viễn ở đúng chỗ ấy.
#
# Đo được: dự án AVR 108 sự kiện ≈ 55,7 KB (sát ngưỡng); dự án ESP32-C3 ≈ 82 KB — **vượt, treo
# ngay khi mở giao diện**. Triệu chứng nhìn từ ngoài là một cửa sổ mở lên rồi đứng im, không
# lỗi, không thông báo.
#
# Kênh đẩy vì thế chỉ dùng cho sự kiện THỜI GIAN THỰC: ít, rải rác, và luôn có một lời gọi đang
# chờ nên client đang đọc. Lịch sử là một khối lớn, và khối lớn phải đi bằng đường hỏi-đáp —
# `view.timeline` (VIEW-12, `ref: memory.ledger`) vốn đã sinh ra để làm đúng việc ấy.
PHAT_LAI_KHI_MO = 0

# Ba kiểu sổ cái KHÔNG lên giao diện, và không phải vì quên.
#
# `context.bundle` và phần `prompt` của `model.call` mang nội dung gửi cho mô hình — có thể là
# mã nguồn của người dùng. Sổ cái đã che khoá API (`che_bi_mat`), nhưng che khoá khác với không
# gửi mã nguồn ra một cửa sổ có thể đang chia sẻ màn hình. Màn chi phí cần con số token và vai
# trò, không cần văn bản.
#
# `session.open` / `session.summary` là nhật ký vận hành của chính daemon, không phải việc tác
# tử làm cho dự án.
KHONG_LEN_UI: frozenset[str] = frozenset({"context.bundle", "session.open", "session.summary"})

# Trường bị lược khỏi `event.*` trước khi đẩy lên giao diện — cùng lý do với `KHONG_LEN_UI`,
# nhưng ở mức trường chứ không mức bản ghi: `model.call` vẫn phải lên UI để người thấy chi phí.
TRUONG_KHONG_DAY: frozenset[str] = frozenset({"prompt", "system", "user", "context", "messages"})

# Năng lực NẶNG — `caps.invoke` trả `job_id` thay vì chờ (API-15: "tool nặng trả job_id trong
# result"). Danh sách theo đúng năm nhóm mà `job.status` kể tên: build, flash, extract, render,
# install.
#
# Ranh giới "nặng" đo bằng THỜI GIAN NGƯỜI PHẢI CHỜ, không bằng độ phức tạp: `code.build` gọi
# cmake mất vài chục giây, `env.install` tải vài trăm MB, `extract.svd` phân tích một tệp XML
# 5 MB. Một panel treo trong ngần ấy thời gian là một panel người dùng nghĩ là đã chết.
CAP_NANG: frozenset[str] = frozenset({
    "code.build", "code.test_host", "code.static",
    "env.install", "env.install_pack", "env.sandbox",
    "extract.svd", "extract.atdf", "extract.pdf_register_map", "extract.pdf_pinout",
    "extract.pdf_errata", "extract.pdf_electrical",
    "diagram.render", "view.export_map", "report.export",
    "sim.run", "sim.sweep", "sim.build_platform",
    "registry.seed", "registry.pull",
    "target.flash", "target.erase_fuse", "discover.ports", "discover.bus_scan",
})

# Tên RPC → id năng lực. Sáu cái lệch tên, và lệch có lý do: tên RPC ngắn cho plugin gõ
# (`view.coverage`), tên năng lực nói rõ nó trả cái gì (`view.coverage_map`). Bảng này là chỗ
# DUY NHẤT giữ ánh xạ ấy — hai chỗ thì một chỗ sẽ quên khi đổi tên.
ALIAS: dict[str, str] = {
    "project.open": "project.open",
    "view.kg_map": "view.kg_map",
    "view.focus": "view.kg_focus",
    "view.provenance": "view.provenance",
    "view.coverage": "view.coverage_map",
    "view.impact": "view.impact_map",
    "view.timeline": "view.timeline",
    "view.rag_ask": "view.rag_ask",
    "view.rag_trace": "view.rag_trace",
    "passport.query": "passport.query",
    "passport.browse": "passport.list",
    "log.stats": "debug.log_stats",
}


def _autonomy_du_an(project: Path | None) -> dict[str, Any] | None:
    """`.eide/autonomy.yaml` của dự án, hoặc None.

    Cùng phép đọc với `cli._autonomy_cua_du_an`. Hai bản sao là hai chỗ sẽ trôi, nhưng gộp
    chúng đòi lõi biết về bố cục thư mục dự án — mà `.eide/` là quy ước của `eide`, không phải
    của `eide_core`. Có test đối chiếu hai bên.

    Tệp hỏng thì trả None chứ không nổ: một `autonomy.yaml` sai cú pháp làm daemon chết lúc
    khởi động nghĩa là người dùng mất cả giao diện vì một dòng YAML — và họ không có cách nào
    biết vì sao, vì daemon chết trước khi kịp nói gì.
    """
    if project is None:
        return None
    f = project / ".eide" / "autonomy.yaml"
    if not f.exists():
        return None
    try:
        d = yaml.safe_load(f.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError):
        return None
    return d if isinstance(d, dict) else None



def _ngay_dia_phuong(ts: Any) -> date | None:
    """Ngày ĐỊA PHƯƠNG của một mốc thời gian trong sổ cái.

    Sổ cái đóng dấu `ts` bằng UTC (`Ledger.append`), còn "hạn mức NGÀY" thì người dùng hiểu theo
    múi giờ của họ. So hai thứ ấy bằng `ts.startswith(date.today())` là so một chuỗi UTC với một
    ngày địa phương — và ở Việt Nam (+07) điều đó nghĩa là **mọi chi phí từ nửa đêm tới 7 giờ
    sáng không được tính vào ngân sách hôm nay**. Đo 16/09/2026 lúc 06:55 giờ địa phương: một
    lượt `model.call` 2 USD vừa ghi xong, `budget_state` trả `spent_usd = 0`.

    Hệ quả không phải chuyện hiển thị: APD-08 §5 leo thang khi còn dưới 20% ngân sách, và một
    bộ đếm đọc 0 suốt bảy tiếng đầu ngày là bộ đếm không bao giờ chạm ngưỡng trong bảy tiếng ấy.

    Trả `None` khi mốc thời gian đọc không được — bản ghi ấy không tính vào ngày nào cả, thay vì
    tính nhầm vào hôm nay.
    """
    try:
        d = datetime.fromisoformat(str(ts))
    except (TypeError, ValueError):
        return None
    # Mốc không mang múi giờ thì coi là UTC — đó là thứ `Ledger.append` ghi ra.
    if d.tzinfo is None:
        d = d.replace(tzinfo=UTC)
    return d.astimezone().date()


class Daemon:
    def __init__(self, project: Path | None = None,
                 phat: Callable[[str, dict[str, Any]], None] | None = None) -> None:
        # Chính sách CỦA DỰ ÁN, không phải chính sách mặc định.
        #
        # `PolicyGate()` trần đọc `docs/spec/policy/defaults.yaml` và niêm `defaults.sig` toàn
        # cục. Trong một dự án thì cả hai đều sai: mức tự chủ nằm ở `.eide/autonomy.yaml`, và
        # niêm có hiệu lực là `.eide/policy.sig` — `eide policy sign -p <dự án>` ghi ra đúng tệp
        # ấy. CLI đã làm thế từ đầu (`cli._router`); daemon thì không, nên **giao diện chạy với
        # một chính sách khác CLI trên cùng một dự án**.
        #
        # Đo được 14/09/2026: dự án AVR đặt `autonomy: A2`, `eide caps invoke` áp A2, còn cửa sổ
        # EIDE hiện mức "—" và quyết định theo mặc định. Hai nguồn sự thật cho cùng một câu hỏi,
        # và cái người dùng NHÌN THẤY là cái sai.
        self.gate = PolicyGate(config=_autonomy_du_an(project),
                               sig_path=(project / ".eide" / "policy.sig") if project else None)
        self.ledger = Ledger((project / ".eide" / "store" / "ledger.jsonl") if project else user_log() / "ledger.jsonl")
        self.router = Router(gate=self.gate, ledger=self.ledger)
        self.ctx = Context(project_dir=project, extra={"gate": self.gate})
        # `phat` do lớp vận chuyển đưa vào (`serve_stdio`). Không có thì daemon chạy y như cũ —
        # CLI và test gọi `handle()` trực tiếp không cần kênh đẩy, và bắt chúng dựng một cái
        # giả chỉ để im lặng là thêm nghi thức không đổi lấy gì.
        self.phat = phat
        # Theo dõi TỆP sổ cái, không chỉ lời gọi của chính daemon này.
        #
        # Đây là mắt xích làm cho giám sát có nghĩa (GIAM-SAT-UI §0.1): tác tử chạy qua CLI, một
        # phiên khác, hay một tiến trình nền — tất cả ghi vào CÙNG `ledger.jsonl` của dự án, và
        # trước 14/09/2026 cửa sổ EIDE không thấy gì trong số đó. Đo được: 28 lời gọi, 105 sự
        # kiện, giao diện đứng yên.
        #
        # `theo_doi()` in-process vẫn giữ, và giữ có lý do: nó chạy NGAY khi bản ghi xuống đĩa,
        # còn người theo dõi tệp chậm nhất một chu kỳ. Việc của chính daemon vì thế hiện tức
        # thì; việc của tiến trình khác hiện sau ~0,4 s. `TheoDoiTep` lọc trùng theo `seq` nên
        # không có bản ghi nào lên giao diện hai lần.
        self._tail: TheoDoiTep | None = None
        if phat is not None:
            self.ledger.theo_doi(self._tu_so_cai)
            self._tail = self.ledger.theo_doi_tep(self._tu_so_cai, phat_lai=PHAT_LAI_KHI_MO)
        # Việc chạy nền. Khóa vì `job.status` đọc từ luồng RPC còn luồng việc thì ghi.
        self._jobs: dict[str, dict[str, Any]] = {}
        self._khoa = threading.Lock()
        self.methods: dict[str, Callable[[dict[str, Any]], Any]] = {
            "plane.hello": self.hello, "caps.list": self.caps_list, "caps.describe": self.caps_describe,
            "caps.invoke": self.caps_invoke, "queue.list": self.queue_list, "autonomy.get": self.autonomy_get,
            "autonomy.set": self.autonomy_set, "stop": self.stop, "project.list": self.project_list,
            "gate.decide": self.gate_decide, "undo.list": self.undo_list, "undo.apply": self.undo_apply,
            # ---- bề mặt panel (UXD-13): API-15 gọi phần lớn nhóm này là "alias caps.invoke để
            # plugin gọi ngắn". Alias chứ không hiện thực lại: mỗi phương thức đi qua ĐÚNG
            # `Router.invoke` như mọi lời gọi khác, nên cùng cổng chính sách, cùng nhật ký, cùng
            # hoàn tác. Một đường tắt gọi thẳng handler sẽ nhanh hơn và sẽ bỏ qua cả ba thứ ấy.
            **{ten: self._alias(cap) for ten, cap in ALIAS.items()},
            "project.close": self.project_close, "session.state": self.session_state, "budget.state": self.budget_state,
            "diagram.open": self.diagram_open, "diagram.save": self.diagram_save,
            "doc.open": self.doc_open, "hex.resolve": self.hex_resolve,
            "chat.send": self.chat_send, "chat.answer": self.chat_answer,
            "chat.history": self.chat_history, "debug.ask": self.debug_ask,
            "log.register": self.log_register,
            "job.status": self.job_status, "job.cancel": self.job_cancel,
        }

    # ---- việc chạy nền (API-15: "tool nặng trả job_id trong result")

    def _chay_nen(self, cap_id: str, args: dict[str, Any]) -> dict[str, Any]:
        """Khởi động một việc nặng và trả `job_id` NGAY.

        Luồng riêng chứ không tiến trình riêng: các năng lực nặng ở đây đều dành phần lớn thời
        gian CHỜ một tiến trình con (`cmake`, `qemu`, `brew`) hoặc chờ I/O, nên GIL không chắn
        đường. Tiến trình riêng thì phải tuần tự hoá `Context` và mở một store thứ hai — đắt hơn
        nhiều mà không nhanh hơn cho đúng loại việc này.
        """
        jid = "job_" + secrets.token_hex(6)
        with self._khoa:
            self._jobs[jid] = {"state": "running", "progress": 0, "log_tail": [],
                               "cap": cap_id, "result": None, "cancel": False,
                               "at": datetime.now(UTC).isoformat()}

        def chay() -> None:
            try:
                run = self.router.invoke(cap_id, args, self.ctx)
                with self._khoa:
                    j = self._jobs[jid]
                    if j["cancel"]:
                        j["state"] = "cancelled"
                    else:
                        j["state"] = "done" if run.status == "done" else run.status
                        j["result"] = asdict(run)
                        j["progress"] = 100
            except Exception as e:  # noqa: BLE001 — một việc nền hỏng KHÔNG được giết daemon
                with self._khoa:
                    self._jobs[jid].update(state="failed",
                                           log_tail=[f"{type(e).__name__}: {e}"[:400]])
            finally:
                self._bao_job(jid)

        threading.Thread(target=chay, name=f"eide-{jid}", daemon=True).start()
        self._bao_job(jid)
        return {"status": "running", "job_id": jid, "cap": cap_id}

    def _bao_job(self, jid: str) -> None:
        if self.phat is None:
            return
        with self._khoa:
            j = dict(self._jobs.get(jid) or {})
        self.phat("event.job.progress", {"job_id": jid, "pct": j.get("progress", 0),
                                         "log_tail": j.get("log_tail") or [],
                                         "state": j.get("state")})

    def job_status(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{job_id}` → `{state, progress, log_tail[], result?}`."""
        with self._khoa:
            j = self._jobs.get(p["job_id"])
            if j is None:
                raise EideError("E2000", f"Không có việc `{p['job_id']}`",
                                exists=sorted(self._jobs), candidates=[], missing=[p["job_id"]])
            return {"state": j["state"], "progress": j["progress"],
                    "log_tail": list(j["log_tail"]),
                    **({"result": j["result"]} if j["result"] is not None else {})}

    def job_cancel(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{job_id}` → trạng thái sau khi xin hủy.

        **Hủy là HỢP TÁC, không phải cưỡng chế** — và nói thẳng điều đó quan trọng hơn là giả vờ
        ngược lại. Python không giết an toàn được một luồng đang chạy, còn giết tiến trình con
        giữa chừng thì để lại một thư mục `build/` nửa vời mà lần dựng sau tưởng là hợp lệ. Cờ
        `cancel` được đặt; việc đang chạy vẫn chạy hết, nhưng KẾT QUẢ bị bỏ và trạng thái là
        `cancelled`.

        Việc đã xong thì không hủy được nữa — trả nguyên trạng thái, không giả vờ đã hủy.
        """
        with self._khoa:
            j = self._jobs.get(p["job_id"])
            if j is None:
                raise EideError("E2000", f"Không có việc `{p['job_id']}`",
                                exists=sorted(self._jobs), candidates=[], missing=[p["job_id"]])
            if j["state"] == "running":
                j["cancel"] = True
                j["log_tail"] = [*j["log_tail"], "đã xin hủy — việc đang chạy sẽ chạy hết, "
                                                 "kết quả bị bỏ"]
        return self.job_status(p)

    # ---- ba sự kiện KHÔNG suy được từ sổ cái

    def _id_cho(self) -> list[str]:
        """Id các mục đang chờ — HỢP của hàng đợi bền và hàng đợi phiên này.

        `cho_con_lai` đọc từ store, vì hàng đợi phải sống qua lần tắt máy (UXD-13 U2). Nhưng một
        mục ASK có thể sinh ra khi CHƯA CÓ store để ghi vào: `project.create` bị cổng chặn thì
        dự án còn chưa tồn tại. Mục ấy có thật, đang chờ, và chỉ nằm trong RAM — bỏ nó khỏi phép
        so là để panel không bao giờ biết về đúng loại mục chờ đến sớm nhất.

        `cho_con_lai` trả DICT (`run_id`), không phải đối tượng. Bản đầu viết `r.id` và lặng lẽ
        không bao giờ chạy tới, vì danh sách luôn rỗng ở đúng tình huống nói trên.
        """
        ben = [r["run_id"] for r in self.router.cho_con_lai(self.ctx)]
        ram = [r.run_id for r in self.router.queue]
        return list(dict.fromkeys(ben + ram))

    def _sau_loi_goi(self, ten: str, kq: Any) -> None:
        """Sự kiện phái sinh từ KẾT QUẢ một lời gọi, không từ bản ghi sổ cái.

        Ba cái này khác mười ba cái kia ở chỗ sổ cái không mang đủ dữ kiện: `store.write` biết
        có ghi vào store, nhưng không biết MỤC NÀO của tài liệu vừa thành lỗi thời — thứ panel
        cần để tô xám đúng chỗ. Đọc từ kết quả là cách duy nhất, và nó vẫn an toàn: kết quả ấy
        đến từ một lượt chạy ĐÃ có `cap.run.finish` trong chuỗi băm.

        `event.queue.changed` thì ngược lại — nó không thuộc về một năng lực nào, nó là trạng
        thái của daemon. So chiều dài hàng đợi trước/sau mỗi lời gọi là phép đo rẻ nhất và
        không bỏ sót đường nào: mục chờ sinh ra từ `caps.invoke`, từ `chat.send`, hay từ một nút
        giữa chuỗi đều đi qua cùng một hàng đợi.
        """
        if self.phat is None:
            return
        if ten in ("doc.sync", "caps.invoke") and isinstance(kq, dict):
            for s in (kq.get("stale") or []):
                if isinstance(s, dict) and s.get("doc_id"):
                    self.phat("event.doc.stale",
                              {"id": s["doc_id"], "sections": [s.get("heading")]})
        if ten in ("diagram.save", "caps.invoke") and isinstance(kq, dict):
            d = kq.get("sync_diff") or kq.get("diff")
            if isinstance(d, dict) and d.get("stale"):
                self.phat("event.diagram.stale",
                          {"id": kq.get("id"), "node_ids": d.get("in_code_only", [])})

    def _hang_doi_doi(self, truoc: list[str]) -> None:
        sau = self._id_cho()
        them_moi = [x for x in sau if x not in truoc]
        bot = [x for x in truoc if x not in sau]
        if self.phat is not None and (them_moi or bot):
            self.phat("event.queue.changed",
                      {"kind": "ask", "added": them_moi, "removed": bot})

    # ---- kênh sự kiện (API-15 §1 `event.*`)

    def _tu_so_cai(self, rec: dict[str, Any]) -> None:
        """Một bản ghi sổ cái → một thông báo cho panel, nếu có ánh xạ.

        Bản ghi KHÔNG có ánh xạ thì im lặng bỏ qua — 26 kiểu sự kiện sổ cái không phải cái nào
        cũng đáng làm phiền giao diện (`model.call`, `context.bundle`, `session.open` là nhật ký
        vận hành, không phải thứ người dùng cần thấy).
        """
        kind = rec.get("kind", "")
        if kind in KHONG_LEN_UI or self.phat is None:
            return
        ten = SU_KIEN.get(kind)
        if ten is None:
            return
        d = {k: v for k, v in (rec.get("data") or {}).items() if k not in TRUONG_KHONG_DAY}
        # `gate.decision` chỉ thành `event.gate.opened` khi nó THẬT SỰ mở một mục chờ. Một quyết
        # định APPROVE là việc máy tự làm xong; báo nó như "có mục cần anh duyệt" sẽ dạy người
        # dùng bỏ qua thông báo — đúng thứ hỏng mà cả POL-17 lo.
        #
        # Nhưng "không phải mục chờ" KHÁC "không đáng cho người biết": ở mức tự chủ cao, thứ
        # người cần giám sát nhất chính là những gì tác tử **tự duyệt**. Nên APPROVE và REJECT
        # đi lên bằng `event.gate.decided` — cùng dữ liệu, khác tên, và giao diện xếp chúng vào
        # dòng thời gian thay vì vào hàng đợi. Trước 14/09/2026 chúng bị bỏ hẳn.
        if kind == "gate.decision" and d.get("decision") != "ASK":
            ten = "event.gate.decided"
        self.phat(ten, {**d, "kind": kind, "at": rec.get("ts"), "seq": rec.get("seq"),
                        "actor": rec.get("actor")})

    def _thong_bao(self, muc: str, van: str, ref: str | None = None) -> None:
        """`event.notice` — cảnh báo chung, dùng cho thứ không đến từ sổ cái."""
        if self.phat is not None:
            self.phat("event.notice", {"level": muc, "text": van, **({"ref": ref} if ref else {})})

    # ---- bề mặt panel

    def _alias(self, cap_id: str):
        """Một phương thức RPC gọi thẳng một năng lực, qua Router.

        Trả `result` chứ không trả cả `CapabilityRun` như `caps.invoke`: panel gọi `view.kg_map`
        muốn một đồ thị để vẽ, không muốn một bản ghi lượt chạy. Nhưng lượt chạy VẪN được ghi —
        chỉ là không trả về. Trạng thái `pending` thì trả nguyên bản ghi, vì lúc ấy thứ panel
        cần đúng là `run_id` để hiện thẻ câu hỏi.
        """
        def goi(p: dict[str, Any]) -> dict[str, Any]:
            run = self.router.invoke(cap_id, p.get("params", p) or {}, self.ctx)
            if run.status != "done":
                return asdict(run)
            return run.result or {}
        return goi

    def session_state(self, p: dict[str, Any]) -> dict[str, Any]:
        """API-15 `session.state` — đọc M2 của phiên đang mở (MEM-11 §2).

        **Trả cả hai trường chưa có dữ liệu, và trả chúng RỖNG.** MEM-11 §2 kể M2 gồm "quyền
        theo phiên (R4)" và "target đang cắm"; `SessionMemory` hôm nay chưa lưu cái nào. Ba
        cách xử lý, và hai cách đầu tệ hơn:

        - Bỏ hẳn hai khoá: giao diện không biết chúng tồn tại, và khoảng trống biến mất khỏi
          tầm nhìn — cùng khuôn với DEV-093, nơi một thiếu sót nằm im vì không ai hỏi tới.
        - Bịa dữ liệu (đọc `discover.ports` gọi đó là "board đang cắm"): board dò được KHÁC
          board đã gắn vào phiên, và trộn hai thứ là nói sai về quyền đang có hiệu lực.
        - Trả rỗng kèm khoá: giao diện hiện đúng thứ có thật và nói ra phần chưa có. Xem DEV-110.
        """
        from eide_core.memory import SessionMemory
        if not self.ctx.project_dir:
            return {"session_id": None, "permits": [], "board": None, "turns": 0,
                    "undo_items": 0, "thieu": ["dự án"]}
        phien = SessionMemory.gan_nhat(Path(self.ctx.project_dir))
        if phien is None:
            return {"session_id": None, "permits": [], "board": None, "turns": 0,
                    "undo_items": 0, "thieu": ["phiên"]}
        return {
            "session_id": phien.session_id,
            "opened_at": phien.opened_at,
            "autonomy_effective": phien.autonomy_effective,
            "stopped": phien.stopped,
            "turns": len(phien.turns),
            "undo_items": len(phien.undo_items),
            # Hai trường MEM-11 §2 kể mà lõi chưa lưu — DEV-110.
            "permits": [],
            "board": None,
            "thieu": ["permits", "board"],
        }

    def project_close(self, p: dict[str, Any]) -> dict[str, Any]:
        """API-15: `project.close` — đóng SessionMemory, KHÔNG đóng dự án.

        Không có năng lực `project.close` trong CDS-12, và đó là đúng: đóng một phiên là việc
        của vòng đời tiến trình, không phải một hành động lên tri thức. Nên nó sống ở đây.
        """
        from eide_core.memory import SessionMemory
        if not self.ctx.project_dir:
            return {}
        phien = SessionMemory.gan_nhat(Path(self.ctx.project_dir))
        if phien is None:
            return {}
        phien.dong(ledger=self.ledger)
        return {"closed": True}

    def diagram_open(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{src, lang}` → `{id, lint[]}` — GEditor vẽ, EIDE soát.

        Ranh giới ấy là của UXD-13: render chạy trong editor (nhanh, không rời máy), còn phán
        xét "lược đồ này có nút mồ côi không" thì cần tri thức của dự án.
        """
        run = self.router.invoke("diagram.lint",
                                 {"src": p.get("src", ""), "lang": p.get("lang", "mermaid")},
                                 self.ctx)
        kq = run.result or {}
        return {"id": p.get("id") or kq.get("id"), "lint": kq.get("issues", kq.get("lint", []))}

    def diagram_save(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{id, src}` → `{lint[], sync_diff?}`.

        `sync_diff` chỉ có khi lược đồ đã lưu trong store — `diagram.sync` so nó với mã. Lược đồ
        mới gõ trong editor chưa có id thì không so được với gì, và nói ra bằng cách vắng mặt
        trường ấy thật hơn là trả một diff rỗng trông như "không lệch".
        """
        lint = self.diagram_open(p).get("lint", [])
        ra: dict[str, Any] = {"lint": lint}
        if p.get("id"):
            run = self.router.invoke("diagram.sync",
                                     {"diagram_id": p["id"], "direction": "check"}, self.ctx)
            if run.status == "done" and run.result:
                ra["sync_diff"] = run.result.get("diff")
        return ra

    def doc_open(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{path}` → `{sections[], stale[]}` — panel mở tài liệu thì thấy ngay mục nào lỗi thời."""
        import json as _json
        import sqlite3 as _sq

        from eide_core import store as _store
        if not self.ctx.project_dir:
            return {"sections": [], "stale": []}
        db = _store.store_path(self.ctx.project_dir)
        if not db.exists():
            return {"sections": [], "stale": []}
        duong = str(p.get("path", ""))
        with _sq.connect(db) as c:
            r = c.execute("SELECT sections, stale_sections FROM doc_artifact"
                          " WHERE path = ? OR id = ?", (duong, duong)).fetchone()
        if not r:
            return {"sections": [], "stale": []}
        return {"sections": _json.loads(r[0] or "[]"), "stale": _json.loads(r[1] or "[]")}

    def hex_resolve(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{address}` → `{subject, facts[]}` — khung nhị phân của GEditor hỏi "0x40005400 là gì".

        Alias của `passport.resolve_address` (PASSPORT-08), KHÔNG tự tra store.

        Bản đầu (12/09 sáng) tự mở store và tự so giá trị ngay trong daemon — chạy đúng, nhưng
        đặt sai tầng: cùng một phép tra sẽ có HAI hiện thực, một cho panel và một cho năng lực,
        và hai phép tra cho cùng một câu hỏi là hai phép tra sẽ lệch nhau đúng lúc quan trọng.
        Phiên bản trong năng lực còn làm được thứ bản daemon không có — suy ra ngoại vi gần nhất
        khi địa chỉ rơi giữa một vùng thanh ghi, đúng cách người ta đọc bản đồ bộ nhớ.

        Đi qua Router nên vẫn có cổng, nhật ký, và `event.run.progress` như mọi lời gọi khác.
        """
        run = self.router.invoke("passport.resolve_address",
                                 {"address": str(p.get("address", "")),
                                  **({"part": p["part"]} if p.get("part") else {})}, self.ctx)
        if run.status != "done":
            return {"subject": None, "facts": []}
        return run.result or {"subject": None, "facts": []}

    def chat_send(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{text}` → `{intent_id, run_id?}` — ô lệnh của UXD-13 U1.

        Đi trọn đường DPS-09: hiểu ý → neo vào dự án → điền mặc định → dựng chuỗi. Không tắt
        bước nào, vì mỗi bước có một cổng riêng: `chat.ground` là chỗ một lệnh nói về con chip
        không có trong dự án bị chặn, và bỏ nó đi thì Orchestrator lập kế hoạch cho một phần
        cứng tưởng tượng.

        Trả `run_id` NGAY cả khi chuỗi còn đang chạy — hợp đồng ghi "kết quả đến qua sự kiện",
        mà kênh sự kiện thì daemon chưa có (16 phương thức `event.*`, xem DOI-CHIEU §4). Cho tới
        khi có, panel hỏi lại bằng `caps.invoke` hoặc `queue.list`; `run_id` là thứ nối hai đầu.
        """
        y = self.router.invoke("chat.parse_intent", {"text": p["text"]}, self.ctx)
        if y.status != "done":
            return asdict(y)
        intent = (y.result or {}).get("intent") or {}
        neo = self.router.invoke("chat.ground", {"intent": intent}, self.ctx)
        grounded = (neo.result or {}).get("grounded", {}) if neo.status == "done" else {}
        ra: dict[str, Any] = {"intent_id": (y.result or {}).get("intent_id") or intent.get("intent")}
        chuoi = self.router.invoke("chat.orchestrate",
                                   {"intent": intent, "grounded": grounded}, self.ctx)
        if chuoi.status == "done" and chuoi.result:
            ra["run_id"] = chuoi.result.get("run_id")
        else:
            ra["run"] = asdict(chuoi)
        return ra

    def chat_answer(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{question_id, option?, text?}` — thẻ câu hỏi gộp của UXD-13 U1.

        Một câu hỏi gộp là một mục ASK đang chờ ở cổng, nên trả lời nó CHÍNH LÀ `gate.decide`.
        Giữ hai tên vì hai chỗ người dùng đứng khác nhau — ô trò chuyện và hàng đợi — nhưng chỉ
        một đường đi xuống, nếu không sẽ có hai sổ quyết định.
        """
        chon = str(p.get("option") or p.get("text") or "approve").lower()
        quyet = "approve" if chon in ("approve", "duyệt", "có", "yes", "ok") else "reject"
        run = self.router.quyet_dinh(p["question_id"], quyet, by="human",
                                     note=str(p.get("text") or ""), ctx_goi_y=self.ctx)
        return asdict(run)

    def chat_history(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{limit?}` → `{turns[]}` từ `session.turns` (MEM-11 §2)."""
        from eide_core.memory import SessionMemory
        if not self.ctx.project_dir:
            return {"turns": []}
        phien = SessionMemory.gan_nhat(Path(self.ctx.project_dir))
        if phien is None:
            return {"turns": []}
        luot = list(getattr(phien, "turns", []) or [])
        n = int(p.get("limit") or 50)
        return {"turns": luot[-n:]}

    def debug_ask(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{path, range, question}` → `{answer, session_id}` — hỏi tại dòng trong khung log."""
        run = self.router.invoke("debug.ask_at",
                                 {"file": p["path"], "range": p.get("range") or {},
                                  "question": p["question"]}, self.ctx)
        if run.status != "done":
            return asdict(run)
        kq = run.result or {}
        return {"answer": (kq.get("diagnosis") or {}).get("summary", ""),
                "session_id": kq.get("session_id")}

    def log_register(self, p: dict[str, Any]) -> dict[str, Any]:
        """`{path}` → `{}` — GEditor báo nó đang mở tệp log nào.

        Chỉ ghi nhận, không đọc tệp: hợp đồng ghi "GEditor tính stats native", nên phía Python
        không nên mở một tệp 1 GB chỉ để biết nó tồn tại. Đăng ký là để `debug.ask` sau đó nhận
        đường dẫn tương đối mà vẫn tra đúng tệp.
        """
        self._log_dang_mo = str(p.get("path", ""))
        return {}

    # ---- phương thức
    def hello(self, p: dict[str, Any]) -> dict[str, Any]:
        client = p.get("api_version", API_VERSION)
        if str(client).split(".")[0] != API_VERSION.split(".")[0]:
            raise EideError("E1002", f"Plugin API {client} không tương thích daemon {API_VERSION}")
        return {"daemon": __version__, "api_version": API_VERSION, "caps": len(get_registry().list()),
                "autonomy": self.gate.config.get("autonomy")}

    def caps_list(self, p: dict[str, Any]) -> dict[str, Any]:
        # `desc` và `ui` là thứ ô lệnh cần cho gợi ý "/" (UXD-13 U1 + §4 CommandBox: "tên + một
        # câu"). Không trả chúng thì plugin phải gọi `caps.describe` 238 lần để dựng một menu.
        return {"caps": [{"id": c.spec.id, "code": c.spec.code, "ns": c.spec.ns,
                          "risk": c.spec.risk_class, "tier": c.spec.tier_hieu_luc,
                          "desc": c.spec.desc, "ui": c.spec.man_hinh,
                          "implemented": c.implemented} for c in get_registry().list(p.get("ns"))]}

    def caps_describe(self, p: dict[str, Any]) -> dict[str, Any]:
        return get_registry().describe(p["id"])

    def caps_invoke(self, p: dict[str, Any]) -> dict[str, Any]:
        """Đường gọi duy nhất. Năng lực NẶNG trả `job_id` thay vì chờ (API-15 §1).

        Chỉ chạy nền khi daemon có kênh đẩy: không có `phat` thì panel không nghe được
        `event.job.progress`, và trả một `job_id` mà người gọi phải tự hỏi vòng là tệ hơn chờ.
        CLI và test gọi `handle()` trực tiếp vì thế vẫn đồng bộ như cũ.
        """
        if p["id"] in CAP_NANG and self.phat is not None:
            return self._chay_nen(p["id"], p.get("params", {}))
        run = self.router.invoke(p["id"], p.get("params", {}), self.ctx, p.get("features"))
        return asdict(run)

    def gate_decide(self, p: dict[str, Any]) -> dict[str, Any]:
        """API-15 §2 `{gate_id, decision: approve|reject, note?}` — UXD-13 U2 nút duyệt/từ chối."""
        # `ctx_goi_y` nói cho Router biết đọc store nào khi mục đến từ phiên daemon TRƯỚC —
        # thiếu nó thì daemon THẤY được mục cũ nhưng không duyệt được, một trạng thái tệ hơn cả
        # không thấy: người bấm nút và nhận E2000 cho một mục đang hiện ngay trước mắt.
        run = self.router.quyet_dinh(p["gate_id"], p["decision"], by="human",
                                     note=p.get("note", ""), ctx_goi_y=self.ctx)
        return asdict(run)

    def undo_list(self, p: dict[str, Any]) -> dict[str, Any]:
        return {"items": UndoService(self.ledger, self.gate.config).list()}

    def undo_apply(self, p: dict[str, Any]) -> dict[str, Any]:
        return self.router.hoan_tac(p["undo_ref"], by="human", ctx=self.ctx)

    def queue_list(self, p: dict[str, Any]) -> dict[str, Any]:
        """Mục chờ của dự án — gồm cả mục từ phiên daemon TRƯỚC (UXD-13 U2).

        Đọc từ store qua `cho_con_lai`, không từ `router.queue`: hàng đợi trong RAM chỉ biết
        phiên hiện tại, nên panel sẽ thấy rỗng sau mỗi lần khởi động lại daemon trong khi các
        mục vẫn nằm nguyên trong store — đúng thứ DEV-049 vừa sửa ở tầng dưới.
        """
        return {"items": self.router.cho_con_lai(self.ctx)}

    def budget_state(self, p: dict[str, Any]) -> dict[str, Any]:
        """Ngân sách token/chi phí — USECASE §4 mục 8, APD-08 §5 (leo thang khi còn < 20%).

        Ba con số, ba nguồn khác nhau, và nói rõ nguồn nào ra nguồn nào:

        - `daily_budget_usd` — hạn mức NGÀY, từ `models.yaml` `policy.daily_budget_usd`.
        - `spent_usd` — đã tiêu, cộng từ SỔ CÁI (`model.call.cost_usd`) trong ngày hôm nay.
        - `warn_pct` — ngưỡng cảnh báo, từ `defaults.yaml` `thresholds.budget_warn_pct` (20).

        Cộng từ sổ cái chứ không giữ một bộ đếm: bộ đếm sống trong tiến trình, mà một dự án có
        thể có nhiều tiến trình (giao diện, CLI, tác tử nền) cùng tiêu tiền. Sổ cái là chỗ duy
        nhất cả ba cùng ghi.
        """
        import yaml as _yaml

        han = 0.0
        if self.ctx.project_dir:
            f = Path(self.ctx.project_dir) / ".eide" / "models.yaml"
            if f.exists():
                try:
                    d = _yaml.safe_load(f.read_text(encoding="utf-8")) or {}
                    han = float(((d.get("policy") or {}).get("daily_budget_usd")) or 0)
                except (OSError, _yaml.YAMLError, TypeError, ValueError):
                    han = 0.0

        hom_nay = date.today()
        da_tieu, so_luot = 0.0, 0
        for r in self.ledger.records():
            if r.get("kind") != "model.call":
                continue
            if _ngay_dia_phuong(r.get("ts")) != hom_nay:
                continue
            so_luot += 1
            try:
                da_tieu += float((r.get("data") or {}).get("cost_usd") or 0)
            except (TypeError, ValueError):
                continue

        canh_bao = float(self.gate.config.get("thresholds", {}).get("budget_warn_pct") or 20)
        con_lai = max(0.0, han - da_tieu) if han > 0 else None
        return {
            "daily_budget_usd": han or None,
            "spent_usd": round(da_tieu, 6),
            "remaining_usd": None if con_lai is None else round(con_lai, 6),
            "calls_today": so_luot,
            "warn_pct": canh_bao,
            # `sap_het` chỉ có nghĩa khi CÓ hạn mức. None nghĩa là chưa biết, không phải "còn
            # nhiều" — và một cảnh báo ngân sách sai hướng thì hoặc làm người ta hoảng, hoặc
            # dạy người ta bỏ qua nó.
            "sap_het": None if han <= 0 else (con_lai or 0) < han * canh_bao / 100,
        }

    def autonomy_get(self, p: dict[str, Any]) -> dict[str, Any]:
        return {"autonomy": self.ctx.autonomy or self.gate.config.get("autonomy"), "stopped": self.gate.stopped}

    def autonomy_set(self, p: dict[str, Any]) -> dict[str, Any]:
        run = self.router.invoke("policy.set_autonomy", {"level": p["level"], "by": p.get("by", "human")}, self.ctx)
        return asdict(run)

    def stop(self, p: dict[str, Any]) -> dict[str, Any]:
        run = self.router.invoke("policy.emergency_stop", {}, self.ctx)
        return asdict(run)

    def project_list(self, p: dict[str, Any]) -> dict[str, Any]:
        run = self.router.invoke("project.list", p, self.ctx)
        return run.result or {"projects": []}

    # ---- khung JSON-RPC
    def handle(self, msg: dict[str, Any]) -> dict[str, Any]:
        rid = msg.get("id")
        try:
            name = msg["method"]
            if name not in self.methods:
                return _err(rid, -32601, f"Phương thức không có: {name}")
            # Chụp hàng đợi TRƯỚC khi chạy: một mục chờ có thể sinh ra ở giữa chuỗi, và so
            # trước/sau là cách duy nhất bắt được mọi đường sinh ra nó.
            cho_truoc = self._id_cho() if self.phat else []
            kq = self.methods[name](msg.get("params") or {})
            self._sau_loi_goi(name, kq)
            self._hang_doi_doi(cho_truoc)
            return {"jsonrpc": "2.0", "id": rid, "result": kq}
        except EideError as e:
            return {"jsonrpc": "2.0", "id": rid, "error": e.to_rpc()}
        except (KeyError, TypeError) as e:
            # Tham số thiếu/sai kiểu là E1000 INVALID_ARGS của API-15 §3, không phải một mã
            # JSON-RPC trần. Client (EIDEKit) tra `eide_code` để hiện CÁCH XỬ LÝ mà tài liệu
            # khuyến nghị; thiếu nó thì phía giao diện chỉ có một con số âm để đưa cho người dùng.
            return _err(rid, -32602, f"Tham số sai: {e}", eide_code="E1000")


def _err(rid: Any, code: int, message: str, eide_code: str | None = None) -> dict[str, Any]:
    err: dict[str, Any] = {"code": code, "message": message}
    if eide_code:
        err["data"] = {"eide_code": eide_code, "name": error_table()[eide_code]["name"]}
    return {"jsonrpc": "2.0", "id": rid, "error": err}


def serve_stdio(inp: TextIO, out: TextIO, project: Path | None = None) -> None:
    """Vòng lặp stdio. Thông báo `event.*` đi CÙNG ống dẫn với câu trả lời.

    JSON-RPC 2.0 phân biệt hai loại bằng trường `id`: câu trả lời có, thông báo không. Nên một
    ống dẫn là đủ, và đó là lý do kênh sự kiện không cần thêm socket hay cổng nào — điều quan
    trọng với một daemon chạy làm tiến trình con của editor.

    Thông báo phát ra TRONG lúc xử lý một lời gọi (sổ cái ghi giữa chừng) nên nó có thể xen vào
    trước câu trả lời của chính lời gọi ấy. Đúng như thế: panel thấy `event.run.progress` rồi
    mới thấy kết quả, và đó là thứ tự người dùng cần.
    """
    def phat(ten: str, p: dict[str, Any]) -> None:
        out.write(json.dumps({"jsonrpc": "2.0", "method": ten, "params": p},
                             ensure_ascii=False) + "\n")
        out.flush()

    d = Daemon(project, phat=phat)
    for line in inp:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            resp = _err(None, -32700, "JSON không hợp lệ")
        else:
            resp = d.handle(msg)
        out.write(json.dumps(resp, ensure_ascii=False) + "\n")
        out.flush()
