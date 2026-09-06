import Foundation

/// Contenuto della guida in italiano — parte 1: per cominciare e modifica.
///
/// **Gli `id` degli argomenti non si traducono MAI.** Sono ciò a cui punta `.seeAlso`, ciò che il menu
/// apre, e ciò che permette alla finestra della guida di cambiare lingua **senza riportare il lettore
/// all'indice**. Cambiare un id spezza tutti i collegamenti, in tutti i libri insieme.
///
/// I titoli di menu in `commands:` restano in vietnamita: devono corrispondere parola per parola alle
/// voci reali del menu, che `HelpCoverage` verifica proprio su quella stringa.
enum HelpIT {}

extension HelpIT {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Per cominciare",
        summary: "Che cosa fa GEditor e dove spendere i primi cinque minuti.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Che cos'è GEditor",
        summary: "Un editor di testo e dati su scala di gigabyte per macOS che parla vietnamita.",
        keywords: ["introduzione", "benvenuto", "panoramica", "informazioni"],
        blocks: [
            .paragraph("""
                GEditor apre un **file da 1 GB senza caricare 1 GB in memoria**. Legge attraverso una \
                finestra scorrevole su un file mappato in memoria, così un registro da 200 milioni di \
                righe o un CSV da un milione di righe si apre in circa un secondo e scorre senza scatti.
                """),
            .paragraph("""
                Oltre alla modifica, è un **banco di lavoro per i dati**: vedere un CSV come tabella, \
                pulirlo, valutarne la qualità, interrogarlo con SQL, cercarvi anomalie e tendenze e poi \
                generare un rapporto. E legge le codifiche vietnamite antiche che la maggior parte degli \
                strumenti di oggi ha dimenticato.
                """),
            .heading("Sei cose da provare per prime"),
            .table(
                headers: ["Compito", "Dove andare"],
                rows: [
                    ["Aprire un file grande senza attendere", "Trascinatelo nella finestra — vedi «Aprire file grandi»"],
                    ["Modificare molti punti insieme", "`⌘D` aggiunge l'occorrenza successiva, poi si scrive una volta sola"],
                    ["Cercare con un'espressione regolare", "`⌘F`, attivate Regex — il motore è PCRE2 con JIT"],
                    ["Vedere un CSV come tabella", "`⌥⌘T` — un milione di righe scorre comunque senza scatti"],
                    ["Ripulire una tabella disordinata", "`⇧⌘L` banco di pulizia — anteprima prima di applicare"],
                    ["Aprire un file vietnamita che appare illeggibile", "Fate clic sulla codifica nella barra di stato"],
                ]
            ),
            .note("""
                Venite da Notepad++? C'è una pagina che confronta le due mappe di tasti, perché alcuni \
                tasti **si scambiano di posto** su macOS invece di limitarsi a cambiare `Ctrl` in `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "I vostri primi cinque minuti",
        summary: "Dodici scorciatoie coprono gran parte del lavoro quotidiano.",
        keywords: ["scorciatoia", "tasti", "inizio", "basi"],
        blocks: [
            .paragraph("""
                Non serve imparare tutto. I dodici tasti qui sotto coprono gran parte del lavoro \
                quotidiano; il resto lo cercherete quando servirà.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Aprire un file"),
                HelpShortcut("⇧⌘O", "Aprire un'intera cartella come spazio di lavoro"),
                HelpShortcut("⌘T", "Nuova scheda"),
                HelpShortcut("⌘S", "Salvare"),
                HelpShortcut("⌘F", "Cercare"),
                HelpShortcut("⌥⌘F", "Cercare e sostituire"),
                HelpShortcut("⇧⌘F", "Cercare in una cartella"),
                HelpShortcut("⌘D", "Aggiungere l'occorrenza successiva alla selezione"),
                HelpShortcut("⌘L", "Andare alla riga"),
                HelpShortcut("⌘/", "Commentare la riga con la sintassi del linguaggio stesso"),
                HelpShortcut("⌥⌘T", "Passare da tabella a testo (file CSV)"),
                HelpShortcut("⌘?", "Riaprire questa finestra della guida"),
            ]),
            .heading("Tre cose che sorprendono i nuovi arrivati"),
            .bullets([
                "**Un'operazione di massa è UN passo di annullamento**, anche se tocca un milione di righe. Ordinato male? Un `⌘Z` e sparisce.",
                "**La sessione si ripristina da sola.** Uscite e riaprite: le schede tornano al loro posto, comprese quelle non salvate. Niente da premere.",
                "**Scrivere senza accenti trova comunque le parole accentate** in ogni campo di ricerca e filtro — scrivete `hue` e ottenete `Huế`, `da nang` e ottenete `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Che cosa volete fare?",
        summary: "Una tabella che va dai compiti reali al capitolo che li tratta.",
        keywords: ["indice", "cercare", "come fare"],
        blocks: [
            .paragraph("""
                L'indice a sinistra è ordinato per **funzione**. Questa tabella è ordinata per \
                **compito**, perché i due ordini non coincidono.
                """),
            .table(
                headers: ["Devo…", "Vedi"],
                rows: [
                    ["Modificare lo stesso punto su centinaia di righe", "Cursori multipli · Selezione a blocco"],
                    ["Riformattare in massa con una regex", "Cerca e sostituisci · Espressioni regolari"],
                    ["Ripetere una sequenza di azioni", "Macro"],
                    ["Aprire un CSV che mi hanno mandato", "La tabella CSV"],
                    ["Ripulire una tabella disordinata: date miste, numeri come testo", "Il flusso di pulizia dei dati"],
                    ["Giudicare se una tabella è affidabile", "Valutazione della qualità dei dati"],
                    ["Trovare anomalie, tendenze, gruppi", "Il flusso di estrazione dei dati"],
                    ["Porre domande in SQL", "Interrogare un CSV con SQL"],
                    ["Pubblicare un rapporto i cui numeri si aggiornino", "Rapporti `.greport.md`"],
                    ["Disegnare uno schema dentro un documento", "Mermaid"],
                    ["Aprire un file vietnamita illeggibile", "Codifiche vietnamite"],
                    ["Automatizzare dalla shell o da AppleScript", "Automazione"],
                    ["Colorare un formato inventato dalla mia azienda", "Linguaggi definiti dall'utente"],
                ]
            ),
            .note("""
                Non è elencato? Il campo di ricerca in alto a sinistra guarda dentro il **testo e gli \
                esempi di codice**, così scrivere una chiave di configurazione come `fail_under` porta \
                alla pagina giusta.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Aprire file grandi",
        summary: "Perché 1 GB si apre davvero, e dove GEditor rifiuta di proposito invece di indovinare.",
        keywords: ["file grande", "gigabyte", "registro", "mmap", "lento", "prestazioni"],
        blocks: [
            .paragraph("""
                Il file è **mappato in memoria** e letto attraverso una finestra scorrevole; la parte che \
                state modificando vive in una piece table. In pratica: il tempo di apertura non dipende \
                quasi dalla dimensione del file, e nemmeno la memoria occupata.
                """),
            .heading("Dove rifiuta di proposito"),
            .paragraph("""
                Alcuni calcoli dovrebbero leggere l'intero file in una sola stringa — esattamente ciò che \
                questa architettura evita. Lì GEditor **dice che non lo farà** invece di strisciare in \
                silenzio o indovinare:
                """),
            .table(
                headers: ["Operazione", "Soglia", "Oltre"],
                rows: [
                    ["Corrispondenza delle parentesi", "1 MB", "Rifiuta e lo dice — evidenziare la coppia sbagliata è peggio di nessuna"],
                    ["Colonna visiva nella barra di stato", "200 KB", "Torna a contare byte e lo segna con `~` perché il significato resti visibile"],
                    ["Anteprima Markdown", "4 MB", "Rifiuta e spiega"],
                ]
            ),
            .warning("""
                Un numero che sembra identico ma significa altro è il tipo peggiore di errore. Per questo \
                una colonna oltre la soglia si legge `~1234` e non `1234`.
                """),
            .heading("Trucchi per i file di registro"),
            .bullets([
                "`File ▸ Segui file (tail -f)` porta dentro ciò che viene scritto in coda. Il documento diventa **in sola lettura** durante il seguito — scrivere mentre arriva testo nuovo sono due scrittori che si contendono un documento, e a perdere è sempre ciò che avete appena battuto.",
                "Le righe di registro sono **colorate per gravità** e si possono filtrare per livello.",
                "La **mappa del documento** (`⌥⌘M`) descrive l'intero file, non solo la parte a schermo.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "Versione App Store e download diretto",
        summary: "Tre funzioni che ha solo la versione diretta, e perché.",
        keywords: ["app store", "sandbox", "download", "cli", "estensione", "differenza"],
        blocks: [
            .paragraph("""
                GEditor esce in due versioni. Provengono dallo **stesso codice sorgente** e l'applicazione \
                riconosce all'avvio quale sia. La differenza sta in ciò che l'App Sandbox permette.
                """),
            .table(
                headers: ["Funzione", "App Store", "Download diretto"],
                rows: [
                    ["Tutta la modifica, CSV, pulizia, estrazione, rapporti", "Sì", "Sì"],
                    ["Lo strumento a riga di comando `geditor`", "No", "Sì"],
                    ["Filtrare il testo con un comando esterno", "No", "Sì"],
                    ["Estensioni native (processo separato)", "No", "Sì"],
                    ["Aggiornamento automatico", "Tramite l'App Store", "Nell'applicazione"],
                ]
            ),
            .paragraph("""
                Ogni «No» qui sopra nasce dalla stessa regola: la sandbox **vieta di eseguire codice fuori \
                dall'applicazione**. È il prezzo della distribuzione sull'App Store, non una svista.
                """),
            .note("""
                Nella versione App Store questi comandi **restano nel menu** e spiegano perché non sono \
                disponibili, invece di sparire. Una voce di menu mancante diventa una richiesta \
                all'assistenza; una risposta sul posto no.
                """),
            .heading("L'accesso ai file nella versione App Store"),
            .paragraph("""
                La versione in sandbox tocca solo i file che avete aperto o trascinato voi. GEditor \
                conserva un **segnalibro con ambito di sicurezza** per ogni scheda e per la cartella dello \
                spazio di lavoro, così la vostra sessione si riapre dopo l'uscita senza richiedere di \
                nuovo il permesso.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Modifica

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Modifica",
        summary: "Modificare molti punti insieme, lavorare sulle righe e le regole nascoste da conoscere per prime.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Cursori multipli",
        summary: "Selezionare ogni punto che corrisponde, scrivere una volta, cambiarli tutti.",
        keywords: ["multicursore", "cmd+d", "selezione multipla"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Questo sostituisce la maggior parte dei momenti in cui stavate per scrivere un'espressione \
                regolare. Selezionate una parola, premete `⌘D` qualche volta per raccogliere le occorrenze \
                successive, poi scrivete — tutti i punti cambiano insieme.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Aggiungere l'occorrenza successiva alla selezione"),
                HelpShortcut("⌘ + clic", "Mettere un altro cursore dove fate clic"),
                HelpShortcut("Esc", "Abbandonarli tutti, tornare a un cursore"),
                HelpShortcut("⌥ + trascinamento", "Selezione a blocco (un altro modo per avere molti cursori)"),
            ]),
            .heading("Regole da conoscere"),
            .bullets([
                "Scrivere, cancellare e incollare su molti cursori è **un** passo di annullamento, non uno per cursore.",
                "I cursori sopravvivono al movimento con le frecce — l'intero gruppo si sposta insieme.",
                "`⌘D` salta i punti già nella selezione, così premerlo troppe volte non impila mai due cursori sullo stesso punto.",
            ]),
            .note("""
                `⌘D` su una parola dentro una stringa lunga prima era lento. Il rilevamento dei confini di \
                parola ora legge a lotti — circa **42× più veloce** su una stringa da 1 MB, il che lo rende \
                utilizzabile su file di dati e non solo su codice sorgente.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Selezione a blocco di colonne",
        summary: "Selezionare un rettangolo su molte righe — con il mouse o dalla tastiera.",
        keywords: ["modo colonna", "blocco", "alt trascinamento", "rettangolo", "tastiera", "frecce"],
        blocks: [
            .paragraph("""
                Tenete `⌥` e trascinate per selezionare un **blocco rettangolare**. Scrivere, cancellare e \
                incollare seguono il blocco. Incollare un blocco su un solo cursore conserva il suo \
                rettangolo.
                """),
            .shortcuts([
                HelpShortcut("⌥ + trascinamento", "Selezionare un blocco"),
                HelpShortcut("⌥⌘← →", "Allargare il blocco di una colonna a sinistra/destra"),
                HelpShortcut("⌥⌘↑ ↓", "Estendere il blocco di una riga in su/in giù"),
            ]),
            .paragraph("""
                La via da tastiera non è un ripiego rispetto al mouse: selezionare un blocco di 40 righe \
                trascinando obbliga a trascinare attraverso uno scorrimento, mentre `⌥⌘` + frecce mantiene \
                la precisione colonna per colonna. Premere **qualsiasi altro** tasto (o scrivere) chiude il \
                blocco che stavate estendendo.
                """),
            .heading("Qui le colonne sono colonne VISIVE"),
            .paragraph("""
                Una tabulazione si espande fino alla tacca successiva secondo la vostra larghezza di \
                tabulazione, invece di contare come una colonna. È questo che fa sì che le righe rientrate \
                con tabulazioni e con spazi **si allineino come appaiono a schermo**.
                """),
            .paragraph("Il testo multibyte resta una colonna: `Nguyễn` occupa sei colonne, non nove."),
            .table(
                headers: ["Situazione", "Che cosa fa GEditor"],
                rows: [
                    ["La colonna di destinazione cade a metà di una tabulazione", "Si aggancia al bordo più vicino; a parità, a sinistra"],
                    ["Una riga è più corta della colonna iniziale", "Quella riga contribuisce con una selezione vuota, e accetta comunque il testo scritto"],
                    ["Incollare un blocco su un solo cursore", "Conserva il rettangolo e inserisce nelle righe sottostanti"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Editor di colonne",
        summary: "Inserire testo, una serie di numeri o di date in ogni riga di un blocco.",
        keywords: ["editor di colonne", "numerazione", "sequenza", "serie"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Selezionate un blocco di colonne e aprite `Modifica ▸ Editor di colonne…` (`⌥⌘C`). La \
                finestra offre un'**anteprima** prima di applicare qualsiasi cosa.
                """),
            .table(
                headers: ["Modo", "Parametri", "Quando"],
                rows: [
                    ["Testo", "Una stringa fissa", "Aggiungere lo stesso prefisso/suffisso a ogni riga"],
                    ["Serie di numeri", "Inizio · passo · base 2·8·10·16 · zeri iniziali", "Numerare righe, generare codici"],
                    ["Serie di date", "Prima data · passo in giorni", "Produrre una colonna di date consecutive"],
                ]
            ),
            .code(language: "text", caption: "Numerazione con zeri iniziali, inizio 1, passo 1",
                  source: """
                    Prima:            Dopo (serie di numeri, 3 cifre):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Un passo **negativo** è valido — contare all'indietro funziona.",
                "Inserire in 5000 righe resta **un** passo di annullamento.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Operazioni sulle righe",
        summary: "Ordinare, togliere i doppioni, spostare, unire, dividere, duplicare, cancellare.",
        keywords: ["ordinare", "duplicare", "unire", "dividere", "spostare riga"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Con una selezione il comando agisce sulla selezione; senza, agisce sull'**intero \
                documento**. Ogni comando qui è un solo passo di annullamento.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Duplicare la riga"),
                HelpShortcut("⌘K", "Cancellare la riga"),
                HelpShortcut("⌥↑ / ⌥↓", "Spostare la riga in su / in giù"),
            ]),
            .heading("Tre tipi di ordinamento, e quale scegliere"),
            .table(
                headers: ["Tipo", "`file2` contro `file10`", "Per"],
                rows: [
                    ["A→Z / Z→A", "`file10` viene prima di `file2`", "Elenchi semplici di parole"],
                    ["Naturale", "`file2` viene prima di `file10`", "Nomi di file, identificatori, versioni"],
                ]
            ),
            .paragraph("""
                L'ordinamento **naturale** legge le sequenze di cifre come numeri. È quasi sempre ciò che \
                volete quando l'elenco è numerato.
                """),
            .heading("Togliere i doppioni"),
            .bullets([
                "**Intero documento** — scarta ogni riga già apparsa prima e tiene la prima.",
                "**Solo adiacenti** — fonde le righe vicine identiche, come `uniq` di Unix.",
            ]),
            .heading("Unire e dividere"),
            .bullets([
                "**Unisci righe** fonde le righe selezionate in una sola.",
                "**Dividi per lunghezza** taglia le righe lunghe a un dato numero di caratteri.",
                "**Dividi per carattere** taglia a ogni occorrenza di un carattere che scrivete — per esempio per spezzare una riga CSV nelle sue celle.",
            ]),
            .note("""
                Duplicare l'**ultima riga** di un file aggiunge l'a capo mancante; cancellare fino alla \
                fine del documento inghiotte anche l'a capo della riga precedente. Entrambi differiscono \
                dall'implementazione ingenua, ed entrambi esistono perché il file non finisca con una riga \
                vuota di troppo — né senza quella che serviva.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Spazi e rientri",
        summary: "Ripulire gli spazi vaganti, convertire tabulazione ↔ spazio, e un interruttore su cui riflettere.",
        keywords: ["spazi", "tabulazione", "rientro", "righe vuote"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Comando", "Che cosa fa"],
                rows: [
                    ["Rimuovere le righe vuote", "Scarta ogni riga senza nulla sopra"],
                    ["Comprimere le righe vuote consecutive", "Più righe vuote di fila diventano una"],
                    ["Tagliare gli spazi a fine riga", "Toglie spazi e tabulazioni vaganti alla fine di ogni riga"],
                    ["Tabulazione → Spazio", "Converte le tabulazioni in spazi alla larghezza corrente"],
                    ["Spazio → Tabulazione", "Il verso opposto"],
                ]
            ),
            .heading("Rientro per linguaggio"),
            .paragraph("""
                Fate clic su `Tab: 4` nella barra di stato. La parte alta del menu lo cambia per l'**intera \
                applicazione**; quella bassa — `Solo per Go`, `Solo per Python`… — vale solo per il \
                linguaggio del file aperto e ricorda se usare tabulazioni o spazi.
                """),
            .paragraph("""
                Le persone non scelgono il rientro per gusto ma per **convenzione della comunità**: Go usa \
                tabulazioni (`gofmt` prevale su tutto il resto), Python quattro spazi secondo la PEP 8, \
                JavaScript e YAML di solito due. Un solo numero per tutti i linguaggi fa sì che ogni file \
                che toccate guadagni righe che non avete mai modificato.
                """),
            .code(language: "json", caption: "settings.json",
                  source: """
                    "languageIndent": {
                      "go":         { "width": 4, "usesTabs": true },
                      "python":     { "width": 4, "usesTabs": false },
                      "javascript": { "width": 2, "usesTabs": false }
                    }
                    """),
            .note("""
                Dichiararlo in `settings.json` funziona ugualmente — la chiave è il codice del linguaggio \
                (`go`, `python`, `javascript`…). I linguaggi assenti usano il `tabWidth` comune.
                """),
            .heading("Perché «tagliare al salvataggio» è DISATTIVATO di serie"),
            .paragraph("""
                L'interruttore `File ▸ Taglia gli spazi finali al salvataggio` modifica **righe che non \
                avete mai toccato**. Attivo di serie, una correzione di una parola nel repository altrui \
                diventa un diff di mille righe, e il revisore non trova più la modifica vera.
                """),
            .paragraph("""
                Quando è attivo, il taglio è un **passo di annullamento separato** posto prima della \
                scrittura — un annullamento riporta il documento com'era, senza perdere ciò che avete \
                appena salvato.
                """),
            .heading("Rientro automatico"),
            .bullets([
                "Una riga nuova eredita il rientro della precedente, più un livello dopo un simbolo di apertura — `{` nei linguaggi a graffe, `:` in Python e YAML.",
                "La misura è in **colonne visive**, così i file che mescolano tabulazioni e spazi restano allineati a schermo.",
                "**Non** esiste la regola «scrivere `}` rientra di nuovo la riga». Quella regola modifica una riga che avevate già finito, ed è il comportamento più criticato di tutti gli editor che ce l'hanno.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Maiuscole e convenzioni di denominazione",
        summary: "Otto conversioni, fra cui camelCase, snake_case e kebab-case.",
        keywords: ["maiuscole", "minuscole", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Si applicano alla selezione. Vivono tutte nel menu `Formato`."),
            .table(
                headers: ["Comando", "`tổng doanh thu` diventa"],
                rows: [
                    ["MAIUSCOLE", "`TỔNG DOANH THU`"],
                    ["minuscole", "`tổng doanh thu`"],
                    ["Iniziali Maiuscole", "`Tổng Doanh Thu`"],
                    ["Maiuscola di frase", "`Tổng doanh thu`"],
                    ["Invertire le maiuscole", "Ribalta ogni carattere"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Le ultime tre tolgono gli accenti vietnamiti, perché producono **identificatori di \
                codice** — dove le lettere accentate di solito non sono ammesse.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Commenti e parentesi",
        summary: "⌘/ usa il marcatore proprio di ogni linguaggio; ⌃⌘B salta alla parentesi corrispondente.",
        keywords: ["commento", "parentesi", "cmd+/", "corrispondenza"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` sceglie il marcatore di commento **in base al linguaggio del documento**: `#` per \
                Python, `//` per Rust e C, `<!-- -->` per XML e HTML.
                """),
            .heading("L'intero blocco va nello stesso verso"),
            .paragraph("""
                Se anche una sola riga del blocco è ancora senza commento, il comando commenta **tutto**. \
                Decidere riga per riga trasformerebbe un blocco commentato a metà in una scacchiera. Il \
                marcatore è inserito al rientro meno profondo del blocco, così il blocco conserva la forma.
                """),
            .heading("Saltare alla parentesi corrispondente"),
            .bullets([
                "`⌃⌘B` salta alla parentesi che fa coppia con quella sotto il cursore.",
                "Le parentesi dentro **stringhe** o **commenti** non contano — un analizzatore leggero le distingue.",
                "Oltre **1 MB**, il comando rifiuta e lo dice invece di ancorarsi a metà strada e indovinare. Evidenziare la coppia sbagliata è peggio che non evidenziarne nessuna.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Annullamento e appunti",
        summary: "Cronologia di annullamento illimitata e appunti a più posizioni.",
        keywords: ["annullare", "ripristinare", "appunti", "incollare", "cronologia"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Annullare / Ripristinare"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Tagliare / Copiare / Incollare"),
                HelpShortcut("⇧⌘V", "Cronologia degli appunti"),
            ]),
            .heading("Un'operazione di massa è UN passo"),
            .paragraph("""
                Ordinare un milione di righe, sostituire diecimila occorrenze, inserire in cinquemila righe \
                con l'editor di colonne — ciascuna si annulla con **un** `⌘Z`.
                """),
            .paragraph("""
                La cronologia di annullamento vive nel buffer di testo proprio di GEditor e non \
                nell'`UndoManager` di sistema, esattamente per questo: l'`UndoManager` conta i tasti.
                """),
            .heading("Cronologia degli appunti"),
            .paragraph("""
                `⇧⌘V` apre l'elenco di ciò che avete copiato di recente e incolla la voce che scegliete. \
                Utile quando dovete alternare due frammenti in molti punti.
                """),
        ]
    )
}
