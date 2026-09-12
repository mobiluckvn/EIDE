"""`registry.*` và hai `search.*` của mốc M4 — CDS-12.5 REGISTRY-01…04, CDS-12.2 SEARCH-01/09.

**Registry ở đây là một THƯ MỤC, và đó không phải một bản giả.** Định dạng `.hkp` là thật (cùng
`manifest.json` + `manifest.sig` mà `env.install_pack` đã đọc từ Sprint 2), chữ ký là thật (băm
nội dung), phép kiểm license và K3/K6 là thật. Cái duy nhất cục bộ là VẬN CHUYỂN — thay thư mục
bằng một git remote thì bốn năng lực không đổi một dòng.

Làm ngược lại — chờ có registry thật rồi mới viết — thì phần đáng kiểm nhất của chúng không bao
giờ được kiểm.
"""
from __future__ import annotations

import hashlib
import json

import pytest

from eide_core import store
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def kho(tmp_path, monkeypatch):
    d = tmp_path / "registry"
    monkeypatch.setenv("EIDE_REGISTRY", str(d))
    return d


@pytest.fixture
def du_an(tmp_path, workspace, kho):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "gói"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    return r, Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger}), root


def _fact(root, fid: str, subject: str, license_="Apache-2.0", sid="s_r") -> None:
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR IGNORE INTO source (id,uri,sha256,kind,tier,license)"
                  " VALUES (?,?,?,?,?,?)",
                  (sid, f"https://x/{sid}.svd", hashlib.sha256(sid.encode()).hexdigest(),
                   "svd", "gold", license_))
        c.execute("INSERT INTO fact (id,subject,predicate,value,source_id,method,tier,"
                  "confidence,status,layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (fid, subject, "base_address", json.dumps("0x40005400"), sid, "parser",
                   "gold", 1.0, "verified", "A"))
        c.commit()


# ---------------------------------------------------------------- REGISTRY-03 pack


def test_pack_mang_CON_TRO_nguon_chu_khong_mang_PDF(du_an):
    """REGISTRY-03 bước 1: "fact + con trỏ nguồn (không PDF)".

    Lý do là giấy phép: một datasheet của hãng thường cấm phát tán lại, còn `source.uri` kèm
    `sha256` thì không mang theo nội dung nào — người nhận tự tải từ hãng và kiểm băm.
    """
    from eide.caps.registry import pack

    _, ctx, root = du_an
    _fact(root, "f_pack00000001", "chip:st.stm32f411/periph:I2C1")
    kq = pack({"id": "st.stm32f411", "include": ["passport"]}, ctx)

    from pathlib import Path
    d = json.loads((Path(kq["file"]) / "facts.json").read_text(encoding="utf-8"))
    assert d["facts"][0]["id"] == "f_pack00000001"
    s = d["sources"][0]
    assert s["uri"] and s["sha256"], "con trỏ nguồn phải có uri + băm"
    assert "content" not in s and "bytes" not in s, "không mang nội dung nguồn"


def test_pack_license_NGOAI_danh_sach_thi_E8001(du_an):
    """Một gói đi ra ngoài mang theo nghĩa vụ pháp lý mà người nhận không đọc."""
    from eide.caps.registry import pack

    _, ctx, root = du_an
    _fact(root, "f_pack00000002", "chip:x", license_="GPL-3.0", sid="s_gpl")
    with pytest.raises(EideError) as e:
        pack({"id": "x"}, ctx)
    assert e.value.code == "E8001" and "GPL-3.0" in str(e.value)


def test_pack_KHONG_co_fact_thi_E2000(du_an):
    from eide.caps.registry import pack

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        pack({"id": "khong-co-gi"}, ctx)
    assert e.value.code == "E2000"


def test_pack_ky_bang_bam_NOI_DUNG(du_an):
    """Chữ ký phải đổi khi nội dung đổi — nếu không nó là một tệp trang trí."""
    from pathlib import Path

    from eide.caps.registry import TEP_CHU_KY, pack

    _, ctx, root = du_an
    _fact(root, "f_pack00000003", "chip:y")
    d = Path(pack({"id": "y"}, ctx)["file"])
    ky = (d / TEP_CHU_KY).read_text(encoding="utf-8").strip()

    (d / "facts.json").write_text("{}", encoding="utf-8")
    from eide.caps.registry import _bam_goi
    assert _bam_goi(d, ["facts.json"]) != ky


