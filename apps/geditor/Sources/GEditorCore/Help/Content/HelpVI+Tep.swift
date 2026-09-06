import Foundation

extension HelpVI {

    static let tep = HelpChapter(
        id: "tep",
        title: "Tệp và phiên làm việc",
        summary: "Mở, lưu, tab, cửa sổ, không gian làm việc, và cách phiên tự quay lại.",
        topics: [moVaLuu, tabVaCuaSo, khongGianLamViec, phienLamViec, banDaLuu, theoDoiTep, inAn,
                 tepKhongPhaiVanBan, congCuPDF]
    )

    // MARK: - Mở và lưu

    static let moVaLuu = HelpTopic(
        id: "mo-va-luu",
        title: "Mở và lưu",
        summary: "Mở tệp bất kể cỡ nào, và lưu với bảng mã hoặc kiểu xuống dòng khác.",
        keywords: ["open", "save", "mở", "lưu", "lưu thành", "as"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Tài liệu mới"),
                HelpShortcut("⌘O", "Mở tệp"),
                HelpShortcut("⌘S", "Lưu"),
                HelpShortcut("⇧⌘S", "Lưu thành"),
            ]),
            .paragraph("""
                Kéo tệp vào cửa sổ cũng mở được. `File ▸ Mở gần đây` giữ danh sách những tệp vừa \
                làm việc.
                """),
            .heading("Lưu thành: ba thứ đổi được"),
            .table(
                headers: ["Đổi", "Nghĩa"],
                rows: [
                    ["Bảng mã", "Ghi ra UTF-8, TCVN3, VNI-Windows… — 36 bảng mã"],
                    ["Kiểu xuống dòng", "LF (Unix) · CRLF (Windows) · CR (Mac cổ)"],
                    ["Tên và nơi để", "Như mọi hộp thoại lưu của macOS"],
                ]
            ),
            .paragraph("""
                Thanh trạng thái luôn nói bảng mã, kiểu xuống dòng và ngôn ngữ đang nhận ra. \
                **Bấm vào từng mục ở đó là đổi được ngay**, không cần đi vòng qua hộp thoại.
                """),
            .heading("Nhân bản · đổi tên · chuyển chỗ"),
            .paragraph("""
                Ba lệnh này làm việc trên TỆP, không phải trên nội dung — và tab đang mở đi theo \
                tệp, nên bạn không mất chỗ đang đọc.
                """),
            .table(
                headers: ["Lệnh", "Việc nó làm"],
                rows: [
                    ["`Nhân bản tệp`",
                     "Chép thành `tên 2.txt` cạnh tệp gốc rồi **mở bản sao ra** — vì người ta nhân bản để sửa bản sao"],
                    ["`Đổi tên tệp…`", "Đổi tên trên đĩa; tab trỏ sang tên mới"],
                    ["`Chuyển tệp tới…`", "Dời sang thư mục khác; tab trỏ sang chỗ mới"],
                ]
            ),
            .note("""
                Cả ba đều **từ chối khi có tệp cùng tên ở đích**, không ghi đè. Và cả ba đều đòi \
                tệp đã lưu ít nhất một lần — một tài liệu chưa từng ở trên đĩa thì không có gì \
                để nhân bản hay dời đi.
                """),
            .heading("Ghi an toàn"),
            .bullets([
                "Phép ghi là **nguyên tử**: mất điện giữa chừng không để lại một tệp cụt đầu.",
                "Tệp bị chương trình khác sửa trong lúc bạn đang mở thì GEditor phát hiện và hỏi trước khi đè.",
                "Tệp trên iCloud Drive hoặc ổ mạng đi qua bộ điều phối của hệ điều hành, nên hai máy không giẫm lên nhau.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    // MARK: - Tab và cửa sổ

    static let tabVaCuaSo = HelpTopic(
        id: "tab-va-cua-so",
        title: "Tab, cửa sổ và chia đôi màn hình",
        summary: "Nhiều tab trong một cửa sổ, nhiều cửa sổ, và tab kéo qua lại được.",
        keywords: ["tab", "cửa sổ", "window", "split", "chia đôi"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Tab mới"),
                HelpShortcut("⌘W", "Đóng tab"),
                HelpShortcut("⇧⌘T", "Mở lại tab vừa đóng"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Tab kế / Tab trước"),
                HelpShortcut("⌥⌘N", "Cửa sổ mới"),
                HelpShortcut("⌃⌘N", "Tách tab đang mở ra cửa sổ riêng"),
            ]),
            .paragraph("""
                Kéo một tab sang cửa sổ khác được, và kéo nó ra khoảng trống để tự thành cửa sổ \
                mới. **Tab đang ghim thì không đi đâu cả** — ghim có nghĩa là "giữ tab này ở đây".
                """),
            .note("""
                `⇧⌘T` mở lại tab vừa đóng, kể cả tab **chưa lưu**: nội dung của nó vẫn còn.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    // MARK: - Workspace

    static let khongGianLamViec = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Mở cả thư mục làm không gian làm việc",
        summary: "Cây thư mục ở sidebar, tìm trong cả dự án, và tệp mở bằng một lần bấm.",
        keywords: ["workspace", "thư mục", "folder", "dự án", "project", "sidebar"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Mở thư mục làm không gian làm việc")]),
            .paragraph("""
                Cây thư mục hiện ở sidebar (`⌘0`). Bấm một tệp là mở, và `⇧⌘F` tìm trong toàn bộ \
                thư mục ấy.
                """),
            .note("""
                Ở bản App Store, quyền vào thư mục được giữ bằng **bookmark có phạm vi bảo mật**, \
                nên lần mở app sau vẫn vào được mà không phải chọn lại thư mục.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    // MARK: - Phiên làm việc

    static let phienLamViec = HelpTopic(
        id: "phien-lam-viec",
        title: "Phiên làm việc tự quay lại",
        summary: "Đóng app rồi mở lại, mọi tab về đúng chỗ — kể cả tab chưa lưu.",
        keywords: ["session", "phiên", "khôi phục", "restore", "chưa lưu", "mất bài"],
        blocks: [
            .paragraph("""
                Không có gì phải bật. Thoát GEditor rồi mở lại thì tab, thứ tự tab, vị trí con \
                nháy và vị trí cuộn đều quay về.
                """),
            .heading("Tab chưa lưu thì sao"),
            .paragraph("""
                Nội dung của nó được giữ trong một bản chụp riêng, nên nó cũng quay lại. Nếu ứng \
                dụng thoát bất thường, lần mở sau GEditor **hỏi** trước khi khôi phục những bản \
                nháp mồ côi — chứ không tự dựng lại một đống tab bạn không nhớ.
                """),
            .warning("""
                Phiên làm việc **không phải bản sao lưu**. Nó giữ trạng thái làm việc, không giữ \
                lịch sử. Việc gì quan trọng thì vẫn phải lưu ra tệp.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    // MARK: - Bản đã lưu

    static let banDaLuu = HelpTopic(
        id: "ban-da-luu",
        title: "Bản đã lưu trước đây",
        summary: "Xem lại và khôi phục các phiên bản cũ của một tệp.",
        keywords: ["versions", "phiên bản", "lịch sử", "khôi phục", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Mỗi lần lưu, GEditor ghi lại bản **cũ** trước khi đè lên. `Macro ▸ Bản đã lưu…` \
                mở bảng duyệt các bản ấy.
                """),
            .bullets([
                "Kho phiên bản là kho **của hệ điều hành**, cùng cơ chế mà các ứng dụng Apple dùng.",
                "Khôi phục một bản cũ là một **sửa đổi bình thường** — hoàn tác được bằng `⌘Z`.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    // MARK: - tail -f

    static let theoDoiTep = HelpTopic(
        id: "theo-doi-tep",
        title: "Theo dõi tệp đang được ghi",
        summary: "Như `tail -f`: phần mới ghi vào cuối tệp tự hiện ra.",
        keywords: ["tail", "follow", "log", "theo dõi", "realtime"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `File ▸ Theo dõi file (tail -f)` nạp thêm phần mới xuất hiện ở cuối tệp và cuộn \
                theo.
                """),
            .warning("""
                Trong lúc theo dõi, tài liệu chuyển sang **chỉ đọc**. Vừa gõ vừa nạp thêm từ đĩa \
                là hai nguồn sửa đổi tranh nhau, và bên thua luôn là phần bạn vừa gõ.
                """),
            .note("""
                Thanh trạng thái ghi **Đang theo dõi** suốt thời gian ấy, nên vài phút sau bạn \
                vẫn biết vì sao tệp không gõ được. Bấm vào mục **chỉ đọc** thì nó nói thẳng lý do.

                Theo dõi gắn với **tab đặt nó**, không gắn với cửa sổ: mở tab khác gõ tiếp thì \
                dòng log mới vẫn chảy vào đúng tab của nó, không đụng vào tệp bạn đang soạn.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    // MARK: - In

    static let inAn = HelpTopic(
        id: "in-an",
        title: "In",
        summary: "In tài liệu qua hộp thoại in chuẩn của macOS.",
        keywords: ["print", "in", "giấy", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "In")]),
            .paragraph("""
                Dùng hộp thoại in của hệ điều hành, nên xuất ra PDF cũng từ đó — nút `PDF` ở góc \
                dưới bên trái.
                """),
        ]
    )

    // MARK: - Tệp không phải văn bản

    static let tepKhongPhaiVanBan = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Ảnh, PDF, Office, nhạc, phim và tệp nén",
        summary: "Tám loại tệp mở được ngay trong GEditor mà không cần ứng dụng khác.",
        keywords: ["ảnh", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "nén",
                   "nhạc", "phim", "audio", "video", "mp3", "mp4"],
        blocks: [
            .table(
                headers: ["Loại", "Làm được gì"],
                rows: [
                    ["Ảnh", "Xem, phóng to thu nhỏ, xoay; **ảnh động thì phát được** và tạm dừng được"],
                    ["Nhạc", "Phát, tua, đổi âm lượng"],
                    ["Phim", "Phát, tua, toàn màn hình, ảnh trong ảnh"],
                    ["PDF", "Xem, tìm chữ, **chú thích**"],
                    ["Word · Excel · PowerPoint", "Xem **và sửa** — `⌘S` ghi thẳng vào tệp gốc"],
                    ["ZIP · TAR · GZ · XZ", "Liệt kê và mở từng mục thành tab"],
                    ["7z · RAR và 7 định dạng khác", "Như trên, qua libarchive"],
                ]
            ),
            .paragraph("""
                Mở một mục trong tệp nén sẽ tạo tab mới với nội dung của mục ấy. Dấu tiếng Việt \
                trong tên và trong nội dung đều giữ nguyên.
                """),
            .note("""
                Ba định dạng Office sửa xong `⌘S` là ghi thẳng vào tệp, và LibreOffice mở lại đọc \
                được — đây là đường đã được kiểm đầu-cuối chứ không phải chỉ xuất ra bản sao.
                """),
            .heading("Nhạc và phim: dùng bộ phát của macOS"),
            .paragraph("""
                Phát bằng chính bộ giải mã của hệ điều hành, nên không có thư viện nào phải tải \
                thêm và không tốn thêm dung lượng. Đổi lại, vài định dạng **không phát được** — \
                `.mkv`, `.webm`, `.avi`, `.wmv` — vì macOS không có bộ giải mã sẵn cho chúng.
                """),
            .paragraph("""
                Gặp một tệp như thế, GEditor **nói rõ lý do** thay vì hiện một ô đen, và mời bạn \
                sang chế độ nhị phân hoặc mở bằng ứng dụng khác.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    // MARK: - Công cụ PDF

    static let congCuPDF = HelpTopic(
        id: "cong-cu-pdf",
        title: "Công cụ PDF",
        summary: "Đọc, chú thích, và cả một tầng thao tác trang: xoay · dời · xoá · trích · gộp.",
        keywords: ["pdf", "trang", "xoay", "xoá trang", "trích", "gộp", "merge", "split",
                   "chú thích", "bôi vàng", "ký"],
        blocks: [
            .paragraph("""
                Khung PDF có **hai hàng công cụ**, và chúng trả lời hai câu khác nhau. Hàng trên \
                làm việc với **nội dung** một trang; hàng dưới làm việc với **tập hợp trang**.
                """),
            .heading("Hàng trên — đọc và chú thích"),
            .table(
                headers: ["Nút", "Làm gì"],
                rows: [
                    ["Bôi vàng · Gạch chân", "Đánh dấu phần chữ đang chọn"],
                    ["Ghi chú…", "Gắn một ghi chú vào trang"],
                    ["Bỏ chú thích", "Gỡ mọi chú thích trên trang đang xem"],
                    ["Lấy chữ ra tab mới", "Đưa toàn bộ chữ sang một tab để tìm, lọc, chạy công cụ khác"],
                    ["Ô tìm", "Tìm trong PDF — **gõ không dấu vẫn ra chữ có dấu**"],
                ]
            ),
            .note("""
                PDF quét từ giấy không có tầng chữ. Lệnh lấy chữ sẽ **nói ra điều đó** thay vì mở \
                một tab trống để bạn tự đoán.
                """),
            .heading("Hàng dưới — thao tác trang"),
            .table(
                headers: ["Nút", "Làm gì", "Hoàn tác được"],
                rows: [
                    ["Xoay trái · Xoay phải", "Xoay trang đang xem 90°", "Có"],
                    ["Trang lên · Trang xuống", "Đổi chỗ trang đang xem với trang liền kề", "Có"],
                    ["Xoá trang…", "Xoá theo dãy, ví dụ `2-4,7`", "Có"],
                    ["Trích trang…", "Ghi một dãy trang ra **tệp mới**", "Không đụng tệp đang mở"],
                    ["Gộp tệp PDF…", "Chèn cả một PDF khác vào ngay sau trang đang xem", "Có"],
                    ["Ký…", "Chèn ảnh chữ ký lên trang đang xem", "Có"],
                    ["Sửa chữ…", "Vẽ đè chữ mới lên phần đang bôi chọn", "Có"],
                    ["Ô chưa điền", "Nhảy tới ô biểu mẫu trống tiếp theo", "—"],
                    ["Xoá nội dung đã điền", "Làm trắng mọi ô biểu mẫu", "Có"],
                    ["Hoàn tác trang", "Lùi lại một thao tác trang", "—"],
                    ["Lưu bản đã sửa…", "Ghi ra tệp mới rồi **mở lại kiểm chứng**", "—"],
                ]
            ),
            .heading("Biểu mẫu điền được"),
            .paragraph("""
                Mở một PDF có ô biểu mẫu, thanh trạng thái nói ngay **có bao nhiêu ô**. Gõ thẳng \
                vào ô trên trang, rồi `Lưu bản đã sửa…`.
                """),
            .bullets([
                "Giá trị được ghi thành **ô biểu mẫu sống**, không phải chữ dán chết — nên Acrobat của bên nhận biết tờ khai đã điền, và họ sửa lại được.",
                "Chữ có dấu tiếng Việt giữ nguyên qua vòng ghi–mở lại. Có bài kiểm gác đúng vế ấy với tên `Nguyễn Văn Anh`.",
                "`Ô chưa điền` nhảy tới ô trống kế tiếp — đường đi tự nhiên khi khai một tờ dài.",
            ]),
            .heading("Ký"),
            .paragraph("""
                Chuẩn bị một ảnh chữ ký (PNG nền trong suốt là đẹp nhất), **bôi chọn chỗ cần ký** \
                — thường là dòng kẻ hoặc chữ «Ký tên» — rồi bấm `Ký…`. Không chọn gì thì chữ ký \
                rơi vào góc dưới bên phải.
                """),
            .note("""
                Chữ ký giữ đúng **tỉ lệ ảnh**: một chữ ký bị kéo dẹt hay kéo dài trông giả ngay \
                lập tức.
                """),
            .heading("Sửa chữ — và ba điều phải biết trước"),
            .paragraph("""
                Bôi chọn phần chữ cần sửa rồi bấm `Sửa chữ…`. GEditor **phủ vùng ấy bằng màu nền \
                lấy mẫu ngay cạnh nó**, rồi vẽ chữ mới lên.
                """),
            .warning("""
                **Chữ cũ bị CHE, không bị XOÁ.** Nó vẫn nằm trong tệp và vẫn lấy ra được bằng \
                `Lấy chữ ra tab mới` hay bất kỳ công cụ nào khác. Đây **không phải cách bôi đen** \
                — che một số căn cước bằng lối này là che với mắt người, không che với máy.
                """),
            .bullets([
                "**Chữ mới vẫn tìm được bằng `⌘F`.** Nó được vẽ thành chữ thật, không thành ảnh — điều này đã đo bằng bài kiểm, không phải suy đoán.",
                "**Font là font hệ thống**, không phải font gốc của tài liệu. Cố ý: font nhúng trong tệp thường không có dấu tiếng Việt, và `Nguyễn` sẽ thành `Nguy?n` trên máy người nhận.",
                "**Nền có hoa văn thì vết vá lộ ra** — màu phủ chỉ lấy một mẫu ngay bên trái vùng chọn.",
            ]),
            .heading("Vì sao vẽ đè chứ không sửa thẳng nội dung"),
            .paragraph("""
                Sửa thẳng luồng nội dung PDF đụng vào font con có mã hoá riêng, câu bị cắt làm ba \
                mảnh vì kerning, và bảng độ rộng ký tự phải tính lại. Làm đúng cho **mọi** tệp là \
                một dự án riêng; làm sai thì hỏng tệp của người khác.
                """),
            .paragraph("""
                Đổi lại, phần còn lại của trang **không đổi một byte nào**, và trang vẫn là trang \
                — chữ vẫn chọn được, chép được, tìm được. Vẽ lại trang **không** biến nó thành ảnh.
                """),
            .heading("Cú pháp dãy trang"),
            .table(
                headers: ["Gõ", "Nghĩa"],
                rows: [
                    ["`5`", "Riêng trang 5"],
                    ["`2-4`", "Trang 2, 3, 4"],
                    ["`-3`", "Từ đầu tới trang 3"],
                    ["`8-`", "Từ trang 8 tới hết"],
                    ["`1-3,5,9-`", "Ghép nhiều mục bằng dấu phẩy"],
                ]
            ),
            .paragraph("""
                Trang đếm **từ 1**, đúng con số bạn thấy trên màn hình.
                """),
            .warning("""
                Dãy viết ngược (`5-2`) và dãy vượt số trang (`1-999`) đều **bị từ chối kèm lý do**, \
                không tự sửa thành thứ gần đúng. Với một lệnh xoá trang thì đoán sai nghĩa là mất \
                trang, và tự cắt bớt biến một câu gõ nhầm thành một câu chạy được.
                """),
            .heading("Tệp gốc không bao giờ bị đè"),
            .paragraph("""
                Mọi thao tác ở trên đổi tài liệu **đang mở trong bộ nhớ**. Chỉ khi bạn bấm \
                `Lưu bản đã sửa…` và chọn chỗ thì mới có tệp được ghi — và ghi xong GEditor **mở \
                lại chính tệp ấy** để chắc nó còn đủ số trang.
                """),
            .paragraph("""
                Lý do: một tệp ghi hỏng vẫn nằm trên đĩa trông như một tệp bình thường, và người \
                dùng chỉ phát hiện ra khi đã gửi nó đi.
                """),
            .note("""
                Thanh trạng thái của khung ghi rõ **· đã sửa, chưa lưu** khi tài liệu khác với tệp \
                trên đĩa.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
