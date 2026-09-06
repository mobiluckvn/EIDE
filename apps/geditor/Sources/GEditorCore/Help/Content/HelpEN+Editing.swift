import Foundation

extension HelpEN {

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Editing",
        summary: "Edit many places at once, work on lines, and the hidden rules worth knowing first.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    // MARK: - Multiple carets

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Multiple carets",
        summary: "Select every matching spot, type once, change them all.",
        keywords: ["multi caret", "multicursor", "cmd+d", "multiple selection"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                This replaces most of the moments where you were about to write a regular \
                expression. Select a word, press `⌘D` a few times to collect the next \
                occurrences, then type — every spot changes at once.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Add the next occurrence to the selection"),
                HelpShortcut("⌘ + click", "Place another caret where you click"),
                HelpShortcut("Esc", "Drop them all, back to one caret"),
                HelpShortcut("⌥ + drag", "Column block selection (another way to get many carets)"),
            ]),
            .heading("Rules worth knowing"),
            .bullets([
                "Typing, deleting and pasting across many carets is **one** undo step, not one per caret.",
                "Carets survive arrow-key movement — the whole group moves together.",
                "`⌘D` skips spots already inside the selection, so over-pressing never stacks carets on top of each other.",
            ]),
            .note("""
                `⌘D` on a word inside a long string used to be slow. Word-boundary detection now \
                reads in batches — about **42× faster** on a 1 MB string, which makes this usable \
                on data files, not just source code.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    // MARK: - Column block

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Column block selection",
        summary: "Select a rectangle across many lines — with the mouse or from the keyboard.",
        keywords: ["column mode", "block select", "alt drag", "rectangle", "keyboard", "arrows"],
        blocks: [
            .paragraph("""
                Hold `⌥` and drag to select a **rectangular block**. Typing, deleting and pasting \
                all follow the block. Pasting a block at a single caret still keeps its rectangle.
                """),
            .shortcuts([
                HelpShortcut("⌥ + drag", "Select a block"),
                HelpShortcut("⌥⌘← →", "Widen the block one column left/right"),
                HelpShortcut("⌥⌘↑ ↓", "Extend the block one line up/down"),
            ]),
            .paragraph("""
                The keyboard route is not a fallback for the mouse: selecting a 40-line block by \
                dragging means dragging through a scroll, while `⌥⌘` + arrows keeps \
                column-by-column precision. Pressing any **other** key (or typing) ends the block \
                you were extending.
                """),
            .heading("Columns here are VISUAL columns"),
            .paragraph("""
                A TAB expands to the next stop at your tab width rather than counting as one \
                column. That is what makes tab-indented and space-indented lines **line up the \
                way they do on screen**.
                """),
            .paragraph("""
                Multi-byte text is still one column: `Nguyễn` occupies six columns, not nine.
                """),
            .table(
                headers: ["Situation", "What GEditor does"],
                rows: [
                    ["The target column lands mid-TAB", "Snaps to the nearer edge; ties go left"],
                    ["A line is shorter than the start column", "That line contributes an empty selection, and still accepts typed text"],
                    ["Pasting a block at a single caret", "Keeps the rectangle, inserting down the lines below"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    // MARK: - Column Editor

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Column Editor",
        summary: "Insert text, a number series or a date series into every line of a block.",
        keywords: ["column editor", "numbering", "sequence", "series"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Select a column block, then open `Edit ▸ Column Editor…` (`⌥⌘C`). The dialog has a \
                **preview** before anything is applied.
                """),
            .table(
                headers: ["Mode", "Parameters", "Use when"],
                rows: [
                    ["Text", "A fixed string", "Adding the same prefix/suffix to every line"],
                    ["Number series", "Start · step · base 2·8·10·16 · zero padding", "Numbering rows, generating codes"],
                    ["Date series", "First date · step in days", "Producing a column of consecutive dates"],
                ]
            ),
            .code(
                language: "text",
                caption: "Numbering with zero padding, starting at 1, step 1",
                source: """
                    Before:           After (number series, padded to 3 digits):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """
            ),
            .bullets([
                "A **negative** step is valid — counting down works.",
                "Inserting into 5,000 lines is still **one** undo step.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    // MARK: - Line operations

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Line operations",
        summary: "Sort, deduplicate, move, join, split, duplicate, delete.",
        keywords: ["sort", "duplicate", "dedupe", "move line", "join", "split"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                With a selection, the command runs on the selection; without one it runs on the \
                **whole document**. Every command here is a single undo step.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Duplicate line"),
                HelpShortcut("⌘K", "Delete line"),
                HelpShortcut("⌥↑ / ⌥↓", "Move line up / down"),
            ]),
            .heading("Three kinds of sort, and which to pick"),
            .table(
                headers: ["Kind", "`file2` vs `file10`", "Use for"],
                rows: [
                    ["A→Z / Z→A", "`file10` comes before `file2`", "Plain word lists"],
                    ["Natural", "`file2` comes before `file10`", "File names, coded IDs, versions"],
                ]
            ),
            .paragraph("""
                **Natural** sort reads runs of digits as numbers. That is almost always what you \
                want when the list is numbered.
                """),
            .heading("Deduplication"),
            .bullets([
                "**Whole document** — drop every line that appeared earlier, keep the first.",
                "**Adjacent only** — collapse identical neighbouring lines, like Unix `uniq`.",
            ]),
            .heading("Joining and splitting"),
            .bullets([
                "**Join lines** merges the selected lines into one.",
                "**Split by length** cuts long lines at a given character count.",
                "**Split by character** cuts at every occurrence of a character you type — for example splitting one CSV row into its cells.",
            ]),
            .note("""
                Duplicating the **last line** of a file adds the missing newline; deleting through \
                the end of the document also swallows the previous line's newline. Both differ \
                from the naive implementation, and both exist so the file does not end up with a \
                stray blank line — or without one.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    // MARK: - Whitespace

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Whitespace and indentation",
        summary: "Clean stray whitespace, convert TAB ↔ Space, and one switch worth thinking about.",
        keywords: ["whitespace", "tab", "space", "trim", "indent", "blank lines"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Command", "What it does"],
                rows: [
                    ["Remove blank lines", "Drops every line with nothing on it"],
                    ["Collapse consecutive blank lines", "Several blank lines in a row become one"],
                    ["Trim trailing whitespace", "Removes stray spaces and tabs at the end of each line"],
                    ["Tab → Space", "Converts TABs into spaces at the current tab width"],
                    ["Space → Tab", "The other direction"],
                ]
            ),
            .heading("Per-language indentation"),
            .paragraph("""
                Click `Tab: 4` on the status bar. The upper part of the menu changes it for the \
                **whole app**; the lower part — `Just for Go`, `Just for Python`… — applies only \
                to the language of the open file, and remembers whether to use tabs or spaces.
                """),
            .paragraph("""
                People do not pick indentation by taste but by **community convention**: Go uses \
                tabs (`gofmt` overrides anything else), Python four spaces per PEP 8, JavaScript \
                and YAML usually two. One number for every language means every file you touch \
                grows lines you never edited.
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
                Declaring it in `settings.json` works too — the key is the language code (`go`, \
                `python`, `javascript`…). Languages absent from it use the shared `tabWidth`.
                """),
            .heading("Why \"trim on save\" is OFF by default"),
            .paragraph("""
                The switch `File ▸ Trim trailing whitespace on save` edits **lines you never \
                touched**. Turned on by default, a one-word fix in someone else's repository \
                becomes a thousand-line diff, and the reviewer cannot find the real change.
                """),
            .paragraph("""
                When it is on, the trim is a **separate undo step** placed before the write — one \
                undo returns the document to how it was, without losing what you just saved.
                """),
            .heading("Automatic indentation"),
            .bullets([
                "A new line inherits the previous line's indentation, plus one level after an opening token — `{` for brace languages, `:` for Python and YAML.",
                "The measurement is in **visual columns**, so files that mix tabs and spaces still line up on screen.",
                "There is **no** \"typing `}` re-indents the line\" rule. That rule edits a line you already finished, and it is the single most complained-about behaviour in every editor that has it.",
            ]),
        ]
    )

    // MARK: - Case conversion

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Case and naming conventions",
        summary: "Eight conversions, including camelCase, snake_case and kebab-case.",
        keywords: ["case", "uppercase", "lowercase", "camel", "snake", "kebab", "title case"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Applied to the selection. All of them live in the `Format` menu."),
            .table(
                headers: ["Command", "`tổng doanh thu` becomes"],
                rows: [
                    ["UPPERCASE", "`TỔNG DOANH THU`"],
                    ["lowercase", "`tổng doanh thu`"],
                    ["Title Case", "`Tổng Doanh Thu`"],
                    ["Sentence case", "`Tổng doanh thu`"],
                    ["Invert case", "Flips each character"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                The last three strip Vietnamese diacritics, because they produce **identifiers in \
                code** — where accented letters are usually not allowed.
                """),
        ]
    )

    // MARK: - Comments and brackets

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Comments and bracket matching",
        summary: "⌘/ uses each language's own marker; ⌃⌘B jumps to the matching bracket.",
        keywords: ["comment", "bracket", "cmd+/", "matching"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` picks the comment marker **by the document's language**: `#` for Python, `//` \
                for Rust and C, `<!-- -->` for XML and HTML.
                """),
            .heading("The whole block goes one way"),
            .paragraph("""
                If a single line in the block is still uncommented, the command comments \
                **everything**. Deciding line by line would turn a half-commented block into a \
                chessboard. The marker is inserted at the block's shallowest indentation, so the \
                block keeps its shape.
                """),
            .heading("Jumping to the matching bracket"),
            .bullets([
                "`⌃⌘B` jumps to the bracket matching the one at the caret.",
                "Brackets inside **strings** or **comments** do not count — a light lexer tells them apart.",
                "Past **1 MB**, the command refuses and says so rather than anchoring halfway and guessing. Highlighting the wrong pair is worse than highlighting none.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    // MARK: - Undo and clipboard

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Undo and the clipboard",
        summary: "Unlimited undo history, and a multi-slot clipboard history.",
        keywords: ["undo", "redo", "clipboard", "paste", "history"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Undo / Redo"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Cut / Copy / Paste"),
                HelpShortcut("⇧⌘V", "Clipboard history"),
            ]),
            .heading("A bulk operation is ONE step"),
            .paragraph("""
                Sorting a million lines, replacing ten thousand matches, inserting into five \
                thousand lines with the Column Editor — each of those is undone by **one** `⌘Z`.
                """),
            .paragraph("""
                The undo history lives in GEditor's own text buffer rather than the system \
                `UndoManager`, for exactly that reason: `UndoManager` counts keystrokes.
                """),
            .heading("Clipboard history"),
            .paragraph("""
                `⇧⌘V` opens a list of what you copied recently and pastes the entry you pick. \
                Useful when you have to alternate two snippets across many places.
                """),
        ]
    )
}
