"""VIEW-11 `view.doc_side_by_side` — hai vế của một trích dẫn ([DEV-133] nửa sau).

`tc` của hợp đồng là *"Vùng bôi sáng đúng bbox"*, và phần lõi chịu trách nhiệm cho hai thứ mà
giao diện không thể tự biết: đường dẫn nguồn TUYỆT ĐỐI, và `bbox` ghi theo quy ước nào.
"""
from __future__ import annotations

import json

from eide.caps.view import _sieu_bbox, _uri_tuyet_doi
from eide_core import store
from test_code import _du_an_git


def _fact(root, *, loc, uri="ds/rm0383.pdf"):
    db = store.store_path(root)
    with store.open_store(db) as c:
        c.execute("INSERT OR REPLACE INTO source (id, uri, kind, tier) VALUES (?,?,?,?)",
                  ("src_1", uri, "datasheet", "gold"))
        c.execute(
            "INSERT OR REPLACE INTO fact (id, subject, predicate, value, unit, method, tier,"
            " status, confidence, locator, source_id) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            ("f_1", "chip:x/periph:I2C1/reg:CR1", "base_address", json.dumps(1073763328),
             None, "extract", "gold", "verified", 1.0, json.dumps(loc), "src_1"))
        c.commit()


def test_tra_ca_hai_ve_cua_mot_trich_dan(tmp_path, workspace):
    r, ctx, root = _du_an_git(tmp_path, workspace)
    _fact(root, loc={"page": 42, "bbox": [72, 530, 180, 14]})
    run = r.invoke("view.doc_side_by_side", {"ref": "f_1"}, ctx)
    assert run.status == "done", run.error
    trai, phai = run.result["left"], run.result["right"]
    assert trai["page"] == 42 and trai["bbox"] == [72, 530, 180, 14]
    assert phai["kind"] == "fact" and phai["predicate"] == "base_address"


def test_uri_tra_ve_TUYET_DOI(tmp_path, workspace):
    """Giao diện mở tệp bằng đường dẫn này.

    Một đường tương đối mở từ thư mục làm việc của daemon trỏ vào chỗ khác chỗ người dùng
    nghĩ — hoặc không trỏ vào đâu cả, và nút "mở nguồn" khi ấy báo không tìm thấy một tệp đang
    nằm ngay trong dự án.
    """
    r, ctx, root = _du_an_git(tmp_path, workspace)
    _fact(root, loc={"page": 1}, uri="ds/rm0383.pdf")
    run = r.invoke("view.doc_side_by_side", {"ref": "f_1"}, ctx)
    uri = run.result["left"]["uri"]
    assert uri.startswith("/"), uri
    assert uri.endswith("ds/rm0383.pdf"), uri
    # URL thì GIỮ NGUYÊN — nối nó vào thư mục dự án là biến một địa chỉ mạng thành một đường
    # dẫn không tồn tại.
    assert _uri_tuyet_doi(ctx, "https://st.com/a.pdf") == "https://st.com/a.pdf"
    assert _uri_tuyet_doi(ctx, "/tuyet/doi.pdf") == "/tuyet/doi.pdf"
    assert _uri_tuyet_doi(ctx, None) is None


def test_noi_ra_bbox_ghi_theo_quy_uoc_nao():
    """**Nói ra, không quy đổi.** Bên vẽ không phân biệt được thì nó sẽ đoán, và một vùng bôi
    sáng lệch chỗ còn tệ hơn không bôi."""
    assert _sieu_bbox([72, 530, 180, 14])["bbox_dang"] == "rong-cao"
    assert _sieu_bbox([72, 530, 252, 544])["bbox_dang"] == "hai-goc"
    # Không kết luận được thì NÓI là không kết luận được: một ô bảng cao 1–2 pt khớp cả hai
    # cách đọc, và đoán ở đó là đặt vùng bôi sáng vào một chỗ có thể không phải nguồn.
    assert _sieu_bbox([72, 530, 73, 531])["bbox_dang"] == "khong-ro"
    assert _sieu_bbox([72, 530, -1, 14])["bbox_dang"] == "khong-ro"
    assert _sieu_bbox(None)["bbox_dang"] == "khong-ro"
    assert _sieu_bbox([1, 2, 3])["bbox_dang"] == "khong-ro"
    # Gốc toạ độ luôn được ghi: `PDFView` lật hay không tuỳ `displayMode`, và một phép lật
    # nhầm đưa vùng bôi sáng sang nửa kia của trang.
    assert _sieu_bbox([72, 530, 180, 14])["origin"] == "duoi-trai"


def test_code_unit_khong_co_trang_thi_noi_ra(tmp_path, workspace):
    """`page: None` là một câu trả lời — "thứ này không nằm trong trang nào" — chứ không phải
    một chỗ trống mà bên gọi phải tự đoán."""
    r, ctx, root = _du_an_git(tmp_path, workspace)
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT INTO code_unit (id, path, symbol, hash, cites) VALUES (?,?,?,?,?)",
                  ("cu_1", "src/i2c.c", "i2c_init", "h", json.dumps([])))
        c.commit()
    run = r.invoke("view.doc_side_by_side", {"ref": "cu_1"}, ctx)
    assert run.status == "done", run.error
    assert run.result["right"]["kind"] == "code"
    assert run.result["left"].get("page") is None


def test_ref_khong_co_thi_E2000(tmp_path, workspace):
    # `Router.invoke` BẮT `EideError` và trả một run `failed` — nó chỉ ném với lỗi xảy ra
    # TRƯỚC khi có run (ví dụ E1000 từ `input_schema`). Hai đường khác nhau.
    r, ctx, root = _du_an_git(tmp_path, workspace)
    run = r.invoke("view.doc_side_by_side", {"ref": "khong_co"}, ctx)
    assert run.status != "done"
    assert (run.error or {}).get("eide_code") == "E2000", run.error
