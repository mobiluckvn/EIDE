import Foundation

/// 简体中文帮助内容 —— 第五部分：越南语支持、语言与格式。
extension HelpZhHans {

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "越南语",
        summary: "旧编码、Unicode 规范化、无声调搜索，以及输入法。",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "越南语编码",
        summary: "读写 TCVN3、VISCII、VNI-Windows 及另外 33 种编码，自动识别。",
        keywords: ["编码", "tcvn3", "abc", "viscii", "vni", "乱码"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                打开一个旧的越南语文件，看到的是 `Tr¦êng §¹i häc` 而不是 `Trường Đại học`？文件 \
                没坏 —— 它是用 Unicode 之前的编码保存的。
                """),
            .steps([
                "点**状态栏**上的编码名（或 `Format ▸ 编码…`）。",
                "选对编码 —— 旧越南语文件通常是 `TCVN3 (ABC)`、`VNI-Windows` 或 `VISCII`。",
                "文字立刻恢复正常，不必重新打开文件。",
                "想一劳永逸就用 `另存为…`，编码选 `UTF-8`。",
            ]),
            .heading("三种越南语旧编码"),
            .table(
                headers: ["编码", "常见于"],
                rows: [
                    ["TCVN3 (ABC)", "北方的公文和较老的 Word 文档"],
                    ["VNI-Windows", "出版、报刊、印刷业 —— 南方常见"],
                    ["VISCII", "早期电子邮件与 Usenet"],
                ]
            ),
            .paragraph("""
                GEditor 打开时会**自动识别**。识别错了，一次点击即可更换，内容是重新解码的，而不是 \
                逐字修补。
                """),
            .warning("""
                写成旧编码时，那种编码没有的字符会丢失。GEditor 会**先数出来并告诉您** —— 例如 \
                *「有 12 个字符不在 TCVN3 中」* —— 而不是默默把它们变成问号。
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "换行方式",
        summary: "LF、CRLF、CR —— 一次点击转换整个文件。",
        keywords: ["eol", "crlf", "lf", "换行", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["方式", "用于", "字节"],
                rows: [
                    ["LF", "macOS、Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "2001 年前的 Mac", "`\\r`"],
                ]
            ),
            .paragraph("""
                当前方式显示在状态栏上，点它即可更改。**混用**两种方式的文件也会在那里报出 —— \
                打开`显示不可见字符 ▸ 换行`就能看到混在哪里。
                """),
            .note("**新**文件的换行方式在 `设置…` 里。"),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode 规范化",
        summary: "为什么搜「ế」有时什么也搜不到，以及怎么修好整个文件。",
        keywords: ["unicode", "nfc", "nfd", "预组合", "分解", "规范化", "搜不到"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                在 Unicode 里，`ế` 有**两种写法**：一个预组合码位（NFC），或者 `e` 加两个独立的 \
                记号（NFD）。屏幕上一模一样，对机器却是两个不同的字符串。
                """),
            .paragraph("""
                后果是：在 NFD 文件里搜 `ế` **什么也搜不到**，而用户会以为数据不存在。
                """),
            .steps([
                "`Format ▸ 规范化 Unicode…`",
                "选 **NFC**（预组合）—— 几乎其他所有东西用的都是这种形式。",
                "应用。这是一步撤销。",
            ]),
            .note("""
                来自 macOS 的文件常常是 NFD，因为苹果的文件系统就是那样存文件名的。这是从访达里 \
                拷出来的数据再也搜不到的最常见原因。
                """),
            .paragraph("""
                `设置…`里有一个**保存时规范化为 NFC** 的开关。默认关闭，因为它会改动文件的字节。
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "不打声调也能搜到带声调的字",
        summary: "每个搜索框和筛选框都在去掉声调后比较。",
        keywords: ["声调", "变音符", "搜索", "筛选"],
        blocks: [
            .paragraph("""
                输 `hue` 找到 `Huế`，输 `da nang` 找到 `Đà Nẵng`。这条规则适用于 CSV 表格筛选框、 \
                函数搜索、帮助搜索以及其他筛选框。
                """),
            .note("""
                `Đ` 是特别处理的，因为在 Unicode 里它是**独立的字母**，而不是带记号的 `D` —— \
                普通的去声调处理碰不到它。
                """),
            .paragraph("""
                CSV 筛选框还接受 `=` 前缀表示精确比较。`=` 形式**同样忽略声调**，因为一个区分 \
                声调的筛选会让用户以为数据不存在。
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "越南语输入法",
        summary: "EVKey、OpenKey、Unikey 和 macOS 自带输入源都能直接输入。",
        keywords: ["输入法", "evkey", "unikey", "openkey", "telex", "vni"],
        blocks: [
            .paragraph("""
                无需任何配置。Telex 和 VNI 都能用，**多光标**上也一样 —— 输入一次，每个光标都 \
                收到正确的带声调字母。
                """),
            .paragraph("搜索框、筛选框和所有对话框都和编辑器一样接受输入法。"),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - 语言与格式

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "语言与格式",
        summary: "二十种内置语言、自定义语言，以及 JSON · XML · YAML · 日志的工具。",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "二十种内置语言",
        summary: "基于真实语法树着色，并附各语言的注释符。",
        keywords: ["语法", "高亮", "语言", "tree-sitter", "grammar"],
        blocks: [
            .paragraph("""
                语言按**扩展名**识别（另有 `Makefile`、`Dockerfile`、`Gemfile` 等几个特殊文件名）。 \
                也可以在状态栏上手动更改。
                """),
            .table(
                headers: ["语言", "扩展名", "行注释 · 块注释"],
                rows: [
                    ["Shell", "`sh` `bash` `zsh` `command`", "`#` · —"],
                    ["C", "`c` `h`", "`//` · `/* */`"],
                    ["C++", "`cpp` `cc` `cxx` `hpp` `hh` `hxx`", "`//` · `/* */`"],
                    ["C#", "`cs`", "`//` · `/* */`"],
                    ["CSS", "`css`", "— · `/* */`"],
                    ["Go", "`go`", "`//` · `/* */`"],
                    ["HTML", "`html` `htm` `xhtml`", "— · `<!-- -->`"],
                    ["Java", "`java`", "`//` · `/* */`"],
                    ["JavaScript", "`js` `mjs` `cjs` `jsx`", "`//` · `/* */`"],
                    ["JSON", "`json` `jsonl` `geojson`", "— · —"],
                    ["Lua", "`lua`", "`--` · `--[[ ]]`"],
                    ["PHP", "`php` `phtml`", "`//` · `/* */`"],
                    ["Python", "`py` `pyw` `pyi`", "`#` · —"],
                    ["Regex", "—", "— · —"],
                    ["Ruby", "`rb` `rake` `gemspec`", "`#` · —"],
                    ["Rust", "`rs`", "`//` · `/* */`"],
                    ["TOML", "`toml`", "`#` · —"],
                    ["TypeScript", "`ts` `mts` `cts`", "`//` · `/* */`"],
                    ["XML", "`xml` `xsd` `xsl` `svg` `plist`", "— · `<!-- -->`"],
                    ["YAML", "`yaml` `yml`", "`#` · —"],
                ]
            ),
            .paragraph("""
                最后一列就是 `⌘/` 使用的符号。没有行注释的语言（JSON、CSS、XML）改用块注释。
                """),
            .heading("有语法树才有的东西"),
            .bullets([
                "侧边栏的**函数列表**遵循真实结构，而不是靠缩进猜。",
                "按结构**折叠**。",
                "**括号匹配**会跳过字符串和注释里的括号。",
                "**自动缩进**在 `{` 之后加一级，Python 和 YAML 在 `:` 之后加一级。",
            ]),
            .note("""
                三个较重的语法（C++、C#、Ruby）放在一个**惰性加载**的库里 —— 只有打开这三种语言 \
                的文件时才载入。启动时间能保持在半秒以内，靠的就是这个。
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "自定义语言",
        summary: "用一个 JSON 文件为自己的格式着色 —— 不必写语法。",
        keywords: ["udl", "自定义语言", "自定义日志"],
        blocks: [
            .paragraph("""
                公司内部的日志格式、自家的配置语言、一门小 DSL —— 这些都没有 tree-sitter 语法， \
                而写一个语法需要编译器和一点解析理论。
                """),
            .paragraph("""
                作为替代，GEditor 接受一个用 JSON 声明的**表驱动词法扫描器**。把文件放进 GEditor \
                配置目录下的 `grammars/` 文件夹，然后重启。
                """),
            .code(
                language: "json",
                caption: "grammars/internal-log.json —— 一门完整的语言",
                source: """
                    {
                      "name": "Internal log",
                      "extensions": ["nklog", "trace"],
                      "caseSensitive": false,
                      "lineComment": ";",
                      "blockComment": ["/*", "*/"],
                      "stringDelimiters": ["\\"", "'"],
                      "escapeCharacter": "\\\\",
                      "keywordGroups": {
                        "keyword": ["BEGIN", "END", "RETRY", "COMMIT", "ROLLBACK"],
                        "type":    ["INT", "TEXT", "DATE", "MONEY"],
                        "constant": ["TRUE", "FALSE", "NULL"]
                      }
                    }
                    """
            ),
            .heading("逐个键"),
            .table(
                headers: ["键", "类型", "含义"],
                rows: [
                    ["`name`", "字符串", "状态栏上显示的名字"],
                    ["`extensions`", "字符串数组", "扩展名，**不带点**"],
                    ["`caseSensitive`", "布尔", "关键字是否区分大小写"],
                    ["`lineComment`", "字符串", "行注释符；没有就省略"],
                    ["`blockComment`", "两个字符串", "`[开, 闭]`"],
                    ["`stringDelimiters`", "字符串数组", "每项是**一个**开闭字符串的字符"],
                    ["`escapeCharacter`", "字符串", "字符串里的转义字符；空表示该语言没有"],
                    ["`keywordGroups`", "对象", "组名 → 关键字表；三个组三种颜色"],
                ]
            ),
            .paragraph("有专属颜色的三个组名是 `keyword`、`type` 和 `constant`。"),
            .warning("""
                这个扫描器**不理解嵌套**。结构化折叠、函数列表和智能括号匹配仍然只属于二十种内置 \
                语言。这是有意的取舍：换来的是您用十分钟而不是一天声明一门语言。
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON 工具",
        summary: "格式化、压缩、排序键，以及按 JSON Schema 校验。",
        keywords: ["json", "格式化", "压缩", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["命令", "作用"],
                rows: [
                    ["格式化", "换行并缩进，便于阅读"],
                    ["压缩成一行", "去掉所有多余空白"],
                    ["排序键", "把每个对象的键按字母排序 —— 这样两个 JSON 文件才**能 diff**"],
                    ["按 JSON Schema 校验…", "对照 schema 文件检查文档，逐条列出问题及行号"],
                ]
            ),
            .paragraph("""
                适用的规则是**严格的 RFC 8259**：不许尾逗号、不许注释、不许 `NaN`。语法错误会 \
                指向确切的行和列。
                """),
            .note("""
                **JSONL** 文件（每行一个对象）同样能识别，并在知识包一章里有专门的工具。
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath 查询",
        summary: "从大 JSON 文件里精确取出需要的部分。",
        keywords: ["jsonpath", "json 查询", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("输入表达式，结果显示为可跳转的列表。"),
            .table(
                headers: ["写法", "含义"],
                rows: [
                    ["`$`", "文档根"],
                    ["`$.name`", "根上的 `name` 键"],
                    ["`$.orders[0]`", "数组的第一个元素"],
                    ["`$.orders[*].total`", "**每个**元素的 `total` 键"],
                    ["`$..province`", "**任意深度**上的 `province` 键"],
                    ["`$.orders[1:3]`", "切片：第 1 和第 2 个元素"],
                ]
            ),
            .code(
                language: "text", caption: "每张订单的省份代码，无论嵌套多深",
                source: "$..orders[*].address.province"
            ),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML 工具",
        summary: "格式化、压缩、语法检查，以及按 DTD 或 XSD 校验。",
        keywords: ["xml", "xsd", "dtd", "schema", "校验", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["命令", "作用"],
                rows: [
                    ["格式化", "按标签层级缩进"],
                    ["压缩成一行", "去掉标签之间的空白"],
                    ["语法检查", "缺失的闭合标签、错误的嵌套、非法字符"],
                    ["按 DTD/XSD 校验…", "对照 schema 检查，逐条报出行号"],
                    ["求值 XPath…", "运行一个 XPath 表达式，结果在新标签页打开"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                输入表达式，结果作为**一个文本标签页**打开，每个节点一行。例如： \
                `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`。
                """),
            .note("""
                **结果无法跳回源文件中的位置。** 系统的 XPath 求值器会建自己的一棵树，不保留每个 \
                节点的字节偏移，所以返回的是**内容**而不是坐标。要到确切位置，请对刚找到的字符串 \
                用 `⌘F`。
                """),
            .paragraph("""
                在 `.xml` 和 `.html` 文件里，输入 `>` 结束一个开标签时，**闭标签会自动出现**， \
                光标停在两者之间。自闭合标签（`<br/>`）、声明（`<?xml …?>`）和注释则不会 —— \
                它们没有什么要闭合。
                """),
            .warning("""
                格式化 XML 会**改动标签之间的空白**。在空白有意义的文档里 —— 比如标签内有文字的 \
                XHTML —— 这会改变显示内容。它是一步撤销，`⌘Z` 可以退回。
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML 检查",
        summary: "抓住两个最常见的 YAML 错误：重复键和 Tab 缩进。",
        keywords: ["yaml", "yml", "lint", "重复键", "缩进"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "同一个映射里的**重复键** —— 多数 YAML 读取器取**最后**一个并默默丢掉前面的，于是配置文件的行为可能与您以为的完全不同。",
                "**用 Tab 缩进** —— YAML 禁止在缩进里用 Tab，而各类库对此报出的错误通常难以理解。",
            ]),
            .note("打开`显示不可见字符 ▸ 制表符`就能立刻看出哪些空白是 Tab。"),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "日志文件",
        summary: "七个严重级别、按级别过滤，以及读超大日志的方法。",
        keywords: ["日志", "错误", "警告", "过滤", "级别"],
        blocks: [
            .paragraph("""
                打开`查看 ▸ 日志模式（按级别着色）`。GEditor 从**每行开头**读取严重级别 —— 在 \
                时间戳和进程名之后。
                """),
            .table(
                headers: ["级别", "颜色"],
                rows: [
                    ["CRITICAL · ERROR", "红色"],
                    ["WARNING", "琥珀色"],
                    ["NOTICE", "强调色"],
                    ["INFO", "普通文字"],
                    ["DEBUG · TRACE", "调暗"],
                ]
            ),
            .paragraph("""
                `按级别过滤日志…`会把低级别整个藏起来。级别**无法识别**的行 —— 比如堆栈跟踪的 \
                续行 —— 保持原样，而不会被安上上一行的级别。
                """),
            .heading("读一份大日志的步骤"),
            .steps([
                "打开文件 —— GB 级也几乎瞬间打开。",
                "`查看 ▸ 日志模式`，先看红色在哪。",
                "`⌥⌘M` 打开文档地图：红色是聚在一段，还是散布全文？",
                "`⌘F` 搜错误码，`⌘M` 标记所有匹配行。",
                "`搜索 ▸ 复制标记行`把它们放进新标签页。",
                "还在运行？用`文件 ▸ 跟踪文件（tail -f）`。",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
