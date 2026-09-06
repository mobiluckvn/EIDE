-- .eide/session/session.sqlite — bộ nhớ phiên M2. Nguồn: MEM-11 §2 và DDD-14 §2.25
-- ("Phiên làm việc (session.sqlite, không commit)"); DDL trong docs/spec/data/schema.sql.
--
-- Cơ sở dữ liệu RIÊNG, không nằm trong dãy user_version của store.sqlite — cùng lý do với
-- index.sqlite: phiên làm việc dựng lại được (mở dự án là có phiên mới), còn store.sqlite thì
-- không. Xóa session.sqlite là thao tác an toàn; nó cũng nằm trong .gitignore của dự án vì
-- lịch sử chat và quyền theo phiên không thuộc về kho mã.
--
-- Tên tệp mang tiền tố `session_` để bộ nạp migration của store bỏ qua (nó chỉ nhận `NNNN_*.sql`).

CREATE TABLE IF NOT EXISTS session (
  id TEXT PRIMARY KEY,
  project TEXT NOT NULL,
  opened_at TEXT NOT NULL,
  closed_at TEXT,
  autonomy_effective TEXT,
  stopped INTEGER DEFAULT 0,
  turns TEXT,
  undo_items TEXT,
  summary TEXT
);
CREATE INDEX IF NOT EXISTS ix_session_0 ON session (project, opened_at);
