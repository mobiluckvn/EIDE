import Foundation

/// 简体中文帮助内容 —— 第六部分：表格数据。
extension HelpZhHans {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "表格数据",
        summary: "把 CSV 当表格看、筛选、排序、检查结构、用 SQL 查询、转换格式。",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "把 CSV 当表格看",
        summary: "一百万行照样顺滑，表头固定不动，源文本分毫未改。",
        keywords: ["csv", "表格", "网格", "tsv", "excel", "列"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "在表格与文本之间切换")]),
            .paragraph("""
                表格是**虚拟化**的：只构建看得见的行，所以一百万行的文件滚起来和一百行的一样。
                """),
            .bullets([
                "**表头行固定不动** —— 滚到第 40 000 行时您依然知道第九列是什么。",
                "在表格里改一个单元格，改动直接写进源文本。",
                "表格和文本是**同一个文件的两种看法**，不是两份副本。",
                "**⌘C 复制选中的行**，单元格之间用 TAB 分隔 —— 直接粘进 Excel 或 Numbers，每个单元格都落在正确的位置。含 TAB 或换行的单元格会加引号，免得目的地把它拆成两个。",
            ]),
            .note("""
                分隔符在打开时自动识别（逗号、分号、TAB、竖线）。识别错了就用 `CSV ▸ 更改分隔符…`。
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "多工作表的电子表格",
        summary: "打开 .xlsx 的任意工作表，⌘S 写回您正在看的那一张。",
        keywords: ["excel", "xlsx", "工作表", "工作簿", "多表"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                打开 `.xlsx`，GEditor 把**第一张工作表**显示为 CSV 表格。`CSV ▸ 选择工作表…` \
                列出文件中的每一张表，并在同一个标签页里打开您选的那张。
                """),
            .heading("写回**正确**的那张表"),
            .paragraph("""
                `⌘S` 把您的改动写进**您正在看的那张表**，而不是第一张。其余各表一个字节都不动。
                """),
            .note("""
                工作表是按**名字**记住的，不是按位置。这样即使您在两次会话之间于 Excel 里调整了 \
                工作表顺序，写入也不会写错地方。
                """),
            .warning("""
                如果打开之后有人在 Excel 里**重命名或删除**了这张表，`⌘S` 会**拒绝写入**并说明 \
                原因。退回去写第一张表，等于把一张表的内容浇到另一张上 —— 文件照样保存、照样能 \
                重新打开，只是数据在错的地方。
                """),
            .heading("有未保存改动时切换工作表"),
            .paragraph("""
                切换工作表会替换整个标签页的内容，所以只要有未保存的东西，GEditor **会先问**。 \
                `⌘Z` 救不回来，因为整份文档都被换掉了。
                """),
            .heading("把 Excel 降成表格要付什么代价"),
            .paragraph("""
                留下来的是**值** —— 包括公式的结果，正是 Excel 显示的那些数字。留不下来的是： \
                字体、颜色、合并单元格、内嵌图表，以及公式本身。
                """),
            .paragraph("""
                换来的是：这张表获得了产品其余的全部能力 —— 筛选、排序、SQL 查询、清洗台、 \
                质量评分、数据挖掘、图表。
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "在表格里筛选和排序",
        summary: "每列一个筛选框，懂数值比较，也懂不打声调的输入。",
        keywords: ["筛选", "排序", "列", "表格搜索"],
        blocks: [
            .paragraph("点列头即排序。下面的筛选框接受："),
            .table(
                headers: ["在筛选框里输入", "含义"],
                rows: [
                    ["`hue`", "包含 `hue`，**忽略声调** —— 也能找到 `Huế`"],
                    ["`=Huế`", "正好是 `Huế`（同样忽略声调）"],
                    ["`>100`", "大于 100"],
                    ["`>=100`", "100 或更大"],
                    ["`<0`", "小于 0"],
                    ["`100..200`", "在 100 到 200 之间"],
                    ["留空", "这一列不筛选"],
                ]
            ),
            .paragraph("""
                多列同时筛选是**并且**的关系：一行必须满足全部条件。数值比较会跳过非数值单元格， \
                而不是把它们当成零。
                """),
            .note("""
                筛选是一种**看法**，不是删除。清空筛选，所有行都回来。
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "检查表格结构",
        summary: "找出列数不对的行和类型不对的单元格 —— 这件事要最先做。",
        keywords: ["校验", "检查", "列数", "类型不符", "坏数据"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                别人发来一个文件，这是您该在**其他一切之前**运行的东西。它回答两个问题：
                """),
            .bullets([
                "**哪些行列数不对？** 通常是某个单元格里有逗号却没加引号 —— 而它会把后面每一行都带偏。",
                "**哪些单元格的类型与本列其余不同？** 例如一列数字里夹着 `n/a`。",
            ]),
            .paragraph("结果显示为列表，点一条即跳到那一行。"),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "删除列",
        summary: "把一列或多列从文件中彻底移除。",
        keywords: ["删除列", "去掉列", "drop column"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                从列表里选出要删的列并应用。无论文件有多少行，这都是**一步**撤销。
                """),
            .warning("""
                与筛选不同，这会**改动真实文件**。只想把列藏起来的话，请用一条列出您要的列的 \
                SQL 查询。
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "用 SQL 查询 CSV",
        summary: "DuckDB 的完整 SQL，直接跑在打开的文件上 —— 只读。",
        keywords: ["sql", "查询", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                打开的表名为 **`t`**。引擎是 **DuckDB**，所以 `JOIN`、`DISTINCT`、`HAVING`、 \
                `IN`、`LIKE`、`BETWEEN`、窗口函数和子查询全都能用。
                """),
            .code(
                language: "sql", caption: "各省营收，从大到小",
                source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """
            ),
            .code(
                language: "sql", caption: "按日期和文本条件筛选",
                source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """
            ),
            .code(
                language: "sql", caption: "各省占总额的比例 —— 用窗口函数",
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
                language: "sql", caption: "与磁盘上的另一个文件做连接",
                source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """
            ),
            .heading("只读，而且这是一条硬保证"),
            .bullets([
                "数据库在**内存**里；源文件只会被读取。",
                "只接受**一条**语句，而且**必须是 `SELECT`**。其余一律拦下 —— 包括 `COPY … TO 'file'`，DuckDB 完全可以用它写到磁盘上 —— 在它碰到任何数据之前就被拦住。",
            ]),
            .warning("""
                DuckDB 读的是**文件**，不是内存。如果文档有未保存的改动，GEditor 必须先写一份 \
                临时副本才能查询。对于一个很大又有未保存改动的文件，它会**停下来说明**，而不是 \
                为了一次查询悄悄往磁盘写几百 MB。
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "透视表与快速图表",
        summary: "直接从查询结果做透视和绘图。",
        keywords: ["透视表", "图表", "交叉表", "聚合"],
        blocks: [
            .paragraph("""
                两者都从**查询结果表**打开：先跑一条 SQL 语句，再用面板上的透视或图表按钮。
                """),
            .heading("透视"),
            .paragraph("""
                选**行**列、**列**列、**值**列和聚合方式（求和、计数、平均、最小、最大）—— \
                和电子表格的数据透视表一样。
                """),
            .heading("图表"),
            .paragraph("""
                柱状、折线、饼图、散点。数字可按越南／欧洲式格式化，图表可导出为 PNG 或 SVG \
                以便粘到别处。
                """),
            .note("""
                想要一张**每次重建都随数据刷新**的图？那是 `.greport.md` 报告里的 `chart` 块。
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "把表格转成别的格式",
        summary: "TSV、JSON、XML、Markdown 表格、SQL INSERT 语句 —— 都带预览。",
        keywords: ["转换", "导出", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["格式", "适合"],
                rows: [
                    ["TSV", "粘进电子表格，不必担心单元格里的逗号"],
                    ["JSON", "喂给 API、脚本或别的工具"],
                    ["XML", "只认 XML 的老系统"],
                    ["Markdown 表格", "粘进文档、README、工单"],
                    ["SQL INSERT 语句", "导入数据库"],
                ]
            ),
            .paragraph("""
                对话框在建立新标签页之前**先预览前五行** —— 五行足以确认表名、引号处理，以及 \
                哪些列变成了数字。
                """),
            .note("""
                预览调用的是**同一个函数**，只是限制在五行。它不是一份可能与最终结果不符的模拟。
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "更改分隔符",
        summary: "在逗号、分号、TAB 和竖线之间转换文件。",
        keywords: ["分隔符", "逗号", "分号", "tab", "欧洲式 csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                从越南或欧洲版 Excel 导出的文件通常用**分号**，因为那里的逗号是小数点。
                """),
            .warning("""
                更改分隔符会**重写整个文件**。含有新分隔符的单元格会被加上引号 —— 否则表格结构 \
                就散了。
                """),
            .note("""
                **如果只是识别错了，您要的不是这条命令。** 这里其实是两件不同的事，正如编码那一 \
                对「重新解释」／「转换」：

                • *文件本来就是分号分隔，而我们猜成了逗号* —— 点**状态栏**上的 `CSV · …` 那一段， \
                选对的那个。文件一个字节都不变，变的只是读法。

                • *文件本来是逗号分隔，而您想要分号* —— 用本页这条命令。它会重写文件。
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )
}
