"""Registry ≡ docs/spec (SDD-04 §4; CDS-12)."""
import pytest

from eide_core.errors import EideError
from eide_core.registry import get_registry


def test_loads_all_capabilities_from_spec():
    reg = get_registry()
    assert len(reg.list()) == 238
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
    """`cds.json` không có trường `gate`; ánh xạ theo nhóm là suy đoán của mã (DEV-026).

    `tool.*` KHÔNG đi cổng G-TOOL ở tầng Router. CDS-12.3 chỉ nói `gate=G-TOOL` ở TOOL-05
    bước 2, tức `tool.run` — và chính `tool.run` hỏi cổng ấy với đặc trưng thật của công cụ,
    vì đó là nơi duy nhất `tested`/`effects`/`uses_ok` tồn tại. Gán cả nhóm vào G-TOOL từng
    làm `tool.write` không bao giờ chạy được: mọi quy tắc G-TOOL đều hỏi `tool.tested`, mà
    một công cụ chưa viết thì đương nhiên chưa test.
    """
    reg = get_registry()
    assert reg.get("tool.write").spec.gate == "*"
    assert reg.get("search.web").spec.gate == "G-SRC"
    assert reg.get("code.merge").spec.gate == "G3"
