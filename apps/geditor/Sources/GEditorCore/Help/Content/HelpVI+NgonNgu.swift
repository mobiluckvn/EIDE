import Foundation

extension HelpVI {

    static let ngonNgu = HelpChapter(
        id: "ngon-ngu",
        title: "Ngôn ngữ và định dạng",
        summary: "Hai mươi ngôn ngữ dựng sẵn, ngôn ngữ tự định nghĩa, và công cụ cho JSON · XML · YAML · log.",
        topics: [ngonNguDungSan, ngonNguTuDinhNghia, congCuJSON, jsonPath, congCuXML, congCuYAML,
                 dinhDangLog]
    )

    // MARK: - Ngôn ngữ dựng sẵn

    static let ngonNguDungSan = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Hai mươi ngôn ngữ dựng sẵn",
        summary: "Tô màu theo cây cú pháp thật, kèm bảng dấu chú thích của từng ngôn ngữ.",
        keywords: ["syntax", "tô màu", "highlight", "ngôn ngữ", "tree-sitter", "grammar"],
        blocks: [
            .paragraph("""
                Ngôn ngữ nhận ra theo **đuôi tệp** (và vài tên tệp đặc biệt như `Makefile`, \
                `Dockerfile`, `Gemfile`). Đổi tay được ở thanh trạng thái.
                """),
            .table(
                headers: ["Ngôn ngữ", "Đuôi tệp", "Chú thích dòng · khối"],
                rows: [
                    ["Shell", "`sh` `bash` `zsh` `command`", "`#` · —"],
                    ["C", "`c` `h`", "`//` · `/* */`"],
                    ["C++", "`cpp` `cc` `cxx` `hpp` `hh` `hxx`", "`//` · `/* */`"],
                    ["C#", "`cs`", "`//` · `/* */`"],
                    ["CSS", "`css`", "— · `/* */`"],
                    ["Go", "`go`", "`//` · `/* */`"],
                    ["HTML", "`html` `htm` `xhtml`", "— · `<!-- -->`"],
                    ["Java", "`java`", "`//` · `/* */`"],
                    ["JavaScript", "`js` `mjs` `cjs` `jsx`", "`//` · `/* */`"],
                    ["JSON", "`json` `jsonl` `geojson`", "— · —"],
                    ["Lua", "`lua`", "`--` · `--[[ ]]`"],
                    ["PHP", "`php` `phtml`", "`//` · `/* */`"],
                    ["Python", "`py` `pyw` `pyi`", "`#` · —"],
                    ["Regex", "—", "— · —"],
                    ["Ruby", "`rb` `rake` `gemspec`", "`#` · —"],
                    ["Rust", "`rs`", "`//` · `/* */`"],
                    ["TOML", "`toml`", "`#` · —"],
                    ["TypeScript", "`ts` `mts` `cts`", "`//` · `/* */`"],
                    ["XML", "`xml` `xsd` `xsl` `svg` `plist`", "— · `<!-- -->`"],
                    ["YAML", "`yaml` `yml`", "`#` · —"],
                ]
            ),
            .paragraph("""
                Cột cuối là dấu mà `⌘/` dùng. Ngôn ngữ không có chú thích dòng (JSON, CSS, XML) \
                thì `⌘/` dùng chú thích khối.
                """),
            .heading("Những gì đi kèm cây cú pháp"),
            .bullets([
                "**Danh sách hàm** ở sidebar theo cấu trúc thật, không đoán theo thụt lề.",
                "**Gấp khối** theo cấu trúc.",
                "**Khớp cặp ngoặc** biết bỏ qua ngoặc nằm trong chuỗi và trong chú thích.",
                "**Tự động thụt lề** thêm một bậc sau `{`, và sau `:` với Python và YAML.",
            ]),
            .note("""
                Ba grammar nặng (C++, C#, Ruby) nằm trong một thư viện **nạp lười** — chúng chỉ \
                được nạp khi bạn mở một tệp thuộc ba ngôn ngữ ấy. Đó là cách thời gian khởi động \
                giữ được dưới nửa giây.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    // MARK: - UDL

    static let ngonNguTuDinhNghia = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Ngôn ngữ tự định nghĩa",
        summary: "Tô màu cho định dạng riêng của bạn bằng một tệp JSON — không cần viết grammar.",
        keywords: ["udl", "user defined language", "tự định nghĩa", "ngôn ngữ riêng", "log riêng"],
        blocks: [
            .paragraph("""
                Định dạng log nội bộ của công ty, một ngôn ngữ cấu hình riêng, một DSL nhỏ — những \
                thứ ấy không có grammar tree-sitter, và viết một grammar thì cần trình biên dịch \
                cùng hiểu biết về phân tích cú pháp.
                """),
            .paragraph("""
                Thay vào đó, GEditor nhận một **bộ quét từ vựng theo bảng**, khai bằng JSON. Đặt \
                tệp vào thư mục `grammars/` trong thư mục cấu hình của GEditor, rồi mở lại app.
                """),
            .code(
                language: "json",
                caption: "grammars/nhat-ky-noi-bo.json — một ngôn ngữ hoàn chỉnh",
                source: """
                    {
                      "name": "Nhật ký nội bộ",
                      "extensions": ["nklog", "trace"],
                      "caseSensitive": false,
                      "lineComment": ";",
                      "blockComment": ["/*", "*/"],
                      "stringDelimiters": ["\\"", "'"],
                      "escapeCharacter": "\\\\",
                      "keywordGroups": {
                        "keyword": ["BEGIN", "END", "RETRY", "COMMIT", "ROLLBACK"],
                        "type":    ["INT", "TEXT", "DATE", "MONEY"],
                        "constant": ["TRUE", "FALSE", "NULL"]
                      }
                    }
                    """
            ),
            .heading("Từng khoá"),
            .table(
                headers: ["Khoá", "Kiểu", "Nghĩa"],
                rows: [
                    ["`name`", "chuỗi", "Tên hiện ở thanh trạng thái"],
                    ["`extensions`", "mảng chuỗi", "Đuôi tệp, **không có dấu chấm**"],
                    ["`caseSensitive`", "đúng/sai", "Từ khoá có phân biệt hoa thường không"],
                    ["`lineComment`", "chuỗi", "Dấu chú thích tới hết dòng; bỏ qua nếu không có"],
                    ["`blockComment`", "mảng 2 chuỗi", "`[mở, đóng]`"],
                    ["`stringDelimiters`", "mảng chuỗi", "Mỗi phần tử là **một** ký tự mở/đóng chuỗi"],
                    ["`escapeCharacter`", "chuỗi", "Ký tự thoát trong chuỗi; rỗng = ngôn ngữ không có escape"],
                    ["`keywordGroups`", "bảng", "Tên nhóm → danh sách từ khoá; ba nhóm tô ba màu"],
                ]
            ),
            .paragraph("""
                Ba tên nhóm được tô màu riêng là `keyword`, `type` và `constant`.
                """),
            .warning("""
                Bộ quét này **không hiểu cấu trúc lồng nhau**. Gấp khối theo cú pháp, danh sách \
                hàm và khớp ngoặc thông minh vẫn chỉ có ở hai mươi ngôn ngữ dựng sẵn. Đây là đánh \
                đổi có chủ ý: đổi lấy việc bạn khai một ngôn ngữ trong mười phút thay vì một ngày.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    // MARK: - JSON

    static let congCuJSON = HelpTopic(
        id: "cong-cu-json",
        title: "Công cụ JSON",
        summary: "Định dạng lại, thu gọn, sắp xếp khoá, và kiểm theo JSON Schema.",
        keywords: ["json", "format", "pretty", "minify", "schema", "định dạng"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Lệnh", "Làm gì"],
                rows: [
                    ["Định dạng lại", "Xuống dòng và thụt lề cho dễ đọc"],
                    ["Thu gọn một dòng", "Bỏ hết khoảng trắng thừa"],
                    ["Sắp xếp khoá", "Sắp khoá của mọi object theo bảng chữ cái — để **diff** hai tệp JSON so được với nhau"],
                    ["Kiểm theo JSON Schema…", "Đối chiếu tài liệu với một tệp schema, liệt kê chỗ sai kèm số dòng"],
                ]
            ),
            .paragraph("""
                Luật áp dụng là **RFC 8259 nghiêm ngặt**: không dấu phẩy thừa, không chú thích, \
                không `NaN`. Tệp sai cú pháp thì lỗi chỉ đúng dòng và cột.
                """),
            .note("""
                Tệp **JSONL** (mỗi dòng một object) cũng nhận ra được, và có bộ công cụ riêng ở \
                chương gói tri thức.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    // MARK: - JSONPath

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "Truy vấn JSONPath",
        summary: "Rút đúng phần cần từ một tệp JSON lớn.",
        keywords: ["jsonpath", "truy vấn json", "query", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Gõ một biểu thức, kết quả hiện thành danh sách và nhảy tới được."),
            .table(
                headers: ["Viết", "Nghĩa"],
                rows: [
                    ["`$`", "Gốc tài liệu"],
                    ["`$.ten`", "Khoá `ten` ở gốc"],
                    ["`$.don_hang[0]`", "Phần tử đầu của mảng"],
                    ["`$.don_hang[*].tong`", "Khoá `tong` của **mọi** phần tử"],
                    ["`$..ma_tinh`", "Khoá `ma_tinh` ở **bất kỳ độ sâu nào**"],
                    ["`$.don_hang[1:3]`", "Lát cắt: phần tử 1 và 2"],
                ]
            ),
            .code(
                language: "text",
                caption: "Lấy mã tỉnh của mọi đơn hàng, dù cấu trúc lồng sâu bao nhiêu",
                source: """
                    $..don_hang[*].dia_chi.ma_tinh
                    """
            ),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    // MARK: - XML

    static let congCuXML = HelpTopic(
        id: "cong-cu-xml",
        title: "Công cụ XML",
        summary: "Định dạng lại, thu gọn, kiểm cú pháp, và kiểm theo DTD hoặc XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "kiểm", "validate"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Lệnh", "Làm gì"],
                rows: [
                    ["Định dạng lại", "Thụt lề theo cấp thẻ"],
                    ["Thu gọn một dòng", "Bỏ khoảng trắng giữa các thẻ"],
                    ["Kiểm cú pháp", "Thẻ đóng thiếu, thẻ lồng sai, ký tự không hợp lệ"],
                    ["Kiểm theo DTD/XSD…", "Đối chiếu với lược đồ, báo chỗ sai kèm dòng"],
                    ["Đánh giá XPath…", "Chạy một biểu thức XPath, kết quả ra một tab mới"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Gõ biểu thức, kết quả mở thành **một tab văn bản** — mỗi node một dòng.                 Ví dụ: `//don_hang/hang[2]/@ma` · `//*[@loai='A']` · `count(//hang)`.
                """),
            .note("""
                **Kết quả KHÔNG nhảy tới được chỗ trong tệp gốc.** Bộ đánh giá XPath của hệ điều                 hành dựng một cây riêng và không giữ vị trí byte của từng node, nên thứ trả về là                 NỘI DUNG chứ không phải toạ độ. Cần đi tới đúng chỗ thì dùng `⌘F` trên chuỗi vừa                 tìm được.
                """),
            .paragraph("""
                Trong tệp `.xml` và `.html`, gõ `>` xong một thẻ mở thì **thẻ đóng tự hiện ra** và                 con nháy nằm giữa hai thẻ. Thẻ tự đóng (`<br/>`), khai báo (`<?xml …?>`) và chú                 thích thì không — chúng không có gì để đóng.
                """),
            .warning("""
                Định dạng lại XML **đổi khoảng trắng giữa các thẻ**. Với tài liệu mà khoảng trắng \
                có nghĩa — ví dụ XHTML có chữ trong thẻ — điều đó đổi nội dung hiển thị. Là một \
                bước hoàn tác, nên `⌘Z` lùi lại được.
                """),
        ]
    )

    // MARK: - YAML

    static let congCuYAML = HelpTopic(
        id: "cong-cu-yaml",
        title: "Kiểm YAML",
        summary: "Bắt hai lỗi YAML hay gặp nhất: khoá trùng và thụt lề lẫn TAB.",
        keywords: ["yaml", "yml", "lint", "khóa trùng", "thụt lề"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Khoá trùng** trong cùng một bảng — hầu hết bộ đọc YAML lấy khoá **cuối**, im lặng bỏ khoá trước, nên một tệp cấu hình có thể chạy hoàn toàn khác điều bạn tưởng.",
                "**Thụt lề bằng TAB** — YAML cấm TAB trong thụt lề, và lỗi báo ra từ các thư viện thường rất khó hiểu.",
            ]),
            .note("""
                Bật `Hiện ký tự ẩn ▸ Tab` để thấy ngay chỗ nào là TAB.
                """),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    // MARK: - Log

    static let dinhDangLog = HelpTopic(
        id: "dinh-dang-log",
        title: "Tệp log",
        summary: "Bảy mức nghiêm trọng, lọc theo mức, và cách đọc tệp log rất lớn.",
        keywords: ["log", "nhật ký", "error", "warning", "lọc", "mức"],
        blocks: [
            .paragraph("""
                Bật `View ▸ Chế độ Log (tô theo mức)`. GEditor đọc mức nghiêm trọng ở **phần đầu \
                mỗi dòng** — sau dấu thời gian và tên tiến trình.
                """),
            .table(
                headers: ["Mức", "Tô"],
                rows: [
                    ["CRITICAL · ERROR", "Đỏ"],
                    ["WARNING", "Vàng"],
                    ["NOTICE", "Màu nhấn"],
                    ["INFO", "Như chữ thường"],
                    ["DEBUG · TRACE", "Nhạt hẳn"],
                ]
            ),
            .paragraph("""
                `Lọc log theo mức…` giấu những mức thấp đi. Dòng **không nhận ra mức** — ví dụ \
                dòng tiếp nối của một stack trace — được để nguyên chứ không gán bừa mức của dòng \
                trước.
                """),
            .heading("Quy trình đọc một tệp log lớn"),
            .steps([
                "Mở tệp — cỡ GB vẫn mở gần như tức thì.",
                "`View ▸ Chế độ Log` để thấy ngay chỗ đỏ.",
                "`⌥⌘M` bật bản đồ tài liệu: chỗ đỏ dồn vào một quãng hay rải đều cả tệp?",
                "`⌘F` tìm mã lỗi, `⌘M` đánh dấu mọi dòng khớp.",
                "`Search ▸ Chép dòng đã đánh dấu` để lấy riêng chúng sang một tab mới.",
                "Đang chạy dở thì `File ▸ Theo dõi file (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
