# -*- coding: utf-8 -*-
# Sáu màn hình mới v1.2 — được nối vào gen.py trước phần canvas
NEW = r'''
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
'''
