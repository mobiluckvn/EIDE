# MCU-X Reference Manual — RM0099 rev 3.1 (2026-03)

## Trang 412 — SPI2: thanh ghi SPI_CR2

| Bit | Tên      | Mô tả                                                        |
|-----|----------|--------------------------------------------------------------|
| 0   | RXDMAEN  | Bật yêu cầu DMA khi bộ đệm nhận đầy                           |
| 1   | TXDMAEN  | Bật yêu cầu DMA khi bộ đệm phát rỗng (dùng cho SPI2 TX)       |
| 2   | SSOE     | Cho phép chân SS ra                                           |
| 6   | RXNEIE   | Cho phép ngắt RXNE                                            |

## Trang 415 — SPI2: kênh DMA

SPI2_TX gắn cứng vào DMA1 kênh 5. Phải bật TXDMAEN (SPI_CR2 bit 1) TRƯỚC khi bật kênh DMA.

## Trang 88 — Nguồn cấp

VDD: 2,0 V – 3,6 V. Dòng tiêu thụ chế độ chạy 8,4 mA ở 48 MHz.

## Errata ES0099 rev 3 — mục 2.4.1

Khi TXDMAEN được bật trong lúc SPI đang bận, byte đầu tiên có thể bị phát hai lần.
Cách tránh: chờ cờ BSY = 0 trước khi bật TXDMAEN.
