import Foundation

extension HelpVI {

    static let xem = HelpChapter(
        id: "xem",
        title: "Cách nhìn tài liệu",
        summary: "Sidebar, bản đồ, gấp khối, chia đôi màn hình, ngắt dòng, ký tự ẩn, chế độ tô màu.",
        topics: [sidebarVaHam, banDoTaiLieu, gapKhoi, chiaDoiManHinh, ngatDong, coChu,
                 kyTuAn, cheDoToMau, xemTruocMarkdown, xemNhiPhan, cheDoViewCode]
    )

    // MARK: - Sidebar

    static let sidebarVaHam = HelpTopic(
        id: "sidebar-va-ham",
        title: "Sidebar và danh sách hàm",
        summary: "Cây thư mục và danh sách hàm của tệp đang mở, trong cùng một cột.",
        keywords: ["sidebar", "function list", "danh sách hàm", "outline", "cây thư mục"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Ẩn / hiện sidebar")]),
            .paragraph("""
                Danh sách hàm dựng từ **cây cú pháp** của ngôn ngữ, nên nó theo đúng cấu trúc chứ \
                không đoán theo thụt lề. Bấm một mục là nhảy tới đó.
                """),
            .note("Ô lọc trong danh sách hàm **gõ không dấu vẫn ra chữ có dấu**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    // MARK: - Bản đồ tài liệu

    static let banDoTaiLieu = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Bản đồ tài liệu",
        summary: "Toàn cảnh cả tệp ở cột hẹp bên phải — kể cả tệp hàng trăm MB.",
        keywords: ["minimap", "bản đồ", "map", "toàn cảnh", "overview"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Ẩn / hiện bản đồ tài liệu")]),
            .paragraph("""
                Bản đồ mô tả **cả tệp**, không chỉ phần đang nằm trong màn hình. Kéo trên bản đồ \
                là nhảy tới vùng tương ứng.
                """),
            .paragraph("""
                Kết quả tìm kiếm và dòng đã đánh dấu hiện lên bản đồ, nên bạn thấy được chúng \
                nằm rải rác hay dồn vào một chỗ trước khi cuộn tới.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    // MARK: - Gấp khối

    static let gapKhoi = HelpTopic(
        id: "gap-khoi",
        title: "Gấp khối",
        summary: "Thu gọn hàm, khối và mảng theo cấu trúc — hoặc gấp cả tệp tới một cấp.",
        keywords: ["fold", "gấp", "code folding", "thu gọn", "collapse"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Gấp / mở khối tại con nháy"),
                HelpShortcut("⌥⇧⌘←", "Gấp tất cả"),
                HelpShortcut("⌥⌘→", "Bỏ gấp tất cả"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Gấp cả tệp tới cấp 1…8"),
            ]),
            .paragraph("""
                Với ngôn ngữ có cây cú pháp, phép gấp đi theo **cấu trúc thật**. Với tệp không có \
                grammar, nó đi theo thụt lề.
                """),
            .paragraph("""
                `Gấp theo cấp` hữu ích nhất trên JSON và YAML sâu: gấp tới cấp 2 là thấy được \
                khung của cả tệp trong một màn hình.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    // MARK: - Chia đôi

    static let chiaDoiManHinh = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Chia đôi màn hình",
        summary: "Hai nửa cạnh nhau, xem hai tệp — hoặc hai chỗ của cùng một tệp.",
        keywords: ["split", "chia đôi", "hai cửa sổ", "so sánh"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Chia đôi theo chiều dọc"),
                HelpShortcut("⌥⌘-", "Chia đôi theo chiều ngang"),
                HelpShortcut("⌥⌘0", "Bỏ chia đôi"),
                HelpShortcut("⌥⌘]", "Mở tab này ở nửa kia"),
                HelpShortcut("⌥⌘[", "Nhảy sang nửa kia"),
            ]),
            .paragraph("""
                Mỗi nửa có thanh tab riêng. Mở **cùng một tệp** ở cả hai nửa cũng được — hai nửa \
                cuộn độc lập, nên so đầu tệp với cuối tệp rất tiện.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    // MARK: - Ngắt dòng

    static let ngatDong = HelpTopic(
        id: "ngat-dong",
        title: "Ngắt dòng",
        summary: "Ba chế độ: tắt, theo bề rộng cửa sổ, hoặc tại một cột cố định.",
        keywords: ["word wrap", "ngắt dòng", "wrap", "xuống dòng mềm"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Chế độ", "Dòng dài thì"],
                rows: [
                    ["Tắt", "Cuộn ngang"],
                    ["Theo cửa sổ", "Xuống hàng ở mép cửa sổ, đổi theo cỡ cửa sổ"],
                    ["Tại cột", "Xuống hàng ở đúng cột bạn đặt — ví dụ 80 hoặc 100"],
                ]
            ),
            .paragraph("""
                Ngắt dòng là **cách nhìn**, không sửa tệp: không có ký tự xuống dòng nào được \
                thêm vào, và nó không vào lịch sử hoàn tác.
                """),
            .note("""
                Chỗ bấm nhanh của lệnh này là mục `Ngắt: …` trên thanh trạng thái.
                """),
        ]
    )

    // MARK: - Cỡ chữ

    static let coChu = HelpTopic(
        id: "co-chu",
        title: "Cỡ chữ",
        summary: "Phóng to thu nhỏ trong khoảng 8–32 pt.",
        keywords: ["zoom", "cỡ chữ", "font size", "phóng to"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Phóng to chữ"),
                HelpShortcut("⌘-", "Thu nhỏ chữ"),
                HelpShortcut("⌃⌘0", "Về cỡ chữ gốc"),
            ]),
            .paragraph("""
                Kẹp trong khoảng 8–32 pt. Đây cũng là **cách nhìn**: không sinh sửa đổi, không \
                vào lịch sử hoàn tác. Cỡ chữ mặc định đặt trong `Cài đặt…`.
                """),
            .note("`⌘0` KHÔNG phải cỡ chữ gốc — phím ấy là ẩn/hiện sidebar."),
            .seeAlso(["cai-dat"]),
        ]
    )

    // MARK: - Ký tự ẩn

    static let kyTuAn = HelpTopic(
        id: "ky-tu-an",
        title: "Hiện ký tự ẩn",
        summary: "Bật từng nhóm một, vì bật hết cùng lúc thường là quá nhiều.",
        keywords: ["invisible", "ký tự ẩn", "khoảng trắng", "nbsp", "zero width", "tab"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Hiện / ẩn tất cả ký tự ẩn")]),
            .paragraph("""
                Bốn nhóm bật tắt riêng được, vì bật hết cùng lúc biến màn hình thành một rừng dấu \
                chấm át cả nội dung.
                """),
            .table(
                headers: ["Nhóm", "Bắt được gì"],
                rows: [
                    ["Khoảng trắng", "Dấu cách thừa ở cuối dòng, thụt lề lẫn lộn"],
                    ["Tab", "Tệp trộn TAB với dấu cách"],
                    ["Xuống dòng", "Tệp trộn CRLF với LF"],
                    ["NBSP · zero-width · điều khiển", "Ký tự vô hình từ Word, từ web, từ bảng tính"],
                ]
            ),
            .warning("""
                Nhóm cuối là nhóm hay cứu người nhất. Một khoảng trắng không ngắt (NBSP) dán từ \
                web trông **giống hệt** dấu cách thường, nhưng làm mọi phép so chuỗi và mọi phép \
                lọc trượt — và không có cách nào thấy nó nếu không bật nhóm này.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    // MARK: - Chế độ tô màu

    static let cheDoToMau = HelpTopic(
        id: "che-do-to-mau",
        title: "Chế độ CSV và chế độ Log",
        summary: "Hai cách tô màu thay cho tô cú pháp, dành cho hai loại tệp dữ liệu.",
        keywords: ["csv mode", "log mode", "tô màu", "highlight", "cột", "mức log"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("Chế độ CSV"),
            .paragraph("""
                Tô mỗi cột một màu ngay trong dạng **văn bản**, nên bạn thấy được ô nào lệch cột \
                mà không phải chuyển sang dạng bảng.
                """),
            .heading("Chế độ Log"),
            .paragraph("""
                Tô theo **mức nghiêm trọng** đọc ra từ dòng: lỗi đỏ, cảnh báo vàng, còn `debug` \
                và `trace` thì tô nhạt hẳn — chúng chiếm phần lớn một tệp log, và tô nổi chúng \
                lên là làm mờ đúng thứ bạn đang tìm.
                """),
            .paragraph("""
                `Lọc log theo mức…` giấu hẳn những mức bạn không cần.
                """),
            .note("""
                Hai chế độ này tô **thay** cho tô cú pháp, không chồng lên. Tệp log không có cú \
                pháp để tô, và hai nguồn màu cùng ghi lên một khoảng byte thì không đoán được cái \
                nào thắng.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    // MARK: - Xem nhị phân

    static let xemNhiPhan = HelpTopic(
        id: "xem-nhi-phan",
        title: "Xem nhị phân",
        summary: "Bảng hex cho mọi tệp — kể cả tệp 1 GB, mở gần như tức thì.",
        keywords: ["hex", "nhị phân", "binary", "byte", "offset", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `View ▸ Xem nhị phân` hiện từng byte của tệp dưới dạng bảng ba cột: **offset · \
                hex · chữ**. Chạy được với **mọi** tệp có trên đĩa, không riêng ảnh hay video.
                """),
            .table(
                headers: ["Cột", "Nội dung"],
                rows: [
                    ["Offset", "Vị trí byte, viết theo hệ 16"],
                    ["Hex", "16 byte một dòng, tách đôi ở byte thứ 8 cho dễ đếm"],
                    ["Chữ", "Byte ASCII in được; còn lại là dấu `.`"],
                ]
            ),
            .note("""
                Cột chữ **không giải mã UTF-8**. Một chữ tiếng Việt chiếm hai tới ba byte, nên \
                hiện nó ra sẽ làm cột chữ lệch khỏi cột hex — mà sự thẳng hàng ấy chính là công \
                dụng của cột này. Cần đọc chữ có dấu thì dùng chế độ xem thường.
                """),
            .heading("Tệp lớn"),
            .paragraph("""
                Tệp được **ánh xạ bộ nhớ**, nên mở một tệp 1 GB ở chế độ nhị phân tốn đúng phần \
                đang nhìn thấy. Phép đo trong bộ tự kiểm: **dưới một phần nghìn giây**.
                """),
            .paragraph("""
                Khung hiện **một cửa sổ 4 MB** một lúc, và thanh trên nói rõ đang ở khoảng nào. \
                Đây là giới hạn của bộ vẽ bảng trong hệ điều hành, không phải của phép đọc: một \
                tệp 1 GB là 62,5 triệu hàng, và quá một ngưỡng nào đó thì hàng bắt đầu nhảy chỗ \
                khi cuộn — một bảng hex nhảy chỗ thì vô dụng.
                """),
            .heading("Nhảy tới một vị trí"),
            .table(
                headers: ["Gõ vào ô offset", "Nghĩa"],
                rows: [
                    ["`1F400`", "Hệ 16 — mặc định"],
                    ["`0x1F400`", "Như trên, viết rõ tiền tố"],
                    ["`#128000`", "Hệ 10, khi bạn có số byte chứ không có offset hex"],
                ]
            ),
            .bullets([
                "`‹` và `›` chuyển cửa sổ trước / sau.",
                "**Chép dòng đã chọn** chép ra đúng thứ đang nhìn — không chọn gì thì chép cả cửa sổ.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    // MARK: - Markdown

    static let xemTruocMarkdown = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Xem trước Markdown",
        summary: "Dựng tài liệu Markdown thành chữ có định dạng — và nói rõ nó không dựng gì.",
        keywords: ["markdown", "preview", "xem trước", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("""
                Dựng bằng bộ Markdown của hệ điều hành: đậm, nghiêng, mã, liên kết, danh sách.
                """),
            .warning("""
                **Không dựng bảng và không tô màu khối mã.** Cửa sổ xem trước nói thẳng điều đó ở \
                chân cửa sổ. Tài liệu lớn hơn **4 MB** thì từ chối dựng.
                """),
            .paragraph("""
                Cần bảng và biểu đồ trong một tài liệu xuất ra được? Đó là việc của báo cáo \
                `.greport.md`, không phải của cửa sổ xem trước này.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    // MARK: - View / Code

    static let cheDoViewCode = HelpTopic(
        id: "che-do-view-code",
        title: "Hai chế độ: View và Code",
        summary: "Một phím đổi giữa bản dựng ra và bản gốc sửa được, cho mọi loại tệp.",
        keywords: ["view", "code", "chế độ", "xem", "sửa", "nguồn", "dựng", "preview"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Đổi giữa View và Code")]),
            .paragraph("""
                Chỗ bấm nằm ở **khung chung ngay dưới thanh tab** — cùng một chỗ cho mọi loại \
                tệp: công tắc `View | Code`, rồi tên chế độ View của tệp ấy («Trang tài liệu», \
                «Cây khoá–giá trị», «Sơ đồ»…). Tệp chỉ có một chế độ thì công tắc mờ đi và \
                khung nói thẳng lý do. Mép phải khung là nút riêng của từng loại: `.xlsx` có \
                **Bảng** (sửa được, ghi thẳng vào tệp), `.pptx` có **Dàn ý**.
                """),
            .note("""
                **Word và PowerPoint xem như một trình đọc tài liệu.** Chế độ View của chúng \
                dựng trang thật — đúng phông, đúng cỡ, đúng màu, có hình, có bảng, có đầu và \
                chân trang kèm số trang. Trang **rộng bằng đúng bề ngang khung**, và phóng to \
                được. Excel là ngoại lệ có chủ ý: View của nó là **bảng tính sửa được**, vì một \
                bảng tính không có khổ giấy cho tới lúc in.
                """),
            .note("""
                Đổi lại, trang **chỉ đọc** và dựng **bản trên đĩa**: sửa ở Code mà chưa lưu thì \
                trang bên View là bản cũ, và khung nói ra điều đó kèm nút `Lưu rồi dựng lại`.
                """),
            .heading("Định nghĩa"),
            .bullets([
                "**Code** là bản **gốc sửa được**. Với tệp văn bản, đó là chính văn bản. Với tệp nhị phân — PDF, ảnh, nhạc, phim — không có nguồn văn bản nào, nên Code là **byte**, hiện dưới dạng hex.",
                "**View** là bản **dựng ra** từ Code. Nó có thể đẹp hơn, gọn hơn, hoặc chạy được — nhưng nó luôn là hệ quả, không phải bản gốc.",
            ]),
            .paragraph("""
                Nói *"loại này không có Code"* với một tệp PDF thì tiện hơn, nhưng sai: byte đúng \
                là nguồn của nó.
                """),
            .heading("Sửa ở đâu"),
            .paragraph("""
                Sửa xảy ra ở **Code**. Có đúng **hai ngoại lệ**, và cả hai vì thao tác ở View tự \
                nhiên hơn hẳn: **ô bảng CSV** và **ô biểu mẫu PDF**. Cả hai ghi thẳng vào nguồn, \
                nên không sinh ra bản thứ hai để rồi phải hỏi bản nào đúng.
                """),
            .heading("Từng loại tệp"),
            .table(
                headers: ["Loại tệp", "View", "Code", "Sửa ở"],
                rows: [
                    ["CSV · TSV", "Bảng", "Văn bản thô", "**Cả hai**"],
                    ["Excel `.xlsx`", "Bảng của sheet đang mở", "CSV của sheet ấy", "**Cả hai**"],
                    ["PDF", "Trang dựng ra", "Nhị phân", "**Cả hai** — chú thích, ô biểu mẫu, trang"],
                    ["Markdown `.md`", "Chữ đã dựng", "Nguồn Markdown", "Code"],
                    ["Báo cáo `.greport.md`", "Báo cáo đã chạy truy vấn và vẽ", "Nguồn", "Code"],
                    ["JSON", "Cây khoá–giá trị, gấp mở được", "Nguồn JSON", "Code"],
                    ["XML · HTML", "Cây thẻ, gấp mở được", "Nguồn XML", "Code"],
                    ["YAML", "Cây khoá–giá trị theo thụt lề", "Nguồn YAML", "Code"],
                    ["Sơ đồ `.mmd` · `.dot`", "Sơ đồ vẽ ra, chiếm trọn tab", "Nguồn mermaid hoặc DOT", "Code"],
                    ["Word `.docx`", "Trang tài liệu dựng ra", "Markdown rút ra", "Code"],
                    ["PowerPoint `.pptx`", "Trang slide dựng ra", "Dàn ý Markdown", "Code"],
                    ["Tệp log", "Tô theo mức, lọc được", "Văn bản thô", "Code"],
                    ["Ảnh", "Ảnh (động thì phát được)", "Nhị phân", "Chỉ đọc"],
                    ["Nhạc · phim", "Bộ phát", "Nhị phân", "Chỉ đọc"],
                    ["Tệp nén", "Danh sách mục", "Nhị phân", "Chỉ đọc"],
                    ["Mã nguồn, văn bản thuần", "— không có", "Chính văn bản", "Code"],
                ]
            ),
            .note("""
                Mã nguồn **không có View**, và đó là chuyện bình thường chứ không phải thiếu sót: \
                một tệp Swift không có bản dựng ra nào đáng xem.
                """),
            .heading("Khung đọc trang của Word và PowerPoint"),
            .paragraph("""
                Trang xếp dọc, cuộn liên tục, mỗi trang một tờ giấy trắng trên nền xám — giống \
                mọi trình đọc tài liệu. Mép phải khung chung có bộ điều khiển của nó.
                """),
            .table(
                headers: ["Nút / phím", "Làm gì"],
                rows: [
                    ["`Vừa ngang`", "Tờ giấy rộng đúng bằng khung — mặc định khi mở"],
                    ["`Vừa khung`", "Cả tờ lọt trong khung"],
                    ["`−` `+`", "Phóng từng nấc; hoặc chụm hai ngón, hoặc ⌘ + con lăn"],
                    ["Ô `Tìm`, hoặc ⌘F", "Tìm chữ trong trang, nhảy tới và tô vàng chỗ khớp"],
                    ["Enter trong ô tìm", "Sang chỗ khớp tiếp theo"],
                    ["Kéo chuột", "Bôi đen chữ; bấm hai lần chọn một từ, ba lần chọn cả đoạn"],
                    ["⌘A · ⌘C", "Chọn tất cả · chép chữ đang bôi đen"],
                    ["Page Up · Page Down · Home · End", "Đi trong tài liệu"],
                ]
            ),
            .paragraph("""
                Ô tìm **bỏ dấu và bỏ hoa thường**: gõ `vuong quoc` ra `Vương quốc`. Nhãn \
                «Trang 12/363» ở khung chung cho biết đang đọc tới đâu.
                """),
            .note("""
                **Phần chưa dựng lại, nói thẳng:** ảnh neo tự do (kiểu chữ chạy quanh ảnh) hiện \
                ra như ảnh nằm trong dòng; ghi chú chân trang, biểu đồ và SmartArt của \
                PowerPoint thì chưa vẽ. Cần đối chiếu tuyệt đối với bản in thì mở bằng Word.
                """),
            .heading("Bấm một nút trong cây là nhảy về nguồn"),
            .paragraph("""
                Cây JSON không phải một bản in đẹp: bấm vào một nút thì con nháy **nhảy về \
                GIÁ TRỊ của nút ấy** trong văn bản, và tab quay lại chế độ Code — vì thứ bạn muốn \
                tiếp theo gần như luôn là sửa chỗ vừa bấm.
                """),
            .bullets([
                "Nút chứa hiện **số phần tử** (`{12}`, `[340]`) chứ không hiện nội dung — đó là thứ trả lời «có đáng mở ra không».",
                "Mở sẵn **hai tầng đầu**: mở hết cây của một tệp mười nghìn nút cho ra danh sách dài hơn chính văn bản gốc, còn đóng hết thì phải bấm mới biết bên trong có gì.",
                "Tệp **sai cú pháp** thì không dựng cây một nửa — một cây cụt trông như tài liệu chỉ có ngần ấy nội dung.",
                "Trong cây XML, thuộc tính mang tiền tố `@` theo đúng ký hiệu XPath, và **khoảng trắng giữa các thẻ không thành nút** — nó là định dạng, không phải nội dung.",
                "Cây YAML đọc được **tệp nhiều tài liệu** (`---`): mỗi tài liệu là một gốc riêng. Tập hợp viết gọn trên một dòng (`cổng: [80, 443]`) để nguyên làm một lá — nội dung đã thấy hết rồi, bung ra chỉ tốn thêm một cú bấm. Còn **thụt lề bằng Tab** thì nói thẳng ra dòng nào: đó là lỗi YAML mà nhìn bằng mắt không thấy.",
                "Dàn ý PowerPoint dựng từ **văn bản đang mở**, không từ tệp trên đĩa: nếu bạn vừa sửa dàn ý ở Code thì cây phải mô tả bản mới, còn nút thì phải nhảy đúng vào bản mới ấy. Ghi chú người trình bày gom vào một nút gấp lại được, để một slide nói nhiều không trông như một slide có nhiều nội dung.",
                "**Sơ đồ chiếm trọn tab cũng theo đúng luật ấy**: bấm một node là quay về Code với con nháy ở dòng khai node. Ở bảng `Mermaid Studio` bên cạnh thì tab không đóng — vùng soạn thảo vẫn hiện ngay bên, con nháy dời là thấy.",
                "Và sơ đồ cũng **mở ra ở chỗ bạn đang đứng**: phần tử ứng với dòng con nháy sáng sẵn ngay khi tab hiện ra, không phải đi tìm bằng mắt.",
            ]),
            .heading("Ô lọc: cây mười nghìn nút thì tìm mới là việc chính"),
            .paragraph("""
                Ngay dưới dòng đếm nút có một ô lọc. Gõ vào đó thì cây chỉ còn những nút khớp — \
                **kèm đường đi từ gốc xuống chúng**, vì một khoá `ten` nằm ở mười chỗ khác nhau \
                thì câu hỏi thật luôn là «cái nào trong số đó», và chỉ nhánh chứa nó mới trả lời \
                được. Phần còn lại được mở sẵn: bắt bạn bấm mở từng tầng là bắt bạn lọc lại bằng \
                tay.
                """),
            .bullets([
                "Lọc theo **cả nhãn lẫn giá trị**: tìm `Huế` cũng thường ngang tìm khoá `tinh`.",
                "**Gõ không dấu vẫn ra chữ có dấu** — `da nang` ra `Đà Nẵng`. Cùng phép so với ô lọc của bảng CSV và của mục lục hàm, để bạn không phải nhớ ba luật tìm kiếm trong một ứng dụng.",
                "Không khớp gì thì đầu khung nói **«Không có kết quả»**, chứ không để bạn nhìn một cây rỗng và đoán là tệp hỏng.",
                "Đổi tệp hay bật lại View thì ô lọc **tự xoá**: một cây mở ra đã cụt sẵn mà không có gì nói vì sao là thứ khó hiểu nhất.",
            ]),
            .heading("Cả cây đi được bằng bàn phím"),
            .paragraph("""
                Bật View là bàn phím sang cây luôn, không phải bấm chuột vào nó trước. Mũi tên \
                lên xuống đi giữa các nút, mũi tên trái phải gấp và mở, rồi hai phím kết thúc \
                một lượt xem — và chúng làm hai việc **khác nhau**:
                """),
            .bullets([
                "**Enter** — đi tới nút đang chọn: quay về Code và con nháy nhảy vào đúng khoảng byte của nút ấy. Giống hệt một cú bấm chuột.",
                "**Tab** — đi qua lại giữa cây và ô lọc.",
                "**⌘C** — chép **đường dẫn** của nút đang chọn, không chép văn bản phía sau cây. JSON và YAML ra cú pháp JSONPath (`$.khach['tên']`) nên dán thẳng được vào ô truy vấn JSONPath của chính sản phẩm này, hay vào `yq`; XML ra XPath (`/don_hang/hang[2]/@ma`), có đánh số khi hai thẻ trùng tên; dàn ý PowerPoint thì chép chữ của dòng, vì dàn ý không có ngôn ngữ đường dẫn nào để mà bịa.",
                "**Esc** — đường lui: quay về Code nhưng con nháy **nằm nguyên chỗ cũ**. Bạn vừa xem một cái cây, không phải vừa đi đâu cả.",
            ]),
            .heading("Và chiều ngược lại: cây mở ra ở chỗ con nháy đang đứng"),
            .paragraph("""
                Bật View từ giữa một tệp mười nghìn dòng thì cây **không** mở ra ở đầu tài liệu: \
                nó tự mở đúng đường xuống nút ứng với chỗ con nháy vừa đứng, và chọn sẵn nút ấy. \
                Đây là nửa còn lại của phép nhảy về nguồn — thiếu nó, View và Code mới là hai \
                cách nhìn cùng một tài liệu theo **một** chiều.
                """),
            .bullets([
                "Mở **sâu hơn hai tầng** khi cần: luật hai tầng trả lời câu «mở tệp này ra thì thấy gì», còn ở đây câu hỏi đã khác — «chỗ tôi đang đứng nằm đâu trong cây».",
                "Con nháy đặt trên **khoá** (`\"dia_chi\":`) chọn đúng mục ấy, dù khoảng byte của nút chỉ bao phần giá trị. Chữ đứng ngay trước một nút thuộc về chính nút ấy.",
                "Con nháy ở **đầu một khối** — khoá của một khối YAML, tiêu đề một slide, tên thẻ XML — thì chọn chính khối ấy chứ không nhảy xuống con đầu tiên.",
                "Bật View **không dời con nháy**. Tắt View đi là bạn vẫn ở đúng chỗ cũ; View chỉ là một cách nhìn, không phải một lệnh sửa vị trí.",
            ]),
            .heading("Không còn loại nào thiếu View"),
            .paragraph("""
                **Mọi loại tệp có chỗ cho một chế độ View thì nay đều dựng được.** Bảng liệt kê \
                những loại còn thiếu đã rỗng và bị bỏ đi.

                Mã nguồn và văn bản thuần vẫn không có View — đó là chuyện bình thường, không \
                phải thiếu sót, nên chúng chưa bao giờ nằm trong bảng ấy.

                Nếu về sau có thêm một loại tệp mà View của nó chưa kịp dựng, lệnh đổi chế độ sẽ \
                nói thẳng điều đó kèm tên thứ còn thiếu, thay vì mở ra một khung trống — một \
                khung trống là lời hứa suông, một câu từ chối có tên gọi là thông tin.
                """),
            .heading("Sáu lệnh cũ vẫn còn"),
            .paragraph("""
                `Xem dạng bảng / văn bản`, `Xem trước Markdown`, `Xem nhị phân`, \
                `Báo cáo: xem trước`, `Sơ đồ Mermaid: xem trước`, `Chế độ Log` — tất cả vẫn ở \
                nguyên chỗ cũ. `⌥⌘V` là **lối vào chung**, không phải bản thay thế.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )
}
