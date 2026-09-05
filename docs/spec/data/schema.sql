-- EIDE store.sqlite — sinh từ EIDE-DDD-14 (ddd_model.py). PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
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
  supersedes TEXT REFERENCES fact(id),
  layer TEXT NOT NULL DEFAULT 'C'
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
CREATE TABLE IF NOT EXISTS code_unit (
  id TEXT PRIMARY KEY,
  path TEXT NOT NULL,
  symbol TEXT,
  hash TEXT NOT NULL,
  cites TEXT,
  uses TEXT,
  module_id TEXT REFERENCES module(id),
  stale INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_code_unit_0 ON code_unit (path);
CREATE INDEX IF NOT EXISTS ix_code_unit_1 ON code_unit (module_id);
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
CREATE TABLE IF NOT EXISTS debug_session (
  id TEXT PRIMARY KEY,
  log_ref TEXT,
  range_start INTEGER,
  range_end INTEGER,
  evidence TEXT,
  hypotheses TEXT,
  outcome TEXT,
  fact_ids TEXT,
  code_ids TEXT,
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
CREATE VIRTUAL TABLE IF NOT EXISTS rag_chunk_fts USING fts5(text, keywords, content='rag_chunk', content_rowid='rowid');
