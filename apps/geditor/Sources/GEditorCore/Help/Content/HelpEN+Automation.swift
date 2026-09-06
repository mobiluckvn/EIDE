import Foundation

extension HelpEN {

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Macros and automation",
        summary: "Record actions, run them in bulk, write scripts, and drive it from the shell.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    // MARK: - Macro basics

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Recording and playing macros",
        summary: "Record a sequence and repeat it — the whole run is one undo step.",
        keywords: ["macro", "record", "playback", "repeat", "automate"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Start / stop recording"),
                HelpShortcut("⌃P", "Play back"),
            ]),
            .steps([
                "`⌃R` starts recording.",
                "Do the thing you want repeated — type, move the caret, find, replace.",
                "`⌃R` again to stop.",
                "`⌃P` plays it back, or `Macro ▸ Play to end of document` runs it to the end.",
                "`Macro ▸ Save macro…` names it for later sessions.",
            ]),
            .heading("It records COMMANDS, not raw keystrokes"),
            .paragraph("""
                A macro stores **what you did**, not which keys you pressed. That makes it \
                independent of keyboard layout and of whichever input method is active, and it \
                makes the macro file **readable** when you open it.
                """),
            .heading("When a macro stops"),
            .table(
                headers: ["Reason", "Meaning"],
                rows: [
                    ["The repeat count ran out", "Normal"],
                    ["A `find` step found nothing", "This is how \"play to end of file\" stops itself"],
                    ["Reached the end of the document", "Nowhere further to go"],
                    ["You cancelled", "`Macro ▸ Cancel running macro`"],
                    ["An iteration changed nothing and moved nowhere", "Stopped so it cannot loop forever"],
                ]
            ),
            .note("""
                The entire run — even ten thousand repetitions — is **one** undo step.
                """),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    // MARK: - Batch

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Running a macro in bulk",
        summary: "Across every open tab, or across a folder of unopened files.",
        keywords: ["batch", "all tabs", "folder", "macro", "mask"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Command", "Scope", "Undoable"],
                rows: [
                    ["Run on all tabs", "The open tabs", "Yes — one undo step per tab"],
                    ["Run across a folder…", "Files **not open** on disk", "No"],
                ]
            ),
            .warning("""
                Running across a folder touches files that are not open in any tab, so there is **no \
                undo**. By default GEditor **writes new files** rather than overwriting the \
                originals. Keep that default unless you have a backup or a version-controlled \
                repository.
                """),
            .heading("Filtering files with a mask"),
            .paragraph("""
                The folder chooser has a **file-name filter**: type `*.csv;*.log` and the macro only \
                touches those. It is the same mask syntax `Find across a folder` uses, and several \
                patterns are separated by `;` or `,`.
                """),
            .bullets([
                "Leave it **empty** and it takes every text file GEditor can read — the previous behaviour.",
                "The mask **replaces** that extension list rather than narrowing it further: type `*.bak` and it runs on `.bak` files, even though that extension is not in the text list.",
                "If nothing matches, the message **repeats the mask back to you** rather than blaming an empty folder.",
            ]),
            .paragraph("""
                This box has a very practical reason: a folder holds 400 `.json` files and 12 `.log` \
                files, and your macro only tidies logs. Without a mask the other 400 get processed \
                too — and since the batch writes new files, a mistake leaves 400 pieces of litter.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    // MARK: - Macro syntax

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Macro file syntax",
        summary: "Seven step types, the complete JSON format, and two macros that run.",
        keywords: ["macro", "json", "syntax", "format", "hand-edit", "share"],
        blocks: [
            .paragraph("""
                Each macro is **its own JSON file** in GEditor's `macros/` folder. Corruption stays \
                confined to one macro, and sharing one with a colleague means sending one file.
                """),
            .code(
                language: "text",
                caption: "Where the files live",
                source: """
                    ~/Library/Application Support/GEditor/macros/<macro-name>.json
                    """
            ),
            .heading("The seven step types"),
            .table(
                headers: ["Step", "Written as", "Meaning"],
                rows: [
                    ["Insert text", "`{\"insert\": {\"_0\": \"text\"}}`", "Type at the caret; with a selection, replaces it"],
                    ["Delete backward", "`{\"deleteBackward\": {}}`", "Like the Delete key"],
                    ["Delete forward", "`{\"deleteForward\": {}}`", "Like ⌦"],
                    ["Move", "`{\"move\": {\"_0\": \"nextLine\"}}`", "See the direction list below"],
                    ["Select the line", "`{\"selectLine\": {}}`", "Excluding the newline"],
                    ["Find", "`{\"find\": { … }}`", "Find and **select** the next match"],
                    ["Replace the selection", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` works when the previous step was a regex `find`"],
                ]
            ),
            .heading("Movement directions"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("The full `find` step"),
            .code(
                language: "json",
                caption: "The four keys of a find step",
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
            .paragraph("`mode` takes `normal`, `extended` or `regex` — the same three modes as the search box."),
            .heading("Example 1 — uppercase the province code at the start of each line"),
            .code(
                language: "json",
                caption: "macros/uppercase-province.json",
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
                Run it with `Macro ▸ Play to end of document`: the `find` step finding nothing more \
                is exactly the stopping condition.
                """),
            .heading("Example 2 — delete the line following every line containing TODO"),
            .code(
                language: "json",
                caption: "macros/delete-line-after-todo.json",
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
                Test a hand-edited macro on a copy first. A mistyped `find` step makes the macro stop \
                immediately — that is the benign case. The malign case is a pattern that matches more \
                widely than you thought, editing thousands of places inside one undo step.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    // MARK: - Scripting

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript scripts",
        summary: "Four functions, one `.js` file, and everything it does is one undo step.",
        keywords: ["script", "javascript", "js", "automate", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Put a `.js` file in GEditor's `scripts/` folder and run it from `Macro ▸ Script…`. A \
                script sees exactly **four** things:
                """),
            .table(
                headers: ["Call", "Meaning"],
                rows: [
                    ["`doc.text`", "The whole document text"],
                    ["`doc.selection`", "The selection (an empty string when nothing is selected)"],
                    ["`doc.replace(s)`", "Replace the **whole document** with `s` — one undo step"],
                    ["`doc.log(s)`", "Write a line to the results panel"],
                ]
            ),
            .code(
                language: "javascript",
                caption: "scripts/number-lines.js",
                source: """
                    // Number every line.
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
                language: "javascript",
                caption: "scripts/keep-three-columns.js — keep the first three CSV columns",
                source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """
            ),
            .heading("Three limits to know"),
            .bullets([
                "**No file access, no network, no spawning processes.** The API surface is deliberately narrow: widening it later is easy, narrowing it breaks every script users have written.",
                "**This is not a security boundary.** Scripts run in the same process. Do not run a script you have not read.",
                "**There is a five-second limit.** Past it you get a message and the app stays usable — but that script's thread **keeps spinning until you quit**, eating a core. The message says so.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    // MARK: - External filter

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filtering through an external command",
        summary: "Pipe the selection through a Unix command and take the result back.",
        keywords: ["filter", "external command", "shell", "pipe", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                The selection (or the whole document) is fed to a command's `stdin`, and that \
                command's `stdout` replaces it.
                """),
            .code(
                language: "bash",
                caption: "A few common ones",
                source: """
                    sort -u                     # sort and drop duplicates
                    jq .                        # reformat JSON
                    tr 'a-z' 'A-Z'              # uppercase
                    grep -v '^#'                # drop comment lines
                    awk -F, '{print $3","$1}'   # swap column order
                    """
            ),
            .note("""
                The result is **one** undo step. If the command returns an error code, GEditor leaves \
                the text alone and shows `stderr`.
                """),
            .warning("""
                This command exists **only in the direct-download build**. App Sandbox forbids \
                running code outside the app, so in the App Store build the menu item remains and \
                explains why it is unavailable.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    // MARK: - CLI

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "The `geditor` command-line tool",
        summary: "Open, clean, query, score and render reports — without opening the app.",
        keywords: ["cli", "command line", "terminal", "geditor", "script", "ci"],
        blocks: [
            .warning("""
                Available only in the **direct-download build**. The App Store build runs in a \
                sandbox, so an external command-line process cannot connect to it.
                """),
            .heading("Opening files"),
            .code(
                language: "bash",
                caption: "Open, jump to a position, read from a pipe",
                source: """
                    geditor report.csv
                    geditor report.csv:120:5       # line 120, column 5
                    geditor -w notes.md            # wait until the file is closed before exiting
                    geditor -r app.log             # open read-only
                    git diff | geditor             # read stdin into a new tab
                    """
            ),
            .table(
                headers: ["Option", "Meaning"],
                rows: [
                    ["`-w`, `--wait`", "Wait until the file is closed before exiting — for use as `git`'s editor"],
                    ["`-n`, `--new-window`", "Open in a new window"],
                    ["`-r`, `--read-only`", "Open read-only"],
                    ["`-i`, `--info`", "Print encoding, line endings and line count, then exit — **without** opening the app"],
                    ["`-h`, `--help`", "Show help"],
                    ["`-v`, `--version`", "Show the version"],
                ]
            ),
            .heading("Running without opening the app"),
            .paragraph("""
                The four command groups below run **entirely in the command-line process**, so they \
                work in CI where nobody is logged into a graphical session.
                """),
            .code(
                language: "bash",
                caption: "Cleaning with a recipe",
                source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "Querying",
                source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "The quality gate — exit code 0 pass · 1 fail · 2 error",
                source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "Rendering reports",
                source: """
                    geditor --report template.greport.md --param-list list.csv --out ./reports/
                    """
            ),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    // MARK: - AppleScript

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript and the Services menu",
        summary: "Read and write the document from AppleScript, or send text to GEditor from another app.",
        keywords: ["applescript", "osascript", "services", "automation", "shortcuts"],
        blocks: [
            .code(
                language: "applescript",
                caption: "Read the open document",
                source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "Write over the contents, and read the selection",
                source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "Open a file",
                source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """
            ),
            .heading("The Services menu"),
            .paragraph("""
                Select text in any application, then use the `Services` menu to send it to GEditor \
                as a new tab.
                """),
            .note("""
                The first time you run AppleScript, macOS asks for Automation permission. That is \
                the system's dialog, not GEditor's.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    // MARK: - Plugins

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Extension packages and plug-ins",
        summary: "Two kinds of extension, and which build each runs in.",
        keywords: ["plugin", "extension", "package", "native"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Extension packages"),
            .paragraph("""
                A package is **one JSON file** bundling a theme, scripts and user-defined languages \
                together. Installing copies a file, removing deletes one — and the package list is \
                derived from **disk**, not from a registry that could lie.
                """),
            .paragraph("Works in **both builds**."),
            .heading("Native plug-ins"),
            .paragraph("""
                Precompiled plug-ins run in a **separate process** with a narrow API surface — a \
                crashing plug-in does not take the app with it.
                """),
            .warning("""
                Native plug-ins exist **only in the direct-download build**, because App Sandbox \
                forbids loading code from outside the app. Each plug-in must be **approved by hand \
                once**, by hash, before it will run.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )
}
