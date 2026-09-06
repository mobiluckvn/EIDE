// Sinh docs/spec/dialog/intent.schema.json từ nguồn docs/ho-so/nguon/dps.js.
//
// VÌ SAO KHÔNG CHẠY THẲNG `node dps.js`. Bộ sinh ấy mở đầu bằng `require('./dialog.json')`,
// và tệp `dialog.json` KHÔNG có ở đâu trong kho — nên DPS-09 chưa từng sinh lại được
// (DEVIATIONS DEV-019). Nhưng schema Intent thì không phụ thuộc `dialog.json`: nó là một
// literal độc lập trong dps.js. Script này rút đúng literal ấy ra, như
// `gen_policy_spec.js` đã làm với RULES/SIT.
//
// Nhờ vậy ba chỗ dùng schema Intent — prompt vai trò, Gateway, và test TC-59 — đọc chung một
// nguồn, và `--kiem` giữ cho chúng không trôi khỏi nhau, kể cả khi `dialog.json` chưa được
// khôi phục.
//
//   node scripts/gen_dialog_spec.js --kiem    so với tệp hiện có, không ghi
//   node scripts/gen_dialog_spec.js           ghi đè docs/spec/dialog/
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const NGUON = path.join(ROOT, 'docs/ho-so/nguon/dps.js');
const DICH = path.join(ROOT, 'docs/spec/dialog');

function literal(ten, src) {
    const dau = src.indexOf(`const ${ten} = {`);
    if (dau < 0) throw new Error(`Không thấy ${ten} trong dps.js`);
    const ketThuc = src.indexOf('\n};', dau);
    if (ketThuc < 0) throw new Error(`${ten} không đóng đúng cách`);
    const body = src.slice(dau + `const ${ten} = `.length, ketThuc + 2);
    return new Function(`return ${body}`)();
}

function mang(ten, src) {
    const dau = src.indexOf(`const ${ten} = [`);
    if (dau < 0) throw new Error(`Không thấy ${ten} trong dps.js`);
    const ketThuc = src.indexOf('\n];', dau);
    return new Function(`return ${src.slice(dau + `const ${ten} = `.length, ketThuc + 2)}`)();
}

const src = fs.readFileSync(NGUON, 'utf8');
const INTENT_SCHEMA = literal('INTENT_SCHEMA', src);
const MO_TA = mang('INTENT_MO_TA', src);
const PHAN_BIET = mang('INTENT_PHAN_BIET', src);

// Enum và bảng mô tả phải phủ nhau HAI CHIỀU: một ý định không có mô tả thì mô hình không biết
// khi nào dùng nó; một mô tả không có trong enum thì mô hình bị mời chọn thứ không tồn tại.
const enumIds = INTENT_SCHEMA.properties.intent.enum;
const motaIds = MO_TA.map(r => r[0]);
const thieuMoTa = enumIds.filter(x => !motaIds.includes(x));
const thuaMoTa = motaIds.filter(x => !enumIds.includes(x));
if (thieuMoTa.length || thuaMoTa.length) {
    console.error(`✗ enum và INTENT_MO_TA lệch nhau — thiếu mô tả: ${thieuMoTa}; thừa: ${thuaMoTa}`);
    process.exit(1);
}

const tep = {
    'intent.schema.json': JSON.stringify(INTENT_SCHEMA, null, 2) + '\n',
    'intents.md': '# C0 — danh sách ý định cho vai trò `intent` (sinh từ DPS-09 §4.1)\n\n'
        + MO_TA.map(([k, v]) => `- \`${k}\` — ${v}`).join('\n')
        + '\n\nPhân biệt:\n' + PHAN_BIET.map(s => `- ${s}`).join('\n') + '\n',
};

let lech = 0;
for (const [ten, noi_dung] of Object.entries(tep)) {
    const p = path.join(DICH, ten);
    const cu = fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
    if (process.argv.includes('--kiem')) {
        if (cu !== noi_dung) { console.error(`✗ ${ten} lệch nguồn dps.js`); lech = 1; }
        else console.log(`✓ ${ten} khớp nguồn dps.js`);
    } else {
        fs.mkdirSync(DICH, { recursive: true });
        fs.writeFileSync(p, noi_dung);
        console.log(`${cu === noi_dung ? '=' : 'đã ghi'} ${ten}`);
    }
}
process.exit(lech);
