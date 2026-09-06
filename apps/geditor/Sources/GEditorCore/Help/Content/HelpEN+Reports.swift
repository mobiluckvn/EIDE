import Foundation

extension HelpEN {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Reports and diagrams",
        summary: "A text file that produces an HTML report whose figures rerun, plus Mermaid diagrams.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    // MARK: - .greport.md

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md` reports",
        summary: "Markdown plus four runnable block types — write on the left, preview on the right.",
        keywords: ["report", "greport", "html", "export", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                A `.greport.md` file is **ordinary Markdown** plus a few runnable fenced blocks. \
                Rendering it produces a **self-contained** HTML file — no network, no companion \
                files — that anyone can open.
                """),
            .paragraph("""
                Because it is plain text it can be **diffed, committed and shared** — the same \
                philosophy as cleaning recipes and quality rule sets.
                """),
            .code(
                language: "markdown",
                caption: "sales-2026-08.greport.md — a complete report",
                source: """
                    ---
                    title: August sales report
                    source: sales-2026-08.csv
                    ---

                    # August sales report

                    Figures as of 31 August 2026.

                    ## Revenue by province

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Revenue by province
                    y_label: Revenue
                    number_format: vi
                    suffix: " ₫"
                    source: Source — sales-2026-08.csv
                    ```

