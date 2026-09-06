"""Store SQLite và di trú — WI-002.

Spec: DDD-14 §5 (lịch migration, quy trình `eide migrate`); DDL trong docs/spec/data/schema.sql;
API-15 §3 E6003 MIGRATION_REQUIRED; API-15 §5 sự kiện ledger `store.migrate` {from_version, to_version}.

Quy trình §5, từng chữ: đọc `PRAGMA user_version`, chạy tuần tự các migration còn thiếu trong MỘT
giao dịch, ghi ledger `store.migrate`, sao lưu `store.sqlite.bak-<version>` TRƯỚC khi chạy,
migration chỉ thêm bảng/cột (không xóa) cho tới v1.0.

Vì sao migration là tệp .sql trong `src/` chứ không phải trong `docs/spec/`: `docs/spec/` là bản
sinh ra từ `docs/ho-so/nguon/` và không được sửa tay (CLAUDE.md §4, hook guard_spec). Lịch
migration thì phải viết tay vì §5 chia bảng theo mốc, còn schema.sql chỉ là ảnh chụp mô hình đầy
đủ. Chỗ nối hai bên là `tests/test_store.py::test_migration_khop_schema_sql` — nó dựng một kho từ
migration, một kho từ schema.sql, rồi so từng bảng từng cột. Mã không lệch spec được mà test vẫn xanh.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import sqlite3
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from eide_core.errors import EideError
from eide_core.ledger import Ledger

MIGRATIONS_DIR = Path(__file__).parent / "migrations"

# Tệp migration của store chính đặt tên `NNNN_<tên>.sql`; `user_version` sau khi chạy = NNNN.
# Tệp mang tiền tố `index_` thuộc index.sqlite riêng (§5, 0003) và cố ý không vào dãy này.
STORE_NAME = "store.sqlite"
INDEX_NAME = "index.sqlite"


def migrations() -> list[dict[str, Any]]:
    """Các migration của store chính, sắp theo phiên bản tăng dần."""
    out = []
    for f in sorted(MIGRATIONS_DIR.glob("[0-9][0-9][0-9][0-9]_*.sql")):
        out.append({"version": int(f.name[:4]), "name": f.stem, "sql": f.read_text(encoding="utf-8")})
    return out


LATEST_VERSION = max((m["version"] for m in migrations()), default=0)


def current_version(conn: sqlite3.Connection) -> int:
    return int(conn.execute("PRAGMA user_version").fetchone()[0])


def _connect(path: Path) -> sqlite3.Connection:
    """Mở kết nối với WAL và khóa ngoại bật.

    Cả hai PRAGMA phải chạy NGOÀI giao dịch: `journal_mode` đổi được chỉ khi không có giao dịch
    mở, còn `foreign_keys` bị SQLite lặng lẽ bỏ qua nếu đặt bên trong. Đặt nhầm chỗ thì khóa
    ngoại không được cưỡng chế và không có gì báo — nên có test riêng cho nó.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path, isolation_level=None)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def migrate(path: Path | str, *, ledger: Ledger | None = None, target: int | None = None,
            actor: str = "agent") -> dict[str, Any]:
    """Đưa store lên `target` (mặc định phiên bản mới nhất). Trả {from_version, to_version, applied, backup}."""
    path = Path(path)
    target = LATEST_VERSION if target is None else target
    con_lai = [m for m in migrations() if m["version"] > current_version(_peek(path)) and m["version"] <= target]
    tu = current_version(_peek(path))
    if not con_lai:
        return {"from_version": tu, "to_version": tu, "applied": [], "backup": None}

    # Sao lưu TRƯỚC khi chạy, và chỉ khi đã có gì để mất. Tên mang phiên bản CŨ — đó là thứ
    # người ta cần biết khi quay lại: bản sao này là trạng thái nào.
    backup = None
    if path.exists():
        backup = path.with_name(f"{path.name}.bak-{tu}")
        shutil.copy2(path, backup)

    conn = _connect(path)
    try:
        conn.execute("BEGIN")
        for m in con_lai:
            for cau in _cau_lenh(m["sql"]):
                conn.execute(cau)
            conn.execute(f"PRAGMA user_version = {int(m['version'])}")
        conn.execute("COMMIT")
    except Exception:
        conn.execute("ROLLBACK")
        conn.close()
        # Kho mới tinh: ROLLBACK đưa nội dung về rỗng nhưng tệp vẫn còn, kèm -wal/-shm. Để lại
        # một store.sqlite rỗng ở chỗ trước đó không có gì là nói dối về trạng thái — lần mở sau
        # sẽ thấy "có kho, user_version=0" thay vì "chưa có kho". Xóa cả ba tệp.
        if not backup:
            for hau_to in ("", "-wal", "-shm"):
                p = path.with_name(path.name + hau_to)
                if p.exists():
                    p.unlink()
        raise
    den = current_version(conn)
    conn.close()

    kq = {"from_version": tu, "to_version": den, "applied": [{"version": m["version"], "name": m["name"]} for m in con_lai],
          "backup": str(backup) if backup else None}
    if ledger:
        ledger.append("store.migrate", {"from_version": tu, "to_version": den,
                                        "applied": [m["name"] for m in con_lai]}, actor=actor)
    # Di trú là con đường duy nhất một store ra đời, nên đây là chỗ đặt niêm phong đầu tiên.
    # Nhờ vậy `verify_seal` được phép coi "thiếu niêm" là "ghi ngoài cổng" (PROJECT-02 bước 2).
    write_seal(path, ledger)
    return kq


