import Foundation

/// Deutscher Hilfeinhalt — Teil 5: Berichte, Wissenspaket, Automatisierung, Anwendung.
extension HelpDE {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Berichte und Diagramme",
        summary: "Eine Textdatei, die einen HTML-Bericht erzeugt, dessen Zahlen neu gerechnet werden, dazu Mermaid-Diagramme.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md`-Berichte",
        summary: "Markdown plus vier ausführbare Blockarten — links schreiben, rechts vorschauen.",
        keywords: ["bericht", "greport", "html", "export", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Eine `.greport.md`-Datei ist **gewöhnliches Markdown** plus einige ausführbare \
                eingezäunte Blöcke. Ihre Darstellung erzeugt eine **eigenständige** HTML-Datei — kein \
                Netz, keine Begleitdateien — die jeder öffnen kann.
                """),
            .paragraph("""
                Weil es reiner Text ist, lässt er sich **vergleichen, versionieren und teilen** — \
                dieselbe Haltung wie bei Bereinigungsrezepten und Qualitätsregelwerken.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — ein vollständiger Bericht",
                  source: """
                    ---
                    title: Verkaufsbericht August
                    source: sales-2026-08.csv
                    ---

                    # Verkaufsbericht August

                    Zahlen zum 31. August 2026.

                    ## Umsatz je Provinz

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Umsatz je Provinz
                    y_label: Umsatz
                    number_format: vi
                    suffix: " ₫"
                    source: Quelle — sales-2026-08.csv
                    ```

                    ## Qualität der Quelldaten

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Die Blockarten"),
            .table(
                headers: ["Block", "Erzeugt"],
                rows: [
                    ["`query`", "Eine Tabelle aus einer DuckDB-SQL-Anweisung"],
                    ["`chart`", "Ein Diagramm"],
                    ["`quality`", "Eine Datenqualitäts-Bewertungskarte"],
                    ["`mining`", "Eine Rangtabelle des Gruppen-Minings"],
                    ["`mermaid`", "Ein Diagramm"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                Der `---`-Block oben erklärt `title` und `source` — die vorgegebene Datenquelle für \
                jeden Block, der keine eigene nennt.
                """),
            .note("""
                Die Vorschau baut sich neu auf, sobald Sie aufhören zu tippen, aber sie **analysiert \
                nur**; sie führt nicht bei jedem Tastendruck Abfragen aus. Dokument- und Datenfehler \
                werden getrennt gemeldet — *„dem chart-Block fehlt der Schlüssel `kind`“* ist ein \
                Dateifehler, *„die Spalte `doanh_thu` gibt es nicht“* ein Datenfehler.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "Der `query`-Block",
        summary: "Eine DuckDB-Anweisung wird zu einer Tabelle im Bericht.",
        keywords: ["abfrage", "sql", "tabelle", "bericht", "block"],
        blocks: [
            .paragraph("""
                Der Inhalt des Blocks ist **eine SQL-Anweisung**, ausgeführt auf der Quelle des \
                Berichts. Die Tabelle heißt `t`, im selben Dialekt wie im Abfragebereich.
                """),
            .code(language: "text", caption: "Ein parametrisierter query-Block",
                  source: """
                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu
                    FROM t
                    WHERE thang = :thang
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    ```
                    """),
            .paragraph("""
                `:thang` ist ein **Parameter**. Er wird beim Darstellen geliefert — aus der Shell mit \
                `--param thang=8` oder aus einer Listendatei beim Erzeugen im Stapel.
                """),
            .note("""
                Tabellen in einem Datenbericht **sollten aus einem query-Block kommen**, nicht von \
                Hand getippt sein. Eine von Hand getippte Tabelle rechnet sich nicht neu, wenn sich \
                die Zahlen ändern, und über kurz oder lang widerspricht sie dem Rest des Berichts.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "Der `chart`-Block",
        summary: "Eine YAML-Konfiguration wird zu einem Diagramm — und die wichtigste Regel des Formats.",
        keywords: ["diagramm", "yaml", "bericht", "zeichnen"],
        blocks: [
            .code(language: "yaml", caption: "Jeder Schlüssel eines chart-Blocks",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Umsatz je Provinz
                    x_label: Provinz
                    y_label: Umsatz
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Quelle — sales.csv, Stand 26. Aug. 2026
                    """),
            .heading("Ohne `query` nutzt er das Ergebnis des query-Blocks DIREKT DARÜBER"),
            .paragraph("""
                Das ist die wichtigste Regel des Formats. Dank ihr wiederholt der übliche Bericht \
                „eine Tabelle und dann ein Diagramm dieser Tabelle“ das SQL nicht — und es zu \
                wiederholen heißt, dass die beiden Kopien irgendwann auseinanderlaufen, und dann sagen \
                Tabelle und Diagramm auf derselben Seite Verschiedenes.
                """),
            .warning("""
                Dafür **zählt die Reihenfolge der Blöcke**: einen query-Block dazwischen einzufügen \
                ändert die Daten des Diagramms darunter.
                """),
            .heading("Warum `source` ein eigener Schlüssel ist"),
            .paragraph("""
                Ein als Fließtext unter das Diagramm geschriebener Quellenhinweis erscheint tadellos — \
                auf dem Bildschirm. Aber das Diagramm wird als PNG exportiert und anderswo eingesetzt, \
                und der Fließtext bleibt zurück. Als Schlüssel wird er **in das Bild** gezeichnet und \
                reist mit.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "Der `quality`-Block",
        summary: "Eine Datenqualitäts-Bewertungskarte innerhalb des Berichts.",
        keywords: ["qualität", "bewertungskarte", "bericht", "block"],
        blocks: [
            .code(language: "yaml", caption: "Jeder Schlüssel eines quality-Blocks",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # leer heißt die eigene Quelle des Berichts
                    title: Datenqualität Verkauf August
                    rules: true                 # die Regeltabelle bestanden/nicht bestanden zeigen
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # das Bezugsdatum für „Aktualität“ festlegen
                    fail_under: 90              # darunter wechselt die Karte auf Warnfarbe
                    """),
            .table(
                headers: ["`chart`", "Zeichnet"],
                rows: [
                    ["`violations`", "Zeilenzahlen für die **nicht bestandenen** Regeln — beantwortet „was zuerst beheben“"],
                    ["`dimensions`", "Die Noten der sechs Dimensionen"],
                    ["`none`", "Nur Tabelle, kein Diagramm"],
                ]
            ),
            .note("""
                Setzen Sie `now:` in einem wiederkehrenden Bericht. Ohne das vergleicht *Aktualität* \
                mit dem Darstellungszeitpunkt: den Bericht des Vormonats erneut darzustellen ergibt \
                eine andere Note als die veröffentlichte.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "Der `mining`-Block",
        summary: "Gruppen nach Ausreißern, Prognosefehler oder Korrelationsabweichung reihen.",
        keywords: ["mining", "bericht", "gruppenrangfolge"],
        blocks: [
            .code(language: "yaml", caption: "Jeder Schlüssel eines mining-Blocks",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # die Spalte für Ausreißer und Prognose
                    pair: chi_phi             # eine zweite Spalte, für die Korrelation je Gruppe
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # leer heißt die eigene Quelle des Berichts
                    title: Mining nach Provinz
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Reiht nach"],
                rows: [
                    ["`anomalies`", "Der Gruppe mit den meisten auffälligen Zeilen"],
                    ["`forecast_error`", "Der Gruppe mit der schlechtesten Prognose"],
                    ["`correlation_gap`", "Der Gruppe, deren Korrelation am stärksten von der zusammengefassten Tabelle abweicht — fängt das Simpson-Paradoxon"],
                ]
            ),
            .warning("""
                **Kein Schlüssel schaltet den „Methode“-Block ab.** Eine Gruppenrangfolge ohne ihre \
                Methode lässt dem Leser keine Möglichkeit zu wissen, gegen welchen Zaun „die meisten \
                Ausreißer“ gemessen wurde. Wer sie verbergen will, kennt die gewünschte Antwort bereits.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Berichte im Stapel erzeugen",
        summary: "Eine Vorlage, eine Parameterliste, viele Berichte.",
        keywords: ["stapel", "massenhaft", "parameter", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Eine Berichtsvorlage, für jede Filiale oder jeden Monat ausgeführt. Die Parameterliste \
                ist eine CSV- oder JSON-Datei — **eine Zeile je Bericht**.
                """),
            .code(language: "text", caption: "list.csv — eine Zeile je Bericht",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Den ganzen Stapel aus der Shell darstellen",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Oder einen Bericht mit von Hand übergebenen Parametern",
                  source: """
                    geditor --report template.greport.md \\
                            --param thang=8 --param tinh="Hà Nội" \\
                            --out ./reports/
                    """),
            .seeAlso(["khoi-query", "dong-lenh"]),
        ]
    )

    static let mermaid = HelpTopic(
        id: "mermaid",
        title: "Mermaid-Diagramme",
        summary: "Diagramme in Text zeichnen, sie mit Befehlen bearbeiten, in beide Richtungen synchron vorschauen.",
        keywords: ["mermaid", "diagramm", "flussdiagramm", "sequenz", "zeichnen"],
        commands: [
            "Sơ đồ Mermaid: xem trước", "Sơ đồ Mermaid: chèn mẫu…",
            "Sơ đồ Mermaid: thêm phần tử…", "Sơ đồ Mermaid: nối hai phần tử đang chọn",
            "Sơ đồ Mermaid: sửa nhãn phần tử đang chọn…", "Sơ đồ Mermaid: xoá phần tử đang chọn",
            "Sơ đồ Mermaid: đưa message lên trên", "Sơ đồ Mermaid: đưa message xuống dưới",
            "Sơ đồ Mermaid: định dạng lại", "Sơ đồ Mermaid: tách khối ra tệp .mmd…",
            "Sơ đồ Mermaid: nhúng tệp tham chiếu trở lại",
        ],
        blocks: [
            .paragraph("""
                Mermaid zeichnet Diagramme **aus Text**: Sie schreiben eine Beschreibung, die Maschine \
                zeichnet sie. Ein Diagramm lässt sich daher vergleichen und versionieren — was eine \
                Bilddatei nicht kann.
                """),
            .paragraph("""
                Öffnen Sie `Mermaid-Diagramm: Vorschau` für eine Ansicht neben dem Editor. Beide sind \
                **in beide Richtungen synchron**: wählen Sie ein Element im Bild, und der Cursor \
                springt in dessen Zeile.
                """),
            .heading("Mit Befehlen bearbeiten, nicht durch Neutippen"),
            .table(
                headers: ["Befehl", "Was er tut"],
                rows: [
                    ["Vorlage einfügen…", "Ein fertiges Gerüst für jeden Diagrammtyp einfügen"],
                    ["Element hinzufügen…", "Einen Knoten oder Teilnehmer hinzufügen"],
                    ["Die zwei gewählten Elemente verbinden", "Einen Pfeil zwischen ihnen zeichnen"],
                    ["Beschriftung des gewählten Elements bearbeiten…", "Den Text ändern, ohne die Zeile zu suchen"],
                    ["Gewähltes Element löschen", "Den Knoten **und** jede Kante, die ihn berührt, entfernen"],
                    ["Nachricht nach oben / unten", "Schritte in einem Sequenzdiagramm umordnen"],
                    ["Neu formatieren", "Den ganzen Block einrücken und ausrichten"],
                ]
            ),
            .heading("In eine Datei auslagern und wieder einbetten"),
            .paragraph("""
                Große Diagramme gehören in eine eigene `.mmd`-Datei: `Block in eine .mmd-Datei \
                auslagern…` verschiebt ihn und lässt einen Verweis zurück. `Die verwiesene Datei wieder \
                einbetten` tut das Gegenteil, wenn Sie eine einzelne Datei verschicken müssen.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Gängige Mermaid-Syntax",
        summary: "Die vier meistgenutzten Diagrammtypen, jeder mit einer Vorlage, die läuft.",
        keywords: ["mermaid", "syntax", "flussdiagramm", "sequenz", "gantt", "klasse", "vorlage"],
        blocks: [
            .code(language: "mermaid", caption: "Flussdiagramm — ein Bestellfreigabeprozess",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Sequenzdiagramm — ein Zahlungsablauf",
                  source: """
                    sequenceDiagram
                        participant K as Khách
                        participant W as Website
                        participant T as Cổng thanh toán
                        K->>W: Đặt hàng
                        W->>T: Tạo giao dịch
                        T-->>W: Mã giao dịch
                        W-->>K: Chuyển tới trang thanh toán
                        K->>T: Xác nhận
                        T-->>W: Kết quả
                    """),
            .code(language: "mermaid", caption: "Klassendiagramm — ein Datenmodell",
                  source: """
                    classDiagram
                        class DonHang {
                            +String maDon
                            +Date ngayDat
                            +tongTien() Double
                        }
                        class KhachHang {
                            +String ten
                            +String soDienThoai
                        }
                        KhachHang "1" --> "*" DonHang : đặt
                    """),
            .code(language: "mermaid", caption: "Gantt — ein Veröffentlichungsplan",
                  source: """
                    gantt
                        title Kế hoạch phát hành
                        dateFormat YYYY-MM-DD
                        section Chuẩn bị
                        Viết tài liệu     :a1, 2026-09-01, 10d
                        Kiểm thử          :a2, after a1, 7d
                        section Phát hành
                        Nộp App Store     :a3, after a2, 3d
                    """),
            .table(
                headers: ["Knotenform", "Schreiben"],
                rows: [
                    ["Rechteck", "`A[Label]`"],
                    ["Abgerundet", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Raute (Entscheidung)", "`A{Label}`"],
                    ["Zylinder (Daten)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Pfeil", "Schreiben"],
                rows: [
                    ["Durchgezogen, mit Spitze", "`A --> B`"],
                    ["Gepunktet", "`A -.-> B`"],
                    ["Dick", "`A ==> B`"],
                    ["Beschriftet", "`A -- label --> B`"],
                ]
            ),
            .note("""
                Die Richtung eines Flussdiagramms folgt direkt auf `flowchart`: `TD` von oben nach \
                unten, `LR` von links nach rechts, dazu `BT` und `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Wissenspaket

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Das Wissenspaket",
        summary: "Zerteilen, Suchindizes, Wissensgraphen, Entitäten und Bewertung der Suche.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Was das Wissenspaket ist",
        summary: "Werkzeuge, um Daten für ein Frage-Antwort-System über Dokumente vorzubereiten und zu prüfen.",
        keywords: ["rag", "wissen", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Wenn man ein System baut, das Fragen aus einer Dokumentsammlung beantwortet, steckt die \
                meiste Arbeit nicht im Modell, sondern in der **Vorbereitung der Daten**: Dokumente in \
                sinnvolle Abschnitte schneiden, die Qualität dieser Abschnitte prüfen, einen Index \
                bauen und **messen, ob die Suche tatsächlich das Richtige findet**.
                """),
            .paragraph("""
                Dieses Kapitel ist genau das Werkzeug dafür. Es läuft **vollständig auf Ihrer Maschine** \
                und ruft nie das Netz.
                """),
            .table(
                headers: ["Aufgabe", "Werkzeug"],
                rows: [
                    ["Dokumente in Abschnitte schneiden", "Chunk-Vorschau"],
                    ["Abschnitte prüfen und bewerten", "JSONL-Chunk-Prüfung"],
                    ["Zwischen Datenformen wandeln", "Wissensumwandlung"],
                    ["Einen Beziehungsgraphen bauen und prüfen", "Wissensgraph"],
                    ["Eigennamen in Text finden", "Entitätsmarkierung"],
                    ["Die Suchqualität messen", "Suchlabor"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Eine JSONL-Sammlung zerteilen und prüfen",
        summary: "Chunk-Grenzen am Text selbst vorschauen, dann die ganze Sammlung bewerten.",
        keywords: ["chunk", "jsonl", "sammlung", "überlappung", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Chunk-Vorschau"),
            .paragraph("""
                Öffnen Sie ein Text- oder Markdown-Dokument, wählen Sie eine Strategie und eine \
                Chunk-Größe. Die Grenzen werden **am Text selbst hervorgehoben**: Sie sehen, wo ein \
                Schnitt mitten in einen Satz oder durch eine Tabelle fällt, bevor Sie etwas exportieren.
                """),
            .bullets([
                "**Feste Größe** mit Überlappung.",
                "**Nach Struktur** — an Markdown-Überschriften, wobei der Fluss des Dokuments erhalten bleibt.",
                "**Nach Absatz**, bis die Größe erreicht ist zusammengefasst.",
            ]),
            .heading("Eine vorhandene JSONL-Sammlung prüfen"),
            .paragraph("""
                Für eine Sammlung, die Sie schon haben (ein JSON-Chunk je Zeile), beantwortet `JSONL: \
                Chunks prüfen…`: welche Zeilen kein gültiges JSON sind, welche Chunks zu kurz oder zu \
                lang sind, welche einander doppeln und welche mitten im Satz geschnitten wurden.
                """),
            .note("""
                Eine Sammlung lässt sich auch mit **demselben Sechs-Dimensionen-Rahmen** wie \
                Tabellendaten bewerten — nutzen Sie den Schlüssel `corpus:` in einem `quality`-Block \
                eines Berichts.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Wissensformate wandeln",
        summary: "Chunks zwischen JSONL · CSV · Markdown, Graphen zwischen DOT · Mermaid · Kantenlisten.",
        keywords: ["wandeln", "jsonl", "dot", "mermaid", "kantenliste"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Von", "Nach"],
                rows: [
                    ["JSONL-Chunks", "CSV · Markdown"],
                    ["CSV-Chunks", "JSONL · Markdown"],
                    ["DOT-Graph", "Mermaid · Kantenliste"],
                    ["Kantenliste", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Vor dem Erstellen des neuen Tabs gibt es eine **Fünf-Zeilen-Vorschau**, derselbe \
                Mechanismus wie bei der CSV-Umwandlung.
                """),
            .paragraph("""
                `Tripel/Kanten als Tabelle öffnen` zeigt eine Tripeldatei oder Kantenliste als Tabelle — \
                filtern und sortieren Sie sie wie jede andere CSV.
                """),
            .note("""
                Die Richtung **Markdown → JSONL** steckt nicht in diesem Befehl: diese Richtung *ist* \
                das Zerteilen, und der Befehl verweist Sie dorthin. Zwei Umsetzungen eines Schnitts \
                ergäben zwei verschiedene Ergebnisse.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Wissensgraphen",
        summary: "Syntax prüfen, Gesundheit bewerten und Algorithmen auf Graphen mit einer Million Kanten laufen lassen.",
        keywords: ["graph", "dot", "cypher", "pagerank", "louvain", "syntaxprüfung"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor liest Graphen als **DOT**, als **Kantenlisten** und als **Tripel**. \
                `Graphsyntax prüfen` fängt Syntaxfehler, lose Knoten und Kanten, die auf nicht \
                vorhandene Knoten zeigen.
                """),
            .heading("Verfügbare Algorithmen"),
            .table(
                headers: ["Algorithmus", "Beantwortet"],
                rows: [
                    ["k-Sprung-Nachbarschaft", "Was in k Schritten mit diesem Knoten zusammenhängt"],
                    ["Zusammenhangskomponenten", "Aus wie vielen unverbundenen Teilen der Graph besteht"],
                    ["PageRank", "Welche Knoten wichtig sind"],
                    ["Louvain", "Wie sich der Graph in Gemeinschaften teilt"],
                ]
            ),
            .paragraph("""
                Auf einem Graphen mit **einer Million Kanten** laufen alle vier irgendwo zwischen \
                wenigen Millisekunden und etwa einer Sekunde.
                """),
            .note("""
                Ein Graph lässt sich ebenfalls mit dem **Sechs-Dimensionen-Rahmen** bewerten, der für \
                Tabellen und Sammlungen dient — nutzen Sie den Schlüssel `graph:` in einem \
                `quality`-Block.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Entitäten aus einer Liste markieren",
        summary: "Eine Eigennamenliste laden und jedes Vorkommen finden — nach drei für Vietnamesisch gebauten Regeln.",
        keywords: ["entität", "eigenname", "ner", "markierung", "abgleich"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Laden Sie eine Namensliste (Firmen, Produkte, Orte), und GEditor hebt jedes Vorkommen im \
                Dokument hervor, mit einer Zähltabelle.
                """),
            .heading("Drei Abgleichsregeln, alle aus vietnamesischen Daten"),
            .bullets([
                "**Der längste Treffer gewinnt.** Stehen `An Phát` und `Công ty An Phát` beide in der Liste, muss ein Satz mit der längeren Wendung auf die längere passen — sonst wird er entzweigeschnitten und als zwei Entitäten gezählt, was die Statistik **aufbläht**.",
                "**Wortgrenzen sind Pflicht.** `An` darf nicht innerhalb von `Anh` oder `Hoàn` treffen. Vietnamesische Eigennamen sind kurz und teilen Silben mit unzähligen gewöhnlichen Wörtern.",
                "**Groß-/Kleinschreibung egal, Akzente aber NICHT.** `CÔNG TY` und `Công ty` sind eines; `má` und `ma` sind es nicht.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Entitätsvarianten auflösen",
        summary: "`Cty An Phát` und `Công ty An Phát` als eines erkennen — die Entscheidung bleibt trotzdem bei Ihnen.",
        keywords: ["entitätsauflösung", "varianten", "namensnormalisierung", "dubletten"],
        blocks: [
            .paragraph("""
                Dasselbe Clustern wie bei **unscharfen Dubletten** in einer CSV-Tabelle — eine \
                gemeinsame Umsetzung, nicht zwei.
                """),
            .paragraph("""
                Die Ausgabe ist ein **Vorschlag**: Sie prüfen jedes Cluster und wählen die kanonische \
                Form. Es gibt keine Taste „alle zusammenführen“, denn zwei zu 92 % ähnliche Namen \
                können zwei echte Organisationen sein.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Das Suchlabor",
        summary: "Messen, ob der Index das Richtige findet, mithilfe eines Fragensatzes mit Antworten.",
        keywords: ["suche", "bm25", "recall", "mrr", "ndcg", "bewertung"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Laden Sie einen **Bewertungssatz** — jede Zeile eine Frage mit den Chunk-Kennungen, die \
                zurückkommen sollten — und lassen Sie dann den ganzen Stapel gegen den Index laufen.
                """),
            .table(
                headers: ["Kennzahl", "Beantwortet"],
                rows: [
                    ["recall@k", "Wie viel des Antwortsatzes in den obersten k erscheint"],
                    ["MRR", "Wie weit unten das erste richtige Ergebnis steht"],
                    ["nDCG@k", "Ob die Reihung gut ist, Position eingerechnet"],
                ]
            ),
            .paragraph("""
                Die Ergebnisse kommen auch **je Frage**, die schlechtesten zuerst — das ist Ihre Liste \
                dessen, was in der Sammlung zu beheben ist, in der lohnendsten Reihenfolge.
                """),
            .warning("""
                Alle drei Kennzahlen sind **Mittelwerte**, und ein Mittelwert verbirgt vieles. Lesen \
                Sie stets die Tabelle je Frage, bevor Sie schließen, „der Index ist gut genug“.
                """),
            .paragraph("""
                Zwei Konfigurationen lassen sich nebeneinander vergleichen, und das Ergebnis fällt \
                direkt in einen `.greport.md`-Bericht, damit der nächste Lauf gleich ist.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Makros und Automatisierung

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Makros und Automatisierung",
        summary: "Aktionen aufzeichnen, im Stapel ausführen, Skripte schreiben und aus der Shell steuern.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Makros aufzeichnen und abspielen",
        summary: "Eine Abfolge aufzeichnen und wiederholen — der ganze Lauf ist ein Widerrufsschritt.",
        keywords: ["makro", "aufzeichnen", "abspielen", "wiederholen", "automatisieren"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Aufzeichnung starten / stoppen"),
                HelpShortcut("⌃P", "Abspielen"),
            ]),
            .steps([
                "`⌃R` startet die Aufzeichnung.",
                "Tun Sie das, was wiederholt werden soll — tippen, Cursor bewegen, suchen, ersetzen.",
                "`⌃R` erneut zum Stoppen.",
                "`⌃P` spielt es ab, oder `Makro ▸ Bis zum Dokumentende abspielen` lässt es bis zum Ende laufen.",
                "`Makro ▸ Makro sichern…` benennt es für spätere Sitzungen.",
            ]),
            .heading("Es zeichnet BEFEHLE auf, keine rohen Tastenanschläge"),
            .paragraph("""
                Ein Makro speichert, **was Sie getan haben**, nicht welche Tasten Sie gedrückt haben. \
                Das macht es unabhängig von der Tastaturbelegung und von der gerade aktiven \
                Eingabemethode, und es macht die Makrodatei **lesbar**, wenn Sie sie öffnen.
                """),
            .heading("Wann ein Makro anhält"),
            .table(
                headers: ["Grund", "Bedeutung"],
                rows: [
                    ["Die Wiederholungszahl ist aufgebraucht", "Normal"],
                    ["Ein `find`-Schritt fand nichts", "So hält „bis zum Dateiende abspielen“ von selbst an"],
                    ["Das Dokumentende erreicht", "Nirgendwo weiter hin"],
                    ["Sie haben abgebrochen", "`Makro ▸ Laufendes Makro abbrechen`"],
                    ["Ein Durchlauf änderte nichts und bewegte nichts", "Angehalten, damit es nicht endlos kreist"],
                ]
            ),
            .note("Der ganze Lauf — auch zehntausend Wiederholungen — ist **ein** Widerrufsschritt."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Ein Makro im Stapel ausführen",
        summary: "Über alle offenen Tabs oder über einen Ordner nicht geöffneter Dateien.",
        keywords: ["stapel", "alle tabs", "ordner", "makro", "maske"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Befehl", "Umfang", "Widerrufbar"],
                rows: [
                    ["Auf allen Tabs ausführen", "Die offenen Tabs", "Ja — ein Widerrufsschritt je Tab"],
                    ["Über einen Ordner ausführen…", "Dateien auf der Festplatte, die **nicht offen** sind", "Nein"],
                ]
            ),
            .warning("""
                Über einen Ordner auszuführen berührt Dateien, die in keinem Tab offen sind, also gibt \
                es **kein Widerrufen**. Standardmäßig **schreibt GEditor neue Dateien**, statt die \
                Originale zu überschreiben. Behalten Sie diese Vorgabe, sofern Sie keine Sicherung oder \
                kein versioniertes Repository haben.
                """),
            .heading("Dateien mit einer Maske filtern"),
            .paragraph("""
                Die Ordnerauswahl hat einen **Dateinamensfilter**: tippen Sie `*.csv;*.log`, und das \
                Makro berührt nur diese. Es ist dieselbe Maskensyntax wie bei `In einem Ordner suchen`, \
                mehrere Muster durch `;` oder `,` getrennt.
                """),
            .bullets([
                "Lassen Sie ihn **leer**, und er nimmt jede Textdatei, die GEditor lesen kann — das bisherige Verhalten.",
                "Die Maske **ersetzt** jene Endungsliste, statt sie weiter einzuengen: tippen Sie `*.bak`, und es läuft auf `.bak`-Dateien, obwohl diese Endung nicht auf der Textliste steht.",
                "Passt nichts, **wiederholt die Meldung Ihre Maske**, statt einen leeren Ordner zu beschuldigen.",
            ]),
            .paragraph("""
                Dieses Feld hat einen sehr praktischen Grund: ein Ordner enthält 400 `.json`-Dateien und \
                12 `.log`-Dateien, und Ihr Makro räumt nur Protokolle auf. Ohne Maske werden auch die \
                anderen 400 verarbeitet — und da der Stapel neue Dateien schreibt, hinterlässt ein \
                Fehler 400 Stück Abfall.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Syntax der Makrodateien",
        summary: "Sieben Schrittarten, das vollständige JSON-Format und zwei Makros, die laufen.",
        keywords: ["makro", "json", "syntax", "format", "von hand ändern", "teilen"],
        blocks: [
            .paragraph("""
                Jedes Makro ist **eine eigene JSON-Datei** im Ordner `macros/` von GEditor. Eine \
                Beschädigung bleibt auf ein Makro begrenzt, und eines mit einem Kollegen zu teilen heißt, \
                eine Datei zu schicken.
                """),
            .code(language: "text", caption: "Wo die Dateien liegen",
                  source: "~/Library/Application Support/GEditor/macros/<makroname>.json"),
            .heading("Die sieben Schrittarten"),
            .table(
                headers: ["Schritt", "Geschrieben als", "Bedeutung"],
                rows: [
                    ["Text einfügen", "`{\"insert\": {\"_0\": \"text\"}}`", "Am Cursor tippen; mit Auswahl ersetzt es sie"],
                    ["Rückwärts löschen", "`{\"deleteBackward\": {}}`", "Wie die Löschtaste"],
                    ["Vorwärts löschen", "`{\"deleteForward\": {}}`", "Wie ⌦"],
                    ["Bewegen", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Siehe die Richtungsliste unten"],
                    ["Zeile auswählen", "`{\"selectLine\": {}}`", "Ohne den Zeilenumbruch"],
                    ["Suchen", "`{\"find\": { … }}`", "Findet den nächsten Treffer und **wählt ihn aus**"],
                    ["Auswahl ersetzen", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` wirkt, wenn der vorherige Schritt ein Regex-`find` war"],
                ]
            ),
            .heading("Bewegungsrichtungen"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Der vollständige `find`-Schritt"),
            .code(language: "json", caption: "Die vier Schlüssel eines find-Schritts",
                  source: """
                    {
                      "find": {
                        "pattern": "^([a-z]{2})\\\\t",
                        "mode": "regex",
                        "matchCase": false,
                        "wholeWord": false
                      }
                    }
                    """),
            .paragraph("`mode` nimmt `normal`, `extended` oder `regex` — dieselben drei Modi wie das Suchfeld."),
            .heading("Beispiel 1 — den Provinzcode am Zeilenanfang großschreiben"),
            .code(language: "json", caption: "macros/uppercase-province.json",
                  source: """
                    {
                      "name": "Uppercase province code",
                      "steps": [
                        {
                          "find": {
                            "pattern": "^([a-z]{2,3})\\\\t",
                            "mode": "regex",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "replaceSelection": { "_0": "\\\\U$1\\\\E\\t" } }
                      ]
                    }
                    """),
            .paragraph("""
                Führen Sie es mit `Makro ▸ Bis zum Dokumentende abspielen` aus: dass der `find`-Schritt \
                nichts mehr findet, ist genau die Abbruchbedingung.
                """),
            .heading("Beispiel 2 — die Zeile nach jeder Zeile mit TODO löschen"),
            .code(language: "json", caption: "macros/delete-line-after-todo.json",
                  source: """
                    {
                      "name": "Delete line after TODO",
                      "steps": [
                        {
                          "find": {
                            "pattern": "TODO",
                            "mode": "normal",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "move": { "_0": "nextLine" } },
                        { "move": { "_0": "lineStart" } },
                        { "selectLine": {} },
                        { "deleteForward": {} },
                        { "deleteForward": {} }
                      ]
                    }
                    """),
            .warning("""
                Erproben Sie ein von Hand geändertes Makro zuerst an einer Kopie. Ein falsch getippter \
                `find`-Schritt lässt das Makro sofort anhalten — das ist der harmlose Fall. Der \
                bösartige Fall ist ein Muster, das weiter trifft als gedacht, und in einem einzigen \
                Widerrufsschritt tausende Stellen ändert.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript-Skripte",
        summary: "Vier Funktionen, eine `.js`-Datei, und alles, was sie tut, ist ein Widerrufsschritt.",
        keywords: ["skript", "javascript", "js", "automatisieren", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Legen Sie eine `.js`-Datei in den Ordner `scripts/` von GEditor und führen Sie sie über \
                `Makro ▸ Skript…` aus. Ein Skript sieht genau **vier** Dinge:
                """),
            .table(
                headers: ["Aufruf", "Bedeutung"],
                rows: [
                    ["`doc.text`", "Der ganze Dokumenttext"],
                    ["`doc.selection`", "Die Auswahl (leere Zeichenkette, wenn nichts gewählt ist)"],
                    ["`doc.replace(s)`", "Das **ganze Dokument** durch `s` ersetzen — ein Widerrufsschritt"],
                    ["`doc.log(s)`", "Eine Zeile in den Ergebnisbereich schreiben"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Jede Zeile nummerieren.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — die ersten drei CSV-Spalten behalten",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Drei Grenzen, die man kennen sollte"),
            .bullets([
                "**Kein Dateizugriff, kein Netz, kein Starten von Prozessen.** Die API-Fläche ist bewusst schmal: sie später zu weiten ist leicht, sie zu verengen zerbricht jedes schon geschriebene Skript.",
                "**Das ist keine Sicherheitsgrenze.** Skripte laufen im selben Prozess. Führen Sie kein Skript aus, das Sie nicht gelesen haben.",
                "**Es gibt eine Fünf-Sekunden-Grenze.** Darüber bekommen Sie eine Meldung und die App bleibt nutzbar — aber der Faden dieses Skripts **dreht sich weiter, bis Sie beenden**, und frisst einen Kern. Die Meldung sagt das.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Durch einen externen Befehl filtern",
        summary: "Die Auswahl durch einen Unix-Befehl leiten und das Ergebnis zurücknehmen.",
        keywords: ["filter", "externer befehl", "shell", "pipe", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Die Auswahl (oder das ganze Dokument) wird dem `stdin` eines Befehls übergeben, und der \
                `stdout` dieses Befehls ersetzt sie.
                """),
            .code(language: "bash", caption: "Ein paar gängige",
                  source: """
                    sort -u                     # sortieren und Dubletten verwerfen
                    jq .                        # JSON neu formatieren
                    tr 'a-z' 'A-Z'              # Großbuchstaben
                    grep -v '^#'                # Kommentarzeilen verwerfen
                    awk -F, '{print $3","$1}'   # Spaltenreihenfolge tauschen
                    """),
            .note("""
                Das Ergebnis ist **ein** Widerrufsschritt. Gibt der Befehl einen Fehlercode zurück, \
                lässt GEditor den Text in Ruhe und zeigt `stderr`.
                """),
            .warning("""
                Diesen Befehl gibt es **nur in der Direktdownload-Fassung**. Die App Sandbox verbietet, \
                Code außerhalb der App auszuführen, also bleibt der Menüeintrag in der \
                App-Store-Fassung und erklärt, warum er nicht verfügbar ist.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Das Kommandozeilenwerkzeug `geditor`",
        summary: "Öffnen, bereinigen, abfragen, bewerten und Berichte darstellen — ohne die App zu öffnen.",
        keywords: ["cli", "kommandozeile", "terminal", "geditor", "skript", "ci"],
        blocks: [
            .warning("""
                Nur in der **Direktdownload-Fassung** verfügbar. Die App-Store-Fassung läuft in einer \
                Sandbox, ein externer Kommandozeilenprozess kann sich also nicht mit ihr verbinden.
                """),
            .heading("Dateien öffnen"),
            .code(language: "bash", caption: "Öffnen, zu einer Position springen, aus einer Pipe lesen",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # Zeile 120, Spalte 5
                    geditor -w notes.md            # warten, bis die Datei geschlossen ist, bevor beendet wird
                    geditor -r app.log             # schreibgeschützt öffnen
                    git diff | geditor             # stdin in einen neuen Tab lesen
                    """),
            .table(
                headers: ["Option", "Bedeutung"],
                rows: [
                    ["`-w`, `--wait`", "Warten, bis die Datei geschlossen ist — für den Einsatz als Editor von `git`"],
                    ["`-n`, `--new-window`", "In einem neuen Fenster öffnen"],
                    ["`-r`, `--read-only`", "Schreibgeschützt öffnen"],
                    ["`-i`, `--info`", "Kodierung, Zeilenenden und Zeilenzahl ausgeben, dann beenden — **ohne** die App zu öffnen"],
                    ["`-h`, `--help`", "Hilfe zeigen"],
                    ["`-v`, `--version`", "Die Version zeigen"],
                ]
            ),
            .heading("Laufen, ohne die App zu öffnen"),
            .paragraph("""
                Die vier Befehlsgruppen unten laufen **vollständig im Kommandozeilenprozess**, sie \
                funktionieren also in der CI, wo niemand an einer grafischen Sitzung angemeldet ist.
                """),
            .code(language: "bash", caption: "Bereinigen mit einem Rezept",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Abfragen",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Das Qualitätstor — Rückgabewert 0 bestanden · 1 nicht bestanden · 2 Fehler",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Berichte darstellen",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript und das Menü „Dienste“",
        summary: "Das Dokument aus AppleScript lesen und schreiben, oder Text aus einer anderen App an GEditor schicken.",
        keywords: ["applescript", "osascript", "dienste", "automatisierung", "kurzbefehle"],
        blocks: [
            .code(language: "applescript", caption: "Das offene Dokument lesen",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Den Inhalt überschreiben und die Auswahl lesen",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Eine Datei öffnen",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Das Menü „Dienste“"),
            .paragraph("""
                Wählen Sie Text in einer beliebigen Anwendung und schicken Sie ihn über das Menü \
                `Dienste` als neuen Tab an GEditor.
                """),
            .note("""
                Beim ersten AppleScript-Lauf fragt macOS nach der Automatisierungsberechtigung. Das ist \
                der Dialog des Systems, nicht der von GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Erweiterungspakete und Plug-ins",
        summary: "Zwei Arten von Erweiterungen, und in welcher Fassung jede läuft.",
        keywords: ["plug-in", "erweiterung", "paket", "nativ"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Erweiterungspakete"),
            .paragraph("""
                Ein Paket ist **eine JSON-Datei**, die ein Thema, Skripte und benutzerdefinierte \
                Sprachen bündelt. Installieren kopiert eine Datei, Entfernen löscht eine — und die \
                Paketliste wird von der **Festplatte** abgeleitet, nicht aus einem Register, das lügen \
                könnte.
                """),
            .paragraph("Funktioniert in **beiden Fassungen**."),
            .heading("Native Plug-ins"),
            .paragraph("""
                Vorkompilierte Plug-ins laufen in einem **eigenen Prozess** mit schmaler API-Fläche — \
                ein abstürzendes Plug-in reißt die App nicht mit.
                """),
            .warning("""
                Native Plug-ins gibt es **nur in der Direktdownload-Fassung**, weil die App Sandbox das \
                Laden von Code außerhalb der App verbietet. Jedes Plug-in muss vor dem Ausführen **einmal \
                von Hand freigegeben** werden, über seine Prüfsumme.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Konfiguration und Anwendung

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Konfiguration und die App",
        summary: "Einstellungen, Kurzbefehle, Themen, Aktualisierungen, Umstieg von Notepad++, Fehlersuche.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Einstellungen",
        summary: "Jede Option liegt in einer lesbaren JSON-Datei, die Sie auf einen anderen Mac kopieren können.",
        keywords: ["einstellungen", "voreinstellungen", "optionen", "konfiguration", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Einstellungen öffnen")]),
            .paragraph("""
                Es gibt kein OK und kein Abbrechen — eine Änderung wirkt und wird sofort geschrieben, \
                auf macOS-Art.
                """),
            .heading("Die Konfigurationsdatei"),
            .code(language: "text", caption: "Wo sie liegt",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Es ist eine **eingerückte JSON-Datei, die Sie lesen und von Hand ändern können**. \
                Kopieren Sie sie auf einen anderen Mac, und Ihre ganze Konfiguration zieht mit. Die \
                Taste `Konfigurationsdatei öffnen` in den Einstellungen bringt Sie direkt hin.
                """),
            .heading("Die Schlüssel"),
            .table(
                headers: ["Schlüssel", "Vorgabe", "Bedeutung"],
                rows: [
                    ["`fontSize`", "`13`", "Schriftgröße des Editors"],
                    ["`tabWidth`", "`4`", "Wie viele Spalten breit ein Tabulator ist"],
                    ["`usesTabsForIndent`", "`false`", "Mit Tabulatoren statt Leerzeichen einrücken"],
                    ["`languageIndent`", "`{}`", "Einrückung je Sprache — siehe die Leerraum-Seite"],
                    ["`smartIndent`", "`true`", "Automatische Einrückung in einer neuen Zeile"],
                    ["`highlightAllMatches`", "`true`", "Jeden Suchtreffer hervorheben"],
                    ["`ligatures`", "`false`", "Ligaturen — siehe die Anmerkung unter der Tabelle"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Leerraum am Zeilenende beim Sichern abschneiden"],
                    ["`normalizeToNFCOnSave`", "`false`", "Unicode beim Sichern zu NFC normalisieren"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Kodierung für neue Dateien"],
                    ["`defaultEOL`", "`\"lf\"`", "Zeilenenden für neue Dateien"],
                    ["`language`", "`\"system\"`", "Sprache der Oberfläche"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "das Standardthema", "Welches Farbthema in Gebrauch ist"],
                    ["`showWelcomeOnLaunch`", "`true`", "Das Willkommensfenster beim Start öffnen"],
                    ["`keyBindings`", "`{}`", "Nur die Tasten, die Sie geändert haben"],
                ]
            ),
            .note("""
                **Warum Ligaturen standardmäßig AUS sind.** Eine Ligatur verschmilzt `!=` oder `->` zu \
                **einer** Glyphe, sodass die Zeichen auf dem Bildschirm nicht mehr den Zeichen in der \
                Datei entsprechen — und Spalteneditor, Spaltenmodus und Umbruch an einer Spalte messen \
                alle in Spalten. Schalten Sie sie ein, wenn Sie Fließtext schreiben oder eine \
                Programmierschrift (Fira Code, JetBrains Mono) gerade wegen ihrer Ligaturen gewählt \
                haben.
                """),
            .heading("Die Nachbarordner"),
            .table(
                headers: ["Ordner", "Enthält"],
                rows: [
                    ["`macros/`", "Gesicherte Makros, je eine JSON-Datei"],
                    ["`scripts/`", "JavaScript-Skripte"],
                    ["`themes/`", "Farbthemen"],
                    ["`grammars/`", "Benutzerdefinierte Sprachen"],
                ]
            ),
            .warning("""
                Eine von einem **neueren** GEditor geschriebene Konfigurationsdatei wird von einem \
                älteren **nicht überschrieben** — er läuft auf Vorgabewerten und sagt das. Zu \
                überschreiben ist der sicherste Weg, die Konfiguration von jemandem zu zerstören, der \
                zwei Maschinen abgleicht, und er erführe nie, warum.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Die Statusleiste",
        summary: "Zehn Segmente unten — jedes lesbar und jedes anklickbar.",
        keywords: ["statusleiste", "position", "kodierung", "schreibgeschützt", "dateigröße"],
        blocks: [
            .paragraph("""
                Das ist der größte Unterschied zu den Statusleisten anderer Editoren: **kein Segment ist \
                schreibgeschützt**. Sehen Sie einen falschen Wert, ist ein Klick darauf der Weg, ihn zu \
                beheben, statt durch Menüs zu suchen.
                """),
            .table(
                headers: ["Segment", "Sagt Ihnen", "Beim Anklicken"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "Cursorposition — Spalte in ZEICHEN, `@340` die Byteposition",
                     "öffnet das Feld `Gehe zu`"],
                    ["`11 byte · 3 dòng`", "Dokumentgröße",
                     "zählt Bytes · Zeichen · Wörter · Zeilen"],
                    ["`🔒 Chỉ đọc`", "wird nur gezeigt, wenn das Dokument gesperrt ist",
                     "sagt WARUM es gesperrt ist, und hebt die Sperre auf, wo möglich"],
                    ["`View` / `Code`", "in welcher Ansicht Sie sind", "wechselt (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "CSV-Modus und benutztes Trennzeichen",
                     "schaltet den CSV-Modus um oder **wählt das Trennzeichen neu**"],
                    ["`Đang theo dõi`", "`tail -f` läuft", "—"],
                    ["`UTF-8`", "die Kodierung", "neu deuten oder in eine andere Kodierung wandeln"],
                    ["`LF`", "Zeilenendenstil", "LF · CRLF · CR umschalten"],
                    ["`Python`", "Sprache der Syntaxfärbung", "eine andere wählen oder zurück zur Endungserkennung"],
                    ["`Tab: 4`", "Einrückungsbreite", "2 · 4 · 8, global oder **nur für diese Sprache**"],
                    ["`Ngắt: tắt`", "Modus des weichen Umbruchs", "wechselt durch die drei Modi"],
                ]
            ),
            .heading("Drei Segmente, die einen zweiten Blick verdienen"),
            .bullets([
                "**`@340` — die Byteposition.** Das ist die Zahl, die jedes andere Werkzeug im Produkt spricht: JSON- und XML-Fehler, die Ausgabe von `--doc-sweep`, die Binäransicht und das Feld `Gehe zu @340`. Hier lesen, dort tippen.",
                "**Ein `~` an der Spalte** heißt, die Zahl zählt BYTES statt visueller Spalten — das passiert nur bei Zeilen über 200 KB, wo das Zählen von Zeichen jede Cursorbewegung verlangsamen würde.",
                "**`CSV · …` ist anklickbar, um das Trennzeichen neu zu wählen.** Die Erkennung kann falsch liegen, und dann ist jede Spaltenoperation daneben, ohne dass irgendetwas es anzeigt. So sagen Sie das Gegenteil — es LIEST die Datei nur neu und ändert kein Byte (anders als `CSV ▸ Trennzeichen ändern…`, das sie neu schreibt).",
            ]),
            .note("""
                Ein Segment, das für die offene Datei nicht gilt, ist **verborgen**, nicht ausgegraut: \
                `Schreibgeschützt` erscheint nur, wenn das Dokument wirklich gesperrt ist, `CSV · …` nur \
                im CSV-Modus.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Tastenkürzel ändern",
        summary: "Einzelne Tasten ändern oder die Notepad++-Belegung im Ganzen übernehmen.",
        keywords: ["kurzbefehl", "tastenbelegung", "voreinstellung"],
        blocks: [
            .paragraph("""
                `Einstellungen…` hat einen Bereich Kurzbefehle mit zwei schnellen Tasten: **Die \
                Notepad++-Voreinstellung nutzen** und **Zurück zu den Vorgaben**.
                """),
            .paragraph("""
                Die Konfigurationsdatei hält nur fest, was Sie **gegenüber den Vorgaben geändert** \
                haben. So bleiben Sie nicht bei der alten Belegung hängen, ohne dass es Ihnen jemand \
                sagt, wenn GEditor in einer neuen Version eine Vorgabetaste ändert.
                """),
            .note("""
                Zwei Befehle dürfen sich kein Kurzbefehl teilen. Tun sie es, löst AppKit still nur den \
                **ersten** Menüeintrag aus, und der andere Befehl wirkt kaputt — deshalb hat GEditor \
                eine Prüfung, die das verhindert.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Themen, hell und dunkel",
        summary: "Dem System folgen, hell oder dunkel; und ein Thema ist eine JSON-Datei, die Sie ändern können.",
        keywords: ["thema", "farben", "dunkelmodus", "hell", "erscheinungsbild"],
        blocks: [
            .paragraph("`Einstellungen…` wählt `Dem System folgen`, `Hell` oder `Dunkel` und ein Farbthema."),
            .paragraph("""
                Ein Thema ist eine JSON-Datei in `themes/`. Die Taste `Aktuelles Thema exportieren` \
                schreibt eines als Ausgangspunkt für Ihr eigenes.
                """),
            .note("""
                Eine falsch getippte Farbe in einer Themendatei fällt auf die Farbe des \
                **Standardthemas** zurück, nicht auf Schwarz. Schwarz sieht aus wie eine \
                Gestaltungsentscheidung, und der Nutzer würde das Problem woanders suchen.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Aktualisierungen, Versionen und Beenden",
        summary: "Worin sich das Aktualisieren zwischen den beiden Fassungen unterscheidet.",
        keywords: ["aktualisierung", "version", "über", "beenden"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Fassung", "Aktualisiert über"],
                rows: [
                    ["App Store", "Den App Store, wie jede andere App"],
                    ["Direktdownload", "`Nach Aktualisierungen suchen…` in der App"],
                ]
            ),
            .paragraph("""
                `Über GEditor` zeigt die laufende Version und um welche Fassung es sich handelt — \
                nützlich beim Melden eines Problems.
                """),
            .note("""
                In der App-Store-Fassung **bleibt `Nach Aktualisierungen suchen…` im Menü** und erklärt, \
                warum es nicht gilt, statt zu verschwinden. Ein fehlender Menüeintrag wird zur \
                Supportanfrage.
                """),
            .paragraph("Beenden verliert keine Arbeit: die Sitzung kommt beim nächsten Öffnen zurück."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Dieses Hilfefenster nutzen",
        summary: "Im Buch suchen, seine Sprache wechseln und das Willkommensfenster zurückholen.",
        keywords: ["hilfe", "anleitung", "suche", "willkommen", "sprache"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Das Hilfefenster öffnen")]),
            .bullets([
                "Das Suchfeld oben links durchsucht **Fließtext und Codebeispiele** — einen bloßen Konfigurationsschlüssel wie `fail_under` zu tippen führt auf die richtige Seite.",
                "Tippen **ohne Akzente** findet trotzdem akzentuierten Text.",
                "Die Taste `Zurück` führt zur vorherigen Seite.",
                "Die Taste `Kopieren` an jedem Codeblock kopiert diesen Block.",
            ]),
            .heading("In einer anderen Sprache lesen"),
            .paragraph("""
                Das Einblendmenü oben rechts in diesem Fenster wählt die **Sprache des Buches**, \
                unabhängig von der Oberflächensprache der App. Der Wechsel hält Sie **auf der Seite, die \
                Sie lesen** — die Seitenkennungen werden bewusst nicht übersetzt, genau damit das \
                funktioniert.
                """),
            .note("""
                Aufgeführt werden nur Sprachen, die tatsächlich ein Buch haben. Ein Menüeintrag, der zu \
                etwas wechselt und den Text unverändert lässt, wäre ein Menüeintrag, der lügt.
                """),
            .heading("Das Willkommensfenster zurückholen"),
            .paragraph("""
                Haben Sie **Dieses Fenster beim Start nicht öffnen** angehakt, öffnen Sie es mit `Hilfe \
                ▸ Funktionsrundgang` wieder — das Kästchen am Fuß des Fensters erscheint erneut und lässt \
                sich abwählen.
                """),
            .paragraph("Oder setzen Sie `showWelcomeOnLaunch` in `settings.json` zurück auf `true`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Von Notepad++ zu GEditor",
        summary: "Welche Tasten den Platz tauschen, was anders funktioniert, und was fehlt.",
        keywords: ["notepad++", "umstieg", "windows", "kurzbefehle"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Einige Tasten **tauschen unter macOS den Platz**, statt bloß `Ctrl` zu `⌘` zu machen. \
                Hier der Vergleich.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Warum"],
                rows: [
                    ["`Ctrl+D` Zeile verdoppeln", "**⇧⌘D**", "`⌘D` ist hier der Multi-Cursor, wie in jedem Mac-Editor"],
                    ["`Ctrl+L` Zeile löschen", "**⌘K**", "Unter macOS heißt `⌘L` „gehe zu Zeile“"],
                    ["`Ctrl+G` Gehe zu Zeile", "**⌘L**", "Diese beiden tauschen den Platz"],
                    ["`Ctrl+Q` Kommentieren", "**⌘/**", "macOS-Konvention"],
                    ["`Ctrl+Shift+↑/↓` Zeile verschieben", "**⌥↑ / ⌥↓**", "Unter macOS gehört `⌃` zu Mission Control"],
                    ["`F3` Weitersuchen", "**⌘G**", "macOS-Konvention"],
                    ["`Ctrl+F2` Lesezeichen umschalten", "**⌘F2**", "F2 und ⇧F2 springen weiterhin zwischen Marken"],
                    ["`Alt` + Ziehen für Spalten", "**⌥ + Ziehen**", "Identisch"],
                    ["`Ctrl+Alt+Shift+↓` Spalteneditor", "**⌥⌘C**", "macOS-Konvention"],
                ]
            ),
            .note("Lieber nicht umlernen? `Einstellungen ▸ Kurzbefehle ▸ Die Notepad++-Voreinstellung nutzen`."),
            .heading("Was Notepad++ hat und hier anders funktioniert"),
            .bullets([
                "**Sitzungen** stellen sich selbst wieder her, ungesicherte Tabs eingeschlossen — nichts einzuschalten.",
                "**Lesezeichen haben neun Farben**, und eine Zeile kann mehrere zugleich tragen.",
                "**Die Dokumentkarte** beschreibt die *ganze* Datei, nicht nur den sichtbaren Teil.",
                "**Makros** können „bis zum Dokumentende“ und „über alle Tabs“ laufen, und ein ganzer Lauf ist ein Widerrufsschritt.",
            ]),
            .heading("Was GEditor hinzufügt"),
            .bullets([
                "Eine **Datenbereinigungswerkbank** und **Datenprofile** für CSV-Dateien.",
                "**SQL-Abfragen** direkt auf einer CSV-Datei.",
                "**Alte vietnamesische Kodierungen** — TCVN3, VISCII, VNI-Windows, gelesen, geschrieben und automatisch erkannt.",
                "**Akzentunabhängige Suche** in jedem Filterfeld.",
                "**`.greport.md`-Berichte** mit Tabellen und Diagrammen, die sich neu rechnen.",
                "Das **Kommandozeilenwerkzeug `geditor`** in der Direktdownload-Fassung.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Häufige Probleme",
        summary: "Sechs Situationen, die den Eindruck erwecken, die App sei kaputt.",
        keywords: ["fehler", "problem", "geht nicht", "fehlersuche", "warum"],
        blocks: [
            .table(
                headers: ["Symptom", "Übliche Ursache"],
                rows: [
                    ["Vietnamesischer Text erscheint als Kauderwelsch", "Falsche Kodierung — die Kodierung in der Statusleiste anklicken"],
                    ["Die Suche nach akzentuiertem Text findet nichts", "Die Datei ist in zerlegtem Unicode — `Unicode normalisieren` auf NFC laufen lassen"],
                    ["Ein Menüeintrag ist ausgegraut", "Die App-Store-Fassung kann diesen Befehl nicht ausführen — der Eintrag erklärt warum"],
                    ["Die Klammernpaarung verweigert sich", "Das Dokument ist größer als 1 MB — das falsche Paar hervorzuheben ist schlimmer als keins"],
                    ["Die Spalte in der Statusleiste hat ein `~`", "Das Dokument ist größer als 200 KB, das ist also eine Bytezahl, keine visuelle Spalte"],
                    ["Eine SQL-Abfrage verlangt, zuerst zu sichern", "DuckDB liest **Dateien**, nicht den Puffer, den Sie bearbeiten"],
                ]
            ),
            .heading("Wenn GEditor unerwartet beendet"),
            .paragraph("""
                Beim nächsten Start sagt ein Banner das, mit einer Taste **Bericht öffnen** — der Bericht \
                öffnet sich als Tab, den Sie wie jede andere Textdatei lesen und aus dem Sie kopieren \
                können.
                """),
            .bullets([
                "Der Bericht trägt nur **Version, macOS-Ausgabe, Rechnerarchitektur, Signalname und Aufrufliste**.",
                "**Kein Dokumentinhalt und auch keine Dateipfade** — ein Pfad wie `~/Schreibtisch/gehalt-dezember.xlsx` hat schon drei private Dinge verraten, bevor ihn jemand öffnet.",
                "**Es wird nichts irgendwohin gesendet.** Es gibt kein automatisches Hochladen und keinen Server, der es entgegennähme; die Datei bleibt in `~/Library/Application Support/GEditor/crash/`, bis Sie sie öffnen oder löschen.",
                "Haben Sie den Bericht einmal geöffnet, erwähnt ihn der nächste Start nicht wieder.",
            ]),
            .heading("Wo als Nächstes zu schauen ist"),
            .bullets([
                "Die Statusleiste zeigt Kodierung, Zeilenenden, Sprache und Umbruchmodus — jedes Segment ist anklickbar.",
                "`settings.json` lässt sich von Hand ändern, wenn das Einstellungsfenster nicht reicht.",
                "`Über GEditor` gibt Version und Fassung, die ein Fehlerbericht braucht.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
