"""CLI `eide` — API-15 §CLI (argparse, stdlib). Sprint 1: doctor, caps list|describe|invoke, project new|list,
policy stop|set, spec, daemon."""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

from eide import __version__
from eide_core import store, tools
from eide_core.errors import EideError
from eide_core.ledger import Ledger
from eide_core.paths import project_dir_default, spec_dir, user_log
from eide_core.policy import PolicyGate
from eide_core.registry import get_registry
from eide_core.router import Context, Router

COMMON_TOOLS = tools.COMMON_TOOLS   # nguồn duy nhất ở eide_core.tools


def _router(project: Path | None = None) -> tuple[Router, Context]:
    ledger = Ledger((project / ".eide" / "store" / "ledger.jsonl") if project else user_log() / "ledger.jsonl")
    gate = PolicyGate()
    return Router(gate=gate, ledger=ledger), Context(project_dir=project, extra={"gate": gate})


def _print_run(run) -> int:
    if run.status == "done":
        print(json.dumps(run.result, ensure_ascii=False, indent=2))
    elif run.status == "pending":
        print(f"CHỜ NGƯỜI ({run.decision['gate']} · {run.decision['rule']}): {run.decision['reason']}")
    else:
        print(f"{run.status.upper()}: {json.dumps(run.error, ensure_ascii=False)}")
    print(f"-- run {run.run_id} · {run.decision['decision']} theo {run.decision['rule']} · {run.duration_ms} ms · undo={run.undo}", file=sys.stderr)
    return 0 if run.status in ("done", "pending") else 2


def _table(headers: list[str], rows: list[list[str]]) -> None:
    w = [max(len(str(x)) for x in col) for col in zip(headers, *rows, strict=False)] if rows else [len(h) for h in headers]
    fmt = "  ".join(f"{{:<{n}}}" for n in w)
    print(fmt.format(*headers))
    print("  ".join("-" * n for n in w))
    for r in rows:
        print(fmt.format(*[str(x) for x in r]))


# ---- lệnh
def cmd_doctor(a) -> int:
    reg = get_registry()
    r, ctx = _router()
    env = r.invoke("env.detect", {}, ctx).result["env"]
    print(f"EIDE {__version__} · {env['os']} {env['os_version']} · {env['arch']} · Python {env['python']}")
    print(f"spec: {spec_dir()} · năng lực: {len(reg.list())} ({len(reg.list(implemented=True))} đã hiện thực)")
    rows, missing = [], 0
    for name, req in COMMON_TOOLS:
        exe = tools.which(name)
        ver = tools.version_of(exe) if exe else None
        missing += int(req and not exe)
        rows.append([name, "bắt buộc" if req else "", str(exe) if exe else "—", (ver or "")[:60]])
    _table(["Công cụ", "", "Tìm thấy", "Phiên bản"], rows)
    if missing:
        print(f"Thiếu {missing} công cụ bắt buộc — xem docs/PLATFORM.md và scripts/setup-mac.sh")
        return 1
    return 0


def cmd_migrate(a) -> int:
    """`eide migrate` — DDD-14 §5. Đưa store.sqlite của dự án lên phiên bản mới nhất."""
    project = a.project or Path.cwd()
    db = store.store_path(project)
    if not (Path(project) / ".eide").is_dir():
        print(f"Không thấy .eide/ trong {project} — đây có phải thư mục dự án không?", file=sys.stderr)
        return 2
    led = Ledger(Path(project) / ".eide" / "store" / "ledger.jsonl")
    kq = store.migrate(db, ledger=led, actor="human")
    if not kq["applied"]:
        print(f"store đã ở user_version={kq['to_version']} — không có migration nào còn thiếu")
        return 0
    for m in kq["applied"]:
        print(f"  ✓ {m['name']} → user_version={m['version']}")
    if kq["backup"]:
        print(f"sao lưu: {kq['backup']}")
    print(f"{db} · user_version {kq['from_version']} → {kq['to_version']}")
    # index.sqlite là cơ sở dữ liệu riêng, dựng lại được từ nguồn (§5 migration 0003).
    store.open_index(store.index_path(project)).close()
    return 0


def cmd_caps_list(a) -> int:
    reg = get_registry()
    rows = [[c.spec.code, c.spec.id, c.spec.risk_class, c.spec.tier, c.spec.milestone, c.spec.gate, "✔" if c.implemented else "—"]
            for c in reg.list(ns=a.ns, implemented=True if a.implemented else None)]
    _table(["Mã", "Năng lực", "R", "T", "Mốc", "Cổng", "HT"], rows)
    return 0


