"""Nhóm project.* mốc M2 — CDS-12.3; DDD-14; DEP-26 §3 (một daemon, nhiều dự án).

Ba năng lực: `project.clone` (PROJECT-04), `project.archive` (PROJECT-05),
`project.rollback` (PROJECT-07).

Điểm chung của cả ba: chúng thao tác trên MỘT DỰ ÁN NHƯ MỘT VẬT THỂ — sao chép, đóng gói, quay
lui. Cái dễ sai không nằm ở thao tác tệp mà ở chỗ **cái gì KHÔNG được đi theo**: một bản sao
mang theo nhật ký của dự án gốc là một bản sao nói dối về lịch sử của chính nó.
"""
from __future__ import annotations

import json
import zipfile
from pathlib import Path

import pytest

from eide_core import git, store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router


@pytest.fixture
def du_an(tmp_path, workspace):
    """Một dự án có store thật: 2 fact, 1 hộ chiếu, 1 dòng decision_log, 1 feature."""
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án gốc"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    db = store.store_path(root)
    store.migrate(db, ledger=r.ledger)
    with store.open_store(db) as c:
        c.execute("INSERT INTO source (id, uri, sha256, kind, tier)"
                  " VALUES ('src_1','stm32f411.svd','h1','svd','gold')")
        for i, (subj, gt) in enumerate((("chip:st.x/periph:I2C1", "1073765376"),
                                        ("chip:st.x/periph:I2C1/reg:CR1", "0")), 1):
            c.execute("INSERT INTO fact (id, subject, predicate, value, source_id, method, tier,"
                      " confidence, status, layer) VALUES (?,?,?,?,?,?,?,?,?,?)",
                      (f"f_{i:016x}", subj, "base_address", gt, "src_1", "parser", "gold",
                       1.0, "normalized", "C"))
        c.execute("INSERT INTO passport (id, kind, header, created_at)"
                  " VALUES ('st.x@1.0.0','chip','{\"name\":\"st.x\"}','2026-09-10T00:00:00Z')")
        c.execute("INSERT INTO decision_log (id, gate, action_cap, risk, autonomy_level,"
                  " decision, by, rule, at) VALUES"
                  " ('d1','*','project.create','R2','A2','APPROVE','agent','TIER-T1','x')")
        c.commit()
    (root / ".eide" / "FEATURES.json").write_text(
        json.dumps({"features": [{"id": "F-01", "title": "đọc IMU", "status": "failing"}]}),
        encoding="utf-8")
    (root / "src").mkdir(exist_ok=True)
    (root / "src" / "main.c").write_text("int main(void){return 0;}\n", encoding="utf-8")
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root, workspace


def _dem(db: Path, bang: str) -> int:
    with store.open_store(db) as c:
        return c.execute(f"SELECT COUNT(*) FROM {bang}").fetchone()[0]  # noqa: S608


# ================================================================ PROJECT-04 clone


def test_ban_sao_cung_so_fact_va_ledger_rong(du_an):
    """tc PROJECT-04 nguyên văn: "Bản sao có cùng số fact, ledger rỗng"."""
    r, ctx, root, ws = du_an
    out = r.invoke("project.clone", {"src": str(root), "new_name": "ban-sao"}, ctx).result

    moi = Path(out["path"])
    assert moi.is_dir() and out["project_id"] == "ban-sao"
    assert _dem(store.store_path(moi), "fact") == _dem(store.store_path(root), "fact") == 2

    nhat_ky = moi / ".eide" / "store" / "ledger.jsonl"
    assert not nhat_ky.exists() or nhat_ky.read_text(encoding="utf-8").strip() == ""


