"""PolicyGate — quyết định APPROVE / ASK / REJECT theo docs/spec/policy/rules.yaml.

Spec: EIDE-APD-08 §2–§5 (mức A0–A4, lớp R0–R4, cổng, dừng khẩn), EIDE-POL-17 §2 (cú pháp quy tắc: biểu thức
Python an toàn chỉ gồm so sánh/logic/in; ưu tiên nhỏ xét trước; quy tắc đầu tiên khớp thắng), §5 (autonomy.yaml).
Bốn tầng quyết định (APD-08 §4.1): (1) dừng khẩn → REJECT/ASK; (2) ngưỡng cứng theo lớp rủi ro và mức tự chủ;
(3) quy tắc theo cổng; (4) quy tắc chung `*` (GEN-*); mặc định ASK.
Tình huống kiểm thử: docs/spec/policy/situations.jsonl (tests/test_policy.py).
"""
from __future__ import annotations

import ast
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from eide_core import whitelist
from eide_core.errors import EideError
from eide_core.paths import spec_dir

APPROVE, ASK, REJECT = "APPROVE", "ASK", "REJECT"
LEVELS = ["A0", "A1", "A2", "A3", "A4"]

# Tầng 2 — ngưỡng cứng (APD-08 §3, bảng "lớp rủi ro × mức tự chủ"): lớp rủi ro tối đa được tự APPROVE ở mỗi mức.
# R4 (không hoàn tác được: xóa flash, fuse, cơ cấu chấp hành, phát hành công khai) luôn ASK ở mọi mức.
MAX_AUTO_RISK = {"A0": -1, "A1": 1, "A2": 2, "A3": 3, "A4": 3}

# Dải "chặn" của rules.yaml: các quy tắc priority <= 5 nói vì sao chính hành động này nguy hiểm
# (hash lệch, không hoàn tác, hằng số không nguồn, dự án nhạy cảm). Quy tắc ưu tiên lớn hơn là
# lời khuyên chung. Ngưỡng cứng chỉ mượn lý do từ dải này — xem `decide` tầng 2, DEVIATIONS DEV-012.
PRI_CHAN = 5

# Ba khóa danh sách trắng được NIÊM trong `defaults.sig` (POL-17 §3). Một quy tắc nhắc tới một
# trong ba là một quy tắc "chủ sản phẩm đã ký trước cho việc này".
KHOA_DANH_SACH = ("trusted_packages", "trusted_sources", "allowed_licenses")


def _dua_tren_danh_sach(rule: dict[str, Any]) -> bool:
    """Quy tắc có dựa trên danh sách trắng đã ký không — ĐỌC TỪ `when`, không liệt kê tay.

    Liệt kê `{"G-OPS-04"}` thì thêm một quy tắc danh-sách-trắng mới vào POL-17 sẽ lặng lẽ không
    có tác dụng, và không ai biết cho tới lúc cần. Đọc từ điều kiện thì bảng quy tắc vẫn là
    nguồn duy nhất.
    """
    return any(k in str(rule.get("when", "")) for k in KHOA_DANH_SACH)



@dataclass
class Decision:
    decision: str
    rule_id: str
    reason: str
    gate: str
    features: dict[str, Any] = field(default_factory=dict)

    @property
    def approved(self) -> bool:
        return self.decision == APPROVE


