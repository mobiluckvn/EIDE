// Sinh các tệp `docs/spec/` mà bộ sinh docx KHÔNG chạy được tới — WI-018.
//
// VÌ SAO GỘP. Đây từng là ba script gần giống nhau (`gen_policy_spec.js`,
// `gen_dialog_spec.js`, và một cái thứ tư sắp có cho CXD-10). Ba bản sao của cùng một thuật
// toán là ba chỗ để sửa khi thuật toán đổi, và hai trong ba sẽ bị quên — đúng khuôn mẫu mà
// DEV-018 nói tới, chỉ khác là lần này nó xảy ra trong chính công cụ dùng để chống nó.
//
// VÌ SAO KHÔNG CHẠY THẲNG BỘ SINH DOCX. Ba lý do khác nhau, mỗi tệp một lý do:
//   pol.js  chạy được, nhưng cần `node_modules` và dựng cả docx chỉ để lấy hai tệp text.
//   dps.js  nay CŨNG chạy được — `dialog.json` đã khôi phục 06/09/2026 (DEV-019 đóng) — nhưng
//           giữ đường rút literal ở đây vì nó không cần `node_modules`, tức `make check` chạy
//           được trên một máy chưa từng `npm install`.
//   cxd.js  bảng ngân sách nằm trong văn xuôi, không có tệp máy đọc được.
// Điểm chung: các BẢNG DỮ LIỆU trong những tệp ấy là literal độc lập, rút ra được mà không
// cần chạy phần còn lại.
//
//   node scripts/gen_spec_tu_nguon.js --kiem   so với tệp hiện có, không ghi (chạy ở CI)
//   node scripts/gen_spec_tu_nguon.js          ghi đè docs/spec/
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const NGUON = path.join(ROOT, 'docs/ho-so/nguon');
const SPEC = path.join(ROOT, 'docs/spec');

/** Rút một literal `const TEN = {…}` hoặc `const TEN = […]` ra khỏi tệp JS. */
function literal(tep, ten) {
    const src = fs.readFileSync(path.join(NGUON, tep), 'utf8');
    for (const mo of ['{', '[']) {
        const dau = src.indexOf(`const ${ten} = ${mo}`);
        if (dau < 0) continue;
        const dong = mo === '{' ? '\n};' : '\n];';
        const ketThuc = src.indexOf(dong, dau);
        if (ketThuc < 0) throw new Error(`${ten} trong ${tep} không đóng đúng cách`);
        const body = src.slice(dau + `const ${ten} = `.length, ketThuc + 2);
        return new Function(`return ${body}`)();
    }
    throw new Error(`Không thấy literal ${ten} trong ${tep}`);
}

