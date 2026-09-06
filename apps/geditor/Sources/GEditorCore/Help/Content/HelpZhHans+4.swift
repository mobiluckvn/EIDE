import Foundation

/// 简体中文帮助内容 —— 第四部分：文档视图。
extension HelpZhHans {

    static let views = HelpChapter(
        id: "xem",
        title: "查看文档的方式",
        summary: "侧边栏、地图、折叠、分屏、换行、不可见字符、着色模式。",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "侧边栏与函数列表",
        summary: "文件树和当前文件的函数列表，同在一栏。",
        keywords: ["侧边栏", "函数列表", "大纲", "文件树"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "显示 / 隐藏侧边栏")]),
            .paragraph("""
                函数列表由语言的**语法树**生成，因此遵循真实结构，而不是靠缩进猜。点条目即跳转。
                """),
            .note("函数列表里的筛选框**不打声调也能找到带声调的字**。"),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "文档地图",
        summary: "右侧窄栏里的整个文件 —— 几百 MB 也一样。",
        keywords: ["缩略图", "地图", "概览"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "显示 / 隐藏文档地图")]),
            .paragraph("""
                地图描述的是**整个文件**，不只是屏幕上这一段。在地图上拖动即跳到对应区域。
                """),
            .paragraph("""
                搜索命中和标记行会显示在地图上，所以滚过去之前就能看出它们是分散还是聚成一堆。
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "折叠",
        summary: "按结构折叠函数、代码块和数组 —— 或者把整个文件折到某一层。",
        keywords: ["折叠", "code folding", "收起"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "折叠 / 展开光标处的块"),
                HelpShortcut("⌥⇧⌘←", "全部折叠"),
                HelpShortcut("⌥⌘→", "全部展开"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "把整个文件折到第 1…8 层"),
            ]),
            .paragraph("""
                有语法树的语言按**真实结构**折叠；没有语法的文件按缩进折叠。
                """),
            .paragraph("""
                `折到某一层`在深层 JSON 和 YAML 上最见效：折到第 2 层，整个文件的骨架就在一屏里。
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "分屏",
        summary: "并排两个窗格，看两个文件 —— 或同一个文件的两处。",
        keywords: ["分屏", "窗格", "对比"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "纵向分屏"),
                HelpShortcut("⌥⌘-", "横向分屏"),
                HelpShortcut("⌥⌘0", "取消分屏"),
                HelpShortcut("⌥⌘]", "在另一半打开这个标签页"),
                HelpShortcut("⌥⌘[", "跳到另一半"),
            ]),
            .paragraph("""
                每一半有自己的标签栏。两边打开**同一个文件**也可以 —— 它们独立滚动，比对文件头 \
                尾很方便。
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "自动换行",
        summary: "三种模式：关闭、按窗口宽度、或在固定列换行。",
        keywords: ["自动换行", "软换行"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["模式", "长行会"],
                rows: [
                    ["关闭", "横向滚动"],
                    ["按窗口", "在窗口边缘折行，随窗口大小变化"],
                    ["在某列", "在您设定的列折行 —— 比如 80 或 100"],
                ]
            ),
            .paragraph("""
                换行是一种**看法**，不是编辑：不会插入任何换行符，也不进入撤销历史。
                """),
            .note("快捷入口是状态栏上的 `Ngắt: …` 那一段。"),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "字号",
        summary: "在 8–32 pt 之间缩放。",
        keywords: ["缩放", "字号", "放大", "缩小"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "放大"),
                HelpShortcut("⌘-", "缩小"),
                HelpShortcut("⌃⌘0", "回到默认字号"),
            ]),
            .paragraph("""
                范围限制在 8–32 pt。这同样是一种**看法**：不产生编辑，不进入撤销历史。默认字号 \
                在 `设置…` 里。
                """),
            .note("`⌘0` **不是**默认字号 —— 那个键用于显示和隐藏侧边栏。"),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "显示不可见字符",
        summary: "一组一组地开，因为全开通常太多了。",
        keywords: ["不可见字符", "空白", "nbsp", "零宽", "tab"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "显示 / 隐藏所有不可见字符")]),
            .paragraph("""
                四组可分别开关，因为一次全开会把内容埋进一片小点里。
                """),
            .table(
                headers: ["组", "能抓到什么"],
                rows: [
                    ["空格", "行尾多余空格、缩进不一致"],
                    ["制表符", "混用 TAB 和空格的文件"],
                    ["换行", "混用 CRLF 和 LF 的文件"],
                    ["NBSP · 零宽 · 控制字符", "来自 Word、网页、表格的隐形字符"],
                ]
            ),
            .warning("""
                最后一组最能救命。从网页粘来的不换行空格（NBSP）看上去**和普通空格一模一样**， \
                却让每一次字符串比较和每一个筛选落空 —— 不打开这一组就无从看见。
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV 模式与日志模式",
        summary: "两种替代语法着色的方案，面向两类数据文件。",
        keywords: ["csv 模式", "日志模式", "着色", "列", "日志级别"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV 模式"),
            .paragraph("""
                在**文本**视图里给每一列上色，这样不切到表格也能看出哪个单元格串了列。
                """),
            .heading("日志模式"),
            .paragraph("""
                按从行里读出的**严重级别**着色：错误红色，警告琥珀色，而 `debug` 和 `trace` 调暗 \
                —— 它们占了日志的大半，把它们标亮反而会盖住您真正要找的东西。
                """),
            .paragraph("`按级别过滤日志…`直接把不需要的级别藏起来。"),
            .note("""
                这两种是**替代**语法着色，而不是叠加。日志文件没有可着色的语法，而两个着色来源 \
                写到同一段字节上，胜负无法预测。
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "二进制视图",
        summary: "任何文件的十六进制表 —— 1 GB 的也几乎瞬间打开。",
        keywords: ["十六进制", "二进制", "字节", "偏移", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `查看 ▸ 二进制视图`把文件的每个字节显示为三列：**偏移 · 十六进制 · 文字**。对磁盘 \
                上的**任何**文件都有效，不限于图片或视频。
                """),
            .table(
                headers: ["列", "内容"],
                rows: [
                    ["偏移", "字节位置，十六进制"],
                    ["十六进制", "每行 16 字节，第 8 字节后分开以便计数"],
                    ["文字", "可打印的 ASCII 字节；其余显示为 `.`"],
                ]
            ),
            .note("""
                文字列**不解码 UTF-8**。一个越南语字母占两到三个字节，渲染出来会让文字列和十六 \
                进制列错位 —— 而那份对齐正是这一列的全部意义。要读带声调的文字，请用普通视图。
                """),
            .heading("大文件"),
            .paragraph("""
                文件是**内存映射**的，所以用二进制视图打开 1 GB 文件只花看得见的那部分的代价。 \
                自检套件里的测量：**不到一毫秒**。
                """),
            .paragraph("""
                视图一次显示**一个 4 MB 窗口**，顶栏说明当前处在哪一段。这是系统表格渲染器的限制， \
                不是读取的限制：1 GB 是 6250 万行，超过某个规模后滚动时行会跳位 —— 会跳位的十六 \
                进制表毫无用处。
                """),
            .heading("跳到某个位置"),
            .table(
                headers: ["在偏移框里输入", "含义"],
                rows: [
                    ["`1F400`", "十六进制 —— 默认"],
                    ["`0x1F400`", "同上，带明确前缀"],
                    ["`#128000`", "十进制，当您手上是字节数而不是十六进制偏移时"],
                ]
            ),
            .bullets([
                "`‹` 和 `›` 切到上一个 / 下一个窗口。",
                "**复制选中的行**复制的正是您看到的内容 —— 什么都没选时复制整个窗口。",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown 预览",
        summary: "把 Markdown 渲染成带格式的文字 —— 并明说它不渲染什么。",
        keywords: ["markdown", "预览", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("用系统的 Markdown 支持渲染：粗体、斜体、代码、链接、列表。"),
            .warning("""
                **不渲染表格，代码块内也不着色。** 预览窗口在底部明说了这一点。超过 **4 MB** 的 \
                文档会被拒绝。
                """),
            .paragraph("""
                需要能发布的文档里带表格和图表？那是 `.greport.md` 报告的事，不是这个预览的事。
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "两种模式：View 与 Code",
        summary: "一个键在渲染结果和可编辑源之间切换，对每种文件类型都适用。",
        keywords: ["view", "code", "模式", "源", "渲染", "预览"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "在 View 与 Code 之间切换")]),
            .paragraph("""
                控件就在**标签栏下方那一条**里 —— 每种文件都在同一个位置：一个 `View | Code` \
                开关，然后是该文件 View 模式的名字（「文档页面」「键–值树」「图表」……）。只有一种 \
                模式的文件会把开关置灰并说明原因。右端是各类型自己的按钮：`.xlsx` 有**表格**（可 \
                编辑，直接写回），`.pptx` 有**大纲**。
                """),
            .note("""
                **Word 和 PowerPoint 表现得像文档阅读器。** 它们的 View 模式渲染真正的页面 —— \
                字体、字号、颜色都对，有图片、表格、页眉页脚和页码。页面**正好与框等宽**，也能 \
                缩放。Excel 是有意的例外：它的 View 是**可编辑的电子表格**，因为电子表格在打印 \
                之前没有纸张尺寸。
                """),
            .note("""
                代价是：页面**只读**，而且渲染的是**磁盘上的副本**：在 Code 里改了没保存，页面 \
                显示的就是旧版本 —— 那一条会说明，并给出`保存并重新渲染`按钮。
                """),
            .heading("定义"),
            .bullets([
                "**Code** 是**可编辑的源**。文本文件的源就是文本本身。二进制文件 —— PDF、图片、音频、视频 —— 没有文本源，所以 Code 就是**字节**，以十六进制显示。",
                "**View** 是从 Code **渲染**出来的东西。它可能更好看、更简短、能运行 —— 但它始终是结果，从不是原件。",
            ]),
            .paragraph("""
                对 PDF 说*「这种类型没有 Code」*会方便些，但那是错的：字节确实是它的源。
                """),
            .heading("在哪里编辑"),
            .paragraph("""
                编辑发生在 **Code** 里。恰好有**两个例外**，都因为在 View 里操作自然得多： \
                **CSV 表格单元格**和 **PDF 表单域**。两者都直接写进源，所以不会冒出第二份副本 \
                让人争论哪份才对。
                """),
            .heading("按文件类型"),
            .table(
                headers: ["文件类型", "View", "Code", "在哪编辑"],
                rows: [
                    ["CSV · TSV", "表格", "原始文本", "**两边都行**"],
                    ["Excel `.xlsx`", "当前工作表的表格", "该表的 CSV", "**两边都行**"],
                    ["PDF", "渲染出的页面", "二进制", "**两边都行** —— 批注、表单域、页面"],
                    ["Markdown `.md`", "渲染后的文字", "Markdown 源", "Code"],
                    ["报告 `.greport.md`", "已跑完查询并绘图的报告", "源", "Code"],
                    ["JSON", "可折叠的键–值树", "JSON 源", "Code"],
                    ["XML · HTML", "可折叠的标签树", "XML 源", "Code"],
                    ["YAML", "按缩进的键–值树", "YAML 源", "Code"],
                    ["图表 `.mmd` · `.dot`", "画出来的图，占满标签页", "mermaid 或 DOT 源", "Code"],
                    ["Word `.docx`", "渲染出的文档页面", "抽取出的 Markdown", "Code"],
                    ["PowerPoint `.pptx`", "渲染出的幻灯片页面", "Markdown 大纲", "Code"],
                    ["日志文件", "按级别着色，可过滤", "原始文本", "Code"],
                    ["图片", "图片（动图可播放）", "二进制", "只读"],
                    ["音频 · 视频", "播放器", "二进制", "只读"],
                    ["压缩包", "条目列表", "二进制", "只读"],
                    ["源代码、纯文本", "— 没有", "文本本身", "Code"],
                ]
            ),
            .note("""
                源代码**没有 View**，这很正常，不是缺陷：一个 Swift 文件没有值得一看的渲染形态。
                """),
            .heading("Word 与 PowerPoint 的页面阅读器"),
            .paragraph("""
                页面纵向排列、连续滚动，每页是灰底上的一张白纸 —— 和所有文档阅读器一样。它的控件 \
                在那一条的右端。
                """),
            .table(
                headers: ["按钮 / 按键", "作用"],
                rows: [
                    ["`适合宽度`", "纸张正好与框等宽 —— 打开时的默认"],
                    ["`适合整页`", "整张纸装进框里"],
                    ["`−` `+`", "逐档缩放；也可以双指捏合，或 ⌘ + 滚动"],
                    ["`查找`框，或 ⌘F", "在页面中搜索、跳转并高亮"],
                    ["在查找框按回车", "下一处"],
                    ["拖动", "选中文字；双击选词，三击选段"],
                    ["⌘A · ⌘C", "全选 · 复制所选"],
                    ["Page Up · Page Down · Home · End", "在文档中移动"],
                ]
            ),
            .paragraph("""
                查找框**忽略声调和大小写**：输 `vuong quoc` 能找到 `Vương quốc`。那一条上的 \
                「第 12/363 页」告诉您读到哪里了。
                """),
            .note("""
                **没有渲染的部分，明说：**浮动锚定图片（文字绕图）显示为行内图片；脚注、图表和 \
                PowerPoint 的 SmartArt 没有绘制。需要与打印件严格一致时，请用 Word 打开。
                """),
            .heading("点树上的节点会跳回源"),
            .paragraph("""
                JSON 树不是一份漂亮的打印稿：点一个节点，光标会移到**该节点的值**在文本中的位置， \
                标签页也回到 Code —— 因为您接下来想做的几乎总是编辑刚点的那处。
                """),
            .bullets([
                "容器节点显示**元素个数**（`{12}`、`[340]`）而不是内容 —— 那才回答「值不值得展开」。",
                "默认展开**前两层**：一万个节点全展开会得到比源文件还长的列表，全收起则什么都要点开才知道。",
                "**语法有错**的文件不会得到半棵树 —— 一棵截断的树看起来就像文档只有这么点内容。",
                "XML 树里，属性带 `@` 前缀，正是 XPath 的记法；**标签之间的空白不会成为节点** —— 它是格式，不是内容。",
                "YAML 树能读**多文档文件**（`---`）：每份文档一个根。行内写法的集合（`ports: [80, 443]`）保持为一个叶子 —— 内容已经全看得见，展开只多一次点击。**用 Tab 缩进**会连同行号一起报出：那是肉眼看不见的 YAML 错误。",
                "PowerPoint 大纲根据**打开的文本**构建，而不是磁盘上的文件：您刚在 Code 里改过大纲，树就必须描述新版本，节点也必须跳进新版本。演讲者备注收进一个可折叠节点，免得一张话多的幻灯片看起来像内容很多。",
                "**占满标签页的图表同样遵守这条规则**：点一个节点就回到 Code，光标停在该节点的声明行。在并排的 `Mermaid Studio` 面板里标签页不会关闭 —— 编辑器就在旁边，移动光标即可看见。",
                "图表也会**在您所在的位置打开**：标签页一出现，与光标所在行对应的元素就已高亮，不用拿眼睛去找。",
            ]),
            .heading("筛选框：一万个节点的树里，搜索才是正事"),
            .paragraph("""
                节点计数下方有一个筛选框。在里面输入，树就只留下匹配的节点 —— **连同从根到它们 \
                的路径**，因为当一个 `name` 键出现在十个地方时，真正的问题是「哪一个」，而只有 \
                包含它的那条分支能回答。其余部分为您展开：让您逐层点开，等于让您再手工筛一遍。
                """),
            .bullets([
                "同时按**标签和值**筛选：搜 `Huế` 和搜键名 `province` 一样常见。",
                "**不打声调也能匹配带声调的字** —— `da nang` 找到 `Đà Nẵng`。与 CSV 表格筛选框、函数列表用的是同一套比较，免得您在一个应用里记三套搜索规则。",
                "没有匹配时表头写**「没有结果」**，而不是让您对着一棵空树怀疑文件坏了。",
                "切换文件或重新进入 View 会**清空筛选**：一棵一打开就已经被截断、又没有任何说明的树，是最令人困惑的状态。",
            ]),
            .heading("整棵树都能用键盘操作"),
            .paragraph("""
                进入 View 后焦点就在树上，不必先用鼠标点它。上下移动节点，左右折叠展开，还有两个 \
                结束浏览的键 —— 它们做的是**不同**的事：
                """),
            .bullets([
                "**回车** —— 前往选中的节点：回到 Code，光标落在该节点的字节范围内。和点击完全一样。",
                "**Tab** —— 在树和筛选框之间移动。",
                "**⌘C** —— 复制选中节点的**路径**，而不是树后面的文本。JSON 和 YAML 产出 JSONPath（`$.customer['name']`），可直接粘进本产品自己的 JSONPath 查询框，或粘给 `yq`；XML 产出 XPath（`/order/item[2]/@code`），同名标签会带序号；PowerPoint 大纲复制的是该行文字，因为大纲没有可以杜撰的路径语言。",
                "**Esc** —— 退路：回到 Code，但光标**留在原处**。您刚才是在看一棵树，不是去了哪里。",
            ]),
            .heading("反过来：树在光标所在处展开"),
            .paragraph("""
                从一万行文件的中间进入 View，树**不会**从顶部打开：它会展开到与光标所在处对应的 \
                节点，并选中它。这是「跳回源」的另一半 —— 少了它，View 和 Code 就只是**单向**的 \
                两种看法。
                """),
            .bullets([
                "需要时会展开**超过两层**：两层规则回答的是「这个文件长什么样」，而这里的问题不同 —— 「我在树的哪里」。",
                "光标停在**键**上（`\"address\":`）会选中那一项，尽管节点的字节范围只覆盖值。紧挨节点之前的文字属于该节点。",
                "光标停在**块的开头** —— YAML 块的键、幻灯片标题、XML 标签名 —— 会选中那个块，而不是钻进它的第一个子节点。",
                "进入 View **不移动光标**。退出 View 后您还在原处；View 是一种看法，不是改变位置的命令。",
            ]),
            .heading("不再有缺 View 的类型"),
            .paragraph("""
                **凡是有 View 余地的文件类型，如今都能渲染。** 那份「还缺什么」的清单已经空了， \
                因而被删掉。

                源代码和纯文本仍然没有 View —— 这很正常，不是缺陷，所以它们从来不在那份清单里。

                如果将来新增一种文件类型而 View 还没做好，切换命令会明说并点出缺的是什么，而不是 \
                打开一个空框 —— 空框是空头承诺，有名有姓的拒绝才是信息。
                """),
            .heading("六条旧命令仍然都在"),
            .paragraph("""
                `表格 / 文本视图`、`Markdown 预览`、`二进制视图`、`报告预览`、`Mermaid 图表预览`、 \
                `日志模式` —— 全都在原处。`⌥⌘V` 是一个**共用入口**，不是替代品。
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )
}