# ---------------------------------------------------------------- REGISTRY-04 publish


def test_publish_CONG_KHAI_thi_hoi_nguoi(du_an):
    """REGISTRY-04 bước 1: "internal + … → APPROVE; public → ASK".

    Phát hành nội bộ là chia sẻ trong nhóm; phát hành công khai là hành động KHÔNG RÚT LẠI
    được, vì người khác đã tải về rồi. Đó là toàn bộ lý do năng lực này là T1* chứ không T1.
    """
    from eide.caps.registry import pack, publish

    _, ctx, root = du_an
    _fact(root, "f_pub00000001", "chip:z")
    goi = pack({"id": "z"}, ctx)["file"]
    with pytest.raises(EideError) as e:
        publish({"pkg": goi, "scope": "public"}, ctx)
    assert e.value.code == "E3000" and e.value.data["gate_id"] == "G5"


def test_publish_NOI_BO_tu_chay_va_vao_index(du_an, kho):
    from eide.caps.registry import pack, publish

    _, ctx, root = du_an
    _fact(root, "f_pub00000002", "chip:w")
    goi = pack({"id": "w"}, ctx)["file"]
    kq = publish({"pkg": goi, "scope": "internal"}, ctx)
    assert kq["published"] is True
    idx = json.loads((kho / "index.json").read_text(encoding="utf-8"))["packages"]
    assert idx[0]["id"].startswith("w@") and idx[0]["scope"] == "internal"


def test_publish_goi_CHUA_pack_thi_E4004_chu_khong_tu_pack_ho(du_an, tmp_path):
    """Không tự pack hộ: `registry.pack` có phép kiểm license và K3/K6 riêng, và chạy nó ngầm
    bên trong đây sẽ làm một lần phát hành bỏ qua hai phép kiểm ấy mà không ai thấy."""
    from eide.caps.registry import publish

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        publish({"pkg": str(tmp_path / "khong-phai-goi"), "scope": "internal"}, ctx)
    assert e.value.code == "E4004" and "registry.pack" in e.value.data["candidates"]


# ---------------------------------------------------------------- REGISTRY-02 pull


def test_pull_KIEM_CHU_KY_truoc_khi_nap_mot_fact_nao(du_an, kho):
    """Bất biến của REGISTRY-02. Một gói đã bị sửa mang theo những con số mà mã sinh ra sẽ trích
    dẫn — nạp nửa chừng rồi mới phát hiện thì store đã có fact bẩn mang nhãn `verified`."""

    from eide.caps.registry import pack, publish, pull

    r, ctx, root = du_an
    _fact(root, "f_pull00000001", "chip:v")
    goi = pack({"id": "v"}, ctx)["file"]
    publish({"pkg": goi, "scope": "internal"}, ctx)

    # Sửa gói trong kho SAU khi ký.
    d = next(p for p in kho.iterdir() if p.is_dir())
    (d / "facts.json").write_text(json.dumps(
        {"facts": [{"id": "f_gia0000000001", "subject": "chip:GIẢ", "predicate": "base_address",
                    "value": "0xBAD"}], "sources": []}), encoding="utf-8")

    truoc = _dem_fact(root)
    with pytest.raises(EideError) as e:
        pull({"id": d.name}, ctx)
    assert e.value.code == "E8001"
    assert _dem_fact(root) == truoc, "không được nạp fact nào khi chữ ký hỏng"


def test_pull_ha_status_xuong_REVIEWED(du_an, kho):
    """Fact trong gói đã được ai đó duyệt, ở một dự án khác, trên một con chip có thể khác lô.

    Giữ `verified` là mượn lòng tin của người khác cho ngữ cảnh của mình — mà `verified` trong
    KAD-07 nghĩa là "đã đo trên board này".
    """
    from eide.caps.registry import pack, publish, pull

    r, ctx, root = du_an
    _fact(root, "f_pull00000002", "chip:u")
    publish({"pkg": pack({"id": "u"}, ctx)["file"], "scope": "internal"}, ctx)

    # Dự án thứ hai để pull vào.
    ws = root.parent
    res = r.invoke("project.create", {"text": "nhận gói"}, Context(project_dir=ws)).result
    root2 = ws / res["project_id"]
    store.migrate(store.store_path(root2))
    ctx2 = Context(project_dir=root2, extra={"gate": PolicyGate(), "ledger": r.ledger})

    d = next(p for p in kho.iterdir() if p.is_dir())
    kq = pull({"id": d.name}, ctx2)
    assert kq["facts"] == 1
    with store.open_store(store.store_path(root2)) as c:
        (st,) = c.execute("SELECT status FROM fact WHERE id='f_pull00000002'").fetchone()
    assert st == "reviewed", "không được giữ verified của dự án khác"


