#!/usr/bin/env python3
"""Dựng DỰ ÁN MẪU đủ hiện vật — để `--do-noi-dung` đo được cả 77 mục.

    python scripts/du_an_mau.py [--ra <thư mục>]

## Vì sao cần

Bộ dò nội dung mở từng màn trên một dự án THẬT rồi tìm dấu hiệu của từng thành phần bắt buộc.
Nhưng phần lớn màn chỉ vẽ khi có dữ liệu loại của nó, và **không dự án nào trong workspace có
đủ mười loại hiện vật cùng lúc**: dự án AVR có 290 fact mà không có yêu cầu, không lược đồ,
không kế hoạch, không tài liệu. Đo 23/09/2026: 18 trong 77 mục KHÔNG ĐO ĐƯỢC vì lý do ấy —
tức gần một phần tư hợp đồng giao diện chưa từng có bằng chứng.

"Không đo được" là câu trả lời trung thực, nhưng nó không phải câu trả lời cuối cùng. Dựng một
dự án có đủ mọi loại thì con số 77 mới nói được điều gì.

## Đây là FIXTURE ĐO, không phải một dự án thật — và giới hạn ấy phải nói ra

Script ghi thẳng vào `store.sqlite` rồi niêm lại bằng `store.write_seal`, **không đi qua Router
và không đi qua cổng chính sách**. Nó vì thế chứng minh được đúng MỘT điều: *màn hình vẽ đúng
khi có dữ liệu*. Nó KHÔNG chứng minh rằng các năng lực sinh ra được dữ liệu ấy — việc đó thuộc
về `make check` và về những lượt chạy thật.

Đi đường này thay vì gọi năng lực thật vì phần lớn năng lực sinh hiện vật (`req.classify`,
`doc.generate`, `plan.create`) đều gọi mô hình: chúng tốn tiền, cần mạng, và kết quả đổi theo
từng lượt — ba tính chất biến một fixture thành thứ không lặp lại được.

Dữ liệu điền là dữ liệu THẬT về ATmega328P (bộ nhớ, ngoại vi, chân) chứ không phải chuỗi giả:
một bảng đầy `foo`/`bar` vẫn làm bộ dò xanh, nhưng nhìn vào ảnh chụp thì không ai biết màn ấy
có đọc được không.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

GOC = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(GOC / "src"))

from eide_core import store  # noqa: E402
from eide_core.ledger import Ledger  # noqa: E402
from eide_core.policy import PolicyGate  # noqa: E402
from eide_core.router import Context, Router  # noqa: E402

TEN = "mau-do-giao-dien"


def _now() -> str:
    from datetime import UTC, datetime
    return datetime.now(UTC).isoformat()


def _tao_du_an(ws: Path) -> Path:
    """Tạo dự án bằng ĐÚNG năng lực `project.create` — phần này KHÔNG đi tắt.

    Khung dự án (`.eide/`, store đã di trú, `autonomy.yaml`, niêm) phải giống hệt dự án thật,
    nếu không thì thứ đo được là một khung khác với khung người dùng có.
    """
    r = Router(gate=PolicyGate(), ledger=Ledger(ws / "ledger-tao.jsonl"))
    kq = r.invoke("project.create", {"text": f"{TEN} — dự án mẫu để đo giao diện"},
                  Context(project_dir=ws))
    if kq.status != "done" or not kq.result:
        raise SystemExit(f"project.create hỏng: {kq.error}")
    goc = Path(kq.result["path"])
    store.migrate(store.store_path(goc))
    return goc


def _ghi(c, bang: str, hang: dict) -> None:
    cot = ",".join(hang)
    dau = ",".join("?" * len(hang))
    c.execute(f"INSERT OR REPLACE INTO {bang} ({cot}) VALUES ({dau})", tuple(hang.values()))


def _co_cot(c, bang: str) -> set[str]:
    return {r[1] for r in c.execute(f"PRAGMA table_info({bang})")}


def _seed(goc: Path) -> dict[str, int]:
    """Điền một hàng cho MỖI loại hiện vật mà một màn cần.

    Lọc theo cột CÓ THẬT trong bảng (`_co_cot`) thay vì viết cứng danh sách cột: schema đổi theo
    migration, và một script fixture vỡ mỗi lần thêm cột là một script người ta xoá đi.
    """
    db = store.store_path(goc)
    dem: dict[str, int] = {}
    with store.open_store(db) as c:
        bang_co = {r[0] for r in c.execute(
            "SELECT name FROM sqlite_master WHERE type='table'")}

        def them(bang: str, hang: dict) -> None:
            if bang not in bang_co:
                return
            loc = {k: v for k, v in hang.items() if k in _co_cot(c, bang)}
            _ghi(c, bang, loc)
            dem[bang] = dem.get(bang, 0) + 1

        # --- nguồn + fact: nền của hộ chiếu chip (S5) và bản đồ tri thức (S7)
        them("source", {"id": "s_mau_ds", "uri": "ATmega328P-datasheet.pdf", "kind": "datasheet",
                        "tier": "gold", "license": "vendor-eula", "fetched_at": _now(),
                        "size_bytes": 12_345_678, "hash": "mau" * 10})
        them("source", {"id": "s_mau_svd", "uri": "ATmega328P.svd", "kind": "svd",
                        "tier": "gold", "license": "Apache-2.0", "fetched_at": _now(),
                        "size_bytes": 234_567, "hash": "svd" * 10})
        # Hộ chiếu TRƯỚC fact: `passport_fact.passport_id → passport.id`.
        them("passport", {"id": "microchip.atmega328p@1.0.0", "kind": "chip",
                          "header": json.dumps({"chip": "ATmega328P", "isa": "avr8"}),
                          "created_at": _now(), "badges": json.dumps(["verified"]),
                          "pinned_by": "human"})

        # `subject` theo ĐÚNG khuôn lõi dùng: `chip:<id>/mem:<tên>`, `…/periph:<tên>`. Bản đầu
        # viết `chip/microchip.atmega328p` — sai khuôn, nên `passport.query` không tìm thấy fact
        # nào và màn Hộ chiếu chip vẫn rỗng dù store có dữ liệu. Một fixture sai khuôn đo ra
        # đúng kết luận "màn hỏng" cho một màn không hỏng.
        CHIP = "chip:microchip.atmega328p"
        for i, (ch, vt, gt, dv) in enumerate([
            (f"{CHIP}/mem:FLASH", "memory_size", "32768", "byte"),
            (f"{CHIP}/mem:FLASH", "base_address", "0", "byte"),
            (f"{CHIP}/mem:SRAM", "memory_size", "2048", "byte"),
            (f"{CHIP}/mem:EEPROM", "memory_size", "1024", "byte"),
            (f"{CHIP}/periph:TWI", "base_address", "184", "byte"),
            (f"{CHIP}/periph:USART0", "base_address", "192", "byte"),
        ]):
            # `value` và `locator` là JSON trong store (DDD-14 §2) — ghi chuỗi trần làm
            # `passport.query` ném `JSONDecodeError` và cả màn Hộ chiếu chip trắng. Một fixture
            # sai định dạng đo ra "màn hỏng" cho một màn không hỏng.
            them("fact", {"id": f"f_mau_{i}", "subject": ch, "predicate": vt,
                          "value": json.dumps(int(gt)),
                          "unit": dv, "source_id": "s_mau_ds",
                          "locator": json.dumps({"page": 12 + i, "bbox": [72, 100, 300, 140]}),
                          "method": "parser", "tier": "gold", "confidence": 0.95,
                          "status": "normalized", "layer": "K2"})
            them("passport_fact", {"passport_id": "microchip.atmega328p@1.0.0",
                                   "fact_id": f"f_mau_{i}"})
        # Một fact CHƯA DUYỆT — S5 đòi "số fact chưa duyệt, bấm được sang duyệt".
        them("fact", {"id": "f_mau_pending", "subject": f"{CHIP}/periph:SPI",
                      "predicate": "base_address", "value": json.dumps(76), "unit": "byte",
                      "source_id": "s_mau_svd",
                      "locator": json.dumps({"path": "svd:SPI"}), "method": "parser",
                      "tier": "silver", "confidence": 0.7, "status": "pending", "layer": "K2"})
        them("passport_fact", {"passport_id": "microchip.atmega328p@1.0.0",
                               "fact_id": "f_mau_pending"})
        # Hai fact CÙNG chủ thể + vị từ, khác giá trị → một XUNG ĐỘT thật cho S8. `method` khác
        # nhau để cột "vì sao mâu thuẫn" có cả hai vế ĐƯỢC KHAI và SUY RA.
        them("fact", {"id": "f_mau_a", "subject": f"{CHIP}/mem:FLASH",
                      "predicate": "page_size", "value": json.dumps(128), "unit": "byte",
                      "source_id": "s_mau_ds",
                      "locator": json.dumps({"page": 12}), "method": "parser",
                      "tier": "gold", "confidence": 0.95, "status": "normalized",
                      "layer": "K2"})
        them("fact", {"id": "f_mau_b", "subject": f"{CHIP}/mem:FLASH",
                      "predicate": "page_size", "value": json.dumps(64), "unit": "byte",
                      "source_id": "s_mau_svd",
                      "locator": json.dumps({"path": "svd:memory"}), "method": "inferred",
                      "tier": "silver", "confidence": 0.6, "status": "conflict",
                      "conflicts_with": "f_mau_a", "layer": "K2"})

        # --- module TRƯỚC `hw_map`: khoá ngoại `hw_map.module_id → module.id`. Thứ tự chèn là
        # một phần của fixture, không phải chi tiết trình bày.
        them("module", {"id": "M-001", "name": "cam_bien", "responsibility": "đọc I2C",
                        "arch_style": "layered", "status": "đang làm"})

        # --- chân/tài nguyên: hộ chiếu mạch (S6). Bảng là `hw_map` (module ↔ tài nguyên ↔
        # fact), không phải `net` — DDD-14 không có thực thể `net` riêng.
        for mod, res, vai in [("M-001", "PC4/SDA", "i2c_data"),
                              ("M-001", "PC5/SCL", "i2c_clock"),
                              ("M-001", "PIN7/VCC", "nguồn")]:
            them("hw_map", {"module_id": mod, "resource": res, "role": vai,
                            "fact_ids": json.dumps(["f_mau_a"])})
        # --- yêu cầu: S10. Một cái ĐO ĐƯỢC, một cái KHÔNG — cột "đo được" cần cả hai vế.
        them("requirement", {"id": "FR-001", "kind": "FR", "text":
                             "Đọc nhiệt độ từ cảm biến qua I2C mỗi 1000 ms",
                             "priority": "cao", "status": "đã duyệt",
                             "feasibility": "khả thi", "updated_at": _now()})
        them("requirement", {"id": "NFR-001", "kind": "NFR", "text":
                             "Hệ thống phải phản hồi nhanh và ổn định",
                             "priority": "trung bình", "status": "nháp",
                             "updated_at": _now()})
        them("adr", {"id": "ADR-001", "title": "Dùng I2C thay vì 1-Wire",
                     "decision": "Chọn I2C vì hộ chiếu có đủ fact thanh ghi TWI",
                     "status": "đã chốt", "citations": json.dumps(["f_mau_a"]), "at": _now()})

        # --- lược đồ: S11
        them("diagram", {"id": "D-001", "kind": "block", "lang": "mermaid",
                         "src": "graph TD; A[cam_bien] --> B[i2c]",
                         "path": "diagrams/kien-truc.mmd", "stale": 1,
                         "synced_with": "M-001", "at": _now()})

        # --- tài liệu: S12
        them("doc_artifact", {"id": "DOC-SRS", "type": "SRS", "version": "0.1",
                              "path": "docs/SRS.md", "status": "nháp",
                              "stale_sections": json.dumps(["3.2"]), "at": _now()})

        # --- tính năng + kế hoạch: S13
        them("feature", {"id": "FT-001", "title": "Đọc cảm biến qua I2C",
                         "status": "failing", "requirement_ids": json.dumps(["FR-001"]),
                         "updated_at": _now()})

        # --- điểm cần làm rõ: S9
        them("clarification", {"id": "CL-mau0001", "kind": "gap",
                               "text": "Chip của thiết bị thuộc kiến trúc tập lệnh nào?",
                               "status": "open", "source_cap": "env.check",
                               "suggestion": "avr8 | armv7e-m | rv32imac",
                               "created_at": _now()})
        them("clarification", {"id": "CL-mau0002", "kind": "gap",
                               "text": "Tần số bus I2C là bao nhiêu?",
                               "status": "answered", "source_cap": "code.write",
                               "answer": "400 kHz", "answered_by": "human",
                               "created_at": _now(), "answered_at": _now()})
        them("clarification_answer", {"id": "ca_mau1", "clar_id": "CL-mau0002",
                                      "answer": "400 kHz", "answered_by": "human",
                                      "at": _now()})

        # --- đơn vị mã: S8 "hệ quả — mã nào đang dùng con số này" tra qua `code_unit.cites`
        them("code_unit", {"id": "cu_mau1", "path": "src/cam_bien.c", "symbol": "doc_nhiet",
                           "hash": "mau" * 8, "cites": json.dumps(["f_mau_a"]),
                           "uses": json.dumps(["TWBR"]), "stale": 0, "module_id": "M-001"})

        # --- báo cáo công cụ: S19 bằng chứng G3, S15 kết quả test
        for t in ("build", "static", "test", "size", "review"):
            them("tool_report", {"id": f"tr_mau_{t}", "tool": t, "passed": 1,
                                 "tong": 12, "at": _now(),
                                 "metrics": json.dumps({"flash": 1234})})

        # S22 Registry đọc CHỈ MỤC registry nằm NGOÀI store (`registry` trong `models.yaml`),
        # không đọc một bảng nào — nên fixture này không dựng được nó. Nói ra ở đây thay vì để
        # người đọc báo cáo tưởng 77/77 đã phủ hết.
        c.commit()

    # --- kế hoạch nằm ở TỆP, không ở store (PLAN-03 ghi `.eide/plans/<feature>.json`)
    from eide.caps.plan import ghi_plan
    ghi_plan(goc, "FT-001",
             {"feature": "FT-001",
              "steps": [{"id": "s1", "cap": "passport.query", "goal": "đọc thanh ghi TWI",
                         "cites": ["f_mau_a"], "done_when": "có địa chỉ TWBR"},
                        {"id": "s2", "cap": "code.generate_module", "goal": "sinh driver",
                         "cites": ["f_mau_a"], "done_when": "biên dịch được"}],
              "missing": ["tần số thạch anh chưa có fact"],
              "estimate": {"cost_usd": 0.12}},
             {"decision": "ASK", "rule": "G1-02", "gate": "G1",
              "reason": "thiếu tri thức: tần số thạch anh", "run_id": "r_mau"})

    # --- TỆP tài liệu và lược đồ THẬT. Liên kết "lược đồ nào dùng trong tài liệu nào" đọc từ
    # chính văn bản (`doc.embed_diagram` chèn hình mà không ghi liên kết nào xuống store), nên
    # thiếu tệp thì cả S11 lẫn S12 không có gì để nối.
    (goc / "diagrams").mkdir(exist_ok=True)
    (goc / "diagrams" / "kien-truc.mmd").write_text(
        "graph TD\n  A[cam_bien] --> B[i2c]\n  B --> C[uart]\n", encoding="utf-8")
    (goc / "docs").mkdir(exist_ok=True)
    (goc / "docs" / "SRS.md").write_text(
        "# SRS — dự án mẫu\n\n"
        "## 3.1 Giao tiếp cảm biến\n\n"
        "Hệ thống đọc nhiệt độ qua I2C mỗi 1000 ms [f_mau_0].\n\n"
        "<!-- eide:diagram D-001 -->\n"
        "![Hình 1 — kiến trúc](../diagrams/kien-truc.mmd)\n\n"
        "## 3.2 Hiệu năng\n\n"
        "Hệ thống phải phản hồi nhanh.\n", encoding="utf-8")

    # --- mã nguồn: S14 cây tệp + constant-guard
    (goc / "src").mkdir(exist_ok=True)
    (goc / "src" / "cam_bien.c").write_text(
        "#include <avr/io.h>\n"
        "// eide:fact f_mau_a\n"
        "#define FLASH_SIZE 32768\n"
        "void doc_nhiet(void) { TWBR = 0x48; }\n", encoding="utf-8")

    # --- ĐÍCH ĐÃ GHIM: `constraints.yaml`. Bốn màn đọc từ đây chứ không từ store — S5 (hộ
    # chiếu chip), S6 (hộ chiếu mạch), S16 (nền tảng mô phỏng), S24 (chuỗi công cụ theo ISA).
    # Thiếu nó thì cả bốn hiện trạng thái rỗng "chưa ghim chip", và 9 mục không đo được.
    import yaml
    ct = goc / ".eide" / "constraints.yaml"
    d = yaml.safe_load(ct.read_text(encoding="utf-8")) if ct.exists() else {}
    d = d or {}
    d["target"] = {
        "chip": "microchip.atmega328p", "board": "arduino-uno", "isa": "avr8",
        "pins": {"isa": "avr8", "chip": "microchip.atmega328p@1.0.0",
                 "board": "arduino-uno@1.0.0"},
        "f_cpu": 16_000_000, "mcu": "atmega328p",
    }
    ct.write_text(yaml.safe_dump(d, allow_unicode=True, sort_keys=False), encoding="utf-8")

    # --- NỀN TẢNG MÔ PHỎNG: gọi năng lực THẬT, không viết tay `sim/platform.json`.
    #
    # Màn Mô phỏng chỉ ĐỌC tệp ấy (nó không tự dựng, vì `sim.build_platform` ghi vào dự án).
    # Viết tay một tệp nền tảng thì fixture sẽ hợp lệ kể cả khi năng lực hỏng — đúng loại
    # "xanh giả" mà cả bộ đo này sinh ra để chặn. Gọi thẳng handler thay vì qua Router vì lớp
    # này là fixture: nó không giả vờ đi qua cổng, và chỗ khác trong script cũng ghi thẳng.
    try:
        from eide.caps.sim import build_platform
        from eide_core.router import Context as _Ctx
        build_platform({"chip": "microchip.atmega328p", "board": "arduino-uno"},
                       _Ctx(project_dir=goc))
    except Exception as e:  # noqa: BLE001 — nói ra, đừng nuốt: thiếu nền tảng thì S16 rỗng
        print(f"  (!) sim.build_platform không chạy được: {type(e).__name__}: {e}")

    store.write_seal(store.store_path(goc))
    return dem


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ra", type=Path, default=Path.home() / "eide")
    a = ap.parse_args()
    a.ra.mkdir(parents=True, exist_ok=True)

    # Xoá bản cũ theo TIỀN TỐ, không theo tên gõ tay: `project.create` tự đặt slug từ câu mô tả
    # nên thư mục thật là `mau-do-giao-dien-du-an-mau-de-do-giao-dien`, không phải `TEN`. Xoá
    # nhầm tên thì mỗi lần chạy lại đẻ thêm một dự án và workspace đầy rác sau vài lượt.
    import shutil
    for cu in sorted(a.ra.glob(TEN + "*")):
        if (cu / ".eide").is_dir():
            shutil.rmtree(cu)
            print(f"đã xoá bản cũ: {cu.name}")

    t0 = time.time()
    goc = _tao_du_an(a.ra)
    dem = _seed(goc)
    print(f"dự án mẫu: {goc}")
    for k in sorted(dem):
        print(f"  {k:16s} {dem[k]}")
    print(f"({time.time() - t0:.1f}s)  đo bằng: "
          f"apps/eide/.build/debug/EideApp --do-noi-dung {goc}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
