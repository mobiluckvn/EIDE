import Foundation

/// Nederlandse helpinhoud — deel 5: rapporten, kennis, automatisering en de toepassing.
extension HelpNL {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Rapporten en schema's",
        summary: "Een tekstbestand dat een HTML-rapport oplevert waarvan de cijfers herrekend worden, plus Mermaid-schema's.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md`-rapporten",
        summary: "Markdown plus vier soorten uitvoerbare blokken — links schrijven, rechts het voorbeeld zien.",
        keywords: ["rapport", "greport", "html", "uitvoeren", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Een `.greport.md`-bestand is **gewone Markdown** plus enkele uitvoerbare afgebakende blokken. \
                Het tonen ervan levert een **op zichzelf staand** HTML-bestand op — geen netwerk, geen \
                bijbehorende bestanden — dat iedereen kan openen.
                """),
            .paragraph("""
                Omdat het kale tekst is, kan het **vergeleken, geversioneerd en gedeeld** worden — dezelfde \
                gedachte als bij opschoonrecepten en sets kwaliteitsregels.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — een volledig rapport",
                  source: """
                    ---
                    title: Verkooprapport augustus
                    source: sales-2026-08.csv
                    ---

                    # Verkooprapport augustus

                    Cijfers per 31 augustus 2026.

                    ## Omzet per provincie

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Omzet per provincie
                    y_label: Omzet
                    number_format: vi
                    suffix: " ₫"
                    source: Bron — sales-2026-08.csv
                    ```

                    ## Kwaliteit van de brongegevens

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("De soorten blokken"),
            .table(
                headers: ["Blok", "Levert"],
                rows: [
                    ["`query`", "Een tabel, uit een SQL-instructie van DuckDB"],
                    ["`chart`", "Een grafiek"],
                    ["`quality`", "Een scorekaart voor gegevenskwaliteit"],
                    ["`mining`", "Een ranglijsttabel van mining per groep"],
                    ["`mermaid`", "Een schema"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                Het `---`-blok bovenaan verklaart `title` en `source` — de standaardgegevensbron voor elk blok \
                dat zijn eigen bron niet noemt.
                """),
            .note("""
                Het voorbeeld wordt herbouwd zodra u ophoudt met typen, maar het **ontleedt alleen**; het voert \
                niet bij elke toetsaanslag bevragingen uit. Documentfouten en gegevensfouten worden apart \
                gemeld — *«het chart-blok mist de sleutel `kind`»* is een bestandsfout, *«de kolom `doanh_thu` \
                bestaat niet»* is een gegevensfout.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "Het `query`-blok",
        summary: "Eén DuckDB-instructie wordt één tabel in het rapport.",
        keywords: ["bevraging", "sql", "tabel", "rapport", "blok"],
        blocks: [
            .paragraph("""
                De inhoud van het blok is **één SQL-instructie**, uitgevoerd op de bron van het rapport. De \
                tabel heet `t`, in hetzelfde dialect als het bevragingspaneel.
                """),
            .code(language: "text", caption: "Een query-blok met parameters",
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
                `:thang` is een **parameter**. Hij wordt bij het tonen aangeleverd — vanaf de shell met \
                `--param thang=8`, of uit een lijstbestand wanneer u rapporten in partij maakt.
                """),
            .note("""
                Tabellen in een gegevensrapport **horen uit een query-blok te komen**, niet met de hand getypt \
                te zijn. Een met de hand getypte tabel wordt niet herrekend wanneer de cijfers veranderen, en \
                vroeg of laat spreekt ze de rest van het rapport tegen.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "Het `chart`-blok",
        summary: "Een YAML-instelling wordt een grafiek — en de belangrijkste regel van het formaat.",
        keywords: ["grafiek", "yaml", "rapport", "tekenen"],
        blocks: [
            .code(language: "yaml", caption: "Elke sleutel van een chart-blok",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Omzet per provincie
                    x_label: Provincie
                    y_label: Omzet
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Bron — sales.csv, per 26 augustus 2026
                    """),
            .heading("Zonder `query` gebruikt hij het resultaat van het query-blok DIRECT ERBOVEN"),
            .paragraph("""
                Dat is de belangrijkste regel van het formaat. Dankzij haar herhaalt het gebruikelijke rapport \
                «een tabel en dan een grafiek van die tabel» het SQL niet — en het herhalen betekent dat de \
                twee kopieën uiteindelijk uit elkaar lopen, waarna tabel en grafiek op dezelfde pagina \
                verschillende dingen zeggen.
                """),
            .warning("""
                In ruil **telt de volgorde van de blokken**: er een query-blok tussen zetten verandert de \
                gegevens van de grafiek eronder.
                """),
            .heading("Waarom `source` een eigen sleutel is"),
            .paragraph("""
                Een bronvermelding als lopende tekst onder de grafiek toont prima — op het scherm. Maar de \
                grafiek wordt als PNG uitgevoerd en elders geplakt, en de lopende tekst blijft achter. Als \
                sleutel wordt ze **in de afbeelding** getekend en reist ze mee.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "Het `quality`-blok",
        summary: "Een scorekaart voor gegevenskwaliteit binnen het rapport.",
        keywords: ["kwaliteit", "scorekaart", "rapport", "blok"],
        blocks: [
            .code(language: "yaml", caption: "Elke sleutel van een quality-blok",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # leeg betekent de eigen bron van het rapport
                    title: Kwaliteit van de verkoopgegevens van augustus
                    rules: true                 # de tabel per regel geslaagd/gezakt tonen
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # de peildatum voor «Tijdigheid» vastleggen
                    fail_under: 90              # daaronder krijgt de kaart een waarschuwingskleur
                    """),
            .table(
                headers: ["`chart`", "Tekent"],
                rows: [
                    ["`violations`", "Het aantal regels voor de **gezakte** regels — beantwoordt «wat eerst herstellen»"],
                    ["`dimensions`", "De cijfers van de zes dimensies"],
                    ["`none`", "Alleen een tabel, geen grafiek"],
                ]
            ),
            .note("""
                Zet `now:` in een terugkerend rapport. Zonder dat vergelijkt *Tijdigheid* met het moment van \
                tonen, zodat het rapport van vorige maand opnieuw tonen een ander cijfer geeft dan wat u hebt \
                gepubliceerd.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "Het `mining`-blok",
        summary: "Groepen rangschikken naar afwijkingen, voorspellingsfout of correlatieafwijking.",
        keywords: ["mining", "rapport", "groepsranglijst"],
        blocks: [
            .code(language: "yaml", caption: "Elke sleutel van een mining-blok",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # de kolom voor afwijkingen en voorspelling
                    pair: chi_phi             # een tweede kolom, voor de correlatie per groep
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # leeg betekent de eigen bron van het rapport
                    title: Mining per provincie
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Rangschikt naar"],
                rows: [
                    ["`anomalies`", "De groep met de meeste afwijkende regels"],
                    ["`forecast_error`", "De groep met de slechtste voorspelling"],
                    ["`correlation_gap`", "De groep waarvan de correlatie het sterkst van de samengevoegde tabel afwijkt — vangt de paradox van Simpson"],
                ]
            ),
            .warning("""
                **Geen sleutel zet het «Methode»-blok uit.** Een groepsranglijst zonder haar methode laat de \
                lezer geen manier om te weten tegen welke grens «de meeste afwijkingen» is gemeten. Wie het \
                wil verbergen kent het gewenste antwoord al.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Rapporten in partij maken",
        summary: "Eén sjabloon, één lijst met parameters, veel rapporten.",
        keywords: ["partij", "massaal", "parameters", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Eén rapportsjabloon, uitgevoerd voor elk filiaal of elke maand. De parameterlijst is een CSV- \
                of JSON-bestand — **één regel per rapport**.
                """),
            .code(language: "text", caption: "list.csv — één regel per rapport",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "De hele partij vanaf de shell tonen",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Of één rapport met met de hand meegegeven parameters",
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
        title: "Mermaid-schema's",
        summary: "Schema's in tekst tekenen, ze met opdrachten bewerken, in beide richtingen gelijklopend voorbeeld.",
        keywords: ["mermaid", "schema", "stroomschema", "volgorde", "tekenen"],
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
                Mermaid tekent schema's **uit tekst**: u schrijft een beschrijving, de machine tekent haar. Een \
                schema kan daardoor vergeleken en geversioneerd worden — iets wat een afbeeldingsbestand niet \
                kan.
                """),
            .paragraph("""
                Open `Mermaid-schema: voorbeeld` voor een weergave naast de bewerker. De twee lopen **in beide \
                richtingen gelijk**: selecteer een element in de afbeelding en de cursor springt naar de regel \
                ervan.
                """),
            .heading("Met opdrachten bewerken, niet door over te typen"),
            .table(
                headers: ["Opdracht", "Wat ze doet"],
                rows: [
                    ["Een sjabloon invoegen…", "Een kant-en-klaar geraamte voor elk schematype invoegen"],
                    ["Een element toevoegen…", "Een knooppunt of een deelnemer toevoegen"],
                    ["De twee geselecteerde elementen verbinden", "Een pijl ertussen tekenen"],
                    ["Het label van het geselecteerde element bewerken…", "De tekst wijzigen zonder de regel te zoeken"],
                    ["Het geselecteerde element wissen", "Het knooppunt **en** elke rand die het raakt weghalen"],
                    ["Bericht omhoog / omlaag", "Stappen in een volgordeschema herschikken"],
                    ["Opnieuw opmaken", "Het hele blok inspringen en uitlijnen"],
                ]
            ),
            .heading("Naar een bestand afsplitsen en weer inbedden"),
            .paragraph("""
                Grote schema's horen in hun eigen `.mmd`-bestand: `Blok naar een .mmd-bestand afsplitsen…` \
                verplaatst het en laat een verwijzing achter. `Het verwezen bestand weer inbedden` doet het \
                omgekeerde wanneer u één enkel bestand moet versturen.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Gebruikelijke Mermaid-syntaxis",
        summary: "De vier meestgebruikte schematypes, elk met een sjabloon dat werkt.",
        keywords: ["mermaid", "syntaxis", "stroomschema", "volgorde", "gantt", "klassen", "sjabloon"],
        blocks: [
            .code(language: "mermaid", caption: "Stroomschema — een goedkeuringsproces voor bestellingen",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Volgordeschema — een betaalstroom",
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
            .code(language: "mermaid", caption: "Klassenschema — een gegevensmodel",
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
            .code(language: "mermaid", caption: "Gantt — een uitgaveplan",
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
                headers: ["Vorm van het knooppunt", "Schrijf"],
                rows: [
                    ["Rechthoek", "`A[Label]`"],
                    ["Afgerond", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Ruit (beslissing)", "`A{Label}`"],
                    ["Cilinder (gegevens)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Pijl", "Schrijf"],
                rows: [
                    ["Vol, met punt", "`A --> B`"],
                    ["Gestippeld", "`A -.-> B`"],
                    ["Dik", "`A ==> B`"],
                    ["Met label", "`A -- label --> B`"],
                ]
            ),
            .note("""
                De richting van een stroomschema komt vlak na `flowchart`: `TD` van boven naar beneden, `LR` \
                van links naar rechts, en verder `BT` en `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Kennispakket

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Het kennispakket",
        summary: "In stukken hakken, zoekindexen, kennisgrafen, entiteiten en het beoordelen van terugvinden.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Wat het kennispakket is",
        summary: "Gereedschap om gegevens voor te bereiden en na te kijken voor een vraag-en-antwoordsysteem op documenten.",
        keywords: ["rag", "kennis", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Wanneer u een systeem bouwt dat vragen uit een verzameling documenten beantwoordt, zit het \
                meeste werk niet in het model maar in het **voorbereiden van de gegevens**: documenten in \
                zinnige passages knippen, de kwaliteit van die passages nakijken, een index bouwen en **meten \
                of het terugvinden werkelijk het juiste vindt**.
                """),
            .paragraph("""
                Dit hoofdstuk is precies het gereedschap daarvoor. Het draait **volledig op uw machine** en \
                roept nooit het netwerk aan.
                """),
            .table(
                headers: ["Taak", "Gereedschap"],
                rows: [
                    ["Documenten in passages knippen", "Voorbeeld van het hakken"],
                    ["Passages bekijken en beoordelen", "JSONL-stukken nakijken"],
                    ["Tussen gegevensvormen omzetten", "Kennisomzetting"],
                    ["Een relatiegraaf bouwen en nakijken", "Kennisgraaf"],
                    ["Eigennamen in tekst vinden", "Entiteiten markeren"],
                    ["De kwaliteit van het terugvinden meten", "Terugvindlab"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Een JSONL-verzameling hakken en nakijken",
        summary: "De hakgrenzen op de tekst zelf vooraf zien, en dan de hele verzameling beoordelen.",
        keywords: ["chunk", "jsonl", "verzameling", "overlap", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Voorbeeld van het hakken"),
            .paragraph("""
                Open een tekst- of Markdown-document, kies een aanpak en een stukgrootte. De grenzen worden \
                **op de tekst zelf opgelicht**, zodat u ziet waar een snee midden in een zin of dwars door een \
                tabel valt voordat u iets uitvoert.
                """),
            .bullets([
                "**Vaste grootte** met overlap.",
                "**Op structuur** — op Markdown-koppen, waarbij de draad van het document heel blijft.",
                "**Per alinea**, samenvoegend tot de grootte bereikt is.",
            ]),
            .heading("Een bestaande JSONL-verzameling nakijken"),
            .paragraph("""
                Voor een verzameling die u al hebt (één JSON-stuk per regel) beantwoordt `JSONL: stukken \
                nakijken…`: welke regels geen geldig JSON zijn, welke stukken te kort of te lang zijn, welke \
                elkaar dubbelen en welke midden in een zin zijn afgesneden.
                """),
            .note("""
                Ook een verzameling is te beoordelen met **hetzelfde raamwerk van zes dimensies** als \
                tabelgegevens — gebruik de sleutel `corpus:` in een `quality`-blok van een rapport.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Kennisformaten omzetten",
        summary: "Stukken tussen JSONL · CSV · Markdown, grafen tussen DOT · Mermaid · randlijsten.",
        keywords: ["omzetten", "jsonl", "dot", "mermaid", "randlijst"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Van", "Naar"],
                rows: [
                    ["JSONL-stukken", "CSV · Markdown"],
                    ["CSV-stukken", "JSONL · Markdown"],
                    ["DOT-graaf", "Mermaid · randlijst"],
                    ["Randlijst", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Er is een **voorbeeld van vijf regels** voordat het nieuwe tabblad wordt gemaakt, hetzelfde \
                mechanisme als bij de CSV-omzetting.
                """),
            .paragraph("""
                `Drietallen/randen als tabel openen` toont een bestand met drietallen of een randlijst als \
                tabel — filter en sorteer zoals bij elke andere CSV.
                """),
            .note("""
                De richting **Markdown → JSONL** zit niet in deze opdracht: die richting *is* het hakken, en de \
                opdracht verwijst u daarheen. Twee uitwerkingen van één snee zouden twee verschillende \
                resultaten geven.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Kennisgrafen",
        summary: "Syntaxis nakijken, gezondheid beoordelen en algoritmen draaien op grafen met een miljoen randen.",
        keywords: ["graaf", "dot", "cypher", "pagerank", "louvain", "syntaxiscontrole"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor leest grafen als **DOT**, als **randlijsten** en als **drietallen**. `Graafsyntaxis \
                nakijken` vangt syntaxisfouten, losse knooppunten en randen die naar niet-bestaande knooppunten \
                wijzen.
                """),
            .heading("Beschikbare algoritmen"),
            .table(
                headers: ["Algoritme", "Beantwoordt"],
                rows: [
                    ["k-sprong-omgeving", "Wat binnen k stappen met dit knooppunt samenhangt"],
                    ["Samenhangende delen", "Uit hoeveel losse stukken de graaf bestaat"],
                    ["PageRank", "Welke knooppunten belangrijk zijn"],
                    ["Louvain", "Hoe de graaf in gemeenschappen uiteenvalt"],
                ]
            ),
            .paragraph("""
                Op een graaf met **een miljoen randen** draaien alle vier tussen enkele milliseconden en \
                ongeveer een seconde.
                """),
            .note("""
                Ook een graaf is te beoordelen met het **raamwerk van zes dimensies** dat voor tabellen en \
                verzamelingen wordt gebruikt — gebruik de sleutel `graph:` in een `quality`-blok.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Entiteiten uit een lijst markeren",
        summary: "Een lijst met eigennamen laden en elk voorkomen vinden — volgens drie regels die voor het Vietnamees zijn gemaakt.",
        keywords: ["entiteit", "eigennaam", "ner", "markeren", "overeenkomst"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Laad een lijst met namen (bedrijven, producten, plaatsen) en GEditor licht elk voorkomen in het \
                document op, met een tabel met tellingen.
                """),
            .heading("Drie regels voor overeenkomst, alle uit Vietnamese gegevens"),
            .bullets([
                "**De langste overeenkomst wint.** Staan `An Phát` en `Công ty An Phát` allebei in de lijst, dan moet een zin met de langere uitdrukking op de langere passen — anders wordt hij in tweeën geknipt en als twee entiteiten geteld, wat de statistiek **opblaast**.",
                "**Woordgrenzen zijn verplicht.** `An` mag niet binnen `Anh` of `Hoàn` passen. Vietnamese eigennamen zijn kort en delen lettergrepen met talloze gewone woorden.",
                "**Ongevoelig voor hoofdletters, maar GEVOELIG voor accenten.** `CÔNG TY` en `Công ty` zijn één; `má` en `ma` niet.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Varianten van entiteiten oplossen",
        summary: "`Cty An Phát` en `Công ty An Phát` als één herkennen — met de beslissing toch bij u.",
        keywords: ["entiteiten samenvoegen", "varianten", "namen normaliseren", "dubbelen"],
        blocks: [
            .paragraph("""
                Dezelfde trosvorming als bij **vage dubbelen** in een CSV-tabel — één gedeelde uitwerking, geen \
                twee.
                """),
            .paragraph("""
                De uitkomst is een **voorstel**: u bekijkt elke tros en kiest de gangbare vorm. Er is geen knop \
                «alles samenvoegen», want twee namen die voor 92 % gelijk zijn kunnen twee echte organisaties \
                zijn.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Het terugvindlab",
        summary: "Meten of de index het juiste vindt, met een set vragen met antwoorden.",
        keywords: ["terugvinden", "bm25", "recall", "mrr", "ndcg", "beoordeling"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Laad een **beoordelingsset** — elke regel een vraag met de nummers van de stukken die \
                teruggegeven zouden moeten worden — en laat dan de hele partij tegen de index draaien.
                """),
            .table(
                headers: ["Maat", "Beantwoordt"],
                rows: [
                    ["recall@k", "Hoeveel van de antwoordset in de bovenste k verschijnt"],
                    ["MRR", "Hoe diep het eerste juiste resultaat staat"],
                    ["nDCG@k", "Of de volgorde goed is, positie meegerekend"],
                ]
            ),
            .paragraph("""
                De resultaten komen ook **per vraag**, de slechtste eerst — dat is uw lijst met dingen om in \
                de verzameling te herstellen, in de volgorde die het meest loont.
                """),
            .warning("""
                Alle drie de maten zijn **gemiddelden**, en een gemiddelde verbergt heel veel. Lees altijd de \
                tabel per vraag voordat u besluit dat «de index goed genoeg is».
                """),
            .paragraph("""
                Twee instellingen zijn naast elkaar te vergelijken, en het resultaat valt rechtstreeks in een \
                `.greport.md`-rapport zodat de volgende ronde gelijk is.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Macro's en automatisering

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Macro's en automatisering",
        summary: "Handelingen opnemen, ze in partij uitvoeren, scripts schrijven en het geheel vanaf de shell besturen.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Macro's opnemen en afspelen",
        summary: "Een reeks opnemen en herhalen — de hele ronde is één stap terug.",
        keywords: ["macro", "opnemen", "afspelen", "herhalen", "automatiseren"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Opnemen starten / stoppen"),
                HelpShortcut("⌃P", "Afspelen"),
            ]),
            .steps([
                "`⌃R` start de opname.",
                "Doe wat u wilt herhalen — typen, de cursor bewegen, zoeken, vervangen.",
                "`⌃R` opnieuw om te stoppen.",
                "`⌃P` speelt het af, of `Macro ▸ Afspelen tot het einde van het document` laat het tot het einde lopen.",
                "`Macro ▸ Macro bewaren…` geeft er een naam aan voor latere sessies.",
            ]),
            .heading("Ze neemt OPDRACHTEN op, geen kale toetsaanslagen"),
            .paragraph("""
                Een macro bewaart **wat u hebt gedaan**, niet welke toetsen u hebt ingedrukt. Dat maakt haar \
                onafhankelijk van de toetsenbordindeling en van de actieve invoermethode, en het maakt het \
                macrobestand **leesbaar** wanneer u het opent.
                """),
            .heading("Wanneer een macro stopt"),
            .table(
                headers: ["Reden", "Betekenis"],
                rows: [
                    ["Het aantal herhalingen is op", "Normaal"],
                    ["Een `find`-stap vond niets", "Zo stopt «afspelen tot het einde van het bestand» vanzelf"],
                    ["Het einde van het document is bereikt", "Nergens verder heen"],
                    ["U hebt geannuleerd", "`Macro ▸ Lopende macro annuleren`"],
                    ["Een ronde veranderde niets en bewoog niets", "Gestopt zodat ze niet eindeloos rondgaat"],
                ]
            ),
            .note("De hele ronde — ook tienduizend herhalingen — is **één** stap terug."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Een macro in partij uitvoeren",
        summary: "Over alle geopende tabbladen, of over een map met niet-geopende bestanden.",
        keywords: ["partij", "alle tabbladen", "map", "macro", "masker"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Opdracht", "Bereik", "Ongedaan te maken"],
                rows: [
                    ["Uitvoeren op alle tabbladen", "De geopende tabbladen", "Ja — één stap terug per tabblad"],
                    ["Uitvoeren over een map…", "Bestanden op schijf die **niet open** staan", "Nee"],
                ]
            ),
            .warning("""
                Over een map uitvoeren raakt bestanden aan die in geen enkel tabblad open staan, dus er is \
                **geen ongedaan maken**. Standaard **schrijft GEditor nieuwe bestanden** in plaats van de \
                originelen te overschrijven. Houd die instelling aan tenzij u een reservekopie of een \
                repository met versies hebt.
                """),
            .heading("Bestanden met een masker filteren"),
            .paragraph("""
                De mapkiezer heeft een **filter op bestandsnaam**: typ `*.csv;*.log` en de macro raakt alleen \
                die aan. Het is dezelfde maskersyntaxis die `In een map zoeken` gebruikt, met meerdere patronen \
                gescheiden door `;` of `,`.
                """),
            .bullets([
                "Laat het **leeg** en hij neemt elk tekstbestand dat GEditor kan lezen — het gedrag van vroeger.",
                "Het masker **vervangt** die lijst met extensies in plaats van haar verder te versmallen: typ `*.bak` en hij draait op `.bak`-bestanden, ook al staat die extensie niet in de tekstlijst.",
                "Past er niets, dan **herhaalt de melding uw masker** in plaats van een lege map de schuld te geven.",
            ]),
            .paragraph("""
                Dit vakje heeft een heel praktische reden: een map bevat 400 `.json`-bestanden en 12 \
                `.log`-bestanden, en uw macro ruimt alleen logboeken op. Zonder masker worden die andere 400 \
                ook verwerkt — en omdat de partij nieuwe bestanden schrijft, laat een misgreep 400 stukken \
                rommel achter.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Syntaxis van het macrobestand",
        summary: "Zeven soorten stappen, het volledige JSON-formaat en twee macro's die werken.",
        keywords: ["macro", "json", "syntaxis", "formaat", "met de hand bewerken", "delen"],
        blocks: [
            .paragraph("""
                Elke macro is **een eigen JSON-bestand** in de map `macros/` van GEditor. Schade blijft tot één \
                macro beperkt, en er een met een collega delen betekent één bestand versturen.
                """),
            .code(language: "text", caption: "Waar de bestanden wonen",
                  source: "~/Library/Application Support/GEditor/macros/<macronaam>.json"),
            .heading("De zeven soorten stappen"),
            .table(
                headers: ["Stap", "Wordt geschreven als", "Betekenis"],
                rows: [
                    ["Tekst invoegen", "`{\"insert\": {\"_0\": \"tekst\"}}`", "Bij de cursor typen; met een selectie vervangt het die"],
                    ["Achterwaarts wissen", "`{\"deleteBackward\": {}}`", "Zoals de wistoets"],
                    ["Voorwaarts wissen", "`{\"deleteForward\": {}}`", "Zoals ⌦"],
                    ["Bewegen", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Zie de lijst met richtingen hieronder"],
                    ["De regel selecteren", "`{\"selectLine\": {}}`", "Zonder de regelovergang"],
                    ["Zoeken", "`{\"find\": { … }}`", "Vindt en **selecteert** het volgende voorkomen"],
                    ["De selectie vervangen", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` werkt als de vorige stap een `find` met regex was"],
                ]
            ),
            .heading("Bewegingsrichtingen"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("De volledige `find`-stap"),
            .code(language: "json", caption: "De vier sleutels van een find-stap",
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
            .paragraph("`mode` neemt `normal`, `extended` of `regex` — dezelfde drie modi als het zoekveld."),
            .heading("Voorbeeld 1 — de provinciecode aan het regelbegin in hoofdletters zetten"),
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
                Voer haar uit met `Macro ▸ Afspelen tot het einde van het document`: dat de `find`-stap niets \
                meer vindt, is precies de stopvoorwaarde.
                """),
            .heading("Voorbeeld 2 — de regel na elke regel met TODO wissen"),
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
                Probeer een met de hand bewerkte macro eerst op een kopie. Een verkeerd getypte `find`-stap \
                laat de macro meteen stoppen — dat is het goedaardige geval. Het kwaadaardige geval is een \
                patroon dat ruimer past dan u dacht, en dat duizenden plekken bewerkt binnen één stap terug.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript-scripts",
        summary: "Vier functies, één `.js`-bestand, en alles wat het doet is één stap terug.",
        keywords: ["script", "javascript", "js", "automatiseren", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Zet een `.js`-bestand in de map `scripts/` van GEditor en voer het uit vanaf `Macro ▸ \
                Script…`. Een script ziet precies **vier** dingen:
                """),
            .table(
                headers: ["Aanroep", "Betekenis"],
                rows: [
                    ["`doc.text`", "De hele tekst van het document"],
                    ["`doc.selection`", "De selectie (lege tekenreeks als er niets geselecteerd is)"],
                    ["`doc.replace(s)`", "Het **hele document** door `s` vervangen — één stap terug"],
                    ["`doc.log(s)`", "Een regel naar het resultatenpaneel schrijven"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Elke regel nummeren.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — de eerste drie CSV-kolommen houden",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Drie grenzen om te kennen"),
            .bullets([
                "**Geen toegang tot bestanden, geen netwerk, geen processen starten.** Het API-oppervlak is met opzet smal: het later verbreden is makkelijk, het versmallen breekt elk script dat gebruikers al schreven.",
                "**Dit is geen veiligheidsgrens.** Scripts draaien in hetzelfde proces. Voer geen script uit dat u niet hebt gelezen.",
                "**Er is een grens van vijf seconden.** Daarboven krijgt u een melding en blijft de toepassing bruikbaar — maar de draad van dat script **blijft doordraaien tot u afsluit**, en eet een kern op. De melding zegt dat.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filteren via een externe opdracht",
        summary: "De selectie door een Unix-opdracht leiden en het resultaat terugnemen.",
        keywords: ["filter", "externe opdracht", "shell", "pijp", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                De selectie (of het hele document) wordt aan de `stdin` van een opdracht gegeven, en de \
                `stdout` van die opdracht vervangt haar.
                """),
            .code(language: "bash", caption: "Een paar gebruikelijke",
                  source: """
                    sort -u                     # sorteren en dubbelen weghalen
                    jq .                        # JSON opnieuw opmaken
                    tr 'a-z' 'A-Z'              # naar hoofdletters
                    grep -v '^#'                # commentaarregels weghalen
                    awk -F, '{print $3","$1}'   # de volgorde van kolommen omwisselen
                    """),
            .note("""
                Het resultaat is **één** stap terug. Geeft de opdracht een foutcode terug, dan laat GEditor de \
                tekst met rust en toont hij `stderr`.
                """),
            .warning("""
                Deze opdracht bestaat **alleen in de uitgave met directe download**. De App Sandbox verbiedt \
                code buiten de toepassing uit te voeren, dus in de App Store-uitgave blijft het menu-item staan \
                en legt het uit waarom het niet beschikbaar is.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Het opdrachtregelgereedschap `geditor`",
        summary: "Openen, opschonen, bevragen, beoordelen en rapporten tonen — zonder de toepassing te openen.",
        keywords: ["cli", "opdrachtregel", "terminal", "geditor", "script", "ci"],
        blocks: [
            .warning("""
                Alleen beschikbaar in de uitgave met **directe download**. De App Store-uitgave draait in een \
                sandbox, dus een extern opdrachtregelproces kan er geen verbinding mee maken.
                """),
            .heading("Bestanden openen"),
            .code(language: "bash", caption: "Openen, naar een positie springen, uit een pijp lezen",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # regel 120, kolom 5
                    geditor -w notes.md            # wachten tot het bestand gesloten is voor het afsluiten
                    geditor -r app.log             # alleen-lezen openen
                    git diff | geditor             # de standaardinvoer in een nieuw tabblad lezen
                    """),
            .table(
                headers: ["Optie", "Betekenis"],
                rows: [
                    ["`-w`, `--wait`", "Wachten tot het bestand gesloten is voor het afsluiten — om als bewerker van `git` te dienen"],
                    ["`-n`, `--new-window`", "In een nieuw venster openen"],
                    ["`-r`, `--read-only`", "Alleen-lezen openen"],
                    ["`-i`, `--info`", "Codering, regelovergangen en aantal regels afdrukken, dan afsluiten — **zonder** de toepassing te openen"],
                    ["`-h`, `--help`", "De help tonen"],
                    ["`-v`, `--version`", "De versie tonen"],
                ]
            ),
            .heading("Draaien zonder de toepassing te openen"),
            .paragraph("""
                De vier groepen opdrachten hieronder draaien **volledig in het opdrachtregelproces**, dus ze \
                werken in CI, waar niemand op een grafische sessie is aangemeld.
                """),
            .code(language: "bash", caption: "Opschonen met een recept",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Bevragen",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "De kwaliteitspoort — code 0 geslaagd · 1 gezakt · 2 fout",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Rapporten tonen",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript en het menu Diensten",
        summary: "Het document vanuit AppleScript lezen en schrijven, of tekst vanuit een ander programma naar GEditor sturen.",
        keywords: ["applescript", "osascript", "diensten", "automatisering", "opdrachten"],
        blocks: [
            .code(language: "applescript", caption: "Het geopende document lezen",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "De inhoud overschrijven en de selectie lezen",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Een bestand openen",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Het menu Diensten"),
            .paragraph("""
                Selecteer tekst in eender welk programma en gebruik het menu `Diensten` om die als nieuw \
                tabblad naar GEditor te sturen.
                """),
            .note("""
                De eerste keer dat u AppleScript uitvoert, vraagt macOS om toestemming voor automatisering. Dat \
                is het venster van het systeem, niet van GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Uitbreidingspakketten en plug-ins",
        summary: "Twee soorten uitbreidingen, en in welke uitgave elk draait.",
        keywords: ["plug-in", "uitbreiding", "pakket", "inheems"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Uitbreidingspakketten"),
            .paragraph("""
                Een pakket is **één JSON-bestand** dat een thema, scripts en zelfgedefinieerde talen bundelt. \
                Installeren kopieert één bestand, verwijderen wist er een — en de pakketlijst wordt van de \
                **schijf** afgeleid, niet uit een register dat zou kunnen liegen.
                """),
            .paragraph("Werkt in **beide uitgaven**."),
            .heading("Inheemse plug-ins"),
            .paragraph("""
                Voorgecompileerde plug-ins draaien in een **apart proces** met een smal API-oppervlak — een \
                plug-in die vastloopt sleept de toepassing niet mee.
                """),
            .warning("""
                Inheemse plug-ins bestaan **alleen in de uitgave met directe download**, omdat de App Sandbox \
                verbiedt code van buiten de toepassing te laden. Elke plug-in moet **één keer met de hand \
                goedgekeurd** worden, op zijn hash, voordat hij draait.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Instellingen en de toepassing

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Instellingen en de toepassing",
        summary: "Instellingen, sneltoetsen, thema's, bijwerken, overstappen van Notepad++, problemen oplossen.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Instellingen",
        summary: "Elke keuze woont in één leesbaar JSON-bestand dat u naar een andere Mac kunt kopiëren.",
        keywords: ["instellingen", "voorkeuren", "opties", "configuratie", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "De instellingen openen")]),
            .paragraph("""
                Er is geen OK en geen Annuleer — een wijziging heeft effect en wordt meteen weggeschreven, op \
                de manier van macOS.
                """),
            .heading("Het configuratiebestand"),
            .code(language: "text", caption: "Waar het woont",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Het is een **ingesprongen JSON-bestand dat u kunt lezen en met de hand bewerken**. Kopieer het \
                naar een andere Mac en uw hele configuratie gaat mee. De knop `Configuratiebestand openen` in \
                de instellingen brengt u er rechtstreeks heen.
                """),
            .heading("De sleutels"),
            .table(
                headers: ["Sleutel", "Standaard", "Betekenis"],
                rows: [
                    ["`fontSize`", "`13`", "Tekengrootte van de bewerker"],
                    ["`tabWidth`", "`4`", "Hoeveel kolommen breed een tab is"],
                    ["`usesTabsForIndent`", "`false`", "Inspringen met tabs in plaats van spaties"],
                    ["`languageIndent`", "`{}`", "Inspringing per taal — zie de pagina over witruimte"],
                    ["`smartIndent`", "`true`", "Automatisch inspringen op een nieuwe regel"],
                    ["`highlightAllMatches`", "`true`", "Elke zoektreffer oplichten"],
                    ["`ligatures`", "`false`", "Ligaturen — zie de opmerking onder de tabel"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Witruimte aan het regeleinde afknippen bij bewaren"],
                    ["`normalizeToNFCOnSave`", "`false`", "Unicode bij bewaren naar NFC normaliseren"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Codering voor nieuwe bestanden"],
                    ["`defaultEOL`", "`\"lf\"`", "Regelovergangen voor nieuwe bestanden"],
                    ["`language`", "`\"system\"`", "Taal van de bediening"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "het standaardthema", "Welk kleurthema in gebruik is"],
                    ["`showWelcomeOnLaunch`", "`true`", "Het welkomstvenster bij het starten openen"],
                    ["`keyBindings`", "`{}`", "Alleen de toetsen die u hebt gewijzigd"],
                ]
            ),
            .note("""
                **Waarom ligaturen standaard UIT staan.** Een ligatuur smelt `!=` of `->` tot **één** teken, \
                zodat de tekens die u op het scherm ziet niet meer overeenkomen met die in het bestand — en de \
                kolombewerker, de kolommodus en het afbreken op een kolom meten allemaal in kolommen. Zet ze \
                aan om lopende tekst te schrijven, of als u juist om de ligaturen een programmeerlettertype \
                (Fira Code, JetBrains Mono) hebt gekozen.
                """),
            .heading("De buurmappen"),
            .table(
                headers: ["Map", "Bevat"],
                rows: [
                    ["`macros/`", "Bewaarde macro's, elk één JSON-bestand"],
                    ["`scripts/`", "JavaScript-scripts"],
                    ["`themes/`", "Kleurthema's"],
                    ["`grammars/`", "Zelfgedefinieerde talen"],
                ]
            ),
            .warning("""
                Een configuratiebestand dat door een **nieuwere** GEditor is geschreven wordt **niet \
                overschreven** door een oudere — die draait op standaardwaarden en zegt dat. Overschrijven is \
                de zekerste manier om de configuratie te vernielen van iemand die twee machines gelijk houdt, \
                en die zou nooit weten waarom.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "De statusbalk",
        summary: "Tien segmenten onderaan — allemaal leesbaar, en allemaal aanklikbaar.",
        keywords: ["statusbalk", "positie", "codering", "alleen-lezen", "grootte"],
        blocks: [
            .paragraph("""
                Dit is het grootste verschil met de statusbalken van andere bewerkers: **geen enkel segment is \
                alleen-lezen**. Ziet u een verkeerde waarde, dan is erop klikken de manier om die te \
                herstellen, in plaats van door menu's te zoeken.
                """),
            .table(
                headers: ["Segment", "Vertelt u", "Bij het aanklikken"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "cursorpositie — kolom in TEKENS, `@340` de bytepositie",
                     "opent het veld `Ga naar`"],
                    ["`11 byte · 3 dòng`", "grootte van het document",
                     "telt bytes · tekens · woorden · regels"],
                    ["`🔒 Chỉ đọc`", "alleen getoond wanneer het document vergrendeld is",
                     "zegt WAAROM het vergrendeld is, en ontgrendelt waar dat kan"],
                    ["`View` / `Code`", "in welke weergave u bent", "wisselt (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "CSV-modus en het gebruikte scheidingsteken",
                     "schakelt de CSV-modus, of **kiest het scheidingsteken opnieuw**"],
                    ["`Đang theo dõi`", "`tail -f` loopt", "—"],
                    ["`UTF-8`", "de codering", "opnieuw uitleggen, of naar een andere codering omzetten"],
                    ["`LF`", "stijl van regelovergang", "LF · CRLF · CR omschakelen"],
                    ["`Python`", "taal van de syntaxiskleuring", "een andere kiezen, of terug naar herkenning op extensie"],
                    ["`Tab: 4`", "breedte van de inspringing", "2 · 4 · 8, globaal of **alleen voor deze taal**"],
                    ["`Ngắt: tắt`", "modus van regelafbreking", "loopt door de drie modi"],
                ]
            ),
            .heading("Drie segmenten die een tweede blik verdienen"),
            .bullets([
                "**`@340` — de bytepositie.** Dat is het getal dat elk ander stuk gereedschap in het product spreekt: JSON- en XML-fouten, de uitvoer van `--doc-sweep`, de binaire weergave en het veld `Ga naar @340`. Lees het hier, typ het daar.",
                "**Een `~` bij de kolom** betekent dat het getal BYTES telt en geen visuele kolommen — dat gebeurt alleen bij regels langer dan 200 KB, waar tekens tellen elke cursorbeweging zou vertragen.",
                "**`CSV · …` is aan te klikken om het scheidingsteken opnieuw te kiezen.** De herkenning kan fout zitten, en dan is elke kolombewerking scheef zonder dat iets het aangeeft. Zo zegt u het tegendeel — het LEEST het bestand alleen opnieuw, zonder een byte te veranderen (anders dan `CSV ▸ Scheidingsteken wijzigen…`, dat het herschrijft).",
            ]),
            .note("""
                Een segment dat niet op het geopende bestand slaat is **verborgen**, niet grijs: `Alleen-lezen` \
                verschijnt alleen wanneer het document echt vergrendeld is, en `CSV · …` alleen in CSV-modus.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Sneltoetsen wijzigen",
        summary: "Losse toetsen wijzigen, of in één keer de indeling van Notepad++ overnemen.",
        keywords: ["sneltoets", "toetsenindeling", "voorinstelling"],
        blocks: [
            .paragraph("""
                `Instellingen…` heeft een deel Sneltoetsen met twee snelle knoppen: **De Notepad++-voorinstelling \
                gebruiken** en **Terug naar de standaardwaarden**.
                """),
            .paragraph("""
                Het configuratiebestand legt alleen vast wat u **ten opzichte van de standaardwaarden hebt \
                gewijzigd**. Zo blijft u niet aan de oude indeling vastzitten zonder dat iemand het u vertelt \
                wanneer GEditor in een nieuwe versie een standaardtoets wijzigt.
                """),
            .note("""
                Twee opdrachten mogen geen sneltoets delen. Doen ze dat toch, dan activeert AppKit stilletjes \
                alleen het **eerste** menu-item en lijkt de andere opdracht kapot — daarom heeft GEditor een \
                controle die dat verhindert.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Thema's, licht en donker",
        summary: "Het systeem volgen, licht of donker; en een thema is een JSON-bestand dat u kunt bewerken.",
        keywords: ["thema", "kleuren", "donkere modus", "licht", "uiterlijk"],
        blocks: [
            .paragraph("`Instellingen…` kiest `Systeem volgen`, `Licht` of `Donker`, en selecteert een kleurthema."),
            .paragraph("""
                Een thema is een JSON-bestand in `themes/`. De knop `Huidig thema uitvoeren` schrijft er een uit \
                als beginpunt voor het uwe.
                """),
            .note("""
                Een verkeerd getypte kleur in een themabestand valt terug op de kleur van het **standaardthema**, \
                niet op zwart. Zwart ziet eruit als een ontwerpkeuze, en de gebruiker zou het probleem ergens \
                anders gaan zoeken.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Bijwerken, versies en afsluiten",
        summary: "Waarin het bijwerken tussen de twee uitgaven verschilt.",
        keywords: ["bijwerken", "versie", "over", "afsluiten"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Uitgave", "Werkt bij via"],
                rows: [
                    ["App Store", "De App Store, zoals elk ander programma"],
                    ["Directe download", "`Zoeken naar updates…` in de toepassing"],
                ]
            ),
            .paragraph("""
                `Over GEditor` toont de draaiende versie en om welke uitgave het gaat — nuttig bij het melden \
                van een probleem.
                """),
            .note("""
                In de App Store-uitgave **blijft `Zoeken naar updates…` in het menu** en legt het uit waarom het \
                niet van toepassing is, in plaats van te verdwijnen. Een ontbrekend menu-item wordt een vraag aan \
                de ondersteuning.
                """),
            .paragraph("Afsluiten kost geen werk: de sessie komt terug wanneer u de volgende keer opent."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Dit helpvenster gebruiken",
        summary: "In het boek zoeken, de taal ervan wisselen en het welkomstvenster terughalen.",
        keywords: ["help", "handleiding", "zoeken", "welkom", "taal"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Het helpvenster openen")]),
            .bullets([
                "Het zoekveld linksboven kijkt in de **lopende tekst en de codevoorbeelden** — een kale configuratiesleutel als `fail_under` typen brengt u op de juiste pagina.",
                "**Zonder accenten** typen vindt toch tekst mét accenten.",
                "De knop `Terug` gaat naar de vorige pagina.",
                "De knop `Kopieer` bij elk codeblok kopieert dat blok.",
            ]),
            .heading("In een andere taal lezen"),
            .paragraph("""
                Het menu rechtsboven in dit venster kiest de **taal van het boek**, los van de taal van de \
                bediening. Het wisselen houdt u **op de pagina die u leest** — de paginanummers worden met opzet \
                niet vertaald, juist opdat dit werkt.
                """),
            .note("""
                Alleen talen die werkelijk een boek hebben worden opgesomd. Een menu-item dat naar iets \
                overschakelt en de tekst onveranderd laat, zou een menu-item zijn dat liegt.
                """),
            .heading("Het welkomstvenster terughalen"),
            .paragraph("""
                Hebt u **Dit venster niet openen bij het starten** aangevinkt, open het dan weer met `Help ▸ \
                Rondleiding langs de functies` — het vakje onderaan het venster verschijnt weer en kan worden \
                uitgevinkt.
                """),
            .paragraph("Of zet `showWelcomeOnLaunch` in `settings.json` weer op `true`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Van Notepad++ naar GEditor",
        summary: "Welke toetsen van plaats wisselen, wat anders werkt, en wat ontbreekt.",
        keywords: ["notepad++", "overstap", "windows", "sneltoetsen"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Enkele toetsen **wisselen van plaats** op macOS in plaats van alleen `Ctrl` in `⌘` te \
                veranderen. Hier is de vergelijking.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Waarom"],
                rows: [
                    ["`Ctrl+D` Regel dupliceren", "**⇧⌘D**", "Hier is `⌘D` de multicursor, zoals in elke Mac-bewerker"],
                    ["`Ctrl+L` Regel wissen", "**⌘K**", "Op macOS betekent `⌘L` «ga naar regel»"],
                    ["`Ctrl+G` Ga naar regel", "**⌘L**", "Deze twee wisselen van plaats"],
                    ["`Ctrl+Q` Becommentariëren", "**⌘/**", "Afspraak van macOS"],
                    ["`Ctrl+Shift+↑/↓` Regel verplaatsen", "**⌥↑ / ⌥↓**", "Op macOS hoort `⌃` bij Mission Control"],
                    ["`F3` Volgende zoeken", "**⌘G**", "Afspraak van macOS"],
                    ["`Ctrl+F2` Bladwijzer aan/uit", "**⌘F2**", "F2 en ⇧F2 springen nog steeds tussen markeringen"],
                    ["`Alt` + slepen voor kolommen", "**⌥ + slepen**", "Gelijk"],
                    ["`Ctrl+Alt+Shift+↓` Kolombewerker", "**⌥⌘C**", "Afspraak van macOS"],
                ]
            ),
            .note("Liever niet opnieuw leren? `Instellingen ▸ Sneltoetsen ▸ De Notepad++-voorinstelling gebruiken`."),
            .heading("Dingen die Notepad++ heeft en die hier anders werken"),
            .bullets([
                "**Sessies** herstellen zichzelf, inclusief niet-bewaarde tabbladen — niets aan te zetten.",
                "**Bladwijzers hebben negen kleuren**, en één regel kan er meerdere tegelijk dragen.",
                "**De documentkaart** beschrijft het *hele* bestand, niet alleen het zichtbare deel.",
                "**Macro's** kunnen «tot het einde van het document» en «over alle tabbladen» draaien, en een hele ronde is één stap terug.",
            ]),
            .heading("Wat GEditor toevoegt"),
            .bullets([
                "Een **opschoonbank voor gegevens** en **gegevensprofielen** voor CSV-bestanden.",
                "**SQL-bevragingen** rechtstreeks op een CSV-bestand.",
                "**Oude Vietnamese coderingen** — TCVN3, VISCII, VNI-Windows, gelezen, geschreven en automatisch herkend.",
                "**Zoeken ongevoelig voor accenten** in elk filterveld.",
                "**`.greport.md`-rapporten** met tabellen en grafieken die herrekend worden.",
                "Het **opdrachtregelgereedschap `geditor`** in de uitgave met directe download.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Veelvoorkomende problemen",
        summary: "Zes situaties waardoor men denkt dat de toepassing kapot is.",
        keywords: ["fout", "probleem", "werkt niet", "oplossen", "waarom"],
        blocks: [
            .table(
                headers: ["Verschijnsel", "Gebruikelijke oorzaak"],
                rows: [
                    ["Vietnamese tekst verschijnt als brij", "Verkeerde codering — klik op de codering in de statusbalk"],
                    ["Zoeken naar tekst mét accenten vindt niets", "Het bestand is in ontleed Unicode — voer `Unicode normaliseren` naar NFC uit"],
                    ["Een menu-item is grijs", "De App Store-uitgave kan die opdracht niet uitvoeren — het item legt uit waarom"],
                    ["Het koppelen van haakjes weigert", "Het document is groter dan 1 MB — het verkeerde paar oplichten is erger dan geen"],
                    ["De kolom in de statusbalk heeft een `~`", "Het document is groter dan 200 KB, dus dat is een aantal bytes en geen visuele kolom"],
                    ["Een SQL-bevraging zegt dat er eerst bewaard moet worden", "DuckDB leest **bestanden**, niet de buffer die u bewerkt"],
                ]
            ),
            .heading("Wanneer GEditor onverwacht afsluit"),
            .paragraph("""
                Bij de volgende start zegt een banier dat, met een knop **Verslag openen** — het verslag gaat \
                open als tabblad dat u kunt lezen en waaruit u kunt kopiëren als uit elk ander tekstbestand.
                """),
            .bullets([
                "Het verslag draagt alleen de **versie, de macOS-uitgave, de bouw van de machine, de naam van het signaal en de aanroepstapel**.",
                "**Geen inhoud van het document, en ook geen bestandspaden** — een pad als `~/Bureaublad/salarissen-december.xlsx` heeft al drie privézaken verraden voordat iemand het opent.",
                "**Er wordt niets nergens heen gestuurd.** Er is geen automatisch uploaden en geen server die het ontvangt; het bestand blijft in `~/Library/Application Support/GEditor/crash/` tot u het opent of wist.",
                "Hebt u het verslag eenmaal geopend, dan noemt de volgende start het niet meer.",
            ]),
            .heading("Waar u vervolgens kunt kijken"),
            .bullets([
                "De statusbalk toont codering, regelovergangen, taal en afbreekmodus — elk segment is aanklikbaar.",
                "`settings.json` is met de hand te bewerken wanneer het instellingenvenster niet volstaat.",
                "`Over GEditor` geeft de versie en de uitgave, die een foutmelding nodig heeft.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
