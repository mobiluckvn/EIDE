import Foundation

/// 简体中文帮助内容 —— 第十一部分：宏与自动化。
extension HelpZhHans {

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "宏与自动化",
        summary: "录制操作、批量重跑、写脚本，以及从终端驱动它。",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "录制与播放宏",
        summary: "录下一串操作再重复 —— 整趟运行是一步撤销。",
        keywords: ["宏", "录制", "回放", "重复", "自动化"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "开始 / 停止录制"),
                HelpShortcut("⌃P", "回放"),
            ]),
            .steps([
                "`⌃R` 开始录制。",
                "做那件您想重复的事 —— 输入、移动光标、查找、替换。",
                "再按 `⌃R` 停止。",
                "`⌃P` 回放，或者用`宏 ▸ 播放到文档末尾`一直跑到底。",
                "`宏 ▸ 保存宏…`给它起个名字，供以后的会话使用。",
            ]),
            .heading("它录的是**命令**，不是原始按键"),
            .paragraph("""
                宏保存的是**您做了什么**，而不是您按了哪些键。因此它与键盘布局无关，与当前是哪 \
                套输入法无关，也因此宏文件打开来是**能读懂**的。
                """),
            .heading("宏什么时候停"),
            .table(
                headers: ["原因", "含义"],
                rows: [
                    ["重复次数用完", "正常"],
                    ["某个 `find` 步骤没找到", "「播放到文件末尾」就是这样自己停下的"],
                    ["到了文档末尾", "没有更远的地方可去"],
                    ["您取消了", "`宏 ▸ 取消正在运行的宏`"],
                    ["某一轮什么都没改、也没移动", "为免无限循环而停下"],
                ]
            ),
            .note("""
                整趟运行 —— 哪怕重复一万次 —— 是**一步**撤销。
                """),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "批量运行宏",
        summary: "在每个打开的标签页上跑，或者在一整个未打开文件的文件夹上跑。",
        keywords: ["批量", "所有标签页", "文件夹", "宏", "掩码"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["命令", "范围", "可撤销"],
                rows: [
                    ["在所有标签页上运行", "已打开的标签页", "可以 —— 每个标签页一步撤销"],
                    ["在整个文件夹上运行…", "磁盘上**未打开**的文件", "不可以"],
                ]
            ),
            .warning("""
                在文件夹上运行会碰到任何标签页里都没打开的文件，所以**没有撤销**。默认情况下 \
                GEditor **写出新文件**，而不是覆盖原件。除非您有备份或有版本库，否则请保留这个 \
                默认。
                """),
            .heading("用掩码筛选文件"),
            .paragraph("""
                文件夹选择器里有一个**文件名筛选框**：输 `*.csv;*.log`，宏就只碰这些。它与`在 \
                文件夹中查找`用的是同一套掩码语法，多个模式之间用 `;` 或 `,` 分隔。
                """),
            .bullets([
                "**留空**则取 GEditor 能读的每一种文本文件 —— 也就是以前的行为。",
                "掩码是**替换**那份扩展名清单，而不是在它之上再收窄：输 `*.bak`，它就在 `.bak` 文件上跑，尽管这个扩展名不在文本清单里。",
                "如果没有任何文件匹配，提示会**把您输的掩码原样念回来**，而不是去怪文件夹是空的。",
            ]),
            .paragraph("""
                这个框有一个非常实际的理由：一个文件夹里有 400 个 `.json` 和 12 个 `.log`，而您 \
                的宏只整理日志。没有掩码，那 400 个也会被处理 —— 而由于批处理会写出新文件，一次 \
                失误留下 400 份垃圾。
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "宏文件语法",
        summary: "七种步骤类型、完整的 JSON 格式，以及两个能跑的宏。",
        keywords: ["宏", "json", "语法", "格式", "手工编辑", "分享"],
        blocks: [
            .paragraph("""
                每个宏是 GEditor `macros/` 文件夹里**各自独立的一个 JSON 文件**。损坏只局限于 \
                一个宏，而分享一个宏给同事，就是发一个文件。
                """),
            .code(
                language: "text", caption: "文件放在哪里",
                source: "~/Library/Application Support/GEditor/macros/<macro-name>.json"
            ),
            .heading("七种步骤类型"),
            .table(
                headers: ["步骤", "写法", "含义"],
                rows: [
                    ["插入文本", "`{\"insert\": {\"_0\": \"text\"}}`", "在光标处输入；有选区时替换选区"],
                    ["向前删除", "`{\"deleteBackward\": {}}`", "相当于 Delete 键"],
                    ["向后删除", "`{\"deleteForward\": {}}`", "相当于 ⌦"],
                    ["移动", "`{\"move\": {\"_0\": \"nextLine\"}}`", "方向见下面的清单"],
                    ["选中本行", "`{\"selectLine\": {}}`", "不含换行符"],
                    ["查找", "`{\"find\": { … }}`", "找到并**选中**下一处"],
                    ["替换选区", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "上一步是正则 `find` 时，`$1` 可用"],
                ]
            ),
            .heading("移动方向"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("完整的 `find` 步骤"),
            .code(
                language: "json", caption: "find 步骤的四个键",
                source: """
                    {
                      "find": {
                        "pattern": "^([a-z]{2})\\\\t",
                        "mode": "regex",
                        "matchCase": false,
                        "wholeWord": false
                      }
                    }
                    """
            ),
            .paragraph("`mode` 取 `normal`、`extended` 或 `regex` —— 和搜索框的三种模式相同。"),
            .heading("例一 —— 把每行开头的省份代码转为大写"),
            .code(
                language: "json", caption: "macros/uppercase-province.json",
                source: """
                    {
                      "name": "Uppercase province code",
                      "steps": [
                        {
                          "find": {
                            "pattern": "^([a-z]{2,3})\\\\t",
                            "mode": "regex",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "replaceSelection": { "_0": "\\\\U$1\\\\E\\t" } }
                      ]
                    }
                    """
            ),
            .paragraph("""
                用`宏 ▸ 播放到文档末尾`运行：`find` 步骤再也找不到，正是它的停止条件。
                """),
            .heading("例二 —— 删掉每个含 TODO 的行后面那一行"),
            .code(
                language: "json", caption: "macros/delete-line-after-todo.json",
                source: """
                    {
                      "name": "Delete line after TODO",
                      "steps": [
                        {
                          "find": {
                            "pattern": "TODO",
                            "mode": "normal",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "move": { "_0": "nextLine" } },
                        { "move": { "_0": "lineStart" } },
                        { "selectLine": {} },
                        { "deleteForward": {} },
                        { "deleteForward": {} }
                      ]
                    }
                    """
            ),
            .warning("""
                手工改过的宏请先在副本上试。写错的 `find` 步骤会让宏立刻停下 —— 那是好的情形。 \
                坏的情形是一个匹配范围比您以为的宽得多的模式，在一步撤销之内改掉了几千处。
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript 脚本",
        summary: "四个函数、一个 `.js` 文件，它做的一切都是一步撤销。",
        keywords: ["脚本", "javascript", "js", "自动化", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                把一个 `.js` 文件放进 GEditor 的 `scripts/` 文件夹，再从`宏 ▸ 脚本…`运行。脚本 \
                只能看到**四**样东西：
                """),
            .table(
                headers: ["调用", "含义"],
                rows: [
                    ["`doc.text`", "整份文档的文本"],
                    ["`doc.selection`", "选区（什么都没选时是空字符串）"],
                    ["`doc.replace(s)`", "用 `s` 替换**整份文档** —— 一步撤销"],
                    ["`doc.log(s)`", "往结果面板写一行"],
                ]
            ),
            .code(
                language: "javascript", caption: "scripts/number-lines.js",
                source: """
                    // 给每一行编号。
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """
            ),
            .code(
                language: "javascript", caption: "scripts/keep-three-columns.js —— 只留 CSV 的前三列",
                source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """
            ),
            .heading("要知道的三条限制"),
            .bullets([
                "**不能访问文件、不能联网、不能启动进程。** API 面是有意收窄的：以后放宽很容易，收窄则会毁掉用户已经写好的每一个脚本。",
                "**这不是一道安全边界。** 脚本跑在同一个进程里。不要运行您没读过的脚本。",
                "**有五秒的限制。** 超过之后您会收到提示，应用仍然可用 —— 但那个脚本的线程会**一直空转到您退出为止**，吃掉一个核。提示里写明了这一点。",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "通过外部命令过滤",
        summary: "把选区管道给一个 Unix 命令，再把结果拿回来。",
        keywords: ["过滤", "外部命令", "shell", "管道", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                选区（或整份文档）被喂给某个命令的 `stdin`，而该命令的 `stdout` 替换掉它。
                """),
            .code(
                language: "bash", caption: "几个常用的",
                source: """
                    sort -u                     # 排序并去重
                    jq .                        # 重新格式化 JSON
                    tr 'a-z' 'A-Z'              # 转大写
                    grep -v '^#'                # 去掉注释行
                    awk -F, '{print $3","$1}'   # 调换列顺序
                    """
            ),
            .note("""
                结果是**一步**撤销。如果命令返回错误码，GEditor 会原样保留文本并显示 `stderr`。
                """),
            .warning("""
                这条命令**只存在于直接下载版**。App Sandbox 禁止运行应用之外的代码，所以在 \
                App Store 版里这个菜单项仍在，并说明为何不可用。
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "`geditor` 命令行工具",
        summary: "打开、清洗、查询、评分、渲染报告 —— 不必打开应用。",
        keywords: ["cli", "命令行", "终端", "geditor", "脚本", "ci"],
        blocks: [
            .warning("""
                只在**直接下载版**里可用。App Store 版跑在沙盒里，外部的命令行进程连不上它。
                """),
            .heading("打开文件"),
            .code(
                language: "bash", caption: "打开、跳到某个位置、从管道读入",
                source: """
                    geditor report.csv
                    geditor report.csv:120:5       # 第 120 行第 5 列
                    geditor -w notes.md            # 等文件关闭后再退出
                    geditor -r app.log             # 以只读方式打开
                    git diff | geditor             # 把标准输入读进一个新标签页
                    """
            ),
            .table(
                headers: ["选项", "含义"],
                rows: [
                    ["`-w`, `--wait`", "等文件关闭后再退出 —— 供作 `git` 的编辑器使用"],
                    ["`-n`, `--new-window`", "在新窗口里打开"],
                    ["`-r`, `--read-only`", "以只读方式打开"],
                    ["`-i`, `--info`", "打印编码、换行方式和行数后退出 —— **不**打开应用"],
                    ["`-h`, `--help`", "显示帮助"],
                    ["`-v`, `--version`", "显示版本"],
                ]
            ),
            .heading("不打开应用也能跑"),
            .paragraph("""
                下面这四组命令**完全在命令行进程里**运行，因此在没人登录图形会话的 CI 里也能用。
                """),
            .code(
                language: "bash", caption: "用配方清洗",
                source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """
            ),
            .code(
                language: "bash", caption: "查询",
                source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """
            ),
            .code(
                language: "bash", caption: "质量关卡 —— 退出码 0 通过 · 1 不通过 · 2 错误",
                source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """
            ),
            .code(
                language: "bash", caption: "渲染报告",
                source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"
            ),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript 与「服务」菜单",
        summary: "用 AppleScript 读写文档，或从别的应用把文字送进 GEditor。",
        keywords: ["applescript", "osascript", "服务", "自动化", "快捷指令"],
        blocks: [
            .code(
                language: "applescript", caption: "读取打开的文档",
                source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """
            ),
            .code(
                language: "applescript", caption: "覆盖内容，以及读取选区",
                source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """
            ),
            .code(
                language: "applescript", caption: "打开一个文件",
                source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """
            ),
            .heading("「服务」菜单"),
            .paragraph("""
                在任意应用里选中文字，然后用`服务`菜单把它作为新标签页送进 GEditor。
                """),
            .note("""
                第一次运行 AppleScript 时，macOS 会索取「自动化」权限。那是系统的对话框，不是 \
                GEditor 的。
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "扩展包与插件",
        summary: "两类扩展，以及各自能在哪个版本里跑。",
        keywords: ["插件", "扩展", "扩展包", "原生"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("扩展包"),
            .paragraph("""
                一个扩展包是**一个 JSON 文件**，把主题、脚本和自定义语言打包在一起。安装是拷一个 \
                文件，卸载是删一个文件 —— 而扩展包清单是从**磁盘**推导出来的，不是来自某个可能 \
                说谎的注册表。
                """),
            .paragraph("**两个版本都可用。**"),
            .heading("原生插件"),
            .paragraph("""
                预编译的插件跑在**独立进程**里，API 面很窄 —— 插件崩溃不会把应用一起带走。
                """),
            .warning("""
                原生插件**只存在于直接下载版**，因为 App Sandbox 禁止从应用之外加载代码。每个 \
                插件在运行之前，都必须按哈希**手工批准一次**。
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )
}
