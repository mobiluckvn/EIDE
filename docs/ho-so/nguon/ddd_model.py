# -*- coding: utf-8 -*-
"""Mô hình dữ liệu EIDE — nguồn duy nhất sinh JSON Schema, DDL SQLite, bảng từ điển dữ liệu (EIDE-DDD-14)."""
# field: (tên, kiểu JSON, kiểu SQL, bắt buộc, mô tả, enum|None)
E = []
def entity(name, table, desc, fields, pk="id", indexes=(), layer="", since="M0"):
    E.append(dict(name=name, table=table, desc=desc, fields=fields, pk=pk, indexes=indexes, layer=layer, since=since))

S, I, N, B, O, A, DT = "string", "integer", "number", "boolean", "object", "array", "date-time"
entity("Source", "source", "Nguồn tri thức: tệp/URL đã tải, có băm, tầng tin cậy, license", [
 ("id", S, "TEXT PRIMARY KEY", 1, "src_<16 hex>", None), ("uri", S, "TEXT NOT NULL", 1, "Đường dẫn cục bộ hoặc URL gốc", None),
 ("sha256", S, "TEXT UNIQUE", 1, "Băm nội dung", None), ("kind", S, "TEXT NOT NULL", 1, "Loại nguồn", ["svd","atdf","edc","binding","header","pdf","docx","xlsx","html","md","image","kicad","netlist","bom","csv","archive","web","docs_mcp","registry","readme"]),
 ("tier", S, "TEXT NOT NULL", 1, "Tầng tin cậy", ["gold","silver","bronze"]), ("license", S, "TEXT", 0, "SPDX hoặc 'unknown'", None),
 ("domain", S, "TEXT", 0, "Tên miền nếu tải từ web", None), ("fetched_at", DT, "TEXT", 0, "Thời điểm tải", None), ("confirmed_by", S, "TEXT", 0, "policy|<user>", None),
 ("size_bytes", I, "INTEGER", 0, "Kích thước", None), ("meta", O, "TEXT", 0, "JSON: trang, phiên bản tài liệu, ngày phát hành", None)], layer="L-A/L-B/L-C")
entity("Fact", "fact", "Bản ghi tri thức bất biến có nguồn (KAD-07)", [
 ("id", S, "TEXT PRIMARY KEY", 1, "f_<16 hex>", None), ("subject", S, "TEXT NOT NULL", 1, "IRI: chip:st.stm32f411ce/periph:I2C1/reg:CR1/field:PE", None),
 ("predicate", S, "TEXT NOT NULL", 1, "Vị từ", ["base_address","offset","bit_range","reset_value","enum","pin_function","voltage_range","timing","irq","description","net","address","clock","memory_size","package","other"]),
 ("value", O, "TEXT NOT NULL", 1, "JSON (số/chuỗi/đối tượng)", None), ("unit", S, "TEXT", 0, "Đơn vị", None), ("source_id", S, "TEXT NOT NULL REFERENCES source(id)", 1, "Nguồn", None),
 ("locator", O, "TEXT", 0, "JSON {page,bbox,xpath,line}", None), ("method", S, "TEXT NOT NULL", 1, "Cách trích", ["parser","layout_llm","vision_llm","manual","inferred","measured"]),
 ("tier", S, "TEXT NOT NULL", 1, "", ["gold","silver","bronze"]), ("confidence", N, "REAL NOT NULL", 1, "0–1", None),
 ("status", S, "TEXT NOT NULL", 1, "", ["normalized","reviewed","verified","rejected","superseded","conflict"]), ("confirmed_by", S, "TEXT", 0, "policy|<user>", None),
 ("confirmed_at", DT, "TEXT", 0, "", None), ("supersedes", S, "TEXT REFERENCES fact(id)", 0, "Fact bị thay", None), ("layer", S, "TEXT NOT NULL DEFAULT 'C'", 1, "Lớp lưu trữ", ["A","B","C"])],
 indexes=("(subject, predicate, status)", "(source_id)", "(status)"), layer="L-A/L-B/L-C")
