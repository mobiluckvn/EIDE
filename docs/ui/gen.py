# Sinh các artboard .dc.html cho bộ mockup HKW (static, 1440x900, macOS-style workbench)
import json, html
from pathlib import Path

# Bảng màu theo nhận diện PTIT: đỏ chủ đạo + sao vàng (ptit.edu.vn); mã HEX chính xác không công bố, dùng giá trị gần đúng — đổi tại đây
NAVY, TEAL, GOLD = '#B8121F', '#2F4858', '#F2B705'  # NAVY=đỏ PTIT (điều hướng/chính), TEAL=xám xanh (hành động phụ), GOLD=vàng sao (cần con người)
OUT = Path(__file__).parent

CSS = f"""
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap');
body {{ margin:0; font-family:'IBM Plex Sans', 'Helvetica Neue', Arial, sans-serif; color:#1b2430; background:#f4f6f9; font-size:13px; }}
a {{ color:{NAVY}; }} a:hover {{ color:{TEAL}; }}
.mono {{ font-family:'IBM Plex Mono', Menlo, Consolas, monospace; }}
.win {{ width:1440px; height:900px; display:flex; flex-direction:column; background:#f4f6f9; overflow:hidden; border-radius:10px; box-shadow:0 20px 60px rgba(184,18,31,.14); }}
.titlebar {{ height:38px; display:flex; align-items:center; gap:8px; padding:0 14px; background:#e9edf3; border-bottom:1px solid #d5dbe5; }}
.dot {{ width:12px; height:12px; border-radius:6px; }}
.tabs {{ display:flex; gap:2px; margin-left:16px; }}
.tab {{ padding:7px 14px; font-size:12px; color:#5b6b7f; border-radius:6px 6px 0 0; }}
.tab.on {{ background:#f4f6f9; color:{NAVY}; font-weight:600; }}
.body {{ flex:1; display:flex; min-height:0; }}
.side {{ width:212px; background:{NAVY}; color:#fbe9ea; display:flex; flex-direction:column; padding:14px 0; gap:2px; }}
.brand {{ display:flex; align-items:center; gap:10px; padding:4px 16px 14px; }}
.brand b {{ color:#fff; font-size:14px; letter-spacing:.3px; }}
.nav {{ display:flex; align-items:center; gap:10px; padding:8px 16px; font-size:13px; color:#f3c6c9; }}
.nav.on {{ background:rgba(255,255,255,.12); color:#fff; border-left:3px solid {TEAL}; padding-left:13px; }}
.nav .cnt {{ margin-left:auto; background:{GOLD}; color:{NAVY}; font-size:11px; font-weight:600; padding:1px 7px; border-radius:9px; }}
.nav svg {{ width:16px; height:16px; stroke:currentColor; fill:none; stroke-width:1.6; stroke-linecap:round; stroke-linejoin:round; }}
.sidefoot {{ margin-top:auto; padding:12px 16px; font-size:11px; color:#f0b3b7; border-top:1px solid rgba(255,255,255,.12); display:flex; flex-direction:column; gap:4px; }}
.main {{ flex:1; display:flex; flex-direction:column; min-width:0; }}
.topbar {{ height:52px; display:flex; align-items:center; gap:12px; padding:0 20px; background:#fff; border-bottom:1px solid #e1e6ee; }}
.topbar h1 {{ font-size:16px; font-weight:600; margin:0; color:{NAVY}; }}
.crumb {{ color:#7b8a9c; font-size:12px; }}
.search {{ margin-left:auto; display:flex; align-items:center; gap:8px; width:340px; height:32px; border:1px solid #d5dbe5; border-radius:6px; padding:0 10px; color:#8a97a8; background:#fbfcfd; }}
.btn {{ display:inline-flex; align-items:center; gap:6px; height:32px; padding:0 12px; border-radius:6px; font-weight:500; font-size:12.5px; border:1px solid #cfd6e0; background:#fff; color:#243447; }}
.btn.p {{ background:{NAVY}; color:#fff; border-color:{NAVY}; }}
.btn.t {{ background:{TEAL}; color:#fff; border-color:{TEAL}; }}
.btn.g {{ background:{GOLD}; color:#3a2a00; border-color:{GOLD}; }}
.btn.d {{ background:#fff; color:#b3261e; border-color:#e6b8b5; }}
.content {{ flex:1; display:flex; gap:16px; padding:16px 20px; min-height:0; }}
.card {{ background:#fff; border:1px solid #e1e6ee; border-radius:8px; display:flex; flex-direction:column; min-width:0; }}
.card h3 {{ margin:0; padding:12px 14px; font-size:12px; font-weight:600; letter-spacing:.4px; text-transform:uppercase; color:#5b6b7f; border-bottom:1px solid #eef1f5; display:flex; align-items:center; gap:8px; }}
.card h3 .sp {{ margin-left:auto; font-weight:500; text-transform:none; letter-spacing:0; color:#8a97a8; }}
.pad {{ padding:12px 14px; }}
table {{ border-collapse:collapse; width:100%; font-size:12.5px; }}
th {{ text-align:left; font-weight:600; color:#5b6b7f; font-size:11px; letter-spacing:.3px; text-transform:uppercase; padding:8px 12px; border-bottom:1px solid #e1e6ee; background:#fafbfd; }}
td {{ padding:8px 12px; border-bottom:1px solid #eef1f5; vertical-align:top; }}
tr.sel td {{ background:#fff4e6; }}
.pill {{ display:inline-flex; align-items:center; gap:5px; padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; }}
.gold {{ background:#fff3d6; color:#7a5200; }} .silver {{ background:#e8eef5; color:#3d5064; }} .bronze {{ background:#f6e3dc; color:#8a3b1f; }}
.ok {{ background:#dff5ee; color:#0b6b52; }} .warn {{ background:#fff0cc; color:#7a5200; }} .bad {{ background:#fde3e1; color:#7a0c0c; }} .info {{ background:#e6effa; color:{NAVY}; }}
.kpi {{ display:flex; flex-direction:column; gap:4px; padding:14px; }}
.kpi .v {{ font-size:26px; font-weight:600; color:{NAVY}; }}
.kpi .l {{ font-size:11.5px; color:#5b6b7f; }}
.status {{ height:26px; display:flex; align-items:center; gap:18px; padding:0 20px; font-size:11px; color:#5b6b7f; background:#fff; border-top:1px solid #e1e6ee; }}
.status .dotg {{ width:8px; height:8px; border-radius:4px; background:{TEAL}; display:inline-block; margin-right:6px; }}
.gate {{ display:flex; align-items:center; gap:10px; padding:10px 12px; border:1px solid #e1e6ee; border-radius:6px; background:#fff; }}
.gate .tag {{ font-family:'IBM Plex Mono', monospace; font-size:11px; font-weight:600; color:#fff; background:{NAVY}; padding:2px 6px; border-radius:4px; }}
.code {{ font-family:'IBM Plex Mono', Menlo, monospace; font-size:12px; line-height:1.55; white-space:pre; color:#1b2430; }}
.tree {{ font-size:12.5px; }} .tree div {{ padding:5px 8px; border-radius:4px; display:flex; gap:8px; align-items:center; }} .tree .on {{ background:#fff4e6; color:{NAVY}; font-weight:600; }}
.field {{ display:flex; flex-direction:column; gap:4px; }} .field label {{ font-size:11px; color:#5b6b7f; font-weight:600; }} .field .in {{ height:30px; border:1px solid #d5dbe5; border-radius:5px; padding:0 10px; display:flex; align-items:center; background:#fff; }}
.hint {{ font-size:11.5px; color:#7b8a9c; }}
"""

ICONS = {
 'home': '<svg viewBox="0 0 24 24"><path d="M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>',
 'in': '<svg viewBox="0 0 24 24"><path d="M12 3v12m0 0l-4-4m4 4l4-4M4 17v3h16v-3"/></svg>',
 'queue': '<svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h10M4 18h13"/><circle cx="19" cy="17" r="2"/></svg>',
 'chip': '<svg viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4"/></svg>',
 'board': '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8" cy="9" r="1.5"/><circle cx="16" cy="15" r="1.5"/><path d="M9.5 9h5l-3.5 6"/></svg>',
 'graph': '<svg viewBox="0 0 24 24"><circle cx="5" cy="6" r="2.5"/><circle cx="19" cy="6" r="2.5"/><circle cx="12" cy="18" r="2.5"/><path d="M7 7.5l3.5 8M17 7.5l-3.5 8M7.5 6h9"/></svg>',
 'plan': '<svg viewBox="0 0 24 24"><path d="M9 5h11M9 12h11M9 19h11M4 5h1M4 12h1M4 19h1"/></svg>',
 'log': '<svg viewBox="0 0 24 24"><path d="M4 4h16v16H4z"/><path d="M7 9h10M7 13h7M7 17h4"/></svg>',
 'bug': '<svg viewBox="0 0 24 24"><path d="M8 9a4 4 0 0 1 8 0v6a4 4 0 0 1-8 0zM3 13h5M16 13h5M5 7l3 2M19 7l-3 2M5 19l3-2M19 19l-3-2"/></svg>',
 'pkg': '<svg viewBox="0 0 24 24"><path d="M12 3l9 4.5v9L12 21l-9-4.5v-9z"/><path d="M12 12l9-4.5M12 12L3 7.5M12 12v9"/></svg>',
 'cfg': '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>',
 'chat': '<svg viewBox="0 0 24 24"><path d="M4 5h16v11H9l-5 4z"/><path d="M8 9h8M8 12h5"/></svg>',
 'code': '<svg viewBox="0 0 24 24"><path d="M8 7l-5 5 5 5M16 7l5 5-5 5M14 4l-4 16"/></svg>',
 'sim': '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M10 8l6 4-6 4z"/></svg>',
 'bench': '<svg viewBox="0 0 24 24"><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg>',
 'req': '<svg viewBox="0 0 24 24"><path d="M5 4h14v16H5z"/><path d="M8 9h8M8 13h8M8 17h5"/></svg>',
 'diagram': '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="7" height="5" rx="1"/><rect x="14" y="4" width="7" height="5" rx="1"/><rect x="8.5" y="15" width="7" height="5" rx="1"/><path d="M6.5 9v3h11V9M12 12v3"/></svg>',
 'doc': '<svg viewBox="0 0 24 24"><path d="M6 2h9l5 5v15H6z"/><path d="M15 2v5h5M9 13h7M9 17h7M9 9h3"/></svg>',
 'discover': '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/><circle cx="12" cy="12" r="8"/></svg>',
 'tool': '<svg viewBox="0 0 24 24"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.6 2.6-2.1-2.1z"/></svg>',
 'search': '<svg viewBox="0 0 24 24" width="14" height="14" style="stroke:#8a97a8;fill:none;stroke-width:1.8"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>',
}
NAV = [('chat','Trò chuyện (mặc định)',''),('home','Tổng quan',''),('queue','Chờ tôi / Đã làm','2'),('in','Nhập tài liệu',''),('chip','Hộ chiếu chip',''),('board','Hộ chiếu mạch',''),('graph','Bản đồ tri thức & hỏi đáp',''),('req','Yêu cầu & kiến trúc',''),('diagram','Lược đồ',''),('doc','Tài liệu',''),('plan','Kế hoạch & mã',''),('code','Mã nguồn',''),('sim','Mô phỏng',''),('discover','Dò board',''),('log','Log & serial',''),('bug','Gỡ lỗi probe',''),('tool','Công cụ tự tạo',''),('bench','Benchmark',''),('pkg','Registry',''),('cfg','Mô hình & môi trường','')]

def shell(title, crumb, active, body, actions='', tabs=('Tổng quan','driver_bme280.c','serial-3.log')):
    def navitem(k, n, c):
        cnt = '<span class="cnt">%s</span>' % c if c else ''
        return '<div class="nav %s">%s<span>%s</span>%s</div>' % ('on' if k == active else '', ICONS[k], n, cnt)
    nav = ''.join(navitem(k, n, c) for k, n, c in NAV)
    tabhtml = ''.join(f'<div class="tab {"on" if i==0 else ""}">{t}</div>' for i,t in enumerate(tabs))
    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>{CSS}</style>
</helmet>
<div class="win">
  <div class="titlebar"><span class="dot" style="background:#ff5f57"></span><span class="dot" style="background:#febc2e"></span><span class="dot" style="background:#28c840"></span>
    <span style="margin-left:10px;font-size:12px;color:#5b6b7f;font-weight:600">EIDE — robot-ctrl · ST-Link nucleo-f411 đang cắm</span>
    <div class="tabs">{tabhtml}</div>
  </div>
  <div class="body">
    <div class="side">
      <div class="brand"><svg width="22" height="22" viewBox="0 0 24 24" style="stroke:{TEAL};fill:none;stroke-width:1.8"><rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4"/></svg><b>EIDE</b><span style="font-size:10px;color:#f3c6c9;margin-left:auto">0.1 · PTIT</span></div>
      {nav}
      <div class="sidefoot"><span><span class="dotg"></span>Knowledge Plane · PC này · Internet</span><span>Tự chủ: <b style="color:#fff">A3</b> · board lab nucleo-f411</span><span>Pin: st.stm32f411@1.2.0</span><span style="margin-top:6px"><span class="btn d" style="height:24px;padding:0 8px;font-size:11px">■ Dừng khẩn</span></span></div>
    </div>
    <div class="main">
      <div class="topbar"><h1>{title}</h1><span class="crumb">{crumb}</span><div class="search">{ICONS['search']}<span>Hỏi hộ chiếu… ví dụ: thanh ghi tốc độ I2C1 của chip này</span></div>{actions}</div>
      <div class="content">{body}</div>
      <div class="status"><span><span class="dotg"></span><b style="color:#B8121F">Tự chủ A3</b> · 12 việc tự làm hôm nay · 2 chờ anh · hoàn tác được đến 09:14</span><span>store.sqlite · 13.494 fact · 2 hộ chiếu</span><span>Ledger: 214 lượt gọi · 0,42 USD hôm nay</span><span>Toolchain: arm-none-eabi-gcc 13.2 · probe-rs 0.24 · ST-Link V3</span><span style="margin-left:auto">G1 ✓ · G3 chờ 1 · G4 ✓ · G-OPS hết hạn 12:40</span></div>
    </div>
  </div>