def cmd_caps_describe(a) -> int:
    print(json.dumps(get_registry().describe(a.cap_id), ensure_ascii=False, indent=2))
    return 0


def cmd_caps_invoke(a) -> int:
    r, ctx = _router(a.project)
    ctx.autonomy = a.autonomy
    return _print_run(r.invoke(a.cap_id, json.loads(a.params), ctx))


def cmd_project_new(a) -> int:
    r, ctx = _router()
    p = {"text": a.text}
    if a.dir:
        p["dir"] = str(a.dir)
    if a.chip:
        p["chip"] = a.chip
    return _print_run(r.invoke("project.create", p, ctx))


def cmd_project_list(a) -> int:
    r, ctx = _router()
    return _print_run(r.invoke("project.list", {"workspace": str(a.workspace or project_dir_default())}, ctx))


def cmd_policy_stop(a) -> int:
    r, ctx = _router(a.project)
    return _print_run(r.invoke("policy.emergency_stop", {}, ctx))


def cmd_policy_set(a) -> int:
    r, ctx = _router(a.project)
    p = {"level": a.level, "by": "human"}
    if a.board:
        p["board"] = a.board
    return _print_run(r.invoke("policy.set_autonomy", p, ctx))


def cmd_spec(a) -> int:
    f = spec_dir().parents[1] / "scripts" / "spec_status.py"
    m = importlib.util.spec_from_file_location("spec_status", f)
    mod = importlib.util.module_from_spec(m)
    m.loader.exec_module(mod)  # type: ignore[union-attr]
    mod.spec_status(a.ns)
    return 0


def cmd_daemon(a) -> int:
    from eide.daemon.rpc import serve_stdio

    serve_stdio(sys.stdin, sys.stdout, a.project)
    return 0


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="eide", description="EIDE — Embedded IDE có tác tử (bộ hồ sơ v1.2)")
    ap.add_argument("-V", "--version", action="version", version=f"eide {__version__}")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("doctor", help="kiểm tra môi trường máy").set_defaults(fn=cmd_doctor)
    caps = sub.add_parser("caps", help="registry năng lực").add_subparsers(dest="sub", required=True)

    p = caps.add_parser("list")
    p.add_argument("--ns")
    p.add_argument("--implemented", action="store_true")
    p.set_defaults(fn=cmd_caps_list)

    p = caps.add_parser("describe")
    p.add_argument("cap_id")
    p.set_defaults(fn=cmd_caps_describe)

    p = caps.add_parser("invoke")
    p.add_argument("cap_id")
    p.add_argument("params", nargs="?", default="{}")
    p.add_argument("-p", "--project", type=Path)
    p.add_argument("--autonomy")
    p.set_defaults(fn=cmd_caps_invoke)

    proj = sub.add_parser("project", help="dự án").add_subparsers(dest="sub", required=True)

    p = proj.add_parser("new")
    p.add_argument("text")
    p.add_argument("--dir", type=Path)
    p.add_argument("--chip")
    p.set_defaults(fn=cmd_project_new)

    p = proj.add_parser("list")
    p.add_argument("workspace", nargs="?", type=Path)
    p.set_defaults(fn=cmd_project_list)

    pol = sub.add_parser("policy", help="chính sách tự chủ").add_subparsers(dest="sub", required=True)

    p = pol.add_parser("stop")
    p.add_argument("-p", "--project", type=Path)
    p.set_defaults(fn=cmd_policy_stop)

    p = pol.add_parser("set")
    p.add_argument("level")
    p.add_argument("-p", "--project", type=Path, required=True)
    p.add_argument("--board")
    p.set_defaults(fn=cmd_policy_set)

    p = sub.add_parser("migrate", help="di trú store.sqlite của dự án (DDD-14 §5)")
    p.add_argument("-p", "--project", type=Path)
    p.set_defaults(fn=cmd_migrate)

    p = sub.add_parser("spec", help="trạng thái hiện thực so với spec")
    p.add_argument("--ns")
    p.set_defaults(fn=cmd_spec)

    p = sub.add_parser("daemon", help="JSON-RPC qua stdio")
    p.add_argument("-p", "--project", type=Path)
    p.set_defaults(fn=cmd_daemon)

    return ap


def main(argv: list[str] | None = None) -> int:
    a = build_parser().parse_args(argv)
    try:
        return a.fn(a)
    except EideError as e:
        print(f"{e.code} {e.name}: {e} {json.dumps(e.data, ensure_ascii=False) if e.data else ''}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
