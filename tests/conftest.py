import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
# `tests/situations.py` là dữ liệu kiểm thử dùng chung (bảng dịch 45 tình huống của POL-17),
# không phải một test — nên nó được import bằng tên chứ không do pytest thu gom.
sys.path.insert(0, str(Path(__file__).resolve().parent))


@pytest.fixture
def workspace(tmp_path):
    return tmp_path / "ws"