</div>
</x-dc>
</body>
</html>
"""

def write(name, s): (OUT / f'{name}.dc.html').write_text(s, encoding='utf-8')

# ---------------------------------------------------------------- 1. Tổng quan
body = f"""
<div style="display:flex;flex-direction:column;gap:16px;flex:1;min-width:0">
  <div style="display:grid;grid-template-columns:repeat(4, minmax(0, 1fr));gap:16px">
    <div class="card"><div class="kpi"><span class="v">2</span><span class="l">Hộ chiếu chip đã pin · 1 hộ chiếu mạch</span></div></div>
    <div class="card"><div class="kpi"><span class="v">100%</span><span class="l">Hằng số trong mã có nguồn (fact id)</span></div></div>
    <div class="card"><div class="kpi"><span class="v">7</span><span class="l">Mục chờ xác nhận (G-SRC 2 · G-FACT 3 · G3 1 · G-OPS 1)</span></div></div>
    <div class="card"><div class="kpi"><span class="v">5 / 8</span><span class="l">Tính năng passing · 3 failing</span></div></div>
  </div>
  <div style="display:flex;gap:16px;flex:1;min-height:0">
    <div class="card" style="flex:1.4">
      <h3>Tính năng (FEATURES.json)<span class="sp">STEP hiện hành: F-06 đọc nhiệt độ BME280</span></h3>
      <table><tr><th>Mã</th><th>Tính năng</th><th>Trạng thái</th><th>Bằng chứng</th><th>Cổng</th></tr>
      <tr><td class="mono">F-01</td><td>Clock 84 MHz + SysTick 1 ms</td><td><span class="pill ok">passing</span></td><td>log#a91f… · G4 05/09 09:12</td><td>—</td></tr>
      <tr><td class="mono">F-02</td><td>UART2 telemetry 115200</td><td><span class="pill ok">passing</span></td><td>serial expect "HKW ready"</td><td>—</td></tr>
      <tr><td class="mono">F-03</td><td>I2C1 master 400 kHz</td><td><span class="pill ok">passing</span></td><td>logic analyzer #7 ACK</td><td>—</td></tr>
      <tr><td class="mono">F-04</td><td>MPU6050 đọc gia tốc</td><td><span class="pill ok">passing</span></td><td>số đo ±1 g</td><td>—</td></tr>
      <tr><td class="mono">F-05</td><td>Bộ lọc bù (complementary)</td><td><span class="pill ok">passing</span></td><td>SIL Renode + board</td><td>—</td></tr>
      <tr class="sel"><td class="mono">F-06</td><td>BME280 đọc nhiệt độ qua I2C1</td><td><span class="pill warn">failing · chờ G3</span></td><td>4 ToolReport đạt</td><td><span class="pill info">G3 diff #23</span></td></tr>
      <tr><td class="mono">F-07</td><td>PID cân bằng 200 Hz</td><td><span class="pill bad">failing</span></td><td>—</td><td>G1 chưa duyệt</td></tr>
      <tr><td class="mono">F-08</td><td>Watchdog + brown-out</td><td><span class="pill bad">failing</span></td><td>—</td><td>—</td></tr></table>
    </div>
    <div style="display:flex;flex-direction:column;gap:16px;flex:1">
      <div class="card"><h3>Hàng đợi xác nhận<span class="sp">mới nhất</span></h3>
        <div class="pad" style="display:flex;flex-direction:column;gap:8px">
          <div class="gate"><span class="tag">G3</span><span>Diff #23 driver_bme280.c · Reviewer (Claude) đạt · 4 ToolReport đạt</span><span class="btn p" style="margin-left:auto;height:26px">Xem diff</span></div>
          <div class="gate"><span class="tag">G-FACT</span><span>BME280 · nhóm "thanh ghi" 42 fact bạc chờ duyệt</span><span class="btn" style="margin-left:auto;height:26px">Duyệt</span></div>
          <div class="gate"><span class="tag">G-SRC</span><span>2 ứng viên datasheet MPU-9250 (tìm web)</span><span class="btn" style="margin-left:auto;height:26px">Chọn</span></div>
          <div class="gate"><span class="tag">G-OPS</span><span>Tác tử xin quyền nạp firmware kiểm tra I2C (phiên này)</span><span class="btn g" style="margin-left:auto;height:26px">Cấp quyền</span></div>
        </div></div>
      <div class="card" style="flex:1"><h3>Hoạt động tác tử<span class="sp">ledger · 10 phút gần nhất</span></h3>
        <div class="pad code" style="font-size:11.5px;color:#3d5064">12:31:04  coder     gemini-flash  CodePatch driver_bme280.c  cites 11 fact  1.9k tok
12:31:19  hooks     constant-guard  11/11 hằng số khớp hộ chiếu ✓
12:31:41  tools     build ✓ size ✓ (Flash 38%, RAM 22%) static ✓ test ✓
12:32:05  reviewer  claude-sonnet   verdict: PASS · 1 finding (timeout I2C)
12:32:06  gate      G3 mở → chờ kỹ sư</div></div>
    </div>
  </div>
</div>"""
write('Main', shell('Tổng quan dự án', 'robot-ctrl · WeAct BlackPill F411 · st.stm32f411@1.1.0', 'home', body, '<span class="btn t">+ Tính năng mới</span>'))

# ---------------------------------------------------------------- 2. Nhập tài liệu
body = f"""
<div class="card" style="flex:1.1">
  <h3>Kéo thả tài liệu<span class="sp">mọi định dạng được mở; tầng tin cậy quyết định đường đi</span></h3>
  <div class="pad" style="display:flex;flex-direction:column;gap:12px;flex:1">
    <div style="border:2px dashed #b8c4d3;border-radius:8px;flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;color:#5b6b7f;background:#fbfcfd">
      <svg width="34" height="34" viewBox="0 0 24 24" style="stroke:{NAVY};fill:none;stroke-width:1.5"><path d="M12 16V4m0 0l-4 4m4-4l4 4M4 17v3h16v-3"/></svg>
      <b style="color:{NAVY}">Thả PDF, SVD, ATDF, .zip, .kicad_sch, ảnh…</b><span class="hint">Hệ thống phân loại theo nội dung, không theo phần mở rộng; nén được mở đệ quy (giới hạn 5 cấp)</span>
    </div>
    <div style="display:flex;gap:8px"><span class="btn">Chọn tệp…</span><span class="btn">Từ registry…</span><span class="btn">Tìm trên web (cần xác nhận)</span></div>
  </div>
</div>
<div class="card" style="flex:1.6">
  <h3>Đã phân loại · bme280_kit.zip<span class="sp">9 tệp · 3 nguồn vàng · 2 bạc · 4 bỏ qua</span></h3>
  <table><tr><th>Tệp</th><th>Nhận diện</th><th>Tầng</th><th>Đường đi</th><th></th></tr>
  <tr><td class="mono">sdk/STM32F411.svd</td><td>CMSIS-SVD · STMicro · v1.1</td><td><span class="pill gold">vàng</span></td><td>Parser xác định → hộ chiếu (đã có, trùng hash)</td><td class="hint">bỏ qua</td></tr>
  <tr><td class="mono">sdk/inc/stm32f411xe.h</td><td>Header C chính hãng</td><td><span class="pill gold">vàng</span></td><td>Đối chiếu địa chỉ với SVD</td><td><span class="pill ok">khớp 100%</span></td></tr>
  <tr><td class="mono">hw/robot-ctrl.kicad_sch</td><td>KiCad 8 schematic</td><td><span class="pill gold">vàng-cấu trúc</span></td><td>kicad-cli netlist → BoardPassport (chờ duyệt)</td><td><span class="pill warn">G-FACT</span></td></tr>
  <tr class="sel"><td class="mono">docs/BST-BME280-DS002.pdf</td><td>Datasheet Bosch · 60 trang · có bảng</td><td><span class="pill silver">bạc</span></td><td>Docling → 42 fact thanh ghi, 9 điện · ảnh cắt</td><td><span class="pill warn">G-FACT</span></td></tr>
  <tr><td class="mono">docs/board_photo.jpg</td><td>Ảnh board (2.1 MP)</td><td><span class="pill silver">bạc</span></td><td>Mô hình thị giác → đề xuất 3 net</td><td><span class="pill warn">G-FACT</span></td></tr>
  <tr><td class="mono">docs/README.txt</td><td>Văn bản</td><td>—</td><td>Lưu làm ngữ cảnh, không sinh fact</td><td class="hint">bỏ qua</td></tr>
  <tr><td class="mono">notes/forum_thread.html</td><td>Diễn đàn</td><td><span class="pill bronze">đồng</span></td><td>Chỉ gợi ý; không vào hộ chiếu</td><td class="hint">bỏ qua</td></tr></table>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:10px;align-items:center"><span class="hint">Fact tầng bạc không vào mã cho tới khi anh duyệt tại G-FACT. PDF không được lưu vào gói chia sẻ, chỉ con trỏ + hash.</span><span class="btn p" style="margin-left:auto">Trích xuất 2 tệp bạc</span></div>
</div>"""
write('Ingest', shell('Nhập tài liệu', 'Acquisition · P1 nhận tri thức', 'in', body))

# ---------------------------------------------------------------- 3. Hàng đợi: chờ tôi / đã làm
body = f"""
<div class="card" style="width:360px">
  <h3>Chờ tôi<span class="sp">2 mục</span></h3>
  <div class="tree" style="padding:0 8px 8px">
    <div class="on"><span class="tag mono" style="background:{NAVY};color:#fff;padding:1px 5px;border-radius:3px;font-size:10.5px">G1</span>F-07 PID chạm động cơ · kế hoạch 9 bước</div>
    <div><span class="mono" style="background:#fff3d6;padding:1px 5px;border-radius:3px;font-size:10.5px">G-SRC</span>forum.st.com · nguồn ngoài danh sách tin cậy</div>
  </div>
  <h3>Đã làm — hoàn tác được<span class="sp">12 · đến 09:14</span></h3>
  <div class="tree" style="padding:0 8px 8px;font-size:12px">
    <div><span class="pill ok">auto</span>58 fact BME280 tự duyệt (G-FACT-02) <span class="hint" style="margin-left:auto">↩ 71h</span></div>
    <div><span class="pill ok">auto</span>merge m_0455 bme280 forced mode (G3-01) <span class="hint" style="margin-left:auto">↩ 23h</span></div>
    <div><span class="pill ok">auto</span>nạp nucleo-f411 fw 0.3 (G-OPS-01) <span class="hint" style="margin-left:auto">↩ phiên</span></div>
    <div><span class="pill ok">auto</span>tải rm0383.pdf st.com (G-SRC-01) <span class="hint" style="margin-left:auto">↩ 23h</span></div>
    <div><span class="pill ok">auto</span>cài renode 1.15 (G-OPS-04) <span class="hint" style="margin-left:auto">↩ 23h</span></div>
    <div><span class="pill ok">auto</span>công cụ user.hex_to_bin_crc chạy 3 lần (TOOL-02) <span class="hint" style="margin-left:auto">—</span></div>
  </div>
  <div class="pad hint" style="margin-top:auto;border-top:1px solid #eef1f5">Mục "chờ tôi" là quyết định chính sách trả ASK; mục "đã làm" là APPROVE có nhật ký, lý do (mã quy tắc) và nút hoàn tác.</div>
</div>
<div class="card" style="flex:1">
  <h3>G1 · F-07 PID cân bằng · chạm cơ cấu chấp hành<span class="sp">policy: ASK G1-99 (touches: actuator) · planner claude-opus · 9 bước · 0,4 USD ước lượng</span></h3>
  <div style="display:flex;flex:1;min-height:0">
    <div style="flex:1.3;overflow:hidden">
    <table><tr><th>#</th><th>Bước</th><th>Bởi</th><th>Trích dẫn</th><th>Chạm</th></tr>
    <tr><td>1</td><td>Đọc góc từ MPU6050 (DMP off), lọc bù</td><td>coder</td><td class="mono">f_5a1c, f_5a1d</td><td>—</td></tr>
    <tr><td>2</td><td>Timer 1 kHz TIM2 cho vòng điều khiển</td><td>coder</td><td class="mono">f_2201</td><td>isr</td></tr>
    <tr><td>3</td><td>PID rời rạc, chống bão hòa tích phân</td><td>coder</td><td>skill/control/pid</td><td>—</td></tr>
    <tr class="sel"><td>4</td><td>Xuất STEP/DIR A4988 qua TIM3 PWM</td><td>coder</td><td class="mono">f_a498, f_a499</td><td><span class="pill warn">actuator</span></td></tr>
    <tr><td>5</td><td>Giới hạn tốc độ và ngắt an toàn khi |góc| > 30°</td><td>coder</td><td>FR-SAF-01</td><td>actuator</td></tr>
    <tr><td>6–9</td><td>Test host PID · sim plant · HIL board không lab → hỏi từng lần nạp</td><td>tester</td><td>—</td><td>—</td></tr></table>
    </div>
    <div style="width:300px;border-left:1px solid #eef1f5;display:flex;flex-direction:column">
      <div class="pad" style="font-size:11px;color:#5b6b7f;font-weight:600;text-transform:uppercase;letter-spacing:.3px">Vì sao hỏi anh</div>
      <div class="pad" style="font-size:12px">Bước 4–5 điều khiển động cơ (lớp R4 khi chạy trên board robot-ctrl có cơ cấu chấp hành). Chính sách: G1-99 mặc định ASK vì <span class="mono">touches_forbidden=true</span>. Mọi bước khác đủ trích dẫn; không tài nguyên mới; ngân sách trong hạn.</div>
      <div class="pad" style="margin-top:auto;display:flex;flex-direction:column;gap:8px;border-top:1px solid #eef1f5">
        <span class="btn p">Duyệt kế hoạch (G1)</span>
        <div style="display:flex;gap:8px"><span class="btn" style="flex:1">Sửa bước</span><span class="btn d" style="flex:1">Từ chối</span></div>
        <span class="hint">Câu trả lời được ghi decision_log (by=human) và làm dữ liệu học ngưỡng.</span>
      </div>
    </div>
  </div>
</div>"""
write('ReviewQueue', shell('Chờ tôi / Đã làm', 'Hàng đợi hai loại · quyết định chính sách có mã quy tắc · hoàn tác trong cửa sổ', 'queue', body))

# ---------------------------------------------------------------- 4. Hộ chiếu chip
body = f"""
<div class="card" style="width:300px">
  <h3>st.stm32f411@1.1.0<span class="sp"><span class="pill gold">vàng</span></span></h3>
  <div class="pad" style="display:flex;flex-direction:column;gap:6px;border-bottom:1px solid #eef1f5">
    <div class="hint">STMicroelectronics · Cortex-M4F · SVD v1.1 · 13.439 fact · badge <span class="pill ok">verified_on_board</span></div>
    <div class="search" style="width:auto;margin:0">{ICONS['search']}<span>Lọc ngoại vi / thanh ghi</span></div>
  </div>
  <div class="tree" style="padding:6px 8px;overflow:hidden">
    <div>▸ GPIOA · GPIOB · GPIOC (3)</div><div>▸ RCC</div><div>▾ I2C1 <span class="hint">0x4000 5400</span></div>
    <div style="padding-left:24px" class="on">CR1 <span class="hint">+0x00</span></div><div style="padding-left:24px">CR2 <span class="hint">+0x04</span></div><div style="padding-left:24px">OAR1 <span class="hint">+0x08</span></div><div style="padding-left:24px">DR <span class="hint">+0x10</span></div><div style="padding-left:24px">SR1 <span class="hint">+0x14</span></div><div style="padding-left:24px">CCR <span class="hint">+0x1C</span></div><div style="padding-left:24px">TRISE <span class="hint">+0x20</span></div>
    <div>▸ I2C2 · I2C3 <span class="hint">derivedFrom I2C1</span></div><div>▸ USART1 · USART2 · USART6</div><div>▸ TIM1 … TIM11</div><div>▸ SPI1 … SPI5</div><div>▸ NVIC · SCB · SysTick</div>
  </div>
</div>
<div class="card" style="flex:1">
  <h3>I2C1 → CR1 <span class="mono" style="font-weight:500;text-transform:none">chip:st.stm32f411/periph:I2C1/reg:CR1</span><span class="sp">offset 0x00 · 32 bit · read-write · reset 0x0000 0000</span></h3>
  <table><tr><th>Field</th><th>Bit</th><th>Mô tả</th><th>Tầng · trạng thái</th><th>Nguồn</th></tr>
  <tr><td class="mono">PE</td><td class="mono">[0]</td><td>Peripheral enable</td><td><span class="pill gold">vàng</span> reviewed</td><td class="mono hint">svd#I2C1/CR1/PE</td></tr>
  <tr><td class="mono">SMBUS</td><td class="mono">[1]</td><td>SMBus mode</td><td><span class="pill gold">vàng</span> reviewed</td><td class="mono hint">svd#…</td></tr>
  <tr><td class="mono">ENARP</td><td class="mono">[4]</td><td>ARP enable</td><td><span class="pill gold">vàng</span> reviewed</td><td class="mono hint">svd#…</td></tr>
  <tr class="sel"><td class="mono">ACK</td><td class="mono">[10]</td><td>Acknowledge enable</td><td><span class="pill gold">vàng</span> verified</td><td class="mono hint">svd#… · probe đọc 05/09</td></tr>
  <tr><td class="mono">POS</td><td class="mono">[11]</td><td>Acknowledge/PEC position</td><td><span class="pill gold">vàng</span> reviewed</td><td class="mono hint">svd#…</td></tr>
  <tr><td class="mono">STOP</td><td class="mono">[9]</td><td>Stop generation</td><td><span class="pill gold">vàng</span> reviewed</td><td class="mono hint">svd#…</td></tr>
  <tr><td class="mono">SWRST</td><td class="mono">[15]</td><td>Software reset</td><td><span class="pill silver">bạc · overlay</span> reviewed</td><td class="mono hint">errata ES0287 §2.4.1 · community.stm32f4-errata@0.3.0</td></tr></table>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:16px">
    <div class="card" style="flex:1"><h3>Provenance · fact f_1a2b9c…</h3><div class="pad code" style="font-size:11.5px">subject   chip:st.stm32f411/periph:I2C1/reg:CR1/field:ACK
predicate bit_range   value {{lsb:10, msb:10}}
source    s_262da1b0…  STM32F411.svd  sha256 9e41…  tier gold
locator   //peripheral[name='I2C1']//register[name='CR1']//field[name='ACK']
status    verified   by cong  05/09/2026 09:14   badge log#a91f
cited by  drivers/i2c_stm32.c:88   driver_bme280.c:41</div></div>
    <div class="card" style="width:300px"><h3>Mã đang trích dẫn</h3><div class="pad code" style="font-size:11.5px">I2C1->CR1 |= I2C_CR1_ACK;
