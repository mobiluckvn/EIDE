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

PY="$GOC/.venv-arm/bin/python"; [ -x "$PY" ] || PY="$GOC/.venv-x86/bin/python"; [ -x "$PY" ] || PY=python3
SAN=$(mktemp -d "${TMPDIR:-/tmp}/eide-sinh-XXXXXX")
trap 'rm -rf "$SAN"' EXIT
# `.json` cũng là nguồn: `dps.js` require('./dialog.json') (bảng §3 và 10 kịch bản §5).
cp "$NGUON"/*.js "$NGUON"/*.py "$NGUON"/*.json "$SAN"/ 2>/dev/null || true
# …nhưng KHÔNG phải package.json/package-lock.json: chép chúng vào thư mục dàn dựng làm node
# coi đó là gốc gói và bỏ qua symlink node_modules bên dưới.
rm -f "$SAN/package.json" "$SAN/package-lock.json"
ln -s "$NGUON/node_modules" "$SAN/node_modules"
[ -d "$NGUON/hinh" ] && cp -R "$NGUON/hinh" "$SAN/" || true
# `caps.json` là dữ liệu viết tay (không bộ sinh nào ghi ra nó); `cds.json` và `ddd.json` thì
# SINH ra từ `cds_data_*.py` / `ddd_model.py` bằng hai kịch bản Python cạnh chúng. Chạy lại hai
# kịch bản ấy ở đây thay vì chép bản cũ trong `docs/spec`: nếu chỉ chép thì sửa `cds_data_a.py`
# xong docx vẫn dựng từ bản cũ, và người sửa tưởng mình vừa đổi tài liệu. Cùng khuôn mẫu DEV-018.
cp "$SPEC/caps.json" "$SAN/"
(cd "$SAN" && "$PY" gen_cds.py >/dev/null && "$PY" gen_ddd.py >/dev/null)

# `ddd.js` đọc `data/json/*.json` — do gen_ddd.py vừa sinh ở trên, nên không chép từ kho.
(cd "$SAN" && node "$TEN.js" >/dev/null)

lech=0

khac() {  # $1 = tệp A, $2 = tệp B → 0 nếu GIỐNG
    # docx là zip có dấu thời gian nén: hai lần sinh từ cùng nguồn khác byte nhưng giống nội
    # dung. Dùng `cmp` ở đây làm `--kiem` báo "LỆCH nguồn" cho MỌI tài liệu (đo 06/09/2026:
    # pol, prs, cxd đều ✗ dù đang đồng bộ) — một cổng luôn đỏ che mất lần lệch thật.
    case "$1" in
        *.docx) "$PY" "$GOC/scripts/so_docx.py" "$1" "$2" --im ;;
        *)      cmp -s "$1" "$2" ;;
    esac
}

chep() {  # $1 = tệp trong $SAN, $2 = đích
    [ -f "$SAN/$1" ] || return 0
    if [ "$KIEM" = "--kiem" ]; then
        if [ ! -f "$2" ]; then echo "  ✗ $(basename "$2") CHƯA CÓ trong kho"; lech=1
        elif khac "$SAN/$1" "$2"; then echo "  = $(basename "$2")"
        else
            echo "  ✗ $(basename "$2") LỆCH nguồn"
            # KHÔNG nối `| head`: `so_docx.py` in nhiều hơn 6 dòng thì head đóng ống, python
            # nhận SIGPIPE, `pipefail` biến cả pipeline thành lỗi và `set -e` giết script ngay
            # tại đây — mọi tệp còn lại không bao giờ được đối chiếu, mà script vẫn thoát 1 nên
            # trông y hệt một lần "có lệch" bình thường. `so_docx.py` đã tự giới hạn 8 dòng.
            case "$1" in *.docx) "$PY" "$GOC/scripts/so_docx.py" "$SAN/$1" "$2" || true ;; esac
            lech=1
        fi
    else
        cp "$SAN/$1" "$2"; echo "  → $2"
    fi
}

for d in "$SAN"/*.docx; do [ -f "$d" ] && chep "$(basename "$d")" "$HO_SO/$(basename "$d")"; done
# `cds.json`/`ddd.json` là đầu ra của gen_cds.py/gen_ddd.py và cũng là đầu vào của các bộ sinh
# docx khác, nên phải đưa về kho — không thì sửa `cds_data_a.py` chỉ đổi được docx của chính
# nhóm ấy, còn `docs/spec/cds.json` mà sản phẩm đọc thì đứng yên.
for f in cds.json ddd.json; do chep "$f" "$SPEC/$f"; done
# `find` chứ không phải `*`: `data/` có thư mục con `json/` với 27 JSON Schema bên trong, và
# một vòng lặp chỉ quét tệp phẳng sẽ bỏ qua đúng phần nhiều nhất.
for sub in policy api prompts isa data capabilities dialog ui context; do
    [ -d "$SAN/$sub" ] || continue
    while IFS= read -r d; do
        rel="${d#"$SAN"/}"
        mkdir -p "$(dirname "$SPEC/$rel")"
        chep "$rel" "$SPEC/$rel"
    done < <(find "$SAN/$sub" -type f | sort)
done
# `prs.js` sinh fixture 50 câu lệnh có nhãn cho TC-59 nhưng đặt tên phẳng ở cwd; đưa nó vào
# spec dưới đúng tên mà PRS-16 §7 nói tới (`tests/dialog/commands.jsonl`).
if [ -f "$SAN/tests_dialog_commands.jsonl" ]; then
    mkdir -p "$SPEC/dialog"; chep "tests_dialog_commands.jsonl" "$SPEC/dialog/commands.jsonl"
fi

exit $lech
