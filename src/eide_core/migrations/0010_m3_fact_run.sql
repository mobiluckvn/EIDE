-- 0010 — `fact.run_id`: fact này do LƯỢT CHẠY nào tạo ra. [DEV-170]
--
-- POL-17 §5 định nghĩa loại hoàn tác `supersede_facts` rất rõ: *"với mỗi fact tự duyệt, tạo
-- fact mới supersedes với status = superseded, khôi phục fact trước (nếu có) thành hiện hành"*.
-- 18 năng lực khai loại ấy. Nhưng tới 22/09/2026 KHÔNG cái nào hoàn tác được, vì câu "mỗi fact
-- tự duyệt **của lượt chạy này**" không trả lời được: bảng `fact` không có chỗ nào nói nó đến
-- từ đâu.
--
-- `store.write` trong sổ cái có `batch_id`, nhưng `fact` không lưu `batch_id` — nên mắt xích
-- đứt ngay chỗ cần nhất.
--
-- Giá trị ngoài hoàn tác: đây là TRUY NGUỒN. "Con số 2,4 MSPS này từ đâu ra" là câu hỏi đầu
-- tiên một kỹ sư hỏi khi thấy một fact đáng ngờ, và hôm nay câu trả lời duy nhất là `source_id`
-- — tức tài liệu gốc, không phải lượt chạy đã rút nó ra. Hai thứ khác nhau: một tài liệu đúng
-- vẫn có thể bị một lượt trích xuất đọc sai.
ALTER TABLE fact ADD COLUMN run_id TEXT;

-- Tên `ix_fact_3` không phải tuỳ tiện: `data/schema.sql` là tệp SINH, và bộ sinh đặt tên index
-- theo vị trí (`ix_<bảng>_<i>`). Đặt tên khác ở đây thì hai đường dựng store — migration và
-- schema.sql — cho ra hai tên cho cùng một index, và `test_migration_khop_schema_sql` (vốn chỉ
-- so cột) sẽ không bắt được.
CREATE INDEX IF NOT EXISTS ix_fact_3 ON fact (run_id);
