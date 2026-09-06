// Sinh lại docs/spec/policy/{rules.yaml,situations.jsonl} từ nguồn docs/ho-so/nguon/pol.js.
//
// VÌ SAO CÓ TỆP NÀY. Quy trình (CLAUDE.md §"Đồng bộ tài liệu") đòi: không sửa tay bản sinh
// trong docs/spec/, mà sửa nguồn rồi sinh lại. Nhưng `pol.js` đồng thời dựng cả docx và cần
// thư viện `docx` qua npm; chạy trọn nó chỉ để lấy hai tệp text là buộc phải có node_modules
// mà kho cố ý không mang theo (NFR-SEC-03: không tải mạng lúc dựng).
//
// Nên script này chỉ lấy HAI BẢNG DỮ LIỆU (`RULES`, `SIT`) ra khỏi pol.js và phát lại đúng
// hai tệp ấy bằng CÙNG đoạn mã phát mà pol.js dùng (chép nguyên văn dòng 87-89 và 184).
//
//   node scripts/gen_policy_spec.js --kiem    so với tệp hiện có, không ghi gì (dùng trong CI)
//   node scripts/gen_policy_spec.js           ghi đè docs/spec/policy/
//
// Chế độ --kiem là thứ giữ cho hai bên không trôi khỏi nhau: nếu ai sửa tay rules.yaml, hoặc
// sửa pol.js mà quên sinh lại, nó đỏ.
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const NGUON = path.join(ROOT, 'docs/ho-so/nguon/pol.js');
const DICH = path.join(ROOT, 'docs/spec/policy');

// Cắt đúng khối `const X = [ ... ];`. Hai bảng là mảng literal của mảng chuỗi/số — không có
// lời gọi hàm, không tham chiếu biến ngoài — nên đánh giá chúng là an toàn và không cần
// nạp phần còn lại của pol.js (vốn require('docx')).
function bang(ten, src) {
    const dau = src.indexOf(`const ${ten} = [`);
    if (dau < 0) throw new Error(`Không thấy bảng ${ten} trong pol.js`);
    const ketThuc = src.indexOf('\n];', dau);
    if (ketThuc < 0) throw new Error(`Bảng ${ten} không đóng đúng cách`);
    const literal = src.slice(dau + `const ${ten} = `.length, ketThuc + 2);
    return new Function(`return ${literal}`)();
}

const src = fs.readFileSync(NGUON, 'utf8');
const RULES = bang('RULES', src);
const SIT = bang('SIT', src);

// --- phát lại, chép nguyên văn từ pol.js ---
const yaml = ['# policy/rules.yaml — sinh từ EIDE-POL-17 §2; PolicyGate nạp lúc khởi động; quy tắc ưu tiên nhỏ xét trước; quy tắc đầu tiên khớp thắng', 'version: 1.0', 'rules:'];
for (const r of RULES) yaml.push(`  - id: ${r[0]}\n    gate: "${r[1]}"\n    when: ${JSON.stringify(r[2])}\n    decision: ${r[3]}\n    reason: ${JSON.stringify(r[4])}\n    priority: ${r[5]}\n    features: ${JSON.stringify(r[6].split(',').map(s => s.trim()).filter(Boolean))}`);
const RULES_YAML = yaml.join('\n') + '\n';
const SIT_JSONL = SIT.map(s => JSON.stringify({ id: s[0], gate: s[1], situation: s[2], expected: s[3] })).join('\n') + '\n';

const raSoat = process.argv.includes('--kiem');
let lech = 0;
for (const [ten, noiDung] of [['rules.yaml', RULES_YAML], ['situations.jsonl', SIT_JSONL]]) {
    const p = path.join(DICH, ten);
    const cu = fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
    if (raSoat) {
        if (cu !== noiDung) { console.error(`✗ ${ten} lệch nguồn pol.js`); lech++; }
        else console.log(`✓ ${ten} khớp nguồn pol.js`);
    } else {
        fs.writeFileSync(p, noiDung);
        console.log(`${cu === noiDung ? '=' : 'đã ghi'} ${ten} (${RULES.length && ten === 'rules.yaml' ? RULES.length + ' quy tắc' : SIT.length + ' tình huống'})`);
    }
}
process.exit(lech ? 1 : 0);