/* hkw:fact f_1a2b9c… */
…
kg.impact → 2 CodeUnit sẽ stale nếu fact đổi</div></div>
  </div>
</div>"""
write('Passport', shell('Hộ chiếu chip', 'Passport Store · lớp L-A lõi + L-B lớp phủ · pin st.stm32f411@1.1.0', 'chip', body, '<span class="btn">So sánh với v1.2</span><span class="btn t">Kiểm định trên board</span>'))

# ---------------------------------------------------------------- 5. Hộ chiếu mạch
body = f"""
<div class="card" style="flex:1.3">
  <h3>weact.blackpill-f411 + robot-ctrl rev B<span class="sp">từ robot-ctrl.kicad_sch · 31 net · 2 chip · 6 linh kiện ngoài</span></h3>
  <table><tr><th>Net</th><th>Chân MCU</th><th>Chức năng (AF)</th><th>Linh kiện</th><th>Ràng buộc</th><th>Kiểm tra</th></tr>
  <tr><td class="mono">I2C1_SCL</td><td class="mono">U1.PB6</td><td>I2C1_SCL (AF4)</td><td>U2 BME280.SCL · U3 MPU6050.SCL</td><td>pull-up 4k7 → 3V3</td><td><span class="pill ok">OK</span></td></tr>
  <tr><td class="mono">I2C1_SDA</td><td class="mono">U1.PB7</td><td>I2C1_SDA (AF4)</td><td>U2.SDA · U3.SDA</td><td>pull-up 4k7</td><td><span class="pill ok">OK</span></td></tr>
  <tr><td class="mono">BME_SDO</td><td>—</td><td>—</td><td>U2.SDO → GND</td><td>địa chỉ I2C = 0x76</td><td><span class="pill ok">suy ra</span></td></tr>
  <tr class="sel"><td class="mono">LED_STATUS</td><td class="mono">U1.PB3</td><td>GPIO out</td><td>D1 LED + R5 330Ω</td><td>—</td><td><span class="pill bad">xung đột: PB3 = SPI1_MOSI đang USES bởi drv_spi_flash.c</span></td></tr>
  <tr><td class="mono">STEP_L</td><td class="mono">U1.PA8</td><td>TIM1_CH1 (AF1)</td><td>U4 A4988.STEP</td><td>5 V tolerant</td><td><span class="pill ok">OK</span></td></tr>
  <tr><td class="mono">DIR_L</td><td class="mono">U1.PA9</td><td>GPIO out</td><td>U4.DIR</td><td>—</td><td><span class="pill ok">OK</span></td></tr>
  <tr><td class="mono">UART2_TX</td><td class="mono">U1.PA2</td><td>USART2_TX (AF7)</td><td>J3 header</td><td>—</td><td><span class="pill ok">OK</span></td></tr>
  <tr><td class="mono">SWDIO / SWCLK</td><td class="mono">U1.PA13 / PA14</td><td>debug</td><td>J1 SWD</td><td>reserved</td><td><span class="pill warn">reserved: cấm dùng GPIO</span></td></tr>
  <tr><td class="mono">BOOT0</td><td class="mono">U1.PB2</td><td>boot</td><td>SW1</td><td>boot pin</td><td><span class="pill warn">reserved</span></td></tr></table>
</div>
<div style="display:flex;flex-direction:column;gap:16px;width:420px">
  <div class="card"><h3>Xung đột tài nguyên (kg.conflicts)</h3>
    <div class="pad" style="display:flex;flex-direction:column;gap:10px">
      <div style="border:1px solid #f1c7c3;background:#fff7f6;border-radius:6px;padding:10px;display:flex;flex-direction:column;gap:6px">
        <b style="color:#9b1c14">PB3: LED_STATUS (mạch rev B) ↔ SPI1_MOSI (drv_spi_flash.c)</b>
        <span class="hint">Nguồn: net từ kicad_sch (vàng-cấu trúc) · USES từ phân tích mã. Hai lựa chọn: đổi LED sang PC13 (trống) hoặc remap SPI1 sang PA7 (AF5).</span>
        <div style="display:flex;gap:8px"><span class="btn" style="height:26px">Đề xuất PC13</span><span class="btn" style="height:26px">Remap SPI1</span><span class="btn" style="height:26px">Bỏ qua có lý do</span></div>
      </div>
      <div style="border:1px solid #f1dcb0;background:#fffaf0;border-radius:6px;padding:10px"><b style="color:#7a5200">I2C1 pull-up 4k7 với 400 kHz và 2 slave</b><span class="hint"> · trong ngưỡng theo fact BME280 tr.32; cảnh báo nếu thêm slave thứ 3</span></div>
    </div></div>
  <div class="card" style="flex:1"><h3>Ràng buộc mạch → cho Coder</h3><div class="pad code" style="font-size:11.5px">reserved_pins: [PA13, PA14, PB2]
buses:
  I2C1: {{speed_max: 400kHz, pullup: 4k7, slaves: [0x76 BME280, 0x68 MPU6050]}}
power: {{vdd: 3.3V, io_max: 25mA, reg: ME6211 500mA}}
stepper: {{driver: A4988, step_pin: PA8/TIM1_CH1, microstep: 1/16}}
sources: [robot-ctrl.kicad_sch sha256 7c2e…, board_photo.jpg (bạc)]</div></div>
</div>"""
write('Board', shell('Hộ chiếu mạch', 'BoardPassport · P1 (E3 KiCad) · Cartographer', 'board', body, '<span class="btn">Nhập lại từ KiCad</span><span class="btn p">Duyệt BoardPassport (G-FACT)</span>'))

# ---------------------------------------------------------------- 6. Đồ thị
def node(x,y,label,fill,stroke,w=150):
    return f'<g><rect x="{x-w/2}" y="{y-16}" width="{w}" height="32" rx="6" fill="{fill}" stroke="{stroke}" stroke-width="1.4"/><text x="{x}" y="{y+4}" text-anchor="middle" font-family="IBM Plex Mono, monospace" font-size="11" fill="#1b2430">{label}</text></g>'
def edge(x1,y1,x2,y2,label,color='#8a97a8'):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="1.3" marker-end="url(#ar)"/><text x="{(x1+x2)/2}" y="{(y1+y2)/2-6}" text-anchor="middle" font-family="IBM Plex Sans" font-size="10" fill="{color}">{label}</text>'
svg = f'''<svg viewBox="0 0 840 560" width="840" height="560" style="background:#fbfcfd;border-radius:6px">
<defs><marker id="ar" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#8a97a8"/></marker></defs>
{edge(420,80,420,160,'HAS')}{edge(420,190,250,270,'HAS')}{edge(420,190,590,270,'HAS')}
{edge(250,300,250,380,'HAS')}{edge(590,300,590,380,'HAS')}
{edge(130,470,240,405,'CITES','#0C3B70')}{edge(130,470,120,300,'USES','#0C3B70')}
{edge(720,470,600,405,'CITES','#0C3B70')}{edge(420,530,250,405,'CITES','#0C3B70')}
{edge(720,150,600,175,'CONNECTS','#1FC3A6')}{edge(720,150,720,240,'HAS','#1FC3A6')}
{edge(150,120,330,170,'SUPERSEDES','#b3261e')}
{node(420,80,'chip:st.stm32f411','#fff3d6','#F8B942')}
{node(420,175,'periph:I2C1  0x40005400','#fff3d6','#F8B942',180)}
{node(250,285,'reg:CR1  +0x00','#fff3d6','#F8B942')}{node(590,285,'reg:CCR  +0x1C','#fff3d6','#F8B942')}
{node(250,395,'field:ACK [10]','#fff3d6','#F8B942')}{node(590,395,'field:CCR [11:0]','#fff3d6','#F8B942')}
{node(120,285,'pin:PB6  I2C1_SCL AF4','#e6effa','#0C3B70',170)}
{node(150,120,'overlay: SWRST errata','#e8eef5','#3d5064',170)}
{node(720,150,'board:robot-ctrl/net:I2C1_SCL','#e6faf5','#1FC3A6',210)}
{node(720,255,'part:U2 bosch.bme280 @0x76','#e6faf5','#1FC3A6',210)}
{node(130,480,'code: drivers/i2c_stm32.c','#fff','#0C3B70',180)}{node(720,480,'code: driver_bme280.c','#fff','#0C3B70',170)}
{node(420,530,'DebugSession #12 · NACK','#fde3e1','#b3261e',190)}
</svg>'''
body = f"""
<div class="card" style="flex:1"><h3>Lân cận của periph:I2C1 · độ sâu 2<span class="sp">vàng = lõi chip · xanh = mạch · navy = mã · đỏ = kinh nghiệm</span></h3>
  <div class="pad" style="display:flex;justify-content:center">{svg}</div></div>
<div style="display:flex;flex-direction:column;gap:16px;width:360px">
  <div class="card"><h3>Truy vấn nhanh</h3><div class="pad" style="display:flex;flex-direction:column;gap:8px">
    <span class="btn">Xung đột tài nguyên trong dự án</span><span class="btn">Ảnh hưởng nếu fact CR1.ACK đổi</span><span class="btn">Mã nào đã chứng minh trên board?</span><span class="btn">Lỗi hiện trường → thanh ghi → nguồn</span></div></div>
  <div class="card" style="flex:1"><h3>kg.impact(f_1a2b9c…)</h3><div class="pad code" style="font-size:11.5px">stale_code_units:
  - drivers/i2c_stm32.c:88   (F-03 passing)
  - driver_bme280.c:41       (F-06 chờ G3)
features_to_reverify: [F-03, F-04, F-06]
superseded_by: []   # fact còn hiện hành
evidence: log#a91f (05/09 09:14), probe read CR1=0x0401</div></div>
</div>"""
write('Graph', shell('Đồ thị tri thức', 'KnowledgeGraph · 3.757 nút · 6.735 cạnh cho chip này', 'graph', body))

# ---------------------------------------------------------------- 7. Kế hoạch & diff
body = f"""
<div class="card" style="width:400px"><h3>Kế hoạch F-06 (đã duyệt G1)<span class="sp">Planner · claude-opus · 5 bước</span></h3>
  <div class="pad" style="display:flex;flex-direction:column;gap:8px">
    <div class="gate"><b class="mono">1</b><span>Khai báo BME280 tại 0x76 trên I2C1 <span class="hint">[f_b1…, f_b2…]</span></span><span class="pill ok" style="margin-left:auto">✓</span></div>
    <div class="gate"><b class="mono">2</b><span>Đọc id 0xD0, kỳ vọng 0x60 <span class="hint">[f_b3…]</span></span><span class="pill ok" style="margin-left:auto">✓</span></div>
    <div class="gate"><b class="mono">3</b><span>Đọc 24 byte hiệu chuẩn 0x88–0xA1 <span class="hint">[f_b7…]</span></span><span class="pill ok" style="margin-left:auto">✓</span></div>
    <div class="gate" style="border-color:{TEAL}"><b class="mono">4</b><span>ctrl_meas: osrs_t=1, mode=normal <span class="hint">[f_b4…, f_b5…]</span></span><span class="pill info" style="margin-left:auto">đang</span></div>
    <div class="gate"><b class="mono">5</b><span>Bù nhiệt độ theo công thức tr.25; phát UART</span><span class="hint" style="margin-left:auto">—</span></div>
    <div class="hint">Ràng buộc: không float trong ISR · timeout I2C 5 ms · Flash &lt; 50%</div>
  </div></div>
<div class="card" style="flex:1"><h3>G3 · Diff #23 · driver_bme280.c<span class="sp">Coder gemini-flash · Reviewer claude-sonnet · 4 ToolReport</span></h3>
  <div style="display:flex;flex:1;min-height:0">
    <div class="code" style="flex:1;padding:12px 14px;overflow:hidden;font-size:11.5px;border-right:1px solid #eef1f5">
<span style="color:#7b8a9c">@@ -38,6 +38,19 @@ int bme280_init(void)</span>
 <span style="color:#7b8a9c">/* hkw:fact f_b3c4… id register */</span>
 uint8_t id = i2c_read8(BME280_ADDR, 0xD0);
<span style="background:#dff5ee">+    if (id != 0x60) return -ENODEV;   /* hkw:fact f_b3c4… */</span>
<span style="background:#dff5ee">+    /* hkw:fact f_b4d1… ctrl_meas 0xF4; f_b5e2… osrs_t [7:5]; mode [1:0] */</span>
<span style="background:#dff5ee">+    uint8_t ctrl = (1u &lt;&lt; 5) | 0x3u;</span>
<span style="background:#dff5ee">+    if (i2c_write8(BME280_ADDR, 0xF4, ctrl, I2C_TIMEOUT_MS) != 0)</span>
<span style="background:#dff5ee">+        return -EIO;</span>
<span style="background:#fde3e1">-    i2c_write8(BME280_ADDR, 0xF4, 0x27);</span>
 <span style="color:#7b8a9c">/* đọc hiệu chuẩn */</span>
<span style="background:#dff5ee">+    /* hkw:fact f_b7a0… calib 0x88..0xA1 (26 byte) */</span>
<span style="background:#dff5ee">+    i2c_read(BME280_ADDR, 0x88, calib, 26, I2C_TIMEOUT_MS);</span></div>
    <div style="width:330px;display:flex;flex-direction:column">
      <div class="pad" style="display:flex;flex-direction:column;gap:6px;border-bottom:1px solid #eef1f5">
        <b style="font-size:12px">Bốn cổng công cụ</b>
        <div class="gate" style="padding:6px 10px"><span class="pill ok">build</span><span class="hint">0 warning · 3,1 s</span></div>
        <div class="gate" style="padding:6px 10px"><span class="pill ok">size</span><span class="hint">Flash 38% · RAM 22%</span></div>
        <div class="gate" style="padding:6px 10px"><span class="pill ok">static</span><span class="hint">cppcheck 0 · quy tắc Pack 0</span></div>
        <div class="gate" style="padding:6px 10px"><span class="pill ok">host-test</span><span class="hint">12/12 · mock I2C</span></div>
      </div>
      <div class="pad" style="display:flex;flex-direction:column;gap:6px;border-bottom:1px solid #eef1f5">
        <b style="font-size:12px">Rationale (Coder)</b><span class="hint">Kiểm id trước khi cấu hình vì datasheet quy định 0x60 [f_b3c4]; dùng timeout theo ràng buộc dự án; thay hằng số 0x27 bằng biểu thức có fact để constant-guard truy vết.</span>
        <b style="font-size:12px">Reviewer (khác hãng)</b><span class="hint">PASS · 1 phát hiện: nên kiểm giá trị trả về của i2c_read hiệu chuẩn (không chặn).</span>
        <b style="font-size:12px">Constant-guard</b><span class="hint">11/11 hằng số khớp fact reviewed/verified.</span>
      </div>
      <div class="pad" style="margin-top:auto;display:flex;gap:8px"><span class="btn p" style="flex:1">Duyệt & merge</span><span class="btn d">Từ chối…</span></div>
    </div>
  </div></div>"""
write('PlanDiff', shell('Kế hoạch & mã', 'P2 lập kế hoạch (G1) · P3 sinh mã (G3)', 'plan', body, '<span class="btn">Gửi sang IDE (MCP)</span>'))

# ---------------------------------------------------------------- 8. Log & serial (GEditor)
lines = ''.join(f'<div style="display:flex;gap:12px"><span style="color:#8a97a8;width:88px;text-align:right">{4213000+i}</span><span style="color:#5b6b7f">12:4{i%10}:{(17+i*3)%60:02d}.{(i*137)%1000:03d}</span><span style="color:{c}">{t}</span></div>' for i,(t,c) in enumerate([
 ('[I2C] start addr=0x76 W', '#1b2430'),('[I2C] ACK', '#0b6b52'),('[BME] ctrl_meas=0x23', '#1b2430'),('[I2C] start addr=0x76 R len=8', '#1b2430'),('[I2C] NACK after byte 3', '#9b1c14'),('[BME] read fail -EIO (2)', '#9b1c14'),('[I2C] SR1=0x0400 AF=1', '#9b1c14'),('[PID] loop 200Hz ok', '#1b2430'),('[I2C] start addr=0x76 R len=8', '#1b2430'),('[I2C] NACK after byte 3', '#9b1c14'),('[WDT] kick', '#1b2430')]))
body = f"""
<div class="card" style="flex:1.5"><h3>serial-3.log · 3,1 GB · 41,2 triệu dòng<span class="sp">GEditor engine · thống kê toàn tệp 2,4 s</span></h3>
  <div class="pad" style="display:flex;gap:8px;border-bottom:1px solid #eef1f5"><span class="pill bad">NACK ×1.204</span><span class="pill warn">-EIO ×1.204</span><span class="pill info">chu kỳ lỗi ≈ 18,0 s</span><span class="pill info">bắt đầu 12:40:17 (sau 6 h 12 m)</span><span class="hint" style="margin-left:auto">đã chọn 200 dòng</span></div>
  <div class="code" style="padding:10px 14px;font-size:11.5px;flex:1;background:#fff;border-left:3px solid {TEAL};margin:0 14px 10px;overflow:hidden">{lines}</div>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:8px;align-items:center"><span class="btn t">Hỏi tác tử tại dòng này</span><span class="btn">Đồng bộ với waveform #7</span><span class="hint">Gửi: 200 dòng + thống kê + hộ chiếu I2C1 + mã USES — không gửi 3 GB</span></div>
