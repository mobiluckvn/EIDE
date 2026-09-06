import Foundation

/// 简体中文帮助内容 —— 第一部分：入门、编辑、搜索、文件、视图。
///
/// **主题 id 一律不翻译。** 它们是 `.seeAlso` 指向的目标，是菜单打开某一页的凭据，也是帮助
/// 窗口切换语言时能让读者**停留在同一页**的原因。改动 id 会同时打断所有语言版本的链接。
///
/// `commands:` 里的菜单标题同样保持越南语原文：它们要和真实菜单项逐字匹配，覆盖率检查正是
/// 按这个字符串来核对的。
enum HelpZhHans {}

extension HelpZhHans {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "入门",
        summary: "GEditor 能做什么，以及最初五分钟该走哪条路。",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "GEditor 是什么",
        summary: "面向 macOS 的 GB 级文本与数据编辑器，说得了越南语。",
        keywords: ["简介", "欢迎", "概览", "关于", "intro", "overview"],
        blocks: [
            .paragraph("""
                GEditor 打开 **1 GB 的文件，却不会把 1 GB 读进内存**。它在内存映射的文件上按滑动 \
                窗口读取，所以两亿行的日志或一百万行的 CSV 都能在一秒左右打开并流畅滚动。
                """),
            .paragraph("""
                除了编辑，它还是一张**数据工作台**：把 CSV 当表格看、清洗、评分、用 SQL 查询、 \
                挖掘异常与趋势，再生成报告。它还能读那些如今大多数工具已经遗忘的越南语旧编码。
                """),
            .heading("先试这六件事"),
            .table(
                headers: ["任务", "去哪里"],
                rows: [
                    ["打开大文件而不用等待", "把文件拖进窗口 —— 见《打开大文件》"],
                    ["同时改多处", "`⌘D` 逐个添加相同片段，然后一次输入"],
                    ["用正则搜索", "`⌘F`，打开 Regex —— 引擎是带 JIT 的 PCRE2"],
                    ["把 CSV 当表格看", "`⌥⌘T` —— 一百万行照样顺滑"],
                    ["清理一张脏表", "`⇧⌘L` 清洗台 —— 先预览再应用"],
                    ["打开显示为乱码的越南语文件", "点状态栏上的编码名"],
                ]
            ),
            .note("""
                从 Notepad++ 过来？有一页专门对照两边的快捷键，因为在 macOS 上有几个键是**互换 \
                位置**的，而不只是把 `Ctrl` 换成 `⌘`。
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "最初的五分钟",
        summary: "十二个快捷键覆盖了日常工作的大部分。",
        keywords: ["快捷键", "上手", "基础", "quick start"],
        blocks: [
            .paragraph("""
                不必全学。下面十二个键覆盖了日常大部分工作，其余的用到时再查。
                """),
            .shortcuts([
                HelpShortcut("⌘O", "打开文件"),
                HelpShortcut("⇧⌘O", "把整个文件夹作为工作区打开"),
                HelpShortcut("⌘T", "新标签页"),
                HelpShortcut("⌘S", "保存"),
                HelpShortcut("⌘F", "查找"),
                HelpShortcut("⌥⌘F", "查找并替换"),
                HelpShortcut("⇧⌘F", "在整个文件夹中查找"),
                HelpShortcut("⌘D", "把下一处相同内容加入选区"),
                HelpShortcut("⌘L", "跳到某一行"),
                HelpShortcut("⌘/", "按语言自身语法注释当前行"),
                HelpShortcut("⌥⌘T", "在表格与文本之间切换（CSV 文件）"),
                HelpShortcut("⌘?", "重新打开这个帮助窗口"),
            ]),
            .heading("三件让新用户意外的事"),
            .bullets([
                "**一次批量操作只是一步撤销**，哪怕它动了一百万行。排序错了？按一次 `⌘Z` 就回来了。",
                "**工作状态自己恢复。** 退出再打开，标签页回到原处，未保存的也在。不用按任何按钮。",
                "**不打声调也能搜到带声调的字** —— 每个搜索框和筛选框都如此：输 `hue` 得到 `Huế`，输 `da nang` 得到 `Đà Nẵng`。",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "您想做什么？",
        summary: "一张从真实任务查到对应章节的对照表。",
        keywords: ["索引", "查找", "怎么做", "how to"],
        blocks: [
            .paragraph("""
                左侧目录按**功能**排列，这张表按**任务**排列 —— 两种顺序并不重合。
                """),
            .table(
                headers: ["我需要……", "请看"],
                rows: [
                    ["在几百行的同一个位置上改", "多光标 · 列块选择"],
                    ["用正则批量改格式", "查找替换 · 正则表达式"],
                    ["重复一串操作", "宏"],
                    ["打开别人发来的 CSV", "CSV 表格"],
                    ["清理脏表：日期混乱、数字混着文字", "数据清洗流程"],
                    ["判断这张表能不能信", "数据质量评分"],
                    ["找异常、趋势、聚类", "数据挖掘流程"],
                    ["用 SQL 提问", "用 SQL 查询 CSV"],
                    ["发布一份数字会自动更新的报告", "`.greport.md` 报告"],
                    ["在文档里画图", "Mermaid"],
                    ["打开乱码的越南语文件", "越南语编码"],
                    ["从命令行或 AppleScript 自动化", "自动化"],
                    ["为公司自创的格式着色", "自定义语言"],
                ]
            ),
            .note("""
                没列出来？左上角的搜索框会搜**正文和示例代码**，所以直接输入像 `fail_under` 这样 \
                的配置键名也能落到正确的页面。
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "打开大文件",
        summary: "1 GB 为什么打得开，以及 GEditor 在哪些地方宁可拒绝也不猜测。",
        keywords: ["大文件", "GB", "日志", "mmap", "慢", "性能"],
        blocks: [
            .paragraph("""
                文件被**内存映射**，再按滑动窗口读取；正在编辑的部分放在 piece table 里。实际效果 \
                是：打开时间几乎与文件大小无关，占用的内存也一样。
                """),
            .heading("有意拒绝的地方"),
            .paragraph("""
                有几种计算必须把整个文件读成一个字符串 —— 正是这套架构要避免的事。在那里，GEditor \
                会**明说自己不做**，而不是悄悄变慢或胡乱猜测：
                """),
            .table(
                headers: ["操作", "上限", "超过之后"],
                rows: [
                    ["括号匹配", "1 MB", "拒绝并说明 —— 高亮错的一对比不高亮更糟"],
                    ["状态栏上的视觉列号", "200 KB", "退回按字节计数，并标一个 `~` 让含义可见"],
                    ["Markdown 预览", "4 MB", "拒绝并说明"],
                ]
            ),
            .warning("""
                一个看上去一模一样、含义却变了的数字，是最糟糕的错。这就是超过上限的列号显示为 \
                `~1234` 而不是 `1234` 的原因。
                """),
            .heading("日志文件的窍门"),
            .bullets([
                "`文件 ▸ 跟踪文件（tail -f）` 会把追加到末尾的内容读进来。跟踪期间文档变为**只读** —— 一边输入一边从磁盘载入，等于两个写入者抢一份文档，输的永远是您刚敲的字。",
                "日志行按**严重级别着色**，也能按级别过滤。",
                "**文档地图**（`⌥⌘M`）描述整个文件，而不只是屏幕上这一段。",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App Store 版与直接下载版",
        summary: "三项功能只有直接下载版才有，以及为什么。",
        keywords: ["app store", "沙盒", "下载", "cli", "插件", "区别"],
        blocks: [
            .paragraph("""
                GEditor 有两个发行版本。它们出自**同一份源码**，应用在启动时自己认出身处哪一版。 \
                差别只在于 App Sandbox 允许什么。
                """),
            .table(
                headers: ["功能", "App Store", "直接下载"],
                rows: [
                    ["全部编辑、CSV、清洗、挖掘、报告", "有", "有"],
                    ["`geditor` 命令行工具", "无", "有"],
                    ["通过外部命令过滤文本", "无", "有"],
                    ["原生插件（独立进程）", "无", "有"],
                    ["自动更新", "经由 App Store", "应用内"],
                ]
            ),
            .paragraph("""
                上面每一个「无」都出自同一条规则：沙盒**禁止运行应用之外的代码**。这是上架 App \
                Store 的代价，不是疏漏。
                """),
            .note("""
                在 App Store 版里，这些命令**仍留在菜单中**并说明为何不可用，而不是消失。菜单项 \
                消失会变成一个支持问题；就地给出的答案不会。
                """),
            .heading("App Store 版的文件访问"),
            .paragraph("""
                沙盒版只能接触您自己打开或拖进来的文件。GEditor 为每个标签页和工作区文件夹保存 \
                **安全作用域书签**，因此退出后再打开，工作状态无需重新授权即可恢复。
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )
}