// --- các tệp cần sinh, mỗi mục nói rõ nguồn và cách dựng nội dung ---
const VIEC = [
    {
        tep: 'policy/rules.yaml', nguon: 'pol.js',
        dung: () => {
            const R = literal('pol.js', 'RULES');
            const d = ['# policy/rules.yaml — sinh từ EIDE-POL-17 §2; PolicyGate nạp lúc khởi động; quy tắc ưu tiên nhỏ xét trước; quy tắc đầu tiên khớp thắng', 'version: 1.0', 'rules:'];
            for (const r of R) d.push(`  - id: ${r[0]}\n    gate: "${r[1]}"\n    when: ${JSON.stringify(r[2])}\n    decision: ${r[3]}\n    reason: ${JSON.stringify(r[4])}\n    priority: ${r[5]}\n    features: ${JSON.stringify(r[6].split(',').map(s => s.trim()).filter(Boolean))}`);
            return d.join('\n') + '\n';
        },
    },
    {
        tep: 'policy/situations.jsonl', nguon: 'pol.js',
        dung: () => literal('pol.js', 'SIT')
            .map(s => JSON.stringify({ id: s[0], gate: s[1], situation: s[2], expected: s[3] }))
            .join('\n') + '\n',
    },
    {
        // POL-17 §4 là schema CHUẨN TẮC của autonomy.yaml, nhưng nó nằm trong một khối CODE
        // của tài liệu — tức là văn xuôi. Trước khi có mục này, `.eide/autonomy.yaml` không hề
        // được kiểm: `additionalProperties: false` nghĩa là một khóa gõ sai (hay một khóa §3
        // nhắc tới mà §4 không có, xem DEV-030) phải bị bắt, mà không ai bắt cả.
        tep: 'policy/autonomy.schema.json', nguon: 'pol.js',
        dung: () => JSON.stringify(JSON.parse(literal('pol.js', 'AUTONOMY_SCHEMA').join('\n')), null, 2) + '\n',
    },
    {
        tep: 'dialog/intent.schema.json', nguon: 'dps.js',
        dung: () => JSON.stringify(literal('dps.js', 'INTENT_SCHEMA'), null, 2) + '\n',
    },
    {
        tep: 'dialog/intents.md', nguon: 'dps.js',
        dung: () => '# C0 — danh sách ý định cho vai trò `intent` (sinh từ DPS-09 §4.1)\n\n'
            + literal('dps.js', 'INTENT_MO_TA').map(([k, v]) => `- \`${k}\` — ${v}`).join('\n')
            + '\n\nPhân biệt:\n' + literal('dps.js', 'INTENT_PHAN_BIET').map(s => `- ${s}`).join('\n')
            + '\n\nis_big:\n' + literal('dps.js', 'IS_BIG_QUY_TAC').map(s => `- ${s}`).join('\n') + '\n',
    },
    {
        // DPS-09 §4.4 năm chuỗi mẫu, cột 3 là ý định kích hoạt. `chat.orchestrate` (CHAT-06 bước
        // 1) chọn chuỗi theo `trigger_intents` TRƯỚC khi nhờ mô hình lập kế hoạch — bám mẫu rẻ
        // hơn và đoán được hơn là để mô hình sáng tác mỗi lần.
        tep: 'dialog/chains.json', nguon: 'dps.js',
        dung: () => JSON.stringify(literal('dps.js', 'CHUOI_MAU').map(r => ({
            ten: r[0],
            chuoi: r[1],
            buoc: r[1].split('\u2192').map(x => x.trim()).filter(Boolean),
            trigger_intents: r[2] || [],
        })), null, 1) + '\n',
    },
    {
        // UXD-13 U1: ô lệnh gợi ý "/" liệt kê "năng lực có `ui`". Nhưng KHÔNG năng lực nào có
        // trường ấy (0/238 trong cds.json), nên quy tắc U1 không áp dụng được. Nguồn duy nhất
        // nói năng lực nào thuộc màn hình nào là bảng §2 — và nó ở dạng literal `S`, rút được.
        // Xem DEVIATIONS DEV-046.
        tep: 'ui/screens.json', nguon: 'uxd.js',
        dung: () => {
            const S = literal('uxd.js', 'S');
            const ra = S.map(r => ({
                so: r[0], man_hinh: r[1], noi_dung: r[2],
                // "chat.*, policy.*, memory.compose" → ["chat.*", "policy.*", "memory.compose"]
                nang_luc: r[3].split(',').map(x => x.trim()).filter(x => x && x !== '—'),
            }));
            return JSON.stringify(ra, null, 1) + '\n';
        },
    },
    {
        tep: 'ui/tokens.json', nguon: 'uxd.js',
        dung: () => JSON.stringify(literal('uxd.js', 'TOKENS'), null, 2) + '\n',
    },
    {
        tep: 'context/budgets.json', nguon: 'cxd.js',
        dung: () => JSON.stringify(literal('cxd.js', 'CXD'), null, 2) + '\n',
    },
];

// --- bất biến giữa các tệp: enum ý định và bảng mô tả phải phủ nhau HAI CHIỀU ---
function kiemBatBien() {
    const enumIds = literal('dps.js', 'INTENT_SCHEMA').properties.intent.enum;
    const motaIds = literal('dps.js', 'INTENT_MO_TA').map(r => r[0]);
    const thieu = enumIds.filter(x => !motaIds.includes(x));
    const thua = motaIds.filter(x => !enumIds.includes(x));
    if (thieu.length || thua.length) {
        // Một ý định không có mô tả thì mô hình không biết khi nào dùng nó; một mô tả không
        // có trong enum thì mô hình bị mời chọn thứ không tồn tại.
        throw new Error(`enum và INTENT_MO_TA lệch — thiếu mô tả: ${thieu}; thừa: ${thua}`);
    }
    const cxd = literal('cxd.js', 'CXD');
    const thieuNS = Object.keys(cxd.budget).filter(r => !cxd.budget[r].total);
    if (thieuNS.length) throw new Error(`vai trò thiếu ngân sách tổng: ${thieuNS}`);
}

const raSoat = process.argv.includes('--kiem');
let lech = 0;
try {
    kiemBatBien();
} catch (e) {
    console.error(`✗ ${e.message}`);
    process.exit(1);
}
for (const v of VIEC) {
    const p = path.join(SPEC, v.tep);
    const noi_dung = v.dung();
    const cu = fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
    if (raSoat) {
        if (cu !== noi_dung) { console.error(`✗ ${v.tep} lệch nguồn ${v.nguon}`); lech = 1; }
        else console.log(`✓ ${v.tep} khớp ${v.nguon}`);
    } else {
        fs.mkdirSync(path.dirname(p), { recursive: true });
        fs.writeFileSync(p, noi_dung);
        console.log(`${cu === noi_dung ? '=' : 'đã ghi'} ${v.tep}  (từ ${v.nguon})`);
    }
}
process.exit(lech);
