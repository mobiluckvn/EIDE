import Foundation

/// 简体中文帮助内容 —— 第十部分：报告与图表。
extension HelpZhHans {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "报告与图表",
        summary: "一个文本文件产出数字会自动重跑的 HTML 报告，外加 Mermaid 图表。",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md` 报告",
        summary: "Markdown 加四种可运行的块 —— 左边写，右边预览。",
        keywords: ["报告", "greport", "html", "导出", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                `.greport.md` 文件就是**普通的 Markdown**，外加几个可运行的围栏块。渲染它会产出 \
                一个**自包含**的 HTML 文件 —— 不联网、没有附带文件 —— 谁都能打开。
                """),
            .paragraph("""
                因为它是纯文本，所以能**做 diff、能提交、能分享** —— 和清洗配方、质量规则集是 \
                同一套理念。
                """),
            .code(
                language: "markdown", caption: "sales-2026-08.greport.md —— 一份完整报告",
                source: """
                    ---
                    title: August sales report
                    source: sales-2026-08.csv
                    ---

                    # 八月销售报告

                    数字截至 2026 年 8 月 31 日。

                    ## 各省营收

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: 各省营收
                    y_label: 营收
                    number_format: vi
                    suffix: " ₫"
                    source: 来源 —— sales-2026-08.csv
                    ```

