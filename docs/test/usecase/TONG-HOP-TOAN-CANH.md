# Tổng hợp toàn cảnh — 3 ca có dữ liệu

| TC | phán quyết | state | bước xong | hỏng (bắt buộc) | hỏng (tuỳ chọn) | hỏi người | lời gọi | bị cắt | token ra | USD |
|---|---|---|---|---|---|---|---|---|---|---|
| TC001 | Không đạt | asked | 2 | — | — | env.check→isa | 1 | — | 95 | 0.001 |
| TC002 | Không đạt | — | 0 | — | — | — | 0 | — | 0 | 0 |
| TC008 | Không đạt | done | 6 | — | arch.adr:E5000 | — | 6 | — | 6967 | 0.0955 |

## Nhóm lỗi — rút từ chữ ký, không đặt tay

| chữ ký | số ca | các ca |
|---|---|---|
| `HỎI env.check→isa` | 1 | TC001 |

## Tổng

- lời gọi mô hình: **7**, trong đó **0 bị cắt** (vai trò: —)
- token vào 11,092 · token ra 7,062 · chi phí **0.0965 USD**
- sự kiện ledger: 484 · cổng hỏi người: 0
- trạng thái lượt chạy: {'asked': 1, '—': 1, 'done': 1}