# ---------- niêm phong toàn vẹn (PROJECT-02 bước 2; DEVIATIONS DEV-007) ----------

def content_digest(conn: sqlite3.Connection) -> str:
    """Vân tay của NỘI DUNG store, không phải của tệp.

    Băm byte thô của store.sqlite thì vô dụng: WAL, checkpoint, VACUUM và cả thứ tự trang đều
    đổi tệp mà không đổi một dòng dữ liệu nào — mỗi lần mở sẽ báo "ghi ngoài cổng" cho một kho
    chưa ai chạm tới. Nên băm phần logic: các bảng theo thứ tự tên, mỗi bảng các dòng đã sắp,
    thành một chuỗi xác định.
    """
    h = hashlib.sha256()
    ten = [r[0] for r in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
    for t in ten:
        h.update(f"\x00T{t}".encode())
        cot = [r[1] for r in conn.execute(f"PRAGMA table_info({t})")]
        h.update(("|".join(cot)).encode())
        thu_tu = ", ".join(f'"{c}"' for c in cot)
        for row in conn.execute(f"SELECT * FROM {t} ORDER BY {thu_tu}"):  # noqa: S608 — tên cột từ PRAGMA
            h.update(b"\x00R")
            h.update(json.dumps(list(row), ensure_ascii=False, default=str, sort_keys=True).encode())
    return h.hexdigest()


def seal_path(db: Path | str) -> Path:
    db = Path(db)
    return db.with_name(db.name + ".seal.json")


def write_seal(db: Path | str, ledger: Ledger | None = None) -> dict[str, Any]:
    """Niêm phong store sau một lần ghi hợp lệ (qua cổng).

    Buộc vân tay nội dung với đầu chuỗi hash của ledger — đó chính là "hash store vs
    ledger.last_hash" trong CDS PROJECT-02 bước 2.
    """
    db = Path(db)
    conn = _connect(db)
    seal = {"content_hash": content_digest(conn),
            "ledger_last_hash": getattr(ledger, "_last_hash", None) if ledger else None,
            "user_version": current_version(conn),
            "at": datetime.now(UTC).isoformat()}
    conn.close()
    seal_path(db).write_text(json.dumps(seal, ensure_ascii=False, indent=2), encoding="utf-8")
    return seal


def verify_seal(db: Path | str) -> tuple[bool, dict[str, Any]]:
    """(khớp, chi tiết). Không có niêm phong cũng là không khớp: store hợp lệ luôn được niêm."""
    db = Path(db)
    p = seal_path(db)
    if not p.exists():
        return False, {"reason": "thiếu niêm phong", "seal": None}
    seal = json.loads(p.read_text(encoding="utf-8"))
    conn = _connect(db)
    hien = content_digest(conn)
    conn.close()
    if hien != seal.get("content_hash"):
        return False, {"reason": "vân tay nội dung lệch", "expected": seal.get("content_hash"), "found": hien}
    return True, {"seal": seal}


def open_store(path: Path | str) -> sqlite3.Connection:
    """Mở store, từ chối nếu chưa di trú (E6003 MIGRATION_REQUIRED — API-15 §3)."""
    path = Path(path)
    if not path.exists():
        raise EideError("E6003", f"Chưa có store tại {path} — chạy `eide migrate`",
                        found=0, expected=LATEST_VERSION, remedy="eide migrate")
    conn = _connect(path)
    v = current_version(conn)
    if v != LATEST_VERSION:
        conn.close()
        raise EideError("E6003", f"store user_version={v}, cần {LATEST_VERSION} — chạy `eide migrate`",
                        found=v, expected=LATEST_VERSION, remedy="eide migrate")
    return conn


def open_index(path: Path | str) -> sqlite3.Connection:
    """Mở (và dựng nếu chưa có) index.sqlite — DDD-14 §5 migration 0003, cơ sở dữ liệu riêng.

    Không có user_version: chỉ mục và FTS5 dựng lại được từ nguồn, nên nó không cần lịch di trú.
    """
    conn = _connect(Path(path))
    conn.executescript((MIGRATIONS_DIR / "index_0003_m1_index.sql").read_text(encoding="utf-8"))
    return conn


def open_session_db(path: Path | str) -> sqlite3.Connection:
    """Mở (và dựng nếu chưa có) session.sqlite — MEM-11 §2 M2, DDD-14 §2.25.

    Không có user_version, cùng lý do với index.sqlite: một phiên dựng lại được bằng cách mở
    lại dự án, nên nó không cần lịch di trú.
    """
    conn = _connect(Path(path))
    conn.executescript((MIGRATIONS_DIR / "session_db.sql").read_text(encoding="utf-8"))
    return conn


def session_path(project_dir: Path | str) -> Path:
    return Path(project_dir) / ".eide" / "session" / "session.sqlite"


def store_path(project_dir: Path | str) -> Path:
    """`.eide/store/store.sqlite` — cấu trúc do project.create dựng (SDD-04 §6)."""
    return Path(project_dir) / ".eide" / "store" / STORE_NAME


def index_path(project_dir: Path | str) -> Path:
    return Path(project_dir) / ".eide" / "index" / INDEX_NAME


def _cau_lenh(sql: str) -> list[str]:
    """Tách tệp .sql thành từng câu lệnh.

    Không dùng `Connection.executescript`: nó COMMIT giao dịch đang mở trước khi chạy, nên cả
    dãy migration không còn là một đơn vị nguyên tử như DDD-14 §5 đòi — 0002 hỏng mà 0001 vẫn
    nằm lại trong kho, kèm `user_version` đã tăng. Test
    `test_migrate_mot_giao_dich_hong_thi_khong_doi_gi` bắt đúng chỗ đó.

    Tách bằng `sqlite3.complete_statement` chứ không phải `sql.split(";")`: hàm ấy hiểu chuỗi
    ký tự và chú thích, nên một dấu chấm phẩy nằm trong chuỗi không cắt nhầm câu lệnh.
    """
    out, buf = [], ""
    for dong in sql.splitlines(keepends=True):
        buf += dong
        if sqlite3.complete_statement(buf):
            if buf.strip():
                out.append(buf)
            buf = ""
    if buf.strip():
        out.append(buf)
    return out


def _peek(path: Path) -> sqlite3.Connection:
    """Đọc user_version mà không tạo tệp nếu chưa có."""
    if not path.exists():
        return sqlite3.connect(":memory:")
    return sqlite3.connect(path)
