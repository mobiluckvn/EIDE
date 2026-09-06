import Foundation

/// English help content — opening chapter.
///
/// # Why a second book instead of a string table
///
/// The Vietnamese book is prose: tables whose rows are sentences, warnings that explain a
/// trade-off, notes that name a real failure. Running that through `L10n` would mean a
/// translation key per sentence — thousands of them — and a translator would be editing
/// fragments with no idea which page they land on. A whole book per language keeps every page
/// readable as a page.
///
/// **Topic `id`s are NOT translated.** They are what `.seeAlso` points at, what the menu opens,
/// and what lets the help window swap languages without throwing the reader back to the table of
/// contents. Change an id and every link breaks — in both books at once.
enum HelpEN {}

extension HelpEN {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Getting started",
        summary: "What GEditor does, and where to spend your first five minutes.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    // MARK: - Intro (welcome page)

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "What GEditor is",
        summary: "A gigabyte-scale text and data editor for macOS that speaks Vietnamese.",
        keywords: ["intro", "welcome", "overview", "about", "giới thiệu"],
        blocks: [
            .paragraph("""
                GEditor opens a **1 GB file without loading 1 GB into RAM**. It reads through a \
                sliding window over a memory-mapped file, so a 200-million-line log or a \
                million-row CSV opens in about a second and scrolls smoothly.
                """),
            .paragraph("""
                Beyond editing, it is a **workbench for data**: view CSV as a grid, clean it, \
                score its quality, query it with SQL, mine it for anomalies and trends, then \
                render a report. And it reads the legacy Vietnamese encodings that most tools \
                today have forgotten.
                """),
            .heading("Six things worth trying first"),
            .table(
                headers: ["Task", "Where to go"],
                rows: [
                    ["Open a large file without waiting", "Drag it into the window — see `Opening large files`"],
                    ["Edit many places at once", "`⌘D` adds the next match, then type once"],
                    ["Search with a regular expression", "`⌘F`, turn on Regex — the engine is PCRE2 with JIT"],
                    ["View a CSV as a grid", "`⌥⌘T` — a million rows still scroll smoothly"],
                    ["Clean a messy data table", "`⇧⌘L` Cleaning bench — preview before you apply"],
                    ["Open a Vietnamese file that shows garbage", "Click the encoding on the status bar"],
                ]
            ),
            .note("""
                Coming from Notepad++? There is a page comparing the two keymaps, because a few \
                keys **swap places** on macOS rather than simply turning `Ctrl` into `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    // MARK: - First five minutes

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Your first five minutes",
        summary: "Twelve shortcuts cover most of the daily work.",
        keywords: ["shortcut", "keys", "start", "basics", "quick start"],
        blocks: [
            .paragraph("""
                You do not need to learn everything. The twelve keys below cover most everyday \
                work; look up the rest when you need it.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Open a file"),
                HelpShortcut("⇧⌘O", "Open a whole folder as a workspace"),
                HelpShortcut("⌘T", "New tab"),
                HelpShortcut("⌘S", "Save"),
                HelpShortcut("⌘F", "Find"),
                HelpShortcut("⌥⌘F", "Find and replace"),
                HelpShortcut("⇧⌘F", "Find across a folder"),
                HelpShortcut("⌘D", "Add the next occurrence of the selection"),
                HelpShortcut("⌘L", "Go to line"),
                HelpShortcut("⌘/", "Comment the line using the language's own syntax"),
                HelpShortcut("⌥⌘T", "Switch between Grid and Text (CSV files)"),
                HelpShortcut("⌘?", "Reopen this help window"),
            ]),
            .heading("Three things that surprise newcomers"),
            .bullets([
                "**A bulk operation is ONE undo step**, even when it touches a million lines. Sorted the wrong way? One `⌘Z` and it is gone.",
                "**The session restores itself.** Quit and reopen: tabs come back where they were, including unsaved ones. Nothing to press.",
                "**Typing without diacritics still finds words with them** in every search and filter box — type `hue` to get `Huế`, `da nang` to get `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    // MARK: - Pick a task

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "What are you trying to do?",
        summary: "A lookup table from real tasks to the chapter that covers them.",
        keywords: ["index", "lookup", "how to", "how do I"],
        blocks: [
            .paragraph("""
                The table of contents on the left is arranged by **feature**. This table is \
                arranged by **task**, because the two orders do not line up.
                """),
            .table(
                headers: ["I need to…", "See"],
                rows: [
                    ["Edit the same spot on hundreds of lines", "Multiple carets · Column block selection"],
                    ["Reformat in bulk with a regex", "Find and replace · Regular expressions"],
                    ["Repeat a sequence of actions", "Macros"],
                    ["Open a CSV someone sent me", "The CSV grid"],
                    ["Clean a messy table: mixed dates, numbers as text", "The data-cleaning workflow"],
                    ["Judge whether a table can be trusted", "Data quality scoring"],
                    ["Find anomalies, trends, clusters", "The data-mining workflow"],
                    ["Ask questions in SQL", "Querying CSV with SQL"],
                    ["Publish a report whose figures refresh", "`.greport.md` reports"],
                    ["Draw a diagram inside a document", "Mermaid"],
                    ["Open a Vietnamese file that shows garbage", "Vietnamese encodings"],
                    ["Automate from the shell or AppleScript", "Automation"],
                    ["Colour a format my company invented", "User-defined languages"],
                ]
            ),
            .note("""
                Not listed? The search box at the top left looks inside **body text and code \
                samples**, so typing a bare config key such as `fail_under` lands on the right \
                page.
                """),
        ]
    )

    // MARK: - Large files

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Opening large files",
        summary: "Why 1 GB opens at all, and where GEditor refuses on purpose instead of guessing.",
        keywords: ["large file", "gigabyte", "1gb", "log", "mmap", "slow", "performance"],
        blocks: [
            .paragraph("""
                The file is **memory-mapped** and read through a sliding window; the part you are \
                editing lives in a piece table. In practice: opening time barely depends on file \
                size, and neither does the memory the app holds.
                """),
            .heading("Where it refuses on purpose"),
            .paragraph("""
                A few computations would have to read the whole file into one string — exactly \
                what this architecture avoids. There, GEditor **says it will not** rather than \
                quietly crawling or guessing:
                """),
            .table(
                headers: ["Operation", "Ceiling", "Beyond it"],
                rows: [
                    ["Bracket matching", "1 MB", "Refuses and says so — highlighting the wrong pair is worse than none"],
                    ["Visual column on the status bar", "200 KB", "Falls back to counting bytes, and marks it `~` so the meaning is visible"],
                    ["Markdown preview", "4 MB", "Refuses and explains"],
                ]
            ),
            .warning("""
                A number that looks identical but means something else is the worst kind of \
                wrong. That is why a column past the ceiling reads `~1234`, not `1234`.
                """),
            .heading("Tips for log files"),
            .bullets([
                "`File ▸ Follow file (tail -f)` appends whatever gets written to the end. The document becomes **read-only** while following — typing while new text streams in means two writers fighting over one document, and the loser is always what you just typed.",
                "Log lines are **coloured by severity**, and can be filtered by level.",
                "The **document map** (`⌥⌘M`) describes the whole file, not just the part on screen.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    // MARK: - Two builds

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App Store build vs direct download",
        summary: "Three features only the direct build has, and why.",
        keywords: ["app store", "sandbox", "download", "cli", "plugin", "difference"],
        blocks: [
            .paragraph("""
                GEditor ships in two builds. They come from the **same source** and the app \
                recognises which one it is at launch. The difference is what App Sandbox permits.
                """),
            .table(
                headers: ["Feature", "App Store", "Direct download"],
                rows: [
                    ["All editing, CSV, cleaning, mining, reporting", "Yes", "Yes"],
                    ["The `geditor` command-line tool", "No", "Yes"],
                    ["Filtering text through an external command", "No", "Yes"],
                    ["Native plug-ins (separate process)", "No", "Yes"],
                    ["Self-update", "Through the App Store", "In-app"],
                ]
            ),
            .paragraph("""
                Every "No" above comes from the same rule: the sandbox **forbids running code \
                outside the app**. That is the price of App Store distribution, not an oversight.
                """),
            .note("""
                In the App Store build those commands **stay in the menu** and explain why they \
                are unavailable, instead of vanishing. A missing menu item is a support question; \
                an answer in place is not.
                """),
            .heading("File access in the App Store build"),
            .paragraph("""
                The sandboxed build can only touch files you opened or dragged in yourself. \
                GEditor keeps a **security-scoped bookmark** for each tab and for the workspace \
                folder, so your session reopens after you quit without asking for permission \
                again.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )
}
