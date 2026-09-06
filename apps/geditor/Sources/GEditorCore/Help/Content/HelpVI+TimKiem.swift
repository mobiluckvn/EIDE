import Foundation

extension HelpVI {

    static let timKiem = HelpChapter(
        id: "tim-kiem",
        title: "Tìm kiếm",
        summary: "Tìm, thay, biểu thức chính quy, tìm cả thư mục, và đánh dấu dòng.",
        topics: [timVaThay, bieuThucChinhQuy, chuoiThayThe, timTrongThuMuc, danhDauDong, diToiDong]
    )

    // MARK: - Tìm và thay

    static let timVaThay = HelpTopic(
        id: "tim-va-thay",
        title: "Tìm và thay",
        summary: "Ba chế độ tìm, và vì sao ^ mặc định là đầu DÒNG chứ không phải đầu tài liệu.",
        keywords: ["find", "replace", "tìm", "thay thế", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Tìm"),
                HelpShortcut("⌥⌘F", "Tìm và thay"),
                HelpShortcut("⌘G / ⇧⌘G", "Kết quả kế / trước"),
            ]),
            .heading("Ba chế độ"),
            .table(
                headers: ["Chế độ", "Hiểu gì", "Dùng khi"],
                rows: [
                    ["Thường", "Chuỗi thuần, không ký tự đặc biệt nào", "Phần lớn các lần tìm"],
                    ["Mở rộng", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Tìm ký tự xuống dòng, TAB, byte cụ thể"],
                    ["Regex", "PCRE2 đầy đủ", "Khớp theo khuôn"],
                ]
            ),
            .note("""
                Chế độ **Mở rộng** không hiểu cú pháp regex. Nó chỉ dịch vài dãy thoát — nên tìm \
                `a.b` ở chế độ này là tìm đúng ba ký tự ấy, dấu chấm không phải ký tự đại diện.
                """),
            .heading("Hai công tắc"),
            .bullets([
                "**Phân biệt hoa thường** — tắt mặc định.",
                "**Nguyên từ** — chỉ khớp khi hai đầu là ranh giới từ.",
            ]),
            .heading("`^` và `$` khớp ở biên mỗi DÒNG"),
            .paragraph("""
                Mặc định bật. Người dùng đến từ Notepad++ mong `^` nghĩa là \"đầu dòng\"; nếu tắt \
                thì `^abc` chỉ khớp khi cả tài liệu bắt đầu bằng `abc` — hầu như không ai muốn thế \
                trong một trình soạn thảo.
                """),
            .heading("Một biểu thức xấu không treo ứng dụng"),
            .paragraph("""
                Bộ máy là **PCRE2 có biên dịch JIT**, và có hạn mức quay lui. Một mẫu bùng nổ tổ \
                hợp sẽ bị dừng và báo lỗi, chứ không làm cửa sổ đứng im.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    // MARK: - Regex

    static let bieuThucChinhQuy = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Biểu thức chính quy",
        summary: "Cú pháp PCRE2 hay dùng, kèm ví dụ chạy được trên dữ liệu tiếng Việt.",
        keywords: ["regex", "regexp", "pcre", "biểu thức", "pattern", "khuôn mẫu"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor dùng **PCRE2**, cùng bộ máy với PHP và nhiều công cụ dòng lệnh. Mở \
                `Search ▸ Thử biểu thức chính quy…` để thử mẫu trên văn bản mẫu và xem từng nhóm \
                bắt được gì **trước khi** áp lên tài liệu thật.
                """),
            .heading("Ký tự đại diện"),
            .table(
                headers: ["Viết", "Khớp"],
                rows: [
                    ["`.`", "Một ký tự bất kỳ, trừ ký tự xuống dòng"],
                    ["`\\d` · `\\D`", "Một chữ số · không phải chữ số"],
                    ["`\\w` · `\\W`", "Một ký tự từ (chữ, số, `_`) · ngược lại"],
                    ["`\\s` · `\\S`", "Một khoảng trắng · không phải khoảng trắng"],
                    ["`[abc]`", "Một trong các ký tự trong ngoặc"],
                    ["`[^abc]`", "Một ký tự KHÔNG nằm trong ngoặc"],
                    ["`[a-z]`", "Một ký tự trong khoảng"],
                ]
            ),
            .heading("Số lần lặp"),
            .table(
                headers: ["Viết", "Nghĩa"],
                rows: [
                    ["`*`", "Không hoặc nhiều"],
                    ["`+`", "Một hoặc nhiều"],
                    ["`?`", "Không hoặc một"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Đúng 3 lần · từ 2 đến 5 · từ 2 trở lên"],
                    ["`*?` `+?` `??`", "Bản **lười** — lấy ít nhất có thể"],
                ]
            ),
            .warning("""
                `.*` là bản **tham lam**: nó ăn tới cuối dòng rồi mới lùi. Khi tách trường trong \
                một dòng, gần như luôn phải dùng `.*?` hoặc một lớp ký tự hẹp như `[^,]*`.
                """),
            .heading("Neo và nhóm"),
            .table(
                headers: ["Viết", "Nghĩa"],
                rows: [
                    ["`^` · `$`", "Đầu dòng · cuối dòng"],
                    ["`\\b`", "Ranh giới từ"],
                    ["`(…)`", "Nhóm **có bắt** — dùng lại được trong chuỗi thay thế"],
                    ["`(?:…)`", "Nhóm không bắt"],
                    ["`(?<ten>…)`", "Nhóm có tên"],
                    ["`a|b`", "a hoặc b"],
                    ["`(?=…)` · `(?!…)`", "Nhìn trước: phải có · không được có"],
                    ["`(?<=…)` · `(?<!…)`", "Nhìn sau: phải có · không được có"],
                ]
            ),
            .heading("Ví dụ chạy được"),
            .code(
                language: "regex",
                caption: "Tìm mọi số điện thoại Việt Nam 10 chữ số",
                source: """
                    \\b0\\d{9}\\b
                    """
            ),
            .code(
                language: "regex",
                caption: "Tách ngày kiểu 31/12/2026 thành ba nhóm",
                source: """
                    (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    """
            ),
            .code(
                language: "regex",
                caption: "Lấy ô thứ ba của một dòng CSV đơn giản (không có dấu nháy)",
                source: """
                    ^[^,]*,[^,]*,([^,]*)
                    """
            ),
            .code(
                language: "regex",
                caption: "Dòng log có mức ERROR hoặc FATAL, kèm dấu thời gian",
                source: """
                    ^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b
                    """
            ),
            .code(
                language: "regex",
                caption: "Dòng trống hoặc chỉ có khoảng trắng",
                source: """
                    ^\\s*$
                    """
            ),
            .code(
                language: "regex",
                caption: "Chữ có dấu tiếng Việt — dùng lớp Unicode, không liệt kê từng chữ",
                source: """
                    \\p{L}+
                    """
            ),
            .note("""
                `\\p{L}` là \"một chữ cái bất kỳ theo Unicode\", nên nó khớp cả `ế` và `đ`. Liệt kê \
                tay từng nguyên âm có dấu là cách chắc chắn sẽ bỏ sót.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    // MARK: - Chuỗi thay thế

    static let chuoiThayThe = HelpTopic(
        id: "chuoi-thay-the",
        title: "Chuỗi thay thế",
        summary: "Dùng lại nhóm đã bắt, và đổi hoa thường ngay trong lúc thay.",
        keywords: ["replace", "thay thế", "backreference", "nhóm", "$1", "\\U"],
        blocks: [
            .heading("Gọi lại nhóm đã bắt"),
            .table(
                headers: ["Viết", "Nghĩa"],
                rows: [
                    ["`$1` … `$9`", "Nội dung nhóm thứ n"],
                    ["`${1}`", "Như trên, nhưng rõ biên — dùng khi ngay sau là chữ số"],
                    ["`\\1`", "Cũng được; GEditor tự dịch sang `${1}`"],
                    ["`$0`", "Toàn bộ chỗ khớp"],
                ]
            ),
            .note("""
                Viết `${1}` thay vì `$1` khi ký tự đứng ngay sau là một chữ số. `$123` bị hiểu là \
                nhóm 123; `${1}23` mới là nhóm 1 rồi hai chữ số.
                """),
            .heading("Đổi hoa thường trong lúc thay"),
            .table(
                headers: ["Viết", "Nghĩa"],
                rows: [
                    ["`\\U`", "Từ đây trở đi HOA"],
                    ["`\\L`", "Từ đây trở đi thường"],
                    ["`\\u`", "Chỉ ký tự kế tiếp thành hoa"],
                    ["`\\l`", "Chỉ ký tự kế tiếp thành thường"],
                    ["`\\E`", "Kết thúc vùng `\\U` hoặc `\\L`"],
                ]
            ),
            .heading("Ví dụ"),
            .code(
                language: "text",
                caption: "Đổi 31/12/2026 thành 2026-12-31",
                source: """
                    Tìm:  (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Thay: $3-$2-$1
                    """
            ),
            .code(
                language: "text",
                caption: "Viết hoa mã tỉnh ở đầu mỗi dòng, giữ nguyên phần còn lại",
                source: """
                    Tìm:  ^([a-z]{2,3})(\\s)
                    Thay: \\U$1\\E$2
                    """
            ),
            .code(
                language: "text",
                caption: "Bọc mỗi dòng thành một chuỗi JSON",
                source: """
                    Tìm:  ^(.+)$
                    Thay: "$1",
                    """
            ),
            .paragraph("""
                Nhóm **không tham gia** vào lần khớp sẽ thành chuỗi rỗng, không phải lỗi — nên một \
                mẫu có nhánh `(a)|(b)` vẫn thay được mà không cần viết hai lần.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    // MARK: - Tìm trong thư mục

    static let timTrongThuMuc = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Tìm và thay trong cả thư mục",
        summary: "Quét nhiều tệp cùng lúc, xem kết quả trước khi ghi.",
        keywords: ["find in files", "tìm trong thư mục", "grep", "thay hàng loạt"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⇧⌘F", "Tìm trong thư mục"),
            ]),
            .paragraph("""
                Chọn thư mục gốc, lọc theo mẫu tên tệp, rồi quét. Kết quả hiện thành danh sách theo \
                tệp; bấm một dòng là mở đúng tệp đúng vị trí.
                """),
            .bullets([
                "Cùng ba chế độ tìm và cùng bộ máy regex với ô tìm trong tài liệu.",
                "Thay trong thư mục cho **xem trước** số tệp và số chỗ sẽ đổi trước khi ghi.",
                "Quét chạy song song và **huỷ được giữa chừng**.",
            ]),
            .warning("""
                Thay trong thư mục ghi thẳng vào các tệp **chưa mở**. Những tệp ấy không nằm trong \
                lịch sử hoàn tác của tài liệu đang mở — hãy xem trước, và nên có bản sao lưu hoặc \
                một kho mã đang theo dõi.
                """),
            .heading("Lượt tìm trước đó, và xuất kết quả"),
            .paragraph("""
                Panel kết quả **giữ lại các lượt tìm** của phiên này. Hộp chọn ở đầu panel liệt kê \
                chúng kèm số kết quả — tìm `TODO`, đọc dở, tìm tiếp `FIXME` để so, rồi quay lại \
                danh sách đầu mà không phải quét lại cả thư mục.
                """),
            .paragraph("""
                Nút **Xuất** mở lượt đang xem thành một tab văn bản, mỗi kết quả một dòng theo dạng \
                `đường-dẫn:dòng:cột: nội dung` — đúng khuôn `grep -n` và khuôn trình biên dịch in \
                lỗi. Nghĩa là mỗi dòng dán thẳng vào ô `Đi tới` của chính sản phẩm này được, và \
                `grep`, `awk`, `sed` của bạn cũng đọc được mà không phải viết bộ tách riêng.
                """),
            .note("""
                Lịch sử sống trong **bộ nhớ**, không ghi ra đĩa: kết quả tìm mang theo nội dung \
                từng dòng của tệp bạn quét, và đó là cùng loại dữ liệu mà lịch sử clipboard đã cố ý \
                không lưu xuống.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    // MARK: - Đánh dấu dòng

    static let danhDauDong = HelpTopic(
        id: "danh-dau-dong",
        title: "Đánh dấu dòng",
        summary: "Chín màu dấu, và bốn lệnh biến vùng đã đánh dấu thành kết quả.",
        keywords: ["bookmark", "đánh dấu", "mark", "f2", "lọc dòng"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Đánh dấu là cách lọc tài liệu **mà không đổi tài liệu**. Đánh dấu mọi dòng khớp một \
                mẫu, rồi chép riêng chúng ra, hoặc giữ lại chỉ chúng.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Đánh dấu mọi dòng khớp mẫu đang tìm"),
                HelpShortcut("⌘F2", "Đánh dấu / bỏ dấu dòng hiện tại"),
                HelpShortcut("F2 / ⇧F2", "Nhảy tới dấu kế / dấu trước"),
            ]),
            .heading("Quy trình hay dùng"),
            .steps([
                "`⌘F` tìm mẫu cần lọc, ví dụ `\\bERROR\\b`.",
                "`⌘M` đánh dấu mọi dòng khớp.",
                "`Search ▸ Chép dòng đã đánh dấu` để lấy riêng chúng sang tab mới — hoặc `Chỉ giữ dòng đã đánh dấu` để lọc tại chỗ.",
            ]),
            .heading("Chín màu"),
            .paragraph("""
                Một dòng mang được **nhiều màu cùng lúc**. Dùng màu khác nhau cho các tiêu chí khác \
                nhau rồi kết hợp: ví dụ đỏ cho dòng lỗi, vàng cho dòng thuộc một mã đơn hàng, và \
                nhìn dòng nào mang cả hai.
                """),
            .bullets([
                "`Đảo dấu` — dòng có dấu thành không, và ngược lại.",
                "`Bỏ mọi dấu` — xoá sạch dấu, không đụng tới nội dung.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    // MARK: - Đi tới dòng

    static let diToiDong = HelpTopic(
        id: "di-toi-dong",
        title: "Đi tới dòng",
        summary: "Nhảy tới một dòng, một cột, hoặc một vị trí byte.",
        keywords: ["goto", "đi tới", "dòng số", "cmd+l", "offset", "vị trí", "cột"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Đi tới dòng")]),
            .paragraph("""
                Ô nhập hiểu **ba cách viết**, và phân biệt chúng bằng chính chuỗi bạn gõ — không \
                có hộp chọn kiểu nào để bấm thêm.
                """),
            .table(
                headers: ["Gõ", "Đi tới"],
                rows: [
                    ["`120`", "đầu dòng 120"],
                    ["`120,5` hoặc `120:5`", "dòng 120, cột 5 — cột đếm theo KÝ TỰ"],
                    ["`@1024`", "vị trí byte 1024 trong tệp"],
                ]
            ),
            .note("""
                `dòng:cột` là đúng cách trình biên dịch và bộ kiểm lỗi in vị trí ra, nên dòng bạn \
                vừa chép từ cửa sổ terminal dán thẳng vào đây được.

                Dấu `@` cho vị trí byte có lý do: `1234` là dòng hay là byte? Không có câu trả lời \
                đúng, và đoán sai thì con nháy nhảy tới một chỗ hoàn toàn khác mà không có gì báo. \
                Con số byte cũng là con số thanh trạng thái hiện ở mục vị trí (`@1024`), nên đọc ở \
                đâu gõ vào đây được ngay.
                """),
            .bullets([
                "Cột **vượt quá độ dài dòng** thì dừng ở cuối dòng ấy, không tràn sang dòng sau.",
                "Vị trí byte **vượt quá tệp** thì đưa bạn tới cuối tệp — bạn thường chép số ấy từ một lần chạy trước, và tệp có thể đã ngắn đi.",
                "Chuỗi không hiểu thì **nói ra** và con nháy đứng yên; không nhảy về đầu tệp.",
            ]),
            .paragraph("""
                Trên tệp rất lớn, GEditor không cần đọc cả tệp để tới nơi — bảng chỉ mục dòng dựng \
                dần trong nền.
                """),
            .note("""
                Công cụ dòng lệnh nhận luôn vị trí: `geditor bao-cao.csv:120:5` mở tệp rồi đặt con \
                nháy ở dòng 120 cột 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )
}
