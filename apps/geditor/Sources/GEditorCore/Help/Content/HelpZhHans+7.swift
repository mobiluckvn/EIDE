import Foundation

/// 简体中文帮助内容 —— 第七部分：数据清洗全流程。
extension HelpZhHans {

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "数据清洗 —— 完整流程",
        summary: "从别人发来的原始文件到一张能用的表，以及一套每月都能重跑的标准。",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "清洗流程，从头到尾",
        summary: "从一个陌生文件到一张可信的表，六步；外加一套供下个月使用的标准。",
        keywords: ["清洗", "流程", "规范化", "整洁数据"],
        blocks: [
            .paragraph("""
                清洗数据**很少是一次性的**。人们每个月收到同一套报表模板，每个月都要把同样的列 \
                用同样的方式规范一遍。这套流程正是为此设计的：手工做一次，之后一条命令重跑。
                """),
            .heading("六步"),
            .steps([
                "**先看结构。** `CSV ▸ 检查数据` —— 哪些行列数不对，哪些单元格类型不对。这一步必须最先，因为一行错位会让后面所有统计失去意义。",
                "**读数据画像。** 逐列看：多少空单元格、多少个不同值、是什么类型、离群值在哪。在动手改任何东西之前，先在这里读懂这份文件。",
                "**打开清洗台**（`⇧⌘L`）。它会认出混杂的日期格式、越南式与欧洲式混用的数字、多余空白、缺失值。**先预览「改前→改后」**，再应用。",
                "**处理模糊重复** —— 如果姓名或地址列里有手工录入的各种写法。这里由您决定，机器只负责提议。",
                "**存成配方。** 刚才那串操作会写进一个具名的 JSON 文件 —— 那份文件就是您关于这批数据的知识。",
                "**写一套质量规则** `.gquality.yaml` 并评分。从此下个月的文件跑过配方并被评分，而 **CLI 关卡**在不合格时返回非零退出码。",
            ]),
            .heading("为什么是这个顺序"),
            .bullets([
                "结构**先于**画像：在错位的表上做统计，统计的是另一列。",
                "画像**先于**清洗：要先知道「2% 为空」，才能决定是填还是删。",
                "模糊重复**在**规范化**之后**：`CÔNG TY  A` 和 `Công ty A` 只有在空白和大小写都理顺之后，才会显出是同一个。",
                "配方**先于**规则集：配方负责修，规则负责判 —— 给一张没修过的表评分，只会得到一个您早就料到的低分。",
            ]),
            .heading("第一次之后，每个月只是一条命令"),
            .code(
                language: "bash", caption: "先清洗再评分，并为 CI 返回退出码",
                source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """
            ),
            .paragraph("""
                退出码 **0** 表示通过，**1** 表示不通过，**2** 表示运行时错误。 \
                `--record-history` 会往历史文件追加一行，好让下一次能比较漂移。
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "数据画像",
        summary: "每列一份描述：类型、空值、不同值个数、分布。",
        keywords: ["画像", "列统计", "空值", "去重计数"],
        blocks: [
            .paragraph("""
                画像只**描述**，不评判。它说*「这一列 2% 为空」*；2% 是否可以接受，那是质量 \
                规则集的事。
                """),
            .table(
                headers: ["指标", "怎么读"],
                rows: [
                    ["类型", "从数据本身推断，而不是看列名"],
                    ["空单元格", "缺失值的个数与比例"],
                    ["不同值个数", "为 1 表示常量列；等于行数表示是键列"],
                    ["最小 · 最大 · 平均", "仅数值列"],
                    ["最频繁的值", "一眼看出某个错误码或被滥用的默认值"],
                ]
            ),
            .warning("""
                不同值计数有一个阈值。超过之后显示的数字是**下界**，而画像会**说明这是估计值**， \
                不会把它混进精确计数里。
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "数据清洗台",
        summary: "七种规范化，永远先预览，永远只是一步撤销，永不猜测。",
        keywords: ["清洗", "规范化", "日期", "数字", "去空白", "填充缺失"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "打开清洗台")]),
            .table(
                headers: ["操作", "作用"],
                rows: [
                    ["规范化日期", "把本列里各种日期写法统一成一种"],
                    ["规范化数字", "理顺小数点和千位分隔符"],
                    ["去除空白", "去掉两端的空白；也可以顺带压缩中间的连续空白"],
                    ["更改大小写", "让本列的大小写一致"],
                    ["用固定值填充", "把空单元格换成您输入的值"],
                    ["从相邻行填充", "取上一行或下一行的值"],
                    ["删除有空单元格的行", "丢掉缺数据的行"],
                ]
            ),
            .heading("整个清洗台给出的三条保证"),
            .bullets([
                "**永远先预览。** 一张「改前→改后」的表，并写明将要改动多少个单元格。",
                "整趟操作是**一步撤销**，哪怕它动了一百万个单元格。",
                "**事后有报告**：改了多少个单元格，哪些读不出来。",
            ]),
            .heading("原则：绝不猜测"),
            .paragraph("""
                读不准的单元格会被**标出来并保持原样**。比如两种约定混用的列里出现 `03/04/2026` \
                —— 是 4 月 3 日还是 3 月 4 日？GEditor 会问您日／月的顺序，而不是替您决定。
                """),
            .warning("""
                把日期列规范错了，是那种**几乎无法察觉**的损坏：数字看上去仍然是对的，只不过是 \
                另一个日期。这就是这张台子宁可拒绝也不推断的原因。
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "模糊重复",
        summary: "找出同一个名字的各种手写变体 —— 并且绝不自动合并。",
        keywords: ["模糊", "重复", "去重", "合并", "变体", "错别字"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`、`Cty TNHH An Bình`、`CÔNG TY  TNHH AN BÌNH` —— 同一个 \
                客户的三种写法。普通去重看不出它们是同一个。
                """),
            .steps([
                "选择要检查的列和一个相似度阈值。",
                "GEditor 把相近的值归成**簇**，并显示用于比较的形式。",
                "**对每一个簇**，由您选择保留哪个值 —— 或者跳过这个簇。",
                "应用。一步撤销。",
            ]),
            .warning("""
                这个工具**绝不自行合并**，也没有「全部合并」按钮。两个 92% 相似的字符串，可能是 \
                打错了字，也可能是两家真正不同、只差一个词的公司 —— 机器分辨不出。
                """),
            .paragraph("""
                错误地合并两条记录是**无声的**数据丢失：没有单元格变空，没有行变红，只是两个 \
                实体变成了一个，而在对账之前没人会发现。
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "清洗配方",
        summary: "把操作序列记成一个 JSON 文件，下个月的数据直接重跑。",
        keywords: ["配方", "重复", "自动化", "每月", "批处理"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                清洗完成后，把这些步骤存成**配方**。它是一个人能读懂的 JSON 文件，可以放在数据 \
                旁边、发给同事、提交进代码库，这样改动就有迹可循。
                """),
            .code(
                language: "json", caption: "sales-standard.json —— 节选",
                source: """
                    {
                      "version": 1,
                      "name": "Sales report standardisation",
                      "sourceFile": "sales-2026-08.csv",
                      "steps": [
                        { "enabled": true, "column": "ngay",       "action": "normalizeDates" },
                        { "enabled": true, "column": "doanh_thu",  "action": "normalizeNumbers" },
                        { "enabled": true, "column": "khach_hang", "action": "trim" }
                      ]
                    }
                    """
            ),
            .paragraph("""
                每一步都可以**关掉**（`enabled`），因此一份配方能服务好几种几乎相同的文件。
                """),
            .heading("重跑"),
            .bullets([
                "在应用里：`CSV ▸ 运行清洗配方…`",
                "在终端里对整个文件夹跑：见命令行那一页。",
            ]),
            .code(
                language: "bash", caption: "先空跑一遍，什么都不写 —— 不碰任何文件",
                source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"
            ),
            .note("""
                默认结果写到原文件旁边的新文件里（`sales-clean.csv`）。要覆盖原文件必须用 \
                `--overwrite` 明确提出。
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "数据质量评分",
        summary: "六个维度、一个 0–100 的分数，每个公式都印出来，您可以自己复算。",
        keywords: ["质量", "评分", "dqr", "六个维度"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                它与数据画像有一个根本区别：画像**描述**，而评分**对照您在 `.gquality.yaml` \
                文件里声明的标准来评判**。
                """),
            .table(
                headers: ["维度", "衡量什么"],
                rows: [
                    ["完整性", "按 `not_null` 规则计算的填充比例"],
                    ["有效性", "格式、类型、范围和正则规则的通过比例"],
                    ["唯一性", "对照您在 `uniqueness_key` 里声明的键"],
                    ["一致性", "跨列与跨文件的规则"],
                    ["准确性（估计）", "您指定的那些数值列里的离群值"],
                    ["时效性", "数据相对 `freshness` 阈值有多旧"],
                ]
            ),
            .heading("关于这个分数的三条保证"),
            .bullets([
                "**公式印在结果里** —— 您可以手工复算。",
                "**确定性**：同样的数据加同样的规则，得同样的分。只有*时效性*取决于时刻，所以 `now` 是一个**参数**，并且记录在结果里。",
                "**评不了的维度会留空并给出原因**，绝不悄悄给 100 分。",
            ]),
            .warning("""
                最后一条很要紧。一张没有声明 `uniqueness_key` 的表，「唯一性」却拿了 100 分， \
                这个分数在撒谎 —— 而且是往好听的方向撒，那正是危险的方向。
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "`.gquality.yaml` 语法",
        summary: "规则文件的每一个键，外加一套能真正跑起来的完整规则集。",
        keywords: ["gquality", "yaml", "规则", "语法", "数据标准"],
        blocks: [
            .paragraph("""
                这个文件放在**数据旁边**，而不是应用内部：数据标准必须能被评审，而评审正是人们 \
                对标准要做的事。
                """),
            .code(
                language: "yaml", caption: "sales-standard.yaml —— 一套完整规则集",
                source: """
                    schemaVersion: 1

                    # 六个维度的权重。没写的维度权重为 1。
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # 让一行唯一的键。没有它，「唯一性」维度就
                    # 无法评分 —— 总分那里会写明它缺失。
                    uniqueness_key: [ma_don]

                    # 在「准确性（估计）」里检查离群值的数值列。
                    accuracy_columns: [doanh_thu, so_luong]

                    # 「时效性」维度。
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # 本次比上一次下降过多时发出警告。
                    drift:
                      max_total_drop: 3
                      max_dimension_drop: 5
                      max_row_change_pct: 20
                      max_null_increase_pct: 1
                      warn_on_new_failure: true

                    rules:
                      - col: ma_don
                        not_null: true
                      - col: ma_don
                        unique: true
                      - col: doanh_thu
                        dtype: float
                      - col: doanh_thu
                        range: { min: 0 }
                      - col: so_luong
                        dtype: int
                        severity: warn
                      - col: ngay
                        date_format: "yyyy-MM-dd"
                      - col: email
                        regex: "^[^@ ]+@[^@ ]+\\\\.[a-z]{2,}$"
                      - col: trang_thai
                        in_set: [moi, dang_giao, hoan_tat, huy]
                      - col: ghi_chu
                        length: { max: 500 }
                      - col: ma_tinh
                        not_null: true
                        max_null_pct: 2          # 允许 2% 为空
                      # 跨列规则：不需要 `col`
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # 跨文件规则：值必须存在于另一个文件中
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """
            ),
            .heading("规则类型"),
            .table(
                headers: ["键", "含义", "维度"],
                rows: [
                    ["`not_null: true`", "单元格必须有值；`max_null_pct` 可放宽", "完整性"],
                    ["`unique: true`", "列内没有重复值", "唯一性"],
                    ["`dtype: int\\|float\\|date\\|text`", "类型正确", "有效性"],
                    ["`range: { min:, max: }`", "落在数值范围内", "有效性"],
                    ["`length: { min:, max: }`", "字符串长度", "有效性"],
                    ["`regex: \"…\"`", "匹配一个正则表达式", "有效性"],
                    ["`in_set: [ … ]`", "属于给定列表之一", "有效性"],
                    ["`date_format: \"…\"`", "日期形状正确", "有效性"],
                    ["`compare: { a:, op:, b: }`", "比较两列；`op` 是 `<` `<=` `=` `>=` `>` `<>`", "一致性"],
                    ["`foreign_key: { file:, column: }`", "值必须存在于另一个文件中", "一致性"],
                    ["`severity: error\\|warn`", "规则的严重级别；默认 `error`", "—"],
                ]
            ),
            .warning("""
                规则的键写错了，文件会**被拒绝并给出提示**，而不是把那条规则悄悄跳过。悄悄跳过 \
                意味着您以为数据经过了一条从未运行的规则的检验。
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "CI 里的质量关卡",
        summary: "用退出码把不合格的数据拦在流水线上。",
        keywords: ["ci", "关卡", "fail-under", "退出码", "自动化", "历史", "漂移"],
        blocks: [
            .code(
                language: "bash", caption: "评分并返回退出码",
                source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """
            ),
            .table(
                headers: ["选项", "含义"],
                rows: [
                    ["`--quality <file.yaml>`", "用来评分的规则集"],
                    ["`--fail-under <0…100>`", "低于此分即为 FAIL"],
                    ["`--json <file\\|->`", "机器可读的结果；`-` 表示打到标准输出"],
                    ["`--record-history`", "往 `sales-standard.history.jsonl` 追加一行"],
                    ["`--now <YYYY-MM-DD>`", "为*时效性*固定参照日期"],
                    ["`--recipe <file.json>`", "评分前**在内存里**清洗，不写任何文件"],
                ]
            ),
            .table(
                headers: ["退出码", "含义"],
                rows: [["`0`", "通过"], ["`1`", "不通过"], ["`2`", "运行时错误"]]
            ),
            .heading("为什么 CI 应该传 `--now`"),
            .paragraph("""
                不传的话，*时效性*会拿数据和运行的那一刻比 —— 于是同一个文件随着日子推移不断 \
                失分，某天早上流水线突然变红，而谁都没改过任何东西。
                """),
            .heading("漂移跟踪"),
            .paragraph("""
                加上 `--record-history`，每次运行都会往一个 JSONL 历史文件追加一行。下一次， \
                `drift:` 块里的阈值会与最近一次比较，下降过大时发出警告。
                """),
            .note("""
                除 `warn_on_new_failure` 外，每个漂移阈值**默认都是关的**。一个开箱即开、数字 \
                还是应用替您挑的警告，会在所有人的第二次运行时就响 —— 而第一天就喊狼来了的东西， \
                到第三天就没人理了。
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )
}
