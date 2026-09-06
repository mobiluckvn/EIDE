import Foundation

/// 简体中文帮助内容 —— 第十二部分：配置与应用本身。
extension HelpZhHans {

    static let application = HelpChapter(
        id: "ung-dung",
        title: "配置与应用",
        summary: "设置、快捷键、主题、更新、从 Notepad++ 迁移、疑难排解。",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "设置",
        summary: "所有选项都在一个人能读懂的 JSON 文件里，可以拷到另一台 Mac。",
        keywords: ["设置", "偏好", "选项", "配置", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "打开设置")]),
            .paragraph("""
                没有「好」和「取消」—— 改动即刻生效并立即写入，这是 macOS 的做法。
                """),
            .heading("配置文件"),
            .code(
                language: "text", caption: "它在哪里",
                source: "~/Library/Application Support/GEditor/settings.json"
            ),
            .paragraph("""
                它是一个**缩进过、您能读也能手工改的 JSON 文件**。把它拷到另一台 Mac，整套配置 \
                就跟着走。设置里的`打开配置文件`按钮会把您直接带过去。
                """),
            .heading("各个键"),
            .table(
                headers: ["键", "默认", "含义"],
                rows: [
                    ["`fontSize`", "`13`", "编辑器字号"],
                    ["`tabWidth`", "`4`", "一个 TAB 有多少列宽"],
                    ["`usesTabsForIndent`", "`false`", "用 TAB 而不是空格缩进"],
                    ["`languageIndent`", "`{}`", "按语言分设的缩进 —— 见空白与缩进那一页"],
                    ["`smartIndent`", "`true`", "换行时自动缩进"],
                    ["`highlightAllMatches`", "`true`", "高亮每一处搜索命中"],
                    ["`ligatures`", "`false`", "连字 —— 见表下方的说明"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "保存时去掉行尾空白"],
                    ["`normalizeToNFCOnSave`", "`false`", "保存时把 Unicode 规范化为 NFC"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "新文件的编码"],
                    ["`defaultEOL`", "`\"lf\"`", "新文件的换行方式"],
                    ["`language`", "`\"system\"`", "界面语言"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "默认主题", "正在使用的颜色主题"],
                    ["`showWelcomeOnLaunch`", "`true`", "启动时打开欢迎窗口"],
                    ["`keyBindings`", "`{}`", "只记录您改动过的那些键"],
                ]
            ),
            .note("""
                **为什么连字默认关闭。** 连字会把 `!=` 或 `->` 合成**一个**字形，于是屏幕上您看到 \
                的字符不再对应文件里的字符 —— 而列编辑器、列模式和按列换行都是按列来量的。写散文 \
                时，或者您正是为了连字才选了某款编程字体（Fira Code、JetBrains Mono）时，再把它 \
                打开。
                """),
            .heading("旁边的几个文件夹"),
            .table(
                headers: ["文件夹", "放什么"],
                rows: [
                    ["`macros/`", "保存的宏，一个宏一个 JSON 文件"],
                    ["`scripts/`", "JavaScript 脚本"],
                    ["`themes/`", "颜色主题"],
                    ["`grammars/`", "自定义语言"],
                ]
            ),
            .warning("""
                由**更新**版本的 GEditor 写下的配置文件，**不会被**旧版本覆盖 —— 旧版本会用 \
                默认值运行并说明这一点。覆盖是毁掉一个人两台机器同步配置的最可靠办法，而他们 \
                永远也不会知道为什么。
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "状态栏",
        summary: "底部的十个分段 —— 每一段都读得懂，每一段都点得动。",
        keywords: ["状态栏", "底栏", "偏移", "位置", "编码", "tab", "只读", "文件大小"],
        blocks: [
            .paragraph("""
                这是与别家编辑器状态栏最大的不同：**没有一段是只读的**。看见一个值不对，点它就是 \
                改法，不必去菜单里翻。
                """),
            .table(
                headers: ["分段", "告诉您", "点它"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "光标位置 —— 列按**字符**计，`@340` 是字节位置",
                     "打开`跳转`框"],
                    ["`11 byte · 3 dòng`", "文档大小",
                     "统计字节 · 字符 · 单词 · 行"],
                    ["`🔒 Chỉ đọc`", "仅在文档被锁定时显示",
                     "说明**为什么**锁着，并在可能时解锁"],
                    ["`View` / `Code`", "您在哪个视图", "切换（⌥⌘V）"],
                    ["`CSV · dấu phẩy`", "CSV 模式和正在用的分隔符",
                     "开关 CSV 模式，或**重新挑分隔符**"],
                    ["`Đang theo dõi`", "`tail -f` 正在运行", "—"],
                    ["`UTF-8`", "编码", "重新解释，或转换成另一种编码"],
                    ["`LF`", "换行方式", "在 LF · CRLF · CR 之间切换"],
                    ["`Python`", "语法着色所用的语言", "换一种，或回到按扩展名判断"],
                    ["`Tab: 4`", "缩进宽度", "2 · 4 · 8，全局或**只对这门语言**"],
                    ["`Ngắt: tắt`", "软换行模式", "在三种模式之间轮换"],
                ]
            ),
            .heading("三段值得多看一眼"),
            .bullets([
                "**`@340` —— 字节位置。** 这是产品里其他每一件工具说的那个数：JSON 和 XML 的报错、`--doc-sweep` 的输出、二进制查看器，以及 `跳转 @340` 那个框。在这里读到，在那里输入。",
                "**列号上的 `~`** 表示这个数在数**字节**而不是可视列 —— 它只出现在超过 200 KB 的行上，那里逐字符计数会拖慢每一次光标移动。",
                "**`CSV · …` 点得动，可以重挑分隔符。** 识别可能出错，一旦出错，每一项列操作都是歪的，却没有任何信号。这就是您纠正它的地方 —— 它只**重读**文件，一个字节都不改（不同于 `CSV ▸ 更改分隔符…`，那个会重写文件）。",
            ]),
            .note("""
                与当前文件无关的分段是**隐藏**的，不是置灰：`只读`只在文档确实被锁时出现， \
                `CSV · …` 只在 CSV 模式下出现。
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "更改键盘快捷键",
        summary: "逐个改键，或者整套采用 Notepad++ 的键位。",
        keywords: ["快捷键", "键位", "keymap", "预设"],
        blocks: [
            .paragraph("""
                `设置…`里有一个快捷键区，带两个快捷按钮：**采用 Notepad++ 预设**和**恢复默认**。
                """),
            .paragraph("""
                配置文件只记录您**相对默认改动过**的部分。这样，当 GEditor 在新版本里改了某个 \
                默认键时，您不会在无人告知的情况下被卡在旧键位上。
                """),
            .note("""
                两条命令不能共用一个快捷键。一旦共用，AppKit 会悄悄只触发**第一个**菜单项，另一 \
                条命令看起来就像坏了 —— 所以 GEditor 有一道检查来阻止这种情况。
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "主题、浅色与深色",
        summary: "跟随系统、浅色或深色；主题是一个您可以编辑的 JSON 文件。",
        keywords: ["主题", "配色", "深色模式", "浅色", "外观"],
        blocks: [
            .paragraph("""
                `设置…`里可选`跟随系统`、`浅色`或`深色`，并挑选一套颜色主题。
                """),
            .paragraph("""
                一套主题就是 `themes/` 里的一个 JSON 文件。`导出当前主题`按钮会写出一份，作为您 \
                自制主题的起点。
                """),
            .note("""
                主题文件里写错的颜色会回退到**默认主题的**那个颜色，而不是黑色。黑色看起来像是 \
                一个设计决定，用户会跑到别处去找问题。
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "更新、版本与退出",
        summary: "两个发行版本更新方式的不同。",
        keywords: ["更新", "版本", "关于", "退出"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["版本", "更新途径"],
                rows: [
                    ["App Store", "经由 App Store，和其他应用一样"],
                    ["直接下载", "应用内的`检查更新…`"],
                ]
            ),
            .paragraph("""
                `关于 GEditor` 显示正在运行的版本以及它属于哪个发行版 —— 报告问题时用得上。
                """),
            .note("""
                在 App Store 版里，`检查更新…` **仍留在菜单中**并说明为何不适用，而不是消失。 \
                消失的菜单项会变成一个支持问题。
                """),
            .paragraph("""
                退出不会丢失工作：下次打开时会话会回来。
                """),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "使用这个帮助窗口",
        summary: "搜索这本书、切换它的语言，以及把欢迎窗口找回来。",
        keywords: ["帮助", "指南", "搜索", "欢迎", "语言"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "打开帮助窗口")]),
            .bullets([
                "左上角的搜索框会搜**正文和示例代码** —— 直接输入像 `fail_under` 这样的配置键名就能落到正确的页面。",
                "**不打声调**也能找到带声调的字。",
                "`返回`按钮回到上一页。",
                "每个代码块上的`复制`按钮复制该块。",
            ]),
            .heading("换一种语言阅读"),
            .paragraph("""
                本窗口右上角的弹出菜单选择**这本书的语言**，与应用的界面语言无关。切换时您会 \
                **停留在正在读的那一页** —— 页面 id 有意不翻译，正是为了让这件事成立。
                """),
            .note("""
                只有真正有书的语言才会列出来。一个切换过去却什么都没变的菜单项，是一个会说谎的 \
                菜单项。
                """),
            .heading("把欢迎窗口找回来"),
            .paragraph("""
                如果您勾了**启动时不再打开此窗口**，用`帮助 ▸ 功能导览`重新打开它 —— 窗口底部 \
                那个复选框会重新出现，可以取消勾选。
                """),
            .paragraph("""
                或者在 `settings.json` 里把 `showWelcomeOnLaunch` 改回 `true`。
                """),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "从 Notepad++ 到 GEditor",
        summary: "哪些键互换了位置、哪些地方做法不同、缺了什么。",
        keywords: ["notepad++", "notepad", "迁移", "windows", "转过来", "快捷键"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                在 macOS 上，有几个键是**互换了位置**，而不只是把 `Ctrl` 换成 `⌘`。下面是对照。
                """),
            .table(
                headers: ["Notepad++", "GEditor", "为什么"],
                rows: [
                    ["`Ctrl+D` 复制行", "**⇧⌘D**", "这里 `⌘D` 是多光标，和每一款 Mac 编辑器一样"],
                    ["`Ctrl+L` 删除行", "**⌘K**", "在 macOS 上 `⌘L` 的意思是「跳到某行」"],
                    ["`Ctrl+G` 跳到某行", "**⌘L**", "这两个互换了位置"],
                    ["`Ctrl+Q` 注释", "**⌘/**", "macOS 惯例"],
                    ["`Ctrl+Shift+↑/↓` 移动行", "**⌥↑ / ⌥↓**", "在 macOS 上 `⌃` 归调度中心所有"],
                    ["`F3` 查找下一个", "**⌘G**", "macOS 惯例"],
                    ["`Ctrl+F2` 切换书签", "**⌘F2**", "F2 和 ⇧F2 仍然在标记之间跳"],
                    ["`Alt` + 拖动选列", "**⌥ + 拖动**", "完全一样"],
                    ["`Ctrl+Alt+Shift+↓` 列编辑器", "**⌥⌘C**", "macOS 惯例"],
                ]
            ),
            .note("""
                不想重新学？`设置 ▸ 快捷键 ▸ 采用 Notepad++ 预设`。
                """),
            .heading("Notepad++ 里有、但这里做法不同的东西"),
            .bullets([
                "**会话**自己恢复，包括未保存的标签页 —— 不用开任何开关。",
                "**书签有九种颜色**，一行还能同时带好几个。",
                "**文档地图**描述的是*整个*文件，不只是看得见的部分。",
                "**宏**能「播放到文档末尾」和「在所有标签页上跑」，而整趟运行是一步撤销。",
            ]),
            .heading("GEditor 多出来的东西"),
            .bullets([
                "针对 CSV 文件的**数据清洗台**和**数据画像**。",
                "直接对 CSV 文件跑的 **SQL 查询**。",
                "**越南语旧编码** —— TCVN3、VISCII、VNI-Windows，能读、能写、能自动识别。",
                "每个筛选框里的**忽略声调搜索**。",
                "带可重跑表格与图表的 **`.greport.md` 报告**。",
                "直接下载版里的 **`geditor` 命令行工具**。",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "常见问题",
        summary: "六种让人以为应用坏了的情形。",
        keywords: ["错误", "问题", "用不了", "坏了", "排查", "为什么"],
        blocks: [
            .table(
                headers: ["现象", "通常的原因"],
                rows: [
                    ["越南语文字显示为乱码", "编码不对 —— 点状态栏上的编码"],
                    ["搜带声调的字什么也搜不到", "文件是分解式 Unicode —— 运行`规范化 Unicode`到 NFC"],
                    ["某个菜单项是灰的", "App Store 版跑不了那条命令 —— 那一项会说明原因"],
                    ["括号匹配拒绝运行", "文档超过 1 MB —— 高亮错的一对比不高亮更糟"],
                    ["状态栏上的列号带 `~`", "文档超过 200 KB，所以那是字节数，不是可视列"],
                    ["SQL 查询说必须先保存文件", "DuckDB 读的是**文件**，不是您正在编辑的缓冲区"],
                ]
            ),
            .heading("当 GEditor 意外退出"),
            .paragraph("""
                下次启动时会有一条横幅说明，并带一个**打开报告**按钮 —— 报告会作为一个标签页 \
                打开，像任何文本文件一样能读、能复制。
                """),
            .bullets([
                "报告里只有**版本、macOS 版本、机器架构、信号名和调用栈**。",
                "**没有文档内容，也没有文件路径** —— 像 `~/Desktop/salary-december.xlsx` 这样一条路径，在谁打开它之前就已经泄露了三件私事。",
                "**什么都不会被发出去。** 没有自动上传，也没有接收它的服务器；文件就留在 `~/Library/Application Support/GEditor/crash/`，直到您打开或删掉它。",
                "报告一旦被您打开过，下次启动就不会再提。",
            ]),
            .heading("接下来去哪里看"),
            .bullets([
                "状态栏显示编码、换行方式、语言和换行模式 —— 每一段都点得动。",
                "设置窗口不够用时，`settings.json` 可以手工编辑。",
                "`关于 GEditor` 给出版本和发行版，报缺陷时需要这两样。",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
