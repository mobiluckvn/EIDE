const fs = require('fs');
const { P, H1, H2, H3, CAP, SP, T, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas, NS_VI } = require('./eide_common');
const ALL = JSON.parse(fs.readFileSync('cds.json', 'utf8'));
const VOLS = {
  1: ['Kỹ nghệ', ['req', 'arch', 'diagram', 'doc', 'plan'], 'Phân tích yêu cầu, thiết kế kiến trúc, vẽ lược đồ, viết tài liệu, lập kế hoạch'],
  2: ['Tri thức', ['archive', 'search', 'extract', 'passport', 'kg', 'board', 'view'], 'Khai phá lưu trữ, tìm kiếm đa nguồn, trích xuất, hộ chiếu, đồ thị tri thức, mạch, bản đồ tri thức và RAG'],
  3: ['Hiện thực và tự tạo công cụ', ['env', 'code', 'project', 'tool'], 'Môi trường, sinh mã/tích hợp/merge, dự án, và năng lực gốc tool.* (tác tử tự viết công cụ Python và chạy)'],
  4: ['Xác minh', ['discover', 'sim', 'target', 'debug', 'measure', 'bench'], 'Dò board và kết nối, mô phỏng, nạp/quan sát, gỡ lỗi, đo, benchmark'],
  5: ['Quản trị', ['policy', 'registry', 'report'], 'Chính sách tự chủ, registry, báo cáo'],
  6: ['Hội thoại và bộ nhớ', ['chat', 'memory'], 'Tầng hiểu lệnh và bộ nhớ tác tử'],
};
const fmtSchema = s => JSON.stringify(s, null, 1).split('\n');
function capBlock(r) {
  const c = [];
  c.push(H3(`${r.code} · ${r.id} — ${r.desc}`));
  c.push(T([2300, 7000], ['Mục', 'Nội dung'], [
    ['Lớp rủi ro / mức', `${r.risk} / ${r.tier}`], ['Grounding (tiền điều kiện)', r.grounding], ['Hỏi kỹ sư khi', r.ask_when], ['Hoàn tác', r.undo], ['Mốc / trạng thái M0', `${r.milestone} / ${r.m0}`], ['Tham chiếu', r.ref],
    ['Ví dụ gọi', `${r.id} ${r.example}`], ['Test hợp đồng / hành vi', r.tc],
  ]));
  c.push(P('**Tham số vào (JSON Schema):**'));
  c.push(...CODE(fmtSchema(r.input_schema)));
  c.push(P('**Kết quả ra (JSON Schema):**'));
  c.push(...CODE(fmtSchema(r.output_schema)));
  c.push(P('**Các bước thực hiện:**'));
  r.steps.forEach((s, i) => c.push(P(`${i + 1}. ${s}`, { bullet: false })));
  c.push(P('**Lỗi:** ' + (r.errors.length ? r.errors.join('; ') : 'không có lỗi đặc thù ngoài lỗi chung của Router (E1000, E3000, E6000)') + '.'));
  c.push(SP());
  return c;
}
for (const [v, [title, nss, desc]] of Object.entries(VOLS)) {
  const recs = ALL.filter(r => r.volume == v);
  const m = metaNew(`EIDE-CDS-12.${v}`, `Đặc tả năng lực — tập ${v}`, `ĐẶC TẢ CHI TIẾT NĂNG LỰC (CDS) — TẬP ${v}: ${title.toUpperCase()}`,
    `${desc}. ${recs.length} năng lực trong ${nss.length} nhóm; mỗi năng lực có hợp đồng 13 trường, JSON Schema vào/ra, các bước, lỗi, hoàn tác, ví dụ gọi và test`,
    [['Tài liệu trước', 'Danh mục năng lực v1.2 (238), EIDE-SRS-02 §3B, EIDE-SDD-04 §4.0, EIDE-POL-17, EIDE-CXD-10, EIDE-MEM-11, EIDE-PRS-16'], ['Tệp kèm', `capabilities/<ns>.yaml (khai báo nạp vào Capability Registry) cho các nhóm: ${nss.join(', ')}`], ['Dùng khi', 'Hiện thực từng năng lực; sinh test hợp đồng; sinh tool MCP; viết UI gọi năng lực']],
    'Phát hành lần đầu — bổ sung lĩnh vực L03/L11; sinh từ cds_data_*.py + caps.py',
    v == '3' ? [['1.1', '07/09/2026', 'Vũ Trí Công',
      'PROJECT-09 project.preferences: `value` nhận GIÁ TRỊ JSON bất kỳ thay vì chỉ đối tượng, '
      + 'và `learned_from`/`ttl_days` thành tham số ngang hàng đúng như thực thể Preference của '
      + 'DDD-14 §2. Trước đó ví dụ của chính hợp đồng (`"value":"stlink"`) bị Router chặn bằng '
      + 'E1000 vì không qua nổi input_schema của nó (DEV-009).']]
    : v == '2' ? [['1.1', '07/09/2026', 'Vũ Trí Công',
      'KG-07 kg.supersede: ví dụ gọi bổ sung trường bắt buộc `actor` — thiếu nó thì ví dụ không '
      + 'qua nổi input_schema của chính hợp đồng.']]
    : v == '6' ? [['1.1', '07/09/2026', 'Vũ Trí Công',
      'CHAT-04 chat.clarify: mức T2 → T1. T2 nghĩa là "cần người duyệt", nhưng chat.clarify '
      + 'CHÍNH LÀ cơ chế hỏi người: bắt nó xin phép trước khi được phép hỏi là một vòng luẩn '
      + 'quẩn — PolicyGate trả ASK, lời gọi vào hàng đợi với một câu hỏi chưa từng được dựng, '
      + 'và quy tắc D3 của DPS-09 không bao giờ chạy (DEV-020).']]
    : undefined);
  const c = [];
  c.push(H1('1. Cách đọc tập này'));
  c.push(P(`Mỗi năng lực là một mục gồm: bảng hợp đồng (lớp rủi ro, mức tự chủ, grounding, điều kiện hỏi, hoàn tác, mốc, ví dụ gọi, test), JSON Schema tham số vào và kết quả ra theo mẫu số chung (object/string/number/integer/boolean/array/enum; sâu ≤ 3; không anyOf/$ref) [19], các bước thực hiện (thuật toán ở mức lập trình được, có tham chiếu tới tài liệu nền: CXD-10 ngữ cảnh, MEM-11 bộ nhớ, POL-17 chính sách, PRS-16 prompt, SEC-25 sandbox, TGT-19 phần cứng, SIM-20 mô phỏng), và mã lỗi (API-15 §6). Khai báo YAML tương ứng nằm trong \`capabilities/<ns>.yaml\` và là thứ Capability Registry nạp; tài liệu này là bản đọc cho người của cùng dữ liệu. Router luôn thực hiện các bước chung trước khi vào năng lực: kiểm input_schema → grounding → policy.decide → thực thi → ledger → đăng ký hoàn tác (SDD-04 §4.0), nên các bước dưới đây không lặp lại phần chung. Quy ước mức: T1 AI làm trọn; T1* tự làm khi chính sách có bằng chứng; T2 AI làm — người duyệt; T3 người làm.`));
  if (v == '3') {
    c.push(H2('1.1. Vì sao tool.* là năng lực gốc'));
    c.push(P('Nhóm `tool.*` cho phép tác tử **tự viết công cụ bằng Python và chạy** khi chuỗi thiếu năng lực phù hợp: nhận diện nhu cầu (tool.need) → tái dùng nếu đã có (tool.search) → viết mã kèm test với **hiệu ứng khai báo tường minh** (tool.write) → kiểm trong sandbox và đối chiếu hiệu ứng thực tế (tool.test) → chạy theo chính sách với lớp rủi ro suy ra từ hiệu ứng (tool.run) → đăng ký thành năng lực tạm `user.*` gọi được từ mọi bề mặt (tool.register) → thăng cấp thành năng lực chính thức sau khi chứng minh (tool.promote). Về nguyên tắc, mọi năng lực khác trong Danh mục đều có thể được sinh ra theo con đường này; Danh mục 228 năng lực còn lại là tập "đã được thiết kế trước" để bảo đảm chất lượng, an toàn và hiệu năng cho những việc lặp lại nhiều. Ba ràng buộc giữ cho năng lực gốc an toàn: (1) hiệu ứng khai báo là hợp đồng — kiểm tĩnh (import cấm) và động (giám sát tệp/socket/tiến trình) — vi phạm là lỗi nghiêm trọng; (2) lớp rủi ro không do mô hình tự chọn mà suy ra từ hiệu ứng (đọc R0, mạng R1, ghi dự án R2, phần cứng R3, hệ thống R4) và đi qua cùng PolicyGate; (3) công cụ tạm không được vào registry chia sẻ cho tới khi Pack owner duyệt (T2).'));
    c.push(...CODE([
      '# .eide/tools/<tool_id>/tool.py — mẫu TEMPLATE_TOOL.py',
      'SPEC = {"id": "user.hex_to_bin_crc", "purpose": "Chuyển Intel HEX sang BIN và tính CRC32",',
      '        "input": {"type":"object","required":["hex"],"properties":{"hex":{"type":"string"},"out":{"type":"string"}}},',
      '        "output": {"type":"object","required":["bin","crc32","size"],"properties":{"bin":{"type":"string"},"crc32":{"type":"string"},"size":{"type":"integer"}}},',
      '        "effects": ["read_fs", "write_project"], "deps": ["intelhex"], "acceptance": [{"in": {"hex": "tests/a.hex"}, "out": {"crc32": "0x1C291CA3", "size": 1024}}]}',
      'def run(args: dict, ctx: "ToolContext") -> dict:',
      '    """Đọc HEX trong dự án, ghi BIN vào out (mặc định cạnh HEX), trả CRC32."""',
      '    from intelhex import IntelHex; import zlib',
      '    ih = IntelHex(ctx.fs.path(args["hex"]))                      # ctx.fs giới hạn trong dự án (effects read_fs/write_project)',
      '    data = ih.tobinarray(); out = args.get("out") or args["hex"].rsplit(".", 1)[0] + ".bin"',
      '    ctx.fs.write_bytes(out, bytes(data))',
      '    return {"bin": out, "crc32": f"0x{zlib.crc32(bytes(data)) & 0xFFFFFFFF:08X}", "size": len(data)}',
    ]));
    c.push(SP());
  }
  c.push(H1('2. Tổng quan tập'));
  c.push(T([1400, 3300, 900, 900, 2800], ['Nhóm', 'Tên', 'Số', 'T1/T1*/T2/T3', 'Mốc'], nss.map(ns => { const rs = recs.filter(r => r.ns === ns); const cnt = t => rs.filter(r => r.tier === t).length; return [ns, NS_VI[ns], String(rs.length), `${cnt('T1')}/${cnt('T1*')}/${cnt('T2')}/${cnt('T3')}`, [...new Set(rs.map(r => r.milestone))].join(', ')]; })));
  c.push(SP());
  let sec = 3;
  for (const ns of nss) {
    c.push(H1(`${sec++}. ${ns.toUpperCase()} — ${NS_VI[ns]}`));
    for (const r of recs.filter(x => x.ns === ns)) c.push(...capBlock(r));
  }
  c.push(...refParas(H1));
  build(m, c, `EIDE-CDS-12.${v}_Dac_ta_nang_luc_tap_${v}.docx`);
}

