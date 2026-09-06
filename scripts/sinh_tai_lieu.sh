#!/usr/bin/env bash
# Sinh lại một tài liệu của bộ hồ sơ từ nguồn — bước cuối của vòng "Đồng bộ tài liệu"
# (CLAUDE.md §"Đồng bộ tài liệu", DEV-29 §4).
#
#   scripts/sinh_tai_lieu.sh pol          sinh EIDE-POL-17…docx (+ policy/rules.yaml, situations.jsonl)
#   scripts/sinh_tai_lieu.sh pol --kiem   sinh vào thư mục tạm và SO với kho, không ghi đè
#   scripts/sinh_tai_lieu.sh --danh-sach  liệt kê các bộ sinh có sẵn
#
# VÌ SAO CẦN SCRIPT NÀY. Quy trình nói "sửa nguồn sinh rồi `node <ten>.js`", nhưng làm thẳng
# như thế thì hỏng: các bộ sinh đọc `caps.json`/`cds.json`/`ddd.json` và GHI docx cùng
# `policy/*` vào THƯ MỤC HIỆN TẠI. Chạy trong `nguon/` sẽ rải tệp sinh lẫn vào mã nguồn; chạy
# ở gốc kho sẽ ghi đè docs/spec bằng đường vòng không ai thấy. Nên: dựng một thư mục dàn dựng
# sạch, chạy ở đó, rồi chép có chủ đích từng tệp về.
#
# `docx` (npm) là phụ thuộc CHỈ của việc soạn tài liệu, không phải của sản phẩm: `make check`
# và `eide` chạy được mà không cần nó. Vì thế nó nằm ở `docs/ho-so/nguon/package.json` chứ
# không phải ở gốc kho.
set -euo pipefail
cd "$(dirname "$0")/.."
GOC="$PWD"
NGUON="$GOC/docs/ho-so/nguon"
HO_SO="$GOC/docs/ho-so"
SPEC="$GOC/docs/spec"

if [ "${1:-}" = "--danh-sach" ] || [ $# -eq 0 ]; then
    echo "Bộ sinh có sẵn (docs/ho-so/nguon/*.js):"
    (cd "$NGUON" && ls *.js | grep -v -E '^(eaa_doc|eide_common)\.js$' | sed 's/\.js$//' | tr '\n' ' ')
    echo; echo "Dùng: scripts/sinh_tai_lieu.sh <tên> [--kiem]"
    exit 0
fi

TEN="$1"; KIEM="${2:-}"
[ -f "$NGUON/$TEN.js" ] || { echo "Không có bộ sinh: $TEN.js"; exit 2; }

command -v node >/dev/null || { echo "Cần node để sinh tài liệu"; exit 1; }
if [ ! -d "$NGUON/node_modules" ]; then
    echo "Cài phụ thuộc soạn tài liệu (một lần)…"
    (cd "$NGUON" && npm install --silent --no-fund --no-audit)
fi

SAN=$(mktemp -d "${TMPDIR:-/tmp}/eide-sinh-XXXXXX")
trap 'rm -rf "$SAN"' EXIT
cp "$NGUON"/*.js "$NGUON"/*.py "$SAN"/ 2>/dev/null || true
ln -s "$NGUON/node_modules" "$SAN/node_modules"
[ -d "$NGUON/hinh" ] && cp -R "$NGUON/hinh" "$SAN/" || true
# Bộ sinh đọc ba tệp sinh sẵn này làm đầu vào
for f in caps.json cds.json ddd.json; do [ -f "$SPEC/$f" ] && cp "$SPEC/$f" "$SAN/"; done

(cd "$SAN" && node "$TEN.js" >/dev/null)

lech=0
chep() {  # $1 = tệp trong $SAN, $2 = đích
    [ -f "$SAN/$1" ] || return 0
    if [ "$KIEM" = "--kiem" ]; then
        if cmp -s "$SAN/$1" "$2"; then echo "  = $(basename "$2")"
        else echo "  ✗ $(basename "$2") LỆCH nguồn"; lech=1; fi
    else
        cp "$SAN/$1" "$2"; echo "  → $2"
    fi
}

for d in "$SAN"/*.docx; do [ -f "$d" ] && chep "$(basename "$d")" "$HO_SO/$(basename "$d")"; done
for sub in policy api prompts isa data capabilities dialog ui context; do
    [ -d "$SAN/$sub" ] || continue
    mkdir -p "$SPEC/$sub"
    for d in "$SAN/$sub"/*; do [ -f "$d" ] && chep "$sub/$(basename "$d")" "$SPEC/$sub/$(basename "$d")"; done
done
# `prs.js` sinh fixture 50 câu lệnh có nhãn cho TC-59 nhưng đặt tên phẳng ở cwd; đưa nó vào
# spec dưới đúng tên mà PRS-16 §7 nói tới (`tests/dialog/commands.jsonl`).
if [ -f "$SAN/tests_dialog_commands.jsonl" ]; then
    mkdir -p "$SPEC/dialog"; chep "tests_dialog_commands.jsonl" "$SPEC/dialog/commands.jsonl"
fi

exit $lech
