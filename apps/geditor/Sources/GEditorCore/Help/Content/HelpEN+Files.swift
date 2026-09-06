import Foundation

extension HelpEN {

    static let files = HelpChapter(
        id: "tep",
        title: "Files and sessions",
        summary: "Opening, saving, tabs, windows, workspaces, and how the session comes back.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    // MARK: - Open and save

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Opening and saving",
        summary: "Open a file of any size, and save it with a different encoding or line ending.",
        keywords: ["open", "save", "save as", "duplicate", "rename", "move"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "New document"),
                HelpShortcut("⌘O", "Open a file"),
                HelpShortcut("⌘S", "Save"),
                HelpShortcut("⇧⌘S", "Save as"),
            ]),
            .paragraph("""
                Dragging a file into the window opens it too. `File ▸ Open Recent` keeps the list \
                of files you were just working on.
                """),
            .heading("Save as: three things you can change"),
            .table(
                headers: ["Change", "Meaning"],
                rows: [
                    ["Encoding", "Write out UTF-8, TCVN3, VNI-Windows… — 36 encodings"],
                    ["Line endings", "LF (Unix) · CRLF (Windows) · CR (classic Mac)"],
                    ["Name and location", "Like every macOS save dialog"],
                ]
            ),
            .paragraph("""
                The status bar always shows the encoding, the line-ending style and the detected \
                language. **Clicking any of those changes it immediately**, without going through \
                a dialog.
                """),
            .heading("Duplicate · rename · move"),
            .paragraph("""
                These three work on the FILE rather than its contents — and the open tab follows \
                the file, so you never lose your place.
                """),
            .table(
                headers: ["Command", "What it does"],
                rows: [
                    ["`Duplicate File`",
                     "Copies it as `name 2.txt` beside the original and **opens the copy** — because people duplicate in order to edit the copy"],
                    ["`Rename File…`", "Renames on disk; the tab follows the new name"],
                    ["`Move File To…`", "Moves to another folder; the tab follows"],
                ]
            ),
            .note("""
                All three **refuse when a file of that name already exists** at the destination; \
                they never overwrite. And all three need a file that has been saved at least once \
                — a document that has never been on disk has nothing to duplicate or move.
                """),
            .heading("Safe writing"),
            .bullets([
                "Writing is **atomic**: losing power midway never leaves a truncated file.",
                "If another program changes the file while you have it open, GEditor notices and asks before overwriting.",
                "Files on iCloud Drive or a network volume go through the system's file coordinator, so two machines do not step on each other.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    // MARK: - Tabs and windows

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Tabs, windows and split view",
        summary: "Many tabs per window, many windows, and tabs you can drag between them.",
        keywords: ["tab", "window", "split", "pane"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "New tab"),
                HelpShortcut("⌘W", "Close tab"),
                HelpShortcut("⇧⌘T", "Reopen the last closed tab"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Next / previous tab"),
                HelpShortcut("⌥⌘N", "New window"),
                HelpShortcut("⌃⌘N", "Detach the current tab into its own window"),
            ]),
            .paragraph("""
                You can drag a tab into another window, or drop it on empty space to make a new \
                window. **A pinned tab does not travel** — pinning means "keep this one here".
                """),
            .note("""
                `⇧⌘T` reopens the last closed tab, including an **unsaved** one: its contents are \
                still there.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    // MARK: - Workspace

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Opening a folder as a workspace",
        summary: "A file tree in the sidebar, project-wide search, and one-click opening.",
        keywords: ["workspace", "folder", "project", "sidebar"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Open a folder as a workspace")]),
            .paragraph("""
                The tree appears in the sidebar (`⌘0`). Click a file to open it, and `⇧⌘F` \
                searches the entire folder.
                """),
            .note("""
                In the App Store build, access to the folder is held by a **security-scoped \
                bookmark**, so the next launch can still reach it without asking you to pick the \
                folder again.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    // MARK: - Session

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "The session restores itself",
        summary: "Quit and reopen: every tab returns, including unsaved ones.",
        keywords: ["session", "restore", "unsaved", "recover"],
        blocks: [
            .paragraph("""
                Nothing to switch on. Quit GEditor and open it again: tabs, their order, caret \
                positions and scroll positions all come back.
                """),
            .heading("What about unsaved tabs"),
            .paragraph("""
                Their contents are kept in a separate snapshot, so they return as well. If the app \
                exits abnormally, the next launch **asks** before restoring orphaned drafts — \
                rather than silently rebuilding a pile of tabs you do not remember.
                """),
            .warning("""
                A session is **not a backup**. It preserves working state, not history. Anything \
                that matters still has to be saved to a file.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    // MARK: - Saved versions

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Previously saved versions",
        summary: "Browse and restore older versions of a file.",
        keywords: ["versions", "history", "restore", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                On every save, GEditor records the **previous** version before overwriting. \
                `Macro ▸ Saved versions…` opens the browser for them.
                """),
            .bullets([
                "The version store is the **operating system's**, the same mechanism Apple's own apps use.",
                "Restoring an older version is an **ordinary edit** — `⌘Z` undoes it.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    // MARK: - Follow file

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Following a file that is still being written",
        summary: "Like `tail -f`: whatever gets appended shows up as it arrives.",
        keywords: ["tail", "follow", "log", "realtime"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `File ▸ Follow file (tail -f)` loads whatever appears at the end of the file and \
                scrolls along.
                """),
            .warning("""
                While following, the document becomes **read-only**. Typing while new text is \
                being loaded from disk means two writers fighting over one document, and the loser \
                is always what you just typed.
                """),
            .note("""
                The status bar reads **Following** the whole time, so minutes later you still know \
                why the file will not accept typing. Clicking the **read-only** segment states the \
                reason outright.

                Following belongs to the **tab that started it**, not to the window: open another \
                tab and keep typing, and new log lines still flow into their own tab without \
                touching the file you are editing.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    // MARK: - Printing

    static let printing = HelpTopic(
        id: "in-an",
        title: "Printing",
        summary: "Print through the standard macOS print dialog.",
        keywords: ["print", "paper", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Print")]),
            .paragraph("""
                It uses the system print dialog, so exporting to PDF happens there too — the `PDF` \
                button at the bottom left.
                """),
        ]
    )

    // MARK: - Non-text files

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Images, PDFs, Office files, audio, video and archives",
        summary: "Eight kinds of file open inside GEditor without another app.",
        keywords: ["image", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "archive",
                   "audio", "video", "mp3", "mp4"],
        blocks: [
            .table(
                headers: ["Kind", "What you can do"],
                rows: [
                    ["Images", "View, zoom, rotate; **animated images play** and can be paused"],
                    ["Audio", "Play, seek, change volume"],
                    ["Video", "Play, seek, full screen, picture-in-picture"],
                    ["PDF", "Read, search, **annotate**"],
                    ["Word · Excel · PowerPoint", "View **and edit** — `⌘S` writes straight back into the file"],
                    ["ZIP · TAR · GZ · XZ", "List entries and open each as a tab"],
                    ["7z · RAR and seven more formats", "The same, via libarchive"],
                ]
            ),
            .paragraph("""
                Opening an entry inside an archive creates a new tab with that entry's contents. \
                Vietnamese diacritics survive in both names and contents.
                """),
            .note("""
                Edit one of the three Office formats, press `⌘S`, and it is written back into the \
                file — LibreOffice reads the result. This path is tested end to end, not merely \
                exported to a copy.
                """),
            .heading("Audio and video use the macOS players"),
            .paragraph("""
                Playback goes through the system's own decoders, so nothing extra is downloaded \
                and nothing extra ships. In exchange, a few formats **will not play** — `.mkv`, \
                `.webm`, `.avi`, `.wmv` — because macOS has no built-in decoder for them.
                """),
            .paragraph("""
                For such a file GEditor **says why** instead of showing a black rectangle, and \
                offers the binary viewer or another app.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    // MARK: - PDF tools

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "PDF tools",
        summary: "Read, annotate, and a whole page layer: rotate · move · delete · extract · merge.",
        keywords: ["pdf", "page", "rotate", "delete page", "extract", "merge", "split",
                   "annotate", "highlight", "sign"],
        blocks: [
            .paragraph("""
                The PDF view has **two toolbars**, and they answer different questions. The top row \
                works on the **content** of one page; the bottom row works on the **set of pages**.
                """),
            .heading("Top row — reading and annotating"),
            .table(
                headers: ["Button", "What it does"],
                rows: [
                    ["Highlight · Underline", "Mark the selected text"],
                    ["Note…", "Attach a note to the page"],
                    ["Remove annotations", "Strip every annotation from the current page"],
                    ["Extract text to a new tab", "Move all the text into a tab so you can search, filter, run other tools"],
                    ["Search field", "Search inside the PDF — **typing without diacritics still finds accented text**"],
                ]
            ),
            .note("""
                A scanned PDF has no text layer. The extract command **says so** rather than \
                opening an empty tab and leaving you to guess.
                """),
            .heading("Bottom row — page operations"),
            .table(
                headers: ["Button", "What it does", "Undoable"],
                rows: [
                    ["Rotate left · right", "Turn the current page 90°", "Yes"],
                    ["Page up · Page down", "Swap the current page with its neighbour", "Yes"],
                    ["Delete pages…", "Delete by range, e.g. `2-4,7`", "Yes"],
                    ["Extract pages…", "Write a page range out as a **new file**", "Does not touch the open file"],
                    ["Merge a PDF…", "Insert another PDF right after the current page", "Yes"],
                    ["Sign…", "Place a signature image on the current page", "Yes"],
                    ["Edit text…", "Draw replacement text over the selection", "Yes"],
                    ["Next empty field", "Jump to the next unfilled form field", "—"],
                    ["Clear filled values", "Blank every form field", "Yes"],
                    ["Undo page change", "Step back one page operation", "—"],
                    ["Save the edited copy…", "Write a new file, then **reopen it to verify**", "—"],
                ]
            ),
            .heading("Fillable forms"),
            .paragraph("""
                Open a PDF with form fields and the status bar states **how many** there are. Type \
                directly into the fields on the page, then `Save the edited copy…`.
                """),
            .bullets([
                "Values are stored as **live form fields**, not flattened text — so the recipient's Acrobat still sees a filled-in form, and they can correct it.",
                "Vietnamese diacritics survive the write-and-reopen round trip. A test guards exactly that, with the name `Nguyễn Văn Anh`.",
                "`Next empty field` jumps to the next blank — the natural path through a long form.",
            ]),
            .heading("Signing"),
            .paragraph("""
                Prepare a signature image (a PNG with a transparent background works best), \
                **select the place to sign** — usually the ruled line or the words \"Signature\" — \
                then press `Sign…`. With nothing selected, the signature lands at the bottom right.
                """),
            .note("""
                The signature keeps the image's **aspect ratio**: a signature squashed or \
                stretched looks fake instantly.
                """),
            .heading("Editing text — and three things to know first"),
            .paragraph("""
                Select the text to change and press `Edit text…`. GEditor **covers that area with \
                a background colour sampled right beside it**, then draws the new text on top.
                """),
            .warning("""
                **The old text is COVERED, not REMOVED.** It is still in the file and still \
                extractable with `Extract text to a new tab` or any other tool. This is **not \
                redaction** — hiding an ID number this way hides it from a human eye, not from a \
                machine.
                """),
            .bullets([
                "**The new text is still findable with `⌘F`.** It is drawn as real text, not as an image — measured by a test, not assumed.",
                "**The font is a system font**, not the document's original. Deliberately: fonts embedded in a PDF often lack Vietnamese diacritics, and `Nguyễn` would arrive as `Nguy?n`.",
                "**On a patterned background the patch shows** — the cover colour is sampled from a single spot just left of the selection.",
            ]),
            .heading("Why draw over instead of editing the content stream"),
            .paragraph("""
                Editing a PDF content stream directly means dealing with subset fonts that carry \
                their own encoding, sentences broken into three fragments by kerning, and \
                character-width tables that must be recomputed. Doing it correctly for **every** \
                file is a project of its own; doing it wrongly corrupts somebody's document.
                """),
            .paragraph("""
                In exchange, the rest of the page **does not change by a single byte**, and the \
                page stays a page — text still selects, copies and searches. Redrawing does **not** \
                turn it into an image.
                """),
            .heading("Page range syntax"),
            .table(
                headers: ["Type", "Meaning"],
                rows: [
                    ["`5`", "Page 5 alone"],
                    ["`2-4`", "Pages 2, 3, 4"],
                    ["`-3`", "From the start to page 3"],
                    ["`8-`", "From page 8 to the end"],
                    ["`1-3,5,9-`", "Several parts joined by commas"],
                ]
            ),
            .paragraph("""
                Pages count **from 1**, the number you see on screen.
                """),
            .warning("""
                A reversed range (`5-2`) and a range past the end (`1-999`) are both **refused with \
                a reason**, never silently corrected into something close. For a delete-pages \
                command, guessing wrong means losing pages, and quietly clamping turns a typo into \
                a valid command.
                """),
            .heading("The original file is never overwritten"),
            .paragraph("""
                Everything above changes the document **in memory**. Only when you press `Save the \
                edited copy…` and choose a location does a file get written — and after writing, \
                GEditor **reopens that very file** to confirm it still has all its pages.
                """),
            .paragraph("""
                The reason: a badly written file sits on disk looking perfectly normal, and the \
                user finds out only after sending it.
                """),
            .note("""
                The view's status line reads **· edited, not saved** whenever the document differs \
                from the file on disk.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
