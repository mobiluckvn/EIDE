import Foundation

/// 简体中文帮助内容 —— 第二部分：编辑与搜索。
extension HelpZhHans {

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "编辑",
        summary: "同时改多处、按行操作，以及值得先知道的隐含规则。",
        topics: [multipleCarets, columnBlock, columnEditor, lineOperations,
                 whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "多光标",
        summary: "选中所有相同之处，输入一次，全部改掉。",
        keywords: ["多光标", "multi caret", "cmd+d", "多重选择"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                这项功能替代了您大多数打算写正则的时刻。选中一个词，按几次 `⌘D` 收集后续出现的 \
                位置，然后输入 —— 所有位置同时改变。
                """),
            .shortcuts([
                HelpShortcut("⌘D", "把下一处出现加入选区"),
                HelpShortcut("⌘ + 点击", "在点击处再放一个光标"),
                HelpShortcut("Esc", "全部取消，回到一个光标"),
                HelpShortcut("⌥ + 拖动", "列块选择（另一种得到多光标的方式）"),
            ]),
            .heading("值得知道的规则"),
            .bullets([
                "在多个光标上输入、删除、粘贴是**一步**撤销，而不是每个光标一步。",
                "用方向键移动时光标不会散开 —— 整组一起走。",
                "`⌘D` 会跳过已在选区内的位置，所以按过头也不会叠出重复光标。",
            ]),
            .note("""
                长字符串中间的 `⌘D` 曾经很慢。词边界探测现在按批读取，在 1 MB 字符串上快了约 \
                **42 倍** —— 这让它在数据文件上也能用，而不只是源代码。
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "列块选择",
        summary: "跨多行选一个矩形 —— 用鼠标，或者用键盘。",
        keywords: ["列模式", "块选择", "矩形", "键盘", "方向键"],
        blocks: [
            .paragraph("""
                按住 `⌥` 拖动即可选出一个**矩形块**。输入、删除、粘贴都按块进行。把一个块粘到 \
                单个光标处，它仍然保持矩形。
                """),
            .shortcuts([
                HelpShortcut("⌥ + 拖动", "选择一个块"),
                HelpShortcut("⌥⌘← →", "把块向左/右扩一列"),
                HelpShortcut("⌥⌘↑ ↓", "把块向上/下扩一行"),
            ]),
            .paragraph("""
                键盘这条路不是鼠标的备用方案：用鼠标选四十行的块意味着要拖过一段滚动，而 `⌥⌘` \
                加方向键能保持逐列的精度。按**其他任意键**（或输入文字）即结束正在扩展的块。
                """),
            .heading("这里的列是**视觉列**"),
            .paragraph("""
                一个 TAB 会撑到您设定的下一个制表位，而不算作一列。正因如此，用 TAB 缩进的行和用 \
                空格缩进的行**在屏幕上对齐**。
                """),
            .paragraph("多字节文字仍算一列：`Nguyễn` 占六列，不是九列。"),
            .table(
                headers: ["情况", "GEditor 的做法"],
                rows: [
                    ["目标列落在 TAB 中间", "靠向较近的一边；相等则靠左"],
                    ["某行比起始列还短", "该行贡献一个空选区，输入时仍会接收字符"],
                    ["把块粘到单个光标处", "保持矩形，向下逐行插入"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "列编辑器",
        summary: "向块中每一行插入文本、数字序列或日期序列。",
        keywords: ["列编辑器", "编号", "序列"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                选中一个列块，然后打开 `编辑 ▸ Column Editor…`（`⌥⌘C`）。对话框在应用前会**预览**。
                """),
            .table(
                headers: ["模式", "参数", "何时用"],
                rows: [
                    ["文本", "一个固定字符串", "给每行加同样的前缀/后缀"],
                    ["数字序列", "起始 · 步长 · 2·8·10·16 进制 · 补零位数", "编号、生成编码"],
                    ["日期序列", "首个日期 · 天数步长", "生成连续日期列"],
                ]
            ),
            .code(
                language: "text",
                caption: "带补零的编号，从 1 开始，步长 1",
                source: """
                    之前:             之后（数字序列，补足三位）:
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """
            ),
            .bullets([
                "步长可以是**负数** —— 倒着数也行。",
                "插入 5000 行仍然只是**一步**撤销。",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "按行操作",
        summary: "排序、去重、移动、合并、拆分、复制、删除。",
        keywords: ["排序", "去重", "移动行", "合并", "拆分"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                有选区时命令作用于选区；没有选区时作用于**整个文档**。这里的每条命令都是一步撤销。
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "复制当前行"),
                HelpShortcut("⌘K", "删除当前行"),
                HelpShortcut("⌥↑ / ⌥↓", "上移 / 下移当前行"),
            ]),
            .heading("三种排序，该选哪种"),
            .table(
                headers: ["种类", "`file2` 与 `file10`", "适用于"],
                rows: [
                    ["A→Z / Z→A", "`file10` 排在 `file2` 前面", "纯文字列表"],
                    ["自然排序", "`file2` 排在 `file10` 前面", "文件名、带数字的编码、版本号"],
                ]
            ),
            .paragraph("""
                **自然排序**把连续数字当作数来读。列表带编号时，这几乎总是您想要的。
                """),
            .heading("去重"),
            .bullets([
                "**整个文档** —— 删掉此前出现过的每一行，保留第一次。",
                "**仅相邻** —— 只合并挨在一起的相同行，像 Unix 的 `uniq`。",
            ]),
            .heading("合并与拆分"),
            .bullets([
                "**合并行**把选中的多行并成一行。",
                "**按长度拆分**在指定字符数处切断长行。",
                "**按字符拆分**在每次遇到您输入的字符处切开 —— 例如把一行 CSV 拆成各个单元格。",
            ]),
            .note("""
                复制文件的**最后一行**会补上缺失的换行；删除到文档末尾也会吞掉前一行的换行。 \
                两处都不同于朴素实现，都是为了让文件既不多出、也不缺少一个空行。
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "空白与缩进",
        summary: "清掉多余空白、TAB ↔ 空格互换，以及一个值得斟酌的开关。",
        keywords: ["空白", "tab", "空格", "缩进", "空行"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["命令", "作用"],
                rows: [
                    ["删除空行", "删掉所有什么都没有的行"],
                    ["合并连续空行", "多个连续空行变成一个"],
                    ["去除行尾空白", "删掉每行末尾多余的空格和 TAB"],
                    ["Tab → Space", "按当前制表宽度把 TAB 换成空格"],
                    ["Space → Tab", "反方向"],
                ]
            ),
            .heading("按语言分别设定缩进"),
            .paragraph("""
                点状态栏上的 `Tab: 4`。菜单上半部分改的是**整个应用**；下半部分 —— `仅用于 Go`、 \
                `仅用于 Python`…… —— 只作用于当前文件的语言，并且连用 TAB 还是空格一起记住。
                """),
            .paragraph("""
                人们不是按喜好选缩进，而是按**各自社区的惯例**：Go 用 TAB（`gofmt` 会覆盖别的写 \
                法），Python 按 PEP 8 用四个空格，JavaScript 和 YAML 通常两个。所有语言共用一个 \
                数字，意味着您碰过的每个文件都会多出您根本没改过的行。
                """),
            .code(
                language: "json", caption: "settings.json",
                source: """
                    "languageIndent": {
                      "go":         { "width": 4, "usesTabs": true },
                      "python":     { "width": 4, "usesTabs": false },
                      "javascript": { "width": 2, "usesTabs": false }
                    }
                    """
            ),
            .note("""
                也可以直接写进 `settings.json` —— 键名就是语言代码（`go`、`python`、`javascript` \
                ……）。没列出的语言使用公共的 `tabWidth`。
                """),
            .heading("为什么「保存时去除行尾空白」默认关闭"),
            .paragraph("""
                `文件 ▸ 保存时去除行尾空白`会修改**您从未碰过的行**。默认打开的话，在别人仓库里 \
                改一个词就会变成上千行的 diff，审阅的人根本找不到真正的改动。
                """),
            .paragraph("""
                打开时，这次清理是写入之前的**一步独立撤销** —— 撤销一次即恢复原状，不会丢掉刚 \
                保存的内容。
                """),
            .heading("自动缩进"),
            .bullets([
                "新行继承上一行的缩进，并在开块符号后加一级 —— 花括号语言是 `{`，Python 和 YAML 是 `:`。",
                "度量按**视觉列**进行，所以混用 TAB 和空格的文件在屏幕上仍然对齐。",
                "**没有**「输入 `}` 就重新缩进」这条规则。那条规则会改动您已经写完的行，也是所有装了它的编辑器里被抱怨最多的行为。",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "大小写与命名风格",
        summary: "八种转换，包括 camelCase、snake_case 和 kebab-case。",
        keywords: ["大小写", "camel", "snake", "kebab", "标题式"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("作用于选区。全部位于 `Format` 菜单。"),
            .table(
                headers: ["命令", "`tổng doanh thu` 变成"],
                rows: [
                    ["全大写", "`TỔNG DOANH THU`"],
                    ["全小写", "`tổng doanh thu`"],
                    ["每词首字母大写", "`Tổng Doanh Thu`"],
                    ["句首大写", "`Tổng doanh thu`"],
                    ["大小写互换", "逐字符翻转"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                最后三种会去掉越南语声调，因为它们生成的是**代码里的标识符** —— 那里通常不允许 \
                带声调的字母。
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "注释与括号匹配",
        summary: "⌘/ 使用每种语言自己的注释符；⌃⌘B 跳到配对的括号。",
        keywords: ["注释", "括号", "cmd+/", "匹配"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` **按文档的语言**选注释符：Python 用 `#`，Rust 和 C 用 `//`，XML 和 HTML 用 \
                `<!-- -->`。
                """),
            .heading("整块朝同一个方向走"),
            .paragraph("""
                只要块里还有一行没被注释，命令就会注释**全部**。逐行判断会把一个注释了一半的块 \
                变成棋盘格。注释符插在块内缩进最浅的位置，所以块的形状保持不变。
                """),
            .heading("跳到配对括号"),
            .bullets([
                "`⌃⌘B` 跳到与光标处括号配对的那一个。",
                "**字符串**或**注释**里的括号不算 —— 一个轻量词法扫描器分得清。",
                "超过 **1 MB** 时命令会拒绝并说明，而不是扫到一半就猜。高亮错的一对比不高亮更糟。",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "撤销与剪贴板",
        summary: "无限撤销历史，以及一份多格剪贴板历史。",
        keywords: ["撤销", "重做", "剪贴板", "粘贴", "历史"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "撤销 / 重做"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "剪切 / 复制 / 粘贴"),
                HelpShortcut("⇧⌘V", "剪贴板历史"),
            ]),
            .heading("一次批量操作只是一步"),
            .paragraph("""
                给一百万行排序、替换一万处、用列编辑器插入五千行 —— 每一件都由**一次** `⌘Z` \
                撤销。
                """),
            .paragraph("""
                撤销历史放在 GEditor 自己的文本缓冲里，而不是系统的 `UndoManager`，原因正在于此： \
                `UndoManager` 是按击键计数的。
                """),
            .heading("剪贴板历史"),
            .paragraph("""
                `⇧⌘V` 打开最近复制过的内容列表，并粘贴您挑中的那条。需要在多处之间交替粘两段 \
                文字时很有用。
                """),
        ]
    )

    // MARK: - 搜索

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "搜索",
        summary: "查找、替换、正则、跨文件夹搜索，以及行标记。",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "查找与替换",
        summary: "三种搜索模式，以及 ^ 为什么默认表示**行**首。",
        keywords: ["查找", "替换", "搜索", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "查找"),
                HelpShortcut("⌥⌘F", "查找并替换"),
                HelpShortcut("⌘G / ⇧⌘G", "下一处 / 上一处"),
            ]),
            .heading("三种模式"),
            .table(
                headers: ["模式", "能理解", "适用于"],
                rows: [
                    ["普通", "纯文本，没有任何特殊字符", "大多数搜索"],
                    ["扩展", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "查换行、TAB、特定字节"],
                    ["正则", "完整的 PCRE2", "按模式匹配"],
                ]
            ),
            .note("""
                **扩展**模式不懂正则语法。它只展开几个转义序列 —— 所以在那里搜 `a.b` 找的就是这 \
                三个字符，点号不是通配符。
                """),
            .heading("两个开关"),
            .bullets([
                "**区分大小写** —— 默认关闭。",
                "**全词匹配** —— 只有两端都是词边界时才算命中。",
            ]),
            .heading("`^` 和 `$` 匹配每**行**的两端"),
            .paragraph("""
                默认开启。从 Notepad++ 过来的人期望 `^` 意味着「行首」；若关闭，`^abc` 只在整份 \
                文档以 `abc` 开头时才匹配 —— 在文本编辑器里几乎没人要这个。
                """),
            .heading("糟糕的表达式不会卡死应用"),
            .paragraph("""
                引擎是**带 JIT 编译的 PCRE2**，并且有回溯预算。组合爆炸的模式会被中止并报告， \
                而不是让窗口僵住。
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "正则表达式",
        summary: "真正会用到的 PCRE2 语法，配上能在越南语数据上跑的例子。",
        keywords: ["正则", "regex", "pcre", "模式"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor 使用 **PCRE2**，与 PHP 和许多命令行工具同一个引擎。打开 `搜索 ▸ 测试正则 \
                表达式…`，可以在示例文本上试模式、看清每个分组捕获到什么，**然后**再用到真实文档上。
                """),
            .heading("字符类"),
            .table(
                headers: ["写法", "匹配"],
                rows: [
                    ["`.`", "除换行外的任意字符"],
                    ["`\\d` · `\\D`", "数字 · 非数字"],
                    ["`\\w` · `\\W`", "词字符（字母、数字、`_`）· 相反"],
                    ["`\\s` · `\\S`", "空白 · 非空白"],
                    ["`[abc]`", "方括号内任一字符"],
                    ["`[^abc]`", "**不**在方括号内的一个字符"],
                    ["`[a-z]`", "区间内的一个字符"],
                ]
            ),
            .heading("重复次数"),
            .table(
                headers: ["写法", "含义"],
                rows: [
                    ["`*`", "零次或多次"],
                    ["`+`", "一次或多次"],
                    ["`?`", "零次或一次"],
                    ["`{3}` · `{2,5}` · `{2,}`", "恰好 3 次 · 2 到 5 次 · 2 次以上"],
                    ["`*?` `+?` `??`", "**懒惰**形式 —— 尽量少取"],
                ]
            ),
            .warning("""
                `.*` 是**贪婪**的：它先吃到行尾再往回退。在一行里切分字段时，几乎总要用 `.*?` \
                或像 `[^,]*` 这样收紧的字符类。
                """),
            .heading("锚点与分组"),
            .table(
                headers: ["写法", "含义"],
                rows: [
                    ["`^` · `$`", "行首 · 行尾"],
                    ["`\\b`", "词边界"],
                    ["`(…)`", "**捕获**分组 —— 可在替换串里复用"],
                    ["`(?:…)`", "非捕获分组"],
                    ["`(?<名字>…)`", "命名分组"],
                    ["`a|b`", "a 或 b"],
                    ["`(?=…)` · `(?!…)`", "前瞻：必须跟着 · 不能跟着"],
                    ["`(?<=…)` · `(?<!…)`", "后顾：前面必须是 · 前面不能是"],
                ]
            ),
            .heading("能直接跑的例子"),
            .code(language: "regex", caption: "所有十位越南手机号", source: "\\b0\\d{9}\\b"),
            .code(
                language: "regex", caption: "把 31/12/2026 这样的日期切成三组",
                source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"
            ),
            .code(
                language: "regex", caption: "简单 CSV 行的第三个单元格（无引号包裹）",
                source: "^[^,]*,[^,]*,([^,]*)"
            ),
            .code(
                language: "regex", caption: "带时间戳的 ERROR 或 FATAL 日志行",
                source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"
            ),
            .code(language: "regex", caption: "空行，或只有空白的行", source: "^\\s*$"),
            .code(
                language: "regex", caption: "带声调的越南语字母 —— 用 Unicode 类，别逐个列举",
                source: "\\p{L}+"
            ),
            .note("""
                `\\p{L}` 的意思是「任意 Unicode 字母」，所以 `ế` 和 `đ` 都能匹配。手工列举每个带 \
                声调的元音，是必然会漏的做法。
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "替换串",
        summary: "复用捕获分组，并在替换过程中改大小写。",
        keywords: ["替换", "反向引用", "分组", "$1", "\\U"],
        blocks: [
            .heading("回引捕获分组"),
            .table(
                headers: ["写法", "含义"],
                rows: [
                    ["`$1` … `$9`", "第 n 组的内容"],
                    ["`${1}`", "同上，但边界明确 —— 后面紧跟数字时用它"],
                    ["`\\1`", "也接受；GEditor 会改写成 `${1}`"],
                    ["`$0`", "整个匹配"],
                ]
            ),
            .note("""
                后一个字符是数字时，写 `${1}` 而不是 `$1`。`$123` 会被读成第 123 组；`${1}23` \
                才是第 1 组后面跟两个数字。
                """),
            .heading("替换时改大小写"),
            .table(
                headers: ["写法", "含义"],
                rows: [
                    ["`\\U`", "从此处起转大写"],
                    ["`\\L`", "从此处起转小写"],
                    ["`\\u`", "只把下一个字符转大写"],
                    ["`\\l`", "只把下一个字符转小写"],
                    ["`\\E`", "结束 `\\U` 或 `\\L` 区域"],
                ]
            ),
            .heading("例子"),
            .code(
                language: "text", caption: "把 31/12/2026 变成 2026-12-31",
                source: """
                    查找:  (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    替换:  $3-$2-$1
                    """
            ),
            .code(
                language: "text", caption: "把每行开头的省份代码转成大写，其余保持不变",
                source: """
                    查找:  ^([a-z]{2,3})(\\s)
                    替换:  \\U$1\\E$2
                    """
            ),
            .code(
                language: "text", caption: "把每一行包成一个 JSON 字符串",
                source: """
                    查找:  ^(.+)$
                    替换:  "$1",
                    """
            ),
            .paragraph("""
                **没有参与**匹配的分组会变成空字符串，而不是报错 —— 所以带 `(a)|(b)` 这类分支的 \
                模式不必写两遍也能正常替换。
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "在整个文件夹中查找与替换",
        summary: "一次扫描多个文件，写入之前先看结果。",
        keywords: ["跨文件查找", "grep", "批量替换", "文件夹"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "在文件夹中查找")]),
            .paragraph("""
                选好根目录、按文件名模式过滤，然后扫描。结果按文件分组列出；点某一行就在那个位置 \
                打开该文件。
                """),
            .bullets([
                "与文档内搜索框相同的三种模式、相同的正则引擎。",
                "文件夹替换会先**预览**将改动多少文件、多少处，然后才写入。",
                "扫描并行执行，并且**中途可以取消**。",
            ]),
            .warning("""
                文件夹替换会直接写入**未打开**的文件。那些文件不在当前文档的撤销历史里 —— 请先 \
                预览，并保留备份或使用版本控制。
                """),
            .heading("此前的搜索，以及导出结果"),
            .paragraph("""
                结果面板会**保留本次会话的各轮搜索**。面板顶部的下拉列出它们和各自的命中数 —— \
                搜 `TODO`、读到一半、再搜 `FIXME` 作对比，然后回到第一份列表，而不必重扫整个 \
                文件夹。
                """),
            .paragraph("""
                **导出**按钮把当前这轮打开成一个文本标签页，每条结果一行，形如 \
                `路径:行:列: 内容` —— 正是 `grep -n` 和编译器报错的格式。每一行都能直接粘进本 \
                产品自己的`跳转`框，您的 `grep`、`awk`、`sed` 也无需另写解析器就能读。
                """),
            .note("""
                历史只留在**内存**里，从不写盘：搜索结果带着被扫文件每一行的内容，而这与剪贴板 \
                历史刻意不落盘的是同一类数据。
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "行标记",
        summary: "九种标记颜色，以及把标记行变成结果的四条命令。",
        keywords: ["书签", "标记", "f2", "过滤行"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                标记是**不改动文档**的过滤方式。把匹配某模式的行全部标记，然后单独复制出来，或者 \
                只保留它们。
                """),
            .shortcuts([
                HelpShortcut("⌘M", "标记所有匹配当前搜索的行"),
                HelpShortcut("⌘F2", "标记 / 取消标记当前行"),
                HelpShortcut("F2 / ⇧F2", "跳到下一个 / 上一个标记"),
            ]),
            .heading("常用流程"),
            .steps([
                "`⌘F` 搜要过滤的模式，例如 `\\bERROR\\b`。",
                "`⌘M` 标记所有匹配行。",
                "`搜索 ▸ 复制标记行`把它们放进新标签页 —— 或者`只保留标记行`就地过滤。",
            ]),
            .heading("九种颜色"),
            .paragraph("""
                一行可以**同时带多种颜色**。不同标准用不同颜色，再组合起来看：红色表示错误行， \
                黄色表示属于某个订单号的行，然后找同时带两种颜色的行。
                """),
            .bullets([
                "`反转标记` —— 已标记的取消，未标记的加上。",
                "`清除所有标记` —— 只去掉标记，不动内容。",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "跳转",
        summary: "跳到某一行、某一列，或某个字节位置。",
        keywords: ["跳转", "行号", "cmd+l", "偏移", "位置", "列"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "跳到某一行")]),
            .paragraph("""
                输入框懂**三种写法**，并且只凭您输入的内容区分它们 —— 不需要再点什么选择器。
                """),
            .table(
                headers: ["输入", "跳到"],
                rows: [
                    ["`120`", "第 120 行行首"],
                    ["`120,5` 或 `120:5`", "第 120 行第 5 列 —— 列按**字符**计"],
                    ["`@1024`", "文件中第 1024 个字节"],
                ]
            ),
            .note("""
                `行:列` 正是编译器和检查工具打印位置的格式，所以刚从终端复制来的一行可以直接粘进来。

                字节位置前面的 `@` 有它的理由：`1234` 是行还是字节？没有正确答案，而猜错会把光标 \
                送到完全不同的地方且毫无提示。那个字节数也正是状态栏位置段显示的内容（`@1024`）， \
                在那里读到的，在这里就能输进去。
                """),
            .bullets([
                "**超出该行长度**的列号停在行尾，不会溢到下一行。",
                "**超出文件**的字节位置会带您到文件末尾 —— 那个数字通常抄自上一次运行，而文件可能已经变短。",
                "读不懂的内容会**明确报告**，光标原地不动；不会跳回文件开头。",
            ]),
            .paragraph("""
                在超大文件上，GEditor 不必读完整个文件才能到达 —— 行索引在后台逐步建立。
                """),
            .note("""
                命令行工具也接受位置：`geditor report.csv:120:5` 打开文件并把光标放在第 120 行 \
                第 5 列。
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )
}