                    ## 源数据质量

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """
            ),
            .heading("块的类型"),
            .table(
                headers: ["块", "产出"],
                rows: [
                    ["`query`", "一张表，来自一条 DuckDB SQL 语句"],
                    ["`chart`", "一张图"],
                    ["`quality`", "一张数据质量记分卡"],
                    ["`mining`", "一张分组挖掘排名表"],
                    ["`mermaid`", "一张示意图"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                顶部的 `---` 块声明 `title` 和 `source` —— 后者是每个未自行指明数据源的块的 \
                默认数据源。
                """),
            .note("""
                预览会在您停止输入时重建，但它**只做解析**；不会每敲一个键就跑一遍查询。文档 \
                错误和数据错误分开报告 —— *「chart 块缺少 `kind` 键」*是文件错误，*「列 \
                `doanh_thu` 不存在」*是数据错误。
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "`query` 块",
        summary: "一条 DuckDB 语句变成报告里的一张表。",
        keywords: ["查询", "sql", "表", "报告", "块"],
        blocks: [
            .paragraph("""
                块的内容是**一条 SQL 语句**，跑在报告的数据源上。表名为 `t`，方言与查询面板相同。
                """),
            .code(
                language: "text", caption: "带参数的 query 块",
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
                `:thang` 是一个**参数**。它在渲染时提供 —— 在终端里用 `--param thang=8`，或者 \
                批量生成报告时从一个清单文件里取。
                """),
            .note("""
                数据报告里的表**应当来自 query 块**，而不是手打的。手打的表在数字变化时不会重跑， \
                早晚会与报告其余部分对不上。
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "`chart` 块",
        summary: "一段 YAML 配置变成一张图 —— 以及这个格式最重要的一条规则。",
        keywords: ["图表", "yaml", "报告", "绘图"],
        blocks: [
            .code(
                language: "yaml", caption: "chart 块的每一个键",
                source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: 各省营收
                    x_label: 省
                    y_label: 营收
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: 来源 —— sales.csv，截至 2026-08-26
                    """
            ),
            .heading("没有 `query` 时，它用**紧挨上方**那个 query 块的结果"),
            .paragraph("""
                这是这个格式最重要的一条规则。有了它，常见的「一张表，然后是这张表的图」式报告 \
                就不必重复那段 SQL —— 而重复意味着两份副本终会走岔，到那时同一页上的表和图会 \
                说两种话。
                """),
            .warning("""
                代价是**块的顺序有意义**：在中间插入一个 query 块，会改变它下方那张图的数据。
                """),
            .heading("为什么 `source` 是一个独立的键"),
            .paragraph("""
                把来源写成图下方的一段散文，显示起来完全没问题 —— 在屏幕上。但这张图会被导出 \
                为 PNG 粘到别处，而那段散文留在了原地。作为一个键，它被画**在图片内部**，跟着 \
                图片一起走。
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "`quality` 块",
        summary: "报告内部的一张数据质量记分卡。",
        keywords: ["质量", "记分卡", "报告", "块"],
        blocks: [
            .code(
                language: "yaml", caption: "quality 块的每一个键",
                source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # 留空表示用报告自己的数据源
                    title: 八月销售数据质量
                    rules: true                 # 显示逐条规则的通过/不通过表
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # 为「时效性」固定参照日期
                    fail_under: 90              # 低于此分，卡片转为警告色
                    """
            ),
            .table(
                headers: ["`chart`", "画出"],
                rows: [
                    ["`violations`", "**未通过**的规则各自的行数 —— 回答「先修哪个」"],
                    ["`dimensions`", "六个维度的得分"],
                    ["`none`", "只有表，不画图"],
                ]
            ),
            .note("""
                周期性报告要设 `now:`。不设的话，*时效性*会拿渲染时刻来比，于是重新渲染上个月的 \
                报告会得出与您当初发布的不同的分数。
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "`mining` 块",
        summary: "按异常数、预测误差或相关背离给各组排名。",
        keywords: ["挖掘", "报告", "分组排名"],
        blocks: [
            .code(
                language: "yaml", caption: "mining 块的每一个键",
                source: """
                    group_by: tinh
                    value: doanh_thu          # 用于异常和预测的列
                    pair: chi_phi             # 第二列，用于逐组相关
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # 留空表示用报告自己的数据源
                    title: 按省挖掘
                    chart: true
                    """
            ),
            .table(
                headers: ["`rank`", "按什么排名"],
                rows: [
                    ["`anomalies`", "异常行最多的组"],
                    ["`forecast_error`", "预测最差的组"],
                    ["`correlation_gap`", "相关与合并表背离最大的组 —— 抓辛普森悖论"],
                ]
            ),
            .warning("""
                **没有任何键能关掉「方法」块。** 一份没有方法的分组排名，会让读者无从知道「异常 \
                最多」是拿什么围栏量出来的。想把它藏起来的人，其实早就知道自己想要什么答案了。
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "批量生成报告",
        summary: "一份模板、一份参数清单、许多份报告。",
        keywords: ["批量", "多份报告", "参数", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                一份报告模板，为每个分店或每个月各跑一遍。参数清单是一个 CSV 或 JSON 文件 —— \
                **一行一份报告**。
                """),
            .code(
                language: "text", caption: "list.csv —— 一行一份报告",
                source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """
            ),
            .code(
                language: "bash", caption: "在终端里渲染整批",
                source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """
            ),
            .code(
                language: "bash", caption: "或者手工传参数，只出一份",
                source: """
                    geditor --report template.greport.md \\
                            --param thang=8 --param tinh="Hà Nội" \\
                            --out ./reports/
                    """
            ),
            .seeAlso(["khoi-query", "dong-lenh"]),
        ]
    )

    static let mermaid = HelpTopic(
        id: "mermaid",
        title: "Mermaid 图表",
        summary: "用文本画图，用命令编辑，两边双向同步预览。",
        keywords: ["mermaid", "图表", "流程图", "时序图", "画图"],
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
                Mermaid **从文本**画图：您写一段描述，机器把它画出来。因此一张图能做 diff、能 \
                提交 —— 这是图片文件做不到的。
                """),
            .paragraph("""
                打开 `Mermaid 图表：预览`，在编辑器旁边得到一个视图。两者**双向同步**：在图上 \
                选中一个元素，光标就跳到它那一行。
                """),
            .heading("用命令编辑，而不是重打一遍"),
            .table(
                headers: ["命令", "作用"],
                rows: [
                    ["插入模板…", "为每种图类型插入一副现成骨架"],
                    ["添加元素…", "添加一个节点或一个参与者"],
                    ["连接选中的两个元素", "在它们之间画一支箭头"],
                    ["编辑选中元素的标签…", "改文字，不必去找那一行"],
                    ["删除选中的元素", "移除该节点**以及**与它相连的每一条边"],
                    ["上移／下移消息", "在时序图里调整步骤顺序"],
                    ["重新格式化", "把整块缩进对齐"],
                ]
            ),
            .heading("拆成文件，再嵌回来"),
            .paragraph("""
                大图应当放进它自己的 `.mmd` 文件：`把块拆成 .mmd 文件…`会把它移出去，原地留下 \
                一个引用。当您需要发一个单独文件时，`把引用的文件嵌回来`做相反的事。
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "常用的 Mermaid 语法",
        summary: "四种最常用的图，每种都配一副能跑的模板。",
        keywords: ["mermaid", "语法", "流程图", "时序图", "甘特图", "类图", "模板"],
        blocks: [
            .code(
                language: "mermaid", caption: "流程图 —— 订单审批流程",
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
                language: "mermaid", caption: "时序图 —— 支付流程",
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
                language: "mermaid", caption: "类图 —— 一个数据模型",
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
                language: "mermaid", caption: "甘特图 —— 发布计划",
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
                headers: ["节点形状", "写法"],
                rows: [
                    ["矩形", "`A[Label]`"],
                    ["圆角", "`A(Label)`"],
                    ["体育场形", "`A([Label])`"],
                    ["菱形（判断）", "`A{Label}`"],
                    ["圆柱形（数据）", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["箭头", "写法"],
                rows: [
                    ["实线带箭头", "`A --> B`"],
                    ["虚线", "`A -.-> B`"],
                    ["粗线", "`A ==> B`"],
                    ["带标签", "`A -- label --> B`"],
                ]
            ),
            .note("""
                流程图的方向紧跟在 `flowchart` 之后：`TD` 从上到下，`LR` 从左到右，另有 `BT` \
                和 `RL`。
                """),
            .seeAlso(["mermaid"]),
        ]
    )
}
