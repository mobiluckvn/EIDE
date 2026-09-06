#!/bin/bash
# End-to-end cho mảng ảnh · PDF · Office · file nén.
#
#   scripts/run-office-e2e.sh
#
# VÌ SAO CẦN, KHI ĐÃ CÓ 2.399 TEST VÀ 275 BÀI TỰ KIỂM.
#
# Hai bộ kia kiểm từng mảnh: bài kiểm lõi chạy `XLSXWriter` mà không cần cửa sổ, bài tự kiểm
# chạy trong app nhưng gọi thẳng vào bộ đọc. Không bộ nào đi HẾT đường mà người dùng đi:
#
#     tệp thật trên đĩa → mở bằng app → sửa → ⌘S → ĐÓNG TAB → MỞ LẠI → và một công cụ NGOÀI
#     (LibreOffice) đọc được tệp ấy.
#
# Vế "đóng tab rồi mở lại" là vế hai bộ kia không có, và nó bắt được đúng loại lỗi hay xảy ra
# nhất ở tầng nối: ghi thành công vào bộ nhớ mà chưa xuống đĩa, hoặc xuống đĩa rồi mà lần mở
# sau đọc từ một bản cache cũ.
#
# Vế "LibreOffice đọc lại" là đối chứng NGOÀI. Tự đọc lại bằng bộ đọc của chính mình chỉ chứng
# minh hai nửa của ta khớp nhau — nó xanh y hệt khi cả hai nửa cùng sai.
set -uo pipefail
cd "$(dirname "$0")/.."

SOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"
APP=".build/release/GEditorApp"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK"

pass=0
fail=0

ok()   { echo "✅ $1"; pass=$((pass + 1)); }
no()   { echo "❌ $1"; fail=$((fail + 1)); }

echo "▸ End-to-end: ảnh · PDF · Office · file nén"
echo

if [ ! -x "$APP" ]; then
    echo "   Chưa dựng bản release. Chạy: swift build -c release"
    exit 2
fi
if [ ! -x "$SOFFICE" ]; then
    echo "   ⏭  Không có LibreOffice — bỏ qua phần đối chứng ngoài."
    echo "      Cài LibreOffice rồi chạy lại để bộ này có nghĩa."
fi

# ============================================================================================
# 1. Dựng fixture bằng LibreOffice — hiện thực ĐỘC LẬP với mọi bộ đọc/ghi của ta
# ============================================================================================
echo "1. Dựng fixture"
mkdir -p "$WORK/in"

printf 'ten,so,ghi chu\nAn,10,alpha\nBinh,20,beta\nCuong,30,gamma\n' > "$WORK/in/bang.csv"
printf '# Tieu de\n\nDoan mot.\n\nDoan hai.\n' > "$WORK/in/tai-lieu.md"

# Một tệp CÓ CÔNG THỨC, để kiểm phép chèn hàng ở GIỮA có dịch lại tham chiếu không.
#
# Dựng hai bước: LibreOffice tạo khung `.xlsx` từ CSV, rồi python tiêm `<f>` vào. Bản đầu dựng
# thẳng bằng `.fods` với `table:formula` — và LibreOffice BỎ QUA nó, cho ra một tệp không có
# công thức nào. Bài kiểm "công thức có dịch đúng không" khi ấy chạy trên một tệp không có gì
# để dịch, và xanh cả khi bộ dịch bị tắt hoàn toàn.
printf 'a,gap doi\n10,\n30,\n' > "$WORK/in/cong-thuc.csv"

if [ -x "$SOFFICE" ]; then
    "$SOFFICE" --headless --convert-to xlsx --outdir "$WORK/in" "$WORK/in/bang.csv" >/dev/null 2>&1
    "$SOFFICE" --headless --convert-to "docx:MS Word 2007 XML" --infilter=Markdown \
        --outdir "$WORK/in" "$WORK/in/tai-lieu.md" >/dev/null 2>&1
    "$SOFFICE" --headless --convert-to xlsx --outdir "$WORK/in" \
        "$WORK/in/cong-thuc.csv" >/dev/null 2>&1
    # Tiêm công thức vào khung vừa dựng, và bật `fullCalcOnLoad` để lát nữa LibreOffice buộc
    # phải TÍNH LẠI. Không có cờ ấy thì nó đọc giá trị đã lưu sẵn trong ô, và phép đối chứng
    # ngoài không kiểm được gì.
    python3 - "$WORK/in/cong-thuc.xlsx" <<'PY'
