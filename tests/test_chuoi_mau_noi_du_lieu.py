"""DPS-09 §4.4 v1.3 — mẫu chuỗi mang phần NỐI dữ liệu giữa các nút ([DEV-121]).

Máy giải tham chiếu `${nX.field}` có trong `eide_core.chain` từ 17/09; thứ thiếu là **dữ liệu
nối trong mẫu**, và trước v1.3 mã còn dựng nút từ bản VĂN XUÔI nên kể cả có dữ liệu cũng không
tới được. Hai nửa ấy phải khớp nhau thì một chuỗi dài hơn một bước mới chạy qua được phép kiểm
deterministic của chính nó.
"""
from __future__ import annotations

import json
from pathlib import Path

from eide_core import chain as chain_mod
from eide_core.paths import spec_dir

GOC = Path(__file__).resolve().parents[1]


def _mau(ma: str) -> dict:
    d = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    return next(c for c in d if ma in c["ten"])


def test_mau_mang_phan_noi_va_tham_chieu_dung_cu_phap():
    """Tham chiếu trong mẫu phải ĐỌC ĐƯỢC và trỏ vào nút CÓ THẬT.

    Một chuỗi gõ sai cú pháp đi thẳng vào chuỗi như một giá trị nguyên, và nút nhận một chuỗi
    `"${n8.patch}"` làm patch.

    `args` cũng được phép mang GIÁ TRỊ HẰNG — `{kind: "requirement"}` của `view.artifacts` là
    một tham số cố định, không phải một phép nối ([DEV-158]). Bản đầu của bài này đòi MỌI `args`
    là tham chiếu, nên nó cấm luôn cả thứ hợp lệ. Phân biệt bằng chính cú pháp: chuỗi có dạng
    `${...}` thì phải giải được; còn lại là hằng.
    """
    d = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    tong = 0
    for c in d:
        ids = {n["id"] for n in c["nodes"]}
        for n in c["nodes"]:
            for k, v in (n.get("args") or {}).items():
                if not (isinstance(v, str) and v.startswith("${")):
                    continue                      # hằng — kiểm kiểu ở bài dưới
                # `${_text}` — câu gốc của người dùng, KHÔNG phải tham chiếu nút. [DEV-201]
                # Mẫu là chỗ duy nhất được quyền nói tham số nào nhận lời người nói (DEV-121);
                # `_tu_nodes` thay nó lúc dựng chuỗi, nên nó không bao giờ tới phép kiểm chuỗi.
                # [DEV-208] `${_path}` cũng là token GỐC, không phải tham chiếu nút. Trước đó
                # nó chỉ xuất hiện trong list (`{files: ['${_path}']}`) nên chưa gặp dạng trần.
                if v in ("${_text}", "${_path}"):
                    continue
                tong += 1
                m = chain_mod.tach_tham_chieu(v)
                assert m is not None, f"{c['ten']} {n['id']}.{k} sai cú pháp tham chiếu: {v!r}"
                assert m[0] in ids, f"{c['ten']} {n['id']}.{k} trỏ nút không có: {m[0]}"
    assert tong >= 8, f"mẫu chỉ mang {tong} phép nối — DEV-121 điền ít nhất 8"


def test_moi_phep_noi_khop_HAI_DAU_hop_dong():
    """**Phép nối phải suy được từ hợp đồng, không từ trí nhớ.**

    Đầu nhận phải là một tham số CÓ THẬT của năng lực ấy, và chặng đầu của đường đọc phải là
    một trường CÓ THẬT trong `output_schema` của nút nguồn. Chặng sâu (`plan.steps[0].id`) thì
    không kiểm được ở đây — phần lớn `output_schema` khai `{"type":"object"}` trần, nên khẳng
    định hơn thế là một lời chắc chắn dựa trên không gì cả.
    """
    caps = {c["id"]: c for c in json.loads((GOC / "docs/spec/cds.json").read_text("utf-8"))}
    d = json.loads((spec_dir() / "dialog" / "chains.json").read_text(encoding="utf-8"))
    for c in d:
        theo_id = {n["id"]: n for n in c["nodes"]}
        for n in c["nodes"]:
            nhan = caps.get(n["cap"])
            for k, v in (n.get("args") or {}).items():
                assert nhan and k in (nhan["input_schema"].get("properties") or {}), \
                    f"{c['ten']} {n['id']}: `{k}` không phải tham số của `{n['cap']}`"
                if v in ("${_text}", "${_path}"):
                    # Câu gốc / đường dẫn của người là CHUỖI — tham số nhận nó phải nhận chuỗi.
                    t = (nhan["input_schema"]["properties"] or {})[k]
                    assert (t or {}).get("type") in (None, "string"), \
                        f"{c['ten']} {n['id']}: `{k}` nhận `${{_text}}` nhưng kiểu là {t.get('type')}"
                    continue
                if not (isinstance(v, str) and v.startswith("${")):
                    # Hằng: kiểm nó khớp `enum` nếu hợp đồng khai enum. Một `kind` gõ sai sẽ bị
                    # Router chặn bằng E1000 lúc CHẠY, tức sau khi vài nút trước đã ghi.
                    t = (nhan["input_schema"]["properties"] or {})[k]
                    if isinstance(t, dict) and t.get("enum"):
                        assert v in t["enum"], \
                            f"{c['ten']} {n['id']}: `{k}={v!r}` ngoài enum {t['enum']}"
                    continue
                nguon_id, duong = chain_mod.tach_tham_chieu(v)
                nguon = caps.get(theo_id[nguon_id]["cap"])
                dau = duong.split(".")[0].split("[")[0]
                assert dau in (nguon["output_schema"].get("properties") or {}), \
                    f"{c['ten']} {n['id']}: `{nguon_id}` không trả ra `{dau}`"


