import Foundation

/// Norsk hjelpeinnhold (bokmål) — del 5: rapporter, kunnskap, automatisering og programmet.
extension HelpNB {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Rapporter og diagrammer",
        summary: "En tekstfil som gir en HTML-rapport med tall som regnes om, pluss Mermaid-diagrammer.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md`-rapporter",
        summary: "Markdown pluss fire slags kjørbare blokker — skriv til venstre, forhåndsvis til høyre.",
        keywords: ["rapport", "greport", "html", "eksport", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                En `.greport.md`-fil er **vanlig Markdown** pluss noen få kjørbare inngjerdede blokker. \
                Å tegne den gir en **selvbærende** HTML-fil — ingen nett, ingen følgefiler — som hvem \
                som helst kan åpne.
                """),
            .paragraph("""
                Fordi det er ren tekst, kan den **sammenlignes, versjoneres og deles** — samme tanke \
                som med ryddeoppskrifter og kvalitetsregelsett.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — en fullstendig rapport",
                  source: """
                    ---
                    title: Salgsrapport for august
                    source: sales-2026-08.csv
                    ---

                    # Salgsrapport for august

                    Tall per 31. august 2026.

                    ## Omsetning per provins

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Omsetning per provins
                    y_label: Omsetning
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
            .heading("Blokkslagene"),
            .table(
                headers: ["Blokk", "Gir"],
                rows: [
                    ["`query`", "En tabell, fra en SQL-setning for DuckDB"],
                    ["`chart`", "Et diagram"],
                    ["`quality`", "Et kvalitetskort for data"],
                    ["`mining`", "En rangeringstabell fra graving per gruppe"],
                    ["`mermaid`", "Et diagram"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                `---`-blokken øverst erklærer `title` og `source` — standard datakilde for hver blokk \
                som ikke nevner sin egen.
                """),
            .note("""
                Forhåndsvisningen bygges om når du slutter å skrive, men den **tolker bare**; den \
                kjører ikke spørringer ved hvert tastetrykk. Dokumentfeil og datafeil meldes hver for \
                seg — *«chart-blokken mangler nøkkelen `kind`»* er en filfeil, *«kolonnen `doanh_thu` \
                finnes ikke»* er en datafeil.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "`query`-blokken",
        summary: "Én DuckDB-setning blir til én tabell i rapporten.",
        keywords: ["spørring", "sql", "tabell", "rapport", "blokk"],
        blocks: [
            .paragraph("""
                Blokkens innhold er **én SQL-setning**, kjørt mot rapportens kilde. Tabellen heter `t`, \
                i samme dialekt som i spørringspanelet.
                """),
            .code(language: "text", caption: "En query-blokk med parameter",
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
                `:thang` er en **parameter**. Den gis ved tegningen — fra skallet med `--param \
                thang=8`, eller fra en listefil når rapporter lages i bunker.
                """),
            .note("""
                Tabeller i en datarapport **bør komme fra en query-blokk**, ikke skrives for hånd. En \
                håndskrevet tabell regnes ikke om når tallene endres, og før eller siden er den uenig \
                med resten av rapporten.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "`chart`-blokken",
        summary: "En YAML-oppsetting blir til et diagram — og formatets viktigste regel.",
        keywords: ["diagram", "yaml", "rapport", "tegn"],
        blocks: [
            .code(language: "yaml", caption: "Hver nøkkel i en chart-blokk",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Omsetning per provins
                    x_label: Provins
                    y_label: Omsetning
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Kilde — sales.csv, per 26. august 2026
                    """),
            .heading("Uten `query` bruker den resultatet fra query-blokken RETT OVER"),
            .paragraph("""
                Dette er formatets viktigste regel. Takket være den gjentar ikke den vanlige rapporten \
                «en tabell og så et diagram over den tabellen» sin SQL — og å gjenta den betyr at de to \
                kopiene til slutt glir fra hverandre, og da sier tabellen og diagrammet ulike ting på \
                samme side.
                """),
            .warning("""
                Til gjengjeld **betyr blokkenes rekkefølge noe**: å skyte inn en query-blokk imellom \
                endrer dataene for diagrammet under.
                """),
            .heading("Hvorfor `source` er sin egen nøkkel"),
            .paragraph("""
                En kildehenvisning skrevet som brødtekst under diagrammet vises helt fint — på \
                skjermen. Men diagrammet skal eksporteres som PNG og limes inn andre steder, og \
                brødteksten blir igjen. Som nøkkel tegnes den **inne i bildet** og følger med det.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "`quality`-blokken",
        summary: "Et kvalitetskort for data inne i rapporten.",
        keywords: ["kvalitet", "kort", "rapport", "blokk"],
        blocks: [
            .code(language: "yaml", caption: "Hver nøkkel i en quality-blokk",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # tomt betyr rapportens egen kilde
                    title: Kvaliteten på augusts salgsdata
                    rules: true                 # vis tabellen regel for regel, bestått/ikke bestått
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # fastsett referansedatoen for "Aktualitet"
                    fail_under: 90              # under dette blir kortet advarselsfarget
                    """),
            .table(
                headers: ["`chart`", "Tegner"],
                rows: [
                    ["`violations`", "Radantall for reglene som **ikke besto** — svarer på «hva rettes først»"],
                    ["`dimensions`", "Poengene for de seks dimensjonene"],
                    ["`none`", "Bare tabell, intet diagram"],
                ]
            ),
            .note("""
                Sett `now:` i en tilbakevendende rapport. Uten den sammenligner *Aktualitet* med \
                tegningens øyeblikk, så å tegne forrige måneds rapport på nytt gir en annen poengsum \
                enn den du utga.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "`mining`-blokken",
        summary: "Rangér grupper etter avvik, prognosefeil eller samvariasjonsavvik.",
        keywords: ["graving", "rapport", "grupperangering"],
        blocks: [
            .code(language: "yaml", caption: "Hver nøkkel i en mining-blokk",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # kolonnen for avvik og prognose
                    pair: chi_phi             # en annen kolonne, for samvariasjon per gruppe
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # tomt betyr rapportens egen kilde
                    title: Graving per provins
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Rangerer etter"],
                rows: [
                    ["`anomalies`", "Gruppen som har flest avvikende rader"],
                    ["`forecast_error`", "Gruppen hvis prognose er dårligst"],
                    ["`correlation_gap`", "Gruppen hvis samvariasjon avviker mest fra den samlede tabellen — fanger Simpsons paradoks"],
                ]
            ),
            .warning("""
                **Ingen nøkkel slår av «Metode»-blokken.** En grupperangering uten metoden sin gir \
                leseren ingen mulighet til å vite mot hvilket gjerde «flest avvik» ble målt. Den som \
                vil ha den skjult, kjenner allerede svaret han ønsker.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Å lage rapporter i bunker",
        summary: "Én mal, én parameterliste, mange rapporter.",
        keywords: ["bunke", "mange", "parametre", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Én rapportmal, kjørt for hver avdeling eller hver måned. Parameterlisten er en CSV- \
                eller JSON-fil — **én rad per rapport**.
                """),
            .code(language: "text", caption: "list.csv — én rad per rapport",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Tegn hele bunken fra skallet",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Eller én rapport med parametre gitt for hånd",
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
        summary: "Tegn diagrammer i tekst, endre dem med kommandoer, forhåndsvis i takt begge veier.",
        keywords: ["mermaid", "diagram", "flytskjema", "sekvens", "tegn"],
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
                Mermaid tegner diagrammer **ut fra tekst**: du skriver en beskrivelse, og maskinen \
                tegner den. Et diagram kan derfor sammenlignes og versjoneres — noe en bildefil ikke \
                kan.
                """),
            .paragraph("""
                Åpne `Mermaid-diagram: forhåndsvisning` for en visning ved siden av redigereren. De to \
                går **i takt begge veier**: marker et element i bildet, og markøren hopper til linjen \
                dets.
                """),
            .heading("Endre med kommandoer, ikke ved å skrive om"),
            .table(
                headers: ["Kommando", "Hva den gjør"],
                rows: [
                    ["Sett inn en mal…", "Sett inn et ferdig skjelett for hver diagramtype"],
                    ["Legg til et element…", "Legg til en node eller en deltaker"],
                    ["Forbind de to markerte elementene", "Tegn en pil mellom dem"],
                    ["Endre det markerte elementets merkelapp…", "Endre teksten uten å lete etter linjen"],
                    ["Slett det markerte elementet", "Fjern noden **og** hver kant som rører den"],
                    ["Flytt meldingen opp / ned", "Omorganiser trinnene i et sekvensdiagram"],
                    ["Omformater", "Rykk inn og rett opp hele blokken"],
                ]
            ),
            .heading("Å skille ut i en fil og bygge inn igjen"),
            .paragraph("""
                Store diagrammer hører hjemme i sin egen `.mmd`-fil: `Skill blokken ut i en .mmd-fil…` \
                flytter den ut og etterlater en henvisning. `Bygg den henviste filen inn igjen` gjør \
                det motsatte når du må sende én enkelt fil.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Vanlig Mermaid-syntaks",
        summary: "De fire mest brukte diagramtypene, hver med en mal som virker.",
        keywords: ["mermaid", "syntaks", "flytskjema", "sekvens", "gantt", "klasse", "mal"],
        blocks: [
            .code(language: "mermaid", caption: "Flytskjema — en godkjenningsprosess for ordrer",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Sekvensdiagram — en betalingsprosess",
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
            .code(language: "mermaid", caption: "Klassediagram — en datamodell",
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
            .code(language: "mermaid", caption: "Gantt — en utgivelsesplan",
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
                headers: ["Nodeform", "Skriv"],
                rows: [
                    ["Rektangel", "`A[Label]`"],
                    ["Avrundet", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Rombe (beslutning)", "`A{Label}`"],
                    ["Sylinder (data)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Pil", "Skriv"],
                rows: [
                    ["Heltrukket, med spiss", "`A --> B`"],
                    ["Prikket", "`A -.-> B`"],
                    ["Tykk", "`A ==> B`"],
                    ["Med merkelapp", "`A -- label --> B`"],
                ]
            ),
            .note("""
                Et flytskjemas retning står rett etter `flowchart`: `TD` ovenfra og ned, `LR` fra \
                venstre til høyre, samt `BT` og `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Kunnskapspakken

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Kunnskapspakken",
        summary: "Oppdeling i biter, søkeregistre, kunnskapsgrafer, entiteter og vurdering av gjenfinning.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Hva kunnskapspakken er",
        summary: "Verktøy for å forberede og prøve data til et system som svarer på spørsmål ut fra dokumenter.",
        keywords: ["rag", "kunnskap", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Når man bygger et system som svarer på spørsmål ut fra en dokumentsamling, ligger \
                mesteparten av arbeidet ikke i modellen, men i å **forberede dataene**: å klippe \
                dokumentene i fornuftige biter, prøve kvaliteten på de bitene, bygge et register og \
                **måle om gjenfinningen virkelig finner det rette**.
                """),
            .paragraph("""
                Dette kapittelet er nettopp verktøyene til det. Det kjører **helt på din egen maskin** \
                og rører aldri nettet.
                """),
            .table(
                headers: ["Oppgave", "Verktøy"],
                rows: [
                    ["Å klippe dokumenter i biter", "Forhåndsvisning av oppdeling"],
                    ["Å gjennomgå og vurdere biter", "Gjennomgang av JSONL-biter"],
                    ["Å konvertere mellom dataformer", "Kunnskapskonvertering"],
                    ["Å bygge og gjennomgå en relasjonsgraf", "Kunnskapsgraf"],
                    ["Å finne egennavn i tekst", "Entitetsmerking"],
                    ["Å måle gjenfinningens kvalitet", "Gjenfinningslaboratoriet"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Å dele opp og gjennomgå en JSONL-samling",
        summary: "Forhåndsvis bitgrensene på selve teksten, og vurder så hele samlingen.",
        keywords: ["chunk", "jsonl", "samling", "overlapp", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Forhåndsvisning av oppdeling"),
            .paragraph("""
                Åpne et tekst- eller Markdown-dokument, velg en framgangsmåte og en bitstørrelse. \
                Grensene **uthevet på selve teksten**, så du ser hvor et snitt havner midt i en setning \
                eller gjennom en tabell før du eksporterer noe.
                """),
            .bullets([
                "**Fast størrelse** med overlapp.",
                "**Etter oppbygning** — ved Markdown-overskrifter, med dokumentets tråd i behold.",
                "**Etter avsnitt**, slått sammen til størrelsen er nådd.",
            ]),
            .heading("Å gjennomgå en eksisterende JSONL-samling"),
            .paragraph("""
                For en samling du allerede har (én JSON-bit per linje), svarer `JSONL: gjennomgå \
                biter…`: hvilke linjer som ikke er gyldig JSON, hvilke biter som er for korte eller for \
                lange, hvilke som dublerer hverandre, og hvilke som er klippet midt i en setning.
                """),
            .note("""
                En samling kan også vurderes med **samme ramme med seks dimensjoner** som tabelldata — \
                bruk nøkkelen `corpus:` i en rapports `quality`-blokk.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Å konvertere kunnskapsformater",
        summary: "Biter mellom JSONL · CSV · Markdown, grafer mellom DOT · Mermaid · kantlister.",
        keywords: ["konverter", "jsonl", "dot", "mermaid", "kantliste"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Fra", "Til"],
                rows: [
                    ["JSONL-biter", "CSV · Markdown"],
                    ["CSV-biter", "JSONL · Markdown"],
                    ["DOT-graf", "Mermaid · kantliste"],
                    ["Kantliste", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Det er en **forhåndsvisning av fem rader** før den nye fanen lages, samme mekanisme som \
                ved CSV-konverteringen.
                """),
            .paragraph("""
                `Åpne tripler/kanter som tabell` viser en tripelfil eller en kantliste som tabell — \
                filtrer og sorter som i enhver annen CSV.
                """),
            .note("""
                Retningen **Markdown → JSONL** finnes ikke i denne kommandoen: den retningen *er* \
                oppdelingen, og kommandoen viser deg dit. To utførelser av ett og samme snitt ville gi \
                to ulike resultater.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Kunnskapsgrafer",
        summary: "Kontroller syntaksen, vurder helsen, og kjør algoritmer på grafer med en million kanter.",
        keywords: ["graf", "dot", "cypher", "pagerank", "louvain", "syntakskontroll"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor leser grafer som **DOT**, som **kantlister** og som **tripler**. `Kontroller \
                grafsyntaks` fanger syntaksfeil, løse noder og kanter som peker på noder som ikke \
                finnes.
                """),
            .heading("Tilgjengelige algoritmer"),
            .table(
                headers: ["Algoritme", "Svarer på"],
                rows: [
                    ["Naboskap i k steg", "Hva som henger sammen med denne noden innen k steg"],
                    ["Sammenhengende deler", "Hvor mange atskilte biter grafen består av"],
                    ["PageRank", "Hvilke noder som er viktige"],
                    ["Louvain", "Hvordan grafen deler seg i fellesskap"],
                ]
            ),
            .paragraph("""
                På en graf med **en million kanter** kjører alle fire på mellom noen få millisekunder \
                og omtrent ett sekund.
                """),
            .note("""
                En graf kan også vurderes med **rammen med seks dimensjoner** som brukes for tabeller \
                og samlinger — bruk nøkkelen `graph:` i en `quality`-blokk.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Å merke entiteter fra en liste",
        summary: "Last inn en liste over egennavn og finn hver forekomst — under tre regler laget for vietnamesisk.",
        keywords: ["entitet", "egennavn", "ner", "merking", "matching"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Last inn en liste over navn (firmaer, varer, steder), og GEditor uthever hver forekomst \
                i dokumentet, med en tabell over antallene.
                """),
            .heading("Tre matchingsregler, alle fra vietnamesiske data"),
            .bullets([
                "**Lengste treff vinner.** Med både `An Phát` og `Công ty An Phát` på listen må en setning som inneholder det lengre uttrykket, treffe det lengre — ellers deles den i to og telles som to entiteter, noe som **blåser opp** statistikken.",
                "**Ordgrenser kreves.** `An` må ikke treffe inne i `Anh` eller `Hoàn`. Vietnamesiske egennavn er korte og deler stavelser med utallige vanlige ord.",
                "**Uavhengig av store/små bokstaver, men AVHENGIG av aksenter.** `CÔNG TY` og `Công ty` er ett; `má` og `ma` er det ikke.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Å løse opp entitetsvarianter",
        summary: "Gjenkjenn `Cty An Phát` og `Công ty An Phát` som ett — men la likevel avgjørelsen ligge hos deg.",
        keywords: ["entitetsoppløsning", "varianter", "navnenormalisering", "duplikater"],
        blocks: [
            .paragraph("""
                Samme klyngedannelse som **uklare duplikater** i en CSV-tabell — én felles utførelse, \
                ikke to.
                """),
            .paragraph("""
                Utdataen er et **forslag**: du går gjennom hver klynge og velger den gjeldende formen. \
                Det finnes ingen «slå sammen alle»-knapp, for to navn som ligner hverandre 92 %, kan \
                være to virkelige organisasjoner.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Gjenfinningslaboratoriet",
        summary: "Mål om registeret finner det rette, ved hjelp av et sett spørsmål med svar.",
        keywords: ["gjenfinning", "bm25", "recall", "mrr", "ndcg", "vurdering"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Last inn et **vurderingssett** — hver linje et spørsmål med numrene på de bitene som \
                burde komme tilbake — og kjør så hele bunken mot registeret.
                """),
            .table(
                headers: ["Mål", "Svarer på"],
                rows: [
                    ["recall@k", "Hvor mye av svarmengden som dukker opp blant de k øverste"],
                    ["MRR", "Hvor langt nede det første riktige resultatet ligger"],
                    ["nDCG@k", "Om rangeringen er god, med plasseringen medregnet"],
                ]
            ),
            .paragraph("""
                Resultatene kommer også **per spørsmål**, de dårligste først — det er listen din over \
                hva som må rettes i samlingen, i den rekkefølgen som lønner seg mest.
                """),
            .warning("""
                Alle tre målene er **gjennomsnitt**, og et gjennomsnitt skjuler mye. Les alltid \
                tabellen per spørsmål før du slår fast at «registeret er godt nok».
                """),
            .paragraph("""
                To oppsett kan sammenlignes side om side, og resultatet faller rett inn i en \
                `.greport.md`-rapport, så neste kjøring blir lik.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Makroer og automatisering

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Makroer og automatisering",
        summary: "Ta opp handlinger, kjør dem i bunker, skriv skript og styr det hele fra skallet.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Å ta opp og spille av makroer",
        summary: "Ta opp en rekkefølge og gjenta den — hele kjøringen er ett angretrinn.",
        keywords: ["makro", "ta opp", "spill av", "gjenta", "automatiser"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Start / stopp opptaket"),
                HelpShortcut("⌃P", "Spill av"),
            ]),
            .steps([
                "`⌃R` starter opptaket.",
                "Gjør det du vil ha gjentatt — skrive, flytte markøren, søke, erstatte.",
                "`⌃R` igjen for å stoppe.",
                "`⌃P` spiller det av, eller `Makro ▸ Spill til dokumentets slutt` kjører det hele veien.",
                "`Makro ▸ Lagre makro…` gir den et navn til senere økter.",
            ]),
            .heading("Den tar opp KOMMANDOER, ikke rå tastetrykk"),
            .paragraph("""
                En makro lagrer **det du gjorde**, ikke hvilke taster du trykket på. Det gjør den \
                uavhengig av tastaturoppsett og av hvilken inndatametode som er på, og det gjør \
                makrofilen **lesbar** når du åpner den.
                """),
            .heading("Når en makro stanser"),
            .table(
                headers: ["Grunn", "Betydning"],
                rows: [
                    ["Antallet gjentakelser tok slutt", "Normalt"],
                    ["Et `find`-trinn fant ingenting", "Slik stanser «spill til filens slutt» av seg selv"],
                    ["Dokumentets slutt nådd", "Ikke lenger noe sted å gå"],
                    ["Du avbrøt", "`Makro ▸ Avbryt makroen som kjører`"],
                    ["En runde endret ingenting og flyttet ingenting", "Stanset så den ikke kan gå i evig runde"],
                ]
            ),
            .note("Hele kjøringen — også ti tusen gjentakelser — er **ett** angretrinn."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Å kjøre en makro i bunke",
        summary: "Over hver åpne fane, eller over en mappe med uåpnede filer.",
        keywords: ["bunke", "alle faner", "mappe", "makro", "maske"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Kommando", "Omfang", "Kan angres"],
                rows: [
                    ["Kjør på alle faner", "De åpne fanene", "Ja — ett angretrinn per fane"],
                    ["Kjør over en mappe…", "Filer på disken som **ikke er åpne**", "Nei"],
                ]
            ),
            .warning("""
                Å kjøre over en mappe berører filer som ikke er åpne i noen fane, så det finnes **ingen \
                angring**. Som standard **skriver GEditor nye filer** i stedet for å overskrive \
                originalene. Behold den innstillingen med mindre du har en sikkerhetskopi eller et \
                versjonsstyrt arkiv.
                """),
            .heading("Å filtrere filer med en maske"),
            .paragraph("""
                Mappevelgeren har et **filnavnfilter**: skriv `*.csv;*.log`, og makroen berører bare \
                dem. Det er samme maskesyntaks som `Søk i en hel mappe` bruker, med flere mønstre \
                skilt av `;` eller `,`.
                """),
            .bullets([
                "La det være **tomt**, og den tar hver tekstfil GEditor kan lese — den tidligere oppførselen.",
                "Masken **erstatter** den endelseslisten heller enn å snevre den inn ytterligere: skriv `*.bak`, og den kjører på `.bak`-filer, selv om den endelsen ikke står på tekstlisten.",
                "Passer ingenting, **gjentar meldingen masken din** heller enn å skylde på en tom mappe.",
            ]),
            .paragraph("""
                Det feltet har en svært praktisk grunn: en mappe rommer 400 `.json`-filer og 12 \
                `.log`-filer, og makroen din rydder bare i logger. Uten maske blir også de andre 400 \
                behandlet — og siden bunken skriver nye filer, etterlater en feil 400 stykker søppel.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Makrofilens syntaks",
        summary: "Sju slags trinn, det fullstendige JSON-formatet og to makroer som virker.",
        keywords: ["makro", "json", "syntaks", "format", "rediger for hånd", "del"],
        blocks: [
            .paragraph("""
                Hver makro er **sin egen JSON-fil** i GEditors mappe `macros/`. En skade holder seg \
                innenfor én makro, og å dele en med en kollega er å sende én fil.
                """),
            .code(language: "text", caption: "Hvor filene bor",
                  source: "~/Library/Application Support/GEditor/macros/<makronavn>.json"),
            .heading("De sju trinnslagene"),
            .table(
                headers: ["Trinn", "Skrives som", "Betydning"],
                rows: [
                    ["Sett inn tekst", "`{\"insert\": {\"_0\": \"text\"}}`", "Skriv ved markøren; med en markering erstatter det den"],
                    ["Slett bakover", "`{\"deleteBackward\": {}}`", "Som slettetasten"],
                    ["Slett forover", "`{\"deleteForward\": {}}`", "Som ⌦"],
                    ["Flytt", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Se retningslisten nedenfor"],
                    ["Marker linjen", "`{\"selectLine\": {}}`", "Uten linjeskiftet"],
                    ["Søk", "`{\"find\": { … }}`", "Finner og **markerer** neste treff"],
                    ["Erstatt markeringen", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` gjelder hvis forrige trinn var et `find` med regex"],
                ]
            ),
            .heading("Flytteretninger"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Det fullstendige `find`-trinnet"),
            .code(language: "json", caption: "De fire nøklene i et find-trinn",
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
            .paragraph("`mode` tar `normal`, `extended` eller `regex` — samme tre modi som søkefeltet."),
            .heading("Eksempel 1 — gjør provinskoden i linjens begynnelse stor"),
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
                Kjør den med `Makro ▸ Spill til dokumentets slutt`: at `find`-trinnet ikke finner mer, \
                er nettopp stoppbetingelsen.
                """),
            .heading("Eksempel 2 — slett linjen etter hver linje som inneholder TODO"),
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
                Prøv en håndredigert makro på en kopi først. Et feilskrevet `find`-trinn får makroen \
                til å stanse straks — det er det ufarlige tilfellet. Det farlige er et mønster som \
                treffer bredere enn du trodde, og endrer tusenvis av steder innenfor ett angretrinn.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript-skript",
        summary: "Fire funksjoner, én `.js`-fil, og alt den gjør er ett angretrinn.",
        keywords: ["skript", "javascript", "js", "automatiser", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Legg en `.js`-fil i GEditors mappe `scripts/`, og kjør den fra `Makro ▸ Skript…`. Et \
                skript ser nøyaktig **fire** ting:
                """),
            .table(
                headers: ["Kall", "Betydning"],
                rows: [
                    ["`doc.text`", "Hele dokumentets tekst"],
                    ["`doc.selection`", "Markeringen (tom streng når ingenting er markert)"],
                    ["`doc.replace(s)`", "Erstatt **hele dokumentet** med `s` — ett angretrinn"],
                    ["`doc.log(s)`", "Skriv en linje i resultatpanelet"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Nummerer hver linje.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — behold de tre første CSV-kolonnene",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Tre grenser å kjenne"),
            .bullets([
                "**Ingen filtilgang, ingen nett, ingen prosesser å starte.** API-flaten er bevisst smal: å utvide den senere er lett, å snevre den inn ødelegger hvert skript brukerne allerede har skrevet.",
                "**Dette er ikke en sikkerhetsgrense.** Skript kjører i samme prosess. Ikke kjør et skript du ikke har lest.",
                "**Det er en grense på fem sekunder.** Over den får du en melding og programmet forblir brukbart — men det skriptets tråd **fortsetter å snurre til du avslutter**, og spiser en kjerne. Meldingen sier det.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Å filtrere gjennom en ytre kommando",
        summary: "Send markeringen gjennom en Unix-kommando og ta resultatet tilbake.",
        keywords: ["filter", "ytre kommando", "skall", "rør", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Markeringen (eller hele dokumentet) gis til en kommandos `stdin`, og den kommandoens \
                `stdout` erstatter den.
                """),
            .code(language: "bash", caption: "Noen vanlige",
                  source: """
                    sort -u                     # sorter og fjern duplikater
                    jq .                        # omformater JSON
                    tr 'a-z' 'A-Z'              # til store bokstaver
                    grep -v '^#'                # fjern kommentarlinjer
                    awk -F, '{print $3","$1}'   # bytt om kolonnenes rekkefølge
                    """),
            .note("""
                Resultatet er **ett** angretrinn. Gir kommandoen en feilkode, lar GEditor teksten være \
                og viser `stderr`.
                """),
            .warning("""
                Denne kommandoen finnes **bare i utgaven med direkte nedlasting**. App Sandbox forbyr å \
                kjøre kode utenfor programmet, så i App Store-utgaven blir menypunktet stående og \
                forklarer hvorfor det ikke er tilgjengelig.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Kommandolinjeverktøyet `geditor`",
        summary: "Åpne, rydd, spør, vurder og tegn rapporter — uten å åpne programmet.",
        keywords: ["cli", "kommandolinje", "terminal", "geditor", "skript", "ci"],
        blocks: [
            .warning("""
                Finnes bare i utgaven med **direkte nedlasting**. App Store-utgaven kjører i en \
                sandkasse, så en ytre kommandolinjeprosess kan ikke koble seg til den.
                """),
            .heading("Å åpne filer"),
            .code(language: "bash", caption: "Åpne, hopp til en posisjon, les fra et rør",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # linje 120, kolonne 5
                    geditor -w notes.md            # vent til filen lukkes før avslutning
                    geditor -r app.log             # åpne skrivebeskyttet
                    git diff | geditor             # les standardinndata inn i en ny fane
                    """),
            .table(
                headers: ["Valg", "Betydning"],
                rows: [
                    ["`-w`, `--wait`", "Vent til filen lukkes før avslutning — for å tjene som `git`s redigerer"],
                    ["`-n`, `--new-window`", "Åpne i et nytt vindu"],
                    ["`-r`, `--read-only`", "Åpne skrivebeskyttet"],
                    ["`-i`, `--info`", "Skriv ut tegnkoding, linjeslutt og linjeantall, og avslutt — **uten** å åpne programmet"],
                    ["`-h`, `--help`", "Vis hjelpen"],
                    ["`-v`, `--version`", "Vis versjonen"],
                ]
            ),
            .heading("Å kjøre uten å åpne programmet"),
            .paragraph("""
                De fire kommandogruppene nedenfor kjører **helt inne i kommandolinjeprosessen**, så de \
                virker i CI, der ingen er logget inn i en grafisk økt.
                """),
            .code(language: "bash", caption: "Rydding med en oppskrift",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Å spørre",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Kvalitetsporten — kode 0 bestått · 1 ikke bestått · 2 feil",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Å tegne rapporter",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript og Tjenester-menyen",
        summary: "Les og skriv dokumentet fra AppleScript, eller send tekst til GEditor fra et annet program.",
        keywords: ["applescript", "osascript", "tjenester", "automatisering", "snarveier"],
        blocks: [
            .code(language: "applescript", caption: "Les det åpne dokumentet",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Skriv over innholdet, og les markeringen",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Åpne en fil",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Tjenester-menyen"),
            .paragraph("""
                Marker tekst i et hvilket som helst program, og bruk så `Tjenester`-menyen for å sende \
                den til GEditor som en ny fane.
                """),
            .note("""
                Første gang du kjører AppleScript, ber macOS om tillatelse til automatisering. Det er \
                systemets dialog, ikke GEditors.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Utvidelsespakker og programtillegg",
        summary: "To slags utvidelser, og i hvilken utgave hver av dem kjører.",
        keywords: ["programtillegg", "utvidelse", "pakke", "innebygd"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Utvidelsespakker"),
            .paragraph("""
                En pakke er **én JSON-fil** som samler et tema, skript og selvdefinerte språk. Å \
                installere kopierer en fil, å fjerne sletter en — og pakkelisten utledes fra \
                **disken**, ikke fra et register som kunne lyve.
                """),
            .paragraph("Virker i **begge utgaver**."),
            .heading("Innebygde programtillegg"),
            .paragraph("""
                Forhåndskompilerte programtillegg kjører i en **egen prosess** med en smal API-flate — \
                et programtillegg som krasjer, drar ikke programmet med seg.
                """),
            .warning("""
                Innebygde programtillegg finnes **bare i utgaven med direkte nedlasting**, fordi App \
                Sandbox forbyr å laste inn kode utenfor programmet. Hvert programtillegg må \
                **godkjennes for hånd én gang**, etter kontrollsummen sin, før det kjører.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Innstillinger og programmet

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Innstillinger og programmet",
        summary: "Innstillinger, snarveier, temaer, oppdateringer, overgang fra Notepad++, feilsøking.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Innstillinger",
        summary: "Hvert valg bor i én lesbar JSON-fil du kan kopiere til en annen Mac.",
        keywords: ["innstillinger", "valg", "konfigurasjon", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Åpne innstillingene")]),
            .paragraph("""
                Det finnes ingen OK og ingen Avbryt — en endring får virkning og skrives straks, på \
                macOS-vis.
                """),
            .heading("Innstillingsfilen"),
            .code(language: "text", caption: "Hvor den bor",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Det er en **innrykket JSON-fil du kan lese og endre for hånd**. Kopier den til en annen \
                Mac, og hele oppsettet ditt følger med. Knappen `Åpne innstillingsfilen` i \
                innstillingene fører deg rett dit.
                """),
            .heading("Nøklene"),
            .table(
                headers: ["Nøkkel", "Standard", "Betydning"],
                rows: [
                    ["`fontSize`", "`13`", "Redigererens skriftstørrelse"],
                    ["`tabWidth`", "`4`", "Hvor mange kolonner bred en TAB er"],
                    ["`usesTabsForIndent`", "`false`", "Rykk inn med TAB i stedet for mellomrom"],
                    ["`languageIndent`", "`{}`", "Innrykk per språk — se blanktegnsiden"],
                    ["`smartIndent`", "`true`", "Automatisk innrykk på en ny linje"],
                    ["`highlightAllMatches`", "`true`", "Uthev hvert søketreff"],
                    ["`ligatures`", "`false`", "Ligaturer — se merknaden under tabellen"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Klipp blanktegn i linjeslutt ved lagring"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normaliser Unicode til NFC ved lagring"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Tegnkoding for nye filer"],
                    ["`defaultEOL`", "`\"lf\"`", "Linjeslutt for nye filer"],
                    ["`language`", "`\"system\"`", "Grensesnittets språk"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "standardtemaet", "Hvilket fargetema som brukes"],
                    ["`showWelcomeOnLaunch`", "`true`", "Åpne velkomstvinduet ved oppstart"],
                    ["`keyBindings`", "`{}`", "Bare tastene du har endret"],
                ]
            ),
            .note("""
                **Hvorfor ligaturer er AV som standard.** En ligatur smelter `!=` eller `->` sammen til \
                **ett** tegn, så tegnene du ser på skjermen, svarer ikke lenger til tegnene i filen — \
                og kolonneredigereren, kolonnemodusen og bryting ved en kolonne måler alle i kolonner. \
                Slå dem på når du skriver brødtekst, eller hvis du valgte en programmererskrift (Fira \
                Code, JetBrains Mono) nettopp for ligaturene.
                """),
            .heading("Nabomappene"),
            .table(
                headers: ["Mappe", "Rommer"],
                rows: [
                    ["`macros/`", "Lagrede makroer, én JSON-fil hver"],
                    ["`scripts/`", "JavaScript-skript"],
                    ["`themes/`", "Fargetemaer"],
                    ["`grammars/`", "Selvdefinerte språk"],
                ]
            ),
            .warning("""
                En innstillingsfil skrevet av et **nyere** GEditor **overskrives ikke** av et eldre — \
                det eldre kjører på standardverdier og sier det. Å overskrive er den sikreste måten å \
                ødelegge oppsettet for en som holder to maskiner i takt, og han ville aldri få vite \
                hvorfor.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Statuslinjen",
        summary: "Ti felt nederst — alle lesbare og alle klikkbare.",
        keywords: ["statuslinje", "posisjon", "tegnkoding", "skrivebeskyttet", "størrelse"],
        blocks: [
            .paragraph("""
                Dette er den største forskjellen fra andre redigereres statuslinjer: **intet felt er \
                skrivebeskyttet**. Ser du en gal verdi, er et klikk på den måten å rette den på, heller \
                enn å lete gjennom menyer.
                """),
            .table(
                headers: ["Felt", "Forteller deg", "Ved klikk"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "markørens posisjon — kolonnen i TEGN, `@340` byteposisjonen",
                     "åpner feltet `Gå til`"],
                    ["`11 byte · 3 dòng`", "dokumentets størrelse",
                     "teller byte · tegn · ord · linjer"],
                    ["`🔒 Chỉ đọc`", "vises bare når dokumentet er låst",
                     "sier HVORFOR det er låst, og låser opp når det går"],
                    ["`View` / `Code`", "hvilken visning du er i", "veksler (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "CSV-modus og skilletegnet som brukes",
                     "slår CSV-modus av/på, eller **velger skilletegn på nytt**"],
                    ["`Đang theo dõi`", "`tail -f` kjører", "—"],
                    ["`UTF-8`", "tegnkodingen", "tolk på nytt, eller konverter til en annen tegnkoding"],
                    ["`LF`", "linjesluttstil", "bytt LF · CRLF · CR"],
                    ["`Python`", "språk for syntaksfargingen", "velg et annet, eller tilbake til gjenkjenning på endelse"],
                    ["`Tab: 4`", "innrykkets bredde", "2 · 4 · 8, generelt eller **bare for dette språket**"],
                    ["`Ngắt: tắt`", "brytingsmodus", "går gjennom de tre modiene"],
                ]
            ),
            .heading("Tre felt verdt et ekstra blikk"),
            .bullets([
                "**`@340` — byteposisjonen.** Det er tallet hvert annet verktøy i programmet snakker: JSON- og XML-feil, utdataen fra `--doc-sweep`, den binære viseren og feltet `Gå til @340`. Les det her, skriv det der.",
                "**En `~` ved kolonnen** betyr at tallet teller BYTE og ikke synlige kolonner — det skjer bare på linjer lengre enn 200 kB, der tegntelling ville sinke hver markørbevegelse.",
                "**`CSV · …` kan klikkes for å velge skilletegn på nytt.** Gjenkjenningen kan slå feil, og da er hver kolonnehandling forskjøvet uten at noe signaliserer det. Slik sier du imot — det bare **LESER filen PÅ NYTT**, uten å endre en byte (til forskjell fra `CSV ▸ Endre skilletegn…`, som skriver den om).",
            ]),
            .note("""
                Et felt som ikke gjelder den åpne filen, er **skjult**, ikke grått: `Skrivebeskyttet` \
                vises bare når dokumentet virkelig er låst, og `CSV · …` bare i CSV-modus.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Å endre tastatursnarveier",
        summary: "Endre enkelttaster, eller overta Notepad++' oppsett i sin helhet.",
        keywords: ["snarvei", "tasteoppsett", "forhåndsvalg"],
        blocks: [
            .paragraph("""
                `Innstillinger…` har en Snarveier-del med to hurtigknapper: **Bruk \
                Notepad++-forhåndsvalget** og **Tilbake til standardverdiene**.
                """),
            .paragraph("""
                Innstillingsfilen noterer bare det du har **endret fra standardverdiene**. Slik blir du \
                ikke sittende med det gamle oppsettet uten beskjed når GEditor endrer en standardtast i \
                en ny versjon.
                """),
            .note("""
                To kommandoer får ikke dele snarvei. Når de gjør det, utløser AppKit stille bare det \
                **første** menypunktet og den andre kommandoen virker ødelagt — derfor har GEditor en \
                kontroll som hindrer det.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Temaer, lyst og mørkt",
        summary: "Følg systemet, lyst eller mørkt; og et tema er en JSON-fil du kan endre.",
        keywords: ["tema", "farger", "mørk modus", "lys", "utseende"],
        blocks: [
            .paragraph("`Innstillinger…` velger `Følg systemet`, `Lyst` eller `Mørkt` og peker ut et fargetema."),
            .paragraph("""
                Et tema er en JSON-fil i `themes/`. Knappen `Eksporter det gjeldende temaet` skriver ut \
                ett som utgangspunkt for ditt eget.
                """),
            .note("""
                En feilskrevet farge i en temafil faller tilbake på **standardtemaets** farge, ikke på \
                svart. Svart ser ut som en designbeslutning, og brukeren ville lete etter feilen et \
                annet sted.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Oppdateringer, versjoner og avslutning",
        summary: "Hva som skiller oppdateringen mellom de to utgavene.",
        keywords: ["oppdatering", "versjon", "om", "avslutt"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Utgave", "Oppdateres via"],
                rows: [
                    ["App Store", "App Store, som ethvert annet program"],
                    ["Direkte nedlasting", "`Se etter oppdateringer…` inne i programmet"],
                ]
            ),
            .paragraph("""
                `Om GEditor` viser versjonen som kjører, og hvilken utgave det er — nyttig når man \
                melder en feil.
                """),
            .note("""
                I App Store-utgaven **blir `Se etter oppdateringer…` stående i menyen** og forklarer \
                hvorfor det ikke gjelder, i stedet for å forsvinne. Et manglende menypunkt er et \
                spørsmål til brukerstøtten.
                """),
            .paragraph("Å avslutte mister ikke arbeid: økten kommer tilbake neste gang du åpner."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Å bruke dette hjelpevinduet",
        summary: "Søk i boken, bytt språk på den, og hent velkomstvinduet tilbake.",
        keywords: ["hjelp", "veiledning", "søk", "velkomst", "språk"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Åpne hjelpevinduet")]),
            .bullets([
                "Søkefeltet øverst til venstre ser i **brødtekst og kodeeksempler** — å skrive en naken innstillingsnøkkel som `fail_under` fører til riktig side.",
                "Å skrive **uten aksenter** finner likevel tekst med dem.",
                "Knappen `Tilbake` går til forrige side.",
                "Knappen `Kopier` ved hver kodeblokk kopierer den blokken.",
            ]),
            .heading("Å lese på et annet språk"),
            .paragraph("""
                Menyen øverst til høyre i dette vinduet velger **bokens språk**, uavhengig av \
                grensesnittets språk. Byttet holder deg **på siden du leser** — sidenes id-er oversettes \
                med vilje ikke, nettopp for at dette skal virke.
                """),
            .note("""
                Bare språk som virkelig har en bok, listes opp. Et menypunkt som bytter til noe og lar \
                teksten stå uendret, ville vært et menypunkt som lyver.
                """),
            .heading("Å hente velkomstvinduet tilbake"),
            .paragraph("""
                Har du krysset av for **Ikke åpne dette vinduet ved oppstart**, åpne det igjen med \
                `Hjelp ▸ Rundtur i funksjonene` — avkrysningsboksen nederst i vinduet dukker opp igjen \
                og kan fjernes.
                """),
            .paragraph("Eller sett `showWelcomeOnLaunch` tilbake til `true` i `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Fra Notepad++ til GEditor",
        summary: "Hvilke taster som bytter plass, hva som virker annerledes, og hva som mangler.",
        keywords: ["notepad++", "overgang", "windows", "snarveier"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Noen få taster **bytter plass** på macOS i stedet for bare å gjøre `Ctrl` om til `⌘`. \
                Her er sammenligningen.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Hvorfor"],
                rows: [
                    ["`Ctrl+D` Dupliser linje", "**⇧⌘D**", "Her er `⌘D` flere markører, som i enhver Mac-redigerer"],
                    ["`Ctrl+L` Slett linje", "**⌘K**", "På macOS betyr `⌘L` «gå til linje»"],
                    ["`Ctrl+G` Gå til linje", "**⌘L**", "De to bytter plass"],
                    ["`Ctrl+Q` Kommenter", "**⌘/**", "macOS-skikk"],
                    ["`Ctrl+Shift+↑/↓` Flytt linje", "**⌥↑ / ⌥↓**", "På macOS hører `⌃` til Mission Control"],
                    ["`F3` Finn neste", "**⌘G**", "macOS-skikk"],
                    ["`Ctrl+F2` Slå bokmerke av/på", "**⌘F2**", "F2 og ⇧F2 hopper fortsatt mellom merker"],
                    ["`Alt` + dra for kolonner", "**⌥ + dra**", "Likt"],
                    ["`Ctrl+Alt+Shift+↓` Kolonneredigerer", "**⌥⌘C**", "macOS-skikk"],
                ]
            ),
            .note("Vil du helst slippe å lære om? `Innstillinger ▸ Snarveier ▸ Bruk Notepad++-forhåndsvalget`."),
            .heading("Ting Notepad++ har som virker annerledes her"),
            .bullets([
                "**Økter** gjenoppretter seg selv, også ulagrede faner — ingenting å slå på.",
                "**Bokmerker har ni farger**, og én linje kan bære flere samtidig.",
                "**Dokumentkartet** beskriver *hele* filen, ikke bare den synlige delen.",
                "**Makroer** kan kjøres «til dokumentets slutt» og «på alle faner», og en hel kjøring er ett angretrinn.",
            ]),
            .heading("Hva GEditor legger til"),
            .bullets([
                "En **ryddebenk for data** og **dataprofiler** for CSV-filer.",
                "**SQL-spørringer** rett mot en CSV-fil.",
                "**Gamle vietnamesiske tegnkodinger** — TCVN3, VISCII, VNI-Windows, lest, skrevet og gjenkjent av seg selv.",
                "**Aksentufølsomt søk** i hvert filterfelt.",
                "**`.greport.md`-rapporter** med tabeller og diagrammer som regnes om.",
                "**Kommandolinjeverktøyet `geditor`** i utgaven med direkte nedlasting.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Vanlige problemer",
        summary: "Seks situasjoner som får folk til å tro at programmet er ødelagt.",
        keywords: ["feil", "problem", "virker ikke", "feilsøking", "hvorfor"],
        blocks: [
            .table(
                headers: ["Symptom", "Vanlig årsak"],
                rows: [
                    ["Vietnamesisk tekst vises som rot", "Feil tegnkoding — klikk på tegnkodingen på statuslinjen"],
                    ["Å søke etter tekst med aksent finner ingenting", "Filen er i oppdelt Unicode — kjør `Normaliser Unicode` til NFC"],
                    ["Et menypunkt er grått", "App Store-utgaven kan ikke kjøre den kommandoen — punktet forklarer hvorfor"],
                    ["Parentesmatchingen nekter å kjøre", "Dokumentet er større enn 1 MB — å utheve feil par er verre enn ingenting"],
                    ["Kolonnen på statuslinjen har en `~`", "Dokumentet er større enn 200 kB, så det er et byteantall, ikke en synlig kolonne"],
                    ["En SQL-spørring sier at filen må lagres først", "DuckDB leser **filer**, ikke bufferen du redigerer"],
                ]
            ),
            .heading("Når GEditor avslutter uventet"),
            .paragraph("""
                Ved neste oppstart sier et banner det, med en knapp **Åpne rapporten** — rapporten \
                åpnes som en fane du kan lese og kopiere fra som fra enhver annen tekstfil.
                """),
            .bullets([
                "Rapporten bærer bare **versjonen, macOS-utgaven, maskinens arkitektur, signalets navn og kallstakken**.",
                "**Ikke noe dokumentinnhold, og heller ingen filstier** — en sti som `~/Skrivebord/lønn-desember.xlsx` har allerede avslørt tre private ting før noen har åpnet den.",
                "**Ingenting sendes noe sted.** Det finnes ingen automatisk opplasting og ingen tjener til å ta imot; filen blir liggende i `~/Library/Application Support/GEditor/crash/` til du åpner eller sletter den.",
                "Når du har åpnet rapporten, nevner ikke neste oppstart den igjen.",
            ]),
            .heading("Hvor man ser videre"),
            .bullets([
                "Statuslinjen viser tegnkoding, linjeslutt, språk og brytingsmodus — hvert felt kan klikkes.",
                "`settings.json` kan endres for hånd når innstillingsvinduet ikke er nok.",
                "`Om GEditor` gir versjonen og utgaven, som en feilmelding trenger.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
