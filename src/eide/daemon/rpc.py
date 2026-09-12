"""JSON-RPC 2.0 daemon — API-15 §1 (docs/spec/api/openrpc.json). Sprint 1: stdio, tập con phương thức.

Phương thức đã có: plane.hello, caps.list, caps.describe, caps.invoke, queue.list, autonomy.get, autonomy.set, stop,
project.list. Tên/tham số/kết quả bám openrpc.json; test_specs_consistency kiểm tra mọi tên đăng ký đều có trong spec.
"""
from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import asdict
from pathlib import Path
from typing import Any, TextIO

from eide import __version__
from eide_core.errors import EideError, error_table
from eide_core.ledger import Ledger
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
    "undo.register": "event.undo.registered",
    "undo.expire": "event.undo.expired",
    "autonomy.change": "event.autonomy.changed",
    "stop": "event.autonomy.changed",
    "store.write": "event.knowledge.changed",
    "acq.state": "event.knowledge.changed",
    "question": "event.chat.question",
    "answer": "event.chat.restated",
    "report": "event.chat.report",
    "error": "event.notice",
}

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


class Daemon:
    def __init__(self, project: Path | None = None,
                 phat: Callable[[str, dict[str, Any]], None] | None = None) -> None:
        self.gate = PolicyGate()
        self.ledger = Ledger((project / ".eide" / "store" / "ledger.jsonl") if project else user_log() / "ledger.jsonl")
        self.router = Router(gate=self.gate, ledger=self.ledger)
        self.ctx = Context(project_dir=project, extra={"gate": self.gate})
        # `phat` do lớp vận chuyển đưa vào (`serve_stdio`). Không có thì daemon chạy y như cũ —
        # CLI và test gọi `handle()` trực tiếp không cần kênh đẩy, và bắt chúng dựng một cái
        # giả chỉ để im lặng là thêm nghi thức không đổi lấy gì.
        self.phat = phat
        if phat is not None:
            self.ledger.theo_doi(self._tu_so_cai)
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
            "project.close": self.project_close,
            "diagram.open": self.diagram_open, "diagram.save": self.diagram_save,
            "doc.open": self.doc_open, "hex.resolve": self.hex_resolve,
            "chat.send": self.chat_send, "chat.answer": self.chat_answer,
            "chat.history": self.chat_history, "debug.ask": self.debug_ask,
            "log.register": self.log_register,
        }

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
        ten = SU_KIEN.get(rec.get("kind", ""))
        if ten is None or self.phat is None:
            return
        d = dict(rec.get("data") or {})
        # `gate.decision` chỉ thành `event.gate.opened` khi nó THẬT SỰ mở một mục chờ. Một quyết
        # định APPROVE là việc máy tự làm xong; báo nó như "có mục cần anh duyệt" sẽ dạy người
        # dùng bỏ qua thông báo — đúng thứ hỏng mà cả POL-17 lo.
        if rec["kind"] == "gate.decision" and d.get("decision") != "ASK":
            return
        self.phat(ten, {**d, "at": rec.get("ts"), "seq": rec.get("seq")})

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