entity("Passport", "passport", "Hộ chiếu chip/board/ISA: tập fact có phiên bản", [
 ("id", S, "TEXT PRIMARY KEY", 1, "ns.part@semver, ví dụ st.stm32f411ce@1.2.0", None), ("kind", S, "TEXT NOT NULL", 1, "", ["chip","board","isa","part"]),
 ("header", O, "TEXT NOT NULL", 1, "JSON/YAML: tên, họ, lõi, gói, nguồn gốc", None), ("created_at", DT, "TEXT NOT NULL", 1, "", None), ("badges", A, "TEXT", 0, "JSON: verified_on_board, bench", None), ("pinned_by", A, "TEXT", 0, "Dự án ghim", None)])
entity("PassportFact", "passport_fact", "Liên kết hộ chiếu ↔ fact", [("passport_id", S, "TEXT NOT NULL REFERENCES passport(id)", 1, "", None), ("fact_id", S, "TEXT NOT NULL REFERENCES fact(id)", 1, "", None)], pk="(passport_id, fact_id)")
entity("AcquisitionRequest", "acq_request", "Yêu cầu nhận tri thức và máy trạng thái", [
 ("id", S, "TEXT PRIMARY KEY", 1, "acq_<hex>", None), ("need", S, "TEXT NOT NULL", 1, "Mô tả nhu cầu", None), ("subject", S, "TEXT", 0, "IRI thiếu", None), ("part", S, "TEXT", 0, "", None), ("peripheral", S, "TEXT", 0, "", None),
 ("state", S, "TEXT NOT NULL", 1, "", ["REQUESTED","CANDIDATES","CONFIRMED","EXTRACTED","NORMALIZED","REVIEWED","VERIFIED","REJECTED"]), ("candidates", A, "TEXT", 0, "JSON Candidate[]", None), ("decisions", A, "TEXT", 0, "JSON decision ids", None),
 ("created_at", DT, "TEXT NOT NULL", 1, "", None), ("updated_at", DT, "TEXT", 0, "", None)], indexes=("(state)",), since="M1")
entity("CodeUnit", "code_unit", "Đơn vị mã (tệp/hàm) và liên kết fact", [
 ("id", S, "TEXT PRIMARY KEY", 1, "cu_<hex>", None), ("path", S, "TEXT NOT NULL", 1, "", None), ("symbol", S, "TEXT", 0, "Hàm/biến", None), ("hash", S, "TEXT NOT NULL", 1, "Băm nội dung", None),
 ("cites", A, "TEXT", 0, "JSON fact ids", None), ("uses", A, "TEXT", 0, "JSON subject IRIs", None), ("module_id", S, "TEXT REFERENCES module(id)", 0, "", None), ("stale", B, "INTEGER DEFAULT 0", 0, "Fact đổi", None)], indexes=("(path)", "(module_id)"))
entity("Feature", "feature", "Tính năng và bằng chứng", [
 ("id", S, "TEXT PRIMARY KEY", 1, "F-nn", None), ("title", S, "TEXT NOT NULL", 1, "", None), ("status", S, "TEXT NOT NULL", 1, "", ["failing","passing","blocked"]), ("evidence", A, "TEXT", 0, "JSON refs (log hash, measurement id)", None),
 ("verified", S, "TEXT", 0, "", ["auto","human",None]), ("run_id", S, "TEXT", 0, "Run đang xử lý", None), ("requirement_ids", A, "TEXT", 0, "JSON", None), ("updated_at", DT, "TEXT", 0, "", None)])
entity("ToolReport", "tool_report", "Kết quả một cổng công cụ", [
 ("id", S, "TEXT PRIMARY KEY", 1, "tr_<hex>", None), ("tool", S, "TEXT NOT NULL", 1, "", ["build","size","static","test","flash","sim","serial","probe","measure","bench","render","install"]), ("passed", B, "INTEGER NOT NULL", 1, "", None),
 ("log_ref", S, "TEXT", 0, "Đường dẫn/băm log", None), ("metrics", O, "TEXT", 0, "JSON (text/data/bss, thời gian…)", None), ("artifacts", A, "TEXT", 0, "JSON đường dẫn", None), ("duration_ms", I, "INTEGER", 0, "", None),
 ("started_by", S, "TEXT", 0, "run/cap", None), ("at", DT, "TEXT NOT NULL", 1, "", None)], indexes=("(tool, at)",))