class _Ns:
    """Đối tượng thuộc tính từ dict; thuộc tính thiếu trả None (đặc trưng chưa biết ⇒ không khớp APPROVE)."""

    def __init__(self, d: dict[str, Any] | None) -> None:
        self._d = d or {}

    def __getattr__(self, k: str) -> Any:
        v = self._d.get(k)
        return _Ns(v) if isinstance(v, dict) else v

    def __bool__(self) -> bool:
        """Đặc trưng chưa biết là SAI, kể cả khi nó xuất hiện dưới dạng tên trần.

        Thiếu hàm này thì `_Ns` mang tính đúng mặc định của object, và hai cách viết cùng một ý
        lại cho hai kết quả ngược nhau: `board.has_actuator` thiếu ⇒ None ⇒ sai, còn `needs_sudo`
        thiếu ⇒ `_Ns({})` ⇒ ĐÚNG. Docstring của lớp này vẫn nói "đặc trưng chưa biết ⇒ không
        khớp APPROVE", nên nhánh tên trần đang làm ngược điều nó tự hứa.

        Hậu quả đo được: `needs_sudo` không ai cung cấp làm G-OPS-05 (ưu tiên 5, ASK) luôn khớp,
        che mất G-OPS-04 (ưu tiên 10, APPROVE) — không gói nào trong `trusted_packages` được
        duyệt tự động, và bảng quy tắc nói một đằng động cơ làm một nẻo. Xem DEVIATIONS DEV-033.
        """
        return bool(self._d)

    def __repr__(self) -> str:
        return f"_Ns({self._d})"


_ALLOWED = (
    ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.Not, ast.UnaryOp, ast.Compare, ast.Name, ast.Attribute,
    ast.Constant, ast.List, ast.Tuple, ast.Load, ast.Eq, ast.NotEq, ast.Lt, ast.LtE, ast.Gt, ast.GtE, ast.In,
    ast.NotIn, ast.Is, ast.IsNot, ast.USub,
)


def compile_rule(expr: str) -> Any:
    """Biên dịch biểu thức an toàn (POL-17 §2): chỉ so sánh, logic, in, hằng, thuộc tính. Không gọi hàm."""
    tree = ast.parse(expr, mode="eval")
    for node in ast.walk(tree):
        if not isinstance(node, _ALLOWED):
            raise ValueError(f"Quy tắc dùng cú pháp không cho phép: {type(node).__name__} trong {expr!r}")
    return compile(tree, "<rule>", "eval")



class _Env(dict):
    """Tên chưa được cung cấp (ví dụ `plan` khi đang ở cổng G-SRC) → đối tượng rỗng: mọi thuộc tính None."""

    def __missing__(self, k: str) -> Any:
        return _Ns({})


def _eval(code: Any, env: dict[str, Any]) -> bool:
    try:
        return bool(eval(code, {"__builtins__": {}}, _Env(env)))  # noqa: S307 — AST đã kiểm, không có builtins
    except (TypeError, AttributeError):
        return False