def test_chuoi_Z05_dung_tu_NODES_chu_khong_tu_van_xuoi(tmp_path, workspace):
    """Tới 21/09 `_dung_chuoi` dựng nút từ `buoc` — bản văn xuôi — nên BA thứ của `nodes` bị bỏ
    qua: `when` thật, `on_ask`, và `args`. Phần nối vừa viết vào mẫu khi ấy không bao giờ chạy.
    """
    from eide.caps.chat import _dung_chuoi
    from eide_core.registry import get_registry
    from eide_core.router import Context

    mau = _mau("Z-05")
    chuoi, nguon = _dung_chuoi(mau, {"intent": "code.feature", "slots": {}}, {},
                               Context(project_dir=None))
    assert nguon.startswith("mẫu:"), nguon
    theo_cap = {n.cap: n for n in chuoi.nodes}

    # Nút nào của mẫu CÓ nối và đã hiện thực thì nút trong chuỗi phải mang đúng phép nối ấy.
    reg = get_registry()
    for n in mau["nodes"]:
        if not (n.get("args") and n["cap"] in reg and reg.get(n["cap"]).implemented):
            continue
        assert n["cap"] in theo_cap, f"mất nút `{n['cap']}` khỏi chuỗi"
        for k, v in n["args"].items():
            assert theo_cap[n["cap"]].args.get(k) == v, \
                f"`{n['cap']}.{k}` mất phép nối — chuỗi dựng từ văn xuôi?"


def test_tham_chieu_toi_nut_DA_BI_BO_thi_go_di(tmp_path, workspace):
    """Một tham chiếu tới nút đã bị bỏ không bao giờ giải được, và nó GIẾT cả chuỗi ở phép kiểm
    deterministic. Bỏ nó đi thì nút rơi về "thiếu tham số" và hỏi người — một câu hỏi người trả
    lời được tốt hơn một chuỗi chết."""
    from eide.caps.chat import _tu_nodes
    from eide_core.registry import get_registry
    from eide_core.router import Context

    mau = {"ten": "giả", "nodes": [
        {"id": "n1", "cap": "khong.co.nang.luc.nay", "when": None, "on_ask": "wait", "args": {}},
        {"id": "n2", "cap": "chat.report_back", "when": "n1", "on_ask": "wait",
         "args": {"run_id": "${n1.gi_do}"}},
    ]}
    nut = _tu_nodes(mau, {"intent": "x", "slots": {}}, {}, Context(project_dir=None), "r1",
                    get_registry())
    assert len(nut) == 1 and nut[0].cap == "chat.report_back"
    assert nut[0].when is None, "`when` còn trỏ vào nút đã bỏ"
    assert not str(nut[0].args.get("run_id", "")).startswith("${n1."), nut[0].args


def test_tham_so_cua_MAU_thang_phep_suy_tu_slots(tmp_path, workspace):
    """Mẫu nói "lấy từ nút n8"; `_args_cho` chỉ biết đọc slots. Một tham chiếu bị giá trị suy
    từ slots đè lên là mất đúng phép nối."""
    from eide.caps.chat import _tu_nodes
    from eide_core.registry import get_registry
    from eide_core.router import Context

    mau = {"ten": "giả", "nodes": [
        {"id": "n1", "cap": "req.elicit", "when": None, "on_ask": "wait", "args": {}},
        {"id": "n2", "cap": "req.classify", "when": "n1", "on_ask": "wait",
         "args": {"raw": "${n1.raw}"}},
    ]}
    nut = _tu_nodes(mau, {"intent": "x", "slots": {"raw": "TU SLOTS"}}, {},
                    Context(project_dir=None), "r1", get_registry())
    n2 = next(n for n in nut if n.cap == "req.classify")
    assert n2.args["raw"] == "${n1.raw}", n2.args
