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

from eide_core.errors import EideError
from eide_core.paths import spec_dir

APPROVE, ASK, REJECT = "APPROVE", "ASK", "REJECT"
LEVELS = ["A0", "A1", "A2", "A3", "A4"]

# Tầng 2 — ngưỡng cứng (APD-08 §3, bảng "lớp rủi ro × mức tự chủ"): lớp rủi ro tối đa được tự APPROVE ở mỗi mức.
# R4 (không hoàn tác được: xóa flash, fuse, cơ cấu chấp hành, phát hành công khai) luôn ASK ở mọi mức.
MAX_AUTO_RISK = {"A0": -1, "A1": 1, "A2": 2, "A3": 3, "A4": 3}


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
    def __init__(self, rules_path: Path | None = None, config: dict[str, Any] | None = None) -> None:
        rules_path = rules_path or spec_dir() / "policy" / "rules.yaml"
        data = yaml.safe_load(rules_path.read_text(encoding="utf-8"))
        self.version = data.get("version")
        self.rules = sorted(data["rules"], key=lambda r: (r.get("priority", 50), r["id"]))
        for r in self.rules:
            r["_code"] = compile_rule(r["when"])
        defaults = yaml.safe_load((spec_dir() / "policy" / "defaults.yaml").read_text(encoding="utf-8"))
        self.config = {**defaults, **(config or {})}
        self.stopped = False  # dừng khẩn (APD-08 §5; API-15 `stop`)

    # ---- API chính
    def decide(self, gate: str, features: dict[str, Any], *, risk: str = "R1", autonomy: str | None = None,
               board: str | None = None, tier: str = "T2", actor: str = "agent") -> Decision:
        level = self._effective_level(autonomy, board)
        # Tầng 1 — dừng khẩn
        if self.stopped:
            return Decision(REJECT, "STOP", "Phiên đang dừng khẩn (E3002)", gate)
        # Tầng 2 — ngưỡng cứng lớp rủi ro × mức tự chủ
        r = int(risk[1]) if len(risk) > 1 and risk[1].isdigit() else 1
        if r >= 4:
            return Decision(ASK, "HARD-R4", "Hành động lớp R4 không hoàn tác được — luôn hỏi người", gate)
        if r > MAX_AUTO_RISK[level] and r > 0:
            return Decision(ASK, f"HARD-{level}", f"Lớp {risk} vượt mức tự chủ {level}", gate)
        # Tầng 3 + 4 — quy tắc theo cổng rồi quy tắc chung
        env = self._env(features, level, board)
        for scope in (gate, "*"):
            for rule in self.rules:
                if rule["gate"] != scope:
                    continue
                if _eval(rule["_code"], env):
                    return Decision(rule["decision"], rule["id"], rule.get("reason", ""), gate, features)
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
            "trusted_sources": cfg.get("trusted_sources", []),
            "trusted_packages": cfg.get("trusted_packages", []),
            "allowed_licenses": cfg.get("allowed_licenses", []),
            "board": _Ns({**binfo, **(features.get("board") or {})}),
        }
        for k, v in features.items():
            if k == "board":
                continue
            env[k] = _Ns(v) if isinstance(v, dict) else v
        return env
