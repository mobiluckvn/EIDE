"""Tìm chuỗi TIẾNG VIỆT trong tầng giao diện chưa đi qua `L()` (FR-UI-804).

**Con số này là CẬN DƯỚI, không phải con số đủ.** Từ tiếng Việt không dấu — "Cam", "Bang",
"Xoa" — không có gì phân biệt với một khoá hay một ký hiệu, nên script bỏ qua. Đã gặp thật:
trong chín tên màu đánh dấu, tám cái có dấu và "Cam" thì không. Dịch tám cái rồi bỏ cái thứ
chín là để lại một menu nửa nọ nửa kia. Đọc con số như "ít nhất ngần này", và khi dịch một
danh sách thì dịch CẢ danh sách chứ đừng dịch theo những gì script chỉ ra.

**Vì sao dò bằng DẤU TIẾNG VIỆT.** Không có cách nào từ mã nguồn mà biết chắc một chuỗi có
hiện ra cho người dùng hay không. Nhưng chuỗi mang dấu tiếng Việt thì gần như chắc chắn là câu
chữ viết cho người đọc — tên khoá, đường dẫn, ký hiệu, mã lỗi đều không có dấu. Đó là dấu hiệu
rẻ và chính xác đủ dùng.

**Vì sao bỏ qua vài tệp.** `SelfTest`, `WindowCapture`, `SoakTest` và `IdleProbe` chỉ chạy khi
có `--self-test`, `--capture`, `--soak` hoặc `--measure-idle`; chữ trong đó viết cho người sửa mã, không cho người
dùng. Dịch chúng là làm phình bảng dịch bằng thứ không ai đọc.

`OfficeE2E` cùng loại: nó chỉ chạy dưới `--office-e2e`, và chữ trong đó là báo cáo của một bộ
kiểm end-to-end, viết cho người đọc kết quả trên dòng lệnh.

`LazyLoadAudit` (ADR-14) cùng loại ấy: chữ của nó chỉ ra ngoài qua `StartupProbe.reportAndExit`
và qua bài tự kiểm — cả hai đã bỏ qua sẵn. Nó là câu nói với người vừa làm vỡ cổng nạp-lười,
và người ấy đang đọc mã nguồn chứ không đọc giao diện.

**Một điểm mù phải nói ra.** Script coi một chuỗi là "đã dịch" khi nó có mặt làm KHOÁ trong
bảng dịch — không kiểm chỗ dùng có bọc `L()` hay không. Nên thêm một dòng vào bảng mà quên bọc
`L()` ở chỗ gọi sẽ làm con số đẹp lên trong khi giao diện vẫn nguyên tiếng Việt.

Điểm mù này CỐ Ý để nguyên, không phải bị bỏ sót. Cách kiểm ngược lại — "chuỗi này có nằm trong
`L(...)` không" — chính là cách bản ĐẦU của script đã làm, và nó cho ra 983 vì thanh menu giữ
chữ trong một BẢNG tuple rồi mới bọc `L()` lúc dựng mục. Một cổng kêu sai hàng trăm lần là cổng
sẽ bị bỏ qua. Nên vế "có bọc `L()` chưa" thuộc về người review, không thuộc về script này.

Chạy: python3 scripts/scan-untranslated.py [--liet-ke]
"""
import os, re, sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "Sources", "GEditorApp")
SKIP = {"SelfTest.swift", "WindowCapture.swift", "StartupProbe.swift", "Unattended.swift",
        # `DocumentSweep` cùng loại: chỉ chạy dưới `--doc-sweep`, và chữ trong đó là một bảng
        # báo cáo đọc trên terminal — viết cho người soát tài liệu thật, không cho người dùng.
        "DocumentSweep.swift",
        "SoakTest.swift", "IdleProbe.swift", "Localization.swift", "LazyLoadAudit.swift",
        # `MermaidKPI` cùng loại với `IdleProbe`: chỉ chạy dưới `--mermaid-kpi`, và chữ trong
        # đó là ghi chú của một phép đo — kèm cả mã sơ đồ thử nghiệm, thứ không phải câu chữ
        # giao diện chút nào.
        # `OpenProbe` cùng loại với `StartupProbe`: chỉ chạy dưới `--measure-open`, và chữ trong
        # đó là kết luận của một phép đo ("trong ngân sách" / "vượt ngân sách") đọc trên terminal.
        "MermaidKPI.swift", "OfficeE2E.swift", "OpenProbe.swift"}

# Các bảng dịch `Localization+<mã>.swift` KHÔNG phải mã giao diện — chúng chỉ chứa các khoá và
# bản dịch của chúng. Quét chúng như mã thường thì mỗi khoá tiếng Việt bị đếm một lần cho MỖI
# thứ tiếng, và con số nợ nhân lên theo số ngôn ngữ chứ không theo số chuỗi chưa dịch.
BANG_DICH = re.compile(r'^Localization\+\w+\.swift$')

# Chữ cái tiếng Việt có dấu — đủ để nhận ra câu chữ cho người đọc.
VIETNAMESE = re.compile(
    "[ăâêôơưđĂÂÊÔƠƯĐáàảãạắằẳẵặấầẩẫậéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ]")
LITERAL = re.compile(r'"(?:[^"\\]|\\.)*"')


