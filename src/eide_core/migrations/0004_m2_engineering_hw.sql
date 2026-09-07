-- 0004_m2_engineering_hw — mốc M2. Nguồn: EIDE-DDD-14 §5, DDL trong docs/spec/data/schema.sql.
--
-- Bảng theo §5: module, hw_map, adr, doc_artifact, discovery, measurement; cột code_unit.module_id.
-- user_version=3.
--
-- Chép nguyên DDL từ docs/spec/data/schema.sql, không viết lại: schema.sql là bản sinh từ
-- ddd_model.py, nên gõ tay ở đây là mở một đường cho hai bản mô tả cùng một bảng trôi khỏi nhau.
-- `tests/test_specs_consistency.py` đối chiếu hai bên.
--
-- Thứ tự có ý nghĩa: `module` phải đứng trước `hw_map` và trước `ALTER TABLE code_unit`, vì cả
-- hai tham chiếu khóa ngoại tới nó.
--
-- `measurement` nằm ở migration này chứ không ở 0001 dù nó là bảng bằng chứng: §5 xếp nó vào M2
-- cùng nhóm phần cứng, và bảng bằng chứng không có giá trị khi chưa có gì để đo.

CREATE TABLE IF NOT EXISTS module (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  responsibility TEXT,
  interfaces TEXT,
  depends TEXT,
  arch_style TEXT,
  budget TEXT,
  fsm TEXT,
  status TEXT
);

CREATE TABLE IF NOT EXISTS hw_map (
  module_id TEXT NOT NULL REFERENCES module(id),
  resource TEXT NOT NULL,
  role TEXT,
  fact_ids TEXT,
  PRIMARY KEY (module_id, resource)
);
CREATE INDEX IF NOT EXISTS ix_hw_map_0 ON hw_map (resource);

CREATE TABLE IF NOT EXISTS adr (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  context TEXT,
  options TEXT,
  decision TEXT,
  consequences TEXT,
  citations TEXT,
  status TEXT,
  at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS doc_artifact (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  template TEXT,
  path TEXT NOT NULL,
  sections TEXT,
  citations TEXT,
  style_issues TEXT,
  stale_sections TEXT,
  lang TEXT,
  at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS discovery (
  id TEXT PRIMARY KEY,
  ports TEXT,
  probes TEXT,
  chip_id TEXT,
  link_speed TEXT,
  firmware TEXT,
  power TEXT,
  network TEXT,
  target_config TEXT,
  at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS measurement (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  target TEXT,
  value TEXT,
  unit TEXT,
  file_ref TEXT,
  hash TEXT,
  at TEXT NOT NULL
);

ALTER TABLE code_unit ADD COLUMN module_id TEXT REFERENCES module(id);
CREATE INDEX IF NOT EXISTS ix_code_unit_1 ON code_unit (module_id);
