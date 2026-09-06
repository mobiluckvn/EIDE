import Foundation

/// Magyar súgótartalom — 5. rész: jelentések, tudás, automatizálás és az alkalmazás.
extension HelpHU {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Jelentések és diagramok",
        summary: "Egy szövegfájl, amely újraszámolódó számokat tartalmazó HTML-jelentést ad, plusz Mermaid-diagramok.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md` jelentések",
        summary: "Markdown plusz négyféle futtatható blokk — balra ír, jobbra előnézet.",
        keywords: ["jelentés", "greport", "html", "exportálás", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Egy `.greport.md` fájl **közönséges Markdown** plusz néhány futtatható kerített blokk. \
                A megjelenítése **önálló** HTML-fájlt ad — nincs hálózat, nincsenek kísérőfájlok —, \
                amelyet bárki megnyithat.
                """),
            .paragraph("""
                Mivel egyszerű szöveg, **összevethető, verziózható és megosztható** — ugyanaz a \
                gondolat, mint a tisztítási recepteknél és a minőségi szabálykészleteknél.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — teljes jelentés",
                  source: """
                    ---
                    title: Augusztusi értékesítési jelentés
                    source: sales-2026-08.csv
                    ---

                    # Augusztusi értékesítési jelentés

                    Adatok 2026. augusztus 31-i állapot szerint.

                    ## Bevétel tartományonként

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Bevétel tartományonként
                    y_label: Bevétel
                    number_format: vi
                    suffix: " ₫"
                    source: Forrás — sales-2026-08.csv
                    ```

                    ## A forrásadat minősége

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("A blokktípusok"),
            .table(
                headers: ["Blokk", "Mit ad"],
                rows: [
                    ["`query`", "Táblát, egy DuckDB-nek szóló SQL-utasításból"],
                    ["`chart`", "Diagramot"],
                    ["`quality`", "Adatminőségi kártyát"],
                    ["`mining`", "Csoportrangsor-táblát a csoportonkénti bányászatból"],
                    ["`mermaid`", "Diagramot"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                A fenti `---` blokk adja meg a `title` és a `source` kulcsot — az alapértelmezett \
                adatforrást minden blokkhoz, amely nem nevez meg sajátot.
                """),
            .note("""
                Az előnézet akkor épül újra, amikor abbahagyja a gépelést, de csak **elemez**; nem \
                futtat lekérdezést minden billentyűleütésre. A dokumentumhibákat és az adathibákat külön \
                jelenti — *»a chart blokkból hiányzik a `kind` kulcs«* fájlhiba, *»a `doanh_thu` oszlop \
                nem létezik«* adathiba.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "A `query` blokk",
        summary: "Egy DuckDB-utasításból egy tábla lesz a jelentésben.",
        keywords: ["lekérdezés", "sql", "tábla", "jelentés", "blokk"],
        blocks: [
            .paragraph("""
                A blokk tartalma **egyetlen SQL-utasítás**, a jelentés forrásán futtatva. A tábla neve \
                `t`, ugyanabban a nyelvjárásban, mint a lekérdezőpanelen.
                """),
            .code(language: "text", caption: "Paraméteres query blokk",
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
                A `:thang` **paraméter**. Megjelenítéskor adjuk meg — héjból a `--param thang=8` \
                kapcsolóval, vagy listafájlból, amikor kötegben állítunk elő jelentéseket.
                """),
            .note("""
                Egy adatjelentés tábláinak **query blokkból kell származniuk**, nem kézzel írva. Egy \
                kézzel írt tábla nem számolódik újra, ha a számok változnak, és előbb-utóbb ellentmond a \
                jelentés többi részének.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "A `chart` blokk",
        summary: "Egy YAML-beállításból diagram lesz — és a formátum legfontosabb szabálya.",
        keywords: ["diagram", "yaml", "jelentés", "rajzolás"],
        blocks: [
            .code(language: "yaml", caption: "A chart blokk minden kulcsa",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Bevétel tartományonként
                    x_label: Tartomány
                    y_label: Bevétel
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Forrás — sales.csv, 2026. aug. 26-i állapot
                    """),
            .heading("`query` nélkül a KÖZVETLENÜL FÖLÖTTE lévő query blokk eredményét használja"),
            .paragraph("""
                Ez a formátum legfontosabb szabálya. Ennek köszönhetően a szokásos »egy tábla, majd \
                annak a táblának a diagramja« jelentés nem ismétli az SQL-t — az ismétlés pedig azt \
                jelenti, hogy a két másolat végül szétcsúszik, és akkor a tábla meg a diagram \
                különbözőt mond ugyanazon az oldalon.
                """),
            .warning("""
                Cserébe **a blokkok sorrendje számít**: egy query blokk közéjük szúrása megváltoztatja \
                az alatta lévő diagram adatait.
                """),
            .heading("Miért saját kulcs a `source`"),
            .paragraph("""
                A diagram alá folyószövegként írt forrásmegjelölés remekül látszik — a képernyőn. Csakhogy \
                a diagramot PNG-ként exportálják és máshová illesztik, a folyószöveg pedig ottmarad. \
                Kulcsként **a képen belülre** rajzolódik, és vele együtt utazik.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "A `quality` blokk",
        summary: "Adatminőségi kártya a jelentésen belül.",
        keywords: ["minőség", "kártya", "jelentés", "blokk"],
        blocks: [
            .code(language: "yaml", caption: "A quality blokk minden kulcsa",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # üres = a jelentés saját forrása
                    title: Az augusztusi értékesítési adat minősége
                    rules: true                 # mutassa a szabályonkénti megfelelt/bukott táblát
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # rögzítse a "Frissesség" viszonyítási dátumát
                    fail_under: 90              # ez alatt a kártya figyelmeztető színt vesz fel
                    """),
            .table(
                headers: ["`chart`", "Mit rajzol"],
                rows: [
                    ["`violations`", "A **megbukott** szabályok sorszámait — arra válaszol, »mit javítsunk először«"],
                    ["`dimensions`", "A hat dimenzió pontszámait"],
                    ["`none`", "Csak táblát, diagram nélkül"],
                ]
            ),
            .note("""
                Állítsa be a `now:` kulcsot ismétlődő jelentésben. Enélkül a *Frissesség* a megjelenítés \
                pillanatához hasonlít, így a múlt havi jelentés újramegjelenítése más pontszámot ad, mint \
                amit kiadott.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "A `mining` blokk",
        summary: "Rangsorolja a csoportokat rendellenességek, előrejelzési hiba vagy korrelációs eltérés szerint.",
        keywords: ["bányászat", "jelentés", "csoportrangsor"],
        blocks: [
            .code(language: "yaml", caption: "A mining blokk minden kulcsa",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # az oszlop a rendellenességekhez és az előrejelzéshez
                    pair: chi_phi             # második oszlop a csoportonkénti korrelációhoz
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # üres = a jelentés saját forrása
                    title: Bányászat tartományonként
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Mi szerint rangsorol"],
                rows: [
                    ["`anomalies`", "Az a csoport, amelynek a legtöbb kiugró sora van"],
                    ["`forecast_error`", "Az a csoport, amelynek az előrejelzése a legrosszabb"],
                    ["`correlation_gap`", "Az a csoport, amelynek a korrelációja legjobban eltér az összevont táblától — elfogja a Simpson-paradoxont"],
                ]
            ),
            .warning("""
                **Egyetlen kulcs sem kapcsolja ki a »Módszer« blokkot.** Egy csoportrangsor a módszere \
                nélkül nem hagy módot az olvasónak megtudni, milyen kerítéshez mérték a »legtöbb \
                rendellenességet«. Aki el akarja rejteni, már tudja, milyen választ szeretne.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Jelentések kötegelt előállítása",
        summary: "Egy sablon, egy paraméterlista, sok jelentés.",
        keywords: ["köteg", "tömeges", "paraméterek", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Egy jelentéssablon, minden fiókra vagy minden hónapra lefuttatva. A paraméterlista egy \
                CSV- vagy JSON-fájl — **jelentésenként egy sor**.
                """),
            .code(language: "text", caption: "list.csv — jelentésenként egy sor",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Az egész köteg megjelenítése héjból",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Vagy egy jelentés kézzel megadott paraméterekkel",
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
        title: "Mermaid-diagramok",
        summary: "Rajzoljon diagramot szövegben, módosítsa parancsokkal, előnézet mindkét irányban szinkronban.",
        keywords: ["mermaid", "diagram", "folyamatábra", "szekvencia", "rajzolás"],
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
                A Mermaid **szövegből** rajzol diagramot: leírást ír, a gép pedig megrajzolja. Egy \
                diagram így összevethető és verziózható — amit egy képfájl nem tud.
                """),
            .paragraph("""
                Nyissa meg a `Mermaid-diagram: előnézet` menüpontot a szerkesztő melletti nézethez. A \
                kettő **mindkét irányban szinkronban** van: jelöljön ki egy elemet a képen, és a kurzor \
                a sorára ugrik.
                """),
            .heading("Módosítson parancsokkal, ne újraírással"),
            .table(
                headers: ["Parancs", "Mit csinál"],
                rows: [
                    ["Sablon beszúrása…", "Kész vázat szúr be minden diagramtípushoz"],
                    ["Elem hozzáadása…", "Csomópontot vagy résztvevőt ad hozzá"],
                    ["A két kijelölt elem összekötése", "Nyilat rajzol közéjük"],
                    ["A kijelölt elem címkéjének szerkesztése…", "Módosítja a szöveget a sor megkeresése nélkül"],
                    ["A kijelölt elem törlése", "Eltávolítja a csomópontot **és** minden hozzá érő élt"],
                    ["Üzenet mozgatása fel / le", "Átrendezi a lépéseket egy szekvenciadiagramban"],
                    ["Újraformázás", "Behúzza és kiegyenesíti az egész blokkot"],
                ]
            ),
            .heading("Kiemelés fájlba és visszaágyazás"),
            .paragraph("""
                A nagy diagramok saját `.mmd` fájlba valók: a `Blokk kiemelése .mmd fájlba…` kiviszi, és \
                hivatkozást hagy. A `A hivatkozott fájl visszaágyazása` az ellenkezőjét teszi, amikor \
                egyetlen fájlt kell küldenie.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Gyakori Mermaid-szintaxis",
        summary: "A négy leghasználtabb diagramtípus, mindegyik működő sablonnal.",
        keywords: ["mermaid", "szintaxis", "folyamatábra", "szekvencia", "gantt", "osztály", "sablon"],
        blocks: [
            .code(language: "mermaid", caption: "Folyamatábra — rendelés jóváhagyása",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Szekvenciadiagram — fizetési folyamat",
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
            .code(language: "mermaid", caption: "Osztálydiagram — adatmodell",
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
            .code(language: "mermaid", caption: "Gantt — kiadási terv",
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
                headers: ["Csomópontalak", "Írja"],
                rows: [
                    ["Téglalap", "`A[Label]`"],
                    ["Lekerekített", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Rombusz (döntés)", "`A{Label}`"],
                    ["Henger (adat)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Nyíl", "Írja"],
                rows: [
                    ["Folytonos, hegyes", "`A --> B`"],
                    ["Pontozott", "`A -.-> B`"],
                    ["Vastag", "`A ==> B`"],
                    ["Címkézett", "`A -- label --> B`"],
                ]
            ),
            .note("""
                A folyamatábra iránya közvetlenül a `flowchart` után áll: `TD` fentről lefelé, `LR` \
                balról jobbra, valamint `BT` és `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Tudáscsomag

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "A tudáscsomag",
        summary: "Darabolás, keresési indexek, tudásgráfok, entitások és a visszakeresés értékelése.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Mi a tudáscsomag",
        summary: "Eszközök az adat előkészítéséhez és ellenőrzéséhez egy dokumentumokból válaszoló rendszerhez.",
        keywords: ["rag", "tudás", "chunk", "beágyazás", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Amikor olyan rendszert épít, amely egy dokumentumgyűjteményből válaszol kérdésekre, a \
                munka nagy része nem a modellben van, hanem **az adat előkészítésében**: a dokumentumok \
                értelmes szakaszokra vágásában, e szakaszok minőségének ellenőrzésében, az index \
                felépítésében, és annak **mérésében, hogy a visszakeresés valóban a helyeset találja-e \
                meg**.
                """),
            .paragraph("""
                Ez a fejezet épp ehhez való eszközkészlet. **Teljesen a saját gépén** fut, és sosem nyúl \
                a hálózathoz.
                """),
            .table(
                headers: ["Feladat", "Eszköz"],
                rows: [
                    ["Dokumentumok szakaszokra vágása", "Darabolás előnézete"],
                    ["Szakaszok átnézése és pontozása", "JSONL-szakaszok átnézése"],
                    ["Átalakítás adatalakok között", "Tudásátalakítás"],
                    ["Kapcsolati gráf építése és átnézése", "Tudásgráf"],
                    ["Tulajdonnevek keresése szövegben", "Entitásjelölés"],
                    ["A visszakeresés minőségének mérése", "Visszakereső labor"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "JSONL-gyűjtemény darabolása és átnézése",
        summary: "Nézze meg a szakaszhatárokat magán a szövegen, majd pontozza az egész gyűjteményt.",
        keywords: ["chunk", "jsonl", "gyűjtemény", "átfedés", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Darabolás előnézete"),
            .paragraph("""
                Nyisson meg egy szöveges vagy Markdown-dokumentumot, válasszon módszert és \
                szakaszméretet. A határok **magán a szövegen kiemelődnek**, így látja, hol esik egy vágás \
                mondat közepére vagy táblázaton át, mielőtt bármit exportálna.
                """),
            .bullets([
                "**Rögzített méret** átfedéssel.",
                "**Szerkezet szerint** — Markdown-címeknél, a dokumentum fonalát megőrizve.",
                "**Bekezdésenként**, a méret eléréséig összevonva.",
            ]),
            .heading("Meglévő JSONL-gyűjtemény átnézése"),
            .paragraph("""
                Egy már meglévő gyűjteményhez (soronként egy JSON-szakasz) a `JSONL: szakaszok \
                átnézése…` megválaszolja: mely sorok nem érvényes JSON-ok, mely szakaszok túl rövidek \
                vagy hosszúak, melyek ismétlik egymást, és melyeket vágtak el mondat közepén.
                """),
            .note("""
                Egy gyűjtemény **ugyanazzal a hatdimenziós kerettel** is pontozható, mint a táblázatos \
                adat — használja a `corpus:` kulcsot egy jelentés `quality` blokkjában.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Tudásformátumok átalakítása",
        summary: "Szakaszok JSONL · CSV · Markdown között, gráfok DOT · Mermaid · éllisták között.",
        keywords: ["átalakítás", "jsonl", "dot", "mermaid", "éllista"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Miből", "Mibe"],
                rows: [
                    ["JSONL-szakaszok", "CSV · Markdown"],
                    ["CSV-szakaszok", "JSONL · Markdown"],
                    ["DOT-gráf", "Mermaid · éllista"],
                    ["Éllista", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Az új lap létrehozása előtt **ötsoros előnézet** van, ugyanaz a mechanizmus, mint a \
                CSV-átalakításnál.
                """),
            .paragraph("""
                A `Hármasok/élek megnyitása táblázatként` egy hármasfájlt vagy éllistát táblázatként \
                mutat — szűrjön és rendezzen, mint bármely más CSV-nél.
                """),
            .note("""
                A **Markdown → JSONL** irány nincs ebben a parancsban: az az irány *maga* a darabolás, \
                és a parancs oda irányítja. Egy és ugyanazon vágás két megvalósítása két különböző \
                eredményt adna.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Tudásgráfok",
        summary: "Ellenőrizze a szintaxist, pontozza az állapotot, és futtasson algoritmusokat egymillió élű gráfokon.",
        keywords: ["gráf", "dot", "cypher", "pagerank", "louvain", "szintaxis-ellenőrzés"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                A GEditor **DOT**-ként, **éllistaként** és **hármasokként** olvas gráfokat. A `Gráf \
                szintaxisának ellenőrzése` elfogja a szintaktikai hibákat, az árva csomópontokat és a \
                nem létező csomópontokra mutató éleket.
                """),
            .heading("Elérhető algoritmusok"),
            .table(
                headers: ["Algoritmus", "Mire válaszol"],
                rows: [
                    ["k lépéses szomszédság", "Mi kapcsolódik ehhez a csomóponthoz k lépésen belül"],
                    ["Összefüggő komponensek", "Hány különálló darabból áll a gráf"],
                    ["PageRank", "Mely csomópontok fontosak"],
                    ["Louvain", "Hogyan oszlik a gráf közösségekre"],
                ]
            ),
            .paragraph("""
                Egy **egymillió élű** gráfon mind a négy néhány ezredmásodperc és körülbelül egy \
                másodperc között fut.
                """),
            .note("""
                Egy gráf is pontozható a táblákhoz és gyűjteményekhez használt **hatdimenziós kerettel** \
                — használja a `graph:` kulcsot egy `quality` blokkban.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Entitások jelölése listából",
        summary: "Töltsön be tulajdonnév-listát, és találja meg minden előfordulást — három, vietnamira szabott szabály szerint.",
        keywords: ["entitás", "tulajdonnév", "ner", "jelölés", "illesztés"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Töltsön be egy névlistát (cégek, termékek, helyek), és a GEditor kiemeli minden \
                előfordulást a dokumentumban, darabszámtáblával együtt.
                """),
            .heading("Három illesztési szabály, mind vietnami adatból"),
            .bullets([
                "**A leghosszabb találat nyer.** Ha az `An Phát` és a `Công ty An Phát` is a listán van, egy mondatnak, amely a hosszabb kifejezést tartalmazza, a hosszabbra kell illeszkednie — különben kettéhasad, és két entitásnak számít, ami **felfújja** a statisztikát.",
                "**Szóhatárok kellenek.** Az `An` nem illeszkedhet az `Anh` vagy a `Hoàn` belsejére. A vietnami tulajdonnevek rövidek, és számtalan közönséges szóval osztoznak szótagokon.",
                "**Kis-/nagybetűre érzéketlen, de az ÉKEZETEKRE ÉRZÉKENY.** A `CÔNG TY` és a `Công ty` egy; a `má` és a `ma` nem.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Entitásváltozatok feloldása",
        summary: "Ismerje fel a `Cty An Phát`-ot és a `Công ty An Phát`-ot egynek — a döntést mégis Önre hagyva.",
        keywords: ["entitásfeloldás", "változatok", "névnormalizálás", "ismétlődések"],
        blocks: [
            .paragraph("""
                Ugyanaz a fürtözés, mint a **homályos ismétlődések** egy CSV-táblázatban — egy közös \
                megvalósítás, nem kettő.
                """),
            .paragraph("""
                A kimenet **javaslat**: átnézi az egyes fürtöket, és kiválasztja a hivatalos alakot. \
                Nincs »mindet egyesít« gomb, mert két 92 %-ban hasonló név lehet két valódi szervezet.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "A visszakereső labor",
        summary: "Mérje meg, hogy az index a helyeset találja-e meg, válaszokkal ellátott kérdéshalmazzal.",
        keywords: ["visszakeresés", "bm25", "recall", "mrr", "ndcg", "értékelés"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Töltsön be egy **értékelő halmazt** — soronként egy kérdés azoknak a szakaszoknak az \
                azonosítóival, amelyeknek vissza kellene jönniük —, majd futtassa az egész köteget az \
                indexen.
                """),
            .table(
                headers: ["Mutató", "Mire válaszol"],
                rows: [
                    ["recall@k", "A válaszhalmaz mekkora része jelenik meg az első k között"],
                    ["MRR", "Milyen mélyen van az első helyes találat"],
                    ["nDCG@k", "Jó-e a rangsor, a helyezést is beleszámítva"],
                ]
            ),
            .paragraph("""
                Az eredmények **kérdésenként** is jönnek, a legrosszabbal kezdve — ez a listája annak, \
                mit javítson a gyűjteményben, abban a sorrendben, ami a leginkább megéri.
                """),
            .warning("""
                Mindhárom mutató **átlag**, az átlag pedig sokat elrejt. Mindig olvassa el a \
                kérdésenkénti táblát, mielőtt kimondaná, hogy »az index elég jó«.
                """),
            .paragraph("""
                Két beállítás egymás mellett összevethető, és az eredmény egyenesen egy `.greport.md` \
                jelentésbe kerül, hogy a következő futás azonos legyen.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Makrók és automatizálás

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Makrók és automatizálás",
        summary: "Vegyen fel műveleteket, futtassa őket kötegben, írjon szkripteket, és vezérelje az egészet héjból.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Makrók felvétele és lejátszása",
        summary: "Vegyen fel egy sorozatot, és ismételje meg — az egész futás egy visszavonási lépés.",
        keywords: ["makró", "felvétel", "lejátszás", "ismétlés", "automatizálás"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Felvétel indítása / leállítása"),
                HelpShortcut("⌃P", "Lejátszás"),
            ]),
            .steps([
                "A `⌃R` elindítja a felvételt.",
                "Csinálja meg azt, amit ismételni akar — gépelés, kurzormozgatás, keresés, csere.",
                "Ismét `⌃R` a leállításhoz.",
                "A `⌃P` lejátssza, vagy a `Makró ▸ Lejátszás a dokumentum végéig` végigfuttatja.",
                "A `Makró ▸ Makró mentése…` nevet ad neki későbbi munkamenetekre.",
            ]),
            .heading("PARANCSOKAT vesz fel, nem nyers billentyűleütéseket"),
            .paragraph("""
                A makró **azt tárolja, amit tett**, nem azt, mely billentyűket nyomta le. Ettől \
                független a billentyűkiosztástól és attól, melyik beviteli mód aktív, és ettől lesz a \
                makrófájl **olvasható**, amikor megnyitja.
                """),
            .heading("Mikor áll meg egy makró"),
            .table(
                headers: ["Ok", "Jelentés"],
                rows: [
                    ["Elfogyott az ismétlésszám", "Normális"],
                    ["Egy `find` lépés nem talált semmit", "Így áll meg magától a »lejátszás a fájl végéig«"],
                    ["Elérte a dokumentum végét", "Nincs hová tovább"],
                    ["Ön megszakította", "`Makró ▸ Futó makró megszakítása`"],
                    ["Egy kör semmit nem változtatott és sehová nem mozdult", "Megállítva, hogy ne pörögjön örökké"],
                ]
            ),
            .note("Az egész futás — akár tízezer ismétlés is — **egy** visszavonási lépés."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Makró futtatása kötegben",
        summary: "Minden nyitott lapon, vagy egy mappányi meg nem nyitott fájlon.",
        keywords: ["köteg", "minden lap", "mappa", "makró", "maszk"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Parancs", "Hatókör", "Visszavonható"],
                rows: [
                    ["Futtatás minden lapon", "A nyitott lapok", "Igen — laponként egy visszavonási lépés"],
                    ["Futtatás egész mappán…", "Lemezen lévő fájlok, amelyek **nincsenek megnyitva**", "Nem"],
                ]
            ),
            .warning("""
                A mappán való futtatás olyan fájlokhoz nyúl, amelyek egyetlen lapon sincsenek nyitva, \
                így **nincs visszavonás**. Alapból a GEditor **új fájlokat ír**, nem írja felül az \
                eredetieket. Hagyja így, hacsak nincs mentése vagy verziókövetett tárolója.
                """),
            .heading("Fájlok szűrése maszkkal"),
            .paragraph("""
                A mappaválasztóban van **fájlnévszűrő**: írja be, hogy `*.csv;*.log`, és a makró csak \
                azokhoz nyúl. Ugyanaz a maszkszintaxis, amit a `Keresés egész mappában` használ, több \
                mintát `;` vagy `,` választ el.
                """),
            .bullets([
                "Hagyja **üresen**, és minden szövegfájlt vesz, amit a GEditor el tud olvasni — ez volt a korábbi viselkedés.",
                "A maszk **lecseréli** azt a kiterjesztéslistát, nem tovább szűkíti: írja be, hogy `*.bak`, és `.bak` fájlokon fut, noha az a kiterjesztés nincs a szöveglistán.",
                "Ha semmi nem illeszkedik, az üzenet **visszaidézi a maszkját**, ahelyett hogy üres mappát hibáztatna.",
            ]),
            .paragraph("""
                Ennek a mezőnek nagyon gyakorlati oka van: egy mappában 400 `.json` és 12 `.log` fájl \
                van, a makrója pedig csak naplókat rendez. Maszk nélkül a másik 400 is feldolgozódik — \
                és mivel a köteg új fájlokat ír, egy hiba 400 darab szemetet hagy maga után.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "A makrófájl szintaxisa",
        summary: "Hétféle lépés, a teljes JSON-formátum és két működő makró.",
        keywords: ["makró", "json", "szintaxis", "formátum", "kézi szerkesztés"],
        blocks: [
            .paragraph("""
                Minden makró **saját JSON-fájl** a GEditor `macros/` mappájában. A sérülés egy makrón \
                belül marad, és megosztani egyet egy kollégával annyi, mint egy fájlt elküldeni.
                """),
            .code(language: "text", caption: "Hol vannak a fájlok",
                  source: "~/Library/Application Support/GEditor/macros/<makrónév>.json"),
            .heading("A hétféle lépés"),
            .table(
                headers: ["Lépés", "Így írjuk", "Jelentés"],
                rows: [
                    ["Szöveg beszúrása", "`{\"insert\": {\"_0\": \"text\"}}`", "Gépel a kurzornál; kijelöléssel lecseréli azt"],
                    ["Törlés visszafelé", "`{\"deleteBackward\": {}}`", "Mint a törlőbillentyű"],
                    ["Törlés előre", "`{\"deleteForward\": {}}`", "Mint a ⌦"],
                    ["Mozgatás", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Lásd az iránylistát lent"],
                    ["Sor kijelölése", "`{\"selectLine\": {}}`", "A sorvég nélkül"],
                    ["Keresés", "`{\"find\": { … }}`", "Megkeresi és **kijelöli** a következő találatot"],
                    ["Kijelölés cseréje", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "A `$1` érvényes, ha az előző lépés regexes `find` volt"],
                ]
            ),
            .heading("Mozgásirányok"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("A teljes `find` lépés"),
            .code(language: "json", caption: "Egy find lépés négy kulcsa",
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
            .paragraph("A `mode` értéke `normal`, `extended` vagy `regex` lehet — ugyanaz a három mód, mint a keresőmezőben."),
            .heading("1. példa — a sor eleji tartománykód nagybetűssé"),
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
                Futtassa a `Makró ▸ Lejátszás a dokumentum végéig` paranccsal: hogy a `find` lépés nem \
                talál többet, épp ez a leállási feltétel.
                """),
            .heading("2. példa — a TODO-t tartalmazó sorok után következő sor törlése"),
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
                Kézzel szerkesztett makrót előbb másolaton próbáljon ki. Egy elgépelt `find` lépés \
                azonnal megállítja a makrót — ez az ártalmatlan eset. A veszélyes az a minta, amely \
                szélesebben fog, mint hitte, és egyetlen visszavonási lépésen belül több ezer helyet \
                módosít.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript-szkriptek",
        summary: "Négy függvény, egy `.js` fájl, és minden, amit tesz, egy visszavonási lépés.",
        keywords: ["szkript", "javascript", "js", "automatizálás", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Tegyen egy `.js` fájlt a GEditor `scripts/` mappájába, és futtassa a `Makró ▸ Szkript…` \
                menüpontból. Egy szkript pontosan **négy** dolgot lát:
                """),
            .table(
                headers: ["Hívás", "Jelentés"],
                rows: [
                    ["`doc.text`", "A teljes dokumentum szövege"],
                    ["`doc.selection`", "A kijelölés (üres karakterlánc, ha nincs kijelölés)"],
                    ["`doc.replace(s)`", "**A teljes dokumentum** cseréje `s`-re — egy visszavonási lépés"],
                    ["`doc.log(s)`", "Sor írása az eredménypanelre"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Számozz meg minden sort.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — tartsd meg az első három CSV-oszlopot",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Három korlát, amit tudni kell"),
            .bullets([
                "**Nincs fájlhozzáférés, nincs hálózat, nincs folyamatindítás.** Az API-felület szándékosan szűk: később bővíteni könnyű, szűkíteni pedig minden felhasználói szkriptet eltör.",
                "**Ez nem biztonsági határ.** A szkriptek ugyanabban a folyamatban futnak. Ne futtasson szkriptet, amit nem olvasott el.",
                "**Öt másodperces korlát van.** Fölötte üzenetet kap, és az alkalmazás használható marad — de annak a szkriptnek a szála **kilépésig pörög tovább**, és megeszik egy magot. Az üzenet ezt kimondja.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Szűrés külső paranccsal",
        summary: "Vezesse át a kijelölést egy Unix-parancson, és vegye vissza az eredményt.",
        keywords: ["szűrő", "külső parancs", "héj", "cső", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                A kijelölés (vagy az egész dokumentum) egy parancs `stdin`-jére kerül, és annak a \
                parancsnak a `stdout`-ja lép a helyébe.
                """),
            .code(language: "bash", caption: "Néhány gyakori",
                  source: """
                    sort -u                     # rendezés és ismétlődések eldobása
                    jq .                        # JSON újraformázása
                    tr 'a-z' 'A-Z'              # nagybetűssé
                    grep -v '^#'                # megjegyzéssorok eldobása
                    awk -F, '{print $3","$1}'   # oszlopsorrend felcserélése
                    """),
            .note("""
                Az eredmény **egy** visszavonási lépés. Ha a parancs hibakódot ad, a GEditor békén hagyja \
                a szöveget, és megmutatja a `stderr`-t.
                """),
            .warning("""
                Ez a parancs **csak a közvetlen letöltésű kiadásban** létezik. Az App Sandbox tiltja az \
                alkalmazáson kívüli kód futtatását, így az App Store-kiadásban a menüpont megmarad, és \
                megmagyarázza, miért nem elérhető.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "A `geditor` parancssori eszköz",
        summary: "Nyisson meg, tisztítson, kérdezzen, pontozzon és jelenítsen meg jelentéseket — az alkalmazás megnyitása nélkül.",
        keywords: ["cli", "parancssor", "terminál", "geditor", "szkript", "ci"],
        blocks: [
            .warning("""
                Csak a **közvetlen letöltésű** kiadásban érhető el. Az App Store-kiadás homokozóban fut, \
                így egy külső parancssori folyamat nem tud hozzá kapcsolódni.
                """),
            .heading("Fájlok megnyitása"),
            .code(language: "bash", caption: "Megnyitás, ugrás pozícióra, olvasás csőből",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # 120. sor, 5. oszlop
                    geditor -w notes.md            # várjon a fájl bezárásáig a kilépés előtt
                    geditor -r app.log             # megnyitás csak olvasásra
                    git diff | geditor             # a szabványos bemenet beolvasása új lapra
                    """),
            .table(
                headers: ["Kapcsoló", "Jelentés"],
                rows: [
                    ["`-w`, `--wait`", "Várjon a fájl bezárásáig a kilépés előtt — hogy a `git` szerkesztőjeként szolgálhasson"],
                    ["`-n`, `--new-window`", "Megnyitás új ablakban"],
                    ["`-r`, `--read-only`", "Megnyitás csak olvasásra"],
                    ["`-i`, `--info`", "Írja ki a kódolást, a sorvégeket és a sorszámot, aztán lépjen ki — **az alkalmazás megnyitása nélkül**"],
                    ["`-h`, `--help`", "Súgó megjelenítése"],
                    ["`-v`, `--version`", "Verzió megjelenítése"],
                ]
            ),
            .heading("Futtatás az alkalmazás megnyitása nélkül"),
            .paragraph("""
                Az alábbi négy parancscsoport **teljesen a parancssori folyamaton belül** fut, így \
                működik CI-ben is, ahol senki nincs bejelentkezve grafikus munkamenetbe.
                """),
            .code(language: "bash", caption: "Tisztítás recepttel",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Lekérdezés",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "A minőségi kapu — 0 siker · 1 bukás · 2 hiba",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Jelentések megjelenítése",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript és a Szolgáltatások menü",
        summary: "Olvassa és írja a dokumentumot AppleScriptből, vagy küldjön szöveget a GEditorba másik alkalmazásból.",
        keywords: ["applescript", "osascript", "szolgáltatások", "automatizálás", "parancsikonok"],
        blocks: [
            .code(language: "applescript", caption: "A nyitott dokumentum olvasása",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "A tartalom felülírása és a kijelölés olvasása",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Fájl megnyitása",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("A Szolgáltatások menü"),
            .paragraph("""
                Jelöljön ki szöveget bármely alkalmazásban, majd a `Szolgáltatások` menüvel küldje a \
                GEditorba új lapként.
                """),
            .note("""
                Az AppleScript első futtatásakor a macOS automatizálási engedélyt kér. Ez a rendszer \
                párbeszédablaka, nem a GEditoré.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Bővítménycsomagok és bővítmények",
        summary: "Kétféle bővítmény, és hogy melyik kiadásban fut mindegyik.",
        keywords: ["bővítmény", "kiterjesztés", "csomag", "natív"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Bővítménycsomagok"),
            .paragraph("""
                Egy csomag **egyetlen JSON-fájl**, amely témát, szkripteket és saját nyelveket fog \
                össze. A telepítés egy fájlt másol, az eltávolítás egyet töröl — és a csomaglista a \
                **lemezről** vezetődik le, nem egy nyilvántartásból, amely hazudhatna.
                """),
            .paragraph("**Mindkét kiadásban** működik."),
            .heading("Natív bővítmények"),
            .paragraph("""
                Az előre lefordított bővítmények **külön folyamatban** futnak, szűk API-felülettel — egy \
                összeomló bővítmény nem viszi magával az alkalmazást.
                """),
            .warning("""
                A natív bővítmények **csak a közvetlen letöltésű kiadásban** léteznek, mert az App \
                Sandbox tiltja az alkalmazáson kívülről érkező kód betöltését. Minden bővítményt **egyszer \
                kézzel jóvá kell hagyni**, az ellenőrzőösszege alapján, mielőtt futna.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Beállítások és az alkalmazás

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Beállítások és az alkalmazás",
        summary: "Beállítások, gyorsbillentyűk, témák, frissítések, átállás Notepad++-ról, hibaelhárítás.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Beállítások",
        summary: "Minden választás egy olvasható JSON-fájlban él, amelyet másik Macre másolhat.",
        keywords: ["beállítások", "opciók", "konfiguráció", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Beállítások megnyitása")]),
            .paragraph("""
                Nincs OK és nincs Mégse — egy módosítás azonnal érvénybe lép és kiíródik, a macOS \
                módján.
                """),
            .heading("A konfigurációs fájl"),
            .code(language: "text", caption: "Hol van",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Ez egy **behúzott JSON-fájl, amelyet elolvashat és kézzel szerkeszthet**. Másolja át egy \
                másik Macre, és az egész beállítása vele megy. A beállításokban lévő `Konfigurációs fájl \
                megnyitása` gomb egyenesen odavisz.
                """),
            .heading("A kulcsok"),
            .table(
                headers: ["Kulcs", "Alapérték", "Jelentés"],
                rows: [
                    ["`fontSize`", "`13`", "A szerkesztő betűmérete"],
                    ["`tabWidth`", "`4`", "Hány oszlop széles egy TAB"],
                    ["`usesTabsForIndent`", "`false`", "Behúzás TAB-bal szóköz helyett"],
                    ["`languageIndent`", "`{}`", "Nyelvenkénti behúzás — lásd az üres karakterek oldalát"],
                    ["`smartIndent`", "`true`", "Automatikus behúzás új sorban"],
                    ["`highlightAllMatches`", "`true`", "Minden keresési találat kiemelése"],
                    ["`ligatures`", "`false`", "Ligatúrák — lásd a tábla alatti megjegyzést"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Sorvégi üres karakterek levágása mentéskor"],
                    ["`normalizeToNFCOnSave`", "`false`", "Unicode normalizálása NFC-re mentéskor"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Új fájlok kódolása"],
                    ["`defaultEOL`", "`\"lf\"`", "Új fájlok sorvégei"],
                    ["`language`", "`\"system\"`", "A felület nyelve"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "az alapértelmezett téma", "Melyik színtéma használatos"],
                    ["`showWelcomeOnLaunch`", "`true`", "Üdvözlőablak megnyitása indításkor"],
                    ["`keyBindings`", "`{}`", "Csak azok a billentyűk, amelyeket megváltoztatott"],
                ]
            ),
            .note("""
                **Miért vannak a ligatúrák alapból KIKAPCSOLVA.** Egy ligatúra a `!=`-t vagy a `->`-t \
                **egyetlen** jellé olvasztja, így a képernyőn látott karakterek már nem felelnek meg a \
                fájlban lévőknek — az oszlopszerkesztő, az oszlopmód és az oszlopnál tördelés pedig mind \
                oszlopokban mér. Kapcsolja be, ha folyószöveget ír, vagy ha épp a ligatúrái miatt \
                választott programozói betűtípust (Fira Code, JetBrains Mono).
                """),
            .heading("A szomszédos mappák"),
            .table(
                headers: ["Mappa", "Mit tartalmaz"],
                rows: [
                    ["`macros/`", "Mentett makrók, mindegyik egy JSON-fájl"],
                    ["`scripts/`", "JavaScript-szkriptek"],
                    ["`themes/`", "Színtémák"],
                    ["`grammars/`", "Saját nyelvek"],
                ]
            ),
            .warning("""
                Egy **újabb** GEditor által írt konfigurációs fájlt egy régebbi **nem ír felül** — a \
                régebbi alapértékekkel fut, és ezt megmondja. A felülírás a legbiztosabb módja annak, \
                hogy tönkretegyük valakinek a beállítását, aki két gépet szinkronizál, és sosem tudná \
                meg, miért.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Az állapotsor",
        summary: "Tíz mező alul — mind olvasható és mind kattintható.",
        keywords: ["állapotsor", "pozíció", "kódolás", "csak olvasható", "méret"],
        blocks: [
            .paragraph("""
                Ez a legnagyobb különbség más szerkesztők állapotsorához képest: **egyetlen mező sem csak \
                olvasható**. Ha rossz értéket lát, a rákattintás a javítás módja, ahelyett hogy menükben \
                keresgélne.
                """),
            .table(
                headers: ["Mező", "Mit mond", "Kattintásra"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "a kurzor helyét — az oszlop KARAKTERBEN, a `@340` a bájtpozíció",
                     "megnyitja az `Ugrás` mezőt"],
                    ["`11 byte · 3 dòng`", "a dokumentum méretét",
                     "megszámolja a bájtokat · karaktereket · szavakat · sorokat"],
                    ["`🔒 Chỉ đọc`", "csak akkor jelenik meg, ha a dokumentum zárolt",
                     "megmondja, MIÉRT zárolt, és feloldja, ha lehet"],
                    ["`View` / `Code`", "melyik nézetben van", "vált (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "CSV-mód és a használt elválasztó",
                     "kapcsolja a CSV-módot, vagy **újraválasztja az elválasztót**"],
                    ["`Đang theo dõi`", "fut a `tail -f`", "—"],
                    ["`UTF-8`", "a kódolás", "újraértelmezés, vagy átalakítás másik kódolásra"],
                    ["`LF`", "sorvégstílus", "váltás LF · CRLF · CR között"],
                    ["`Python`", "a szintaxisszínezés nyelve", "válasszon másikat, vagy vissza a kiterjesztés szerinti felismerésre"],
                    ["`Tab: 4`", "a behúzás szélessége", "2 · 4 · 8, általánosan vagy **csak ehhez a nyelvhez**"],
                    ["`Ngắt: tắt`", "tördelési mód", "végigmegy a három módon"],
                ]
            ),
            .heading("Három mező, amely megér egy második pillantást"),
            .bullets([
                "**`@340` — a bájtpozíció.** Ezt a számot beszéli a termék minden más eszköze: a JSON- és XML-hibák, a `--doc-sweep` kimenete, a bináris nézegető és az `Ugrás @340` mező. Olvassa itt, írja ott.",
                "**Egy `~` az oszlopnál** azt jelenti, hogy a szám BÁJTOKAT számol, nem látható oszlopokat — csak 200 kB-nál hosszabb sorokon fordul elő, ahol a karakterszámolás minden kurzormozgást lelassítana.",
                "**A `CSV · …` rákattintva újraválaszthatja az elválasztót.** A felismerés tévedhet, és ha téved, minden oszlopművelet elcsúszik anélkül, hogy bármi jelezné. Így mond ellent — csak **ÚJRAOLVASSA** a fájlt, egyetlen bájtot sem változtatva (szemben a `CSV ▸ Elválasztó módosítása…` paranccsal, amely újraírja).",
            ]),
            .note("""
                Az a mező, amely nem vonatkozik a nyitott fájlra, **rejtve van**, nem szürke: a `Csak \
                olvasható` csak akkor jelenik meg, ha a dokumentum valóban zárolt, a `CSV · …` pedig csak \
                CSV-módban.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Gyorsbillentyűk módosítása",
        summary: "Módosítson egyes billentyűket, vagy vegye át a Notepad++ teljes kiosztását.",
        keywords: ["gyorsbillentyű", "billentyűkiosztás", "előbeállítás"],
        blocks: [
            .paragraph("""
                A `Beállítások…` alatt van egy Gyorsbillentyűk rész két gyors gombbal: **A Notepad++ \
                előbeállítás használata** és **Vissza az alapértékekre**.
                """),
            .paragraph("""
                A konfigurációs fájl csak azt jegyzi fel, amit **az alapértékekhez képest módosított**. \
                Így, amikor a GEditor egy új változatban módosít egy alapértelmezett billentyűt, nem \
                marad a régi kiosztással anélkül, hogy bárki szólna.
                """),
            .note("""
                Két parancs nem oszthat gyorsbillentyűt. Ha mégis, az AppKit csendben csak az **első** \
                menüpontot indítja el, és a másik parancs elrontottnak látszik — ezért van a GEditorban \
                ellenőrzés, amely ezt megakadályozza.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Témák, világos és sötét",
        summary: "Kövesse a rendszert, világos vagy sötét; és egy téma szerkeszthető JSON-fájl.",
        keywords: ["téma", "színek", "sötét mód", "világos", "megjelenés"],
        blocks: [
            .paragraph("A `Beállítások…` alatt választható a `Rendszer követése`, a `Világos` vagy a `Sötét`, és a színtéma."),
            .paragraph("""
                Egy téma JSON-fájl a `themes/` mappában. Az `Aktuális téma exportálása` gomb kiír egyet \
                kiindulópontnak a sajátjához.
                """),
            .note("""
                Egy elgépelt szín a témafájlban **az alapértelmezett téma** színére esik vissza, nem \
                feketére. A fekete tervezői döntésnek látszik, és a felhasználó máshol keresné a hibát.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Frissítések, verziók és kilépés",
        summary: "Miben tér el a frissítés a két kiadás között.",
        keywords: ["frissítés", "verzió", "névjegy", "kilépés"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Kiadás", "Frissül"],
                rows: [
                    ["App Store", "Az App Store-on át, mint minden más alkalmazás"],
                    ["Közvetlen letöltés", "`Frissítések keresése…` az alkalmazáson belül"],
                ]
            ),
            .paragraph("""
                A `GEditor névjegye` mutatja a futó verziót és azt, melyik kiadás — hasznos hibajelentéskor.
                """),
            .note("""
                Az App Store-kiadásban a `Frissítések keresése…` **a menüben marad**, és megmagyarázza, \
                miért nem érvényes, ahelyett hogy eltűnne. Egy hiányzó menüpont kérdés a támogatásnak.
                """),
            .paragraph("A kilépés nem veszít munkát: a munkamenet visszatér, amikor legközelebb megnyitja."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Ennek a súgóablaknak a használata",
        summary: "Keressen a könyvben, váltson nyelvet, és hozza vissza az üdvözlőablakot.",
        keywords: ["súgó", "útmutató", "keresés", "üdvözlés", "nyelv"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "A súgóablak megnyitása")]),
            .bullets([
                "A bal felső keresőmező a **törzsszövegben és a kódmintákban** is néz — egy csupasz beállításkulcs, mint a `fail_under`, a megfelelő oldalra visz.",
                "Az **ékezet nélküli** gépelés is megtalálja az ékezetes szöveget.",
                "A `Vissza` gomb az előző oldalra tér.",
                "A `Másolás` gomb minden kódblokknál azt a blokkot másolja.",
            ]),
            .heading("Olvasás más nyelven"),
            .paragraph("""
                Az ablak jobb felső menüje **a könyv nyelvét** választja, függetlenül az alkalmazás \
                felületi nyelvétől. A váltás **azon az oldalon tartja**, amelyet olvas — az oldalak \
                azonosítóit szándékosan nem fordítjuk, épp azért, hogy ez működjön.
                """),
            .note("""
                Csak azok a nyelvek szerepelnek, amelyekhez valóban van könyv. Egy menüpont, amely átvált \
                valamire, és a szöveg változatlan marad, hazudó menüpont volna.
                """),
            .heading("Az üdvözlőablak visszahozása"),
            .paragraph("""
                Ha bejelölte a **Ne nyíljon meg ez az ablak indításkor** lehetőséget, nyissa meg újra a \
                `Súgó ▸ Funkciótúra` menüponttal — az ablak alján lévő jelölőnégyzet ismét megjelenik, és \
                kivehető a jelölés.
                """),
            .paragraph("Vagy állítsa a `showWelcomeOnLaunch` értékét vissza `true`-ra a `settings.json`-ban."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Notepad++-ról GEditorra",
        summary: "Mely billentyűk cserélnek helyet, mi működik másként, és mi hiányzik.",
        keywords: ["notepad++", "átállás", "windows", "gyorsbillentyűk"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Néhány billentyű macOS-en **helyet cserél** ahelyett, hogy a `Ctrl`-ból egyszerűen `⌘` \
                lenne. Íme az összevetés.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Miért"],
                rows: [
                    ["`Ctrl+D` Sor kettőzése", "**⇧⌘D**", "Itt a `⌘D` több kurzor, mint minden Mac-szerkesztőben"],
                    ["`Ctrl+L` Sor törlése", "**⌘K**", "macOS-en a `⌘L` azt jelenti: »ugrás sorra«"],
                    ["`Ctrl+G` Ugrás sorra", "**⌘L**", "Ez a kettő helyet cserél"],
                    ["`Ctrl+Q` Megjegyzés", "**⌘/**", "macOS-szokás"],
                    ["`Ctrl+Shift+↑/↓` Sor mozgatása", "**⌥↑ / ⌥↓**", "macOS-en a `⌃` a Mission Controlé"],
                    ["`F3` Következő keresése", "**⌘G**", "macOS-szokás"],
                    ["`Ctrl+F2` Könyvjelző be/ki", "**⌘F2**", "Az F2 és a ⇧F2 továbbra is jelölők közt ugrál"],
                    ["`Alt` + húzás oszlopokhoz", "**⌥ + húzás**", "Ugyanaz"],
                    ["`Ctrl+Alt+Shift+↓` Oszlopszerkesztő", "**⌥⌘C**", "macOS-szokás"],
                ]
            ),
            .note("Inkább nem tanulná újra? `Beállítások ▸ Gyorsbillentyűk ▸ A Notepad++ előbeállítás használata`."),
            .heading("Amit a Notepad++ tud, és itt másként működik"),
            .bullets([
                "**A munkamenetek** maguktól állnak vissza, a mentetlen lapokkal együtt — nincs mit bekapcsolni.",
                "**A könyvjelzőknek kilenc színük van**, és egy sor többet is viselhet egyszerre.",
                "**A dokumentumtérkép** az *egész* fájlt írja le, nem csak a látható részt.",
                "**A makrók** lejátszhatók »a dokumentum végéig« és »minden lapon«, és az egész futás egy visszavonási lépés.",
            ]),
            .heading("Amit a GEditor hozzátesz"),
            .bullets([
                "Egy **adattisztító pad** és **adatprofilok** CSV-fájlokhoz.",
                "**SQL-lekérdezések** közvetlenül CSV-fájlon.",
                "**Régi vietnami karakterkódolások** — TCVN3, VISCII, VNI-Windows, olvasva, írva és automatikusan felismerve.",
                "**Ékezetfüggetlen keresés** minden szűrőmezőben.",
                "**`.greport.md` jelentések** újraszámolódó táblákkal és diagramokkal.",
                "**A `geditor` parancssori eszköz** a közvetlen letöltésű kiadásban.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Gyakori problémák",
        summary: "Hat helyzet, amelytől az emberek azt hiszik, elromlott az alkalmazás.",
        keywords: ["hiba", "probléma", "nem működik", "hibaelhárítás", "miért"],
        blocks: [
            .table(
                headers: ["Tünet", "Szokásos ok"],
                rows: [
                    ["A vietnami szöveg kacatként jelenik meg", "Rossz kódolás — kattintson a kódolásra az állapotsoron"],
                    ["Az ékezetes szöveg keresése nem talál semmit", "A fájl felbontott Unicode-ban van — futtassa az `Unicode normalizálása` parancsot NFC-re"],
                    ["Egy menüpont szürke", "Az App Store-kiadás nem tudja futtatni azt a parancsot — a menüpont megmagyarázza, miért"],
                    ["A zárójelpárosítás megtagadja a futást", "A dokumentum 1 MB fölött van — rossz párt kiemelni rosszabb, mint semmit"],
                    ["Az állapotsor oszlopánál `~` van", "A dokumentum 200 kB fölött van, tehát az bájtszám, nem látható oszlop"],
                    ["Egy SQL-lekérdezés azt mondja, előbb menteni kell a fájlt", "A DuckDB **fájlokat** olvas, nem a szerkesztett puffert"],
                ]
            ),
            .heading("Amikor a GEditor váratlanul kilép"),
            .paragraph("""
                A következő indításkor egy szalag ezt kiírja, **Jelentés megnyitása** gombbal — a \
                jelentés lapként nyílik meg, amelyet úgy olvashat és másolhat, mint bármely más \
                szövegfájlt.
                """),
            .bullets([
                "A jelentés csak a **verziót, a macOS-kiadást, a gép architektúráját, a szignál nevét és a hívási vermet** hordozza.",
                "**Semmilyen dokumentumtartalom, és fájlútvonalak sem** — egy olyan útvonal, mint a `~/Asztal/bérek-december.xlsx`, már három magánjellegű dolgot elárult, mielőtt bárki megnyitná.",
                "**Sehová nem küldünk semmit.** Nincs automatikus feltöltés és nincs fogadó kiszolgáló; a fájl a `~/Library/Application Support/GEditor/crash/` mappában marad, amíg meg nem nyitja vagy nem törli.",
                "Ha egyszer megnyitotta a jelentést, a következő indítás nem említi újra.",
            ]),
            .heading("Hol nézzen tovább"),
            .bullets([
                "Az állapotsor mutatja a kódolást, a sorvégeket, a nyelvet és a tördelési módot — minden mező kattintható.",
                "A `settings.json` kézzel szerkeszthető, ha a beállításablak nem elég.",
                "A `GEditor névjegye` megadja a verziót és a kiadást, amire egy hibajelentésnek szüksége van.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
