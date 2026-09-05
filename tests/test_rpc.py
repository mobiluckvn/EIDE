import io
import json

from eide.daemon.rpc import Daemon, serve_stdio


def test_hello_and_caps_list():
    d = Daemon()
    r = d.handle({"jsonrpc": "2.0", "id": 1, "method": "plane.hello", "params": {"api_version": "1.2"}})
    assert r["result"]["caps"] == 238
    r = d.handle({"jsonrpc": "2.0", "id": 2, "method": "caps.list", "params": {"ns": "tool"}})
    assert len(r["result"]["caps"]) == 10


def test_version_mismatch_E1002():
    r = Daemon().handle({"jsonrpc": "2.0", "id": 1, "method": "plane.hello", "params": {"api_version": "2.0"}})
    assert r["error"]["data"]["eide_code"] == "E1002"


def test_stdio_roundtrip():
    inp = io.StringIO(json.dumps({"jsonrpc": "2.0", "id": 9, "method": "nope"}) + "\nkhông phải json\n")
    out = io.StringIO()
    serve_stdio(inp, out)
    lines = [json.loads(x) for x in out.getvalue().splitlines()]
    assert lines[0]["error"]["code"] == -32601 and lines[1]["error"]["code"] == -32700
