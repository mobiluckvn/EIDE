"""Nhóm tool.* mốc M2 — CDS-12.3 TOOL-08/09/10; SEC-25 §2; POL-17 G-TOOL.

Ba năng lực khép vòng đời một công cụ tự viết: **ghép** (`compose`), **thăng cấp**
(`promote`), **khai tử** (`deprecate`). Bảy năng lực trước dựng ra công cụ; ba cái này quyết
định nó sống tiếp thế nào.

Điểm chung: cả ba đều về QUYỀN của một công cụ — nó được làm gì (`compose` hợp hiệu ứng, và
hiệu ứng quyết định lớp rủi ro), nó có được rời khỏi `user.*` không (`promote` đề xuất, người
duyệt), và nó có còn được gợi ý cho mô hình không (`deprecate`).
"""
from __future__ import annotations

import json

import pytest
import yaml

from eide_core import store
from eide_core.gateway import EchoPort, Gateway
from eide_core.ledger import Ledger
from eide_core.paths import spec_dir
from eide_core.policy import PolicyGate
from eide_core.registry import Registry
from eide_core.router import Context, Router


@pytest.fixture
def moi_truong(tmp_path, workspace):
    cfg = yaml.safe_load((spec_dir() / "models.yaml").read_text(encoding="utf-8"))
    echo = EchoPort([])
    led = Ledger(tmp_path / "ledger.jsonl")
    r = Router(gate=PolicyGate(), ledger=led)
    res = r.invoke("project.create", {"text": "dự án ghép công cụ"},
                   Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=led)
    ctx = Context(project_dir=root, extra={
        "gate": PolicyGate(), "ledger": led, "registry": Registry(),
        "gateway": Gateway(config=cfg, ledger=led, ports={"gemini": echo, "claude": echo})})
    return r, ctx, root


def _tao_tool(root, ten, effects, *, input_schema=None, output_schema=None, dung=0,
              da_test=True, acceptance=None):
    """Dựng sẵn một công cụ trong `.eide/tools/` như `tool.write` + `tool.test` để lại."""
    d = root / ".eide" / "tools" / ten
    d.mkdir(parents=True, exist_ok=True)
    spec = {"name": ten, "purpose": f"công cụ {ten}", "effects": effects, "deps": [],
            "input_schema": input_schema or {"type": "object",
                                             "properties": {"x": {"type": "number"}},
                                             "required": ["x"]},
            "output_schema": output_schema or {"type": "object",
                                               "properties": {"y": {"type": "number"}},
                                               "required": ["y"]},
            "acceptance": acceptance or [{"args": {"x": 1}, "expect": {"y": 2}}]}
    (d / "spec.json").write_text(json.dumps(spec, ensure_ascii=False), encoding="utf-8")
    (d / "tool.py").write_text(
        "def run(args, ctx=None):\n    return {'y': args['x'] * 2}\n", encoding="utf-8")
    if da_test:
        (d / "last_test.json").write_text(
            json.dumps({"passed": True, "effects_ok": True, "cases": 1}), encoding="utf-8")
    if dung:
        (d / "uses.json").write_text(json.dumps({"ok": dung, "fail": 0}), encoding="utf-8")
    return ten


# ================================================================ TOOL-09 compose


def test_ghep_hai_cong_cu_thanh_mot(moi_truong):
    """Bước 1: sinh tool.py **gọi ctx.invoke từng bước, KHÔNG nhúng mã**.

    Nhúng mã của các thành phần vào công cụ ghép là tạo một bản sao thứ hai: sửa công cụ gốc
    thì bản ghép vẫn chạy mã cũ, và không ai biết vì cả hai đều có tên riêng.
    """
    r, ctx, root = moi_truong
    a = _tao_tool(root, "nhan_doi", ["read_fs"])
    b = _tao_tool(root, "cong_mot", ["read_fs"],
                  input_schema={"type": "object", "properties": {"y": {"type": "number"}},
                                "required": ["y"]},
                  output_schema={"type": "object", "properties": {"z": {"type": "number"}},
                                 "required": ["z"]})
    out = r.invoke("tool.compose", {"tool_ids": [a, b], "wiring": {"y": "y"},
                                    "name": "nhan_roi_cong"}, ctx).result

    ma = (root / ".eide" / "tools" / out["tool_id"] / "tool.py").read_text(encoding="utf-8")
    assert "ctx.invoke" in ma
    assert "args['x'] * 2" not in ma, "mã của thành phần bị nhúng vào bản ghép"