entity("DebugSession", "debug_session", "Phiên gỡ lỗi có chứng cứ", [
 ("id", S, "TEXT PRIMARY KEY", 1, "ds_<hex>", None), ("log_ref", S, "TEXT", 0, "", None), ("range_start", I, "INTEGER", 0, "Dòng", None), ("range_end", I, "INTEGER", 0, "", None), ("evidence", A, "TEXT", 0, "JSON EvidencePack[]", None),
 ("hypotheses", A, "TEXT", 0, "JSON", None), ("outcome", S, "TEXT", 0, "", ["confirmed","refuted","open"]), ("fact_ids", A, "TEXT", 0, "", None), ("code_ids", A, "TEXT", 0, "", None), ("at", DT, "TEXT NOT NULL", 1, "", None)], since="M3")
entity("Measurement", "measurement", "Số đo làm bằng chứng", [
 ("id", S, "TEXT PRIMARY KEY", 1, "m_<hex>", None), ("kind", S, "TEXT NOT NULL", 1, "", ["serial_expect","probe_reg","logic","current","voltage","frequency","camera","custom"]), ("target", S, "TEXT", 0, "board id", None),
 ("value", O, "TEXT", 0, "JSON", None), ("unit", S, "TEXT", 0, "", None), ("file_ref", S, "TEXT", 0, "CSV/log", None), ("hash", S, "TEXT", 0, "", None), ("at", DT, "TEXT NOT NULL", 1, "", None)], since="M2")
entity("Permission", "permission", "Quyền theo phiên cho thao tác R3/R4", [
 ("id", S, "TEXT PRIMARY KEY", 1, "", None), ("session_id", S, "TEXT NOT NULL", 1, "", None), ("op", S, "TEXT NOT NULL", 1, "", ["flash","erase_all","fuse","write_mem","install","actuator","publish_public","delete_project","upload_sensitive"]),
 ("target", S, "TEXT", 0, "", None), ("granted_by", S, "TEXT NOT NULL", 1, "", None), ("granted_at", DT, "TEXT NOT NULL", 1, "", None), ("expires_at", DT, "TEXT", 0, "", None)], indexes=("(session_id, op)",), since="M1")
entity("DecisionLog", "decision_log", "Quyết định ở cổng (POL-17)", [
 ("id", S, "TEXT PRIMARY KEY", 1, "d_<hex>", None), ("gate", S, "TEXT", 0, "", ["G-SRC","G-FACT","G1","G3","G-OPS","G4","G5","*"]), ("action_cap", S, "TEXT NOT NULL", 1, "id năng lực", None), ("risk", S, "TEXT NOT NULL", 1, "", ["R0","R1","R2","R3","R4"]),
 ("autonomy_level", S, "TEXT NOT NULL", 1, "Mức hiệu lực", ["A0","A1","A2","A3","A4"]), ("decision", S, "TEXT NOT NULL", 1, "", ["APPROVE","ASK","REJECT"]), ("by", S, "TEXT NOT NULL", 1, "", ["policy","human"]), ("rule", S, "TEXT", 0, "Mã quy tắc", None),
 ("reason", S, "TEXT", 0, "", None), ("evidence", A, "TEXT", 0, "JSON", None), ("features", O, "TEXT", 0, "JSON đặc trưng", None), ("human_answer", S, "TEXT", 0, "Nếu ASK → người trả lời", None), ("undone_at", DT, "TEXT", 0, "", None), ("at", DT, "TEXT NOT NULL", 1, "", None)],
 indexes=("(gate, decision, by)", "(at)"), since="M1")
