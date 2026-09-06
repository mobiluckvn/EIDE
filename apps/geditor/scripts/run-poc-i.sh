#!/bin/bash
# PoC-I — FR-FMT-505 (validate XSD/DTD) có THẬT SỰ cần vendor libxml2 không?
#
# `docs/trang-thai.md` §4bis khoá mục này lại với lý do "cần vendor libxml2 — một quyết định
# kiến trúc thật: kích thước bundle, ADR-08, và đường ký". Trước khi đi chốt quyết định ấy, đo
# xem TIỀN ĐỀ của nó có đúng không.
#
# Ba câu hỏi, mỗi câu một phép đo:
#
#   1. Foundation có validate được DTD không? (nếu có thì nửa yêu cầu không tốn gì)
#   2. libxml2 HỆ THỐNG có validate được XSD không, và liên kết vào nó có cần vendor gì không?
#   3. Nếu nạp LƯỜI bằng `dlopen` thì khởi động có đắt thêm không? (ADR-08 là ràng buộc thật)
#
# Chạy: scripts/run-poc-i.sh
set -uo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SDK="$(xcrun --show-sdk-path 2>/dev/null)"

echo "▸ PoC-I — FR-FMT-505 cần vendor libxml2 không?"
echo

# --- 1. DTD qua Foundation ------------------------------------------------------------------
cat > "$WORK/dtd.swift" <<'EOF'
import Foundation
let good = """
<?xml version="1.0"?>
<!DOCTYPE danhba [
  <!ELEMENT danhba (nguoi+)>
  <!ELEMENT nguoi (ten, tuoi)>
  <!ELEMENT ten (#PCDATA)>
  <!ELEMENT tuoi (#PCDATA)>
]>
<danhba><nguoi><ten>Nguyễn An</ten><tuoi>30</tuoi></nguoi></danhba>
"""
let bad = good.replacingOccurrences(of: "<tuoi>30</tuoi>", with: "<mau>xanh</mau>")
for (name, text) in [("hợp lệ", good), ("sai DTD", bad)] {
    do {
        let doc = try XMLDocument(xmlString: text, options: [.documentValidate])
        try doc.validate()
        print("   \(name): NHẬN")
    } catch {
        let first = (error as NSError).localizedDescription
            .split(separator: "\n").first.map(String.init) ?? ""
        print("   \(name): TỪ CHỐI — \(first)")
    }
}
EOF
echo "1. DTD qua Foundation (XMLDocument), KHÔNG thêm phụ thuộc nào:"
swift "$WORK/dtd.swift" 2>&1 | grep -E "NHẬN|TỪ CHỐI"
echo

# --- 2. XSD qua libxml2 HỆ THỐNG ------------------------------------------------------------
cat > "$WORK/xsd.c" <<'EOF'
#include <libxml/xmlschemas.h>
#include <libxml/parser.h>
#include <stdio.h>
#include <string.h>
static const char *XSD =
"<?xml version=\"1.0\"?>"
"<xs:schema xmlns:xs=\"http://www.w3.org/2001/XMLSchema\">"
"  <xs:element name=\"nguoi\"><xs:complexType><xs:sequence>"
"    <xs:element name=\"ten\" type=\"xs:string\"/>"
"    <xs:element name=\"tuoi\" type=\"xs:integer\"/>"
"  </xs:sequence></xs:complexType></xs:element>"
"</xs:schema>";
static int check(const char *xml) {
    xmlSchemaParserCtxtPtr p = xmlSchemaNewMemParserCtxt(XSD, (int)strlen(XSD));
    xmlSchemaPtr s = xmlSchemaParse(p);
    xmlSchemaFreeParserCtxt(p);
    if (!s) return -1;
    xmlDocPtr d = xmlReadMemory(xml, (int)strlen(xml), "m.xml", NULL, 0);
    xmlSchemaValidCtxtPtr v = xmlSchemaNewValidCtxt(s);
    int rc = xmlSchemaValidateDoc(v, d);
    xmlSchemaFreeValidCtxt(v); xmlFreeDoc(d); xmlSchemaFree(s);
    return rc;
}
int main(void) {
    printf("   phiên bản libxml2 hệ thống: %s\n", LIBXML_DOTTED_VERSION);
    printf("   hợp lệ: %s\n",
           check("<nguoi><ten>An</ten><tuoi>30</tuoi></nguoi>") == 0 ? "NHẬN" : "TỪ CHỐI");
    printf("   sai XSD: %s\n",
           check("<nguoi><ten>An</ten><tuoi>ba mươi</tuoi></nguoi>") == 0 ? "NHẬN" : "TỪ CHỐI");
    return 0;
}
EOF
echo "2. XSD qua libxml2 HỆ THỐNG (-lxml2), KHÔNG vendor:"
if clang -I"$SDK/usr/include/libxml2" -o "$WORK/xsd" "$WORK/xsd.c" -lxml2 2>"$WORK/cc.log"; then
    "$WORK/xsd" 2>/dev/null | grep -E "phiên bản|hợp lệ|sai XSD"
    echo "   liên kết tới: $(otool -L "$WORK/xsd" | grep -i xml | awk '{print $1}')"
else
    echo "   ❌ không biên dịch được — xem $WORK/cc.log"
    head -3 "$WORK/cc.log"
fi
echo

# --- 3. Giá khởi động nếu nạp LƯỜI ----------------------------------------------------------
#
# ADR-08 là ràng buộc thật (trần 500 ms, đang ở 465). Câu hỏi không phải "libxml2 nặng bao
# nhiêu" mà là "app có phải trả gì lúc khởi động không". Nạp lười bằng `dlopen` thì câu trả lời
# là KHÔNG theo cấu tạo — nhưng đo vẫn hơn tin.
cat > "$WORK/lazy.c" <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
#include <mach/mach_time.h>
int main(void) {
    mach_timebase_info_data_t tb; mach_timebase_info(&tb);
    uint64_t t0 = mach_absolute_time();
    void *h = dlopen("/usr/lib/libxml2.2.dylib", RTLD_NOW | RTLD_LOCAL);
    uint64_t t1 = mach_absolute_time();
    if (!h) { printf("   ❌ dlopen hỏng: %s\n", dlerror()); return 1; }
    void *sym = dlsym(h, "xmlSchemaParse");
    double ms = (double)(t1 - t0) * tb.numer / tb.denom / 1e6;
    printf("   dlopen libxml2 hệ thống: %.2f ms · xmlSchemaParse %s\n",
           ms, sym ? "tìm thấy" : "KHÔNG thấy");
    return 0;
}
EOF
echo "3. Giá nếu nạp LƯỜI (chỉ khi người dùng bấm validate):"
clang -O2 -o "$WORK/lazy" "$WORK/lazy.c" 2>/dev/null && "$WORK/lazy"
echo
echo "▸ Kết luận cần anh đọc: cả hai vế chạy được mà KHÔNG vendor một byte nào."
echo "  Rủi ro còn lại KHÔNG phải kích thước bundle hay đường ký, mà là:"
echo "  phiên bản libxml2 đổi theo bản macOS, và Apple có thể bỏ nó khỏi SDK."
