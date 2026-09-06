"""Orchestrator — nối bốn trách nhiệm của DPS-09 §2 thành một lượt. WI-005.

Spec: DPS-09 §2 (bốn trách nhiệm), §4.1–§4.3, §5 (kịch bản đầu vào trống); SDD-04 §4.6.

Orchestrator KHÔNG tự làm gì cả — nó chỉ gọi các năng lực `chat.*` qua Router, đúng thứ tự.
Điều đó không phải là hình thức: mọi bước vì thế đều đi qua PolicyGate và đều vào ledger, nên
tầng hiểu lệnh chịu cùng luật với phần còn lại của sản phẩm. Một Orchestrator tự gọi mô hình
hay tự đọc store sẽ là một đường vòng quanh cổng.

Sprint này làm ①③④; ② lập chuỗi (`chat.orchestrate`, CHAT-06) là mốc M2.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from eide_core.errors import EideError
from eide_core.router import Context, Router


@dataclass
class Orchestrator:
    router: Router
    ctx: Context

    def xu_ly(self, text: str, attachments: list[str] | None = None) -> dict[str, Any]:
        """Một lượt: hiểu → đối chiếu → mặc định → (hỏi lại nếu không hiểu) → báo cáo."""
        kq: dict[str, Any] = {"text": text}

        # ① hiểu
        run = self.router.invoke("chat.parse_intent",
                                 {"text": text, **({"attachments": attachments} if attachments else {})},
                                 self.ctx)
        if run.status != "done":
            return {**kq, "error": run.error, "intent": None}
        intent = run.result["intent"]
        kq["intent"] = intent

        # DPS-09 §4.1: không hiểu thì HỎI LẠI, không đoán rồi làm. Đây là chỗ dễ sai nhất của
        # một tác tử: đoán một ý định gần đúng rồi chạy còn tệ hơn thú nhận là chưa hiểu.
        if intent["intent"] == "unknown":
            hoi = self.router.invoke("chat.clarify", {
                "gaps": [{"slot": "intent",
                          "options": [{"label": "Tạo dự án mới", "value": "project.create"},
                                      {"label": "Mở dự án đã có", "value": "project.open"},
                                      {"label": "Hỏi về tri thức dự án", "value": "view.ask"}],
                          "default": 0}],
                "context": {"timeout_s": 0}}, self.ctx)
            kq["question"] = hoi.result["question"] if hoi.status == "done" else None
            return kq

        # ① đối chiếu — deterministic
        run = self.router.invoke("chat.ground", {"intent": intent}, self.ctx)
        kq["grounded"] = run.result["grounded"] if run.status == "done" else {}

        # ③ mặc định trước, hỏi sau
        run = self.router.invoke("chat.fill_defaults",
                                 {"intent": intent, "grounded": kq["grounded"]}, self.ctx)
        if run.status == "done":
            kq["intent"] = intent = run.result["intent"]
            kq["defaults_applied"] = run.result["applied"]

        # ④ báo cáo
        try:
            rp = self.router.invoke("chat.report_back", {"run_id": run.run_id}, self.ctx)
            kq["report"] = rp.result if rp.status == "done" else {"text": ""}
        except EideError as e:                     # báo cáo hỏng không được nuốt cả lượt
            kq["report"] = {"text": f"(không dựng được báo cáo: {e.code})"}
        return kq
