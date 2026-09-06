import Foundation

/// Contenuto della guida in italiano — parte 4: dati tabellari, pulizia ed estrazione.
extension HelpIT {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Dati tabellari",
        summary: "Vedere un CSV come tabella, filtrare, ordinare, controllare la struttura, interrogare con SQL, convertire.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Vedere un CSV come tabella",
        summary: "Un milione di righe scorre comunque senza scatti, l'intestazione resta ferma e il testo sorgente è intatto.",
        keywords: ["csv", "tabella", "griglia", "tsv", "excel", "colonne"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Passare da tabella a testo")]),
            .paragraph("""
                La tabella è **virtualizzata**: si costruiscono solo le righe visibili, così un file da un \
                milione di righe scorre come uno da cento.
                """),
            .bullets([
                "**La riga d'intestazione resta incollata** durante lo scorrimento — alla riga 40 000 sapete ancora che cos'è la nona colonna.",
                "Modificate una cella nella tabella; la modifica va dritta nel testo sorgente.",
                "Tabella e testo sono **due sguardi su un file**, non due copie.",
                "**⌘C copia la riga selezionata**, con le celle separate da tabulazioni — incollate direttamente in Excel o Numbers e ogni cella finisce al posto giusto. Le celle con tabulazioni o a capo vengono virgolettate, perché la destinazione non le spezzi in due.",
            ]),
            .note("""
                Il separatore è rilevato all'apertura (virgola, punto e virgola, tabulazione, barra \
                verticale). Se l'ipotesi è sbagliata, cambiatelo con `CSV ▸ Cambia separatore…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Cartelle con più fogli",
        summary: "Aprire qualsiasi foglio di un .xlsx, e ⌘S riscrive nel foglio che state guardando.",
        keywords: ["excel", "xlsx", "foglio", "cartella di lavoro"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Aprite un `.xlsx` e GEditor mostra il **primo foglio** come tabella CSV. `CSV ▸ Scegli \
                foglio…` elenca ogni foglio del file e apre quello che scegliete nella stessa scheda.
                """),
            .heading("Riscrivere nel foglio GIUSTO"),
            .paragraph("""
                `⌘S` scrive le vostre modifiche nel **foglio che state guardando**, non nel primo. Gli altri \
                fogli non vengono toccati nemmeno di un byte.
                """),
            .note("""
                Il foglio è ricordato per **nome**, non per posizione. Così riordinare i fogli in Excel fra \
                due sessioni non devia la scrittura.
                """),
            .warning("""
                Se il foglio aperto è stato **rinominato o eliminato** in Excel da quando l'avete aperto, \
                `⌘S` **rifiuta di scrivere** e lo dice. Ripiegare sul primo foglio equivarrebbe a versare il \
                contenuto di un foglio sopra un altro — il file verrebbe salvato lo stesso, si riaprirebbe lo \
                stesso, e conterrebbe semplicemente i dati nel posto sbagliato.
                """),
            .heading("Cambiare foglio con modifiche non salvate"),
            .paragraph("""
                Cambiare foglio sostituisce l'intero contenuto della scheda, quindi se c'è qualcosa di non \
                salvato GEditor **chiede prima**. `⌘Z` non può riportarlo indietro, perché è stato scambiato \
                l'intero documento.
                """),
            .heading("Che cosa costa ridurre Excel a una tabella"),
            .paragraph("""
                Ciò che sopravvive sono i **valori** — compresi i risultati delle formule, esattamente i \
                numeri che Excel mostra. Ciò che non sopravvive: caratteri, colori, celle unite, grafici \
                incorporati e le formule stesse.
                """),
            .paragraph("""
                In cambio quel foglio guadagna tutto il resto del prodotto: filtri, ordinamenti, \
                interrogazioni SQL, il banco di pulizia, la valutazione della qualità, l'estrazione, i \
                grafici.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtrare e ordinare nella tabella",
        summary: "Un campo di filtro per colonna, che capisce il confronto numerico e la scrittura senza accenti.",
        keywords: ["filtro", "ordinare", "colonna", "cercare nella tabella"],
        blocks: [
            .paragraph("Fate clic su un'intestazione di colonna per ordinare. Il campo di filtro sotto accetta:"),
            .table(
                headers: ["Scrivete nel filtro", "Significato"],
                rows: [
                    ["`hue`", "Contiene `hue`, **insensibile agli accenti** — trova anche `Huế`"],
                    ["`=Huế`", "Esattamente `Huế` (resta insensibile agli accenti)"],
                    ["`>100`", "Maggiore di 100"],
                    ["`>=100`", "100 o più"],
                    ["`<0`", "Minore di 0"],
                    ["`100..200`", "Fra 100 e 200"],
                    ["vuoto", "Nessun filtro su questa colonna"],
                ]
            ),
            .paragraph("""
                Filtrare più colonne è una **e**: una riga deve soddisfarle tutte. Il confronto numerico salta \
                le celle non numeriche invece di trattarle come zero.
                """),
            .note("""
                Filtrare è un **modo di guardare**, non una cancellazione. Svuotate il filtro e tornano tutte \
                le righe.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Controllare la struttura della tabella",
        summary: "Trovare le righe con il numero di colonne sbagliato e le celle di tipo sbagliato — questo per primo.",
        keywords: ["convalidare", "controllare", "numero di colonne", "tipo sbagliato", "dati rotti"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                È questo da eseguire **prima** di ogni altra cosa su un file che vi hanno mandato. Risponde a \
                due domande:
                """),
            .bullets([
                "**Quali righe hanno il numero di colonne sbagliato?** Di solito una cella con una virgola non virgolettata — e sfasa tutte le righe successive.",
                "**Quali celle hanno un tipo diverso dal resto della loro colonna?** Per esempio un `n/a` in una colonna di numeri.",
            ]),
            .paragraph("I risultati appaiono come elenco; fate clic su uno per saltare a quella riga."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Eliminare colonne",
        summary: "Togliere del tutto dal file una o più colonne.",
        keywords: ["eliminare colonna", "togliere colonna"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Scegliete dall'elenco le colonne da scartare e applicate. È **un** passo di annullamento, per \
                quante righe abbia il file.
                """),
            .warning("""
                A differenza del filtro, questo **modifica il file vero**. Per limitarvi a nascondere colonne, \
                usate un'interrogazione SQL che elenchi quelle che volete.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Interrogare un CSV con SQL",
        summary: "Tutto l'SQL di DuckDB, eseguito direttamente sul file aperto — in sola lettura.",
        keywords: ["sql", "interrogazione", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                La tabella aperta si chiama **`t`**. Il motore è **DuckDB**, quindi `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, le funzioni finestra e le sottointerrogazioni funzionano \
                tutte.
                """),
            .code(language: "sql", caption: "Ricavi per provincia, dal maggiore al minore",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Filtrare per data e per una condizione testuale",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "La quota di ogni provincia sul totale — con una funzione finestra",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Unire con un altro file su disco",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Sola lettura, ed è una garanzia ferma"),
            .bullets([
                "Il database vive **in memoria**; il file sorgente viene solo letto.",
                "Viene accettata esattamente **una istruzione**, e **dev'essere un `SELECT`**. Tutto il resto — compreso `COPY … TO 'file'`, che DuckDB può benissimo usare per scrivere su disco — è bloccato prima di raggiungere qualsiasi dato.",
            ]),
            .warning("""
                DuckDB legge **file**, non memoria. Se il documento ha modifiche non salvate, GEditor deve \
                scrivere una copia temporanea prima di interrogare. Con un file molto grande e modifiche non \
                salvate, **si ferma e lo dice** invece di scrivere in silenzio centinaia di megabyte su disco \
                per una sola interrogazione.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Tabelle pivot e grafici rapidi",
        summary: "Pivotare e disegnare direttamente da un risultato d'interrogazione.",
        keywords: ["pivot", "grafico", "tabella incrociata", "aggregato"],
        blocks: [
            .paragraph("""
                Entrambi si aprono dalla **tabella dei risultati**: eseguite un'istruzione SQL e poi usate il \
                pulsante Pivot o Grafico del pannello.
                """),
            .heading("Pivot"),
            .paragraph("""
                Scegliete la colonna delle **righe**, quella delle **colonne**, quella dei **valori** e \
                l'aggregato (somma, conteggio, media, min, max) — come la tabella pivot di un foglio di \
                calcolo.
                """),
            .heading("Grafici"),
            .paragraph("""
                Barre, linee, torta, dispersione. Numeri in formato vietnamita o europeo, e il grafico si \
                esporta come PNG o SVG per incollarlo altrove.
                """),
            .note("""
                Volete un grafico che **si aggiorni con i dati** a ogni ricostruzione? È il blocco `chart` di \
                un rapporto `.greport.md`.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Convertire una tabella in un altro formato",
        summary: "TSV, JSON, XML, tabelle Markdown, istruzioni SQL INSERT — con anteprima.",
        keywords: ["convertire", "esportare", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Formato", "Utile per"],
                rows: [
                    ["TSV", "Incollare in un foglio di calcolo senza preoccuparsi delle virgole nelle celle"],
                    ["JSON", "Alimentare un'API, uno script o un altro strumento"],
                    ["XML", "Sistemi vecchi che pretendono XML"],
                    ["Tabella Markdown", "Incollare in documentazione, in un README, in un ticket"],
                    ["Istruzioni SQL INSERT", "Caricare in una base di dati"],
                ]
            ),
            .paragraph("""
                La finestra **mostra in anteprima le prime cinque righe** prima di creare la scheda nuova — \
                cinque righe bastano a confermare il nome della tabella, le virgolette e quali colonne sono \
                diventate numeri.
                """),
            .note("""
                L'anteprima chiama **la stessa funzione** che produce l'output vero, limitata a cinque righe. \
                Non è una simulazione che potrebbe discostarsi dal risultato finale.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Cambiare il separatore",
        summary: "Convertire un file fra virgola, punto e virgola, tabulazione e barra verticale.",
        keywords: ["separatore", "virgola", "punto e virgola", "tabulazione", "csv europeo"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                I file esportati da un Excel vietnamita o europeo usano di solito il **punto e virgola**, \
                perché lì la virgola è il separatore decimale.
                """),
            .warning("""
                Cambiare il separatore **riscrive l'intero file**. Le celle che contengono il separatore nuovo \
                vengono virgolettate — altrimenti la struttura della tabella si rompe.
                """),
            .note("""
                **Se il rilevamento ha sbagliato, non è questo il comando che volete.** Qui ci sono due \
                compiti diversi, esattamente come nella coppia di codifica «reinterpreta» / «converti»:

                • *Il file usa davvero il punto e virgola e noi abbiamo indovinato la virgola* — fate clic sul \
                segmento `CSV · …` della **barra di stato** e scegliete quello giusto. Non cambia un byte del \
                file; cambia solo come viene letto.

                • *Il file usa davvero la virgola e voi volete il punto e virgola* — usate il comando di questa \
                pagina. Riscrive il file.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Pulizia

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Pulizia dei dati — l'intero flusso",
        summary: "Da un file grezzo che vi hanno mandato a una tabella usabile, e uno standard da rieseguire ogni mese.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Il flusso di pulizia, dall'inizio alla fine",
        summary: "Sei passi da un file sconosciuto a una tabella affidabile, e uno standard per il mese prossimo.",
        keywords: ["pulizia", "flusso", "normalizzare", "dati puliti"],
        blocks: [
            .paragraph("""
                Pulire i dati **è raramente una cosa una tantum**. Le persone ricevono lo stesso modello di \
                rapporto ogni mese, e ogni mese vanno normalizzate le stesse colonne allo stesso modo. Questo \
                flusso è pensato per questo: lo fate a mano una volta e poi lo rieseguite con un solo comando.
                """),
            .heading("Sei passi"),
            .steps([
                "**Guardate prima la struttura.** `CSV ▸ Controlla i dati` — quali righe hanno il numero di colonne sbagliato, quali celle il tipo sbagliato. Viene per prima perché una sola riga sfasata rende priva di senso ogni statistica successiva.",
                "**Leggete il profilo dei dati.** Per colonna: quante celle vuote, quanti valori distinti, che tipo, dove sono gli anomali. È qui che capite il file, prima di cambiare qualsiasi cosa.",
                "**Aprite il banco di pulizia** (`⇧⌘L`). Rileva formati di data misti, numeri vietnamiti mescolati a europei, spazi vaganti, valori mancanti. **Anteprima prima→dopo**, poi applicate.",
                "**Trattate i doppioni approssimati** se una colonna di nomi o indirizzi ha varianti scritte a mano. Qui decidete voi; la macchina si limita a proporre.",
                "**Salvatelo come ricetta.** La sequenza che avete appena eseguito viene scritta in un file JSON con nome — quel file è la vostra conoscenza su questi dati.",
                "**Scrivete un insieme di regole di qualità** `.gquality.yaml` e valutate. Da qui in poi il file del mese prossimo passa dalla ricetta e riceve un voto, e il **cancello a riga di comando** restituisce un codice d'uscita diverso da zero quando non passa.",
            ]),
            .heading("Perché quest'ordine"),
            .bullets([
                "Struttura **prima** del profilo: le statistiche su una tabella sfasata sono statistiche su un'altra colonna.",
                "Profilo **prima** della pulizia: bisogna sapere «2 % vuoto» prima di decidere se riempire o scartare.",
                "Doppioni approssimati **dopo** la normalizzazione: `CÔNG TY  A` e `Công ty A` si rivelano uno solo quando spazi e maiuscole sono sistemati.",
                "Ricetta **prima** dell'insieme di regole: la ricetta corregge, le regole giudicano — valutare una tabella non corretta produce solo un numero basso che vi aspettavate già.",
            ]),
            .heading("Dopo la prima volta, ogni mese è un comando"),
            .code(language: "bash", caption: "Pulire e poi valutare, restituendo un codice d'uscita per la CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Il codice d'uscita **0** significa superato, **1** non superato, **2** errore d'esecuzione. \
                `--record-history` aggiunge una riga al file di cronologia perché l'esecuzione successiva possa \
                confrontare la deriva.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Profilo dei dati",
        summary: "Una descrizione per colonna: tipo, vuoti, valori distinti, distribuzione.",
        keywords: ["profilo", "statistica di colonna", "nullo", "distinto"],
        blocks: [
            .paragraph("""
                Un profilo **descrive**; non giudica. Dice *«questa colonna è vuota al 2 %»*; se il 2 % sia \
                accettabile appartiene all'insieme di regole di qualità.
                """),
            .table(
                headers: ["Misura", "Come leggerla"],
                rows: [
                    ["Tipo", "Dedotto dai dati stessi, non dal nome della colonna"],
                    ["Celle vuote", "Numero e proporzione di valori mancanti"],
                    ["Valori distinti", "1 significa colonna costante; uguale al numero di righe, colonna chiave"],
                    ["Min · max · media", "Solo colonne numeriche"],
                    ["Valori più frequenti", "Individuare subito un codice d'errore o un valore predefinito abusato"],
                ]
            ),
            .warning("""
                Il conteggio dei valori distinti ha una soglia. Oltre, il numero mostrato è un **limite \
                inferiore**, e il profilo **dice che è una stima** invece di mescolarlo ai conteggi esatti.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Il banco di pulizia dei dati",
        summary: "Sette normalizzazioni, sempre con anteprima, sempre un passo di annullamento, mai a indovinare.",
        keywords: ["pulire", "normalizzare", "date", "numeri", "riempire"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Aprire il banco di pulizia")]),
            .table(
                headers: ["Operazione", "Che cosa fa"],
                rows: [
                    ["Normalizzare le date", "Portare ogni forma di data della colonna a una sola"],
                    ["Normalizzare i numeri", "Sistemare il separatore decimale e quello delle migliaia"],
                    ["Tagliare gli spazi", "Toglierli alle due estremità; volendo comprimere anche quelli interni"],
                    ["Cambiare le maiuscole", "Rendere coerente la capitalizzazione della colonna"],
                    ["Riempire con un valore fisso", "Sostituire le celle vuote con un valore che scrivete"],
                    ["Riempire da una vicina", "Prendere il valore della riga sopra o sotto"],
                    ["Eliminare le righe con celle vuote", "Scartare le righe a cui mancano dati"],
                ]
            ),
            .heading("Tre garanzie dell'intero banco"),
            .bullets([
                "**Sempre con anteprima.** Una tabella prima→dopo, con il numero di celle che cambieranno.",
                "**Un passo di annullamento** per l'intera passata, anche se tocca un milione di celle.",
                "**Un rapporto dopo**: quante celle sono cambiate e quali non si sono potute leggere.",
            ]),
            .heading("Il principio: non indovinare mai"),
            .paragraph("""
                Una cella che non si riesce a leggere con certezza viene **segnalata e lasciata stare**. \
                Prendete `03/04/2026` in una colonna che mescola le due convenzioni: è il 3 aprile o il 4 \
                marzo? GEditor vi chiede l'ordine giorno/mese invece di scegliere al posto vostro.
                """),
            .warning("""
                Normalizzare male una colonna di date è il tipo di corruzione **quasi impossibile da \
                rilevare**: i numeri continuano a sembrare giusti, sono solo un'altra data. Per questo questo \
                banco preferisce rifiutare che dedurre.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Doppioni approssimati",
        summary: "Trovare varianti scritte a mano dello stesso nome — e non fonderle mai in automatico.",
        keywords: ["approssimato", "doppioni", "fondere", "varianti", "refusi"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — tre modi di scrivere lo \
                stesso cliente. La rimozione ordinaria dei doppioni non li vede come uguali.
                """),
            .steps([
                "Scegliete la colonna da esaminare e una soglia di somiglianza.",
                "GEditor raggruppa i valori vicini in **grappoli** e mostra la forma di confronto.",
                "Per **ogni grappolo** scegliete voi quale valore tenere — oppure lo saltate.",
                "Applicate. Un passo di annullamento.",
            ]),
            .warning("""
                Questo strumento **non fonde mai da solo**, e non c'è un pulsante «fondi tutto». Due stringhe \
                simili al 92 % possono essere un refuso, o due aziende davvero diverse che si distinguono per \
                una parola — una macchina non può deciderlo.
                """),
            .paragraph("""
                Fondere male due record è perdita di dati **silenziosa**: nessuna cella diventa vuota, nessuna \
                riga diventa rossa, due entità semplicemente diventano una e nessuno se ne accorge finché non \
                si chiudono i conti.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Ricette di pulizia",
        summary: "Registrare la sequenza come file JSON e rieseguirla sui dati del mese prossimo.",
        keywords: ["ricetta", "ripetere", "automatizzare", "mensile", "lotto"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Dopo la pulizia salvate i passi come **ricetta**. È un file JSON leggibile da un umano che \
                potete tenere accanto ai dati, mandare a un collega e mettere in un repository perché le \
                modifiche restino tracciate.
                """),
            .code(language: "json", caption: "sales-standard.json — abbreviato",
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
                Ogni passo si può **disattivare** (`enabled`), così una ricetta può servire per più specie di \
                file quasi identiche.
                """),
            .heading("Rieseguire"),
            .bullets([
                "Nell'applicazione: `CSV ▸ Esegui ricetta di pulizia…`",
                "Dalla shell, su un'intera cartella: vedi la pagina della riga di comando.",
            ]),
            .code(language: "bash", caption: "Una prova a vuoto prima di scrivere qualsiasi cosa — nessun file viene toccato",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Di serie il risultato è scritto in un file nuovo accanto all'originale (`sales-clean.csv`). \
                Sovrascrivere l'originale va chiesto esplicitamente con `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Valutazione della qualità dei dati",
        summary: "Sei dimensioni, un voto da 0 a 100, e ogni formula stampata perché possiate ricalcolarla.",
        keywords: ["qualità", "voto", "dqr", "sei dimensioni"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Si distingue dal profilo dei dati per una cosa fondamentale: un profilo **descrive**, un voto \
                **giudica rispetto allo standard che avete dichiarato** in un file `.gquality.yaml`.
                """),
            .table(
                headers: ["Dimensione", "Che cosa misura"],
                rows: [
                    ["Completezza", "Proporzione di celle riempite secondo le regole `not_null`"],
                    ["Validità", "Proporzione di regole di formato, tipo, intervallo e regex superate"],
                    ["Unicità", "Rispetto alla chiave dichiarata in `uniqueness_key`"],
                    ["Coerenza", "Regole fra colonne e fra file"],
                    ["Accuratezza (stimata)", "Valori anomali nelle colonne numeriche che indicate"],
                    ["Tempestività", "Quanto sono vecchi i dati rispetto alla soglia `freshness`"],
                ]
            ),
            .heading("Tre garanzie sul voto"),
            .bullets([
                "**La formula è stampata nel risultato** — potete ricalcolarla a mano.",
                "**Deterministico**: gli stessi dati e le stesse regole danno lo stesso voto. Solo la *Tempestività* dipende dal momento, quindi `now` è un **parametro** ed è registrato nel risultato.",
                "**Una dimensione che non si può valutare resta vuota con la sua ragione**, mai con un 100 dato in silenzio.",
            ]),
            .warning("""
                Quest'ultima garanzia conta. Una tabella senza `uniqueness_key` dichiarata a cui si dà 100 in \
                «unicità» è un voto che mente — e mente nella direzione lusinghiera, quella pericolosa.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Sintassi di `.gquality.yaml`",
        summary: "Ogni chiave del file di regole, con un insieme completo che gira.",
        keywords: ["gquality", "yaml", "regole", "sintassi", "standard di dati"],
        blocks: [
            .paragraph("""
                Il file vive **accanto ai dati**, non dentro l'applicazione: uno standard di dati dev'essere \
                revisionabile, e revisionare è ciò che le persone fanno con gli standard.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — un insieme di regole completo",
                  source: """
                    schemaVersion: 1

                    # Pesi delle sei dimensioni. Una dimensione assente pesa 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # La chiave che rende unica una riga. Senza di essa la dimensione «Unicità»
                    # NON PUÒ essere valutata — e il totale lo dice.
                    uniqueness_key: [ma_don]

                    # Colonne numeriche esaminate per gli anomali nell'«Accuratezza (stimata)».
                    accuracy_columns: [doanh_thu, so_luong]

                    # La dimensione «Tempestività».
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Avvertire quando questa esecuzione cala rispetto alla precedente.
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
                        max_null_pct: 2          # ammette il 2 % vuoto
                      # Regola fra colonne: non serve `col`
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Regola fra file: il valore deve esistere in un altro file
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("I tipi di regola"),
            .table(
                headers: ["Chiave", "Significato", "Dimensione"],
                rows: [
                    ["`not_null: true`", "La cella dev'essere riempita; `max_null_pct` allenta", "Completezza"],
                    ["`unique: true`", "Nessun valore ripetuto nella colonna", "Unicità"],
                    ["`dtype: int\\|float\\|date\\|text`", "Tipo corretto", "Validità"],
                    ["`range: { min:, max: }`", "Dentro un intervallo numerico", "Validità"],
                    ["`length: { min:, max: }`", "Lunghezza della stringa", "Validità"],
                    ["`regex: \"…\"`", "Corrisponde a un'espressione regolare", "Validità"],
                    ["`in_set: [ … ]`", "Uno di un elenco dato", "Validità"],
                    ["`date_format: \"…\"`", "Forma di data corretta", "Validità"],
                    ["`compare: { a:, op:, b: }`", "Confrontare due colonne; `op` è `<` `<=` `=` `>=` `>` `<>`", "Coerenza"],
                    ["`foreign_key: { file:, column: }`", "Il valore deve esistere in un altro file", "Coerenza"],
                    ["`severity: error\\|warn`", "Gravità della regola; `error` di serie", "—"],
                ]
            ),
            .warning("""
                Se scrivete male una chiave di regola, il file viene **rifiutato con un messaggio**, invece di \
                saltare quella regola in silenzio. Saltarla in silenzio significa lasciarvi credere che i dati \
                siano stati verificati rispetto a una regola che non è mai girata.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Un cancello di qualità nella CI",
        summary: "Fermare i dati difettosi nella catena, usando i codici d'uscita.",
        keywords: ["ci", "cancello", "fail-under", "codice d'uscita", "cronologia", "deriva"],
        blocks: [
            .code(language: "bash", caption: "Valutare e restituire un codice d'uscita",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Opzione", "Significato"],
                rows: [
                    ["`--quality <file.yaml>`", "L'insieme di regole con cui valutare"],
                    ["`--fail-under <0…100>`", "Sotto questo voto è NON SUPERATO"],
                    ["`--json <file\\|->`", "Risultato leggibile da macchina; `-` scrive sullo standard output"],
                    ["`--record-history`", "Aggiunge una riga a `sales-standard.history.jsonl`"],
                    ["`--now <AAAA-MM-GG>`", "Fissa la data di riferimento della *Tempestività*"],
                    ["`--recipe <file.json>`", "Pulire **in memoria** prima di valutare, senza scrivere file"],
                ]
            ),
            .table(
                headers: ["Codice d'uscita", "Significato"],
                rows: [["`0`", "Superato"], ["`1`", "Non superato"], ["`2`", "Errore d'esecuzione"]]
            ),
            .heading("Perché la CI dovrebbe passare `--now`"),
            .paragraph("""
                Senza, la *Tempestività* confronta i dati con il momento dell'esecuzione — così lo stesso file \
                perde punti col passare dei giorni, e una mattina la catena diventa rossa senza che nessuno \
                abbia cambiato nulla.
                """),
            .heading("Tracciare la deriva"),
            .paragraph("""
                Con `--record-history`, ogni esecuzione aggiunge una riga a un file di cronologia JSONL. La \
                volta dopo, le soglie del blocco `drift:` confrontano con l'esecuzione più recente e avvertono \
                quando il calo è troppo forte.
                """),
            .note("""
                Ogni soglia di deriva è **disattiva di serie**, tranne `warn_on_new_failure`. Un avviso attivo \
                di fabbrica con un numero scelto dall'applicazione scatterebbe già alla seconda esecuzione di \
                chiunque — e ciò che grida «al lupo» il primo giorno viene ignorato il terzo.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Estrazione

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Estrazione dei dati — l'intero flusso",
        summary: "Anomalie, correlazione, grappoli, previsione, regole di associazione — e come leggerle.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Il flusso di estrazione, dall'inizio alla fine",
        summary: "Sei strumenti, l'ordine in cui usarli, e una regola: senza misura non c'è conclusione.",
        keywords: ["estrazione", "analisi", "flusso", "statistica"],
        blocks: [
            .warning("""
                **Prima pulire, poi estrarre.** Una colonna di date non normalizzata produce previsioni \
                sbagliate; una colonna numerica che mescola separatori di migliaia europei produce anomali \
                fantasma. Ogni strumento qui sotto dà per scontato che la tabella sia pulita.
                """),
            .heading("L'ordine da seguire"),
            .steps([
                "**Trovare anomalie** — risponde a *«c'è qualche riga strana?»*. Il più economico e spesso utile subito.",
                "**Matrice di correlazione** — risponde a *«quale colonna si muove con quale?»*. Guida tutto ciò che viene dopo.",
                "**Grappoli** — risponde a *«quanti gruppi naturali ci sono qui dentro?»*.",
                "**Previsione** — solo con una colonna di tempo e almeno **due cicli completi**.",
                "**Regole di associazione** — solo per dati a forma di carrello: una transazione per riga, o due colonne con identificativo di transazione e articolo.",
                "**Estrazione per gruppo** — riesegue le prime tre **in modo indipendente dentro ogni gruppo**. Questo passo ribalta spesso la conclusione tratta dalla tabella aggregata.",
            ]),
            .heading("Tre regole per l'intera famiglia"),
            .bullets([
                "**Ogni risultato porta un blocco «Metodo»**: algoritmo, parametri, seme, formula. Non c'è modo di spegnerlo — una tabella di tre numeri che non dice da dove vengono non serve a decidere.",
                "**Senza misura non c'è conclusione.** Campione troppo piccolo, varianza nulla, matrice singolare — GEditor rifiuta e dice perché, invece di restituire un numero che sembra soltanto giusto.",
                "**Risultati deterministici.** Gli stessi dati danno lo stesso risultato; dove serve casualità, il seme è registrato nell'output.",
            ]),
            .heading("Dal risultato di nuovo ai dati"),
            .paragraph("""
                Ogni pannello **contrassegna di nuovo nei dati sorgente**: fate clic su una riga anomala, su \
                una cella di correlazione o su una regola di associazione e le righe interessate vengono \
                contrassegnate nella tabella. È così che si passa da *«c'è qualcosa di strano»* a *«strano \
                esattamente in queste righe»*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Trovare le righe anomale",
        summary: "Quattro misure, tre livelli di gravità e una spiegazione del perché una riga è strana.",
        keywords: ["anomalo", "anomalia", "z-score", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Misura", "Quando usarla"],
                rows: [
                    ["z-score", "La colonna segue più o meno una normale"],
                    ["IQR", "La colonna è asimmetrica con coda lunga — la scelta sicura di serie"],
                    ["MAD", "La colonna contiene già molti anomali e serve una misura robusta"],
                    ["Mahalanobis", "**Più colonne insieme** — prende le righe strane nella combinazione, non in una singola colonna"],
                ]
            ),
            .paragraph("""
                I risultati sono colorati per **tre livelli di gravità** invece che con un colore unico — \
                altrimenti una riga leggermente insolita non si distinguerebbe da una follemente insolita.
                """),
            .heading("Spiegare il perché"),
            .paragraph("""
                Per la misura multicolonna GEditor scompone il contributo di ogni colonna e produce una frase \
                come *«anomala soprattutto per la combinazione ricavo (50 %) × quantità (50 %)»*.
                """),
            .note("""
                Quella percentuale riguarda la *parte spiegabile*, non la *distanza*. Il blocco Metodo lo dice \
                proprio sotto la tabella.
                """),
            .warning("""
                Una colonna il cui IQR o MAD sia zero fa **rifiutare l'esecuzione** della misura, invece di \
                dividere per qualcosa di minuscolo e produrre un punteggio enorme. Nel caso multicolonna, se \
                la matrice di covarianza è singolare, GEditor **dice quale colonna togliere** invece di usare \
                una pseudo-inversa per «farlo funzionare».
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Matrice di correlazione",
        summary: "Pearson e Spearman per ogni coppia, con diagramma a dispersione al clic.",
        keywords: ["correlazione", "pearson", "spearman", "mappa di calore", "dispersione"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Coefficiente", "Che cosa misura"],
                rows: [
                    ["Pearson", "Una relazione **lineare**"],
                    ["Spearman", "**Qualsiasi** relazione **monotona**, anche curva — calcolata sui ranghi"],
                ]
            ),
            .paragraph("""
                Fate clic su una cella della mappa di calore per vedere il diagramma a dispersione di quella \
                coppia, con retta di regressione e R².
                """),
            .heading("Quattro dettagli che cambiano la lettura"),
            .bullets([
                "**I pari merito usano ranghi medi**, così riordinare la tabella non cambia il coefficiente di Spearman.",
                "**Le celle vuote sono trattate a coppie**, e l'`n` di ogni cella è lì nella tabella — `0,93` su 6 righe non significa ciò che `0,93` su 6000 righe significa.",
                "**Una colonna costante restituisce vuoto**, non 0. Zero significa *misurato, nessuna relazione trovata*.",
                "**La scala di colore è blu↔arancio**, non rosso-verde: l'8 % degli uomini vede una scala rosso-verde come una massa grigia, il che fa sembrare uguali `+0,9` e `−0,9`.",
            ]),
            .warning("""
                **Correlazione non implica causalità.** Quella frase è disegnata **dentro il grafico stesso**, \
                così viaggia con l'immagine quando la esportate.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Raggruppamento",
        summary: "k-medie e DBSCAN, due modi di scegliere k — e un avvertimento sulla scalatura.",
        keywords: ["grappolo", "cluster", "kmeans", "dbscan", "silhouette", "gomito"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritmo", "Quando usarlo"],
                rows: [
                    ["k-medie", "Conoscete (o volete provare) il numero di grappoli; sono a forma di macchia"],
                    ["DBSCAN", "Non conoscete il numero; i grappoli hanno forme arbitrarie; volete separare il rumore"],
                ]
            ),
            .heading("La scalatura è attiva di serie — e perché"),
            .paragraph("""
                Una colonna `ricavo` (in milioni) accanto a una colonna `quantità` (in unità): la distanza fra \
                due righe è decisa quasi del tutto dalla maggiore. Questo non è «subottimale» — è **rispondere \
                a un'altra domanda**. La scalatura in vigore è registrata nel risultato.
                """),
            .heading("Scegliere il numero di grappoli"),
            .bullets([
                "**Silhouette** — più alto è il punteggio, meglio separati sono i grappoli. Su una tabella grande **campiona** (a intervalli regolari, non le prime 2000 righe), e il risultato si dichiara una stima.",
                "**Gomito** — disegna la somma dei quadrati entro il grappolo rispetto a k. È un **modo di leggere un grafico**, non un'ottimizzazione: quella quantità cala sempre al crescere di k, quindi statisticamente non esiste un «k ottimo».",
            ]),
            .note("""
                Per DBSCAN il grafico delle **k-distanze** aiuta a scegliere un raggio: il ginocchio della \
                curva è di solito un valore di partenza sensato.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Previsione di serie temporali",
        summary: "Scomposizione di tendenza e stagionalità, Holt-Winters, e un riferimento che gira sempre accanto.",
        keywords: ["previsione", "serie temporale", "stagionalità", "holt-winters", "tendenza"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Scegliete una colonna di tempo e una di valori. GEditor scompone la serie in **tendenza · \
                stagionalità · residuo** e poi prevede con Holt-Winters (additivo o moltiplicativo), con \
                intervalli all'80 % e al 95 %.
                """),
            .heading("Il riferimento gira sempre, e dice apertamente chi ha vinto"),
            .paragraph("""
                Accanto al modello GEditor esegue due metodi ingenui: *prendere il periodo precedente* e \
                *prendere lo stesso periodo della stagione scorsa*. Se il modello **perde** contro un \
                riferimento, quella frase compare sulla **prima riga, in un altro colore** — e non sotto una \
                tabella di numeri.
                """),
            .paragraph("""
                La ragione: gli strumenti di previsione tendono a presentare il modello come un fatto, e \
                l'utente non ha modo di sapere che «prendere semplicemente il numero del mese scorso» sarebbe \
                stato più esatto.
                """),
            .heading("Tre punti in cui GEditor rifiuta, o si dichiara"),
            .bullets([
                "**Senza due cicli completi torna al metodo ingenuo.** Adattare la stagionalità al rumore di un solo ciclo e ripeterla nel futuro produce una previsione molto convincente e del tutto inventata.",
                "**Se il MAPE incontra uno zero lo dice**, e se più del 25 % dei periodi è zero trattiene la metrica — saltarli in silenzio produce un numero calcolato su un sottoinsieme sistematicamente distorto.",
                "**L'intervallo di confidenza si dichiara approssimato**, e avverte che si allarga troppo lentamente su orizzonti lunghi.",
            ]),
            .note("""
                Il periodo stagionale è rilevato sulla **differenza prima**, non sulla serie grezza: una \
                tendenza rende tutti i ritardi molto correlati e affoga il picco stagionale.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Regole di associazione",
        summary: "Compra A, spesso compra B — e perché la tabella è ordinata per lift e non per confidenza.",
        keywords: ["apriori", "regole di associazione", "carrello", "lift", "supporto"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Sono accettate due forme di dati:"),
            .bullets([
                "**Un carrello per riga** — una colonna con un elenco di articoli.",
                "**Due colonne** — identificativo di transazione e articolo, un articolo per riga.",
            ]),
            .table(
                headers: ["Metrica", "Significato"],
                rows: [
                    ["supporto", "Quota di carrelli che contengono entrambi i lati"],
                    ["confidenza", "Dei carrelli con il lato sinistro, quale quota ha il destro"],
                    ["**lift**", "La confidenza divisa per il tasso di base del lato destro"],
                    ["leverage", "La distanza da ciò che prevederebbe l'indipendenza"],
                ]
            ),
            .heading("Ordinato per lift, non per confidenza"),
            .paragraph("""
                Se il lato destro compare comunque nel 95 % dei carrelli, allora **ogni** regola che porta a \
                esso ha circa il 95 % di confidenza — senza dire assolutamente nulla. Ordinare per confidenza \
                mette in cima proprio le regole più vuote di senso.
                """),
            .warning("""
                `lift < 1` è **segnalato nella riga stessa**: l'80 % di confidenza verso qualcosa con un tasso \
                di base del 95 % significa una relazione **inversa** — un numero giusto che porta a una \
                conclusione sbagliata.
                """),
            .bullets([
                "Comprare due confezioni di latte resta **una** transazione con latte: i doppioni dentro un carrello vengono scartati, altrimenti il supporto si gonfia con la quantità.",
                "Mettere la soglia di supporto troppo bassa fa esplodere in modo combinatorio l'insieme dei candidati; raggiunto il tetto, GEditor **si ferma e dichiara la tabella incompleta**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Estrarre per gruppo",
        summary: "Rieseguire l'analisi in modo indipendente per gruppo — il passo che più spesso ribalta una conclusione.",
        keywords: ["per gruppo", "simpson", "filiali", "confrontare gruppi"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Scegliete una colonna di testo come chiave di raggruppamento. Ogni gruppo riceve anomalie, \
                previsione e correlazione eseguite **in modo del tutto indipendente**, poi ordinate secondo il \
                criterio che scegliete.
                """),
            .heading("Perché i gruppi vanno separati e non aggregati"),
            .paragraph("""
                Due filiali, una attorno a 10 e una attorno a 100. Una barriera di anomali calcolata sulla \
                tabella **aggregata** cade attorno a ±135 — e fallisce **in entrambe le direzioni**:
                """),
            .bullets([
                "**Falsi negativi**: un valore di 20, palesemente anomalo per la filiale piccola, sta ben dentro la barriera comune. Più gruppi ci sono, più diventa cieca.",
                "**Falsi positivi**: a un gruppo molto disperso la barriera comune taglia la coda normale, e una folla di righe comuni viene segnalata.",
            ]),
            .heading("La colonna «divergenza di correlazione» prende il paradosso di Simpson"),
            .paragraph("""
                Tre gruppi in cui **ogni** gruppo correla le sue due colonne a `−1`, eppure aggregati correlano \
                a `> 0,9`. Chi legge solo la tabella aggregata conclude **esattamente il contrario**. Questa \
                colonna punta proprio a quei casi.
                """),
            .note("""
                Il pannello offre solo **colonne di testo** come chiave di raggruppamento e si ferma a 1000 \
                gruppi con un avviso — per evitare che si scelga una colonna di numeri d'ordine e ogni riga \
                diventi un gruppo a sé.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Estrazione dal testo",
        summary: "n-grammi e TF-IDF su una colonna di testo — trovare le espressioni caratteristiche.",
        keywords: ["estrazione dal testo", "n-gramma", "tf-idf", "parole chiave", "espressioni"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Gira su una colonna di testo — descrizioni di prodotto, opinioni dei clienti, campi di note.
                """),
            .bullets([
                "**n-grammi** — le espressioni di 1, 2 e 3 parole più frequenti.",
                "**TF-IDF** — parole **caratteristiche** di ogni gruppo di documenti, cioè frequenti qui e rare altrove.",
            ]),
            .paragraph("""
                La differenza: gli n-grammi vi dicono *«che cosa i clienti nominano di continuo»*, il TF-IDF vi \
                dice *«in che cosa questo gruppo differisce dagli altri»*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