</div>
<div style="display:flex;flex-direction:column;gap:16px;width:440px">
  <div class="card" style="flex:1"><h3>Debugger · trả lời neo dòng 4.213.004</h3>
    <div class="pad" style="display:flex;flex-direction:column;gap:8px;font-size:12.5px">
      <b>Giả thuyết xếp hạng</b>
      <div class="gate"><b class="mono">1</b><span>Pull-up I2C yếu khi thêm slave: SR1.AF sau byte 3, lặp 18 s trùng chu kỳ đọc MPU6050 <span class="hint">[f_1a2b CR1.ACK · f_9f… SR1.AF · K3 pull-up 4k7]</span></span><span class="pill ok" style="margin-left:auto">0,71</span></div>
      <div class="gate"><b class="mono">2</b><span>Timeout 5 ms quá ngắn khi bus bận</span><span class="pill silver" style="margin-left:auto">0,18</span></div>
      <div class="gate"><b class="mono">3</b><span>BME280 chưa thoát sleep sau ctrl_meas</span><span class="pill silver" style="margin-left:auto">0,11</span></div>
      <b>Thí nghiệm phân biệt</b><span class="hint">Đọc SR1/SR2 qua probe ngay khi NACK (breakpoint tại i2c_read:57) và bắt sóng SCL/SDA; nếu SDA không lên 3V3 trong 1 µs → giả thuyết 1.</span>
      <div style="display:flex;gap:8px"><span class="btn g">Xin quyền chạy thí nghiệm (G-OPS)</span><span class="btn">Lưu DebugSession</span></div>
    </div></div>
  <div class="card"><h3>Serial console · /dev/tty.usbmodem3 115200</h3><div class="pad code" style="font-size:11.5px">&gt; bme status
BME280 id=0x60 mode=normal t=27.41C
&gt; _</div></div>
</div>"""
write('LogAssist', shell('Log & serial', 'Bề mặt quan sát · GEditor · P5 gỡ lỗi', 'log', body, '<span class="btn">Mở waveform</span>', tabs=('serial-3.log','driver_bme280.c','Tổng quan')))

# ---------------------------------------------------------------- 9. Gỡ lỗi probe
body = f"""
<div class="card" style="width:360px"><h3>Probe · ST-Link V3 → STM32F411 (SWD)<span class="sp"><span class="pill ok">halted</span></span></h3>
  <div class="pad" style="display:flex;gap:8px;flex-wrap:wrap"><span class="btn">Run</span><span class="btn">Step</span><span class="btn">Reset</span><span class="btn d">Write mem (cần G-OPS)</span></div>
  <div class="pad code" style="font-size:11.5px;border-top:1px solid #eef1f5">PC   0x0800 2A3C  i2c_read+0x38
LR   0x0800 31F1  bme280_read_raw+0x1D
SP   0x2001 FE90
xPSR 0x6100 0000
CFSR 0x0000 0000   (không fault)
I2C1.SR1 = 0x0400  AF=1 ← NACK
I2C1.SR2 = 0x0002  BUSY=1
I2C1.CR1 = 0x0401  PE=1 ACK=1
RTT ch0: "[I2C] NACK after byte 3"</div>
  <div class="pad" style="border-top:1px solid #eef1f5"><b style="font-size:12px">Breakpoint</b><div class="hint">i2c_read:57 (điều kiện SR1&amp;0x0400) · đã trúng 3 lần</div></div>
</div>
<div class="card" style="flex:1"><h3>Gói chứng cứ · DebugSession #12<span class="sp">liên kết fact, mã, log range, waveform</span></h3>
  <div class="pad" style="display:grid;grid-template-columns:repeat(2, minmax(0, 1fr));gap:12px">
    <div class="card"><h3>Waveform #7 · sigrok I2C decode</h3><div class="pad">
      <svg viewBox="0 0 400 110" width="100%" height="110"><rect width="400" height="110" fill="#fbfcfd"/>
      <text x="4" y="14" font-size="10" fill="#5b6b7f">SCL</text><polyline points="30,30 60,30 60,10 90,10 90,30 120,30 120,10 150,10 150,30 180,30 180,10 210,10 210,30 240,30 240,10 270,10 270,30 300,30 300,10 330,10 330,30 380,30" fill="none" stroke="#0C3B70" stroke-width="1.5"/>
      <text x="4" y="64" font-size="10" fill="#5b6b7f">SDA</text><polyline points="30,80 45,80 45,60 75,60 75,80 135,80 135,60 165,60 165,80 225,80 225,66 300,66 300,80 380,80" fill="none" stroke="#1FC3A6" stroke-width="1.5"/>
      <rect x="225" y="52" width="75" height="34" fill="rgba(179,38,30,.10)" stroke="#b3261e" stroke-dasharray="3 2"/><text x="228" y="100" font-size="10" fill="#b3261e">SDA chỉ lên 2,1 V → NACK</text>
      <text x="40" y="100" font-size="10" fill="#5b6b7f">S 0x76 R · A · D0 · A · D1 · A · D2 · N</text></svg></div></div>
    <div class="card"><h3>Đo tại NACK</h3><div class="pad code" style="font-size:11.5px">VDD          3,29 V
SDA high     2,08 V   (ngưỡng VIH 2,31 V)
SCL rise     1,4 µs   (max 0,3 µs @400k)
I_bus        1,7 mA
kết luận     pull-up 4k7 quá yếu với 2 slave
             + cáp 30 cm → giả thuyết 1 ✓</div></div>
    <div class="card"><h3>Fact liên quan</h3><div class="pad code" style="font-size:11.5px">f_1a2b… I2C1/CR1/ACK [10]        vàng verified
f_9f3e… I2C1/SR1/AF  [10]        vàng reviewed
f_b7c1… bme280 t_rise max 300ns  bạc reviewed tr.33
K3      I2C1 pull-up 4k7          vàng-cấu trúc</div></div>
    <div class="card"><h3>Đề xuất và bước tiếp</h3><div class="pad" style="display:flex;flex-direction:column;gap:8px;font-size:12.5px">
      <span>Sửa phần cứng: đổi R3/R4 thành 2k2 (mở G-FACT cho K3) hoặc giảm bus xuống 100 kHz (sửa K6 ràng buộc → G1).</span>
      <div style="display:flex;gap:8px"><span class="btn p">Tạo STEP "giảm I2C1 xuống 100 kHz"</span><span class="btn">Ghi sổ lỗi</span></div></div></div>
  </div></div>"""
write('Debug', shell('Gỡ lỗi probe', 'P5 · embedded-debugger-mcp (probe-rs) · EvidencePack', 'bug', body, '<span class="btn d">Ngắt kết nối</span>'))

# ---------------------------------------------------------------- 10. Registry
body = f"""
<div class="card" style="flex:1"><h3>Registry nội bộ · git@code247/hkw-registry<span class="sp">1.312 gói · 640 hạt giống · 24 đã kiểm định · 9 cộng đồng</span></h3>
  <div class="pad" style="display:flex;gap:8px;border-bottom:1px solid #eef1f5"><div class="search" style="margin:0;width:360px">{ICONS['search']}<span>bme280</span></div><span class="pill ok">đã kiểm định</span><span class="pill silver">chính hãng</span><span class="pill silver">cộng đồng</span><span class="pill silver">chưa kiểm định</span></div>
  <table><tr><th>Gói</th><th>Loại</th><th>Tầng</th><th>Huy hiệu</th><th>Benchmark</th><th>Người phát hành</th><th></th></tr>
  <tr class="sel"><td class="mono">bosch.bme280@0.3.0</td><td>chip (ngoại vi ngoài)</td><td><span class="pill silver">bạc</span></td><td><span class="pill ok">verified_on_board ×3</span></td><td>Claude 10/10 · Gemini 9/10 · local 7/10</td><td>cong@mobiluck · ký minisign</td><td><span class="btn" style="height:26px">Pull</span></td></tr>
  <tr><td class="mono">st.stm32f411@1.1.0</td><td>chip (lõi)</td><td><span class="pill gold">vàng</span></td><td><span class="pill ok">verified_on_board</span> <span class="pill info">vendor SVD</span></td><td>—</td><td>seed (CMSIS pack)</td><td><span class="btn" style="height:26px">Pull</span></td></tr>
  <tr><td class="mono">community.stm32f4-errata@0.3.0</td><td>overlay</td><td><span class="pill silver">bạc</span></td><td><span class="pill silver">cộng đồng</span></td><td>—</td><td>hv-k12 (học viên)</td><td><span class="btn" style="height:26px">Pull</span></td></tr>
  <tr><td class="mono">skills.armv7e-m@2.1.0</td><td>skill (K5)</td><td>—</td><td><span class="pill ok">bench BC 93%</span></td><td>10 tác vụ · 2 mô hình</td><td>cong@mobiluck</td><td><span class="btn" style="height:26px">Pull</span></td></tr>
  <tr><td class="mono">nordic.nrf52840@1.0.0</td><td>chip (lõi)</td><td><span class="pill gold">vàng</span></td><td><span class="pill warn">unverified</span></td><td>—</td><td>seed</td><td><span class="btn" style="height:26px">Pull</span></td></tr>
  <tr><td class="mono">weact.blackpill-f411@1.0.0</td><td>board</td><td><span class="pill gold">vàng-cấu trúc</span></td><td><span class="pill ok">verified_on_board</span></td><td>—</td><td>cong@mobiluck</td><td><span class="btn" style="height:26px">Pull</span></td></tr></table>
</div>
<div class="card" style="width:400px"><h3>bosch.bme280@0.3.0<span class="sp">.hkp · 184 KB</span></h3>
  <div class="pad code" style="font-size:11.5px">manifest
  kind: chip   license: CC-BY-4.0 (fact) · nguồn PDF: con trỏ+hash
  deps: []     signature: minisign RW…9e ✓
badges
  verified_on_board  weact.blackpill-f411  05/09/2026  cong  log#a91f
  verified_on_board  nucleo-f411re        02/09/2026  hv-k07
  bench  claude-sonnet 10/10 · gemini-flash 9/10 · qwen-14b 7/10
contents
  passport.yaml   58 fact (49 bạc reviewed, 9 điện)
  skills/bme280_init.md   1 skill · 420 token
  bench/read_temp.yaml    kịch bản HIL</div>
  <div class="pad" style="margin-top:auto;display:flex;flex-direction:column;gap:8px;border-top:1px solid #eef1f5"><span class="btn p">Pull vào dự án (G-SRC)</span><span class="btn">Xem diff với bản đang dùng 0.2.1</span><span class="hint">Gói không chứa tài liệu của hãng; anh cần có PDF gốc để xem ảnh cắt.</span></div>
</div>"""
write('Registry', shell('Registry', 'P6 · gói .hkp có chữ ký và huy hiệu', 'pkg', body, '<span class="btn t">Đóng gói & phát hành (G5)</span>'))

# ---------------------------------------------------------------- 11. Mô hình & chi phí
body = f"""
<div class="card" style="flex:1"><h3>models.yaml · vai trò → mô hình<span class="sp">offline_mode: <b style="color:#0b6b52">bật</b> · reviewer khác hãng với coder</span></h3>
  <table><tr><th>Vai trò</th><th>Ứng viên (thứ tự)</th><th>Đang dùng</th><th>Quy tắc</th><th>Hôm nay</th></tr>
  <tr><td>librarian</td><td class="mono">gemini-flash → local/qwen</td><td class="pill info">local/qwen (offline)</td><td>—</td><td>38 lượt · 0,00 USD</td></tr>
  <tr><td>cartographer</td><td class="mono">claude-sonnet → gemini-pro</td><td class="pill info">local/qwen (offline)</td><td>inputs: image</td><td>2 lượt</td></tr>
  <tr><td>planner</td><td class="mono">claude-opus → gemini-pro</td><td class="pill info">local/qwen (offline)</td><td>min_context 200k</td><td>3 lượt</td></tr>
  <tr><td>coder</td><td class="mono">gemini-flash → claude-sonnet</td><td class="pill info">local/qwen (offline)</td><td>temperature 0</td><td>61 lượt</td></tr>
  <tr><td>reviewer</td><td class="mono">claude-sonnet → gemini-pro</td><td class="pill warn">local/qwen (cảnh báo: cùng hãng với coder)</td><td class="mono">different_vendor_from(coder)</td><td>61 lượt</td></tr>
  <tr><td>debugger</td><td class="mono">claude-sonnet → gemini-pro</td><td class="pill info">local/qwen (offline)</td><td>—</td><td>9 lượt</td></tr></table>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:16px">
    <div class="field" style="flex:1"><label>Ngân sách ngày (USD)</label><div class="in mono">5.00</div></div>
    <div class="field" style="flex:1"><label>Ngữ cảnh tối đa / lượt (token)</label><div class="in mono">8000</div></div>
    <div class="field" style="flex:1"><label>Chế độ cục bộ (egress-guard)</label><div class="in">Bật — 0 kết nối ngoài, chặn tải tài liệu</div></div>
  </div></div>
<div style="display:flex;flex-direction:column;gap:16px;width:420px">
  <div class="card"><h3>Chi phí tuần này (ledger)</h3><div class="pad">
    <svg viewBox="0 0 380 150" width="100%" height="150"><rect width="380" height="150" fill="#fbfcfd"/>
    {''.join(f'<rect x="{30+i*48}" y="{130-h}" width="30" height="{h}" fill="{TEAL if i<5 else "#c6d3e3"}"/><text x="{45+i*48}" y="145" font-size="10" text-anchor="middle" fill="#5b6b7f">{d}</text><text x="{45+i*48}" y="{124-h}" font-size="10" text-anchor="middle" fill="#0C3B70">{v}</text>' for i,(d,h,v) in enumerate([('T2',62,'1,24'),('T3',88,'1,76'),('T4',41,'0,82'),('T5',95,'1,90'),('T6',21,'0,42'),('T7',0,''),('CN',0,'')]))}
    <text x="30" y="14" font-size="10" fill="#5b6b7f">USD/ngày · T6 chuyển offline từ 09:00</text></svg></div></div>
  <div class="card" style="flex:1"><h3>Kiểm thử hợp đồng Gateway<span class="sp">5 ca × 3 adapter</span></h3>
    <table><tr><th>Ca</th><th>Claude</th><th>Gemini</th><th>Cục bộ</th></tr>
    <tr><td>Tool lồng 2 cấp</td><td><span class="pill ok">✓</span></td><td><span class="pill ok">✓</span></td><td><span class="pill ok">✓</span></td></tr>
    <tr><td>2 tool song song</td><td><span class="pill ok">✓</span></td><td><span class="pill ok">✓</span></td><td><span class="pill ok">✓</span></td></tr>
    <tr><td>JSON theo schema Plan</td><td><span class="pill ok">✓</span></td><td><span class="pill ok">✓</span></td><td><span class="pill warn">sửa 1 lần</span></td></tr>
    <tr><td>Ảnh schematic → bảng</td><td><span class="pill ok">✓</span></td><td><span class="pill ok">✓</span></td><td><span class="pill bad">không thị giác</span></td></tr>
    <tr><td>Từ chối → stop_reason</td><td><span class="pill ok">✓</span></td><td><span class="pill ok">✓</span></td><td><span class="pill ok">✓</span></td></tr></table></div>
