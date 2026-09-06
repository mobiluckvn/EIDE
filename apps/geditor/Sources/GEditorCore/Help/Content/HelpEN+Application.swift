import Foundation

extension HelpEN {

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Configuration and the app",
        summary: "Settings, shortcuts, themes, updates, migrating from Notepad++, troubleshooting.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    // MARK: - Settings

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Settings",
        summary: "Every option lives in one human-readable JSON file you can copy to another Mac.",
        keywords: ["settings", "preferences", "options", "configuration", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Open Settings")]),
            .paragraph("""
                There is no OK or Cancel — a change takes effect and is written immediately, the \
                macOS way.
                """),
            .heading("The configuration file"),
            .code(
                language: "text",
                caption: "Where it lives",
                source: """
                    ~/Library/Application Support/GEditor/settings.json
                    """
            ),
            .paragraph("""
                It is an **indented JSON file you can read and edit by hand**. Copy it to another \
                Mac and your whole configuration goes with it. The `Open config file` button in \
                Settings takes you straight there.
                """),
            .heading("The keys"),
            .table(
                headers: ["Key", "Default", "Meaning"],
                rows: [
                    ["`fontSize`", "`13`", "Editor font size"],
                    ["`tabWidth`", "`4`", "How many columns wide a TAB is"],
                    ["`usesTabsForIndent`", "`false`", "Indent with TABs instead of spaces"],
                    ["`languageIndent`", "`{}`", "Per-language indentation — see the whitespace page"],
                    ["`smartIndent`", "`true`", "Auto-indent on a new line"],
                    ["`highlightAllMatches`", "`true`", "Highlight every search hit"],
                    ["`ligatures`", "`false`", "Ligatures — see the note below the table"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Trim trailing whitespace when saving"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalise Unicode to NFC when saving"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Encoding for new files"],
                    ["`defaultEOL`", "`\"lf\"`", "Line endings for new files"],
                    ["`language`", "`\"system\"`", "Interface language"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "the default theme", "Which colour theme is in use"],
                    ["`showWelcomeOnLaunch`", "`true`", "Open the welcome window at launch"],
                    ["`keyBindings`", "`{}`", "Only the keys you changed from the defaults"],
                ]
            ),
            .note("""
                **Why ligatures are OFF by default.** A ligature merges `!=` or `->` into **one** \
                glyph, so the characters you see on screen no longer match the characters in the \
                file — and the Column Editor, column mode and wrap-at-column all measure in \
                columns. Turn it on when writing prose, or when you chose a programming font \
                (Fira Code, JetBrains Mono) precisely for its ligatures.
                """),
            .heading("The neighbouring folders"),
            .table(
                headers: ["Folder", "Holds"],
                rows: [
                    ["`macros/`", "Saved macros, one JSON file each"],
                    ["`scripts/`", "JavaScript scripts"],
                    ["`themes/`", "Colour themes"],
                    ["`grammars/`", "User-defined languages"],
                ]
            ),
            .warning("""
                A configuration file written by a **newer** GEditor is **not overwritten** by an \
                older one — it runs on defaults and says so. Overwriting is the surest way to \
                destroy the configuration of somebody syncing two machines, and they would never \
                learn why.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Status bar

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "The status bar",
        summary: "Ten segments at the bottom — every one readable, and every one clickable.",
        keywords: ["status bar", "bottom bar", "offset", "position",
                   "encoding", "tab", "read-only", "file size"],
        blocks: [
            .paragraph("""
                This is the biggest difference from other editors' status bars: **no segment is \
                read-only**. See a wrong value and clicking it is how you fix it, rather than \
                hunting through menus.
                """),
            .table(
                headers: ["Segment", "Tells you", "Clicking it"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "caret position — column in CHARACTERS, `@340` the byte position",
                     "opens the `Go To` box"],
                    ["`11 byte · 3 dòng`", "document size",
                     "counts bytes · characters · words · lines"],
                    ["`🔒 Chỉ đọc`", "shown only when the document is locked",
                     "states WHY it is locked, and unlocks it when that is possible"],
                    ["`View` / `Code`", "which view you are in", "switches (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "CSV mode and the delimiter in use",
                     "toggles CSV mode, or **re-picks the delimiter**"],
                    ["`Đang theo dõi`", "`tail -f` is running", "—"],
                    ["`UTF-8`", "the encoding", "reinterpret, or convert to another encoding"],
                    ["`LF`", "line-ending style", "switch LF · CRLF · CR"],
                    ["`Python`", "syntax colouring language", "choose another, or go back to by-extension"],
                    ["`Tab: 4`", "indentation width", "2 · 4 · 8, globally or **just for this language**"],
                    ["`Ngắt: tắt`", "soft-wrap mode", "cycles the three modes"],
                ]
            ),
            .heading("Three segments worth a second look"),
            .bullets([
                "**`@340` — the byte position.** This is the number every other tool in the product speaks: JSON and XML errors, `--doc-sweep` output, the binary viewer, and the `Go To @340` box. Read it here, type it there.",
                "**A `~` on the column** means the number is counting BYTES rather than visual columns — it only happens on lines longer than 200 KB, where counting characters would slow every caret movement.",
                "**`CSV · …` is clickable to re-pick the delimiter.** Detection can be wrong, and when it is, every column operation is off with nothing to signal it. This is how you say otherwise — it only RE-READS the file, changing not a byte (unlike `CSV ▸ Change delimiter…`, which rewrites it).",
            ]),
            .note("""
                A segment that does not apply to the open file is **hidden**, not greyed: `Read-only` \
                appears only when the document really is locked, `CSV · …` only in CSV mode.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    // MARK: - Key bindings

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Changing keyboard shortcuts",
        summary: "Change individual keys, or adopt the Notepad++ keymap wholesale.",
        keywords: ["shortcut", "keybinding", "keymap", "preset"],
        blocks: [
            .paragraph("""
                `Settings…` has a Shortcuts section with two quick buttons: **Use the Notepad++ \
                preset** and **Back to defaults**.
                """),
            .paragraph("""
                The configuration file records only what you **changed from the defaults**. That way, \
                when GEditor changes a default key in a new version, you are not stuck with the old \
                keymap without anybody telling you.
                """),
            .note("""
                Two commands may not share a shortcut. When they do, AppKit quietly triggers only \
                the **first** menu item and the other command appears broken — so GEditor has a \
                check that prevents it.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    // MARK: - Themes

    static let themes = HelpTopic(
        id: "theme",
        title: "Themes, light and dark",
        summary: "Follow the system, light or dark; and a theme is a JSON file you can edit.",
        keywords: ["theme", "colours", "dark mode", "light", "appearance"],
        blocks: [
            .paragraph("""
                `Settings…` chooses `Follow system`, `Light` or `Dark`, and picks a colour theme.
                """),
            .paragraph("""
                A theme is a JSON file in `themes/`. The `Export current theme` button writes one \
                out as a starting point for your own.
                """),
            .note("""
                A mistyped colour in a theme file falls back to the **default theme's** colour, not \
                to black. Black looks like a design decision, and the user would go looking for the \
                problem somewhere else.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    // MARK: - Updates

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Updates, versions and quitting",
        summary: "How updating differs between the two builds.",
        keywords: ["update", "version", "about", "quit"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Build", "Updates via"],
                rows: [
                    ["App Store", "The App Store, like any other app"],
                    ["Direct download", "`Check for updates…` inside the app"],
                ]
            ),
            .paragraph("""
                `About GEditor` shows the running version and which build it is — useful when \
                reporting a problem.
                """),
            .note("""
                In the App Store build, `Check for updates…` **stays in the menu** and explains why \
                it does not apply, instead of disappearing. A missing menu item is a support \
                question.
                """),
            .paragraph("""
                Quitting loses no work: the session comes back next time you open it.
                """),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    // MARK: - Using help

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Using this help window",
        summary: "Search the book, switch its language, and bring back the welcome window.",
        keywords: ["help", "guide", "search", "welcome", "language"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Open the help window")]),
            .bullets([
                "The search box at the top left looks inside **body text and code samples** — typing a bare config key such as `fail_under` lands on the right page.",
                "Typing **without diacritics** still finds accented text.",
                "The `Back` button returns to the previous page.",
                "The `Copy` button on each code block copies that block.",
            ]),
            .heading("Reading in another language"),
            .paragraph("""
                The pop-up at the top right of this window chooses the **language of the book**, \
                independently of the app's interface language. Switching keeps you **on the page you \
                are reading** — page ids are deliberately not translated, precisely so this works.
                """),
            .note("""
                Only languages that actually have a book are listed. A menu entry that switches to \
                something and leaves the text unchanged would be a menu entry that lies.
                """),
            .heading("Bringing back the welcome window"),
            .paragraph("""
                If you ticked **Do not open this window at launch**, reopen it with `Help ▸ Feature \
                tour` — the checkbox at the foot of the window reappears and can be unticked.
                """),
            .paragraph("""
                Or set `showWelcomeOnLaunch` back to `true` in `settings.json`.
                """),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    // MARK: - Notepad++ migration

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "From Notepad++ to GEditor",
        summary: "Which keys swap places, what works differently, and what is missing.",
        keywords: ["notepad++", "notepad", "migration", "windows", "switching", "shortcuts"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                A few keys **swap places** on macOS rather than simply turning `Ctrl` into `⌘`. Here \
                is the comparison.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Why"],
                rows: [
                    ["`Ctrl+D` Duplicate line", "**⇧⌘D**", "`⌘D` is multi-caret here, as in every Mac editor"],
                    ["`Ctrl+L` Delete line", "**⌘K**", "`⌘L` on macOS means \"go to line\""],
                    ["`Ctrl+G` Go to line", "**⌘L**", "These two swap places"],
                    ["`Ctrl+Q` Comment", "**⌘/**", "macOS convention"],
                    ["`Ctrl+Shift+↑/↓` Move line", "**⌥↑ / ⌥↓**", "`⌃` belongs to Mission Control on macOS"],
                    ["`F3` Find next", "**⌘G**", "macOS convention"],
                    ["`Ctrl+F2` Toggle bookmark", "**⌘F2**", "F2 and ⇧F2 still jump between marks"],
                    ["`Alt` + drag for columns", "**⌥ + drag**", "Identical"],
                    ["`Ctrl+Alt+Shift+↓` Column Editor", "**⌥⌘C**", "macOS convention"],
                ]
            ),
            .note("""
                Would rather not relearn? `Settings ▸ Shortcuts ▸ Use the Notepad++ preset`.
                """),
            .heading("Things Notepad++ has that work differently here"),
            .bullets([
                "**Sessions** restore themselves, unsaved tabs included — nothing to enable.",
                "**Bookmarks have nine colours**, and one line can carry several at once.",
                "**The document map** describes the *whole* file, not just the visible part.",
                "**Macros** can play \"to end of document\" and \"across all tabs\", and a whole run is one undo step.",
            ]),
            .heading("Things GEditor adds"),
            .bullets([
                "**A data cleaning bench** and **data profiles** for CSV files.",
                "**SQL queries** directly against a CSV file.",
                "**Legacy Vietnamese encodings** — TCVN3, VISCII, VNI-Windows, read, written and auto-detected.",
                "**Accent-insensitive search** in every filter box.",
                "**`.greport.md` reports** with tables and charts that rerun.",
                "**The `geditor` command-line tool** in the direct-download build.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    // MARK: - Troubleshooting

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Common problems",
        summary: "Six situations that make people think the app is broken.",
        keywords: ["error", "problem", "not working", "broken", "troubleshoot", "why"],
        blocks: [
            .table(
                headers: ["Symptom", "Usual cause"],
                rows: [
                    ["Vietnamese text shows as gibberish", "Wrong encoding — click the encoding on the status bar"],
                    ["Searching for accented text finds nothing", "The file is in decomposed Unicode — run `Normalise Unicode` to NFC"],
                    ["A menu item is greyed out", "The App Store build cannot run that command — the item explains why"],
                    ["Bracket matching refuses to run", "The document is over 1 MB — highlighting the wrong pair is worse than none"],
                    ["The column on the status bar has a `~`", "The document is over 200 KB, so that is a byte count, not a visual column"],
                    ["A SQL query says the file must be saved first", "DuckDB reads **files**, not the buffer you are editing"],
                ]
            ),
            .heading("When GEditor quits unexpectedly"),
            .paragraph("""
                At the next launch a banner says so, with an **Open report** button — the report \
                opens as a tab you can read and copy from like any other text file.
                """),
            .bullets([
                "The report carries only the **version, macOS release, machine architecture, signal name and call stack**.",
                "**No document content, and no file paths either** — a path like `~/Desktop/salary-december.xlsx` has already revealed three private things before anyone opens it.",
                "**Nothing is sent anywhere.** There is no automatic upload and no server to receive it; the file stays in `~/Library/Application Support/GEditor/crash/` until you open or delete it.",
                "Once you have opened the report, the next launch does not mention it again.",
            ]),
            .heading("Where to look next"),
            .bullets([
                "The status bar shows encoding, line endings, language and wrap mode — every segment is clickable.",
                "`settings.json` can be edited by hand when the Settings window is not enough.",
                "`About GEditor` gives the version and the build, which a bug report needs.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