def test_khong_mang_theo_lich_su_cua_du_an_goc(du_an):
    """Bước 2 liệt kê thứ KHÔNG đi theo: ledger, session, index, decision_log, run.

    Đây là phần dễ làm sai nhất, vì cách viết một lệnh sao chép tự nhiên nhất — chép cả thư mục
    `.eide/` — làm đúng điều ngược lại. Một bản sao mang theo `decision_log` của bản gốc sẽ khiến
    `policy.learn_thresholds` học từ những quyết định chưa từng xảy ra trong dự án này, và mỗi
    dòng nhật ký ấy trỏ về `run_id` không tồn tại ở đây.
    """
    r, ctx, root, ws = du_an
    out = r.invoke("project.clone", {"src": str(root), "new_name": "sach"}, ctx).result
    db = store.store_path(Path(out["path"]))
    assert _dem(db, "decision_log") == 0
    assert _dem(db, "capability_run") == 0
    assert _dem(db, "run") == 0
    # `session` không nằm trong store — `SessionMemory` ghi ra `.eide/session/` (MEM-11 §2), nên
    # phép kiểm cho nó là thư mục ấy phải trống.
    assert list((Path(out["path"]) / ".eide" / "session").glob("*")) == []


def test_hộ_chiếu_và_nguồn_đi_theo_fact(du_an):
    """Fact có khoá ngoại tới `source`, và một fact không có nguồn là một fact không kiểm được.
    Hộ chiếu đi cùng vì đó chính là "knowledge" mà `keep` mặc định nói tới."""
    r, ctx, root, ws = du_an
    out = r.invoke("project.clone", {"src": str(root), "new_name": "b2"}, ctx).result
    db = store.store_path(Path(out["path"]))
    assert _dem(db, "source") == 1
    assert _dem(db, "passport") == 1


def test_keep_mac_dinh_chi_lay_tri_thuc(du_an):
    """`keep` mặc định là `["knowledge"]`: mã và tài liệu KHÔNG đi theo trừ khi được nêu. Sao
    chép cả mã theo mặc định thì "clone để thử một hướng khác" biến thành "nhân đôi một dự án
    đang dở"."""
    r, ctx, root, ws = du_an
    out = r.invoke("project.clone", {"src": str(root), "new_name": "chi-tri-thuc"}, ctx).result
    moi = Path(out["path"])
    assert not (moi / "src" / "main.c").exists()
    assert json.loads((moi / ".eide" / "FEATURES.json").read_text(encoding="utf-8"))["features"] == []


def test_keep_code_va_features(du_an):
    r, ctx, root, ws = du_an
    out = r.invoke("project.clone", {"src": str(root), "new_name": "day-du",
                                     "keep": ["knowledge", "code", "features"]}, ctx).result
    moi = Path(out["path"])
    assert (moi / "src" / "main.c").read_text(encoding="utf-8").startswith("int main")
    f = json.loads((moi / ".eide" / "FEATURES.json").read_text(encoding="utf-8"))["features"]
    assert [x["id"] for x in f] == ["F-01"]