import sys, zipfile, shutil, re, os
path = sys.argv[1]
tmp = path + ".tmp"
with zipfile.ZipFile(path) as src, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as dst:
    for item in src.infolist():
        data = src.read(item.filename)
        if item.filename.startswith("xl/worksheets/sheet"):
            text = data.decode()
            for line in (2, 3):
                cell = '<c r="B%d"><f>A%d*2</f><v>%d</v></c>' % (
                    line, line, {2: 20, 3: 60}[line])
                text = re.sub(r'(<row r="%d"[^>]*>.*?)(</row>)' % line,
                              lambda m: m.group(1) + cell + m.group(2), text, count=1)
            data = text.encode()
        elif item.filename == "xl/workbook.xml":
            text = data.decode()
            if "<calcPr" in text:
                text = re.sub(r"<calcPr[^>]*/?>", '<calcPr fullCalcOnLoad="1"/>', text, count=1)
            else:
                text = text.replace("</workbook>", '<calcPr fullCalcOnLoad="1"/></workbook>')
            data = text.encode()
        dst.writestr(item, data)
os.replace(tmp, path)
PY
fi
[ -f "$WORK/in/bang.xlsx" ]     && ok "dựng được bang.xlsx"     || no "không dựng được bang.xlsx"
[ -f "$WORK/in/tai-lieu.docx" ] && ok "dựng được tai-lieu.docx" || no "không dựng được tai-lieu.docx"
[ -f "$WORK/in/cong-thuc.xlsx" ] && ok "dựng được cong-thuc.xlsx" || no "không dựng được cong-thuc.xlsx"

# Ảnh và file nén thì dựng bằng công cụ hệ thống, không cần LibreOffice.
python3 - "$WORK/in/anh.png" <<'PY'
import sys, zlib, struct
w, h = 8, 4
raw = b"".join(b"\x00" + bytes([255, 120, 40] * w) for _ in range(h))
def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(
        ">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw))
       + chunk(b"IEND", b""))
open(sys.argv[1], "wb").write(png)
PY
[ -f "$WORK/in/anh.png" ] && ok "dựng được anh.png" || no "không dựng được anh.png"

mkdir -p "$WORK/in/nen" && printf 'noi dung trong file nen\n' > "$WORK/in/nen/ghi-chu.txt"
(cd "$WORK/in/nen" && zip -q -r ../bo.zip .) 2>/dev/null
[ -f "$WORK/in/bo.zip" ] && ok "dựng được bo.zip" || no "không dựng được bo.zip"

# Kho TAR nén gzip — nhánh KHÔNG phải ZIP của khung duyệt file nén.
mkdir -p "$WORK/in/tarnen" && printf 'noi dung trong kho tar\n' > "$WORK/in/tarnen/ghi-chu.txt"
COPYFILE_DISABLE=1 tar -czf "$WORK/in/kho.tar.gz" -C "$WORK/in/tarnen" . 2>/dev/null
[ -f "$WORK/in/kho.tar.gz" ] && ok "dựng được kho.tar.gz" || no "không dựng được kho.tar.gz"

# Kho 7z — nhánh nhờ công cụ nén của hệ điều hành. `bsdtar` của macOS tạo và đọc được 7z.
mkdir -p "$WORK/in/z7" && printf 'noi dung trong kho 7z\n' > "$WORK/in/z7/ghi-chu.txt"
COPYFILE_DISABLE=1 tar -acf "$WORK/in/kho.7z" -C "$WORK/in/z7" . 2>/dev/null
[ -f "$WORK/in/kho.7z" ] && ok "dựng được kho.7z" || no "không dựng được kho.7z"
echo

# ============================================================================================
# 2. Đi hết đường của người dùng, trong app thật
# ============================================================================================
echo "2. Mở · sửa · ⌘S · đóng tab · mở lại — trong app"
GEDITOR_E2E_DIR="$WORK/in" "$APP" --office-e2e 2>&1 | while IFS= read -r line; do
    echo "   $line"
done
E2E_STATUS=${PIPESTATUS[0]}
if [ "$E2E_STATUS" = "0" ]; then
    ok "vòng mở–sửa–lưu–mở lại chạy hết"
else
    no "vòng mở–sửa–lưu–mở lại TRƯỢT (mã thoát $E2E_STATUS)"
