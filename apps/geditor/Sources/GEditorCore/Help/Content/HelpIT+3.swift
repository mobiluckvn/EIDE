import Foundation

/// Contenuto della guida in italiano — parte 3: modi di vedere, vietnamita, linguaggi e formati.
extension HelpIT {

    static let views = HelpChapter(
        id: "xem",
        title: "Modi di vedere un documento",
        summary: "Barra laterale, mappa, piegatura, vista divisa, a capo automatico, invisibili, modi di colore.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Barra laterale ed elenco delle funzioni",
        summary: "L'albero dei file e l'elenco delle funzioni del file aperto, nella stessa colonna.",
        keywords: ["barra laterale", "elenco funzioni", "struttura", "albero dei file"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Mostrare / nascondere la barra laterale")]),
            .paragraph("""
                L'elenco delle funzioni è costruito sull'**albero sintattico** del linguaggio, quindi segue \
                la struttura reale invece di indovinarla dai rientri. Fate clic su una voce per saltarci.
                """),
            .note("Il campo di filtro dell'elenco **trova testo accentato scrivendo senza accenti**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Mappa del documento",
        summary: "L'intero file in una colonna stretta a destra — anche a centinaia di MB.",
        keywords: ["minimappa", "mappa", "panoramica"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Mostrare / nascondere la mappa del documento")]),
            .paragraph("""
                La mappa descrive l'**intero file**, non solo ciò che è a schermo. Trascinarvi sopra salta \
                alla regione corrispondente.
                """),
            .paragraph("""
                Le occorrenze di ricerca e le righe contrassegnate appaiono sulla mappa, così vedete se sono \
                sparse o raggruppate prima di scorrere fin lì.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Piegatura",
        summary: "Piegare funzioni, blocchi e array per struttura — o piegare l'intero file a un livello.",
        keywords: ["piegare", "code folding", "comprimere"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Piegare / dispiegare il blocco del cursore"),
                HelpShortcut("⌥⇧⌘←", "Piegare tutto"),
                HelpShortcut("⌥⌘→", "Dispiegare tutto"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Piegare l'intero file al livello 1…8"),
            ]),
            .paragraph("""
                Nei linguaggi con albero sintattico la piegatura segue la **struttura reale**. Nei file senza \
                grammatica segue i rientri.
                """),
            .paragraph("""
                `Piega al livello` si guadagna il posto su JSON e YAML profondi: piegare al livello 2 mette \
                la forma dell'intero file in una schermata.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Vista divisa",
        summary: "Due riquadri affiancati, per due file — o due punti di uno stesso file.",
        keywords: ["dividere", "riquadri", "confrontare"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Dividere in verticale"),
                HelpShortcut("⌥⌘-", "Dividere in orizzontale"),
                HelpShortcut("⌥⌘0", "Togliere la divisione"),
                HelpShortcut("⌥⌘]", "Aprire questa scheda nell'altro riquadro"),
                HelpShortcut("⌥⌘[", "Saltare nell'altro riquadro"),
            ]),
            .paragraph("""
                Ogni riquadro ha la propria barra delle schede. Aprire lo **stesso file** in entrambi va \
                benissimo — scorrono in modo indipendente, il che rende facile confrontare l'inizio e la \
                fine di un file.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "A capo automatico",
        summary: "Tre modi: disattivo, al bordo della finestra, o a una colonna fissa.",
        keywords: ["a capo", "ritorno morbido"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Modo", "Una riga lunga"],
                rows: [
                    ["Disattivo", "Scorre in orizzontale"],
                    ["Alla finestra", "Va a capo al bordo della finestra, seguendone la dimensione"],
                    ["A una colonna", "Va a capo alla colonna che fissate — 80 o 100, poniamo"],
                ]
            ),
            .paragraph("""
                L'a capo è un **modo di guardare**, non una modifica: non viene inserito alcun a capo e non \
                entra mai nella cronologia di annullamento.
                """),
            .note("La via rapida è il segmento `Ngắt: …` della barra di stato."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Corpo del testo",
        summary: "Ingrandire fra 8 e 32 pt.",
        keywords: ["zoom", "corpo", "più grande", "più piccolo"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Più grande"),
                HelpShortcut("⌘-", "Più piccolo"),
                HelpShortcut("⌃⌘0", "Tornare al corpo predefinito"),
            ]),
            .paragraph("""
                Limitato fra 8 e 32 pt. Anche questo è un **modo di guardare**: nessuna modifica, nulla nella \
                cronologia di annullamento. Il corpo predefinito vive in `Impostazioni…`.
                """),
            .note("`⌘0` **non** è il corpo predefinito — quel tasto mostra e nasconde la barra laterale."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Mostrare i caratteri invisibili",
        summary: "Un gruppo per volta, perché tutti insieme di solito è troppo.",
        keywords: ["invisibile", "spazi", "nbsp", "larghezza zero", "tabulazione"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Mostrare / nascondere tutti i caratteri invisibili")]),
            .paragraph("""
                Quattro gruppi si accendono separatamente, perché accenderli tutti insieme seppellisce il \
                contenuto sotto una foresta di puntini.
                """),
            .table(
                headers: ["Gruppo", "Che cosa prende"],
                rows: [
                    ["Spazi", "Spazi a fine riga, rientri incoerenti"],
                    ["Tabulazioni", "File che mescolano tabulazioni e spazi"],
                    ["Fine riga", "File che mescolano CRLF e LF"],
                    ["NBSP · larghezza zero · controllo", "Caratteri invisibili da Word, dal web, dai fogli di calcolo"],
                ]
            ),
            .warning("""
                L'ultimo gruppo è quello che salva le persone. Uno spazio unificatore (NBSP) incollato da una \
                pagina web sembra **esattamente** uno spazio comune, eppure fa fallire ogni confronto di \
                stringhe e ogni filtro — e non c'è modo di vederlo senza questo gruppo attivo.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "Modo CSV e modo Registro",
        summary: "Due colorazioni che sostituiscono l'evidenziazione della sintassi, per due tipi di file di dati.",
        keywords: ["modo csv", "modo registro", "evidenziazione", "colonne", "livello"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("Modo CSV"),
            .paragraph("""
                Dà a ogni colonna un colore proprio nella vista **testo**, così vedete quale cella è \
                scivolata di una colonna senza passare alla tabella.
                """),
            .heading("Modo Registro"),
            .paragraph("""
                Colora secondo la **gravità** che legge dalla riga: errori in rosso, avvisi in ambra, mentre \
                `debug` e `trace` sono attenuati — costituiscono gran parte di un registro, ed evidenziarli \
                attenua proprio ciò che state cercando.
                """),
            .paragraph("`Filtra il registro per livello…` nasconde del tutto i livelli che non servono."),
            .note("""
                Questi due colorano **al posto dell'**evidenziazione della sintassi, non sopra. Un registro \
                non ha sintassi da colorare, e due fonti di colore che scrivono sullo stesso intervallo di \
                byte non lasciano un vincitore prevedibile.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Vista binaria",
        summary: "Una tabella esadecimale per qualsiasi file — anche da 1 GB, che si apre quasi all'istante.",
        keywords: ["hex", "binario", "byte", "posizione", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Vista ▸ Vista binaria` mostra ogni byte come tabella a tre colonne: **posizione · esa · \
                testo**. Funziona con **qualsiasi** file su disco, non solo con immagini o video.
                """),
            .table(
                headers: ["Colonna", "Contenuto"],
                rows: [
                    ["Posizione", "Posizione del byte, in esadecimale"],
                    ["Esa", "16 byte per riga, separati dopo l'ottavo per contare meglio"],
                    ["Testo", "Byte ASCII stampabili; tutto il resto è un `.`"],
                ]
            ),
            .note("""
                La colonna di testo **non decodifica UTF-8**. Una lettera vietnamita occupa due o tre byte, \
                quindi mostrarla disallineerebbe la colonna di testo rispetto a quella esadecimale — e quel \
                allineamento è tutto il senso della colonna. Per leggere testo accentato usate la vista \
                normale.
                """),
            .heading("File grandi"),
            .paragraph("""
                Il file è **mappato in memoria**, quindi aprirne uno da 1 GB in vista binaria costa solo ciò \
                che guardate. Misurato nella batteria di autotest: **meno di un millisecondo**.
                """),
            .paragraph("""
                La vista mostra **una finestra da 4 MB** per volta, e la barra in alto dice in quale \
                intervallo siete. È un limite del disegnatore di tabelle del sistema, non della lettura: 1 GB \
                sono 62,5 milioni di righe, e oltre un certo punto le righe cominciano a saltare durante lo \
                scorrimento — e una tabella esadecimale che salta non serve a nulla.
                """),
            .heading("Saltare a una posizione"),
            .table(
                headers: ["Scrivete nel campo di posizione", "Significato"],
                rows: [
                    ["`1F400`", "Esadecimale — l'impostazione predefinita"],
                    ["`0x1F400`", "Lo stesso, con prefisso esplicito"],
                    ["`#128000`", "Decimale, quando avete un conteggio di byte e non una posizione esadecimale"],
                ]
            ),
            .bullets([
                "`‹` e `›` vanno alla finestra precedente / successiva.",
                "**Copia le righe selezionate** copia esattamente ciò che vedete — senza selezione copia l'intera finestra.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Anteprima Markdown",
        summary: "Mostrare Markdown come testo formattato — e dire chiaramente ciò che non mostra.",
        keywords: ["markdown", "anteprima", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("Reso con il supporto Markdown del sistema: grassetto, corsivo, codice, collegamenti, elenchi."),
            .warning("""
                **Niente tabelle e niente colore di sintassi dentro i blocchi di codice.** La finestra \
                d'anteprima lo dice in fondo. I documenti oltre **4 MB** vengono rifiutati.
                """),
            .paragraph("""
                Servono tabelle e grafici in un documento pubblicabile? È per questo che esistono i rapporti \
                `.greport.md`, non questa anteprima.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Due modi: Vista e Codice",
        summary: "Un tasto alterna fra la forma resa e il sorgente modificabile, per ogni tipo di file.",
        keywords: ["vista", "codice", "modo", "sorgente", "reso", "anteprima"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Alternare fra Vista e Codice")]),
            .paragraph("""
                Il controllo sta nella **barra subito sotto le schede** — nello stesso posto per ogni tipo di \
                file: un selettore `View | Code` e poi il nome del modo Vista di quel file («Pagine del \
                documento», «Albero chiave-valore», «Diagramma»…). Un file con un solo modo attenua il \
                selettore e la barra dice perché. Sul bordo destro stanno i pulsanti propri di ogni tipo: \
                `.xlsx` ha **Tabella** (modificabile, riscritta direttamente), `.pptx` ha **Struttura**.
                """),
            .note("""
                **Word e PowerPoint si comportano come un lettore di documenti.** Il loro modo Vista \
                costruisce pagine vere — caratteri, corpi e colori corretti, con immagini, tabelle, \
                intestazioni e piè di pagina con i numeri. Una pagina è **larga esattamente quanto la \
                cornice** e si ingrandisce. Excel è un'eccezione voluta: la sua Vista è un **foglio di \
                calcolo modificabile**, perché un foglio di calcolo non ha un formato di carta finché non \
                viene stampato.
                """),
            .note("""
                In cambio le pagine sono **in sola lettura** e mostrano la **copia su disco**: modificate in \
                Codice senza salvare e le pagine mostrano la versione vecchia — la barra lo dice, con un \
                pulsante `Salva e ridisegna`.
                """),
            .heading("Definizioni"),
            .bullets([
                "**Codice** è il **sorgente modificabile**. In un file di testo è il testo stesso. In un file binario — PDF, immagine, audio, video — non c'è sorgente testuale, quindi Codice sono i **byte**, mostrati in esadecimale.",
                "**Vista** è ciò che viene **reso** dal Codice. Può essere più bello, più corto o eseguibile — ma è sempre una conseguenza, mai l'originale.",
            ]),
            .paragraph("""
                Dire di un PDF che *«questo tipo non ha Codice»* sarebbe comodo, ma falso: i byte sono \
                davvero il suo sorgente.
                """),
            .heading("Dove si modifica"),
            .paragraph("""
                La modifica avviene nel **Codice**. Ci sono esattamente **due eccezioni**, entrambe perché \
                modificare in Vista è molto più naturale: le **celle della tabella CSV** e i **campi modulo \
                del PDF**. Entrambe scrivono direttamente nel sorgente, così non compare una seconda copia \
                con cui litigare.
                """),
            .heading("Per tipo di file"),
            .table(
                headers: ["Tipo di file", "Vista", "Codice", "Modificare in"],
                rows: [
                    ["CSV · TSV", "Tabella", "Testo grezzo", "**Entrambi**"],
                    ["Excel `.xlsx`", "Tabella del foglio aperto", "Quel foglio come CSV", "**Entrambi**"],
                    ["PDF", "Pagine rese", "Binario", "**Entrambi** — annotazioni, campi, pagine"],
                    ["Markdown `.md`", "Testo reso", "Sorgente Markdown", "Codice"],
                    ["Rapporto `.greport.md`", "Rapporto con interrogazioni eseguite e grafici disegnati", "Sorgente", "Codice"],
                    ["JSON", "Albero chiave-valore, piegabile", "Sorgente JSON", "Codice"],
                    ["XML · HTML", "Albero di tag, piegabile", "Sorgente XML", "Codice"],
                    ["YAML", "Albero chiave-valore per rientro", "Sorgente YAML", "Codice"],
                    ["Diagrammi `.mmd` · `.dot`", "Il diagramma disegnato, che occupa la scheda", "Sorgente mermaid o DOT", "Codice"],
                    ["Word `.docx`", "Pagine di documento rese", "Markdown estratto", "Codice"],
                    ["PowerPoint `.pptx`", "Pagine di diapositive rese", "Struttura Markdown", "Codice"],
                    ["File di registro", "Colorati per livello, filtrabili", "Testo grezzo", "Codice"],
                    ["Immagini", "L'immagine (le animate si riproducono)", "Binario", "Sola lettura"],
                    ["Audio · video", "Un lettore", "Binario", "Sola lettura"],
                    ["Archivi", "Elenco delle voci", "Binario", "Sola lettura"],
                    ["Codice sorgente, testo semplice", "— nessuna", "Il testo stesso", "Codice"],
                ]
            ),
            .note("""
                Il codice sorgente **non ha Vista**, ed è normale più che una mancanza: un file Swift non ha \
                forma resa che valga la pena guardare.
                """),
            .heading("Il lettore di pagine per Word e PowerPoint"),
            .paragraph("""
                Le pagine si impilano in verticale e scorrono di continuo, ciascuna un foglio bianco su fondo \
                grigio — come in ogni lettore di documenti. I suoi controlli stanno a destra nella barra.
                """),
            .table(
                headers: ["Pulsante / tasto", "Che cosa fa"],
                rows: [
                    ["`Adatta alla larghezza`", "Il foglio è largo esattamente quanto la cornice — l'impostazione predefinita"],
                    ["`Adatta alla pagina`", "L'intero foglio entra nella cornice"],
                    ["`−` `+`", "Ingrandire a scatti; o pizzicare, o ⌘ + rotellina"],
                    ["Il campo `Cerca`, o ⌘F", "Cercare dentro le pagine, saltarci ed evidenziare"],
                    ["Invio nel campo di ricerca", "Occorrenza successiva"],
                    ["Trascinare", "Selezionare testo; doppio clic per una parola, triplo per un paragrafo"],
                    ["⌘A · ⌘C", "Selezionare tutto · copiare la selezione"],
                    ["Pag su · Pag giù · Inizio · Fine", "Muoversi nel documento"],
                ]
            ),
            .paragraph("""
                Il campo di ricerca **ignora accenti e maiuscole**: scrivere `vuong quoc` trova `Vương quốc`. \
                L'etichetta «Pagina 12/363» nella barra vi dice dove siete.
                """),
            .note("""
                **Ciò che non viene reso, detto chiaramente:** le immagini ancorate flottanti (testo che gira \
                attorno a una figura) appaiono come immagini in linea; le note a piè di pagina, i grafici e \
                lo SmartArt di PowerPoint non sono disegnati. Quando serve corrispondenza esatta con la copia \
                stampata, apritelo in Word.
                """),
            .heading("Fare clic su un nodo riporta al sorgente"),
            .paragraph("""
                Un albero JSON non è una bella stampa: fare clic su un nodo sposta il cursore **sul VALORE di \
                quel nodo** nel testo e riporta la scheda a Codice — perché ciò che volete dopo è quasi \
                sempre modificare ciò su cui avete appena fatto clic.
                """),
            .bullets([
                "I nodi contenitore mostrano il loro **numero di elementi** (`{12}`, `[340]`) invece del contenuto — è questo che risponde a «vale la pena aprirlo?».",
                "I **primi due livelli** sono aperti: aprire del tutto un file da diecimila nodi produce un elenco più lungo del sorgente, mentre chiuderlo del tutto obbliga a fare clic per scoprire qualsiasi cosa.",
                "Un file con **sintassi non valida** non riceve mezzo albero — un albero troncato sembra un documento che contiene semplicemente così poco.",
                "In un albero XML gli attributi portano il prefisso `@` in notazione XPath, e **lo spazio fra i tag non diventa un nodo** — è formattazione, non contenuto.",
                "Un albero YAML legge i **file multidocumento** (`---`): ogni documento ha la sua radice. Le raccolte scritte in linea (`ports: [80, 443]`) restano una foglia — vedete già tutto, e aprirle costerebbe un clic. Il **rientro con tabulazioni** è segnalato con la riga esatta: è un errore YAML che l'occhio non vede.",
                "La struttura di PowerPoint è costruita dal **testo aperto**, non dal file su disco: se avete appena modificato la struttura in Codice, l'albero deve descrivere la versione nuova e i suoi nodi devono saltare in quella versione nuova. Le note del relatore si piegano in un nodo, perché una diapositiva loquace non sembri una piena di contenuto.",
                "**Un diagramma a scheda piena segue la stessa regola**: fate clic su un nodo e tornate al Codice con il cursore sulla sua dichiarazione. Nel pannello `Mermaid Studio` affiancato la scheda non si chiude — l'editor è lì accanto, e basta spostare il cursore per vederlo.",
                "I diagrammi **si aprono anche dove siete**: l'elemento corrispondente alla riga del cursore è evidenziato appena appare la scheda, così non dovete cercarlo.",
            ]),
            .heading("Il campo di filtro: in un albero da diecimila nodi, cercare è il lavoro"),
            .paragraph("""
                Subito sotto il conteggio dei nodi c'è un campo di filtro. Scrivetevi e l'albero tiene solo i \
                nodi corrispondenti — **insieme al percorso dalla radice fino a loro**, perché quando una \
                chiave `name` compare in dieci punti la domanda vera è «quale», e solo il ramo che la \
                contiene risponde. Il resto viene aperto per voi: farvi aprire ogni livello a clic è farvi \
                filtrare una seconda volta a mano.
                """),
            .bullets([
                "Filtra su **etichette e valori**: cercare `Huế` è comune quanto cercare la chiave `province`.",
                "**Scrivere senza accenti corrisponde comunque a testo accentato** — `da nang` trova `Đà Nẵng`. Lo stesso confronto del filtro della tabella CSV e dell'elenco delle funzioni, per non dover ricordare tre regole di ricerca in una sola applicazione.",
                "Senza corrispondenze l'intestazione dice **«Nessun risultato»** invece di lasciarvi davanti a un albero vuoto a chiedervi se il file è rotto.",
                "Cambiare file o rientrare nella Vista **azzera il filtro**: un albero che si apre già troncato, senza nulla che lo spieghi, è lo stato più disorientante di tutti.",
            ]),
            .heading("Tutto l'albero si usa da tastiera"),
            .paragraph("""
                Entrare nella Vista mette il fuoco sull'albero; non serve farci clic prima. Su e giù si \
                muovono fra i nodi, sinistra e destra piegano e dispiegano, e due tasti chiudono la \
                consultazione — facendo cose **diverse**:
                """),
            .bullets([
                "**Invio** — andare al nodo selezionato: ritorno al Codice con il cursore dentro l'intervallo di byte di quel nodo. Esattamente come farci clic.",
                "**Tab** — passare fra l'albero e il campo di filtro.",
                "**⌘C** — copia il **percorso** del nodo selezionato, non il testo dietro l'albero. JSON e YAML producono JSONPath (`$.customer['name']`) che si incolla tale e quale nel campo di interrogazione JSONPath di questo stesso prodotto, o in `yq`; XML produce XPath (`/order/item[2]/@code`) con indici quando due tag condividono il nome; una struttura PowerPoint copia il testo della riga, perché una struttura non ha un linguaggio di percorsi da inventare.",
                "**Esc** — la via del ritorno: tornare al Codice con il cursore **esattamente dov'era**. Stavate guardando un albero, non viaggiando da qualche parte.",
            ]),
            .heading("E all'inverso: l'albero si apre dov'è il cursore"),
            .paragraph("""
                Entrare nella Vista da metà di un file di diecimila righe **non** apre l'albero in cima: apre \
                il percorso fino al nodo corrispondente al punto in cui era il cursore e lo seleziona. Questa \
                è l'altra metà del salto al sorgente — senza di essa, Vista e Codice sarebbero due sguardi su \
                un documento in una **sola** direzione.
                """),
            .bullets([
                "Apre **più di due livelli** quando serve: la regola dei due livelli risponde a «com'è fatto questo file», mentre qui la domanda è un'altra — «dove sono in questo albero».",
                "Un cursore su una **chiave** (`\"address\":`) seleziona quella voce, anche se l'intervallo di byte del nodo copre solo il valore. Il testo immediatamente prima di un nodo appartiene a quel nodo.",
                "Un cursore all'**inizio di un blocco** — la chiave di un blocco YAML, un titolo di diapositiva, un nome di tag XML — seleziona quel blocco invece di tuffarsi nel suo primo figlio.",
                "Entrare nella Vista **non sposta il cursore**. Uscite dalla Vista e siete esattamente dov'eravate; la Vista è un modo di guardare, non un comando che cambia posto.",
            ]),
            .heading("Non manca più la Vista a nessun tipo"),
            .paragraph("""
                **Ogni tipo di file con margine per un modo Vista ora ne rende uno.** L'elenco dei tipi \
                mancanti è rimasto vuoto ed è stato tolto.

                Il codice sorgente e il testo semplice restano senza Vista — è normale, non una mancanza, \
                quindi non sono mai stati in quell'elenco.

                Se arriva un tipo di file nuovo la cui Vista non è ancora costruita, il comando di alternanza \
                lo dirà e nominerà ciò che manca, invece di aprire una cornice vuota — una cornice vuota è \
                una promessa vuota, mentre un rifiuto con un nome è informazione.
                """),
            .heading("I sei comandi più vecchi ci sono ancora"),
            .paragraph("""
                `Vista tabella / testo`, `Anteprima Markdown`, `Vista binaria`, `Anteprima del rapporto`, \
                `Anteprima del diagramma Mermaid`, `Modo registro` — restano tutti esattamente dov'erano. \
                `⌥⌘V` è un **ingresso condiviso**, non un sostituto.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamita

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamita",
        summary: "Codifiche antiche, normalizzazione Unicode, ricerca senza accenti e metodi di immissione.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Codifiche vietnamite",
        summary: "Leggere e scrivere TCVN3, VISCII, VNI-Windows e altre 33, rilevate automaticamente.",
        keywords: ["codifica", "tcvn3", "abc", "viscii", "vni", "caratteri strani"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Avete aperto un vecchio file vietnamita e vi è comparso `Tr¦êng §¹i häc` invece di `Trường \
                Đại học`? Il file non è danneggiato — è stato salvato in una codifica anteriore a Unicode.
                """),
            .steps([
                "Fate clic sulla codifica nella **barra di stato** (o `Formato ▸ Codifica…`).",
                "Scegliete quella giusta — nei vecchi file vietnamiti di solito è `TCVN3 (ABC)`, `VNI-Windows` o `VISCII`.",
                "Il testo si corregge subito; non serve riaprire il file.",
                "Per farlo restare così, `Salva col nome…` con la codifica `UTF-8`.",
            ]),
            .heading("Le tre codifiche vietnamite antiche"),
            .table(
                headers: ["Codifica", "Si trova soprattutto in"],
                rows: [
                    ["TCVN3 (ABC)", "Documenti amministrativi e vecchi documenti Word del nord"],
                    ["VNI-Windows", "Editoria, stampa e tipografie — comune al sud"],
                    ["VISCII", "Posta elettronica e Usenet dei primi tempi"],
                ]
            ),
            .paragraph("""
                GEditor **rileva la codifica** all'apertura. Quando sbaglia, un clic risolve, e il contenuto \
                viene decodificato di nuovo invece di essere rattoppato lettera per lettera.
                """),
            .warning("""
                Scrivere verso una codifica antica perde i caratteri che quella codifica non ha. GEditor **li \
                conta e ve lo dice prima** — per esempio *«12 caratteri non sono in TCVN3»* — invece di \
                trasformarli in punti interrogativi in silenzio.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Fine riga",
        summary: "LF, CRLF, CR — convertiti per l'intero file con un clic.",
        keywords: ["eol", "crlf", "lf", "fine riga", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Stile", "Usato da", "Byte"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac prima del 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Lo stile corrente appare nella barra di stato; fateci clic per cambiarlo. Un file che \
                **mescola** due stili viene segnalato anche lì — attivate `Mostra invisibili ▸ Fine riga` per \
                vedere esattamente dove.
                """),
            .note("Lo stile di fine riga per i file **nuovi** si imposta in `Impostazioni…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Normalizzazione Unicode",
        summary: "Perché cercare «ế» a volte non trova nulla, e come sistemare un intero file.",
        keywords: ["unicode", "nfc", "nfd", "composto", "decomposto", "normalizzare"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                In Unicode `ế` si può scrivere in **due modi**: come un solo punto di codice precomposto \
                (NFC), o come `e` più due segni separati (NFD). A schermo appaiono identici; per una macchina \
                sono due stringhe diverse.
                """),
            .paragraph("""
                La conseguenza: cercare `ế` in un file NFD non trova **nulla**, e l'utente conclude che il \
                dato non c'è.
                """),
            .steps([
                "`Formato ▸ Normalizza Unicode…`",
                "Scegliete **NFC** (precomposto) — la forma che usa quasi tutto il resto.",
                "Applicate. È un solo passo di annullamento.",
            ]),
            .note("""
                I file che vengono da macOS sono spesso NFD, perché il file system di Apple memorizza così i \
                nomi. È di gran lunga la ragione più comune per cui i dati copiati dal Finder non si trovano \
                più.
                """),
            .paragraph("""
                C'è un interruttore **normalizza a NFC al salvataggio** in `Impostazioni…`. Disattivo di \
                serie, perché cambia i byte del file.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Scrivere senza accenti trova comunque testo accentato",
        summary: "Ogni campo di ricerca e di filtro confronta con gli accenti tolti.",
        keywords: ["accenti", "diacritici", "ricerca", "filtro"],
        blocks: [
            .paragraph("""
                Scrivete `hue` per trovare `Huế`. Scrivete `da nang` per trovare `Đà Nẵng`. La regola vale \
                per il filtro della tabella CSV, la ricerca delle funzioni, la ricerca nella guida e gli \
                altri campi di filtro.
                """),
            .note("""
                La `Đ` è trattata a parte, perché in Unicode è **una lettera a sé** e non una `D` con un \
                segno — la rimozione ordinaria degli accenti non la tocca.
                """),
            .paragraph("""
                Il filtro CSV accetta anche il prefisso `=` per il confronto esatto. La forma `=` è **anche \
                essa insensibile agli accenti**, perché un filtro che distingue i diacritici lascia l'utente \
                convinto che il dato manchi.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Metodi di immissione vietnamiti",
        summary: "EVKey, OpenKey, Unikey e la sorgente di immissione di macOS scrivono direttamente nel documento.",
        keywords: ["metodo di immissione", "evkey", "unikey", "openkey", "telex", "vni"],
        blocks: [
            .paragraph("""
                Niente da configurare. Telex e VNI funzionano entrambi, anche su **cursori multipli** — \
                scrivete una volta e ogni cursore riceve la lettera correttamente accentata.
                """),
            .paragraph("""
                I campi di ricerca, quelli di filtro e ogni finestra di dialogo accettano il metodo di \
                immissione proprio come l'editor.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Linguaggi e formati

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Linguaggi e formati",
        summary: "Venti linguaggi integrati, altri definiti dall'utente, e strumenti per JSON · XML · YAML · registri.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Venti linguaggi integrati",
        summary: "Colorazione da un vero albero sintattico, con i marcatori di commento di ogni linguaggio.",
        keywords: ["sintassi", "evidenziazione", "linguaggio", "tree-sitter", "grammatica"],
        blocks: [
            .paragraph("""
                Il linguaggio è rilevato dall'**estensione del file** (più qualche nome speciale come \
                `Makefile`, `Dockerfile`, `Gemfile`). Potete cambiarlo a mano nella barra di stato.
                """),
            .table(
                headers: ["Linguaggio", "Estensioni", "Commento di riga · di blocco"],
                rows: [
                    ["Shell", "`sh` `bash` `zsh` `command`", "`#` · —"],
                    ["C", "`c` `h`", "`//` · `/* */`"],
                    ["C++", "`cpp` `cc` `cxx` `hpp` `hh` `hxx`", "`//` · `/* */`"],
                    ["C#", "`cs`", "`//` · `/* */`"],
                    ["CSS", "`css`", "— · `/* */`"],
                    ["Go", "`go`", "`//` · `/* */`"],
                    ["HTML", "`html` `htm` `xhtml`", "— · `<!-- -->`"],
                    ["Java", "`java`", "`//` · `/* */`"],
                    ["JavaScript", "`js` `mjs` `cjs` `jsx`", "`//` · `/* */`"],
                    ["JSON", "`json` `jsonl` `geojson`", "— · —"],
                    ["Lua", "`lua`", "`--` · `--[[ ]]`"],
                    ["PHP", "`php` `phtml`", "`//` · `/* */`"],
                    ["Python", "`py` `pyw` `pyi`", "`#` · —"],
                    ["Regex", "—", "— · —"],
                    ["Ruby", "`rb` `rake` `gemspec`", "`#` · —"],
                    ["Rust", "`rs`", "`//` · `/* */`"],
                    ["TOML", "`toml`", "`#` · —"],
                    ["TypeScript", "`ts` `mts` `cts`", "`//` · `/* */`"],
                    ["XML", "`xml` `xsd` `xsl` `svg` `plist`", "— · `<!-- -->`"],
                    ["YAML", "`yaml` `yml`", "`#` · —"],
                ]
            ),
            .paragraph("""
                L'ultima colonna è ciò che usa `⌘/`. I linguaggi senza commento di riga (JSON, CSS, XML) \
                ricevono invece la forma a blocco.
                """),
            .heading("Che cosa arriva con un albero sintattico"),
            .bullets([
                "L'**elenco delle funzioni** nella barra laterale segue la struttura reale, non congetture sui rientri.",
                "**Piegatura** per struttura.",
                "**Corrispondenza delle parentesi** che salta quelle dentro stringhe e commenti.",
                "**Rientro automatico** che aggiunge un livello dopo `{`, e dopo `:` in Python e YAML.",
            ]),
            .note("""
                Tre grammatiche pesanti (C++, C#, Ruby) vivono in una libreria **caricata pigramente** — sono \
                caricate solo aprendo un file di quei linguaggi. È così che il tempo di avvio resta sotto \
                mezzo secondo.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Linguaggi definiti dall'utente",
        summary: "Colorare il proprio formato con un file JSON — senza grammatica da scrivere.",
        keywords: ["udl", "linguaggio proprio", "registro proprio"],
        blocks: [
            .paragraph("""
                Il formato di registro interno di un'azienda, un linguaggio di configurazione proprio, un \
                piccolo DSL — nessuno ha una grammatica tree-sitter, e scriverne una richiede un compilatore \
                e un po' di teoria del parsing.
                """),
            .paragraph("""
                In alternativa GEditor accetta un **analizzatore lessicale guidato da tabelle** dichiarato in \
                JSON. Mettete il file nella cartella `grammars/` dentro la directory di configurazione di \
                GEditor e riavviate.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — un linguaggio completo",
                  source: """
                    {
                      "name": "Internal log",
                      "extensions": ["nklog", "trace"],
                      "caseSensitive": false,
                      "lineComment": ";",
                      "blockComment": ["/*", "*/"],
                      "stringDelimiters": ["\\"", "'"],
                      "escapeCharacter": "\\\\",
                      "keywordGroups": {
                        "keyword": ["BEGIN", "END", "RETRY", "COMMIT", "ROLLBACK"],
                        "type":    ["INT", "TEXT", "DATE", "MONEY"],
                        "constant": ["TRUE", "FALSE", "NULL"]
                      }
                    }
                    """),
            .heading("Ogni chiave"),
            .table(
                headers: ["Chiave", "Tipo", "Significato"],
                rows: [
                    ["`name`", "stringa", "Il nome mostrato nella barra di stato"],
                    ["`extensions`", "elenco di stringhe", "Estensioni di file, **senza il punto**"],
                    ["`caseSensitive`", "booleano", "Se le parole chiave distinguono le maiuscole"],
                    ["`lineComment`", "stringa", "Marcatore di commento fino a fine riga; ometterlo se non c'è"],
                    ["`blockComment`", "elenco di 2 stringhe", "`[apertura, chiusura]`"],
                    ["`stringDelimiters`", "elenco di stringhe", "Ogni voce è **un** carattere che apre/chiude una stringa"],
                    ["`escapeCharacter`", "stringa", "Carattere di escape dentro le stringhe; vuoto se il linguaggio non ne ha"],
                    ["`keywordGroups`", "oggetto", "Nome di gruppo → elenco di parole chiave; tre gruppi ricevono tre colori"],
                ]
            ),
            .paragraph("I tre nomi di gruppo con colore proprio sono `keyword`, `type` e `constant`."),
            .warning("""
                Questo analizzatore **non capisce l'annidamento**. La piegatura strutturale, l'elenco delle \
                funzioni e la corrispondenza intelligente delle parentesi restano esclusive dei venti \
                linguaggi integrati. È uno scambio voluto: in cambio dichiarate un linguaggio in dieci \
                minuti invece che in un giorno.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "Strumenti JSON",
        summary: "Riformattare, minimizzare, ordinare le chiavi e convalidare rispetto a un JSON Schema.",
        keywords: ["json", "formattare", "minimizzare", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Comando", "Che cosa fa"],
                rows: [
                    ["Riformatta", "Va a capo e rientra per la lettura"],
                    ["Minimizza", "Toglie ogni spazio superfluo"],
                    ["Ordina le chiavi", "Mette in ordine alfabetico le chiavi di ogni oggetto — così due file JSON si possono **confrontare**"],
                    ["Convalida rispetto a JSON Schema…", "Controlla il documento rispetto a uno schema, elencando ogni problema con la sua riga"],
                ]
            ),
            .paragraph("""
                Le regole applicate sono **RFC 8259 in senso stretto**: niente virgole finali, niente \
                commenti, niente `NaN`. Un errore di sintassi indica la riga e la colonna esatte.
                """),
            .note("""
                Anche i file **JSONL** (un oggetto per riga) sono riconosciuti e hanno il proprio corredo di \
                strumenti nel capitolo del pacchetto di conoscenza.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "Interrogazioni JSONPath",
        summary: "Tirare fuori esattamente la parte che serve da un file JSON grande.",
        keywords: ["jsonpath", "interrogazione json", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Scrivete un'espressione; i risultati appaiono come elenco in cui potete saltare."),
            .table(
                headers: ["Scrivete", "Significato"],
                rows: [
                    ["`$`", "La radice del documento"],
                    ["`$.name`", "La chiave `name` alla radice"],
                    ["`$.orders[0]`", "Il primo elemento di un array"],
                    ["`$.orders[*].total`", "La chiave `total` di **ogni** elemento"],
                    ["`$..province`", "La chiave `province` a **qualsiasi profondità**"],
                    ["`$.orders[1:3]`", "Una fetta: elementi 1 e 2"],
                ]
            ),
            .code(language: "text", caption: "Il codice di provincia di ogni ordine, per quanto annidato",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "Strumenti XML",
        summary: "Riformattare, minimizzare, controllare la sintassi e convalidare rispetto a una DTD o a un XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "convalidare", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Comando", "Che cosa fa"],
                rows: [
                    ["Riformatta", "Rientra secondo la profondità dei tag"],
                    ["Minimizza", "Toglie lo spazio fra i tag"],
                    ["Controlla la sintassi", "Tag di chiusura mancanti, annidamento sbagliato, caratteri non validi"],
                    ["Convalida rispetto a DTD/XSD…", "Controlla rispetto a uno schema, segnalando ogni problema con la sua riga"],
                    ["Valuta XPath…", "Esegue un'espressione XPath; i risultati si aprono in una scheda nuova"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Scrivete un'espressione e i risultati si aprono come **una scheda di testo**, un nodo per \
                riga. Per esempio: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **I risultati NON saltano a una posizione nel file sorgente.** Il valutatore XPath del sistema \
                costruisce un albero proprio e non conserva la posizione in byte di ogni nodo, quindi ciò che \
                torna è CONTENUTO e non coordinate. Per arrivare al punto esatto usate `⌘F` sulla stringa che \
                avete appena trovato.
                """),
            .paragraph("""
                Nei file `.xml` e `.html`, scrivere `>` per chiudere un tag di apertura fa **comparire il tag \
                di chiusura** con il cursore fra i due. I tag autochiudenti (`<br/>`), le dichiarazioni \
                (`<?xml …?>`) e i commenti no — non hanno nulla da chiudere.
                """),
            .warning("""
                Riformattare XML **cambia lo spazio fra i tag**. Nei documenti dove quello spazio conta — \
                XHTML con testo dentro i tag, per esempio — questo cambia ciò che viene mostrato. È un solo \
                passo di annullamento, quindi `⌘Z` lo ribalta.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "Controllo YAML",
        summary: "Prendere i due errori YAML più comuni: chiavi doppie e rientro con tabulazioni.",
        keywords: ["yaml", "yml", "lint", "chiave doppia", "rientro"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Chiavi doppie** in una stessa mappatura — la maggior parte dei lettori YAML prende l'**ultima** e scarta in silenzio le precedenti, così un file di configurazione può comportarsi in modo del tutto diverso da come credete.",
                "**Rientro con tabulazioni** — YAML vieta le tabulazioni nel rientro, e i messaggi d'errore delle librerie al riguardo sono di solito incomprensibili.",
            ]),
            .note("Attivate `Mostra invisibili ▸ Tabulazioni` per vedere subito quale spazio è una tabulazione."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "File di registro",
        summary: "Sette livelli di gravità, filtraggio per livello e come leggere un registro molto grande.",
        keywords: ["registro", "log", "errore", "avviso", "filtro", "livello"],
        blocks: [
            .paragraph("""
                Attivate `Vista ▸ Modo registro (colora per livello)`. GEditor legge la gravità all'**inizio \
                di ogni riga** — dopo la marca temporale e il nome del processo.
                """),
            .table(
                headers: ["Livello", "Colore"],
                rows: [
                    ["CRITICAL · ERROR", "Rosso"],
                    ["WARNING", "Ambra"],
                    ["NOTICE", "Colore d'accento"],
                    ["INFO", "Testo comune"],
                    ["DEBUG · TRACE", "Attenuato"],
                ]
            ),
            .paragraph("""
                `Filtra il registro per livello…` nasconde del tutto i livelli più bassi. Le righe il cui \
                livello **non è riconosciuto** — la continuazione di una traccia di stack, per esempio — \
                restano intatte invece di ricevere il livello della riga precedente.
                """),
            .heading("Leggere un registro grande, passo per passo"),
            .steps([
                "Aprite il file — anche su scala di gigabyte si apre quasi all'istante.",
                "`Vista ▸ Modo registro` per vedere dov'è il rosso.",
                "`⌥⌘M` per la mappa del documento: il rosso è raggruppato in un tratto o sparso per tutto il file?",
                "`⌘F` per il codice d'errore, `⌘M` per contrassegnare ogni riga corrispondente.",
                "`Cerca ▸ Copia le righe contrassegnate` per portarle in una scheda nuova.",
                "Ancora in corso? `File ▸ Segui file (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
