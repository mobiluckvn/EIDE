const { Paragraph, TextRun, AlignmentType } = require('docx');
const fs = require('fs');
const CAPS = JSON.parse(fs.readFileSync(__dirname + '/caps.json', 'utf8'));
const NS_ORDER = [];
for (const c of CAPS) if (!NS_ORDER.includes(c.ns)) NS_ORDER.push(c.ns);
const NS_VI = {
  project: 'Dự án', memory: 'Bộ nhớ và ngữ cảnh', archive: 'Khai phá lưu trữ (zip/rar/7z/tar)', search: 'Tìm kiếm đa nguồn',
  extract: 'Trích xuất (PDF, ảnh, BOM, SVD…)', passport: 'Hộ chiếu chip/board', kg: 'Đồ thị tri thức', board: 'Mạch và ràng buộc',
  env: 'Môi trường và công cụ', plan: 'Lập kế hoạch', code: 'Sinh mã, tích hợp, merge', sim: 'Mô phỏng', target: 'Board và probe',
  debug: 'Gỡ lỗi', measure: 'Đo đạc', bench: 'Benchmark', registry: 'Registry và gói', report: 'Báo cáo', policy: 'Chính sách tự chủ',
  chat: 'Hiểu lệnh và điều phối', req: 'Phân tích yêu cầu', arch: 'Thiết kế kiến trúc', diagram: 'Vẽ lược đồ (Mermaid, PlantUML, DOT, D2, WaveDrom, SVG)',
  doc: 'Viết tài liệu theo chuẩn EAA/EIDE', view: 'Bản đồ tri thức và RAG', discover: 'Dò board, probe, kết nối', tool: 'Tự tạo công cụ (self-tooling) — năng lực gốc',
};
const DOCSET = 'Nền: EIDE-PDA-00 · URD-01 · SRS-02 · SAD-03 · SDD-04 · STP-05 · BPD-06 · KAD-07 · APD-08 · DPS-09. Bổ sung v1.2: CXD-10 · MEM-11 · CDS-12 (6 tập) · UXD-13 · DDD-14 · API-15 · PRS-16 · POL-17 · TGT-19 · SIM-20 · BEN-21 · PKG-22 · GPI-23 · SEC-25 · DEP-26 · CON-28. Excel: Danh mục năng lực v1.2 · Use case chi tiết v1.2 (UCD-24) · Kế hoạch backlog (PLN-27) · Rà soát đủ điều kiện phát triển';
const H12 = 'Bổ sung nhóm năng lực gốc tool.* (tác tử tự viết công cụ Python, kiểm thử trong sandbox, đăng ký thành năng lực tạm user.* và thăng cấp qua Pack) — 238 năng lực / 27 nhóm; phát hành 19 tài liệu bổ sung mức 3 (CXD, MEM, CDS ×6, UXD, DDD, API, PRS, POL, TGT, SIM, BEN, PKG, GPI, SEC, DEP, CON, PLN); cổng G-TOOL trong chính sách; 11 use case mới (nhóm I/J/K), sơ đồ tuần tự và ánh xạ bước ↔ năng lực; đồng bộ toàn bộ hồ sơ với caps.json/cds.json (tài liệu = mã)';
const H11 = 'Đổi mã HKW→EIDE; tích hợp Danh mục năng lực v1.1 (228 năng lực / 26 nhóm) làm xương sống yêu cầu–thiết kế; áp dụng EIDE-APD-08 (bản đầu: một PC có Internet đầy đủ, lệnh ngôn ngữ tự nhiên là giao diện chính, mức tự chủ A3 mặc định, "làm rồi báo cáo"); bỏ chế độ cục bộ/không mạng khỏi mặc định; bổ sung năng lực phân tích yêu cầu, thiết kế kiến trúc, vẽ lược đồ, viết tài liệu, bản đồ tri thức/RAG, dò board và kết nối';
function meta(code, short, title, subtitle, extraAttrs, history10, extra11) {
  return {
    kicker: 'HỌC VIỆN CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG · ĐỀ ÁN TỐT NGHIỆP THẠC SĨ KỸ THUẬT ĐIỆN TỬ · EIDE v1.2', footer: 'EIDE — Bộ hồ sơ thiết kế v1.2',
    code, short, version: '1.2', title, subtitle,
    attrs: [
      ['Mã tài liệu', `${code} (trước đây ${code.replace('EIDE', 'HKW')})`], ['Phiên bản', '1.2 — đồng bộ với 19 tài liệu bổ sung và năng lực gốc tool.*'], ['Ngày lập', '05/09/2026'],
      ['Người lập', 'Vũ Trí Công — học viên cao học (hỗ trợ soạn thảo: Claude)'],
      ['Người hướng dẫn', 'TS. Nguyễn Trung Hiếu'],
      ['Khuôn khổ', 'Đề án tốt nghiệp Thạc sĩ ngành Kỹ thuật Điện tử — Học viện Công nghệ Bưu chính Viễn thông (PTIT)'],
      ['Sản phẩm', 'EIDE (Embedded IDE) — trước đây Hardware Knowledge Workbench (HKW); Knowledge Plane bằng Python; kho mã core dùng chung với EAA-U; bản đầu chạy trên một PC có Internet'],
      ...extraAttrs,
      ['Bộ hồ sơ', DOCSET],
    ],
    history: [
      ...(history10 || [['1.0', '05/09/2026', 'Vũ Trí Công', 'Phát hành lần đầu (mã HKW)']]),
      ['1.1', '05/09/2026', 'Vũ Trí Công', H11 + (extra11 ? '. ' + extra11 : '')],
      ['1.2', '05/09/2026', 'Vũ Trí Công', H12],
    ],
  };
}
const REFS = [
  'V. T. Công, "EIDE-PDA-00 — Phân tích thiết kế sản phẩm EIDE v1.1 (trước đây HKW-PDA-00)," 05/09/2026.',
  'V. T. Công, "Embedded AIDD Agent (EAA) — bộ hồ sơ v1.0 và mã nguồn," GitHub mobiluckvn/Agent, 2026. [Online]. Available: https://github.com/mobiluckvn/Agent',
  'V. T. Công, "Phân tích thiết kế Agent — Kiến trúc agent đa mô hình cho lập trình nhúng (EAA-U) v0.1," 05/09/2026.',
  'ISO/IEC/IEEE 29148:2018, "Systems and software engineering — Requirements engineering," 2018.',
  'ISO/IEC/IEEE 42010:2022, "Software, systems and enterprise — Architecture description," 2022.',
  'IEEE Std 1016-2009, "IEEE Standard for Information Technology — Systems Design — Software Design Descriptions," 2009.',
  'ISO/IEC/IEEE 29119-3:2021, "Software testing — Part 3: Test documentation," 2021.',
  'Arm, "CMSIS-SVD: System View Description," Open-CMSIS-Pack. [Online]. Available: https://open-cmsis-pack.github.io/svd-spec/',
  'Microchip Technology, "Microchip Packs Repository (Device Family Packs, ATDF)." [Online]. Available: https://packs.download.microchip.com/',
  'Zephyr Project, "Devicetree bindings," Zephyr Documentation. [Online]. Available: https://docs.zephyrproject.org/latest/build/dts/bindings.html',
  'IBM, "Docling — document conversion toolkit," GitHub. [Online]. Available: https://github.com/docling-project/docling',
  'KiCad, "kicad-cli — command line interface," KiCad 8 Documentation. [Online]. Available: https://docs.kicad.org/8.0/en/cli/cli.html',
  'Anthropic, "Model Context Protocol — specification," 2025–2026. [Online]. Available: https://modelcontextprotocol.io/specification',
  'Adancurusul, "embedded-debugger-mcp," GitHub, 2026. [Online]. Available: https://github.com/adancurusul/embedded-debugger-mcp',
  'Espressif Systems, "ESP-IDF Tools Local MCP Server," Developer Portal, Apr. 2026. [Online]. Available: https://developer.espressif.com/blog/2026/04/esp-idf-tools-mcp-server/',
  'Nordic Semiconductor, "AI-assisted development the Nordic way," Nordic DevZone Blog, Jun. 2026. [Online]. Available: https://devzone.nordicsemi.com/nordic/nordic-blog/b/blog/posts/bringing-ai-assisted-development-to-nrf-connect-sdk-and-nrf-cloud',
  '"Skilled AI Agents for Embedded and IoT Systems Development," arXiv:2603.19583, Mar. 2026. [Online]. Available: https://arxiv.org/html/2603.19583',
  'Anthropic, "Effective harnesses for long-running agents," Anthropic Engineering. [Online]. Available: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents',
  'Logic, "Structured outputs: JSON Schema, OpenAI, Claude, Gemini," 2026. [Online]. Available: https://logic.inc/resources/structured-outputs-guide',
  'Antmicro, "Renode — open source simulation framework." [Online]. Available: https://renode.io/',
  'Sigstore, "Sigstore — signing and provenance for software artifacts." [Online]. Available: https://www.sigstore.dev/',
  'Embedder, "Embedder | Enterprise AI Platform for Embedded Software," 2026. [Online]. Available: https://embedder.com/',
  'sigrok, "sigrok-cli and libsigrokdecode." [Online]. Available: https://sigrok.org/',
  'JSON Schema, "JSON Schema Specification 2020-12." [Online]. Available: https://json-schema.org/specification',
  // v1.1
  'V. T. Công, "EIDE — Danh mục năng lực đầy đủ v1.1 (EIDE_Danh_muc_Nang_luc.xlsx): 228 năng lực, 26 nhóm," 05/09/2026.',
  'V. T. Công, "EIDE-APD-08 — Chính sách tự chủ của tác tử và cổng người thích ứng v1.1," 05/09/2026.',
  'V. T. Công, "EIDE-DPS-09 — Chính sách hội thoại và suy luận ý định v1.0," 05/09/2026.',
  'V. T. Công, "EIDE — Use case chi tiết (EIDE_Use_Case_Chi_Tiet.xlsx): 45 use case, 3 mức tự chủ, kịch bản hội thoại," 05/09/2026.',
  'Anthropic, "Building Effective AI Agents," Anthropic Engineering. [Online]. Available: https://www.anthropic.com/engineering/building-effective-agents',
  'R. Parasuraman, T. B. Sheridan, and C. D. Wickens, "A model for types and levels of human interaction with automation," IEEE Trans. Syst., Man, Cybern. A, vol. 30, no. 3, pp. 286–297, 2000.',
  'Mermaid, "Mermaid — diagramming and charting tool." [Online]. Available: https://mermaid.js.org/',
  'PlantUML, "PlantUML language reference guide." [Online]. Available: https://plantuml.com/',
  'Graphviz, "DOT language." [Online]. Available: https://graphviz.org/doc/info/lang.html',
  'Terrastruct, "D2 — declarative diagramming language." [Online]. Available: https://d2lang.com/',
  'WaveDrom, "WaveDrom — digital timing diagram everywhere." [Online]. Available: https://wavedrom.com/',
  'S. Brown, "The C4 model for visualising software architecture." [Online]. Available: https://c4model.com/',
  'D. Edge et al., "From Local to Global: A Graph RAG Approach to Query-Focused Summarization," arXiv:2404.16130, 2024.',
  'D. Nardi et al., "Architecture Decision Records (ADR)," adr.github.io. [Online]. Available: https://adr.github.io/',
  'libusb / pyserial / probe-rs, "Device enumeration and probe discovery APIs." [Online]. Available: https://probe.rs/',
  // v1.2
  'Anthropic, "Effective context engineering for AI agents," Anthropic Engineering, 2025. [Online]. Available: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents',
  'Anthropic, "Prompt caching," Claude Developer Platform documentation. [Online]. Available: https://docs.claude.com/en/docs/build-with-claude/prompt-caching',
  'Google, "Context caching," Gemini API documentation. [Online]. Available: https://ai.google.dev/gemini-api/docs/caching',
  'OpenAI, "Prompt caching," OpenAI Platform documentation. [Online]. Available: https://platform.openai.com/docs/guides/prompt-caching',
  'T. R. Sumers, S. Yao, K. Narasimhan, and T. L. Griffiths, "Cognitive Architectures for Language Agents (CoALA)," arXiv:2309.02427, 2023.',
  'C. Packer et al., "MemGPT: Towards LLMs as Operating Systems," arXiv:2310.08560, 2023.',
  'J. S. Park et al., "Generative Agents: Interactive Simulacra of Human Behavior," in Proc. UIST, 2023.',
  'N. F. Liu et al., "Lost in the Middle: How Language Models Use Long Contexts," Trans. ACL, vol. 12, 2024.',
  'P. Lewis et al., "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks," in Proc. NeurIPS, 2020.',
  'OpenRPC, "OpenRPC Specification 1.3." [Online]. Available: https://spec.open-rpc.org/',
  'JSON-RPC Working Group, "JSON-RPC 2.0 Specification," 2010. [Online]. Available: https://www.jsonrpc.org/specification',
  'OWASP, "OWASP Top 10 for Large Language Model Applications," 2025. [Online]. Available: https://owasp.org/www-project-top-10-for-large-language-model-applications/',
  'buserror, "simavr — a lean AVR simulator," GitHub. [Online]. Available: https://github.com/buserror/simavr',
  'QEMU Project, "QEMU system emulation targets (Arm, RISC-V, Xtensa)." [Online]. Available: https://www.qemu.org/docs/master/system/targets.html',
  'J. Nielsen, "10 Usability Heuristics for User Interface Design," Nielsen Norman Group, 1994 (cập nhật 2024).',
  'Apple, "Human Interface Guidelines — macOS," Apple Developer. [Online]. Available: https://developer.apple.com/design/human-interface-guidelines/',
  'W3C, "Web Content Accessibility Guidelines (WCAG) 2.2," W3C Recommendation, 2023.',
  'V. T. Công, "EIDE-CXD-10 — Kiến trúc ngữ cảnh cho tác tử v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-MEM-11 — Kiến trúc bộ nhớ tác tử v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-CDS-12 — Đặc tả chi tiết năng lực (6 tập) v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-UXD-13 — Đặc tả UI/UX v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-DDD-14 — Từ điển dữ liệu, DDL và di trú v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-API-15 — Đặc tả giao diện lập trình v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-PRS-16 — Prompt, vai trò LLM và skill v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-POL-17 — Quy tắc chính sách tự chủ máy đọc được v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-TGT-19 — ISA profile, toolchain, adapter target và discovery v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-SIM-20 — Thiết kế mô phỏng v1.0," 05/09/2026.',
  'V. T. Công, "EIDE-Rà soát đủ điều kiện phát triển (EIDE_Ra_soat_Du_dieu_kien_Phat_trien.xlsx)," 05/09/2026.',
  'Anthropic, "Claude Code documentation — memory (CLAUDE.md), slash commands, hooks, settings," Claude Docs, 2026. [Online]. Available: https://docs.claude.com/en/docs/claude-code',
];
function refParas(H1) {
  const out = [H1('Tài liệu tham khảo')];
  REFS.forEach((r, i) => out.push(new Paragraph({ children: [new TextRun({ text: `[${i + 1}] ${r}`, font: 'Times New Roman', size: 24 })], alignment: AlignmentType.LEFT, spacing: { line: 276, after: 100 }, indent: { left: 567, hanging: 567 } })));
  return out;
}
const byNs = ns => CAPS.filter(c => c.ns === ns);
const count = (pred) => CAPS.filter(pred).length;
module.exports = { meta, REFS, refParas, CAPS, NS_ORDER, NS_VI, byNs, count, DOCSET, H11, H12 };
// v1.2: tài liệu bổ sung mới (phát hành lần đầu cùng bộ v1.2)
function metaNew(code, short, title, subtitle, extraAttrs, historyNote) {
  const m = meta(code, short, title, subtitle, extraAttrs);
  m.version = '1.0';
  m.attrs[0] = ['Mã tài liệu', code];
  m.attrs[1] = ['Phiên bản', '1.0 — phát hành cùng bộ hồ sơ v1.2 (bổ sung theo Rà soát đủ điều kiện phát triển)'];
  
  m.history = [['1.0', '05/09/2026', 'Vũ Trí Công', historyNote || 'Phát hành lần đầu']];
  return m;
}
module.exports.metaNew = metaNew;
