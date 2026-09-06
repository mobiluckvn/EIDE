import Foundation

/// Nội dung trợ giúp tiếng Việt — chương mở đầu.
///
/// Tách theo chương, mỗi chương một tệp. Gộp cả sách vào một tệp thì mỗi lần sửa một câu là một
/// lần chạm vào tệp mà mọi chương khác cũng đang nằm trong đó — và khi hai người cùng viết, đó là
/// một cuộc xung đột hợp nhất cho mỗi lần sửa chữ.
enum HelpVI {}

extension HelpVI {

    static let batDau = HelpChapter(
        id: "bat-dau",
        title: "Bắt đầu",
        summary: "GEditor làm được gì, và năm phút đầu tiên nên đi đường nào.",
        topics: [gioiThieu, namPhutDau, chonViec, fileLon, haiBanPhatHanh]
    )

    // MARK: - Giới thiệu (trang chào)

    /// Trang này là thứ hiện ra khi mở app lần đầu. Nó phải trả lời đúng một câu hỏi — *"cái này
    /// làm được gì cho tôi"* — trong thời gian người ta còn kiên nhẫn, tức khoảng một màn hình.
    /// Mọi thứ khác đẩy sang `chon-viec`.
    static let gioiThieu = HelpTopic(
        id: "gioi-thieu",
        title: "GEditor là gì",
        summary: "Trình soạn thảo văn bản và dữ liệu cỡ Gigabyte cho macOS, nói được tiếng Việt.",
        keywords: ["giới thiệu", "welcome", "chào", "tổng quan", "overview", "about"],
        blocks: [
            .paragraph("""
                GEditor mở một tệp **1 GB mà không nạp 1 GB vào RAM**. Nó đọc theo cửa sổ trượt \
                trên tệp đã ánh xạ bộ nhớ, nên tệp log hai trăm triệu dòng hay bảng CSV một triệu \
                hàng đều mở ra trong khoảng một giây và cuộn mượt.
                """),
            .paragraph("""
                Ngoài phần soạn thảo, nó còn là một **bàn làm việc với dữ liệu**: xem CSV dạng \
                bảng, làm sạch, chấm chất lượng, truy vấn bằng SQL, khai phá bất thường và xu \
                hướng, rồi kết xuất thành báo cáo. Và nó đọc được các bảng mã tiếng Việt đời cũ \
                mà hầu hết công cụ hiện nay đã quên.
                """),
            .heading("Sáu thứ đáng thử trước"),
            .table(
                headers: ["Việc", "Đi đâu"],
                rows: [
                    ["Mở tệp lớn mà không đợi", "Kéo tệp vào cửa sổ — xem `Mở tệp lớn`"],
                    ["Sửa nhiều chỗ cùng lúc", "`⌘D` chọn thêm chỗ giống nhau, rồi gõ một lần"],
                    ["Tìm bằng biểu thức chính quy", "`⌘F`, bật Regex — bộ máy là PCRE2 có JIT"],
                    ["Xem CSV thành bảng", "`⌥⌘T` — một triệu hàng vẫn cuộn mượt"],
                    ["Dọn một bảng dữ liệu bẩn", "`⇧⌘L` Bàn làm sạch — xem trước rồi mới áp"],
                    ["Mở tệp tiếng Việt bị lỗi phông", "Bấm tên bảng mã ở thanh trạng thái"],
                ]
            ),
            .note("""
                Quen Notepad++? Có một trang riêng đối chiếu phím tắt hai bên, vì vài phím **hoán \
                chỗ cho nhau** trên macOS chứ không chỉ đổi `Ctrl` thành `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    // MARK: - Năm phút đầu

    static let namPhutDau = HelpTopic(
        id: "nam-phut-dau",
        title: "Năm phút đầu tiên",
        summary: "Mười hai phím tắt đi được hết phần lớn công việc hằng ngày.",
        keywords: ["phím tắt", "shortcut", "bắt đầu", "cơ bản", "quick start"],
        blocks: [
            .paragraph("""
                Không cần học hết. Mười hai phím dưới đây phủ phần lớn việc thường ngày; phần còn \
                lại tra khi cần.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Mở tệp"),
                HelpShortcut("⇧⌘O", "Mở cả thư mục làm không gian làm việc"),
                HelpShortcut("⌘T", "Tab mới"),
                HelpShortcut("⌘S", "Lưu"),
                HelpShortcut("⌘F", "Tìm"),
                HelpShortcut("⌥⌘F", "Tìm và thay"),
                HelpShortcut("⇧⌘F", "Tìm trong cả thư mục"),
                HelpShortcut("⌘D", "Chọn thêm chỗ giống chỗ đang chọn"),
                HelpShortcut("⌘L", "Đi tới dòng"),
                HelpShortcut("⌘/", "Comment dòng theo đúng cú pháp ngôn ngữ"),
                HelpShortcut("⌥⌘T", "Chuyển giữa dạng Bảng và dạng Văn bản (tệp CSV)"),
                HelpShortcut("⌘?", "Mở lại cửa sổ trợ giúp này"),
            ]),
            .heading("Ba điều dễ làm người mới ngạc nhiên"),
            .bullets([
                "**Một thao tác hàng loạt là MỘT bước hoàn tác**, kể cả khi nó chạm một triệu dòng. Sắp xếp nhầm thì `⌘Z` một lần là xong.",
                "**Phiên làm việc tự khôi phục.** Đóng app rồi mở lại thì tab quay về nguyên chỗ, kể cả tab chưa lưu. Không phải bấm gì.",
                "**Gõ không dấu vẫn ra chữ có dấu** ở mọi ô tìm và ô lọc — gõ `hue` ra `Huế`, gõ `da nang` ra `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    // MARK: - Chọn việc

    /// Trang định tuyến. Nó tồn tại vì mục lục sắp theo TÍNH NĂNG, còn người dùng đến với một
    /// CÔNG VIỆC — và hai cách sắp ấy không trùng nhau. Ai muốn "dọn bảng doanh thu sếp gửi"
    /// không biết mình đang tìm chương "Chất lượng dữ liệu".
    static let chonViec = HelpTopic(
        id: "chon-viec",
        title: "Bạn đang cần làm gì?",
        summary: "Bảng tra từ công việc thật sang chương hướng dẫn tương ứng.",
        keywords: ["mục lục", "tra cứu", "index", "làm sao để", "how to"],
        blocks: [
            .paragraph("""
                Mục lục bên trái sắp theo **tính năng**. Bảng này sắp theo **việc**, vì hai cách \
                sắp ấy không trùng nhau.
                """),
            .table(
                headers: ["Tôi cần…", "Xem"],
                rows: [
                    ["Sửa cùng một chỗ ở hàng trăm dòng", "Nhiều con nháy · Chọn theo khối cột"],
                    ["Đổi định dạng hàng loạt bằng regex", "Tìm và thay · Biểu thức chính quy"],
                    ["Lặp lại một chuỗi thao tác", "Macro"],
                    ["Mở tệp CSV sếp gửi và xem thử", "Bảng CSV"],
                    ["Dọn bảng bẩn: ngày lộn xộn, số lẫn chữ", "Quy trình làm sạch dữ liệu"],
                    ["Biết bảng này có tin được không", "Chấm chất lượng dữ liệu"],
                    ["Tìm điểm bất thường, xu hướng, nhóm", "Quy trình khai phá dữ liệu"],
                    ["Hỏi dữ liệu bằng SQL", "Truy vấn CSV bằng SQL"],
                    ["Xuất một báo cáo có số liệu tự cập nhật", "Báo cáo `.greport.md`"],
                    ["Vẽ sơ đồ trong tài liệu", "Mermaid"],
                    ["Mở tệp tiếng Việt bị lỗi phông", "Bảng mã tiếng Việt"],
                    ["Tự động hoá từ dòng lệnh hoặc AppleScript", "Tự động hoá"],
                    ["Tô màu cho định dạng riêng của công ty", "Ngôn ngữ tự định nghĩa"],
                ]
            ),
            .note("""
                Không thấy thứ mình cần? Ô tìm ở góc trên bên trái soi cả **thân bài và khối mã \
                mẫu**, nên gõ thẳng tên một khoá cấu hình như `fail_under` cũng ra đúng trang.
                """),
        ]
    )

    // MARK: - Tệp lớn

    static let fileLon = HelpTopic(
        id: "file-lon",
        title: "Mở tệp lớn",
        summary: "Vì sao mở được 1 GB, và những chỗ GEditor cố ý từ chối thay vì đoán.",
        keywords: ["file lớn", "gigabyte", "1gb", "log", "mmap", "chậm", "hiệu năng"],
        blocks: [
            .paragraph("""
                Tệp được **ánh xạ bộ nhớ** rồi đọc theo cửa sổ trượt, và phần đang sửa nằm trong \
                một cấu trúc piece table. Hệ quả thực tế: thời gian mở gần như không phụ thuộc cỡ \
                tệp, và bộ nhớ ứng dụng chiếm cũng vậy.
                """),
            .heading("Những chỗ cố ý từ chối"),
            .paragraph("""
                Vài phép tính buộc phải đọc cả tệp thành một chuỗi — đúng thứ kiến trúc này tránh. \
                Ở đó GEditor **nói thẳng là không làm** thay vì im lặng chạy chậm hoặc đoán bừa:
                """),
            .table(
                headers: ["Việc", "Trần", "Quá trần thì"],
                rows: [
                    ["Khớp cặp ngoặc", "1 MB", "Từ chối và nói ra — tô sai cặp ngoặc tệ hơn không tô"],
                    ["Số cột thị giác ở thanh trạng thái", "200 KB", "Quay về đếm byte, và ghi dấu `~` để nói rõ nghĩa đã khác"],
                    ["Xem trước Markdown", "4 MB", "Từ chối và nói rõ"],
                ]
            ),
            .warning("""
                Một con số trông y hệt nhưng mang nghĩa khác là kiểu sai tệ nhất. Đó là lý do cột \
                vượt trần hiện `~1234` chứ không hiện `1234`.
                """),
            .heading("Mẹo cho tệp log"),
            .bullets([
                "`File ▸ Theo dõi tệp (tail -f)` nạp thêm phần mới ghi vào cuối. Tài liệu chuyển sang **chỉ đọc** trong lúc theo dõi — vừa gõ vừa nạp là hai nguồn sửa đổi tranh nhau, và bên thua luôn là phần bạn vừa gõ.",
                "Dòng log được **tô theo mức nghiêm trọng**, và lọc được theo mức.",
                "**Bản đồ tài liệu** (`⌥⌘M`) mô tả cả tệp chứ không chỉ phần đang hiện trên màn hình.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    // MARK: - Hai bản phát hành

    /// Trang này tồn tại vì cùng một sản phẩm có hai bản chạy khác nhau, và sự khác nhau ấy sẽ
    /// làm người dùng tưởng máy mình hỏng. Nói trước rẻ hơn trả lời sau.
    static let haiBanPhatHanh = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "Bản App Store và bản tải trực tiếp",
        summary: "Ba tính năng chỉ có ở bản tải trực tiếp, và vì sao.",
        keywords: ["app store", "sandbox", "tải về", "cli", "plugin", "khác nhau"],
        blocks: [
            .paragraph("""
                GEditor có hai bản. Chúng dựng từ **cùng một mã nguồn** và ứng dụng tự nhận ra \
                mình đang là bản nào lúc chạy. Khác nhau nằm ở những gì App Sandbox cho phép.
                """),
            .table(
                headers: ["Tính năng", "App Store", "Tải trực tiếp"],
                rows: [
                    ["Toàn bộ phần soạn thảo, CSV, làm sạch, khai phá, báo cáo", "Có", "Có"],
                    ["Công cụ dòng lệnh `geditor`", "Không", "Có"],
                    ["Lọc văn bản qua lệnh ngoài", "Không", "Có"],
                    ["Plugin native (tiến trình riêng)", "Không", "Có"],
                    ["Tự cập nhật", "Qua App Store", "Trong ứng dụng"],
                ]
            ),
            .paragraph("""
                Ba dòng "Không" ở trên đều vì sandbox **cấm chạy mã ngoài ứng dụng**. Đó là điều \
                kiện của App Store, không phải thiếu sót.
                """),
            .note("""
                Ở bản App Store các lệnh ấy **vẫn nằm trong menu** và nói rõ vì sao không dùng \
                được, chứ không biến mất. Một mục menu vắng mặt là một câu hỏi hỗ trợ; một câu \
                trả lời tại chỗ thì không.
                """),
            .heading("Quyền truy cập tệp ở bản App Store"),
            .paragraph("""
                Bản sandbox chỉ chạm được tệp bạn đã tự mở hoặc kéo vào. GEditor giữ **bookmark có \
                phạm vi bảo mật** cho từng tab và cho cả thư mục không gian làm việc, nên phiên làm \
                việc mở lại được sau khi thoát app mà không phải cấp quyền lại.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )
}
