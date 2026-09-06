import Foundation

extension HelpVI {

    static let baoCao = HelpChapter(
        id: "bao-cao",
        title: "Báo cáo và sơ đồ",
        summary: "Một tệp văn bản sinh ra báo cáo HTML có số liệu tự chạy lại, và sơ đồ Mermaid.",
        topics: [baoCaoGReport, khoiQuery, khoiChart, khoiQuality, khoiMining, baoCaoHangLoat,
                 mermaid, cuPhapMermaid]
    )

    // MARK: - .greport.md

    static let baoCaoGReport = HelpTopic(
        id: "bao-cao-greport",
        title: "Báo cáo `.greport.md`",
        summary: "Markdown cộng bốn loại khối chạy được — soạn bên trái, xem trước bên phải.",
        keywords: ["báo cáo", "report", "greport", "html", "xuất", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Một tệp `.greport.md` là **Markdown thường** cộng thêm vài khối rào chạy được. \
                Dựng nó ra một tệp HTML **tự chứa** — không cần mạng, không cần tệp đi kèm — gửi \
                cho ai cũng mở được.
                """),
            .paragraph("""
                Vì là văn bản thuần nên nó **diff được, đưa vào kho mã được, chia sẻ được** — cùng \
                triết lý với công thức làm sạch và bộ luật chất lượng.
                """),
            .code(
                language: "markdown",
                caption: "bao-cao-thang-08.greport.md — một báo cáo hoàn chỉnh",
                source: """
                    ---
                    title: Báo cáo bán hàng tháng 8
                    source: ban-hang-thang-08.csv
                    ---

                    # Báo cáo bán hàng tháng 8

                    Số liệu chốt ngày 31/08/2026.

                    ## Doanh thu theo tỉnh

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Doanh thu theo tỉnh
                    y_label: Doanh thu
                    number_format: vi
                    suffix: " ₫"
                    source: Nguồn — ban-hang-thang-08.csv
                    ```

                    ## Chất lượng dữ liệu nguồn

                    ```quality
                    rules_file: chuan-ban-hang.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """
            ),
            .heading("Bốn loại khối"),
            .table(
                headers: ["Khối", "Sinh ra"],
                rows: [
                    ["`query`", "Một bảng, từ câu SQL DuckDB"],
                    ["`chart`", "Một biểu đồ"],
                    ["`quality`", "Thẻ điểm chất lượng dữ liệu"],
                    ["`mining`", "Bảng xếp hạng khai phá theo nhóm"],
                    ["`mermaid`", "Một sơ đồ"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                Khối `---` ở đầu tệp khai `title` và `source` — nguồn dữ liệu mặc định cho mọi \
                khối không tự khai nguồn riêng.
                """),
            .note("""
                Xem trước dựng lại mỗi lần bạn ngừng gõ, nhưng nó **chỉ phân tích cú pháp**, không \
                chạy truy vấn ở mỗi phím. Lỗi cú pháp của tài liệu và lỗi của dữ liệu được báo \
                tách bạch — *\"khối chart thiếu khoá `kind`\"* là lỗi tệp, *\"cột `doanh_thu` không \
                tồn tại\"* là lỗi dữ liệu.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    // MARK: - query

    static let khoiQuery = HelpTopic(
        id: "khoi-query",
        title: "Khối `query`",
        summary: "Một câu SQL DuckDB thành một bảng trong báo cáo.",
        keywords: ["query", "sql", "bảng", "báo cáo", "khối"],
        blocks: [
            .paragraph("""
                Nội dung khối là **một câu SQL**, chạy trên nguồn của báo cáo. Bảng tên `t`, cùng \
                phương ngữ với panel truy vấn.
                """),
            .code(
                language: "text",
                caption: "Khối query có tham số",
                source: """
                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu
                    FROM t
                    WHERE thang = :thang
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    ```
                    """
            ),
            .paragraph("""
                `:thang` là **tham số**. Nó được truyền vào lúc dựng — từ dòng lệnh bằng `--param \
                thang=8`, hoặc từ một tệp danh sách khi sinh báo cáo hàng loạt.
                """),
            .note("""
                Bảng trong báo cáo dữ liệu **nên đến từ khối query**, không nên gõ tay. Một bảng \
                gõ tay không chạy lại được khi số liệu đổi, và sớm muộn nó nói khác phần còn lại \
                của báo cáo.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    // MARK: - chart

    static let khoiChart = HelpTopic(
        id: "khoi-chart",
        title: "Khối `chart`",
        summary: "Cấu hình YAML thành biểu đồ — và luật quan trọng nhất của định dạng.",
        keywords: ["chart", "biểu đồ", "yaml", "báo cáo", "vẽ"],
        blocks: [
            .code(
                language: "yaml",
                caption: "Toàn bộ khoá của khối chart",
                source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Doanh thu theo tỉnh
                    x_label: Tỉnh
                    y_label: Doanh thu
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Nguồn — ban-hang.csv, chốt 26/08/2026
                    """
            ),
            .heading("Không có `query` thì dùng kết quả của khối query LIỀN TRƯỚC"),
            .paragraph("""
                Đây là luật quan trọng nhất của định dạng. Nhờ nó, một báo cáo kiểu \"bảng rồi biểu \
                đồ của chính bảng ấy\" không phải chép câu SQL hai lần — mà chép hai lần thì sớm \
                muộn hai bản lệch nhau, và khi ấy bảng nói một đằng biểu đồ nói một nẻo trong cùng \
                một trang.
                """),
            .warning("""
                Đổi lại, **thứ tự khối có nghĩa**: chèn một khối query vào giữa sẽ đổi dữ liệu của \
                biểu đồ bên dưới.
                """),
            .heading("Vì sao `source` là một khoá riêng"),
            .paragraph("""
                Viết chú thích nguồn thành một dòng văn xuôi dưới biểu đồ cũng hiện ra được — trên \
                màn hình. Nhưng biểu đồ sẽ được xuất thành PNG rồi dán đi chỗ khác, và dòng văn \
                xuôi ở lại. Là một khoá thì nó **nằm trong chính hình vẽ** và đi theo tấm ảnh.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    // MARK: - quality

    static let khoiQuality = HelpTopic(
        id: "khoi-quality",
        title: "Khối `quality`",
        summary: "Thẻ điểm chất lượng dữ liệu ngay trong báo cáo.",
        keywords: ["quality", "chất lượng", "thẻ điểm", "báo cáo", "khối"],
        blocks: [
            .code(
                language: "yaml",
                caption: "Toàn bộ khoá của khối quality",
                source: """
                    rules_file: chuan-ban-hang.yaml
                    source: ban-hang-t8.csv     # để trống thì dùng nguồn của cả báo cáo
                    title: Chất lượng dữ liệu bán hàng tháng 8
                    rules: true                 # hiện bảng luật đạt/trượt
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # đóng đinh mốc cho chiều "Tươi mới"
                    fail_under: 90              # dưới ngưỡng thì thẻ điểm đổi màu cảnh báo
                    """
            ),
            .table(
                headers: ["`chart`", "Vẽ gì"],
                rows: [
                    ["`violations`", "Số hàng vi phạm của các luật **không đạt** — nói được \"sửa cái nào trước\""],
                    ["`dimensions`", "Điểm sáu chiều"],
                    ["`none`", "Chỉ bảng, không vẽ"],
                ]
            ),
            .note("""
                Nên đặt `now:` trong báo cáo định kỳ. Không có nó, chiều *Tươi mới* so với thời \
                điểm dựng, nên dựng lại báo cáo tháng cũ sẽ ra một điểm số khác điểm đã công bố.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    // MARK: - mining

    static let khoiMining = HelpTopic(
        id: "khoi-mining",
        title: "Khối `mining`",
        summary: "Xếp hạng nhóm theo bất thường, sai số dự báo hoặc lệch tương quan.",
        keywords: ["mining", "khai phá", "báo cáo", "xếp hạng nhóm"],
        blocks: [
            .code(
                language: "yaml",
                caption: "Toàn bộ khoá của khối mining",
                source: """
                    group_by: tinh
                    value: doanh_thu          # cột chạy bất thường và dự báo
                    pair: chi_phi             # cột thứ hai, để đo tương quan trong từng nhóm
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: ban-hang.csv      # để trống thì dùng nguồn của cả báo cáo
                    title: Khai phá theo tỉnh
                    chart: true
                    """
            ),
            .table(
                headers: ["`rank`", "Xếp hạng theo"],
                rows: [
                    ["`anomalies`", "Nhóm có nhiều hàng bất thường nhất"],
                    ["`forecast_error`", "Nhóm mà dự báo sai nhiều nhất"],
                    ["`correlation_gap`", "Nhóm có tương quan lệch xa bảng gộp nhất — bắt nghịch lý Simpson"],
                ]
            ),
            .warning("""
                **Không có khoá nào tắt được khối \"Phương pháp\".** Một bảng xếp hạng nhóm không \
                kèm phương pháp thì người đọc không có cách nào biết \"nhiều bất thường nhất\" được \
                đo bằng hàng rào nào. Người muốn tắt nó đi luôn là người đã biết câu trả lời.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Hàng loạt

    static let baoCaoHangLoat = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Sinh báo cáo hàng loạt",
        summary: "Một mẫu, một danh sách tham số, ra nhiều báo cáo.",
        keywords: ["batch", "hàng loạt", "nhiều báo cáo", "tham số", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Cùng một mẫu báo cáo, chạy cho từng chi nhánh hoặc từng tháng. Danh sách tham số là \
                một tệp CSV hoặc JSON — **mỗi hàng một báo cáo**.
                """),
            .code(
                language: "text",
                caption: "danh-sach.csv — mỗi hàng một báo cáo",
                source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """
            ),
            .code(
                language: "bash",
                caption: "Dựng cả loạt từ dòng lệnh",
                source: """
                    geditor --report mau-bao-cao.greport.md \\
                            --param-list danh-sach.csv \\
                            --out ./bao-cao-thang-08/
                    """
            ),
            .code(
                language: "bash",
                caption: "Hoặc một báo cáo với tham số truyền tay",
                source: """
                    geditor --report mau-bao-cao.greport.md \\
                            --param thang=8 --param tinh="Hà Nội" \\
                            --out ./bao-cao/
                    """
            ),
            .seeAlso(["khoi-query", "dong-lenh"]),
        ]
    )

    // MARK: - Mermaid

    static let mermaid = HelpTopic(
        id: "mermaid",
        title: "Sơ đồ Mermaid",
        summary: "Vẽ sơ đồ bằng chữ, sửa bằng lệnh, và xem trước đồng bộ hai chiều.",
        keywords: ["mermaid", "sơ đồ", "diagram", "flowchart", "sequence", "vẽ"],
        commands: [
            "Sơ đồ Mermaid: xem trước", "Sơ đồ Mermaid: chèn mẫu…",
            "Sơ đồ Mermaid: thêm phần tử…", "Sơ đồ Mermaid: nối hai phần tử đang chọn",
            "Sơ đồ Mermaid: sửa nhãn phần tử đang chọn…", "Sơ đồ Mermaid: xoá phần tử đang chọn",
            "Sơ đồ Mermaid: đưa message lên trên", "Sơ đồ Mermaid: đưa message xuống dưới",
            "Sơ đồ Mermaid: định dạng lại", "Sơ đồ Mermaid: tách khối ra tệp .mmd…",
            "Sơ đồ Mermaid: nhúng tệp tham chiếu trở lại",
        ],
        blocks: [
            .paragraph("""
                Mermaid là cách vẽ sơ đồ **bằng chữ**: bạn viết mô tả, máy vẽ hình. Sơ đồ vì thế \
                diff được và đưa vào kho mã được — điều một tệp ảnh không làm được.
                """),
            .paragraph("""
                Mở `Sơ đồ Mermaid: xem trước` để có khung xem cạnh khung soạn. Hai bên **đồng bộ \
                hai chiều**: chọn một phần tử trong hình thì con nháy nhảy tới dòng của nó.
                """),
            .heading("Sửa bằng lệnh, không phải bằng cách gõ lại"),
            .table(
                headers: ["Lệnh", "Làm gì"],
                rows: [
                    ["Chèn mẫu…", "Chèn khung sẵn cho từng loại sơ đồ"],
                    ["Thêm phần tử…", "Thêm một nút hoặc một bên tham gia"],
                    ["Nối hai phần tử đang chọn", "Vẽ mũi tên giữa chúng"],
                    ["Sửa nhãn phần tử đang chọn…", "Đổi chữ mà không phải tìm đúng dòng"],
                    ["Xoá phần tử đang chọn", "Bỏ nút **và** mọi cạnh dính tới nó"],
                    ["Đưa message lên trên / xuống dưới", "Đổi thứ tự trong sơ đồ tuần tự"],
                    ["Định dạng lại", "Thụt lề và căn cho cả khối"],
                ]
            ),
            .heading("Tách ra tệp riêng và nhúng trở lại"),
            .paragraph("""
                Sơ đồ lớn nên nằm ở tệp `.mmd` riêng: `Tách khối ra tệp .mmd…` chuyển nó ra ngoài \
                và để lại một tham chiếu. `Nhúng tệp tham chiếu trở lại` làm điều ngược lại khi \
                bạn cần gửi đi một tệp duy nhất.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    // MARK: - Cú pháp Mermaid

    static let cuPhapMermaid = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Cú pháp Mermaid hay dùng",
        summary: "Bốn loại sơ đồ thường dùng nhất, mỗi loại một mẫu chạy được.",
        keywords: ["mermaid", "cú pháp", "flowchart", "sequence", "gantt", "class", "mẫu"],
        blocks: [
            .code(
                language: "mermaid",
                caption: "Lưu đồ — quy trình duyệt đơn",
                source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """
            ),
            .code(
                language: "mermaid",
                caption: "Sơ đồ tuần tự — luồng thanh toán",
                source: """
                    sequenceDiagram
                        participant K as Khách
                        participant W as Website
                        participant T as Cổng thanh toán
                        K->>W: Đặt hàng
                        W->>T: Tạo giao dịch
                        T-->>W: Mã giao dịch
                        W-->>K: Chuyển tới trang thanh toán
                        K->>T: Xác nhận
                        T-->>W: Kết quả
                    """
            ),
            .code(
                language: "mermaid",
                caption: "Sơ đồ lớp — mô hình dữ liệu",
                source: """
                    classDiagram
                        class DonHang {
                            +String maDon
                            +Date ngayDat
                            +tongTien() Double
                        }
                        class KhachHang {
                            +String ten
                            +String soDienThoai
                        }
                        KhachHang "1" --> "*" DonHang : đặt
                    """
            ),
            .code(
                language: "mermaid",
                caption: "Gantt — kế hoạch phát hành",
                source: """
                    gantt
                        title Kế hoạch phát hành
                        dateFormat YYYY-MM-DD
                        section Chuẩn bị
                        Viết tài liệu     :a1, 2026-09-01, 10d
                        Kiểm thử          :a2, after a1, 7d
                        section Phát hành
                        Nộp App Store     :a3, after a2, 3d
                    """
            ),
            .table(
                headers: ["Hình dạng nút", "Viết"],
                rows: [
                    ["Chữ nhật", "`A[Nhãn]`"],
                    ["Bo tròn", "`A(Nhãn)`"],
                    ["Viên thuốc", "`A([Nhãn])`"],
                    ["Thoi (điều kiện)", "`A{Nhãn}`"],
                    ["Trụ (dữ liệu)", "`A[(Nhãn)]`"],
                ]
            ),
            .table(
                headers: ["Mũi tên", "Viết"],
                rows: [
                    ["Đặc, có đầu", "`A --> B`"],
                    ["Đứt nét", "`A -.-> B`"],
                    ["Đậm", "`A ==> B`"],
                    ["Có nhãn", "`A -- nhãn --> B`"],
                ]
            ),
            .note("""
                Hướng của lưu đồ đặt ngay sau `flowchart`: `TD` trên xuống, `LR` trái sang phải, \
                `BT`, `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )
}
