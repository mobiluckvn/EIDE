import Foundation

/// Contenuto della guida in italiano — parte 2: ricerca, file e sessioni.
extension HelpIT {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Ricerca",
        summary: "Cercare, sostituire, espressioni regolari, ricerca su cartella e contrassegni di riga.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Cercare e sostituire",
        summary: "Tre modi di ricerca, e perché ^ significa inizio RIGA di serie.",
        keywords: ["cercare", "sostituire", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Cercare"),
                HelpShortcut("⌥⌘F", "Cercare e sostituire"),
                HelpShortcut("⌘G / ⇧⌘G", "Occorrenza successiva / precedente"),
            ]),
            .heading("Tre modi"),
            .table(
                headers: ["Modo", "Capisce", "Per"],
                rows: [
                    ["Normale", "Testo semplice, nessun carattere speciale", "La maggior parte delle ricerche"],
                    ["Esteso", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Trovare a capo, tabulazioni, byte precisi"],
                    ["Regex", "PCRE2 completo", "Cercare per schema"],
                ]
            ),
            .note("""
                Il modo **esteso** non capisce la sintassi delle regex. Espande solo alcune sequenze di \
                escape — cercarvi `a.b` trova esattamente quei tre caratteri; il punto non è un jolly.
                """),
            .heading("Due interruttori"),
            .bullets([
                "**Distingui maiuscole** — disattivo di serie.",
                "**Parola intera** — corrisponde solo quando entrambe le estremità sono confini di parola.",
            ]),
            .heading("`^` e `$` corrispondono ai bordi di ogni RIGA"),
            .paragraph("""
                Attivo di serie. Chi viene da Notepad++ si aspetta che `^` significhi «inizio riga»; senza, \
                `^abc` corrisponderebbe solo se l'intero documento iniziasse con `abc` — quasi nessuno lo \
                vuole in un editor di testo.
                """),
            .heading("Un'espressione cattiva non bloccherà l'applicazione"),
            .paragraph("""
                Il motore è **PCRE2 con compilazione JIT** e ha un budget di backtracking. Uno schema che \
                esplode in modo combinatorio viene fermato e segnalato, invece di congelare la finestra.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Espressioni regolari",
        summary: "La sintassi PCRE2 che si usa davvero, con esempi che girano su dati vietnamiti.",
        keywords: ["regex", "pcre", "schema"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor usa **PCRE2**, lo stesso motore di PHP e di molti strumenti a riga di comando. \
                Aprite `Cerca ▸ Prova espressione regolare…` per provare uno schema su un testo di esempio \
                e vedere che cosa cattura ogni gruppo **prima** di applicarlo a un documento vero.
                """),
            .heading("Classi di caratteri"),
            .table(
                headers: ["Scrivete", "Corrisponde a"],
                rows: [
                    ["`.`", "Qualsiasi carattere tranne un a capo"],
                    ["`\\d` · `\\D`", "Una cifra · non una cifra"],
                    ["`\\w` · `\\W`", "Un carattere di parola (lettera, cifra, `_`) · il contrario"],
                    ["`\\s` · `\\S`", "Spazio bianco · non spazio"],
                    ["`[abc]`", "Uno dei caratteri fra parentesi quadre"],
                    ["`[^abc]`", "Un carattere che NON è fra parentesi quadre"],
                    ["`[a-z]`", "Un carattere dell'intervallo"],
                ]
            ),
            .heading("Ripetizione"),
            .table(
                headers: ["Scrivete", "Significato"],
                rows: [
                    ["`*`", "Zero o più"],
                    ["`+`", "Uno o più"],
                    ["`?`", "Zero o uno"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Esattamente 3 · fra 2 e 5 · 2 o più"],
                    ["`*?` `+?` `??`", "Le forme **pigre** — prendere il meno possibile"],
                ]
            ),
            .warning("""
                `.*` è **avido**: mangia fino a fine riga e poi indietreggia. Nel separare campi dentro una \
                riga servono quasi sempre `.*?` o una classe stretta come `[^,]*`.
                """),
            .heading("Ancore e gruppi"),
            .table(
                headers: ["Scrivete", "Significato"],
                rows: [
                    ["`^` · `$`", "Inizio riga · fine riga"],
                    ["`\\b`", "Confine di parola"],
                    ["`(…)`", "Un gruppo **di cattura** — riutilizzabile nella sostituzione"],
                    ["`(?:…)`", "Gruppo senza cattura"],
                    ["`(?<name>…)`", "Gruppo con nome"],
                    ["`a|b`", "a oppure b"],
                    ["`(?=…)` · `(?!…)`", "Sguardo avanti: deve seguire · non deve seguire"],
                    ["`(?<=…)` · `(?<!…)`", "Sguardo indietro: deve precedere · non deve precedere"],
                ]
            ),
            .heading("Esempi che funzionano"),
            .code(language: "regex", caption: "Ogni numero di telefono vietnamita a 10 cifre",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Spezzare una data 31/12/2026 in tre gruppi",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "La terza cella di una riga CSV semplice (senza virgolette)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Righe di registro con ERROR o FATAL, con la marca temporale",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Righe vuote, o con soli spazi",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Lettere vietnamite accentate — usate la classe Unicode, non elencatele",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` significa «qualsiasi lettera Unicode», quindi prende anche `ế` e `đ`. Elencare a \
                mano ogni vocale accentata è il modo sicuro per dimenticarne qualcuna.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Stringhe di sostituzione",
        summary: "Riutilizzare i gruppi catturati e cambiare le maiuscole mentre si sostituisce.",
        keywords: ["sostituire", "retroriferimento", "gruppo", "$1", "\\U"],
        blocks: [
            .heading("Richiamare un gruppo catturato"),
            .table(
                headers: ["Scrivete", "Significato"],
                rows: [
                    ["`$1` … `$9`", "Il contenuto del gruppo n"],
                    ["`${1}`", "Lo stesso con limiti espliciti — usatelo quando segue una cifra"],
                    ["`\\1`", "È accettato anche; GEditor lo riscrive come `${1}`"],
                    ["`$0`", "L'intera corrispondenza"],
                ]
            ),
            .note("""
                Scrivete `${1}` invece di `$1` quando il carattere successivo è una cifra. `$123` si legge \
                come gruppo 123; `${1}23` è il gruppo 1 seguito da due cifre.
                """),
            .heading("Cambiare le maiuscole durante una sostituzione"),
            .table(
                headers: ["Scrivete", "Significato"],
                rows: [
                    ["`\\U`", "MAIUSCOLE da qui in poi"],
                    ["`\\L`", "minuscole da qui in poi"],
                    ["`\\u`", "Solo il carattere successivo maiuscolo"],
                    ["`\\l`", "Solo il carattere successivo minuscolo"],
                    ["`\\E`", "Fine della zona `\\U` o `\\L`"],
                ]
            ),
            .heading("Esempi"),
            .code(language: "text", caption: "Trasformare 31/12/2026 in 2026-12-31",
                  source: """
                    Cerca:      (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Sostituisci: $3-$2-$1
                    """),
            .code(language: "text", caption: "Mettere in maiuscolo il codice di provincia a inizio riga, tenere il resto",
                  source: """
                    Cerca:      ^([a-z]{2,3})(\\s)
                    Sostituisci: \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Avvolgere ogni riga come stringa JSON",
                  source: """
                    Cerca:      ^(.+)$
                    Sostituisci: "$1",
                    """),
            .paragraph("""
                Un gruppo che **non ha partecipato** alla corrispondenza diventa una stringa vuota, non un \
                errore — così uno schema con alternative come `(a)|(b)` sostituisce pulitamente senza \
                scriverlo due volte.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Cercare e sostituire in una cartella",
        summary: "Scorrere molti file insieme e vedere i risultati prima di scrivere qualsiasi cosa.",
        keywords: ["cerca nei file", "grep", "sostituzione di massa", "cartella"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Cercare in una cartella")]),
            .paragraph("""
                Scegliete la cartella radice, filtrate per schema di nome e scorrete. I risultati appaiono \
                raggruppati per file; fare clic su una riga apre quel file in quella posizione.
                """),
            .bullets([
                "Gli stessi tre modi di ricerca e lo stesso motore di regex del campo di ricerca nel documento.",
                "La sostituzione su cartella **mostra in anteprima** quanti file e quante occorrenze cambieranno prima di scrivere.",
                "La scansione va in parallelo e **si può annullare** a metà.",
            ]),
            .warning("""
                La sostituzione su cartella scrive direttamente in file **non aperti**. Quei file non sono \
                nella cronologia di annullamento del documento aperto — guardate prima l'anteprima e tenete \
                una copia di sicurezza o un repository con versioni.
                """),
            .heading("Ricerche precedenti ed esportazione dei risultati"),
            .paragraph("""
                Il pannello dei risultati **conserva le ricerche di questa sessione**. Il menu a comparsa in \
                cima le elenca con il numero di occorrenze — cercate `TODO`, leggete a metà, cercate `FIXME` \
                per confrontare e tornate al primo elenco senza riscansionare l'intera cartella.
                """),
            .paragraph("""
                Il pulsante **Esporta** apre la ricerca corrente come scheda di testo, un risultato per riga \
                nel formato `percorso:riga:colonna: testo` — la forma che usa `grep -n` e quella che i \
                compilatori usano per gli errori. Ogni riga si incolla tale e quale nel campo `Vai a` di \
                questo stesso prodotto, e i vostri `grep`, `awk` e `sed` la leggono senza un analizzatore \
                fatto in casa.
                """),
            .note("""
                La cronologia vive **in memoria** e non viene mai scritta su disco: i risultati di ricerca \
                portano il contenuto di ogni riga trovata, cioè la stessa classe di dati che la cronologia \
                degli appunti deliberatamente non conserva.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Contrassegni di riga",
        summary: "Nove colori di contrassegno e quattro comandi che trasformano le righe contrassegnate in un risultato.",
        keywords: ["segnalibro", "contrassegno", "f2", "filtrare righe"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Contrassegnare è il modo di filtrare un documento **senza cambiarlo**. Contrassegnate ogni \
                riga che corrisponde a uno schema, poi copiate solo quelle, o tenete solo quelle.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Contrassegnare ogni riga che corrisponde alla ricerca corrente"),
                HelpShortcut("⌘F2", "Contrassegnare / togliere il contrassegno dalla riga corrente"),
                HelpShortcut("F2 / ⇧F2", "Andare al contrassegno successivo / precedente"),
            ]),
            .heading("Un flusso abituale"),
            .steps([
                "`⌘F` con lo schema su cui volete filtrare, p. es. `\\bERROR\\b`.",
                "`⌘M` contrassegna ogni riga corrispondente.",
                "`Cerca ▸ Copia le righe contrassegnate` le porta in una scheda nuova — oppure `Tieni solo le righe contrassegnate` filtra sul posto.",
            ]),
            .heading("Nove colori"),
            .paragraph("""
                Una riga può portare **più colori insieme**. Usate colori diversi per criteri diversi e \
                combinateli: rosso per le righe di errore, giallo per le righe di uno stesso numero \
                d'ordine, poi cercate le righe che portano entrambi.
                """),
            .bullets([
                "`Inverti i contrassegni` — le righe contrassegnate diventano non contrassegnate e viceversa.",
                "`Cancella tutti i contrassegni` — toglie ogni contrassegno senza toccare il contenuto.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Andare alla riga",
        summary: "Saltare a una riga, a una colonna o a una posizione in byte.",
        keywords: ["vai a", "numero di riga", "cmd+l", "posizione", "colonna"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Andare alla riga")]),
            .paragraph("""
                Il campo capisce **tre notazioni** e le distingue da ciò che scrivete — non c'è alcun \
                selettore in più da premere.
                """),
            .table(
                headers: ["Scrivete", "Va a"],
                rows: [
                    ["`120`", "l'inizio della riga 120"],
                    ["`120,5` o `120:5`", "riga 120, colonna 5 — la colonna conta CARATTERI"],
                    ["`@1024`", "la posizione 1024 in byte nel file"],
                ]
            ),
            .note("""
                `riga:colonna` è esattamente il modo in cui compilatori e linter stampano una posizione, \
                così una riga appena copiata da un terminale si incolla tale e quale.

                La `@` delle posizioni in byte ha una ragione: `1234` è una riga o un byte? Non c'è risposta \
                giusta, e indovinare male manda il cursore da tutt'altra parte senza alcun segnale. Quella \
                cifra in byte è anche quella che la barra di stato mostra nel segmento di posizione \
                (`@1024`): ciò che leggete lì potete scriverlo qui.
                """),
            .bullets([
                "Una colonna **oltre la lunghezza della riga** si ferma a fine riga; non trabocca su quella successiva.",
                "Una posizione in byte **oltre il file** vi porta alla fine — quel numero di solito viene da un'esecuzione precedente, e il file può essersi ristretto.",
                "Il testo che non riesce a leggere viene **segnalato**, e il cursore resta dov'è; non salta all'inizio del file.",
            ]),
            .paragraph("""
                Su file molto grandi GEditor non legge l'intero file per arrivarci — l'indice delle righe si \
                costruisce a poco a poco in secondo piano.
                """),
            .note("""
                Anche lo strumento a riga di comando accetta una posizione: `geditor rapporto.csv:120:5` apre \
                il file con il cursore alla riga 120, colonna 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - File e sessioni

    static let files = HelpChapter(
        id: "tep",
        title: "File e sessioni",
        summary: "Aprire, salvare, schede, finestre, spazi di lavoro e come torna la sessione.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Aprire e salvare",
        summary: "Aprire un file di qualsiasi dimensione e salvarlo con un'altra codifica o fine riga.",
        keywords: ["aprire", "salvare", "duplicare", "rinominare", "spostare"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Documento nuovo"),
                HelpShortcut("⌘O", "Aprire un file"),
                HelpShortcut("⌘S", "Salvare"),
                HelpShortcut("⇧⌘S", "Salvare col nome"),
            ]),
            .paragraph("""
                Trascinare un file nella finestra lo apre ugualmente. `File ▸ Apri recenti` conserva \
                l'elenco dei file su cui stavate lavorando.
                """),
            .heading("Salvare col nome: tre cose che potete cambiare"),
            .table(
                headers: ["Cambiamento", "Significato"],
                rows: [
                    ["Codifica", "Scrivere in UTF-8, TCVN3, VNI-Windows… — 36 codifiche"],
                    ["Fine riga", "LF (Unix) · CRLF (Windows) · CR (Mac classico)"],
                    ["Nome e posizione", "Come in ogni finestra di salvataggio di macOS"],
                ]
            ),
            .paragraph("""
                La barra di stato mostra sempre la codifica, lo stile di fine riga e il linguaggio \
                rilevato. **Fare clic su uno di essi lo cambia subito**, senza passare da una finestra di \
                dialogo.
                """),
            .heading("Duplicare · rinominare · spostare"),
            .paragraph("""
                Queste tre agiscono sul FILE e non sul suo contenuto — e la scheda aperta segue il file, \
                così non perdete mai il vostro posto.
                """),
            .table(
                headers: ["Comando", "Che cosa fa"],
                rows: [
                    ["`Duplica file`",
                     "Lo copia come `nome 2.txt` accanto all'originale e **apre la copia** — perché si duplica per modificare la copia"],
                    ["`Rinomina file…`", "Rinomina su disco; la scheda segue il nome nuovo"],
                    ["`Sposta file in…`", "Sposta in un'altra cartella; la scheda segue"],
                ]
            ),
            .note("""
                Tutte e tre **rifiutano se a destinazione esiste già un file con quel nome**; non \
                sovrascrivono mai. E tutte e tre richiedono un file salvato almeno una volta — un documento \
                che non è mai stato su disco non ha nulla da duplicare o spostare.
                """),
            .heading("Scrittura sicura"),
            .bullets([
                "La scrittura è **atomica**: un'interruzione di corrente a metà non lascia mai un file troncato.",
                "Se un altro programma modifica il file mentre lo tenete aperto, GEditor se ne accorge e chiede prima di sovrascrivere.",
                "I file su iCloud Drive o su un volume di rete passano dal coordinatore di file del sistema, così due macchine non si pestano i piedi.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Schede, finestre e vista divisa",
        summary: "Molte schede per finestra, molte finestre e schede che si trascinano fra loro.",
        keywords: ["scheda", "finestra", "dividere", "riquadro"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Nuova scheda"),
                HelpShortcut("⌘W", "Chiudere la scheda"),
                HelpShortcut("⇧⌘T", "Riaprire l'ultima scheda chiusa"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Scheda successiva / precedente"),
                HelpShortcut("⌥⌘N", "Finestra nuova"),
                HelpShortcut("⌃⌘N", "Staccare la scheda corrente in una finestra propria"),
            ]),
            .paragraph("""
                Potete trascinare una scheda in un'altra finestra, o lasciarla nel vuoto per creare una \
                finestra. **Una scheda fissata non viaggia** — fissare vuol dire «tieni questa qui».
                """),
            .note("""
                `⇧⌘T` riapre l'ultima scheda chiusa, compresa una **non salvata**: il suo contenuto è ancora \
                lì.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Aprire una cartella come spazio di lavoro",
        summary: "Un albero di file nella barra laterale, ricerca su tutto il progetto e apertura con un clic.",
        keywords: ["spazio di lavoro", "cartella", "progetto", "barra laterale"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Aprire una cartella come spazio di lavoro")]),
            .paragraph("""
                L'albero appare nella barra laterale (`⌘0`). Fate clic su un file per aprirlo, e `⇧⌘F` cerca \
                nell'intera cartella.
                """),
            .note("""
                Nella versione App Store, l'accesso alla cartella è retto da un **segnalibro con ambito di \
                sicurezza**, così l'avvio successivo ci arriva ancora senza chiedervi di scegliere di nuovo \
                la cartella.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "La sessione si ripristina da sola",
        summary: "Uscite e riaprite: ogni scheda torna, comprese quelle non salvate.",
        keywords: ["sessione", "ripristinare", "non salvato", "recuperare"],
        blocks: [
            .paragraph("""
                Niente da attivare. Uscite da GEditor e riapritelo: le schede, il loro ordine, le posizioni \
                del cursore e dello scorrimento tornano tutte.
                """),
            .heading("E le schede non salvate"),
            .paragraph("""
                Il loro contenuto è conservato in un'istantanea separata, quindi tornano anche loro. Se \
                l'applicazione termina in modo anomalo, l'avvio successivo **chiede** prima di ripristinare \
                bozze orfane — invece di ricostruire in silenzio un mucchio di schede che non ricordate.
                """),
            .warning("""
                Una sessione **non è un backup**. Conserva lo stato di lavoro, non la cronologia. Tutto ciò \
                che conta va comunque salvato in un file.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Versioni salvate in precedenza",
        summary: "Sfogliare e ripristinare versioni più vecchie di un file.",
        keywords: ["versioni", "cronologia", "ripristinare", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                A ogni salvataggio GEditor registra la versione **precedente** prima di sovrascrivere. \
                `Macro ▸ Versioni salvate…` ne apre il navigatore.
                """),
            .bullets([
                "L'archivio delle versioni è quello del **sistema operativo**, lo stesso meccanismo che usano le app di Apple.",
                "Ripristinare una versione più vecchia è una **modifica ordinaria** — `⌘Z` la annulla.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Seguire un file ancora in scrittura",
        summary: "Come `tail -f`: ciò che viene aggiunto appare man mano che arriva.",
        keywords: ["tail", "seguire", "registro", "tempo reale"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `File ▸ Segui file (tail -f)` carica ciò che appare in coda al file e scorre con esso.
                """),
            .warning("""
                Durante il seguito il documento diventa **in sola lettura**. Scrivere mentre nuovo testo \
                viene caricato dal disco sono due scrittori che si contendono un documento, e a perdere è \
                sempre ciò che avete appena battuto.
                """),
            .note("""
                La barra di stato dice **In ascolto** per tutto il tempo, così qualche minuto dopo sapete \
                ancora perché il file non accetta la scrittura. Fare clic sul segmento **sola lettura** ne \
                dà la ragione senza giri di parole.

                Il seguito appartiene alla **scheda che lo ha avviato**, non alla finestra: aprite un'altra \
                scheda e continuate a scrivere, e le nuove righe di registro continuano ad affluire nella \
                loro scheda senza toccare il file che state modificando.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Stampa",
        summary: "Stampare dalla finestra di stampa standard di macOS.",
        keywords: ["stampare", "carta", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Stampare")]),
            .paragraph("""
                Usa la finestra di stampa del sistema, quindi anche l'esportazione in PDF avviene lì — il \
                pulsante `PDF` in basso a sinistra.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Immagini, PDF, file Office, audio, video e archivi",
        summary: "Otto tipi di file si aprono dentro GEditor senza un'altra applicazione.",
        keywords: ["immagine", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "archivio",
                   "audio", "video"],
        blocks: [
            .table(
                headers: ["Tipo", "Che cosa potete fare"],
                rows: [
                    ["Immagini", "Vedere, ingrandire, ruotare; **le immagini animate si riproducono** e si possono mettere in pausa"],
                    ["Audio", "Riprodurre, cercare, cambiare volume"],
                    ["Video", "Riprodurre, cercare, schermo intero, immagine nell'immagine"],
                    ["PDF", "Leggere, cercare, **annotare**"],
                    ["Word · Excel · PowerPoint", "Vedere **e modificare** — `⌘S` riscrive direttamente nel file"],
                    ["ZIP · TAR · GZ · XZ", "Elencare le voci e aprirne ciascuna come scheda"],
                    ["7z · RAR e altri sette formati", "Lo stesso, tramite libarchive"],
                ]
            ),
            .paragraph("""
                Aprire una voce d'archivio crea una scheda con il suo contenuto. Gli accenti vietnamiti \
                sopravvivono sia nei nomi sia nel contenuto.
                """),
            .note("""
                Modificate uno dei tre formati Office, premete `⌘S`, e viene riscritto nel file — \
                LibreOffice legge il risultato. Questo percorso è collaudato da capo a fondo, non solo \
                esportato in una copia.
                """),
            .heading("Audio e video usano i lettori di macOS"),
            .paragraph("""
                La riproduzione passa dai decodificatori del sistema, quindi non si scarica né si include \
                nulla in più. In cambio alcuni formati **non si riprodurranno** — `.mkv`, `.webm`, `.avi`, \
                `.wmv` — perché macOS non ha un decodificatore integrato per essi.
                """),
            .paragraph("""
                Per un file così GEditor **dice perché** invece di mostrare un rettangolo nero, e propone il \
                visualizzatore binario o un'altra applicazione.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "Strumenti PDF",
        summary: "Leggere, annotare e un intero strato di pagine: ruotare · spostare · eliminare · estrarre · unire.",
        keywords: ["pdf", "pagina", "ruotare", "eliminare pagina", "estrarre", "unire",
                   "annotare", "evidenziare", "firmare"],
        blocks: [
            .paragraph("""
                La vista PDF ha **due barre degli strumenti**, che rispondono a domande diverse. La riga in \
                alto agisce sul **contenuto** di una pagina; quella in basso sull'**insieme delle pagine**.
                """),
            .heading("Riga in alto — leggere e annotare"),
            .table(
                headers: ["Pulsante", "Che cosa fa"],
                rows: [
                    ["Evidenzia · Sottolinea", "Contrassegnare il testo selezionato"],
                    ["Nota…", "Allegare una nota alla pagina"],
                    ["Rimuovi annotazioni", "Togliere ogni annotazione dalla pagina corrente"],
                    ["Estrai il testo in una scheda", "Portare tutto il testo in una scheda per cercare, filtrare, usare altri strumenti"],
                    ["Campo di ricerca", "Cercare dentro il PDF — **scrivere senza accenti trova comunque testo accentato**"],
                ]
            ),
            .note("""
                Un PDF scansionato non ha strato di testo. Il comando di estrazione **lo dice** invece di \
                aprire una scheda vuota e lasciarvi indovinare.
                """),
            .heading("Riga in basso — operazioni sulle pagine"),
            .table(
                headers: ["Pulsante", "Che cosa fa", "Annullabile"],
                rows: [
                    ["Ruota a sinistra · destra", "Girare la pagina corrente di 90°", "Sì"],
                    ["Pagina su · giù", "Scambiare la pagina corrente con la vicina", "Sì"],
                    ["Elimina pagine…", "Eliminare per intervallo, p. es. `2-4,7`", "Sì"],
                    ["Estrai pagine…", "Scrivere un intervallo di pagine come **file nuovo**", "Non tocca il file aperto"],
                    ["Unisci un PDF…", "Inserire un altro PDF subito dopo la pagina corrente", "Sì"],
                    ["Firma…", "Mettere un'immagine di firma sulla pagina corrente", "Sì"],
                    ["Modifica testo…", "Disegnare testo sostitutivo sopra la selezione", "Sì"],
                    ["Campo vuoto successivo", "Andare al campo modulo successivo non compilato", "—"],
                    ["Cancella i valori compilati", "Svuotare ogni campo del modulo", "Sì"],
                    ["Annulla la modifica di pagina", "Tornare indietro di un'operazione di pagina", "—"],
                    ["Salva la copia modificata…", "Scrivere un file nuovo e poi **riaprirlo per verificare**", "—"],
                ]
            ),
            .heading("Moduli compilabili"),
            .paragraph("""
                Aprite un PDF con campi modulo e la barra di stato dice **quanti** ce ne sono. Scrivete \
                direttamente nei campi della pagina, poi `Salva la copia modificata…`.
                """),
            .bullets([
                "I valori sono conservati come **campi modulo vivi**, non come testo appiattito — così l'Acrobat del destinatario vede ancora un modulo compilato e può correggerlo.",
                "Gli accenti vietnamiti sopravvivono al giro scrittura-e-riapertura. Un test sorveglia proprio questo, con il nome `Nguyễn Văn Anh`.",
                "`Campo vuoto successivo` salta al prossimo in bianco — il percorso naturale in un modulo lungo.",
            ]),
            .heading("Firmare"),
            .paragraph("""
                Preparate un'immagine di firma (un PNG con sfondo trasparente va meglio), **selezionate il \
                punto dove firmare** — di solito la riga o la parola «Firma» — e premete `Firma…`. Senza \
                nulla di selezionato, la firma finisce in basso a destra.
                """),
            .note("""
                La firma conserva le **proporzioni** dell'immagine: una firma schiacciata o stirata sembra \
                falsa all'istante.
                """),
            .heading("Modificare il testo — e tre cose da sapere prima"),
            .paragraph("""
                Selezionate il testo da cambiare e premete `Modifica testo…`. GEditor **copre quell'area con \
                un colore di sfondo campionato lì accanto** e disegna sopra il testo nuovo.
                """),
            .warning("""
                **Il testo vecchio è COPERTO, non RIMOSSO.** È ancora nel file ed è ancora estraibile con \
                `Estrai il testo in una scheda` o con qualsiasi altro strumento. Questa **non è \
                oscuratura**: nascondere così un numero di documento lo nasconde a un occhio umano, non a \
                una macchina.
                """),
            .bullets([
                "**Il testo nuovo resta trovabile con `⌘F`.** È disegnato come testo vero, non come immagine — misurato da un test, non dato per scontato.",
                "**Il carattere è uno di sistema**, non quello originale del documento. Di proposito: i caratteri incorporati in un PDF spesso non hanno gli accenti vietnamiti, e `Nguyễn` arriverebbe come `Nguy?n`.",
                "**Su uno sfondo a motivi la toppa si vede** — il colore di copertura è campionato in un solo punto, subito a sinistra della selezione.",
            ]),
            .heading("Perché disegnare sopra invece di modificare il flusso di contenuto"),
            .paragraph("""
                Modificare direttamente il flusso di contenuto di un PDF significa fare i conti con caratteri \
                in sottoinsieme che portano la propria codifica, frasi spezzate in tre frammenti dalla \
                crenatura e tabelle di larghezza dei caratteri da ricalcolare. Farlo bene per **ogni** file è \
                un progetto a sé; farlo male corrompe il documento di qualcuno.
                """),
            .paragraph("""
                In cambio, il resto della pagina **non cambia di un solo byte**, e la pagina resta una pagina \
                — il testo si seleziona, si copia e si cerca ancora. Ridisegnare **non** la trasforma in \
                un'immagine.
                """),
            .heading("Sintassi degli intervalli di pagine"),
            .table(
                headers: ["Scrivete", "Significato"],
                rows: [
                    ["`5`", "Solo la pagina 5"],
                    ["`2-4`", "Pagine 2, 3, 4"],
                    ["`-3`", "Dall'inizio alla pagina 3"],
                    ["`8-`", "Dalla pagina 8 alla fine"],
                    ["`1-3,5,9-`", "Più parti unite da virgole"],
                ]
            ),
            .paragraph("Le pagine si contano **da 1**, il numero che vedete a schermo."),
            .warning("""
                Un intervallo invertito (`5-2`) e uno oltre la fine (`1-999`) sono entrambi **rifiutati con \
                una ragione**, mai corretti in silenzio in qualcosa di simile. In un comando che elimina \
                pagine, indovinare male vuol dire perdere pagine, e tagliare in silenzio trasforma un refuso \
                in un comando valido.
                """),
            .heading("Il file originale non viene mai sovrascritto"),
            .paragraph("""
                Tutto quanto sopra cambia il documento **in memoria**. Solo quando premete `Salva la copia \
                modificata…` e scegliete una posizione viene scritto un file — e dopo la scrittura GEditor \
                **riapre proprio quel file** per confermare che ha ancora tutte le sue pagine.
                """),
            .paragraph("""
                La ragione: un file scritto male sta sul disco con un'aria perfettamente normale, e l'utente \
                se ne accorge solo dopo averlo spedito.
                """),
            .note("""
                La riga di stato della vista dice **· modificato, non salvato** ogni volta che il documento \
                differisce dal file su disco.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
