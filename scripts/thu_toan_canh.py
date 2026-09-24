"""Gom TOÀN BỘ trạng thái hệ thống của một ca kiểm thử vào một chỗ. [DEV-217]

Bằng chứng của một ca đang nằm rải ở sáu nơi: nhật ký giao diện, stdout của bộ lái, ledger,
store SQLite, session SQLite, và các tệp cấu hình trong `.eide/`. Muốn hiểu vì sao một ca
trượt thì phải mở cả sáu — và trong đợt [DEV-216], chính vì không đọc được mô hình đã NHẬN gì
và TRẢ gì mà ba giả thuyết sai lần lượt sống sót qua nhiều vòng đo.

Kết quả là **một tệp JSON cho máy** (`toan-canh.json`) và **một tệp Markdown cho người**
(`toan-canh.md`). Không tóm tắt, không cắt bớt ở tầng này: chỗ để quyết định cái gì đáng đọc
là lúc phân tích, không phải lúc thu thập.

Câu nhắc đầy đủ chỉ có mặt khi `EIDE_LOG_LLM` bật (xem `Gateway._ghi_day_du`).
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

#: Bảng nào đổ hết, bảng nào chỉ đếm. Ngưỡng này canh KÍCH THƯỚC, không canh tầm quan trọng:
#: `chunk` của chỉ mục RAG có thể hàng nghìn dòng văn bản datasheet và làm tệp gom vô dụng.
TRAN_DONG = 400


def _bang(db: Path) -> dict[str, Any]:
    """Đổ mọi bảng của một SQLite. Bảng quá lớn thì giữ số dòng + mẫu đầu."""
    if not db.exists():
        return {"_loi": f"không có {db.name}"}
    ra: dict[str, Any] = {}
    try:
        c = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        c.row_factory = sqlite3.Row
        ten = [r[0] for r in c.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
        for t in ten:
            try:
                n = c.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
                rows = [dict(r) for r in c.execute(f'SELECT * FROM "{t}" LIMIT {TRAN_DONG}')]
            except sqlite3.Error as e:
                ra[t] = {"_loi": str(e)}
                continue
            ra[t] = {"so_dong": n, "dong": rows,
                     **({"_cat_bot": n - len(rows)} if n > len(rows) else {})}
        c.close()
    except sqlite3.Error as e:
        return {"_loi": str(e)}
    return ra


def _jsonl(f: Path) -> list[dict[str, Any]]:
    if not f.exists():
        return []
    ra = []
    for d in f.read_text(encoding="utf-8", errors="replace").splitlines():
        if d.strip():
            try:
                ra.append(json.loads(d))
            except json.JSONDecodeError:
                ra.append({"_khong_doc_duoc": d[:500]})
    return ra


def _van_ban(f: Path, tran: int = 400_000) -> str | None:
    if not f.exists():
        return None
    t = f.read_text(encoding="utf-8", errors="replace")
    return t if len(t) <= tran else t[:tran] + f"\n… [cắt {len(t) - tran} ký tự]"


def thu(thu_muc: Path, du_an: Path | None) -> dict[str, Any]:
    """Gom một ca. `thu_muc` là thư mục kết quả TC; `du_an` là dự án nó tạo ra."""
    d: dict[str, Any] = {"thu_muc": str(thu_muc), "du_an": str(du_an) if du_an else None}

    # 1. Người gõ gì
    d["kich_ban"] = _van_ban(thu_muc / "kich-ban.kb")
    # 2. Hệ thống in ra gì
    d["stdout"] = _van_ban(thu_muc / "stdout.log")
    d["nhat_ky_giao_dien"] = _van_ban(thu_muc / "nhat-ky.md")
    d["anh"] = sorted(x.name for x in thu_muc.glob("*.png"))

    if du_an is None or not Path(du_an).is_dir():
        d["_ghi_chu"] = "ca này không tạo dự án — không có trạng thái để đọc"
        return d

    e = Path(du_an) / ".eide"
    # 3. Gọi mô hình: băm (ledger) VÀ nội dung đầy đủ (nếu EIDE_LOG_LLM bật)
    d["ledger"] = _jsonl(e / "store" / "ledger.jsonl")
    d["llm_day_du"] = _jsonl(e / "store" / "llm-day-du.jsonl")
    # 4. Hiện vật + trí nhớ
    d["store"] = _bang(e / "store" / "store.sqlite")
    d["session"] = _bang(e / "session" / "session.sqlite")
    # 5. Cấu hình có hiệu lực lúc chạy — mức tự chủ và chính sách đổi hành vi của cả lượt
    d["cau_hinh"] = {f.name: _van_ban(f, 40_000)
                     for f in sorted(e.glob("*")) if f.is_file()}
    # 6. Hiện vật ghi ra tệp chứ không vào store
    d["tep_hien_vat"] = sorted(
        str(x.relative_to(e)) for x in e.rglob("*")
        if x.is_file() and x.suffix in {".md", ".json", ".yaml", ".c", ".h", ".mmd", ".svg"})
    return d


def _tom_tat_llm(ds: list[dict[str, Any]]) -> list[str]:
    r = []
    for i, x in enumerate(ds, 1):
        r.append(f"\n### Lời gọi {i} — vai trò `{x.get('role')}` · `{x.get('model_id')}`\n")
        r.append(f"- dừng: `{x.get('stop_reason')}` · vào {x.get('tokens_in')} tok · "
                 f"ra {x.get('tokens_out')} tok · {x.get('latency_ms')} ms · "
                 f"{x.get('cost_usd')} USD" + (f" · LỖI `{x['error_kind']}`"
                                               if x.get("error_kind") else ""))
        r.append("\n**Câu nhắc hệ thống**\n\n```\n" + str(x.get("system", ""))[:12000] + "\n```")
        r.append("\n**Câu hỏi gửi lên**\n\n```\n" + str(x.get("user", ""))[:12000] + "\n```")
        r.append("\n**Đầu ra thô**\n\n```\n" + str(x.get("raw"))[:12000] + "\n```")
    return r


def viet(d: dict[str, Any], thu_muc: Path) -> None:
    (thu_muc / "toan-canh.json").write_text(
        json.dumps(d, ensure_ascii=False, indent=1, default=str), encoding="utf-8")

    m = [f"# Toàn cảnh — {thu_muc.name}\n",
         f"Dự án: `{d.get('du_an')}`\n",
         "\n## 1. Người gõ gì\n\n```\n" + (d.get("kich_ban") or "(không có)") + "\n```\n",
         f"\n## 2. Gọi mô hình — {len(d.get('llm_day_du') or [])} lời gọi đầy đủ, "
         f"{len([x for x in (d.get('ledger') or []) if x.get('kind') == 'model.call'])} "
         "bản ghi trong ledger\n"]
    if d.get("llm_day_du"):
        m += _tom_tat_llm(d["llm_day_du"])
    else:
        m.append("\n> Không có bản ghi đầy đủ — `EIDE_LOG_LLM` chưa bật lúc chạy ca này.\n")

    led = d.get("ledger") or []
    m.append(f"\n## 3. Ledger — {len(led)} sự kiện\n")
    dem: dict[str, int] = {}
    for x in led:
        dem[str(x.get("kind"))] = dem.get(str(x.get("kind")), 0) + 1
    m.append("\n| loại sự kiện | số lần |\n|---|---|\n")
    m += [f"| `{k}` | {v} |\n" for k, v in sorted(dem.items(), key=lambda p: -p[1])]
    m.append("\n<details><summary>Toàn bộ sự kiện</summary>\n\n```json\n"
             + json.dumps(led, ensure_ascii=False, indent=1, default=str)[:300_000]
             + "\n```\n</details>\n")

    for ten, nhan in (("store", "4. Hiện vật (store.sqlite)"),
                      ("session", "5. Trí nhớ phiên (session.sqlite)")):
        b = d.get(ten) or {}
        m.append(f"\n## {nhan}\n\n| bảng | số dòng |\n|---|---|\n")
        m += [f"| `{t}` | {v.get('so_dong', '?')} |\n"
              for t, v in sorted(b.items()) if isinstance(v, dict)]
        m.append("\n<details><summary>Toàn bộ nội dung</summary>\n\n```json\n"
                 + json.dumps(b, ensure_ascii=False, indent=1, default=str)[:300_000]
                 + "\n```\n</details>\n")

    m.append("\n## 6. Cấu hình có hiệu lực\n")
    for t, v in (d.get("cau_hinh") or {}).items():
        m.append(f"\n**`{t}`**\n\n```\n{str(v)[:8000]}\n```\n")

    m.append("\n## 7. Tệp hiện vật\n\n"
             + "\n".join(f"- `{x}`" for x in (d.get("tep_hien_vat") or []) [:400]) + "\n")
    m.append("\n## 8. Nhật ký giao diện\n\n```\n"
             + str(d.get("nhat_ky_giao_dien"))[:200_000] + "\n```\n")
    m.append("\n## 9. stdout/stderr bộ lái\n\n```\n"
             + str(d.get("stdout"))[:200_000] + "\n```\n")
    (thu_muc / "toan-canh.md").write_text("".join(m), encoding="utf-8")


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser(description="Gom toàn bộ trạng thái của các ca đã chạy")
    ap.add_argument("thu_muc", nargs="*", help="thư mục TC; bỏ trống = tất cả")
    a = ap.parse_args()
    goc = Path(__file__).resolve().parent.parent / "docs/test/usecase"
    ds = [Path(x) for x in a.thu_muc] or sorted(
        x for x in goc.iterdir() if x.is_dir() and x.name.startswith("TC"))
    for t in ds:
        kq = t / "ket-qua.json"
        du_an = None
        if kq.exists():
            du_an = (json.loads(kq.read_text(encoding="utf-8")) or {}).get("du_an")
        d = thu(t, Path(du_an) if du_an else None)
        viet(d, t)
        print(f"{t.name}: {len(d.get('llm_day_du') or [])} lời gọi đầy đủ · "
              f"{len(d.get('ledger') or [])} sự kiện")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