// ---------------------------------------------------------------------------------------------
// CDS-12.4 DOC-01 — nguồn tri thức của từng mục, theo LOẠI tài liệu (DEVIATIONS DEV-070).
//
// Phần ĐỀ MỤC không nằm ở đây: `scripts/gen_spec_tu_nguon.js` rút thẳng các `H1(...)` của chính
// bộ sinh tài liệu (`urd.js`, `srs.js`, `sad.js`, `sdd.js`, `stp.js`, `bpd.js`) rồi ghép với bảng
// dưới đây thành `docs/spec/doc/outlines.json`. Nhờ vậy đổi mục lục trong bộ hồ sơ là mục lục
// tài liệu do EIDE sinh cũng đổi theo — không phải sửa hai chỗ, và không có bản chép tay nào để
// trôi đi. Cùng khuôn với `doc/glossary.json` (DEV-025/029/043/046).
//
// Khóa là TIỀN TỐ số hiệu mục ("3.", "3B."), không phải cả tiêu đề: tiêu đề còn được sửa chữ,
// còn số hiệu thì ổn định. `-` nghĩa là mục dẫn nhập, không có bảng số liệu nào.
const DOC_OUTLINE_NGUON = {
  URD: { '1.': '-', '2.': '-', '3.': 'req:UR', '4.': 'req:NFR', '5.': 'constraints', '6.': 'trace' },
  SRS: { '1.': '-', '2.': 'constraints', '3.': 'req:FR', '3B.': 'req:FR', '4.': 'req:NFR', '5.': 'hw_map', '6.': 'acceptance', '7.': 'trace' },
  SAD: { '1.': '-', '2.': 'constraints', '3.': 'module', '3A.': 'module', '4.': 'fsm', '5.': 'fact', '6.': '-', '7.': 'adr', '8.': 'adr' },
  SDD: { '1.': '-', '2.': 'code_unit', '3.': 'fact', '4.': 'module', '5.': 'constraints', '6.': 'constraints', '7.': '-', '8.': '-' },
  STP: { '1.': '-', '2.': 'constraints', '3.': 'acceptance', '4.': 'tool_report', '5.': 'trace' },
  BPD: { '1.': '-', '2.': '-', '10.': 'module' },
};

// Mục BẮT BUỘC phải có dữ liệu — `ask_when` của DOC-01 là "Thiếu fact bắt buộc". Một SRS không có
// yêu cầu chức năng nào không phải SRS mỏng, nó là SRS rỗng, và sinh ra rồi nộp đi là cách tệ
// nhất để phát hiện chuyện ấy.
const DOC_OUTLINE_BAT_BUOC = {
  URD: ['req:UR'], SRS: ['req:FR'], SAD: ['module'], SDD: ['module'], STP: ['acceptance'], BPD: [],
};
