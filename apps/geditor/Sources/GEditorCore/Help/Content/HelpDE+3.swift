import Foundation

/// Deutscher Hilfeinhalt — Teil 3: Ansichten, Vietnamesisch, Sprachen und Formate.
extension HelpDE {

    static let views = HelpChapter(
        id: "xem",
        title: "Arten, ein Dokument zu sehen",
        summary: "Seitenleiste, Karte, Falten, geteilte Ansicht, Zeilenumbruch, unsichtbare Zeichen, Einfärbungsmodi.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Seitenleiste und Funktionsliste",
        summary: "Der Dateibaum und die Funktionsliste der offenen Datei, in einer Spalte.",
        keywords: ["seitenleiste", "funktionsliste", "gliederung", "dateibaum"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Seitenleiste ein-/ausblenden")]),
            .paragraph("""
                Die Funktionsliste entsteht aus dem **Syntaxbaum** der Sprache, folgt also der echten \
                Struktur, statt sie aus der Einrückung zu erraten. Ein Klick auf einen Eintrag \
                springt dorthin.
                """),
            .note("Das Filterfeld der Funktionsliste **findet akzentuierten Text bei akzentloser Eingabe**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Dokumentkarte",
        summary: "Die ganze Datei in einer schmalen Spalte rechts — auch bei hunderten MB.",
        keywords: ["minikarte", "karte", "überblick"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Dokumentkarte ein-/ausblenden")]),
            .paragraph("""
                Die Karte beschreibt die **ganze Datei**, nicht nur das, was auf dem Bildschirm steht. \
                Ziehen auf ihr springt in die passende Region.
                """),
            .paragraph("""
                Suchtreffer und markierte Zeilen erscheinen auf der Karte: Sie sehen, ob sie verstreut \
                oder gebündelt sind, bevor Sie dorthin rollen.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Falten",
        summary: "Funktionen, Blöcke und Arrays nach Struktur einklappen — oder die ganze Datei auf eine Ebene falten.",
        keywords: ["falten", "code folding", "einklappen"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Block unter dem Cursor falten / entfalten"),
                HelpShortcut("⌥⇧⌘←", "Alles falten"),
                HelpShortcut("⌥⌘→", "Alles entfalten"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Die ganze Datei auf Ebene 1…8 falten"),
            ]),
            .paragraph("""
                Bei Sprachen mit Syntaxbaum folgt das Falten der **echten Struktur**. Bei Dateien ohne \
                Grammatik folgt es der Einrückung.
                """),
            .paragraph("""
                `Auf Ebene falten` zahlt sich bei tiefem JSON und YAML aus: auf Ebene 2 gefaltet passt \
                die Gestalt der ganzen Datei auf einen Bildschirm.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Geteilte Ansicht",
        summary: "Zwei Bereiche nebeneinander, für zwei Dateien — oder zwei Stellen einer Datei.",
        keywords: ["teilen", "bereiche", "vergleichen"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Senkrecht teilen"),
                HelpShortcut("⌥⌘-", "Waagerecht teilen"),
                HelpShortcut("⌥⌘0", "Teilung aufheben"),
                HelpShortcut("⌥⌘]", "Diesen Tab im anderen Bereich öffnen"),
                HelpShortcut("⌥⌘[", "In den anderen Bereich springen"),
            ]),
            .paragraph("""
                Jeder Bereich hat seine eigene Tableiste. **Dieselbe Datei** in beiden Bereichen zu \
                öffnen ist völlig in Ordnung — sie rollen unabhängig, was den Vergleich von Anfang \
                und Ende einer Datei leicht macht.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Automatischer Zeilenumbruch",
        summary: "Drei Modi: aus, am Fensterrand, oder an einer festen Spalte.",
        keywords: ["zeilenumbruch", "weicher umbruch"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Modus", "Eine lange Zeile"],
                rows: [
                    ["Aus", "Rollt waagerecht"],
                    ["Am Fenster", "Bricht am Fensterrand um, folgt dessen Größe"],
                    ["An einer Spalte", "Bricht an der von Ihnen gesetzten Spalte um — etwa 80 oder 100"],
                ]
            ),
            .paragraph("""
                Der Umbruch ist eine **Art zu sehen**, keine Bearbeitung: es wird kein Zeilenumbruch \
                eingefügt, und er kommt nie in den Widerrufsverlauf.
                """),
            .note("Der schnelle Weg dorthin ist das Segment `Ngắt: …` in der Statusleiste."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Schriftgröße",
        summary: "Zwischen 8 und 32 pt zoomen.",
        keywords: ["zoom", "schriftgröße", "größer", "kleiner"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Größer"),
                HelpShortcut("⌘-", "Kleiner"),
                HelpShortcut("⌃⌘0", "Zurück zur Standardgröße"),
            ]),
            .paragraph("""
                Begrenzt auf 8 bis 32 pt. Auch das ist eine **Art zu sehen**: keine Bearbeitung, \
                nichts im Widerrufsverlauf. Die Standardgröße liegt in `Einstellungen…`.
                """),
            .note("`⌘0` ist **nicht** die Standardgröße — diese Taste blendet die Seitenleiste ein und aus."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Unsichtbare Zeichen anzeigen",
        summary: "Eine Gruppe nach der anderen, denn alle zugleich ist meist zu viel.",
        keywords: ["unsichtbar", "leerraum", "nbsp", "nullbreite", "tabulator"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Alle unsichtbaren Zeichen ein-/ausblenden")]),
            .paragraph("""
                Vier Gruppen lassen sich einzeln einschalten, denn alle auf einmal begräbt den Inhalt \
                unter einem Wald aus Punkten.
                """),
            .table(
                headers: ["Gruppe", "Was sie fängt"],
                rows: [
                    ["Leerzeichen", "Leerzeichen am Zeilenende, uneinheitliche Einrückung"],
                    ["Tabulatoren", "Dateien, die Tabulatoren mit Leerzeichen mischen"],
                    ["Zeilenenden", "Dateien, die CRLF mit LF mischen"],
                    ["NBSP · Nullbreite · Steuerzeichen", "Unsichtbare Zeichen aus Word, aus dem Web, aus Tabellenkalkulationen"],
                ]
            ),
            .warning("""
                Die letzte Gruppe ist die, die Leute rettet. Ein aus einer Webseite eingesetztes \
                geschütztes Leerzeichen (NBSP) sieht **genau** aus wie ein gewöhnliches, lässt aber \
                jeden Zeichenkettenvergleich und jeden Filter danebengreifen — und ohne diese Gruppe \
                gibt es keine Möglichkeit, es zu sehen.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV-Modus und Protokollmodus",
        summary: "Zwei Einfärbungen, die die Syntaxhervorhebung ersetzen, für zwei Arten von Datendateien.",
        keywords: ["csv-modus", "protokollmodus", "einfärbung", "spalten", "stufe"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV-Modus"),
            .paragraph("""
                Gibt jeder Spalte in der **Textansicht** eine eigene Farbe, sodass Sie sehen, welche \
                Zelle eine Spalte verrutscht ist, ohne zur Tabelle zu wechseln.
                """),
            .heading("Protokollmodus"),
            .paragraph("""
                Färbt nach dem **Schweregrad**, den er aus der Zeile liest: Fehler rot, Warnungen \
                bernstein, während `debug` und `trace` gedimmt werden — sie machen den Großteil einer \
                Protokolldatei aus, und sie hervorzuheben dimmt genau das, wonach Sie suchen.
                """),
            .paragraph("`Protokoll nach Stufe filtern…` blendet nicht benötigte Stufen ganz aus."),
            .note("""
                Diese beiden färben **anstelle** der Syntaxhervorhebung, nicht darüber. Eine \
                Protokolldatei hat keine Syntax zum Einfärben, und zwei Farbquellen, die in denselben \
                Bytebereich schreiben, hinterlassen keinen vorhersagbaren Sieger.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Binäransicht",
        summary: "Eine Hex-Tabelle für jede Datei — auch für eine mit 1 GB, fast augenblicklich offen.",
        keywords: ["hex", "binär", "byte", "position", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Darstellung ▸ Binäransicht` zeigt jedes Byte als dreispaltige Tabelle: **Position · \
                Hex · Text**. Das funktioniert für **jede** Datei auf der Festplatte, nicht nur für \
                Bilder oder Video.
                """),
            .table(
                headers: ["Spalte", "Inhalt"],
                rows: [
                    ["Position", "Byteposition, hexadezimal"],
                    ["Hex", "16 Bytes je Zeile, nach dem achten getrennt, damit sich leichter zählen lässt"],
                    ["Text", "Druckbare ASCII-Bytes; alles andere ist ein `.`"],
                ]
            ),
            .note("""
                Die Textspalte **dekodiert kein UTF-8**. Ein vietnamesischer Buchstabe braucht zwei \
                oder drei Bytes; ihn darzustellen brächte die Textspalte aus der Flucht mit der \
                Hex-Spalte — und genau diese Flucht ist der ganze Sinn der Spalte. Um akzentuierten \
                Text zu lesen, nehmen Sie die normale Ansicht.
                """),
            .heading("Große Dateien"),
            .paragraph("""
                Die Datei ist **speicherabgebildet**, also kostet das Öffnen einer 1-GB-Datei in der \
                Binäransicht nur das, was Sie ansehen. In der Selbsttest-Sammlung gemessen: **unter \
                einer Millisekunde**.
                """),
            .paragraph("""
                Die Ansicht zeigt jeweils **ein 4-MB-Fenster**, und die obere Leiste nennt den \
                Bereich, in dem Sie sind. Das ist eine Grenze des Tabellenzeichners des Systems, nicht \
                des Lesens: 1 GB sind 62,5 Millionen Zeilen, und ab einem gewissen Punkt beginnen \
                Zeilen beim Rollen zu springen — und eine springende Hex-Tabelle ist nutzlos.
                """),
            .heading("Zu einer Position springen"),
            .table(
                headers: ["Ins Positionsfeld tippen", "Bedeutung"],
                rows: [
                    ["`1F400`", "Hexadezimal — die Voreinstellung"],
                    ["`0x1F400`", "Dasselbe, mit ausdrücklichem Präfix"],
                    ["`#128000`", "Dezimal, wenn Sie eine Byteanzahl statt einer Hex-Position haben"],
                ]
            ),
            .bullets([
                "`‹` und `›` gehen zum vorherigen / nächsten Fenster.",
                "**Ausgewählte Zeilen kopieren** kopiert genau das, was Sie sehen — ohne Auswahl das ganze Fenster.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown-Vorschau",
        summary: "Markdown als formatierten Text darstellen — und klar sagen, was sie nicht darstellt.",
        keywords: ["markdown", "vorschau", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("Dargestellt mit der Markdown-Unterstützung des Systems: fett, kursiv, Code, Links, Listen."),
            .warning("""
                **Keine Tabellen und keine Syntaxfarben in Codeblöcken.** Das Vorschaufenster sagt das \
                an seinem Fuß. Dokumente über **4 MB** werden abgelehnt.
                """),
            .paragraph("""
                Sie brauchen Tabellen und Diagramme in einem veröffentlichbaren Dokument? Dafür sind \
                `.greport.md`-Berichte da, nicht diese Vorschau.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Zwei Modi: View und Code",
        summary: "Eine Taste wechselt zwischen dargestellter Form und bearbeitbarer Quelle, für jeden Dateityp.",
        keywords: ["view", "code", "modus", "quelle", "dargestellt", "vorschau"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Zwischen View und Code wechseln")]),
            .paragraph("""
                Die Steuerung sitzt in der **Leiste direkt unter den Tabs** — für jeden Dateityp an \
                derselben Stelle: ein `View | Code`-Schalter, dann der Name des View-Modus dieser \
                Datei („Dokumentseiten“, „Schlüssel-Wert-Baum“, „Diagramm“…). Eine Datei mit nur einem \
                Modus graut den Schalter aus, und die Leiste sagt warum. Am rechten Rand sitzen die \
                typeigenen Tasten: `.xlsx` hat **Tabelle** (bearbeitbar, direkt zurückgeschrieben), \
                `.pptx` hat **Gliederung**.
                """),
            .note("""
                **Word und PowerPoint verhalten sich wie ein Dokumentleser.** Ihr View-Modus baut \
                echte Seiten — richtige Schriften, Größen und Farben, mit Bildern, Tabellen, Kopf- \
                und Fußzeilen samt Seitenzahlen. Eine Seite ist **genau so breit wie der Rahmen** und \
                lässt sich zoomen. Excel ist eine bewusste Ausnahme: sein View ist eine \
                **bearbeitbare Tabellenkalkulation**, denn eine Tabellenkalkulation hat keine \
                Papiergröße, bevor sie gedruckt wird.
                """),
            .note("""
                Dafür sind die Seiten **schreibgeschützt** und stellen die **Kopie auf der Festplatte** \
                dar: bearbeiten Sie im Code, ohne zu sichern, und die Seiten zeigen die alte Fassung — \
                die Leiste sagt das, mit einer Taste `Sichern und neu darstellen`.
                """),
            .heading("Definitionen"),
            .bullets([
                "**Code** ist die **bearbeitbare Quelle**. Bei einer Textdatei ist das der Text selbst. Bei einer Binärdatei — PDF, Bild, Audio, Video — gibt es keine Textquelle, also ist Code die **Bytes**, hexadezimal gezeigt.",
                "**View** ist das, was aus dem Code **dargestellt** wird. Es mag hübscher, kürzer oder ausführbar sein — aber es ist immer eine Folge, nie das Original.",
            ]),
            .paragraph("""
                Von einem PDF zu sagen, *„dieser Typ hat keinen Code“*, wäre bequem, aber falsch: die \
                Bytes sind sehr wohl seine Quelle.
                """),
            .heading("Wo bearbeitet wird"),
            .paragraph("""
                Bearbeitet wird im **Code**. Es gibt genau **zwei Ausnahmen**, beide weil das \
                Bearbeiten im View weit natürlicher ist: **CSV-Tabellenzellen** und \
                **PDF-Formularfelder**. Beide schreiben direkt in die Quelle, sodass keine zweite \
                Kopie entsteht, die widerspricht.
                """),
            .heading("Nach Dateityp"),
            .table(
                headers: ["Dateityp", "View", "Code", "Bearbeiten in"],
                rows: [
                    ["CSV · TSV", "Tabelle", "Roher Text", "**Beide**"],
                    ["Excel `.xlsx`", "Tabelle des offenen Blatts", "Dieses Blatt als CSV", "**Beide**"],
                    ["PDF", "Dargestellte Seiten", "Binär", "**Beide** — Anmerkungen, Felder, Seiten"],
                    ["Markdown `.md`", "Dargestellter Text", "Markdown-Quelle", "Code"],
                    ["Bericht `.greport.md`", "Bericht mit ausgeführten Abfragen und gezeichneten Diagrammen", "Quelle", "Code"],
                    ["JSON", "Schlüssel-Wert-Baum, faltbar", "JSON-Quelle", "Code"],
                    ["XML · HTML", "Tag-Baum, faltbar", "XML-Quelle", "Code"],
                    ["YAML", "Schlüssel-Wert-Baum nach Einrückung", "YAML-Quelle", "Code"],
                    ["Diagramme `.mmd` · `.dot`", "Das gezeichnete Diagramm, füllt den Tab", "mermaid- oder DOT-Quelle", "Code"],
                    ["Word `.docx`", "Dargestellte Dokumentseiten", "Extrahiertes Markdown", "Code"],
                    ["PowerPoint `.pptx`", "Dargestellte Folienseiten", "Markdown-Gliederung", "Code"],
                    ["Protokolldateien", "Nach Stufe eingefärbt, filterbar", "Roher Text", "Code"],
                    ["Bilder", "Das Bild (animierte laufen)", "Binär", "Schreibgeschützt"],
                    ["Audio · Video", "Ein Abspieler", "Binär", "Schreibgeschützt"],
                    ["Archive", "Eintragsliste", "Binär", "Schreibgeschützt"],
                    ["Quelltext, reiner Text", "— keine", "Der Text selbst", "Code"],
                ]
            ),
            .note("""
                Quelltext hat **kein View**, und das ist normal statt eine Lücke: eine Swift-Datei hat \
                keine dargestellte Form, die des Ansehens wert wäre.
                """),
            .heading("Der Seitenleser für Word und PowerPoint"),
            .paragraph("""
                Die Seiten stapeln sich senkrecht und rollen durchgehend, jede ein weißes Blatt auf \
                grauem Grund — wie bei jedem Dokumentleser. Seine Steuerungen sitzen rechts in der \
                Leiste.
                """),
            .table(
                headers: ["Taste / Taste", "Was sie tut"],
                rows: [
                    ["`Breite anpassen`", "Das Blatt ist genau so breit wie der Rahmen — die Voreinstellung"],
                    ["`Seite anpassen`", "Das ganze Blatt passt in den Rahmen"],
                    ["`−` `+`", "Stufenweise zoomen; oder aufziehen, oder ⌘ + Rollen"],
                    ["Das Feld `Suchen`, oder ⌘F", "In den Seiten suchen, dorthin springen und hervorheben"],
                    ["Zeilenschalter im Suchfeld", "Nächster Treffer"],
                    ["Ziehen", "Text auswählen; Doppelklick für ein Wort, Dreifachklick für einen Absatz"],
                    ["⌘A · ⌘C", "Alles auswählen · Auswahl kopieren"],
                    ["Bild auf · Bild ab · Pos1 · Ende", "Durch das Dokument bewegen"],
                ]
            ),
            .paragraph("""
                Das Suchfeld **ignoriert Akzente und Schreibweise**: `vuong quoc` findet `Vương quốc`. \
                Die Beschriftung „Seite 12/363“ in der Leiste sagt Ihnen, wo Sie sind.
                """),
            .note("""
                **Was nicht dargestellt wird, klar gesagt:** frei verankerte Bilder (Text, der um ein \
                Bild fließt) erscheinen als eingebettete Bilder; Fußnoten, Diagramme und PowerPoints \
                SmartArt werden nicht gezeichnet. Wenn Sie exakte Übereinstimmung mit dem Ausdruck \
                brauchen, öffnen Sie es in Word.
                """),
            .heading("Ein Klick auf einen Knoten führt zurück in die Quelle"),
            .paragraph("""
                Ein JSON-Baum ist kein hübscher Ausdruck: ein Klick auf einen Knoten bewegt den Cursor \
                **zum WERT dieses Knotens** im Text und bringt den Tab zurück in den Code — denn was \
                Sie als Nächstes wollen, ist fast immer, das zu bearbeiten, was Sie gerade angeklickt \
                haben.
                """),
            .bullets([
                "Behälterknoten zeigen ihre **Elementanzahl** (`{12}`, `[340]`) statt ihres Inhalts — das beantwortet die Frage „lohnt sich das Öffnen“.",
                "Die **ersten zwei Ebenen** sind ausgeklappt: eine Datei mit zehntausend Knoten ganz auszuklappen ergibt eine Liste, die länger ist als die Quelle, ganz einzuklappen heißt, für jede Erkenntnis klicken zu müssen.",
                "Eine Datei mit **ungültiger Syntax** bekommt keinen halben Baum — ein abgeschnittener Baum sieht aus wie ein Dokument, das schlicht nur so wenig enthält.",
                "In einem XML-Baum tragen Attribute ein `@`-Präfix in ordentlicher XPath-Schreibweise, und **Leerraum zwischen Tags wird nicht zum Knoten** — er ist Formatierung, nicht Inhalt.",
                "Ein YAML-Baum liest **Mehrdokumentdateien** (`---`): jedes Dokument hat seine eigene Wurzel. In einer Zeile geschriebene Sammlungen (`ports: [80, 443]`) bleiben ein Blatt — Sie sehen schon alles, und Ausklappen kostete einen Klick. **Einrückung mit Tabulatoren** wird mit der genauen Zeile gemeldet: das ist ein YAML-Fehler, den das Auge nicht sieht.",
                "Die PowerPoint-Gliederung entsteht aus dem **offenen Text**, nicht aus der Datei auf der Festplatte: haben Sie die Gliederung gerade im Code bearbeitet, muss der Baum die neue Fassung beschreiben und seine Knoten müssen in diese neue Fassung springen. Vortragsnotizen klappen in einen Knoten zusammen, damit eine redselige Folie nicht wie eine inhaltsreiche aussieht.",
                "**Ein tabfüllendes Diagramm folgt derselben Regel**: ein Klick auf einen Knoten, und Sie sind im Code mit dem Cursor auf seiner Deklaration. Im nebenstehenden Bereich `Mermaid Studio` schließt der Tab nicht — der Editor ist gleich daneben, und den Cursor zu bewegen genügt, um es zu sehen.",
                "Diagramme **öffnen sich auch dort, wo Sie stehen**: das Element zur Cursorzeile ist hervorgehoben, sobald der Tab erscheint, sodass Sie nicht danach jagen müssen.",
            ]),
            .heading("Das Filterfeld: in einem Baum mit zehntausend Knoten ist Suchen die Arbeit"),
            .paragraph("""
                Direkt unter der Knotenanzahl sitzt ein Filterfeld. Tippen Sie dort, und der Baum \
                behält nur passende Knoten — **samt dem Pfad von der Wurzel zu ihnen**, denn wenn ein \
                Schlüssel `name` an zehn Stellen vorkommt, ist die eigentliche Frage „welcher“, und nur \
                der Ast, der ihn enthält, beantwortet sie. Der Rest wird für Sie ausgeklappt: Sie jede \
                Ebene aufklappen zu lassen, hieße Sie ein zweites Mal von Hand filtern zu lassen.
                """),
            .bullets([
                "Es filtert nach **Beschriftungen und Werten**: nach `Huế` zu suchen ist so üblich wie nach dem Schlüssel `province`.",
                "**Akzentlose Eingabe trifft trotzdem akzentuierten Text** — `da nang` findet `Đà Nẵng`. Derselbe Vergleich wie beim Filter der CSV-Tabelle und bei der Funktionsliste, damit Sie in einer App nicht drei Suchregeln behalten müssen.",
                "Ohne Treffer steht in der Kopfzeile **„Keine Ergebnisse“**, statt Sie vor einem leeren Baum rätseln zu lassen, ob die Datei kaputt ist.",
                "Ein Dateiwechsel oder erneutes Betreten des View **löscht den Filter**: ein Baum, der schon abgeschnitten aufgeht, ohne dass irgendetwas es erklärt, ist der verwirrendste Zustand überhaupt.",
            ]),
            .heading("Der ganze Baum lässt sich über die Tastatur bedienen"),
            .paragraph("""
                Das Betreten des View setzt den Fokus auf den Baum; Sie müssen ihn nicht erst \
                anklicken. Auf und ab bewegen zwischen Knoten, links und rechts falten und entfalten, \
                und zwei Tasten beenden das Betrachten — und tun dabei **Verschiedenes**:
                """),
            .bullets([
                "**Zeilenschalter** — zum gewählten Knoten gehen: zurück in den Code mit dem Cursor im Bytebereich dieses Knotens. Genau wie ein Klick.",
                "**Tabulator** — zwischen Baum und Filterfeld wechseln.",
                "**⌘C** — kopiert den **Pfad** des gewählten Knotens, nicht den Text hinter dem Baum. JSON und YAML liefern JSONPath (`$.customer['name']`), das sich direkt in das eigene JSONPath-Abfragefeld dieses Produkts oder in `yq` einsetzen lässt; XML liefert XPath (`/order/item[2]/@code`) mit Indizes, wenn zwei Tags einen Namen teilen; eine PowerPoint-Gliederung kopiert den Text der Zeile, denn eine Gliederung hat keine Pfadsprache, die man erfinden könnte.",
                "**Esc** — der Rückweg: zurück in den Code mit dem Cursor **genau dort, wo er war**. Sie haben einen Baum betrachtet, sind nirgendwohin gereist.",
            ]),
            .heading("Und andersherum: der Baum öffnet sich dort, wo der Cursor steht"),
            .paragraph("""
                Das View aus der Mitte einer Datei mit zehntausend Zeilen zu betreten öffnet den Baum \
                **nicht** oben: er klappt den Pfad bis zu dem Knoten auf, der der Cursorstelle \
                entspricht, und wählt ihn aus. Das ist die andere Hälfte des Sprungs zur Quelle — ohne \
                sie wären View und Code nur in **eine** Richtung zwei Blicke auf ein Dokument.
                """),
            .bullets([
                "Er klappt bei Bedarf **tiefer als zwei Ebenen** auf: die Zwei-Ebenen-Regel beantwortet „wie sieht diese Datei aus“, hier ist die Frage aber eine andere — „wo bin ich in diesem Baum“.",
                "Ein Cursor auf einem **Schlüssel** (`\"address\":`) wählt diesen Eintrag, obwohl der Bytebereich des Knotens nur den Wert abdeckt. Text unmittelbar vor einem Knoten gehört zu diesem Knoten.",
                "Ein Cursor am **Anfang eines Blocks** — der Schlüssel eines YAML-Blocks, ein Folientitel, ein XML-Tagname — wählt diesen Block, statt zu seinem ersten Kind hinabzutauchen.",
                "Das Betreten des View **bewegt den Cursor nicht**. Verlassen Sie das View, sind Sie genau dort, wo Sie waren; View ist eine Art zu sehen, kein Befehl, der die Position ändert.",
            ]),
            .heading("Kein Typ vermisst mehr ein View"),
            .paragraph("""
                **Jeder Dateityp mit Raum für einen View-Modus stellt jetzt einen dar.** Die Liste der \
                fehlenden Typen wurde leer und wurde entfernt.

                Quelltext und reiner Text haben weiterhin kein View — das ist normal, keine Lücke, \
                also standen sie nie auf dieser Liste.

                Kommt ein neuer Dateityp, dessen View noch nicht gebaut ist, sagt der Umschaltbefehl \
                das und nennt, was fehlt, statt einen leeren Rahmen zu öffnen — ein leerer Rahmen ist \
                ein leeres Versprechen, eine benannte Ablehnung ist Information.
                """),
            .heading("Die sechs älteren Befehle gibt es weiterhin"),
            .paragraph("""
                `Tabellen-/Textansicht`, `Markdown-Vorschau`, `Binäransicht`, `Berichtsvorschau`, \
                `Mermaid-Diagrammvorschau`, `Protokollmodus` — alle bleiben genau, wo sie waren. \
                `⌥⌘V` ist ein **gemeinsamer Eingang**, kein Ersatz.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamesisch

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamesisch",
        summary: "Alte Kodierungen, Unicode-Normalisierung, akzentlose Suche und Eingabemethoden.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnamesische Kodierungen",
        summary: "TCVN3, VISCII, VNI-Windows und 33 weitere lesen und schreiben, automatisch erkannt.",
        keywords: ["kodierung", "tcvn3", "abc", "viscii", "vni", "kauderwelsch"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Eine alte vietnamesische Datei geöffnet und `Tr¦êng §¹i häc` statt `Trường Đại học` \
                bekommen? Die Datei ist nicht beschädigt — sie wurde in einer Kodierung von vor \
                Unicode gesichert.
                """),
            .steps([
                "Klicken Sie die Kodierung in der **Statusleiste** an (oder `Format ▸ Kodierung…`).",
                "Wählen Sie die richtige — bei alten vietnamesischen Dateien meist `TCVN3 (ABC)`, `VNI-Windows` oder `VISCII`.",
                "Der Text berichtigt sich sofort; die Datei muss nicht neu geöffnet werden.",
                "Damit es so bleibt: `Sichern unter…` mit der Kodierung `UTF-8`.",
            ]),
            .heading("Die drei alten vietnamesischen Kodierungen"),
            .table(
                headers: ["Kodierung", "Meist zu finden in"],
                rows: [
                    ["TCVN3 (ABC)", "Behördenpapieren und älteren Word-Dokumenten im Norden"],
                    ["VNI-Windows", "Verlagswesen, Zeitungen und Druckereien — im Süden verbreitet"],
                    ["VISCII", "Frühe E-Mail und Usenet"],
                ]
            ),
            .paragraph("""
                GEditor **erkennt die Kodierung** beim Öffnen. Rät er falsch, behebt ein Klick es, und \
                der Inhalt wird neu dekodiert statt Buchstabe für Buchstabe geflickt.
                """),
            .warning("""
                Das Schreiben in eine alte Kodierung verliert Zeichen, die diese nicht kennt. GEditor \
                **zählt sie und sagt es Ihnen vorher** — etwa *„12 Zeichen sind nicht in TCVN3“* — \
                statt sie stillschweigend in Fragezeichen zu verwandeln.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Zeilenenden",
        summary: "LF, CRLF, CR — mit einem Klick für die ganze Datei umgewandelt.",
        keywords: ["eol", "crlf", "lf", "zeilenende", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Stil", "Genutzt von", "Bytes"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac vor 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Der aktuelle Stil steht in der Statusleiste; klicken Sie ihn zum Ändern. Eine Datei, \
                die zwei Stile **mischt**, wird dort ebenfalls gemeldet — schalten Sie `Unsichtbare \
                anzeigen ▸ Zeilenenden` ein, um genau zu sehen, wo.
                """),
            .note("Der Zeilenendenstil für **neue** Dateien wird in `Einstellungen…` gesetzt."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode-Normalisierung",
        summary: "Warum die Suche nach „ế“ manchmal nichts findet, und wie man eine ganze Datei repariert.",
        keywords: ["unicode", "nfc", "nfd", "zusammengesetzt", "zerlegt", "normalisieren"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                In Unicode lässt sich `ế` auf **zwei Arten** schreiben: als ein vorkomponierter \
                Codepunkt (NFC) oder als `e` plus zwei eigene Zeichen (NFD). Auf dem Bildschirm sehen \
                sie gleich aus; für eine Maschine sind es zwei verschiedene Zeichenketten.
                """),
            .paragraph("""
                Die Folge: die Suche nach `ế` in einer NFD-Datei findet **nichts**, und der Nutzer \
                schließt daraus, die Daten seien nicht da.
                """),
            .steps([
                "`Format ▸ Unicode normalisieren…`",
                "Wählen Sie **NFC** (vorkomponiert) — die Form, die fast alles andere nutzt.",
                "Anwenden. Es ist ein einziger Widerrufsschritt.",
            ]),
            .note("""
                Dateien von macOS sind oft NFD, weil Apples Dateisystem Namen so speichert. Das ist \
                der mit Abstand häufigste Grund, warum aus dem Finder kopierte Daten nicht wieder \
                gefunden werden.
                """),
            .paragraph("""
                In `Einstellungen…` gibt es einen Schalter **beim Sichern zu NFC normalisieren**. \
                Standardmäßig aus, denn er ändert die Bytes der Datei.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Tippen ohne Akzente findet trotzdem akzentuierten Text",
        summary: "Jedes Such- und Filterfeld vergleicht mit entfernten Akzenten.",
        keywords: ["akzente", "diakritika", "suche", "filter"],
        blocks: [
            .paragraph("""
                Tippen Sie `hue`, um `Huế` zu finden. Tippen Sie `da nang`, um `Đà Nẵng` zu finden. \
                Die Regel gilt für den Filter der CSV-Tabelle, die Funktionssuche, die Hilfesuche und \
                die übrigen Filterfelder.
                """),
            .note("""
                `Đ` wird eigens behandelt, denn in Unicode ist es **ein eigener Buchstabe** und kein \
                `D` mit einem Zeichen — gewöhnliches Akzententfernen fasst es nicht an.
                """),
            .paragraph("""
                Der CSV-Filter nimmt auch ein `=`-Präfix für den genauen Vergleich. Die `=`-Form ist \
                **ebenfalls akzentunabhängig**, denn ein Filter, der Diakritika unterscheidet, lässt \
                den Nutzer glauben, die Daten fehlten.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnamesische Eingabemethoden",
        summary: "EVKey, OpenKey, Unikey und die macOS-Eingabequelle schreiben direkt ins Dokument.",
        keywords: ["eingabemethode", "evkey", "unikey", "openkey", "telex", "vni"],
        blocks: [
            .paragraph("""
                Nichts einzurichten. Telex und VNI funktionieren beide, auch über **mehrere Cursor** — \
                einmal tippen, und jeder Cursor erhält den richtig akzentuierten Buchstaben.
                """),
            .paragraph("""
                Suchfelder, Filterfelder und jeder Dialog nehmen die Eingabemethode genauso an wie der \
                Editor.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Sprachen und Formate

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Sprachen und Formate",
        summary: "Zwanzig eingebaute Sprachen, benutzerdefinierte, und Werkzeuge für JSON · XML · YAML · Protokolle.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Zwanzig eingebaute Sprachen",
        summary: "Einfärbung aus einem echten Syntaxbaum, mit den Kommentarzeichen jeder Sprache.",
        keywords: ["syntax", "hervorhebung", "sprache", "tree-sitter", "grammatik"],
        blocks: [
            .paragraph("""
                Die Sprache wird an der **Dateiendung** erkannt (dazu einige besondere Namen wie \
                `Makefile`, `Dockerfile`, `Gemfile`). In der Statusleiste können Sie sie von Hand \
                ändern.
                """),
            .table(
                headers: ["Sprache", "Endungen", "Zeilen- · Blockkommentar"],
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
                Die letzte Spalte ist das, was `⌘/` nutzt. Sprachen ohne Zeilenkommentar (JSON, CSS, \
                XML) bekommen stattdessen die Blockform.
                """),
            .heading("Was mit einem Syntaxbaum kommt"),
            .bullets([
                "Die **Funktionsliste** in der Seitenleiste folgt der echten Struktur, nicht Einrückungsvermutungen.",
                "**Falten** nach Struktur.",
                "**Klammernpaarung**, die Klammern in Zeichenketten und Kommentaren überspringt.",
                "**Automatische Einrückung**, die nach `{` eine Ebene hinzufügt, und nach `:` in Python und YAML.",
            ]),
            .note("""
                Drei schwere Grammatiken (C++, C#, Ruby) liegen in einer **verzögert geladenen** \
                Bibliothek — sie werden nur geladen, wenn Sie eine Datei dieser Sprachen öffnen. So \
                bleibt die Startzeit unter einer halben Sekunde.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Benutzerdefinierte Sprachen",
        summary: "Ihr eigenes Format mit einer JSON-Datei einfärben — ohne Grammatik zu schreiben.",
        keywords: ["udl", "eigene sprache", "eigenes protokoll"],
        blocks: [
            .paragraph("""
                Das interne Protokollformat einer Firma, eine eigene Konfigurationssprache, eine kleine \
                DSL — keines davon hat eine tree-sitter-Grammatik, und eine zu schreiben braucht einen \
                Compiler und etwas Parsertheorie.
                """),
            .paragraph("""
                Stattdessen nimmt GEditor einen **tabellengesteuerten Lexer** an, in JSON deklariert. \
                Legen Sie die Datei in den Ordner `grammars/` im Konfigurationsverzeichnis von GEditor \
                und starten Sie neu.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — eine vollständige Sprache",
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
                    """),
            .heading("Jeder Schlüssel"),
            .table(
                headers: ["Schlüssel", "Typ", "Bedeutung"],
                rows: [
                    ["`name`", "Zeichenkette", "Der in der Statusleiste gezeigte Name"],
                    ["`extensions`", "Feld von Zeichenketten", "Dateiendungen, **ohne den Punkt**"],
                    ["`caseSensitive`", "Wahrheitswert", "Ob Schlüsselwörter Groß-/Kleinschreibung beachten"],
                    ["`lineComment`", "Zeichenkette", "Zeichen für Kommentar bis Zeilenende; weglassen, wenn es keines gibt"],
                    ["`blockComment`", "Feld aus 2 Zeichenketten", "`[öffnend, schließend]`"],
                    ["`stringDelimiters`", "Feld von Zeichenketten", "Jeder Eintrag ist **ein** Zeichen, das eine Zeichenkette öffnet/schließt"],
                    ["`escapeCharacter`", "Zeichenkette", "Escape-Zeichen in Zeichenketten; leer heißt, die Sprache hat keines"],
                    ["`keywordGroups`", "Objekt", "Gruppenname → Schlüsselwortliste; drei Gruppen bekommen drei Farben"],
                ]
            ),
            .paragraph("Die drei Gruppennamen mit eigener Farbe sind `keyword`, `type` und `constant`."),
            .warning("""
                Dieser Lexer **versteht keine Verschachtelung**. Strukturelles Falten, die \
                Funktionsliste und die kluge Klammernpaarung bleiben den zwanzig eingebauten Sprachen \
                vorbehalten. Das ist ein bewusster Tausch: dafür deklarieren Sie eine Sprache in zehn \
                Minuten statt an einem Tag.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON-Werkzeuge",
        summary: "Neu formatieren, verkleinern, Schlüssel sortieren und gegen ein JSON Schema prüfen.",
        keywords: ["json", "formatieren", "minify", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Befehl", "Was er tut"],
                rows: [
                    ["Neu formatieren", "Bricht um und rückt zum Lesen ein"],
                    ["Verkleinern", "Entfernt allen überflüssigen Leerraum"],
                    ["Schlüssel sortieren", "Ordnet die Schlüssel jedes Objekts alphabetisch — damit sich zwei JSON-Dateien **vergleichen** lassen"],
                    ["Gegen JSON Schema prüfen…", "Prüft das Dokument gegen eine Schema-Datei und listet jedes Problem mit Zeile"],
                ]
            ),
            .paragraph("""
                Angewandt werden die Regeln von **striktem RFC 8259**: keine abschließenden Kommas, \
                keine Kommentare, kein `NaN`. Ein Syntaxfehler zeigt auf genau Zeile und Spalte.
                """),
            .note("""
                **JSONL**-Dateien (ein Objekt je Zeile) werden ebenfalls erkannt und haben ihr eigenes \
                Werkzeug im Kapitel zum Wissenspaket.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath-Abfragen",
        summary: "Genau den Teil aus einer großen JSON-Datei ziehen, den Sie brauchen.",
        keywords: ["jsonpath", "json-abfrage", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Tippen Sie einen Ausdruck; die Ergebnisse erscheinen als Liste, in die man springen kann."),
            .table(
                headers: ["Schreiben", "Bedeutung"],
                rows: [
                    ["`$`", "Die Dokumentwurzel"],
                    ["`$.name`", "Der Schlüssel `name` an der Wurzel"],
                    ["`$.orders[0]`", "Das erste Element eines Feldes"],
                    ["`$.orders[*].total`", "Der Schlüssel `total` **jedes** Elements"],
                    ["`$..province`", "Der Schlüssel `province` in **beliebiger Tiefe**"],
                    ["`$.orders[1:3]`", "Ein Ausschnitt: Elemente 1 und 2"],
                ]
            ),
            .code(language: "text", caption: "Der Provinzcode jeder Bestellung, wie tief auch verschachtelt",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML-Werkzeuge",
        summary: "Neu formatieren, verkleinern, Syntax prüfen und gegen eine DTD oder ein XSD prüfen.",
        keywords: ["xml", "xsd", "dtd", "schema", "prüfen", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Befehl", "Was er tut"],
                rows: [
                    ["Neu formatieren", "Rückt nach Tag-Tiefe ein"],
                    ["Verkleinern", "Entfernt Leerraum zwischen Tags"],
                    ["Syntax prüfen", "Fehlende schließende Tags, falsche Verschachtelung, ungültige Zeichen"],
                    ["Gegen DTD/XSD prüfen…", "Prüft gegen ein Schema und meldet jedes Problem mit Zeile"],
                    ["XPath auswerten…", "Führt einen XPath-Ausdruck aus; die Ergebnisse öffnen sich in einem neuen Tab"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Tippen Sie einen Ausdruck, und die Ergebnisse öffnen sich als **Text-Tab**, ein Knoten \
                je Zeile. Zum Beispiel: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Die Ergebnisse springen NICHT zu einer Stelle in der Quelldatei.** Der XPath-Auswerter \
                des Systems baut seinen eigenen Baum und behält die Byteposition jedes Knotens nicht: \
                zurück kommt INHALT, keine Koordinaten. Um die genaue Stelle zu erreichen, nutzen Sie \
                `⌘F` auf der eben gefundenen Zeichenkette.
                """),
            .paragraph("""
                In `.xml`- und `.html`-Dateien lässt das Tippen von `>` zum Abschluss eines öffnenden \
                Tags das **schließende Tag erscheinen**, mit dem Cursor dazwischen. Selbstschließende \
                Tags (`<br/>`), Deklarationen (`<?xml …?>`) und Kommentare nicht — sie haben nichts zu \
                schließen.
                """),
            .warning("""
                XML neu zu formatieren **ändert den Leerraum zwischen Tags**. In Dokumenten, wo dieser \
                Leerraum Bedeutung hat — etwa XHTML mit Text in Tags — ändert das die Anzeige. Es ist \
                ein einziger Widerrufsschritt, `⌘Z` macht es rückgängig.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML-Prüfung",
        summary: "Die zwei häufigsten YAML-Fehler fangen: doppelte Schlüssel und Tabulatoreinrückung.",
        keywords: ["yaml", "yml", "lint", "doppelter schlüssel", "einrückung"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Doppelte Schlüssel** in einer Zuordnung — die meisten YAML-Leser nehmen den **letzten** und verwerfen die früheren stillschweigend, sodass sich eine Konfigurationsdatei ganz anders verhalten kann, als Sie erwarten.",
                "**Tabulatoreinrückung** — YAML verbietet Tabulatoren in der Einrückung, und die Fehlermeldungen der Bibliotheken dazu sind meist unverständlich.",
            ]),
            .note("Schalten Sie `Unsichtbare anzeigen ▸ Tabulatoren` ein, um sofort zu sehen, welcher Leerraum ein Tabulator ist."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Protokolldateien",
        summary: "Sieben Schweregrade, Filtern nach Stufe, und wie man ein sehr großes Protokoll liest.",
        keywords: ["protokoll", "log", "fehler", "warnung", "filter", "stufe"],
        blocks: [
            .paragraph("""
                Schalten Sie `Darstellung ▸ Protokollmodus (Farbe nach Stufe)` ein. GEditor liest den \
                Schweregrad am **Anfang jeder Zeile** — nach Zeitstempel und Prozessname.
                """),
            .table(
                headers: ["Stufe", "Farbe"],
                rows: [
                    ["CRITICAL · ERROR", "Rot"],
                    ["WARNING", "Bernstein"],
                    ["NOTICE", "Akzentfarbe"],
                    ["INFO", "Gewöhnlicher Text"],
                    ["DEBUG · TRACE", "Gedimmt"],
                ]
            ),
            .paragraph("""
                `Protokoll nach Stufe filtern…` blendet die niedrigeren Stufen ganz aus. Zeilen, deren \
                Stufe **nicht erkannt** wird — etwa die Fortsetzung eines Stack-Trace — bleiben in \
                Ruhe, statt die Stufe der vorherigen Zeile zu erhalten.
                """),
            .heading("Ein großes Protokoll lesen, Schritt für Schritt"),
            .steps([
                "Die Datei öffnen — auch im Gigabyte-Maßstab geht sie fast augenblicklich auf.",
                "`Darstellung ▸ Protokollmodus`, um zu sehen, wo das Rot ist.",
                "`⌥⌘M` für die Dokumentkarte: ist das Rot auf eine Strecke gebündelt oder über die ganze Datei verteilt?",
                "`⌘F` für den Fehlercode, `⌘M`, um jede Trefferzeile zu markieren.",
                "`Suchen ▸ Markierte Zeilen kopieren`, um sie in einen neuen Tab zu ziehen.",
                "Läuft noch? `Ablage ▸ Datei verfolgen (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
