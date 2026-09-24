"""Tổng hợp 76 ca từ `toan-canh.json` — bảng tỉ lệ và NHÓM LỖI rút từ dữ liệu. [DEV-217]

Bảng tỉ lệ nói *bao nhiêu ca trượt*; nó không nói *vì sao*. Các đợt trước phải đọc tay 76 nhật
ký rồi tự gom thành nhóm, và cách ấy vừa chậm vừa trôi: một nhóm đặt tên hôm nay không khớp
với nhóm đặt tên tuần trước, nên không so được hai đợt đo với nhau.

Ở đây nhóm được rút từ CHỮ KÝ MÁY ĐỌC ĐƯỢC của mỗi ca — năng lực chết, mã lỗi, câu hỏi tác tử
hỏi người — nên hai đợt đo cùng chữ ký thì cùng nhóm, không phụ thuộc người đặt tên.
"""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Any

GOC = Path(__file__).resolve().parent.parent
RA = GOC / "docs/test/usecase"


def _bao_cao_run(store: dict[str, Any]) -> list[dict[str, Any]]:
    """Các `run.report` trong store — nơi duy nhất nói chuỗi đã chạy tới đâu."""
    b = (store.get("run") or {}).get("dong") or []
    ra = []
    for r in b:
        try:
            ra.append({"state": r.get("state"), **json.loads(r.get("report") or "{}")})
        except (json.JSONDecodeError, TypeError):
            continue
    return ra


def chu_ky(tc: str, d: dict[str, Any]) -> dict[str, Any]:
    """Chữ ký máy đọc được của một ca: chuỗi chạy tới đâu, chết ở đâu, hỏi người gì."""
    led = d.get("ledger") or []
    llm = d.get("llm_day_du") or []
    bc = _bao_cao_run(d.get("store") or {})

    hong: list[str] = []
    hong_bat_buoc: list[str] = []
    hoi: list[str] = []
    xong: list[str] = []
    state = None
    for r in bc:
        state = r.get("state") or state
        for x in r.get("failed") or []:
            ma = ((x.get("error") or {}).get("eide_code")) or "?"
            hong.append(f"{x.get('cap')}:{ma}")
            if x.get("bat_buoc", True):
                hong_bat_buoc.append(f"{x.get('cap')}:{ma}")
        for x in r.get("waiting") or []:
            for t in x.get("thieu") or []:
                hoi.append(f"{x.get('cap')}→{t}")
        xong += [x.get("cap") for x in r.get("done") or []]

    # Lời gọi HỎNG ghi `stop_reason: "error"` — nhận ra nó bằng `error_kind`, không bằng
    # `stop_reason`. Bản đầu đếm theo `stop_reason` và ra 0 lần bị cắt trên một đợt CÓ hai
    # lần bị cắt: một con số 0 nói dối còn tệ hơn không có con số nào. [DEV-217]
    cat = [x for x in llm if x.get("error_kind") == "truncated"
           or str(x.get("stop_reason", "")).lower() in
           ("max_tokens", "length", "maxtokens", "max_output_tokens")]
    return {
        "tc": tc,
        "state": state,
        "xong": xong,
        "hong": sorted(set(hong)),
        "hong_bat_buoc": sorted(set(hong_bat_buoc)),
        "hoi": sorted(set(hoi)),
        "so_loi_goi": len(llm),
        "so_cat": len(cat),
        "vai_tro_cat": sorted({x.get("role") for x in cat}),
        "tokens_in": sum(int(x.get("tokens_in") or 0) for x in llm),
        "tokens_out": sum(int(x.get("tokens_out") or 0) for x in llm),
        "cost_usd": round(sum(float(x.get("cost_usd") or 0) for x in llm), 4),
        "su_kien": len(led),
        "gate_ask": len([x for x in led
                         if x.get("kind") == "gate.decision"
                         and (x.get("data") or {}).get("decision") == "ASK"]),
    }


def main() -> int:
    pq = {}
    f = RA / "phan-quyet.json"
    if f.exists():
        pq = json.loads(f.read_text(encoding="utf-8"))

    ds = []
    for t in sorted(x for x in RA.iterdir() if x.is_dir() and x.name.startswith("TC")):
        j = t / "toan-canh.json"
        if not j.exists():
            continue
        ds.append(chu_ky(t.name, json.loads(j.read_text(encoding="utf-8"))))

    if not ds:
        print("chưa có toàn cảnh nào — chạy scripts/thu_toan_canh.py trước")
        return 1

    # --- Bảng từng ca
    d = [f"# Tổng hợp toàn cảnh — {len(ds)} ca có dữ liệu\n",
         "\n| TC | phán quyết | state | bước xong | hỏng (bắt buộc) | hỏng (tuỳ chọn) | "
         "hỏi người | lời gọi | bị cắt | token ra | USD |\n",
         "|---|---|---|---|---|---|---|---|---|---|---|\n"]
    for x in ds:
        tuy_chon = [h for h in x["hong"] if h not in x["hong_bat_buoc"]]
        d.append(
            f"| {x['tc']} | {(pq.get(x['tc']) or {}).get('trang_thai', '—')} | "
            f"{x['state'] or '—'} | {len(x['xong'])} | "
            f"{', '.join(x['hong_bat_buoc']) or '—'} | {', '.join(tuy_chon) or '—'} | "
            f"{', '.join(x['hoi'])[:60] or '—'} | {x['so_loi_goi']} | "
            f"{x['so_cat'] or '—'} | {x['tokens_out']} | {x['cost_usd']} |\n")

    # --- Nhóm lỗi rút từ chữ ký
    d.append("\n## Nhóm lỗi — rút từ chữ ký, không đặt tay\n")
    nhom: Counter[str] = Counter()
    thanh_vien: dict[str, list[str]] = {}
    for x in ds:
        for k in (x["hong_bat_buoc"] or []) + [f"HỎI {h}" for h in x["hoi"]]:
            nhom[k] += 1
            thanh_vien.setdefault(k, []).append(x["tc"])
    d.append("\n| chữ ký | số ca | các ca |\n|---|---|---|\n")
    for k, n in nhom.most_common():
        d.append(f"| `{k}` | {n} | {', '.join(thanh_vien[k][:14])} |\n")

    # --- Tổng
    d.append("\n## Tổng\n\n")
    d.append(f"- lời gọi mô hình: **{sum(x['so_loi_goi'] for x in ds)}**, "
             f"trong đó **{sum(x['so_cat'] for x in ds)} bị cắt** "
             f"(vai trò: {', '.join(sorted({r for x in ds for r in x['vai_tro_cat']})) or '—'})\n")
    d.append(f"- token vào {sum(x['tokens_in'] for x in ds):,} · "
             f"token ra {sum(x['tokens_out'] for x in ds):,} · "
             f"chi phí **{sum(x['cost_usd'] for x in ds):.4f} USD**\n")
    d.append(f"- sự kiện ledger: {sum(x['su_kien'] for x in ds):,} · "
             f"cổng hỏi người: {sum(x['gate_ask'] for x in ds)}\n")
    dem = Counter(x["state"] or "—" for x in ds)
    d.append(f"- trạng thái lượt chạy: {dict(dem)}\n")

    out = RA / "TONG-HOP-TOAN-CANH.md"
    out.write_text("".join(d), encoding="utf-8")
    (RA / "TONG-HOP-TOAN-CANH.json").write_text(
        json.dumps(ds, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"đã ghi {out} — {len(ds)} ca, {len(nhom)} chữ ký lỗi")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
