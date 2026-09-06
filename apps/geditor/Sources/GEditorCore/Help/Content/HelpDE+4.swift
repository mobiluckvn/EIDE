import Foundation

/// Deutscher Hilfeinhalt — Teil 4: Tabellendaten, Bereinigung, Data Mining.
extension HelpDE {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Tabellendaten",
        summary: "CSV als Tabelle sehen, filtern, sortieren, Struktur prüfen, mit SQL abfragen, umwandeln.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "CSV als Tabelle sehen",
        summary: "Eine Million Zeilen rollt weiterhin flüssig, die Kopfzeile bleibt stehen, der Quelltext bleibt unberührt.",
        keywords: ["csv", "tabelle", "raster", "tsv", "excel", "spalten"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Zwischen Tabelle und Text wechseln")]),
            .paragraph("""
                Die Tabelle ist **virtualisiert**: nur sichtbare Zeilen werden gebaut, sodass eine \
                Datei mit einer Million Zeilen rollt wie eine mit hundert.
                """),
            .bullets([
                "**Die Kopfzeile bleibt kleben**, während Sie rollen — bei Zeile 40 000 wissen Sie noch, was die neunte Spalte ist.",
                "Ändern Sie eine Zelle in der Tabelle; die Änderung geht direkt in den Quelltext.",
                "Tabelle und Text sind **zwei Blicke auf eine Datei**, nicht zwei Kopien.",
                "**⌘C kopiert die ausgewählte Zeile**, Zellen durch Tabulatoren getrennt — direkt in Excel oder Numbers einsetzen, und jede Zelle landet richtig. Zellen mit Tabulatoren oder Umbrüchen werden in Anführungszeichen gesetzt, damit das Ziel sie nicht entzweischneidet.",
            ]),
            .note("""
                Das Trennzeichen wird beim Öffnen erkannt (Komma, Semikolon, Tabulator, senkrechter \
                Strich). Ist die Annahme falsch, ändern Sie es mit `CSV ▸ Trennzeichen ändern…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Arbeitsmappen mit mehreren Blättern",
        summary: "Jedes Blatt einer .xlsx öffnen, und ⌘S schreibt in das Blatt zurück, das Sie ansehen.",
        keywords: ["excel", "xlsx", "blatt", "arbeitsmappe"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Öffnen Sie eine `.xlsx`, und GEditor zeigt das **erste Blatt** als CSV-Tabelle. `CSV ▸ \
                Blatt wählen…` listet jedes Blatt der Datei und öffnet das gewählte im selben Tab.
                """),
            .heading("Ins RICHTIGE Blatt zurückschreiben"),
            .paragraph("""
                `⌘S` schreibt Ihre Änderungen in **das Blatt, das Sie ansehen**, nicht ins erste. Die \
                übrigen Blätter werden um kein Byte angerührt.
                """),
            .note("""
                Das Blatt wird über den **Namen** gemerkt, nicht über die Position. So lenkt ein \
                Umsortieren der Blätter in Excel zwischen zwei Sitzungen das Schreiben nicht fehl.
                """),
            .warning("""
                Wurde das offene Blatt seit dem Öffnen in Excel **umbenannt oder gelöscht**, \
                **verweigert `⌘S` das Schreiben** und sagt es. Auf das erste Blatt zurückzufallen \
                hieße, den Inhalt eines Blattes über ein anderes zu gießen — die Datei würde \
                trotzdem gesichert, ließe sich trotzdem wieder öffnen und hielte die Daten schlicht \
                an der falschen Stelle.
                """),
            .heading("Blatt wechseln mit ungesicherten Änderungen"),
            .paragraph("""
                Ein Blattwechsel ersetzt den ganzen Inhalt des Tabs; ist etwas ungesichert, **fragt \
                GEditor zuerst**. `⌘Z` kann es nicht zurückholen, denn das ganze Dokument wurde \
                getauscht.
                """),
            .heading("Was es kostet, Excel auf eine Tabelle herunterzubrechen"),
            .paragraph("""
                Was überlebt, sind die **Werte** — samt Formelergebnissen, genau den Zahlen, die Excel \
                zeigt. Was nicht: Schriften, Farben, verbundene Zellen, eingebettete Diagramme und die \
                Formeln selbst.
                """),
            .paragraph("""
                Dafür gewinnt dieses Blatt den ganzen Rest des Produkts: Filtern, Sortieren, \
                SQL-Abfragen, die Bereinigungswerkbank, Qualitätsbewertung, Mining, Diagramme.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtern und Sortieren in der Tabelle",
        summary: "Ein Filterfeld je Spalte, das Zahlenvergleiche und akzentlose Eingabe versteht.",
        keywords: ["filter", "sortieren", "spalte", "in der tabelle suchen"],
        blocks: [
            .paragraph("Ein Klick auf eine Spaltenüberschrift sortiert. Das Filterfeld darunter nimmt an:"),
            .table(
                headers: ["In den Filter tippen", "Bedeutung"],
                rows: [
                    ["`hue`", "Enthält `hue`, **akzentunabhängig** — findet auch `Huế`"],
                    ["`=Huế`", "Genau `Huế` (weiterhin akzentunabhängig)"],
                    ["`>100`", "Größer als 100"],
                    ["`>=100`", "100 oder mehr"],
                    ["`<0`", "Kleiner als 0"],
                    ["`100..200`", "Zwischen 100 und 200"],
                    ["leer", "Kein Filter auf dieser Spalte"],
                ]
            ),
            .paragraph("""
                Mehrere Spalten zu filtern ist ein **und**: eine Zeile muss allen genügen. Der \
                Zahlenvergleich überspringt nichtnumerische Zellen, statt sie als Null zu behandeln.
                """),
            .note("""
                Filtern ist eine **Art zu sehen**, kein Löschen. Löschen Sie den Filter, und jede Zeile \
                kehrt zurück.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Die Tabellenstruktur prüfen",
        summary: "Zeilen mit falscher Spaltenzahl und Zellen mit falschem Typ finden — das zuerst.",
        keywords: ["prüfen", "spaltenzahl", "falscher typ", "kaputte daten"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Das ist es, was Sie bei einer zugeschickten Datei **vor** allem anderen laufen lassen. \
                Es beantwortet zwei Fragen:
                """),
            .bullets([
                "**Welche Zeilen haben die falsche Spaltenzahl?** Meist eine Zelle mit einem Komma, das nicht in Anführungszeichen stand — und sie bringt jede Zeile danach aus dem Takt.",
                "**Welche Zellen haben einen anderen Typ als der Rest ihrer Spalte?** Etwa ein `n/a` in einer Zahlenspalte.",
            ]),
            .paragraph("Die Ergebnisse erscheinen als Liste; ein Klick springt zu dieser Zeile."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Spalten löschen",
        summary: "Eine oder mehrere Spalten ganz aus der Datei entfernen.",
        keywords: ["spalte löschen", "spalte entfernen"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Wählen Sie die zu verwerfenden Spalten aus der Liste und wenden Sie an. Es ist **ein** \
                Widerrufsschritt, gleich wie viele Zeilen die Datei hat.
                """),
            .warning("""
                Anders als Filtern **bearbeitet das die echte Datei**. Um Spalten nur auszublenden, \
                nehmen Sie eine SQL-Abfrage, die die gewünschten Spalten auflistet.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "CSV mit SQL abfragen",
        summary: "Das volle SQL von DuckDB, direkt auf der offenen Datei ausgeführt — nur lesend.",
        keywords: ["sql", "abfrage", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Die offene Tabelle heißt **`t`**. Die Maschine ist **DuckDB**, also funktionieren \
                `JOIN`, `DISTINCT`, `HAVING`, `IN`, `LIKE`, `BETWEEN`, Fensterfunktionen und \
                Unterabfragen alle.
                """),
            .code(language: "sql", caption: "Umsatz je Provinz, größter zuerst",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Nach Datum und einer Textbedingung filtern",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Der Anteil jeder Provinz am Gesamten — mit einer Fensterfunktion",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Verknüpfung mit einer anderen Datei auf der Festplatte",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Nur lesend, und das ist eine harte Zusage"),
            .bullets([
                "Die Datenbank lebt **im Arbeitsspeicher**; die Quelldatei wird immer nur gelesen.",
                "Genau **eine Anweisung** wird angenommen, und sie **muss ein `SELECT` sein**. Alles andere — auch `COPY … TO 'datei'`, womit DuckDB durchaus auf die Festplatte schreiben kann — wird geblockt, bevor es überhaupt Daten erreicht.",
            ]),
            .warning("""
                DuckDB liest **Dateien**, nicht den Arbeitsspeicher. Hat das Dokument ungesicherte \
                Änderungen, muss GEditor vor dem Abfragen eine temporäre Kopie schreiben. Bei einer \
                sehr großen Datei mit ungesicherten Änderungen **hält er an und sagt es**, statt für \
                eine Abfrage still hunderte Megabyte auf die Festplatte zu schreiben.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Pivot-Tabellen und schnelle Diagramme",
        summary: "Direkt aus einem Abfrageergebnis pivotieren und zeichnen.",
        keywords: ["pivot", "diagramm", "kreuztabelle", "aggregat"],
        blocks: [
            .paragraph("""
                Beide öffnen sich aus der **Ergebnistabelle**: führen Sie eine SQL-Anweisung aus und \
                nutzen Sie dann die Taste Pivot oder Diagramm im Bereich.
                """),
            .heading("Pivot"),
            .paragraph("""
                Wählen Sie die **Zeilen**-Spalte, die **Spalten**-Spalte, die **Werte**-Spalte und das \
                Aggregat (Summe, Anzahl, Mittel, Min, Max) — wie eine Pivot-Tabelle in einer \
                Tabellenkalkulation.
                """),
            .heading("Diagramme"),
            .paragraph("""
                Balken, Linie, Kreis, Streuung. Zahlen im vietnamesischen oder europäischen Format, und \
                das Diagramm lässt sich als PNG oder SVG exportieren, um es anderswo einzusetzen.
                """),
            .note("""
                Sie wollen ein Diagramm, das sich bei jedem Neuaufbau **mit den Daten erneuert**? Das \
                ist der `chart`-Block in einem `.greport.md`-Bericht.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Eine Tabelle in ein anderes Format wandeln",
        summary: "TSV, JSON, XML, Markdown-Tabellen, SQL-INSERT-Anweisungen — mit Vorschau.",
        keywords: ["wandeln", "exportieren", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Format", "Nützlich für"],
                rows: [
                    ["TSV", "Einsetzen in eine Tabellenkalkulation, ohne sich um Kommas in Zellen zu sorgen"],
                    ["JSON", "Eine API, ein Skript oder ein anderes Werkzeug speisen"],
                    ["XML", "Altsysteme, die XML verlangen"],
                    ["Markdown-Tabelle", "Einsetzen in Dokumentation, eine README, ein Ticket"],
                    ["SQL-INSERT-Anweisungen", "In eine Datenbank laden"],
                ]
            ),
            .paragraph("""
                Der Dialog **zeigt die ersten fünf Zeilen vorab**, bevor der neue Tab entsteht — fünf \
                Zeilen genügen, um Tabellenname, Anführungszeichen und die zu Zahlen gewordenen \
                Spalten zu bestätigen.
                """),
            .note("""
                Die Vorschau ruft **dieselbe Funktion** auf, die die echte Ausgabe erzeugt, begrenzt \
                auf fünf Zeilen. Sie ist keine Simulation, die vom Endergebnis abweichen könnte.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Das Trennzeichen ändern",
        summary: "Eine Datei zwischen Komma, Semikolon, Tabulator und senkrechtem Strich wandeln.",
        keywords: ["trennzeichen", "komma", "semikolon", "tabulator", "europäische csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Aus einem vietnamesischen oder europäischen Excel exportierte Dateien nutzen meist \
                **Semikolons**, weil dort das Komma das Dezimaltrennzeichen ist.
                """),
            .warning("""
                Das Trennzeichen zu ändern **schreibt die ganze Datei neu**. Zellen mit dem neuen \
                Trennzeichen werden in Anführungszeichen gesetzt — sonst zerbricht die Struktur der \
                Tabelle.
                """),
            .note("""
                **War die Erkennung falsch, ist das nicht der Befehl, den Sie wollen.** Hier stecken \
                zwei verschiedene Aufgaben, genau wie beim Kodierungspaar „neu deuten“ / „umwandeln“:

                • *Die Datei ist wirklich semikolongetrennt und wir haben Komma geraten* — klicken Sie \
                das Segment `CSV · …` in der **Statusleiste** und wählen Sie das richtige. Kein Byte \
                der Datei ändert sich; nur wie sie gelesen wird.

                • *Die Datei ist wirklich kommagetrennt, und Sie wollen Semikolons* — nehmen Sie den \
                Befehl auf dieser Seite. Er schreibt die Datei neu.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Bereinigung

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Datenbereinigung — der ganze Ablauf",
        summary: "Von einer zugeschickten Rohdatei zu einer brauchbaren Tabelle, und ein Standard für jeden Monat.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Der Bereinigungsablauf, von Anfang bis Ende",
        summary: "Sechs Schritte von einer unbekannten Datei zu einer vertrauenswürdigen Tabelle, und ein Standard für nächsten Monat.",
        keywords: ["bereinigung", "ablauf", "normalisieren", "saubere daten"],
        blocks: [
            .paragraph("""
                Daten zu bereinigen ist **selten einmalig**. Menschen erhalten jeden Monat dieselbe \
                Berichtsvorlage, und jeden Monat müssen dieselben Spalten auf dieselbe Art normalisiert \
                werden. Dieser Ablauf ist dafür gedacht: einmal von Hand, danach mit einem einzigen \
                Befehl wiederholt.
                """),
            .heading("Sechs Schritte"),
            .steps([
                "**Sehen Sie zuerst die Struktur an.** `CSV ▸ Daten prüfen` — welche Zeilen haben die falsche Spaltenzahl, welche Zellen den falschen Typ. Das kommt zuerst, denn eine einzige verrutschte Zeile macht jede spätere Statistik bedeutungslos.",
                "**Lesen Sie das Datenprofil.** Je Spalte: wie viele leere Zellen, wie viele verschiedene Werte, welcher Typ, wo die Ausreißer sind. Hier verstehen Sie die Datei, bevor Sie etwas ändern.",
                "**Öffnen Sie die Bereinigungswerkbank** (`⇧⌘L`). Sie erkennt gemischte Datumsformate, vietnamesische Zahlen neben europäischen, streunenden Leerraum, fehlende Werte. **Vorschau vorher→nachher**, dann anwenden.",
                "**Behandeln Sie unscharfe Dubletten**, wenn eine Namens- oder Adressspalte von Hand getippte Varianten enthält. Hier entscheiden Sie; die Maschine schlägt nur vor.",
                "**Sichern Sie es als Rezept.** Die eben ausgeführte Abfolge wird in eine benannte JSON-Datei geschrieben — diese Datei ist Ihr Wissen über diese Daten.",
                "**Schreiben Sie ein Qualitätsregelwerk** `.gquality.yaml` und bewerten Sie. Von nun an läuft die Datei des nächsten Monats durch das Rezept und wird bewertet, und das **Kommandozeilentor** gibt bei Nichtbestehen einen Rückgabewert ungleich null.",
            ]),
            .heading("Warum diese Reihenfolge"),
            .bullets([
                "Struktur **vor** Profil: Statistiken auf einer verrutschten Tabelle sind Statistiken über eine andere Spalte.",
                "Profil **vor** Bereinigung: Sie müssen „2 % leer“ wissen, bevor Sie über Füllen oder Verwerfen entscheiden.",
                "Unscharfe Dubletten **nach** der Normalisierung: `CÔNG TY  A` und `Công ty A` zeigen sich erst als eines, wenn Leerraum und Schreibweise geklärt sind.",
                "Rezept **vor** Regelwerk: das Rezept behebt, die Regeln urteilen — eine unbehobene Tabelle zu bewerten liefert nur eine niedrige Zahl, die Sie ohnehin erwartet haben.",
            ]),
            .heading("Nach dem ersten Mal ist jeder Monat ein Befehl"),
            .code(language: "bash", caption: "Bereinigen, dann bewerten, mit Rückgabewert für die CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Rückgabewert **0** heißt bestanden, **1** nicht bestanden, **2** Laufzeitfehler. \
                `--record-history` hängt eine Zeile an die Verlaufsdatei, damit der nächste Lauf die \
                Abweichung vergleichen kann.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Datenprofil",
        summary: "Eine Beschreibung je Spalte: Typ, Leerstellen, verschiedene Werte, Verteilung.",
        keywords: ["profil", "spaltenstatistik", "null", "verschieden"],
        blocks: [
            .paragraph("""
                Ein Profil **beschreibt**; es urteilt nicht. Es sagt *„diese Spalte ist zu 2 % leer“*; \
                ob 2 % annehmbar sind, gehört ins Qualitätsregelwerk.
                """),
            .table(
                headers: ["Maß", "Wie es zu lesen ist"],
                rows: [
                    ["Typ", "Aus den Daten selbst abgeleitet, nicht aus dem Spaltennamen"],
                    ["Leere Zellen", "Anzahl und Anteil fehlender Werte"],
                    ["Verschiedene Werte", "1 heißt konstante Spalte; gleich der Zeilenzahl heißt Schlüsselspalte"],
                    ["Min · Max · Mittel", "Nur numerische Spalten"],
                    ["Häufigste Werte", "Einen Fehlercode oder einen überstrapazierten Vorgabewert sofort erkennen"],
                ]
            ),
            .warning("""
                Das Zählen verschiedener Werte hat eine Schwelle. Darüber ist die gezeigte Zahl eine \
                **untere Schranke**, und das Profil **sagt, dass es eine Schätzung ist**, statt sie \
                unter die genauen Zählungen zu mischen.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Die Datenbereinigungswerkbank",
        summary: "Sieben Normalisierungen, stets mit Vorschau, stets ein Widerrufsschritt, nie geraten.",
        keywords: ["bereinigen", "normalisieren", "daten", "zahlen", "füllen"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Die Bereinigungswerkbank öffnen")]),
            .table(
                headers: ["Operation", "Was sie tut"],
                rows: [
                    ["Daten normalisieren", "Jede Datumsform der Spalte auf eine Form bringen"],
                    ["Zahlen normalisieren", "Dezimal- und Gruppierungstrennzeichen klären"],
                    ["Leerraum kürzen", "An beiden Enden entfernen; wahlweise auch innere Folgen zusammenfassen"],
                    ["Schreibweise ändern", "Die Groß-/Kleinschreibung der Spalte vereinheitlichen"],
                    ["Mit festem Wert füllen", "Leere Zellen durch einen von Ihnen getippten Wert ersetzen"],
                    ["Von einer Nachbarin füllen", "Den Wert der Zeile darüber oder darunter nehmen"],
                    ["Zeilen mit leeren Zellen löschen", "Zeilen verwerfen, denen Daten fehlen"],
                ]
            ),
            .heading("Drei Zusagen der ganzen Werkbank"),
            .bullets([
                "**Stets mit Vorschau.** Eine Tabelle vorher→nachher, samt Anzahl der Zellen, die sich ändern werden.",
                "**Ein Widerrufsschritt** für den ganzen Durchlauf, auch wenn er eine Million Zellen berührt.",
                "**Ein Bericht danach**: wie viele Zellen sich geändert haben, und welche nicht gelesen werden konnten.",
            ]),
            .heading("Der Grundsatz: nie raten"),
            .paragraph("""
                Eine Zelle, die sich nicht sicher lesen lässt, wird **gekennzeichnet und in Ruhe \
                gelassen**. Nehmen Sie `03/04/2026` in einer Spalte, die beide Konventionen mischt — \
                ist das der 3. April oder der 4. März? GEditor fragt Sie nach der Tag/Monat-Reihenfolge, \
                statt für Sie zu wählen.
                """),
            .warning("""
                Eine Datumsspalte falsch zu normalisieren ist die Art von Beschädigung, die sich \
                **fast nicht entdecken lässt**: die Zahlen sehen weiterhin richtig aus, sie sind nur \
                ein anderes Datum. Deshalb lehnt diese Werkbank lieber ab, als zu schließen.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Unscharfe Dubletten",
        summary: "Von Hand getippte Varianten desselben Namens finden — und nie automatisch zusammenführen.",
        keywords: ["unscharf", "dubletten", "zusammenführen", "varianten", "tippfehler"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — drei Arten, einen \
                Kunden zu schreiben. Gewöhnliches Entdoppeln sieht sie nicht als dieselben.
                """),
            .steps([
                "Wählen Sie die zu prüfende Spalte und eine Ähnlichkeitsschwelle.",
                "GEditor gruppiert nahe Werte zu **Clustern** und zeigt die Vergleichsform.",
                "Für **jedes Cluster** wählen Sie, welcher Wert bleibt — oder überspringen es.",
                "Anwenden. Ein Widerrufsschritt.",
            ]),
            .warning("""
                Dieses Werkzeug **führt nie von selbst zusammen**, und es gibt keine Taste „alle \
                zusammenführen“. Zwei zu 92 % ähnliche Zeichenketten können ein Tippfehler sein oder \
                zwei tatsächlich verschiedene Firmen, die sich um ein Wort unterscheiden — eine \
                Maschine kann das nicht entscheiden.
                """),
            .paragraph("""
                Zwei Datensätze falsch zusammenzuführen ist **stiller** Datenverlust: keine Zelle wird \
                leer, keine Zeile rot, zwei Wesenheiten werden schlicht zu einer, und niemand merkt es, \
                bis die Bücher abgeglichen werden.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Bereinigungsrezepte",
        summary: "Die Abfolge als JSON-Datei aufzeichnen und auf die Daten des nächsten Monats anwenden.",
        keywords: ["rezept", "wiederholen", "automatisieren", "monatlich", "stapel"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Sichern Sie nach dem Bereinigen die Schritte als **Rezept**. Es ist eine für Menschen \
                lesbare JSON-Datei, die Sie neben den Daten aufbewahren, einem Kollegen schicken und \
                in ein Repository legen können, damit Änderungen nachvollziehbar sind.
                """),
            .code(language: "json", caption: "sales-standard.json — gekürzt",
                  source: """
                    {
                      "version": 1,
                      "name": "Sales report standardisation",
                      "sourceFile": "sales-2026-08.csv",
                      "steps": [
                        { "enabled": true, "column": "ngay",       "action": "normalizeDates" },
                        { "enabled": true, "column": "doanh_thu",  "action": "normalizeNumbers" },
                        { "enabled": true, "column": "khach_hang", "action": "trim" }
                      ]
                    }
                    """),
            .paragraph("""
                Jeder Schritt lässt sich **abschalten** (`enabled`), sodass ein Rezept mehrere fast \
                gleiche Dateiarten bedienen kann.
                """),
            .heading("Erneut ausführen"),
            .bullets([
                "In der App: `CSV ▸ Bereinigungsrezept ausführen…`",
                "Aus der Shell, über einen Ordner: siehe die Kommandozeilenseite.",
            ]),
            .code(language: "bash", caption: "Ein Trockenlauf, bevor etwas geschrieben wird — keine Datei wird angerührt",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Standardmäßig wird das Ergebnis in eine neue Datei neben dem Original geschrieben \
                (`sales-clean.csv`). Das Original zu überschreiben muss mit `--overwrite` ausdrücklich \
                verlangt werden.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Datenqualitätsbewertung",
        summary: "Sechs Dimensionen, eine Note von 0 bis 100, und jede Formel abgedruckt, damit Sie sie nachrechnen können.",
        keywords: ["qualität", "note", "dqr", "sechs dimensionen"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Sie unterscheidet sich vom Datenprofil in einem grundlegenden Punkt: ein Profil \
                **beschreibt**, eine Note **urteilt gegen den Standard, den Sie erklärt haben** — in \
                einer `.gquality.yaml`-Datei.
                """),
            .table(
                headers: ["Dimension", "Was sie misst"],
                rows: [
                    ["Vollständigkeit", "Anteil gefüllter Zellen gemäß den `not_null`-Regeln"],
                    ["Gültigkeit", "Anteil bestandener Format-, Typ-, Bereichs- und Regex-Regeln"],
                    ["Eindeutigkeit", "Gegen den in `uniqueness_key` erklärten Schlüssel"],
                    ["Konsistenz", "Regeln über Spalten und über Dateien hinweg"],
                    ["Genauigkeit (geschätzt)", "Ausreißer in den von Ihnen benannten numerischen Spalten"],
                    ["Aktualität", "Wie alt die Daten gegen die `freshness`-Schwelle sind"],
                ]
            ),
            .heading("Drei Zusagen zur Note"),
            .bullets([
                "**Die Formel steht im Ergebnis** — Sie können sie von Hand nachrechnen.",
                "**Deterministisch**: dieselben Daten und dieselben Regeln ergeben dieselbe Note. Nur *Aktualität* hängt vom Zeitpunkt ab, daher ist `now` ein **Parameter** und wird im Ergebnis festgehalten.",
                "**Eine nicht bewertbare Dimension bleibt mit Begründung leer**, nie still mit 100 bedacht.",
            ]),
            .warning("""
                Diese letzte Zusage zählt. Eine Tabelle ohne erklärten `uniqueness_key`, die für \
                „Eindeutigkeit“ eine 100 bekommt, ist eine Note, die lügt — und sie lügt in die \
                schmeichelnde Richtung, die gefährliche.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Syntax von `.gquality.yaml`",
        summary: "Jeder Schlüssel der Regeldatei, mit einem vollständigen Regelwerk, das läuft.",
        keywords: ["gquality", "yaml", "regeln", "syntax", "datenstandard"],
        blocks: [
            .paragraph("""
                Die Datei liegt **neben den Daten**, nicht in der Anwendung: ein Datenstandard muss \
                prüfbar sein, und Prüfen ist das, was Menschen mit Standards tun.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — ein vollständiges Regelwerk",
                  source: """
                    schemaVersion: 1

                    # Gewichte der sechs Dimensionen. Eine fehlende Dimension wiegt 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Der Schlüssel, der eine Zeile eindeutig macht. Ohne ihn KANN die Dimension
                    # „Eindeutigkeit“ nicht bewertet werden — und die Gesamtnote sagt das.
                    uniqueness_key: [ma_don]

                    # Numerische Spalten, die für „Genauigkeit (geschätzt)“ auf Ausreißer geprüft werden.
                    accuracy_columns: [doanh_thu, so_luong]

                    # Die Dimension „Aktualität“.
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Warnen, wenn dieser Lauf gegenüber dem vorherigen abfällt.
                    drift:
                      max_total_drop: 3
                      max_dimension_drop: 5
                      max_row_change_pct: 20
                      max_null_increase_pct: 1
                      warn_on_new_failure: true

                    rules:
                      - col: ma_don
                        not_null: true
                      - col: ma_don
                        unique: true
                      - col: doanh_thu
                        dtype: float
                      - col: doanh_thu
                        range: { min: 0 }
                      - col: so_luong
                        dtype: int
                        severity: warn
                      - col: ngay
                        date_format: "yyyy-MM-dd"
                      - col: email
                        regex: "^[^@ ]+@[^@ ]+\\\\.[a-z]{2,}$"
                      - col: trang_thai
                        in_set: [moi, dang_giao, hoan_tat, huy]
                      - col: ghi_chu
                        length: { max: 500 }
                      - col: ma_tinh
                        not_null: true
                        max_null_pct: 2          # 2 % leer sind erlaubt
                      # Regel über Spalten hinweg: kein `col` nötig
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Regel über Dateien hinweg: der Wert muss in einer anderen Datei stehen
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Die Regeltypen"),
            .table(
                headers: ["Schlüssel", "Bedeutung", "Dimension"],
                rows: [
                    ["`not_null: true`", "Die Zelle muss gefüllt sein; `max_null_pct` lockert das", "Vollständigkeit"],
                    ["`unique: true`", "Keine wiederholten Werte in der Spalte", "Eindeutigkeit"],
                    ["`dtype: int\\|float\\|date\\|text`", "Richtiger Typ", "Gültigkeit"],
                    ["`range: { min:, max: }`", "Innerhalb eines Zahlenbereichs", "Gültigkeit"],
                    ["`length: { min:, max: }`", "Zeichenkettenlänge", "Gültigkeit"],
                    ["`regex: \"…\"`", "Passt auf einen regulären Ausdruck", "Gültigkeit"],
                    ["`in_set: [ … ]`", "Eines aus einer gegebenen Liste", "Gültigkeit"],
                    ["`date_format: \"…\"`", "Richtige Datumsform", "Gültigkeit"],
                    ["`compare: { a:, op:, b: }`", "Zwei Spalten vergleichen; `op` ist `<` `<=` `=` `>=` `>` `<>`", "Konsistenz"],
                    ["`foreign_key: { file:, column: }`", "Der Wert muss in einer anderen Datei stehen", "Konsistenz"],
                    ["`severity: error\\|warn`", "Schweregrad der Regel; `error` als Vorgabe", "—"],
                ]
            ),
            .warning("""
                Ein falsch geschriebener Regelschlüssel führt dazu, dass die Datei **mit einer Meldung \
                abgelehnt** wird, statt diese Regel still zu überspringen. Still zu überspringen heißt, \
                Sie glauben zu lassen, die Daten seien gegen eine Regel geprüft worden, die nie lief.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Ein Qualitätstor in der CI",
        summary: "Fehlerhafte Daten in der Pipeline aufhalten, über Rückgabewerte.",
        keywords: ["ci", "tor", "fail-under", "rückgabewert", "verlauf", "abweichung"],
        blocks: [
            .code(language: "bash", caption: "Bewerten und einen Rückgabewert liefern",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Option", "Bedeutung"],
                rows: [
                    ["`--quality <datei.yaml>`", "Das Regelwerk, gegen das bewertet wird"],
                    ["`--fail-under <0…100>`", "Unter dieser Note gilt es als FEHLGESCHLAGEN"],
                    ["`--json <datei\\|->`", "Maschinenlesbares Ergebnis; `-` schreibt nach stdout"],
                    ["`--record-history`", "Hängt eine Zeile an `sales-standard.history.jsonl`"],
                    ["`--now <JJJJ-MM-TT>`", "Legt das Bezugsdatum für *Aktualität* fest"],
                    ["`--recipe <datei.json>`", "Vor dem Bewerten **im Arbeitsspeicher** bereinigen, ohne Datei zu schreiben"],
                ]
            ),
            .table(
                headers: ["Rückgabewert", "Bedeutung"],
                rows: [["`0`", "Bestanden"], ["`1`", "Nicht bestanden"], ["`2`", "Laufzeitfehler"]]
            ),
            .heading("Warum die CI `--now` übergeben sollte"),
            .paragraph("""
                Ohne das vergleicht *Aktualität* die Daten mit dem Augenblick des Laufs — dieselbe \
                Datei verliert also mit den Tagen Punkte, und eines Morgens wird die Pipeline rot, \
                ohne dass jemand etwas geändert hätte.
                """),
            .heading("Abweichungsverfolgung"),
            .paragraph("""
                Mit `--record-history` hängt jeder Lauf eine Zeile an eine JSONL-Verlaufsdatei. Beim \
                nächsten Mal vergleichen die Schwellen im `drift:`-Block mit dem jüngsten Lauf und \
                warnen, wenn der Rückgang zu groß ist.
                """),
            .note("""
                Jede Abweichungsschwelle ist **standardmäßig aus**, außer `warn_on_new_failure`. Eine \
                von Haus aus aktive Warnung mit einer von der App gewählten Zahl schlüge bei jedem \
                schon beim zweiten Lauf an — und was am ersten Tag „Wolf“ ruft, wird am dritten \
                ignoriert.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Data Mining

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Data Mining — der ganze Ablauf",
        summary: "Ausreißer, Korrelation, Cluster, Prognose, Assoziationsregeln — und wie man sie liest.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Der Mining-Ablauf, von Anfang bis Ende",
        summary: "Sechs Werkzeuge, die Reihenfolge, und eine Regel: keine Messung, keine Schlussfolgerung.",
        keywords: ["mining", "analyse", "ablauf", "statistik"],
        blocks: [
            .warning("""
                **Erst bereinigen, dann schürfen.** Eine nicht normalisierte Datumsspalte erzeugt \
                falsche Prognosen; eine Zahlenspalte mit europäischen Gruppierungstrennzeichen erzeugt \
                Phantomausreißer. Jedes Werkzeug unten setzt eine saubere Tabelle voraus.
                """),
            .heading("Die Reihenfolge"),
            .steps([
                "**Ausreißer finden** — beantwortet *„ist irgendeine Zeile sonderbar“*. Am billigsten und oft sofort nützlich.",
                "**Korrelationsmatrix** — beantwortet *„welche Spalte bewegt sich mit welcher“*. Sie lenkt alles Weitere.",
                "**Clustern** — beantwortet *„wie viele natürliche Gruppen stecken hier drin“*.",
                "**Prognose** — nur mit einer Zeitspalte und mindestens **zwei vollen Zyklen**.",
                "**Assoziationsregeln** — nur für warenkorbförmige Daten: eine Transaktion je Zeile, oder zwei Spalten mit Transaktions-ID und Artikel.",
                "**Mining nach Gruppe** — führt die ersten drei **unabhängig innerhalb jeder Gruppe** erneut aus. Dieser Schritt dreht die aus der zusammengefassten Tabelle gezogene Schlussfolgerung häufig um.",
            ]),
            .heading("Drei Regeln für die ganze Familie"),
            .bullets([
                "**Jedes Ergebnis trägt einen „Methode“-Block**: Algorithmus, Parameter, Startwert, Formel. Er lässt sich nicht abschalten — eine Tabelle mit drei Zahlen, die nicht sagt, woher sie stammen, taugt nicht für eine Entscheidung.",
                "**Keine Messung, keine Schlussfolgerung.** Zu kleine Stichprobe, keine Varianz, singuläre Matrix — GEditor lehnt ab und sagt warum, statt eine Zahl zu liefern, die bloß richtig aussieht.",
                "**Deterministische Ergebnisse.** Dieselben Daten ergeben dasselbe Ergebnis; wo Zufall nötig ist, steht der Startwert in der Ausgabe.",
            ]),
            .heading("Vom Ergebnis zurück zu den Daten"),
            .paragraph("""
                Jeder Bereich **markiert in die Quelldaten zurück**: klicken Sie eine auffällige Zeile, \
                eine Korrelationszelle oder eine Assoziationsregel an, und die betreffenden Zeilen \
                werden in der Tabelle markiert. So kommen Sie von *„irgendetwas ist sonderbar“* zu \
                *„sonderbar genau in diesen Zeilen“*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Auffällige Zeilen finden",
        summary: "Vier Maße, drei Schweregrade, und eine Erklärung, warum eine Zeile sonderbar ist.",
        keywords: ["ausreißer", "anomalie", "z-wert", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Maß", "Wann"],
                rows: [
                    ["z-Wert", "Die Spalte ist annähernd normalverteilt"],
                    ["IQR", "Die Spalte ist schief mit langem Ausläufer — die sichere Vorgabe"],
                    ["MAD", "Die Spalte enthält bereits viele Ausreißer und braucht ein robustes Maß"],
                    ["Mahalanobis", "**Mehrere Spalten zugleich** — fängt Zeilen, die in der Kombination sonderbar sind, nicht in einer einzelnen Spalte"],
                ]
            ),
            .paragraph("""
                Die Ergebnisse werden nach **drei Schweregraden** eingefärbt statt in einer einzigen \
                Farbe — sonst ließe sich eine leicht ungewöhnliche Zeile nicht von einer wild \
                ungewöhnlichen unterscheiden.
                """),
            .heading("Das Warum erklären"),
            .paragraph("""
                Beim Mehrspaltenmaß zerlegt GEditor den Beitrag jeder Spalte und liefert einen Satz \
                wie *«auffällig vor allem durch die Kombination Umsatz (50 %) × Menge (50 %)»*.
                """),
            .note("""
                Dieser Prozentsatz bezieht sich auf den *erklärbaren Teil*, nicht auf den *Abstand*. \
                Der Methode-Block sagt das direkt unter der Tabelle.
                """),
            .warning("""
                Eine Spalte, deren IQR oder MAD null ist, lässt das Maß **die Ausführung verweigern**, \
                statt durch etwas Winziges zu teilen und einen riesigen Wert zu erzeugen. Ist im \
                Mehrspaltenfall die Kovarianzmatrix singulär, **sagt GEditor, welche Spalte zu \
                entfernen ist**, statt mit einer Pseudoinversen „es zum Laufen zu bringen“.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Korrelationsmatrix",
        summary: "Pearson und Spearman für jedes Paar, mit Streudiagramm auf Klick.",
        keywords: ["korrelation", "pearson", "spearman", "heatmap", "streudiagramm"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Koeffizient", "Was er misst"],
                rows: [
                    ["Pearson", "Einen **linearen** Zusammenhang"],
                    ["Spearman", "**Jeden monotonen** Zusammenhang, auch gekrümmte — auf Rängen berechnet"],
                ]
            ),
            .paragraph("""
                Klicken Sie eine Zelle in der Heatmap an, um das Streudiagramm dieses Paares zu sehen, \
                mit Regressionsgerade und R².
                """),
            .heading("Vier Einzelheiten, die das Lesen ändern"),
            .bullets([
                "**Bindungen bekommen Durchschnittsränge**, ein Umsortieren der Tabelle ändert den Spearman-Koeffizienten also nicht.",
                "**Leere Zellen werden paarweise behandelt**, und das `n` jeder Zelle steht direkt in der Tabelle — `0,93` über 6 Zeilen bedeutet nicht, was `0,93` über 6 000 Zeilen bedeutet.",
                "**Eine konstante Spalte liefert leer**, nicht 0. Null heißt *gemessen, kein Zusammenhang gefunden*.",
                "**Die Farbskala ist blau↔orange**, nicht rot-grün: 8 % der Männer sehen eine rot-grüne Skala als eine graue Masse, was `+0,9` und `−0,9` gleich aussehen lässt.",
            ]),
            .warning("""
                **Korrelation bedeutet keine Kausalität.** Dieser Satz wird **in das Diagramm selbst** \
                gezeichnet, er reist also mit dem Bild, wenn Sie es exportieren.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Clustern",
        summary: "k-Means und DBSCAN, zwei Arten, k zu wählen — und eine Warnung zur Skalierung.",
        keywords: ["cluster", "kmeans", "dbscan", "gruppen", "silhouette", "ellbogen"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algorithmus", "Wann"],
                rows: [
                    ["k-Means", "Sie kennen (oder wollen erproben) die Anzahl der Cluster; die Cluster sind klumpenförmig"],
                    ["DBSCAN", "Sie kennen die Anzahl nicht; die Cluster haben beliebige Formen; Sie wollen Rauschen abtrennen"],
                ]
            ),
            .heading("Die Skalierung ist standardmäßig an — und warum"),
            .paragraph("""
                Eine Spalte `Umsatz` (in Millionen) neben einer Spalte `Menge` (in Stück): der Abstand \
                zwischen zwei Zeilen wird fast vollständig von der größeren bestimmt. Das ist nicht \
                „suboptimal“ — das ist **eine andere Frage beantworten**. Die geltende Skalierung wird \
                im Ergebnis festgehalten.
                """),
            .heading("Die Anzahl der Cluster wählen"),
            .bullets([
                "**Silhouette** — je höher der Wert, desto besser getrennt die Cluster. Bei einer großen Tabelle **zieht sie eine Stichprobe** (gleichmäßig verteilt, nicht die ersten 2 000 Zeilen), und das Ergebnis erklärt sich als Schätzung.",
                "**Ellbogen** — trägt die Quadratsumme innerhalb der Cluster gegen k auf. Das ist eine **Art, ein Diagramm zu lesen**, keine Optimierung: diese Größe fällt immer, wenn k steigt, es gibt also statistisch kein „optimales k“.",
            ]),
            .note("""
                Bei DBSCAN hilft das **k-Abstands**-Diagramm bei der Radiuswahl: das Knie der Kurve ist \
                meist ein sinnvoller Startwert.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Zeitreihenprognose",
        summary: "Trend- und Saisonzerlegung, Holt-Winters, und eine Grundlinie, die stets danebenläuft.",
        keywords: ["prognose", "zeitreihe", "saisonalität", "holt-winters", "trend"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Wählen Sie eine Zeitspalte und eine Wertspalte. GEditor zerlegt die Reihe in **Trend · \
                Saison · Rest** und prognostiziert dann mit Holt-Winters (additiv oder multiplikativ), \
                mit 80-%- und 95-%-Intervallen.
                """),
            .heading("Die Grundlinie läuft immer mit, und sie sagt geradeheraus, wer gewonnen hat"),
            .paragraph("""
                Neben dem Modell führt GEditor zwei naive Verfahren aus: *nimm die vorige Periode* und \
                *nimm dieselbe Periode der letzten Saison*. **Verliert** das Modell gegen eine \
                Grundlinie, erscheint dieser Satz in der **ersten Zeile, in anderer Farbe** — nicht \
                unter einer Zahlentabelle.
                """),
            .paragraph("""
                Der Grund: Prognosewerkzeuge neigen dazu, das Modell als Tatsache darzustellen, und der \
                Nutzer hat keine Möglichkeit zu erfahren, dass „nimm einfach die Zahl vom letzten \
                Monat“ genauer gewesen wäre.
                """),
            .heading("Drei Stellen, an denen GEditor ablehnt oder sich erklärt"),
            .bullets([
                "**Ohne zwei volle Zyklen fällt er auf das naive Verfahren zurück.** Saisonalität an das Rauschen eines einzigen Zyklus anzupassen und in die Zukunft zu wiederholen erzeugt eine sehr überzeugende, völlig erfundene Prognose.",
                "**Trifft MAPE auf eine Null, sagt er das**, und sind mehr als 25 % der Perioden null, hält er die Kennzahl zurück — sie still zu überspringen erzeugt eine Zahl, die auf einer systematisch verzerrten Teilmenge gerechnet wurde.",
                "**Das Konfidenzintervall erklärt sich als Näherung** und sagt, dass es bei langen Horizonten zu langsam breiter wird.",
            ]),
            .note("""
                Die Saisonperiode wird an der **ersten Differenz** erkannt, nicht an der rohen Reihe: \
                ein Trend macht jede Verzögerung hoch korreliert und ersäuft die Saisonspitze.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Assoziationsregeln",
        summary: "Kauft A, kauft oft auch B — und warum die Tabelle nach Lift sortiert ist, nicht nach Konfidenz.",
        keywords: ["apriori", "assoziationsregeln", "warenkorb", "lift", "support"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Zwei Datenformen werden angenommen:"),
            .bullets([
                "**Ein Warenkorb je Zeile** — eine Spalte mit einer Artikelliste.",
                "**Zwei Spalten** — Transaktions-ID und Artikel, ein Artikel je Zeile.",
            ]),
            .table(
                headers: ["Kennzahl", "Bedeutung"],
                rows: [
                    ["support", "Anteil der Körbe, die beide Seiten enthalten"],
                    ["Konfidenz", "Welcher Anteil der Körbe mit der linken Seite auch die rechte hat"],
                    ["**Lift**", "Konfidenz geteilt durch die Grundrate der rechten Seite"],
                    ["leverage", "Der Abstand zu dem, was Unabhängigkeit vorhersagen würde"],
                ]
            ),
            .heading("Nach Lift sortiert, nicht nach Konfidenz"),
            .paragraph("""
                Erscheint die rechte Seite ohnehin in 95 % der Körbe, dann hat **jede** Regel, die zu \
                ihr führt, rund 95 % Konfidenz — und sagt dabei gar nichts. Nach Konfidenz zu sortieren \
                setzt genau die bedeutungslosesten Regeln nach oben.
                """),
            .warning("""
                `lift < 1` wird **in der Zeile selbst gekennzeichnet**: 80 % Konfidenz auf etwas mit \
                einer Grundrate von 95 % bedeutet einen **umgekehrten** Zusammenhang — eine richtige \
                Zahl, die zu einem falschen Schluss führt.
                """),
            .bullets([
                "Zwei Packungen Milch zu kaufen bleibt **eine** Transaktion mit Milch: Dubletten innerhalb eines Korbes werden verworfen, sonst bläht sich der Support mit der Menge auf.",
                "Eine zu niedrige Support-Schwelle lässt die Kandidatenmenge kombinatorisch explodieren; beim Erreichen der Obergrenze **hält GEditor an und erklärt die Tabelle für unvollständig**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Nach Gruppe schürfen",
        summary: "Die Analyse je Gruppe unabhängig erneut ausführen — der Schritt, der am häufigsten eine Schlussfolgerung umdreht.",
        keywords: ["nach gruppe", "simpson", "filialen", "gruppen vergleichen"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Wählen Sie eine Textspalte als Gruppierungsschlüssel. Jede Gruppe bekommt Ausreißer, \
                Prognose und Korrelation **völlig unabhängig** ausgeführt und dann nach dem von Ihnen \
                gewählten Kriterium gereiht.
                """),
            .heading("Warum Gruppen getrennt und nicht zusammengefasst gehören"),
            .paragraph("""
                Zwei Filialen, eine um 10, eine um 100. Ein auf der **zusammengefassten** Tabelle \
                berechneter Ausreißerzaun landet bei etwa ±135 — und er versagt **in beide \
                Richtungen**:
                """),
            .bullets([
                "**Falsch negativ**: ein Wert von 20, für die kleine Filiale offenkundig auffällig, liegt gut innerhalb des gemeinsamen Zauns. Je mehr Gruppen, desto blinder wird er.",
                "**Falsch positiv**: einer weit gestreuten Gruppe wird ihr normaler Ausläufer vom gemeinsamen Zaun abgeschnitten, und eine Schar gewöhnlicher Zeilen wird gekennzeichnet.",
            ]),
            .heading("Die Spalte „Korrelationsabweichung“ fängt das Simpson-Paradoxon"),
            .paragraph("""
                Drei Gruppen, in denen **jede** Gruppe ihre zwei Spalten mit `−1` korreliert, \
                zusammengefasst aber mit `> 0,9`. Wer nur die zusammengefasste Tabelle liest, schließt \
                **genau das Gegenteil**. Diese Spalte zeigt genau auf solche Fälle.
                """),
            .note("""
                Der Bereich bietet nur **Textspalten** als Gruppierungsschlüssel an und hält bei 1 000 \
                Gruppen mit einer Warnung an — damit niemand eine Bestellnummernspalte wählt und jede \
                Zeile zu einer eigenen Gruppe macht.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Text Mining",
        summary: "n-Gramme und TF-IDF über einer Textspalte — kennzeichnende Wendungen finden.",
        keywords: ["text mining", "n-gramm", "tf-idf", "schlüsselwörter", "wendungen"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Läuft auf einer Textspalte — Produktbeschreibungen, Kundenrückmeldungen, Notizfelder.
                """),
            .bullets([
                "**n-Gramme** — die häufigsten Wendungen aus 1, 2 und 3 Wörtern.",
                "**TF-IDF** — Wörter, die für jede Dokumentgruppe **kennzeichnend** sind, also hier häufig und anderswo selten.",
            ]),
            .paragraph("""
                Der Unterschied: n-Gramme sagen Ihnen *„was Kunden immer wieder erwähnen“*, TF-IDF sagt \
                Ihnen *„worin sich diese Gruppe von den anderen unterscheidet“*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
