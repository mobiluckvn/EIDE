import Foundation

extension HelpEN {

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Languages and formats",
        summary: "Twenty built-in languages, user-defined ones, and tools for JSON · XML · YAML · logs.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    // MARK: - Built-in languages

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Twenty built-in languages",
        summary: "Colouring from a real syntax tree, with each language's comment markers.",
        keywords: ["syntax", "highlight", "language", "tree-sitter", "grammar"],
        blocks: [
            .paragraph("""
                The language is detected from the **file extension** (plus a few special names such \
                as `Makefile`, `Dockerfile`, `Gemfile`). You can change it by hand on the status \
                bar.
                """),
            .table(
                headers: ["Language", "Extensions", "Line · block comment"],
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
                The last column is what `⌘/` uses. Languages without a line comment (JSON, CSS, \
                XML) get the block form instead.
                """),
            .heading("What comes with a syntax tree"),
            .bullets([
                "The **function list** in the sidebar follows real structure, not indentation guesses.",
                "**Folding** by structure.",
                "**Bracket matching** that skips brackets inside strings and comments.",
                "**Auto-indent** adding a level after `{`, and after `:` in Python and YAML.",
            ]),
            .note("""
                Three heavy grammars (C++, C#, Ruby) live in a **lazily loaded** library — they are \
                loaded only when you open a file in one of those languages. That is how launch time \
                stays under half a second.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    // MARK: - User-defined languages

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "User-defined languages",
        summary: "Colour your own format with one JSON file — no grammar to write.",
        keywords: ["udl", "user defined language", "custom language", "custom log"],
        blocks: [
            .paragraph("""
                A company's internal log format, a private configuration language, a small DSL — \
                none of these have a tree-sitter grammar, and writing one takes a compiler and \
                some parsing theory.
                """),
            .paragraph("""
                Instead, GEditor accepts a **table-driven lexer** declared in JSON. Put the file in \
                the `grammars/` folder inside GEditor's configuration directory and relaunch.
                """),
            .code(
                language: "json",
                caption: "grammars/internal-log.json — a complete language",
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
            .heading("Each key"),
            .table(
                headers: ["Key", "Type", "Meaning"],
                rows: [
                    ["`name`", "string", "The name shown on the status bar"],
                    ["`extensions`", "array of strings", "File extensions, **without the dot**"],
                    ["`caseSensitive`", "boolean", "Whether keywords are case-sensitive"],
                    ["`lineComment`", "string", "Comment-to-end-of-line marker; omit if there is none"],
                    ["`blockComment`", "array of 2 strings", "`[open, close]`"],
                    ["`stringDelimiters`", "array of strings", "Each entry is **one** character that opens/closes a string"],
                    ["`escapeCharacter`", "string", "Escape character inside strings; empty means the language has none"],
                    ["`keywordGroups`", "object", "Group name → keyword list; three groups get three colours"],
                ]
            ),
            .paragraph("""
                The three group names that receive their own colours are `keyword`, `type` and \
                `constant`.
                """),
            .warning("""
                This lexer **does not understand nesting**. Structural folding, the function list \
                and smart bracket matching remain exclusive to the twenty built-in languages. That \
                is a deliberate trade: in exchange you declare a language in ten minutes instead of \
                a day.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    // MARK: - JSON tools

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON tools",
        summary: "Reformat, minify, sort keys, and validate against a JSON Schema.",
        keywords: ["json", "format", "pretty", "minify", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Command", "What it does"],
                rows: [
                    ["Reformat", "Wraps and indents for reading"],
                    ["Minify", "Removes all superfluous whitespace"],
                    ["Sort keys", "Alphabetises the keys of every object — so two JSON files can be **diffed** against each other"],
                    ["Validate against JSON Schema…", "Checks the document against a schema file, listing each problem with its line"],
                ]
            ),
            .paragraph("""
                The rules applied are **strict RFC 8259**: no trailing commas, no comments, no \
                `NaN`. A syntax error points at the exact line and column.
                """),
            .note("""
                **JSONL** files (one object per line) are recognised too, and have their own \
                toolset in the knowledge-pack chapter.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    // MARK: - JSONPath

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath queries",
        summary: "Pull exactly the part you need out of a large JSON file.",
        keywords: ["jsonpath", "json query", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Type an expression; results appear as a list you can jump into."),
            .table(
                headers: ["Write", "Meaning"],
                rows: [
                    ["`$`", "The document root"],
                    ["`$.name`", "The key `name` at the root"],
                    ["`$.orders[0]`", "The first element of an array"],
                    ["`$.orders[*].total`", "The `total` key of **every** element"],
                    ["`$..province`", "The key `province` at **any depth**"],
                    ["`$.orders[1:3]`", "A slice: elements 1 and 2"],
                ]
            ),
            .code(
                language: "text",
                caption: "Every order's province code, however deeply nested",
                source: """
                    $..orders[*].address.province
                    """
            ),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    // MARK: - XML tools

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML tools",
        summary: "Reformat, minify, check syntax, and validate against a DTD or XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "validate", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Command", "What it does"],
                rows: [
                    ["Reformat", "Indents by tag depth"],
                    ["Minify", "Removes whitespace between tags"],
                    ["Check syntax", "Missing closing tags, wrong nesting, invalid characters"],
                    ["Validate against DTD/XSD…", "Checks against a schema, reporting each problem with its line"],
                    ["Evaluate XPath…", "Runs an XPath expression; results open in a new tab"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Type an expression and the results open as **a text tab**, one node per line. For \
                example: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **The results do NOT jump to a position in the source file.** The system's XPath \
                evaluator builds its own tree and does not keep each node's byte offset, so what \
                comes back is CONTENT rather than coordinates. To reach the exact spot, use `⌘F` on \
                the string you just found.
                """),
            .paragraph("""
                In `.xml` and `.html` files, typing `>` to finish an opening tag makes the **closing \
                tag appear** with the caret between the two. Self-closing tags (`<br/>`), \
                declarations (`<?xml …?>`) and comments do not — they have nothing to close.
                """),
            .warning("""
                Reformatting XML **changes the whitespace between tags**. In documents where that \
                whitespace is meaningful — XHTML with text inside tags, say — this changes what is \
                displayed. It is a single undo step, so `⌘Z` reverses it.
                """),
        ]
    )

    // MARK: - YAML tools

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML checking",
        summary: "Catch the two most common YAML mistakes: duplicate keys and tab indentation.",
        keywords: ["yaml", "yml", "lint", "duplicate key", "indentation"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Duplicate keys** in one mapping — most YAML readers take the **last** one and silently drop the earlier, so a config file can behave nothing like you expect.",
                "**Tab indentation** — YAML forbids tabs in indentation, and library error messages about it are usually incomprehensible.",
            ]),
            .note("""
                Turn on `Show invisibles ▸ Tabs` to see immediately which whitespace is a tab.
                """),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    // MARK: - Log files

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Log files",
        summary: "Seven severity levels, filtering by level, and how to read a very large log.",
        keywords: ["log", "error", "warning", "filter", "level"],
        blocks: [
            .paragraph("""
                Turn on `View ▸ Log mode (colour by level)`. GEditor reads the severity from the \
                **start of each line** — after the timestamp and process name.
                """),
            .table(
                headers: ["Level", "Colour"],
                rows: [
                    ["CRITICAL · ERROR", "Red"],
                    ["WARNING", "Amber"],
                    ["NOTICE", "Accent colour"],
                    ["INFO", "Ordinary text"],
                    ["DEBUG · TRACE", "Dimmed"],
                ]
            ),
            .paragraph("""
                `Filter log by level…` hides the lower levels altogether. Lines whose level is **not \
                recognised** — a stack-trace continuation, for example — are left alone rather than \
                being assigned the previous line's level.
                """),
            .heading("Reading a large log, step by step"),
            .steps([
                "Open the file — gigabyte-scale still opens almost instantly.",
                "`View ▸ Log mode` to see the red spots.",
                "`⌥⌘M` for the document map: is the red clustered in one stretch or spread through the file?",
                "`⌘F` for the error code, `⌘M` to mark every matching line.",
                "`Search ▸ Copy marked lines` to pull them into a new tab.",
                "Still running? `File ▸ Follow file (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
