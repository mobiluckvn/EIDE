import Foundation

extension HelpVI {

    static let tiengViet = HelpChapter(
        id: "tieng-viet",
        title: "Tiếng Việt",
        summary: "Bảng mã đời cũ, chuẩn hoá Unicode, gõ không dấu, và bộ gõ.",
        topics: [bangMaTiengViet, xuongDong, chuanHoaUnicode, goKhongDau, boGo]
    )

    // MARK: - Bảng mã

    static let bangMaTiengViet = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Bảng mã tiếng Việt",
        summary: "Đọc và ghi TCVN3, VISCII, VNI-Windows cùng 33 bảng mã khác, nhận diện tự động.",
        keywords: ["encoding", "bảng mã", "tcvn3", "abc", "viscii", "vni", "lỗi phông", "font lỗi"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Mở một tệp tiếng Việt cũ mà thấy `Tr¦êng §¹i häc` thay vì `Trường Đại học`? Tệp \
                ấy không hỏng — nó được lưu bằng một bảng mã trước thời Unicode.
                """),
            .steps([
                "Bấm tên bảng mã ở **thanh trạng thái** (hoặc `Format ▸ Bảng mã…`).",
                "Chọn bảng mã đúng — với tệp Việt cũ thường là `TCVN3 (ABC)`, `VNI-Windows` hoặc `VISCII`.",
                "Chữ hiện đúng ngay, không phải mở lại tệp.",
                "Muốn giữ lâu dài thì `Lưu thành…` với bảng mã `UTF-8`.",
            ]),
            .heading("Ba bảng mã Việt đời cũ"),
            .table(
                headers: ["Bảng mã", "Thường gặp ở"],
                rows: [
                    ["TCVN3 (ABC)", "Văn bản hành chính, tài liệu Word cũ ở miền Bắc"],
                    ["VNI-Windows", "Tài liệu, báo chí, nhà in — phổ biến ở miền Nam"],
                    ["VISCII", "Thư điện tử và Usenet thời kỳ đầu"],
                ]
            ),
            .paragraph("""
                GEditor **tự nhận diện** khi mở. Nhận sai thì đổi bằng một lần bấm, và nội dung \
                được giải mã lại chứ không phải sửa chữa từng chữ.
                """),
            .warning("""
                Ghi ra một bảng mã cũ thì những ký tự không có trong bảng ấy sẽ mất. GEditor \
                **đếm và nói ra trước** khi ghi — ví dụ *"12 ký tự không có trong TCVN3"* — chứ \
                không thay chúng bằng dấu hỏi trong im lặng.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    // MARK: - Xuống dòng

    static let xuongDong = HelpTopic(
        id: "xuong-dong",
        title: "Kiểu xuống dòng",
        summary: "LF, CRLF, CR — đổi cho cả tệp bằng một lần bấm.",
        keywords: ["eol", "crlf", "lf", "xuống dòng", "line ending", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Kiểu", "Của", "Ký hiệu"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac trước 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Kiểu đang dùng hiện ở thanh trạng thái, bấm vào là đổi. Tệp **trộn lẫn** hai kiểu \
                cũng được nói ra ở đó — bật `Hiện ký tự ẩn ▸ Xuống dòng` để thấy chỗ nào lẫn.
                """),
            .note("""
                Kiểu xuống dòng cho tệp **mới** đặt trong `Cài đặt…`.
                """),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    // MARK: - Chuẩn hoá Unicode

    static let chuanHoaUnicode = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Chuẩn hoá Unicode",
        summary: "Vì sao tìm chữ «ế» đôi khi không ra, và cách sửa cho cả tệp.",
        keywords: ["unicode", "nfc", "nfd", "tổ hợp", "dựng sẵn", "chuẩn hóa", "tìm không ra"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                Trong Unicode, chữ `ế` viết được bằng **hai cách khác nhau**: một điểm mã dựng sẵn \
                (NFC), hoặc `e` cộng hai dấu rời (NFD). Trên màn hình chúng trông y hệt nhau, \
                nhưng với máy thì đó là hai chuỗi khác nhau.
                """),
            .paragraph("""
                Hệ quả: tìm `ế` trong một tệp viết theo NFD sẽ **không ra gì**, và người dùng kết \
                luận là dữ liệu không có.
                """),
            .steps([
                "`Format ▸ Chuẩn hóa Unicode…`",
                "Chọn **NFC** (dựng sẵn) — đây là dạng gần như mọi thứ khác dùng.",
                "Áp. Là một bước hoàn tác.",
            ]),
            .note("""
                Tệp đến từ macOS thường ở dạng NFD, vì hệ thống tệp của Apple lưu tên tệp theo \
                dạng ấy. Đây là lý do phổ biến nhất khiến dữ liệu chép từ Finder tìm mãi không ra.
                """),
            .paragraph("""
                Có công tắc **chuẩn hoá về NFC khi lưu** trong `Cài đặt…`. Mặc định tắt, vì nó \
                đổi byte của tệp.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    // MARK: - Gõ không dấu

    static let goKhongDau = HelpTopic(
        id: "go-khong-dau",
        title: "Gõ không dấu vẫn ra chữ có dấu",
        summary: "Mọi ô tìm và ô lọc đều bỏ dấu khi so sánh.",
        keywords: ["không dấu", "bỏ dấu", "tìm kiếm", "lọc", "diacritic"],
        blocks: [
            .paragraph("""
                Gõ `hue` ra `Huế`. Gõ `da nang` ra `Đà Nẵng`. Luật này áp dụng cho ô lọc bảng CSV, \
                ô tìm hàm, ô tìm trong trợ giúp và các ô lọc khác.
                """),
            .note("""
                `Đ` được xử lý riêng, vì trong Unicode nó là **một chữ cái riêng** chứ không phải \
                `D` mang dấu — phép bỏ dấu thông thường không đụng tới nó.
                """),
            .paragraph("""
                Ô lọc CSV còn có tiền tố `=` cho phép so bằng. Bản `=` **cũng bỏ dấu**, vì một ô \
                lọc phân biệt dấu sẽ làm người dùng tưởng dữ liệu không có ở đó.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    // MARK: - Bộ gõ

    static let boGo = HelpTopic(
        id: "bo-go",
        title: "Bộ gõ tiếng Việt",
        summary: "EVKey, OpenKey, Unikey và bộ gõ của macOS đều gõ thẳng vào tài liệu.",
        keywords: ["ime", "evkey", "unikey", "openkey", "telex", "vni", "bộ gõ"],
        blocks: [
            .paragraph("""
                Không cần cấu hình gì. Telex và VNI đều gõ được, kể cả trên **nhiều con nháy** — \
                gõ một lần, mọi chỗ nhận đúng chữ có dấu.
                """),
            .paragraph("""
                Ô tìm, ô lọc và mọi hộp thoại đều nhận bộ gõ như vùng soạn thảo.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )
}