</div>"""
write('Models', shell('Mô hình & chi phí', 'LLM Gateway · router theo vai trò · ledger', 'cfg', body, '<span class="btn">Lưu models.yaml</span>'))

# ---------------------------------------------------------------- 12. Flow map (không dùng shell)
flow = f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet><style>{CSS}</style></helmet>
<div style="width:1440px;height:620px;background:#f4f6f9;padding:28px;box-sizing:border-box;display:flex;flex-direction:column;gap:18px">
  <div style="display:flex;align-items:baseline;gap:14px"><span style="font-size:20px;font-weight:600;color:{NAVY}">Hành trình người dùng và cổng người · EIDE</span><span class="hint">P1 nhận tri thức → P2 kế hoạch → P3 sinh mã → P4 xác minh → P5 gỡ lỗi → P6 phát hành · ô vàng = con người quyết định</span></div>
  <svg viewBox="0 0 1384 470" width="1384" height="470">
    <defs><marker id="a2" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#8a97a8"/></marker></defs>
    {''.join(f'<rect x="{20+i*228}" y="20" width="200" height="60" rx="8" fill="#fff" stroke="{NAVY}" stroke-width="1.5"/><text x="{120+i*228}" y="45" text-anchor="middle" font-size="13" font-weight="600" fill="{NAVY}">{t}</text><text x="{120+i*228}" y="65" text-anchor="middle" font-size="11" fill="#5b6b7f">{s}</text>' for i,(t,s) in enumerate([('Nhập tài liệu','Ingest · phân loại · mở nén'),('Hàng đợi xác nhận','G-SRC · G-FACT'),('Hộ chiếu chip / mạch','Passport · Board · Graph'),('Kế hoạch & mã','G1 · G3 · IDE qua MCP'),('Log · serial · probe','G-OPS · G4 · DebugSession'),('Registry','G5 · .hkp · huy hiệu')]))}
    {''.join(f'<line x1="{220+i*228}" y1="50" x2="{248+i*228}" y2="50" stroke="#8a97a8" stroke-width="1.5" marker-end="url(#a2)"/>' for i in range(5))}
    {''.join(f'<rect x="{20+i*228}" y="120" width="200" height="34" rx="6" fill="#FFF6E0" stroke="{GOLD}" stroke-width="1.4"/><text x="{120+i*228}" y="142" text-anchor="middle" font-size="11.5" font-weight="600" fill="#5a3d00">{g}</text>' for i,g in enumerate(['(tự động, có sandbox)','G-SRC chọn nguồn · G-FACT duyệt fact','Kiểm định trên board (G-OPS)','G1 duyệt kế hoạch · G3 merge','G-OPS nạp/ghi · G4 xác nhận vật lý','G5 duyệt phát hành']))}
    <rect x="20" y="190" width="1344" height="120" rx="8" fill="#fff" stroke="#e1e6ee"/>
    <text x="36" y="214" font-size="12" font-weight="600" fill="{NAVY}">Knowledge Plane (daemon cục bộ) — mọi bề mặt dùng chung</text>
    {''.join(f'<rect x="{36+i*268}" y="228" width="248" height="66" rx="6" fill="#E6FAF5" stroke="{TEAL}"/><text x="{160+i*268}" y="252" text-anchor="middle" font-size="12" font-weight="600" fill="{NAVY}">{t}</text><text x="{160+i*268}" y="272" text-anchor="middle" font-size="10.5" fill="#3d5064">{s}</text>' for i,(t,s) in enumerate([('Acquisition','extractor theo tầng · máy trạng thái'),('Passport Store + KG','SQLite · fact bất biến · đồ thị'),('Agent Runtime','Gateway đa mô hình · hooks · gate'),('Tool & Target','build · flash · serial · probe · sim'),('Registry client','ký · huy hiệu · pull/publish')]))}
    <rect x="20" y="340" width="420" height="110" rx="8" fill="#fff" stroke="#e1e6ee"/><text x="36" y="364" font-size="12" font-weight="600" fill="{NAVY}">Ba bề mặt</text>
    <text x="36" y="388" font-size="11.5" fill="#3d5064">• GEditor plugin (macOS): hộ chiếu, hàng đợi, log gigabyte, serial, probe</text><text x="36" y="408" font-size="11.5" fill="#3d5064">• IDE ngoài qua MCP: Claude Code, Cursor, VS Code — tool passport.*, review.patch, flash</text><text x="36" y="428" font-size="11.5" fill="#3d5064">• CLI/CI: hkw ingest | query | bench | publish | doctor</text>
    <rect x="470" y="340" width="440" height="110" rx="8" fill="#fff" stroke="#e1e6ee"/><text x="486" y="364" font-size="12" font-weight="600" fill="{NAVY}">Bất biến hiển thị ở mọi màn hình</text>
    <text x="486" y="388" font-size="11.5" fill="#3d5064">• Thanh trạng thái: chế độ offline, pin phiên bản, gate đang mở, chi phí hôm nay</text><text x="486" y="408" font-size="11.5" fill="#3d5064">• Mọi giá trị phần cứng hiện kèm tầng (vàng/bạc/đồng), trạng thái, nguồn</text><text x="486" y="428" font-size="11.5" fill="#3d5064">• Thao tác không đảo ngược luôn là nút vàng "Cấp quyền" (G-OPS), không bao giờ mặc định</text>
    <rect x="940" y="340" width="424" height="110" rx="8" fill="#fff" stroke="#e1e6ee"/><text x="956" y="364" font-size="12" font-weight="600" fill="{NAVY}">Ngôn ngữ thị giác</text>
    <text x="956" y="388" font-size="11.5" fill="#3d5064">• Đỏ PTIT điều hướng/chính · Xám xanh hành động phụ · Vàng sao = cần con người</text><text x="956" y="408" font-size="11.5" fill="#3d5064">• IBM Plex Sans / Plex Mono · mật độ kỹ thuật · bảng là đơn vị chính</text><text x="956" y="428" font-size="11.5" fill="#3d5064">• Đỏ chỉ dành cho mâu thuẫn và lỗi phần cứng</text>
  </svg>
</div>
</x-dc>
</body>
</html>
"""
write('FlowMap', flow)


# ---------------------------------------------------------------- 13. Chat tác tử (màn hình mặc định, v1.2)
def bubble(who, text, side='l', meta=''):
    bg = '#fff' if side=='l' else '#fff4e6'
    return f'<div style="display:flex;flex-direction:column;gap:4px;align-self:{"flex-start" if side=="l" else "flex-end"};max-width:82%"><span class="hint" style="{"" if side=="l" else "text-align:right"}">{who}{(" · "+meta) if meta else ""}</span><div style="background:{bg};border:1px solid #e1e6ee;border-radius:10px;padding:10px 12px;font-size:12.5px;line-height:1.5">{text}</div></div>'
def card(title, inner, color=NAVY):
    return f'<div style="align-self:stretch;border:1px solid #e1e6ee;border-left:4px solid {color};border-radius:8px;background:#fff;padding:10px 12px;font-size:12.5px"><div style="font-size:11px;font-weight:600;color:{color};text-transform:uppercase;letter-spacing:.3px;margin-bottom:6px">{title}</div>{inner}</div>'
body = f"""
<div class="card" style="flex:1">
  <h3>Trò chuyện · robot-2-banh<span class="sp">intent gemini-flash · planner claude-opus · A3 · run r_0192</span></h3>
  <div class="pad" style="display:flex;flex-direction:column;gap:12px;flex:1;overflow:hidden;background:#fbfcfd">
    {bubble('Anh (kỹ sư)','Tạo cho anh dự án robot hai bánh tự cân bằng.','r','21:02')}
    {card('Tôi hiểu là… (chat.restate)','Tạo dự án mới <b>robot-2-banh-tu-can-bang</b> tại ~/eide/, mức tự chủ A3, mô phỏng trước khi nạp. Chưa có dự án nào gần giống. Registry có mẫu tham chiếu <b>eide.ref.balancing-robot@1.2</b> (STM32F411 + MPU6050 + A4988, đã kiểm định trên board). Tôi sẽ: tạo khung dự án → kéo hộ chiếu chip/board của mẫu → phân tích yêu cầu từ mẫu → đề xuất kiến trúc và sơ đồ khối → dựng mô phỏng. <a href="#">Sửa ý hiểu</a>')}
    {card('Một câu hỏi (chat.clarify · mặc định sau 1:48)','Anh có board/tài liệu sẵn không, hay tôi dựng theo mẫu tham chiếu để mô phỏng trước?<div style="display:flex;gap:8px;margin-top:8px"><span class="btn p">1 · Mẫu tham chiếu (mặc định)</span><span class="btn">2 · Tôi gửi tài liệu</span><span class="hint" style="margin-left:auto">ghi nhớ: create_source</span></div>', GOLD)}
    {bubble('EIDE','Đang làm ngay phần chắc chắn trong lúc chờ anh: đã tạo khung dự án, ghim st.stm32f411ce@1.2.0, đang cài Renode (danh sách tin cậy, ~3 phút).','l','21:02')}
    {card('Tiến độ chuỗi (run r_0192 · 14 nút)','<span class="pill ok">project.create</span> <span class="pill ok">search.reference_projects</span> <span class="pill ok">registry.pull</span> <span class="pill info">env.install renode ▶</span> <span class="pill silver">req.elicit</span> <span class="pill silver">arch.style_select</span> <span class="pill silver">diagram.block</span> <span class="pill silver">sim.build</span> <span class="pill silver">plan.create</span> … <span class="hint">2 nút chờ câu trả lời · 3 nút song song</span>', TEAL)}
    {card('Báo cáo (chat.report_back · 21:09)','<b>Đã làm:</b> dự án tạo; hộ chiếu chip+board từ mẫu (612 fact vàng, 40 bạc tự duyệt); ReqSet 18 yêu cầu; kiến trúc RTOS 3 task (ADR-01); sơ đồ khối và sơ đồ chân trong Lược đồ; mô phỏng chạy hello 1 kHz.<br><b>Chờ anh:</b> 1 — kế hoạch F-07 PID chạm động cơ (G1).<br><b>Hoàn tác được đến 09:14:</b> 3 mục.<br><b>Chi phí:</b> 0,31 USD · 41k token vào · 7 phút.', '#2E7D32')}
  </div>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;flex-direction:column;gap:8px">
    <div style="display:flex;gap:6px;flex-wrap:wrap"><span class="pill info">/vẽ sơ đồ kiến trúc</span><span class="pill info">/viết SRS</span><span class="pill info">/dò board</span><span class="pill info">/nạp</span><span class="pill silver">+ đính kèm zip/PDF/ảnh</span></div>
    <div style="display:flex;gap:8px;align-items:center"><div class="in" style="flex:1;height:38px;border:1px solid #d5dbe5;border-radius:8px;padding:0 12px;display:flex;align-items:center;color:#8a97a8">Ra lệnh bằng ngôn ngữ tự nhiên… (Enter gửi · "/" gọi năng lực · "dừng" hạ A0)</div><span class="btn p">Gửi</span></div>
    <span class="hint">Mọi hành động đi qua chính sách tự chủ: làm rồi báo cáo khi hoàn tác được; hỏi ở việc không hoàn tác được hoặc rủi ro vật lý.</span>
  </div>
</div>
<div style="display:flex;flex-direction:column;gap:16px;width:380px">
  <div class="card"><h3>Trạng thái tự chủ</h3><div class="pad" style="display:flex;flex-direction:column;gap:6px;font-size:12px">
    <div class="gate" style="padding:6px 10px"><span class="pill info">A3</span>dự án · board robot-ctrl <b>A2</b> (động cơ)</div>
    <div class="gate" style="padding:6px 10px"><span class="pill ok">12</span>việc tự làm hôm nay · 0 hoàn tác</div>
    <div class="gate" style="padding:6px 10px"><span class="pill warn">1</span>chờ anh (G1)</div>
    <div class="gate" style="padding:6px 10px"><span class="pill silver">0,31 USD</span>/ 5 USD ngân sách ngày</div>
    <span class="btn d">■ Dừng khẩn (hạ A0, hủy nạp đang chờ)</span>
  </div></div>
  <div class="card" style="flex:1"><h3>Ngữ cảnh lượt gần nhất (CXD-10)</h3><table>
    <tr><td>C0 năng lực (15)</td><td class="mono" style="text-align:right">780</td></tr><tr><td>C1 vai trò planner + 2 phủ định</td><td class="mono" style="text-align:right">410</td></tr><tr><td>C2 ràng buộc dự án</td><td class="mono" style="text-align:right">520</td></tr><tr><td>C3 skill armv7e-m/rtos, control/pid</td><td class="mono" style="text-align:right">1.140</td></tr><tr><td>C4 fact (Graph-RAG 2 bước, 96)</td><td class="mono" style="text-align:right">2.380</td></tr><tr><td>C5 ReqSet + ModuleGraph</td><td class="mono" style="text-align:right">1.900</td></tr><tr><td>C6 ToolReport sim</td><td class="mono" style="text-align:right">310</td></tr><tr><td>C7 lịch sử</td><td class="mono" style="text-align:right">220</td></tr><tr><td><b>Tổng / ngân sách</b></td><td class="mono" style="text-align:right"><b>7.660 / 9.000</b></td></tr></table>
  <div class="pad hint">Bộ đệm prompt: 62% trúng · bundle hash 9c1e…</div></div>
</div>"""
write('Chat', shell('Trò chuyện với tác tử', 'Màn hình mặc định · lệnh ngôn ngữ tự nhiên → chuỗi năng lực · làm rồi báo cáo', 'chat', body, '<span class="btn">Lịch sử phiên</span><span class="btn">Xem run r_0192</span>'))

# ---------------------------------------------------------------- 14. Mã nguồn
code_lines = [
 ('#include "eide/i2c.h"','#7b8a9c'),('#include "bme280.h"',''),('',''),
 ('/* hkw:fact f_b1c2… BME280 addr 0x76 (SDO→GND, BoardPassport) */','#7b8a9c'),('#define BME280_ADDR   0x76u',''),
 ('/* hkw:fact f_b3c4… id register 0xD0, expected 0x60 */','#7b8a9c'),('#define BME280_REG_ID 0xD0u',''),('',''),
 ('int bme280_init(void)','#B8121F'),('{',''),('    uint8_t id = i2c_read8(BME280_ADDR, BME280_REG_ID, I2C_TIMEOUT_MS);',''),
 ('    if (id != 0x60u) return -ENODEV;          /* hkw:fact f_b3c4… */',''),
 ('    /* hkw:fact f_b4d1… ctrl_meas 0xF4; f_b5e2… osrs_t[7:5] mode[1:0] */','#7b8a9c'),
 ('    uint8_t ctrl = (1u << 5) | 0x3u;',''),
 ('    if (i2c_write8(BME280_ADDR, 0xF4u, ctrl, I2C_TIMEOUT_MS) != 0)',''),('        return -EIO;',''),
 ('    i2c_write8(BME280_ADDR, 0xF5u, 0x27u, I2C_TIMEOUT_MS);   /* ← 0x27 KHÔNG có fact id */','#7a0c0c'),
 ('    return bme280_read_calib();',''),('}',''),
]
gutter = ''.join(f'<div style="display:flex;gap:14px"><span style="color:#b0bac6;width:24px;text-align:right">{i+1}</span><span style="color:{c or "#1b2430"}{";background:#fde3e1;display:inline-block;width:100%" if i==16 else ""}">{html.escape(t) if t else " "}</span></div>' for i,(t,c) in enumerate(code_lines))
body = f"""
<div class="card" style="width:230px"><h3>Dự án</h3><div class="tree" style="padding:6px 8px">
  <div>▾ robot-ctrl</div><div style="padding-left:14px">▾ src</div><div style="padding-left:28px">main.c</div><div style="padding-left:28px">pid.c</div><div style="padding-left:28px" class="on">driver_bme280.c</div><div style="padding-left:28px">drv_mpu6050.c</div><div style="padding-left:28px">drv_spi_flash.c</div><div style="padding-left:14px">▾ drivers</div><div style="padding-left:28px">i2c_stm32.c</div><div style="padding-left:28px">uart_stm32.c</div><div style="padding-left:14px">▸ tests</div><div style="padding-left:14px">▸ sim</div><div style="padding-left:14px">▾ .hkw</div><div style="padding-left:28px" class="hint">FEATURES.json</div><div style="padding-left:28px" class="hint">PROGRESS.md</div><div style="padding-left:28px" class="hint">constraints.yaml</div></div></div>
<div class="card" style="flex:1"><h3>driver_bme280.c<span class="sp">armv7e-m · STM32Cube bare-metal · 118 dòng · constant-guard: 1 vi phạm</span></h3>
  <div class="code" style="flex:1;padding:12px 14px;font-size:12px;overflow:hidden;background:#fff">{gutter}</div>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:10px;align-items:center;background:#fff7f6"><span class="pill bad" style="flex-shrink:0">constant-guard</span><span style="font-size:12px;flex:1">Dòng 17: hằng số <span class="mono">0x27</span> ghi vào thanh ghi <span class="mono">config (0xF5)</span> không có fact id — hộ chiếu BME280 chưa có nhóm "config/enum t_sb" (1 fact bạc chưa duyệt).</span><span class="btn g" style="height:26px;flex-shrink:0">Mở G-FACT</span><span class="btn" style="height:26px;flex-shrink:0">Hỏi tác tử</span></div>
</div>
<div style="display:flex;flex-direction:column;gap:16px;width:340px">
  <div class="card"><h3>Hộ chiếu tại con trỏ · dòng 14</h3><div class="pad code" style="font-size:11.5px">reg ctrl_meas  addr 0xF4  bạc reviewed  tr.27
  osrs_t [7:5]  001 = ×1 oversampling
  osrs_p [4:2]
  mode   [1:0]  11 = normal
nguồn BST-BME280-DS002.pdf  sha256 3f9a…
badge  verified_on_board ×3 (registry)</div></div>
  <div class="card"><h3>Hover 0x40005400</h3><div class="pad code" style="font-size:11.5px">→ I2C1 (st.stm32f411@1.1.0, vàng)
   CR1 +0x00 · CR2 +0x04 · DR +0x10 · SR1 +0x14</div></div>
  <div class="card" style="flex:1"><h3>Cổng công cụ (chạy khi lưu)</h3><div class="pad" style="display:flex;flex-direction:column;gap:6px">
    <div class="gate" style="padding:6px 10px"><span class="pill ok">build</span><span class="hint">3,1 s</span></div>
    <div class="gate" style="padding:6px 10px"><span class="pill ok">size</span><span class="hint">Flash 38% · RAM 22%</span></div>
    <div class="gate" style="padding:6px 10px"><span class="pill ok">static</span><span class="hint">0 vi phạm quy tắc Pack</span></div>
    <div class="gate" style="padding:6px 10px"><span class="pill ok">host-test</span><span class="hint">12/12</span></div>
    <div class="gate" style="padding:6px 10px"><span class="pill bad">constant-guard</span><span class="hint">1 vi phạm → chặn G3</span></div>
  </div></div>
</div>"""
write('Code', shell('Mã nguồn', 'Trình soạn thảo GEditor · hộ chiếu tại con trỏ · cổng công cụ khi lưu', 'code', body, '<span class="btn">Sinh lại từ STEP</span><span class="btn p">Gửi G3</span>', tabs=('driver_bme280.c','i2c_stm32.c','Tổng quan')))