def test_pull_goi_khong_co_thi_E4004_kem_goi_y(du_an):
    from eide.caps.registry import pull

    _, ctx, _ = du_an
    with pytest.raises(EideError) as e:
        pull({"id": "khong.co@1.0.0"}, ctx)
    assert e.value.code == "E4004" and "registry.search" in e.value.data["candidates"]


def _dem_fact(root) -> int:
    with store.open_store(store.store_path(root)) as c:
        return c.execute("SELECT count(*) FROM fact").fetchone()[0]


# ---------------------------------------------------------------- tìm kiếm


def test_search_xep_BADGE_len_truoc_diem_khop(du_an, kho):
    """Badge là thứ đắt nhất để có được trong cả hệ thống — nó đòi một lần nạp firmware lên
    board thật. Một hộ chiếu `verified_on_board` đáng tin hơn một hộ chiếu trùng tên hơn một
    ký tự."""
    from eide.caps.registry import _ghi_index, search

    _, ctx, _ = du_an
    _ghi_index([
        {"id": "abc@1.0.0", "kind": "passport", "badges": []},
        {"id": "abcd@1.0.0", "kind": "passport", "badges": ["verified_on_board"]},
    ])
    ds = search({"q": "abc"}, ctx)["packages"]
    assert ds[0]["id"] == "abcd@1.0.0", ds


def test_search_registry_RONG_thi_canh_bao_chu_khong_nem(du_an):
    """SEARCH-01 ghi rõ: "registry không tới được → trả rỗng + cảnh báo". Một máy chưa từng
    publish thì chưa có index, và đó là trạng thái bình thường."""
    from eide.caps.search import registry as search_registry

    _, ctx, _ = du_an
    kq = search_registry({"query": "bất kỳ"}, ctx)
    assert kq["candidates"] == [] and "warning" in kq


def test_reference_projects_RONG_khong_chan_chuoi_Z01(du_an):
    """Chuỗi Z-01 dùng năng lực này ở bước 2 và nó phải đi tiếp được khi registry rỗng: một dự
    án mới vẫn dựng được mà không cần mẫu nào."""
    from eide.caps.search import reference_projects

    _, ctx, _ = du_an
    kq = reference_projects({"idea": "robot cân bằng hai bánh"}, ctx)
    assert kq["candidates"] == [] and "không chặn chuỗi Z-01" in kq["warning"]


def test_reference_projects_khop_theo_TU(du_an, kho):
    from eide.caps.registry import _ghi_index
    from eide.caps.search import reference_projects

    _, ctx, _ = du_an
    _ghi_index([
        {"id": "robot-can-bang@1.0.0", "kind": "template",
         "keywords": ["robot", "cân", "bằng", "mpu6050"]},
        {"id": "den-led@1.0.0", "kind": "template", "keywords": ["led", "nhấp", "nháy"]},
        {"id": "khong-phai-mau@1.0.0", "kind": "passport", "keywords": ["robot"]},
    ])
    ds = reference_projects({"idea": "robot cân bằng dùng mpu6050"}, ctx)["candidates"]
    assert ds[0]["id"] == "robot-can-bang@1.0.0"
    assert all(x["kind"] == "template" for x in ds), "chỉ mẫu dự án, không lẫn hộ chiếu"


def test_ca_nam_nang_luc_registry_da_gan_hien_thuc():
    from eide.cli import main  # noqa: F401
    from eide_core.registry import get_registry

    reg = get_registry()
    assert {c.spec.id for c in reg.list(ns="registry", implemented=True)} == {
        "registry.seed", "registry.search", "registry.pull", "registry.pack",
        "registry.publish"}