entity("CapabilityRun", "capability_run", "Một lời gọi năng lực qua Router", [
 ("id", S, "TEXT PRIMARY KEY", 1, "cr_<hex>", None), ("run_id", S, "TEXT", 0, "Chuỗi cha", None), ("cap", S, "TEXT NOT NULL", 1, "id năng lực", None), ("args_hash", S, "TEXT NOT NULL", 1, "", None), ("actor", S, "TEXT NOT NULL", 1, "", ["human","orchestrator","mcp","cli","policy"]),
 ("decision_id", S, "TEXT REFERENCES decision_log(id)", 0, "", None), ("status", S, "TEXT NOT NULL", 1, "", ["pending","running","done","failed","cancelled","undone"]), ("started_at", DT, "TEXT NOT NULL", 1, "", None), ("finished_at", DT, "TEXT", 0, "", None),
 ("result_ref", S, "TEXT", 0, "Đường dẫn/băm kết quả", None), ("undo_ref", S, "TEXT", 0, "", None), ("error", O, "TEXT", 0, "JSON {code, message}", None), ("cost_usd", N, "REAL", 0, "", None)], indexes=("(run_id)", "(cap, started_at)"), since="M1")
entity("Intent", "intent", "Ý định đã hiểu từ lệnh (DPS-09)", [
 ("id", S, "TEXT PRIMARY KEY", 1, "it_<hex>", None), ("text", S, "TEXT NOT NULL", 1, "Lệnh gốc", None), ("intent", S, "TEXT NOT NULL", 1, "", None), ("slots", O, "TEXT", 0, "JSON", None), ("is_big", B, "INTEGER", 0, "", None), ("confidence", N, "REAL", 0, "", None),
 ("lang", S, "TEXT", 0, "", ["vi","en"]), ("grounded", O, "TEXT", 0, "JSON Grounded", None), ("defaults_applied", A, "TEXT", 0, "JSON", None), ("question", O, "TEXT", 0, "JSON Question", None), ("session_id", S, "TEXT", 0, "", None), ("at", DT, "TEXT NOT NULL", 1, "", None)], since="M1")
entity("Run", "run", "Chuỗi năng lực đang/đã chạy", [
 ("id", S, "TEXT PRIMARY KEY", 1, "r_<hex>", None), ("intent_id", S, "TEXT REFERENCES intent(id)", 0, "", None), ("graph", O, "TEXT NOT NULL", 1, "JSON ChainNode[]", None), ("state", S, "TEXT NOT NULL", 1, "", ["planned","running","asked","done","failed","cancelled"]),
 ("working", O, "TEXT", 0, "JSON WorkingMemory (MEM-11)", None), ("report", O, "TEXT", 0, "JSON Report", None), ("cost_usd", N, "REAL", 0, "", None), ("started_at", DT, "TEXT", 0, "", None), ("finished_at", DT, "TEXT", 0, "", None)], indexes=("(state)",), since="M1")
entity("Requirement", "requirement", "Yêu cầu do req.* sinh (K10)", [
 ("id", S, "TEXT PRIMARY KEY", 1, "UR-xx-nn | FR-xx-nn | NFR-nn", None), ("kind", S, "TEXT NOT NULL", 1, "", ["FR","NFR","HW","SAFETY","RT","CR"]), ("text", S, "TEXT NOT NULL", 1, "Câu đo được", None), ("priority", S, "TEXT", 0, "", ["M","S","C","W"]),
 ("acceptance", A, "TEXT", 0, "JSON Given-When-Then[]", None), ("trace", A, "TEXT", 0, "JSON ids (module, code_unit, tc, doc)", None), ("source", S, "TEXT", 0, "lệnh/README/tài liệu + locator", None), ("feasibility", O, "TEXT", 0, "JSON {ok, facts[], note}", None),
 ("status", S, "TEXT NOT NULL DEFAULT 'generated'", 1, "", ["generated","reviewed","accepted","rejected","stale"]), ("updated_at", DT, "TEXT", 0, "", None)], since="M1")
