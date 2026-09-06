import Foundation

extension HelpEN {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Tabular data",
        summary: "View CSV as a grid, filter, sort, check structure, query with SQL, convert.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    // MARK: - CSV grid

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Viewing CSV as a grid",
        summary: "A million rows still scroll smoothly, headers stay put, and the source text is untouched.",
        keywords: ["csv", "grid", "table", "tsv", "excel", "columns"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Switch between Grid and Text")]),
            .paragraph("""
                The grid is **virtualised**: only visible rows are built, so a million-row file \
                scrolls like a hundred-row one.
                """),
            .bullets([
                "**The header row sticks** while scrolling — at row 40,000 you still know what the ninth column is.",
                "Edit a cell in the grid; the change goes straight into the source text.",
                "Grid and Text are **two views of one file**, not two copies.",
                "**⌘C copies the selected row**, cells separated by TAB — paste straight into Excel or Numbers and each cell lands correctly. Cells containing TABs or newlines are quoted, so the destination does not split them in two.",
            ]),
            .note("""
                The delimiter is detected on open (comma, semicolon, TAB, pipe). If the guess is \
                wrong, change it with `CSV ▸ Change delimiter…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    // MARK: - Filter and sort

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtering and sorting in the grid",
        summary: "A filter box per column, understanding numeric comparison and unaccented typing.",
        keywords: ["filter", "sort", "column", "search in grid"],
        blocks: [
            .paragraph("Click a column header to sort. The filter box below it accepts:"),
            .table(
                headers: ["Type in the filter", "Meaning"],
                rows: [
                    ["`hue`", "Contains `hue`, **accent-insensitive** — also finds `Huế`"],
                    ["`=Huế`", "Exactly `Huế` (still accent-insensitive)"],
                    ["`>100`", "Greater than 100"],
                    ["`>=100`", "100 or more"],
                    ["`<0`", "Less than 0"],
                    ["`100..200`", "Between 100 and 200"],
                    ["empty", "No filter on this column"],
                ]
            ),
            .paragraph("""
                Filtering several columns is an **and**: a row must satisfy all of them. Numeric \
                comparison skips non-numeric cells rather than treating them as zero.
                """),
            .note("""
                Filtering is a **way of looking**, not a deletion. Clear the filter and every row \
                returns.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    // MARK: - Structure check

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Checking table structure",
        summary: "Find rows with the wrong column count and cells of the wrong type — do this first.",
        keywords: ["validate", "check", "column count", "wrong type", "broken data"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                This is what to run **before** anything else on a file someone sent you. It answers \
                two questions:
                """),
            .bullets([
                "**Which rows have the wrong column count?** Usually a cell containing a comma that was not quoted — and it throws off every row after it.",
                "**Which cells have a type unlike the rest of their column?** For instance `n/a` sitting in a column of numbers.",
            ]),
            .paragraph("""
                Results appear as a list; click one to jump to that row.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    // MARK: - Delete columns

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Deleting columns",
        summary: "Remove one or more columns from the file entirely.",
        keywords: ["delete column", "drop column", "remove column"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Pick the columns to drop from the list and apply. It is **one** undo step no matter \
                how many rows the file has.
                """),
            .warning("""
                Unlike filtering, this **edits the real file**. To merely hide columns, use a SQL \
                query listing the columns you want.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    // MARK: - SQL

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Querying CSV with SQL",
        summary: "DuckDB's full SQL, run directly against the open file — read-only.",
        keywords: ["sql", "query", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                The open table is called **`t`**. The engine is **DuckDB**, so `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, window functions and subqueries all work.
                """),
            .code(
                language: "sql",
                caption: "Revenue by province, largest first",
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
                caption: "Filtering by date and by a text condition",
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
                caption: "Each province's share of the total — with a window function",
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
                caption: "Joining against another file on disk",
                source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """
            ),
            .heading("Read-only, and that is a hard guarantee"),
            .bullets([
                "The database lives **in memory**; the source file is only ever read.",
                "Exactly **one statement** is accepted, and it **must be a `SELECT`**. Everything else — including `COPY … TO 'file'`, which DuckDB can absolutely use to write to disk — is blocked before it reaches any data.",
            ]),
            .warning("""
                DuckDB reads **files**, not memory. If the document has unsaved edits, GEditor must \
                write a temporary copy before querying. For a very large file with unsaved edits it \
                **stops and says so** rather than quietly writing hundreds of megabytes to disk for \
                one query.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Pivot and charts

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Pivot tables and quick charts",
        summary: "Pivot and plot straight from a query result.",
        keywords: ["pivot", "chart", "graph", "crosstab", "aggregate"],
        blocks: [
            .paragraph("""
                Both open from the **query result table**: run a SQL statement, then use the Pivot \
                or Chart button on the panel.
                """),
            .heading("Pivot"),
            .paragraph("""
                Choose the **row** column, the **column** column, the **value** column and the \
                aggregate (sum, count, average, min, max) — like a spreadsheet's pivot table.
                """),
            .heading("Charts"),
            .paragraph("""
                Bar, line, pie, scatter. Numbers formatted Vietnamese- or European-style, and the \
                chart exports as PNG or SVG to paste elsewhere.
                """),
            .note("""
                Want a chart that **refreshes with the data** on every rebuild? That is the `chart` \
                block in a `.greport.md` report.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    // MARK: - Conversion

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Converting a table to another format",
        summary: "TSV, JSON, XML, Markdown tables, SQL INSERT statements — with a preview.",
        keywords: ["convert", "export", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Format", "Useful for"],
                rows: [
                    ["TSV", "Pasting into a spreadsheet without worrying about commas in cells"],
                    ["JSON", "Feeding an API, a script, or another tool"],
                    ["XML", "Legacy systems that demand XML"],
                    ["Markdown table", "Pasting into documentation, a README, a ticket"],
                    ["SQL INSERT statements", "Loading into a database"],
                ]
            ),
            .paragraph("""
                The dialog **previews the first five rows** before creating the new tab — five lines \
                is enough to confirm the table name, the quoting and which columns became numbers.
                """),
            .note("""
                The preview calls **the same function** that produces the real output, limited to \
                five rows. It is not a simulation that could disagree with the final result.
                """),
        ]
    )

    // MARK: - Delimiter

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Changing the delimiter",
        summary: "Convert a file between comma, semicolon, TAB and pipe.",
        keywords: ["delimiter", "comma", "semicolon", "tab", "european csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Files exported from a Vietnamese or European Excel usually use **semicolons**, \
                because there the comma is the decimal separator.
                """),
            .warning("""
                Changing the delimiter **rewrites the whole file**. Cells containing the new \
                delimiter get quoted — otherwise the table's structure breaks.
                """),
            .note("""
                **If the detection was wrong, this is not the command you want.** There are two \
                different jobs here, exactly like the encoding pair «reinterpret» / «convert»:

                • *The file really is semicolon-separated and we guessed comma* — click the \
                `CSV · …` segment on the **status bar** and pick the right one. Not a byte of the \
                file changes; only how it is read.

                • *The file really is comma-separated, and you want semicolons* — use the command \
                on this page. It rewrites the file.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Excel sheets

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Multi-sheet spreadsheets",
        summary: "Open any sheet of an .xlsx, and ⌘S writes back into the sheet you are viewing.",
        keywords: ["excel", "xlsx", "sheet", "workbook", "multiple sheets"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Open an `.xlsx` and GEditor shows the **first sheet** as a CSV grid. `CSV ▸ Choose \
                sheet…` lists every sheet in the file and opens the one you pick in the same tab.
                """),
            .heading("Writing back into the RIGHT sheet"),
            .paragraph("""
                `⌘S` writes your edits into **the sheet you are viewing**, not the first one. The \
                other sheets are not touched by a single byte.
                """),
            .note("""
                The sheet is remembered by **name**, not by position. That way reordering sheets in \
                Excel between two sessions does not misdirect the write.
                """),
            .warning("""
                If the open sheet has been **renamed or deleted** in Excel since you opened it, \
                `⌘S` **refuses to write** and says so. Falling back to the first sheet would mean \
                pouring one sheet's contents over another — the file would still save, still \
                reopen, and simply hold the data in the wrong place.
                """),
            .heading("Switching sheets with unsaved edits"),
            .paragraph("""
                Switching sheets replaces the whole tab's contents, so if anything is unsaved \
                GEditor **asks first**. `⌘Z` cannot bring it back, because the entire document was \
                swapped.
                """),
            .heading("What it costs to bring Excel down to a grid"),
            .paragraph("""
                What survives is **values** — including formula results, exactly the numbers Excel \
                is showing. What does not: fonts, colours, merged cells, embedded charts, and the \
                formulas themselves.
                """),
            .paragraph("""
                In exchange, that sheet gains the entire rest of the product: filtering, sorting, \
                SQL queries, the cleaning bench, quality scoring, mining, charts.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )
}