# ---------------------------------------------------------------- 15. Mô phỏng
def series(pts, color, y0=150, sc=1.0):
    return '<polyline fill="none" stroke="%s" stroke-width="1.6" points="%s"/>' % (color, ' '.join(f'{30+i*9},{y0-v*sc}' for i,v in enumerate(pts)))
import math
theta=[12*math.exp(-i*0.06)*math.cos(i*0.45) for i in range(80)]
u=[max(-10,min(10,-3*t)) for t in theta]
body = f"""
<div style="display:flex;flex-direction:column;gap:16px;flex:1">
  <div class="card" style="flex:1"><h3>SIL · Renode stm32f4 + mô hình robot 2 bánh<span class="sp">firmware thật (ELF) · chu kỳ 200 Hz · 4,0 s ảo / 1,3 s thật</span></h3>
    <div class="pad" style="display:flex;gap:16px;flex:1">
      <div style="flex:1;display:flex;flex-direction:column;gap:8px">
        <svg viewBox="0 0 760 180" width="100%" height="180" style="background:#fbfcfd;border:1px solid #eef1f5;border-radius:6px">
          <line x1="30" y1="150" x2="750" y2="150" stroke="#d5dbe5"/><text x="34" y="20" font-size="11" fill="#5b6b7f">góc nghiêng θ (°) — đỏ · lệnh mô-men u — xám xanh · kỳ vọng |θ| &lt; 1° sau 3 s</text>
          {series([t*5 for t in theta], '#B8121F')}{series(u, '#2F4858')}
          <line x1="30" y1="145" x2="750" y2="145" stroke="#F2B705" stroke-dasharray="4 3"/><line x1="30" y1="155" x2="750" y2="155" stroke="#F2B705" stroke-dasharray="4 3"/>
          <text x="600" y="172" font-size="10" fill="#0b6b52">ổn định tại 2,6 s ✓</text></svg>
        <div style="display:grid;grid-template-columns:repeat(4, minmax(0, 1fr));gap:10px">
          <div class="card"><div class="kpi"><span class="v" style="font-size:20px">2,6 s</span><span class="l">Thời gian ổn định (SIL)</span></div></div>
          <div class="card"><div class="kpi"><span class="v" style="font-size:20px">4,9 ms</span><span class="l">Loop latency max (kỳ vọng ≤ 5)</span></div></div>
          <div class="card"><div class="kpi"><span class="v" style="font-size:20px">0,31 ms</span><span class="l">Jitter</span></div></div>
          <div class="card"><div class="kpi"><span class="v" style="font-size:20px;color:#7a0c0c">+0,8°</span><span class="l">Lệch so với HIL (board thật)</span></div></div>
        </div>
      </div>
      <div style="width:320px;display:flex;flex-direction:column;gap:8px">
        <b style="font-size:12px">Kịch bản (bench/balance_step.yaml)</b>
        <div class="code" style="font-size:11px;background:#fbfcfd;border:1px solid #eef1f5;border-radius:6px;padding:8px">init: {{theta: 12deg, omega: 0}}
inject:
  - t: 1.5s  push: 0.3 N·m
expect:
  - settle: {{abs_theta_lt: 1deg, within: 3s}}
  - loop_latency_max_ms: 5
peripherals_mocked: [MPU6050 (model), A4988 (step counter)]
run_on: [renode, board:nucleo-f411]</div>
        <b style="font-size:12px">Kết quả so sánh SIL ↔ HIL</b>
        <table><tr><th>Chỉ số</th><th>SIL</th><th>HIL</th><th></th></tr><tr><td>Ổn định</td><td>2,6 s</td><td>3,1 s</td><td><span class="pill ok">đạt</span></td></tr><tr><td>Latency max</td><td>4,9 ms</td><td>5,3 ms</td><td><span class="pill warn">vượt 0,3</span></td></tr><tr><td>Góc dư</td><td>0,2°</td><td>1,0°</td><td><span class="pill warn">lệch</span></td></tr></table>
        <span class="hint">Lệch HIL do ma sát bánh chưa mô hình hóa → đề xuất cập nhật mô hình (K7 → K5) chờ duyệt.</span>
      </div>
    </div></div>
  <div class="card" style="height:190px"><h3>Thiết bị ảo & log Renode<span class="sp">UART2 → serial console · GPIO PB3 LED · I2C1 MPU6050 mock</span></h3>
    <div class="pad code" style="font-size:11.5px">00:00:00.000 [INFO] sysbus.usart2: "EIDE robot-ctrl v0.6 · SIL"
00:00:00.005 [INFO] sysbus.i2c1: MPU6050 mock WHO_AM_I=0x68
00:00:01.500 [INFO] scenario: inject push 0.3 N·m
00:00:02.612 [INFO] scenario: settle ✓ |θ|=0.9°
00:00:04.000 [INFO] scenario: done · exit 0 · ToolReport sim#41 passed</div></div>
</div>
<div class="card" style="width:330px"><h3>Chạy</h3><div class="pad" style="display:flex;flex-direction:column;gap:10px">
  <div class="field"><label>Mục tiêu</label><div class="in">Renode · platforms/cpus/stm32f4.repl</div></div>
  <div class="field"><label>Firmware</label><div class="in mono">build/robot-ctrl.elf (sha 41c0…)</div></div>
  <div class="field"><label>Kịch bản</label><div class="in">bench/balance_step.yaml</div></div>
  <div class="field"><label>Tốc độ</label><div class="in">Nhanh nhất có thể (không realtime)</div></div>
  <span class="btn t">Chạy SIL</span><span class="btn g">Chạy trên board (cần G-OPS)</span><span class="btn">So sánh SIL/HIL</span>
  <span class="hint">SIL không cần quyền; HIL luôn hỏi. Kết quả trở thành ToolReport và bằng chứng EVIDENCED_BY cho tính năng.</span>
</div></div>"""
write('Sim', shell('Mô phỏng', 'P4 · SIL trước, HIL sau · cùng một kịch bản', 'sim', body, '<span class="btn">Mở kịch bản</span>'))

# ---------------------------------------------------------------- 16. Benchmark
rows = [('B-01','Blink + SysTick','1','✓','✓','✓'),('B-02','UART echo','1','✓','✓','✓'),('B-03','I2C BME280 đọc id','2','✓','✓','BF'),('B-04','SPI flash JEDEC id','2','✓','✓','✓'),('B-05','TIM PWM 1 kHz','2','✓','✓','CF'),('B-06','EXTI nút nhấn','2','✓','BF','✓'),('B-07','DMA UART TX','3','✓','✓','BF'),('B-08','RTOS 2 task','3','✓','✓','CF'),('B-09','Watchdog','3','BF','✓','BF'),('B-10','Low-power stop','3','✓','BF','CF')]
def cell(v):
    return {'✓':'<span class="pill ok">BC</span>','BF':'<span class="pill warn">BF</span>','CF':'<span class="pill bad">CF</span>'}[v]
trs=''.join(f'<tr><td class="mono">{a}</td><td>{b}</td><td>{c}</td><td>{cell(d)}</td><td>{cell(e)}</td><td>{cell(f)}</td></tr>' for a,b,c,d,e,f in rows)
body = f"""
<div class="card" style="flex:1"><h3>armv7e-m · Nucleo-F411 · 10 tác vụ × 3 mô hình<span class="sp">chấm trên board thật · CF lỗi dịch · BF lỗi hành vi · BC đúng hành vi</span></h3>
  <table><tr><th>Mã</th><th>Tác vụ</th><th>Mức</th><th>claude-sonnet</th><th>gemini-flash</th><th>local/qwen-14b</th></tr>{trs}
  <tr><td></td><td><b>BC mức 1–2</b></td><td></td><td><b>6/6 · 100%</b></td><td><b>5/6 · 83%</b></td><td><b>4/6 · 67%</b></td></tr>
  <tr><td></td><td><b>BC mức 3</b></td><td></td><td><b>3/4</b></td><td><b>3/4</b></td><td><b>1/4</b></td></tr></table>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:10px;align-items:center"><span class="hint">Ngưỡng kiểm định Pack: BC ≥ 90% mức 1–2 (IoT-SkillsBench). gemini-flash đạt 83% → chưa gắn huy hiệu cho skill v2.1 với mô hình này.</span><span class="btn p" style="margin-left:auto">Chạy lại 3 ca lỗi</span><span class="btn">Xuất báo cáo</span></div>
</div>
<div style="display:flex;flex-direction:column;gap:16px;width:400px">
  <div class="card"><h3>Chi tiết B-03 · gemini-flash · BF</h3><div class="pad code" style="font-size:11.5px">kỳ vọng   serial "BME280 id=0x60"
thực tế   serial "BME280 id=0xFF"
vòng sửa  3/3 (hết)
nguyên nhân (Debugger): dùng địa chỉ 0x77
  → skill bme280_init thiếu câu "địa chỉ theo chân SDO"
đề xuất   sửa skill (K5) → chờ Pack owner duyệt
token     18.4k · 0,02 USD · 41 s</div></div>
  <div class="card" style="flex:1"><h3>Theo thời gian · BC mức 1–2</h3><div class="pad">
    <svg viewBox="0 0 360 150" width="100%" height="150"><rect width="360" height="150" fill="#fbfcfd"/>
    <polyline fill="none" stroke="#B8121F" stroke-width="2" points="30,90 100,70 170,40 240,30 310,20"/><polyline fill="none" stroke="#2F4858" stroke-width="2" points="30,110 100,95 170,80 240,55 310,45"/><polyline fill="none" stroke="#b0bac6" stroke-width="2" stroke-dasharray="4 3" points="30,130 100,120 170,110 240,95 310,80"/>
    <text x="30" y="145" font-size="10" fill="#5b6b7f">skill v1.0</text><text x="170" y="145" font-size="10" fill="#5b6b7f">v1.5</text><text x="290" y="145" font-size="10" fill="#5b6b7f">v2.1</text>
    <text x="34" y="16" font-size="10" fill="#B8121F">claude</text><text x="80" y="16" font-size="10" fill="#2F4858">gemini</text><text x="130" y="16" font-size="10" fill="#8a97a8">local</text></svg>
    <span class="hint">Mỗi lần đổi skill hoặc mô hình → chạy lại tự động (FR-BEN-03); kết quả ghi vào badges.json của gói.</span></div></div>
</div>"""
write('Bench', shell('Benchmark', 'UC12 · đánh giá tác tử và Pack trên phần cứng thật', 'bench', body, '<span class="btn t">Chạy bộ armv7e-m</span>'))

# ---------------------------------------------------------------- 17. Môi trường (doctor)
body = f"""
<div class="card" style="flex:1"><h3>eide doctor · Pack armv7e-m + avr8<span class="sp">tools.lock 05/09/2026 · macOS 15 · Python 3.12</span></h3>
  <table><tr><th>Công cụ</th><th>Cần</th><th>Có</th><th>Trạng thái</th><th></th></tr>
  <tr><td class="mono">arm-none-eabi-gcc</td><td>≥ 13.2</td><td>13.2.1</td><td><span class="pill ok">khóa</span></td><td></td></tr>
  <tr><td class="mono">probe-rs</td><td>≥ 0.24</td><td>0.24.0</td><td><span class="pill ok">khóa</span></td><td></td></tr>
  <tr><td class="mono">openocd</td><td>≥ 0.12</td><td>—</td><td><span class="pill warn">thiếu (tùy chọn)</span></td><td><span class="btn" style="height:26px">Cài (hỏi trước)</span></td></tr>
  <tr><td class="mono">renode</td><td>≥ 1.15</td><td>1.15.3</td><td><span class="pill ok">khóa</span></td><td></td></tr>
  <tr><td class="mono">kicad-cli</td><td>≥ 8.0</td><td>8.0.7</td><td><span class="pill ok">khóa</span></td><td></td></tr>
  <tr><td class="mono">avr-gcc / avrdude</td><td>≥ 12 / ≥ 7</td><td>14.1 / 7.3</td><td><span class="pill ok">khóa</span></td><td></td></tr>
  <tr><td class="mono">sigrok-cli</td><td>≥ 0.7</td><td>0.7.2</td><td><span class="pill ok">khóa</span></td><td></td></tr>
  <tr><td class="mono">Ollama · qwen2.5-coder:14b</td><td>—</td><td>9,0 GB</td><td><span class="pill ok">sẵn sàng (offline)</span></td><td></td></tr>
  <tr><td class="mono">ST-Link V3 (USB)</td><td>—</td><td>đã cắm</td><td><span class="pill ok">nhận</span></td><td></td></tr></table>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:10px"><span class="hint">Cài đặt luôn hỏi trước (G-OPS); tools.lock ghi hash để tái dựng trên máy khác. Toolchain đóng (XC8, IAR, Keil) chỉ dùng qua dòng lệnh khi anh tự cài.</span><span class="btn p" style="margin-left:auto">Khóa phiên bản</span></div>
</div>
<div class="card" style="width:400px"><h3>Xuất báo cáo (G5)</h3><div class="pad" style="display:flex;flex-direction:column;gap:10px">
  <div class="field"><label>Loại</label><div class="in">Báo cáo dự án · docx (có mục Nguồn)</div></div>
  <div class="field"><label>Bao gồm</label><div class="in">Hộ chiếu · A/B KPI · Ma trận Người–AI · Benchmark</div></div>
  <div class="field"><label>Ẩn IP</label><div class="in">Ẩn net mạch không liên quan · không kèm PDF</div></div>
  <span class="btn p">Tạo báo cáo</span>
  <div class="hint">Ma trận Người–AI được điền tự động từ nhật ký gate (pha × vai trò AI × vai trò người × tri thức sinh ra).</div>
  <div class="code" style="font-size:11px;background:#fbfcfd;border:1px solid #eef1f5;border-radius:6px;padding:8px">P1 nhận tri thức   AI: tìm/trích   Người: G-SRC, G-FACT   → 58 fact
P3 sinh mã         AI: Coder/Rev   Người: G3 (từ chối 43%) → 7 module
P4 xác minh        AI: Tester      Người: G4              → 5 passing
P5 gỡ lỗi          AI: Debugger    Người: G-OPS           → 12 phiên</div>
</div></div>"""
write('Env', shell('Môi trường & báo cáo', 'UC13 doctor · GOV-06 export', 'cfg', body))


