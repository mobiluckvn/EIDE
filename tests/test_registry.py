"""Registry ≡ docs/spec (SDD-04 §4; CDS-12)."""
import json

import pytest

from eide_core.errors import EideError
from eide_core.paths import spec_dir
from eide_core.registry import get_registry

#: Số năng lực trong đặc tả — ĐỌC từ `cds.json`, không gõ tay.
#:
#: Con số này đổi mỗi lần bộ hồ sơ thêm năng lực (238 → 241 ở v2.0), và viết cứng
#: nó biến mỗi lần mở rộng đặc tả thành một bài test đỏ ở chỗ không liên quan —
#: cái giá là người ta sửa số cho qua mà không đọc xem năng lực mới có đúng không.

SO_NANG_LUC = len(json.loads((spec_dir() / "cds.json").read_text(encoding="utf-8")))


def test_loads_all_capabilities_from_spec():
    reg = get_registry()
    assert len(reg.list()) == SO_NANG_LUC
    assert len(reg.namespaces()) == 27
    assert "tool.write" in reg and "project.create" in reg


def test_unknown_capability_is_E1001():
    with pytest.raises(EideError) as e:
        get_registry().get("foo.bar")
    assert e.value.code == "E1001" and e.value.name == "UNKNOWN_CAPABILITY"


def test_input_validation_E1000():
    reg = get_registry()
    with pytest.raises(EideError) as e:
        reg.validate_input("project.create", {"nope": 1})
    assert e.value.code == "E1000"
    reg.validate_input("project.create", {"text": "Tạo dự án robot"})


def test_gate_mapping():
    """Cổng SUY TỪ ĐẶC TẢ, không đoán theo nhóm (DEV-026, DEV-041).

    Ánh xạ theo nhóm là suy đoán của mã, và nó sai hai lần với hậu quả đo được. Lần đầu: cả
    `tool.*` vào G-TOOL làm `tool.write` không bao giờ chạy được, vì mọi quy tắc G-TOOL hỏi
    `tool.tested` mà công cụ chưa viết thì chưa test. Lần hai: 73 năng lực nhận cổng trong khi
    đặc tả chỉ nêu cổng cho 10, và ba nhóm nguyên vẹn nhận cổng không hợp đồng nào nhắc tới.

    Nay quét `steps`/`ask_when` của cds.json tìm tên cổng — mỗi mục trong bảng truy được về một
    câu trong hợp đồng.
    """
    reg = get_registry()
    # Hành động ĐI QUA cổng: tải một nguồn, nạp firmware, merge mã, phát hành gói.
    assert reg.get("search.fetch").spec.gate == "G-SRC"
    assert reg.get("target.flash").spec.gate == "G-OPS"
    assert reg.get("code.merge").spec.gate == "G3"
    assert reg.get("registry.publish").spec.gate == "G5"
    assert reg.get("tool.run").spec.gate == "G-TOOL"

    # `search.web` KHÔNG đi G-SRC: hợp đồng ghi "không tải" — nó chỉ liệt kê ứng viên, và
    # domain/license/hash mà G-SRC hỏi chưa tồn tại ở bước ấy. `search.fetch` mới là nơi tải.
    assert reg.get("search.web").spec.gate == "*"
    assert reg.get("tool.write").spec.gate == "*"

    # G-FACT không xuất hiện ở tầng Router: nó là cổng của một FACT, không phải của một hành
    # động — mọi quy tắc của nó hỏi thuộc tính dữ liệu (tier, confidence, second_source). Năng
    # lực HỎI nó cho từng fact; để Router chặn ở cửa thì `kg.review_facts` bị chính cổng mà nó
    # phục vụ chặn lại, và không fact nào được duyệt bao giờ.
    assert reg.get("kg.review_facts").spec.gate == "*"
    assert not [c for c in reg.list() if c.spec.gate == "G-FACT"]
