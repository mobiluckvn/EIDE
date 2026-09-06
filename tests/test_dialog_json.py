"""`docs/ho-so/nguon/dialog.json` — nguồn của DPS-09 §1, §3, §5. DEVIATIONS DEV-019.

Tệp này đã MẤT khỏi kho và được dựng lại từ chính docx DPS-09 (`scripts/khoi_phuc_dialog_json.py`,
06/09/2026, chủ sản phẩm duyệt). Bằng chứng bản dựng lại đúng: sinh lại DPS-09 rồi so nội dung
với bản trong kho — 157/157 khối trùng khớp, chỉ thừa một mục tham khảo đến từ `eide_common.js`
chứ không đến từ đây; CXD-10 (không dùng dialog.json) lệch đúng cùng một khối ấy.

Các test dưới đây chốt HÌNH DẠNG mà `dps.js` giả định. Vòng đối chiếu docx đầy đủ nằm ở
`scripts/sinh_tai_lieu.sh dps --kiem` vì nó cần node và `node_modules`.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

NGUON = Path(__file__).resolve().parents[1] / "docs" / "ho-so" / "nguon"
DPS_JS = NGUON / "dps.js"


@pytest.fixture(scope="module")
def d() -> dict:
    return json.loads((NGUON / "dialog.json").read_text(encoding="utf-8"))


def test_co_du_ba_khoa_dps_js_can(d):
    """Khóa nào `dps.js` dùng thì tệp phải có — thiếu một khóa là DPS-09 không sinh lại được,
    và đó chính là tình trạng DEV-019 mô tả."""
    can = set(re.findall(r"\bD\.([A-Za-z_][A-Za-z0-9_]*)", DPS_JS.read_text(encoding="utf-8")))
    assert can, "không tìm thấy chỗ nào dùng D.* trong dps.js — bộ rút hỏng"
    assert can <= set(d), f"dialog.json thiếu: {sorted(can - set(d))}"


def test_WHERE_ba_cot(d):
    assert all(len(r) == 3 for r in d["WHERE"]), "T() dựng bảng 3 cột ở §1"
    assert len(d["WHERE"]) == 5


def test_RULES_du_D1_den_D8_bon_cot(d):
    """DPS-09 §3 tên là "Tám quy tắc hội thoại D1–D8" — thiếu một quy tắc là thiếu một quy tắc
    mà Orchestrator phải hiện thực, không phải thiếu một dòng bảng."""
    assert [r[0] for r in d["RULES"]] == [f"D{i}" for i in range(1, 9)]
    assert all(len(r) == 4 for r in d["RULES"])


def test_SCENARIOS_du_Z01_den_Z10_tam_truong(d):
    """§5: mười kịch bản, mỗi kịch bản tám phần tử (id, tiêu đề, và sáu dòng bảng).

    STP-05 TC-59…TC-64 lấy chính mười kịch bản này làm bộ kiểm thử bắt buộc, nên số lượng và
    thứ tự không phải chuyện trình bày.
    """
    assert [z[0] for z in d["SCENARIOS"]] == [f"Z-{i:02d}" for i in range(1, 11)]
    for z in d["SCENARIOS"]:
        assert len(z) == 8, f"{z[0]} có {len(z)} phần tử, chờ 8"
        assert all(isinstance(x, str) and x.strip() for x in z), f"{z[0]} có ô rỗng"


def test_khong_con_danh_dau_dam_tu_dong(d):
    """`T()` tự in đậm hàng tiêu đề và CỘT ĐẦU (`bold: i === 0`), nên nguồn không được chứa `**`
    ở cột đầu — nếu có thì bản dựng lại đang bịa ra đánh dấu và docx sẽ ra `****D1****`."""
    for r in d["RULES"] + d["WHERE"]:
        assert not r[0].startswith("**"), f"cột đầu còn đánh dấu tự động: {r[0]!r}"
    for z in d["SCENARIOS"]:
        assert not z[0].startswith("**")