entity("Module", "module", "Module firmware (ModuleGraph)", [
 ("id", S, "TEXT PRIMARY KEY", 1, "mod_<slug>", None), ("name", S, "TEXT NOT NULL", 1, "", None), ("responsibility", S, "TEXT", 0, "", None), ("interfaces", A, "TEXT", 0, "JSON InterfaceSpec[]", None), ("depends", A, "TEXT", 0, "JSON module ids", None),
 ("arch_style", S, "TEXT", 0, "", ["super_loop","event_driven","rtos","layered"]), ("budget", O, "TEXT", 0, "JSON {ram, flash, stack, wcet_us, period_ms}", None), ("fsm", O, "TEXT", 0, "JSON FSM", None), ("status", S, "TEXT", 0, "", ["proposed","accepted","implemented","stale"])], since="M2")
entity("HwMap", "hw_map", "Gán module ↔ tài nguyên phần cứng", [("module_id", S, "TEXT NOT NULL REFERENCES module(id)", 1, "", None), ("resource", S, "TEXT NOT NULL", 1, "IRI chip:…/periph:… | pin:… | irq:… | dma:…", None), ("role", S, "TEXT", 0, "master|slave|input|output|shared", None), ("fact_ids", A, "TEXT", 0, "JSON", None)], pk="(module_id, resource)", indexes=("(resource)",), since="M2")
entity("ADR", "adr", "Architecture Decision Record", [
 ("id", S, "TEXT PRIMARY KEY", 1, "ADR-nn", None), ("title", S, "TEXT NOT NULL", 1, "", None), ("context", S, "TEXT", 0, "", None), ("options", A, "TEXT", 0, "JSON {name, pros, cons}[]", None), ("decision", S, "TEXT", 0, "", None), ("consequences", S, "TEXT", 0, "", None),
 ("citations", A, "TEXT", 0, "JSON fact/source ids", None), ("status", S, "TEXT", 0, "", ["proposed","accepted","superseded"]), ("at", DT, "TEXT NOT NULL", 1, "", None)], since="M2")
entity("Diagram", "diagram", "Lược đồ dạng văn bản", [
 ("id", S, "TEXT PRIMARY KEY", 1, "dg_<hex>", None), ("kind", S, "TEXT NOT NULL", 1, "", ["block","pinmap","architecture","sequence","state","flow","timing","memory_map","kg_view","gantt","from_image","custom"]),
 ("lang", S, "TEXT NOT NULL", 1, "", ["mermaid","plantuml","dot","d2","wavedrom","svg"]), ("src", S, "TEXT NOT NULL", 1, "Mã lược đồ", None), ("source_ref", S, "TEXT", 0, "Mô hình gốc (module_id, fsm, plan…)", None), ("rendered_ref", S, "TEXT", 0, "svg/png", None),
 ("lint", A, "TEXT", 0, "JSON Issue[]", None), ("node_ids", A, "TEXT", 0, "JSON để sync", None), ("synced_with", S, "TEXT", 0, "", None), ("stale", B, "INTEGER DEFAULT 0", 0, "", None), ("path", S, "TEXT", 0, ".eide/diagrams/…", None), ("at", DT, "TEXT NOT NULL", 1, "", None)], since="M1")
entity("DocArtifact", "doc_artifact", "Tài liệu sinh ra", [
 ("id", S, "TEXT PRIMARY KEY", 1, "doc_<hex>", None), ("type", S, "TEXT NOT NULL", 1, "", ["URD","SRS","SAD","SDD","STP","BPD","bringup","test_report","api_ref","datasheet_summary","changelog","slides","section","custom"]), ("template", S, "TEXT", 0, "", None),
 ("path", S, "TEXT NOT NULL", 1, ".eide/docs/…", None), ("sections", A, "TEXT", 0, "JSON {heading, hash, citations[]}", None), ("citations", A, "TEXT", 0, "JSON", None), ("style_issues", A, "TEXT", 0, "JSON", None), ("stale_sections", A, "TEXT", 0, "JSON", None), ("lang", S, "TEXT", 0, "", ["vi","en"]), ("at", DT, "TEXT NOT NULL", 1, "", None)], since="M2")