def translation_keys():
    """Mọi khoá trong bảng dịch — tức mọi chuỗi ĐÃ có bản tiếng Anh.

    Đây mới là tiêu chí đúng. Bản đầu của script này hỏi "chuỗi có nằm ngay sau `L(` không" và
    con số ra 983 — sai nặng, vì thanh menu giữ chữ trong một BẢNG tuple rồi mới bọc `L()` lúc
    dựng mục. Một chuỗi có được dịch hay không là chuyện nó có mặt trong bảng dịch, không phải
    chuyện nó viết ở đâu.

    Khoá nằm ở BẢNG TIẾNG ANH, không ở `Localization.swift`. Lúc mới viết thì hai chỗ là một;
    khi bảng tách ra thành `Localization+<mã>.swift` thì hàm này vẫn đọc tệp cũ, tập khoá thành
    RỖNG, và cổng lập tức tố cáo cả ba vạn chuỗi. Không có bài kiểm nào đỏ vì cổng vẫn "chạy" —
    nó chỉ trả lời một câu hỏi đã hết nghĩa. Nên ở đây thiếu tệp là LỖI, không phải tập rỗng.
    """
    path = os.path.join(os.path.dirname(__file__), "..", "Sources", "GEditorApp",
                        "Localization+en.swift")
    keys = set()
    for line in open(path).read().split("\n"):
        match = re.match(r'\s*"((?:[^"\\]|\\.)*)"\s*:', line)
        if match:
            keys.add(match.group(1))
    if not keys:
        raise SystemExit("❌ scan-untranslated: không đọc được khoá nào từ Localization+en.swift "
                         "— cổng này sẽ vô nghĩa nếu cứ chạy tiếp")
    return keys


def scan():
    keys = translation_keys()
    findings = []
    for name in sorted(os.listdir(ROOT)):
        if not name.endswith(".swift") or name in SKIP or BANG_DICH.match(name):
            continue
        path = os.path.join(ROOT, name)
        for number, line in enumerate(open(path).read().split("\n"), 1):
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("///"):
                continue
            # Dòng ghi nhật ký viết cho người SỬA MÃ, không cho người dùng. Dịch chúng là làm
            # phình bảng dịch bằng thứ không ai đọc — và tệ hơn, làm con số ở dưới mất nghĩa.
            if "NSLog(" in stripped or stripped.startswith("print(") or "FileHandle.standardError" in stripped:
                continue
            for match in LITERAL.finditer(line):
                text = match.group(0)[1:-1]
                if not VIETNAMESE.search(text):
                    continue
                if text in keys:
                    continue
                # Khoá bị NỐI CHUỖI qua nhiều dòng: mỗi mảnh không phải khoá, nhưng cả câu thì
                # có. Chỉ nhận mảnh ĐỦ DÀI — một từ ngắn tình cờ nằm trong khoá nào đó thì
                # không nói lên điều gì, còn một mảnh mười hai ký tự thì gần như chắc là nối.
                if len(text) >= 12 and any(text in key for key in keys):
                    continue
                # Hai loại nợ khác hẳn nhau:
                #   - chuỗi TRẦN: tra bảng được ngay, chỉ cần bọc `L()` và thêm một dòng.
                #   - chuỗi có nội suy `\(…)`: khoá dịch không thể là chính nó, phải tách thành
                #     chuỗi định dạng trước. Đó là sửa mã, không phải dịch.
                findings.append((name, number, text, "\\(" in text))
    return findings


def main():
    found = scan()
    plain = [f for f in found if not f[3]]
    interpolated = [f for f in found if f[3]]

    if "--liet-ke" in sys.argv:
        current = None
        for name, number, text, interp in found:
            if name != current:
                current = name
                print("── %s" % name)
            print("   %5d %s %s" % (number, "~" if interp else " ", text[:88]))
        print()
    print("   %d chuỗi TRẦN (bọc L() là xong) · %d chuỗi có nội suy (phải tách chuỗi định dạng)"
          % (len(plain), len(interpolated)))
    # `--tran N`: cổng CHỐT. Đỏ khi con số TĂNG, và cũng đỏ khi nó GIẢM mà quên sửa mốc.
    #
    # Chỉ chặn chiều tăng thì mốc sẽ đứng yên ở 558 mãi mãi kể cả khi nợ đã trả bớt, và một con
    # số không còn đúng thì không ai tin nó nữa. Bắt cập nhật cả hai chiều là cách duy nhất giữ
    # nó nói thật — cùng lối `SelfTest.menuItemsPendingImplementation` đã dùng: danh sách nợ
    # phải TỰ DỌN.
    if "--tran" in sys.argv:
        ceiling = int(sys.argv[sys.argv.index("--tran") + 1])
        if len(found) > ceiling:
            print("❌ FR-UI-804: %d chuỗi chưa dịch, mốc là %d — đừng thêm chữ tiếng Việt mới"
                  % (len(found), ceiling))
            print("   Xem danh sách: python3 scripts/scan-untranslated.py --liet-ke")
            return 1
        if len(found) < ceiling:
            print("❌ FR-UI-804: chỉ còn %d chuỗi chưa dịch, mốc vẫn ghi %d — hạ mốc xuống %d"
                  % (len(found), ceiling, len(found)))
            return 1
        print("✅ FR-UI-804: %d chuỗi chưa có bản dịch, đúng mốc đã chốt" % len(found))
        return 0

    print("%d chuỗi tiếng Việt chưa có bản dịch" % len(found))
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
