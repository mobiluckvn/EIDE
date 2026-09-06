#!/usr/bin/env python3
"""Sinh một bảng dịch `Sources/GEditorApp/Localization+<mã>.swift` và đăng ký nó.

    # soát ô định dạng trước, không sinh gì
    python3 scripts/gen-language.py --check ban-dich/nl.py

    # sinh tệp Swift và thêm dòng vào `L10n.table(for:)`
    python3 scripts/gen-language.py --code nl --name "tiếng Hà Lan" ban-dich/nl.py

Tệp bản dịch là một mô-đun Python khai một danh sách tên `VALS`, đúng THỨ TỰ khoá của bảng
tiếng Anh, một phần tử cho mỗi khoá. `None` nghĩa là chưa dịch — khoá ấy bị bỏ hẳn khỏi bảng
và chuỗi rơi về tiếng Anh (xem `L10n.translate`).

# Vì sao sinh chứ không gõ tay

Khoá là 1050 chuỗi tiếng Việt, nhiều chuỗi có dấu nháy cong, dấu ba chấm, ký tự `\\u{...}` và
một chuỗi nhiều dòng. Gõ lại chúng cho mỗi ngôn ngữ là mỗi lần một cơ hội lệch MỘT byte — và
lệch một byte thì `L()` im lặng trả về nguyên bản tiếng Việt. Không có gì để nổ, không bài kiểm
nào đỏ, chỉ một nhãn tiếng Việt lọt giữa giao diện tiếng Nhật.

Ở đây người dịch chỉ cung cấp GIÁ TRỊ; khoá lấy nguyên văn từ `Localization+en.swift`.

# Vì sao có `--check` riêng

Vì vòng «sinh → biên dịch → chạy tự kiểm → đọc lỗi → sửa» mất vài phút và chỉ báo MỘT lỗi mỗi
vòng. `--check` chạy trong một giây và kể ra hết. Nó dùng ĐÚNG luật của cổng trong `SelfTest`:
so tham số THỨ MẤY mang kiểu gì, không so thứ tự xuất hiện — nên bản dịch đảo trật tự bằng ô
đánh số `%1$d` / `%2$@` là hợp lệ, và đó là cách duy nhất đúng cho những thứ tiếng mà trật tự
từ bắt buộc phải đảo (đã gặp thật ở tiếng Nga và tiếng Ả Rập).
"""
import argparse
import importlib.util
import re
import sys
from pathlib import Path

GOC = Path(__file__).resolve().parent.parent
NGUON = GOC / 'Sources/GEditorApp'
BANG_ANH = NGUON / 'Localization+en.swift'
LOI = NGUON / 'Localization.swift'

# Ký tự chuyển đổi THẬT của `String(format:)`. `%` đứng trước thứ khác là dấu phần trăm
# nguyên nghĩa — "Dải 80%" đã một lần bị bộ đo đầu tiên tố nhầm là thiếu ô "%b".
CHUYEN_DOI = set('diouxXeEfgGaAcsp@')


def doc_khoa() -> list:
    """Cặp (khoá, giá trị) NGUYÊN VĂN kèm dấu nháy, theo đúng thứ tự trong tệp tiếng Anh."""
    than = BANG_ANH.read_text()
    than = than[than.index('static let en: [String: String] = ['):]
    mau = re.compile(
        r'(?:^|\n)\s*((?:"(?:[^"\\]|\\.)*")|(?:"""(?:.|\n)*?"""))'
        r'\s*:\s*\n?\s*((?:"(?:[^"\\]|\\.)*")|(?:"""(?:.|\n)*?"""))\s*,'
    )
    return mau.findall(than)


def o_dinh_dang(text: str) -> dict:
    """{vị trí tham số: ký tự chuyển đổi}. Hiểu cả `%n$` lẫn thứ tự ngầm."""
    ra, ngam, i, n = {}, 0, 0, len(text)
    while i < n:
        if text[i] != '%':
            i += 1
            continue
        j = i + 1
        if j >= n:
            break
        if text[j] == '%':                       # `%%` — phần trăm thật
            i = j + 1
            continue
        vi_tri, k, so = None, j, ''
        while k < n and text[k].isdigit():
            so += text[k]
            k += 1
        if k < n and text[k] == '$' and so:      # tiền tố đánh số, đọc TRƯỚC cờ
            vi_tri = int(so)
            j = k + 1
        while j < n and text[j] in "0123456789.-+#'":
            j += 1
        while j < n and text[j] in 'lhzjt':
            j += 1
        if j >= n or text[j] not in CHUYEN_DOI:
            i += 1
            continue
        ngam += 1
        ra[vi_tri if vi_tri else ngam] = text[j]
        i = j + 1
    return ra


