import Foundation

extension HelpVI {

    static let soanThao = HelpChapter(
        id: "soan-thao",
        title: "Soạn thảo",
        summary: "Sửa nhiều chỗ cùng lúc, thao tác trên dòng, và những luật ngầm đáng biết trước.",
        topics: [
            nhieuConNhay, chonKhoiCot, columnEditor, thaoTacDong,
            khoangTrangThutLe, doiHoaThuong, commentVaNgoac, hoanTacClipboard,
        ]
    )

    // MARK: - Nhiều con nháy

    static let nhieuConNhay = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Nhiều con nháy",
        summary: "Chọn mọi chỗ giống nhau rồi gõ một lần, sửa tất cả.",
        keywords: ["multi caret", "multicursor", "nhiều con trỏ", "cmd+d", "chọn nhiều"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Đây là thứ thay thế cho phần lớn những lần bạn định viết một biểu thức chính quy. \
                Chọn một từ, bấm `⌘D` vài lần để gom các chỗ xuất hiện tiếp theo, rồi gõ — mọi \
                chỗ đổi cùng lúc.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Thêm chỗ xuất hiện kế tiếp vào vùng chọn"),
                HelpShortcut("⌘ + bấm", "Đặt thêm một con nháy ở chỗ bấm"),
                HelpShortcut("Esc", "Bỏ hết, quay về một con nháy"),
                HelpShortcut("⌥ + kéo", "Chọn theo khối cột (một cách khác để có nhiều con nháy)"),
            ]),
            .heading("Những luật đáng biết"),
            .bullets([
                "Gõ, xoá, dán trên nhiều con nháy là **một** bước hoàn tác, không phải mỗi con nháy một bước.",
                "Các con nháy giữ nguyên khi bạn di chuyển bằng phím mũi tên — cả nhóm cùng đi.",
                "`⌘D` bỏ qua chỗ nằm trong vùng đã chọn, nên bấm quá tay không sinh con nháy chồng nhau.",
            ]),
            .note("""
                `⌘D` trên một từ nằm giữa chuỗi dài từng rất chậm. Phép dò biên từ nay đọc theo lô, \
                nhanh hơn khoảng **42 lần** trên chuỗi cỡ 1 MB — thao tác này dùng được cả trên tệp \
                dữ liệu, không riêng mã nguồn.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    // MARK: - Chọn khối cột

    static let chonKhoiCot = HelpTopic(
        id: "chon-khoi-cot",
        title: "Chọn theo khối cột",
        summary: "Chọn một hình chữ nhật cắt ngang qua mọi dòng — bằng chuột hoặc bằng bàn phím.",
        keywords: ["column mode", "block select", "chọn cột", "alt kéo", "hình chữ nhật",
                   "bàn phím", "mũi tên"],
        blocks: [
            .paragraph("""
                Giữ `⌥` rồi kéo chuột để chọn một **khối hình chữ nhật**. Gõ, xoá và dán đều theo \
                khối. Dán một khối vào một con nháy đơn vẫn giữ đúng hình chữ nhật của nó.
                """),
            .shortcuts([
                HelpShortcut("⌥ + kéo chuột", "Chọn khối"),
                HelpShortcut("⌥⌘← →", "Nới khối sang trái/phải một cột"),
                HelpShortcut("⌥⌘↑ ↓", "Nới khối lên/xuống một dòng"),
            ]),
            .paragraph("""
                Đường bàn phím không phải bản dự phòng của đường chuột: chọn một khối 40 dòng bằng \
                chuột nghĩa là kéo qua một vùng cuộn, còn `⌥⌘` + mũi tên giữ được độ chính xác \
                từng cột. Bấm phím **khác** (hoặc gõ chữ) là kết thúc khối đang kéo.
                """),
            .heading("Cột ở đây là cột THỊ GIÁC"),
            .paragraph("""
                Một ký tự TAB nở tới nấc kế tiếp theo bề rộng tab bạn đặt, chứ không tính là một \
                cột. Nhờ vậy dòng thụt bằng TAB và dòng thụt bằng dấu cách **dóng nhau đúng như \
                trên màn hình**.
                """),
            .paragraph("""
                Chữ nhiều byte vẫn là một cột: `Nguyễn` chiếm sáu cột, không phải chín.
                """),
            .table(
                headers: ["Tình huống", "GEditor làm gì"],
                rows: [
                    ["Cột đích rơi vào giữa một TAB", "Về biên gần hơn; hoà thì về bên trái"],
                    ["Dòng ngắn hơn cột bắt đầu", "Dòng ấy đóng góp một vùng chọn rỗng, vẫn nhận ký tự khi gõ"],
                    ["Dán khối vào một con nháy", "Giữ nguyên hình chữ nhật, chèn xuống các dòng bên dưới"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    // MARK: - Column Editor

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Column Editor",
        summary: "Chèn văn bản, dãy số hoặc dãy ngày vào mọi dòng của một khối cột.",
        keywords: ["column editor", "đánh số", "sinh dãy", "stt", "numbering"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Chọn một khối cột rồi mở `Edit ▸ Column Editor…` (`⌥⌘C`). Hộp thoại có ô **xem \
                trước** trước khi áp.
                """),
            .table(
                headers: ["Chế độ", "Tham số", "Dùng khi"],
                rows: [
                    ["Văn bản", "Chuỗi cố định", "Thêm cùng một tiền tố/hậu tố vào mọi dòng"],
                    ["Dãy số", "Bắt đầu · bước · cơ số 2·8·10·16 · đệm số 0", "Đánh số thứ tự, sinh mã"],
                    ["Dãy ngày", "Ngày đầu · bước ngày", "Sinh cột ngày liên tiếp"],
                ]
            ),
            .code(
                language: "text",
                caption: "Đánh số thứ tự có đệm 0, bắt đầu từ 1, bước 1",
                source: """
                    Trước:            Sau (chèn dãy số, đệm 3 chữ số):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """
            ),
            .bullets([
                "Bước **âm** hợp lệ — đếm ngược được.",
                "Chèn vào 5.000 dòng vẫn là **một** bước hoàn tác.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    // MARK: - Thao tác dòng

    static let thaoTacDong = HelpTopic(
        id: "thao-tac-dong",
        title: "Thao tác trên dòng",
        summary: "Sắp xếp, khử trùng lặp, dời, ghép, tách, nhân đôi, xoá.",
        keywords: ["sort", "sắp xếp", "trùng lặp", "dedupe", "dời dòng", "ghép dòng", "tách dòng"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Có vùng chọn thì lệnh chạy trên vùng chọn; không có thì chạy trên **cả tài liệu**. \
                Mọi lệnh ở đây là một bước hoàn tác duy nhất.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Nhân đôi dòng"),
                HelpShortcut("⌘K", "Xoá dòng"),
                HelpShortcut("⌥↑ / ⌥↓", "Dời dòng lên / xuống"),
            ]),
            .heading("Ba kiểu sắp xếp, và chọn kiểu nào"),
            .table(
                headers: ["Kiểu", "`tep2` so với `tep10`", "Dùng khi"],
                rows: [
                    ["A→Z / Z→A", "`tep10` đứng trước `tep2`", "Danh sách chữ thuần"],
                    ["Tự nhiên", "`tep2` đứng trước `tep10`", "Tên tệp, mã có số, phiên bản"],
                ]
            ),
            .paragraph("""
                Sắp xếp **tự nhiên** đọc cụm chữ số thành số. Đây gần như luôn là thứ bạn muốn khi \
                danh sách có đánh số.
                """),
            .heading("Khử trùng lặp"),
            .bullets([
                "**Toàn tài liệu** — bỏ mọi dòng đã xuất hiện trước đó, giữ lần đầu.",
                "**Liên tiếp** — chỉ gộp các dòng giống nhau nằm cạnh nhau, như `uniq` của Unix.",
            ]),
            .heading("Ghép và tách"),
            .bullets([
                "**Ghép dòng** nối các dòng đang chọn thành một.",
                "**Tách theo độ dài** cắt dòng dài thành nhiều dòng ở một số ký tự cho trước.",
                "**Tách theo ký tự** cắt tại mỗi lần gặp ký tự bạn nhập — ví dụ tách một dòng CSV thành từng ô.",
            ]),
            .note("""
                Nhân đôi **dòng cuối cùng** của tệp sẽ tự thêm ký tự xuống dòng; xoá dòng tới hết \
                tài liệu thì nuốt luôn ký tự xuống dòng của dòng trước. Hai chỗ này khác với cách \
                làm ngây thơ, và cả hai đều để tệp không bị thừa hoặc thiếu một dòng trống.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    // MARK: - Khoảng trắng

    static let khoangTrangThutLe = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Khoảng trắng và thụt lề",
        summary: "Dọn khoảng trắng thừa, đổi TAB ↔ Space, và một công tắc nên cân nhắc.",
        keywords: ["whitespace", "tab", "space", "trim", "thụt lề", "indent", "dòng rỗng"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Lệnh", "Làm gì"],
                rows: [
                    ["Xóa dòng rỗng", "Bỏ hẳn mọi dòng không có gì"],
                    ["Nén dòng trống liên tiếp", "Nhiều dòng trống liền nhau còn một"],
                    ["Cắt khoảng trắng cuối dòng", "Bỏ dấu cách và TAB thừa ở cuối mỗi dòng"],
                    ["Tab → Space", "Đổi TAB thành dấu cách theo bề rộng tab đang đặt"],
                    ["Space → Tab", "Chiều ngược lại"],
                ]
            ),
            .heading("Thụt lề riêng cho từng ngôn ngữ"),
            .paragraph("""
                Bấm mục `Tab: 4` trên thanh trạng thái. Phần trên của menu đổi cho **cả ứng dụng**; \
                phần dưới — `Riêng cho Go`, `Riêng cho Python`… — chỉ áp cho ngôn ngữ của tệp đang \
                mở, và nhớ luôn cả việc dùng TAB hay dấu cách.
                """),
            .paragraph("""
                Người ta không chọn thụt lề theo sở thích mà theo **quy ước của từng cộng đồng**: \
                Go dùng TAB (`gofmt` ghi đè mọi thứ khác), Python 4 dấu cách theo PEP 8, \
                JavaScript và YAML thường 2. Một con số chung cho mọi ngôn ngữ nghĩa là mỗi tệp \
                bạn chạm vào lại mọc thêm những dòng bạn không hề sửa.
                """),
            .code(
                language: "json", caption: "settings.json",
                source: """
                    "languageIndent": {
                      "go":         { "width": 4, "usesTabs": true },
                      "python":     { "width": 4, "usesTabs": false },
                      "javascript": { "width": 2, "usesTabs": false }
                    }
                    """
            ),
            .note("""
                Khai trong `settings.json` cũng được — khoá là mã ngôn ngữ (`go`, `python`, \
                `javascript`…). Ngôn ngữ không có mặt ở đó thì dùng `tabWidth` chung.
                """),
            .heading("Vì sao \"cắt khoảng trắng khi lưu\" mặc định TẮT"),
            .paragraph("""
                Công tắc `File ▸ Cắt khoảng trắng cuối dòng khi lưu` sửa **những dòng bạn không hề \
                chạm tới**. Bật sẵn thì một lần sửa một chữ trong kho mã của người khác biến thành \
                một diff hàng nghìn dòng, và người review sẽ không tìm nổi thay đổi thật.
                """),
            .paragraph("""
                Khi bật, phép cắt là **một bước hoàn tác riêng** đứng trước phép ghi — hoàn tác một \
                lần là quay lại nguyên trạng, không mất phần vừa lưu.
                """),
            .heading("Tự động thụt lề"),
            .bullets([
                "Dòng mới thừa hưởng thụt lề của dòng trước, và thêm một bậc sau dấu mở khối — `{` với ngôn ngữ dùng ngoặc, `:` với Python và YAML.",
                "Phép đo theo **cột thị giác**, nên tệp trộn TAB và dấu cách vẫn khớp nhau trên màn hình.",
                "**Không** có luật \"gõ `}` thì tự lùi dòng\". Luật ấy chạm vào dòng bạn đã gõ xong, và là thứ bị phàn nàn nhiều nhất ở mọi trình soạn thảo có nó.",
            ]),
        ]
    )

    // MARK: - Hoa thường

    static let doiHoaThuong = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Đổi hoa thường và kiểu đặt tên",
        summary: "Tám phép đổi, kể cả camelCase, snake_case và kebab-case.",
        keywords: ["hoa thường", "uppercase", "lowercase", "camel", "snake", "kebab", "title case"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Áp lên vùng chọn. Tất cả nằm ở menu `Format`."),
            .table(
                headers: ["Lệnh", "`tổng doanh thu` thành"],
                rows: [
                    ["HOA", "`TỔNG DOANH THU`"],
                    ["thường", "`tổng doanh thu`"],
                    ["Chữ Hoa Đầu Từ", "`Tổng Doanh Thu`"],
                    ["Chữ hoa đầu câu", "`Tổng doanh thu`"],
                    ["Đảo hoa/thường", "Đổi ngược từng ký tự"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Ba phép cuối bỏ dấu tiếng Việt, vì chúng sinh ra **định danh trong mã** — nơi chữ \
                có dấu thường không dùng được.
                """),
        ]
    )

    // MARK: - Comment và ngoặc

    static let commentVaNgoac = HelpTopic(
        id: "comment-va-ngoac",
        title: "Comment và cặp ngoặc",
        summary: "⌘/ dùng đúng dấu của từng ngôn ngữ; ⌃⌘B nhảy tới ngoặc khớp.",
        keywords: ["comment", "chú thích", "ngoặc", "bracket", "cmd+/"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` chọn dấu chú thích **theo ngôn ngữ** của tài liệu: `#` cho Python, `//` cho \
                Rust và C, `<!-- -->` cho XML và HTML.
                """),
            .heading("Cả khối đi cùng một hướng"),
            .paragraph("""
                Còn một dòng chưa được comment thì lệnh sẽ comment **tất cả**. Quyết định theo từng \
                dòng riêng lẻ sẽ biến một khối comment dở dang thành bàn cờ. Dấu được chèn ở cột \
                thụt lề nông nhất trong khối, nên khối giữ nguyên hình.
                """),
            .heading("Nhảy tới ngoặc khớp"),
            .bullets([
                "`⌃⌘B` nhảy tới dấu ngoặc khớp với dấu tại con nháy.",
                "Ngoặc nằm trong **chuỗi** hoặc **chú thích** không được tính — bộ quét từ vựng nhẹ biết phân biệt.",
                "Tài liệu lớn hơn **1 MB** thì lệnh từ chối và nói ra, thay vì neo giữa chừng rồi đoán. Tô sáng sai cặp ngoặc tệ hơn không tô gì.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    // MARK: - Hoàn tác và clipboard

    static let hoanTacClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Hoàn tác và clipboard",
        summary: "Lịch sử hoàn tác không giới hạn, và một lịch sử clipboard nhiều ô.",
        keywords: ["undo", "redo", "hoàn tác", "clipboard", "dán", "lịch sử"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Hoàn tác / Làm lại"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Cắt / Sao chép / Dán"),
                HelpShortcut("⇧⌘V", "Lịch sử clipboard"),
            ]),
            .heading("Một thao tác hàng loạt là MỘT bước"),
            .paragraph("""
                Sắp xếp một triệu dòng, thay thế mười nghìn chỗ, chèn vào năm nghìn dòng bằng \
                Column Editor — mỗi thứ ấy đều lùi lại được bằng **một** lần `⌘Z`.
                """),
            .paragraph("""
                Lịch sử hoàn tác nằm trong bộ đệm văn bản của GEditor chứ không nằm trong \
                `UndoManager` của hệ điều hành, đúng vì lý do trên: `UndoManager` đếm theo từng \
                lần gõ.
                """),
            .heading("Lịch sử clipboard"),
            .paragraph("""
                `⇧⌘V` mở danh sách những thứ đã sao chép gần đây và dán lại thứ bạn chọn. Hữu ích \
                khi phải xen kẽ hai đoạn giữa nhiều chỗ.
                """),
        ]
    )
}
