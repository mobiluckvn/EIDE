import Foundation

extension HelpVI {

    static let tuDongHoa = HelpChapter(
        id: "tu-dong-hoa",
        title: "Macro và tự động hoá",
        summary: "Ghi lại thao tác, chạy hàng loạt, viết script, và điều khiển từ dòng lệnh.",
        topics: [macroCoBan, macroChayHangLoat, macroCuPhap, script, locQuaLenhNgoai,
                 dongLenh, appleScript, plugin]
    )

    // MARK: - Macro cơ bản

    static let macroCoBan = HelpTopic(
        id: "macro-co-ban",
        title: "Ghi và phát macro",
        summary: "Ghi lại một chuỗi thao tác rồi lặp lại — cả lần chạy là một bước hoàn tác.",
        keywords: ["macro", "ghi", "record", "phát lại", "lặp", "tự động"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Bắt đầu / dừng ghi"),
                HelpShortcut("⌃P", "Phát lại"),
            ]),
            .steps([
                "`⌃R` bắt đầu ghi.",
                "Làm việc bạn muốn lặp — gõ chữ, di chuyển con nháy, tìm, thay thế.",
                "`⌃R` lần nữa để dừng.",
                "`⌃P` phát lại, hoặc `Macro ▸ Phát đến cuối tài liệu` để chạy tới hết.",
                "`Macro ▸ Lưu macro…` đặt tên để dùng lại ở những phiên sau.",
            ]),
            .heading("Ghi LỆNH, không ghi phím thô"),
            .paragraph("""
                Macro lưu lại **việc bạn làm**, không phải phím bạn bấm. Nhờ vậy nó không phụ thuộc \
                bố cục bàn phím, không phụ thuộc bộ gõ đang bật, và mở tệp macro ra là **đọc hiểu \
                được**.
                """),
            .heading("Macro dừng khi nào"),
            .table(
                headers: ["Lý do dừng", "Nghĩa"],
                rows: [
                    ["Chạy hết số lần", "Bình thường"],
                    ["Bước `find` không tìm thấy", "Đây là cách \"chạy đến cuối tệp\" tự dừng"],
                    ["Tới cuối tài liệu", "Không đi tiếp được"],
                    ["Bạn huỷ", "`Macro ▸ Hủy macro đang chạy`"],
                    ["Một vòng lặp không làm gì và không dịch chuyển", "Dừng để khỏi chạy mãi"],
                ]
            ),
            .note("""
                Cả lần chạy — dù lặp mười nghìn lần — là **một** bước hoàn tác.
                """),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    // MARK: - Chạy hàng loạt