def nap_ban_dich(duong_dan: str) -> list:
    spec = importlib.util.spec_from_file_location('ban_dich', duong_dan)
    mo_dun = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mo_dun)
    return mo_dun.VALS


def soat(cap: list, vals: list) -> int:
    if len(vals) != len(cap):
        print(f'❌ LỆCH SỐ LƯỢNG: cần {len(cap)} bản dịch, nhận {len(vals)}')
        return 1
    loi = 0
    for i, ((khoa, _), dich) in enumerate(zip(cap, vals)):
        if dich is None or khoa.startswith('"""'):
            continue
        if not dich.strip():
            print(f'[{i}] RỖNG: {khoa[1:76]}')
            loi += 1
            continue
        goc, ra = o_dinh_dang(khoa[1:-1]), o_dinh_dang(dich)
        if goc != ra:
            print(f'[{i}] {khoa[1:76]}\n    gốc={goc}  dịch={ra}\n    {dich[:90]}')
            loi += 1
    print(f'❌ {loi} chỗ lệch' if loi else '✅ ô định dạng khớp hết')
    return loi


def sinh(ma: str, ten: str, cap: list, vals: list) -> Path:
    bien = {'zh-Hans': 'zhHans', 'zh-Hant': 'zhHant'}.get(ma, ma.replace('-', ''))
    dong = []
    for (khoa, _), dich in zip(cap, vals):
        if dich is None:
            continue                              # bỏ khoá → rơi về tiếng Anh
        if khoa.startswith('"""'):
            dong.append(f'        {khoa}: """\n{dich}\n        """,')
        else:
            thoat = (dich.replace('\\', '\\\\').replace('"', '\\"')
                         .replace('\n', '\\n').replace('\t', '\\t'))
            dong.append(f'        {khoa}: "{thoat}",')
    noi_dung = f'''import Foundation

/// Bảng dịch {ten}. Sinh bằng `scripts/gen-language.py` — xem chú thích ở đó.
///
/// Khoá lấy NGUYÊN VĂN từ bảng tiếng Anh, nên không khoá nào lệch được. Chuỗi thiếu ở đây rơi
/// về tiếng Anh chứ không về tiếng Việt — xem `L10n.translate`.
extension L10n {{

    static let {bien}: [String: String] = [
{chr(10).join(dong)}
    ]
}}
'''
    dich_ra = NGUON / f'Localization+{bien}.swift'
    dich_ra.write_text(noi_dung)

    # Đăng ký. Quên dòng này là kiểu hỏng IM LẶNG: tệp nằm đó, biên dịch trót lọt, cổng «ô %d»
    # không thấy gì để soi vì `table(for:)` trả `nil`, và người dùng vẫn nhận tiếng Anh.
    lang = LOI.read_text()
    moi = f'        case .{bien}: return {bien}\n'
    if moi not in lang:
        LOI.write_text(lang.replace('        default: return nil', moi + '        default: return nil', 1))
    return dich_ra


def main() -> None:
    dm = argparse.ArgumentParser()
    dm.add_argument('ban_dich')
    dm.add_argument('--code')
    dm.add_argument('--name')
    dm.add_argument('--check', action='store_true')
    args = dm.parse_args()

    cap = doc_khoa()
    vals = nap_ban_dich(args.ban_dich)
    if soat(cap, vals):
        sys.exit(1)
    if args.check:
        print(f'{len(cap)} khoá — chỉ soát, không sinh')
        return
    if not args.code or not args.name:
        sys.exit('cần --code và --name để sinh')
    ra = sinh(args.code, args.name, cap, vals)
    print(f'{args.code}: {ra.name} — {sum(1 for v in vals if v is not None)} mục, đã đăng ký')


if __name__ == '__main__':
    main()