fi
echo

# ============================================================================================
# 3. Đối chứng NGOÀI — LibreOffice phải mở được tệp app vừa ghi
# ============================================================================================
echo "3. Đối chứng ngoài: LibreOffice đọc lại tệp app vừa ghi"
if [ -x "$SOFFICE" ]; then
    mkdir -p "$WORK/out"
    "$SOFFICE" --headless --convert-to csv --outdir "$WORK/out" "$WORK/in/bang.xlsx" >/dev/null 2>&1
    if grep -q "GEDITOR-E2E" "$WORK/out/bang.csv" 2>/dev/null; then
        ok "LibreOffice thấy ô app vừa sửa trong .xlsx"
    else
        no "LibreOffice KHÔNG thấy ô app vừa sửa trong .xlsx"
    fi
    # Hàng thêm vào cũng phải có.
    if grep -q "HANG-MOI" "$WORK/out/bang.csv" 2>/dev/null; then
        ok "LibreOffice thấy hàng app vừa THÊM vào .xlsx"
    else
        no "LibreOffice KHÔNG thấy hàng app vừa thêm"
    fi

    # Tệp có công thức: LibreOffice chỉ được dùng để xác nhận tệp MỞ ĐƯỢC và còn đủ hàng.
    #
    # Nó KHÔNG kiểm được công thức có dịch đúng không, và điều ấy phải nói rõ ở đây: mọi trình
    # bảng tính đều đọc giá trị ĐÃ LƯU SẴN trong ô thay vì tính lại — kể cả khi đã bật
    # `fullCalcOnLoad`. Bản đầu của bộ này tin vào phép tính lại ấy, nên nó xanh cả khi bộ dịch
    # tham chiếu bị tắt hoàn toàn.
    #
    # Thứ kiểm được, và kiểm thẳng: VĂN BẢN công thức trong tệp app vừa ghi.
    "$SOFFICE" --headless --convert-to csv --outdir "$WORK/out" \
        "$WORK/in/cong-thuc.xlsx" >/dev/null 2>&1
    if [ -s "$WORK/out/cong-thuc.csv" ] && grep -q "HANG-MOI" "$WORK/out/cong-thuc.csv"; then
        ok "LibreOffice mở được tệp app vừa chèn hàng, và thấy hàng mới"
    else
        no "LibreOffice KHÔNG mở được tệp sau khi chèn hàng ở giữa"
    fi

    if python3 - "$WORK/in/cong-thuc.xlsx" <<'PY'
import sys, zipfile, re
with zipfile.ZipFile(sys.argv[1]) as z:
    name = [n for n in z.namelist() if n.startswith("xl/worksheets/sheet")][0]
    xml = z.read(name).decode()
formulas = re.findall(r"<f>(.*?)</f>", xml)
# Chèn một hàng trước hàng 3: công thức trên chỗ chèn giữ nguyên, dưới trôi xuống một bậc.
sys.exit(0 if formulas == ["A2*2", "A4*2"] else print("thấy", formulas) or 1)
PY
    then
        ok "công thức đã dịch theo hàng: A2*2 giữ nguyên, A3*2 → A4*2"
    else
        no "công thức KHÔNG dịch theo hàng sau khi chèn"
    fi

    "$SOFFICE" --headless --convert-to "txt:Text (encoded):UTF8" --outdir "$WORK/out" \
        "$WORK/in/tai-lieu.docx" >/dev/null 2>&1
    if grep -q "GEDITOR-E2E" "$WORK/out/tai-lieu.txt" 2>/dev/null; then
        ok "LibreOffice thấy đoạn app vừa sửa trong .docx"
    else
        no "LibreOffice KHÔNG thấy đoạn app vừa sửa trong .docx"
    fi
    if grep -q "GEDITOR-E2E-DOAN-MOI" "$WORK/out/tai-lieu.txt" 2>/dev/null; then
        ok "LibreOffice thấy đoạn app vừa THÊM vào .docx"
    else
        no "LibreOffice KHÔNG thấy đoạn app vừa thêm vào .docx"
    fi
else
    echo "   ⏭  bỏ qua — không có LibreOffice"
fi
echo

echo "──────────────────────────────────────────"
if [ "$fail" = "0" ]; then
    echo "Đạt $pass/$pass"
    exit 0
fi
echo "TRƯỢT $fail/$((pass + fail))"
exit 1
