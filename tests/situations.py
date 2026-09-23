"""Bảng dịch 45 tình huống của `docs/spec/policy/situations.jsonl` thành lời gọi PolicyGate.

`situations.jsonl` mô tả tình huống bằng VĂN XUÔI ("A3; st.com; svd; 2 MB; license MIT; hash
khớp"), còn `rules.yaml` đọc các đặc trưng có tên. Muốn "chạy đủ 45 tình huống" như STP-05
TC-51 đòi thì phải có một bản dịch giữa hai bên, và bản dịch ấy là tệp này.

QUY TẮC DỊCH — chỗ nào văn xuôi im lặng thì điền GIÁ TRỊ LÀNH:
  license không nêu  → một license trong allowed_licenses
  hash không nêu     → khớp
  kích thước không nêu → dưới ngưỡng
Vì tình huống chỉ liệt kê thứ ĐÁNG CHÚ Ý; thứ không nêu là thứ bình thường. Điền giá trị dữ
sẽ làm một quy tắc khác nổ trước và test hóa ra kiểm nhầm quy tắc.

Hệ quả phải nói ra: đặc trưng nào không tình huống nào nêu thì không được kiểm ở đây —
`test_policy_situations.py::test_bao_cao_quy_tac_khong_duoc_tinh_huong_nao_cham` in ra danh
sách ấy để khoảng trống không nằm im.
"""
from __future__ import annotations

