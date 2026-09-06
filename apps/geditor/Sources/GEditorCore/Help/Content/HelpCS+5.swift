import Foundation

/// Česká nápověda — část 5: zprávy, znalosti, automatizace a aplikace.
extension HelpCS {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Zprávy a diagramy",
        summary: "Textový soubor, který dá zprávu v HTML s přepočítanými čísly, plus diagramy Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "Zprávy `.greport.md`",
        summary: "Markdown plus čtyři druhy spustitelných bloků — piště vlevo, náhled vpravo.",
        keywords: ["zpráva", "greport", "html", "export", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Soubor `.greport.md` je **obyčejný Markdown** plus několik spustitelných ohrazených \
                bloků. Jeho vykreslení dá **samostatný** soubor HTML — žádná síť, žádné doprovodné \
                soubory — který otevře kdokoli.
                """),
            .paragraph("""
                Protože je to prostý text, lze ho **porovnávat, verzovat a sdílet** — stejná myšlenka \
                jako u čisticích receptů a sad pravidel kvality.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — úplná zpráva",
                  source: """
                    ---
                    title: Srpnová zpráva o prodeji
                    source: sales-2026-08.csv
                    ---

                    # Srpnová zpráva o prodeji

                    Čísla k 31. srpnu 2026.

                    ## Tržby podle provincie

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Tržby podle provincie
                    y_label: Tržby
                    number_format: vi
                    suffix: " ₫"
                    source: Zdroj — sales-2026-08.csv
                    ```

                    ## Kvalita zdrojových dat

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Druhy bloků"),
            .table(
                headers: ["Blok", "Vytvoří"],
                rows: [
                    ["`query`", "Tabulku z příkazu SQL pro DuckDB"],
                    ["`chart`", "Graf"],
                    ["`quality`", "Kartu kvality dat"],
                    ["`mining`", "Pořadovou tabulku z dolování po skupinách"],
                    ["`mermaid`", "Diagram"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                Blok `---` nahoře deklaruje `title` a `source` — výchozí zdroj dat pro každý blok, který \
                si neuvede vlastní.
                """),
            .note("""
                Náhled se přestaví, jakmile přestanete psát, ale jen **parsuje**; nespouští dotazy při \
                každém stisku klávesy. Chyby dokumentu a chyby dat se hlásí zvlášť — *»bloku chart chybí \
                klíč `kind`«* je chyba souboru, *»sloupec `doanh_thu` neexistuje«* je chyba dat.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "Blok `query`",
        summary: "Jeden příkaz DuckDB se stane jednou tabulkou ve zprávě.",
        keywords: ["dotaz", "sql", "tabulka", "zpráva", "blok"],
        blocks: [
            .paragraph("""
                Obsahem bloku je **jeden příkaz SQL**, spuštěný proti zdroji zprávy. Tabulka se jmenuje \
                `t`, ve stejném dialektu jako v panelu dotazů.
                """),
            .code(language: "text", caption: "Blok query s parametrem",
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
                `:thang` je **parametr**. Dodává se při vykreslení — z shellu pomocí `--param thang=8`, \
                nebo ze souboru se seznamem při dávkovém generování zpráv.
                """),
            .note("""
                Tabulky v datové zprávě **by měly pocházet z bloku query**, ne být psány ručně. Ručně \
                psaná tabulka se při změně čísel nepřepočítá a dříve nebo později si se zbytkem zprávy \
                odporuje.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "Blok `chart`",
        summary: "Nastavení v YAML se stane grafem — a nejdůležitější pravidlo formátu.",
        keywords: ["graf", "yaml", "zpráva", "kreslit"],
        blocks: [
            .code(language: "yaml", caption: "Každý klíč bloku chart",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Tržby podle provincie
                    x_label: Provincie
                    y_label: Tržby
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Zdroj — sales.csv, k 26. srpnu 2026
                    """),
            .heading("Bez `query` použije výsledek bloku query BEZPROSTŘEDNĚ NAD SEBOU"),
            .paragraph("""
                Tohle je nejdůležitější pravidlo formátu. Díky němu běžná zpráva »tabulka a pak graf té \
                tabulky« neopakuje SQL — a opakovat ho znamená, že se ty dvě kopie nakonec rozejdou, a \
                pak tabulka a graf říkají na téže stránce různé věci.
                """),
            .warning("""
                Na oplátku **na pořadí bloků záleží**: vložení bloku query mezi ně změní data grafu pod \
                ním.
                """),
            .heading("Proč je `source` vlastním klíčem"),
            .paragraph("""
                Zdrojová poznámka napsaná jako běžný text pod grafem se zobrazí naprosto dobře — na \
                obrazovce. Jenže graf se vyexportuje jako PNG a vloží jinam a ten text zůstane vzadu. \
                Jako klíč se vykreslí **dovnitř obrázku** a cestuje s ním.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "Blok `quality`",
        summary: "Karta kvality dat uvnitř zprávy.",
        keywords: ["kvalita", "karta", "zpráva", "blok"],
        blocks: [
            .code(language: "yaml", caption: "Každý klíč bloku quality",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # prázdné znamená vlastní zdroj zprávy
                    title: Kvalita srpnových prodejních dat
                    rules: true                 # ukázat tabulku pravidlo po pravidle, prošlo/neprošlo
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # ukotvit referenční datum pro "Aktuálnost"
                    fail_under: 90              # pod tím karta zčervená varovnou barvou
                    """),
            .table(
                headers: ["`chart`", "Kreslí"],
                rows: [
                    ["`violations`", "Počty řádků u pravidel, která **neprošla** — odpovídá na »co opravit první«"],
                    ["`dimensions`", "Skóre šesti rozměrů"],
                    ["`none`", "Jen tabulku, žádný graf"],
                ]
            ),
            .note("""
                V opakující se zprávě nastavte `now:`. Bez toho *Aktuálnost* porovnává s okamžikem \
                vykreslení, takže opětovné vykreslení minulé měsíční zprávy dá jiné skóre než to, které \
                jste vydali.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "Blok `mining`",
        summary: "Seřaďte skupiny podle odchylek, chyby předpovědi nebo rozchodu korelace.",
        keywords: ["dolování", "zpráva", "pořadí skupin"],
        blocks: [
            .code(language: "yaml", caption: "Každý klíč bloku mining",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # sloupec pro odchylky a předpověď
                    pair: chi_phi             # druhý sloupec, pro korelaci po skupinách
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # prázdné znamená vlastní zdroj zprávy
                    title: Dolování podle provincie
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Řadí podle"],
                rows: [
                    ["`anomalies`", "Skupiny s nejvíce odlehlými řádky"],
                    ["`forecast_error`", "Skupiny, jejíž předpověď je nejhorší"],
                    ["`correlation_gap`", "Skupiny, jejíž korelace se nejvíc rozchází se sloučenou tabulkou — zachytí Simpsonův paradox"],
                ]
            ),
            .warning("""
                **Žádný klíč blok »Metoda« nevypne.** Pořadí skupin bez své metody nedává čtenáři žádnou \
                možnost zjistit, proti jakému plotu se »nejvíc odchylek« měřilo. Kdo to chce skrýt, už \
                zná odpověď, kterou si přeje.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Dávkové generování zpráv",
        summary: "Jedna šablona, jeden seznam parametrů, mnoho zpráv.",
        keywords: ["dávka", "hromadně", "parametry", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Jedna šablona zprávy, spuštěná pro každou pobočku nebo každý měsíc. Seznam parametrů je \
                soubor CSV nebo JSON — **jeden řádek na zprávu**.
                """),
            .code(language: "text", caption: "list.csv — jeden řádek na zprávu",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Vykreslit celou dávku z shellu",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Nebo jednu zprávu s ručně zadanými parametry",
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
        title: "Diagramy Mermaid",
        summary: "Kreslete diagramy textem, upravujte je příkazy, náhled v souhře oběma směry.",
        keywords: ["mermaid", "diagram", "vývojový diagram", "sekvence", "kreslit"],
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
                Mermaid kreslí diagramy **z textu**: napíšete popis a stroj ho nakreslí. Diagram lze \
                proto porovnávat a verzovat — což obrázkový soubor neumí.
                """),
            .paragraph("""
                Otevřete `Diagram Mermaid: náhled` a získáte pohled vedle editoru. Ty dva jsou **v \
                souhře oběma směry**: vyberte prvek v obrázku a kurzor skočí na jeho řádek.
                """),
            .heading("Upravujte příkazy, ne přepisováním"),
            .table(
                headers: ["Příkaz", "Co dělá"],
                rows: [
                    ["Vložit šablonu…", "Vloží hotovou kostru pro každý druh diagramu"],
                    ["Přidat prvek…", "Přidá uzel nebo účastníka"],
                    ["Spojit dva vybrané prvky", "Nakreslí mezi nimi šipku"],
                    ["Upravit popisek vybraného prvku…", "Změní text bez hledání řádku"],
                    ["Smazat vybraný prvek", "Odstraní uzel **i** každou hranu, která se ho dotýká"],
                    ["Posunout zprávu nahoru / dolů", "Přeuspořádá kroky v sekvenčním diagramu"],
                    ["Přeformátovat", "Odsadí a srovná celý blok"],
                ]
            ),
            .heading("Vyčlenění do souboru a vložení zpět"),
            .paragraph("""
                Velké diagramy patří do vlastního souboru `.mmd`: `Vyčlenit blok do souboru .mmd…` ho \
                přesune ven a zanechá odkaz. `Vložit odkazovaný soubor zpět` udělá opak, když je třeba \
                poslat jediný soubor.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Běžná syntaxe Mermaid",
        summary: "Čtyři nejužívanější druhy diagramů, každý s fungující šablonou.",
        keywords: ["mermaid", "syntaxe", "vývojový diagram", "sekvence", "gantt", "třídy", "šablona"],
        blocks: [
            .code(language: "mermaid", caption: "Vývojový diagram — schvalování objednávky",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Sekvenční diagram — průběh platby",
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
            .code(language: "mermaid", caption: "Diagram tříd — datový model",
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
            .code(language: "mermaid", caption: "Gantt — plán vydání",
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
                headers: ["Tvar uzlu", "Napište"],
                rows: [
                    ["Obdélník", "`A[Label]`"],
                    ["Zaoblený", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Kosočtverec (rozhodnutí)", "`A{Label}`"],
                    ["Válec (data)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Šipka", "Napište"],
                rows: [
                    ["Plná, s hrotem", "`A --> B`"],
                    ["Tečkovaná", "`A -.-> B`"],
                    ["Tlustá", "`A ==> B`"],
                    ["S popiskem", "`A -- label --> B`"],
                ]
            ),
            .note("""
                Směr vývojového diagramu jde hned za `flowchart`: `TD` shora dolů, `LR` zleva doprava, \
                plus `BT` a `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Znalostní balík

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Znalostní balík",
        summary: "Dělení na kusy, vyhledávací rejstříky, znalostní grafy, entity a hodnocení vyhledávání.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Co je znalostní balík",
        summary: "Nástroje pro přípravu a prověření dat pro systém odpovídající na otázky z dokumentů.",
        keywords: ["rag", "znalosti", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Když stavíte systém, který odpovídá na otázky ze sbírky dokumentů, většina práce není v \
                modelu, ale v **přípravě dat**: v rozřezání dokumentů na rozumné úseky, v prověření \
                kvality těch úseků, ve stavbě rejstříku a v **měření, zda vyhledávání skutečně najde tu \
                správnou věc**.
                """),
            .paragraph("""
                Tato kapitola je právě sada nástrojů na to. Běží **zcela na vašem stroji** a nikdy se \
                nedotkne sítě.
                """),
            .table(
                headers: ["Úkol", "Nástroj"],
                rows: [
                    ["Rozřezat dokumenty na úseky", "Náhled dělení"],
                    ["Prohlédnout a ohodnotit úseky", "Prohlídka úseků JSONL"],
                    ["Převádět mezi tvary dat", "Převod znalostí"],
                    ["Postavit a prohlédnout graf vztahů", "Znalostní graf"],
                    ["Najít vlastní jména v textu", "Označení entit"],
                    ["Změřit kvalitu vyhledávání", "Laboratoř vyhledávání"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Dělení a prohlídka sbírky JSONL",
        summary: "Prohlédněte si hranice úseků přímo na textu a pak ohodnoťte celou sbírku.",
        keywords: ["chunk", "jsonl", "sbírka", "překryv", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Náhled dělení"),
            .paragraph("""
                Otevřete textový dokument nebo Markdown, zvolte přístup a velikost úseku. Hranice se \
                **zvýrazní přímo na textu**, takže vidíte, kde řez padne doprostřed věty nebo skrz \
                tabulku, ještě než cokoli vyexportujete.
                """),
            .bullets([
                "**Pevná velikost** s překryvem.",
                "**Podle struktury** — na nadpisech Markdownu, se zachovanou nití dokumentu.",
                "**Po odstavcích**, slučovaných až do dosažení velikosti.",
            ]),
            .heading("Prohlídka existující sbírky JSONL"),
            .paragraph("""
                U sbírky, kterou už máte (jeden úsek JSON na řádek), `JSONL: prohlédnout úseky…` \
                odpoví: které řádky nejsou platný JSON, které úseky jsou příliš krátké či dlouhé, které \
                se navzájem opakují a které byly rozříznuty uprostřed věty.
                """),
            .note("""
                Sbírku lze také ohodnotit **týmž rámcem šesti rozměrů** jako tabulková data — použijte \
                klíč `corpus:` v bloku `quality` zprávy.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Převod znalostních formátů",
        summary: "Úseky mezi JSONL · CSV · Markdown, grafy mezi DOT · Mermaid · seznamy hran.",
        keywords: ["převést", "jsonl", "dot", "mermaid", "seznam hran"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Z", "Do"],
                rows: [
                    ["Úseky JSONL", "CSV · Markdown"],
                    ["Úseky CSV", "JSONL · Markdown"],
                    ["Graf DOT", "Mermaid · seznam hran"],
                    ["Seznam hran", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Před vytvořením nové karty je **náhled pěti řádků**, stejný mechanismus jako u převodu \
                CSV.
                """),
            .paragraph("""
                `Otevřít trojice/hrany jako tabulku` ukáže soubor trojic nebo seznam hran jako tabulku \
                — filtrujte a řaďte jako u jakéhokoli jiného CSV.
                """),
            .note("""
                Směr **Markdown → JSONL** v tomto příkazu není: ten směr *je* dělení a příkaz vás tam \
                odkáže. Dvě provedení jednoho a téhož řezu by dala dva různé výsledky.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Znalostní grafy",
        summary: "Zkontrolujte syntaxi, ohodnoťte zdraví a spusťte algoritmy na grafech s milionem hran.",
        keywords: ["graf", "dot", "cypher", "pagerank", "louvain", "kontrola syntaxe"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor čte grafy jako **DOT**, jako **seznamy hran** a jako **trojice**. `Zkontrolovat \
                syntaxi grafu` odhalí chyby syntaxe, osamocené uzly a hrany mířící na neexistující uzly.
                """),
            .heading("Dostupné algoritmy"),
            .table(
                headers: ["Algoritmus", "Odpovídá na"],
                rows: [
                    ["Okolí do k kroků", "Co s tímto uzlem souvisí do k kroků"],
                    ["Souvislé komponenty", "Z kolika oddělených kusů se graf skládá"],
                    ["PageRank", "Které uzly jsou důležité"],
                    ["Louvain", "Jak se graf dělí na komunity"],
                ]
            ),
            .paragraph("""
                Na grafu s **milionem hran** běží všechny čtyři někde mezi několika milisekundami a asi \
                sekundou.
                """),
            .note("""
                Graf lze také ohodnotit **rámcem šesti rozměrů** používaným pro tabulky a sbírky — \
                použijte klíč `graph:` v bloku `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Označení entit ze seznamu",
        summary: "Načtěte seznam vlastních jmen a najděte každý výskyt — podle tří pravidel dělaných pro vietnamštinu.",
        keywords: ["entita", "vlastní jméno", "ner", "označení", "porovnávání"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Načtěte seznam jmen (firmy, produkty, místa) a GEditor zvýrazní každý výskyt v dokumentu \
                spolu s tabulkou počtů.
                """),
            .heading("Tři pravidla porovnávání, všechna z vietnamských dat"),
            .bullets([
                "**Vyhrává nejdelší shoda.** Když je v seznamu `An Phát` i `Công ty An Phát`, musí věta obsahující delší obrat odpovídat tomu delšímu — jinak se rozpadne vejpůl a započítá se jako dvě entity, což statistiku **nafoukne**.",
                "**Vyžadují se hranice slov.** `An` nesmí odpovídat uvnitř `Anh` ani `Hoàn`. Vietnamská vlastní jména jsou krátká a sdílejí slabiky s nesčetnými běžnými slovy.",
                "**Nezáleží na velikosti písmen, ale ZÁLEŽÍ na diakritice.** `CÔNG TY` a `Công ty` jsou jedno; `má` a `ma` nejsou.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Rozřešení variant entit",
        summary: "Rozpoznejte `Cty An Phát` a `Công ty An Phát` jako jedno — a rozhodnutí přesto ponechte vám.",
        keywords: ["rozřešení entit", "varianty", "normalizace jmen", "duplicity"],
        blocks: [
            .paragraph("""
                Totéž shlukování jako **neostré duplicity** v tabulce CSV — jedna společná implementace, \
                ne dvě.
                """),
            .paragraph("""
                Výstup je **návrh**: projdete každý shluk a zvolíte kanonický tvar. Tlačítko »sloučit \
                vše« neexistuje, protože dvě jména podobná z 92 % mohou být dvě skutečné organizace.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Laboratoř vyhledávání",
        summary: "Změřte, zda rejstřík najde tu správnou věc, pomocí sady otázek s odpověďmi.",
        keywords: ["vyhledávání", "bm25", "recall", "mrr", "ndcg", "hodnocení"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Načtěte **hodnoticí sadu** — každý řádek otázka s identifikátory úseků, které by se měly \
                vrátit — a pak spusťte celou dávku proti rejstříku.
                """),
            .table(
                headers: ["Metrika", "Odpovídá na"],
                rows: [
                    ["recall@k", "Kolik z množiny odpovědí se objeví mezi k nejlepšími"],
                    ["MRR", "Jak hluboko leží první správný výsledek"],
                    ["nDCG@k", "Zda je pořadí dobré, včetně polohy"],
                ]
            ),
            .paragraph("""
                Výsledky přicházejí i **po otázkách**, nejhorší první — to je váš seznam toho, co ve \
                sbírce opravit, v pořadí, ve kterém se to nejvíc vyplatí.
                """),
            .warning("""
                Všechny tři metriky jsou **průměry** a průměr toho hodně skryje. Než usoudíte, že \
                »rejstřík je dost dobrý«, vždy si přečtěte tabulku po otázkách.
                """),
            .paragraph("""
                Dvě nastavení lze porovnat vedle sebe a výsledek padne rovnou do zprávy `.greport.md`, \
                takže příští běh bude totožný.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Makra a automatizace

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Makra a automatizace",
        summary: "Nahrávejte akce, spouštějte je dávkově, pište skripty a řiďte to celé z shellu.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Nahrávání a přehrávání maker",
        summary: "Nahrajte sled a opakujte ho — celý běh je jeden krok zpět.",
        keywords: ["makro", "nahrát", "přehrát", "opakovat", "automatizovat"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Začít / ukončit nahrávání"),
                HelpShortcut("⌃P", "Přehrát"),
            ]),
            .steps([
                "`⌃R` začne nahrávat.",
                "Udělejte to, co chcete opakovat — psaní, pohyb kurzoru, hledání, nahrazení.",
                "`⌃R` znovu pro ukončení.",
                "`⌃P` to přehraje, nebo `Makro ▸ Přehrát do konce dokumentu` to spustí až na konec.",
                "`Makro ▸ Uložit makro…` mu dá jméno pro pozdější sezení.",
            ]),
            .heading("Nahrává PŘÍKAZY, ne holé stisky kláves"),
            .paragraph("""
                Makro ukládá **to, co jste udělali**, ne to, které klávesy jste stiskli. Tím je \
                nezávislé na rozložení klávesnice i na tom, která metoda vstupu je zapnutá, a soubor \
                makra je při otevření **čitelný**.
                """),
            .heading("Kdy se makro zastaví"),
            .table(
                headers: ["Důvod", "Význam"],
                rows: [
                    ["Došel počet opakování", "Normální"],
                    ["Krok `find` nic nenašel", "Takhle se »přehrát do konce souboru« zastaví samo"],
                    ["Dosažen konec dokumentu", "Není kam dál"],
                    ["Zrušili jste to", "`Makro ▸ Zrušit běžící makro`"],
                    ["Jedno kolo nic nezměnilo a nikam se neposunulo", "Zastaveno, aby to nemohlo běžet donekonečna"],
                ]
            ),
            .note("Celý běh — i deset tisíc opakování — je **jeden** krok zpět."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Dávkové spuštění makra",
        summary: "Přes každou otevřenou kartu, nebo přes složku neotevřených souborů.",
        keywords: ["dávka", "všechny karty", "složka", "makro", "maska"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Příkaz", "Rozsah", "Lze vrátit"],
                rows: [
                    ["Spustit na všech kartách", "Otevřené karty", "Ano — jeden krok zpět na kartu"],
                    ["Spustit přes složku…", "Soubory na disku, které **nejsou otevřené**", "Ne"],
                ]
            ),
            .warning("""
                Spuštění přes složku se dotýká souborů, které nejsou otevřené v žádné kartě, takže \
                **není jak to vrátit**. Ve výchozím stavu GEditor **zapisuje nové soubory**, místo aby \
                přepisoval originály. Toto nastavení ponechte, nemáte-li zálohu nebo verzovaný \
                repozitář.
                """),
            .heading("Filtrování souborů maskou"),
            .paragraph("""
                Výběr složky má **filtr názvů souborů**: napište `*.csv;*.log` a makro se dotkne jen \
                jich. Je to táž syntaxe masky, jakou používá `Hledat v celé složce`, s několika vzory \
                oddělenými `;` nebo `,`.
                """),
            .bullets([
                "Nechte to **prázdné** a vezme každý textový soubor, který GEditor umí přečíst — dřívější chování.",
                "Maska ten seznam přípon **nahrazuje**, místo aby ho dál zužovala: napište `*.bak` a poběží na souborech `.bak`, i když ta přípona v textovém seznamu není.",
                "Když nic neodpovídá, zpráva **zopakuje vaši masku**, místo aby vinila prázdnou složku.",
            ]),
            .paragraph("""
                To pole má velmi praktický důvod: složka drží 400 souborů `.json` a 12 souborů `.log` a \
                vaše makro uklízí jen logy. Bez masky se zpracuje i těch dalších 400 — a jelikož dávka \
                zapisuje nové soubory, chyba po sobě zanechá 400 kusů odpadu.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Syntaxe souboru makra",
        summary: "Sedm druhů kroků, úplný formát JSON a dvě fungující makra.",
        keywords: ["makro", "json", "syntaxe", "formát", "ruční úprava", "sdílet"],
        blocks: [
            .paragraph("""
                Každé makro je **vlastní soubor JSON** ve složce `macros/` GEditoru. Poškození zůstane \
                uvnitř jednoho makra a sdílet ho s kolegou znamená poslat jeden soubor.
                """),
            .code(language: "text", caption: "Kde soubory bydlí",
                  source: "~/Library/Application Support/GEditor/macros/<název-makra>.json"),
            .heading("Sedm druhů kroků"),
            .table(
                headers: ["Krok", "Zapisuje se jako", "Význam"],
                rows: [
                    ["Vložit text", "`{\"insert\": {\"_0\": \"text\"}}`", "Psát u kurzoru; s výběrem ho nahradí"],
                    ["Smazat vzad", "`{\"deleteBackward\": {}}`", "Jako klávesa mazání"],
                    ["Smazat vpřed", "`{\"deleteForward\": {}}`", "Jako ⌦"],
                    ["Přesunout", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Viz seznam směrů níže"],
                    ["Vybrat řádek", "`{\"selectLine\": {}}`", "Bez konce řádku"],
                    ["Hledat", "`{\"find\": { … }}`", "Najde a **vybere** další výskyt"],
                    ["Nahradit výběr", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` platí, byl-li předchozí krok `find` s regexem"],
                ]
            ),
            .heading("Směry pohybu"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Úplný krok `find`"),
            .code(language: "json", caption: "Čtyři klíče kroku find",
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
            .paragraph("`mode` přijímá `normal`, `extended` nebo `regex` — stejné tři režimy jako vyhledávací pole."),
            .heading("Příklad 1 — kód provincie na začátku řádku velkými"),
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
                Spusťte ho pomocí `Makro ▸ Přehrát do konce dokumentu`: to, že krok `find` už nic \
                nenajde, je právě podmínka zastavení.
                """),
            .heading("Příklad 2 — smazat řádek za každým řádkem obsahujícím TODO"),
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
                Ručně upravené makro nejdřív vyzkoušejte na kopii. Překlep v kroku `find` makro ihned \
                zastaví — to je ten neškodný případ. Nebezpečný je vzor, který zabírá šířeji, než jste \
                mysleli, a upraví tisíce míst uvnitř jediného kroku zpět.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "Skripty v JavaScriptu",
        summary: "Čtyři funkce, jeden soubor `.js` a vše, co udělá, je jeden krok zpět.",
        keywords: ["skript", "javascript", "js", "automatizovat", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Vložte soubor `.js` do složky `scripts/` GEditoru a spusťte ho z `Makro ▸ Skript…`. \
                Skript vidí přesně **čtyři** věci:
                """),
            .table(
                headers: ["Volání", "Význam"],
                rows: [
                    ["`doc.text`", "Text celého dokumentu"],
                    ["`doc.selection`", "Výběr (prázdný řetězec, když není nic vybráno)"],
                    ["`doc.replace(s)`", "Nahradit **celý dokument** hodnotou `s` — jeden krok zpět"],
                    ["`doc.log(s)`", "Zapsat řádek do panelu výsledků"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Očísluj každý řádek.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — ponechat první tři sloupce CSV",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Tři meze, které je třeba znát"),
            .bullets([
                "**Žádný přístup k souborům, žádná síť, žádné spouštění procesů.** Plocha API je záměrně úzká: rozšířit ji později je snadné, zúžit ji rozbije každý skript, který uživatelé napsali.",
                "**Tohle není bezpečnostní hranice.** Skripty běží ve stejném procesu. Nespouštějte skript, který jste nečetli.",
                "**Platí limit pěti sekund.** Nad ním dostanete zprávu a aplikace zůstane použitelná — ale vlákno toho skriptu **se točí dál, dokud neukončíte**, a žere jedno jádro. Zpráva to říká.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filtrování vnějším příkazem",
        summary: "Prožeňte výběr unixovým příkazem a výsledek vezměte zpět.",
        keywords: ["filtr", "vnější příkaz", "shell", "roura", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Výběr (nebo celý dokument) se předá na `stdin` příkazu a `stdout` toho příkazu ho \
                nahradí.
                """),
            .code(language: "bash", caption: "Několik běžných",
                  source: """
                    sort -u                     # seřadit a zahodit duplicity
                    jq .                        # přeformátovat JSON
                    tr 'a-z' 'A-Z'              # na velká písmena
                    grep -v '^#'                # zahodit řádky komentářů
                    awk -F, '{print $3","$1}'   # prohodit pořadí sloupců
                    """),
            .note("""
                Výsledek je **jeden** krok zpět. Vrátí-li příkaz chybový kód, GEditor text nechá být a \
                ukáže `stderr`.
                """),
            .warning("""
                Tento příkaz existuje **jen ve verzi s přímým stažením**. App Sandbox zakazuje spouštět \
                kód mimo aplikaci, takže ve verzi z App Store položka nabídky zůstává a vysvětluje, \
                proč není dostupná.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Nástroj příkazového řádku `geditor`",
        summary: "Otevírat, čistit, dotazovat se, hodnotit a vykreslovat zprávy — bez otevření aplikace.",
        keywords: ["cli", "příkazový řádek", "terminál", "geditor", "skript", "ci"],
        blocks: [
            .warning("""
                Dostupné jen ve verzi s **přímým stažením**. Verze z App Store běží v sandboxu, takže \
                se k ní vnější proces příkazového řádku nemůže připojit.
                """),
            .heading("Otevírání souborů"),
            .code(language: "bash", caption: "Otevřít, skočit na pozici, číst z roury",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # řádek 120, sloupec 5
                    geditor -w notes.md            # počkat na zavření souboru, teprve pak skončit
                    geditor -r app.log             # otevřít jen ke čtení
                    git diff | geditor             # načíst standardní vstup do nové karty
                    """),
            .table(
                headers: ["Volba", "Význam"],
                rows: [
                    ["`-w`, `--wait`", "Počkat na zavření souboru, teprve pak skončit — aby mohl sloužit jako editor `gitu`"],
                    ["`-n`, `--new-window`", "Otevřít v novém okně"],
                    ["`-r`, `--read-only`", "Otevřít jen ke čtení"],
                    ["`-i`, `--info`", "Vypsat znakovou sadu, konce řádků a počet řádků, pak skončit — **bez** otevření aplikace"],
                    ["`-h`, `--help`", "Zobrazit nápovědu"],
                    ["`-v`, `--version`", "Zobrazit verzi"],
                ]
            ),
            .heading("Běh bez otevření aplikace"),
            .paragraph("""
                Čtyři skupiny příkazů níže běží **zcela uvnitř procesu příkazového řádku**, takže \
                fungují v CI, kde nikdo není přihlášen do grafického sezení.
                """),
            .code(language: "bash", caption: "Čištění receptem",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Dotazování",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Brána kvality — kód 0 prošlo · 1 neprošlo · 2 chyba",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Vykreslení zpráv",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript a nabídka Služby",
        summary: "Čtěte a zapisujte dokument z AppleScriptu, nebo pošlete text do GEditoru z jiné aplikace.",
        keywords: ["applescript", "osascript", "služby", "automatizace", "zkratky"],
        blocks: [
            .code(language: "applescript", caption: "Přečíst otevřený dokument",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Přepsat obsah a přečíst výběr",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Otevřít soubor",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Nabídka Služby"),
            .paragraph("""
                Vyberte text v jakékoli aplikaci a pak ho pomocí nabídky `Služby` pošlete do GEditoru \
                jako novou kartu.
                """),
            .note("""
                Při prvním spuštění AppleScriptu si macOS vyžádá oprávnění k automatizaci. To je dialog \
                systému, ne GEditoru.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Rozšiřující balíčky a zásuvné moduly",
        summary: "Dva druhy rozšíření a ve které verzi každé z nich běží.",
        keywords: ["zásuvný modul", "rozšíření", "balíček", "nativní"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Rozšiřující balíčky"),
            .paragraph("""
                Balíček je **jeden soubor JSON**, který svazuje motiv, skripty a vlastní jazyky. \
                Instalace zkopíruje soubor, odebrání jeden smaže — a seznam balíčků se odvozuje z \
                **disku**, ne z registru, který by mohl lhát.
                """),
            .paragraph("Funguje v **obou verzích**."),
            .heading("Nativní zásuvné moduly"),
            .paragraph("""
                Předkompilované zásuvné moduly běží ve **vlastním procesu** s úzkou plochou API — modul, \
                který spadne, aplikaci s sebou nestrhne.
                """),
            .warning("""
                Nativní zásuvné moduly existují **jen ve verzi s přímým stažením**, protože App Sandbox \
                zakazuje načítat kód zvenčí aplikace. Každý modul musí být **jednou ručně schválen** \
                podle svého kontrolního součtu, než poběží.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Nastavení a aplikace

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Nastavení a aplikace",
        summary: "Nastavení, zkratky, motivy, aktualizace, přechod z Notepad++, řešení potíží.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Nastavení",
        summary: "Každá volba žije v jednom čitelném souboru JSON, který můžete zkopírovat na jiný Mac.",
        keywords: ["nastavení", "volby", "konfigurace", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Otevřít nastavení")]),
            .paragraph("""
                Není zde žádné OK ani Zrušit — změna se projeví a zapíše okamžitě, po způsobu macOS.
                """),
            .heading("Konfigurační soubor"),
            .code(language: "text", caption: "Kde bydlí",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Je to **odsazený soubor JSON, který můžete číst a ručně upravovat**. Zkopírujte ho na \
                jiný Mac a celé vaše nastavení jde s ním. Tlačítko `Otevřít konfigurační soubor` v \
                nastavení vás tam zavede rovnou.
                """),
            .heading("Klíče"),
            .table(
                headers: ["Klíč", "Výchozí", "Význam"],
                rows: [
                    ["`fontSize`", "`13`", "Velikost písma editoru"],
                    ["`tabWidth`", "`4`", "Kolik sloupců je široký TAB"],
                    ["`usesTabsForIndent`", "`false`", "Odsazovat TABy místo mezer"],
                    ["`languageIndent`", "`{}`", "Odsazení podle jazyka — viz stránka o bílých znacích"],
                    ["`smartIndent`", "`true`", "Automatické odsazení na novém řádku"],
                    ["`highlightAllMatches`", "`true`", "Zvýraznit každý nalezený výskyt"],
                    ["`ligatures`", "`false`", "Ligatury — viz poznámka pod tabulkou"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Ořezat bílé znaky na konci řádku při ukládání"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalizovat Unicode na NFC při ukládání"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Znaková sada pro nové soubory"],
                    ["`defaultEOL`", "`\"lf\"`", "Konce řádků pro nové soubory"],
                    ["`language`", "`\"system\"`", "Jazyk rozhraní"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "výchozí motiv", "Který barevný motiv se používá"],
                    ["`showWelcomeOnLaunch`", "`true`", "Otevřít uvítací okno při spuštění"],
                    ["`keyBindings`", "`{}`", "Jen klávesy, které jste změnili"],
                ]
            ),
            .note("""
                **Proč jsou ligatury ve výchozím stavu VYPNUTÉ.** Ligatura sloučí `!=` nebo `->` do \
                **jednoho** znaku, takže znaky, které vidíte na obrazovce, už neodpovídají znakům v \
                souboru — a editor sloupců, sloupcový režim i zalomení na sloupci měří ve sloupcích. \
                Zapněte je, když píšete běžný text, nebo pokud jste zvolili programátorské písmo (Fira \
                Code, JetBrains Mono) právě kvůli jeho ligaturám.
                """),
            .heading("Sousední složky"),
            .table(
                headers: ["Složka", "Obsahuje"],
                rows: [
                    ["`macros/`", "Uložená makra, každé jako soubor JSON"],
                    ["`scripts/`", "Skripty v JavaScriptu"],
                    ["`themes/`", "Barevné motivy"],
                    ["`grammars/`", "Vlastní jazyky"],
                ]
            ),
            .warning("""
                Konfigurační soubor zapsaný **novějším** GEditorem se starším **nepřepisuje** — ten \
                starší běží na výchozích hodnotách a řekne to. Přepsání je nejjistější způsob, jak \
                zničit nastavení někomu, kdo synchronizuje dva stroje, a on by se nikdy nedozvěděl proč.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Stavový řádek",
        summary: "Deset polí dole — všechna čitelná a všechna klepnutelná.",
        keywords: ["stavový řádek", "pozice", "znaková sada", "jen ke čtení", "velikost"],
        blocks: [
            .paragraph("""
                Tohle je největší rozdíl oproti stavovým řádkům jiných editorů: **žádné pole není jen ke \
                čtení**. Vidíte-li špatnou hodnotu, klepnutí na ni je způsob, jak ji opravit, místo aby \
                se hledalo po nabídkách.
                """),
            .table(
                headers: ["Pole", "Říká vám", "Po klepnutí"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "polohu kurzoru — sloupec ve ZNACÍCH, `@340` bajtovou pozici",
                     "otevře pole `Přejít na`"],
                    ["`11 byte · 3 dòng`", "velikost dokumentu",
                     "spočítá bajty · znaky · slova · řádky"],
                    ["`🔒 Chỉ đọc`", "zobrazí se jen, když je dokument zamčený",
                     "řekne PROČ je zamčený a odemkne, když to jde"],
                    ["`View` / `Code`", "ve kterém zobrazení jste", "přepíná (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "režim CSV a použitý oddělovač",
                     "přepne režim CSV, nebo **znovu zvolí oddělovač**"],
                    ["`Đang theo dõi`", "běží `tail -f`", "—"],
                    ["`UTF-8`", "znakovou sadu", "přečíst jinak, nebo převést do jiné sady"],
                    ["`LF`", "styl konce řádku", "přepnout LF · CRLF · CR"],
                    ["`Python`", "jazyk obarvení syntaxe", "zvolit jiný, nebo zpět na rozpoznání dle přípony"],
                    ["`Tab: 4`", "šířku odsazení", "2 · 4 · 8, obecně nebo **jen pro tento jazyk**"],
                    ["`Ngắt: tắt`", "režim zalamování", "prochází třemi režimy"],
                ]
            ),
            .heading("Tři pole, která si zaslouží druhý pohled"),
            .bullets([
                "**`@340` — bajtová pozice.** To je číslo, kterým mluví každý další nástroj v produktu: chyby JSON a XML, výstup `--doc-sweep`, binární prohlížeč i pole `Přejít na @340`. Přečtěte ho tady, napište ho tam.",
                "**`~` u sloupce** znamená, že číslo počítá BAJTY, a ne viditelné sloupce — stává se to jen na řádcích delších než 200 kB, kde by počítání znaků zpomalilo každý pohyb kurzoru.",
                "**Na `CSV · …` lze klepnout a znovu zvolit oddělovač.** Rozpoznání se může splést, a když se splete, každá operace se sloupci je posunutá, aniž by to cokoli signalizovalo. Takhle řeknete opak — jen se soubor **ZNOVU PŘEČTE**, aniž by se změnil bajt (na rozdíl od `CSV ▸ Změnit oddělovač…`, který ho přepíše).",
            ]),
            .note("""
                Pole, které se otevřeného souboru netýká, je **skryté**, ne šedé: `Jen ke čtení` se \
                zobrazí, jen když je dokument opravdu zamčený, a `CSV · …` jen v režimu CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Změna klávesových zkratek",
        summary: "Měňte jednotlivé klávesy, nebo převezměte celou klávesovou mapu Notepad++.",
        keywords: ["zkratka", "klávesová mapa", "přednastavení"],
        blocks: [
            .paragraph("""
                `Nastavení…` má oddíl Zkratky se dvěma rychlými tlačítky: **Použít přednastavení \
                Notepad++** a **Zpět na výchozí**.
                """),
            .paragraph("""
                Konfigurační soubor zaznamenává jen to, co jste **změnili oproti výchozím hodnotám**. \
                Tak nezůstanete se starou mapou, aniž by vám to někdo řekl, když GEditor v nové verzi \
                změní výchozí klávesu.
                """),
            .note("""
                Dva příkazy nesmějí sdílet zkratku. Když ji sdílejí, AppKit tiše spustí jen **první** \
                položku nabídky a druhý příkaz vypadá rozbitě — proto má GEditor kontrolu, která tomu \
                brání.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Motivy, světlý a tmavý",
        summary: "Podle systému, světlý nebo tmavý; a motiv je soubor JSON, který můžete upravit.",
        keywords: ["motiv", "barvy", "tmavý režim", "světlý", "vzhled"],
        blocks: [
            .paragraph("`Nastavení…` volí `Podle systému`, `Světlý` nebo `Tmavý` a určuje barevný motiv."),
            .paragraph("""
                Motiv je soubor JSON ve složce `themes/`. Tlačítko `Exportovat aktuální motiv` jeden \
                vypíše jako výchozí bod pro váš vlastní.
                """),
            .note("""
                Chybně zapsaná barva v souboru motivu se vrátí k barvě **výchozího motivu**, ne k \
                černé. Černá vypadá jako záměr návrhu a uživatel by chybu hledal jinde.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Aktualizace, verze a ukončení",
        summary: "V čem se aktualizace mezi oběma verzemi liší.",
        keywords: ["aktualizace", "verze", "o aplikaci", "ukončit"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Verze", "Aktualizuje se přes"],
                rows: [
                    ["App Store", "App Store, jako každá jiná aplikace"],
                    ["Přímé stažení", "`Zkontrolovat aktualizace…` uvnitř aplikace"],
                ]
            ),
            .paragraph("""
                `O aplikaci GEditor` ukáže běžící verzi a to, o kterou verzi jde — hodí se při hlášení \
                problému.
                """),
            .note("""
                Ve verzi z App Store `Zkontrolovat aktualizace…` **zůstává v nabídce** a vysvětluje, \
                proč se to netýká, místo aby zmizelo. Chybějící položka nabídky je dotaz na podporu.
                """),
            .paragraph("Ukončení nezpůsobí ztrátu práce: sezení se vrátí, až aplikaci příště otevřete."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Používání tohoto okna nápovědy",
        summary: "Hledejte v knize, přepínejte její jazyk a vraťte si uvítací okno.",
        keywords: ["nápověda", "průvodce", "hledání", "uvítání", "jazyk"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Otevřít okno nápovědy")]),
            .bullets([
                "Vyhledávací pole vlevo nahoře prohledává **hlavní text i ukázky kódu** — napsání holého konfiguračního klíče jako `fail_under` vede na správnou stránku.",
                "Psaní **bez diakritiky** přesto najde text s ní.",
                "Tlačítko `Zpět` se vrátí na předchozí stránku.",
                "Tlačítko `Kopírovat` u každého bloku kódu ten blok zkopíruje.",
            ]),
            .heading("Čtení v jiném jazyce"),
            .paragraph("""
                Nabídka vpravo nahoře v tomto okně volí **jazyk knihy**, nezávisle na jazyce rozhraní \
                aplikace. Přepnutí vás udrží **na stránce, kterou čtete** — identifikátory stránek se \
                záměrně nepřekládají právě proto, aby tohle fungovalo.
                """),
            .note("""
                Uvádějí se jen jazyky, které knihu skutečně mají. Položka nabídky, která na něco přepne \
                a text nechá beze změny, by byla položkou, která lže.
                """),
            .heading("Návrat uvítacího okna"),
            .paragraph("""
                Zaškrtli jste **Neotvírat toto okno při spuštění**? Otevřete ho znovu pomocí `Nápověda \
                ▸ Prohlídka funkcí` — zaškrtávací pole dole v okně se objeví zpět a lze ho odškrtnout.
                """),
            .paragraph("Nebo nastavte `showWelcomeOnLaunch` zpět na `true` v `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Z Notepad++ do GEditoru",
        summary: "Které klávesy si prohodí místa, co funguje jinak a co chybí.",
        keywords: ["notepad++", "přechod", "windows", "zkratky"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Několik kláves si na macOS **prohodí místa**, místo aby se `Ctrl` prostě změnilo na \
                `⌘`. Tady je srovnání.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Proč"],
                rows: [
                    ["`Ctrl+D` Zdvojit řádek", "**⇧⌘D**", "Zde je `⌘D` více kurzorů, jako v každém editoru na Macu"],
                    ["`Ctrl+L` Smazat řádek", "**⌘K**", "Na macOS `⌘L` znamená »přejít na řádek«"],
                    ["`Ctrl+G` Přejít na řádek", "**⌘L**", "Tyto dvě si prohodí místa"],
                    ["`Ctrl+Q` Zakomentovat", "**⌘/**", "Zvyklost macOS"],
                    ["`Ctrl+Shift+↑/↓` Přesunout řádek", "**⌥↑ / ⌥↓**", "Na macOS patří `⌃` Mission Controlu"],
                    ["`F3` Najít další", "**⌘G**", "Zvyklost macOS"],
                    ["`Ctrl+F2` Přepnout záložku", "**⌘F2**", "F2 a ⇧F2 stále skáčou mezi značkami"],
                    ["`Alt` + tažení pro sloupce", "**⌥ + tažení**", "Stejné"],
                    ["`Ctrl+Alt+Shift+↓` Editor sloupců", "**⌥⌘C**", "Zvyklost macOS"],
                ]
            ),
            .note("Raději byste se neučili znovu? `Nastavení ▸ Zkratky ▸ Použít přednastavení Notepad++`."),
            .heading("Věci, které Notepad++ má a zde fungují jinak"),
            .bullets([
                "**Sezení** se obnovují sama, včetně neuložených karet — není co zapínat.",
                "**Záložky mají devět barev** a jeden řádek jich může nést několik najednou.",
                "**Mapa dokumentu** popisuje *celý* soubor, ne jen viditelnou část.",
                "**Makra** lze přehrát »do konce dokumentu« a »na všech kartách« a celý běh je jeden krok zpět.",
            ]),
            .heading("Co GEditor přidává"),
            .bullets([
                "**Čisticí stůl pro data** a **profily dat** pro soubory CSV.",
                "**Dotazy SQL** přímo nad souborem CSV.",
                "**Staré vietnamské znakové sady** — TCVN3, VISCII, VNI-Windows, čtené, zapisované a samy rozpoznávané.",
                "**Hledání bez ohledu na diakritiku** v každém filtrovacím poli.",
                "**Zprávy `.greport.md`** s tabulkami a grafy, které se přepočítají.",
                "**Nástroj příkazového řádku `geditor`** ve verzi s přímým stažením.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Časté potíže",
        summary: "Šest situací, kvůli kterým si lidé myslí, že je aplikace rozbitá.",
        keywords: ["chyba", "problém", "nefunguje", "řešení potíží", "proč"],
        blocks: [
            .table(
                headers: ["Příznak", "Obvyklá příčina"],
                rows: [
                    ["Vietnamský text se zobrazuje jako nesmysly", "Špatná znaková sada — klepněte na znakovou sadu ve stavovém řádku"],
                    ["Hledání textu s diakritikou nic nenajde", "Soubor je v rozloženém Unicode — spusťte `Normalizovat Unicode` na NFC"],
                    ["Položka nabídky je šedá", "Verze z App Store ten příkaz nemůže spustit — položka vysvětluje proč"],
                    ["Párování závorek odmítá běžet", "Dokument je nad 1 MB — zvýraznit špatný pár je horší než nic"],
                    ["Sloupec ve stavovém řádku má `~`", "Dokument je nad 200 kB, takže je to počet bajtů, ne viditelný sloupec"],
                    ["Dotaz SQL říká, že soubor je nutné nejdřív uložit", "DuckDB čte **soubory**, ne vyrovnávací paměť, kterou upravujete"],
                ]
            ),
            .heading("Když GEditor neočekávaně skončí"),
            .paragraph("""
                Při dalším spuštění to oznámí banner s tlačítkem **Otevřít hlášení** — hlášení se \
                otevře jako karta, kterou lze číst a kopírovat z ní jako z jakéhokoli jiného textového \
                souboru.
                """),
            .bullets([
                "Hlášení nese jen **verzi, vydání macOS, architekturu stroje, název signálu a zásobník volání**.",
                "**Žádný obsah dokumentu a ani žádné cesty k souborům** — cesta jako `~/Plocha/mzdy-prosinec.xlsx` už prozradila tři soukromé věci, ještě než ji kdokoli otevřel.",
                "**Nikam se nic neposílá.** Není žádné automatické nahrávání ani server, který by to přijal; soubor zůstane v `~/Library/Application Support/GEditor/crash/`, dokud ho neotevřete nebo nesmažete.",
                "Jakmile hlášení otevřete, další spuštění ho už nezmíní.",
            ]),
            .heading("Kam se podívat dál"),
            .bullets([
                "Stavový řádek ukazuje znakovou sadu, konce řádků, jazyk a režim zalamování — na každé pole lze klepnout.",
                "`settings.json` lze upravit ručně, když okno nastavení nestačí.",
                "`O aplikaci GEditor` dá verzi a variantu, které hlášení chyby potřebuje.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
