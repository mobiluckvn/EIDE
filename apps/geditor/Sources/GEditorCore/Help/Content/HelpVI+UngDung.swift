import Foundation

extension HelpVI {

    static let ungDung = HelpChapter(
        id: "ung-dung",
        title: "Cấu hình và ứng dụng",
        summary: "Cài đặt, phím tắt, theme, cập nhật, di cư từ Notepad++, và xử lý sự cố.",
        topics: [caiDat, thanhTrangThai, phimTat, theme, capNhatVaVe, troGiup, diCuNotepadpp,
                 suCoThuongGap]
    )

    // MARK: - Cài đặt

    static let caiDat = HelpTopic(
        id: "cai-dat",
        title: "Cài đặt",
        summary: "Mọi tuỳ chọn ghi vào một tệp JSON đọc được bằng mắt, chép sang máy khác được.",
        keywords: ["cài đặt", "settings", "tuỳ chọn", "preferences", "cấu hình", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Mở Cài đặt")]),
            .paragraph("""
                Không có nút OK hay Huỷ — đổi là ăn ngay và ghi ngay, đúng lối cài đặt của macOS.
                """),
            .heading("Tệp cấu hình"),
            .code(
                language: "text",
                caption: "Nơi để tệp",
                source: """
                    ~/Library/Application Support/GEditor/settings.json
                    """
            ),
            .paragraph("""
                Đây là **tệp JSON có thụt lề, đọc và sửa tay được**. Chép nó sang máy khác là mang \
                theo toàn bộ cấu hình. Nút `Mở file cấu hình` trong cửa sổ Cài đặt mở thẳng tới đó.
                """),
            .heading("Các khoá"),
            .table(
                headers: ["Khoá", "Mặc định", "Nghĩa"],
                rows: [
                    ["`fontSize`", "`13`", "Cỡ chữ vùng soạn thảo"],
                    ["`tabWidth`", "`4`", "Một TAB rộng bao nhiêu cột"],
                    ["`usesTabsForIndent`", "`false`", "Thụt lề bằng TAB thay vì dấu cách"],
                    ["`smartIndent`", "`true`", "Tự động thụt lề khi xuống dòng"],
                    ["`highlightAllMatches`", "`true`", "Tô mọi kết quả tìm kiếm"],
                    ["`ligatures`", "`false`", "Chữ ghép — xem ghi chú ngay dưới bảng"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Cắt khoảng trắng cuối dòng khi lưu"],
                    ["`normalizeToNFCOnSave`", "`false`", "Chuẩn hoá Unicode về NFC khi lưu"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Bảng mã cho tệp mới"],
                    ["`defaultEOL`", "`\"lf\"`", "Kiểu xuống dòng cho tệp mới"],
                    ["`language`", "`\"system\"`", "Ngôn ngữ giao diện"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "theme mặc định", "Tên theme đang dùng"],
                    ["`showWelcomeOnLaunch`", "`true`", "Mở cửa sổ giới thiệu khi khởi động"],
                    ["`keyBindings`", "`{}`", "Chỉ chứa phím bạn đã đổi khác mặc định"],
                ]
            ),
            .note("""
                **Vì sao chữ ghép mặc định TẮT.** Một chữ ghép gộp `!=` hay `->` thành **một** \
                hình, nên số ký tự bạn thấy trên màn hình không còn khớp số ký tự trong tệp — \
                mà Column Editor, chế độ cột và ngắt dòng tại cột đều đo bằng cột. Bật nó lên \
                khi bạn đang viết văn xuôi, hoặc khi bạn dùng một font lập trình có chữ ghép \
                (Fira Code, JetBrains Mono) và chọn font ấy chính vì chúng.
                """),
            .heading("Các thư mục cùng chỗ"),
            .table(
                headers: ["Thư mục", "Chứa"],
                rows: [
                    ["`macros/`", "Macro đã lưu, mỗi macro một tệp JSON"],
                    ["`scripts/`", "Script JavaScript"],
                    ["`themes/`", "Theme màu"],
                    ["`grammars/`", "Ngôn ngữ tự định nghĩa"],
                ]
            ),
            .warning("""
                Tệp cấu hình do một bản GEditor **mới hơn** ghi ra thì bản đang chạy **không ghi \
                đè** — nó chạy bằng mặc định và nói ra. Ghi đè là cách chắc chắn xoá mất cấu hình \
                của người đang đồng bộ hai máy, và họ sẽ không bao giờ biết vì sao.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Phím tắt

    static let phimTat = HelpTopic(
        id: "phim-tat",
        title: "Đổi phím tắt",
        summary: "Đổi từng phím, hoặc dùng thẳng bộ phím của Notepad++.",
        keywords: ["phím tắt", "keybinding", "shortcut", "đổi phím", "preset"],
        blocks: [
            .paragraph("""
                Trong `Cài đặt…` có mục Phím tắt với hai nút nhanh: **Dùng preset Notepad++** và \
                **Về phím mặc định**.
                """),
            .paragraph("""
                Tệp cấu hình chỉ ghi phần bạn **đổi khác mặc định**. Nhờ vậy khi GEditor đổi một \
                phím mặc định trong bản mới, bạn không mắc kẹt với bảng phím cũ mà không ai nói cho \
                biết.
                """),
            .note("""
                Hai lệnh không được gán trùng phím. Nếu trùng, AppKit lặng lẽ chỉ kích hoạt mục \
                **đầu tiên** và lệnh kia trông như hỏng — nên GEditor có một phép kiểm chặn việc ấy.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    // MARK: - Theme

    static let theme = HelpTopic(
        id: "theme",
        title: "Theme và giao diện sáng tối",
        summary: "Theo hệ thống, sáng hoặc tối; và theme là tệp JSON tự sửa được.",
        keywords: ["theme", "màu", "dark mode", "sáng", "tối", "giao diện"],
        blocks: [
            .paragraph("""
                `Cài đặt…` chọn nền `Theo hệ thống`, `Sáng` hoặc `Tối`, và chọn theme màu.
                """),
            .paragraph("""
                Theme là tệp JSON trong `themes/`. Nút `Xuất theme hiện tại` ghi ra một tệp làm \
                điểm khởi đầu để bạn sửa.
                """),
            .note("""
                Màu gõ sai trong tệp theme sẽ rơi về màu của theme **mặc định**, không rơi về đen. \
                Màu đen trông như một lựa chọn thiết kế, và người dùng sẽ đi tìm lỗi ở chỗ khác.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    // MARK: - Cập nhật

    static let capNhatVaVe = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Cập nhật, phiên bản và thoát",
        summary: "Cách cập nhật khác nhau giữa hai bản phát hành.",
        keywords: ["cập nhật", "update", "phiên bản", "version", "về", "about", "thoát"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Bản", "Cập nhật bằng"],
                rows: [
                    ["App Store", "Qua App Store, như mọi ứng dụng khác"],
                    ["Tải trực tiếp", "`Kiểm tra bản cập nhật…` ngay trong ứng dụng"],
                ]
            ),
            .paragraph("""
                `Về GEditor` cho biết phiên bản đang chạy và bản phát hành nào — hữu ích khi báo lỗi.
                """),
            .note("""
                Ở bản App Store, mục `Kiểm tra bản cập nhật…` **vẫn có mặt** và nói rõ vì sao không \
                dùng được, thay vì biến mất. Một mục menu vắng mặt là một câu hỏi hỗ trợ.
                """),
            .paragraph("""
                Thoát app không mất việc: phiên làm việc quay lại ở lần mở sau.
                """),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    // MARK: - Thanh trạng thái

    static let thanhTrangThai = HelpTopic(
        id: "thanh-trang-thai",
        title: "Thanh trạng thái",
        summary: "Mười mục ở đáy cửa sổ — mỗi mục đọc được, và mỗi mục bấm được.",
        keywords: ["status bar", "thanh trạng thái", "đáy cửa sổ", "offset", "vị trí",
                   "bảng mã", "tab", "chỉ đọc", "cỡ tệp"],
        blocks: [
            .paragraph("""
                Đây là điểm khác biệt lớn nhất so với thanh trạng thái của các trình soạn thảo \
                khác: **không mục nào chỉ để đọc**. Thấy một con số sai thì bấm vào chính nó là \
                sửa được, không phải đi tìm trong menu.
                """),
            .table(
                headers: ["Mục", "Nói gì", "Bấm vào thì"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "vị trí con nháy — cột theo KÝ TỰ, `@340` là vị trí byte",
                     "mở hộp `Đi tới`"],
                    ["`11 byte · 3 dòng`", "cỡ tài liệu",
                     "đếm đủ byte · ký tự · từ · dòng"],
                    ["`🔒 Chỉ đọc`", "chỉ hiện khi tài liệu bị khoá",
                     "nói VÌ SAO khoá, và mở khoá nếu mở được"],
                    ["`View` / `Code`", "đang xem cách nhìn nào", "đổi cách nhìn (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "chế độ CSV và dấu phân tách đang dùng",
                     "bật/tắt chế độ CSV, hoặc **chọn lại dấu phân tách**"],
                    ["`Đang theo dõi`", "đang chạy `tail -f`", "—"],
                    ["`UTF-8`", "bảng mã", "diễn giải lại, hoặc chuyển đổi sang bảng mã khác"],
                    ["`LF`", "kiểu xuống dòng", "đổi LF · CRLF · CR"],
                    ["`Python`", "ngôn ngữ tô màu", "chọn ngôn ngữ khác, hoặc trả về theo đuôi tệp"],
                    ["`Tab: 4`", "độ rộng tab", "đổi 2 · 4 · 8, chung hoặc **riêng cho ngôn ngữ này**"],
                    ["`Ngắt: tắt`", "chế độ ngắt dòng mềm", "vòng qua ba chế độ"],
                ]
            ),
            .heading("Ba mục đáng để ý"),
            .bullets([
                "**`@340` — vị trí byte.** Đây là con số mà mọi công cụ khác của sản phẩm nói bằng: lỗi JSON và XML, kết quả `--doc-sweep`, khung xem nhị phân, và ô `Đi tới @340`. Đọc ở đây, gõ vào chỗ kia.",
                "**Cột có dấu `~`** nghĩa là con số đang đếm BYTE chứ không phải cột thị giác — chỉ xảy ra trên dòng dài quá 200 KB, nơi phép đếm ký tự sẽ làm chậm mỗi lần con nháy nhúc nhích.",
                "**`CSV · …` bấm được để chọn lại dấu phân tách.** Phép đoán theo nội dung có thể sai, và khi nó sai thì mọi thao tác cột đều lệch mà không có gì báo. Đây là đường nói lại — nó chỉ ĐỌC LẠI tệp, không sửa một byte nào (khác `CSV ▸ Đổi dấu phân tách…`, lệnh ấy ghi lại cả tệp).",
            ]),
            .note("""
                Mục nào không áp dụng cho tệp đang mở thì **ẩn đi**, không hiện mờ: `Chỉ đọc` chỉ \
                xuất hiện khi tài liệu thật sự bị khoá, `CSV · …` chỉ khi đang ở chế độ CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    // MARK: - Trợ giúp

    static let troGiup = HelpTopic(
        id: "tro-giup",
        title: "Dùng cửa sổ trợ giúp này",
        summary: "Tìm trong sách, và bật lại cửa sổ giới thiệu nếu đã tắt.",
        keywords: ["trợ giúp", "help", "hướng dẫn", "tìm", "giới thiệu", "bật lại"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Mở cửa sổ trợ giúp")]),
            .bullets([
                "Ô tìm ở góc trên bên trái soi **cả thân bài và khối mã mẫu** — gõ thẳng tên một khoá cấu hình như `fail_under` cũng ra đúng trang.",
                "Gõ **không dấu** vẫn ra chữ có dấu.",
                "Nút `Lùi` quay về trang trước.",
                "Nút `Chép` trên mỗi khối mã chép nội dung khối ấy.",
            ]),
            .heading("Bật lại cửa sổ giới thiệu"),
            .paragraph("""
                Nếu bạn đã tích **Không mở cửa sổ này khi khởi động nữa**, mở lại bằng \
                `Help ▸ Giới thiệu tính năng` — ô tích ở chân cửa sổ sẽ hiện ra và bỏ tích được.
                """),
            .paragraph("""
                Hoặc sửa khoá `showWelcomeOnLaunch` trong `settings.json` về `true`.
                """),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    // MARK: - Di cư

    static let diCuNotepadpp = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Từ Notepad++ sang GEditor",
        summary: "Phím nào hoán chỗ, thứ gì làm khác, và thứ gì không có.",
        keywords: ["notepad++", "notepad", "di cư", "windows", "chuyển sang", "phím tắt"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Vài phím **hoán chỗ cho nhau** trên macOS chứ không chỉ đổi `Ctrl` thành `⌘`. Đây \
                là bảng đối chiếu.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Vì sao"],
                rows: [
                    ["`Ctrl+D` Nhân đôi dòng", "**⇧⌘D**", "`⌘D` đã là multi-caret, giống mọi trình soạn thảo Mac"],
                    ["`Ctrl+L` Xoá dòng", "**⌘K**", "`⌘L` trên macOS là \"đi tới dòng\""],
                    ["`Ctrl+G` Đi tới dòng", "**⌘L**", "Hai phím này hoán chỗ cho nhau"],
                    ["`Ctrl+Q` Comment", "**⌘/**", "Quy ước macOS"],
                    ["`Ctrl+Shift+↑/↓` Dời dòng", "**⌥↑ / ⌥↓**", "`⌃` trên macOS thuộc về Mission Control"],
                    ["`F3` Kết quả kế", "**⌘G**", "Quy ước macOS"],
                    ["`Ctrl+F2` Đánh dấu", "**⌘F2**", "F2 và ⇧F2 nhảy dấu — giữ nguyên"],
                    ["`Alt` + kéo chọn cột", "**⌥ + kéo**", "Giống hệt"],
                    ["`Ctrl+Alt+Shift+↓` Column Editor", "**⌥⌘C**", "Quy ước macOS"],
                ]
            ),
            .note("""
                Không muốn học lại? `Cài đặt ▸ Phím tắt ▸ Dùng preset Notepad++`.
                """),
            .heading("Thứ Notepad++ có mà ở đây làm khác"),
            .bullets([
                "**Phiên làm việc** tự khôi phục, kể cả tab chưa lưu — không phải bật gì.",
                "**Bookmark có chín màu**, một dòng mang được nhiều màu cùng lúc.",
                "**Bản đồ tài liệu** mô tả *cả* tệp chứ không chỉ phần đang hiện.",
                "**Macro** phát được \"đến cuối tài liệu\" và \"trên mọi tab\", cả lần chạy là một bước hoàn tác.",
            ]),
            .heading("Thứ GEditor có thêm"),
            .bullets([
                "**Bàn làm sạch dữ liệu** và **hồ sơ dữ liệu** cho tệp CSV.",
                "**Truy vấn SQL** thẳng trên tệp CSV.",
                "**Bảng mã tiếng Việt đời cũ** — TCVN3, VISCII, VNI-Windows, đọc ghi và tự nhận diện.",
                "**Tìm không dấu ra chữ có dấu** ở mọi ô lọc.",
                "**Báo cáo `.greport.md`** với bảng và biểu đồ tự chạy lại.",
                "**Công cụ dòng lệnh `geditor`** ở bản tải trực tiếp.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    // MARK: - Sự cố

    static let suCoThuongGap = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Sự cố thường gặp",
        summary: "Sáu tình huống hay làm người dùng tưởng ứng dụng hỏng.",
        keywords: ["lỗi", "sự cố", "không chạy", "hỏng", "troubleshoot", "vì sao"],
        blocks: [
            .table(
                headers: ["Triệu chứng", "Nguyên nhân thường gặp"],
                rows: [
                    ["Chữ tiếng Việt hiện thành ký tự lạ", "Sai bảng mã — bấm tên bảng mã ở thanh trạng thái"],
                    ["Tìm một chữ có dấu mà không ra gì", "Tệp ở dạng Unicode tổ hợp — chạy `Chuẩn hoá Unicode` về NFC"],
                    ["Một mục menu mờ đi và không bấm được", "Bản App Store không chạy được lệnh ấy — mục menu nói rõ vì sao"],
                    ["Lệnh khớp ngoặc từ chối chạy", "Tài liệu lớn hơn 1 MB — tô sai cặp ngoặc tệ hơn không tô"],
                    ["Cột ở thanh trạng thái có dấu `~`", "Tài liệu quá 200 KB nên đó là số byte, không phải cột thị giác"],
                    ["Truy vấn SQL báo phải lưu tệp trước", "DuckDB đọc **tệp**, không đọc vùng nhớ đang sửa"],
                ]
            ),
            .heading("Khi GEditor đóng đột ngột"),
            .paragraph("""
                Lần khởi động sau, một dải thông báo nói ra điều đó kèm nút **Mở báo cáo** — báo \
                cáo mở ra thành một tab, đọc và chép được như mọi tệp chữ khác.
                """),
            .bullets([
                "Báo cáo chỉ mang **phiên bản, macOS, kiến trúc máy, tên tín hiệu và ngăn xếp lời gọi**.",
                "**Không có nội dung tài liệu, và cũng không có đường dẫn tệp** — một đường dẫn như `~/Desktop/luong-thang-12.xlsx` đã nói ra ba điều riêng tư trước khi ai kịp mở nó.",
                "**Không có gì được gửi đi.** Không có đường gửi tự động và cũng chưa có máy chủ nào để gửi; tệp nằm trong `~/Library/Application Support/GEditor/crash/` cho tới khi bạn mở hoặc xoá nó.",
                "Mở báo cáo xong thì lần khởi động sau không nhắc lại nữa.",
            ]),
            .heading("Chỗ để tìm thêm"),
            .bullets([
                "Thanh trạng thái nói bảng mã, kiểu xuống dòng, ngôn ngữ và chế độ ngắt dòng — bấm được vào từng mục.",
                "`settings.json` sửa tay được khi cửa sổ Cài đặt không đủ.",
                "`Về GEditor` cho biết phiên bản và bản phát hành, cần khi báo lỗi.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