# Mỗi mục: id → (gate, features, kwargs cho decide)
# kwargs: risk (lớp rủi ro của hành động), autonomy, board, tier, actor
SITUATIONS: dict[str, tuple[str, dict, dict]] = {

    # ---------- G-SRC: nhận nguồn ----------
    "S01": ("G-SRC", {"source": {"domain": "st.com", "kind": "svd", "size_mb": 2,
                                 "license": "MIT", "hash_match": True}},
            {"risk": "R1", "autonomy": "A3"}),

    "S02": ("G-SRC", {"source": {"domain": "forum.st.com", "kind": "pdf", "size_mb": 1,
                                 "license": "vendor-doc", "hash_match": True}},
            {"risk": "R1", "autonomy": "A3"}),

    "S03": ("G-SRC", {"source": {"domain": "st.com", "kind": "pdf_vendor", "size_mb": 80,
                                 "license": "vendor-doc", "hash_match": True}},
            {"risk": "R1", "autonomy": "A3"}),

    "S04": ("G-SRC", {"source": {"kind": "registry", "signature_valid": True,
                                 "license": "Apache-2.0", "size_mb": 3, "hash_match": True}},
            {"risk": "R1", "autonomy": "A1"}),

    "S05": ("G-SRC", {"source": {"domain": "st.com", "kind": "svd", "size_mb": 1, "license": "MIT",
                                 "hash_match": False, "expected_hash": "9f2c...a1"}},
            {"risk": "R1", "autonomy": "A3"}),

    # match_score 0,4 < source_match_min 0,7
    "S06": ("G-SRC", {"source": {"domain": "bosch-sensortec.com", "kind": "pdf_vendor", "size_mb": 4,
                                 "license": "vendor-doc", "hash_match": True, "match_score": 0.4}},
            {"risk": "R1", "autonomy": "A3"}),

    "S07": ("G-SRC", {"project": {"sensitive": True},
                      "source": {"domain": "docs.mcp.local", "kind": "pdf", "size_mb": 2,
                                 "license": "MIT", "hash_match": True, "requires_upload": True}},
            {"risk": "R1", "autonomy": "A3"}),

    # A0 = không tự làm gì; chặn ở tầng ngưỡng cứng trước khi tới quy tắc cổng
    "S08": ("G-SRC", {"source": {"domain": "st.com", "kind": "svd", "size_mb": 1,
                                 "license": "MIT", "hash_match": True}},
            {"risk": "R1", "autonomy": "A0"}),

    # ---------- G-FACT: nhận fact ----------
    "S09": ("G-FACT", {"fact": {"tier": "gold"}}, {"risk": "R1", "autonomy": "A3"}),

    "S10": ("G-FACT", {"fact": {"tier": "silver", "confidence": 0.9, "second_source": True,
                                "conflict": False, "method": "parser", "predicate": "gpio_count"}},
            {"risk": "R1", "autonomy": "A3"}),

    "S11": ("G-FACT", {"fact": {"tier": "silver", "confidence": 0.8, "second_source": True,
                                "conflict": False, "method": "parser", "predicate": "gpio_count"}},
            {"risk": "R1", "autonomy": "A3"}),

    "S12": ("G-FACT", {"fact": {"tier": "silver", "confidence": 0.95, "second_source": True,
                                "conflict": True, "method": "parser", "predicate": "gpio_count"}},
            {"risk": "R1", "autonomy": "A3"}),

    "S13": ("G-FACT", {"fact": {"tier": "silver", "confidence": 0.95, "second_source": True,
                                "conflict": False, "method": "vision_llm", "predicate": "gpio_count"}},
            {"risk": "R1", "autonomy": "A3"}),

    "S14": ("G-FACT", {"fact": {"tier": "silver", "confidence": 0.9, "second_source": False,
                                "conflict": False, "method": "parser", "predicate": "timing"}},
            {"risk": "R1", "autonomy": "A3"}),

    "S15": ("G-FACT", {"fact": {"tier": "silver", "confidence": 0.9, "second_source": True,
                                "conflict": False, "method": "parser", "predicate": "timing"}},
            {"risk": "R1", "autonomy": "A3"}),

    "S16": ("G-FACT", {"fact": {"tier": "bronze"}}, {"risk": "R1", "autonomy": "A3"}),

    "S17": ("G-FACT", {"fact": {"tier": "gold"}}, {"risk": "R1", "autonomy": "A1"}),

    # ---------- G1: duyệt kế hoạch ----------
    "S18": ("G1", {"plan": {"steps": 6, "all_cited": True, "new_resources": False,
                            "touches_forbidden": False, "est_cost_usd": 0.3,
                            "missing": [], "arch_change": False},
                   "feature": {"needs_review": False}},
            {"risk": "R2", "autonomy": "A3"}),

    "S19": ("G1", {"plan": {"steps": 14, "all_cited": True, "new_resources": False,
                            "touches_forbidden": False, "est_cost_usd": 0.3,
                            "missing": [], "arch_change": False},
                   "feature": {"needs_review": False}},
            {"risk": "R2", "autonomy": "A3"}),

    "S20": ("G1", {"plan": {"steps": 6, "all_cited": True, "new_resources": False,
                            "touches_forbidden": False, "est_cost_usd": 0.3,
                            "missing": ["I2C timing"], "arch_change": False},
                   "feature": {"needs_review": False}},
            {"risk": "R2", "autonomy": "A3"}),

    "S21": ("G1", {"plan": {"steps": 6, "all_cited": True, "new_resources": False,
                            "touches_forbidden": False, "est_cost_usd": 0.3,
                            "missing": [], "arch_change": True},
                   "feature": {"needs_review": False}},
            {"risk": "R2", "autonomy": "A3"}),

    # R2 vượt mức tự chủ A1 → chặn ở ngưỡng cứng
    "S22": ("G1", {"plan": {"steps": 6, "all_cited": True, "new_resources": False,
                            "touches_forbidden": False, "est_cost_usd": 0.3,
                            "missing": [], "arch_change": False},
                   "feature": {"needs_review": False}},
            {"risk": "R2", "autonomy": "A1"}),

    # ---------- G3: gộp mã ----------
    "S23": ("G3", {"patch": {"tools_passed": 4, "constant_guard_violations": 0, "in_scope": True,
                             "size_growth_pct": 2, "touches_isr_linker": False},
                   "review": {"verdict": "PASS", "max_severity": "minor"},
                   "reviewer": {"vendor": "anthropic"}, "coder": {"vendor": "google"}},
            {"risk": "R2", "autonomy": "A3"}),

    "S24": ("G3", {"patch": {"tools_passed": 4, "constant_guard_violations": 0, "in_scope": True,
                             "size_growth_pct": 2, "touches_isr_linker": False},
                   "review": {"verdict": "PASS", "max_severity": "major"},
                   "reviewer": {"vendor": "anthropic"}, "coder": {"vendor": "google"}},
            {"risk": "R2", "autonomy": "A3"}),

    "S25": ("G3", {"patch": {"tools_passed": 4, "constant_guard_violations": 2, "in_scope": True,
                             "size_growth_pct": 2, "touches_isr_linker": False},
                   "review": {"verdict": "PASS", "max_severity": "minor"},
                   "reviewer": {"vendor": "anthropic"}, "coder": {"vendor": "google"}},
            {"risk": "R2", "autonomy": "A3"}),

    "S26": ("G3", {"patch": {"tools_passed": 4, "constant_guard_violations": 0, "in_scope": True,
                             "size_growth_pct": 2, "touches_isr_linker": False},
                   "review": {"verdict": "PASS", "max_severity": "minor"},
                   "reviewer": {"vendor": "google"}, "coder": {"vendor": "google"}},
            {"risk": "R2", "autonomy": "A3"}),

    "S27": ("G3", {"patch": {"tools_passed": 4, "constant_guard_violations": 0, "in_scope": True,
                             "size_growth_pct": 2, "touches_isr_linker": True},
                   "review": {"verdict": "PASS", "max_severity": "minor"},
                   "reviewer": {"vendor": "anthropic"}, "coder": {"vendor": "google"}},
            {"risk": "R2", "autonomy": "A3"}),

    "S28": ("G3", {"patch": {"tools_passed": 4, "constant_guard_violations": 0, "in_scope": True,
                             "size_growth_pct": 8, "touches_isr_linker": False},
                   "review": {"verdict": "PASS", "max_severity": "minor"},
                   "reviewer": {"vendor": "anthropic"}, "coder": {"vendor": "google"}},
            {"risk": "R2", "autonomy": "A3"}),

    # ---------- G-OPS: chạm phần cứng ----------
    "S29": ("G-OPS", {"op": "flash", "board": {"lab": True, "has_actuator": False, "flash_count_hour": 3},
                      "artifact": {"passed_g3": True, "hash_match": True}},
            {"risk": "R3", "autonomy": "A3"}),

    "S30": ("G-OPS", {"op": "flash", "board": {"lab": False, "has_actuator": False, "flash_count_hour": 0},
                      "artifact": {"passed_g3": True, "hash_match": True}},
            {"risk": "R3", "autonomy": "A3"}),

    "S31": ("G-OPS", {"op": "erase_all", "board": {"lab": True, "has_actuator": False, "flash_count_hour": 0}},
            {"risk": "R4", "autonomy": "A4"}),

    "S32": ("G-OPS", {"op": "flash", "board": {"lab": True, "has_actuator": True, "flash_count_hour": 1},
                      "artifact": {"passed_g3": True, "hash_match": True}},
            {"risk": "R3", "autonomy": "A3"}),

    "S33": ("G-OPS", {"op": "install", "package": "renode", "needs_sudo": False},
            {"risk": "R2", "autonomy": "A3"}),

    "S34": ("G-OPS", {"op": "install", "package": "mot-goi-la", "needs_sudo": True},
            {"risk": "R2", "autonomy": "A3"}),

    "S35": ("G-OPS", {"op": "flash", "board": {"lab": True, "has_actuator": False, "flash_count_hour": 21},
                      "artifact": {"passed_g3": True, "hash_match": True}},
            {"risk": "R3", "autonomy": "A3"}),

    # ---------- G4: nghiệm thu ----------
    "S36": ("G4", {"expect": {"machine_observable": True, "all_passed": True}},
            {"risk": "R1", "autonomy": "A3"}),

    "S37": ("G4", {"expect": {"machine_observable": False, "all_passed": False}},
            {"risk": "R1", "autonomy": "A3"}),

    # ---------- G5: phát hành ----------
    "S38": ("G5", {"publish": {"scope": "internal"},
                   "pkg": {"auto_verified": True, "bench_bc": 0.93, "license_ok": True,
                           "contains_project_knowledge": False}},
            {"risk": "R2", "autonomy": "A4"}),

    "S39": ("G5", {"publish": {"scope": "public"},
                   "pkg": {"auto_verified": True, "bench_bc": 0.93, "license_ok": True,
                           "contains_project_knowledge": False}},
            {"risk": "R4", "autonomy": "A4"}),

    # ---------- dừng khẩn ----------
    "S40": ("*", {}, {"risk": "R0", "autonomy": "A3", "stopped": True}),

    # ---------- G-TOOL: công cụ tự viết ----------
    "S41": ("G-TOOL", {"tool": {"tested": True, "effects_ok": True, "risk": "R0",
                                "effects": ["read_fs"], "last_fail_count": 0, "uses_ok": 0}},
            {"risk": "R0", "autonomy": "A3"}),

    "S42": ("G-TOOL", {"tool": {"tested": False, "effects_ok": True, "risk": "R1",
                                "effects": ["read_fs"], "last_fail_count": 0, "uses_ok": 0}},
            {"risk": "R1", "autonomy": "A3"}),

    "S43": ("G-TOOL", {"tool": {"tested": True, "effects_ok": True, "risk": "R1",
                                "effects": ["write_project"], "last_fail_count": 0, "uses_ok": 0}},
            {"risk": "R1", "autonomy": "A3"}),

    "S44": ("G-TOOL", {"tool": {"tested": True, "effects_ok": True, "risk": "R3",
                                "effects": ["hardware"], "last_fail_count": 0, "uses_ok": 1},
                       "board": {"lab": True}},
            {"risk": "R3", "autonomy": "A3"}),

    "S45": ("G-TOOL", {"tool": {"tested": True, "effects_ok": True, "risk": "R2",
                                "effects": ["system"], "last_fail_count": 0, "uses_ok": 0}},
            {"risk": "R2", "autonomy": "A4"}),

    # G-WL — cổng danh sách trắng (POL-17 §3, thêm ở v1.2).
    #
    # `risk="R2"` chứ không phải R4 dù §3 gọi đổi danh sách là "hành động R4": ba tình huống này
    # kiểm CHÍNH bảng quy tắc §2, và ở R4 thì ngưỡng cứng tầng T2 trả lời trước khi cổng được
    # hỏi tới — S46 sẽ ra `ASK HARD-R4` và không quy tắc G-WL nào được chạm. Lớp rủi ro thật của
    # hành động do registry gắn, không do fixture này quyết; xem DEV-012 về quan hệ giữa hai tầng.
    "S46": ("G-WL", {"actor": "human", "wl": {"verified": True}},
            {"risk": "R2", "autonomy": "A3", "actor": "human"}),

    "S47": ("G-WL", {"actor": "agent", "wl": {"verified": False}},
            {"risk": "R2", "autonomy": "A3"}),

    "S48": ("G-WL", {"actor": "human", "wl": {"verified": False}},
            {"risk": "R2", "autonomy": "A3", "actor": "human"}),

    # P-EDIT / P-RUN — người và tác tử cùng sửa tệp (POL-17 v2.0, cổng `*`).
    #
    # S50 và S51 là MỘT CẶP và phải đọc cùng nhau: cùng năng lực `code.human_save`, khác đúng
    # một thứ — ai gọi — và ra hai quyết định ngược nhau. Đây là ranh giới an toàn của cả nhóm
    # quy tắc v2.0; nếu một ngày S51 chuyển từ REJECT sang bất cứ gì khác thì tác tử có một
    # đường ghi tệp không qua cổng nào.
    "S49": ("*", {"action": {"target_dirty_by_human": True}},
            {"risk": "R1", "autonomy": "A2"}),

    "S50": ("*", {"cap": {"is_human_surface": True}, "actor": "human"},
            {"risk": "R1", "autonomy": "A0", "actor": "human"}),

    "S51": ("*", {"cap": {"is_human_surface": True}, "actor": "agent"},
            {"risk": "R1", "autonomy": "A2"}),

    "S52": ("*", {"action": {"merge_regions_overlap": True}},
            {"risk": "R1", "autonomy": "A2"}),

    "S53": ("*", {"action": {"chain_started_without_event": True}},
            {"risk": "R1", "autonomy": "A2"}),

    # [DEV-204] Ba quy tắc xét CHÍNH YÊU CẦU, không xét năng lực sắp chạy. Đặc trưng viết LỒNG:
    # `_env` dựng đối tượng lồng nhau và `when` đọc theo đường chấm; viết phẳng thì quy tắc
    # không khớp và cổng lặng lẽ rơi xuống ngưỡng cứng (ASK HARD-R4 thay cho REJECT P-LAW-01).
    "S54": ("*", {"request": {"illegal": True}},
            {"risk": "R4", "tier": "T3", "autonomy": "A2"}),

    "S55": ("*", {"request": {"physical_danger": True}},
            {"risk": "R3", "tier": "T2", "autonomy": "A2"}),

    "S56": ("*", {"requirement": {"lowers_acceptance": True}},
            {"risk": "R2", "tier": "T2", "autonomy": "A2"}),
}
