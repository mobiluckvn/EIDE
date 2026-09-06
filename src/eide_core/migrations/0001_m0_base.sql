-- 0001_m0_base — mốc M0. Nguồn: EIDE-DDD-14 §5, DDL trong docs/spec/data/schema.sql.
--
-- Bảng: source, fact, passport, passport_fact, code_unit, feature, tool_report. user_version=1.
--
-- HAI CHỖ CỐ Ý KHÁC schema.sql, và cả hai đều do §5 quy định chứ không phải lựa chọn:
--
--   fact.layer      §5 xếp cột này vào 0002. schema.sql là ảnh chụp mô hình ĐẦY ĐỦ (sau mọi
--                   migration) nên có sẵn cột ấy; ở đây thì chưa.
--   code_unit.module_id  §5 xếp vào 0004 cùng bảng `module` mà nó tham chiếu. Đặt cột ở 0001
--                   thì khóa ngoại trỏ vào một bảng chưa tồn tại — SQLite chấp nhận lúc tạo
--                   nhưng hỏng ngay lần ghi đầu khi foreign_keys=ON.
--
-- Chỉ mục ix_code_unit_1 (trên module_id) đi cùng cột của nó sang 0004.

CREATE TABLE IF NOT EXISTS source (
  id TEXT PRIMARY KEY,
  uri TEXT NOT NULL,
  sha256 TEXT UNIQUE,
  kind TEXT NOT NULL,
  tier TEXT NOT NULL,
  license TEXT,
  domain TEXT,
  fetched_at TEXT,
  confirmed_by TEXT,
  size_bytes INTEGER,
  meta TEXT
);

CREATE TABLE IF NOT EXISTS fact (
  id TEXT PRIMARY KEY,
  subject TEXT NOT NULL,
  predicate TEXT NOT NULL,
  value TEXT NOT NULL,
  unit TEXT,
  source_id TEXT NOT NULL REFERENCES source(id),
  locator TEXT,
  method TEXT NOT NULL,
  tier TEXT NOT NULL,
  confidence REAL NOT NULL,
  status TEXT NOT NULL,
  confirmed_by TEXT,
  confirmed_at TEXT,
  supersedes TEXT REFERENCES fact(id)
);
CREATE INDEX IF NOT EXISTS ix_fact_0 ON fact (subject, predicate, status);
CREATE INDEX IF NOT EXISTS ix_fact_1 ON fact (source_id);
CREATE INDEX IF NOT EXISTS ix_fact_2 ON fact (status);

CREATE TABLE IF NOT EXISTS passport (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  header TEXT NOT NULL,
  created_at TEXT NOT NULL,
  badges TEXT,
  pinned_by TEXT
);

CREATE TABLE IF NOT EXISTS passport_fact (
  passport_id TEXT NOT NULL REFERENCES passport(id),
  fact_id TEXT NOT NULL REFERENCES fact(id),
  PRIMARY KEY (passport_id, fact_id)
);

CREATE TABLE IF NOT EXISTS code_unit (
  id TEXT PRIMARY KEY,
  path TEXT NOT NULL,
  symbol TEXT,
  hash TEXT NOT NULL,
  cites TEXT,
  uses TEXT,
  stale INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_code_unit_0 ON code_unit (path);

CREATE TABLE IF NOT EXISTS feature (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL,
  evidence TEXT,
  verified TEXT,
  run_id TEXT,
  requirement_ids TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS tool_report (
  id TEXT PRIMARY KEY,
  tool TEXT NOT NULL,
  passed INTEGER NOT NULL,
  log_ref TEXT,
  metrics TEXT,
  artifacts TEXT,
  duration_ms INTEGER,
  started_by TEXT,
  at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_tool_report_0 ON tool_report (tool, at);
