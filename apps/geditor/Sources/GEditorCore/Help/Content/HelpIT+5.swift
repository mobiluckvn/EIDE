import Foundation

/// Contenuto della guida in italiano — parte 5: rapporti, conoscenza, automazione e applicazione.
extension HelpIT {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Rapporti e diagrammi",
        summary: "Un file di testo che produce un rapporto HTML i cui numeri si ricalcolano, più i diagrammi Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "Rapporti `.greport.md`",
        summary: "Markdown più quattro tipi di blocco eseguibili — scrivere a sinistra, vedere l'anteprima a destra.",
        keywords: ["rapporto", "greport", "html", "esportare", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Un file `.greport.md` è **Markdown comune** più qualche blocco delimitato eseguibile. Renderlo \
                produce un file HTML **autosufficiente** — niente rete, niente file di contorno — che chiunque \
                può aprire.
                """),
            .paragraph("""
                Essendo testo semplice, può essere **confrontato, versionato e condiviso** — la stessa \
                filosofia delle ricette di pulizia e degli insiemi di regole di qualità.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — un rapporto completo",
                  source: """
                    ---
                    title: Rapporto vendite di agosto
                    source: sales-2026-08.csv
                    ---

                    # Rapporto vendite di agosto

                    Numeri al 31 agosto 2026.

                    ## Ricavi per provincia

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Ricavi per provincia
                    y_label: Ricavi
                    number_format: vi
                    suffix: " ₫"
                    source: Fonte — sales-2026-08.csv
                    ```

                    ## Qualità dei dati di origine

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("I tipi di blocco"),
            .table(
                headers: ["Blocco", "Produce"],
                rows: [
                    ["`query`", "Una tabella, da un'istruzione SQL di DuckDB"],
                    ["`chart`", "Un grafico"],
                    ["`quality`", "Una scheda di valutazione della qualità dei dati"],
                    ["`mining`", "Una tabella di classifica dell'estrazione per gruppo"],
                    ["`mermaid`", "Un diagramma"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                Il blocco `---` in cima dichiara `title` e `source` — la fonte dati predefinita per ogni blocco \
                che non indichi la propria.
                """),
            .note("""
                L'anteprima si ricostruisce quando smettete di scrivere, ma **si limita ad analizzare**; non \
                esegue interrogazioni a ogni tasto. Gli errori di documento e quelli di dati sono segnalati \
                separatamente — *«al blocco chart manca la chiave `kind`»* è un errore di file, *«la colonna \
                `doanh_thu` non esiste»* è un errore di dati.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "Il blocco `query`",
        summary: "Un'istruzione di DuckDB diventa una tabella nel rapporto.",
        keywords: ["interrogazione", "sql", "tabella", "rapporto", "blocco"],
        blocks: [
            .paragraph("""
                Il contenuto del blocco è **un'istruzione SQL**, eseguita sulla fonte del rapporto. La tabella \
                si chiama `t`, nello stesso dialetto del pannello delle interrogazioni.
                """),
            .code(language: "text", caption: "Un blocco query con parametri",
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
                `:thang` è un **parametro**. Viene fornito al momento del rendering — dalla shell con `--param \
                thang=8`, o da un file di elenco quando si generano rapporti in lotto.
                """),
            .note("""
                Le tabelle di un rapporto di dati **dovrebbero venire da un blocco query**, non essere scritte \
                a mano. Una tabella scritta a mano non si ricalcola quando i numeri cambiano e, prima o poi, \
                contraddice il resto del rapporto.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "Il blocco `chart`",
        summary: "Una configurazione YAML diventa un grafico — e la regola più importante del formato.",
        keywords: ["grafico", "yaml", "rapporto", "disegnare"],
        blocks: [
            .code(language: "yaml", caption: "Ogni chiave di un blocco chart",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Ricavi per provincia
                    x_label: Provincia
                    y_label: Ricavi
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Fonte — sales.csv, al 26 agosto 2026
                    """),
            .heading("Senza `query`, usa il risultato del blocco query IMMEDIATAMENTE SOPRA"),
            .paragraph("""
                È la regola più importante del formato. Grazie a essa il rapporto abituale «una tabella e poi \
                un grafico di quella tabella» non ripete l'SQL — e ripeterlo significa che le due copie prima \
                o poi divergono, e a quel punto la tabella e il grafico dicono cose diverse sulla stessa \
                pagina.
                """),
            .warning("""
                In cambio **l'ordine dei blocchi conta**: inserire un blocco query in mezzo cambia i dati del \
                grafico sottostante.
                """),
            .heading("Perché `source` è una chiave a sé"),
            .paragraph("""
                Una nota di fonte scritta in prosa sotto il grafico si vede benissimo — a schermo. Ma il \
                grafico verrà esportato come PNG e incollato altrove, e la prosa resta indietro. Come chiave \
                viene disegnata **dentro l'immagine** e viaggia con essa.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "Il blocco `quality`",
        summary: "Una scheda di valutazione della qualità dei dati dentro il rapporto.",
        keywords: ["qualità", "scheda", "rapporto", "blocco"],
        blocks: [
            .code(language: "yaml", caption: "Ogni chiave di un blocco quality",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # vuoto significa la fonte propria del rapporto
                    title: Qualità dei dati di vendita di agosto
                    rules: true                 # mostrare la tabella regola per regola
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # fissare la data di riferimento della «Tempestività»
                    fail_under: 90              # sotto, la scheda passa al colore d'avviso
                    """),
            .table(
                headers: ["`chart`", "Disegna"],
                rows: [
                    ["`violations`", "Il numero di righe delle regole **non superate** — risponde a «che cosa correggere per primo»"],
                    ["`dimensions`", "I voti delle sei dimensioni"],
                    ["`none`", "Solo tabella, nessun grafico"],
                ]
            ),
            .note("""
                Mettete `now:` in un rapporto periodico. Senza, la *Tempestività* si confronta con il momento \
                del rendering, quindi rifare il rendering del rapporto del mese scorso dà un voto diverso da \
                quello che avete pubblicato.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "Il blocco `mining`",
        summary: "Classificare i gruppi per anomalie, errore di previsione o divergenza di correlazione.",
        keywords: ["estrazione", "rapporto", "classifica dei gruppi"],
        blocks: [
            .code(language: "yaml", caption: "Ogni chiave di un blocco mining",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # la colonna per anomalie e previsione
                    pair: chi_phi             # una seconda colonna, per la correlazione per gruppo
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # vuoto significa la fonte propria del rapporto
                    title: Estrazione per provincia
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Classifica per"],
                rows: [
                    ["`anomalies`", "Il gruppo con più righe anomale"],
                    ["`forecast_error`", "Il gruppo la cui previsione è la peggiore"],
                    ["`correlation_gap`", "Il gruppo la cui correlazione diverge di più dalla tabella aggregata — prende il paradosso di Simpson"],
                ]
            ),
            .warning("""
                **Nessuna chiave spegne il blocco «Metodo».** Una classifica di gruppi senza il suo metodo non \
                lascia al lettore alcun modo di sapere rispetto a quale barriera sia stato misurato «più \
                anomalie». Chi vuole nasconderlo conosce già la risposta che desidera.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Generare rapporti in lotto",
        summary: "Un modello, un elenco di parametri, molti rapporti.",
        keywords: ["lotto", "in massa", "parametri", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Un modello di rapporto, eseguito per ogni filiale o ogni mese. L'elenco dei parametri è un file \
                CSV o JSON — **una riga per rapporto**.
                """),
            .code(language: "text", caption: "list.csv — una riga per rapporto",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Rendere l'intero lotto dalla shell",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Oppure un rapporto con parametri passati a mano",
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
        title: "Diagrammi Mermaid",
        summary: "Disegnare diagrammi in testo, modificarli con comandi, vedere l'anteprima sincronizzata nei due versi.",
        keywords: ["mermaid", "diagramma", "diagramma di flusso", "sequenza", "disegnare"],
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
                Mermaid disegna diagrammi **a partire dal testo**: voi scrivete una descrizione e la macchina \
                la disegna. Perciò un diagramma può essere confrontato e versionato — cosa che un file \
                immagine non può.
                """),
            .paragraph("""
                Aprite `Diagramma Mermaid: anteprima` per avere una vista accanto all'editor. I due sono \
                **sincronizzati nei due versi**: selezionate un elemento nell'immagine e il cursore salta alla \
                sua riga.
                """),
            .heading("Modificare con comandi, non riscrivendo"),
            .table(
                headers: ["Comando", "Che cosa fa"],
                rows: [
                    ["Inserisci un modello…", "Inserire uno scheletro pronto per ogni tipo di diagramma"],
                    ["Aggiungi un elemento…", "Aggiungere un nodo o un partecipante"],
                    ["Collega i due elementi selezionati", "Disegnare una freccia fra loro"],
                    ["Modifica l'etichetta dell'elemento selezionato…", "Cambiare il testo senza cercare la riga"],
                    ["Elimina l'elemento selezionato", "Togliere il nodo **e** ogni arco che lo tocca"],
                    ["Sposta il messaggio su / giù", "Riordinare i passi in un diagramma di sequenza"],
                    ["Riformatta", "Rientrare e allineare l'intero blocco"],
                ]
            ),
            .heading("Estrarre in un file e reincorporarlo"),
            .paragraph("""
                I diagrammi grandi meritano un file `.mmd` proprio: `Estrai il blocco in un file .mmd…` lo \
                sposta e lascia un riferimento. `Reincorpora il file di riferimento` fa l'inverso quando dovete \
                spedire un solo file.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Sintassi Mermaid comune",
        summary: "I quattro tipi di diagramma più usati, ciascuno con un modello che funziona.",
        keywords: ["mermaid", "sintassi", "flusso", "sequenza", "gantt", "classi", "modello"],
        blocks: [
            .code(language: "mermaid", caption: "Diagramma di flusso — un processo di approvazione ordini",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Diagramma di sequenza — un flusso di pagamento",
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
            .code(language: "mermaid", caption: "Diagramma delle classi — un modello di dati",
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
            .code(language: "mermaid", caption: "Gantt — un piano di pubblicazione",
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
                headers: ["Forma del nodo", "Scrivete"],
                rows: [
                    ["Rettangolo", "`A[Label]`"],
                    ["Arrotondato", "`A(Label)`"],
                    ["Stadio", "`A([Label])`"],
                    ["Rombo (decisione)", "`A{Label}`"],
                    ["Cilindro (dati)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Freccia", "Scrivete"],
                rows: [
                    ["Piena, con punta", "`A --> B`"],
                    ["Punteggiata", "`A -.-> B`"],
                    ["Spessa", "`A ==> B`"],
                    ["Con etichetta", "`A -- label --> B`"],
                ]
            ),
            .note("""
                La direzione di un diagramma di flusso segue subito `flowchart`: `TD` dall'alto in basso, `LR` \
                da sinistra a destra, più `BT` e `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Pacchetto di conoscenza

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Il pacchetto di conoscenza",
        summary: "Spezzettare, indici di ricerca, grafi di conoscenza, entità e valutazione del recupero.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Che cos'è il pacchetto di conoscenza",
        summary: "Strumenti per preparare e verificare dati destinati a un sistema di domande e risposte sui documenti.",
        keywords: ["rag", "conoscenza", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Quando si costruisce un sistema che risponde a domande a partire da un corpus di documenti, la \
                maggior parte del lavoro non sta nel modello ma nel **preparare i dati**: tagliare i documenti \
                in passaggi sensati, verificare la qualità di quei passaggi, costruire un indice e **misurare \
                se il recupero trova davvero la cosa giusta**.
                """),
            .paragraph("""
                Questo capitolo è esattamente lo strumentario per questo. Gira **interamente sulla vostra \
                macchina** e non chiama mai la rete.
                """),
            .table(
                headers: ["Compito", "Strumento"],
                rows: [
                    ["Tagliare documenti in passaggi", "Anteprima di spezzettamento"],
                    ["Ispezionare e valutare i passaggi", "Ispezione dei pezzi JSONL"],
                    ["Convertire fra forme di dati", "Conversione della conoscenza"],
                    ["Costruire e ispezionare un grafo di relazioni", "Grafo di conoscenza"],
                    ["Trovare nomi propri in un testo", "Marcatura delle entità"],
                    ["Misurare la qualità del recupero", "Laboratorio di recupero"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Spezzettare e ispezionare un corpus JSONL",
        summary: "Vedere in anteprima i confini di spezzettamento sul testo stesso, poi valutare l'intero corpus.",
        keywords: ["chunk", "jsonl", "corpus", "sovrapposizione", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Anteprima di spezzettamento"),
            .paragraph("""
                Aprite un documento di testo o Markdown, scegliete una strategia e una dimensione di pezzo. I \
                confini sono **evidenziati sul testo stesso**, così vedete dove un taglio cade a metà frase o \
                attraversa una tabella prima di esportare qualsiasi cosa.
                """),
            .bullets([
                "**Dimensione fissa** con sovrapposizione.",
                "**Per struttura** — sui titoli Markdown, mantenendo intatto il filo del documento.",
                "**Per paragrafo**, fondendo finché non si raggiunge la dimensione.",
            ]),
            .heading("Ispezionare un corpus JSONL esistente"),
            .paragraph("""
                Per un corpus che avete già (un pezzo JSON per riga), `JSONL: ispeziona i pezzi…` risponde: \
                quali righe non sono JSON valido, quali pezzi sono troppo corti o troppo lunghi, quali si \
                duplicano fra loro e quali sono stati tagliati a metà frase.
                """),
            .note("""
                Anche un corpus si può valutare con lo **stesso quadro a sei dimensioni** dei dati tabellari — \
                usate la chiave `corpus:` in un blocco `quality` di un rapporto.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Convertire formati di conoscenza",
        summary: "Pezzi fra JSONL · CSV · Markdown, grafi fra DOT · Mermaid · elenchi di archi.",
        keywords: ["convertire", "jsonl", "dot", "mermaid", "elenco di archi"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Da", "A"],
                rows: [
                    ["Pezzi JSONL", "CSV · Markdown"],
                    ["Pezzi CSV", "JSONL · Markdown"],
                    ["Grafo DOT", "Mermaid · elenco di archi"],
                    ["Elenco di archi", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                C'è un'**anteprima di cinque righe** prima che la scheda nuova venga creata, lo stesso \
                meccanismo della conversione CSV.
                """),
            .paragraph("""
                `Apri triple/archi come tabella` mostra un file di triple o un elenco di archi come tabella — \
                filtrate e ordinate come in qualsiasi altro CSV.
                """),
            .note("""
                Il verso **Markdown → JSONL** non è in questo comando: quel verso *è* lo spezzettamento, e il \
                comando vi rimanda là. Due implementazioni di uno stesso taglio produrrebbero due risultati \
                diversi.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Grafi di conoscenza",
        summary: "Controllare la sintassi, valutare la salute ed eseguire algoritmi su grafi da un milione di archi.",
        keywords: ["grafo", "dot", "cypher", "pagerank", "louvain", "controllo di sintassi"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor legge i grafi come **DOT**, come **elenchi di archi** e come **triple**. `Controlla la \
                sintassi del grafo` prende errori di sintassi, nodi penzolanti e archi che puntano a nodi \
                inesistenti.
                """),
            .heading("Algoritmi disponibili"),
            .table(
                headers: ["Algoritmo", "Risponde a"],
                rows: [
                    ["Vicinato a k salti", "Che cosa è legato a questo nodo in k passi"],
                    ["Componenti connesse", "In quanti pezzi scollegati si divide il grafo"],
                    ["PageRank", "Quali nodi sono importanti"],
                    ["Louvain", "Come il grafo si divide in comunità"],
                ]
            ),
            .paragraph("""
                Su un grafo da **un milione di archi**, tutti e quattro girano fra pochi millisecondi e circa \
                un secondo.
                """),
            .note("""
                Anche un grafo si può valutare con il **quadro a sei dimensioni** usato per tabelle e corpora — \
                usate la chiave `graph:` in un blocco `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Marcare le entità da un elenco",
        summary: "Caricare un elenco di nomi propri e trovare ogni occorrenza — con tre regole pensate per il vietnamita.",
        keywords: ["entità", "nome proprio", "ner", "marcatura", "corrispondenza"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Caricate un elenco di nomi (aziende, prodotti, luoghi) e GEditor evidenzia ogni occorrenza nel \
                documento, con una tabella di conteggi.
                """),
            .heading("Tre regole di corrispondenza, tutte nate da dati vietnamiti"),
            .bullets([
                "**Vince la corrispondenza più lunga.** Con `An Phát` e `Công ty An Phát` entrambi nell'elenco, una frase che contiene l'espressione lunga deve corrispondere a quella lunga — altrimenti viene spezzata in due e contata come due entità, il che **gonfia** le statistiche.",
                "**Sono richiesti i confini di parola.** `An` non deve corrispondere dentro `Anh` né `Hoàn`. I nomi propri vietnamiti sono corti e condividono sillabe con innumerevoli parole comuni.",
                "**Insensibile alle maiuscole, ma SENSIBILE agli accenti.** `CÔNG TY` e `Công ty` sono uno; `má` e `ma` no.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Risolvere le varianti di entità",
        summary: "Riconoscere `Cty An Phát` e `Công ty An Phát` come una sola — lasciandovi comunque la decisione.",
        keywords: ["risoluzione di entità", "varianti", "normalizzazione dei nomi", "doppioni"],
        blocks: [
            .paragraph("""
                Lo stesso raggruppamento dei **doppioni approssimati** di una tabella CSV — un'unica \
                implementazione condivisa, non due.
                """),
            .paragraph("""
                L'esito è una **proposta**: voi rivedete ogni grappolo e scegliete la forma canonica. Non c'è \
                un pulsante «fondi tutto», perché due nomi simili al 92 % possono essere due organizzazioni \
                reali.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Il laboratorio di recupero",
        summary: "Misurare se l'indice trova la cosa giusta, con un insieme di domande dotate di risposte.",
        keywords: ["recupero", "bm25", "recall", "mrr", "ndcg", "valutazione"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Caricate un **insieme di valutazione** — ogni riga una domanda con gli identificativi dei pezzi \
                che dovrebbero essere restituiti — e poi eseguite l'intero lotto contro l'indice.
                """),
            .table(
                headers: ["Metrica", "Risponde a"],
                rows: [
                    ["recall@k", "Quanto dell'insieme di risposte compare nei primi k"],
                    ["MRR", "A che profondità sta il primo risultato giusto"],
                    ["nDCG@k", "Se l'ordinamento è buono, tenendo conto della posizione"],
                ]
            ),
            .paragraph("""
                I risultati arrivano anche **per domanda**, i peggiori per primi — quello è il vostro elenco di \
                cose da correggere nel corpus, nell'ordine che conviene di più.
                """),
            .warning("""
                Tutte e tre le metriche sono **medie**, e una media nasconde moltissimo. Leggete sempre la \
                tabella per domanda prima di concludere che «l'indice è già abbastanza buono».
                """),
            .paragraph("""
                Due configurazioni si possono confrontare affiancate, e il risultato cade direttamente in un \
                rapporto `.greport.md` perché l'esecuzione successiva sia identica.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Macro e automazione

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Macro e automazione",
        summary: "Registrare azioni, eseguirle in lotto, scrivere script e guidare il tutto dalla shell.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Registrare e riprodurre macro",
        summary: "Registrare una sequenza e ripeterla — l'intera esecuzione è un passo di annullamento.",
        keywords: ["macro", "registrare", "riprodurre", "ripetere", "automatizzare"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Avviare / fermare la registrazione"),
                HelpShortcut("⌃P", "Riprodurre"),
            ]),
            .steps([
                "`⌃R` avvia la registrazione.",
                "Fate ciò che volete ripetere — scrivere, muovere il cursore, cercare, sostituire.",
                "`⌃R` di nuovo per fermare.",
                "`⌃P` la riproduce, oppure `Macro ▸ Riproduci fino alla fine del documento` la esegue fino in fondo.",
                "`Macro ▸ Salva macro…` le dà un nome per le sessioni successive.",
            ]),
            .heading("Registra COMANDI, non tasti grezzi"),
            .paragraph("""
                Una macro conserva **ciò che avete fatto**, non quali tasti avete premuto. Questo la rende \
                indipendente dalla disposizione della tastiera e dal metodo di immissione attivo, e rende il \
                file della macro **leggibile** quando lo aprite.
                """),
            .heading("Quando una macro si ferma"),
            .table(
                headers: ["Motivo", "Significato"],
                rows: [
                    ["Il conto delle ripetizioni si è esaurito", "Normale"],
                    ["Un passo `find` non ha trovato nulla", "È così che «riproduci fino alla fine del file» si ferma da sé"],
                    ["Si è arrivati alla fine del documento", "Non c'è più dove andare"],
                    ["Avete annullato", "`Macro ▸ Annulla la macro in corso`"],
                    ["Un'iterazione non ha cambiato né mosso nulla", "Fermata perché non giri all'infinito"],
                ]
            ),
            .note("L'intera esecuzione — anche diecimila ripetizioni — è **un** passo di annullamento."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Eseguire una macro in lotto",
        summary: "Su tutte le schede aperte, o su una cartella di file non aperti.",
        keywords: ["lotto", "tutte le schede", "cartella", "macro", "maschera"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Comando", "Ambito", "Annullabile"],
                rows: [
                    ["Esegui su tutte le schede", "Le schede aperte", "Sì — un passo di annullamento per scheda"],
                    ["Esegui su una cartella…", "File su disco **non aperti**", "No"],
                ]
            ),
            .warning("""
                Eseguire su una cartella tocca file che non sono aperti in nessuna scheda, quindi **non c'è \
                annullamento**. Di serie GEditor **scrive file nuovi** invece di sovrascrivere gli originali. \
                Tenete quel valore a meno che non abbiate un backup o un repository con versioni.
                """),
            .heading("Filtrare i file con una maschera"),
            .paragraph("""
                Il selettore di cartella ha un **filtro di nome file**: scrivete `*.csv;*.log` e la macro tocca \
                solo quelli. È la stessa sintassi di maschera che usa `Cerca in una cartella`, con più schemi \
                separati da `;` o `,`.
                """),
            .bullets([
                "Lasciatelo **vuoto** e prende ogni file di testo che GEditor sappia leggere — il comportamento di prima.",
                "La maschera **sostituisce** quell'elenco di estensioni invece di restringerlo ulteriormente: scrivete `*.bak` e gira sui file `.bak`, anche se quell'estensione non è nell'elenco di testo.",
                "Se nulla corrisponde, il messaggio **vi ripete la maschera** invece di incolpare una cartella vuota.",
            ]),
            .paragraph("""
                Questa casella ha una ragione molto pratica: una cartella contiene 400 file `.json` e 12 \
                `.log`, e la vostra macro sistema solo i registri. Senza maschera vengono elaborati anche gli \
                altri 400 — e siccome il lotto scrive file nuovi, un errore lascia 400 pezzi di spazzatura.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Sintassi del file di macro",
        summary: "Sette tipi di passo, il formato JSON completo e due macro che funzionano.",
        keywords: ["macro", "json", "sintassi", "formato", "modificare a mano", "condividere"],
        blocks: [
            .paragraph("""
                Ogni macro è **un file JSON a sé** nella cartella `macros/` di GEditor. Un danno resta confinato \
                a una macro, e condividerne una con un collega significa mandare un file.
                """),
            .code(language: "text", caption: "Dove vivono i file",
                  source: "~/Library/Application Support/GEditor/macros/<nome-macro>.json"),
            .heading("I sette tipi di passo"),
            .table(
                headers: ["Passo", "Si scrive", "Significato"],
                rows: [
                    ["Inserire testo", "`{\"insert\": {\"_0\": \"testo\"}}`", "Scrivere al cursore; con una selezione la sostituisce"],
                    ["Cancellare indietro", "`{\"deleteBackward\": {}}`", "Come il tasto Cancella"],
                    ["Cancellare avanti", "`{\"deleteForward\": {}}`", "Come ⌦"],
                    ["Spostare", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Vedete l'elenco delle direzioni qui sotto"],
                    ["Selezionare la riga", "`{\"selectLine\": {}}`", "Senza l'a capo"],
                    ["Cercare", "`{\"find\": { … }}`", "Trova e **seleziona** l'occorrenza successiva"],
                    ["Sostituire la selezione", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` vale se il passo precedente era un `find` con regex"],
                ]
            ),
            .heading("Direzioni di spostamento"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Il passo `find` completo"),
            .code(language: "json", caption: "Le quattro chiavi di un passo find",
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
            .paragraph("`mode` accetta `normal`, `extended` o `regex` — gli stessi tre modi del campo di ricerca."),
            .heading("Esempio 1 — mettere in maiuscolo il codice di provincia a inizio riga"),
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
                Eseguitela con `Macro ▸ Riproduci fino alla fine del documento`: che il passo `find` non trovi \
                più nulla è esattamente la condizione d'arresto.
                """),
            .heading("Esempio 2 — cancellare la riga successiva a ogni riga che contiene TODO"),
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
                Provate prima su una copia una macro modificata a mano. Un passo `find` scritto male fa fermare \
                subito la macro — questo è il caso benigno. Quello maligno è uno schema che corrisponde più \
                largamente di quanto credevate, e modifica migliaia di punti dentro un solo passo di \
                annullamento.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "Script JavaScript",
        summary: "Quattro funzioni, un file `.js`, e tutto ciò che fa è un passo di annullamento.",
        keywords: ["script", "javascript", "js", "automatizzare", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Mettete un file `.js` nella cartella `scripts/` di GEditor ed eseguitelo da `Macro ▸ Script…`. \
                Uno script vede esattamente **quattro** cose:
                """),
            .table(
                headers: ["Chiamata", "Significato"],
                rows: [
                    ["`doc.text`", "L'intero testo del documento"],
                    ["`doc.selection`", "La selezione (stringa vuota quando non c'è nulla di selezionato)"],
                    ["`doc.replace(s)`", "Sostituire l'**intero documento** con `s` — un passo di annullamento"],
                    ["`doc.log(s)`", "Scrivere una riga nel pannello dei risultati"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Numerare ogni riga.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — tenere le prime tre colonne CSV",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Tre limiti da conoscere"),
            .bullets([
                "**Nessun accesso ai file, niente rete, niente avvio di processi.** La superficie dell'API è volutamente stretta: allargarla in seguito è facile, stringerla rompe ogni script già scritto.",
                "**Questo non è un confine di sicurezza.** Gli script girano nello stesso processo. Non eseguite uno script che non avete letto.",
                "**C'è un limite di cinque secondi.** Oltre quel punto ricevete un messaggio e l'applicazione resta usabile — ma il thread di quello script **continua a girare finché non uscite**, mangiandosi un core. Il messaggio lo dice.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filtrare con un comando esterno",
        summary: "Passare la selezione attraverso un comando Unix e riprenderne il risultato.",
        keywords: ["filtro", "comando esterno", "shell", "pipe", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                La selezione (o l'intero documento) viene data allo `stdin` di un comando, e lo `stdout` di quel \
                comando la sostituisce.
                """),
            .code(language: "bash", caption: "Qualche comando abituale",
                  source: """
                    sort -u                     # ordinare e togliere i doppioni
                    jq .                        # riformattare JSON
                    tr 'a-z' 'A-Z'              # in maiuscolo
                    grep -v '^#'                # togliere le righe di commento
                    awk -F, '{print $3","$1}'   # scambiare l'ordine delle colonne
                    """),
            .note("""
                Il risultato è **un** passo di annullamento. Se il comando restituisce un codice d'errore, \
                GEditor lascia stare il testo e mostra `stderr`.
                """),
            .warning("""
                Questo comando esiste **solo nella versione a download diretto**. L'App Sandbox vieta di \
                eseguire codice fuori dall'applicazione, quindi nella versione App Store la voce di menu resta \
                e spiega perché non è disponibile.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Lo strumento a riga di comando `geditor`",
        summary: "Aprire, pulire, interrogare, valutare e rendere rapporti — senza aprire l'applicazione.",
        keywords: ["cli", "riga di comando", "terminale", "geditor", "script", "ci"],
        blocks: [
            .warning("""
                Disponibile solo nella **versione a download diretto**. La versione App Store gira in una \
                sandbox, quindi un processo esterno a riga di comando non può collegarvisi.
                """),
            .heading("Aprire file"),
            .code(language: "bash", caption: "Aprire, saltare a una posizione, leggere da una pipe",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # riga 120, colonna 5
                    geditor -w notes.md            # aspettare che il file si chiuda prima di uscire
                    geditor -r app.log             # aprire in sola lettura
                    git diff | geditor             # leggere lo standard input in una scheda nuova
                    """),
            .table(
                headers: ["Opzione", "Significato"],
                rows: [
                    ["`-w`, `--wait`", "Aspettare che il file si chiuda prima di uscire — per fare da editor di `git`"],
                    ["`-n`, `--new-window`", "Aprire in una finestra nuova"],
                    ["`-r`, `--read-only`", "Aprire in sola lettura"],
                    ["`-i`, `--info`", "Stampare codifica, fine riga e numero di righe, poi uscire — **senza** aprire l'applicazione"],
                    ["`-h`, `--help`", "Mostrare la guida"],
                    ["`-v`, `--version`", "Mostrare la versione"],
                ]
            ),
            .heading("Girare senza aprire l'applicazione"),
            .paragraph("""
                I quattro gruppi di comandi qui sotto girano **interamente nel processo a riga di comando**, \
                quindi funzionano in CI, dove nessuno ha aperto una sessione grafica.
                """),
            .code(language: "bash", caption: "Pulire con una ricetta",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Interrogare",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Il cancello di qualità — codice 0 superato · 1 non superato · 2 errore",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Rendere rapporti",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript e il menu Servizi",
        summary: "Leggere e scrivere il documento da AppleScript, o mandare testo a GEditor da un'altra applicazione.",
        keywords: ["applescript", "osascript", "servizi", "automazione", "comandi rapidi"],
        blocks: [
            .code(language: "applescript", caption: "Leggere il documento aperto",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Sovrascrivere il contenuto e leggere la selezione",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Aprire un file",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Il menu Servizi"),
            .paragraph("""
                Selezionate testo in qualsiasi applicazione, poi usate il menu `Servizi` per mandarlo a GEditor \
                come scheda nuova.
                """),
            .note("""
                La prima volta che eseguite AppleScript, macOS chiede il permesso di automazione. È la finestra \
                del sistema, non di GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Pacchetti di estensione e plug-in",
        summary: "Due tipi di estensione, e in quale versione gira ciascuno.",
        keywords: ["plug-in", "estensione", "pacchetto", "nativo"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Pacchetti di estensione"),
            .paragraph("""
                Un pacchetto è **un file JSON** che raccoglie un tema, script e linguaggi definiti dall'utente. \
                Installare copia un file, rimuovere ne cancella uno — e l'elenco dei pacchetti è ricavato dal \
                **disco**, non da un registro che potrebbe mentire.
                """),
            .paragraph("Funziona in **entrambe le versioni**."),
            .heading("Plug-in nativi"),
            .paragraph("""
                I plug-in precompilati girano in un **processo separato** con una superficie d'API stretta — un \
                plug-in che va in crash non si porta dietro l'applicazione.
                """),
            .warning("""
                I plug-in nativi esistono **solo nella versione a download diretto**, perché l'App Sandbox vieta \
                di caricare codice da fuori dell'applicazione. Ogni plug-in dev'essere **approvato a mano una \
                volta**, tramite il suo hash, prima di girare.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Configurazione e l'applicazione

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Configurazione e l'applicazione",
        summary: "Impostazioni, scorciatoie, temi, aggiornamenti, migrare da Notepad++, risoluzione dei problemi.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Impostazioni",
        summary: "Ogni opzione vive in un file JSON leggibile che potete copiare su un altro Mac.",
        keywords: ["impostazioni", "preferenze", "opzioni", "configurazione", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Aprire le impostazioni")]),
            .paragraph("""
                Non c'è OK né Annulla — una modifica ha effetto e viene scritta subito, alla maniera di macOS.
                """),
            .heading("Il file di configurazione"),
            .code(language: "text", caption: "Dove vive",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                È un **file JSON rientrato che potete leggere e modificare a mano**. Copiatelo su un altro Mac \
                e tutta la vostra configurazione va con lui. Il pulsante `Apri il file di configurazione` nelle \
                impostazioni vi porta lì direttamente.
                """),
            .heading("Le chiavi"),
            .table(
                headers: ["Chiave", "Di serie", "Significato"],
                rows: [
                    ["`fontSize`", "`13`", "Corpo del testo dell'editor"],
                    ["`tabWidth`", "`4`", "Quante colonne è larga una tabulazione"],
                    ["`usesTabsForIndent`", "`false`", "Rientrare con tabulazioni invece che con spazi"],
                    ["`languageIndent`", "`{}`", "Rientro per linguaggio — vedi la pagina sugli spazi"],
                    ["`smartIndent`", "`true`", "Rientro automatico su una riga nuova"],
                    ["`highlightAllMatches`", "`true`", "Evidenziare ogni occorrenza di ricerca"],
                    ["`ligatures`", "`false`", "Legature — vedi la nota sotto la tabella"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Tagliare gli spazi finali al salvataggio"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalizzare Unicode a NFC al salvataggio"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Codifica dei file nuovi"],
                    ["`defaultEOL`", "`\"lf\"`", "Fine riga dei file nuovi"],
                    ["`language`", "`\"system\"`", "Lingua dell'interfaccia"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "il tema di serie", "Quale tema di colore è in uso"],
                    ["`showWelcomeOnLaunch`", "`true`", "Aprire la finestra di benvenuto all'avvio"],
                    ["`keyBindings`", "`{}`", "Solo i tasti che avete cambiato"],
                ]
            ),
            .note("""
                **Perché le legature sono DISATTIVE di serie.** Una legatura fonde `!=` o `->` in **un solo** \
                glifo, così i caratteri che vedete a schermo non corrispondono più a quelli nel file — e \
                l'editor di colonne, il modo colonna e l'a capo a una colonna misurano tutti in colonne. \
                Attivatele per scrivere prosa, o se avete scelto un carattere da programmazione (Fira Code, \
                JetBrains Mono) proprio per le sue legature.
                """),
            .heading("Le cartelle vicine"),
            .table(
                headers: ["Cartella", "Contiene"],
                rows: [
                    ["`macros/`", "Macro salvate, un file JSON ciascuna"],
                    ["`scripts/`", "Script JavaScript"],
                    ["`themes/`", "Temi di colore"],
                    ["`grammars/`", "Linguaggi definiti dall'utente"],
                ]
            ),
            .warning("""
                Un file di configurazione scritto da un GEditor **più recente non viene sovrascritto** da uno \
                più vecchio — quest'ultimo gira sui valori di serie e lo dice. Sovrascrivere è il modo più \
                sicuro di distruggere la configurazione di chi sincronizza due macchine, e non ne saprebbe mai \
                il perché.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "La barra di stato",
        summary: "Dieci segmenti in basso — tutti leggibili e tutti cliccabili.",
        keywords: ["barra di stato", "posizione", "codifica", "sola lettura", "dimensione"],
        blocks: [
            .paragraph("""
                È la differenza più grande rispetto alle barre di stato di altri editor: **nessun segmento è in \
                sola lettura**. Se vedete un valore sbagliato, farci clic è il modo di correggerlo, invece di \
                frugare nei menu.
                """),
            .table(
                headers: ["Segmento", "Vi dice", "Facendoci clic"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "posizione del cursore — colonna in CARATTERI, `@340` la posizione in byte",
                     "apre il campo `Vai a`"],
                    ["`11 byte · 3 dòng`", "dimensione del documento",
                     "conta byte · caratteri · parole · righe"],
                    ["`🔒 Chỉ đọc`", "mostrato solo quando il documento è bloccato",
                     "dice PERCHÉ è bloccato, e lo sblocca quando è possibile"],
                    ["`View` / `Code`", "in quale vista siete", "alterna (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "modo CSV e separatore in uso",
                     "commuta il modo CSV, o **riseleziona il separatore**"],
                    ["`Đang theo dõi`", "`tail -f` è in corso", "—"],
                    ["`UTF-8`", "la codifica", "reinterpretare, o convertire in un'altra codifica"],
                    ["`LF`", "stile di fine riga", "alternare LF · CRLF · CR"],
                    ["`Python`", "linguaggio della colorazione sintattica", "sceglierne un altro, o tornare al rilevamento per estensione"],
                    ["`Tab: 4`", "larghezza del rientro", "2 · 4 · 8, globale o **solo per questo linguaggio**"],
                    ["`Ngắt: tắt`", "modo di a capo", "scorre i tre modi"],
                ]
            ),
            .heading("Tre segmenti che meritano una seconda occhiata"),
            .bullets([
                "**`@340` — la posizione in byte.** È il numero che parla ogni altro strumento del prodotto: gli errori JSON e XML, l'output di `--doc-sweep`, il visualizzatore binario e il campo `Vai a @340`. Leggetelo qui, scrivetelo là.",
                "**Una `~` sulla colonna** significa che il numero conta BYTE e non colonne visive — succede solo su righe oltre i 200 KB, dove contare i caratteri rallenterebbe ogni movimento del cursore.",
                "**`CSV · …` è cliccabile per riselezionare il separatore.** Il rilevamento può sbagliare, e quando sbaglia ogni operazione sulle colonne è fuori posto senza nulla che lo segnali. È così che dite il contrario — RILEGGE soltanto il file, senza cambiare un byte (a differenza di `CSV ▸ Cambia separatore…`, che lo riscrive).",
            ]),
            .note("""
                Un segmento che non riguarda il file aperto è **nascosto**, non attenuato: `Sola lettura` \
                compare solo quando il documento è davvero bloccato, e `CSV · …` solo in modo CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Cambiare le scorciatoie da tastiera",
        summary: "Cambiare singoli tasti, o adottare in blocco la mappa di Notepad++.",
        keywords: ["scorciatoia", "mappa di tasti", "preimpostazione"],
        blocks: [
            .paragraph("""
                Le `Impostazioni…` hanno una sezione Scorciatoie con due pulsanti rapidi: **Usa la \
                preimpostazione di Notepad++** e **Torna ai valori di serie**.
                """),
            .paragraph("""
                Il file di configurazione registra solo ciò che avete **cambiato rispetto ai valori di serie**. \
                Così, quando GEditor cambia un tasto predefinito in una versione nuova, non restate bloccati \
                sulla mappa vecchia senza che nessuno ve lo dica.
                """),
            .note("""
                Due comandi non possono condividere una scorciatoia. Quando lo fanno, AppKit attiva in silenzio \
                solo la **prima** voce di menu e l'altro comando sembra rotto — perciò GEditor ha un controllo \
                che lo impedisce.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Temi, chiaro e scuro",
        summary: "Seguire il sistema, chiaro o scuro; e un tema è un file JSON che potete modificare.",
        keywords: ["tema", "colori", "modo scuro", "chiaro", "aspetto"],
        blocks: [
            .paragraph("Le `Impostazioni…` scelgono `Segui il sistema`, `Chiaro` o `Scuro`, e selezionano un tema di colore."),
            .paragraph("""
                Un tema è un file JSON in `themes/`. Il pulsante `Esporta il tema corrente` ne scrive uno come \
                punto di partenza per il vostro.
                """),
            .note("""
                Un colore scritto male in un file di tema ricade sul colore del **tema di serie**, non sul nero. \
                Il nero sembra una decisione di progetto, e l'utente andrebbe a cercare il problema altrove.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Aggiornamenti, versioni e uscita",
        summary: "In che cosa differisce l'aggiornamento fra le due versioni.",
        keywords: ["aggiornamento", "versione", "informazioni", "uscire"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Versione", "Si aggiorna tramite"],
                rows: [
                    ["App Store", "L'App Store, come ogni altra app"],
                    ["Download diretto", "`Cerca aggiornamenti…` dentro l'applicazione"],
                ]
            ),
            .paragraph("""
                `Informazioni su GEditor` mostra la versione in esecuzione e di quale versione si tratta — utile \
                quando si segnala un problema.
                """),
            .note("""
                Nella versione App Store, `Cerca aggiornamenti…` **resta nel menu** e spiega perché non si \
                applica, invece di sparire. Una voce di menu mancante diventa una richiesta all'assistenza.
                """),
            .paragraph("Uscire non fa perdere lavoro: la sessione torna la prossima volta che aprite."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Usare questa finestra della guida",
        summary: "Cercare nel libro, cambiarne la lingua e far tornare la finestra di benvenuto.",
        keywords: ["guida", "manuale", "ricerca", "benvenuto", "lingua"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Aprire la finestra della guida")]),
            .bullets([
                "Il campo di ricerca in alto a sinistra guarda dentro il **testo e gli esempi di codice** — scrivere una chiave di configurazione come `fail_under` porta alla pagina giusta.",
                "Scrivere **senza accenti** trova comunque testo accentato.",
                "Il pulsante `Indietro` torna alla pagina precedente.",
                "Il pulsante `Copia` su ogni blocco di codice copia quel blocco.",
            ]),
            .heading("Leggere in un'altra lingua"),
            .paragraph("""
                Il menu a comparsa in alto a destra di questa finestra sceglie la **lingua del libro**, \
                indipendentemente dalla lingua dell'interfaccia. Il cambio vi tiene **sulla pagina che state \
                leggendo** — gli identificativi di pagina non sono tradotti di proposito, proprio perché questo \
                funzioni.
                """),
            .note("""
                Sono elencate solo le lingue che hanno davvero un libro. Una voce di menu che passa a qualcosa \
                e lascia il testo invariato sarebbe una voce di menu che mente.
                """),
            .heading("Far tornare la finestra di benvenuto"),
            .paragraph("""
                Se avete spuntato **Non aprire questa finestra all'avvio**, riapritela con `Aiuto ▸ Giro fra le \
                funzioni` — la casella in fondo alla finestra ricompare e si può togliere.
                """),
            .paragraph("Oppure rimettete `showWelcomeOnLaunch` a `true` in `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Da Notepad++ a GEditor",
        summary: "Quali tasti si scambiano di posto, che cosa funziona diversamente e che cosa manca.",
        keywords: ["notepad++", "migrazione", "windows", "scorciatoie"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Alcuni tasti **si scambiano di posto** su macOS invece di limitarsi a cambiare `Ctrl` in `⌘`. \
                Ecco il confronto.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Perché"],
                rows: [
                    ["`Ctrl+D` Duplica riga", "**⇧⌘D**", "Qui `⌘D` è il multicursore, come in ogni editor per Mac"],
                    ["`Ctrl+L` Elimina riga", "**⌘K**", "Su macOS `⌘L` significa «vai alla riga»"],
                    ["`Ctrl+G` Vai alla riga", "**⌘L**", "Questi due si scambiano di posto"],
                    ["`Ctrl+Q` Commenta", "**⌘/**", "Convenzione di macOS"],
                    ["`Ctrl+Shift+↑/↓` Sposta riga", "**⌥↑ / ⌥↓**", "Su macOS `⌃` appartiene a Mission Control"],
                    ["`F3` Trova successivo", "**⌘G**", "Convenzione di macOS"],
                    ["`Ctrl+F2` Attiva segnalibro", "**⌘F2**", "F2 e ⇧F2 saltano ancora fra i contrassegni"],
                    ["`Alt` + trascinamento per le colonne", "**⌥ + trascinamento**", "Identico"],
                    ["`Ctrl+Alt+Shift+↓` Editor di colonne", "**⌥⌘C**", "Convenzione di macOS"],
                ]
            ),
            .note("Preferite non reimparare? `Impostazioni ▸ Scorciatoie ▸ Usa la preimpostazione di Notepad++`."),
            .heading("Cose che Notepad++ ha e qui funzionano diversamente"),
            .bullets([
                "**Le sessioni** si ripristinano da sole, comprese le schede non salvate — niente da attivare.",
                "**I segnalibri hanno nove colori**, e una riga può portarne più d'uno insieme.",
                "**La mappa del documento** descrive l'*intero* file, non solo la parte visibile.",
                "**Le macro** possono girare «fino alla fine del documento» e «su tutte le schede», e un'intera esecuzione è un passo di annullamento.",
            ]),
            .heading("Che cosa aggiunge GEditor"),
            .bullets([
                "Un **banco di pulizia dei dati** e **profili dei dati** per i file CSV.",
                "**Interrogazioni SQL** direttamente su un file CSV.",
                "**Codifiche vietnamite antiche** — TCVN3, VISCII, VNI-Windows, lette, scritte e rilevate automaticamente.",
                "**Ricerca insensibile agli accenti** in ogni campo di filtro.",
                "**Rapporti `.greport.md`** con tabelle e grafici che si ricalcolano.",
                "Lo **strumento a riga di comando `geditor`** nella versione a download diretto.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Problemi comuni",
        summary: "Sei situazioni che fanno pensare che l'applicazione sia rotta.",
        keywords: ["errore", "problema", "non funziona", "risolvere", "perché"],
        blocks: [
            .table(
                headers: ["Sintomo", "Causa abituale"],
                rows: [
                    ["Il testo vietnamita appare illeggibile", "Codifica sbagliata — fate clic sulla codifica nella barra di stato"],
                    ["Cercare testo accentato non trova nulla", "Il file è in Unicode decomposto — eseguite `Normalizza Unicode` a NFC"],
                    ["Una voce di menu è attenuata", "La versione App Store non può eseguire quel comando — la voce spiega perché"],
                    ["La corrispondenza delle parentesi rifiuta", "Il documento supera 1 MB — evidenziare la coppia sbagliata è peggio di nessuna"],
                    ["La colonna nella barra di stato ha una `~`", "Il documento supera 200 KB, quindi è un conteggio di byte e non una colonna visiva"],
                    ["Un'interrogazione SQL dice che bisogna prima salvare", "DuckDB legge **file**, non il buffer che state modificando"],
                ]
            ),
            .heading("Quando GEditor termina inaspettatamente"),
            .paragraph("""
                All'avvio successivo un banner lo dice, con un pulsante **Apri il rapporto** — il rapporto si \
                apre come scheda che potete leggere e da cui potete copiare come da qualsiasi file di testo.
                """),
            .bullets([
                "Il rapporto porta solo la **versione, la versione di macOS, l'architettura della macchina, il nome del segnale e la pila delle chiamate**.",
                "**Nessun contenuto del documento, e nemmeno percorsi di file** — un percorso come `~/Scrivania/stipendi-dicembre.xlsx` ha già rivelato tre cose private prima che qualcuno lo apra.",
                "**Non viene mandato nulla da nessuna parte.** Non c'è invio automatico né un server che lo riceva; il file resta in `~/Library/Application Support/GEditor/crash/` finché non lo aprite o lo cancellate.",
                "Una volta che avete aperto il rapporto, l'avvio successivo non lo nomina più.",
            ]),
            .heading("Dove guardare poi"),
            .bullets([
                "La barra di stato mostra codifica, fine riga, linguaggio e modo di a capo — ogni segmento è cliccabile.",
                "`settings.json` si può modificare a mano quando la finestra delle impostazioni non basta.",
                "`Informazioni su GEditor` dà la versione e la variante, di cui una segnalazione di errore ha bisogno.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