class PolicyGate:
    def __init__(self, rules_path: Path | None = None, config: dict[str, Any] | None = None,
                 *, sig_path: Path | None = None, ledger: Any = None) -> None:
        rules_path = rules_path or spec_dir() / "policy" / "rules.yaml"
        data = yaml.safe_load(rules_path.read_text(encoding="utf-8"))
        self.version = data.get("version")
        self.rules = sorted(data["rules"], key=lambda r: (r.get("priority", 50), r["id"]))
        for r in self.rules:
            r["_code"] = compile_rule(r["when"])
        defaults = yaml.safe_load((spec_dir() / "policy" / "defaults.yaml").read_text(encoding="utf-8"))
        self.config = {**defaults, **(config or {})}
        self.stopped = False  # dừng khẩn (APD-08 §5; API-15 `stop`)
        # POL-17 §3: "PolicyGate từ chối nạp danh sách có băm không khớp chữ ký". Niêm phủ cấu
        # hình SAU hợp nhất — xem whitelist.py về lý do.
        sig_path = sig_path or spec_dir() / "policy" / "defaults.sig"
        self.danh_sach_da_ky, self.ly_do_chua_ky = whitelist.kiem(self.config, sig_path, ledger)

    # ---- API chính
    def decide(self, gate: str, features: dict[str, Any], *, risk: str = "R1", autonomy: str | None = None,
               board: str | None = None, tier: str = "T2", actor: str = "agent") -> Decision:
        level = self._effective_level(autonomy, board)
        # Tầng 1 — dừng khẩn
        if self.stopped:
            return Decision(REJECT, "STOP", "Phiên đang dừng khẩn (E3002)", gate)
        # Tầng 2 — ngưỡng cứng lớp rủi ro × mức tự chủ
        #
        # Ngưỡng cứng ép ASK, nhưng vẫn tra quy tắc cổng TRƯỚC để lấy lý do cụ thể. Không có
        # bước ấy thì `G-OPS-02` ("Không hoàn tác") và `G5-02` ("Công khai") là quy tắc chết —
        # mọi R4 đều bị nuốt thành một dòng "HARD-R4" trong decision_log, và người duyệt chỉ
        # đọc được lớp rủi ro chứ không đọc được ĐIỀU GÌ sắp xảy ra. Xem DEVIATIONS DEV-012.
        #
        # Quy tắc cổng chỉ được phép SIẾT ở đây, không được nới: một quy tắc APPROVE gặp ngưỡng
        # cứng vẫn ra ASK. REJECT thì mạnh hơn ASK nên được giữ nguyên.
        env = self._env(features, level, board)
        r = int(risk[1]) if len(risk) > 1 and risk[1].isdigit() else 1
        khop = self._match(gate, env)

        # DANH SÁCH TRẮNG ĐÃ KÝ là lối duy nhất cho một hành động R4 — chữ của POL-17 §2, trong
        # chính mã giả của nó: `MIN_LEVEL = {…, "R4": 5}  # R4: không mức nào đủ (chỉ whitelist)`.
        # CDS-12.3 nói cùng điều ở cột lớp rủi ro của ENV-03: "R4→T1 theo danh sách trắng", và
        # POL-17 §8 S33 ("A3; install renode (trusted)" → APPROVE G-OPS-04) là tình huống nghiệm
        # thu của đúng lối ấy.
        #
        # Trước 08/09/2026 hiện thực không có lối này: mọi R4 đều ASK, nên `G-OPS-04` là quy tắc
        # chết và S33 không thể xảy ra với một năng lực R4 nào. Xem DEV-060.
        #
        # Ba điều kiện, hẹp có chủ ý:
        #   (1) quy tắc khớp là APPROVE — không phải mọi quy tắc, chỉ quy tắc nói "được phép";
        #   (2) điều kiện của nó DỰA TRÊN một danh sách trắng (đọc từ `when`, không liệt kê tay);
        #   (3) niêm `defaults.sig` còn đạt — chữ ký của chủ sản phẩm chính là lần hỏi người.
        #
        # Điều kiện (3) là DƯ, và nói ra chỗ dư ấy: niêm hỏng thì `_env` bỏ hẳn ba khóa danh sách,
        # nên `package in trusted_packages` ném TypeError và quy tắc không khớp — lối này đã đóng
        # trước khi tới đây. Giữ lại vì nó là bất biến quan trọng nhất của cả nhánh, và một lớp
        # bảo vệ viết ra rõ ràng thì không hỏng lặng lẽ khi `_env` đổi cách xử lý niêm.
        #
        # Hạ xuống R2 chứ không hạ thẳng thành APPROVE: mức tự chủ vẫn phải đủ. Ở A1 thì R2 vẫn
        # vượt mức và vẫn hỏi — đúng như `test_ngưỡng_cứng` của POL-17 đòi.
        if r >= 4 and self.danh_sach_da_ky and khop and khop["decision"] == APPROVE \
                and _dua_tren_danh_sach(khop):
            r = 2

        cung = None
        if r >= 4:
            cung = ("HARD-R4", "Hành động lớp R4 không hoàn tác được — luôn hỏi người")
        elif r > MAX_AUTO_RISK[level] and r > 0:
            cung = (f"HARD-{level}", f"Lớp {risk} vượt mức tự chủ {level}")
        if cung:
            # Chỉ mượn lý do của quy tắc NÓI VỀ CHÍNH HÀNH ĐỘNG NÀY. Quy tắc trong dải chặn
            # (priority <= PRI_CHAN) mô tả vì sao hành động này nguy hiểm — "Không hoàn tác",
            # "Công khai", "Hằng số không nguồn". Quy tắc ưu tiên lớn hơn là lời khuyên chung
            # ("board chưa đánh dấu lab") và dùng nó làm lý do cho một hành động R4 là nói
            # nhỏ đi mức nghiêm trọng thật.
            if khop and khop.get("priority", 50) <= PRI_CHAN and khop["decision"] in (ASK, REJECT):
                return Decision(khop["decision"], khop["id"], khop.get("reason", ""), gate, features)
            return Decision(ASK, cung[0], cung[1], gate)
        # Tầng 2, nhánh còn lại — APD-08 §4.1 và POL-17 §1 hàng T2: "R0 → APPROVE(R0) (bỏ qua
        # tầng sau)". R0 là lớp CHỈ ĐỌC: không ghi, không chạm phần cứng, không phát ra ngoài.
        #
        # Thiếu nhánh này thì mọi năng lực R0 nằm sau một cổng thật đều rơi xuống quy tắc bắt
        # hết của cổng — vốn luôn là ASK. Đo 07/09/2026: **43 năng lực R0** ở bảy cổng đều bị
        # hỏi người, gồm cả `kg.build` và `search.rank`. Lỗi nằm im tới giờ vì mọi năng lực đã
        # hiện thực trước đó đều gắn cổng `*`, nơi tầng 5 trả APPROVE cho T1. Xem DEV-040.
        #
        # NHƯNG không "bỏ qua tầng sau" theo nghĩa đen, vì hai lẽ.
        #
        # (a) Quy tắc trong DẢI CHẶN (priority ≤ 5) vẫn thắng, kể cả khi nó chỉ ASK. Hai ví dụ
        #     cụ thể: `TOOL-03` chặn công cụ chưa test — mà lớp rủi ro của một công cụ tác tử tự
        #     viết được SUY TỪ HIỆU ỨNG NÓ KHAI BÁO, và `effects_ok` tồn tại đúng vì khai báo ấy
        #     có thể sai, nên cho R0 vượt qua là tin lời khai của chính thứ đang bị nghi. Và
        #     `G-SRC-07` hỏi khi một dự án NHẠY CẢM dùng nguồn đòi gửi dữ liệu ra ngoài — vài
        #     năng lực `search.*` mang nhãn R0 vì chúng chỉ đọc, nhưng "chỉ đọc" ở đây là đọc từ
        #     một dịch vụ bên ngoài. Cùng nguyên tắc với DEV-012: dải chặn chỉ siết, không nới.
        #
        # (b) Quy tắc APPROVE khớp thì MƯỢN mã và lý do của nó. Trả về mã chung "R0" khi
        #     `TOOL-01` vừa khớp sẽ biến TOOL-01 thành quy tắc chết và decision_log mất câu giải
        #     thích — đúng khuôn hỏng mà DEV-012 mô tả, chỉ đổi chỗ.
        if r == 0:
            khop = self._match(gate, env)
            if khop and khop.get("priority", 50) <= PRI_CHAN and khop["decision"] in (ASK, REJECT):
                return Decision(khop["decision"], khop["id"], khop.get("reason", ""), gate, features)
            if khop and khop["decision"] == APPROVE:
                return Decision(APPROVE, khop["id"], self._ly_do(khop), gate, features)
            return Decision(APPROVE, "R0", "Lớp R0 chỉ đọc — tự làm (APD-08 §4.1 tầng 2)", gate, features)
        # Tầng 3 + 4 — quy tắc theo cổng rồi quy tắc chung
        khop = self._match(gate, env)
        if khop:
            return Decision(khop["decision"], khop["id"], self._ly_do(khop), gate, features)
        # Tầng 5 — mức năng lực (APD-08 §4.1, Danh mục cột "Mức"): T1/T1* tự làm (T1* làm rồi báo cáo) trong
        # phạm vi lớp rủi ro đã qua tầng 2; T2 cần người duyệt; T3 người làm.
        if actor == "human":
            return Decision(APPROVE, "HUMAN", "Người gọi trực tiếp — chính là quyết định của người (APD-08 §1)", gate)
        if tier in ("T1", "T1*"):
            return Decision(APPROVE, f"TIER-{tier}", "Năng lực mức T1: tự làm trong mức tự chủ hiện tại", gate)
        return Decision(ASK, "DEFAULT", f"Năng lực mức {tier} — mặc định hỏi người", gate)

    def stop(self) -> None:
        self.stopped = True

    def resume(self) -> None:
        self.stopped = False

    def raise_if_blocked(self, d: Decision) -> None:
        """Chuyển quyết định thành lỗi API-15: E3000 (ASK, không phải lỗi thật), E3001 (REJECT), E3002 (STOP)."""
        if d.rule_id == "STOP":
            raise EideError("E3002", d.reason, rule=d.rule_id)
        if d.decision == REJECT:
            raise EideError("E3001", d.reason, rule=d.rule_id)
        if d.decision == ASK:
            raise EideError("E3000", d.reason, rule=d.rule_id, gate=d.gate)

    # ---- nội bộ
    def _ly_do(self, rule: dict[str, Any]) -> str:
        """Nói ra khi cổng đang chạy THIẾU danh sách trắng — POL-17 §3.

        Niêm không đạt thì ba danh sách bị bỏ khỏi biểu thức, nên các quy tắc dựa vào chúng
        không khớp và lời gọi rơi xuống quy tắc bắt hết của cổng. Lý do ghi vào decision_log khi
        ấy là "Mặc định: nguồn ngoài danh sách tin cậy" — đúng chữ nhưng sai nguyên nhân: nguồn
        có thể đang nằm trong danh sách, chỉ là danh sách không được nạp. Người đọc nhật ký sẽ
        đi thêm tên miền vào một tệp đằng nào cũng không được đọc.
        """
        ly_do = rule.get("reason", "")
        if not self.danh_sach_da_ky and rule.get("when") == "True":
            return f"{ly_do} — lưu ý: {self.ly_do_chua_ky}"
        return ly_do

    def _match(self, gate: str, env: dict[str, Any]) -> dict[str, Any] | None:
        """Quy tắc đầu tiên khớp, xét cổng trước rồi quy tắc chung `*` (POL-17 §2)."""
        for scope in (gate, "*"):
            for rule in self.rules:
                if rule["gate"] == scope and _eval(rule["_code"], env):
                    return rule
        return None

    def _effective_level(self, autonomy: str | None, board: str | None) -> str:
        level = autonomy or self.config.get("autonomy", "A3")
        boards = self.config.get("boards") or {}
        if board and board in boards and boards[board].get("autonomy"):
            b = boards[board]["autonomy"]
            level = min(level, b, key=LEVELS.index)  # ghi đè theo board chỉ hạ mức (APD-08 §2)
        if level not in LEVELS:
            raise EideError("E1000", f"Mức tự chủ không hợp lệ: {level}")
        return level

    def _env(self, features: dict[str, Any], level: str, board: str | None) -> dict[str, Any]:
        cfg = self.config
        boards = cfg.get("boards") or {}
        binfo = dict(boards.get(board, {})) if board else {}
        env: dict[str, Any] = {
            "True": True, "False": False, "None": None,
            "autonomy": level, "level": LEVELS.index(level),
            "thresholds": _Ns(cfg.get("thresholds")),
            "board": _Ns({**binfo, **(features.get("board") or {})}),
        }
        # Niêm không đạt ⇒ BỎ HẲN ba khóa, không nạp danh sách rỗng. `_Env.__missing__` trả
        # `_Ns({})`, `x in _Ns({})` ném TypeError, `_eval` bắt TypeError ⇒ quy tắc không khớp ⇒
        # rơi xuống quy tắc mặc định của cổng ⇒ ASK.
        #
        # Nạp rỗng cũng ra ASK, nhưng ra vì lý do SAI: `license in []` là False nên G-SRC-05
        # bắt trước và ghi vào decision_log "License không rõ/không cho phép", trong khi license
        # hoàn toàn hợp lệ và thứ hỏng là chữ ký. Người duyệt đọc dòng đó rồi đi sửa nhầm chỗ.
        if self.danh_sach_da_ky:
            for k in ("trusted_sources", "trusted_packages", "allowed_licenses"):
                env[k] = cfg.get(k, [])
        for k, v in features.items():
            if k == "board":
                continue
            env[k] = _Ns(v) if isinstance(v, dict) else v
        return env
