"""Mã ≡ spec: mọi mã lỗi trong mã có trong errors.json; mọi phương thức RPC có trong openrpc.json;
mọi @capability trỏ tới id trong cds.json; capabilities/*.yaml khớp cds.json; docstring có `Spec:`."""
import json
import re
from pathlib import Path

import yaml

from eide_core.paths import repo_root, spec_dir
from eide_core.registry import get_registry

SRC = repo_root() / "src"


def test_error_codes_used_exist():
    known = {e["code"] for e in json.loads((spec_dir() / "api" / "errors.json").read_text(encoding="utf-8"))}
    used = set()
    for f in SRC.rglob("*.py"):
        used |= set(re.findall(r'EideError\("(E\d{4})"', f.read_text(encoding="utf-8")))
    assert used <= known, used - known


def test_rpc_methods_exist_in_openrpc():
    from eide.daemon.rpc import Daemon

    names = {m["name"] for m in json.loads((spec_dir() / "api" / "openrpc.json").read_text(encoding="utf-8"))["methods"]}
    assert set(Daemon().methods) <= names


def test_capability_decorators_point_to_spec_ids():
    reg = get_registry()
    for f in (SRC / "eide" / "caps").glob("*.py"):
        for cid in re.findall(r'@capability\("([a-z_.]+)"', f.read_text(encoding="utf-8")):
            assert cid in reg, cid
            assert reg.get(cid).implemented


def test_yaml_matches_cds():
    cds = {c["id"]: c for c in json.loads((spec_dir() / "cds.json").read_text(encoding="utf-8"))}
    for f in (spec_dir() / "capabilities").glob("*.yaml"):
        for row in yaml.safe_load(f.read_text(encoding="utf-8")):
            assert row["id"] in cds and row["code"] == cds[row["id"]]["code"], row["id"]


def test_handlers_cite_spec_in_docstring():
    reg = get_registry()
    for c in reg.list(implemented=True):
        assert c.handler.__doc__ and c.handler.__doc__.lstrip().startswith("Spec:"), c.spec.id


def test_deviations_have_status():
    text = (repo_root() / "docs" / "DEVIATIONS.md").read_text(encoding="utf-8")
    rows = [l for l in text.splitlines() if l.startswith("| DEV-")]
    for r in rows:
        assert r.rstrip("| ").split("|")[-1].strip() in {"Mở", "Đã duyệt", "Bác"} or "Đã cập nhật tài liệu" in r, r
