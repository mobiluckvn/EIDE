import Foundation

extension HelpEN {

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamese",
        summary: "Legacy encodings, Unicode normalisation, accent-insensitive search, and input methods.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    // MARK: - Encodings

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnamese encodings",
        summary: "Read and write TCVN3, VISCII, VNI-Windows and 33 others, detected automatically.",
        keywords: ["encoding", "tcvn3", "abc", "viscii", "vni", "mojibake", "broken font"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Opened an old Vietnamese file and got `Tr¦êng §¹i häc` instead of `Trường Đại \
                học`? The file is not corrupt — it was saved in a pre-Unicode encoding.
                """),
            .steps([
                "Click the encoding on the **status bar** (or `Format ▸ Encoding…`).",
                "Pick the right one — for old Vietnamese files that is usually `TCVN3 (ABC)`, `VNI-Windows` or `VISCII`.",
                "The text corrects itself immediately; there is no need to reopen the file.",
                "To keep it that way, `Save As…` with the `UTF-8` encoding.",
            ]),
            .heading("The three legacy Vietnamese encodings"),
            .table(
                headers: ["Encoding", "Usually found in"],
                rows: [
                    ["TCVN3 (ABC)", "Government paperwork and older Word documents in the north"],
                    ["VNI-Windows", "Publishing, newspapers and print shops — common in the south"],
                    ["VISCII", "Early email and Usenet"],
                ]
            ),
            .paragraph("""
                GEditor **detects the encoding** on open. When it guesses wrong, one click fixes \
                it, and the content is decoded again rather than patched letter by letter.
                """),
            .warning("""
                Writing out to a legacy encoding loses characters that encoding does not have. \
                GEditor **counts them and tells you first** — for example *"12 characters are not \
                in TCVN3"* — instead of silently turning them into question marks.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    // MARK: - Line endings

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Line endings",
        summary: "LF, CRLF, CR — converted for the whole file with one click.",
        keywords: ["eol", "crlf", "lf", "line ending", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Style", "Used by", "Bytes"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac before 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                The current style shows on the status bar; click it to change. A file that **mixes** \
                two styles is reported there too — turn on `Show invisibles ▸ Line endings` to see \
                exactly where.
                """),
            .note("""
                The line-ending style for **new** files is set in `Settings…`.
                """),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    // MARK: - Unicode normalisation

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode normalisation",
        summary: "Why searching for «ế» sometimes finds nothing, and how to fix a whole file.",
        keywords: ["unicode", "nfc", "nfd", "composed", "decomposed", "normalise", "no matches"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                In Unicode, `ế` can be written **two different ways**: as one precomposed code \
                point (NFC), or as `e` plus two separate marks (NFD). On screen they look \
                identical; to a machine they are different strings.
                """),
            .paragraph("""
                The consequence: searching for `ế` in an NFD file finds **nothing**, and the user \
                concludes the data is not there.
                """),
            .steps([
                "`Format ▸ Normalise Unicode…`",
                "Choose **NFC** (precomposed) — the form almost everything else uses.",
                "Apply. It is a single undo step.",
            ]),
            .note("""
                Files that come from macOS are often NFD, because Apple's file system stores file \
                names that way. This is the single most common reason data copied out of Finder \
                cannot be found again.
                """),
            .paragraph("""
                There is a **normalise to NFC on save** switch in `Settings…`. Off by default, \
                because it changes the file's bytes.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    // MARK: - Accent-insensitive search

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Typing without diacritics still finds accented text",
        summary: "Every search and filter box compares with the accents stripped.",
        keywords: ["diacritics", "accents", "search", "filter", "unaccented"],
        blocks: [
            .paragraph("""
                Type `hue` to find `Huế`. Type `da nang` to find `Đà Nẵng`. The rule applies to the \
                CSV grid filter, the function search, the help search and the other filter boxes.
                """),
            .note("""
                `Đ` is handled specially, because in Unicode it is **a letter of its own** rather \
                than a `D` carrying a mark — ordinary accent stripping does not touch it.
                """),
            .paragraph("""
                The CSV filter also accepts an `=` prefix for exact comparison. The `=` form is \
                **also accent-insensitive**, because a filter that distinguishes diacritics leaves \
                the user believing the data is missing.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    // MARK: - Input methods

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnamese input methods",
        summary: "EVKey, OpenKey, Unikey and the macOS input source all type straight into the document.",
        keywords: ["ime", "evkey", "unikey", "openkey", "telex", "vni", "input method"],
        blocks: [
            .paragraph("""
                Nothing to configure. Telex and VNI both work, including across **multiple carets** \
                — type once and every caret receives the correctly accented letter.
                """),
            .paragraph("""
                Search boxes, filter boxes and every dialog accept the input method just as the \
                editor does.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )
}