def test_effects_la_HOP_cua_cac_buoc(moi_truong):
    """tc TOOL-09 nguyên văn: "Effects gồm hardware → risk R3".

    Hiệu ứng của bản ghép là HỢP của các bước, và lớp rủi ro suy từ đó (TOOL-05). Lấy hiệu ứng
    của bước đầu — hay tệ hơn, để trống — thì một chuỗi có bước chạm phần cứng lại đi qua cổng
    như một công cụ chỉ đọc tệp.
    """
    r, ctx, root = moi_truong
    a = _tao_tool(root, "doc_gi_do", ["read_fs"])
    b = _tao_tool(root, "nap_chip", ["hardware"],
                  input_schema={"type": "object", "properties": {"y": {"type": "number"}},
                                "required": ["y"]})
    out = r.invoke("tool.compose", {"tool_ids": [a, b], "wiring": {"y": "y"},
                                    "name": "doc_roi_nap"}, ctx).result

    spec = json.loads((root / ".eide" / "tools" / out["tool_id"] / "spec.json")
                      .read_text(encoding="utf-8"))
    assert set(spec["effects"]) == {"read_fs", "hardware"}
    from eide_core.toolforge import ToolSpec
    assert ToolSpec.from_dict(spec).risk == "R3"


def test_schema_khong_khop_bao_E1000(moi_truong):
    """`errors: ["E1000 schema không khớp"]`. Kiểm lúc GHÉP chứ không lúc chạy: một chuỗi hỏng
    ở bước ba chỉ lộ ra sau khi bước một và hai đã gây hiệu ứng."""
    r, ctx, root = moi_truong
    a = _tao_tool(root, "ra_so", ["read_fs"])
    b = _tao_tool(root, "can_chuoi", ["read_fs"],
                  input_schema={"type": "object", "properties": {"s": {"type": "string"}},
                                "required": ["s"]})
    run = r.invoke("tool.compose", {"tool_ids": [a, b], "wiring": {"s": "y"},
                                    "name": "lech_kieu"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


def test_wiring_tro_vao_khoa_khong_ton_tai_bao_E1000(moi_truong):
    r, ctx, root = moi_truong
    a = _tao_tool(root, "b1", ["read_fs"])
    b = _tao_tool(root, "b2", ["read_fs"],
                  input_schema={"type": "object", "properties": {"y": {"type": "number"}},
                                "required": ["y"]})
    run = r.invoke("tool.compose", {"tool_ids": [a, b], "wiring": {"y": "khong_co"},
                                    "name": "sai_wiring"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E1000"


def test_test_sinh_tu_acceptance_cua_thanh_phan(moi_truong):
    """Bước 1: "test từ acceptance của các thành phần". Một công cụ ghép không có test là một
    công cụ không ai kiểm được — mà `tool.register` đòi `tool.test` đạt trước khi vào registry."""
    r, ctx, root = moi_truong
    a = _tao_tool(root, "x1", ["read_fs"], acceptance=[{"args": {"x": 2}, "expect": {"y": 4}}])
    b = _tao_tool(root, "x2", ["read_fs"],
                  input_schema={"type": "object", "properties": {"y": {"type": "number"}},
                                "required": ["y"]})
    out = r.invoke("tool.compose", {"tool_ids": [a, b], "wiring": {"y": "y"},
                                    "name": "co_test"}, ctx).result
    d = root / ".eide" / "tools" / out["tool_id"]
    assert (d / "test_tool.py").exists()
    spec = json.loads((d / "spec.json").read_text(encoding="utf-8"))
    assert spec["acceptance"], "bản ghép không thừa hưởng acceptance nào"


def test_compose_dang_ky_undo_xoa_tep(moi_truong):
    r, ctx, root = moi_truong
    a = _tao_tool(root, "u1", ["read_fs"])
    b = _tao_tool(root, "u2", ["read_fs"],
                  input_schema={"type": "object", "properties": {"y": {"type": "number"}},
                                "required": ["y"]})
    r.invoke("tool.compose", {"tool_ids": [a, b], "wiring": {"y": "y"}, "name": "co_undo"}, ctx)
    ref = [(e.get("data") or {}).get("undo_ref", "") for e in ctx.extra["ledger"].records()
           if (e.get("data") or {}).get("kind") == "delete_created_files"]
    assert any(x.startswith("tool:") for x in ref), ref


# ================================================================ TOOL-10 deprecate


def test_khong_con_trong_caps_list_mac_dinh(moi_truong):
    """tc TOOL-10 nguyên văn: "Không còn trong caps.list mặc định"."""
    r, ctx, root = moi_truong
    _tao_tool(root, "cu_ky", ["read_fs"])
    r.invoke("tool.register", {"tool_id": "cu_ky"}, ctx)
    reg = ctx.extra["registry"]
    assert "user.cu_ky" in {c.spec.id for c in reg.list()}

    out = r.invoke("tool.deprecate", {"tool_id": "cu_ky", "reason": "có bản tốt hơn",
                                      "replaced_by": "user.moi_hon"}, ctx).result
    assert out["ok"] is True
    assert "user.cu_ky" not in {c.spec.id for c in reg.list()}


def test_giu_ma_va_lich_su(moi_truong):
    """Bước 1: "giữ mã và lịch sử". Khai tử không phải xóa: một chuỗi cũ trong nhật ký vẫn nhắc
    tới công cụ ấy, và người đọc nhật ký sáu tháng sau cần mở được mã để hiểu chuyện gì đã xảy
    ra."""
    r, ctx, root = moi_truong
    _tao_tool(root, "giu_lai", ["read_fs"])
    r.invoke("tool.register", {"tool_id": "giu_lai"}, ctx)
    r.invoke("tool.deprecate", {"tool_id": "giu_lai", "reason": "hết dùng"}, ctx)

    d = root / ".eide" / "tools" / "giu_lai"
    assert (d / "tool.py").exists() and (d / "spec.json").exists()
    assert json.loads((d / "deprecated.json").read_text(encoding="utf-8"))["reason"] == "hết dùng"


def test_goi_lai_thi_goi_y_replaced_by(moi_truong):
    """Bước 1: "chuỗi cũ gọi → gợi ý replaced_by". Báo "không có năng lực này" cho một thứ vừa
    bị thay là bắt người dùng đi tìm; nêu tên bản thay là trả lời đúng câu họ đang hỏi."""
    r, ctx, root = moi_truong
    _tao_tool(root, "ban_cu", ["read_fs"])
    r.invoke("tool.register", {"tool_id": "ban_cu"}, ctx)
    r.invoke("tool.deprecate", {"tool_id": "ban_cu", "reason": "chậm",
                                "replaced_by": "user.ban_moi"}, ctx)

    # Gọi HANDLER trực tiếp, không qua Router: cổng G-TOOL được Router hỏi với `features` rỗng
    # nên quy tắc TOOL-03 ("chưa test") REJECT trước khi vào handler — một câu trả lời đúng
    # nhưng lạc đề. Phép kiểm ở đây là về thông điệp của `tool.run`, và nó nằm sau cổng.
    from eide.caps.tool import run as tool_run
    from eide_core.errors import EideError
    with pytest.raises(EideError) as e:
        tool_run({"tool_id": "ban_cu", "args": {"x": 1}}, ctx)
    assert e.value.code == "E2000"
    assert "user.ban_moi" in json.dumps(e.value.to_rpc(), ensure_ascii=False)


def test_deprecate_dang_ky_undo_restore_config(moi_truong):
    r, ctx, root = moi_truong
    _tao_tool(root, "co_undo2", ["read_fs"])
    r.invoke("tool.register", {"tool_id": "co_undo2"}, ctx)
    r.invoke("tool.deprecate", {"tool_id": "co_undo2", "reason": "x"}, ctx)
    kinds = [(e.get("data") or {}).get("kind") for e in ctx.extra["ledger"].records()]
    assert "restore_config" in kinds


def test_khong_co_cong_cu_bao_E2000(moi_truong):
    r, ctx, root = moi_truong
    run = r.invoke("tool.deprecate", {"tool_id": "khong_ton_tai", "reason": "x"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ================================================================ TOOL-08 promote


def _chay_promote(r, ctx, tool_id, ns="hkw"):
    """TOOL-08 là **T2** với `ask_when: "Luôn"` ⇒ Router xếp hàng chờ. Thăng cấp một công cụ do
    mô hình viết lên namespace chung là việc không bao giờ tự chạy."""
    run = r.invoke("tool.promote", {"tool_id": tool_id, "target_ns": ns}, ctx)
    assert run.status == "pending", "TOOL-08 là T2, phải hỏi người mọi lần"
    return r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)


def test_de_xuat_khong_tu_ap_dung(moi_truong):
    """tc TOOL-08 nguyên văn: "Đề xuất không tự áp dụng; sau duyệt registry có năng lực mới".

    Vế đầu là vế đáng kiểm: năng lực này TRẢ VỀ một đề xuất và không đụng gì tới registry. Tự
    đổi `user.crc16` thành `hkw.crc16` là để một công cụ do mô hình viết mang tên của namespace
    mà người dùng tin.
    """
    import hashlib

    from eide_core.paths import spec_dir
    r, ctx, root = moi_truong
    _tao_tool(root, "crc16", ["read_fs"], dung=3)
    r.invoke("tool.register", {"tool_id": "crc16"}, ctx)
    reg = ctx.extra["registry"]

    def _bam_spec():
        h = hashlib.sha256()
        for f in sorted((spec_dir() / "capabilities").glob("*.yaml")):
            h.update(f.read_bytes())
        h.update((spec_dir() / "cds.json").read_bytes())
        return h.hexdigest()

    truoc = _bam_spec()
    out = _chay_promote(r, ctx, "crc16").result
    assert out["proposal"]["target_id"] == "hkw.crc16"
    # Ba mức của "không tự áp dụng", và mức thứ ba là mức đáng sợ nhất: năng lực cũ còn nguyên,
    # năng lực mới CHƯA có, và **bộ đặc tả trong `docs/spec/` không bị đụng một byte**. Ghi
    # thẳng vào `capabilities/*.yaml` là đưa một công cụ do mô hình viết vào chính tệp mà
    # `test_specs_consistency` coi là nguồn sự thật.
    assert "user.crc16" in {c.spec.id for c in reg.list()}
    assert "hkw.crc16" not in {c.spec.id for c in reg.list()}
    assert _bam_spec() == truoc, "tool.promote đã sửa docs/spec/ — nó chỉ được ĐỀ XUẤT"


def test_chua_du_ba_lan_dung_bao_E3000(moi_truong):
    """Điều kiện bước 1: "uses ≥ 3 thành công". Thăng cấp một công cụ mới chạy một lần là đề
    xuất người khác tin vào thứ chính ta chưa tin."""
    r, ctx, root = moi_truong
    _tao_tool(root, "moi_toanh", ["read_fs"], dung=1)
    r.invoke("tool.register", {"tool_id": "moi_toanh"}, ctx)
    run = r.invoke("tool.promote", {"tool_id": "moi_toanh", "target_ns": "hkw"}, ctx)
    assert run.status == "pending"
    sau = r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)
    assert sau.status == "pending" and sau.error["eide_code"] == "E3000"


def test_chua_test_bao_E3000(moi_truong):
    r, ctx, root = moi_truong
    _tao_tool(root, "chua_kiem", ["read_fs"], dung=5, da_test=False)
    run = r.invoke("tool.promote", {"tool_id": "chua_kiem", "target_ns": "hkw"}, ctx)
    assert run.status == "pending"
    sau = r.quyet_dinh(run.run_id, "approve", ctx_goi_y=ctx)
    assert sau.status == "pending" and sau.error["eide_code"] == "E3000"


def test_bench_mini_chay_acceptance_ba_lan(moi_truong):
    """Bước 1: "bench.run mini (acceptance × 3 lần)". Ba lần chứ không một: một công cụ đọc
    trạng thái ngoài (giờ, tệp tạm, bộ đếm) có thể đúng lần đầu rồi sai lần sau, và đó đúng là
    loại công cụ không nên mang tên namespace chung."""
    r, ctx, root = moi_truong
    _tao_tool(root, "on_dinh", ["read_fs"], dung=4)
    out = _chay_promote(r, ctx, "on_dinh").result
    b = out["proposal"]["bench"]
    assert b["runs"] == 3 and b["passed"] == 3


def test_de_xuat_neu_ro_dang_goi(moi_truong):
    """Bước 1 cho hai dạng: PR vào `eide-packs/tools` hoặc gói `.hkp kind=tool`. Đề xuất phải
    nói rõ nó là dạng nào — Pack owner duyệt hai thứ ấy theo hai đường khác nhau."""
    r, ctx, root = moi_truong
    _tao_tool(root, "co_dang", ["read_fs"], dung=3)
    out = _chay_promote(r, ctx, "co_dang").result
    assert out["proposal"]["kind"] in ("pr", "hkp")
    assert out["proposal"]["files"]
