import Foundation

extension HelpEN {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Search",
        summary: "Find, replace, regular expressions, folder-wide search, and line marks.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    // MARK: - Find and replace

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Find and replace",
        summary: "Three search modes, and why ^ means start of LINE by default.",
        keywords: ["find", "replace", "search", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Find"),
                HelpShortcut("⌥⌘F", "Find and replace"),
                HelpShortcut("⌘G / ⇧⌘G", "Next / previous match"),
            ]),
            .heading("Three modes"),
            .table(
                headers: ["Mode", "Understands", "Use for"],
                rows: [
                    ["Normal", "Plain text, no special characters at all", "Most searches"],
                    ["Extended", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Finding newlines, TABs, specific bytes"],
                    ["Regex", "Full PCRE2", "Matching by pattern"],
                ]
            ),
            .note("""
                **Extended** mode does not understand regex syntax. It only expands a few escape \
                sequences — so searching `a.b` there finds exactly those three characters; the \
                dot is not a wildcard.
                """),
            .heading("Two switches"),
            .bullets([
                "**Match case** — off by default.",
                "**Whole word** — matches only when both ends are word boundaries.",
            ]),
            .heading("`^` and `$` match at each LINE's edges"),
            .paragraph("""
                On by default. People coming from Notepad++ expect `^` to mean \"start of line\"; \
                with it off, `^abc` would match only if the whole document began with `abc` — \
                almost nobody wants that in a text editor.
                """),
            .heading("A bad expression will not hang the app"),
            .paragraph("""
                The engine is **PCRE2 with JIT compilation**, and it has a backtracking budget. A \
                pattern that explodes combinatorially is stopped and reported, rather than \
                freezing the window.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    // MARK: - Regex

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Regular expressions",
        summary: "The PCRE2 syntax you actually use, with examples that run on Vietnamese data.",
        keywords: ["regex", "regexp", "pcre", "pattern"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor uses **PCRE2**, the same engine as PHP and many command-line tools. Open \
                `Search ▸ Test regular expression…` to try a pattern against sample text and see \
                what each group captures **before** applying it to a real document.
                """),
            .heading("Character classes"),
            .table(
                headers: ["Write", "Matches"],
                rows: [
                    ["`.`", "Any character except a newline"],
                    ["`\\d` · `\\D`", "A digit · not a digit"],
                    ["`\\w` · `\\W`", "A word character (letter, digit, `_`) · the opposite"],
                    ["`\\s` · `\\S`", "Whitespace · not whitespace"],
                    ["`[abc]`", "One of the characters in the brackets"],
                    ["`[^abc]`", "One character NOT in the brackets"],
                    ["`[a-z]`", "One character in the range"],
                ]
            ),
            .heading("Repetition"),
            .table(
                headers: ["Write", "Meaning"],
                rows: [
                    ["`*`", "Zero or more"],
                    ["`+`", "One or more"],
                    ["`?`", "Zero or one"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Exactly 3 · between 2 and 5 · 2 or more"],
                    ["`*?` `+?` `??`", "The **lazy** forms — take as little as possible"],
                ]
            ),
            .warning("""
                `.*` is **greedy**: it eats to the end of the line and then backs off. When \
                splitting fields inside a line you almost always need `.*?` or a narrow character \
                class such as `[^,]*`.
                """),
            .heading("Anchors and groups"),
            .table(
                headers: ["Write", "Meaning"],
                rows: [
                    ["`^` · `$`", "Start of line · end of line"],
                    ["`\\b`", "Word boundary"],
                    ["`(…)`", "A **capturing** group — reusable in the replacement"],
                    ["`(?:…)`", "Non-capturing group"],
                    ["`(?<name>…)`", "Named group"],
                    ["`a|b`", "a or b"],
                    ["`(?=…)` · `(?!…)`", "Lookahead: must follow · must not follow"],
                    ["`(?<=…)` · `(?<!…)`", "Lookbehind: must precede · must not precede"],
                ]
            ),
            .heading("Examples that run"),
            .code(
                language: "regex",
                caption: "Every 10-digit Vietnamese phone number",
                source: """
                    \\b0\\d{9}\\b
                    """
            ),
            .code(
                language: "regex",
                caption: "Split a date like 31/12/2026 into three groups",
                source: """
                    (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    """
            ),
            .code(
                language: "regex",
                caption: "The third cell of a simple CSV row (no quoting)",
                source: """
                    ^[^,]*,[^,]*,([^,]*)
                    """
            ),
            .code(
                language: "regex",
                caption: "Log lines at ERROR or FATAL, with their timestamp",
                source: """
                    ^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b
                    """
            ),
            .code(
                language: "regex",
                caption: "Blank lines, or lines holding only whitespace",
                source: """
                    ^\\s*$
                    """
            ),
            .code(
                language: "regex",
                caption: "Accented Vietnamese letters — use the Unicode class, do not list them",
                source: """
                    \\p{L}+
                    """
            ),
            .note("""
                `\\p{L}` means \"any Unicode letter\", so it matches `ế` and `đ` too. Listing every \
                accented vowel by hand is a guaranteed way to miss some.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    // MARK: - Replacement strings

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Replacement strings",
        summary: "Reuse captured groups, and change case while replacing.",
        keywords: ["replace", "backreference", "group", "$1", "\\U"],
        blocks: [
            .heading("Calling back a captured group"),
            .table(
                headers: ["Write", "Meaning"],
                rows: [
                    ["`$1` … `$9`", "The contents of group n"],
                    ["`${1}`", "The same, with explicit bounds — use it when a digit follows"],
                    ["`\\1`", "Also accepted; GEditor rewrites it as `${1}`"],
                    ["`$0`", "The entire match"],
                ]
            ),
            .note("""
                Write `${1}` rather than `$1` when the next character is a digit. `$123` reads as \
                group 123; `${1}23` is group 1 followed by two digits.
                """),
            .heading("Changing case during a replacement"),
            .table(
                headers: ["Write", "Meaning"],
                rows: [
                    ["`\\U`", "UPPERCASE from here on"],
                    ["`\\L`", "lowercase from here on"],
                    ["`\\u`", "Only the next character uppercase"],
                    ["`\\l`", "Only the next character lowercase"],
                    ["`\\E`", "End the `\\U` or `\\L` region"],
                ]
            ),
            .heading("Examples"),
            .code(
                language: "text",
                caption: "Turn 31/12/2026 into 2026-12-31",
                source: """
                    Find:    (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Replace: $3-$2-$1
                    """
            ),
            .code(
                language: "text",
                caption: "Uppercase the province code at the start of each line, keep the rest",
                source: """
                    Find:    ^([a-z]{2,3})(\\s)
                    Replace: \\U$1\\E$2
                    """
            ),
            .code(
                language: "text",
                caption: "Wrap each line as a JSON string",
                source: """
                    Find:    ^(.+)$
                    Replace: "$1",
                    """
            ),
            .paragraph("""
                A group that **did not take part** in the match becomes an empty string, not an \
                error — so a pattern with alternatives like `(a)|(b)` still replaces cleanly \
                without writing it twice.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    // MARK: - Find in files

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Find and replace across a folder",
        summary: "Scan many files at once, and see the results before anything is written.",
        keywords: ["find in files", "grep", "bulk replace", "folder"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⇧⌘F", "Find across a folder"),
            ]),
            .paragraph("""
                Pick the root folder, filter by file-name pattern, then scan. Results appear as a \
                list grouped by file; clicking a line opens that file at that position.
                """),
            .bullets([
                "The same three search modes and the same regex engine as the in-document search box.",
                "Replace across a folder **previews** how many files and how many matches will change before writing.",
                "The scan runs in parallel and **can be cancelled** mid-way.",
            ]),
            .warning("""
                Replace across a folder writes directly into files that are **not open**. Those \
                files are not in the open document's undo history — preview first, and keep a \
                backup or a version-controlled repository.
                """),
            .heading("Earlier searches, and exporting results"),
            .paragraph("""
                The results panel **keeps this session's searches**. The pop-up at the top of the \
                panel lists them with their match counts — search `TODO`, read part-way, search \
                `FIXME` to compare, then come back to the first list without rescanning the whole \
                folder.
                """),
            .paragraph("""
                The **Export** button opens the current search as a text tab, one result per line \
                as `path:line:column: text` — the shape `grep -n` uses and the shape compilers \
                use for errors. Each line pastes straight into this product's own `Go To` box, \
                and your `grep`, `awk` and `sed` read it without a custom parser.
                """),
            .note("""
                The history lives in **memory** and is never written to disk: search results carry \
                the content of each matching line, which is the same class of data the clipboard \
                history deliberately does not persist.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    // MARK: - Line marks

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Line marks",
        summary: "Nine mark colours, and four commands that turn marked lines into a result.",
        keywords: ["bookmark", "mark", "f2", "filter lines"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Marking is how you filter a document **without changing it**. Mark every line \
                matching a pattern, then copy just those out, or keep only them.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Mark every line matching the current search"),
                HelpShortcut("⌘F2", "Mark / unmark the current line"),
                HelpShortcut("F2 / ⇧F2", "Jump to next / previous mark"),
            ]),
            .heading("A common workflow"),
            .steps([
                "`⌘F` for the pattern you want to filter on, e.g. `\\bERROR\\b`.",
                "`⌘M` marks every matching line.",
                "`Search ▸ Copy marked lines` pulls them into a new tab — or `Keep only marked lines` filters in place.",
            ]),
            .heading("Nine colours"),
            .paragraph("""
                A line can carry **several colours at once**. Use different colours for different \
                criteria and combine them: red for error lines, yellow for lines belonging to one \
                order ID, then look for lines wearing both.
                """),
            .bullets([
                "`Invert marks` — marked lines become unmarked and vice versa.",
                "`Clear all marks` — removes every mark without touching the content.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    // MARK: - Go to line

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Go to line",
        summary: "Jump to a line, a column, or a byte position.",
        keywords: ["goto", "go to", "line number", "cmd+l", "offset", "position", "column"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Go to line")]),
            .paragraph("""
                The field understands **three notations**, and tells them apart from what you \
                type — there is no extra selector to click.
                """),
            .table(
                headers: ["Type", "Goes to"],
                rows: [
                    ["`120`", "the start of line 120"],
                    ["`120,5` or `120:5`", "line 120, column 5 — the column counts CHARACTERS"],
                    ["`@1024`", "byte position 1024 in the file"],
                ]
            ),
            .note("""
                `line:column` is exactly how compilers and linters print a position, so a line you \
                just copied from a terminal pastes straight in.

                The `@` for byte positions has a reason: is `1234` a line or a byte? There is no \
                right answer, and guessing wrong sends the caret somewhere else entirely with \
                nothing to signal it. That byte figure is also what the status bar shows in the \
                position segment (`@1024`), so what you read there you can type here.
                """),
            .bullets([
                "A column **beyond the line's length** stops at the end of that line; it does not spill onto the next.",
                "A byte position **beyond the file** takes you to the end — you usually copied that number from an earlier run, and the file may have shrunk.",
                "Text it cannot read is **reported**, and the caret stays put; it does not jump to the top of the file.",
            ]),
            .paragraph("""
                On very large files GEditor does not read the whole file to get there — the line \
                index is built incrementally in the background.
                """),
            .note("""
                The command-line tool takes a position too: `geditor report.csv:120:5` opens the \
                file with the caret at line 120, column 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )
}