    static let macroChayHangLoat = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Chạy macro hàng loạt",
        summary: "Trên mọi tab đang mở, hoặc trên cả một thư mục tệp chưa mở.",
        keywords: ["batch", "hàng loạt", "mọi tab", "thư mục", "macro"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Lệnh", "Phạm vi", "Lùi lại được không"],
                rows: [
                    ["Chạy trên mọi tab", "Các tab đang mở", "Có — mỗi tab một bước hoàn tác"],
                    ["Chạy trên cả thư mục…", "Tệp **chưa mở** trên đĩa", "Không"],
                ]
            ),
            .warning("""
                Chạy trên cả thư mục đụng tới tệp không mở trong bất kỳ tab nào, nên **không có \
                bước lùi**. Mặc định GEditor **ghi ra tệp mới**, không đè lên tệp gốc. Hãy giữ \
                mặc định ấy trừ khi bạn có bản sao lưu hoặc một kho mã đang theo dõi.
                """),
            .heading("Lọc tệp bằng mask"),
            .paragraph("""
                Hộp chọn thư mục có một ô **lọc tên tệp**: gõ `*.csv;*.log` thì macro chỉ chạm tới \
                những tệp ấy. Cùng cú pháp mask mà `Tìm trong cả thư mục` dùng, và nhiều mẫu ngăn \
                nhau bằng `;` hoặc `,`.
                """),
            .bullets([
                "Để **trống** thì lấy mọi tệp văn bản mà GEditor đọc được — hành vi như trước.",
                "Mask **thay** cho bảng đuôi ấy chứ không lọc thêm sau nó: gõ `*.bak` là chạy trên tệp `.bak`, dù đuôi ấy không nằm trong danh sách văn bản.",
                "Không tệp nào khớp thì thông báo **nhắc lại chính cái mask**, không đổ cho thư mục rỗng.",
            ]),
            .paragraph("""
                Ô này có lý do rất thực tế: một thư mục có 400 tệp `.json` và 12 tệp `.log`, mà \
                macro của bạn chỉ để dọn log. Không có mask thì 400 tệp kia cũng bị chạy qua — và \
                vì batch ghi ra tệp mới, nhầm là để lại 400 tệp rác.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    // MARK: - Cú pháp macro

    static let macroCuPhap = HelpTopic(
        id: "macro-cu-phap",
        title: "Cú pháp tệp macro",
        summary: "Bảy loại bước, định dạng JSON đầy đủ, và hai macro mẫu chạy được.",
        keywords: ["macro", "json", "cú pháp", "định dạng", "sửa tay", "chia sẻ"],
        blocks: [
            .paragraph("""
                Mỗi macro là **một tệp JSON riêng** trong thư mục `macros/` của GEditor. Hỏng thì \
                hỏng lẻ một macro, và gửi cho đồng nghiệp chỉ cần gửi một tệp.
                """),
            .code(
                language: "text",
                caption: "Nơi để tệp",
                source: """
                    ~/Library/Application Support/GEditor/macros/<ten-macro>.json
                    """
            ),
            .heading("Bảy loại bước"),
            .table(
                headers: ["Bước", "Viết", "Nghĩa"],
                rows: [
                    ["Gõ chữ", "`{\"insert\": {\"_0\": \"chữ\"}}`", "Gõ tại con nháy; có vùng chọn thì thay vùng ấy"],
                    ["Xoá lùi", "`{\"deleteBackward\": {}}`", "Như phím Delete"],
                    ["Xoá tiến", "`{\"deleteForward\": {}}`", "Như phím ⌦"],
                    ["Di chuyển", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Xem bảng hướng bên dưới"],
                    ["Chọn cả dòng", "`{\"selectLine\": {}}`", "Không kể ký tự xuống dòng"],
                    ["Tìm", "`{\"find\": { … }}`", "Tìm và **chọn** chỗ khớp kế tiếp"],
                    ["Thay vùng chọn", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` dùng được nếu bước ngay trước là `find` bằng regex"],
                ]
            ),
            .heading("Hướng di chuyển"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Bước `find` đầy đủ"),
            .code(
                language: "json",
                caption: "Bốn khoá của bước find",
                source: """
                    {
                      "find": {
                        "pattern": "^([a-z]{2})\\\\t",
                        "mode": "regex",
                        "matchCase": false,
                        "wholeWord": false
                      }
                    }
                    """
            ),
            .paragraph("`mode` nhận `normal`, `extended` hoặc `regex` — cùng ba chế độ của ô tìm."),
            .heading("Macro mẫu 1 — viết hoa mã tỉnh ở đầu mỗi dòng"),
            .code(
                language: "json",
                caption: "macros/hoa-ma-tinh.json",
                source: """
                    {
                      "name": "Hoa mã tỉnh",
                      "steps": [
                        {
                          "find": {
                            "pattern": "^([a-z]{2,3})\\\\t",
                            "mode": "regex",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "replaceSelection": { "_0": "\\\\U$1\\\\E\\t" } }
                      ]
                    }
                    """
            ),
            .paragraph("""
                Chạy nó bằng `Macro ▸ Phát đến cuối tài liệu`: bước `find` không còn tìm thấy gì \
                nữa chính là điều kiện dừng.
                """),
            .heading("Macro mẫu 2 — xoá dòng đứng ngay sau mỗi dòng chứa TODO"),
            .code(
                language: "json",
                caption: "macros/xoa-dong-sau-todo.json",
                source: """
                    {
                      "name": "Xoá dòng sau TODO",
                      "steps": [
                        {
                          "find": {
                            "pattern": "TODO",
                            "mode": "normal",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "move": { "_0": "nextLine" } },
                        { "move": { "_0": "lineStart" } },
                        { "selectLine": {} },
                        { "deleteForward": {} },
                        { "deleteForward": {} }
                      ]
                    }
                    """
            ),
            .warning("""
                Macro sửa tay thì nên thử trên một bản sao trước. Một bước `find` viết sai khiến \
                macro dừng ngay lập tức — đó là trường hợp lành. Trường hợp không lành là một mẫu \
                khớp rộng hơn bạn tưởng, và nó sửa hàng nghìn chỗ trong một bước hoàn tác.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    // MARK: - Script

    static let script = HelpTopic(
        id: "script",
        title: "Script JavaScript",
        summary: "Bốn hàm, một tệp `.js`, và mọi thứ nó làm là một bước hoàn tác.",
        keywords: ["script", "javascript", "js", "tự động", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Đặt tệp `.js` vào thư mục `scripts/` của GEditor, rồi chạy từ `Macro ▸ Script…`. \
                Script thấy đúng **bốn** thứ:
                """),
            .table(
                headers: ["Gọi", "Nghĩa"],
                rows: [
                    ["`doc.text`", "Toàn văn tài liệu"],
                    ["`doc.selection`", "Phần đang chọn (chuỗi rỗng nếu không chọn gì)"],
                    ["`doc.replace(s)`", "Thay **toàn văn** bằng `s` — một bước hoàn tác"],
                    ["`doc.log(s)`", "Ghi một dòng ra bảng kết quả"],
                ]
            ),
            .code(
                language: "javascript",
                caption: "scripts/danh-so-dong.js",
                source: """
                    // Đánh số thứ tự cho từng dòng.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Đã đánh số " + (lines.length - 1) + " dòng");
                    doc.replace(out.join("\\n"));
                    """
            ),
            .code(
                language: "javascript",
                caption: "scripts/bo-cot-thua.js — giữ ba cột đầu của một tệp CSV",
                source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Đã cắt " + out.length + " dòng còn 3 cột");
                    doc.replace(out.join("\\n"));
                    """
            ),
            .heading("Ba giới hạn phải biết"),
            .bullets([
                "**Không truy cập tệp, không mạng, không tạo tiến trình.** Bề mặt API cố ý hẹp: mở rộng về sau thì dễ, thu hẹp lại thì phá mọi script người dùng đã viết.",
                "**Đây không phải hàng rào an ninh.** Script chạy trong cùng tiến trình. Đừng chạy script bạn không đọc.",
                "**Có hạn giờ 5 giây.** Quá hạn thì bạn nhận thông báo và ứng dụng vẫn dùng được — nhưng luồng chạy script kia **vẫn quay tới khi thoát app**, ăn một lõi CPU. Cái giá ấy được nói ra ngay trong thông báo.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    // MARK: - Lọc qua lệnh ngoài

    static let locQuaLenhNgoai = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Lọc qua lệnh ngoài",
        summary: "Đưa vùng chọn qua một lệnh Unix rồi lấy kết quả về.",
        keywords: ["filter", "lệnh ngoài", "shell", "pipe", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Vùng chọn (hoặc cả tài liệu) được đưa vào `stdin` của một lệnh, và `stdout` của \
                lệnh ấy thay lại chỗ cũ.
                """),
            .code(
                language: "bash",
                caption: "Vài lệnh hay dùng",
                source: """
                    sort -u                     # sắp và bỏ trùng
                    jq .                        # định dạng lại JSON
                    tr 'a-z' 'A-Z'              # viết hoa
                    grep -v '^#'                # bỏ dòng chú thích
                    awk -F, '{print $3","$1}'   # đảo thứ tự cột
                    """
            ),
            .note("""
                Kết quả là **một** bước hoàn tác. Lệnh trả mã lỗi thì GEditor giữ nguyên văn bản \
                và hiện `stderr`.
                """),
            .warning("""
                Lệnh này **chỉ có ở bản tải trực tiếp**. App Sandbox cấm chạy mã ngoài ứng dụng, \
                nên ở bản App Store mục menu vẫn còn nhưng nói rõ vì sao không dùng được.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    // MARK: - CLI

    static let dongLenh = HelpTopic(
        id: "dong-lenh",
        title: "Công cụ dòng lệnh `geditor`",
        summary: "Mở tệp, làm sạch, truy vấn, chấm chất lượng và dựng báo cáo — không cần mở app.",
        keywords: ["cli", "dòng lệnh", "terminal", "geditor", "script", "ci"],
        blocks: [
            .warning("""
                Chỉ có ở **bản tải trực tiếp**. Bản App Store chạy trong sandbox, nên tiến trình \
                dòng lệnh bên ngoài không nối được vào ứng dụng.
                """),
            .heading("Mở tệp"),
            .code(
                language: "bash",
                caption: "Mở, nhảy tới vị trí, đọc từ ống dẫn",
                source: """
                    geditor bao-cao.csv
                    geditor bao-cao.csv:120:5      # dòng 120, cột 5
                    geditor -w ghi-chu.md          # chờ tới khi đóng tệp rồi mới thoát
                    geditor -r nhat-ky.log         # mở ở chế độ chỉ đọc
                    git diff | geditor             # đọc stdin thành tab mới
                    """
            ),
            .table(
                headers: ["Tuỳ chọn", "Nghĩa"],
                rows: [
                    ["`-w`, `--wait`", "Chờ tới khi đóng tệp rồi mới thoát — dùng làm trình soạn cho `git`"],
                    ["`-n`, `--new-window`", "Mở trong cửa sổ mới"],
                    ["`-r`, `--read-only`", "Mở ở chế độ chỉ đọc"],
                    ["`-i`, `--info`", "In bảng mã, kiểu xuống dòng, số dòng rồi thoát — **không** mở app"],
                    ["`-h`, `--help`", "Hiện trợ giúp"],
                    ["`-v`, `--version`", "Hiện phiên bản"],
                ]
            ),
            .heading("Chạy không cần mở ứng dụng"),
            .paragraph("""
                Bốn nhóm lệnh dưới đây chạy **thẳng trong tiến trình dòng lệnh**, nên dùng được \
                trong CI nơi không có ai đăng nhập đồ hoạ.
                """),
            .code(
                language: "bash",
                caption: "Làm sạch theo công thức",
                source: """
                    geditor --recipe chuan.json --dry-run ban-hang-*.csv
                    geditor --recipe chuan.json --out ./sach/ ban-hang-*.csv
                    geditor --recipe chuan.json --overwrite ban-hang-08.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "Truy vấn",
                source: """
                    geditor --query tong-hop.sql --param thang=8 \\
                            --format md --out ket-qua.md ban-hang.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "Cổng chất lượng — mã thoát 0 đạt · 1 trượt · 2 lỗi",
                source: """
                    geditor --quality chuan.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            ban-hang-09.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "Dựng báo cáo",
                source: """
                    geditor --report mau.greport.md --param-list danh-sach.csv --out ./bao-cao/
                    """
            ),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    // MARK: - AppleScript

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript và menu Services",
        summary: "Đọc và ghi tài liệu từ AppleScript, hoặc gửi văn bản sang GEditor từ ứng dụng khác.",
        keywords: ["applescript", "osascript", "services", "automation", "shortcuts"],
        blocks: [
            .code(
                language: "applescript",
                caption: "Đọc nội dung tài liệu đang mở",
                source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "Ghi đè nội dung, và lấy phần đang chọn",
                source: """
                    tell application "GEditor"
                        set selected text to "chữ thay vào chỗ đang chọn"
                        set noi_dung to document text
                        get document path
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "Mở một tệp",
                source: """
                    tell application "GEditor"
                        open POSIX file "/Users/ban/bao-cao.csv"
                    end tell
                    """
            ),
            .heading("Menu Services"),
            .paragraph("""
                Chọn văn bản trong bất kỳ ứng dụng nào, rồi dùng menu `Services` để gửi nó sang \
                GEditor thành một tab mới.
                """),
            .note("""
                Lần đầu chạy AppleScript, macOS sẽ hỏi quyền Automation. Đây là hộp thoại của hệ \
                điều hành, không phải của GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    // MARK: - Plugin

    static let plugin = HelpTopic(
        id: "plugin",
        title: "Gói mở rộng và plugin",
        summary: "Hai loại mở rộng, và loại nào chạy được ở bản nào.",
        keywords: ["plugin", "gói mở rộng", "extension", "package", "native"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Gói mở rộng"),
            .paragraph("""
                Một gói là **một tệp JSON** gói theme, script và ngôn ngữ tự định nghĩa lại với \
                nhau. Cài là chép tệp, gỡ là xoá tệp — và danh sách gói suy ra từ **đĩa**, không \
                từ một cuốn sổ có thể nói dối.
                """),
            .paragraph("Chạy được ở **cả hai bản phát hành**."),
            .heading("Plugin native"),
            .paragraph("""
                Plugin biên dịch sẵn, chạy trong **tiến trình riêng** với bề mặt API hẹp — plugin \
                hỏng thì không kéo theo ứng dụng.
                """),
            .warning("""
                Plugin native **chỉ có ở bản tải trực tiếp**, vì App Sandbox cấm nạp mã ngoài \
                ứng dụng. Mỗi plugin phải được **duyệt tay một lần** theo mã băm trước khi chạy.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )
}