# ---------------------------------------------------------------- 18. Bản đồ tri thức & hỏi đáp (RagAsk)
def kgnode(x, y, label, cls, r=18):
    col = {'gold': '#F2B705', 'silver': '#9fb0c3', 'conflict': '#B8121F', 'code': '#2F4858', 'src': '#6b7f95'}[cls]
    return f'<g><circle cx="{x}" cy="{y}" r="{r}" fill="{col}" fill-opacity=".18" stroke="{col}" stroke-width="1.6"/><text x="{x}" y="{y+4}" font-size="9.5" text-anchor="middle" fill="#1b2430">{label}</text></g>'
kg = ''.join([
  '<line x1="330" y1="120" x2="200" y2="200" stroke="#c9d2de"/>', '<line x1="330" y1="120" x2="460" y2="200" stroke="#c9d2de"/>', '<line x1="200" y1="200" x2="150" y2="300" stroke="#c9d2de"/>', '<line x1="200" y1="200" x2="270" y2="300" stroke="#c9d2de"/>',
  '<line x1="460" y1="200" x2="420" y2="300" stroke="#B8121F" stroke-dasharray="4 3"/>', '<line x1="460" y1="200" x2="530" y2="300" stroke="#c9d2de"/>', '<line x1="270" y1="300" x2="330" y2="390" stroke="#c9d2de"/>', '<line x1="420" y1="300" x2="330" y2="390" stroke="#c9d2de"/>',
  kgnode(330, 120, 'stm32f411', 'gold', 26), kgnode(200, 200, 'I2C1', 'gold'), kgnode(460, 200, 'BME280', 'silver', 22), kgnode(150, 300, 'PB6', 'gold'), kgnode(270, 300, 'CR1', 'gold'), kgnode(420, 300, 'ctrl_meas', 'conflict'), kgnode(530, 300, 'errata', 'src'), kgnode(330, 390, 'bme280.c', 'code', 22)])
body = f"""
<div style="display:flex;flex-direction:column;gap:16px;flex:1.2;min-width:0">
  <div class="card" style="flex:1">
    <h3>Bản đồ tri thức<span class="sp">3.757 nút · lọc: lân cận BME280 · màu: vàng/bạc/mâu thuẫn/mã</span></h3>
    <div style="display:flex;gap:8px;padding:8px 14px;border-bottom:1px solid #eef1f5"><span class="pill gold">vàng 612</span><span class="pill silver">bạc 40</span><span class="pill bad">mâu thuẫn 1</span><span class="pill info">mã 6</span><span class="hint" style="margin-left:auto">zoom · lọc theo tầng/trạng thái/lớp · xuất Mermaid/DOT</span></div>
    <svg viewBox="0 0 680 430" style="flex:1">{kg}</svg>
  </div>
  <div class="card"><h3>Nguồn gốc · ctrl_meas (fact f_9e0f) · mâu thuẫn</h3><div class="pad" style="font-size:12px;display:flex;gap:16px">
    <div style="flex:1"><b>A</b> 0xF4 · bme280-ds.pdf tr.27 bảng 18 · bạc 0,91 · auto-reviewed by policy (G-FACT-02)</div>
    <div style="flex:1"><b>B</b> 0xF5 · forum.st.com · đồng · <span class="pill bad">REJECT G-FACT-05</span></div>
    <span class="btn">Mở PDF tr.27</span></div></div>
</div>
<div class="card" style="flex:1">
  <h3>Hỏi–đáp trên kho tài liệu (RAG)<span class="sp">chỉ mục 1.842 đoạn · 6 nguồn</span></h3>
  <div class="pad" style="display:flex;flex-direction:column;gap:12px;flex:1;overflow:hidden;background:#fbfcfd">
    <div style="align-self:flex-end;background:#fff4e6;border:1px solid #e1e6ee;border-radius:10px;padding:8px 12px;font-size:12.5px">Địa chỉ I2C mặc định của BME280 và điều kiện chọn?</div>
    <div style="background:#fff;border:1px solid #e1e6ee;border-radius:10px;padding:10px 12px;font-size:12.5px;line-height:1.55">BME280 có địa chỉ 7-bit <b>0x76</b> khi chân SDO nối GND và <b>0x77</b> khi SDO nối VDDIO [1]; SDO không được để hở vì địa chỉ sẽ không xác định [1]. Trên board robot-main, SDO nối GND theo net N$14 nên địa chỉ dùng là 0x76 [2].
      <div style="margin-top:8px;display:flex;gap:6px;flex-wrap:wrap"><span class="pill info">[1] bme280-ds.pdf · tr.32 §6.2</span><span class="pill info">[2] robot.kicad_sch · net N$14</span><span class="pill silver">trace tr_a1</span></div></div>
    <div class="card" style="border-style:dashed"><h3>Vì sao (view.rag_trace)</h3><table><tr><th>Đoạn</th><th>BM25</th><th>Vector</th><th>Đồ thị</th><th>Tổng</th></tr>
      <tr><td>bme280-ds.pdf p32 "I2C address…"</td><td>0,71</td><td>0,83</td><td>1,0 (part:bosch.bme280)</td><td><b>0,86</b></td></tr>
      <tr><td>robot.kicad_sch N$14 SDO–GND</td><td>0,22</td><td>0,58</td><td>0,9 (CONNECTS)</td><td>0,61</td></tr>
      <tr><td>forum.st.com "bme280 0x77…"</td><td>0,64</td><td>0,70</td><td>0</td><td>0,44 (đồng — bỏ)</td></tr></table></div>
  </div>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:8px"><div class="in" style="flex:1;height:34px;border:1px solid #d5dbe5;border-radius:8px;padding:0 12px;display:flex;align-items:center;color:#8a97a8">Hỏi về tài liệu dự án… (trả lời luôn có trích dẫn mở nguồn)</div><span class="btn">So sánh nguồn</span><span class="btn p">Hỏi</span></div>
</div>"""
write('RagAsk', shell('Bản đồ tri thức & hỏi đáp', 'view.kg_map · view.provenance · view.rag_ask (Graph-RAG, trích dẫn nhấp mở nguồn)', 'graph', body, '<span class="btn">Độ phủ</span><span class="btn">Tác động</span><span class="btn">Xuất Mermaid</span>'))

# ---------------------------------------------------------------- 19. Yêu cầu & kiến trúc (ReqArch)
body = f"""
<div class="card" style="flex:1.1">
  <h3>Yêu cầu (ReqSet) · 18<span class="sp">req.elicit từ mẫu tham chiếu + lệnh · req.ground_hw với st.stm32f411ce@1.2.0</span></h3>
  <table><tr><th>Mã</th><th>Loại</th><th>Yêu cầu (đo được)</th><th>Ưu</th><th>Khả thi</th></tr>
  <tr><td class="mono">FR-SNS-01</td><td>FR</td><td>Đọc góc nghiêng từ MPU6050 qua I2C1 ở 1 kHz, độ trễ ≤ 2 ms</td><td>M</td><td><span class="pill ok">ok · f_5a1c</span></td></tr>
  <tr><td class="mono">FR-CTL-01</td><td>RT</td><td>Vòng PID 1 kHz, WCET ≤ 400 µs</td><td>M</td><td><span class="pill ok">ok · 100 MHz</span></td></tr>
  <tr><td class="mono">FR-ACT-01</td><td>FR</td><td>Điều khiển 2 stepper qua A4988, ≤ 4.000 bước/s</td><td>M</td><td><span class="pill ok">ok · TIM3</span></td></tr>
  <tr class="sel"><td class="mono">FR-SAF-01</td><td>SAFETY</td><td>Ngắt động cơ trong ≤ 10 ms khi |góc| > 30° hoặc mất IMU 50 ms</td><td>M</td><td><span class="pill ok">ok</span></td></tr>
  <tr><td class="mono">NFR-PWR-01</td><td>NFR</td><td>Chạy ≥ 30 phút với pin 12 V 2.200 mAh</td><td>S</td><td><span class="pill warn">chưa xác định · cần dòng động cơ</span></td></tr>
  <tr><td class="mono">FR-COM-01</td><td>FR</td><td>Telemetry UART2 115200, 20 Hz</td><td>S</td><td><span class="pill ok">ok · f_2210</span></td></tr>
  <tr><td class="mono">—</td><td>Issue</td><td><span class="pill warn">mơ hồ</span> "phản ứng nhanh" → đề xuất: thời gian ổn định ≤ 1,5 s sau nhiễu 5°</td><td>—</td><td><span class="btn" style="height:24px">Chấp nhận câu chữ</span></td></tr></table>
  <div class="pad hint" style="margin-top:auto;border-top:1px solid #eef1f5">Mỗi yêu cầu có tiêu chí Given–When–Then (req.acceptance) và truy vết tới module/test/tài liệu (req.trace_matrix).</div>
</div>
<div style="display:flex;flex-direction:column;gap:16px;flex:1">
  <div class="card"><h3>Kiến trúc · ADR-01<span class="sp">arch.style_select → <b>rtos</b> (FreeRTOS) · 3 task</span></h3><div class="pad" style="font-size:12px;line-height:1.5">
    <b>Vì sao:</b> 3 chu kỳ khác nhau (IMU 1 kHz, PID 1 kHz, telemetry 20 Hz) + I2C chặn; RAM 128 KB [f_mem1] đủ cho kernel (~6 KB). <b>Loại:</b> super_loop (jitter I2C), event_driven (đủ nhưng khó đảm bảo deadline PID). <span class="pill silver">ADR-01 · citations 4</span></div></div>
  <div class="card" style="flex:1"><h3>Module ↔ phần cứng (HwMap)<span class="sp">board.check_pins: 0 xung đột</span></h3>
    <table><tr><th>Module</th><th>Trách nhiệm</th><th>Tài nguyên</th><th>Ngân sách</th></tr>
    <tr><td class="mono">mod_imu</td><td>Đọc MPU6050, lọc bù</td><td class="mono">I2C1 PB6/PB7 · EXTI PA0</td><td>RAM 0,6 KB · WCET 180 µs</td></tr>
    <tr><td class="mono">mod_pid</td><td>Vòng cân bằng</td><td class="mono">TIM2 1 kHz</td><td>RAM 0,2 KB · WCET 60 µs</td></tr>
    <tr><td class="mono">mod_motor</td><td>STEP/DIR A4988, giới hạn</td><td class="mono">TIM3 CH1/CH2 PA6/PA7 · PB4/PB5 DIR</td><td>RAM 0,3 KB · WCET 40 µs</td></tr>
    <tr><td class="mono">mod_safety</td><td>Giám sát, watchdog</td><td class="mono">IWDG · GPIO PC13</td><td>RAM 0,1 KB</td></tr>
    <tr><td class="mono">mod_telemetry</td><td>UART2 20 Hz</td><td class="mono">USART2 PA2/PA3 DMA1</td><td>RAM 0,5 KB</td></tr></table>
    <div class="pad" style="display:flex;gap:8px;border-top:1px solid #eef1f5;margin-top:auto"><span class="pill ok">RMS U = 0,24 ≤ 0,78 · schedulable</span><span class="pill ok">Flash 41% · RAM 18%</span><span class="btn" style="margin-left:auto">Vẽ sơ đồ kiến trúc</span><span class="btn t">→ Kế hoạch</span></div></div>
</div>"""
write('ReqArch', shell('Yêu cầu & kiến trúc', 'req.* → arch.* · ReqSet · ADR · HwMap · ngân sách RAM/thời gian', 'req', body, '<span class="btn">Ma trận truy vết</span><span class="btn">Rà kiến trúc</span>'))

# ---------------------------------------------------------------- 20. Lược đồ (DiagramView)
mer = """stateDiagram-v2
  [*] --> IDLE
  IDLE --> CALIB: imu_ok
  CALIB --> BALANCE: calib_done
  BALANCE --> SAFE_STOP: angle_gt_30 / stop_motors
  BALANCE --> SAFE_STOP: imu_timeout_50ms
  SAFE_STOP --> IDLE: reset_cmd
  BALANCE --> BALANCE: tick_1khz / pid_step"""
body = f"""
<div class="card" style="width:520px">
  <h3>Mã lược đồ · mod_motor · Mermaid<span class="sp">diagram.state từ FSM · lint 0 lỗi · sync ↔ motor_fsm.c: khớp</span></h3>
  <div class="code pad" style="flex:1;background:#fbfcfd">{html.escape(mer)}</div>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:8px"><span class="pill ok">lint 0</span><span class="pill ok">sync khớp mã</span><span class="btn" style="margin-left:auto">PlantUML</span><span class="btn">D2</span><span class="btn t">Chèn vào SDD</span></div>
</div>
<div class="card" style="flex:1">
  <h3>Hình (GEditor render)<span class="sp">Mermaid · PlantUML · Graphviz/DOT · D2 · WaveDrom · SVG</span></h3>
  <svg viewBox="0 0 700 420" style="flex:1">
    <defs><marker id="ar" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8z" fill="#2F4858"/></marker></defs>
    <circle cx="80" cy="60" r="8" fill="#1b2430"/>
    <rect x="40" y="110" width="110" height="40" rx="8" fill="#fff" stroke="#2F4858" stroke-width="1.5"/><text x="95" y="135" text-anchor="middle" font-size="12">IDLE</text>
    <rect x="230" y="110" width="110" height="40" rx="8" fill="#fff" stroke="#2F4858" stroke-width="1.5"/><text x="285" y="135" text-anchor="middle" font-size="12">CALIB</text>
    <rect x="420" y="110" width="130" height="40" rx="8" fill="#fff4e6" stroke="#B8121F" stroke-width="1.5"/><text x="485" y="135" text-anchor="middle" font-size="12" font-weight="600">BALANCE</text>
    <rect x="420" y="290" width="130" height="40" rx="8" fill="#fde3e1" stroke="#B8121F" stroke-width="1.5"/><text x="485" y="315" text-anchor="middle" font-size="12">SAFE_STOP</text>
    <line x1="80" y1="68" x2="80" y2="110" stroke="#2F4858" marker-end="url(#ar)"/>
    <line x1="150" y1="130" x2="230" y2="130" stroke="#2F4858" marker-end="url(#ar)"/><text x="190" y="122" font-size="10" text-anchor="middle">imu_ok</text>
    <line x1="340" y1="130" x2="420" y2="130" stroke="#2F4858" marker-end="url(#ar)"/><text x="380" y="122" font-size="10" text-anchor="middle">calib_done</text>
    <line x1="485" y1="150" x2="485" y2="290" stroke="#B8121F" marker-end="url(#ar)"/><text x="560" y="215" font-size="10">angle_gt_30 / stop_motors</text><text x="560" y="230" font-size="10">imu_timeout_50ms</text>
    <path d="M420 310 L95 310 L95 150" fill="none" stroke="#2F4858" marker-end="url(#ar)"/><text x="250" y="302" font-size="10" text-anchor="middle">reset_cmd</text>
    <path d="M550 120 C 600 80, 600 180, 550 140" fill="none" stroke="#2F4858" marker-end="url(#ar)"/><text x="610" y="112" font-size="10">tick_1khz / pid_step</text>
  </svg>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:8px;flex-wrap:wrap"><span class="pill info">Sơ đồ khối</span><span class="pill info">Sơ đồ chân</span><span class="pill info">Kiến trúc C4</span><span class="pill info">Tuần tự F-04</span><span class="pill gold">Trạng thái mod_motor</span><span class="pill info">Timing I2C (WaveDrom)</span><span class="pill info">Bản đồ bộ nhớ</span><span class="pill info">Gantt</span></div>
</div>"""
write('DiagramView', shell('Lược đồ', 'diagram.* · mã ↔ hình · đồng bộ hai chiều với mã và kiến trúc', 'diagram', body, '<span class="btn">Từ ảnh</span><span class="btn">Lint</span><span class="btn t">Sync ↔ mã</span>'))

