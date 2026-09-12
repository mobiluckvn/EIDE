-- DDD-14 §2 DebugSession (`since: M3`) — bảng cuối cùng của bộ hồ sơ chưa có migration.
-- user_version=7.
--
-- Nhóm `debug.*` sinh ra một hiện vật mà không nhóm nào khác sinh: **một lần suy luận có chứng
-- cứ**. `tool_report` ghi kết quả một lần chạy công cụ, `decision_log` ghi một lần cổng quyết,
-- `capability_run` ghi một lời gọi — không bảng nào trong ba bảng ấy giữ được "giả thuyết nào
-- đã xét, chứng cứ nào ủng hộ, và cuối cùng hoá ra đúng hay sai".
--
-- Vì sao điều ấy phải LƯU chứ không chỉ trả về: `debug.propose_fix` đọc lại một phiên đã
-- `confirmed` để đề xuất sửa, và `memory.error_ledger` đọc `outcome` để rút bài học. Một phiên
-- gỡ lỗi chỉ sống trong một lời gọi thì hai năng lực ấy không có gì để đứng lên — và bài học
-- đắt nhất của một dự án nhúng (lần trước con chip này NACK vì bus quá nhanh) là đúng thứ dễ
-- mất nhất.
--
-- `range_start`/`range_end` là SỐ DÒNG trong `log_ref`, không phải mốc thời gian: log firmware
-- thường không có dấu thời gian theo dòng (xem DEV-085 về cùng vấn đề ở `sim.run`), còn số
-- dòng thì luôn có. Neo câu trả lời vào vùng dòng là cách duy nhất để người đọc mở đúng chỗ.
--
-- `evidence` và `hypotheses` lưu JSON chứ không tách bảng con: cả hai chỉ được đọc CÙNG phiên
-- của chúng, không ai truy vấn chéo "mọi giả thuyết có p > 0,8 trong mọi phiên". Tách bảng cho
-- một quan hệ chưa ai hỏi là thêm hai phép nối vào mọi lần đọc để đổi lấy một truy vấn giả
-- định.
--
-- `fact_ids`/`code_ids` là chỗ phiên gỡ lỗi nối vào tầng tri thức: một chẩn đoán nói "thanh ghi
-- này đặt sai" phải chỉ được ra FACT nào mô tả thanh ghi ấy, nếu không nó chỉ là một câu văn.
CREATE TABLE IF NOT EXISTS debug_session (
    id           TEXT PRIMARY KEY,
    log_ref      TEXT,
    range_start  INTEGER,
    range_end    INTEGER,
    evidence     TEXT,
    hypotheses   TEXT,
    outcome      TEXT CHECK (outcome IS NULL OR outcome IN ('confirmed', 'refuted', 'open')),
    fact_ids     TEXT,
    code_ids     TEXT,
    at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_debug_session_at ON debug_session (at);
