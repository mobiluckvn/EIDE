import Foundation

/// Norsk hjelpeinnhold (bokmål) — del 3: visninger, vietnamesisk samt språk og formater.
extension HelpNB {

    static let views = HelpChapter(
        id: "xem",
        title: "Måter å se et dokument på",
        summary: "Sidepanel, kart, sammenfolding, delt visning, linjebryting, usynlige tegn, fargemodi.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Sidepanel og funksjonsliste",
        summary: "Mappetreet og den åpne filens funksjonsliste, i én spalte.",
        keywords: ["sidepanel", "funksjonsliste", "disposisjon", "filtre"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Vis / skjul sidepanelet")]),
            .paragraph("""
                Funksjonslisten bygges av språkets **syntakstre**, så den følger den virkelige \
                oppbygningen i stedet for å gjette ut fra innrykket. Klikk på et punkt for å hoppe dit.
                """),
            .note("Filterfeltet i funksjonslisten **finner tekst med aksent ut fra skrift uten aksent**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Dokumentkart",
        summary: "Hele filen i en smal spalte til høyre — også ved hundrevis av MB.",
        keywords: ["minikart", "kart", "oversikt"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Vis / skjul dokumentkartet")]),
            .paragraph("""
                Kartet beskriver **hele filen**, ikke bare det som er på skjermen. Å dra på det hopper \
                til det tilsvarende stedet.
                """),
            .paragraph("""
                Søketreff og merkede linjer vises på kartet, så du kan se om de er spredte eller \
                klumpede før du ruller dit.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Sammenfolding",
        summary: "Fold funksjoner, blokker og lister etter oppbygning — eller fold filen til et nivå.",
        keywords: ["fold", "kodefolding", "sammenfold"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Fold / fold ut blokken ved markøren"),
                HelpShortcut("⌥⇧⌘←", "Fold alt"),
                HelpShortcut("⌥⌘→", "Fold ut alt"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Fold hele filen til nivå 1…8"),
            ]),
            .paragraph("""
                For språk med et syntakstre følger sammenfoldingen den **virkelige oppbygningen**. For \
                filer uten en grammatikk følger den innrykket.
                """),
            .paragraph("""
                `Fold til nivå` gjør seg fortjent på dyp JSON og YAML: å folde til nivå 2 setter hele \
                filens form på én skjerm.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Delt visning",
        summary: "To ruter side om side, for to filer — eller to steder i én fil.",
        keywords: ["del", "ruter", "sammenlign"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Del loddrett"),
                HelpShortcut("⌥⌘-", "Del vannrett"),
                HelpShortcut("⌥⌘0", "Fjern delingen"),
                HelpShortcut("⌥⌘]", "Åpne denne fanen i den andre ruten"),
                HelpShortcut("⌥⌘[", "Hopp til den andre ruten"),
            ]),
            .paragraph("""
                Hver rute har sin egen fanerad. Å åpne **samme fil** i begge ruter er greit — de ruller \
                uavhengig, noe som gjør det lett å sammenligne toppen og bunnen av en fil.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Linjebryting",
        summary: "Tre modi: av, ved vinduskanten eller ved en fast kolonne.",
        keywords: ["linjebryting", "myk bryting"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Modus", "En lang linje"],
                rows: [
                    ["Av", "Ruller vannrett"],
                    ["Ved vinduet", "Brytes ved vinduskanten og følger størrelsen"],
                    ["Ved en kolonne", "Brytes ved kolonnen du setter — for eksempel 80 eller 100"],
                ]
            ),
            .paragraph("""
                Linjebryting er en **måte å se på**, ikke en redigering: det settes ikke inn noe \
                linjeskift, og det havner aldri i angrehistorikken.
                """),
            .note("Den raske veien hit er feltet `Bryting: …` på statuslinjen."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Skriftstørrelse",
        summary: "Zoom mellom 8 og 32 pt.",
        keywords: ["zoom", "skriftstørrelse", "større", "mindre"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Større tekst"),
                HelpShortcut("⌘-", "Mindre tekst"),
                HelpShortcut("⌃⌘0", "Tilbake til standardstørrelsen"),
            ]),
            .paragraph("""
                Begrenset til mellom 8 og 32 pt. Også dette er en **måte å se på**: ingen redigering, \
                ingenting i angrehistorikken. Standardstørrelsen ligger i `Innstillinger…`.
                """),
            .note("`⌘0` er IKKE standardstørrelsen — den tasten viser og skjuler sidepanelet."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Å vise usynlige tegn",
        summary: "Slå på én gruppe om gangen, for alle samtidig er som regel for mye.",
        keywords: ["usynlig", "blanktegn", "nbsp", "nullbredde", "tabulator"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Vis / skjul alle usynlige tegn")]),
            .paragraph("""
                Fire grupper slås på hver for seg, for å slå dem alle på samtidig begraver innholdet \
                under en skog av prikker.
                """),
            .table(
                headers: ["Gruppe", "Hva den fanger"],
                rows: [
                    ["Mellomrom", "Mellomrom i linjeslutt, ujevnt innrykk"],
                    ["Tabulatorer", "Filer som blander TAB med mellomrom"],
                    ["Linjeslutt", "Filer som blander CRLF med LF"],
                    ["NBSP · nullbredde · styretegn", "Usynlige tegn fra Word, fra nettet, fra regneark"],
                ]
            ),
            .warning("""
                Den siste gruppen er den som redder folk. Et hardt mellomrom (NBSP) limt inn fra en \
                nettside ser **nøyaktig** ut som et vanlig mellomrom, men det får hver \
                strengsammenligning og hvert filter til å bomme — og det finnes ingen måte å se det på \
                uten denne gruppen på.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV-modus og loggmodus",
        summary: "To fargeskjemaer som erstatter syntaksfarging, for to slags datafiler.",
        keywords: ["csv-modus", "loggmodus", "uthev", "kolonner", "loggnivå"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV-modus"),
            .paragraph("""
                Gir hver kolonne sin egen farge i **tekst**visningen, så du kan se hvilken celle som \
                har glidd en kolonne, uten å bytte til tabellen.
                """),
            .heading("Loggmodus"),
            .paragraph("""
                Farger etter **alvorlighetsgraden** den leser av linjen: feil røde, advarsler gule, \
                mens `debug` og `trace` dempes — de utgjør mesteparten av en loggfil, og å utheve dem \
                demper nettopp det du ser etter.
                """),
            .paragraph("`Filtrer logg etter nivå…` skjuler de nivåene du ikke trenger i det hele tatt."),
            .note("""
                Disse to farger **i stedet for** syntaksfarging, ikke oppå den. En loggfil har ingen \
                syntaks å farge, og to fargekilder som skriver til samme byteområde, etterlater ingen \
                forutsigbar vinner.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Binær visning",
        summary: "En hex-tabell for enhver fil — også en på 1 GB, som åpnes nesten øyeblikkelig.",
        keywords: ["hex", "binær", "byte", "forskyvning", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Vis ▸ Binær visning` viser hver byte som en tabell med tre spalter: **forskyvning · \
                hex · tekst**. Det virker for **enhver** fil på disken, ikke bare bilder eller video.
                """),
            .table(
                headers: ["Spalte", "Innhold"],
                rows: [
                    ["Forskyvning", "Byteposisjon, i heksadesimal"],
                    ["Hex", "16 byte per rad, delt etter den åttende for lettere telling"],
                    ["Tekst", "Skrivbare ASCII-byte; alt annet er et `.`"],
                ]
            ),
            .note("""
                Tekstspalten **dekoder ikke UTF-8**. En vietnamesisk bokstav tar to eller tre byte, så \
                å gjengi den ville skyve tekstspalten ut av linje med hex-spalten — og den linjen er \
                hele poenget med spalten. Bruk den vanlige visningen for å lese tekst med aksent.
                """),
            .heading("Store filer"),
            .paragraph("""
                Filen er **minnekartlagt**, så å åpne en fil på 1 GB i binær visning koster bare det \
                du ser på. Målt i selvtestsamlingen: **under et millisekund**.
                """),
            .paragraph("""
                Visningen viser **ett vindu på 4 MB** om gangen, og den øverste linjen sier hvilket \
                område du er i. Det er en grense i systemets tabelltegner, ikke i lesingen: en fil på 1 \
                GB er 62,5 millioner rader, og etter et visst punkt begynner rader å hoppe rundt under \
                rulling — og en hex-tabell som hopper, er ubrukelig.
                """),
            .heading("Å hoppe til en posisjon"),
            .table(
                headers: ["Skriv i forskyvningsfeltet", "Betydning"],
                rows: [
                    ["`1F400`", "Heksadesimal — standarden"],
                    ["`0x1F400`", "Det samme, med tydelig prefiks"],
                    ["`#128000`", "Desimal, når du har et byteantall og ikke en hex-forskyvning"],
                ]
            ),
            .bullets([
                "`‹` og `›` flytter til forrige / neste vindu.",
                "**Kopier markerte rader** kopierer nøyaktig det du ser — uten en markering kopierer det hele vinduet.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown-forhåndsvisning",
        summary: "Gjengi Markdown som formatert tekst — og si rett ut hva den ikke gjengir.",
        keywords: ["markdown", "forhåndsvisning", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("""
                Gjengitt med systemets Markdown-støtte: fet, kursiv, kode, lenker, lister.
                """),
            .warning("""
                **Ingen tabeller, og ingen syntaksfarging inne i kodeblokker.** \
                Forhåndsvisningsvinduet sier det nederst. Dokumenter større enn **4 MB** avvises.
                """),
            .paragraph("""
                Trenger du tabeller og diagrammer i et dokument du kan utgi? Det er det \
                `.greport.md`-rapporter er til, ikke denne forhåndsvisningen.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "To modi: View og Code",
        summary: "Én tast veksler mellom den gjengitte formen og den redigerbare kilden, for hver filtype.",
        keywords: ["view", "code", "modus", "kilde", "gjengitt", "forhåndsvisning"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Veksle mellom View og Code")]),
            .paragraph("""
                Kontrollen sitter i **linjen rett under faneraden** — samme sted for hver filtype: en \
                `View | Code`-bryter, og så navnet på den filens View-modus («Dokumentsider», \
                «Nøkkel–verdi-tre», «Diagram»…). En fil med bare én modus gjør bryteren grå, og linjen \
                sier hvorfor. I høyre kant sitter hver types egne knapper: `.xlsx` har **Tabell** \
                (redigerbar, skrives rett tilbake), `.pptx` har **Disposisjon**.
                """),
            .note("""
                **Word og PowerPoint oppfører seg som en dokumentleser.** Deres View-modus bygger \
                virkelige sider — riktige skrifter, størrelser og farger, med bilder, tabeller, \
                topptekst og bunntekst inkludert sidetall. En side er **nøyaktig så bred som rammen** \
                og kan zoomes. Excel er et bevisst unntak: dens View er et **redigerbart regneark**, \
                for et regneark har ingen papirstørrelse før det skrives ut.
                """),
            .note("""
                Til gjengjeld er sidene **skrivebeskyttet** og gjengir **kopien på disken**: rediger i \
                Code uten å lagre, og sidene viser den gamle versjonen — linjen sier det, med en knapp \
                `Lagre og gjengi på nytt`.
                """),
            .heading("Definisjoner"),
            .bullets([
                "**Code** er den **redigerbare kilden**. For en tekstfil er det teksten selv. For en binærfil — PDF, bilde, lyd, video — finnes det ingen tekstlig kilde, så Code er **bytene**, vist som hex.",
                "**View** er det som **gjengis** fra Code. Det kan være penere, kortere eller kjørbart — men det er alltid en følge, aldri originalen.",
            ]),
            .paragraph("""
                Å si *«denne typen har ingen Code»* om en PDF ville vært beleilig, men galt: bytene er \
                virkelig kilden dens.
                """),
            .heading("Hvor redigeringen skjer"),
            .paragraph("""
                Redigering skjer i **Code**. Det er nøyaktig **to unntak**, begge fordi det er langt \
                mer naturlig å redigere i View: **CSV-tabellceller** og **PDF-skjemafelt**. Begge \
                skriver rett inn i kilden, så det oppstår ingen andre kopier å krangle med.
                """),
            .heading("Etter filtype"),
            .table(
                headers: ["Filtype", "View", "Code", "Rediger i"],
                rows: [
                    ["CSV · TSV", "Tabell", "Rå tekst", "**Begge**"],
                    ["Excel `.xlsx`", "Tabell over det åpne arket", "Det arket som CSV", "**Begge**"],
                    ["PDF", "Gjengitte sider", "Binær", "**Begge** — kommentarer, skjemafelt, sider"],
                    ["Markdown `.md`", "Gjengitt tekst", "Markdown-kilde", "Code"],
                    ["Rapport `.greport.md`", "Rapport med kjørte spørringer og tegnede diagrammer", "Kilde", "Code"],
                    ["JSON", "Nøkkel–verdi-tre, kan foldes", "JSON-kilde", "Code"],
                    ["XML · HTML", "Merketre, kan foldes", "XML-kilde", "Code"],
                    ["YAML", "Nøkkel–verdi-tre etter innrykk", "YAML-kilde", "Code"],
                    ["Diagrammer `.mmd` · `.dot`", "Det tegnede diagrammet, som fyller fanen", "mermaid- eller DOT-kilde", "Code"],
                    ["Word `.docx`", "Gjengitte dokumentsider", "Uttrukket Markdown", "Code"],
                    ["PowerPoint `.pptx`", "Gjengitte lysbildesider", "Markdown-disposisjon", "Code"],
                    ["Loggfiler", "Farget etter nivå, kan filtreres", "Rå tekst", "Code"],
                    ["Bilder", "Bildet (animerte spilles av)", "Binær", "Skrivebeskyttet"],
                    ["Lyd · video", "En spiller", "Binær", "Skrivebeskyttet"],
                    ["Arkiver", "Innholdsliste", "Binær", "Skrivebeskyttet"],
                    ["Kildekode, ren tekst", "— ingen", "Teksten selv", "Code"],
                ]
            ),
            .note("""
                Kildekode har **ingen View**, og det er normalt heller enn en mangel: en Swift-fil har \
                ingen gjengitt form som er verdt å se på.
                """),
            .heading("Sideleseren for Word og PowerPoint"),
            .paragraph("""
                Sidene stables loddrett og ruller sammenhengende, hver som et hvitt ark på grå \
                bakgrunn — som i enhver dokumentleser. Kontrollene sitter til høyre i linjen.
                """),
            .table(
                headers: ["Knapp / tast", "Hva den gjør"],
                rows: [
                    ["`Tilpass bredde`", "Arket er nøyaktig så bredt som rammen — standarden"],
                    ["`Tilpass side`", "Hele arket får plass i rammen"],
                    ["`−` `+`", "Zoom i trinn; eller knip, eller ⌘ + rulling"],
                    ["`Søk`-feltet, eller ⌘F", "Søk inne i sidene, hopp dit og uthev"],
                    ["Enter i søkefeltet", "Neste treff"],
                    ["Dra", "Marker tekst; dobbeltklikk for et ord, trippelklikk for et avsnitt"],
                    ["⌘A · ⌘C", "Marker alt · kopier markeringen"],
                    ["Page Up · Page Down · Home · End", "Beveg deg gjennom dokumentet"],
                ]
            ),
            .paragraph("""
                Søkefeltet **ser bort fra aksenter og store/små bokstaver**: å skrive `vuong quoc` \
                finner `Vương quốc`. Merkelappen «Side 12/363» i linjen sier hvor du er.
                """),
            .note("""
                **Det som ikke gjengis, sagt rett ut:** flytende forankrede bilder (tekst som bryter \
                rundt et bilde) vises som innebygde bilder; fotnoter, diagrammer og PowerPoints \
                SmartArt tegnes ikke. Når du trenger nøyaktig samsvar med det trykte, åpne det i Word.
                """),
            .heading("Å klikke på en node hopper tilbake til kilden"),
            .paragraph("""
                Et JSON-tre er ikke en pen utskrift: å klikke på en node flytter markøren **til den \
                nodens VERDI** i teksten og fører fanen tilbake til Code — for det du vil neste gang, \
                er nesten alltid å redigere det du nettopp klikket på.
                """),
            .bullets([
                "Beholdernoder viser **antall elementer** (`{12}`, `[340]`) i stedet for innholdet — det er det som svarer på «er dette verdt å åpne».",
                "**De to første nivåene** er foldet ut: å folde en fil med ti tusen noder helt ut gir en liste lengre enn kilden, mens å folde den helt sammen betyr at man må klikke for i det hele tatt å oppdage noe.",
                "En fil med **ugyldig syntaks** får ikke et halvt tre — et avkortet tre ser ut som et dokument som rett og slett inneholder så lite.",
                "I et XML-tre bærer attributter et `@`-prefiks i korrekt XPath-notasjon, og **blanktegn mellom merker blir ikke en node** — det er formatering, ikke innhold.",
                "Et YAML-tre leser **flerdokumentfiler** (`---`): hvert dokument er sin egen rot. Samlinger skrevet på én linje (`ports: [80, 443]`) forblir ett blad — du ser allerede alt, og å folde ut ville kostet et klikk. **Innrykk med tabulatorer** meldes med den nøyaktige linjen: det er en YAML-feil øyet ikke ser.",
                "PowerPoint-disposisjonen bygges av den **åpne teksten**, ikke av filen på disken: har du nettopp redigert disposisjonen i Code, må treet beskrive den nye versjonen og nodene hoppe inn i den nye versjonen. Talernotater foldes til én node, så et lysbilde som sier mye, ikke ser ut som et lysbilde som inneholder mye.",
                "**Et diagram som fyller fanen, følger samme regel**: klikk på en node, og du er tilbake i Code med markøren på den nodens erklæring. I sidepanelet `Mermaid Studio` lukkes ikke fanen — redigereren er rett der, og å flytte markøren er nok til å se det.",
                "Diagrammer **åpnes også der du står**: elementet som svarer til markørens linje, uthevet i samme øyeblikk fanen dukker opp, så du slipper å lete etter det.",
            ]),
            .heading("Filterfeltet: i et tre med ti tusen noder er søking selve jobben"),
            .paragraph("""
                Rett under nodeantallet sitter et filterfelt. Skriv i det, og treet beholder bare de \
                nodene som passer — **sammen med stien fra roten ned til dem**, for når en nøkkel \
                `name` dukker opp ti ulike steder, er det virkelige spørsmålet «hvilken», og bare \
                grenen som inneholder den, svarer på det. Resten foldes ut for deg: å få deg til å \
                klikke opp hvert nivå ville være å få deg til å filtrere på nytt for hånd.
                """),
            .bullets([
                "Det filtrerer på **både merkelapper og verdier**: å søke `Huế` er like vanlig som å søke etter nøkkelen `province`.",
                "**Skrift uten aksenter treffer likevel tekst med aksent** — `da nang` finner `Đà Nẵng`. Samme sammenligning som CSV-tabellens filter og funksjonslistens, så du slipper å huske tre søkeregler i ett program.",
                "Uten treff sier overskriften **«Ingen resultater»** heller enn å la deg stirre på et tomt tre og lure på om filen er ødelagt.",
                "Å bytte fil eller gå inn i View igjen **tømmer filteret**: et tre som åpnes allerede avkortet, uten at noe forklarer hvorfor, er den mest forvirrende tilstanden av alle.",
            ]),
            .heading("Hele treet virker fra tastaturet"),
            .paragraph("""
                Når du går inn i View, flyttes fokus til treet; du trenger ikke å klikke på det først. \
                Opp og ned beveger seg mellom noder, venstre og høyre folder sammen og ut, og to taster \
                avslutter en visning — med **ulik** virkning:
                """),
            .bullets([
                "**Enter** — gå til den valgte noden: tilbake til Code med markøren inne i den nodens byteområde. Nøyaktig som å klikke på den.",
                "**Tab** — veksle mellom treet og filterfeltet.",
                "**⌘C** — kopierer den valgte nodens **sti**, ikke teksten bak treet. JSON og YAML gir JSONPath (`$.customer['name']`) som kan limes rett inn i dette produktets eget JSONPath-felt eller i `yq`; XML gir XPath (`/order/item[2]/@code`) med indekser når to merker deler navn; en PowerPoint-disposisjon kopierer linjens tekst, for en disposisjon har ikke noe stispråk å finne på.",
                "**Esc** — veien tilbake: tilbake til Code med markøren **nøyaktig der den var**. Du så på et tre, du reiste ikke noe sted.",
            ]),
            .heading("Og den andre veien: treet åpnes der markøren står"),
            .paragraph("""
                Å gå inn i View midt i en fil på ti tusen linjer åpner **ikke** treet på toppen: det \
                folder ut stien ned til noden som svarer til der markøren var, og velger den. Dette er \
                den andre halvdelen av hopp-til-kilde — uten det ville View og Code vært to visninger \
                av ett dokument i bare **én** retning.
                """),
            .bullets([
                "Det folder ut **dypere enn to nivåer** når det trengs: toårsregelen svarer på «hvordan ser denne filen ut», mens spørsmålet her er et annet — «hvor er jeg i dette treet».",
                "En markør på en **nøkkel** (`\"address\":`) velger den oppføringen, selv om nodens byteområde bare dekker verdien. Tekst umiddelbart før en node hører til den noden.",
                "En markør ved **begynnelsen av en blokk** — en YAML-blokks nøkkel, en lysbildetittel, et XML-merkenavn — velger den blokken heller enn å dykke ned til dens første barn.",
                "Å gå inn i View **flytter ikke markøren**. Forlat View, og du er nøyaktig der du var; View er en måte å se på, ikke en kommando som endrer posisjon.",
            ]),
            .heading("Ingen type mangler lenger en View"),
            .paragraph("""
                **Hver filtype med plass til en View-modus gjengir nå en.** Listen over manglende typer \
                ble tom og ble fjernet.

                Kildekode og ren tekst har fortsatt ingen View — det er normalt, ikke en mangel, så de \
                sto aldri på den listen.

                Kommer det en ny filtype hvis View ikke er bygd ennå, vil vekslekommandoen si det og \
                navngi det som mangler, heller enn å åpne en tom ramme — en tom ramme er et tomt løfte, \
                mens et avslag med et navn er informasjon.
                """),
            .heading("De seks eldre kommandoene finnes fortsatt"),
            .paragraph("""
                `Tabell/tekstvisning`, `Markdown-forhåndsvisning`, `Binær visning`, \
                `Rapportforhåndsvisning`, `Mermaid-diagramforhåndsvisning`, `Loggmodus` — alle blir \
                nøyaktig der de var. `⌥⌘V` er en **felles inngang**, ikke en erstatning.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamesisk

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamesisk",
        summary: "Gamle tegnkodinger, Unicode-normalisering, aksentufølsomt søk og inndatametoder.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnamesiske tegnkodinger",
        summary: "Les og skriv TCVN3, VISCII, VNI-Windows og 33 andre, gjenkjent av seg selv.",
        keywords: ["tegnkoding", "tcvn3", "abc", "viscii", "vni", "rot"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Åpnet en gammel vietnamesisk fil og fikk `Tr¦êng §¹i häc` i stedet for `Trường Đại \
                học`? Filen er ikke ødelagt — den ble lagret i en tegnkoding fra før Unicode.
                """),
            .steps([
                "Klikk på tegnkodingen på **statuslinjen** (eller `Format ▸ Tegnkoding…`).",
                "Velg den rette — for gamle vietnamesiske filer er det som regel `TCVN3 (ABC)`, `VNI-Windows` eller `VISCII`.",
                "Teksten retter seg selv umiddelbart; det er ikke nødvendig å åpne filen igjen.",
                "For å beholde det slik: `Lagre som…` med tegnkodingen `UTF-8`.",
            ]),
            .heading("De tre gamle vietnamesiske tegnkodingene"),
            .table(
                headers: ["Tegnkoding", "Finnes som regel i"],
                rows: [
                    ["TCVN3 (ABC)", "Offentlig papirarbeid og eldre Word-dokumenter i nord"],
                    ["VNI-Windows", "Forlag, aviser og trykkerier — vanlig i sør"],
                    ["VISCII", "Tidlig e-post og Usenet"],
                ]
            ),
            .paragraph("""
                GEditor **gjenkjenner tegnkodingen** ved åpning. Gjetter den galt, retter ett klikk \
                det, og innholdet dekodes på nytt heller enn å lappes bokstav for bokstav.
                """),
            .warning("""
                Å skrive ut til en gammel tegnkoding mister de tegnene den kodingen ikke har. GEditor \
                **teller dem og sier det på forhånd** — for eksempel *«12 tegn finnes ikke i TCVN3»* — \
                i stedet for stille å gjøre dem om til spørsmålstegn.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Linjeslutt",
        summary: "LF, CRLF, CR — konvertert for hele filen med ett klikk.",
        keywords: ["eol", "crlf", "lf", "linjeslutt", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Stil", "Brukes av", "Byte"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac før 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Den gjeldende stilen vises på statuslinjen; klikk på den for å endre. En fil som \
                **blander** to stiler, meldes også der — slå på `Vis usynlige ▸ Linjeslutt` for å se \
                nøyaktig hvor.
                """),
            .note("Linjesluttstilen for **nye** filer settes i `Innstillinger…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode-normalisering",
        summary: "Hvorfor et søk etter «ế» noen ganger ikke finner noe, og hvordan man retter en hel fil.",
        keywords: ["unicode", "nfc", "nfd", "sammensatt", "oppdelt", "normaliser", "ingen treff"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                I Unicode kan `ế` skrives på **to ulike måter**: som ett forhåndssammensatt kodepunkt \
                (NFC), eller som `e` pluss to separate tegn (NFD). På skjermen ser de like ut; for en \
                maskin er de ulike strenger.
                """),
            .paragraph("""
                Følgen: et søk etter `ế` i en NFD-fil finner **ingenting**, og brukeren slutter at \
                dataene ikke er der.
                """),
            .steps([
                "`Format ▸ Normaliser Unicode…`",
                "Velg **NFC** (forhåndssammensatt) — formen nesten alt annet bruker.",
                "Bruk. Det er ett angretrinn.",
            ]),
            .note("""
                Filer som kommer fra macOS, er ofte NFD, fordi Apples filsystem lagrer filnavn slik. \
                Dette er den desidert vanligste grunnen til at data kopiert ut av Finder ikke lar seg \
                finne igjen.
                """),
            .paragraph("""
                Det finnes en bryter **normaliser til NFC ved lagring** i `Innstillinger…`. Av som \
                standard, fordi den endrer filens byte.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Å skrive uten aksenter finner likevel tekst med aksent",
        summary: "Hvert søke- og filterfelt sammenligner med aksentene fjernet.",
        keywords: ["aksenter", "diakritiske tegn", "søk", "filter", "uten aksent"],
        blocks: [
            .paragraph("""
                Skriv `hue` for å finne `Huế`. Skriv `da nang` for å finne `Đà Nẵng`. Regelen gjelder \
                CSV-tabellens filter, funksjonssøket, hjelpesøket og de øvrige filterfeltene.
                """),
            .note("""
                `Đ` behandles særskilt, for i Unicode er det **en bokstav i seg selv** og ikke en `D` \
                med et tegn på — vanlig aksentfjerning rører den ikke.
                """),
            .paragraph("""
                CSV-filteret tar også imot et `=`-prefiks for nøyaktig sammenligning. `=`-formen er \
                **også aksentufølsom**, for et filter som skiller aksenter, etterlater brukeren i den \
                tro at dataene mangler.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnamesiske inndatametoder",
        summary: "EVKey, OpenKey, Unikey og macOS' egen inndatakilde skriver alle rett inn i dokumentet.",
        keywords: ["ime", "evkey", "unikey", "openkey", "telex", "vni", "inndatametode"],
        blocks: [
            .paragraph("""
                Ingenting å stille inn. Telex og VNI virker begge, også på tvers av **flere markører** \
                — skriv én gang, og hver markør får den riktig aksentuerte bokstaven.
                """),
            .paragraph("""
                Søkefelt, filterfelt og hver dialog tar imot inndatametoden akkurat som redigereren.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Språk og formater

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Språk og formater",
        summary: "Tjue innebygde språk, selvdefinerte språk og verktøy for JSON · XML · YAML · logger.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Tjue innebygde språk",
        summary: "Farging fra et virkelig syntakstre, med hvert språks egne kommentartegn.",
        keywords: ["syntaks", "uthevning", "språk", "tree-sitter", "grammatikk"],
        blocks: [
            .paragraph("""
                Språket gjenkjennes fra **filendelsen** (pluss noen få spesielle navn som `Makefile`, \
                `Dockerfile`, `Gemfile`). Du kan endre det for hånd på statuslinjen.
                """),
            .table(
                headers: ["Språk", "Endelser", "Linje- · blokkommentar"],
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
                Den siste spalten er det `⌘/` bruker. Språk uten en linjekommentar (JSON, CSS, XML) \
                får blokkformen i stedet.
                """),
            .heading("Hva som følger med et syntakstre"),
            .bullets([
                "**Funksjonslisten** i sidepanelet følger den virkelige oppbygningen, ikke gjetninger ut fra innrykk.",
                "**Sammenfolding** etter oppbygning.",
                "**Parentesmatching** som hopper over parenteser inne i strenger og kommentarer.",
                "**Automatisk innrykk** som legger til et nivå etter `{`, og etter `:` i Python og YAML.",
            ]),
            .note("""
                Tre tunge grammatikker (C++, C#, Ruby) bor i et **lat innlastet** bibliotek — de lastes \
                bare når du åpner en fil i ett av de språkene. Slik holdes oppstartstiden under et \
                halvt sekund.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Selvdefinerte språk",
        summary: "Farg ditt eget format med én JSON-fil — ingen grammatikk å skrive.",
        keywords: ["udl", "selvdefinert språk", "eget språk", "egen logg"],
        blocks: [
            .paragraph("""
                Et firmas interne loggformat, et privat konfigurasjonsspråk, et lite DSL — ingen av dem \
                har en tree-sitter-grammatikk, og å skrive en krever en kompilator og litt \
                parseringsteori.
                """),
            .paragraph("""
                I stedet tar GEditor imot en **tabellstyrt lekser** erklært i JSON. Legg filen i mappen \
                `grammars/` inne i GEditors konfigurasjonsmappe, og start på nytt.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — et helt språk",
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
            .heading("Hver nøkkel"),
            .table(
                headers: ["Nøkkel", "Type", "Betydning"],
                rows: [
                    ["`name`", "streng", "Navnet som vises på statuslinjen"],
                    ["`extensions`", "liste av strenger", "Filendelser, **uten punktum**"],
                    ["`caseSensitive`", "boolsk", "Om nøkkelord skiller store og små bokstaver"],
                    ["`lineComment`", "streng", "Tegn for kommentar til linjens slutt; utelat hvis det ikke finnes"],
                    ["`blockComment`", "liste av 2 strenger", "`[åpne, lukke]`"],
                    ["`stringDelimiters`", "liste av strenger", "Hvert element er **ett** tegn som åpner/lukker en streng"],
                    ["`escapeCharacter`", "streng", "Unnvikelsestegn inne i strenger; tomt betyr at språket ikke har et"],
                    ["`keywordGroups`", "objekt", "Gruppenavn → nøkkelordliste; tre grupper får tre farger"],
                ]
            ),
            .paragraph("""
                De tre gruppenavnene som får sine egne farger, er `keyword`, `type` og `constant`.
                """),
            .warning("""
                Denne lekseren **forstår ikke nesting**. Strukturell sammenfolding, funksjonslisten og \
                smart parentesmatching forblir forbeholdt de tjue innebygde språkene. Det er en bevisst \
                byttehandel: til gjengjeld erklærer du et språk på ti minutter i stedet for på en dag.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON-verktøy",
        summary: "Omformater, komprimer, sorter nøkler, og kontroller mot et JSON Schema.",
        keywords: ["json", "format", "komprimer", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Kommando", "Hva den gjør"],
                rows: [
                    ["Omformater", "Bryter og rykker inn for lesing"],
                    ["Komprimer", "Fjerner alle overflødige blanktegn"],
                    ["Sorter nøkler", "Setter hvert objekts nøkler i alfabetisk orden — så to JSON-filer kan **sammenlignes**"],
                    ["Kontroller mot JSON Schema…", "Kontrollerer dokumentet mot en skjemafil og lister hvert problem med linjenummer"],
                ]
            ),
            .paragraph("""
                Reglene som brukes, er **streng RFC 8259**: ingen etterfølgende komma, ingen \
                kommentarer, ingen `NaN`. En syntaksfeil peker på nøyaktig linje og kolonne.
                """),
            .note("""
                **JSONL**-filer (ett objekt per linje) gjenkjennes også og har sitt eget verktøysett i \
                kapittelet om kunnskapspakken.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath-spørringer",
        summary: "Trekk ut nøyaktig den delen du trenger av en stor JSON-fil.",
        keywords: ["jsonpath", "json-spørring", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Skriv et uttrykk; resultatene vises som en liste du kan hoppe inn i."),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`$`", "Dokumentets rot"],
                    ["`$.name`", "Nøkkelen `name` ved roten"],
                    ["`$.orders[0]`", "Første element i en liste"],
                    ["`$.orders[*].total`", "Nøkkelen `total` i **hvert** element"],
                    ["`$..province`", "Nøkkelen `province` på **enhver dybde**"],
                    ["`$.orders[1:3]`", "Et utsnitt: element 1 og 2"],
                ]
            ),
            .code(language: "text", caption: "Hver ordres provinskode, uansett hvor dypt nestet",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML-verktøy",
        summary: "Omformater, komprimer, kontroller syntaks, og kontroller mot en DTD eller XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "kontroller", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Kommando", "Hva den gjør"],
                rows: [
                    ["Omformater", "Rykker inn etter merkedybde"],
                    ["Komprimer", "Fjerner blanktegn mellom merker"],
                    ["Kontroller syntaks", "Manglende sluttmerker, feil nesting, ugyldige tegn"],
                    ["Kontroller mot DTD/XSD…", "Kontrollerer mot et skjema og melder hvert problem med linjenummer"],
                    ["Evaluer XPath…", "Kjører et XPath-uttrykk; resultatene åpnes i en ny fane"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Skriv et uttrykk, og resultatene åpnes som **en tekstfane**, én node per linje. For \
                eksempel: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Resultatene hopper IKKE til en posisjon i kildefilen.** Systemets XPath-evaluator \
                bygger sitt eget tre og tar ikke vare på hver nodes byteposisjon, så det som kommer \
                tilbake, er INNHOLD heller enn koordinater. For å nå det nøyaktige stedet, bruk `⌘F` på \
                strengen du nettopp fant.
                """),
            .paragraph("""
                I `.xml`- og `.html`-filer får det å skrive `>` for å avslutte et åpningsmerke \
                **sluttmerket til å dukke opp** med markøren mellom de to. Selvlukkende merker \
                (`<br/>`), erklæringer (`<?xml …?>`) og kommentarer gjør ikke det — de har ingenting å \
                lukke.
                """),
            .warning("""
                Å omformatere XML **endrer blanktegnene mellom merker**. I dokumenter der de \
                blanktegnene betyr noe — XHTML med tekst inne i merker, for eksempel — endrer dette hva \
                som vises. Det er ett angretrinn, så `⌘Z` reverserer det.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML-kontroll",
        summary: "Fang de to vanligste YAML-feilene: gjentatte nøkler og tabulatorinnrykk.",
        keywords: ["yaml", "yml", "lint", "gjentatt nøkkel", "innrykk"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Gjentatte nøkler** i én avbildning — de fleste YAML-lesere tar den **siste** og dropper stille de tidligere, så en konfigurasjonsfil kan oppføre seg helt annerledes enn du venter.",
                "**Tabulatorinnrykk** — YAML forbyr tabulatorer i innrykk, og bibliotekenes feilmeldinger om det er som regel uforståelige.",
            ]),
            .note("Slå på `Vis usynlige ▸ Tabulatorer` for straks å se hvilket blanktegn som er en tabulator."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Loggfiler",
        summary: "Sju alvorlighetsgrader, filtrering etter nivå, og hvordan man leser en svært stor logg.",
        keywords: ["logg", "feil", "advarsel", "filter", "nivå"],
        blocks: [
            .paragraph("""
                Slå på `Vis ▸ Loggmodus (farg etter nivå)`. GEditor leser alvorlighetsgraden fra **hver \
                linjes begynnelse** — etter tidsstempelet og prosessnavnet.
                """),
            .table(
                headers: ["Nivå", "Farge"],
                rows: [
                    ["CRITICAL · ERROR", "Rød"],
                    ["WARNING", "Gul"],
                    ["NOTICE", "Aksentfarge"],
                    ["INFO", "Vanlig tekst"],
                    ["DEBUG · TRACE", "Dempet"],
                ]
            ),
            .paragraph("""
                `Filtrer logg etter nivå…` skjuler de lavere nivåene helt. Linjer hvis nivå **ikke \
                gjenkjennes** — en fortsettelse av et stakkspor, for eksempel — lar den være i fred \
                heller enn å gi dem den forrige linjens nivå.
                """),
            .heading("Å lese en stor logg, trinn for trinn"),
            .steps([
                "Åpne filen — også i gigabyteskala åpnes den nesten øyeblikkelig.",
                "`Vis ▸ Loggmodus` for å se de røde flekkene.",
                "`⌥⌘M` for dokumentkartet: er det røde klumpet ett sted eller spredt gjennom filen?",
                "`⌘F` etter feilkoden, `⌘M` for å merke hver linje som passer.",
                "`Søk ▸ Kopier merkede linjer` for å dra dem over i en ny fane.",
                "Kjører den fortsatt? `Fil ▸ Følg fil (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