                    ## Source data quality

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """
            ),
            .heading("The block types"),
            .table(
                headers: ["Block", "Produces"],
                rows: [
                    ["`query`", "A table, from a DuckDB SQL statement"],
                    ["`chart`", "A chart"],
                    ["`quality`", "A data-quality scorecard"],
                    ["`mining`", "A group-mining ranking table"],
                    ["`mermaid`", "A diagram"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                The `---` block at the top declares `title` and `source` — the default data source \
                for every block that does not name its own.
                """),
            .note("""
                The preview rebuilds whenever you stop typing, but it **only parses**; it does not \
                run queries on every keystroke. Document errors and data errors are reported \
                separately — *\"the chart block is missing the `kind` key\"* is a file error, \
                *\"column `doanh_thu` does not exist\"* is a data error.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    // MARK: - query block

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "The `query` block",
        summary: "One DuckDB statement becomes one table in the report.",
        keywords: ["query", "sql", "table", "report", "block"],
        blocks: [
            .paragraph("""
                The block's contents are **one SQL statement**, run against the report's source. The \
                table is called `t`, in the same dialect as the query panel.
                """),
            .code(
                language: "text",
                caption: "A parameterised query block",
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
                `:thang` is a **parameter**. It is supplied at render time — from the shell with \
                `--param thang=8`, or from a list file when generating reports in bulk.
                """),
            .note("""
                Tables in a data report **should come from a query block**, not be typed by hand. A \
                hand-typed table does not rerun when the figures change, and sooner or later it \
                disagrees with the rest of the report.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    // MARK: - chart block

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "The `chart` block",
        summary: "YAML configuration becomes a chart — and the format's most important rule.",
        keywords: ["chart", "yaml", "report", "plot"],
        blocks: [
            .code(
                language: "yaml",
                caption: "Every key of a chart block",
                source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Revenue by province
                    x_label: Province
                    y_label: Revenue
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Source — sales.csv, as of 26 Aug 2026
                    """
            ),
            .heading("Without `query`, it uses the result of the query block IMMEDIATELY ABOVE"),
            .paragraph("""
                This is the format's most important rule. Thanks to it, the common \"a table then a \
                chart of that table\" report does not repeat the SQL — and repeating it means the \
                two copies eventually drift apart, at which point the table and the chart say \
                different things on the same page.
                """),
            .warning("""
                In exchange, **block order matters**: inserting a query block in between changes the \
                data of the chart below it.
                """),
            .heading("Why `source` is its own key"),
            .paragraph("""
                A source note written as prose under the chart displays perfectly well — on screen. \
                But the chart will be exported as a PNG and pasted elsewhere, and the prose stays \
                behind. As a key it is drawn **inside the image** and travels with it.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    // MARK: - quality block

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "The `quality` block",
        summary: "A data-quality scorecard inside the report.",
        keywords: ["quality", "scorecard", "report", "block"],
        blocks: [
            .code(
                language: "yaml",
                caption: "Every key of a quality block",
                source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # empty means the report's own source
                    title: August sales data quality
                    rules: true                 # show the pass/fail rule table
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # pin the reference date for "Timeliness"
                    fail_under: 90              # below this the card turns a warning colour
                    """
            ),
            .table(
                headers: ["`chart`", "Draws"],
                rows: [
                    ["`violations`", "Row counts for the rules that **failed** — answers \"what to fix first\""],
                    ["`dimensions`", "The six dimension scores"],
                    ["`none`", "Table only, no chart"],
                ]
            ),
            .note("""
                Set `now:` in a periodic report. Without it, *Timeliness* compares against render \
                time, so re-rendering last month's report produces a different score from the one \
                you published.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    // MARK: - mining block

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "The `mining` block",
        summary: "Rank groups by anomalies, forecast error or correlation divergence.",
        keywords: ["mining", "report", "group ranking"],
        blocks: [
            .code(
                language: "yaml",
                caption: "Every key of a mining block",
                source: """
                    group_by: tinh
                    value: doanh_thu          # the column for anomalies and forecasting
                    pair: chi_phi             # a second column, for per-group correlation
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # empty means the report's own source
                    title: Mining by province
                    chart: true
                    """
            ),
            .table(
                headers: ["`rank`", "Ranks by"],
                rows: [
                    ["`anomalies`", "The group with the most anomalous rows"],
                    ["`forecast_error`", "The group whose forecast is worst"],
                    ["`correlation_gap`", "The group whose correlation diverges most from the pooled table — catches Simpson's paradox"],
                ]
            ),
            .warning("""
                **No key turns off the \"Method\" block.** A group ranking without its method leaves \
                the reader no way to know what fence \"most anomalies\" was measured against. Anyone \
                who wants it hidden already knows the answer they want.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Batch reports

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Generating reports in bulk",
        summary: "One template, one parameter list, many reports.",
        keywords: ["batch", "bulk", "many reports", "parameters", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                One report template, run for each branch or each month. The parameter list is a CSV \
                or JSON file — **one row per report**.
                """),
            .code(
                language: "text",
                caption: "list.csv — one row per report",
                source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """
            ),
            .code(
                language: "bash",
                caption: "Render the whole batch from the shell",
                source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """
            ),
            .code(
                language: "bash",
                caption: "Or one report with parameters passed by hand",
                source: """
                    geditor --report template.greport.md \\
                            --param thang=8 --param tinh="Hà Nội" \\
                            --out ./reports/
                    """
            ),
            .seeAlso(["khoi-query", "dong-lenh"]),
        ]
    )

    // MARK: - Mermaid

    static let mermaid = HelpTopic(
        id: "mermaid",
        title: "Mermaid diagrams",
        summary: "Draw diagrams in text, edit them with commands, preview both ways in sync.",
        keywords: ["mermaid", "diagram", "flowchart", "sequence", "draw"],
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
                Mermaid draws diagrams **from text**: you write a description, the machine draws it. \
                A diagram can therefore be diffed and committed — something an image file cannot.
                """),
            .paragraph("""
                Open `Mermaid diagram: preview` for a view beside the editor. The two are **in sync \
                both ways**: select an element in the picture and the caret jumps to its line.
                """),
            .heading("Edit with commands, not by retyping"),
            .table(
                headers: ["Command", "What it does"],
                rows: [
                    ["Insert a template…", "Insert a ready skeleton for each diagram type"],
                    ["Add an element…", "Add a node or a participant"],
                    ["Connect the two selected elements", "Draw an arrow between them"],
                    ["Edit the selected element's label…", "Change the text without hunting for the line"],
                    ["Delete the selected element", "Remove the node **and** every edge touching it"],
                    ["Move message up / down", "Reorder steps in a sequence diagram"],
                    ["Reformat", "Indent and align the whole block"],
                ]
            ),
            .heading("Splitting out to a file and embedding it back"),
            .paragraph("""
                Large diagrams belong in their own `.mmd` file: `Split block into a .mmd file…` moves \
                it out and leaves a reference behind. `Embed the referenced file back` does the \
                reverse when you need to send a single file.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    // MARK: - Mermaid syntax

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Common Mermaid syntax",
        summary: "The four most-used diagram types, each with a template that runs.",
        keywords: ["mermaid", "syntax", "flowchart", "sequence", "gantt", "class", "template"],
        blocks: [
            .code(
                language: "mermaid",
                caption: "Flowchart — an order approval process",
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
                caption: "Sequence diagram — a payment flow",
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
                caption: "Class diagram — a data model",
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
                caption: "Gantt — a release plan",
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
                headers: ["Node shape", "Write"],
                rows: [
                    ["Rectangle", "`A[Label]`"],
                    ["Rounded", "`A(Label)`"],
                    ["Stadium", "`A([Label])`"],
                    ["Rhombus (decision)", "`A{Label}`"],
                    ["Cylinder (data)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Arrow", "Write"],
                rows: [
                    ["Solid, with head", "`A --> B`"],
                    ["Dotted", "`A -.-> B`"],
                    ["Thick", "`A ==> B`"],
                    ["Labelled", "`A -- label --> B`"],
                ]
            ),
            .note("""
                A flowchart's direction goes right after `flowchart`: `TD` top-down, `LR` \
                left-to-right, plus `BT` and `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )
}
