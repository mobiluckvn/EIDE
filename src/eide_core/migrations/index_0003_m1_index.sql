-- 0003_m1_index — mốc M1. Nguồn: EIDE-DDD-14 §5, DDL trong docs/spec/data/schema.sql.
--
-- §5 ghi rõ: "index/index.sqlite RIÊNG: rag_chunk + FTS5 (rag_chunk_fts); KHÔNG migration trong
-- store chính". Nên tệp này không nằm trong dãy user_version của store.sqlite — nó dựng một cơ
-- sở dữ liệu thứ hai ở .eide/index/index.sqlite, và tên tệp mang tiền tố `index_` để bộ nạp
-- migration của store bỏ qua.
--
-- Tách ra là có lý do: chỉ mục nhúng và FTS5 dựng lại được từ nguồn, còn store.sqlite thì không.
-- Xóa index.sqlite là một thao tác an toàn; xóa store.sqlite thì mất tri thức.

CREATE TABLE IF NOT EXISTS rag_chunk (
  id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL,
  locator TEXT,
  text TEXT NOT NULL,
  embedding BLOB,
  keywords TEXT,
  graph_nodes TEXT,
  model TEXT
);
CREATE INDEX IF NOT EXISTS ix_rag_chunk_0 ON rag_chunk (source_id);

CREATE VIRTUAL TABLE IF NOT EXISTS rag_chunk_fts USING fts5(text, keywords, content='rag_chunk', content_rowid='rowid');
