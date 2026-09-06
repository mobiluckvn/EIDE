import Foundation

/// Dansk hjælpeindhold — del 5: rapporter, viden, automatisering og programmet.
extension HelpDA {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Rapporter og diagrammer",
        summary: "En tekstfil, der giver en HTML-rapport, hvis tal genberegnes, plus Mermaid-diagrammer.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md`-rapporter",
        summary: "Markdown plus fire slags kørbare blokke — skriv til venstre, se resultatet til højre.",
        keywords: ["rapport", "greport", "html", "eksport", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                En `.greport.md`-fil er **almindelig Markdown** plus nogle få kørbare indhegnede \
                blokke. At tegne den giver en **selvbærende** HTML-fil — intet net, ingen følgefiler — \
                som hvem som helst kan åbne.
                """),
            .paragraph("""
                Fordi det er ren tekst, kan den **sammenlignes, versionsstyres og deles** — samme tanke \
                som med renseopskrifter og kvalitetsregelsæt.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — en fuldstændig rapport",
                  source: """
                    ---
                    title: Salgsrapport for august
                    source: sales-2026-08.csv
                    ---

                    # Salgsrapport for august

                    Tal pr. 31. august 2026.

                    ## Omsætning pr. provins

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Omsætning pr. provins
                    y_label: Omsætning
                    number_format: vi
                    suffix: " ₫"
                    source: Kilde — sales-2026-08.csv
                    ```

                    ## Kildedataenes kvalitet

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Blokkenes slags"),
            .table(
                headers: ["Blok", "Giver"],
                rows: [
                    ["`query`", "En tabel, ud fra en SQL-sætning til DuckDB"],
                    ["`chart`", "Et diagram"],
                    ["`quality`", "Et kvalitetskort for data"],
                    ["`mining`", "En rangordningstabel fra gravning pr. gruppe"],
                    ["`mermaid`", "Et diagram"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                `---`-blokken øverst erklærer `title` og `source` — standarddatakilden for hver blok, \
                der ikke nævner sin egen.
                """),
            .note("""
                Forhåndsvisningen bygges om, når du holder op med at skrive, men den **fortolker kun**; \
                den kører ikke forespørgsler ved hvert tastetryk. Dokumentfejl og datafejl meldes hver \
                for sig — *»chart-blokken mangler nøglen `kind`«* er en filfejl, *»kolonnen \
                `doanh_thu` findes ikke«* er en datafejl.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "`query`-blokken",
        summary: "Én DuckDB-sætning bliver til én tabel i rapporten.",
        keywords: ["forespørgsel", "sql", "tabel", "rapport", "blok"],
        blocks: [
            .paragraph("""
                Blokkens indhold er **én SQL-sætning**, kørt mod rapportens kilde. Tabellen hedder `t`, \
                i samme dialekt som i forespørgselspanelet.
                """),
            .code(language: "text", caption: "En query-blok med parameter",
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
                `:thang` er en **parameter**. Den gives ved tegningen — fra skallen med \
                `--param thang=8`, eller fra en listefil, når rapporter laves i sats.
                """),
            .note("""
                Tabeller i en datarapport **bør komme fra en query-blok**, ikke skrives i hånden. En \
                håndskrevet tabel genberegnes ikke, når tallene ændrer sig, og før eller siden er den \
                uenig med resten af rapporten.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "`chart`-blokken",
        summary: "En YAML-opsætning bliver til et diagram — og formatets vigtigste regel.",
        keywords: ["diagram", "yaml", "rapport", "tegn"],
        blocks: [
            .code(language: "yaml", caption: "Hver nøgle i en chart-blok",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Omsætning pr. provins
                    x_label: Provins
                    y_label: Omsætning
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Kilde — sales.csv, pr. 26. august 2026
                    """),
            .heading("Uden `query` bruger den resultatet af query-blokken LIGE OVENOVER"),
            .paragraph("""
                Dette er formatets vigtigste regel. Takket være den gentager den almindelige rapport \
                »en tabel og så et diagram over den tabel« ikke sin SQL — og at gentage den betyder, at \
                de to kopier til sidst driver fra hinanden, og så siger tabellen og diagrammet \
                forskellige ting på samme side.
                """),
            .warning("""
                Til gengæld **betyder blokkenes rækkefølge noget**: at skyde en query-blok ind imellem \
                ændrer dataene for diagrammet nedenunder.
                """),
            .heading("Hvorfor `source` er sin egen nøgle"),
            .paragraph("""
                En kildeangivelse skrevet som brødtekst under diagrammet vises udmærket — på skærmen. \
                Men diagrammet skal eksporteres som PNG og indsættes andetsteds, og brødteksten bliver \
                tilbage. Som nøgle tegnes den **inde i billedet** og følger med det.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "`quality`-blokken",
        summary: "Et kvalitetskort for data inde i rapporten.",
        keywords: ["kvalitet", "kort", "rapport", "blok"],
        blocks: [
            .code(language: "yaml", caption: "Hver nøgle i en quality-blok",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # tomt betyder rapportens egen kilde
                    title: Kvaliteten af augusts salgsdata
                    rules: true                 # vis tabellen regel for regel, bestået/ikke bestået
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # fastsæt referencedatoen for "Aktualitet"
                    fail_under: 90              # under dette skifter kortet til advarselsfarve
                    """),
            .table(
                headers: ["`chart`", "Tegner"],
                rows: [
                    ["`violations`", "Rækkeantal for de regler, der **ikke bestod** — besvarer »hvad skal rettes først«"],
                    ["`dimensions`", "Karaktererne for de seks dimensioner"],
                    ["`none`", "Kun tabel, intet diagram"],
                ]
            ),
            .note("""
                Sæt `now:` i en tilbagevendende rapport. Uden den sammenligner *Aktualitet* med \
                tegningens øjeblik, så at tegne sidste måneds rapport igen giver en anden karakter end \
                den, du udgav.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "`mining`-blokken",
        summary: "Rangordn grupper efter afvigelser, prognosefejl eller samvariationsafvigelse.",
        keywords: ["gravning", "rapport", "grupperangordning"],
        blocks: [
            .code(language: "yaml", caption: "Hver nøgle i en mining-blok",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # kolonnen til afvigelser og prognose
                    pair: chi_phi             # en anden kolonne, til samvariation pr. gruppe
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # tomt betyder rapportens egen kilde
                    title: Gravning pr. provins
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Rangordner efter"],
                rows: [
                    ["`anomalies`", "Den gruppe, der har flest afvigende rækker"],
                    ["`forecast_error`", "Den gruppe, hvis prognose er dårligst"],
                    ["`correlation_gap`", "Den gruppe, hvis samvariation afviger mest fra den samlede tabel — fanger Simpsons paradoks"],
                ]
            ),
            .warning("""
                **Ingen nøgle slår »Metode«-blokken fra.** En grupperangordning uden sin metode giver \
                læseren ingen mulighed for at vide, mod hvilket hegn »flest afvigelser« blev målt. Den, \
                der vil have den skjult, kender allerede det svar, han ønsker.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "At lave rapporter i sats",
        summary: "Én skabelon, én parameterliste, mange rapporter.",
        keywords: ["sats", "mange", "parametre", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Én rapportskabelon, kørt for hver afdeling eller hver måned. Parameterlisten er en CSV- \
                eller JSON-fil — **én række pr. rapport**.
                """),
            .code(language: "text", caption: "list.csv — én række pr. rapport",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Tegn hele satsen fra skallen",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Eller én rapport med parametre givet i hånden",
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
        title: "Mermaid-diagrammer",
        summary: "Tegn diagrammer i tekst, ændr dem med kommandoer, se dem i takt begge veje.",
        keywords: ["mermaid", "diagram", "rutediagram", "sekvens", "tegn"],
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
                Mermaid tegner diagrammer **ud fra tekst**: du skriver en beskrivelse, og maskinen \
                tegner den. Et diagram kan derfor sammenlignes og versionsstyres — hvilket en billedfil \
                ikke kan.
                """),
            .paragraph("""
                Åbn `Mermaid-diagram: forhåndsvisning` for en visning ved siden af editoren. De to går \
                **i takt begge veje**: markér et element i billedet, og markøren springer til dets \
                linje.
                """),
            .heading("Ret med kommandoer, ikke ved at skrive om"),
            .table(
                headers: ["Kommando", "Hvad den gør"],
                rows: [
                    ["Indsæt en skabelon…", "Indsæt et færdigt skelet for hver diagramtype"],
                    ["Tilføj et element…", "Tilføj en knude eller en deltager"],
                    ["Forbind de to markerede elementer", "Tegn en pil mellem dem"],
                    ["Ret det markerede elements mærkat…", "Ændr teksten uden at lede efter linjen"],
                    ["Slet det markerede element", "Fjern knuden **og** hver kant, der rører den"],
                    ["Flyt beskeden op / ned", "Omordn trinene i et sekvensdiagram"],
                    ["Omformatér", "Indryk og ret hele blokken op"],
                ]
            ),
            .heading("At skille ud i en fil og lægge ind igen"),
            .paragraph("""
                Store diagrammer hører hjemme i deres egen `.mmd`-fil: `Skil blokken ud i en .mmd-fil…` \
                flytter den ud og efterlader en henvisning. `Læg den henviste fil ind igen` gør det \
                omvendte, når du skal sende én enkelt fil.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Almindelig Mermaid-syntaks",
        summary: "De fire mest brugte diagramtyper, hver med en skabelon der virker.",
        keywords: ["mermaid", "syntaks", "rutediagram", "sekvens", "gantt", "klasse", "skabelon"],
        blocks: [
            .code(language: "mermaid", caption: "Rutediagram — et godkendelsesforløb for ordrer",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Sekvensdiagram — et betalingsforløb",
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
            .code(language: "mermaid", caption: "Klassediagram — en datamodel",
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
            .code(language: "mermaid", caption: "Gantt — en udgivelsesplan",
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
                headers: ["Knudeform", "Skriv"],
                rows: [
                    ["Rektangel", "`A[Label]`"],
                    ["Afrundet", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Rombe (beslutning)", "`A{Label}`"],
                    ["Cylinder (data)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Pil", "Skriv"],
                rows: [
                    ["Fuldt optrukket, med spids", "`A --> B`"],
                    ["Prikket", "`A -.-> B`"],
                    ["Tyk", "`A ==> B`"],
                    ["Med mærkat", "`A -- label --> B`"],
                ]
            ),
            .note("""
                Et rutediagrams retning står lige efter `flowchart`: `TD` oppefra og ned, `LR` fra \
                venstre mod højre, samt `BT` og `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Videnspakken

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Videnspakken",
        summary: "Opdeling i stykker, søgeindeks, vidensgrafer, enheder og bedømmelse af genfinding.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Hvad videnspakken er",
        summary: "Værktøjer til at forberede og prøve data til et system, der svarer på spørgsmål ud fra dokumenter.",
        keywords: ["rag", "viden", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Når man bygger et system, der besvarer spørgsmål ud fra en dokumentsamling, ligger det \
                meste af arbejdet ikke i modellen, men i at **forberede dataene**: at klippe \
                dokumenterne i fornuftige stykker, prøve de stykkers kvalitet, bygge et indeks og \
                **måle, om genfindingen virkelig finder det rigtige**.
                """),
            .paragraph("""
                Dette kapitel er netop værktøjerne til det. Det kører **helt på din egen maskine** og \
                rører aldrig nettet.
                """),
            .table(
                headers: ["Opgave", "Værktøj"],
                rows: [
                    ["At klippe dokumenter i stykker", "Forhåndsvisning af opdeling"],
                    ["At gennemse og bedømme stykker", "Gennemsyn af JSONL-stykker"],
                    ["At omsætte mellem dataformer", "Vidensomsætning"],
                    ["At bygge og gennemse en relationsgraf", "Vidensgraf"],
                    ["At finde egennavne i tekst", "Enhedsmærkning"],
                    ["At måle genfindingens kvalitet", "Genfindingslaboratoriet"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "At opdele og gennemse en JSONL-samling",
        summary: "Se stykkegrænserne på selve teksten, og bedøm så hele samlingen.",
        keywords: ["chunk", "jsonl", "samling", "overlap", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Forhåndsvisning af opdeling"),
            .paragraph("""
                Åbn et tekst- eller Markdown-dokument, vælg en fremgangsmåde og en stykkestørrelse. \
                Grænserne **fremhæves på selve teksten**, så du kan se, hvor et snit falder midt i en \
                sætning eller gennem en tabel, før du eksporterer noget.
                """),
            .bullets([
                "**Fast størrelse** med overlap.",
                "**Efter opbygning** — ved Markdown-overskrifter, med dokumentets tråd i behold.",
                "**Efter afsnit**, sammenlagt indtil størrelsen nås.",
            ]),
            .heading("At gennemse en eksisterende JSONL-samling"),
            .paragraph("""
                For en samling, du allerede har (ét JSON-stykke pr. linje), svarer `JSONL: gennemse \
                stykker…`: hvilke linjer der ikke er gyldig JSON, hvilke stykker der er for korte eller \
                for lange, hvilke der er dubletter af hinanden, og hvilke der er klippet midt i en \
                sætning.
                """),
            .note("""
                En samling kan også bedømmes med **samme ramme med seks dimensioner** som tabeldata — \
                brug nøglen `corpus:` i en rapports `quality`-blok.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "At omsætte vidensformater",
        summary: "Stykker mellem JSONL · CSV · Markdown, grafer mellem DOT · Mermaid · kantlister.",
        keywords: ["omsæt", "jsonl", "dot", "mermaid", "kantliste"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Fra", "Til"],
                rows: [
                    ["JSONL-stykker", "CSV · Markdown"],
                    ["CSV-stykker", "JSONL · Markdown"],
                    ["DOT-graf", "Mermaid · kantliste"],
                    ["Kantliste", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Der er en **forhåndsvisning af fem rækker**, før det nye faneblad laves, samme \
                mekanisme som ved CSV-omsætningen.
                """),
            .paragraph("""
                `Åbn tripler/kanter som tabel` viser en tripelfil eller en kantliste som tabel — \
                filtrér og sortér som i enhver anden CSV.
                """),
            .note("""
                Retningen **Markdown → JSONL** findes ikke i denne kommando: den retning *er* \
                opdelingen, og kommandoen henviser dig derhen. To udførelser af ét og samme snit ville \
                give to forskellige resultater.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Vidensgrafer",
        summary: "Kontrollér syntaksen, bedøm helbredet, og kør algoritmer på grafer med en million kanter.",
        keywords: ["graf", "dot", "cypher", "pagerank", "louvain", "syntakskontrol"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor læser grafer som **DOT**, som **kantlister** og som **tripler**. `Kontrollér \
                grafsyntaks` fanger syntaksfejl, løse knuder og kanter, der peger på knuder, som ikke \
                findes.
                """),
            .heading("Tilgængelige algoritmer"),
            .table(
                headers: ["Algoritme", "Besvarer"],
                rows: [
                    ["Naboskab i k skridt", "Hvad der hænger sammen med denne knude inden for k skridt"],
                    ["Sammenhængende dele", "Hvor mange adskilte stykker grafen består af"],
                    ["PageRank", "Hvilke knuder der er vigtige"],
                    ["Louvain", "Hvordan grafen deler sig i fællesskaber"],
                ]
            ),
            .paragraph("""
                På en graf med **en million kanter** kører alle fire på mellem nogle få millisekunder \
                og omkring et sekund.
                """),
            .note("""
                En graf kan også bedømmes med **rammen med seks dimensioner**, der bruges til tabeller \
                og samlinger — brug nøglen `graph:` i en `quality`-blok.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "At mærke enheder ud fra en liste",
        summary: "Indlæs en liste over egennavne, og find hver forekomst — under tre regler lavet til vietnamesisk.",
        keywords: ["enhed", "egennavn", "ner", "mærkning", "matchning"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Indlæs en liste over navne (firmaer, varer, steder), og GEditor fremhæver hver \
                forekomst i dokumentet med en tabel over antallene.
                """),
            .heading("Tre matchningsregler, alle fra vietnamesiske data"),
            .bullets([
                "**Længste træf vinder.** Med både `An Phát` og `Công ty An Phát` på listen skal en sætning, der indeholder det længere udtryk, matche det længere — ellers deles den i to og tælles som to enheder, hvilket **oppuster** statistikken.",
                "**Ordgrænser er nødvendige.** `An` må ikke matche inde i `Anh` eller `Hoàn`. Vietnamesiske egennavne er korte og deler stavelser med utallige almindelige ord.",
                "**Ufølsom over for store/små bogstaver, men FØLSOM over for accenter.** `CÔNG TY` og `Công ty` er ét; `má` og `ma` er ikke.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "At løse enhedsvarianter op",
        summary: "Genkend `Cty An Phát` og `Công ty An Phát` som ét — men overlad stadig beslutningen til dig.",
        keywords: ["enhedsopløsning", "varianter", "navnenormalisering", "dubletter"],
        blocks: [
            .paragraph("""
                Samme klyngedannelse som **uklare dubletter** i en CSV-tabel — én fælles udførelse, \
                ikke to.
                """),
            .paragraph("""
                Uddataet er et **forslag**: du gennemgår hver klynge og vælger den gældende form. Der \
                er ingen »flet alle«-knap, for to navne, der ligner hinanden 92 %, kan være to virkelige \
                organisationer.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Genfindingslaboratoriet",
        summary: "Mål, om indekset finder det rigtige, ved hjælp af et sæt spørgsmål med svar.",
        keywords: ["genfinding", "bm25", "recall", "mrr", "ndcg", "bedømmelse"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Indlæs et **bedømmelsessæt** — hver linje et spørgsmål med numrene på de stykker, der \
                burde komme tilbage — og kør så hele satsen mod indekset.
                """),
            .table(
                headers: ["Mål", "Besvarer"],
                rows: [
                    ["recall@k", "Hvor meget af svarmængden der dukker op blandt de øverste k"],
                    ["MRR", "Hvor langt nede det første rigtige resultat ligger"],
                    ["nDCG@k", "Om rangordningen er god, med placeringen medregnet"],
                ]
            ),
            .paragraph("""
                Resultaterne kommer også **pr. spørgsmål**, de dårligste først — det er din liste over, \
                hvad der skal rettes i samlingen, i den rækkefølge der bedst kan betale sig.
                """),
            .warning("""
                Alle tre mål er **gennemsnit**, og et gennemsnit skjuler meget. Læs altid tabellen pr. \
                spørgsmål, før du slår fast, at »indekset er godt nok«.
                """),
            .paragraph("""
                To opsætninger kan sammenlignes side om side, og resultatet falder direkte ind i en \
                `.greport.md`-rapport, så næste kørsel bliver ens.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Makroer og automatisering

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Makroer og automatisering",
        summary: "Optag handlinger, kør dem i sats, skriv scripts, og styr det hele fra skallen.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "At optage og afspille makroer",
        summary: "Optag en rækkefølge, og gentag den — hele kørslen er ét fortrydelsestrin.",
        keywords: ["makro", "optag", "afspil", "gentag", "automatisér"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Begynd / stop optagelsen"),
                HelpShortcut("⌃P", "Afspil"),
            ]),
            .steps([
                "`⌃R` begynder optagelsen.",
                "Gør det, du vil have gentaget — skrive, flytte markøren, søge, erstatte.",
                "`⌃R` igen for at stoppe.",
                "`⌃P` afspiller det, eller `Makro ▸ Afspil til dokumentets slutning` kører det hele vejen.",
                "`Makro ▸ Gem makro…` giver den et navn til senere omgange.",
            ]),
            .heading("Den optager KOMMANDOER, ikke rå tastetryk"),
            .paragraph("""
                En makro gemmer **det, du gjorde**, ikke hvilke taster du trykkede på. Det gør den \
                uafhængig af tastaturopsætning og af, hvilken inddatametode der er slået til, og det \
                gør makrofilen **læsbar**, når du åbner den.
                """),
            .heading("Hvornår en makro standser"),
            .table(
                headers: ["Grund", "Betydning"],
                rows: [
                    ["Antallet af gentagelser slap op", "Normalt"],
                    ["Et `find`-skridt fandt intet", "Sådan standser »afspil til filens slutning« af sig selv"],
                    ["Dokumentets slutning nået", "Ingen steder længere at gå hen"],
                    ["Du afbrød", "`Makro ▸ Afbryd den kørende makro`"],
                    ["En omgang ændrede intet og flyttede intet", "Standset, så den ikke kan køre i ring for evigt"],
                ]
            ),
            .note("Hele kørslen — også ti tusind gentagelser — er **ét** fortrydelsestrin."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "At køre en makro i sats",
        summary: "På tværs af hvert åbent faneblad eller på tværs af en mappe med uåbnede filer.",
        keywords: ["sats", "alle faneblade", "mappe", "makro", "maske"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Kommando", "Omfang", "Kan fortrydes"],
                rows: [
                    ["Kør på alle faneblade", "De åbne faneblade", "Ja — ét fortrydelsestrin pr. faneblad"],
                    ["Kør på tværs af en mappe…", "Filer på disken, der **ikke er åbne**", "Nej"],
                ]
            ),
            .warning("""
                At køre på tværs af en mappe rører filer, der ikke er åbne i noget faneblad, så der er \
                **ingen fortrydelse**. Som standard **skriver GEditor nye filer** i stedet for at \
                overskrive originalerne. Behold den indstilling, medmindre du har en sikkerhedskopi \
                eller et versionsstyret arkiv.
                """),
            .heading("At filtrere filer med en maske"),
            .paragraph("""
                Mappevælgeren har et **filnavnsfilter**: skriv `*.csv;*.log`, og makroen rører kun dem. \
                Det er samme maskesyntaks, som `Søg i en hel mappe` bruger, med flere mønstre adskilt af \
                `;` eller `,`.
                """),
            .bullets([
                "Lad det være **tomt**, og den tager hver tekstfil, GEditor kan læse — den tidligere adfærd.",
                "Masken **erstatter** den liste af endelser frem for at indsnævre den yderligere: skriv `*.bak`, og den kører på `.bak`-filer, selv om den endelse ikke står på tekstlisten.",
                "Passer intet, **gentager beskeden din maske** frem for at give en tom mappe skylden.",
            ]),
            .paragraph("""
                Det felt har en meget praktisk grund: en mappe rummer 400 `.json`-filer og 12 \
                `.log`-filer, og din makro rydder kun op i logfiler. Uden maske bliver de andre 400 også \
                behandlet — og da satsen skriver nye filer, efterlader en fejl 400 stykker affald.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Makrofilens syntaks",
        summary: "Syv slags skridt, det fuldstændige JSON-format og to makroer, der virker.",
        keywords: ["makro", "json", "syntaks", "format", "ret i hånden", "del"],
        blocks: [
            .paragraph("""
                Hver makro er **sin egen JSON-fil** i GEditors mappe `macros/`. En skade bliver inden \
                for én makro, og at dele en med en kollega er at sende én fil.
                """),
            .code(language: "text", caption: "Hvor filerne bor",
                  source: "~/Library/Application Support/GEditor/macros/<makronavn>.json"),
            .heading("De syv slags skridt"),
            .table(
                headers: ["Skridt", "Skrives som", "Betydning"],
                rows: [
                    ["Indsæt tekst", "`{\"insert\": {\"_0\": \"text\"}}`", "Skriv ved markøren; med en markering erstatter det den"],
                    ["Slet baglæns", "`{\"deleteBackward\": {}}`", "Som slettetasten"],
                    ["Slet forlæns", "`{\"deleteForward\": {}}`", "Som ⌦"],
                    ["Flyt", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Se retningslisten nedenfor"],
                    ["Markér linjen", "`{\"selectLine\": {}}`", "Uden linjeskiftet"],
                    ["Søg", "`{\"find\": { … }}`", "Finder og **markerer** næste træf"],
                    ["Erstat markeringen", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` gælder, hvis forrige skridt var et `find` med regex"],
                ]
            ),
            .heading("Flytteretninger"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Det fuldstændige `find`-skridt"),
            .code(language: "json", caption: "De fire nøgler i et find-skridt",
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
            .paragraph("`mode` tager `normal`, `extended` eller `regex` — samme tre tilstande som søgefeltet."),
            .heading("Eksempel 1 — sæt provinskoden i linjens begyndelse med store bogstaver"),
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
                Kør den med `Makro ▸ Afspil til dokumentets slutning`: at `find`-skridtet ikke finder \
                mere er netop standsningsbetingelsen.
                """),
            .heading("Eksempel 2 — slet linjen efter hver linje, der indeholder TODO"),
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
                Prøv en håndrettet makro på en kopi først. Et fejlskrevet `find`-skridt får makroen til \
                at standse med det samme — det er det ufarlige tilfælde. Det farlige er et mønster, der \
                rammer bredere, end du troede, og ændrer tusindvis af steder inden for ét \
                fortrydelsestrin.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript-scripts",
        summary: "Fire funktioner, én `.js`-fil, og alt hvad den gør er ét fortrydelsestrin.",
        keywords: ["script", "javascript", "js", "automatisér", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Læg en `.js`-fil i GEditors mappe `scripts/`, og kør den fra `Makro ▸ Script…`. Et \
                script ser præcis **fire** ting:
                """),
            .table(
                headers: ["Kald", "Betydning"],
                rows: [
                    ["`doc.text`", "Hele dokumentets tekst"],
                    ["`doc.selection`", "Markeringen (tom streng, når intet er markeret)"],
                    ["`doc.replace(s)`", "Erstat **hele dokumentet** med `s` — ét fortrydelsestrin"],
                    ["`doc.log(s)`", "Skriv en linje i resultatpanelet"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Nummerér hver linje.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — behold de tre første CSV-kolonner",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Tre grænser at kende"),
            .bullets([
                "**Ingen filadgang, intet net, ingen processer at starte.** API-fladen er med vilje smal: at udvide den senere er let, at indsnævre den ødelægger hvert script, brugerne allerede har skrevet.",
                "**Dette er ikke en sikkerhedsgrænse.** Scripts kører i samme proces. Kør ikke et script, du ikke har læst.",
                "**Der er en grænse på fem sekunder.** Derover får du en besked, og programmet forbliver brugbart — men det scripts tråd **bliver ved med at snurre, indtil du slutter**, og æder en kerne. Beskeden siger det.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "At filtrere gennem en ydre kommando",
        summary: "Send markeringen gennem en Unix-kommando, og tag resultatet tilbage.",
        keywords: ["filter", "ydre kommando", "skal", "rør", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Markeringen (eller hele dokumentet) gives til en kommandos `stdin`, og den kommandos \
                `stdout` erstatter den.
                """),
            .code(language: "bash", caption: "Nogle almindelige",
                  source: """
                    sort -u                     # sortér og fjern dubletter
                    jq .                        # omformatér JSON
                    tr 'a-z' 'A-Z'              # til store bogstaver
                    grep -v '^#'                # fjern kommentarlinjer
                    awk -F, '{print $3","$1}'   # byt om på kolonnernes rækkefølge
                    """),
            .note("""
                Resultatet er **ét** fortrydelsestrin. Giver kommandoen en fejlkode, lader GEditor \
                teksten være og viser `stderr`.
                """),
            .warning("""
                Denne kommando findes **kun i udgaven med direkte hentning**. App Sandbox forbyder at \
                køre kode uden for programmet, så i App Store-udgaven bliver menupunktet stående og \
                forklarer, hvorfor det ikke er til rådighed.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Kommandolinjeværktøjet `geditor`",
        summary: "Åbn, rens, spørg, bedøm og tegn rapporter — uden at åbne programmet.",
        keywords: ["cli", "kommandolinje", "terminal", "geditor", "script", "ci"],
        blocks: [
            .warning("""
                Findes kun i udgaven med **direkte hentning**. App Store-udgaven kører i en sandkasse, \
                så en ydre kommandolinjeproces kan ikke forbinde til den.
                """),
            .heading("At åbne filer"),
            .code(language: "bash", caption: "Åbn, spring til en position, læs fra et rør",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # linje 120, kolonne 5
                    geditor -w notes.md            # vent til filen lukkes, før der afsluttes
                    geditor -r app.log             # åbn skrivebeskyttet
                    git diff | geditor             # læs standardinddata ind i et nyt faneblad
                    """),
            .table(
                headers: ["Tilvalg", "Betydning"],
                rows: [
                    ["`-w`, `--wait`", "Vent til filen lukkes, før der afsluttes — til at tjene som `git`s editor"],
                    ["`-n`, `--new-window`", "Åbn i et nyt vindue"],
                    ["`-r`, `--read-only`", "Åbn skrivebeskyttet"],
                    ["`-i`, `--info`", "Udskriv tegnkodning, linjeslutninger og linjeantal, og afslut — **uden** at åbne programmet"],
                    ["`-h`, `--help`", "Vis hjælpen"],
                    ["`-v`, `--version`", "Vis versionen"],
                ]
            ),
            .heading("At køre uden at åbne programmet"),
            .paragraph("""
                De fire kommandogrupper nedenfor kører **helt inde i kommandolinjeprocessen**, så de \
                virker i CI, hvor ingen er logget ind i en grafisk omgang.
                """),
            .code(language: "bash", caption: "At rense med en opskrift",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "At spørge",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Kvalitetsporten — kode 0 bestået · 1 ikke bestået · 2 fejl",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "At tegne rapporter",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript og menuen Tjenester",
        summary: "Læs og skriv dokumentet fra AppleScript, eller send tekst til GEditor fra et andet program.",
        keywords: ["applescript", "osascript", "tjenester", "automatisering", "genveje"],
        blocks: [
            .code(language: "applescript", caption: "Læs det åbne dokument",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Skriv indholdet over, og læs markeringen",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Åbn en fil",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Menuen Tjenester"),
            .paragraph("""
                Markér tekst i et hvilket som helst program, og brug så menuen `Tjenester` til at sende \
                den til GEditor som et nyt faneblad.
                """),
            .note("""
                Første gang du kører AppleScript, beder macOS om tilladelse til automatisering. Det er \
                systemets dialog, ikke GEditors.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Udvidelsespakker og plugins",
        summary: "To slags udvidelser, og hvilken udgave hver af dem kører i.",
        keywords: ["plugin", "udvidelse", "pakke", "indbygget"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Udvidelsespakker"),
            .paragraph("""
                En pakke er **én JSON-fil**, der samler et tema, scripts og selvdefinerede sprog. At \
                installere kopierer en fil, at fjerne sletter en — og pakkelisten udledes af **disken**, \
                ikke af et register, der kunne lyve.
                """),
            .paragraph("Virker i **begge udgaver**."),
            .heading("Indbyggede plugins"),
            .paragraph("""
                Forudoversatte plugins kører i en **egen proces** med en smal API-flade — et plugin, \
                der bryder sammen, trækker ikke programmet med sig.
                """),
            .warning("""
                Indbyggede plugins findes **kun i udgaven med direkte hentning**, fordi App Sandbox \
                forbyder at indlæse kode uden for programmet. Hvert plugin skal **godkendes i hånden én \
                gang**, efter sin kontrolsum, før det kører.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Indstillinger og programmet

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Indstillinger og programmet",
        summary: "Indstillinger, genveje, temaer, opdateringer, skift fra Notepad++, fejlfinding.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Indstillinger",
        summary: "Hvert valg bor i én læsbar JSON-fil, du kan kopiere til en anden Mac.",
        keywords: ["indstillinger", "valg", "konfiguration", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Åbn indstillingerne")]),
            .paragraph("""
                Der er intet OK og ingen Annullér — en ændring får virkning og skrives med det samme, \
                på macOS-vis.
                """),
            .heading("Konfigurationsfilen"),
            .code(language: "text", caption: "Hvor den bor",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Det er en **indrykket JSON-fil, du kan læse og rette i hånden**. Kopiér den til en \
                anden Mac, og hele din opsætning følger med. Knappen `Åbn konfigurationsfilen` i \
                indstillingerne fører dig direkte derhen.
                """),
            .heading("Nøglerne"),
            .table(
                headers: ["Nøgle", "Standard", "Betydning"],
                rows: [
                    ["`fontSize`", "`13`", "Editorens skriftstørrelse"],
                    ["`tabWidth`", "`4`", "Hvor mange kolonner bred en TAB er"],
                    ["`usesTabsForIndent`", "`false`", "Indryk med TAB i stedet for mellemrum"],
                    ["`languageIndent`", "`{}`", "Indrykning pr. sprog — se siden om blanktegn"],
                    ["`smartIndent`", "`true`", "Automatisk indrykning på en ny linje"],
                    ["`highlightAllMatches`", "`true`", "Fremhæv hvert søgetræf"],
                    ["`ligatures`", "`false`", "Ligaturer — se bemærkningen under tabellen"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Klip blanktegn i linjeslutningen ved gemning"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalisér Unicode til NFC ved gemning"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Tegnkodning til nye filer"],
                    ["`defaultEOL`", "`\"lf\"`", "Linjeslutninger til nye filer"],
                    ["`language`", "`\"system\"`", "Brugerfladens sprog"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "standardtemaet", "Hvilket farvetema der bruges"],
                    ["`showWelcomeOnLaunch`", "`true`", "Åbn velkomstvinduet ved start"],
                    ["`keyBindings`", "`{}`", "Kun de taster, du har ændret"],
                ]
            ),
            .note("""
                **Hvorfor ligaturer er SLÅET FRA som standard.** En ligatur smelter `!=` eller `->` \
                sammen til **ét** tegn, så de tegn, du ser på skærmen, ikke længere svarer til tegnene i \
                filen — og kolonneeditoren, kolonnetilstanden og ombrydning ved en kolonne måler alle i \
                kolonner. Slå dem til, når du skriver brødtekst, eller hvis du har valgt en \
                programmørskrift (Fira Code, JetBrains Mono) netop for dens ligaturer.
                """),
            .heading("Nabomapperne"),
            .table(
                headers: ["Mappe", "Rummer"],
                rows: [
                    ["`macros/`", "Gemte makroer, én JSON-fil hver"],
                    ["`scripts/`", "JavaScript-scripts"],
                    ["`themes/`", "Farvetemaer"],
                    ["`grammars/`", "Selvdefinerede sprog"],
                ]
            ),
            .warning("""
                En konfigurationsfil skrevet af et **nyere** GEditor **overskrives ikke** af et ældre — \
                det ældre kører på standardværdier og siger det. At overskrive er den sikreste måde at \
                ødelægge opsætningen for en, der holder to maskiner i takt, og han ville aldrig få at \
                vide hvorfor.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Statuslinjen",
        summary: "Ti felter nederst — alle læsbare og alle klikbare.",
        keywords: ["statuslinje", "position", "tegnkodning", "skrivebeskyttet", "størrelse"],
        blocks: [
            .paragraph("""
                Dette er den største forskel fra andre editorers statuslinjer: **intet felt er \
                skrivebeskyttet**. Ser du en forkert værdi, er et klik på den måden at rette den på, \
                frem for at lede gennem menuer.
                """),
            .table(
                headers: ["Felt", "Fortæller dig", "Ved klik"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "markørens position — kolonnen i TEGN, `@340` bytepositionen",
                     "åbner feltet `Gå til`"],
                    ["`11 byte · 3 dòng`", "dokumentets størrelse",
                     "tæller bytes · tegn · ord · linjer"],
                    ["`🔒 Chỉ đọc`", "vises kun, når dokumentet er låst",
                     "siger HVORFOR det er låst, og låser op, når det kan lade sig gøre"],
                    ["`View` / `Code`", "hvilken visning du er i", "skifter (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "CSV-tilstand og det anvendte skilletegn",
                     "slår CSV-tilstand til/fra, eller **vælger skilletegn på ny**"],
                    ["`Đang theo dõi`", "`tail -f` kører", "—"],
                    ["`UTF-8`", "tegnkodningen", "fortolk om, eller omsæt til en anden tegnkodning"],
                    ["`LF`", "linjeslutningsstil", "skift LF · CRLF · CR"],
                    ["`Python`", "sprog til syntaksfarvningen", "vælg et andet, eller tilbage til genkendelse på endelse"],
                    ["`Tab: 4`", "indrykningens bredde", "2 · 4 · 8, generelt eller **kun for dette sprog**"],
                    ["`Ngắt: tắt`", "ombrydningstilstand", "gennemgår de tre tilstande"],
                ]
            ),
            .heading("Tre felter, der er et ekstra blik værd"),
            .bullets([
                "**`@340` — bytepositionen.** Det er det tal, hvert andet værktøj i programmet taler: JSON- og XML-fejl, uddata fra `--doc-sweep`, den binære fremviser og feltet `Gå til @340`. Læs det her, skriv det der.",
                "**En `~` ved kolonnen** betyder, at tallet tæller BYTES og ikke synlige kolonner — det sker kun på linjer længere end 200 KB, hvor tegntælling ville sinke hver markørbevægelse.",
                "**`CSV · …` kan klikkes for at vælge skilletegn på ny.** Genkendelsen kan tage fejl, og så er hver kolonnehandling forskudt, uden at noget signalerer det. Sådan siger du imod — det **LÆSER kun filen IGEN**, uden at ændre en byte (til forskel fra `CSV ▸ Skift skilletegn…`, som omskriver den).",
            ]),
            .note("""
                Et felt, der ikke vedrører den åbne fil, er **skjult**, ikke gråt: `Skrivebeskyttet` \
                vises kun, når dokumentet virkelig er låst, og `CSV · …` kun i CSV-tilstand.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "At ændre tastaturgenveje",
        summary: "Ændr enkelte taster, eller overtag Notepad++' opsætning i sin helhed.",
        keywords: ["genvej", "tasteopsætning", "forindstilling"],
        blocks: [
            .paragraph("""
                `Indstillinger…` har en afdeling Genveje med to hurtigknapper: **Brug \
                Notepad++-forindstillingen** og **Tilbage til standardværdierne**.
                """),
            .paragraph("""
                Konfigurationsfilen noterer kun det, du har **ændret i forhold til standardværdierne**. \
                Derved bliver du ikke siddende med den gamle opsætning uden besked, når GEditor ændrer \
                en standardtast i en ny version.
                """),
            .note("""
                To kommandoer må ikke dele genvej. Når de gør, udløser AppKit stille kun det **første** \
                menupunkt, og den anden kommando virker ødelagt — derfor har GEditor en kontrol, der \
                hindrer det.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Temaer, lyst og mørkt",
        summary: "Følg systemet, lyst eller mørkt; og et tema er en JSON-fil, du kan rette.",
        keywords: ["tema", "farver", "mørk tilstand", "lys", "udseende"],
        blocks: [
            .paragraph("`Indstillinger…` vælger `Følg systemet`, `Lyst` eller `Mørkt` og udpeger et farvetema."),
            .paragraph("""
                Et tema er en JSON-fil i `themes/`. Knappen `Eksportér det nuværende tema` skriver et ud \
                som udgangspunkt for dit eget.
                """),
            .note("""
                En fejlskrevet farve i en temafil falder tilbage på **standardtemaets** farve, ikke på \
                sort. Sort ser ud som en designbeslutning, og brugeren ville lede efter fejlen et andet \
                sted.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Opdateringer, versioner og at afslutte",
        summary: "Hvori opdateringen adskiller sig mellem de to udgaver.",
        keywords: ["opdatering", "version", "om", "afslut"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Udgave", "Opdateres via"],
                rows: [
                    ["App Store", "App Store, som ethvert andet program"],
                    ["Direkte hentning", "`Søg efter opdateringer…` inde i programmet"],
                ]
            ),
            .paragraph("""
                `Om GEditor` viser den kørende version og hvilken udgave det er — nyttigt, når man \
                melder en fejl.
                """),
            .note("""
                I App Store-udgaven **bliver `Søg efter opdateringer…` stående i menuen** og forklarer, \
                hvorfor det ikke gælder, i stedet for at forsvinde. Et manglende menupunkt er et \
                spørgsmål til supporten.
                """),
            .paragraph("At afslutte mister intet arbejde: omgangen kommer tilbage næste gang, du åbner."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "At bruge dette hjælpevindue",
        summary: "Søg i bogen, skift dens sprog, og hent velkomstvinduet tilbage.",
        keywords: ["hjælp", "vejledning", "søgning", "velkomst", "sprog"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Åbn hjælpevinduet")]),
            .bullets([
                "Søgefeltet øverst til venstre kigger i **brødtekst og kodeeksempler** — at skrive en nøgen konfigurationsnøgle som `fail_under` fører til den rigtige side.",
                "At skrive **uden accenter** finder alligevel tekst med dem.",
                "Knappen `Tilbage` går til den forrige side.",
                "Knappen `Kopiér` ved hver kodeblok kopierer den blok.",
            ]),
            .heading("At læse på et andet sprog"),
            .paragraph("""
                Menuen øverst til højre i dette vindue vælger **bogens sprog**, uafhængigt af \
                brugerfladens sprog. Skiftet holder dig **på den side, du læser** — sidernes id'er \
                oversættes med vilje ikke, netop for at dette skal virke.
                """),
            .note("""
                Kun sprog, der virkelig har en bog, står på listen. Et menupunkt, der skifter til noget \
                og lader teksten være uændret, ville være et menupunkt, der lyver.
                """),
            .heading("At hente velkomstvinduet tilbage"),
            .paragraph("""
                Har du sat flueben ved **Åbn ikke dette vindue ved start**, så åbn det igen med \
                `Hjælp ▸ Rundtur i funktionerne` — feltet nederst i vinduet dukker op igen og kan \
                fjernes.
                """),
            .paragraph("Eller sæt `showWelcomeOnLaunch` tilbage til `true` i `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Fra Notepad++ til GEditor",
        summary: "Hvilke taster der bytter plads, hvad der virker anderledes, og hvad der mangler.",
        keywords: ["notepad++", "skift", "windows", "genveje"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Nogle få taster **bytter plads** på macOS i stedet for blot at gøre `Ctrl` til `⌘`. Her \
                er sammenligningen.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Hvorfor"],
                rows: [
                    ["`Ctrl+D` Fordobl linje", "**⇧⌘D**", "Her er `⌘D` flere markører, som i enhver Mac-editor"],
                    ["`Ctrl+L` Slet linje", "**⌘K**", "På macOS betyder `⌘L` »gå til linje«"],
                    ["`Ctrl+G` Gå til linje", "**⌘L**", "De to bytter plads"],
                    ["`Ctrl+Q` Udkommentér", "**⌘/**", "macOS-sædvane"],
                    ["`Ctrl+Shift+↑/↓` Flyt linje", "**⌥↑ / ⌥↓**", "På macOS hører `⌃` til Mission Control"],
                    ["`F3` Find næste", "**⌘G**", "macOS-sædvane"],
                    ["`Ctrl+F2` Slå bogmærke til/fra", "**⌘F2**", "F2 og ⇧F2 springer stadig mellem mærker"],
                    ["`Alt` + træk til kolonner", "**⌥ + træk**", "Ens"],
                    ["`Ctrl+Alt+Shift+↓` Kolonneeditor", "**⌥⌘C**", "macOS-sædvane"],
                ]
            ),
            .note("Vil du hellere slippe for at lære om? `Indstillinger ▸ Genveje ▸ Brug Notepad++-forindstillingen`."),
            .heading("Ting Notepad++ har, som virker anderledes her"),
            .bullets([
                "**Arbejdsomgange** genskaber sig selv, også ugemte faneblade — intet at slå til.",
                "**Bogmærker har ni farver**, og én linje kan bære flere på én gang.",
                "**Dokumentkortet** beskriver *hele* filen, ikke kun den synlige del.",
                "**Makroer** kan køres »til dokumentets slutning« og »på alle faneblade«, og en hel kørsel er ét fortrydelsestrin.",
            ]),
            .heading("Hvad GEditor lægger til"),
            .bullets([
                "En **rensebænk til data** og **dataprofiler** til CSV-filer.",
                "**SQL-forespørgsler** direkte mod en CSV-fil.",
                "**Gamle vietnamesiske tegnkodninger** — TCVN3, VISCII, VNI-Windows, læst, skrevet og genkendt af sig selv.",
                "**Accentufølsom søgning** i hvert filterfelt.",
                "**`.greport.md`-rapporter** med tabeller og diagrammer, der genberegnes.",
                "**Kommandolinjeværktøjet `geditor`** i udgaven med direkte hentning.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Almindelige problemer",
        summary: "Seks situationer, der får folk til at tro, programmet er i stykker.",
        keywords: ["fejl", "problem", "virker ikke", "fejlfinding", "hvorfor"],
        blocks: [
            .table(
                headers: ["Symptom", "Almindelig årsag"],
                rows: [
                    ["Vietnamesisk tekst vises som volapyk", "Forkert tegnkodning — klik på tegnkodningen på statuslinjen"],
                    ["At søge efter tekst med accent finder intet", "Filen er i opdelt Unicode — kør `Normalisér Unicode` til NFC"],
                    ["Et menupunkt er gråt", "App Store-udgaven kan ikke køre den kommando — punktet forklarer hvorfor"],
                    ["Parentesmatchningen nægter at køre", "Dokumentet er større end 1 MB — at fremhæve det forkerte par er værre end intet"],
                    ["Kolonnen på statuslinjen har en `~`", "Dokumentet er større end 200 KB, så det er et byteantal, ikke en synlig kolonne"],
                    ["En SQL-forespørgsel siger, at filen skal gemmes først", "DuckDB læser **filer**, ikke den buffer du redigerer"],
                ]
            ),
            .heading("Når GEditor afslutter uventet"),
            .paragraph("""
                Ved næste start siger et banner det, med en knap **Åbn rapporten** — rapporten åbner som \
                et faneblad, du kan læse og kopiere fra som fra enhver anden tekstfil.
                """),
            .bullets([
                "Rapporten bærer kun **versionen, macOS-udgaven, maskinens arkitektur, signalets navn og kaldstakken**.",
                "**Intet dokumentindhold, og heller ingen filstier** — en sti som `~/Skrivebord/løn-december.xlsx` har allerede afsløret tre private ting, før nogen har åbnet den.",
                "**Intet sendes nogen steder hen.** Der er ingen automatisk overførsel og ingen server til at tage imod; filen bliver liggende i `~/Library/Application Support/GEditor/crash/`, indtil du åbner eller sletter den.",
                "Når du har åbnet rapporten, nævner næste start den ikke igen.",
            ]),
            .heading("Hvor man kigger dernæst"),
            .bullets([
                "Statuslinjen viser tegnkodning, linjeslutninger, sprog og ombrydningstilstand — hvert felt kan klikkes.",
                "`settings.json` kan rettes i hånden, når indstillingsvinduet ikke er nok.",
                "`Om GEditor` giver versionen og udgaven, som en fejlmelding har brug for.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