entity("Discovery", "discovery", "Kết quả dò board/probe/kết nối", [
 ("id", S, "TEXT PRIMARY KEY", 1, "dv_<hex>", None), ("ports", A, "TEXT", 0, "JSON Port[]", None), ("probes", A, "TEXT", 0, "JSON Probe[]", None), ("chip_id", O, "TEXT", 0, "JSON ChipIdentity", None), ("link_speed", O, "TEXT", 0, "JSON LinkSpeed", None),
 ("firmware", O, "TEXT", 0, "JSON {banner, version}", None), ("power", O, "TEXT", 0, "JSON {v, i}", None), ("network", A, "TEXT", 0, "JSON", None), ("target_config", O, "TEXT", 0, "JSON target.yaml", None), ("at", DT, "TEXT NOT NULL", 1, "", None)], since="M2")
entity("ErrorLedgerEntry", "error_ledger", "Sổ lỗi (MEM-11 §6)", [
 ("id", S, "TEXT PRIMARY KEY", 1, "e_<hex>", None), ("role", S, "TEXT", 0, "", None), ("kind", S, "TEXT NOT NULL", 1, "", ["hallucination","refusal","tool_fail","human_reject","undo","policy_reject"]), ("task_ref", S, "TEXT", 0, "", None), ("chip", S, "TEXT", 0, "", None),
 ("evidence", S, "TEXT", 0, "", None), ("negative_prompt", S, "TEXT", 0, "≤ 40 token", None), ("ttl_until", DT, "TEXT", 0, "", None), ("at", DT, "TEXT NOT NULL", 1, "", None)], indexes=("(role, chip, at)",), since="M1")
entity("Preference", "preference", "Tùy chọn người dùng (D8)", [("key", S, "TEXT NOT NULL", 1, "", None), ("scope", S, "TEXT NOT NULL", 1, "", ["user","project"]), ("value", O, "TEXT NOT NULL", 1, "JSON", None), ("learned_from", S, "TEXT", 0, "decision/turn id", None), ("ttl_days", I, "INTEGER", 0, "", None), ("at", DT, "TEXT NOT NULL", 1, "", None)], pk="(key, scope)", since="M1")
entity("Session", "session", "Phiên làm việc (session.sqlite, không commit)", [
 ("id", S, "TEXT PRIMARY KEY", 1, "s_<hex>", None), ("project", S, "TEXT NOT NULL", 1, "", None), ("opened_at", DT, "TEXT NOT NULL", 1, "", None), ("closed_at", DT, "TEXT", 0, "", None), ("autonomy_effective", S, "TEXT", 0, "", ["A0","A1","A2","A3","A4"]), ("stopped", B, "INTEGER DEFAULT 0", 0, "", None),
 ("turns", A, "TEXT", 0, "JSON Turn[] / TurnSummary", None), ("undo_items", A, "TEXT", 0, "JSON UndoItem[]", None), ("summary", O, "TEXT", 0, "JSON khi đóng", None)], since="M1")
entity("RagChunk", "rag_chunk", "Đoạn văn bản chỉ mục RAG (index/index.sqlite, không commit)", [
 ("id", S, "TEXT PRIMARY KEY", 1, "rc_<hex>", None), ("source_id", S, "TEXT NOT NULL", 1, "", None), ("locator", O, "TEXT", 0, "JSON {page,bbox,line}", None), ("text", S, "TEXT NOT NULL", 1, "≤ 800 token", None), ("embedding", A, "BLOB", 0, "float32[] qua Gateway", None),
 ("keywords", S, "TEXT", 0, "FTS5", None), ("graph_nodes", A, "TEXT", 0, "JSON subject IRIs xuất hiện", None), ("model", S, "TEXT", 0, "Mô hình embedding", None)], indexes=("(source_id)",), layer="L-E", since="M1")
