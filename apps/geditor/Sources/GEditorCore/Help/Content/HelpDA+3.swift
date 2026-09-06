import Foundation

/// Dansk hjælpeindhold — del 3: visninger, vietnamesisk samt sprog og formater.
extension HelpDA {

    static let views = HelpChapter(
        id: "xem",
        title: "Måder at se et dokument på",
        summary: "Sidepanel, kort, sammenfoldning, delt visning, ombrydning, usynlige tegn, farvelægningstilstande.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Sidepanel og funktionsliste",
        summary: "Mappetræet og den åbne fils funktionsliste, i én spalte.",
        keywords: ["sidepanel", "funktionsliste", "disposition", "filtræ"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Vis / skjul sidepanelet")]),
            .paragraph("""
                Funktionslisten bygges ud fra sprogets **syntakstræ**, så den følger den virkelige \
                opbygning i stedet for at gætte ud fra indrykningen. Klik på et punkt for at springe \
                derhen.
                """),
            .note("Filterfeltet i funktionslisten **finder tekst med accent ud fra skrift uden accent**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Dokumentkort",
        summary: "Hele filen i en smal spalte til højre — også ved hundredvis af MB.",
        keywords: ["minikort", "kort", "oversigt"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Vis / skjul dokumentkortet")]),
            .paragraph("""
                Kortet beskriver **hele filen**, ikke kun det, der er på skærmen. At trække på det \
                springer til det tilsvarende sted.
                """),
            .paragraph("""
                Søgetræf og mærkede linjer vises på kortet, så du kan se, om de er spredte eller \
                klumpede, før du ruller derhen.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Sammenfoldning",
        summary: "Fold funktioner, blokke og lister sammen efter opbygning — eller fold filen til et niveau.",
        keywords: ["fold", "kodefoldning", "sammenfold"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Fold / fold ud blokken ved markøren"),
                HelpShortcut("⌥⇧⌘←", "Fold alt"),
                HelpShortcut("⌥⌘→", "Fold alt ud"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Fold hele filen til niveau 1…8"),
            ]),
            .paragraph("""
                For sprog med et syntakstræ følger sammenfoldningen den **virkelige opbygning**. For \
                filer uden en grammatik følger den indrykningen.
                """),
            .paragraph("""
                `Fold til niveau` gør sig fortjent på dyb JSON og YAML: at folde til niveau 2 sætter \
                hele filens form på én skærm.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Delt visning",
        summary: "To ruder side om side, til to filer — eller to steder i én fil.",
        keywords: ["del", "ruder", "sammenlign"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Del lodret"),
                HelpShortcut("⌥⌘-", "Del vandret"),
                HelpShortcut("⌥⌘0", "Fjern delingen"),
                HelpShortcut("⌥⌘]", "Åbn dette faneblad i den anden rude"),
                HelpShortcut("⌥⌘[", "Spring til den anden rude"),
            ]),
            .paragraph("""
                Hver rude har sin egen fanebladslinje. At åbne **samme fil** i begge ruder er fint — de \
                ruller uafhængigt, hvilket gør det let at sammenligne toppen og bunden af en fil.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Ombrydning",
        summary: "Tre tilstande: fra, ved vinduets kant eller ved en fast kolonne.",
        keywords: ["ombrydning", "linjeombrydning", "blød ombrydning"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Tilstand", "En lang linje"],
                rows: [
                    ["Fra", "Ruller vandret"],
                    ["Ved vinduet", "Ombrydes ved vinduets kant og følger dets størrelse"],
                    ["Ved en kolonne", "Ombrydes ved den kolonne, du sætter — f.eks. 80 eller 100"],
                ]
            ),
            .paragraph("""
                Ombrydning er en **måde at se på**, ikke en redigering: der indsættes intet linjeskift, \
                og det kommer aldrig i fortrydelseshistorikken.
                """),
            .note("Den hurtige vej hertil er feltet `Ombryd: …` på statuslinjen."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Skriftstørrelse",
        summary: "Zoom mellem 8 og 32 pt.",
        keywords: ["zoom", "skriftstørrelse", "større", "mindre"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Større tekst"),
                HelpShortcut("⌘-", "Mindre tekst"),
                HelpShortcut("⌃⌘0", "Tilbage til standardstørrelsen"),
            ]),
            .paragraph("""
                Begrænset til mellem 8 og 32 pt. Også dette er en **måde at se på**: ingen redigering, \
                intet i fortrydelseshistorikken. Standardstørrelsen findes i `Indstillinger…`.
                """),
            .note("`⌘0` er IKKE standardstørrelsen — den tast viser og skjuler sidepanelet."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "At vise usynlige tegn",
        summary: "Slå én gruppe til ad gangen, for alle på én gang er som regel for meget.",
        keywords: ["usynlig", "blanktegn", "nbsp", "nulbredde", "tabulator"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Vis / skjul alle usynlige tegn")]),
            .paragraph("""
                Fire grupper slås til hver for sig, for at slå dem alle til på én gang begraver \
                indholdet under en skov af prikker.
                """),
            .table(
                headers: ["Gruppe", "Hvad den fanger"],
                rows: [
                    ["Mellemrum", "Mellemrum i linjeslutningen, ujævn indrykning"],
                    ["Tabulatorer", "Filer, der blander TAB med mellemrum"],
                    ["Linjeslutninger", "Filer, der blander CRLF med LF"],
                    ["NBSP · nulbredde · styretegn", "Usynlige tegn fra Word, fra nettet, fra regneark"],
                ]
            ),
            .warning("""
                Den sidste gruppe er den, der redder folk. Et hårdt mellemrum (NBSP) indsat fra en \
                webside ser **præcis** ud som et almindeligt mellemrum, men det får hver \
                strengsammenligning og hvert filter til at ramme forbi — og der er ingen måde at se \
                det på uden denne gruppe slået til.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV-tilstand og logtilstand",
        summary: "To farveskemaer, der erstatter syntaksfarvning, til to slags datafiler.",
        keywords: ["csv-tilstand", "logtilstand", "fremhæv", "kolonner", "logniveau"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV-tilstand"),
            .paragraph("""
                Giver hver kolonne sin egen farve i **tekst**visningen, så du kan se, hvilken celle der \
                er rykket en kolonne, uden at skifte til tabellen.
                """),
            .heading("Logtilstand"),
            .paragraph("""
                Farver efter den **alvorsgrad**, den læser af linjen: fejl røde, advarsler ravgule, \
                mens `debug` og `trace` dæmpes — de udgør det meste af en logfil, og at fremhæve dem \
                dæmper netop det, du leder efter.
                """),
            .paragraph("`Filtrér log efter niveau…` skjuler de niveauer, du slet ikke har brug for."),
            .note("""
                Disse to farver **i stedet for** syntaksfarvning, ikke oven på den. En logfil har ingen \
                syntaks at farve, og to farvekilder, der skriver til samme byteområde, efterlader ingen \
                forudsigelig vinder.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Binær visning",
        summary: "En hex-tabel for enhver fil — også en på 1 GB, der åbner næsten øjeblikkeligt.",
        keywords: ["hex", "binær", "byte", "position", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Vis ▸ Binær visning` viser hver byte som en tabel med tre spalter: **position · hex · \
                tekst**. Det virker for **enhver** fil på disken, ikke kun billeder eller video.
                """),
            .table(
                headers: ["Spalte", "Indhold"],
                rows: [
                    ["Position", "Byteposition, i hexadecimal"],
                    ["Hex", "16 bytes pr. række, delt efter den ottende for lettere tælling"],
                    ["Tekst", "Skrivbare ASCII-bytes; alt andet er et `.`"],
                ]
            ),
            .note("""
                Tekstspalten **afkoder ikke UTF-8**. Et vietnamesisk bogstav fylder to eller tre bytes, \
                så at gengive det ville skubbe tekstspalten ud af flugt med hex-spalten — og den flugt \
                er hele meningen med spalten. Brug den almindelige visning til at læse tekst med accent.
                """),
            .heading("Store filer"),
            .paragraph("""
                Filen er **hukommelsesafbildet**, så at åbne en fil på 1 GB i binær visning koster kun \
                det, du ser på. Målt i selvprøvesamlingen: **under et millisekund**.
                """),
            .paragraph("""
                Visningen viser **ét vindue på 4 MB** ad gangen, og den øverste linje siger, hvilket \
                område du er i. Det er en grænse i systemets tabelgengiver, ikke i læsningen: en fil på \
                1 GB er 62,5 millioner rækker, og over et vist punkt begynder rækker at hoppe rundt \
                under rulning — og en hex-tabel, der hopper, er ubrugelig.
                """),
            .heading("At springe til en position"),
            .table(
                headers: ["Skriv i positionsfeltet", "Betydning"],
                rows: [
                    ["`1F400`", "Hexadecimal — standarden"],
                    ["`0x1F400`", "Det samme, med tydeligt præfiks"],
                    ["`#128000`", "Decimal, når du har et byteantal frem for en hex-position"],
                ]
            ),
            .bullets([
                "`‹` og `›` flytter til forrige / næste vindue.",
                "**Kopiér markerede rækker** kopierer præcis det, du ser — uden en markering kopierer det hele vinduet.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown-forhåndsvisning",
        summary: "Gengiv Markdown som formateret tekst — og sig lige ud, hvad den ikke gengiver.",
        keywords: ["markdown", "forhåndsvisning", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("""
                Gengivet med systemets Markdown-understøttelse: fed, kursiv, kode, links, lister.
                """),
            .warning("""
                **Ingen tabeller og ingen syntaksfarvning inde i kodeblokke.** Forhåndsvisningen siger \
                det nederst. Dokumenter større end **4 MB** afvises.
                """),
            .paragraph("""
                Har du brug for tabeller og diagrammer i et dokument, du kan udgive? Det er det, \
                `.greport.md`-rapporter er til, ikke denne forhåndsvisning.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "To tilstande: View og Code",
        summary: "Én tast skifter mellem den gengivne form og den redigerbare kilde, for hver filtype.",
        keywords: ["view", "code", "tilstand", "kilde", "gengivet", "forhåndsvisning"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Skift mellem View og Code")]),
            .paragraph("""
                Betjeningen sidder i **linjen lige under fanebladsrækken** — samme sted for hver \
                filtype: en `View | Code`-kontakt og så navnet på den fils View-tilstand \
                (»Dokumentsider«, »Nøgle-værdi-træ«, »Diagram«…). En fil med kun én tilstand gør \
                kontakten grå, og linjen siger hvorfor. I højre kant sidder hver types egne knapper: \
                `.xlsx` har **Tabel** (redigerbar, skrives direkte tilbage), `.pptx` har **Disposition**.
                """),
            .note("""
                **Word og PowerPoint opfører sig som en dokumentlæser.** Deres View-tilstand bygger \
                virkelige sider — rigtige skrifter, størrelser og farver, med billeder, tabeller, \
                sidehoveder og sidefødder inklusive sidetal. En side er **præcis så bred som rammen** \
                og kan zoomes. Excel er en bevidst undtagelse: dens View er et **redigerbart regneark**, \
                for et regneark har ingen papirstørrelse, før det udskrives.
                """),
            .note("""
                Til gengæld er sider **skrivebeskyttede** og gengiver **kopien på disken**: redigér i \
                Code uden at gemme, og siderne viser den gamle udgave — linjen siger det, med en knap \
                `Gem og gengiv igen`.
                """),
            .heading("Definitioner"),
            .bullets([
                "**Code** er den **redigerbare kilde**. For en tekstfil er det teksten selv. For en binær fil — PDF, billede, lyd, video — findes der ingen tekstlig kilde, så Code er **bytes**, vist som hex.",
                "**View** er det, der **gengives** ud fra Code. Det kan være pænere, kortere eller kørbart — men det er altid en følge, aldrig originalen.",
            ]),
            .paragraph("""
                At sige *»denne type har ingen Code«* om en PDF ville være bekvemt, men forkert: dens \
                bytes er virkelig dens kilde.
                """),
            .heading("Hvor redigeringen sker"),
            .paragraph("""
                Redigering sker i **Code**. Der er præcis **to undtagelser**, begge fordi det er langt \
                mere naturligt at redigere i View: **CSV-tabelceller** og **PDF-formularfelter**. Begge \
                skriver direkte i kilden, så der opstår ingen anden kopi at skændes med.
                """),
            .heading("Efter filtype"),
            .table(
                headers: ["Filtype", "View", "Code", "Redigér i"],
                rows: [
                    ["CSV · TSV", "Tabel", "Rå tekst", "**Begge**"],
                    ["Excel `.xlsx`", "Tabel over det åbne ark", "Det ark som CSV", "**Begge**"],
                    ["PDF", "Gengivne sider", "Binært", "**Begge** — kommentarer, formularfelter, sider"],
                    ["Markdown `.md`", "Gengivet tekst", "Markdown-kilde", "Code"],
                    ["Rapport `.greport.md`", "Rapport med kørte forespørgsler og tegnede diagrammer", "Kilde", "Code"],
                    ["JSON", "Nøgle-værdi-træ, kan foldes", "JSON-kilde", "Code"],
                    ["XML · HTML", "Mærketræ, kan foldes", "XML-kilde", "Code"],
                    ["YAML", "Nøgle-værdi-træ efter indrykning", "YAML-kilde", "Code"],
                    ["Diagrammer `.mmd` · `.dot`", "Det tegnede diagram, der fylder fanebladet", "mermaid- eller DOT-kilde", "Code"],
                    ["Word `.docx`", "Gengivne dokumentsider", "Udtrukket Markdown", "Code"],
                    ["PowerPoint `.pptx`", "Gengivne diassider", "Markdown-disposition", "Code"],
                    ["Logfiler", "Farvet efter niveau, kan filtreres", "Rå tekst", "Code"],
                    ["Billeder", "Billedet (animerede afspilles)", "Binært", "Skrivebeskyttet"],
                    ["Lyd · video", "En afspiller", "Binært", "Skrivebeskyttet"],
                    ["Arkiver", "Liste over indhold", "Binært", "Skrivebeskyttet"],
                    ["Kildekode, ren tekst", "— ingen", "Teksten selv", "Code"],
                ]
            ),
            .note("""
                Kildekode har **ingen View**, og det er normalt frem for en mangel: en Swift-fil har \
                ingen gengivet form, det er værd at se på.
                """),
            .heading("Sidelæseren til Word og PowerPoint"),
            .paragraph("""
                Sider stables lodret og ruller sammenhængende, hver et hvidt ark på en grå baggrund — \
                som i enhver dokumentlæser. Dens betjening sidder til højre i linjen.
                """),
            .table(
                headers: ["Knap / tast", "Hvad den gør"],
                rows: [
                    ["`Tilpas bredde`", "Arket er præcis så bredt som rammen — standarden"],
                    ["`Tilpas side`", "Hele arket passer i rammen"],
                    ["`−` `+`", "Zoom i trin; eller knib, eller ⌘ + rul"],
                    ["`Søg`-feltet, eller ⌘F", "Søg inde i siderne, spring derhen og fremhæv"],
                    ["Enter i søgefeltet", "Næste træf"],
                    ["Træk", "Markér tekst; dobbeltklik for et ord, tredobbeltklik for et afsnit"],
                    ["⌘A · ⌘C", "Markér alt · kopiér markeringen"],
                    ["Page Up · Page Down · Home · End", "Bevæg dig gennem dokumentet"],
                ]
            ),
            .paragraph("""
                Søgefeltet **ser bort fra accenter og store/små bogstaver**: at skrive `vuong quoc` \
                finder `Vương quốc`. Mærkatet »Side 12/363« i linjen siger, hvor du er.
                """),
            .note("""
                **Det, der ikke gengives, sagt lige ud:** flydende forankrede billeder (tekst, der \
                ombryder om et billede) vises som indlejrede billeder; fodnoter, diagrammer og \
                PowerPoints SmartArt tegnes ikke. Når du har brug for præcis overensstemmelse med det \
                trykte, så åbn det i Word.
                """),
            .heading("Et klik på en knude springer tilbage til kilden"),
            .paragraph("""
                Et JSON-træ er ikke en pæn udskrift: et klik på en knude flytter markøren **til den \
                knudes VÆRDI** i teksten og fører fanebladet tilbage til Code — for det, du vil \
                dernæst, er næsten altid at redigere det, du lige klikkede på.
                """),
            .bullets([
                "Beholderknuder viser deres **antal elementer** (`{12}`, `[340]`) frem for deres indhold — det er det, der besvarer »er dette værd at åbne«.",
                "**De første to niveauer** er foldet ud: at folde en fil med ti tusind knuder helt ud giver en liste længere end kilden, mens at folde den helt sammen betyder, at man skal klikke for overhovedet at opdage noget.",
                "En fil med **ugyldig syntaks** får ikke et halvt træ — et afkortet træ ligner et dokument, der blot indeholder så lidt.",
                "I et XML-træ bærer attributter et `@`-præfiks i korrekt XPath-notation, og **blanktegn mellem mærker bliver ikke en knude** — det er formatering, ikke indhold.",
                "Et YAML-træ læser **flerdokumentfiler** (`---`): hvert dokument er sin egen rod. Samlinger skrevet på én linje (`ports: [80, 443]`) forbliver ét blad — du kan allerede se alt, og at folde ud koster et klik. **Indrykning med tabulatorer** meldes med den nøjagtige linje: det er en YAML-fejl, øjet ikke kan se.",
                "PowerPoint-dispositionen bygges på den **åbne tekst**, ikke på filen på disken: har du netop redigeret dispositionen i Code, skal træet beskrive den nye udgave, og dets knuder skal springe ind i den nye udgave. Talernoter foldes til én knude, så et dias, der siger meget, ikke ser ud som et dias, der indeholder meget.",
                "**Et diagram, der fylder fanebladet, følger samme regel**: klik på en knude, og du er tilbage i Code med markøren på den knudes erklæring. I sidepanelet `Mermaid Studio` lukker fanebladet ikke — editoren er lige der, og det er nok at flytte markøren for at se det.",
                "Diagrammer **åbner også, hvor du står**: det element, der svarer til markørens linje, fremhæves, i samme øjeblik fanebladet dukker op, så du ikke skal lede efter det.",
            ]),
            .heading("Filterfeltet: i et træ med ti tusind knuder er søgning selve arbejdet"),
            .paragraph("""
                Lige under knudeantallet sidder et filterfelt. Skriv i det, og træet beholder kun de \
                knuder, der passer — **sammen med stien fra roden ned til dem**, for når en nøgle `name` \
                optræder ti forskellige steder, er det virkelige spørgsmål »hvilken en«, og kun den gren, \
                der indeholder den, svarer på det. Resten foldes ud for dig: at få dig til at klikke \
                hvert niveau op er at få dig til at filtrere igen i hånden.
                """),
            .bullets([
                "Det filtrerer på **både mærkater og værdier**: at søge `Huế` er lige så almindeligt som at søge nøglen `province`.",
                "**At skrive uden accenter matcher stadig tekst med accent** — `da nang` finder `Đà Nẵng`. Samme sammenligning som CSV-tabellens filter og funktionslistens, så du ikke skal huske tre søgeregler i ét program.",
                "Uden træf siger overskriften **»Ingen resultater«** frem for at efterlade dig stirrende på et tomt træ i tvivl om, hvorvidt filen er i stykker.",
                "At skifte fil eller gå ind i View igen **rydder filteret**: et træ, der åbner allerede afkortet, uden at noget forklarer hvorfor, er den mest forvirrende tilstand af alle.",
            ]),
            .heading("Hele træet virker fra tastaturet"),
            .paragraph("""
                Når du går ind i View, flyttes fokus til træet; du behøver ikke først at klikke på det. \
                Op og ned bevæger sig mellem knuder, venstre og højre folder sammen og ud, og to taster \
                afslutter en visning — med **forskellig** virkning:
                """),
            .bullets([
                "**Enter** — gå til den valgte knude: tilbage til Code med markøren inde i den knudes byteområde. Præcis som at klikke på den.",
                "**Tab** — skift mellem træet og filterfeltet.",
                "**⌘C** — kopierer den valgte knudes **sti**, ikke teksten bag træet. JSON og YAML giver JSONPath (`$.customer['name']`), der kan indsættes direkte i dette produkts eget JSONPath-felt eller i `yq`; XML giver XPath (`/order/item[2]/@code`) med indeks, når to mærker deler navn; en PowerPoint-disposition kopierer linjens tekst, for en disposition har intet stisprog at finde på.",
                "**Esc** — vejen tilbage: tilbage til Code med markøren **præcis hvor den var**. Du kiggede på et træ, du rejste ikke nogen steder hen.",
            ]),
            .heading("Og den anden vej: træet åbner, hvor markøren står"),
            .paragraph("""
                At gå ind i View midt i en fil på ti tusind linjer åbner **ikke** træet ved toppen: det \
                folder stien ud ned til den knude, der svarer til, hvor markøren var, og vælger den. \
                Dette er den anden halvdel af spring-til-kilde — uden det ville View og Code være to \
                visninger af ét dokument i kun **én** retning.
                """),
            .bullets([
                "Det folder **dybere end to niveauer** ud, når det er nødvendigt: toniveauregelen besvarer »hvordan ser denne fil ud«, mens spørgsmålet her er et andet — »hvor er jeg i dette træ«.",
                "En markør på en **nøgle** (`\"address\":`) vælger den post, selv om knudens byteområde kun dækker værdien. Tekst umiddelbart før en knude hører til den knude.",
                "En markør ved en **bloks begyndelse** — en YAML-bloks nøgle, en diastitel, et XML-mærkenavn — vælger den blok frem for at dykke ned til dens første barn.",
                "At gå ind i View **flytter ikke markøren**. Forlad View, og du er præcis, hvor du var; View er en måde at se på, ikke en kommando, der ændrer position.",
            ]),
            .heading("Ingen type mangler længere en View"),
            .paragraph("""
                **Hver filtype med plads til en View-tilstand gengiver nu en.** Listen over manglende \
                typer blev tom og blev fjernet.

                Kildekode og ren tekst har stadig ingen View — det er normalt, ikke en mangel, så de \
                stod aldrig på den liste.

                Kommer der en ny filtype, hvis View ikke er bygget endnu, vil skiftekommandoen sige det \
                og nævne, hvad der mangler, frem for at åbne en tom ramme — en tom ramme er et tomt \
                løfte, mens et afslag med et navn er oplysning.
                """),
            .heading("De seks ældre kommandoer findes stadig"),
            .paragraph("""
                `Tabel/tekstvisning`, `Markdown-forhåndsvisning`, `Binær visning`, \
                `Rapportforhåndsvisning`, `Mermaid-diagramforhåndsvisning`, `Logtilstand` — de bliver \
                alle præcis, hvor de var. `⌥⌘V` er en **fælles indgang**, ikke en erstatning.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamesisk

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamesisk",
        summary: "Gamle tegnkodninger, Unicode-normalisering, accentufølsom søgning og inddatametoder.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnamesiske tegnkodninger",
        summary: "Læs og skriv TCVN3, VISCII, VNI-Windows og 33 andre, genkendt af sig selv.",
        keywords: ["tegnkodning", "tcvn3", "abc", "viscii", "vni", "volapyk"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Åbnet en gammel vietnamesisk fil og fået `Tr¦êng §¹i häc` i stedet for `Trường Đại \
                học`? Filen er ikke ødelagt — den blev gemt i en tegnkodning fra før Unicode.
                """),
            .steps([
                "Klik på tegnkodningen på **statuslinjen** (eller `Format ▸ Tegnkodning…`).",
                "Vælg den rigtige — for gamle vietnamesiske filer er det som regel `TCVN3 (ABC)`, `VNI-Windows` eller `VISCII`.",
                "Teksten retter sig selv med det samme; der er ingen grund til at åbne filen igen.",
                "For at beholde den sådan: `Gem som…` med tegnkodningen `UTF-8`.",
            ]),
            .heading("De tre gamle vietnamesiske tegnkodninger"),
            .table(
                headers: ["Tegnkodning", "Findes som regel i"],
                rows: [
                    ["TCVN3 (ABC)", "Offentligt papirarbejde og ældre Word-dokumenter i nord"],
                    ["VNI-Windows", "Forlag, aviser og trykkerier — almindelig i syd"],
                    ["VISCII", "Tidlig e-post og Usenet"],
                ]
            ),
            .paragraph("""
                GEditor **genkender tegnkodningen**, når filen åbnes. Gætter den forkert, retter et \
                klik det, og indholdet afkodes på ny frem for at blive lappet bogstav for bogstav.
                """),
            .warning("""
                At skrive ud i en gammel tegnkodning mister de tegn, den kodning ikke har. GEditor \
                **tæller dem og siger det først** — for eksempel *»12 tegn findes ikke i TCVN3«* — i \
                stedet for stille at gøre dem til spørgsmålstegn.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Linjeslutninger",
        summary: "LF, CRLF, CR — omsat for hele filen med ét klik.",
        keywords: ["eol", "crlf", "lf", "linjeslutning", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Stil", "Bruges af", "Bytes"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac før 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Den aktuelle stil vises på statuslinjen; klik på den for at ændre den. En fil, der \
                **blander** to stilarter, meldes også dér — slå `Vis usynlige tegn ▸ Linjeslutninger` \
                til for at se præcis hvor.
                """),
            .note("Linjeslutningsstilen for **nye** filer sættes i `Indstillinger…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode-normalisering",
        summary: "Hvorfor en søgning efter «ế» somme tider intet finder, og hvordan man retter en hel fil.",
        keywords: ["unicode", "nfc", "nfd", "sammensat", "opdelt", "normalisér", "ingen træf"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                I Unicode kan `ế` skrives på **to forskellige måder**: som ét forud sammensat kodepunkt \
                (NFC) eller som `e` plus to særskilte tegn (NFD). På skærmen ser de ens ud; for en \
                maskine er de forskellige strenge.
                """),
            .paragraph("""
                Følgen: en søgning efter `ế` i en NFD-fil finder **intet**, og brugeren slutter, at \
                dataene ikke er der.
                """),
            .steps([
                "`Format ▸ Normalisér Unicode…`",
                "Vælg **NFC** (forud sammensat) — den form, næsten alt andet bruger.",
                "Anvend. Det er ét fortrydelsestrin.",
            ]),
            .note("""
                Filer, der kommer fra macOS, er ofte NFD, fordi Apples filsystem gemmer filnavne \
                sådan. Det er den enkeltstående mest almindelige grund til, at data kopieret ud af \
                Finder ikke kan findes igen.
                """),
            .paragraph("""
                Der findes en kontakt **normalisér til NFC ved gemning** i `Indstillinger…`. Slået fra \
                som standard, fordi den ændrer filens bytes.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "At skrive uden accenter finder stadig tekst med accent",
        summary: "Hvert søge- og filterfelt sammenligner med accenterne fjernet.",
        keywords: ["accenter", "diakritiske tegn", "søgning", "filter", "uden accent"],
        blocks: [
            .paragraph("""
                Skriv `hue` for at finde `Huế`. Skriv `da nang` for at finde `Đà Nẵng`. Reglen gælder \
                CSV-tabellens filter, funktionssøgningen, hjælpesøgningen og de øvrige filterfelter.
                """),
            .note("""
                `Đ` behandles særskilt, for i Unicode er det **et bogstav i sig selv** og ikke et `D` \
                med et tegn på — almindelig accentfjernelse rører det ikke.
                """),
            .paragraph("""
                CSV-filteret tager også imod et `=`-præfiks til nøjagtig sammenligning. `=`-formen er \
                **også accentufølsom**, for et filter, der skelner accenter, efterlader brugeren i den \
                tro, at dataene mangler.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnamesiske inddatametoder",
        summary: "EVKey, OpenKey, Unikey og macOS' egen inddatakilde skriver alle direkte i dokumentet.",
        keywords: ["ime", "evkey", "unikey", "openkey", "telex", "vni", "inddatametode"],
        blocks: [
            .paragraph("""
                Intet at indstille. Telex og VNI virker begge, også på tværs af **flere markører** — \
                skriv én gang, og hver markør får det rigtigt accentuerede bogstav.
                """),
            .paragraph("""
                Søgefelter, filterfelter og hver dialog tager imod inddatametoden præcis som editoren.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Sprog og formater

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Sprog og formater",
        summary: "Tyve indbyggede sprog, selvdefinerede sprog og værktøjer til JSON · XML · YAML · logfiler.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Tyve indbyggede sprog",
        summary: "Farvelægning ud fra et virkeligt syntakstræ, med hvert sprogs egne kommentartegn.",
        keywords: ["syntaks", "fremhævning", "sprog", "tree-sitter", "grammatik"],
        blocks: [
            .paragraph("""
                Sproget genkendes ud fra **filendelsen** (plus nogle få særlige navne som `Makefile`, \
                `Dockerfile`, `Gemfile`). Du kan ændre det i hånden på statuslinjen.
                """),
            .table(
                headers: ["Sprog", "Endelser", "Linje- · blokkommentar"],
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
                Den sidste spalte er det, `⌘/` bruger. Sprog uden en linjekommentar (JSON, CSS, XML) \
                får blokformen i stedet.
                """),
            .heading("Hvad der følger med et syntakstræ"),
            .bullets([
                "**Funktionslisten** i sidepanelet følger den virkelige opbygning, ikke gæt ud fra indrykning.",
                "**Sammenfoldning** efter opbygning.",
                "**Parentesmatchning**, der springer parenteser inde i strenge og kommentarer over.",
                "**Automatisk indrykning**, der føjer et niveau til efter `{` og efter `:` i Python og YAML.",
            ]),
            .note("""
                Tre tunge grammatikker (C++, C#, Ruby) ligger i et **dovent indlæst** bibliotek — de \
                indlæses kun, når du åbner en fil i et af de sprog. Sådan holdes starttiden under et \
                halvt sekund.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Selvdefinerede sprog",
        summary: "Farv dit eget format med én JSON-fil — ingen grammatik at skrive.",
        keywords: ["udl", "selvdefineret sprog", "eget sprog", "egen log"],
        blocks: [
            .paragraph("""
                Et firmas interne logformat, et privat konfigurationssprog, et lille DSL — ingen af dem \
                har en tree-sitter-grammatik, og at skrive en kræver en oversætter og noget \
                fortolkningsteori.
                """),
            .paragraph("""
                I stedet tager GEditor imod en **tabelstyret lekser** erklæret i JSON. Læg filen i \
                mappen `grammars/` inde i GEditors konfigurationsmappe, og start programmet igen.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — et helt sprog",
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
            .heading("Hver nøgle"),
            .table(
                headers: ["Nøgle", "Type", "Betydning"],
                rows: [
                    ["`name`", "streng", "Navnet, der vises på statuslinjen"],
                    ["`extensions`", "liste af strenge", "Filendelser, **uden punktum**"],
                    ["`caseSensitive`", "boolesk", "Om nøgleord skelner store og små bogstaver"],
                    ["`lineComment`", "streng", "Tegn for kommentar til linjens slutning; udelad, hvis der ikke er et"],
                    ["`blockComment`", "liste af 2 strenge", "`[åbn, luk]`"],
                    ["`stringDelimiters`", "liste af strenge", "Hvert element er **ét** tegn, der åbner/lukker en streng"],
                    ["`escapeCharacter`", "streng", "Undvigetegn inde i strenge; tomt betyder, at sproget ikke har et"],
                    ["`keywordGroups`", "objekt", "Gruppenavn → nøgleordsliste; tre grupper får tre farver"],
                ]
            ),
            .paragraph("""
                De tre gruppenavne, der får deres egne farver, er `keyword`, `type` og `constant`.
                """),
            .warning("""
                Denne lekser **forstår ikke indlejring**. Strukturel sammenfoldning, funktionslisten og \
                klog parentesmatchning forbliver forbeholdt de tyve indbyggede sprog. Det er en bevidst \
                byttehandel: til gengæld erklærer du et sprog på ti minutter i stedet for på en dag.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON-værktøjer",
        summary: "Omformatér, komprimér, sortér nøgler, og kontrollér mod et JSON Schema.",
        keywords: ["json", "format", "pæn", "komprimér", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Kommando", "Hvad den gør"],
                rows: [
                    ["Omformatér", "Ombryder og indrykker, så det kan læses"],
                    ["Komprimér", "Fjerner alle overflødige blanktegn"],
                    ["Sortér nøgler", "Sætter hvert objekts nøgler i alfabetisk orden — så to JSON-filer kan **sammenlignes**"],
                    ["Kontrollér mod JSON Schema…", "Kontrollerer dokumentet mod en schemafil og lister hvert problem med linjenummer"],
                ]
            ),
            .paragraph("""
                De anvendte regler er **streng RFC 8259**: ingen efterfølgende kommaer, ingen \
                kommentarer, ingen `NaN`. En syntaksfejl peger på den nøjagtige linje og kolonne.
                """),
            .note("""
                **JSONL**-filer (ét objekt pr. linje) genkendes også og har deres eget værktøjssæt i \
                kapitlet om videnspakken.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath-forespørgsler",
        summary: "Træk præcis den del ud, du har brug for, af en stor JSON-fil.",
        keywords: ["jsonpath", "json-forespørgsel", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Skriv et udtryk; resultaterne vises som en liste, du kan springe ind i."),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`$`", "Dokumentets rod"],
                    ["`$.name`", "Nøglen `name` ved roden"],
                    ["`$.orders[0]`", "Første element i en liste"],
                    ["`$.orders[*].total`", "Nøglen `total` i **hvert** element"],
                    ["`$..province`", "Nøglen `province` i **enhver dybde**"],
                    ["`$.orders[1:3]`", "Et udsnit: element 1 og 2"],
                ]
            ),
            .code(language: "text", caption: "Hver ordres provinskode, uanset hvor dybt indlejret",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML-værktøjer",
        summary: "Omformatér, komprimér, kontrollér syntaks, og kontrollér mod en DTD eller XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "kontrollér", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Kommando", "Hvad den gør"],
                rows: [
                    ["Omformatér", "Indrykker efter mærkedybde"],
                    ["Komprimér", "Fjerner blanktegn mellem mærker"],
                    ["Kontrollér syntaks", "Manglende slutmærker, forkert indlejring, ugyldige tegn"],
                    ["Kontrollér mod DTD/XSD…", "Kontrollerer mod et schema og melder hvert problem med linjenummer"],
                    ["Evaluér XPath…", "Kører et XPath-udtryk; resultaterne åbner i et nyt faneblad"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Skriv et udtryk, og resultaterne åbner som **et tekstfaneblad**, én knude pr. linje. For \
                eksempel: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Resultaterne springer IKKE til en position i kildefilen.** Systemets XPath-evaluator \
                bygger sit eget træ og gemmer ikke hver knudes byteposition, så det, der kommer tilbage, \
                er INDHOLD frem for koordinater. For at nå det nøjagtige sted skal du bruge `⌘F` på den \
                streng, du netop har fundet.
                """),
            .paragraph("""
                I `.xml`- og `.html`-filer får det at skrive `>` for at afslutte et åbningsmærke \
                **slutmærket til at dukke op** med markøren mellem de to. Selvlukkende mærker (`<br/>`), \
                erklæringer (`<?xml …?>`) og kommentarer gør ikke — de har intet at lukke.
                """),
            .warning("""
                At omformatere XML **ændrer blanktegnene mellem mærker**. I dokumenter, hvor de \
                blanktegn betyder noget — XHTML med tekst inde i mærker, for eksempel — ændrer det, \
                hvad der vises. Det er ét fortrydelsestrin, så `⌘Z` vender det om.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML-kontrol",
        summary: "Fang de to mest almindelige YAML-fejl: gentagne nøgler og indrykning med tabulatorer.",
        keywords: ["yaml", "yml", "lint", "gentaget nøgle", "indrykning"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Gentagne nøgler** i én afbildning — de fleste YAML-læsere tager den **sidste** og dropper stille de tidligere, så en konfigurationsfil kan opføre sig helt anderledes, end du forventer.",
                "**Indrykning med tabulatorer** — YAML forbyder tabulatorer i indrykning, og bibliotekernes fejlmeddelelser om det er som regel uforståelige.",
            ]),
            .note("Slå `Vis usynlige tegn ▸ Tabulatorer` til for straks at se, hvilket blanktegn der er en tabulator."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Logfiler",
        summary: "Syv alvorsgrader, filtrering efter niveau, og hvordan man læser en meget stor log.",
        keywords: ["log", "fejl", "advarsel", "filter", "niveau"],
        blocks: [
            .paragraph("""
                Slå `Vis ▸ Logtilstand (farv efter niveau)` til. GEditor læser alvorsgraden fra **hver \
                linjes begyndelse** — efter tidsstemplet og procesnavnet.
                """),
            .table(
                headers: ["Niveau", "Farve"],
                rows: [
                    ["CRITICAL · ERROR", "Rød"],
                    ["WARNING", "Ravgul"],
                    ["NOTICE", "Accentfarve"],
                    ["INFO", "Almindelig tekst"],
                    ["DEBUG · TRACE", "Dæmpet"],
                ]
            ),
            .paragraph("""
                `Filtrér log efter niveau…` skjuler de lavere niveauer helt. Linjer, hvis niveau **ikke \
                genkendes** — en fortsættelse af et fejlspor, for eksempel — bliver ladt i fred frem for \
                at få den foregående linjes niveau.
                """),
            .heading("At læse en stor log, trin for trin"),
            .steps([
                "Åbn filen — også i gigabyteskala åbner den næsten øjeblikkeligt.",
                "`Vis ▸ Logtilstand` for at se de røde pletter.",
                "`⌥⌘M` for dokumentkortet: er det røde klumpet ét sted eller spredt gennem filen?",
                "`⌘F` efter fejlkoden, `⌘M` for at mærke hver linje, der passer.",
                "`Søg ▸ Kopiér mærkede linjer` for at trække dem over i et nyt faneblad.",
                "Kører den stadig? `Fil ▸ Følg fil (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
