-- 0002_m1_policy_runtime — mốc M1. Nguồn: EIDE-DDD-14 §5, DDL trong docs/spec/data/schema.sql.
--
-- Bảng theo §5: acq_request, permission, decision_log, capability_run, intent, run, error_ledger,
-- preference, capability, requirement, diagram; cột fact.layer; chỉ mục mới. user_version=2.
--
-- THÊM `session`, KHÔNG có trong §5 — xem DEVIATIONS DEV-006. DDD-14 §2.25 ghi rõ bảng `session`
-- là "từ M1" và schema.sql có nó, nhưng bảng lịch migration §5 không xếp nó vào migration nào,
-- nên nếu bám §5 từng chữ thì `session` không bao giờ được tạo. Đặt ở đây vì §2.25 nói M1.
--
-- Thứ tự trong tệp có ý nghĩa: decision_log trước capability_run và intent trước run, vì khóa
-- ngoại tham chiếu tới chúng.

ALTER TABLE fact ADD COLUMN layer TEXT NOT NULL DEFAULT 'C';

CREATE TABLE IF NOT EXISTS acq_request (
  id TEXT PRIMARY KEY,
  need TEXT NOT NULL,
  subject TEXT,
  part TEXT,
  peripheral TEXT,
  state TEXT NOT NULL,
  candidates TEXT,
  decisions TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE INDEX IF NOT EXISTS ix_acq_request_0 ON acq_request (state);

CREATE TABLE IF NOT EXISTS permission (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  op TEXT NOT NULL,
  target TEXT,
  granted_by TEXT NOT NULL,
  granted_at TEXT NOT NULL,
  expires_at TEXT
);
CREATE INDEX IF NOT EXISTS ix_permission_0 ON permission (session_id, op);

CREATE TABLE IF NOT EXISTS decision_log (
  id TEXT PRIMARY KEY,
  gate TEXT,
  action_cap TEXT NOT NULL,
  risk TEXT NOT NULL,
  autonomy_level TEXT NOT NULL,
  decision TEXT NOT NULL,
  by TEXT NOT NULL,
  rule TEXT,
  reason TEXT,
  evidence TEXT,
  features TEXT,
  human_answer TEXT,
  undone_at TEXT,
  at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_decision_log_0 ON decision_log (gate, decision, by);
CREATE INDEX IF NOT EXISTS ix_decision_log_1 ON decision_log (at);

CREATE TABLE IF NOT EXISTS capability_run (
  id TEXT PRIMARY KEY,
  run_id TEXT,
  cap TEXT NOT NULL,
  args_hash TEXT NOT NULL,
  actor TEXT NOT NULL,
  decision_id TEXT REFERENCES decision_log(id),
  status TEXT NOT NULL,
  started_at TEXT NOT NULL,
  finished_at TEXT,
  result_ref TEXT,
  undo_ref TEXT,
  error TEXT,
  cost_usd REAL
);
CREATE INDEX IF NOT EXISTS ix_capability_run_0 ON capability_run (run_id);
CREATE INDEX IF NOT EXISTS ix_capability_run_1 ON capability_run (cap, started_at);

CREATE TABLE IF NOT EXISTS intent (
  id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  intent TEXT NOT NULL,
  slots TEXT,
  is_big INTEGER,
  confidence REAL,
  lang TEXT,
  grounded TEXT,
  defaults_applied TEXT,
  question TEXT,
  session_id TEXT,
  at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS run (
  id TEXT PRIMARY KEY,
  intent_id TEXT REFERENCES intent(id),
  graph TEXT NOT NULL,
  state TEXT NOT NULL,
  working TEXT,
  report TEXT,
  cost_usd REAL,
  started_at TEXT,
  finished_at TEXT
);
CREATE INDEX IF NOT EXISTS ix_run_0 ON run (state);

CREATE TABLE IF NOT EXISTS requirement (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  text TEXT NOT NULL,
  priority TEXT,
  acceptance TEXT,
  trace TEXT,
  source TEXT,
  feasibility TEXT,
  status TEXT NOT NULL DEFAULT 'generated',
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS diagram (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  lang TEXT NOT NULL,
  src TEXT NOT NULL,
  source_ref TEXT,
  rendered_ref TEXT,
  lint TEXT,
  node_ids TEXT,
  synced_with TEXT,
  stale INTEGER DEFAULT 0,
  path TEXT,
  at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS error_ledger (
  id TEXT PRIMARY KEY,
  role TEXT,
  kind TEXT NOT NULL,
  task_ref TEXT,
  chip TEXT,
  evidence TEXT,
  negative_prompt TEXT,
  ttl_until TEXT,
  at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_error_ledger_0 ON error_ledger (role, chip, at);

CREATE TABLE IF NOT EXISTS preference (
  key TEXT NOT NULL,
  scope TEXT NOT NULL,
  value TEXT NOT NULL,
  learned_from TEXT,
  ttl_days INTEGER,
  at TEXT NOT NULL,
  PRIMARY KEY (key, scope)
);

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

CREATE TABLE IF NOT EXISTS capability (
  code TEXT PRIMARY KEY,
  id TEXT UNIQUE NOT NULL,
  ns TEXT NOT NULL,
  name TEXT NOT NULL,
  desc TEXT,
  input_schema TEXT,
  output_schema TEXT,
  risk TEXT NOT NULL,
  tier TEXT NOT NULL,
  grounding TEXT,
  ask_when TEXT,
  undo_kind TEXT,
  milestone TEXT,
  impl TEXT,
  ui TEXT
);
