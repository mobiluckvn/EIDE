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
    reg = get_registry()
    assert reg.get("tool.write").spec.gate == "G-TOOL"
    assert reg.get("search.web").spec.gate == "G-SRC"
    assert reg.get("code.merge").spec.gate == "G3"
