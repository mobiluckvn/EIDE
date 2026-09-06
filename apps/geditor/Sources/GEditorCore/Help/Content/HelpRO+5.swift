import Foundation

/// Conținut de ajutor în română — partea 5: rapoarte, cunoștințe, automatizare și aplicație.
extension HelpRO {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Rapoarte și diagrame",
        summary: "Un fișier text care produce un raport HTML cu cifre recalculate, plus diagrame Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "Rapoarte `.greport.md`",
        summary: "Markdown plus patru feluri de blocuri rulabile — scrieți în stânga, previzualizare în dreapta.",
        keywords: ["raport", "greport", "html", "export", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Un fișier `.greport.md` este **Markdown obișnuit** plus câteva blocuri împrejmuite \
                rulabile. Randarea lui produce un fișier HTML **de sine stătător** — fără rețea, fără \
                fișiere însoțitoare — pe care îl poate deschide oricine.
                """),
            .paragraph("""
                Fiind text simplu, poate fi **comparat, versionat și partajat** — aceeași idee ca la \
                rețetele de curățare și la seturile de reguli de calitate.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — un raport complet",
                  source: """
                    ---
                    title: Raport de vânzări pentru august
                    source: sales-2026-08.csv
                    ---

                    # Raport de vânzări pentru august

                    Cifre la 31 august 2026.

                    ## Venituri pe provincii

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Venituri pe provincii
                    y_label: Venituri
                    number_format: vi
                    suffix: " ₫"
                    source: Sursă — sales-2026-08.csv
                    ```

                    ## Calitatea datelor-sursă

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Felurile de blocuri"),
            .table(
                headers: ["Bloc", "Produce"],
                rows: [
                    ["`query`", "Un tabel, dintr-o instrucțiune SQL pentru DuckDB"],
                    ["`chart`", "Un grafic"],
                    ["`quality`", "O fișă de calitate a datelor"],
                    ["`mining`", "Un tabel de clasament din explorarea pe grupuri"],
                    ["`mermaid`", "O diagramă"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                Blocul `---` de sus declară `title` și `source` — sursa implicită de date pentru fiecare \
                bloc care nu o numește pe a lui.
                """),
            .note("""
                Previzualizarea se reconstruiește când vă opriți din scris, dar doar **analizează**; nu \
                rulează interogări la fiecare apăsare de tastă. Erorile de document și cele de date sunt \
                raportate separat — *»blocului chart îi lipsește cheia `kind`«* e o eroare de fișier, \
                *»coloana `doanh_thu` nu există«* e o eroare de date.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "Blocul `query`",
        summary: "O instrucțiune DuckDB devine un tabel în raport.",
        keywords: ["interogare", "sql", "tabel", "raport", "bloc"],
        blocks: [
            .paragraph("""
                Conținutul blocului este **o singură instrucțiune SQL**, rulată pe sursa raportului. \
                Tabelul se numește `t`, în același dialect ca în panoul de interogări.
                """),
            .code(language: "text", caption: "Un bloc query cu parametru",
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
                `:thang` este un **parametru**. Se dă la randare — din shell cu `--param thang=8`, sau \
                dintr-un fișier-listă când se generează rapoarte în lot.
                """),
            .note("""
                Tabelele dintr-un raport de date **ar trebui să vină dintr-un bloc query**, nu scrise de \
                mână. Un tabel scris de mână nu se recalculează când se schimbă cifrele și, mai devreme \
                sau mai târziu, contrazice restul raportului.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "Blocul `chart`",
        summary: "O configurație YAML devine un grafic — și cea mai importantă regulă a formatului.",
        keywords: ["grafic", "yaml", "raport", "desen"],
        blocks: [
            .code(language: "yaml", caption: "Fiecare cheie a unui bloc chart",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Venituri pe provincii
                    x_label: Provincie
                    y_label: Venituri
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Sursă — sales.csv, la 26 aug. 2026
                    """),
            .heading("Fără `query`, folosește rezultatul blocului query IMEDIAT DEASUPRA"),
            .paragraph("""
                Aceasta este cea mai importantă regulă a formatului. Datorită ei, raportul obișnuit »un \
                tabel, apoi un grafic al acelui tabel« nu repetă SQL-ul — iar a-l repeta înseamnă că cele \
                două copii ajung să se despartă, și atunci tabelul și graficul spun lucruri diferite pe \
                aceeași pagină.
                """),
            .warning("""
                În schimb, **ordinea blocurilor contează**: inserarea unui bloc query între ele schimbă \
                datele graficului de dedesubt.
                """),
            .heading("De ce `source` este o cheie separată"),
            .paragraph("""
                O notă de sursă scrisă ca text sub grafic se vede perfect — pe ecran. Dar graficul va fi \
                exportat ca PNG și lipit altundeva, iar textul rămâne în urmă. Ca și cheie, se desenează \
                **în interiorul imaginii** și călătorește odată cu ea.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "Blocul `quality`",
        summary: "O fișă de calitate a datelor în interiorul raportului.",
        keywords: ["calitate", "fișă", "raport", "bloc"],
        blocks: [
            .code(language: "yaml", caption: "Fiecare cheie a unui bloc quality",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # gol înseamnă sursa proprie a raportului
                    title: Calitatea datelor de vânzări din august
                    rules: true                 # arată tabelul pe reguli, trecut/picat
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # fixează data de referință pentru "Actualitate"
                    fail_under: 90              # sub asta, fișa capătă culoare de avertisment
                    """),
            .table(
                headers: ["`chart`", "Desenează"],
                rows: [
                    ["`violations`", "Numărul de rânduri pentru regulile **picate** — răspunde la »ce reparăm întâi«"],
                    ["`dimensions`", "Scorurile celor șase dimensiuni"],
                    ["`none`", "Doar tabel, fără grafic"],
                ]
            ),
            .note("""
                Puneți `now:` într-un raport periodic. Fără el, *Actualitatea* compară cu momentul \
                randării, așa că re-randarea raportului de luna trecută dă alt scor decât cel publicat.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "Blocul `mining`",
        summary: "Clasați grupurile după anomalii, eroare de prognoză sau divergență de corelație.",
        keywords: ["explorare", "raport", "clasament de grupuri"],
        blocks: [
            .code(language: "yaml", caption: "Fiecare cheie a unui bloc mining",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # coloana pentru anomalii și prognoză
                    pair: chi_phi             # a doua coloană, pentru corelația pe grupuri
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # gol înseamnă sursa proprie a raportului
                    title: Explorare pe provincii
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Clasează după"],
                rows: [
                    ["`anomalies`", "Grupul cu cele mai multe rânduri anormale"],
                    ["`forecast_error`", "Grupul a cărui prognoză e cea mai proastă"],
                    ["`correlation_gap`", "Grupul a cărui corelație se abate cel mai mult de la tabelul unificat — prinde paradoxul lui Simpson"],
                ]
            ),
            .warning("""
                **Nicio cheie nu dezactivează blocul »Metodă«.** Un clasament de grupuri fără metoda lui \
                nu-i lasă cititorului nicio cale de a ști față de ce gard s-au măsurat »cele mai multe \
                anomalii«. Cine vrea să-l ascundă știe deja răspunsul pe care îl dorește.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Generarea rapoartelor în lot",
        summary: "Un șablon, o listă de parametri, multe rapoarte.",
        keywords: ["lot", "în masă", "parametri", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Un șablon de raport, rulat pentru fiecare filială sau pentru fiecare lună. Lista de \
                parametri este un fișier CSV sau JSON — **un rând pe raport**.
                """),
            .code(language: "text", caption: "list.csv — un rând pe raport",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Randați tot lotul din shell",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Sau un raport cu parametri dați manual",
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
        title: "Diagrame Mermaid",
        summary: "Desenați diagrame în text, modificați-le prin comenzi, previzualizare sincronizată în ambele sensuri.",
        keywords: ["mermaid", "diagramă", "organigramă", "secvență", "desen"],
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
                Mermaid desenează diagrame **din text**: scrieți o descriere, iar mașina o desenează. O \
                diagramă poate fi astfel comparată și versionată — lucru pe care un fișier-imagine nu-l \
                poate.
                """),
            .paragraph("""
                Deschideți `Diagramă Mermaid: previzualizare` pentru o vedere lângă editor. Cele două sunt \
                **sincronizate în ambele sensuri**: selectați un element în imagine, iar cursorul sare la \
                linia lui.
                """),
            .heading("Modificați prin comenzi, nu rescriind"),
            .table(
                headers: ["Comandă", "Ce face"],
                rows: [
                    ["Inserează un șablon…", "Inserează un schelet gata făcut pentru fiecare tip de diagramă"],
                    ["Adaugă un element…", "Adaugă un nod sau un participant"],
                    ["Leagă cele două elemente selectate", "Desenează o săgeată între ele"],
                    ["Modifică eticheta elementului selectat…", "Schimbă textul fără să căutați linia"],
                    ["Șterge elementul selectat", "Elimină nodul **și** fiecare muchie care îl atinge"],
                    ["Mută mesajul sus / jos", "Rearanjează pașii într-o diagramă de secvență"],
                    ["Reformatează", "Indentează și aliniază tot blocul"],
                ]
            ),
            .heading("Extragerea într-un fișier și reîncorporarea"),
            .paragraph("""
                Diagramele mari își au locul într-un fișier `.mmd` propriu: `Extrage blocul într-un fișier \
                .mmd…` îl scoate afară și lasă o referință. `Reîncorporează fișierul referit` face invers, \
                când trebuie să trimiteți un singur fișier.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Sintaxă Mermaid uzuală",
        summary: "Cele patru tipuri de diagrame cele mai folosite, fiecare cu un șablon care merge.",
        keywords: ["mermaid", "sintaxă", "organigramă", "secvență", "gantt", "clase", "șablon"],
        blocks: [
            .code(language: "mermaid", caption: "Organigramă — aprobarea unei comenzi",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Diagramă de secvență — un flux de plată",
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
            .code(language: "mermaid", caption: "Diagramă de clase — un model de date",
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
            .code(language: "mermaid", caption: "Gantt — un plan de lansare",
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
                headers: ["Formă de nod", "Scrieți"],
                rows: [
                    ["Dreptunghi", "`A[Label]`"],
                    ["Rotunjit", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Romb (decizie)", "`A{Label}`"],
                    ["Cilindru (date)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Săgeată", "Scrieți"],
                rows: [
                    ["Continuă, cu vârf", "`A --> B`"],
                    ["Punctată", "`A -.-> B`"],
                    ["Groasă", "`A ==> B`"],
                    ["Cu etichetă", "`A -- label --> B`"],
                ]
            ),
            .note("""
                Direcția unei organigrame vine imediat după `flowchart`: `TD` de sus în jos, `LR` de la \
                stânga la dreapta, plus `BT` și `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Pachetul de cunoștințe

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Pachetul de cunoștințe",
        summary: "Fragmentare, indexuri de căutare, grafuri de cunoștințe, entități și evaluarea regăsirii.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Ce este pachetul de cunoștințe",
        summary: "Unelte pentru pregătirea și verificarea datelor pentru un sistem care răspunde la întrebări din documente.",
        keywords: ["rag", "cunoștințe", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Când construiți un sistem care răspunde la întrebări dintr-o colecție de documente, cea \
                mai mare parte a muncii nu e în model, ci în **pregătirea datelor**: tăierea documentelor \
                în fragmente rezonabile, verificarea calității acelor fragmente, construirea unui index și \
                **măsurarea faptului că regăsirea găsește într-adevăr lucrul potrivit**.
                """),
            .paragraph("""
                Acest capitol este exact setul de unelte pentru asta. Rulează **în întregime pe mașina \
                dumneavoastră** și nu atinge niciodată rețeaua.
                """),
            .table(
                headers: ["Sarcină", "Unealtă"],
                rows: [
                    ["Tăierea documentelor în fragmente", "Previzualizarea fragmentării"],
                    ["Inspectarea și evaluarea fragmentelor", "Inspecția fragmentelor JSONL"],
                    ["Conversia între forme de date", "Conversia cunoștințelor"],
                    ["Construirea și inspectarea unui graf de relații", "Graf de cunoștințe"],
                    ["Găsirea numelor proprii în text", "Marcarea entităților"],
                    ["Măsurarea calității regăsirii", "Laboratorul de regăsire"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Fragmentarea și inspectarea unei colecții JSONL",
        summary: "Previzualizați limitele fragmentelor chiar pe text, apoi evaluați toată colecția.",
        keywords: ["chunk", "jsonl", "colecție", "suprapunere", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Previzualizarea fragmentării"),
            .paragraph("""
                Deschideți un document text sau Markdown, alegeți o strategie și o mărime de fragment. \
                Limitele sunt **evidențiate chiar pe text**, ca să vedeți unde cade o tăietură la mijlocul \
                unei propoziții sau printr-un tabel, înainte de a exporta ceva.
                """),
            .bullets([
                "**Mărime fixă** cu suprapunere.",
                "**După structură** — la titlurile Markdown, păstrând firul documentului.",
                "**Pe paragrafe**, contopite până la atingerea mărimii.",
            ]),
            .heading("Inspectarea unei colecții JSONL existente"),
            .paragraph("""
                Pentru o colecție pe care o aveți deja (un fragment JSON pe linie), `JSONL: inspectează \
                fragmentele…` răspunde: ce linii nu sunt JSON valid, ce fragmente sunt prea scurte sau \
                prea lungi, care se dublează între ele și care au fost tăiate la mijlocul unei propoziții.
                """),
            .note("""
                O colecție poate fi evaluată și cu **același cadru cu șase dimensiuni** ca datele tabelare \
                — folosiți cheia `corpus:` în blocul `quality` al unui raport.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Conversia formatelor de cunoștințe",
        summary: "Fragmente între JSONL · CSV · Markdown, grafuri între DOT · Mermaid · liste de muchii.",
        keywords: ["conversie", "jsonl", "dot", "mermaid", "listă de muchii"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Din", "În"],
                rows: [
                    ["Fragmente JSONL", "CSV · Markdown"],
                    ["Fragmente CSV", "JSONL · Markdown"],
                    ["Graf DOT", "Mermaid · listă de muchii"],
                    ["Listă de muchii", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Există o **previzualizare de cinci rânduri** înainte de crearea filei noi, același \
                mecanism ca la conversia CSV.
                """),
            .paragraph("""
                `Deschide triplete/muchii ca tabel` arată un fișier de triplete sau o listă de muchii ca \
                tabel — filtrați și sortați ca la orice alt CSV.
                """),
            .note("""
                Direcția **Markdown → JSONL** nu este în această comandă: acea direcție *este* \
                fragmentarea, iar comanda vă trimite acolo. Două implementări ale aceleiași tăieturi ar da \
                două rezultate diferite.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Grafuri de cunoștințe",
        summary: "Verificați sintaxa, evaluați sănătatea și rulați algoritmi pe grafuri cu un milion de muchii.",
        keywords: ["graf", "dot", "cypher", "pagerank", "louvain", "verificare de sintaxă"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor citește grafuri ca **DOT**, ca **liste de muchii** și ca **triplete**. `Verifică \
                sintaxa grafului` prinde erorile de sintaxă, nodurile izolate și muchiile care arată spre \
                noduri inexistente.
                """),
            .heading("Algoritmi disponibili"),
            .table(
                headers: ["Algoritm", "Răspunde la"],
                rows: [
                    ["Vecinătate la k pași", "Ce este legat de acest nod în k pași"],
                    ["Componente conexe", "Din câte bucăți separate e alcătuit graful"],
                    ["PageRank", "Ce noduri sunt importante"],
                    ["Louvain", "Cum se împarte graful în comunități"],
                ]
            ),
            .paragraph("""
                Pe un graf cu **un milion de muchii**, toți patru rulează undeva între câteva milisecunde \
                și circa o secundă.
                """),
            .note("""
                Un graf poate fi evaluat și cu **cadrul cu șase dimensiuni** folosit pentru tabele și \
                colecții — folosiți cheia `graph:` într-un bloc `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Marcarea entităților dintr-o listă",
        summary: "Încărcați o listă de nume proprii și găsiți fiecare apariție — după trei reguli făcute pentru vietnameză.",
        keywords: ["entitate", "nume propriu", "ner", "marcare", "potrivire"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Încărcați o listă de nume (firme, produse, locuri), iar GEditor evidențiază fiecare \
                apariție din document, cu un tabel de numărători.
                """),
            .heading("Trei reguli de potrivire, toate din date vietnameze"),
            .bullets([
                "**Câștigă potrivirea cea mai lungă.** Cu `An Phát` și `Công ty An Phát` amândouă în listă, o propoziție care conține expresia mai lungă trebuie să se potrivească cu cea lungă — altfel se rupe în două și se numără ca două entități, ceea ce **umflă** statistica.",
                "**Sunt necesare limite de cuvânt.** `An` nu trebuie să se potrivească în interiorul lui `Anh` sau `Hoàn`. Numele proprii vietnameze sunt scurte și împart silabe cu nenumărate cuvinte obișnuite.",
                "**Insensibil la majuscule, dar SENSIBIL la diacritice.** `CÔNG TY` și `Công ty` sunt una; `má` și `ma` nu sunt.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Rezolvarea variantelor de entități",
        summary: "Recunoașteți `Cty An Phát` și `Công ty An Phát` ca fiind una — lăsându-vă totuși decizia.",
        keywords: ["rezolvarea entităților", "variante", "normalizarea numelor", "duplicate"],
        blocks: [
            .paragraph("""
                Aceeași grupare ca la **duplicatele aproximative** dintr-un tabel CSV — o singură \
                implementare comună, nu două.
                """),
            .paragraph("""
                Ieșirea este o **propunere**: parcurgeți fiecare grup și alegeți forma canonică. Nu există \
                buton »îmbină tot«, pentru că două nume asemănătoare în proporție de 92 % pot fi două \
                organizații reale.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Laboratorul de regăsire",
        summary: "Măsurați dacă indexul găsește lucrul potrivit, folosind un set de întrebări cu răspunsuri.",
        keywords: ["regăsire", "bm25", "recall", "mrr", "ndcg", "evaluare"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Încărcați un **set de evaluare** — fiecare linie o întrebare cu identificatorii \
                fragmentelor care ar trebui să revină — apoi rulați tot lotul pe index.
                """),
            .table(
                headers: ["Indicator", "Răspunde la"],
                rows: [
                    ["recall@k", "Cât din mulțimea de răspunsuri apare în primele k"],
                    ["MRR", "Cât de jos stă primul rezultat corect"],
                    ["nDCG@k", "Dacă ordinea e bună, cu poziția inclusă"],
                ]
            ),
            .paragraph("""
                Rezultatele vin și **pe întrebări**, cele mai proaste întâi — aceea e lista dumneavoastră \
                cu ce trebuie reparat în colecție, în ordinea care merită cel mai mult.
                """),
            .warning("""
                Toate cele trei măsuri sunt **medii**, iar o medie ascunde multe. Citiți întotdeauna \
                tabelul pe întrebări înainte de a conchide că »indexul e destul de bun«.
                """),
            .paragraph("""
                Două configurații pot fi comparate alături, iar rezultatul cade direct într-un raport \
                `.greport.md`, ca rularea următoare să fie identică.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Macrocomenzi și automatizare

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Macrocomenzi și automatizare",
        summary: "Înregistrați acțiuni, rulați-le în lot, scrieți scripturi și conduceți totul din shell.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Înregistrarea și redarea macrocomenzilor",
        summary: "Înregistrați o succesiune și repetați-o — toată rularea e un singur pas de anulare.",
        keywords: ["macrocomandă", "înregistrare", "redare", "repetare", "automatizare"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Pornește / oprește înregistrarea"),
                HelpShortcut("⌃P", "Redă"),
            ]),
            .steps([
                "`⌃R` pornește înregistrarea.",
                "Faceți ce vreți repetat — scriere, mutarea cursorului, căutare, înlocuire.",
                "`⌃R` din nou pentru oprire.",
                "`⌃P` o redă, sau `Macro ▸ Redă până la sfârșitul documentului` o rulează până la capăt.",
                "`Macro ▸ Salvează macrocomanda…` îi dă un nume pentru sesiuni viitoare.",
            ]),
            .heading("Înregistrează COMENZI, nu apăsări brute de taste"),
            .paragraph("""
                O macrocomandă stochează **ce ați făcut**, nu ce taste ați apăsat. Asta o face \
                independentă de aranjamentul tastaturii și de metoda de introducere activă, și face \
                fișierul macrocomenzii **lizibil** când îl deschideți.
                """),
            .heading("Când se oprește o macrocomandă"),
            .table(
                headers: ["Motiv", "Sens"],
                rows: [
                    ["S-a terminat numărul de repetări", "Normal"],
                    ["Un pas `find` nu a găsit nimic", "Așa se oprește singură »redă până la sfârșitul fișierului«"],
                    ["S-a ajuns la sfârșitul documentului", "Nu mai e unde merge"],
                    ["Ați anulat", "`Macro ▸ Anulează macrocomanda în curs`"],
                    ["O rundă n-a schimbat nimic și nu s-a mutat nicăieri", "Oprită ca să nu se învârtă la infinit"],
                ]
            ),
            .note("Toată rularea — chiar și zece mii de repetări — este **un singur** pas de anulare."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Rularea unei macrocomenzi în lot",
        summary: "Pe fiecare filă deschisă, sau pe un dosar cu fișiere nedeschise.",
        keywords: ["lot", "toate filele", "dosar", "macrocomandă", "mască"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Comandă", "Domeniu", "Se anulează"],
                rows: [
                    ["Rulează pe toate filele", "Filele deschise", "Da — un pas de anulare pe filă"],
                    ["Rulează pe un dosar întreg…", "Fișiere de pe disc care **nu sunt deschise**", "Nu"],
                ]
            ),
            .warning("""
                Rularea pe un dosar atinge fișiere care nu sunt deschise în nicio filă, așa că **nu \
                există anulare**. Implicit, GEditor **scrie fișiere noi** în loc să suprascrie \
                originalele. Păstrați această setare dacă nu aveți o copie de rezervă sau un depozit cu \
                control de versiuni.
                """),
            .heading("Filtrarea fișierelor cu o mască"),
            .paragraph("""
                Selectorul de dosar are un **filtru de nume de fișier**: scrieți `*.csv;*.log` și \
                macrocomanda atinge doar acele fișiere. E aceeași sintaxă de mască folosită de `Caută \
                într-un dosar întreg`, cu mai multe tipare despărțite prin `;` sau `,`.
                """),
            .bullets([
                "Lăsați-o **goală** și ia orice fișier text pe care GEditor îl poate citi — comportamentul de dinainte.",
                "Masca **înlocuiește** acea listă de extensii, nu o îngustează mai departe: scrieți `*.bak` și rulează pe fișiere `.bak`, chiar dacă acea extensie nu e pe lista de text.",
                "Dacă nu se potrivește nimic, mesajul **vă repetă masca** în loc să dea vina pe un dosar gol.",
            ]),
            .paragraph("""
                Acest câmp are un motiv foarte practic: un dosar ține 400 de fișiere `.json` și 12 fișiere \
                `.log`, iar macrocomanda dumneavoastră curăță doar jurnale. Fără mască, se procesează și \
                celelalte 400 — și, cum lotul scrie fișiere noi, o greșeală lasă în urmă 400 de bucăți de \
                gunoi.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Sintaxa fișierului de macrocomandă",
        summary: "Șapte feluri de pași, formatul JSON complet și două macrocomenzi care merg.",
        keywords: ["macrocomandă", "json", "sintaxă", "format", "editare manuală"],
        blocks: [
            .paragraph("""
                Fiecare macrocomandă este **fișierul ei JSON** din dosarul `macros/` al GEditor. O \
                stricăciune rămâne într-o singură macrocomandă, iar a împărtăși una unui coleg înseamnă a \
                trimite un fișier.
                """),
            .code(language: "text", caption: "Unde stau fișierele",
                  source: "~/Library/Application Support/GEditor/macros/<nume-macro>.json"),
            .heading("Cele șapte feluri de pași"),
            .table(
                headers: ["Pas", "Se scrie ca", "Sens"],
                rows: [
                    ["Inserează text", "`{\"insert\": {\"_0\": \"text\"}}`", "Scrie la cursor; cu o selecție, o înlocuiește"],
                    ["Șterge înapoi", "`{\"deleteBackward\": {}}`", "Ca tasta de ștergere"],
                    ["Șterge înainte", "`{\"deleteForward\": {}}`", "Ca ⌦"],
                    ["Mută", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Vedeți lista de direcții de mai jos"],
                    ["Selectează linia", "`{\"selectLine\": {}}`", "Fără sfârșitul de linie"],
                    ["Caută", "`{\"find\": { … }}`", "Găsește și **selectează** potrivirea următoare"],
                    ["Înlocuiește selecția", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` se aplică dacă pasul precedent a fost un `find` cu regex"],
                ]
            ),
            .heading("Direcții de mutare"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Pasul `find` complet"),
            .code(language: "json", caption: "Cele patru chei ale unui pas find",
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
            .paragraph("`mode` acceptă `normal`, `extended` sau `regex` — aceleași trei moduri ca în câmpul de căutare."),
            .heading("Exemplul 1 — codul de provincie de la începutul liniei cu majuscule"),
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
                Rulați-o cu `Macro ▸ Redă până la sfârșitul documentului`: faptul că pasul `find` nu mai \
                găsește nimic este exact condiția de oprire.
                """),
            .heading("Exemplul 2 — șterge linia de după fiecare linie care conține TODO"),
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
                Încercați o macrocomandă editată manual mai întâi pe o copie. Un pas `find` scris greșit \
                oprește macrocomanda imediat — acesta e cazul benign. Cel malign e un tipar care prinde \
                mai larg decât credeați și modifică mii de locuri într-un singur pas de anulare.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "Scripturi JavaScript",
        summary: "Patru funcții, un fișier `.js`, și tot ce face este un singur pas de anulare.",
        keywords: ["script", "javascript", "js", "automatizare", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Puneți un fișier `.js` în dosarul `scripts/` al GEditor și rulați-l din `Macro ▸ \
                Script…`. Un script vede exact **patru** lucruri:
                """),
            .table(
                headers: ["Apel", "Sens"],
                rows: [
                    ["`doc.text`", "Textul întregului document"],
                    ["`doc.selection`", "Selecția (șir gol când nu e nimic selectat)"],
                    ["`doc.replace(s)`", "Înlocuiește **tot documentul** cu `s` — un singur pas de anulare"],
                    ["`doc.log(s)`", "Scrie o linie în panoul de rezultate"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Numerotează fiecare linie.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — păstrează primele trei coloane CSV",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Trei limite de știut"),
            .bullets([
                "**Fără acces la fișiere, fără rețea, fără pornire de procese.** Suprafața API e intenționat îngustă: a o lărgi mai târziu e ușor, a o îngusta strică fiecare script scris de utilizatori.",
                "**Aceasta nu e o graniță de securitate.** Scripturile rulează în același proces. Nu rulați un script pe care nu l-ați citit.",
                "**Există o limită de cinci secunde.** Peste ea primiți un mesaj, iar aplicația rămâne utilizabilă — dar firul acelui script **continuă să se învârtă până ieșiți**, mâncând un nucleu. Mesajul o spune.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filtrarea printr-o comandă externă",
        summary: "Trimiteți selecția printr-o comandă Unix și luați rezultatul înapoi.",
        keywords: ["filtru", "comandă externă", "shell", "conductă", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Selecția (sau tot documentul) se dă la `stdin`-ul unei comenzi, iar `stdout`-ul acelei \
                comenzi o înlocuiește.
                """),
            .code(language: "bash", caption: "Câteva obișnuite",
                  source: """
                    sort -u                     # sortează și elimină duplicatele
                    jq .                        # reformatează JSON
                    tr 'a-z' 'A-Z'              # cu majuscule
                    grep -v '^#'                # elimină liniile de comentariu
                    awk -F, '{print $3","$1}'   # schimbă ordinea coloanelor
                    """),
            .note("""
                Rezultatul este **un singur** pas de anulare. Dacă comanda întoarce un cod de eroare, \
                GEditor lasă textul în pace și arată `stderr`.
                """),
            .warning("""
                Această comandă există **doar în ediția cu descărcare directă**. App Sandbox interzice \
                rularea de cod în afara aplicației, așa că în ediția App Store elementul de meniu rămâne \
                și explică de ce nu e disponibil.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Unealta de linie de comandă `geditor`",
        summary: "Deschideți, curățați, interogați, evaluați și randați rapoarte — fără a deschide aplicația.",
        keywords: ["cli", "linie de comandă", "terminal", "geditor", "script", "ci"],
        blocks: [
            .warning("""
                Disponibilă doar în ediția cu **descărcare directă**. Ediția App Store rulează într-o \
                cutie de nisip, așa că un proces extern de linie de comandă nu se poate conecta la ea.
                """),
            .heading("Deschiderea fișierelor"),
            .code(language: "bash", caption: "Deschide, sari la o poziție, citește dintr-o conductă",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # linia 120, coloana 5
                    geditor -w notes.md            # așteaptă închiderea fișierului înainte de a ieși
                    geditor -r app.log             # deschide doar pentru citire
                    git diff | geditor             # citește intrarea standard într-o filă nouă
                    """),
            .table(
                headers: ["Opțiune", "Sens"],
                rows: [
                    ["`-w`, `--wait`", "Așteaptă închiderea fișierului înainte de a ieși — ca să servească drept editor pentru `git`"],
                    ["`-n`, `--new-window`", "Deschide într-o fereastră nouă"],
                    ["`-r`, `--read-only`", "Deschide doar pentru citire"],
                    ["`-i`, `--info`", "Tipărește codificarea, sfârșiturile de linie și numărul de linii, apoi iese — **fără** a deschide aplicația"],
                    ["`-h`, `--help`", "Arată ajutorul"],
                    ["`-v`, `--version`", "Arată versiunea"],
                ]
            ),
            .heading("Rularea fără deschiderea aplicației"),
            .paragraph("""
                Cele patru grupuri de comenzi de mai jos rulează **în întregime în procesul de linie de \
                comandă**, așa că funcționează în CI, unde nimeni nu e conectat la o sesiune grafică.
                """),
            .code(language: "bash", caption: "Curățare cu o rețetă",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Interogare",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Poarta de calitate — cod 0 trecut · 1 picat · 2 eroare",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Randarea rapoartelor",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript și meniul Servicii",
        summary: "Citiți și scrieți documentul din AppleScript, sau trimiteți text în GEditor din altă aplicație.",
        keywords: ["applescript", "osascript", "servicii", "automatizare", "scurtături"],
        blocks: [
            .code(language: "applescript", caption: "Citirea documentului deschis",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Suprascrierea conținutului și citirea selecției",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Deschiderea unui fișier",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Meniul Servicii"),
            .paragraph("""
                Selectați text în orice aplicație, apoi folosiți meniul `Servicii` ca să-l trimiteți în \
                GEditor ca filă nouă.
                """),
            .note("""
                Prima dată când rulați AppleScript, macOS cere permisiune de automatizare. Acela e \
                dialogul sistemului, nu al GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Pachete de extensii și extensii",
        summary: "Două feluri de extensii și în ce ediție rulează fiecare.",
        keywords: ["extensie", "pachet", "nativ"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Pachete de extensii"),
            .paragraph("""
                Un pachet este **un singur fișier JSON** care leagă o temă, scripturi și limbaje proprii. \
                Instalarea copiază un fișier, dezinstalarea șterge unul — iar lista de pachete se deduce \
                din **disc**, nu dintr-un registru care ar putea minți.
                """),
            .paragraph("Funcționează în **ambele ediții**."),
            .heading("Extensii native"),
            .paragraph("""
                Extensiile precompilate rulează într-un **proces separat**, cu o suprafață API îngustă — \
                o extensie care se blochează nu duce aplicația cu ea.
                """),
            .warning("""
                Extensiile native există **doar în ediția cu descărcare directă**, pentru că App Sandbox \
                interzice încărcarea de cod din afara aplicației. Fiecare extensie trebuie **aprobată \
                manual o dată**, după suma ei de control, înainte de a rula.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Setări și aplicație

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Setări și aplicație",
        summary: "Setări, scurtături, teme, actualizări, trecerea de la Notepad++, depanare.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Setări",
        summary: "Fiecare opțiune trăiește într-un fișier JSON lizibil pe care îl puteți copia pe alt Mac.",
        keywords: ["setări", "opțiuni", "configurare", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Deschide setările")]),
            .paragraph("""
                Nu există OK și nici Anulare — o schimbare intră în vigoare și se scrie imediat, în felul \
                macOS.
                """),
            .heading("Fișierul de configurare"),
            .code(language: "text", caption: "Unde stă",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Este un **fișier JSON indentat pe care îl puteți citi și edita manual**. Copiați-l pe alt \
                Mac și toată configurația merge cu el. Butonul `Deschide fișierul de configurare` din \
                setări vă duce direct acolo.
                """),
            .heading("Cheile"),
            .table(
                headers: ["Cheie", "Implicit", "Sens"],
                rows: [
                    ["`fontSize`", "`13`", "Mărimea fontului editorului"],
                    ["`tabWidth`", "`4`", "Câte coloane are un TAB"],
                    ["`usesTabsForIndent`", "`false`", "Indentare cu TAB în loc de spații"],
                    ["`languageIndent`", "`{}`", "Indentare pe limbaj — vedeți pagina despre spații"],
                    ["`smartIndent`", "`true`", "Indentare automată pe o linie nouă"],
                    ["`highlightAllMatches`", "`true`", "Evidențiază fiecare potrivire de căutare"],
                    ["`ligatures`", "`false`", "Ligaturi — vedeți nota de sub tabel"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Taie spațiile de la capăt de linie la salvare"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalizează Unicode la NFC la salvare"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Codificarea pentru fișiere noi"],
                    ["`defaultEOL`", "`\"lf\"`", "Sfârșiturile de linie pentru fișiere noi"],
                    ["`language`", "`\"system\"`", "Limba interfeței"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "tema implicită", "Ce temă de culori se folosește"],
                    ["`showWelcomeOnLaunch`", "`true`", "Deschide fereastra de bun venit la pornire"],
                    ["`keyBindings`", "`{}`", "Doar tastele pe care le-ați schimbat"],
                ]
            ),
            .note("""
                **De ce ligaturile sunt DEZACTIVATE implicit.** O ligatură topește `!=` sau `->` într-un \
                **singur** semn, așa că literele pe care le vedeți pe ecran nu mai corespund celor din \
                fișier — iar editorul de coloane, modul coloană și încadrarea la o coloană măsoară toate \
                în coloane. Activați-le când scrieți text curent sau dacă ați ales un font de programare \
                (Fira Code, JetBrains Mono) tocmai pentru ligaturile lui.
                """),
            .heading("Dosarele vecine"),
            .table(
                headers: ["Dosar", "Conține"],
                rows: [
                    ["`macros/`", "Macrocomenzi salvate, câte un fișier JSON fiecare"],
                    ["`scripts/`", "Scripturi JavaScript"],
                    ["`themes/`", "Teme de culori"],
                    ["`grammars/`", "Limbaje proprii"],
                ]
            ),
            .warning("""
                Un fișier de configurare scris de un GEditor **mai nou** **nu este suprascris** de unul \
                mai vechi — cel vechi rulează pe valori implicite și o spune. Suprascrierea e cel mai \
                sigur mod de a distruge configurația cuiva care ține două mașini sincronizate, iar el \
                n-ar afla niciodată de ce.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Bara de stare",
        summary: "Zece segmente jos — toate lizibile și toate clicabile.",
        keywords: ["bară de stare", "poziție", "codificare", "doar citire", "mărime"],
        blocks: [
            .paragraph("""
                Aceasta e cea mai mare diferență față de barele de stare ale altor editoare: **niciun \
                segment nu e doar pentru citire**. Vedeți o valoare greșită, iar un clic pe ea e felul de \
                a o repara, în loc să vânați prin meniuri.
                """),
            .table(
                headers: ["Segment", "Vă spune", "La clic"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "poziția cursorului — coloana în CARACTERE, `@340` poziția în octeți",
                     "deschide câmpul `Mergi la`"],
                    ["`11 byte · 3 dòng`", "mărimea documentului",
                     "numără octeți · caractere · cuvinte · linii"],
                    ["`🔒 Chỉ đọc`", "apare doar când documentul e blocat",
                     "spune DE CE e blocat și îl deblochează când se poate"],
                    ["`View` / `Code`", "în ce vedere sunteți", "comută (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "modul CSV și separatorul folosit",
                     "comută modul CSV, sau **realege separatorul**"],
                    ["`Đang theo dõi`", "rulează `tail -f`", "—"],
                    ["`UTF-8`", "codificarea", "reinterpretează, sau convertește în altă codificare"],
                    ["`LF`", "stilul sfârșitului de linie", "comută LF · CRLF · CR"],
                    ["`Python`", "limbajul colorării sintaxei", "alegeți altul, sau înapoi la detectarea după extensie"],
                    ["`Tab: 4`", "lățimea indentării", "2 · 4 · 8, general sau **doar pentru acest limbaj**"],
                    ["`Ngắt: tắt`", "modul de încadrare", "parcurge cele trei moduri"],
                ]
            ),
            .heading("Trei segmente care merită o a doua privire"),
            .bullets([
                "**`@340` — poziția în octeți.** Este numărul pe care îl vorbește orice altă unealtă din produs: erorile JSON și XML, ieșirea lui `--doc-sweep`, vizualizatorul binar și câmpul `Mergi la @340`. Citiți-l aici, scrieți-l acolo.",
                "**Un `~` lângă coloană** înseamnă că numărul numără OCTEȚI, nu coloane vizibile — se întâmplă doar pe linii mai lungi de 200 kO, unde numărarea caracterelor ar încetini fiecare mișcare de cursor.",
                "**Pe `CSV · …` se poate face clic ca să realegeți separatorul.** Detectarea poate greși, și atunci fiecare operație pe coloane e deplasată fără ca ceva să semnaleze. Așa spuneți altfel — doar **RECITEȘTE** fișierul, fără a schimba un octet (spre deosebire de `CSV ▸ Schimbă separatorul…`, care îl rescrie).",
            ]),
            .note("""
                Un segment care nu se aplică fișierului deschis este **ascuns**, nu estompat: `Doar \
                citire` apare doar când documentul chiar e blocat, iar `CSV · …` doar în modul CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Schimbarea scurtăturilor de tastatură",
        summary: "Schimbați taste individuale sau adoptați harta Notepad++ în întregime.",
        keywords: ["scurtătură", "hartă de taste", "presetare"],
        blocks: [
            .paragraph("""
                `Setări…` are o secțiune Scurtături cu două butoane rapide: **Folosește presetarea \
                Notepad++** și **Înapoi la valorile implicite**.
                """),
            .paragraph("""
                Fișierul de configurare notează doar ce ați **schimbat față de valorile implicite**. \
                Astfel, când GEditor schimbă o tastă implicită într-o versiune nouă, nu rămâneți cu harta \
                veche fără ca cineva să vă spună.
                """),
            .note("""
                Două comenzi nu pot împărți o scurtătură. Când o fac, AppKit declanșează în tăcere doar \
                **primul** element de meniu, iar cealaltă comandă pare stricată — de aceea GEditor are o \
                verificare care previne asta.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Teme, luminoasă și întunecată",
        summary: "Urmați sistemul, luminos sau întunecat; iar o temă e un fișier JSON pe care îl puteți edita.",
        keywords: ["temă", "culori", "mod întunecat", "luminos", "aspect"],
        blocks: [
            .paragraph("`Setări…` alege `Urmează sistemul`, `Luminos` sau `Întunecat` și indică o temă de culori."),
            .paragraph("""
                O temă este un fișier JSON din `themes/`. Butonul `Exportă tema curentă` scrie una ca \
                punct de pornire pentru a dumneavoastră.
                """),
            .note("""
                O culoare scrisă greșit într-un fișier de temă revine la culoarea **temei implicite**, nu \
                la negru. Negrul pare o decizie de proiectare, iar utilizatorul ar căuta problema în altă \
                parte.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Actualizări, versiuni și ieșire",
        summary: "Prin ce diferă actualizarea între cele două ediții.",
        keywords: ["actualizare", "versiune", "despre", "ieșire"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Ediție", "Se actualizează prin"],
                rows: [
                    ["App Store", "App Store, ca orice altă aplicație"],
                    ["Descărcare directă", "`Caută actualizări…` din aplicație"],
                ]
            ),
            .paragraph("""
                `Despre GEditor` arată versiunea care rulează și ce ediție este — util când raportați o \
                problemă.
                """),
            .note("""
                În ediția App Store, `Caută actualizări…` **rămâne în meniu** și explică de ce nu se \
                aplică, în loc să dispară. Un element de meniu lipsă e o întrebare pentru asistență.
                """),
            .paragraph("Ieșirea nu pierde muncă: sesiunea revine data viitoare când deschideți."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Folosirea acestei ferestre de ajutor",
        summary: "Căutați în carte, schimbați-i limba și readuceți fereastra de bun venit.",
        keywords: ["ajutor", "ghid", "căutare", "bun venit", "limbă"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Deschide fereastra de ajutor")]),
            .bullets([
                "Câmpul de căutare din stânga sus se uită în **textul principal și în exemplele de cod** — scrierea unei chei de configurare simple, precum `fail_under`, duce la pagina potrivită.",
                "Scrisul **fără diacritice** găsește totuși text cu diacritice.",
                "Butonul `Înapoi` revine la pagina precedentă.",
                "Butonul `Copiază` de la fiecare bloc de cod copiază acel bloc.",
            ]),
            .heading("Citirea în altă limbă"),
            .paragraph("""
                Meniul din dreapta sus a acestei ferestre alege **limba cărții**, independent de limba \
                interfeței aplicației. Schimbarea vă ține **pe pagina pe care o citiți** — identificatorii \
                paginilor nu se traduc intenționat, tocmai ca asta să funcționeze.
                """),
            .note("""
                Se enumeră doar limbile care au într-adevăr o carte. Un element de meniu care comută spre \
                ceva și lasă textul neschimbat ar fi un element de meniu care minte.
                """),
            .heading("Readucerea ferestrei de bun venit"),
            .paragraph("""
                Dacă ați bifat **Nu deschide această fereastră la pornire**, redeschideți-o cu `Ajutor ▸ \
                Tur al funcțiilor` — caseta de la baza ferestrei reapare și poate fi debifată.
                """),
            .paragraph("Sau puneți `showWelcomeOnLaunch` înapoi pe `true` în `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "De la Notepad++ la GEditor",
        summary: "Ce taste își schimbă locurile, ce funcționează altfel și ce lipsește.",
        keywords: ["notepad++", "trecere", "windows", "scurtături"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Câteva taste **își schimbă locurile** pe macOS în loc ca `Ctrl` să devină pur și simplu \
                `⌘`. Iată comparația.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "De ce"],
                rows: [
                    ["`Ctrl+D` Dublează linia", "**⇧⌘D**", "Aici `⌘D` e multicursor, ca în orice editor de Mac"],
                    ["`Ctrl+L` Șterge linia", "**⌘K**", "Pe macOS, `⌘L` înseamnă »mergi la linie«"],
                    ["`Ctrl+G` Mergi la linie", "**⌘L**", "Acestea două își schimbă locurile"],
                    ["`Ctrl+Q` Comentează", "**⌘/**", "Convenție macOS"],
                    ["`Ctrl+Shift+↑/↓` Mută linia", "**⌥↑ / ⌥↓**", "Pe macOS, `⌃` aparține Mission Control"],
                    ["`F3` Găsește următorul", "**⌘G**", "Convenție macOS"],
                    ["`Ctrl+F2` Comută semnul de carte", "**⌘F2**", "F2 și ⇧F2 sar în continuare între marcaje"],
                    ["`Alt` + tragere pentru coloane", "**⌥ + tragere**", "Identic"],
                    ["`Ctrl+Alt+Shift+↓` Editor de coloane", "**⌥⌘C**", "Convenție macOS"],
                ]
            ),
            .note("Preferați să nu reînvățați? `Setări ▸ Scurtături ▸ Folosește presetarea Notepad++`."),
            .heading("Lucruri pe care Notepad++ le are și aici merg altfel"),
            .bullets([
                "**Sesiunile** se restaurează singure, inclusiv filele nesalvate — nu e nimic de activat.",
                "**Semnele de carte au nouă culori**, iar o linie poate purta mai multe deodată.",
                "**Harta documentului** descrie *tot* fișierul, nu doar partea vizibilă.",
                "**Macrocomenzile** pot rula »până la sfârșitul documentului« și »pe toate filele«, iar o rulare întreagă e un singur pas de anulare.",
            ]),
            .heading("Ce adaugă GEditor"),
            .bullets([
                "Un **banc de curățare a datelor** și **profiluri de date** pentru fișiere CSV.",
                "**Interogări SQL** direct pe un fișier CSV.",
                "**Codificări vietnameze vechi** — TCVN3, VISCII, VNI-Windows, citite, scrise și detectate automat.",
                "**Căutare fără diacritice** în fiecare câmp de filtrare.",
                "**Rapoarte `.greport.md`** cu tabele și grafice care se recalculează.",
                "**Unealta de linie de comandă `geditor`** în ediția cu descărcare directă.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Probleme frecvente",
        summary: "Șase situații care îi fac pe oameni să creadă că aplicația e stricată.",
        keywords: ["eroare", "problemă", "nu merge", "depanare", "de ce"],
        blocks: [
            .table(
                headers: ["Simptom", "Cauză obișnuită"],
                rows: [
                    ["Textul vietnamez apare aiurea", "Codificare greșită — faceți clic pe codificare în bara de stare"],
                    ["Căutarea textului cu diacritice nu găsește nimic", "Fișierul e în Unicode descompus — rulați `Normalizează Unicode` la NFC"],
                    ["Un element de meniu e estompat", "Ediția App Store nu poate rula acea comandă — elementul explică de ce"],
                    ["Potrivirea parantezelor refuză să ruleze", "Documentul depășește 1 MB — a evidenția perechea greșită e mai rău decât niciuna"],
                    ["Coloana din bara de stare are un `~`", "Documentul depășește 200 kO, deci e un număr de octeți, nu o coloană vizibilă"],
                    ["O interogare SQL spune că fișierul trebuie salvat întâi", "DuckDB citește **fișiere**, nu memoria tampon pe care o editați"],
                ]
            ),
            .heading("Când GEditor iese pe neașteptate"),
            .paragraph("""
                La pornirea următoare, un banner o spune, cu un buton **Deschide raportul** — raportul se \
                deschide ca filă pe care o citiți și din care copiați ca din orice alt fișier text.
                """),
            .bullets([
                "Raportul poartă doar **versiunea, ediția macOS, arhitectura mașinii, numele semnalului și stiva de apeluri**.",
                "**Niciun conținut de document și nici căi de fișiere** — o cale precum `~/Birou/salarii-decembrie.xlsx` a dezvăluit deja trei lucruri private înainte s-o deschidă cineva.",
                "**Nu se trimite nimic nicăieri.** Nu există încărcare automată și niciun server care să primească; fișierul rămâne în `~/Library/Application Support/GEditor/crash/` până îl deschideți sau îl ștergeți.",
                "După ce ați deschis raportul, pornirea următoare nu-l mai menționează.",
            ]),
            .heading("Unde să căutați mai departe"),
            .bullets([
                "Bara de stare arată codificarea, sfârșiturile de linie, limbajul și modul de încadrare — pe fiecare segment se poate face clic.",
                "`settings.json` poate fi editat manual când fereastra de setări nu e de ajuns.",
                "`Despre GEditor` dă versiunea și ediția, de care are nevoie un raport de eroare.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