entity("Capability", "capability", "Khai báo năng lực (nạp từ YAML, bảng chỉ để truy vấn)", [
 ("code", S, "TEXT PRIMARY KEY", 1, "EXTRACT-05", None), ("id", S, "TEXT UNIQUE NOT NULL", 1, "extract.bom", None), ("ns", S, "TEXT NOT NULL", 1, "", None), ("name", S, "TEXT NOT NULL", 1, "", None), ("desc", S, "TEXT", 0, "", None),
 ("input_schema", O, "TEXT", 0, "JSON Schema", None), ("output_schema", O, "TEXT", 0, "JSON Schema", None), ("risk", S, "TEXT NOT NULL", 1, "", ["R0","R1","R2","R3","R4"]), ("tier", S, "TEXT NOT NULL", 1, "", ["T1","T1*","T2","T3"]),
 ("grounding", A, "TEXT", 0, "JSON", None), ("ask_when", A, "TEXT", 0, "JSON", None), ("undo_kind", S, "TEXT", 0, "", ["supersede_facts","git_revert","reflash_known_good","delete_created_files","restore_config","none"]), ("milestone", S, "TEXT", 0, "", None), ("impl", S, "TEXT", 0, "module:function", None), ("ui", O, "TEXT", 0, "JSON {screen, action}", None)], since="M1")

YAML_FILES = [
 ("constraints.yaml", "Ràng buộc dự án (K6)", "chip, board, isa, toolchain, ecosystem (bare|hal|esp-idf|zephyr), reserved_pins[], bus_limits{}, memory_budget{flash_pct, ram_pct}, sensitive, conventions{}", "M0"),
 ("autonomy.yaml", "Mức tự chủ, ngưỡng, danh sách trắng (POL-17 §4)", "autonomy, boards{}, action_types{}, thresholds{}, trusted_sources[], trusted_packages[], allowed_licenses[], undo_window{}, ask_timeout_s, defaults{}, escalation{}, sensitive", "M1"),
 ("preferences.yaml", "Tùy chọn (M6)", "map key → {value, scope, learned_from, ttl_days}", "M1"),
 ("models.yaml", "Mô hình theo vai trò (SDD §6)", "roles{<role>: {candidates[], temperature, max_output, min_context, inputs[], rule, budget{}}}, policy{daily_budget_usd, offline_mode, fallback_on[]}, embedding{model}", "M0"),
 ("roles.yaml", "Công cụ và ngân sách vai trò", "<role>: {skills_max, tools[], budget{input, output}, prompt}", "M0"),
 ("target.yaml", "Cấu hình target sau discover.auto_setup", "board, isa, adapter{kind, cfg, probe_serial}, port{dev, baud}, speeds{swd_khz, jtag_khz}, lab, last_discovery", "M2"),
 ("capabilities/*.yaml", "Khai báo năng lực (SDD §4.0)", "danh sách Capability (13 trường + input/output schema + undo + ui + impl + features_provided[])", "M1"),
 ("isa/*.yaml", "ISA profile (TGT-19)", "id, abi{}, interrupts{}, toolchain{}, debug{}, sim{}, skills[], probes[], id_read{}", "M0"),
 ("policy/rules.yaml", "Quy tắc chính sách (POL-17)", "rules[] {id, gate, when, decision, reason, priority, features[]}", "M1"),
 ("manifest.json (.hkp)", "Gói registry (PKG-22)", "id, version, kind, license, passports[], skills[], bench[], badges[], signature", "M4"),
]
MIGRATIONS = [
 ("0001_m0_base", "M0", "source, fact, passport, passport_fact, code_unit, feature, tool_report; PRAGMA journal_mode=WAL; user_version=1"),
 ("0002_m1_policy_runtime", "M1", "acq_request, permission, decision_log, capability_run, intent, run, error_ledger, preference, capability, requirement, diagram; cột fact.layer; chỉ mục mới; user_version=2"),
 ("0003_m1_index", "M1", "index/index.sqlite riêng: rag_chunk + FTS5 (rag_chunk_fts); không migration trong store chính"),
 ("0004_m2_engineering_hw", "M2", "module, hw_map, adr, doc_artifact, discovery, measurement; code_unit.module_id; user_version=3"),
 ("0005_m3_debug", "M3", "debug_session; user_version=4"),
 ("0006_rename_eide", "M1", "Đổi thư mục .hkw → .eide (giữ symlink đọc); không đổi schema"),
]