# ---------------------------------------------------------------- 21. Tài liệu (Doc)
body = f"""
<div class="card" style="width:300px">
  <h3>Bộ tài liệu dự án<span class="sp">.eide/docs</span></h3>
  <div class="tree" style="padding:0 8px 8px">
    <div><span class="pill ok">ok</span>EIDE-URD robot-2-banh v0.2</div>
    <div class="on"><span class="pill warn">2 stale</span>EIDE-SRS robot-2-banh v0.3</div>
    <div><span class="pill ok">ok</span>EIDE-SAD v0.2 · ADR-01</div>
    <div><span class="pill silver">—</span>EIDE-SDD (chưa sinh)</div>
    <div><span class="pill ok">ok</span>Hướng dẫn bring-up robot-main</div>
    <div><span class="pill ok">ok</span>Tóm tắt datasheet BME280</div>
    <div><span class="pill ok">ok</span>Báo cáo kiểm thử 05/09</div>
  </div>
  <div class="pad" style="margin-top:auto;border-top:1px solid #eef1f5;display:flex;flex-direction:column;gap:8px"><span class="btn p">Sinh tài liệu…</span><span class="btn">Xuất docx/pdf</span><span class="btn">Slide đề án</span></div>
</div>
<div class="card" style="flex:1">
  <h3>EIDE-SRS robot-2-banh v0.3<span class="sp">doc.generate (writer claude-sonnet) · style_check 0 lỗi · 2 mục lỗi thời sau khi fact f_9e0f đổi</span></h3>
  <div class="pad" style="flex:1;overflow:hidden;font-size:12.5px;line-height:1.6">
    <div style="font-weight:600;color:#B8121F;margin-bottom:6px">3.2. Yêu cầu chức năng — cảm biến</div>
    <p style="margin:0 0 8px">FR-SNS-01 quy định vòng đọc MPU6050 qua I2C1 ở tần số 1 kHz với độ trễ không quá 2 ms. Bus I2C1 được cấu hình 400 kHz theo giới hạn của điện trở kéo lên 4,7 kΩ trên board [f_net14] và tốc độ tối đa của cảm biến [f_5a1c]. …</p>
    <div style="border-left:3px solid #F2B705;background:#fff6dd;padding:6px 10px;margin:8px 0;font-size:12px"><b>Mục lỗi thời (doc.sync):</b> 3.4 dùng địa chỉ ctrl_meas 0xF4 — fact f_9e0f vừa được thay bởi f_9e10 (0xF4, nguồn thứ hai). Số liệu không đổi; tôi đã cập nhật trích dẫn và ghi lịch sử v0.3 → v0.4 (T1*). <a href="#">Xem diff</a></div>
    <div style="font-weight:600;color:#B8121F;margin:10px 0 6px">Hình 3. Kiến trúc firmware (C4 component)</div>
    <div style="border:1px dashed #cfd6e0;border-radius:6px;height:120px;display:flex;align-items:center;justify-content:center;color:#8a97a8">[diagram.architecture · mermaid · dg_0214 · đồng bộ ModuleGraph]</div>
    <div style="margin-top:10px;display:flex;gap:6px;flex-wrap:wrap"><span class="pill ok">tiếng Việt ưu tiên</span><span class="pill ok">thuật ngữ có giải nghĩa</span><span class="pill ok">100% số liệu có nguồn</span><span class="pill ok">bảng thuộc tính/lịch sử/Nguồn</span></div>
  </div>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;gap:8px"><span class="btn">Sửa mục</span><span class="btn">Dịch sang Anh</span><span class="btn" style="margin-left:auto">Kiểm style</span><span class="btn t">Cập nhật mục lỗi thời</span></div>
</div>"""
write('Doc', shell('Tài liệu', 'doc.* · chuẩn bộ EAA/EIDE · mọi khẳng định có nguồn · đồng bộ khi fact/mã đổi', 'doc', body))

# ---------------------------------------------------------------- 22. Dò board (Discovery)
body = f"""
<div style="display:flex;flex-direction:column;gap:16px;flex:1">
  <div style="display:grid;grid-template-columns:repeat(4, minmax(0,1fr));gap:16px">
    <div class="card"><div class="kpi"><span class="v">2</span><span class="l">Cổng USB/serial đang cắm</span></div></div>
    <div class="card"><div class="kpi"><span class="v">ST-Link V3</span><span class="l">Probe · fw J40 · cập nhật khả dụng</span></div></div>
    <div class="card"><div class="kpi"><span class="v">0x431</span><span class="l">IDCODE → STM32F411 · khớp hộ chiếu</span></div></div>
    <div class="card"><div class="kpi"><span class="v">921600</span><span class="l">Baud tối ưu · 0 lỗi / 1.000 khung</span></div></div>
  </div>
  <div class="card" style="flex:1"><h3>Kết quả dò (discover.*)<span class="sp">21:14 · 4,8 s · target.yaml đã ghi (auto_setup)</span></h3>
    <table><tr><th>Bước</th><th>Kết quả</th><th>Đối chiếu</th><th>Trạng thái</th></tr>
    <tr><td>discover.ports</td><td class="mono">/dev/tty.usbmodem14203 (0483:374E) · /dev/tty.usbserial-A50 (0403:6001)</td><td>ST-Link VCP · FTDI</td><td><span class="pill ok">driver ok</span></td></tr>
    <tr><td>discover.probe</td><td>ST-Link V3 · serial 0669FF… · fw J40M27</td><td>probe-rs 0.24</td><td><span class="pill ok">ok</span></td></tr>
    <tr><td>discover.chip_id</td><td class="mono">DP IDCODE 0x2BA01477 · DBGMCU 0x431 rev A</td><td>st.stm32f411ce@1.2.0</td><td><span class="pill ok">khớp</span></td></tr>
    <tr><td>discover.link_speed (swd)</td><td>100k ✓ 1M ✓ 4M ✓ 8M ✗(3 lỗi) → chọn <b>4 MHz</b></td><td>giới hạn fact f_swd1: 8 MHz</td><td><span class="pill ok">trong giới hạn</span></td></tr>
    <tr><td>discover.link_speed (baud)</td><td>115200 ✓ 460800 ✓ 921600 ✓ → chọn <b>921600</b></td><td>firmware kiểm định echo</td><td><span class="pill ok">0 lỗi</span></td></tr>
    <tr><td>discover.bus_scan (i2c)</td><td class="mono">0x68 · 0x76</td><td>MPU6050 · BME280 (BOM)</td><td><span class="pill ok">khớp BOM</span></td></tr>
    <tr><td>discover.firmware_probe</td><td>banner "EIDE fw 0.3 r_0188"</td><td>known-good 0.3</td><td><span class="pill ok">đã nạp trước</span></td></tr>
    <tr><td>discover.power</td><td>VDD 3,29 V · IDD 42 mA</td><td>fact f_vdd: 1,7–3,6 V</td><td><span class="pill ok">an toàn nạp</span></td></tr>
    <tr><td>discover.board_match</td><td>nucleo-f411 (điểm 9) · blackpill-f411 (điểm 4)</td><td>registry boards</td><td><span class="pill ok">nucleo-f411 · lab</span></td></tr></table>
  </div>
</div>
<div class="card" style="width:340px"><h3>target.yaml</h3><div class="code pad" style="flex:1">board: nucleo-f411
isa: armv7e-m
adapter: {{kind: probe-rs, probe: "0669FF…", chip: STM32F411CEUx}}
port: {{dev: /dev/tty.usbmodem14203, baud: 921600}}
speeds: {{swd_khz: 4000}}
lab: true
last_discovery: dv_0031</div>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;flex-direction:column;gap:8px"><span class="btn p">Dò lại</span><span class="btn">Đo tần số thực</span><span class="btn">Dò thiết bị LAN</span><span class="hint">Cắm/rút board tự cập nhật (event.discover.changed). ID không khớp hộ chiếu → cảnh báo và không nạp.</span></div></div>"""
write('Discovery', shell('Dò board', 'discover.* · cổng · probe · ID chip · tốc độ kết nối · bus · nguồn · tự cấu hình target', 'discover', body, '<span class="btn t">Nạp fw mới nhất</span>'))

# ---------------------------------------------------------------- 23. Công cụ tự tạo (ToolForge)
tcode = """SPEC = {"id": "user.hex_to_bin_crc", "purpose": "Chuyển Intel HEX sang BIN và tính CRC32",
        "effects": ["read_fs", "write_project"], "deps": ["intelhex"]}
def run(args: dict, ctx) -> dict:
    from intelhex import IntelHex; import zlib
    ih = IntelHex(ctx.fs.path(args["hex"]))
    data = bytes(ih.tobinarray())
    out = args.get("out") or args["hex"].rsplit(".", 1)[0] + ".bin"
    ctx.fs.write_bytes(out, data)
    return {"bin": out, "crc32": f"0x{zlib.crc32(data) & 0xFFFFFFFF:08X}", "size": len(data)}"""
body = f"""
<div class="card" style="width:330px">
  <h3>Công cụ do tác tử tự viết<span class="sp">.eide/tools · 4</span></h3>
  <div class="tree" style="padding:0 8px 8px">
    <div class="on"><span class="pill ok">R2</span>user.hex_to_bin_crc <span class="hint" style="margin-left:auto">3 lần ok</span></div>
    <div><span class="pill ok">R0</span>user.parse_ina219_log <span class="hint" style="margin-left:auto">1 lần</span></div>
    <div><span class="pill warn">R3</span>user.stepper_sweep_test <span class="hint" style="margin-left:auto">chờ board lab</span></div>
    <div><span class="pill silver">—</span>user.old_crc_tool <span class="hint" style="margin-left:auto">deprecated</span></div>
  </div>
  <div class="pad" style="font-size:12px;border-top:1px solid #eef1f5"><b>Vì sao có công cụ này:</b> chuỗi r_0190 cần chuyển .hex → .bin cho bootloader UF2; không có năng lực khớp (điểm C0 0,31) → tool.need → tool.write → tool.test → tool.register.</div>
  <div class="pad" style="margin-top:auto;border-top:1px solid #eef1f5;display:flex;flex-direction:column;gap:8px"><span class="btn t">Đề nghị thăng cấp (Pack owner)</span><span class="btn">Ghép công cụ (compose)</span><span class="btn d">Vô hiệu</span></div>
</div>
<div class="card" style="flex:1">
  <h3>user.hex_to_bin_crc · tool.py<span class="sp">effects khai báo: read_fs, write_project → lớp R2 · test 3/3 đạt · hiệu ứng thực tế khớp</span></h3>
  <div class="code pad" style="flex:1;background:#fbfcfd">{html.escape(tcode)}</div>
  <div class="pad" style="border-top:1px solid #eef1f5;display:flex;flex-direction:column;gap:8px">
    <div style="display:flex;gap:8px;flex-wrap:wrap"><span class="pill ok">AST: không import socket/subprocess</span><span class="pill ok">sandbox: 0 socket · 1 tệp ghi (khai báo)</span><span class="pill ok">schema vào/ra hợp lệ</span><span class="pill info">TOOL-02 APPROVE</span></div>
    <div style="display:flex;gap:8px"><span class="btn">Chạy với build/fw.hex</span><span class="btn">Xem test</span><span class="btn" style="margin-left:auto">Sửa (tool.repair)</span></div>
    <span class="hint">Công cụ tạm chỉ chạy trong sandbox theo hiệu ứng khai báo; hiệu ứng vượt khai báo → REJECT và vô hiệu. Thăng cấp thành năng lực chính thức cần Pack owner duyệt và benchmark.</span>
  </div>
</div>"""
write('ToolForge', shell('Công cụ tự tạo', 'tool.* · tác tử tự viết công cụ Python, test trong sandbox, chạy theo chính sách, đăng ký thành năng lực', 'tool', body, '<span class="btn p">Tạo công cụ mới…</span>'))

canvas = {
  "artboards": [
    {"file": "FlowMap.dc.html", "x": 0, "y": 0, "w": 1440, "h": 620, "title": "0 · Hành trình & cổng người"},
    {"file": "Main.dc.html", "x": 0, "y": 760, "w": 1440, "h": 900, "title": "1 · Tổng quan dự án"},
    {"file": "Ingest.dc.html", "x": 1560, "y": 760, "w": 1440, "h": 900, "title": "2 · Nhập tài liệu"},
    {"file": "ReviewQueue.dc.html", "x": 3120, "y": 760, "w": 1440, "h": 900, "title": "3 · Hàng đợi xác nhận (G-FACT)"},
    {"file": "Passport.dc.html", "x": 0, "y": 1800, "w": 1440, "h": 900, "title": "4 · Hộ chiếu chip"},
    {"file": "Board.dc.html", "x": 1560, "y": 1800, "w": 1440, "h": 900, "title": "5 · Hộ chiếu mạch"},
    {"file": "Graph.dc.html", "x": 3120, "y": 1800, "w": 1440, "h": 900, "title": "6 · Đồ thị tri thức"},
    {"file": "PlanDiff.dc.html", "x": 0, "y": 2840, "w": 1440, "h": 900, "title": "7 · Kế hoạch (G1) & diff (G3)"},
    {"file": "LogAssist.dc.html", "x": 1560, "y": 2840, "w": 1440, "h": 900, "title": "8 · Log gigabyte & hỏi tại dòng"},
    {"file": "Debug.dc.html", "x": 3120, "y": 2840, "w": 1440, "h": 900, "title": "9 · Gỡ lỗi probe & chứng cứ"},
    {"file": "Registry.dc.html", "x": 0, "y": 3880, "w": 1440, "h": 900, "title": "10 · Registry"},
    {"file": "Models.dc.html", "x": 1560, "y": 3880, "w": 1440, "h": 900, "title": "11 · Mô hình & chi phí"},
    {"file": "Chat.dc.html", "x": 3120, "y": 3880, "w": 1440, "h": 900, "title": "12 · Trò chuyện với tác tử"},
    {"file": "Code.dc.html", "x": 0, "y": 4920, "w": 1440, "h": 900, "title": "13 · Mã nguồn (constant-guard)"},
    {"file": "Sim.dc.html", "x": 1560, "y": 4920, "w": 1440, "h": 900, "title": "14 · Mô phỏng SIL/HIL"},
    {"file": "Bench.dc.html", "x": 3120, "y": 4920, "w": 1440, "h": 900, "title": "15 · Benchmark"},
    {"file": "Env.dc.html", "x": 0, "y": 5960, "w": 1440, "h": 900, "title": "16 · Môi trường & báo cáo"},
    {"file": "RagAsk.dc.html", "x": 1560, "y": 5960, "w": 1440, "h": 900, "title": "18 · Bản đồ tri thức & hỏi đáp (v1.2)"},
    {"file": "ReqArch.dc.html", "x": 3120, "y": 5960, "w": 1440, "h": 900, "title": "19 · Yêu cầu & kiến trúc (v1.2)"},
    {"file": "DiagramView.dc.html", "x": 0, "y": 7000, "w": 1440, "h": 900, "title": "20 · Lược đồ (v1.2)"},
    {"file": "Doc.dc.html", "x": 1560, "y": 7000, "w": 1440, "h": 900, "title": "21 · Tài liệu (v1.2)"},
    {"file": "Discovery.dc.html", "x": 3120, "y": 7000, "w": 1440, "h": 900, "title": "22 · Dò board (v1.2)"},
    {"file": "ToolForge.dc.html", "x": 0, "y": 8040, "w": 1440, "h": 900, "title": "23 · Công cụ tự tạo (v1.2)"},
  ],
  "annotations": [
    {"id": "note-direction", "x": 1560, "y": 40, "w": 520, "text": "Hướng thiết kế: bàn làm việc kỹ thuật, mật độ cao, sáng. Màu theo nhận diện PTIT: đỏ chủ đạo cho điều hướng/hành động chính, vàng sao = cần con người quyết định, xám xanh cho hành động phụ. Mã HEX chính xác của PTIT chưa công bố — đổi 3 hằng số trong gen.py khi có bộ nhận diện. Mọi giá trị phần cứng luôn đi kèm tầng tin cậy và nguồn.\nKịch bản dữ liệu: robot-ctrl trên WeAct BlackPill F411 + BME280 (kịch bản B của PDA-00)."},
    {"id": "note-scope", "x": 2140, "y": 40, "w": 420, "text": "Mockup tĩnh 1440×900 (macOS, EIDE trên nền GEditor). CLI và MCP không có màn hình riêng; IDE ngoài dùng tool của Knowledge Plane. 17 màn hình gồm chat, mã nguồn, mô phỏng, benchmark, môi trường & báo cáo."}
  ],
  "launch": {"view": "canvas"}
}
(OUT / 'canvas.json').write_text(json.dumps(canvas, ensure_ascii=False, indent=2), encoding='utf-8')
print('ok', len(list(OUT.glob('*.dc.html'))))