def test_ten_trung_bao_E2001(du_an):
    """Bước 1. E2001 kèm phương án là quy định của API-15 §3 cho mã này."""
    r, ctx, root, ws = du_an
    run = r.invoke("project.clone", {"src": str(root), "new_name": root.name}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2001"


def test_src_khong_co_bao_E2000(du_an):
    r, ctx, root, ws = du_an
    run = r.invoke("project.clone", {"src": str(ws / "khong-co"), "new_name": "x"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


def test_ghi_ledger_kem_nguon(du_an):
    """Bước 3: "Ghi ledger project.clone với nguồn". Nguồn là thứ duy nhất trả lời được câu hỏi
    "tri thức trong dự án này từ đâu ra" khi nhìn một bản sao ba tháng sau."""
    r, ctx, root, ws = du_an
    r.invoke("project.clone", {"src": str(root), "new_name": "co-nguon"}, ctx)
    # API-15 §7 không có kiểu sự kiện nào cho việc này (25 kiểu, không kiểu nào là
    # `project.clone`), nên hiện thực mượn `report` và ghi loại vào `data.kind` — cùng cách tạm
    # mà DEV-013 và DEV-031 đã dùng. Xem DEV-081.
    ds = [e for e in r.ledger.records()
          if e["kind"] == "report" and (e.get("data") or {}).get("kind") == "project.clone"]
    assert ds and ds[-1]["data"]["src"] == str(root)


# ================================================================ PROJECT-05 archive


def test_zip_mo_lai_duoc_va_list_gan_co_archived(du_an):
    """tc PROJECT-05 nguyên văn: "Zip mở lại được; project.list gắn cờ archived"."""
    r, ctx, root, ws = du_an
    out = r.invoke("project.archive", {"project": str(root)}, ctx).result

    z = Path(out["archived_path"])
    assert z.is_file() and z.parent == ws / "archive"
    with zipfile.ZipFile(z) as f:
        assert f.testzip() is None
        ten = f.namelist()
        assert any(x.endswith("store.sqlite") for x in ten)
        assert any(x.endswith("src/main.c") for x in ten)

    ds = r.invoke("project.list", {"workspace": str(ws)}, ctx).result["projects"]
    assert next(x for x in ds if x["id"] == root.name)["archived"] is True


def test_khong_dong_goi_cache_va_index(du_an):
    """Bước 1: "không bao gồm cache/index". Chúng dựng lại được từ store, và chúng là phần LỚN
    nhất — một kho lưu trữ 800 MB vì mang theo cache là một kho không ai lưu."""
    r, ctx, root, ws = du_an
    (root / ".eide" / "index").mkdir(exist_ok=True)
    (root / ".eide" / "index" / "rag.sqlite").write_bytes(b"x" * 1024)
    (root / ".eide" / "cache").mkdir(exist_ok=True)
    (root / ".eide" / "cache" / "unpacked.bin").write_bytes(b"y" * 1024)

    out = r.invoke("project.archive", {"project": str(root)}, ctx).result
    with zipfile.ZipFile(Path(out["archived_path"])) as f:
        ten = f.namelist()
    assert not any("/index/" in x or "/cache/" in x for x in ten), ten


def test_archive_khong_xoa_du_an(du_an):
    """`ask_when` của hợp đồng là "Xóa thật sự (R4)" — tức việc XÓA là một hành động khác, ở lớp
    rủi ro khác. Đóng gói thì không được đụng gì tới bản gốc."""
    r, ctx, root, ws = du_an
    r.invoke("project.archive", {"project": str(root)}, ctx)
    assert (root / ".eide" / "store" / "store.sqlite").exists()
    assert (root / "src" / "main.c").exists()


def test_du_an_khong_co_bao_E2000(du_an):
    r, ctx, root, ws = du_an
    run = r.invoke("project.archive", {"project": str(ws / "khong-co")}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ================================================================ PROJECT-07 rollback


def _kho_git(root: Path) -> str:
    """Dựng một kho git có một tag known-good rồi làm hỏng mã sau đó."""
    git.dam_bao_kho(root)
    git.chay(root, "config", "user.email", "t@t")
    git.chay(root, "config", "user.name", "t")
    git.chay(root, "add", "-A")
    git.chay(root, "commit", "-m", "tot")
    tag = git.dat_tag(root, "known-good/2026-09-10")
    (root / "src" / "main.c").write_text("int main(void){ hong(); }\n", encoding="utf-8")
    (root / ".eide" / "FEATURES.json").write_text(
        json.dumps({"features": [{"id": "F-01", "title": "đọc IMU", "status": "passing"}]}),
        encoding="utf-8")
    git.chay(root, "add", "-A")
    git.chay(root, "commit", "-m", "hong")
    return tag


@pytest.mark.skipif(git.co_git() is None, reason="cần git")
def test_rollback_ve_known_good_gan_nhat(du_an):
    """tc PROJECT-07: "Sau sửa hỏng → rollback → build đạt". Không nêu `tag` thì lấy known-good
    GẦN NHẤT — đó là mặc định trong `input_schema`, và nó là lý do năng lực này dùng được trong
    lúc hoảng."""
    r, ctx, root, ws = du_an
    _kho_git(root)
    out = r.invoke("project.rollback", {}, ctx).result

    assert (root / "src" / "main.c").read_text(encoding="utf-8") == "int main(void){return 0;}\n"
    assert out["state"]["commit"]
    assert git.nhanh_hien_tai(root) == "auto/rollback"


@pytest.mark.skipif(git.co_git() is None, reason="cần git")
def test_FEATURES_khoi_phuc_tu_tag(du_an):
    """Bước 2: "FEATURES.json khôi phục từ tag". Để lại bản `passing` của lần hỏng thì bảng tiến
    độ nói dự án đang chạy tốt trong khi mã vừa bị quay lui — và đó là bảng người ta nhìn để
    quyết định làm gì tiếp."""
    r, ctx, root, ws = du_an
    _kho_git(root)
    out = r.invoke("project.rollback", {}, ctx).result
    f = json.loads((root / ".eide" / "FEATURES.json").read_text(encoding="utf-8"))["features"]
    assert f[0]["status"] == "failing"
    assert out["state"]["features"] == 1
    assert out["state"]["features_restored"] is True


@pytest.mark.skipif(git.co_git() is None, reason="cần git")
def test_FEATURES_khong_duoc_git_theo_doi_thi_noi_ra(du_an):
    """Nếu `.eide/FEATURES.json` không nằm trong git thì `checkout -B <tag>` không đưa nó về, và
    bảng tiến độ của lần hỏng nằm lại sau khi mã đã quay lui.

    Rollback vẫn chạy — quay lui MÃ là việc chính — nhưng `state` phải nói rõ. Một rollback báo
    thành công trong khi FEATURES.json còn ghi `passing` là lời hứa sai ở đúng chỗ người ta nhìn
    để quyết định làm gì tiếp.
    """
    r, ctx, root, ws = du_an
    (root / ".eide" / ".gitignore").write_text("store/\nsession/\nindex/\nFEATURES.json\n",
                                               encoding="utf-8")
    _kho_git(root)
    out = r.invoke("project.rollback", {}, ctx).result
    assert out["state"]["features_restored"] is False


@pytest.mark.skipif(git.co_git() is None, reason="cần git")
def test_working_tree_ban_bao_E7001(du_an):
    """`E7001 UNDO_FAILED` của hợp đồng. Quay lui khi còn thay đổi chưa commit là cách nhanh
    nhất để mất chúng — và người gọi rollback đang hoảng, không phải đang cẩn thận."""
    r, ctx, root, ws = du_an
    _kho_git(root)
    (root / "src" / "main.c").write_text("// sửa dở dang\n", encoding="utf-8")
    run = r.invoke("project.rollback", {}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E7001"


@pytest.mark.skipif(git.co_git() is None, reason="cần git")
def test_tep_moi_chua_commit_cung_chan_rollback(du_an):
    """Trường hợp git KHÔNG tự chặn — và là lý do phép kiểm working tree phải là của năng lực.

    Một tệp mới chưa commit không xung đột với tag nào, nên `checkout -B` chạy trót lọt và mang
    tệp dở dang ấy sang nhánh `auto/rollback`. Kết quả: một bản "đã quay lui về trạng thái tốt"
    có lẫn mã đang viết dở — đúng thứ người gọi rollback muốn thoát khỏi.

    (Kiểm đột biến bắt được chỗ này: với tệp ĐÃ commit rồi sửa, git tự từ chối và cũng nói
    "stash", nên test trước đó xanh cả khi phép kiểm bị gỡ bỏ.)
    """
    r, ctx, root, ws = du_an
    _kho_git(root)
    (root / "src" / "dang_lam.c").write_text("// viết dở\n", encoding="utf-8")
    run = r.invoke("project.rollback", {}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E7001"
    assert git.nhanh_hien_tai(root) != "auto/rollback"
    assert (root / "src" / "dang_lam.c").exists()


@pytest.mark.skipif(git.co_git() is None, reason="cần git")
def test_tag_khong_co_bao_E2000(du_an):
    r, ctx, root, ws = du_an
    _kho_git(root)
    run = r.invoke("project.rollback", {"tag": "known-good/1999-01-01"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


@pytest.mark.skipif(git.co_git() is None, reason="cần git")
def test_khong_co_tag_nao_bao_E2000(du_an):
    """Kho chưa có known-good nào: nói thẳng, đừng quay về commit đầu tiên. "Trạng thái tốt gần
    nhất" mà không ai từng đánh dấu là tốt thì không tồn tại."""
    r, ctx, root, ws = du_an
    git.dam_bao_kho(root)
    git.chay(root, "config", "user.email", "t@t")
    git.chay(root, "config", "user.name", "t")
    git.chay(root, "add", "-A")
    git.chay(root, "commit", "-m", "dau")
    run = r.invoke("project.rollback", {}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"
