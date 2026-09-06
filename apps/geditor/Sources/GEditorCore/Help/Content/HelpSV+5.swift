import Foundation

/// Svenskt hjälpinnehåll — del 5: rapporter, kunskap, automatisering och programmet.
extension HelpSV {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Rapporter och scheman",
        summary: "En textfil som ger en HTML-rapport vars siffror räknas om, och Mermaid-scheman.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md`-rapporter",
        summary: "Markdown plus fyra slags körbara block — skriv till vänster, förhandsvisa till höger.",
        keywords: ["rapport", "greport", "html", "export", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                En `.greport.md`-fil är **vanlig Markdown** plus några körbara inhägnade block. Att rita den \
                ger en **självbärande** HTML-fil — inget nät, inga följefiler — som vem som helst kan öppna.
                """),
            .paragraph("""
                Eftersom det är ren text går den att **jämföra, versionera och dela** — samma tanke som med \
                städrecept och kvalitetsregler.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — en fullständig rapport",
                  source: """
                    ---
                    title: Försäljningsrapport för augusti
                    source: sales-2026-08.csv
                    ---

                    # Försäljningsrapport för augusti

                    Siffror per den 31 augusti 2026.

                    ## Intäkt per provins

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Intäkt per provins
                    y_label: Intäkt
                    number_format: vi
                    suffix: " ₫"
                    source: Källa — sales-2026-08.csv
                    ```

                    ## Källdatas kvalitet

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Blockslagen"),
            .table(
                headers: ["Block", "Ger"],
                rows: [
                    ["`query`", "En tabell, ur en SQL-sats för DuckDB"],
                    ["`chart`", "Ett diagram"],
                    ["`quality`", "Ett kvalitetskort för data"],
                    ["`mining`", "En rangordningstabell från utvinning per grupp"],
                    ["`mermaid`", "Ett schema"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                `---`-blocket överst anger `title` och `source` — den förvalda datakällan för varje block som \
                inte anger sin egen.
                """),
            .note("""
                Förhandsvisningen byggs om när ni slutar skriva, men den **tolkar bara**; den kör inte frågor \
                vid varje tangenttryckning. Dokumentfel och datafel rapporteras var för sig — *«chart-blocket \
                saknar nyckeln `kind`»* är ett filfel, *«kolumnen `doanh_thu` finns inte»* är ett datafel.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "`query`-blocket",
        summary: "En DuckDB-sats blir en tabell i rapporten.",
        keywords: ["fråga", "sql", "tabell", "rapport", "block"],
        blocks: [
            .paragraph("""
                Blockets innehåll är **en SQL-sats**, körd på rapportens källa. Tabellen heter `t`, i samma \
                dialekt som i frågepanelen.
                """),
            .code(language: "text", caption: "Ett query-block med parameter",
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
                `:thang` är en **parameter**. Den ges vid ritningen — från skalet med `--param thang=8`, \
                eller ur en listfil när rapporter skapas i sats.
                """),
            .note("""
                Tabeller i en datarapport **bör komma ur ett query-block**, inte skrivas för hand. En tabell \
                skriven för hand räknas inte om när siffrorna ändras, och förr eller senare säger den emot \
                resten av rapporten.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "`chart`-blocket",
        summary: "En YAML-inställning blir ett diagram — och formatets viktigaste regel.",
        keywords: ["diagram", "yaml", "rapport", "rita"],
        blocks: [
            .code(language: "yaml", caption: "Varje nyckel i ett chart-block",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Intäkt per provins
                    x_label: Provins
                    y_label: Intäkt
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Källa — sales.csv, per den 26 augusti 2026
                    """),
            .heading("Utan `query` använder det resultatet från query-blocket DIREKT OVANFÖR"),
            .paragraph("""
                Det är formatets viktigaste regel. Tack vare den upprepar den vanliga rapporten «en tabell och \
                sedan ett diagram över den tabellen» inte SQL:en — och att upprepa den betyder att de två \
                kopiorna till slut glider isär, och då säger tabellen och diagrammet olika saker på samma \
                sida.
                """),
            .warning("""
                I gengäld **spelar blockens ordning roll**: att skjuta in ett query-block emellan ändrar data \
                för diagrammet nedanför.
                """),
            .heading("Varför `source` är en egen nyckel"),
            .paragraph("""
                En källhänvisning skriven som löptext under diagrammet visas alldeles utmärkt — på skärmen. \
                Men diagrammet ska exporteras som PNG och klistras in någon annanstans, och löptexten blir \
                kvar. Som nyckel ritas den **inne i bilden** och följer med den.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "`quality`-blocket",
        summary: "Ett kvalitetskort för data inne i rapporten.",
        keywords: ["kvalitet", "kort", "rapport", "block"],
        blocks: [
            .code(language: "yaml", caption: "Varje nyckel i ett quality-block",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # tomt betyder rapportens egen källa
                    title: Kvalitet på augusti månads försäljningsdata
                    rules: true                 # visa tabellen regel för regel, godkänt/underkänt
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # fastställ referensdatum för «Aktualitet»
                    fail_under: 90              # under detta byter kortet till varningsfärg
                    """),
            .table(
                headers: ["`chart`", "Ritar"],
                rows: [
                    ["`violations`", "Radantalet för de **underkända** reglerna — svarar på «vad ska lagas först»"],
                    ["`dimensions`", "Betygen för de sex dimensionerna"],
                    ["`none`", "Bara tabell, inget diagram"],
                ]
            ),
            .note("""
                Sätt `now:` i en återkommande rapport. Utan det jämför *Aktualitet* med ritningens ögonblick, \
                så att rita om förra månadens rapport ger ett annat betyg än det ni gav ut.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "`mining`-blocket",
        summary: "Rangordna grupper efter avvikelser, prognosfel eller samvariationsavvikelse.",
        keywords: ["utvinning", "rapport", "grupprangordning"],
        blocks: [
            .code(language: "yaml", caption: "Varje nyckel i ett mining-block",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # kolumnen för avvikelser och prognos
                    pair: chi_phi             # en andra kolumn, för samvariation per grupp
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # tomt betyder rapportens egen källa
                    title: Utvinning per provins
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Rangordnar efter"],
                rows: [
                    ["`anomalies`", "Den grupp som har flest avvikande rader"],
                    ["`forecast_error`", "Den grupp vars prognos är sämst"],
                    ["`correlation_gap`", "Den grupp vars samvariation avviker mest från den samlade tabellen — fångar Simpsons paradox"],
                ]
            ),
            .warning("""
                **Ingen nyckel stänger av «Metod»-blocket.** En grupprangordning utan sin metod ger läsaren \
                ingen möjlighet att veta mot vilket staket «flest avvikelser» mättes. Den som vill dölja det \
                känner redan till svaret han vill ha.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Skapa rapporter i sats",
        summary: "En mall, en lista med parametrar, många rapporter.",
        keywords: ["sats", "massvis", "parametrar", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                En rapportmall, körd för varje kontor eller varje månad. Parameterlistan är en CSV- eller \
                JSON-fil — **en rad per rapport**.
                """),
            .code(language: "text", caption: "list.csv — en rad per rapport",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Rita hela satsen från skalet",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Eller en rapport med parametrar givna för hand",
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
        title: "Mermaid-scheman",
        summary: "Rita scheman i text, ändra dem med kommandon, förhandsvisa i takt åt båda hållen.",
        keywords: ["mermaid", "schema", "flödesschema", "sekvens", "rita"],
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
                Mermaid ritar scheman **ur text**: ni skriver en beskrivning och maskinen ritar den. Ett schema \
                går därför att jämföra och versionera — vilket en bildfil inte gör.
                """),
            .paragraph("""
                Öppna `Mermaid-schema: förhandsvisning` för en vy bredvid redigeraren. De två går **i takt åt \
                båda hållen**: markera ett element i bilden, så hoppar markören till dess rad.
                """),
            .heading("Ändra med kommandon, inte genom att skriva om"),
            .table(
                headers: ["Kommando", "Vad det gör"],
                rows: [
                    ["Infoga en mall…", "Infoga ett färdigt skelett för varje schemaslag"],
                    ["Lägg till ett element…", "Lägga till en nod eller en deltagare"],
                    ["Förbind de två markerade elementen", "Rita en pil mellan dem"],
                    ["Ändra det markerade elementets etikett…", "Ändra texten utan att leta upp raden"],
                    ["Radera det markerade elementet", "Ta bort noden **och** varje kant som rör den"],
                    ["Flytta meddelandet upp / ned", "Ordna om stegen i ett sekvensschema"],
                    ["Formatera om", "Dra in och rätta upp hela blocket"],
                ]
            ),
            .heading("Bryta ut till en fil och bädda in igen"),
            .paragraph("""
                Stora scheman hör hemma i en egen `.mmd`-fil: `Bryt ut blocket till en .mmd-fil…` flyttar det \
                och lämnar en hänvisning. `Bädda in den hänvisade filen igen` gör tvärtom när ni måste skicka \
                en enda fil.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Vanlig Mermaid-syntax",
        summary: "De fyra mest använda schemaslagen, vart och ett med en mall som fungerar.",
        keywords: ["mermaid", "syntax", "flödesschema", "sekvens", "gantt", "klasser", "mall"],
        blocks: [
            .code(language: "mermaid", caption: "Flödesschema — ett godkännandeförlopp för order",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Sekvensschema — ett betalningsförlopp",
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
            .code(language: "mermaid", caption: "Klasschema — en datamodell",
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
            .code(language: "mermaid", caption: "Gantt — en utgivningsplan",
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
                headers: ["Nodform", "Skriv"],
                rows: [
                    ["Rektangel", "`A[Label]`"],
                    ["Rundad", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Romb (beslut)", "`A{Label}`"],
                    ["Cylinder (data)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Pil", "Skriv"],
                rows: [
                    ["Heldragen, med spets", "`A --> B`"],
                    ["Prickad", "`A -.-> B`"],
                    ["Tjock", "`A ==> B`"],
                    ["Med etikett", "`A -- label --> B`"],
                ]
            ),
            .note("""
                Ett flödesschemas riktning står direkt efter `flowchart`: `TD` uppifrån och ned, `LR` från \
                vänster till höger, samt `BT` och `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Kunskapspaketet

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Kunskapspaketet",
        summary: "Styckning, sökregister, kunskapsgrafer, entiteter och bedömning av återsökning.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Vad kunskapspaketet är",
        summary: "Verktyg för att förbereda och pröva data åt ett system som svarar på frågor ur dokument.",
        keywords: ["rag", "kunskap", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                När man bygger ett system som besvarar frågor ur en dokumentsamling ligger det mesta av \
                arbetet inte i modellen utan i att **förbereda uppgifterna**: att klippa dokumenten i \
                vettiga stycken, pröva de styckenas kvalitet, bygga ett register och **mäta om \
                återsökningen verkligen hittar rätt sak**.
                """),
            .paragraph("""
                Detta kapitel är just verktygen för det. Det körs **helt på er egen maskin** och rör aldrig \
                nätet.
                """),
            .table(
                headers: ["Uppgift", "Verktyg"],
                rows: [
                    ["Klippa dokument i stycken", "Förhandsvisning av styckning"],
                    ["Granska och betygsätta stycken", "Granskning av JSONL-stycken"],
                    ["Omvandla mellan dataformer", "Kunskapsomvandling"],
                    ["Bygga och granska en relationsgraf", "Kunskapsgraf"],
                    ["Hitta egennamn i text", "Entitetsmärkning"],
                    ["Mäta återsökningens kvalitet", "Återsökningslabbet"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Stycka och granska en JSONL-samling",
        summary: "Förhandsvisa styckgränserna på själva texten och betygsätt sedan hela samlingen.",
        keywords: ["chunk", "jsonl", "samling", "överlapp", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Förhandsvisning av styckning"),
            .paragraph("""
                Öppna ett text- eller Markdown-dokument, välj ett tillvägagångssätt och en styckstorlek. \
                Gränserna **framhävs på själva texten**, så ni ser var ett snitt hamnar mitt i en mening \
                eller genom en tabell innan ni exporterar något.
                """),
            .bullets([
                "**Fast storlek** med överlapp.",
                "**Efter uppbyggnad** — vid Markdown-rubriker, med dokumentets tråd i behåll.",
                "**Efter stycke**, sammanslaget tills storleken nås.",
            ]),
            .heading("Granska en befintlig JSONL-samling"),
            .paragraph("""
                För en samling ni redan har (ett JSON-stycke per rad) svarar `JSONL: granska stycken…`: vilka \
                rader som inte är giltig JSON, vilka stycken som är för korta eller för långa, vilka som \
                dubblerar varandra och vilka som klippts mitt i en mening.
                """),
            .note("""
                En samling går också att betygsätta med **samma ram med sex dimensioner** som tabelldata — \
                använd nyckeln `corpus:` i en rapports `quality`-block.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Omvandla kunskapsformat",
        summary: "Stycken mellan JSONL · CSV · Markdown, grafer mellan DOT · Mermaid · kantlistor.",
        keywords: ["omvandla", "jsonl", "dot", "mermaid", "kantlista"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Från", "Till"],
                rows: [
                    ["JSONL-stycken", "CSV · Markdown"],
                    ["CSV-stycken", "JSONL · Markdown"],
                    ["DOT-graf", "Mermaid · kantlista"],
                    ["Kantlista", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Det finns en **förhandsvisning av fem rader** innan den nya fliken skapas, samma mekanism som \
                vid CSV-omvandlingen.
                """),
            .paragraph("""
                `Öppna tripplar/kanter som tabell` visar en trippelfil eller en kantlista som tabell — \
                filtrera och sortera som i vilken annan CSV som helst.
                """),
            .note("""
                Riktningen **Markdown → JSONL** finns inte i detta kommando: den riktningen *är* styckningen, \
                och kommandot hänvisar er dit. Två utföranden av ett och samma snitt skulle ge två olika \
                resultat.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Kunskapsgrafer",
        summary: "Pröva syntaxen, betygsätt hälsan och kör algoritmer på grafer med en miljon kanter.",
        keywords: ["graf", "dot", "cypher", "pagerank", "louvain", "syntaxprövning"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor läser grafer som **DOT**, som **kantlistor** och som **tripplar**. `Pröva grafsyntaxen` \
                fångar syntaxfel, lösa noder och kanter som pekar på noder som inte finns.
                """),
            .heading("Tillgängliga algoritmer"),
            .table(
                headers: ["Algoritm", "Svarar på"],
                rows: [
                    ["Grannskap på k steg", "Vad som hänger ihop med den här noden inom k steg"],
                    ["Sammanhängande delar", "Hur många åtskilda stycken grafen består av"],
                    ["PageRank", "Vilka noder som är viktiga"],
                    ["Louvain", "Hur grafen delar sig i gemenskaper"],
                ]
            ),
            .paragraph("""
                På en graf med **en miljon kanter** körs alla fyra på mellan några millisekunder och ungefär \
                en sekund.
                """),
            .note("""
                En graf går också att betygsätta med **ramen med sex dimensioner** som används för tabeller och \
                samlingar — använd nyckeln `graph:` i ett `quality`-block.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Märka entiteter ur en lista",
        summary: "Läs in en lista med egennamn och hitta varje förekomst — under tre regler gjorda för vietnamesiskan.",
        keywords: ["entitet", "egennamn", "ner", "märkning", "matchning"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Läs in en lista med namn (företag, varor, platser), så framhäver GEditor varje förekomst i \
                dokumentet, med en tabell över antalen.
                """),
            .heading("Tre matchningsregler, alla ur vietnamesiska data"),
            .bullets([
                "**Längsta träffen vinner.** Med både `An Phát` och `Công ty An Phát` i listan måste en mening som innehåller det längre uttrycket matcha det längre — annars klyvs den itu och räknas som två entiteter, vilket **blåser upp** statistiken.",
                "**Ordgränser krävs.** `An` får inte matcha inne i `Anh` eller `Hoàn`. Vietnamesiska egennamn är korta och delar stavelser med otaliga vanliga ord.",
                "**Okänsligt för versaler, men KÄNSLIGT för diakritiska tecken.** `CÔNG TY` och `Công ty` är ett; `má` och `ma` är det inte.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Reda ut entitetsvarianter",
        summary: "Känna igen `Cty An Phát` och `Công ty An Phát` som ett — men ändå lämna beslutet åt er.",
        keywords: ["entitetsuppredning", "varianter", "namnnormalisering", "dubbletter"],
        blocks: [
            .paragraph("""
                Samma klasindelning som **ungefärliga dubbletter** i en CSV-tabell — ett gemensamt utförande, \
                inte två.
                """),
            .paragraph("""
                Utfallet är ett **förslag**: ni går igenom varje klase och väljer den gällande formen. Det \
                finns ingen knapp för att slå ihop allt, för två namn som liknar varandra till 92 % kan vara \
                två verkliga organisationer.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Återsökningslabbet",
        summary: "Mät om registret hittar rätt sak, med hjälp av en uppsättning frågor med svar.",
        keywords: ["återsökning", "bm25", "recall", "mrr", "ndcg", "bedömning"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Läs in en **bedömningsuppsättning** — varje rad en fråga med numren på de stycken som borde \
                komma tillbaka — och kör sedan hela satsen mot registret.
                """),
            .table(
                headers: ["Mått", "Svarar på"],
                rows: [
                    ["recall@k", "Hur mycket av svarsmängden som dyker upp bland de k översta"],
                    ["MRR", "Hur långt ned det första rätta resultatet ligger"],
                    ["nDCG@k", "Om ordningen är god, med läget inräknat"],
                ]
            ),
            .paragraph("""
                Resultaten kommer också **per fråga**, de sämsta först — det är er lista över vad som ska \
                lagas i samlingen, i den ordning som lönar sig mest.
                """),
            .warning("""
                Alla tre måtten är **medelvärden**, och ett medelvärde döljer mycket. Läs alltid tabellen per \
                fråga innan ni slår fast att «registret är gott nog».
                """),
            .paragraph("""
                Två inställningar går att jämföra sida vid sida, och resultatet faller rakt in i en \
                `.greport.md`-rapport så att nästa körning blir likadan.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Makron och automatisering

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Makron och automatisering",
        summary: "Spela in handlingar, köra dem i sats, skriva skript och styra alltihop från skalet.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Spela in och spela upp makron",
        summary: "Spela in en följd och upprepa den — hela körningen är ett ångra-steg.",
        keywords: ["makro", "spela in", "spela upp", "upprepa", "automatisera"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Börja / sluta spela in"),
                HelpShortcut("⌃P", "Spela upp"),
            ]),
            .steps([
                "`⌃R` börjar inspelningen.",
                "Gör det ni vill upprepa — skriva, flytta markören, söka, ersätta.",
                "`⌃R` igen för att sluta.",
                "`⌃P` spelar upp det, eller `Makro ▸ Spela till dokumentets slut` kör det hela vägen.",
                "`Makro ▸ Spara makro…` ger det ett namn för senare arbetspass.",
            ]),
            .heading("Det spelar in KOMMANDON, inte råa tangenttryckningar"),
            .paragraph("""
                Ett makro sparar **vad ni gjorde**, inte vilka tangenter ni tryckte på. Det gör det oberoende \
                av tangentbordsupplägget och av vilken inmatningsmetod som är på, och det gör makrofilen \
                **läsbar** när ni öppnar den.
                """),
            .heading("När ett makro stannar"),
            .table(
                headers: ["Skäl", "Betydelse"],
                rows: [
                    ["Antalet upprepningar tog slut", "Normalt"],
                    ["Ett `find`-steg hittade ingenting", "Så stannar «spela till filens slut» av sig själv"],
                    ["Dokumentets slut nått", "Ingenstans längre att gå"],
                    ["Ni avbröt", "`Makro ▸ Avbryt makrot som körs`"],
                    ["Ett varv ändrade ingenting och flyttade ingenting", "Stoppat så att det inte går i evig runda"],
                ]
            ),
            .note("Hela körningen — även tiotusen upprepningar — är **ett** ångra-steg."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Köra ett makro i sats",
        summary: "Över alla öppna flikar, eller över en mapp med filer som inte är öppna.",
        keywords: ["sats", "alla flikar", "mapp", "makro", "mask"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Kommando", "Omfattning", "Går att ångra"],
                rows: [
                    ["Kör på alla flikar", "De öppna flikarna", "Ja — ett ångra-steg per flik"],
                    ["Kör över en mapp…", "Filer på disken som **inte är öppna**", "Nej"],
                ]
            ),
            .warning("""
                Att köra över en mapp rör filer som inte är öppna i någon flik, så det finns **ingen \
                ångring**. Som standard **skriver GEditor nya filer** i stället för att skriva över \
                originalen. Behåll den inställningen om ni inte har en säkerhetskopia eller ett \
                versionshanterat arkiv.
                """),
            .heading("Att filtrera filer med en mask"),
            .paragraph("""
                Mappväljaren har ett **filnamnsfilter**: skriv `*.csv;*.log`, så rör makrot bara dem. Det är \
                samma masksyntax som `Sök i en mapp` använder, med flera mönster åtskilda av `;` eller `,`.
                """),
            .bullets([
                "Lämna det **tomt**, så tar det varje textfil GEditor kan läsa — det tidigare beteendet.",
                "Masken **ersätter** den listan av ändelser i stället för att smalna av den ytterligare: skriv `*.bak`, så körs det på `.bak`-filer, fast den ändelsen inte står på textlistan.",
                "Stämmer inget **upprepar meddelandet er mask** i stället för att skylla på en tom mapp.",
            ]),
            .paragraph("""
                Den rutan har ett mycket praktiskt skäl: en mapp rymmer 400 `.json`-filer och 12 `.log`-filer, \
                och ert makro städar bara loggar. Utan mask behandlas även de andra 400 — och eftersom satsen \
                skriver nya filer lämnar ett misstag 400 skräpbitar efter sig.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Makrofilens syntax",
        summary: "Sju slags steg, det fullständiga JSON-formatet och två makron som fungerar.",
        keywords: ["makro", "json", "syntax", "format", "ändra för hand", "dela"],
        blocks: [
            .paragraph("""
                Varje makro är **en egen JSON-fil** i GEditors mapp `macros/`. En skada stannar inom ett \
                makro, och att dela ett med en kollega är att skicka en fil.
                """),
            .code(language: "text", caption: "Var filerna bor",
                  source: "~/Library/Application Support/GEditor/macros/<makronamn>.json"),
            .heading("De sju stegslagen"),
            .table(
                headers: ["Steg", "Skrivs som", "Betydelse"],
                rows: [
                    ["Infoga text", "`{\"insert\": {\"_0\": \"text\"}}`", "Skriva vid markören; med en markering ersätter det den"],
                    ["Radera bakåt", "`{\"deleteBackward\": {}}`", "Som raderingstangenten"],
                    ["Radera framåt", "`{\"deleteForward\": {}}`", "Som ⌦"],
                    ["Flytta", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Se riktningslistan nedan"],
                    ["Markera raden", "`{\"selectLine\": {}}`", "Utan radbrytningen"],
                    ["Söka", "`{\"find\": { … }}`", "Hittar och **markerar** nästa träff"],
                    ["Ersätta markeringen", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` gäller om föregående steg var ett `find` med regex"],
                ]
            ),
            .heading("Flyttriktningar"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Det fullständiga `find`-steget"),
            .code(language: "json", caption: "De fyra nycklarna i ett find-steg",
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
            .paragraph("`mode` tar `normal`, `extended` eller `regex` — samma tre lägen som sökfältet."),
            .heading("Exempel 1 — versalisera provinskoden i radens början"),
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
                Kör det med `Makro ▸ Spela till dokumentets slut`: att `find`-steget inte hittar något mer är \
                just stoppvillkoret.
                """),
            .heading("Exempel 2 — radera raden efter varje rad som innehåller TODO"),
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
                Pröva ett för hand ändrat makro på en kopia först. Ett felskrivet `find`-steg får makrot att \
                stanna genast — det är det ofarliga fallet. Det farliga är ett mönster som träffar bredare än \
                ni trodde och ändrar tusentals ställen inom ett enda ångra-steg.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript-skript",
        summary: "Fyra funktioner, en `.js`-fil, och allt den gör är ett ångra-steg.",
        keywords: ["skript", "javascript", "js", "automatisera", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Lägg en `.js`-fil i GEditors mapp `scripts/` och kör den från `Makro ▸ Skript…`. Ett skript \
                ser exakt **fyra** saker:
                """),
            .table(
                headers: ["Anrop", "Betydelse"],
                rows: [
                    ["`doc.text`", "Hela dokumentets text"],
                    ["`doc.selection`", "Markeringen (tom sträng när inget är markerat)"],
                    ["`doc.replace(s)`", "Ersätta **hela dokumentet** med `s` — ett ångra-steg"],
                    ["`doc.log(s)`", "Skriva en rad i resultatpanelen"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Numrera varje rad.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — behåll de tre första CSV-kolumnerna",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Tre gränser att känna till"),
            .bullets([
                "**Ingen filåtkomst, inget nät, inga processer att starta.** API-ytan är medvetet smal: att vidga den senare är lätt, att smalna av den förstör varje skript användare redan skrivit.",
                "**Detta är ingen säkerhetsgräns.** Skript körs i samma process. Kör inte ett skript ni inte läst.",
                "**Det finns en gräns på fem sekunder.** Ovanför den får ni ett meddelande och programmet förblir brukbart — men det skriptets tråd **fortsätter snurra tills ni avslutar**, och äter en kärna. Meddelandet säger det.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filtrera genom ett yttre kommando",
        summary: "Skicka markeringen genom ett Unix-kommando och ta emot resultatet.",
        keywords: ["filter", "yttre kommando", "skal", "rör", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Markeringen (eller hela dokumentet) ges till ett kommandos `stdin`, och det kommandots \
                `stdout` ersätter den.
                """),
            .code(language: "bash", caption: "Några vanliga",
                  source: """
                    sort -u                     # sortera och rensa dubbletter
                    jq .                        # formatera om JSON
                    tr 'a-z' 'A-Z'              # till versaler
                    grep -v '^#'                # ta bort kommentarrader
                    awk -F, '{print $3","$1}'   # kasta om kolumnernas ordning
                    """),
            .note("""
                Resultatet är **ett** ångra-steg. Ger kommandot en felkod lämnar GEditor texten i fred och \
                visar `stderr`.
                """),
            .warning("""
                Detta kommando finns **bara i utgåvan med direkt hämtning**. App Sandbox förbjuder att köra \
                kod utanför programmet, så i App Store-utgåvan står menyposten kvar och förklarar varför den \
                inte är tillgänglig.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Kommandoradsverktyget `geditor`",
        summary: "Öppna, städa, fråga, betygsätta och rita rapporter — utan att öppna programmet.",
        keywords: ["cli", "kommandorad", "terminal", "geditor", "skript", "ci"],
        blocks: [
            .warning("""
                Finns bara i utgåvan med **direkt hämtning**. App Store-utgåvan körs i en sandlåda, så en \
                yttre kommandoradsprocess kan inte koppla upp sig mot den.
                """),
            .heading("Att öppna filer"),
            .code(language: "bash", caption: "Öppna, hoppa till en position, läsa ur ett rör",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # rad 120, kolumn 5
                    geditor -w notes.md            # vänta tills filen stängs innan avslut
                    geditor -r app.log             # öppna skrivskyddat
                    git diff | geditor             # läs standardindata till en ny flik
                    """),
            .table(
                headers: ["Väljare", "Betydelse"],
                rows: [
                    ["`-w`, `--wait`", "Vänta tills filen stängs innan avslut — för att tjäna som `git`s redigerare"],
                    ["`-n`, `--new-window`", "Öppna i ett nytt fönster"],
                    ["`-r`, `--read-only`", "Öppna skrivskyddat"],
                    ["`-i`, `--info`", "Skriv ut teckenkodning, radbrytningar och radantal, avsluta sedan — **utan** att öppna programmet"],
                    ["`-h`, `--help`", "Visa hjälpen"],
                    ["`-v`, `--version`", "Visa versionen"],
                ]
            ),
            .heading("Att köra utan att öppna programmet"),
            .paragraph("""
                De fyra kommandogrupperna nedan körs **helt inom kommandoradsprocessen**, så de fungerar i CI, \
                där ingen är inloggad i ett grafiskt arbetspass.
                """),
            .code(language: "bash", caption: "Städa med ett recept",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Att fråga",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Kvalitetsgrinden — kod 0 godkänt · 1 underkänt · 2 fel",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Att rita rapporter",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript och menyn Tjänster",
        summary: "Läsa och skriva dokumentet från AppleScript, eller skicka text till GEditor från ett annat program.",
        keywords: ["applescript", "osascript", "tjänster", "automatisering", "kortkommandon"],
        blocks: [
            .code(language: "applescript", caption: "Läsa det öppna dokumentet",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Skriva över innehållet och läsa markeringen",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Öppna en fil",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Menyn Tjänster"),
            .paragraph("""
                Markera text i vilket program som helst och använd sedan menyn `Tjänster` för att skicka den \
                till GEditor som en ny flik.
                """),
            .note("""
                Första gången ni kör AppleScript ber macOS om tillstånd för automatisering. Det är systemets \
                ruta, inte GEditors.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Tilläggspaket och insticksmoduler",
        summary: "Två slags tillägg, och i vilken utgåva vart och ett körs.",
        keywords: ["insticksmodul", "tillägg", "paket", "inbyggd"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Tilläggspaket"),
            .paragraph("""
                Ett paket är **en JSON-fil** som samlar ett tema, skript och egendefinierade språk. Att \
                installera kopierar en fil, att ta bort raderar en — och paketlistan härleds ur **disken**, \
                inte ur ett register som skulle kunna ljuga.
                """),
            .paragraph("Fungerar i **båda utgåvorna**."),
            .heading("Inbyggda insticksmoduler"),
            .paragraph("""
                Förkompilerade insticksmoduler körs i en **egen process** med en smal API-yta — en modul som \
                kraschar drar inte med sig programmet.
                """),
            .warning("""
                Inbyggda insticksmoduler finns **bara i utgåvan med direkt hämtning**, eftersom App Sandbox \
                förbjuder att läsa in kod utanför programmet. Varje modul måste **godkännas för hand en \
                gång**, efter sin kontrollsumma, innan den körs.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Inställningar och programmet

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Inställningar och programmet",
        summary: "Inställningar, kortkommandon, teman, uppdateringar, byte från Notepad++, felsökning.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Inställningar",
        summary: "Varje val bor i en läsbar JSON-fil som ni kan kopiera till en annan Mac.",
        keywords: ["inställningar", "val", "konfiguration", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Öppna inställningarna")]),
            .paragraph("""
                Det finns inget OK och inget Avbryt — en ändring får verkan och skrivs genast, på macOS vis.
                """),
            .heading("Inställningsfilen"),
            .code(language: "text", caption: "Var den bor",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Det är en **indragen JSON-fil ni kan läsa och ändra för hand**. Kopiera den till en annan Mac, \
                så följer hela er uppsättning med. Knappen `Öppna inställningsfilen` i inställningarna för er \
                dit direkt.
                """),
            .heading("Nycklarna"),
            .table(
                headers: ["Nyckel", "Standard", "Betydelse"],
                rows: [
                    ["`fontSize`", "`13`", "Redigerarens teckenstorlek"],
                    ["`tabWidth`", "`4`", "Hur många kolumner bred en tabb är"],
                    ["`usesTabsForIndent`", "`false`", "Dra in med tabbar i stället för blanksteg"],
                    ["`languageIndent`", "`{}`", "Indrag per språk — se sidan om blanktecken"],
                    ["`smartIndent`", "`true`", "Automatiskt indrag på en ny rad"],
                    ["`highlightAllMatches`", "`true`", "Framhäv varje sökträff"],
                    ["`ligatures`", "`false`", "Ligaturer — se anmärkningen under tabellen"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Klipp blanktecken i radslutet vid sparande"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalisera Unicode till NFC vid sparande"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Teckenkodning för nya filer"],
                    ["`defaultEOL`", "`\"lf\"`", "Radbrytningar för nya filer"],
                    ["`language`", "`\"system\"`", "Gränssnittets språk"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "standardtemat", "Vilket färgtema som används"],
                    ["`showWelcomeOnLaunch`", "`true`", "Öppna välkomstfönstret vid start"],
                    ["`keyBindings`", "`{}`", "Bara de tangenter ni ändrat"],
                ]
            ),
            .note("""
                **Varför ligaturer är AV som standard.** En ligatur smälter `!=` eller `->` till **ett** \
                tecken, så tecknen ni ser på skärmen svarar inte längre mot tecknen i filen — och \
                kolumnredigeraren, kolumnläget och brytning vid en kolumn mäter allihop i kolumner. Slå på \
                dem när ni skriver löptext, eller om ni valt ett programmerarsnitt (Fira Code, JetBrains \
                Mono) just för dess ligaturer.
                """),
            .heading("Grannmapparna"),
            .table(
                headers: ["Mapp", "Rymmer"],
                rows: [
                    ["`macros/`", "Sparade makron, en JSON-fil var"],
                    ["`scripts/`", "JavaScript-skript"],
                    ["`themes/`", "Färgteman"],
                    ["`grammars/`", "Egendefinierade språk"],
                ]
            ),
            .warning("""
                En inställningsfil skriven av ett **nyare** GEditor **skrivs inte över** av ett äldre — det \
                senare kör på standardvärden och säger det. Att skriva över är det säkraste sättet att \
                förstöra uppsättningen för någon som håller två maskiner i takt, och han skulle aldrig få \
                veta varför.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Statusraden",
        summary: "Tio delar längst ner — alla läsbara och alla klickbara.",
        keywords: ["statusrad", "position", "teckenkodning", "skrivskyddad", "storlek"],
        blocks: [
            .paragraph("""
                Detta är den största skillnaden mot andra redigerares statusrader: **ingen del är \
                skrivskyddad**. Ser ni ett fel värde är ett klick på det sättet att rätta det, i stället för \
                att leta genom menyer.
                """),
            .table(
                headers: ["Del", "Säger er", "Vid klick"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "markörens läge — kolumnen i TECKEN, `@340` bytepositionen",
                     "öppnar fältet `Gå till`"],
                    ["`11 byte · 3 dòng`", "dokumentets storlek",
                     "räknar byte · tecken · ord · rader"],
                    ["`🔒 Chỉ đọc`", "visas bara när dokumentet är låst",
                     "säger VARFÖR det är låst och låser upp när det går"],
                    ["`View` / `Code`", "vilken vy ni är i", "växlar (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "CSV-läge och avgränsaren som används",
                     "slår om CSV-läget, eller **väljer avgränsare på nytt**"],
                    ["`Đang theo dõi`", "`tail -f` pågår", "—"],
                    ["`UTF-8`", "teckenkodningen", "tolka om, eller omvandla till en annan teckenkodning"],
                    ["`LF`", "radbrytningsstil", "växla LF · CRLF · CR"],
                    ["`Python`", "språk för syntaxfärgningen", "välja ett annat, eller tillbaka till igenkänning på ändelse"],
                    ["`Tab: 4`", "indragets bredd", "2 · 4 · 8, allmänt eller **bara för detta språk**"],
                    ["`Ngắt: tắt`", "radbrytningsläge", "går genom de tre lägena"],
                ]
            ),
            .heading("Tre delar värda en andra blick"),
            .bullets([
                "**`@340` — bytepositionen.** Det är det tal varje annat verktyg i programmet talar: JSON- och XML-fel, utdatan från `--doc-sweep`, den binära vyn och fältet `Gå till @340`. Läs det här, skriv det där.",
                "**Ett `~` vid kolumnen** betyder att talet räknar BYTE och inte synliga kolumner — det händer bara på rader längre än 200 KB, där teckenräkning skulle sinka varje markörflytt.",
                "**`CSV · …` går att klicka för att välja avgränsare på nytt.** Igenkänningen kan slå fel, och då är varje kolumnåtgärd förskjuten utan att något signalerar det. Så säger ni emot — det bara LÄSER OM filen, utan att ändra en byte (till skillnad från `CSV ▸ Byt avgränsare…`, som skriver om den).",
            ]),
            .note("""
                En del som inte rör den öppna filen är **dold**, inte grå: `Skrivskyddad` visas bara när \
                dokumentet verkligen är låst, och `CSV · …` bara i CSV-läge.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Ändra kortkommandon",
        summary: "Ändra enstaka tangenter, eller ta över Notepad++ uppsättning i sin helhet.",
        keywords: ["kortkommando", "tangentuppsättning", "förinställning"],
        blocks: [
            .paragraph("""
                `Inställningar…` har en avdelning Kortkommandon med två snabbknappar: **Använd \
                Notepad++-förinställningen** och **Tillbaka till standardvärdena**.
                """),
            .paragraph("""
                Inställningsfilen antecknar bara det ni **ändrat mot standardvärdena**. Så när GEditor ändrar \
                en standardtangent i en ny version blir ni inte sittande med den gamla uppsättningen utan att \
                någon säger till.
                """),
            .note("""
                Två kommandon får inte dela kortkommando. När de gör det utlöser AppKit tyst bara den \
                **första** menyposten och det andra kommandot verkar trasigt — därför har GEditor en \
                kontroll som hindrar det.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Teman, ljust och mörkt",
        summary: "Följ systemet, ljust eller mörkt; och ett tema är en JSON-fil ni kan ändra.",
        keywords: ["tema", "färger", "mörkt läge", "ljust", "utseende"],
        blocks: [
            .paragraph("`Inställningar…` väljer `Följ systemet`, `Ljust` eller `Mörkt`, och pekar ut ett färgtema."),
            .paragraph("""
                Ett tema är en JSON-fil i `themes/`. Knappen `Exportera nuvarande tema` skriver ut ett som \
                utgångspunkt för ert eget.
                """),
            .note("""
                En felskriven färg i en temafil faller tillbaka på **standardtemats** färg, inte på svart. \
                Svart ser ut som ett formgivningsbeslut, och användaren skulle leta efter felet någon \
                annanstans.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Uppdateringar, versioner och avslut",
        summary: "Vari uppdateringen skiljer sig mellan de två utgåvorna.",
        keywords: ["uppdatering", "version", "om", "avsluta"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Utgåva", "Uppdateras via"],
                rows: [
                    ["App Store", "App Store, som varje annat program"],
                    ["Direkt hämtning", "`Sök efter uppdateringar…` inne i programmet"],
                ]
            ),
            .paragraph("""
                `Om GEditor` visar den körande versionen och vilken utgåva det är — bra när man rapporterar ett \
                fel.
                """),
            .note("""
                I App Store-utgåvan **står `Sök efter uppdateringar…` kvar i menyn** och förklarar varför det \
                inte gäller, i stället för att försvinna. En saknad menypost blir en fråga till supporten.
                """),
            .paragraph("Att avsluta förlorar inget arbete: arbetspasset kommer tillbaka nästa gång ni öppnar."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Att bruka detta hjälpfönster",
        summary: "Söka i boken, byta dess språk och hämta tillbaka välkomstfönstret.",
        keywords: ["hjälp", "handledning", "sökning", "välkomst", "språk"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Öppna hjälpfönstret")]),
            .bullets([
                "Sökfältet uppe till vänster tittar i **brödtext och kodexempel** — att skriva en naken konfigurationsnyckel som `fail_under` leder till rätt sida.",
                "Att skriva **utan tecken** hittar ändå text med dem.",
                "Knappen `Tillbaka` går till föregående sida.",
                "Knappen `Kopiera` vid varje kodblock kopierar det blocket.",
            ]),
            .heading("Att läsa på ett annat språk"),
            .paragraph("""
                Menyn uppe till höger i detta fönster väljer **bokens språk**, oberoende av gränssnittets \
                språk. Bytet håller er kvar **på den sida ni läser** — sidornas beteckningar översätts med \
                flit inte, just för att detta ska fungera.
                """),
            .note("""
                Bara språk som verkligen har en bok räknas upp. En menypost som byter till något och lämnar \
                texten oförändrad vore en menypost som ljuger.
                """),
            .heading("Att hämta tillbaka välkomstfönstret"),
            .paragraph("""
                Har ni kryssat för **Öppna inte detta fönster vid start**, öppna det igen med `Hjälp ▸ Rundtur \
                bland funktionerna` — rutan längst ner i fönstret dyker upp igen och går att kryssa ur.
                """),
            .paragraph("Eller sätt tillbaka `showWelcomeOnLaunch` till `true` i `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Från Notepad++ till GEditor",
        summary: "Vilka tangenter som byter plats, vad som fungerar annorlunda och vad som saknas.",
        keywords: ["notepad++", "byte", "windows", "kortkommandon"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Några tangenter **byter plats** på macOS i stället för att bara byta `Ctrl` mot `⌘`. Här är \
                jämförelsen.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Varför"],
                rows: [
                    ["`Ctrl+D` Dubblera rad", "**⇧⌘D**", "Här är `⌘D` flermarkör, som i varje Mac-redigerare"],
                    ["`Ctrl+L` Radera rad", "**⌘K**", "På macOS betyder `⌘L` «gå till rad»"],
                    ["`Ctrl+G` Gå till rad", "**⌘L**", "De två byter plats"],
                    ["`Ctrl+Q` Kommentera", "**⌘/**", "macOS sedvänja"],
                    ["`Ctrl+Shift+↑/↓` Flytta rad", "**⌥↑ / ⌥↓**", "På macOS hör `⌃` till Mission Control"],
                    ["`F3` Sök nästa", "**⌘G**", "macOS sedvänja"],
                    ["`Ctrl+F2` Slå om bokmärke", "**⌘F2**", "F2 och ⇧F2 hoppar fortfarande mellan markeringar"],
                    ["`Alt` + dra för kolumner", "**⌥ + dra**", "Likadant"],
                    ["`Ctrl+Alt+Shift+↓` Kolumnredigerare", "**⌥⌘C**", "macOS sedvänja"],
                ]
            ),
            .note("Vill ni hellre slippa lära om? `Inställningar ▸ Kortkommandon ▸ Använd Notepad++-förinställningen`."),
            .heading("Saker Notepad++ har som fungerar annorlunda här"),
            .bullets([
                "**Arbetspass** återställer sig själva, även osparade flikar — inget att slå på.",
                "**Bokmärken har nio färger**, och en rad kan bära flera samtidigt.",
                "**Dokumentkartan** beskriver *hela* filen, inte bara den synliga delen.",
                "**Makron** kan köras «till dokumentets slut» och «över alla flikar», och en hel körning är ett ångra-steg.",
            ]),
            .heading("Vad GEditor lägger till"),
            .bullets([
                "En **städbänk för data** och **dataprofiler** för CSV-filer.",
                "**SQL-frågor** rakt på en CSV-fil.",
                "**Gamla vietnamesiska teckenkodningar** — TCVN3, VISCII, VNI-Windows, lästa, skrivna och igenkända av sig själva.",
                "**Sökning okänslig för diakritiska tecken** i varje filterfält.",
                "**`.greport.md`-rapporter** med tabeller och diagram som räknas om.",
                "**Kommandoradsverktyget `geditor`** i utgåvan med direkt hämtning.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Vanliga problem",
        summary: "Sex lägen som får folk att tro att programmet är trasigt.",
        keywords: ["fel", "problem", "fungerar inte", "felsöka", "varför"],
        blocks: [
            .table(
                headers: ["Symptom", "Vanlig orsak"],
                rows: [
                    ["Vietnamesisk text visas som kråkfötter", "Fel teckenkodning — klicka på teckenkodningen i statusraden"],
                    ["Att söka text med tecken hittar ingenting", "Filen är i uppdelad Unicode — kör `Normalisera Unicode` till NFC"],
                    ["En menypost är grå", "App Store-utgåvan kan inte köra det kommandot — posten förklarar varför"],
                    ["Parentesmatchningen avstår", "Dokumentet är större än 1 MB — att markera fel par är värre än inget"],
                    ["Kolumnen i statusraden har ett `~`", "Dokumentet är större än 200 KB, så det är ett byteantal, inte en synlig kolumn"],
                    ["En SQL-fråga säger att man måste spara först", "DuckDB läser **filer**, inte bufferten ni redigerar"],
                ]
            ),
            .heading("När GEditor avslutas oväntat"),
            .paragraph("""
                Vid nästa start säger en banderoll det, med en knapp **Öppna redogörelsen** — redogörelsen \
                öppnas som en flik ni kan läsa och kopiera ur som ur vilken textfil som helst.
                """),
            .bullets([
                "Redogörelsen bär bara **versionen, macOS-utgåvan, maskinens byggnad, signalens namn och anropsstacken**.",
                "**Inget dokumentinnehåll, och inga filsökvägar heller** — en sökväg som `~/Skrivbord/löner-december.xlsx` har redan avslöjat tre privata saker innan någon öppnat den.",
                "**Ingenting skickas någonstans.** Det finns ingen automatisk uppladdning och ingen server som tar emot; filen ligger kvar i `~/Library/Application Support/GEditor/crash/` tills ni öppnar eller raderar den.",
                "När ni väl öppnat redogörelsen nämner nästa start den inte igen.",
            ]),
            .heading("Var man tittar härnäst"),
            .bullets([
                "Statusraden visar teckenkodning, radbrytningar, språk och brytningsläge — varje del är klickbar.",
                "`settings.json` går att ändra för hand när inställningsfönstret inte räcker.",
                "`Om GEditor` ger versionen och utgåvan, som en felanmälan behöver.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
