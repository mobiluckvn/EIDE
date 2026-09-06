import Foundation

extension HelpEN {

    static let views = HelpChapter(
        id: "xem",
        title: "Ways of viewing a document",
        summary: "Sidebar, map, folding, split view, wrapping, invisibles, colouring modes.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    // MARK: - Sidebar

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Sidebar and function list",
        summary: "The folder tree and the open file's function list, in one column.",
        keywords: ["sidebar", "function list", "outline", "file tree"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Show / hide the sidebar")]),
            .paragraph("""
                The function list is built from the language's **syntax tree**, so it follows the \
                real structure instead of guessing from indentation. Click an entry to jump there.
                """),
            .note("The filter box in the function list **finds accented text from unaccented typing**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    // MARK: - Document map

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Document map",
        summary: "The whole file in a narrow column on the right — even at hundreds of MB.",
        keywords: ["minimap", "map", "overview"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Show / hide the document map")]),
            .paragraph("""
                The map describes the **whole file**, not just what is on screen. Dragging on it \
                jumps to the matching region.
                """),
            .paragraph("""
                Search hits and marked lines appear on the map, so you can see whether they are \
                scattered or clustered before scrolling there.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    // MARK: - Folding

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Folding",
        summary: "Collapse functions, blocks and arrays by structure — or fold the file to a level.",
        keywords: ["fold", "code folding", "collapse"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Fold / unfold the block at the caret"),
                HelpShortcut("⌥⇧⌘←", "Fold all"),
                HelpShortcut("⌥⌘→", "Unfold all"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Fold the whole file to level 1…8"),
            ]),
            .paragraph("""
                For languages with a syntax tree, folding follows the **real structure**. For files \
                without a grammar it follows indentation.
                """),
            .paragraph("""
                `Fold to level` earns its keep on deep JSON and YAML: folding to level 2 puts the \
                shape of the whole file on one screen.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    // MARK: - Split view

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Split view",
        summary: "Two panes side by side, for two files — or two places in one file.",
        keywords: ["split", "panes", "compare"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Split vertically"),
                HelpShortcut("⌥⌘-", "Split horizontally"),
                HelpShortcut("⌥⌘0", "Remove the split"),
                HelpShortcut("⌥⌘]", "Open this tab in the other pane"),
                HelpShortcut("⌥⌘[", "Jump to the other pane"),
            ]),
            .paragraph("""
                Each pane has its own tab bar. Opening the **same file** in both panes is fine — \
                they scroll independently, which makes comparing the top and the bottom of a file \
                easy.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    // MARK: - Wrapping

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Word wrap",
        summary: "Three modes: off, at the window edge, or at a fixed column.",
        keywords: ["word wrap", "wrap", "soft wrap"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Mode", "A long line"],
                rows: [
                    ["Off", "Scrolls horizontally"],
                    ["At the window", "Wraps at the window edge, following its size"],
                    ["At a column", "Wraps at the column you set — 80 or 100, say"],
                ]
            ),
            .paragraph("""
                Wrapping is a **way of looking**, not an edit: no newline is inserted, and it never \
                enters the undo history.
                """),
            .note("""
                The quick way to reach this is the `Wrap: …` segment on the status bar.
                """),
        ]
    )

    // MARK: - Font size

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Font size",
        summary: "Zoom between 8 and 32 pt.",
        keywords: ["zoom", "font size", "larger", "smaller"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Larger text"),
                HelpShortcut("⌘-", "Smaller text"),
                HelpShortcut("⌃⌘0", "Back to the default size"),
            ]),
            .paragraph("""
                Clamped between 8 and 32 pt. This too is a **way of looking**: no edit, nothing in \
                the undo history. The default size lives in `Settings…`.
                """),
            .note("`⌘0` is NOT the default size — that key shows and hides the sidebar."),
            .seeAlso(["cai-dat"]),
        ]
    )

    // MARK: - Invisibles

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Showing invisible characters",
        summary: "Turn on one group at a time, because all of them at once is usually too much.",
        keywords: ["invisible", "whitespace", "nbsp", "zero width", "tab"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Show / hide all invisible characters")]),
            .paragraph("""
                Four groups switch on separately, because turning them all on at once buries the \
                content under a forest of dots.
                """),
            .table(
                headers: ["Group", "What it catches"],
                rows: [
                    ["Spaces", "Trailing spaces, inconsistent indentation"],
                    ["Tabs", "Files mixing TABs with spaces"],
                    ["Line endings", "Files mixing CRLF with LF"],
                    ["NBSP · zero-width · control", "Invisible characters from Word, from the web, from spreadsheets"],
                ]
            ),
            .warning("""
                The last group is the one that rescues people. A non-breaking space (NBSP) pasted \
                from a web page looks **exactly** like an ordinary space, yet it makes every string \
                comparison and every filter miss — and there is no way to see it without this \
                group on.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    // MARK: - Colouring modes

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV mode and Log mode",
        summary: "Two colouring schemes that replace syntax highlighting, for two kinds of data file.",
        keywords: ["csv mode", "log mode", "highlight", "columns", "log level"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV mode"),
            .paragraph("""
                Gives each column its own colour in the **text** view, so you can see which cell \
                has slipped a column without switching to the grid.
                """),
            .heading("Log mode"),
            .paragraph("""
                Colours by the **severity** it reads from the line: errors red, warnings amber, \
                while `debug` and `trace` are dimmed — they make up most of a log file, and \
                highlighting them dims the thing you are actually looking for.
                """),
            .paragraph("""
                `Filter log by level…` hides the levels you do not need at all.
                """),
            .note("""
                These two colour **instead of** syntax highlighting, not on top of it. A log file \
                has no syntax to colour, and two colour sources writing to the same byte range \
                leaves no predictable winner.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    // MARK: - Binary view

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Binary view",
        summary: "A hex table for any file — including a 1 GB one, opening almost instantly.",
        keywords: ["hex", "binary", "byte", "offset", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `View ▸ Binary view` shows every byte as a three-column table: **offset · hex · \
                text**. It works for **any** file on disk, not just images or video.
                """),
            .table(
                headers: ["Column", "Contents"],
                rows: [
                    ["Offset", "Byte position, in hexadecimal"],
                    ["Hex", "16 bytes per row, split after the eighth for easier counting"],
                    ["Text", "Printable ASCII bytes; everything else is a `.`"],
                ]
            ),
            .note("""
                The text column **does not decode UTF-8**. A Vietnamese letter takes two or three \
                bytes, so rendering it would push the text column out of line with the hex column — \
                and that alignment is the whole point of the column. To read accented text, use \
                the normal view.
                """),
            .heading("Large files"),
            .paragraph("""
                The file is **memory-mapped**, so opening a 1 GB file in binary view costs only \
                what you look at. Measured in the self-test suite: **under a millisecond**.
                """),
            .paragraph("""
                The view shows **one 4 MB window** at a time, and the top bar states which range \
                you are in. That is a limit of the system's table renderer, not of the reading: a \
                1 GB file is 62.5 million rows, and past a certain point rows start jumping around \
                while scrolling — and a hex table that jumps is useless.
                """),
            .heading("Jumping to a position"),
            .table(
                headers: ["Type in the offset box", "Meaning"],
                rows: [
                    ["`1F400`", "Hexadecimal — the default"],
                    ["`0x1F400`", "The same, with an explicit prefix"],
                    ["`#128000`", "Decimal, for when you have a byte count rather than a hex offset"],
                ]
            ),
            .bullets([
                "`‹` and `›` move to the previous / next window.",
                "**Copy selected rows** copies exactly what you see — with nothing selected it copies the whole window.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    // MARK: - Markdown preview

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown preview",
        summary: "Render Markdown as formatted text — and say plainly what it does not render.",
        keywords: ["markdown", "preview", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("""
                Rendered with the system's Markdown support: bold, italic, code, links, lists.
                """),
            .warning("""
                **No tables, and no syntax colouring inside code blocks.** The preview window says \
                so at its foot. Documents larger than **4 MB** are refused.
                """),
            .paragraph("""
                Need tables and charts in a document you can publish? That is what `.greport.md` \
                reports are for, not this preview.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    // MARK: - View / Code

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Two modes: View and Code",
        summary: "One key switches between the rendered form and the editable source, for every file type.",
        keywords: ["view", "code", "mode", "source", "rendered", "preview"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Switch between View and Code")]),
            .paragraph("""
                The control sits in the **bar just below the tab strip** — the same place for every \
                file type: a `View | Code` switch, then the name of that file's View mode \
                (\"Document pages\", \"Key–value tree\", \"Diagram\"…). A file with only one mode \
                greys the switch out and the bar states why. At the right edge sit each type's own \
                buttons: `.xlsx` has **Grid** (editable, written straight back), `.pptx` has \
                **Outline**.
                """),
            .note("""
                **Word and PowerPoint behave like a document reader.** Their View mode builds real \
                pages — correct fonts, sizes and colours, with images, tables, headers and footers \
                including page numbers. A page is **exactly as wide as the frame**, and zooms. \
                Excel is a deliberate exception: its View is an **editable spreadsheet**, because a \
                spreadsheet has no paper size until it is printed.
                """),
            .note("""
                In exchange, pages are **read-only** and render the **copy on disk**: edit in Code \
                without saving and the pages show the old version — the bar says so, with a \
                `Save and re-render` button.
                """),
            .heading("Definitions"),
            .bullets([
                "**Code** is the **editable source**. For a text file that is the text itself. For a binary file — PDF, image, audio, video — there is no textual source, so Code is the **bytes**, shown as hex.",
                "**View** is what gets **rendered** from Code. It may be prettier, shorter, or runnable — but it is always a consequence, never the original.",
            ]),
            .paragraph("""
                Saying *\"this type has no Code\"* about a PDF would be convenient, but wrong: the \
                bytes really are its source.
                """),
            .heading("Where editing happens"),
            .paragraph("""
                Editing happens in **Code**. There are exactly **two exceptions**, both because \
                editing in View is far more natural: **CSV grid cells** and **PDF form fields**. \
                Both write straight into the source, so no second copy appears to argue with.
                """),
            .heading("By file type"),
            .table(
                headers: ["File type", "View", "Code", "Edit in"],
                rows: [
                    ["CSV · TSV", "Grid", "Raw text", "**Both**"],
                    ["Excel `.xlsx`", "Grid of the open sheet", "That sheet as CSV", "**Both**"],
                    ["PDF", "Rendered pages", "Binary", "**Both** — annotations, form fields, pages"],
                    ["Markdown `.md`", "Rendered text", "Markdown source", "Code"],
                    ["Report `.greport.md`", "Report with queries run and charts drawn", "Source", "Code"],
                    ["JSON", "Key–value tree, foldable", "JSON source", "Code"],
                    ["XML · HTML", "Tag tree, foldable", "XML source", "Code"],
                    ["YAML", "Key–value tree by indentation", "YAML source", "Code"],
                    ["Diagrams `.mmd` · `.dot`", "The drawn diagram, filling the tab", "mermaid or DOT source", "Code"],
                    ["Word `.docx`", "Rendered document pages", "Extracted Markdown", "Code"],
                    ["PowerPoint `.pptx`", "Rendered slide pages", "Markdown outline", "Code"],
                    ["Log files", "Coloured by level, filterable", "Raw text", "Code"],
                    ["Images", "The image (animated ones play)", "Binary", "Read-only"],
                    ["Audio · video", "A player", "Binary", "Read-only"],
                    ["Archives", "Entry list", "Binary", "Read-only"],
                    ["Source code, plain text", "— none", "The text itself", "Code"],
                ]
            ),
            .note("""
                Source code has **no View**, and that is normal rather than a gap: a Swift file has \
                no rendered form worth looking at.
                """),
            .heading("The page reader for Word and PowerPoint"),
            .paragraph("""
                Pages stack vertically and scroll continuously, each a white sheet on a grey \
                background — like every document reader. Its controls sit at the right of the bar.
                """),
            .table(
                headers: ["Button / key", "What it does"],
                rows: [
                    ["`Fit width`", "The sheet is exactly as wide as the frame — the default"],
                    ["`Fit page`", "The whole sheet fits in the frame"],
                    ["`−` `+`", "Zoom by steps; or pinch, or ⌘ + scroll"],
                    ["The `Find` box, or ⌘F", "Search inside the pages, jump there and highlight"],
                    ["Enter in the find box", "Next match"],
                    ["Drag", "Select text; double-click for a word, triple-click for a paragraph"],
                    ["⌘A · ⌘C", "Select all · copy the selection"],
                    ["Page Up · Page Down · Home · End", "Move through the document"],
                ]
            ),
            .paragraph("""
                The find box **ignores diacritics and case**: typing `vuong quoc` finds `Vương \
                quốc`. The label \"Page 12/363\" in the bar tells you where you are.
                """),
            .note("""
                **What is not rendered, stated plainly:** floating anchored images (text wrapping \
                around a picture) appear as inline images; footnotes, charts and PowerPoint \
                SmartArt are not drawn. When you need an exact match with the printed copy, open \
                it in Word.
                """),
            .heading("Clicking a node jumps back to the source"),
            .paragraph("""
                A JSON tree is not a pretty printout: clicking a node moves the caret **to that \
                node's VALUE** in the text and returns the tab to Code — because what you want \
                next is almost always to edit what you just clicked.
                """),
            .bullets([
                "Container nodes show their **element count** (`{12}`, `[340]`) rather than their contents — that is what answers \"is this worth opening\".",
                "The **first two levels** are expanded: fully expanding a ten-thousand-node file produces a list longer than the source, while fully collapsing it means clicking to discover anything at all.",
                "A file with **invalid syntax** does not get half a tree — a truncated tree looks like a document that simply contains that little.",
                "In an XML tree, attributes carry an `@` prefix in proper XPath notation, and **whitespace between tags does not become a node** — it is formatting, not content.",
                "A YAML tree reads **multi-document files** (`---`): each document is its own root. Collections written inline (`ports: [80, 443]`) stay a single leaf — you can already see everything, and expanding costs a click. **Tab-based indentation** is reported with the exact line: that is a YAML error the eye cannot see.",
                "The PowerPoint outline is built from the **open text**, not from the file on disk: if you just edited the outline in Code, the tree must describe the new version and its nodes must jump into that new version. Presenter notes collapse into one node, so a slide that says a lot does not look like a slide that contains a lot.",
                "**A full-tab diagram follows the same rule**: click a node and you are back in Code with the caret on that node's declaration. In the side-by-side `Mermaid Studio` panel the tab does not close — the editor is right there, and moving the caret is enough to see it.",
                "Diagrams also **open where you are standing**: the element matching the caret's line is highlighted the moment the tab appears, so you do not have to hunt for it.",
            ]),
            .heading("The filter box: in a ten-thousand-node tree, searching is the job"),
            .paragraph("""
                Just below the node count sits a filter box. Type in it and the tree keeps only \
                matching nodes — **together with the path from the root down to them**, because \
                when a key `name` appears in ten different places the real question is \"which \
                one\", and only the branch containing it answers that. The rest is expanded for \
                you: making you click open each level is making you filter again by hand.
                """),
            .bullets([
                "It filters on **both labels and values**: searching `Huế` is as common as searching for the key `province`.",
                "**Unaccented typing still matches accented text** — `da nang` finds `Đà Nẵng`. The same comparison as the CSV grid's filter and the function list's, so you do not have to remember three search rules in one app.",
                "With no match, the header says **\"No results\"** rather than leaving you staring at an empty tree wondering whether the file is broken.",
                "Switching files or re-entering View **clears the filter**: a tree that opens already truncated, with nothing explaining why, is the most confusing state of all.",
            ]),
            .heading("The whole tree works from the keyboard"),
            .paragraph("""
                Entering View moves focus to the tree; you do not have to click it first. Up and \
                down move between nodes, left and right fold and unfold, and two keys end a \
                viewing session — doing **different** things:
                """),
            .bullets([
                "**Enter** — go to the selected node: back to Code with the caret inside that node's byte range. Exactly like clicking it.",
                "**Tab** — move between the tree and the filter box.",
                "**⌘C** — copies the selected node's **path**, not the text behind the tree. JSON and YAML produce JSONPath (`$.customer['name']`) that pastes straight into this product's own JSONPath query box, or into `yq`; XML produces XPath (`/order/item[2]/@code`) with indices when two tags share a name; a PowerPoint outline copies the line's text, because an outline has no path language to invent.",
                "**Esc** — the way back: return to Code with the caret **exactly where it was**. You were looking at a tree, not travelling somewhere.",
            ]),
            .heading("And the other direction: the tree opens where the caret stands"),
            .paragraph("""
                Entering View from the middle of a ten-thousand-line file does **not** open the \
                tree at the top: it expands the path down to the node matching where the caret was, \
                and selects it. This is the other half of jump-to-source — without it, View and \
                Code would be two views of one document in only **one** direction.
                """),
            .bullets([
                "It expands **deeper than two levels** when needed: the two-level rule answers \"what does this file look like\", while here the question is different — \"where am I in this tree\".",
                "A caret on a **key** (`\"address\":`) selects that entry, even though the node's byte range covers only the value. Text immediately before a node belongs to that node.",
                "A caret at the **start of a block** — a YAML block's key, a slide title, an XML tag name — selects that block rather than diving to its first child.",
                "Entering View **does not move the caret**. Leave View and you are exactly where you were; View is a way of looking, not a command that changes position.",
            ]),
            .heading("No type is missing a View any more"),
            .paragraph("""
                **Every file type with room for a View mode now renders one.** The list of missing \
                types became empty and was removed.

                Source code and plain text still have no View — that is normal, not a gap, so they \
                were never on that list.

                If a new file type arrives whose View is not built yet, the switch command will say \
                so and name what is missing, rather than opening an empty frame — an empty frame is \
                an empty promise, while a refusal with a name is information.
                """),
            .heading("The six older commands are still there"),
            .paragraph("""
                `Grid / text view`, `Markdown preview`, `Binary view`, `Report preview`, \
                `Mermaid diagram preview`, `Log mode` — all of them stay exactly where they were. \
                `⌥⌘V` is a **shared entrance**, not a replacement.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )
}
