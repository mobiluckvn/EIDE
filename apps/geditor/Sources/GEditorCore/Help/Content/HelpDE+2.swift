import Foundation

/// Deutscher Hilfeinhalt — Teil 2: Suchen, Dateien und Sitzungen.
extension HelpDE {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Suchen",
        summary: "Suchen, Ersetzen, reguläre Ausdrücke, ordnerweite Suche und Zeilenmarken.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Suchen und Ersetzen",
        summary: "Drei Suchmodi, und warum ^ standardmäßig ZEILENanfang bedeutet.",
        keywords: ["suchen", "ersetzen", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Suchen"),
                HelpShortcut("⌥⌘F", "Suchen und Ersetzen"),
                HelpShortcut("⌘G / ⇧⌘G", "Nächster / vorheriger Treffer"),
            ]),
            .heading("Drei Modi"),
            .table(
                headers: ["Modus", "Versteht", "Für"],
                rows: [
                    ["Normal", "Reinen Text, gar keine Sonderzeichen", "Die meisten Suchen"],
                    ["Erweitert", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Umbrüche, Tabulatoren, bestimmte Bytes finden"],
                    ["Regex", "Volles PCRE2", "Nach Muster suchen"],
                ]
            ),
            .note("""
                Der **erweiterte** Modus versteht keine Regex-Syntax. Er löst nur einige \
                Escape-Folgen auf — dort nach `a.b` zu suchen findet genau diese drei Zeichen; der \
                Punkt ist kein Platzhalter.
                """),
            .heading("Zwei Schalter"),
            .bullets([
                "**Groß-/Kleinschreibung beachten** — standardmäßig aus.",
                "**Ganzes Wort** — trifft nur, wenn beide Enden Wortgrenzen sind.",
            ]),
            .heading("`^` und `$` treffen an den Rändern jeder ZEILE"),
            .paragraph("""
                Standardmäßig an. Wer von Notepad++ kommt, erwartet, dass `^` „Zeilenanfang“ heißt; \
                ohne das würde `^abc` nur treffen, wenn das ganze Dokument mit `abc` begänne — das \
                will in einem Texteditor fast niemand.
                """),
            .heading("Ein schlechter Ausdruck hängt die App nicht auf"),
            .paragraph("""
                Die Maschine ist **PCRE2 mit JIT-Kompilierung** und hat ein Rücksetzbudget. Ein \
                Muster, das kombinatorisch explodiert, wird gestoppt und gemeldet, statt das Fenster \
                einzufrieren.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Reguläre Ausdrücke",
        summary: "Die PCRE2-Syntax, die man wirklich braucht, mit Beispielen auf vietnamesischen Daten.",
        keywords: ["regex", "pcre", "muster"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor nutzt **PCRE2**, dieselbe Maschine wie PHP und viele Kommandozeilenwerkzeuge. \
                Öffnen Sie `Suchen ▸ Regulären Ausdruck testen…`, um ein Muster an Beispieltext zu \
                erproben und zu sehen, was jede Gruppe erfasst, **bevor** Sie es auf ein echtes \
                Dokument anwenden.
                """),
            .heading("Zeichenklassen"),
            .table(
                headers: ["Schreiben", "Trifft"],
                rows: [
                    ["`.`", "Jedes Zeichen außer einem Zeilenumbruch"],
                    ["`\\d` · `\\D`", "Eine Ziffer · keine Ziffer"],
                    ["`\\w` · `\\W`", "Ein Wortzeichen (Buchstabe, Ziffer, `_`) · das Gegenteil"],
                    ["`\\s` · `\\S`", "Leerraum · kein Leerraum"],
                    ["`[abc]`", "Eines der Zeichen in den Klammern"],
                    ["`[^abc]`", "Ein Zeichen, das NICHT in den Klammern steht"],
                    ["`[a-z]`", "Ein Zeichen aus dem Bereich"],
                ]
            ),
            .heading("Wiederholung"),
            .table(
                headers: ["Schreiben", "Bedeutung"],
                rows: [
                    ["`*`", "Null oder mehr"],
                    ["`+`", "Eins oder mehr"],
                    ["`?`", "Null oder eins"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Genau 3 · zwischen 2 und 5 · 2 oder mehr"],
                    ["`*?` `+?` `??`", "Die **genügsamen** Formen — so wenig wie möglich nehmen"],
                ]
            ),
            .warning("""
                `.*` ist **gierig**: es frisst bis zum Zeilenende und weicht dann zurück. Wenn Sie \
                Felder innerhalb einer Zeile trennen, brauchen Sie fast immer `.*?` oder eine enge \
                Zeichenklasse wie `[^,]*`.
                """),
            .heading("Anker und Gruppen"),
            .table(
                headers: ["Schreiben", "Bedeutung"],
                rows: [
                    ["`^` · `$`", "Zeilenanfang · Zeilenende"],
                    ["`\\b`", "Wortgrenze"],
                    ["`(…)`", "Eine **erfassende** Gruppe — im Ersatz wiederverwendbar"],
                    ["`(?:…)`", "Nicht erfassende Gruppe"],
                    ["`(?<name>…)`", "Benannte Gruppe"],
                    ["`a|b`", "a oder b"],
                    ["`(?=…)` · `(?!…)`", "Vorausschau: muss folgen · darf nicht folgen"],
                    ["`(?<=…)` · `(?<!…)`", "Rückschau: muss vorangehen · darf nicht vorangehen"],
                ]
            ),
            .heading("Beispiele, die laufen"),
            .code(language: "regex", caption: "Jede zehnstellige vietnamesische Telefonnummer",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Ein Datum wie 31/12/2026 in drei Gruppen zerlegen",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "Die dritte Zelle einer einfachen CSV-Zeile (ohne Anführungszeichen)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Protokollzeilen mit ERROR oder FATAL, samt Zeitstempel",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Leere Zeilen oder Zeilen mit nur Leerraum",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Akzentuierte vietnamesische Buchstaben — die Unicode-Klasse nehmen, nicht aufzählen",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` heißt „jeder Unicode-Buchstabe“, trifft also auch `ế` und `đ`. Jeden \
                akzentuierten Vokal von Hand aufzuzählen ist der sichere Weg, welche zu übersehen.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Ersetzungszeichenketten",
        summary: "Erfasste Gruppen wiederverwenden und beim Ersetzen die Schreibweise ändern.",
        keywords: ["ersetzen", "rückverweis", "gruppe", "$1", "\\U"],
        blocks: [
            .heading("Eine erfasste Gruppe zurückrufen"),
            .table(
                headers: ["Schreiben", "Bedeutung"],
                rows: [
                    ["`$1` … `$9`", "Der Inhalt von Gruppe n"],
                    ["`${1}`", "Dasselbe mit klaren Grenzen — nötig, wenn eine Ziffer folgt"],
                    ["`\\1`", "Wird ebenfalls angenommen; GEditor schreibt es als `${1}`"],
                    ["`$0`", "Der ganze Treffer"],
                ]
            ),
            .note("""
                Schreiben Sie `${1}` statt `$1`, wenn das nächste Zeichen eine Ziffer ist. `$123` \
                liest sich als Gruppe 123; `${1}23` ist Gruppe 1 gefolgt von zwei Ziffern.
                """),
            .heading("Die Schreibweise beim Ersetzen ändern"),
            .table(
                headers: ["Schreiben", "Bedeutung"],
                rows: [
                    ["`\\U`", "Ab hier GROSSBUCHSTABEN"],
                    ["`\\L`", "Ab hier kleinbuchstaben"],
                    ["`\\u`", "Nur das nächste Zeichen groß"],
                    ["`\\l`", "Nur das nächste Zeichen klein"],
                    ["`\\E`", "Ende des `\\U`- oder `\\L`-Bereichs"],
                ]
            ),
            .heading("Beispiele"),
            .code(language: "text", caption: "Aus 31/12/2026 wird 2026-12-31",
                  source: """
                    Suchen:   (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Ersetzen: $3-$2-$1
                    """),
            .code(language: "text", caption: "Den Provinzcode am Zeilenanfang großschreiben, den Rest behalten",
                  source: """
                    Suchen:   ^([a-z]{2,3})(\\s)
                    Ersetzen: \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Jede Zeile als JSON-Zeichenkette einfassen",
                  source: """
                    Suchen:   ^(.+)$
                    Ersetzen: "$1",
                    """),
            .paragraph("""
                Eine Gruppe, die am Treffer **nicht beteiligt** war, wird zur leeren Zeichenkette, \
                nicht zum Fehler — ein Muster mit Alternativen wie `(a)|(b)` ersetzt also sauber, \
                ohne es zweimal zu schreiben.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Suchen und Ersetzen über einen Ordner",
        summary: "Viele Dateien auf einmal durchsuchen und die Ergebnisse sehen, bevor etwas geschrieben wird.",
        keywords: ["dateisuche", "grep", "massenersetzung", "ordner"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "In einem Ordner suchen")]),
            .paragraph("""
                Wählen Sie den Wurzelordner, filtern Sie nach Dateinamensmuster und starten Sie den \
                Durchlauf. Die Ergebnisse erscheinen nach Datei gruppiert; ein Klick auf eine Zeile \
                öffnet diese Datei an dieser Stelle.
                """),
            .bullets([
                "Dieselben drei Suchmodi und dieselbe Regex-Maschine wie das Suchfeld im Dokument.",
                "Ersetzen über einen Ordner **zeigt vorab**, wie viele Dateien und wie viele Treffer sich ändern werden, bevor geschrieben wird.",
                "Der Durchlauf läuft parallel und **lässt sich unterwegs abbrechen**.",
            ]),
            .warning("""
                Ersetzen über einen Ordner schreibt direkt in Dateien, die **nicht geöffnet** sind. \
                Diese Dateien stehen nicht im Widerrufsverlauf des offenen Dokuments — sehen Sie \
                zuerst die Vorschau an und halten Sie eine Sicherung oder ein versioniertes \
                Repository bereit.
                """),
            .heading("Frühere Suchen und Ergebnisse exportieren"),
            .paragraph("""
                Das Ergebnisfenster **behält die Suchen dieser Sitzung**. Das Einblendmenü oben \
                listet sie samt Trefferzahl — suchen Sie `TODO`, lesen Sie halb durch, suchen Sie \
                `FIXME` zum Vergleich und kehren Sie zur ersten Liste zurück, ohne den ganzen Ordner \
                neu zu durchsuchen.
                """),
            .paragraph("""
                Die Taste **Exportieren** öffnet die aktuelle Suche als Text-Tab, ein Ergebnis je \
                Zeile als `pfad:zeile:spalte: text` — die Form, die `grep -n` nutzt und die \
                Compiler für Fehler verwenden. Jede Zeile lässt sich direkt in das eigene `Gehe \
                zu`-Feld dieses Produkts einsetzen, und Ihre `grep`, `awk` und `sed` lesen sie ohne \
                eigenen Parser.
                """),
            .note("""
                Der Verlauf liegt im **Arbeitsspeicher** und wird nie auf die Festplatte geschrieben: \
                Suchergebnisse tragen den Inhalt jeder Trefferzeile, also dieselbe Datenklasse, die \
                der Verlauf der Zwischenablage bewusst nicht dauerhaft speichert.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Zeilenmarken",
        summary: "Neun Markenfarben und vier Befehle, die markierte Zeilen zu einem Ergebnis machen.",
        keywords: ["lesezeichen", "marke", "f2", "zeilen filtern"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Markieren ist die Art, ein Dokument zu filtern, **ohne es zu ändern**. Markieren Sie \
                jede Zeile, die einem Muster entspricht, und kopieren Sie dann nur diese heraus, oder \
                behalten Sie nur sie.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Jede Zeile markieren, die der aktuellen Suche entspricht"),
                HelpShortcut("⌘F2", "Aktuelle Zeile markieren / Markierung entfernen"),
                HelpShortcut("F2 / ⇧F2", "Zur nächsten / vorherigen Marke springen"),
            ]),
            .heading("Ein üblicher Ablauf"),
            .steps([
                "`⌘F` für das Muster, nach dem Sie filtern wollen, z. B. `\\bERROR\\b`.",
                "`⌘M` markiert jede Trefferzeile.",
                "`Suchen ▸ Markierte Zeilen kopieren` zieht sie in einen neuen Tab — oder `Nur markierte Zeilen behalten` filtert an Ort und Stelle.",
            ]),
            .heading("Neun Farben"),
            .paragraph("""
                Eine Zeile kann **mehrere Farben zugleich** tragen. Nutzen Sie verschiedene Farben für \
                verschiedene Kriterien und kombinieren Sie sie: Rot für Fehlerzeilen, Gelb für Zeilen \
                zu einer Bestellnummer, und suchen Sie dann Zeilen, die beides tragen.
                """),
            .bullets([
                "`Marken umkehren` — markierte Zeilen werden unmarkiert und umgekehrt.",
                "`Alle Marken löschen` — entfernt jede Marke, ohne den Inhalt anzurühren.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Gehe zu Zeile",
        summary: "Zu einer Zeile, einer Spalte oder einer Byteposition springen.",
        keywords: ["gehe zu", "zeilennummer", "cmd+l", "position", "spalte"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Gehe zu Zeile")]),
            .paragraph("""
                Das Feld versteht **drei Schreibweisen** und unterscheidet sie an dem, was Sie tippen \
                — es gibt keinen zusätzlichen Umschalter zum Anklicken.
                """),
            .table(
                headers: ["Tippen", "Geht zu"],
                rows: [
                    ["`120`", "den Anfang von Zeile 120"],
                    ["`120,5` oder `120:5`", "Zeile 120, Spalte 5 — die Spalte zählt ZEICHEN"],
                    ["`@1024`", "Byteposition 1024 in der Datei"],
                ]
            ),
            .note("""
                `zeile:spalte` ist genau die Art, wie Compiler und Linter eine Position ausgeben: \
                eine gerade aus dem Terminal kopierte Zeile lässt sich direkt einsetzen.

                Das `@` für Bytepositionen hat einen Grund: ist `1234` eine Zeile oder ein Byte? Es \
                gibt keine richtige Antwort, und falsch zu raten schickt den Cursor völlig woandershin \
                — ohne jedes Signal. Diese Bytezahl zeigt auch die Statusleiste im Positionssegment \
                (`@1024`): was Sie dort lesen, können Sie hier tippen.
                """),
            .bullets([
                "Eine Spalte **jenseits der Zeilenlänge** hält am Zeilenende an; sie läuft nicht in die nächste Zeile über.",
                "Eine Byteposition **jenseits der Datei** bringt Sie ans Ende — diese Zahl stammt meist aus einem früheren Lauf, und die Datei kann geschrumpft sein.",
                "Nicht lesbarer Text wird **gemeldet**, und der Cursor bleibt stehen; er springt nicht an den Dateianfang.",
            ]),
            .paragraph("""
                Bei sehr großen Dateien liest GEditor nicht die ganze Datei, um dorthin zu kommen — \
                der Zeilenindex wird schrittweise im Hintergrund aufgebaut.
                """),
            .note("""
                Das Kommandozeilenwerkzeug nimmt ebenfalls eine Position: `geditor report.csv:120:5` \
                öffnet die Datei mit dem Cursor in Zeile 120, Spalte 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Dateien und Sitzungen

    static let files = HelpChapter(
        id: "tep",
        title: "Dateien und Sitzungen",
        summary: "Öffnen, Sichern, Tabs, Fenster, Arbeitsbereiche, und wie die Sitzung zurückkommt.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Öffnen und Sichern",
        summary: "Eine Datei jeder Größe öffnen und mit anderer Kodierung oder anderem Zeilenende sichern.",
        keywords: ["öffnen", "sichern", "duplizieren", "umbenennen", "bewegen"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Neues Dokument"),
                HelpShortcut("⌘O", "Datei öffnen"),
                HelpShortcut("⌘S", "Sichern"),
                HelpShortcut("⇧⌘S", "Sichern unter"),
            ]),
            .paragraph("""
                Eine Datei ins Fenster zu ziehen öffnet sie ebenfalls. `Ablage ▸ Benutzte Dokumente` \
                behält die Liste der Dateien, an denen Sie gerade gearbeitet haben.
                """),
            .heading("Sichern unter: drei Dinge, die sich ändern lassen"),
            .table(
                headers: ["Änderung", "Bedeutung"],
                rows: [
                    ["Kodierung", "UTF-8, TCVN3, VNI-Windows… schreiben — 36 Kodierungen"],
                    ["Zeilenenden", "LF (Unix) · CRLF (Windows) · CR (klassischer Mac)"],
                    ["Name und Ort", "Wie in jedem macOS-Sicherndialog"],
                ]
            ),
            .paragraph("""
                Die Statusleiste zeigt stets Kodierung, Zeilenendenstil und erkannte Sprache. **Ein \
                Klick auf eines davon ändert es sofort**, ohne Dialog.
                """),
            .heading("Duplizieren · umbenennen · bewegen"),
            .paragraph("""
                Diese drei wirken auf die DATEI statt auf ihren Inhalt — und der offene Tab folgt der \
                Datei, sodass Sie nie Ihren Platz verlieren.
                """),
            .table(
                headers: ["Befehl", "Was er tut"],
                rows: [
                    ["`Datei duplizieren`",
                     "Kopiert sie als `name 2.txt` neben das Original und **öffnet die Kopie** — denn man dupliziert, um die Kopie zu bearbeiten"],
                    ["`Datei umbenennen…`", "Benennt auf der Festplatte um; der Tab folgt dem neuen Namen"],
                    ["`Datei bewegen nach…`", "Bewegt in einen anderen Ordner; der Tab folgt"],
                ]
            ),
            .note("""
                Alle drei **lehnen ab, wenn am Ziel bereits eine Datei dieses Namens existiert**; sie \
                überschreiben nie. Und alle drei brauchen eine mindestens einmal gesicherte Datei — \
                ein Dokument, das nie auf der Festplatte lag, hat nichts zu duplizieren oder zu \
                bewegen.
                """),
            .heading("Sicheres Schreiben"),
            .bullets([
                "Das Schreiben ist **atomar**: ein Stromausfall mittendrin hinterlässt nie eine abgeschnittene Datei.",
                "Ändert ein anderes Programm die Datei, während Sie sie offen haben, merkt GEditor es und fragt vor dem Überschreiben.",
                "Dateien auf iCloud Drive oder einem Netzlaufwerk laufen über den Dateikoordinator des Systems, damit zwei Maschinen sich nicht ins Gehege kommen.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Tabs, Fenster und geteilte Ansicht",
        summary: "Viele Tabs je Fenster, viele Fenster, und Tabs, die sich dazwischen ziehen lassen.",
        keywords: ["tab", "fenster", "teilen", "bereich"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Neuer Tab"),
                HelpShortcut("⌘W", "Tab schließen"),
                HelpShortcut("⇧⌘T", "Zuletzt geschlossenen Tab wieder öffnen"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Nächster / vorheriger Tab"),
                HelpShortcut("⌥⌘N", "Neues Fenster"),
                HelpShortcut("⌃⌘N", "Aktuellen Tab in ein eigenes Fenster lösen"),
            ]),
            .paragraph("""
                Sie können einen Tab in ein anderes Fenster ziehen oder ihn auf leeren Raum fallen \
                lassen, um ein neues Fenster zu erzeugen. **Ein angehefteter Tab reist nicht** — \
                Anheften heißt „behalte diesen hier“.
                """),
            .note("""
                `⇧⌘T` öffnet den zuletzt geschlossenen Tab wieder, auch einen **ungesicherten**: sein \
                Inhalt ist noch da.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Einen Ordner als Arbeitsbereich öffnen",
        summary: "Ein Dateibaum in der Seitenleiste, projektweite Suche und Öffnen mit einem Klick.",
        keywords: ["arbeitsbereich", "ordner", "projekt", "seitenleiste"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Einen Ordner als Arbeitsbereich öffnen")]),
            .paragraph("""
                Der Baum erscheint in der Seitenleiste (`⌘0`). Klicken Sie eine Datei zum Öffnen, und \
                `⇧⌘F` durchsucht den ganzen Ordner.
                """),
            .note("""
                In der App-Store-Fassung hält ein **sicherheitsbereichs-Lesezeichen** den Zugriff auf \
                den Ordner, sodass der nächste Start ihn noch erreicht, ohne Sie erneut um die \
                Ordnerauswahl zu bitten.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "Die Sitzung stellt sich selbst wieder her",
        summary: "Beenden und wieder öffnen: jeder Tab kommt zurück, auch ungesicherte.",
        keywords: ["sitzung", "wiederherstellen", "ungesichert"],
        blocks: [
            .paragraph("""
                Nichts einzuschalten. Beenden Sie GEditor und öffnen Sie ihn wieder: Tabs, ihre \
                Reihenfolge, Cursor- und Bildlaufpositionen kommen alle zurück.
                """),
            .heading("Was ist mit ungesicherten Tabs"),
            .paragraph("""
                Ihr Inhalt liegt in einer eigenen Momentaufnahme, also kommen auch sie zurück. Endet \
                die App unnormal, **fragt** der nächste Start, bevor verwaiste Entwürfe \
                wiederhergestellt werden — statt still einen Stapel Tabs aufzubauen, an den Sie sich \
                nicht erinnern.
                """),
            .warning("""
                Eine Sitzung ist **keine Sicherung**. Sie bewahrt den Arbeitszustand, nicht den \
                Verlauf. Alles, was zählt, muss weiterhin in eine Datei gesichert werden.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Zuvor gesicherte Versionen",
        summary: "Ältere Versionen einer Datei durchsehen und wiederherstellen.",
        keywords: ["versionen", "verlauf", "wiederherstellen", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Bei jedem Sichern hält GEditor die **vorherige** Version fest, bevor er überschreibt. \
                `Makro ▸ Gesicherte Versionen…` öffnet den Browser dafür.
                """),
            .bullets([
                "Der Versionsspeicher ist der des **Betriebssystems**, derselbe Mechanismus, den Apples eigene Apps nutzen.",
                "Eine ältere Version wiederherzustellen ist eine **gewöhnliche Bearbeitung** — `⌘Z` macht sie rückgängig.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Eine Datei verfolgen, die noch geschrieben wird",
        summary: "Wie `tail -f`: was angehängt wird, erscheint, sobald es kommt.",
        keywords: ["tail", "verfolgen", "protokoll", "echtzeit"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Ablage ▸ Datei verfolgen (tail -f)` lädt, was am Dateiende erscheint, und rollt mit.
                """),
            .warning("""
                Während des Verfolgens wird das Dokument **schreibgeschützt**. Tippen, während neuer \
                Text von der Festplatte geladen wird, heißt zwei Schreiber streiten um ein Dokument, \
                und der Verlierer ist immer das, was Sie gerade getippt haben.
                """),
            .note("""
                Die Statusleiste zeigt die ganze Zeit **Wird verfolgt**, sodass Sie Minuten später \
                noch wissen, warum die Datei keine Eingabe annimmt. Ein Klick auf das Segment \
                **Schreibgeschützt** nennt den Grund unverblümt.

                Das Verfolgen gehört dem **Tab, der es gestartet hat**, nicht dem Fenster: öffnen Sie \
                einen anderen Tab und tippen Sie weiter, so fließen neue Protokollzeilen weiterhin in \
                ihren eigenen Tab, ohne die Datei zu berühren, die Sie bearbeiten.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Drucken",
        summary: "Drucken über den Standard-Druckdialog von macOS.",
        keywords: ["drucken", "papier", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Drucken")]),
            .paragraph("""
                Es nutzt den Druckdialog des Systems, also geschieht auch der PDF-Export dort — die \
                Taste `PDF` unten links.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Bilder, PDFs, Office-Dateien, Audio, Video und Archive",
        summary: "Acht Dateiarten öffnen sich in GEditor ohne eine weitere App.",
        keywords: ["bild", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "archiv",
                   "audio", "video"],
        blocks: [
            .table(
                headers: ["Art", "Was Sie tun können"],
                rows: [
                    ["Bilder", "Ansehen, zoomen, drehen; **animierte Bilder laufen** und lassen sich anhalten"],
                    ["Audio", "Abspielen, spulen, Lautstärke ändern"],
                    ["Video", "Abspielen, spulen, Vollbild, Bild-im-Bild"],
                    ["PDF", "Lesen, suchen, **kommentieren**"],
                    ["Word · Excel · PowerPoint", "Ansehen **und bearbeiten** — `⌘S` schreibt direkt in die Datei zurück"],
                    ["ZIP · TAR · GZ · XZ", "Einträge auflisten und jeden als Tab öffnen"],
                    ["7z · RAR und sieben weitere Formate", "Dasselbe, über libarchive"],
                ]
            ),
            .paragraph("""
                Einen Archiveintrag zu öffnen erzeugt einen neuen Tab mit seinem Inhalt. \
                Vietnamesische Akzente überleben in Namen wie Inhalten.
                """),
            .note("""
                Bearbeiten Sie eines der drei Office-Formate, drücken Sie `⌘S`, und es wird in die \
                Datei zurückgeschrieben — LibreOffice liest das Ergebnis. Dieser Weg ist \
                durchgehend getestet, nicht bloß in eine Kopie exportiert.
                """),
            .heading("Audio und Video nutzen die macOS-Abspieler"),
            .paragraph("""
                Die Wiedergabe läuft über die Decoder des Systems, also wird nichts zusätzlich \
                geladen und nichts zusätzlich mitgeliefert. Dafür **spielen einige Formate nicht** — \
                `.mkv`, `.webm`, `.avi`, `.wmv` — weil macOS keinen eingebauten Decoder dafür hat.
                """),
            .paragraph("""
                Für eine solche Datei **sagt GEditor, warum**, statt ein schwarzes Rechteck zu zeigen, \
                und bietet die Binäransicht oder eine andere App an.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "PDF-Werkzeuge",
        summary: "Lesen, kommentieren, und eine ganze Seitenebene: drehen · bewegen · löschen · auslösen · zusammenführen.",
        keywords: ["pdf", "seite", "drehen", "seite löschen", "auslösen", "zusammenführen",
                   "kommentieren", "hervorheben", "unterschreiben"],
        blocks: [
            .paragraph("""
                Die PDF-Ansicht hat **zwei Werkzeugleisten**, die verschiedene Fragen beantworten. Die \
                obere Reihe wirkt auf den **Inhalt** einer Seite; die untere auf die **Menge der \
                Seiten**.
                """),
            .heading("Obere Reihe — lesen und kommentieren"),
            .table(
                headers: ["Taste", "Was sie tut"],
                rows: [
                    ["Hervorheben · Unterstreichen", "Den ausgewählten Text markieren"],
                    ["Notiz…", "Eine Notiz an die Seite heften"],
                    ["Anmerkungen entfernen", "Jede Anmerkung von der aktuellen Seite entfernen"],
                    ["Text in einen neuen Tab auslösen", "Den ganzen Text in einen Tab holen, um zu suchen, zu filtern, andere Werkzeuge laufen zu lassen"],
                    ["Suchfeld", "Im PDF suchen — **Tippen ohne Akzente findet trotzdem akzentuierten Text**"],
                ]
            ),
            .note("""
                Ein eingescanntes PDF hat keine Textebene. Der Auslösebefehl **sagt das**, statt einen \
                leeren Tab zu öffnen und Sie raten zu lassen.
                """),
            .heading("Untere Reihe — Seitenoperationen"),
            .table(
                headers: ["Taste", "Was sie tut", "Widerrufbar"],
                rows: [
                    ["Links · rechts drehen", "Die aktuelle Seite um 90° drehen", "Ja"],
                    ["Seite hoch · runter", "Die aktuelle Seite mit ihrer Nachbarin tauschen", "Ja"],
                    ["Seiten löschen…", "Nach Bereich löschen, z. B. `2-4,7`", "Ja"],
                    ["Seiten auslösen…", "Einen Seitenbereich als **neue Datei** schreiben", "Rührt die offene Datei nicht an"],
                    ["Ein PDF zusammenführen…", "Ein anderes PDF direkt nach der aktuellen Seite einfügen", "Ja"],
                    ["Unterschreiben…", "Ein Unterschriftsbild auf der aktuellen Seite platzieren", "Ja"],
                    ["Text bearbeiten…", "Ersatztext über die Auswahl zeichnen", "Ja"],
                    ["Nächstes leeres Feld", "Zum nächsten unausgefüllten Formularfeld springen", "—"],
                    ["Ausgefüllte Werte löschen", "Jedes Formularfeld leeren", "Ja"],
                    ["Seitenänderung widerrufen", "Eine Seitenoperation zurückgehen", "—"],
                    ["Bearbeitete Kopie sichern…", "Eine neue Datei schreiben und sie dann **zur Prüfung erneut öffnen**", "—"],
                ]
            ),
            .heading("Ausfüllbare Formulare"),
            .paragraph("""
                Öffnen Sie ein PDF mit Formularfeldern, und die Statusleiste nennt, **wie viele** es \
                sind. Tippen Sie direkt in die Felder auf der Seite und dann `Bearbeitete Kopie \
                sichern…`.
                """),
            .bullets([
                "Werte werden als **lebende Formularfelder** gespeichert, nicht als abgeflachter Text — der Acrobat des Empfängers sieht also weiterhin ein ausgefülltes Formular und kann es korrigieren.",
                "Vietnamesische Akzente überleben den Weg Schreiben-und-wieder-Öffnen. Genau das sichert ein Test ab, mit dem Namen `Nguyễn Văn Anh`.",
                "`Nächstes leeres Feld` springt zum nächsten leeren — der natürliche Weg durch ein langes Formular.",
            ]),
            .heading("Unterschreiben"),
            .paragraph("""
                Bereiten Sie ein Unterschriftsbild vor (ein PNG mit transparentem Hintergrund passt am \
                besten), **wählen Sie die Stelle zum Unterschreiben** — meist die Linie oder das Wort \
                „Unterschrift“ — und drücken Sie `Unterschreiben…`. Ohne Auswahl landet die \
                Unterschrift unten rechts.
                """),
            .note("""
                Die Unterschrift behält das **Seitenverhältnis** des Bildes: eine gestauchte oder \
                gedehnte Unterschrift wirkt sofort gefälscht.
                """),
            .heading("Text bearbeiten — und drei Dinge, die man vorher wissen sollte"),
            .paragraph("""
                Wählen Sie den zu ändernden Text und drücken Sie `Text bearbeiten…`. GEditor \
                **überdeckt diesen Bereich mit einer direkt daneben abgetasteten Hintergrundfarbe** \
                und zeichnet den neuen Text darüber.
                """),
            .warning("""
                **Der alte Text wird ÜBERDECKT, nicht ENTFERNT.** Er steht weiterhin in der Datei und \
                lässt sich weiterhin mit `Text in einen neuen Tab auslösen` oder jedem anderen \
                Werkzeug herausholen. Das ist **keine Schwärzung** — eine so verborgene \
                Ausweisnummer ist vor einem menschlichen Auge verborgen, nicht vor einer Maschine.
                """),
            .bullets([
                "**Der neue Text bleibt mit `⌘F` auffindbar.** Er wird als echter Text gezeichnet, nicht als Bild — durch einen Test gemessen, nicht angenommen.",
                "**Die Schrift ist eine Systemschrift**, nicht die des Dokuments. Absichtlich: in ein PDF eingebettete Schriften haben oft keine vietnamesischen Akzente, und `Nguyễn` käme als `Nguy?n` an.",
                "**Auf gemustertem Hintergrund sieht man den Flicken** — die Deckfarbe wird an einer einzigen Stelle links von der Auswahl abgetastet.",
            ]),
            .heading("Warum überzeichnen statt den Inhaltsstrom zu bearbeiten"),
            .paragraph("""
                Den Inhaltsstrom eines PDFs direkt zu bearbeiten heißt: Teilmengen-Schriften mit \
                eigener Kodierung, durch Unterschneidung in drei Fragmente zerbrochene Sätze und \
                Zeichenbreitentabellen, die neu zu berechnen sind. Das für **jede** Datei richtig zu \
                tun ist ein eigenes Projekt; es falsch zu tun beschädigt das Dokument eines anderen.
                """),
            .paragraph("""
                Dafür ändert sich der Rest der Seite **um kein einziges Byte**, und die Seite bleibt \
                eine Seite — Text lässt sich weiterhin auswählen, kopieren und durchsuchen. Das \
                Übermalen macht sie **nicht** zu einem Bild.
                """),
            .heading("Syntax für Seitenbereiche"),
            .table(
                headers: ["Tippen", "Bedeutung"],
                rows: [
                    ["`5`", "Nur Seite 5"],
                    ["`2-4`", "Seiten 2, 3, 4"],
                    ["`-3`", "Vom Anfang bis Seite 3"],
                    ["`8-`", "Von Seite 8 bis zum Ende"],
                    ["`1-3,5,9-`", "Mehrere Teile, durch Kommas verbunden"],
                ]
            ),
            .paragraph("Seiten zählen **ab 1**, die Zahl, die Sie auf dem Bildschirm sehen."),
            .warning("""
                Ein umgedrehter Bereich (`5-2`) und ein Bereich über das Ende hinaus (`1-999`) werden \
                beide **mit Begründung abgelehnt**, nie stillschweigend in etwas Ähnliches korrigiert. \
                Bei einem Befehl zum Löschen von Seiten bedeutet falsches Raten verlorene Seiten, und \
                stilles Zurechtstutzen macht aus einem Tippfehler einen gültigen Befehl.
                """),
            .heading("Die Originaldatei wird nie überschrieben"),
            .paragraph("""
                Alles oben ändert das Dokument **im Arbeitsspeicher**. Erst wenn Sie `Bearbeitete \
                Kopie sichern…` drücken und einen Ort wählen, wird eine Datei geschrieben — und nach \
                dem Schreiben **öffnet GEditor genau diese Datei erneut**, um zu bestätigen, dass sie \
                noch alle Seiten hat.
                """),
            .paragraph("""
                Der Grund: eine schlecht geschriebene Datei liegt völlig normal aussehend auf der \
                Festplatte, und der Nutzer merkt es erst, nachdem er sie verschickt hat.
                """),
            .note("""
                Die Statuszeile der Ansicht zeigt **· bearbeitet, nicht gesichert**, sobald das \
                Dokument von der Datei auf der Festplatte abweicht.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
