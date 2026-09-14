# Nhật ký hệ thống — phiên AVR / Arduino Uno (ATmega328P)

Dự án: `/Users/congvt/eide/doc-cam-bien-dht22-va-nhap-nhay-led-tren-arduino`  
Ngày: 2026-09-14 · Máy: darwin arm64 · qemu-system-avr, avr-gcc 7.3.0 (Arduino AVR core)

## 1. Toàn vẹn chuỗi băm

- Sự kiện: **105**
- Chuỗi băm: **HỢP LỆ** (`Ledger.verify()`)
- Mắt xích cuối: `681c806dfa601c38fbe6d533334d7d1c75c42e09…`

Nhật ký là chuỗi chỉ-thêm: mỗi bản ghi băm cả nội dung của nó lẫn băm của bản ghi trước.
Sửa một dòng ở giữa làm gãy mọi mắt xích sau nó, nên một lần `verify()` hợp lệ nghĩa là
không ai chèn, xoá hay sửa sự kiện nào sau khi nó được ghi.

## 2. Sự kiện theo loại

| Loại | Số | Nghĩa |
|---|---|---|
| `cap.run.start` | 28 | một lời gọi năng lực bắt đầu |
| `gate.decision` | 28 | PolicyGate quyết định APPROVE / ASK / REJECT |
| `cap.run.finish` | 28 | …và kết thúc, kèm trạng thái |
| `tool.report` | 8 | một công cụ ngoài chạy xong (build / size / sim) |
| `undo.register` | 7 | một việc đã làm, còn hoàn tác được trong hạn |
| `store.write` | 3 | ghi vào store qua cổng ghi duy nhất |
| `gate.human` | 2 | NGƯỜI duyệt hoặc từ chối một mục chờ |
| `store.migrate` | 1 | di trú lược đồ store |

## 3. Quyết định của cổng

| Quyết định | Số |
|---|---|
| APPROVE | 25 |
| ASK | 3 |

### Mục NGƯỜI đã duyệt

- `ba1edc51d5ab` → **APPROVE** bởi *human*
  > packs.download.microchip.com là máy chủ gói chính thức của Microchip, khai trong docs/spec/sources/vendors.yaml §microchip.domains. Gói DFP là ATDF/EDC hãng phát hành, Apache-2.0 (trong allowed_licenses). Rơi vào ASK chỉ vì trusted_sources khớp CHÍNH XÁC và chỉ có microchip.com trần — xem DEV-103. Duyệt bởi tác tử thay chủ sản phẩm.

- `2eec6dc559e6` → **APPROVE** bởi *human*
  > Máy chủ gói chính thức của Microchip (vendors.yaml §microchip.domains). ATDF/EDC hãng phát hành, Apache-2.0. ASK chỉ vì trusted_sources khớp chính xác — DEV-103. Duyệt thay chủ sản phẩm.

## 4. Mọi lời gọi năng lực, theo thứ tự

| # | Năng lực | Trạng thái |
|---|---|---|
| 1 | `env.detect` | done |
| 2 | `search.vendor` | done |
| 3 | `search.fetch` | pending |
| 4 | `policy.undo_window` | done |
| 5 | `search.fetch` | pending |
| 6 | `policy.undo_window` | done |
| 7 | `search.fetch` | failed |
| 8 | `search.fetch` | pending |
| 9 | `policy.undo_window` | done |
| 10 | `search.fetch` | done |
| 11 | `archive.query` | failed |
| 12 | `archive.query` | done |
| 13 | `archive.extract_one` | done |
| 14 | `extract.atdf` | done |
| 15 | `kg.build` | done |
| 16 | `passport.query` | done |
| 17 | `passport.query` | done |
| 18 | `project.set_target` | done |
| 19 | `env.check` | done |
| 20 | `env.check` | done |
| 21 | `code.build` | failed |
| 22 | `env.check` | done |
| 23 | `code.build` | done |
| 24 | `code.size` | done |
| 25 | `kg.review_facts` | done |
| 26 | `sim.build_platform` | done |
| 27 | `sim.run` | done |
| 28 | `sim.run` | done |

## 5. Báo cáo công cụ ngoài

- **/usr/bin/make** — passed=`True`, 5546 ms
- **build** — passed=`True`, 5550 ms
  - {"error_kind": null, "error_lines": [], "exit_code": 0, "isa": "avr8", "map": null}
- **/Users/congvt/Library/Arduino15/packages/arduino/tools/avr-gcc/7.3.0-atmel3.6.1-arduino7/bin/avr-size** — passed=`True`, 40 ms
- **size** — passed=`True`, 43 ms
  - {"bss": 0, "data": 108, "flash": 650, "flash_pct": 1.98, "flash_truoc": null, "limits": {"flash": 32768, "ram": 2304}, "ram": 108, "ram_pct": 4.69, "reason": null, "text": 542, "threshold_flash": 0.85}
- **/opt/homebrew/bin/qemu-system-avr** — passed=`False`, 25005 ms
- **sim.run** — passed=`True`, 25007 ms
  - {"duration_s": 5, "engine": "qemu", "feature": "F-01", "n_passed": 6, "n_unverified": 0, "scenario": "sim/blink-uart.yaml", "terminated_by": "timeout"}
- **/opt/homebrew/bin/qemu-system-avr** — passed=`False`, 25004 ms
- **sim.run** — passed=`True`, 25006 ms
  - {"duration_s": 5, "engine": "qemu", "feature": "F-01", "n_passed": 6, "n_unverified": 0, "scenario": "sim/blink-uart.yaml", "terminated_by": "timeout"}
