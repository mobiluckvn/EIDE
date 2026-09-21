-- 0008 — bảng `clarification`: những ĐIỂM CẦN LÀM RÕ mà tác tử tìm ra. [DEV-151]
--
-- Vì sao cần một bảng riêng, thay vì nhét vào `requirement`:
--
-- `requirement.status` khai đúng năm giá trị (`generated | reviewed | accepted | rejected |
-- stale`) và không giá trị nào nghĩa là "cần làm rõ". Quan trọng hơn: phần lớn điểm cần làm rõ
-- KHÔNG phải một yêu cầu. `req.elicit` trả `gaps` TRƯỚC khi có mã yêu cầu nào; `req.detect_conflict`
-- trả `issues` trỏ tới NHIỀU yêu cầu cùng lúc ("R-01 và R-07 mâu thuẫn"). Ép chúng thành hàng
-- trong `requirement` sẽ đẻ ra những yêu cầu giả mang mã thật.
--
-- Vì sao bảng này phải tồn tại:
--
-- Sản phẩm có một tab tên "Làm rõ yêu cầu", có hai năng lực tính ra đúng dữ liệu ấy, và tới
-- 21/09/2026 KHÔNG CÓ GÌ Ở GIỮA — `req.elicit.gaps` và `req.detect_conflict.issues` được tính
-- rồi vứt đi trong cùng một nhịp. Nên tab ấy không có gì để hiện và lấp chỗ trống bằng lịch sử
-- trò chuyện. Chủ sản phẩm nói thẳng: *"nếu đang làm rõ yêu cầu thì yêu cầu cần làm rõ nó phải
-- hiển thị ở tab Làm rõ yêu cầu"*.
--
-- `answer` nằm cùng bảng chứ không ở nơi khác: mục tiêu là NGƯỜI VÀ TÁC TỬ CÙNG LÀM, nên câu
-- trả lời của người là một phần của chính điểm cần làm rõ, và đọc một cái mà không thấy cái kia
-- là đọc nửa câu chuyện.
CREATE TABLE IF NOT EXISTS clarification (
  id           TEXT PRIMARY KEY,
  kind         TEXT NOT NULL,              -- gap | conflict | ambiguous | unmeasurable
  text         TEXT NOT NULL,              -- điều cần làm rõ, bằng tiếng người
  req_ids      TEXT,                       -- JSON: mã các yêu cầu liên quan (có thể rỗng)
  suggestion   TEXT,                       -- đề xuất của tác tử, nếu có
  source_cap   TEXT,                       -- năng lực đã tìm ra nó
  run_id       TEXT,                       -- lượt chạy đã tìm ra nó
  status       TEXT NOT NULL DEFAULT 'open',   -- open | answered | dismissed
  answer       TEXT,                       -- câu trả lời của NGƯỜI
  answered_by  TEXT,                       -- human:<tên> | agent
  created_at   TEXT,
  answered_at  TEXT
);

CREATE INDEX IF NOT EXISTS idx_clarification_status ON clarification (status);

-- Lịch sử câu trả lời, CHỈ THÊM. `clarification.answer` là bản hiện hành (đọc nhanh), còn sự
-- thật nằm ở đây.
--
-- Chủ sản phẩm đòi "mọi thứ phải được lưu lại sự thay đổi và rollback lại theo TỪNG LẦN thay
-- đổi". Một cột `answer` bị ghi đè không làm được điều đó, và sổ cái cũng không: `cap.run.start`
-- chỉ giữ `args_hash` — một mã băm, không giữ nội dung. Nên lịch sử phải nằm ở đây.
--
-- `undone_at` chứ không XOÁ dòng: một lần hoàn tác cũng là một sự kiện, và xoá nó đi thì lần
-- sau không ai biết câu trả lời ấy từng tồn tại.
CREATE TABLE IF NOT EXISTS clarification_answer (
  id          TEXT PRIMARY KEY,
  clar_id     TEXT NOT NULL REFERENCES clarification(id),
  answer      TEXT NOT NULL,
  answered_by TEXT NOT NULL,
  at          TEXT NOT NULL,
  undone_at   TEXT
);
CREATE INDEX IF NOT EXISTS idx_clar_answer ON clarification_answer (clar_id, at);
