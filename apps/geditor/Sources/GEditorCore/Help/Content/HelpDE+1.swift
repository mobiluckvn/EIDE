import Foundation

/// Deutscher Hilfeinhalt — Teil 1: Erste Schritte und Bearbeiten.
///
/// **Themen-`id`s werden NIE übersetzt.** Auf sie zeigt `.seeAlso`, sie öffnet das Menü, und sie
/// erlauben dem Hilfefenster, die Sprache zu wechseln, **ohne den Leser ins Inhaltsverzeichnis
/// zurückzuwerfen**. Eine geänderte id zerreißt alle Verweise — in allen Büchern zugleich.
///
/// Die Menütitel in `commands:` bleiben vietnamesisch: sie müssen Wort für Wort den echten
/// Menüeinträgen entsprechen, die `HelpCoverage` genau über diese Zeichenkette prüft.
enum HelpDE {}

extension HelpDE {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Erste Schritte",
        summary: "Was GEditor tut, und wofür die ersten fünf Minuten gut sind.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Was GEditor ist",
        summary: "Ein Text- und Daten-Editor im Gigabyte-Maßstab für macOS, der Vietnamesisch spricht.",
        keywords: ["einführung", "willkommen", "überblick", "über"],
        blocks: [
            .paragraph("""
                GEditor öffnet eine **1-GB-Datei, ohne 1 GB in den Arbeitsspeicher zu laden**. Er \
                liest über ein gleitendes Fenster auf einer speicherabgebildeten Datei: ein Protokoll \
                mit 200 Millionen Zeilen oder eine CSV-Datei mit einer Million Zeilen öffnet sich in \
                etwa einer Sekunde und scrollt flüssig.
                """),
            .paragraph("""
                Über das Bearbeiten hinaus ist er eine **Werkbank für Daten**: CSV als Tabelle \
                ansehen, bereinigen, Qualität bewerten, mit SQL abfragen, nach Ausreißern und Trends \
                durchsuchen und daraus einen Bericht erzeugen. Und er liest die alten \
                vietnamesischen Kodierungen, die die meisten Werkzeuge heute vergessen haben.
                """),
            .heading("Sechs Dinge, die sich zuerst lohnen"),
            .table(
                headers: ["Aufgabe", "Wohin"],
                rows: [
                    ["Eine große Datei ohne Warten öffnen", "Ins Fenster ziehen — siehe „Große Dateien öffnen“"],
                    ["Viele Stellen gleichzeitig ändern", "`⌘D` nimmt das nächste Vorkommen dazu, dann einmal tippen"],
                    ["Mit einem regulären Ausdruck suchen", "`⌘F`, Regex einschalten — die Maschine ist PCRE2 mit JIT"],
                    ["Eine CSV als Tabelle sehen", "`⌥⌘T` — eine Million Zeilen scrollt weiterhin flüssig"],
                    ["Eine unordentliche Datentabelle säubern", "`⇧⌘L` Bereinigungswerkbank — Vorschau vor dem Anwenden"],
                    ["Eine vietnamesische Datei öffnen, die Kauderwelsch zeigt", "Die Kodierung in der Statusleiste anklicken"],
                ]
            ),
            .note("""
                Sie kommen von Notepad++? Es gibt eine Seite, die beide Tastenbelegungen \
                gegenüberstellt, denn einige Tasten **tauschen unter macOS ihren Platz**, statt nur \
                `Ctrl` durch `⌘` zu ersetzen.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Ihre ersten fünf Minuten",
        summary: "Zwölf Tastenkürzel decken den größten Teil der täglichen Arbeit ab.",
        keywords: ["kürzel", "tasten", "start", "grundlagen"],
        blocks: [
            .paragraph("""
                Sie müssen nicht alles lernen. Die zwölf Tasten unten decken den größten Teil der \
                täglichen Arbeit ab; den Rest schlagen Sie nach, wenn Sie ihn brauchen.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Datei öffnen"),
                HelpShortcut("⇧⌘O", "Einen ganzen Ordner als Arbeitsbereich öffnen"),
                HelpShortcut("⌘T", "Neuer Tab"),
                HelpShortcut("⌘S", "Sichern"),
                HelpShortcut("⌘F", "Suchen"),
                HelpShortcut("⌥⌘F", "Suchen und Ersetzen"),
                HelpShortcut("⇧⌘F", "In einem Ordner suchen"),
                HelpShortcut("⌘D", "Das nächste Vorkommen zur Auswahl hinzufügen"),
                HelpShortcut("⌘L", "Gehe zu Zeile"),
                HelpShortcut("⌘/", "Zeile mit der Syntax der Sprache auskommentieren"),
                HelpShortcut("⌥⌘T", "Zwischen Tabelle und Text wechseln (CSV-Dateien)"),
                HelpShortcut("⌘?", "Dieses Hilfefenster erneut öffnen"),
            ]),
            .heading("Drei Dinge, die Neulinge überraschen"),
            .bullets([
                "**Eine Massenoperation ist EIN Widerrufsschritt**, auch wenn sie eine Million Zeilen berührt. Falsch sortiert? Ein `⌘Z` und es ist weg.",
                "**Die Sitzung stellt sich selbst wieder her.** Beenden und wieder öffnen: die Tabs kommen an ihren Platz zurück, auch ungesicherte. Nichts zu drücken.",
                "**Tippen ohne Akzente findet trotzdem akzentuierte Wörter** — in jedem Such- und Filterfeld: `hue` ergibt `Huế`, `da nang` ergibt `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Was möchten Sie tun?",
        summary: "Eine Tabelle von echten Aufgaben zum Kapitel, das sie behandelt.",
        keywords: ["index", "nachschlagen", "wie geht"],
        blocks: [
            .paragraph("""
                Das Inhaltsverzeichnis links ist nach **Funktion** geordnet. Diese Tabelle ist nach \
                **Aufgabe** geordnet, denn die beiden Ordnungen decken sich nicht.
                """),
            .table(
                headers: ["Ich muss…", "Siehe"],
                rows: [
                    ["Dieselbe Stelle in hunderten Zeilen ändern", "Mehrere Cursor · Spaltenblockauswahl"],
                    ["Massenhaft mit einer Regex umformatieren", "Suchen und Ersetzen · Reguläre Ausdrücke"],
                    ["Eine Abfolge von Aktionen wiederholen", "Makros"],
                    ["Eine zugeschickte CSV öffnen", "Die CSV-Tabelle"],
                    ["Eine unordentliche Tabelle säubern: gemischte Daten, Zahlen als Text", "Der Bereinigungsablauf"],
                    ["Beurteilen, ob einer Tabelle zu trauen ist", "Datenqualitätsbewertung"],
                    ["Ausreißer, Trends, Gruppen finden", "Der Data-Mining-Ablauf"],
                    ["Fragen in SQL stellen", "CSV mit SQL abfragen"],
                    ["Einen Bericht veröffentlichen, dessen Zahlen sich erneuern", "`.greport.md`-Berichte"],
                    ["Ein Diagramm in einem Dokument zeichnen", "Mermaid"],
                    ["Eine vietnamesische Datei öffnen, die Kauderwelsch zeigt", "Vietnamesische Kodierungen"],
                    ["Aus der Shell oder mit AppleScript automatisieren", "Automatisierung"],
                    ["Ein selbst erfundenes Format einfärben", "Benutzerdefinierte Sprachen"],
                ]
            ),
            .note("""
                Nicht aufgeführt? Das Suchfeld oben links durchsucht **Fließtext und \
                Codebeispiele**: Tippen Sie einen Konfigurationsschlüssel wie `fail_under`, und Sie \
                landen auf der richtigen Seite.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Große Dateien öffnen",
        summary: "Warum 1 GB überhaupt aufgeht, und wo GEditor absichtlich ablehnt statt zu raten.",
        keywords: ["große datei", "gigabyte", "protokoll", "mmap", "langsam", "leistung"],
        blocks: [
            .paragraph("""
                Die Datei wird **speicherabgebildet** und über ein gleitendes Fenster gelesen; der \
                Teil, den Sie bearbeiten, liegt in einer Piece Table. In der Praxis: die Öffnungszeit \
                hängt kaum von der Dateigröße ab, und der belegte Speicher ebenso wenig.
                """),
            .heading("Wo er absichtlich ablehnt"),
            .paragraph("""
                Einige Berechnungen müssten die ganze Datei zu einer einzigen Zeichenkette lesen — \
                genau das, was diese Architektur vermeidet. Dort **sagt GEditor, dass er es nicht \
                tut**, statt still zu kriechen oder zu raten:
                """),
            .table(
                headers: ["Operation", "Obergrenze", "Darüber hinaus"],
                rows: [
                    ["Klammernpaarung", "1 MB", "Lehnt ab und sagt es — das falsche Paar hervorzuheben ist schlimmer als keins"],
                    ["Visuelle Spalte in der Statusleiste", "200 KB", "Fällt auf Bytezählung zurück und markiert das mit `~`, damit die Bedeutung sichtbar bleibt"],
                    ["Markdown-Vorschau", "4 MB", "Lehnt ab und erklärt"],
                ]
            ),
            .warning("""
                Eine Zahl, die gleich aussieht, aber etwas anderes bedeutet, ist die schlimmste Art \
                von Fehler. Deshalb steht bei einer Spalte jenseits der Grenze `~1234` und nicht \
                `1234`.
                """),
            .heading("Tipps für Protokolldateien"),
            .bullets([
                "`Ablage ▸ Datei verfolgen (tail -f)` lädt nach, was ans Ende geschrieben wird. Das Dokument wird währenddessen **schreibgeschützt** — tippen, während neuer Text hereinströmt, heißt zwei Schreiber streiten um ein Dokument, und der Verlierer ist immer das, was Sie gerade getippt haben.",
                "Protokollzeilen werden **nach Schweregrad eingefärbt** und lassen sich nach Stufe filtern.",
                "Die **Dokumentkarte** (`⌥⌘M`) beschreibt die ganze Datei, nicht nur den Teil auf dem Bildschirm.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App-Store-Fassung und Direktdownload",
        summary: "Drei Funktionen, die nur die Direktfassung hat, und warum.",
        keywords: ["app store", "sandbox", "download", "cli", "plug-in", "unterschied"],
        blocks: [
            .paragraph("""
                GEditor erscheint in zwei Fassungen. Sie stammen aus **derselben Quelle**, und die \
                App erkennt beim Start, welche sie ist. Der Unterschied liegt darin, was die App \
                Sandbox erlaubt.
                """),
            .table(
                headers: ["Funktion", "App Store", "Direktdownload"],
                rows: [
                    ["Bearbeiten, CSV, Bereinigen, Mining, Berichte", "Ja", "Ja"],
                    ["Das Kommandozeilenwerkzeug `geditor`", "Nein", "Ja"],
                    ["Text durch einen externen Befehl filtern", "Nein", "Ja"],
                    ["Native Plug-ins (eigener Prozess)", "Nein", "Ja"],
                    ["Selbstaktualisierung", "Über den App Store", "In der App"],
                ]
            ),
            .paragraph("""
                Jedes „Nein“ oben folgt derselben Regel: die Sandbox **verbietet, Code außerhalb der \
                App auszuführen**. Das ist der Preis des App-Store-Vertriebs, kein Versehen.
                """),
            .note("""
                In der App-Store-Fassung **bleiben diese Befehle im Menü** und erklären, warum sie \
                nicht verfügbar sind, statt zu verschwinden. Ein fehlender Menüeintrag wird zur \
                Supportanfrage; eine Antwort an Ort und Stelle nicht.
                """),
            .heading("Dateizugriff in der App-Store-Fassung"),
            .paragraph("""
                Die Sandbox-Fassung berührt nur Dateien, die Sie selbst geöffnet oder hineingezogen \
                haben. GEditor bewahrt für jeden Tab und für den Arbeitsbereichsordner ein \
                **sicherheitsbereichs-Lesezeichen** auf, sodass Ihre Sitzung nach dem Beenden wieder \
                aufgeht, ohne erneut um Erlaubnis zu fragen.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Bearbeiten

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Bearbeiten",
        summary: "Viele Stellen gleichzeitig ändern, mit Zeilen arbeiten, und die verborgenen Regeln, die man zuerst kennen sollte.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Mehrere Cursor",
        summary: "Jede passende Stelle auswählen, einmal tippen, alle ändern.",
        keywords: ["multi-cursor", "cmd+d", "mehrfachauswahl"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Das ersetzt die meisten Momente, in denen Sie gerade einen regulären Ausdruck \
                schreiben wollten. Wählen Sie ein Wort, drücken Sie einige Male `⌘D`, um die \
                nächsten Vorkommen einzusammeln, und tippen Sie — alle Stellen ändern sich zugleich.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Das nächste Vorkommen zur Auswahl hinzufügen"),
                HelpShortcut("⌘ + Klick", "Einen weiteren Cursor an die Klickstelle setzen"),
                HelpShortcut("Esc", "Alle verwerfen, zurück zu einem Cursor"),
                HelpShortcut("⌥ + Ziehen", "Spaltenblockauswahl (ein anderer Weg zu vielen Cursorn)"),
            ]),
            .heading("Regeln, die man kennen sollte"),
            .bullets([
                "Tippen, Löschen und Einsetzen über viele Cursor hinweg ist **ein** Widerrufsschritt, nicht einer je Cursor.",
                "Die Cursor überleben Pfeiltastenbewegungen — die ganze Gruppe wandert gemeinsam.",
                "`⌘D` überspringt Stellen, die schon in der Auswahl sind: zu häufiges Drücken stapelt nie zwei Cursor aufeinander.",
            ]),
            .note("""
                `⌘D` auf einem Wort in einer langen Zeichenkette war früher langsam. Die Erkennung \
                der Wortgrenzen liest jetzt in Stapeln — etwa **42× schneller** bei einer 1-MB-Kette, \
                was das Ganze auf Datendateien brauchbar macht, nicht nur auf Quelltext.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Spaltenblockauswahl",
        summary: "Ein Rechteck über viele Zeilen auswählen — mit der Maus oder über die Tastatur.",
        keywords: ["spaltenmodus", "blockauswahl", "alt ziehen", "rechteck", "tastatur", "pfeile"],
        blocks: [
            .paragraph("""
                Halten Sie `⌥` und ziehen Sie, um einen **rechteckigen Block** auszuwählen. Tippen, \
                Löschen und Einsetzen folgen dem Block. Einen Block an einem einzelnen Cursor \
                einzusetzen behält sein Rechteck.
                """),
            .shortcuts([
                HelpShortcut("⌥ + Ziehen", "Einen Block auswählen"),
                HelpShortcut("⌥⌘← →", "Den Block eine Spalte nach links/rechts erweitern"),
                HelpShortcut("⌥⌘↑ ↓", "Den Block eine Zeile nach oben/unten erweitern"),
            ]),
            .paragraph("""
                Der Tastaturweg ist kein Notbehelf für die Maus: einen 40-Zeilen-Block zu ziehen \
                heißt durch einen Bildlauf zu ziehen, während `⌥⌘` + Pfeile die Genauigkeit Spalte \
                für Spalte behält. Jede **andere** Taste (oder Tippen) beendet den Block, den Sie \
                erweitert haben.
                """),
            .heading("Spalten sind hier VISUELLE Spalten"),
            .paragraph("""
                Ein Tabulator dehnt sich bis zum nächsten Halt Ihrer Tabulatorbreite aus, statt als \
                eine Spalte zu zählen. Genau das lässt tabulator- und leerzeicheneingerückte Zeilen \
                **so ausrichten, wie sie auf dem Bildschirm stehen**.
                """),
            .paragraph("Mehrbyte-Text bleibt eine Spalte: `Nguyễn` belegt sechs Spalten, nicht neun."),
            .table(
                headers: ["Situation", "Was GEditor tut"],
                rows: [
                    ["Die Zielspalte landet mitten im Tabulator", "Springt zur näheren Kante; bei Gleichstand nach links"],
                    ["Eine Zeile ist kürzer als die Startspalte", "Diese Zeile steuert eine leere Auswahl bei und nimmt getippten Text trotzdem an"],
                    ["Einen Block an einem einzelnen Cursor einsetzen", "Behält das Rechteck und fügt in die darunterliegenden Zeilen ein"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Spalteneditor",
        summary: "Text, eine Zahlen- oder eine Datumsreihe in jede Zeile eines Blocks einfügen.",
        keywords: ["spalteneditor", "nummerierung", "folge", "reihe"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Wählen Sie einen Spaltenblock und öffnen Sie `Bearbeiten ▸ Spalteneditor…` (`⌥⌘C`). \
                Der Dialog hat eine **Vorschau**, bevor irgendetwas angewendet wird.
                """),
            .table(
                headers: ["Modus", "Parameter", "Wann"],
                rows: [
                    ["Text", "Eine feste Zeichenkette", "Dasselbe Präfix/Suffix an jede Zeile hängen"],
                    ["Zahlenreihe", "Start · Schritt · Basis 2·8·10·16 · Nullen auffüllen", "Zeilen nummerieren, Codes erzeugen"],
                    ["Datumsreihe", "Erstes Datum · Schritt in Tagen", "Eine Spalte fortlaufender Daten erzeugen"],
                ]
            ),
            .code(language: "text", caption: "Nummerierung mit führenden Nullen, Start 1, Schritt 1",
                  source: """
                    Vorher:           Nachher (Zahlenreihe, 3 Stellen):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Ein **negativer** Schritt ist zulässig — rückwärts zählen geht.",
                "Das Einfügen in 5 000 Zeilen bleibt **ein** Widerrufsschritt.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Zeilenoperationen",
        summary: "Sortieren, entdoppeln, verschieben, verbinden, teilen, verdoppeln, löschen.",
        keywords: ["sortieren", "verdoppeln", "entdoppeln", "zeile verschieben", "verbinden", "teilen"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Mit einer Auswahl läuft der Befehl auf der Auswahl; ohne eine läuft er auf dem \
                **ganzen Dokument**. Jeder Befehl hier ist ein einziger Widerrufsschritt.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Zeile verdoppeln"),
                HelpShortcut("⌘K", "Zeile löschen"),
                HelpShortcut("⌥↑ / ⌥↓", "Zeile nach oben / unten verschieben"),
            ]),
            .heading("Drei Arten zu sortieren, und welche man wählt"),
            .table(
                headers: ["Art", "`file2` vs `file10`", "Für"],
                rows: [
                    ["A→Z / Z→A", "`file10` kommt vor `file2`", "Einfache Wortlisten"],
                    ["Natürlich", "`file2` kommt vor `file10`", "Dateinamen, kodierte IDs, Versionen"],
                ]
            ),
            .paragraph("""
                **Natürliches** Sortieren liest Ziffernfolgen als Zahlen. Das ist fast immer das, was \
                Sie wollen, wenn die Liste nummeriert ist.
                """),
            .heading("Entdoppeln"),
            .bullets([
                "**Ganzes Dokument** — jede Zeile verwerfen, die früher schon vorkam, die erste behalten.",
                "**Nur benachbarte** — gleiche Nachbarzeilen zusammenfassen, wie `uniq` unter Unix.",
            ]),
            .heading("Verbinden und Teilen"),
            .bullets([
                "**Zeilen verbinden** führt die ausgewählten Zeilen zu einer zusammen.",
                "**Nach Länge teilen** schneidet lange Zeilen bei einer bestimmten Zeichenzahl.",
                "**Nach Zeichen teilen** schneidet bei jedem Vorkommen eines Zeichens, das Sie eingeben — etwa um eine CSV-Zeile in ihre Zellen zu zerlegen.",
            ]),
            .note("""
                Die **letzte Zeile** einer Datei zu verdoppeln ergänzt den fehlenden Zeilenumbruch; \
                bis zum Dokumentende zu löschen schluckt auch den Umbruch der vorherigen Zeile. \
                Beides weicht von der naiven Umsetzung ab, und beides gibt es, damit die Datei nicht \
                mit einer überzähligen Leerzeile endet — oder ohne die nötige.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Leerraum und Einrückung",
        summary: "Streunenden Leerraum säubern, Tab ↔ Leerzeichen wandeln, und ein Schalter zum Nachdenken.",
        keywords: ["leerraum", "tabulator", "einrückung", "leerzeilen"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Befehl", "Was er tut"],
                rows: [
                    ["Leerzeilen entfernen", "Verwirft jede Zeile ohne Inhalt"],
                    ["Aufeinanderfolgende Leerzeilen zusammenfassen", "Mehrere Leerzeilen hintereinander werden zu einer"],
                    ["Leerraum am Zeilenende abschneiden", "Entfernt streunende Leerzeichen und Tabulatoren am Zeilenende"],
                    ["Tab → Leerzeichen", "Wandelt Tabulatoren in Leerzeichen bei der aktuellen Breite"],
                    ["Leerzeichen → Tab", "Die Gegenrichtung"],
                ]
            ),
            .heading("Einrückung je Sprache"),
            .paragraph("""
                Klicken Sie `Tab: 4` in der Statusleiste. Der obere Teil des Menüs ändert sie für die \
                **ganze App**; der untere — `Nur für Go`, `Nur für Python`… — gilt nur für die \
                Sprache der offenen Datei und merkt sich, ob Tabulatoren oder Leerzeichen gelten.
                """),
            .paragraph("""
                Menschen wählen die Einrückung nicht nach Geschmack, sondern nach **Konvention der \
                Gemeinschaft**: Go nimmt Tabulatoren (`gofmt` überstimmt alles andere), Python vier \
                Leerzeichen nach PEP 8, JavaScript und YAML meist zwei. Eine Zahl für alle Sprachen \
                bedeutet, dass jede Datei, die Sie anfassen, Zeilen bekommt, die Sie nie bearbeitet \
                haben.
                """),
            .code(language: "json", caption: "settings.json",
                  source: """
                    "languageIndent": {
                      "go":         { "width": 4, "usesTabs": true },
                      "python":     { "width": 4, "usesTabs": false },
                      "javascript": { "width": 2, "usesTabs": false }
                    }
                    """),
            .note("""
                Es in `settings.json` zu deklarieren geht ebenfalls — der Schlüssel ist der \
                Sprachcode (`go`, `python`, `javascript`…). Nicht aufgeführte Sprachen nutzen die \
                gemeinsame `tabWidth`.
                """),
            .heading("Warum „beim Sichern abschneiden“ standardmäßig AUS ist"),
            .paragraph("""
                Der Schalter `Ablage ▸ Leerraum am Zeilenende beim Sichern abschneiden` bearbeitet \
                **Zeilen, die Sie nie angefasst haben**. Standardmäßig eingeschaltet wird aus einer \
                Ein-Wort-Korrektur im Repository eines anderen ein Diff über tausend Zeilen, und der \
                Prüfer findet die echte Änderung nicht mehr.
                """),
            .paragraph("""
                Ist er an, ist das Abschneiden ein **eigener Widerrufsschritt** vor dem Schreiben — \
                ein Widerruf bringt das Dokument in den vorherigen Zustand, ohne zu verlieren, was \
                Sie gerade gesichert haben.
                """),
            .heading("Automatische Einrückung"),
            .bullets([
                "Eine neue Zeile erbt die Einrückung der vorherigen, plus eine Ebene nach einem öffnenden Zeichen — `{` bei Klammersprachen, `:` bei Python und YAML.",
                "Gemessen wird in **visuellen Spalten**, sodass Dateien mit gemischten Tabulatoren und Leerzeichen auf dem Bildschirm bündig bleiben.",
                "Es gibt **keine** Regel „`}` tippen rückt die Zeile neu ein“. Diese Regel bearbeitet eine Zeile, die Sie schon fertig hatten, und sie ist das meistbeklagte Verhalten in jedem Editor, der sie hat.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Groß-/Kleinschreibung und Namenskonventionen",
        summary: "Acht Umwandlungen, darunter camelCase, snake_case und kebab-case.",
        keywords: ["schreibweise", "großbuchstaben", "kleinbuchstaben", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Wird auf die Auswahl angewendet. Alle liegen im Menü `Format`."),
            .table(
                headers: ["Befehl", "`tổng doanh thu` wird zu"],
                rows: [
                    ["GROSSBUCHSTABEN", "`TỔNG DOANH THU`"],
                    ["kleinbuchstaben", "`tổng doanh thu`"],
                    ["Wortanfänge Groß", "`Tổng Doanh Thu`"],
                    ["Satzanfang groß", "`Tổng doanh thu`"],
                    ["Schreibweise umkehren", "Dreht jedes Zeichen um"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Die letzten drei entfernen vietnamesische Akzente, denn sie erzeugen **Bezeichner im \
                Code** — wo akzentuierte Buchstaben meist nicht erlaubt sind.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Kommentare und Klammernpaarung",
        summary: "⌘/ nutzt das eigene Zeichen jeder Sprache; ⌃⌘B springt zur passenden Klammer.",
        keywords: ["kommentar", "klammer", "cmd+/", "paarung"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` wählt das Kommentarzeichen **nach der Sprache des Dokuments**: `#` für Python, \
                `//` für Rust und C, `<!-- -->` für XML und HTML.
                """),
            .heading("Der ganze Block geht in eine Richtung"),
            .paragraph("""
                Ist auch nur eine Zeile im Block unkommentiert, kommentiert der Befehl **alles**. \
                Zeilenweise zu entscheiden machte aus einem halb kommentierten Block ein Schachbrett. \
                Das Zeichen wird an der flachsten Einrückung des Blocks eingefügt, damit der Block \
                seine Form behält.
                """),
            .heading("Zur passenden Klammer springen"),
            .bullets([
                "`⌃⌘B` springt zu der Klammer, die zu der unter dem Cursor passt.",
                "Klammern in **Zeichenketten** oder **Kommentaren** zählen nicht — ein leichter Lexer unterscheidet sie.",
                "Jenseits von **1 MB** lehnt der Befehl ab und sagt es, statt auf halbem Weg zu ankern und zu raten. Das falsche Paar hervorzuheben ist schlimmer, als gar keins hervorzuheben.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Widerrufen und Zwischenablage",
        summary: "Unbegrenzter Widerrufsverlauf und eine Zwischenablage mit mehreren Plätzen.",
        keywords: ["widerrufen", "wiederholen", "zwischenablage", "einsetzen", "verlauf"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Widerrufen / Wiederholen"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Ausschneiden / Kopieren / Einsetzen"),
                HelpShortcut("⇧⌘V", "Verlauf der Zwischenablage"),
            ]),
            .heading("Eine Massenoperation ist EIN Schritt"),
            .paragraph("""
                Eine Million Zeilen sortieren, zehntausend Treffer ersetzen, mit dem Spalteneditor in \
                fünftausend Zeilen einfügen — jedes davon macht **ein** `⌘Z` rückgängig.
                """),
            .paragraph("""
                Der Widerrufsverlauf liegt in GEditors eigenem Textpuffer statt im `UndoManager` des \
                Systems, genau aus diesem Grund: der `UndoManager` zählt Tastenanschläge.
                """),
            .heading("Verlauf der Zwischenablage"),
            .paragraph("""
                `⇧⌘V` öffnet eine Liste dessen, was Sie zuletzt kopiert haben, und setzt den \
                gewählten Eintrag ein. Nützlich, wenn Sie zwei Schnipsel an vielen Stellen abwechseln \
                müssen.
                """),
        ]
    )
}
