import Foundation

extension HelpVI {

    static let csv = HelpChapter(
        id: "csv",
        title: "Dữ liệu bảng",
        summary: "Xem CSV thành bảng, lọc, sắp, kiểm cấu trúc, truy vấn SQL và xuất sang định dạng khác.",
        topics: [bangCSV, sheetExcel, locVaSapBang, kiemTraDuLieu, xoaCot, truyVanSQL,
                 pivotVaBieuDo, chuyenDoiDinhDang, dauPhanTach]
    )

    // MARK: - Bảng CSV

    static let bangCSV = HelpTopic(
        id: "bang-csv",
        title: "Xem CSV dạng bảng",
        summary: "Một triệu hàng vẫn cuộn mượt, hàng tiêu đề dính, và văn bản gốc không hề đổi.",
        keywords: ["csv", "bảng", "table", "tsv", "excel", "cột"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Chuyển giữa dạng Bảng và dạng Văn bản")]),
            .paragraph("""
                Bảng được **ảo hoá**: chỉ những hàng đang nhìn thấy mới được dựng, nên một tệp một \
                triệu hàng cuộn mượt như một tệp trăm hàng.
                """),
            .bullets([
                "**Hàng tiêu đề dính** khi cuộn — tới hàng 40.000 vẫn biết cột thứ chín là cột gì.",
                "Sửa ô ngay trong bảng; thay đổi đi thẳng vào văn bản gốc.",
                "Dạng Bảng và dạng Văn bản là **hai cách nhìn cùng một tệp**, không phải hai bản sao.",
                "**⌘C chép hàng đang chọn**, các ô cách nhau bằng TAB — dán thẳng vào Excel hay Numbers là ra đúng từng ô. Ô nào chứa TAB hay xuống dòng thì được bọc trong dấu nháy, nên chỗ dán không tách nhầm nó làm đôi.",
            ]),
            .note("""
                Dấu phân tách được đoán khi mở (phẩy, chấm phẩy, TAB, sổ đứng). Đoán sai thì đổi \
                bằng `CSV ▸ Đổi dấu phân tách…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    // MARK: - Lọc và sắp

    static let locVaSapBang = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Lọc và sắp xếp trong bảng",
        summary: "Ô lọc trên mỗi cột, hiểu cả phép so số và gõ không dấu.",
        keywords: ["lọc", "filter", "sắp xếp", "sort", "cột", "tìm trong bảng"],
        blocks: [
            .paragraph("Bấm tiêu đề cột để sắp. Ô lọc dưới tiêu đề nhận các dạng sau:"),
            .table(
                headers: ["Gõ vào ô lọc", "Nghĩa"],
                rows: [
                    ["`hue`", "Chứa chữ `hue`, **bỏ dấu** — ra cả `Huế`"],
                    ["`=Huế`", "Bằng đúng `Huế` (vẫn bỏ dấu)"],
                    ["`>100`", "Lớn hơn 100"],
                    ["`>=100`", "Từ 100 trở lên"],
                    ["`<0`", "Nhỏ hơn 0"],
                    ["`100..200`", "Trong khoảng 100 đến 200"],
                    ["ô trống", "Không lọc cột này"],
                ]
            ),
            .paragraph("""
                Lọc nhiều cột cùng lúc là phép **và** — hàng phải thoả hết. Phép so số bỏ qua ô \
                không phải số thay vì coi chúng bằng 0.
                """),
            .note("""
                Lọc là **cách nhìn**, không xoá dữ liệu. Bỏ lọc là mọi hàng quay lại.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    // MARK: - Kiểm tra dữ liệu

    static let kiemTraDuLieu = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Kiểm tra cấu trúc bảng",
        summary: "Tìm hàng lệch số cột và ô sai kiểu — bước nên làm đầu tiên với tệp lạ.",
        keywords: ["validate", "kiểm tra", "lệch cột", "sai kiểu", "hỏng dữ liệu"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Đây là việc nên làm **trước** mọi thứ khác với một tệp người khác gửi. Nó trả lời \
                hai câu:
                """),
            .bullets([
                "**Hàng nào lệch số cột?** Thường do một ô chứa dấu phẩy mà không được bọc trong dấu nháy — và nó làm mọi hàng phía sau lệch theo.",
                "**Ô nào sai kiểu so với phần còn lại của cột?** Ví dụ chữ `n/a` nằm giữa một cột toàn số.",
            ]),
            .paragraph("""
                Kết quả hiện thành danh sách, bấm là nhảy tới đúng hàng.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    // MARK: - Xoá cột

    static let xoaCot = HelpTopic(
        id: "xoa-cot",
        title: "Xoá cột",
        summary: "Bỏ hẳn một hoặc nhiều cột khỏi tệp.",
        keywords: ["xóa cột", "bỏ cột", "drop column"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Chọn cột cần bỏ trong danh sách rồi áp. Là **một** bước hoàn tác dù tệp có bao \
                nhiêu hàng.
                """),
            .warning("""
                Khác với lọc, đây là phép **sửa tệp thật**. Muốn chỉ giấu cột đi thì dùng truy vấn \
                SQL với danh sách cột bạn cần.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    // MARK: - SQL

    static let truyVanSQL = HelpTopic(
        id: "truy-van-sql",
        title: "Truy vấn CSV bằng SQL",
        summary: "SQL đầy đủ của DuckDB chạy thẳng trên tệp đang mở — chỉ đọc.",
        keywords: ["sql", "truy vấn", "query", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Bảng đang mở có tên là **`t`**. Bộ máy là **DuckDB**, nên `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, hàm cửa sổ và truy vấn con đều dùng được.
                """),
            .code(
                language: "sql",
                caption: "Tổng doanh thu theo tỉnh, cao nhất trước",
                source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """
            ),
            .code(
                language: "sql",
                caption: "Lọc theo ngày và theo điều kiện chữ",
                source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """
            ),
            .code(
                language: "sql",
                caption: "Tỷ trọng từng tỉnh trên tổng — dùng hàm cửa sổ",
                source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """
            ),
            .code(
                language: "sql",
                caption: "Nối với một tệp khác trên đĩa",
                source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """
            ),
            .heading("Chỉ đọc, và đó là bảo đảm cứng"),
            .bullets([
                "Cơ sở dữ liệu nằm **trong bộ nhớ**; tệp nguồn chỉ được đọc.",
                "Chỉ nhận **đúng một câu**, và câu ấy **phải là `SELECT`**. Mọi thứ khác — kể cả `COPY … TO 'tệp'`, thứ DuckDB hoàn toàn có thể dùng để ghi ra đĩa — bị chặn trước khi chạm tới dữ liệu.",
            ]),
            .warning("""
                DuckDB đọc **tệp**, không đọc vùng nhớ. Nếu tài liệu đang sửa mà chưa lưu, GEditor \
                phải ghi một bản tạm trước khi truy vấn. Với tệp rất lớn đang sửa dở, GEditor \
                **chặn và nói ra** thay vì lặng lẽ ghi hàng trăm MB xuống đĩa cho một câu truy vấn.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Pivot và biểu đồ

    static let pivotVaBieuDo = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Pivot và biểu đồ nhanh",
        summary: "Xoay bảng và vẽ biểu đồ ngay từ kết quả truy vấn.",
        keywords: ["pivot", "biểu đồ", "chart", "đồ thị", "xoay bảng", "tổng hợp"],
        blocks: [
            .paragraph("""
                Cả hai mở từ **bảng kết quả truy vấn**: chạy một câu SQL xong, dùng nút Pivot hoặc \
                Biểu đồ trên panel.
                """),
            .heading("Pivot"),
            .paragraph("""
                Chọn cột làm **hàng**, cột làm **cột**, cột làm **giá trị**, và phép gộp (tổng, \
                đếm, trung bình, nhỏ nhất, lớn nhất) — như bảng tổng hợp của bảng tính.
                """),
            .heading("Biểu đồ"),
            .paragraph("""
                Cột, đường, tròn, phân tán. Định dạng số theo kiểu Việt hoặc kiểu Âu, và biểu đồ \
                xuất ra được PNG hoặc SVG để dán đi chỗ khác.
                """),
            .note("""
                Muốn biểu đồ **tự cập nhật theo dữ liệu** mỗi lần dựng lại? Đó là khối `chart` \
                trong báo cáo `.greport.md`.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    // MARK: - Chuyển đổi

    static let chuyenDoiDinhDang = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Chuyển bảng sang định dạng khác",
        summary: "TSV, JSON, XML, bảng Markdown, câu lệnh SQL INSERT — có xem trước.",
        keywords: ["chuyển đổi", "convert", "xuất", "export", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Định dạng", "Dùng để"],
                rows: [
                    ["TSV", "Dán vào bảng tính mà không lo ô chứa dấu phẩy"],
                    ["JSON", "Đưa vào API, script, hoặc công cụ khác"],
                    ["XML", "Hệ thống cũ đòi XML"],
                    ["Bảng Markdown", "Dán vào tài liệu, README, ticket"],
                    ["Câu lệnh SQL INSERT", "Nạp vào cơ sở dữ liệu"],
                ]
            ),
            .paragraph("""
                Hộp thoại **xem trước năm hàng đầu** trước khi tạo tab mới — nhìn năm dòng là biết \
                tên bảng, dấu bọc và cột nào thành số có đúng ý không.
                """),
            .note("""
                Bản xem trước gọi **đúng hàm** sinh ra bản thật, chỉ giới hạn năm hàng. Nó không \
                phải một bản mô phỏng có thể nói khác kết quả cuối.
                """),
        ]
    )

    // MARK: - Dấu phân tách

    static let dauPhanTach = HelpTopic(
        id: "dau-phan-tach",
        title: "Đổi dấu phân tách",
        summary: "Chuyển tệp giữa phẩy, chấm phẩy, TAB và sổ đứng.",
        keywords: ["delimiter", "dấu phân tách", "phẩy", "chấm phẩy", "tab", "csv châu âu"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Tệp xuất từ Excel bản tiếng Việt hoặc tiếng Âu thường dùng **chấm phẩy**, vì dấu \
                phẩy ở đó là dấu thập phân.
                """),
            .warning("""
                Đổi dấu phân tách **ghi lại cả tệp**. Ô nào chứa dấu phân tách mới sẽ được bọc \
                trong dấu nháy — nếu không thì cấu trúc bảng vỡ.
                """),
            .note("""
                **Đoán sai thì đừng dùng lệnh này.** Có hai việc khác nhau, đúng như cặp \
                «diễn giải lại» / «chuyển đổi» của bảng mã:

                • *Tệp vốn là chấm phẩy, sản phẩm đoán nhầm là phẩy* — bấm mục `CSV · …` trên \
                **thanh trạng thái** rồi chọn dấu đúng. Tệp không bị sửa một byte nào; chỉ cách \
                đọc đổi.

                • *Tệp đúng là phẩy, và bạn muốn nó thành chấm phẩy* — dùng lệnh trên trang này. \
                Nó ghi lại tệp.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Sheet của Excel

    static let sheetExcel = HelpTopic(
        id: "sheet-excel",
        title: "Bảng tính nhiều sheet",
        summary: "Mở từng sheet của một tệp .xlsx, và ⌘S ghi ngược vào đúng sheet đang xem.",
        keywords: ["excel", "xlsx", "sheet", "trang tính", "workbook", "nhiều sheet"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Mở một tệp `.xlsx`, GEditor hiện **sheet đầu tiên** dưới dạng bảng CSV. \
                `CSV ▸ Chọn sheet…` liệt kê mọi sheet trong tệp và mở sheet bạn chọn vào chính \
                tab ấy.
                """),
            .heading("Ghi ngược vào ĐÚNG sheet"),
            .paragraph("""
                `⌘S` ghi phần bạn vừa sửa vào **đúng sheet đang xem**, không phải sheet đầu. \
                Các sheet còn lại không bị đụng tới một byte nào.
                """),
            .note("""
                Sheet được nhớ theo **tên**, không theo thứ tự. Nhờ vậy sắp lại sheet trong Excel \
                giữa hai lần mở cũng không làm lệch chỗ ghi.
                """),
            .warning("""
                Nếu sheet đang mở đã bị **đổi tên hoặc xoá** trong Excel từ lúc bạn mở nó, `⌘S` \
                **từ chối ghi** và nói ra. Rơi về sheet đầu nghĩa là đổ nội dung của một sheet \
                lên một sheet khác — tệp vẫn ghi được, vẫn mở lại được, chỉ là dữ liệu nằm sai chỗ.
                """),
            .heading("Đổi sheet khi đang sửa dở"),
            .paragraph("""
                Đổi sheet thay toàn bộ nội dung tab, nên nếu còn phần chưa lưu thì GEditor **hỏi \
                trước**. `⌘Z` không lấy lại được phần ấy, vì cả tài liệu đã bị tráo.
                """),
            .heading("Cái giá của việc đưa Excel về bảng"),
            .paragraph("""
                Thứ đi qua là **giá trị** — kể cả kết quả của công thức, đúng con số Excel đang \
                hiện. Thứ không đi qua: font, màu, ô gộp, biểu đồ nhúng, và bản thân công thức.
                """),
            .paragraph("""
                Đổi lại, sheet ấy dùng được toàn bộ phần còn lại của sản phẩm: lọc, sắp, truy vấn \
                SQL, bàn làm sạch, chấm chất lượng, khai phá, biểu đồ.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )
}
