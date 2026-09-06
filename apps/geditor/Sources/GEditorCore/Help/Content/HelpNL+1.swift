import Foundation

/// Nederlandse helpinhoud — deel 1: aan de slag en bewerken.
///
/// **Onderwerp-`id`'s worden NOOIT vertaald.** Ze zijn waar `.seeAlso` naar wijst, wat het menu opent,
/// en waardoor het helpvenster van taal kan wisselen **zonder de lezer terug te werpen naar de
/// inhoudsopgave**. Een id wijzigen breekt alle verwijzingen, in alle boeken tegelijk.
///
/// De menutitels in `commands:` blijven Vietnamees: ze moeten woord voor woord overeenkomen met de
/// echte menu-items, die `HelpCoverage` juist op die tekenreeks nakijkt.
enum HelpNL {}

extension HelpNL {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Aan de slag",
        summary: "Wat GEditor doet, en waaraan u uw eerste vijf minuten besteedt.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Wat GEditor is",
        summary: "Een tekst- en gegevensbewerker op gigabyteschaal voor macOS die Vietnamees spreekt.",
        keywords: ["inleiding", "welkom", "overzicht", "over"],
        blocks: [
            .paragraph("""
                GEditor opent een **bestand van 1 GB zonder 1 GB in het geheugen te laden**. Hij leest \
                via een schuivend venster over een in het geheugen afgebeeld bestand, zodat een logboek \
                van 200 miljoen regels of een CSV van een miljoen regels in ongeveer een seconde opengaat \
                en soepel schuift.
                """),
            .paragraph("""
                Naast bewerken is het een **werkbank voor gegevens**: een CSV als tabel bekijken, \
                opschonen, de kwaliteit ervan beoordelen, met SQL bevragen, er afwijkingen en trends in \
                zoeken en er dan een rapport van maken. En hij leest de oude Vietnamese coderingen die de \
                meeste hulpmiddelen van vandaag vergeten zijn.
                """),
            .heading("Zes dingen om eerst te proberen"),
            .table(
                headers: ["Taak", "Waar naartoe"],
                rows: [
                    ["Een groot bestand openen zonder wachten", "Sleep het in het venster — zie «Grote bestanden openen»"],
                    ["Veel plekken tegelijk bewerken", "`⌘D` voegt het volgende voorkomen toe, dan typt u één keer"],
                    ["Zoeken met een reguliere uitdrukking", "`⌘F`, zet Regex aan — de motor is PCRE2 met JIT"],
                    ["Een CSV als tabel bekijken", "`⌥⌘T` — een miljoen regels schuift nog steeds soepel"],
                    ["Een rommelige gegevenstabel opschonen", "`⇧⌘L` opschoonbank — voorbeeld vóór het toepassen"],
                    ["Een Vietnamees bestand openen dat als brij verschijnt", "Klik op de codering in de statusbalk"],
                ]
            ),
            .note("""
                Komt u van Notepad++? Er is een pagina die beide toetsenindelingen vergelijkt, want enkele \
                toetsen **wisselen van plaats** op macOS in plaats van alleen `Ctrl` in `⌘` te veranderen.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Uw eerste vijf minuten",
        summary: "Twaalf sneltoetsen dekken het grootste deel van het dagelijkse werk.",
        keywords: ["sneltoets", "toetsen", "start", "basis"],
        blocks: [
            .paragraph("""
                U hoeft niet alles te leren. De twaalf toetsen hieronder dekken het grootste deel van het \
                dagelijkse werk; de rest zoekt u op wanneer u ze nodig hebt.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Een bestand openen"),
                HelpShortcut("⇧⌘O", "Een hele map als werkruimte openen"),
                HelpShortcut("⌘T", "Nieuw tabblad"),
                HelpShortcut("⌘S", "Bewaren"),
                HelpShortcut("⌘F", "Zoeken"),
                HelpShortcut("⌥⌘F", "Zoeken en vervangen"),
                HelpShortcut("⇧⌘F", "In een map zoeken"),
                HelpShortcut("⌘D", "Het volgende voorkomen aan de selectie toevoegen"),
                HelpShortcut("⌘L", "Naar regel gaan"),
                HelpShortcut("⌘/", "De regel becommentariëren met de syntaxis van de taal zelf"),
                HelpShortcut("⌥⌘T", "Wisselen tussen tabel en tekst (CSV-bestanden)"),
                HelpShortcut("⌘?", "Dit helpvenster opnieuw openen"),
            ]),
            .heading("Drie dingen die nieuwkomers verrassen"),
            .bullets([
                "**Een massale bewerking is ÉÉN stap terug**, ook als ze een miljoen regels raakt. Verkeerd gesorteerd? Eén `⌘Z` en het is weg.",
                "**De sessie herstelt zichzelf.** Sluit af en open opnieuw: de tabbladen komen op hun plaats terug, ook de niet-bewaarde. Niets in te drukken.",
                "**Zonder accenten typen vindt toch woorden mét accenten** in elk zoek- en filterveld — typ `hue` en u krijgt `Huế`, `da nang` en u krijgt `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Wat wilt u doen?",
        summary: "Een tabel die van echte taken naar het hoofdstuk leidt dat ze behandelt.",
        keywords: ["index", "opzoeken", "hoe doe ik"],
        blocks: [
            .paragraph("""
                De inhoudsopgave links is geordend op **functie**. Deze tabel is geordend op **taak**, \
                want die twee ordeningen vallen niet samen.
                """),
            .table(
                headers: ["Ik moet…", "Zie"],
                rows: [
                    ["Dezelfde plek op honderden regels bewerken", "Meerdere cursors · Blokselectie"],
                    ["Massaal opmaken met een regex", "Zoeken en vervangen · Reguliere uitdrukkingen"],
                    ["Een reeks handelingen herhalen", "Macro's"],
                    ["Een CSV openen die iemand me stuurde", "De CSV-tabel"],
                    ["Een rommelige tabel opschonen: gemengde datums, getallen als tekst", "De opschoonstroom"],
                    ["Beoordelen of een tabel te vertrouwen is", "Kwaliteitsbeoordeling van gegevens"],
                    ["Afwijkingen, trends, groepen vinden", "De datamining-stroom"],
                    ["Vragen stellen in SQL", "Een CSV bevragen met SQL"],
                    ["Een rapport publiceren waarvan de cijfers zich vernieuwen", "`.greport.md`-rapporten"],
                    ["Een schema in een document tekenen", "Mermaid"],
                    ["Een onleesbaar Vietnamees bestand openen", "Vietnamese coderingen"],
                    ["Automatiseren vanaf de shell of AppleScript", "Automatisering"],
                    ["Een door mijn bedrijf verzonnen formaat inkleuren", "Zelfgedefinieerde talen"],
                ]
            ),
            .note("""
                Staat het er niet bij? Het zoekveld linksboven kijkt in de **lopende tekst en de \
                codevoorbeelden**, dus een configuratiesleutel als `fail_under` typen brengt u op de \
                juiste pagina.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Grote bestanden openen",
        summary: "Waarom 1 GB überhaupt opengaat, en waar GEditor met opzet weigert in plaats van te raden.",
        keywords: ["groot bestand", "gigabyte", "logboek", "mmap", "traag", "prestaties"],
        blocks: [
            .paragraph("""
                Het bestand wordt **in het geheugen afgebeeld** en via een schuivend venster gelezen; het \
                deel dat u bewerkt woont in een piece table. In de praktijk: de openingstijd hangt \
                nauwelijks van de bestandsgrootte af, en het gebruikte geheugen evenmin.
                """),
            .heading("Waar hij met opzet weigert"),
            .paragraph("""
                Een paar berekeningen zouden het hele bestand tot één tekenreeks moeten lezen — precies \
                wat deze architectuur vermijdt. Daar **zegt GEditor dat hij het niet doet** in plaats van \
                stilletjes te kruipen of te raden:
                """),
            .table(
                headers: ["Bewerking", "Grens", "Daarboven"],
                rows: [
                    ["Haakjes koppelen", "1 MB", "Weigert en zegt het — het verkeerde paar oplichten is erger dan geen"],
                    ["Visuele kolom in de statusbalk", "200 KB", "Valt terug op bytes tellen en markeert dat met `~` zodat de betekenis zichtbaar blijft"],
                    ["Markdown-voorbeeld", "4 MB", "Weigert en legt uit"],
                ]
            ),
            .warning("""
                Een getal dat er hetzelfde uitziet maar iets anders betekent, is de ergste soort fout. \
                Daarom leest een kolom voorbij de grens `~1234` en niet `1234`.
                """),
            .heading("Tips voor logbestanden"),
            .bullets([
                "`Bestand ▸ Bestand volgen (tail -f)` haalt binnen wat aan het einde wordt geschreven. Het document wordt **alleen-lezen** tijdens het volgen — typen terwijl er nieuwe tekst binnenkomt, zijn twee schrijvers die om één document vechten, en de verliezer is altijd wat u net typte.",
                "Logregels worden **gekleurd naar ernst** en zijn per niveau te filteren.",
                "De **documentkaart** (`⌥⌘M`) beschrijft het hele bestand, niet alleen het deel op het scherm.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App Store-uitgave tegenover directe download",
        summary: "Drie functies die alleen de directe uitgave heeft, en waarom.",
        keywords: ["app store", "sandbox", "download", "cli", "uitbreiding", "verschil"],
        blocks: [
            .paragraph("""
                GEditor verschijnt in twee uitgaven. Ze komen uit **dezelfde broncode** en de toepassing \
                herkent bij het starten welke ze is. Het verschil zit in wat de App Sandbox toestaat.
                """),
            .table(
                headers: ["Functie", "App Store", "Directe download"],
                rows: [
                    ["Alle bewerking, CSV, opschonen, mining, rapporten", "Ja", "Ja"],
                    ["Het opdrachtregelgereedschap `geditor`", "Nee", "Ja"],
                    ["Tekst filteren via een externe opdracht", "Nee", "Ja"],
                    ["Inheemse plug-ins (apart proces)", "Nee", "Ja"],
                    ["Zelf bijwerken", "Via de App Store", "In de toepassing"],
                ]
            ),
            .paragraph("""
                Elke «Nee» hierboven komt uit dezelfde regel: de sandbox **verbiedt code buiten de \
                toepassing uit te voeren**. Dat is de prijs van verspreiding via de App Store, geen \
                vergissing.
                """),
            .note("""
                In de App Store-uitgave **blijven die opdrachten in het menu** en leggen uit waarom ze \
                niet beschikbaar zijn, in plaats van te verdwijnen. Een ontbrekend menu-item wordt een \
                vraag aan de ondersteuning; een antwoord ter plekke niet.
                """),
            .heading("Toegang tot bestanden in de App Store-uitgave"),
            .paragraph("""
                De sandbox-uitgave raakt alleen bestanden aan die u zelf hebt geopend of ingesleept. \
                GEditor bewaart een **bladwijzer met veiligheidsbereik** voor elk tabblad en voor de map \
                van de werkruimte, zodat uw sessie na afsluiten weer opengaat zonder opnieuw om \
                toestemming te vragen.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Bewerken

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Bewerken",
        summary: "Veel plekken tegelijk bewerken, met regels werken, en de verborgen regels die u eerst moet kennen.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Meerdere cursors",
        summary: "Elke passende plek selecteren, één keer typen, ze allemaal veranderen.",
        keywords: ["multicursor", "cmd+d", "meervoudige selectie"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Dit vervangt de meeste momenten waarop u een reguliere uitdrukking wilde gaan schrijven. \
                Selecteer een woord, druk een paar keer op `⌘D` om de volgende voorkomens op te rapen, en \
                typ — alle plekken veranderen tegelijk.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Het volgende voorkomen aan de selectie toevoegen"),
                HelpShortcut("⌘ + klik", "Nog een cursor zetten waar u klikt"),
                HelpShortcut("Esc", "Ze allemaal laten vallen, terug naar één cursor"),
                HelpShortcut("⌥ + slepen", "Blokselectie (een andere manier om veel cursors te krijgen)"),
            ]),
            .heading("Regels die u moet kennen"),
            .bullets([
                "Typen, wissen en plakken over veel cursors is **één** stap terug, niet één per cursor.",
                "De cursors overleven pijltjesbewegingen — de hele groep verplaatst mee.",
                "`⌘D` slaat plekken over die al in de selectie zitten, dus te vaak drukken stapelt nooit twee cursors op elkaar.",
            ]),
            .note("""
                `⌘D` op een woord binnen een lange tekenreeks was vroeger traag. Het herkennen van \
                woordgrenzen leest nu in porties — ongeveer **42× sneller** op een reeks van 1 MB, \
                waardoor dit bruikbaar wordt op gegevensbestanden en niet alleen op broncode.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Blokselectie van kolommen",
        summary: "Een rechthoek over veel regels selecteren — met de muis of vanaf het toetsenbord.",
        keywords: ["kolommodus", "blok", "alt slepen", "rechthoek", "toetsenbord", "pijltjes"],
        blocks: [
            .paragraph("""
                Houd `⌥` vast en sleep om een **rechthoekig blok** te selecteren. Typen, wissen en plakken \
                volgen het blok. Een blok op één cursor plakken houdt zijn rechthoek.
                """),
            .shortcuts([
                HelpShortcut("⌥ + slepen", "Een blok selecteren"),
                HelpShortcut("⌥⌘← →", "Het blok een kolom naar links/rechts verbreden"),
                HelpShortcut("⌥⌘↑ ↓", "Het blok een regel omhoog/omlaag uitbreiden"),
            ]),
            .paragraph("""
                De toetsenbordweg is geen noodoplossing voor de muis: een blok van 40 regels slepend \
                selecteren dwingt u door een schuifbeweging heen te slepen, terwijl `⌥⌘` + pijltjes de \
                precisie kolom voor kolom houdt. Op **elke andere** toets drukken (of typen) sluit het blok \
                dat u aan het uitbreiden was.
                """),
            .heading("Kolommen zijn hier VISUELE kolommen"),
            .paragraph("""
                Een tab rekt uit tot de volgende stop volgens uw tabbreedte, in plaats van als één kolom \
                te tellen. Dat is wat regels met tabs en met spaties **laat uitlijnen zoals ze op het \
                scherm staan**.
                """),
            .paragraph("Meerbyte-tekst blijft één kolom: `Nguyễn` beslaat zes kolommen, geen negen."),
            .table(
                headers: ["Situatie", "Wat GEditor doet"],
                rows: [
                    ["De doelkolom valt midden in een tab", "Klikt naar de dichtstbijzijnde rand; bij gelijkspel naar links"],
                    ["Een regel is korter dan de startkolom", "Die regel levert een lege selectie, en aanvaardt toch getypte tekst"],
                    ["Een blok op één cursor plakken", "Houdt de rechthoek en voegt in op de regels eronder"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Kolombewerker",
        summary: "Tekst, een getallenreeks of een datumreeks in elke regel van een blok invoegen.",
        keywords: ["kolombewerker", "nummering", "reeks", "serie"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Selecteer een kolomblok en open `Wijzig ▸ Kolombewerker…` (`⌥⌘C`). Het venster heeft een \
                **voorbeeld** voordat er iets wordt toegepast.
                """),
            .table(
                headers: ["Modus", "Parameters", "Wanneer"],
                rows: [
                    ["Tekst", "Een vaste tekenreeks", "Hetzelfde voor-/achtervoegsel aan elke regel toevoegen"],
                    ["Getallenreeks", "Start · stap · grondtal 2·8·10·16 · voorloopnullen", "Regels nummeren, codes maken"],
                    ["Datumreeks", "Eerste datum · stap in dagen", "Een kolom opeenvolgende datums maken"],
                ]
            ),
            .code(language: "text", caption: "Nummering met voorloopnullen, start 1, stap 1",
                  source: """
                    Voor:             Na (getallenreeks, 3 cijfers):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Een **negatieve** stap is geldig — terugtellen werkt.",
                "Invoegen in 5000 regels blijft **één** stap terug.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Bewerkingen op regels",
        summary: "Sorteren, dubbele verwijderen, verplaatsen, samenvoegen, splitsen, dupliceren, wissen.",
        keywords: ["sorteren", "dupliceren", "samenvoegen", "splitsen", "regel verplaatsen"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Met een selectie werkt de opdracht op de selectie; zonder werkt ze op het **hele \
                document**. Elke opdracht hier is één stap terug.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Regel dupliceren"),
                HelpShortcut("⌘K", "Regel wissen"),
                HelpShortcut("⌥↑ / ⌥↓", "Regel omhoog / omlaag verplaatsen"),
            ]),
            .heading("Drie soorten sorteren, en welke te kiezen"),
            .table(
                headers: ["Soort", "`file2` tegenover `file10`", "Voor"],
                rows: [
                    ["A→Z / Z→A", "`file10` komt vóór `file2`", "Eenvoudige woordenlijsten"],
                    ["Natuurlijk", "`file2` komt vóór `file10`", "Bestandsnamen, codes, versies"],
                ]
            ),
            .paragraph("""
                **Natuurlijk** sorteren leest cijferreeksen als getallen. Dat is bijna altijd wat u wilt \
                wanneer de lijst genummerd is.
                """),
            .heading("Dubbele verwijderen"),
            .bullets([
                "**Hele document** — gooit elke regel weg die eerder verscheen en houdt de eerste.",
                "**Alleen aangrenzende** — voegt gelijke buurregels samen, zoals `uniq` in Unix.",
            ]),
            .heading("Samenvoegen en splitsen"),
            .bullets([
                "**Regels samenvoegen** smelt de geselecteerde regels tot één.",
                "**Splitsen op lengte** knipt lange regels op een gegeven aantal tekens.",
                "**Splitsen op teken** knipt bij elk voorkomen van een teken dat u typt — bijvoorbeeld om een CSV-regel in zijn cellen te breken.",
            ]),
            .note("""
                De **laatste regel** van een bestand dupliceren voegt de ontbrekende regelovergang toe; \
                wissen tot het einde van het document slikt ook de regelovergang van de vorige regel op. \
                Beide wijken af van de naïeve uitvoering, en beide bestaan opdat het bestand niet met een \
                lege regel te veel eindigt — en evenmin zonder de regel die nodig was.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Witruimte en inspringing",
        summary: "Zwervende witruimte opruimen, tab ↔ spatie omzetten, en één schakelaar om over na te denken.",
        keywords: ["witruimte", "tab", "inspringing", "lege regels"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Opdracht", "Wat ze doet"],
                rows: [
                    ["Lege regels verwijderen", "Gooit elke regel zonder inhoud weg"],
                    ["Opeenvolgende lege regels samenpersen", "Meerdere lege regels achter elkaar worden er één"],
                    ["Witruimte aan het regeleinde afknippen", "Verwijdert zwervende spaties en tabs aan het einde van elke regel"],
                    ["Tab → Spatie", "Zet tabs om in spaties bij de huidige breedte"],
                    ["Spatie → Tab", "De andere richting"],
                ]
            ),
            .heading("Inspringing per taal"),
            .paragraph("""
                Klik op `Tab: 4` in de statusbalk. Het bovenste deel van het menu verandert het voor de \
                **hele toepassing**; het onderste — `Alleen voor Go`, `Alleen voor Python`… — geldt alleen \
                voor de taal van het geopende bestand en onthoudt of tabs of spaties gebruikt worden.
                """),
            .paragraph("""
                Mensen kiezen inspringing niet uit smaak maar uit **afspraak van de gemeenschap**: Go \
                gebruikt tabs (`gofmt` gaat boven al het andere), Python vier spaties volgens PEP 8, \
                JavaScript en YAML meestal twee. Eén getal voor alle talen betekent dat elk bestand dat u \
                aanraakt regels krijgt die u nooit hebt bewerkt.
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
                Het in `settings.json` verklaren werkt ook — de sleutel is de taalcode (`go`, `python`, \
                `javascript`…). Talen die er niet in staan gebruiken de gedeelde `tabWidth`.
                """),
            .heading("Waarom «afknippen bij bewaren» standaard UIT staat"),
            .paragraph("""
                De schakelaar `Bestand ▸ Witruimte aan het regeleinde afknippen bij bewaren` bewerkt \
                **regels die u nooit hebt aangeraakt**. Standaard aan wordt een correctie van één woord in \
                andermans repository een diff van duizend regels, en vindt de beoordelaar de echte \
                wijziging niet meer.
                """),
            .paragraph("""
                Als hij aanstaat, is het afknippen een **aparte stap terug** vóór het schrijven — één keer \
                terug brengt het document in de vorige toestand, zonder te verliezen wat u net bewaard \
                hebt.
                """),
            .heading("Automatische inspringing"),
            .bullets([
                "Een nieuwe regel erft de inspringing van de vorige, plus één niveau na een openingsteken — `{` in accolade-talen, `:` in Python en YAML.",
                "De meting is in **visuele kolommen**, zodat bestanden die tabs en spaties mengen op het scherm uitgelijnd blijven.",
                "Er is **geen** regel «`}` typen springt de regel opnieuw in». Die regel bewerkt een regel die u al af had, en het is het meest bekritiseerde gedrag van elke bewerker die het heeft.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Hoofdletters en naamgevingsafspraken",
        summary: "Acht omzettingen, waaronder camelCase, snake_case en kebab-case.",
        keywords: ["hoofdletters", "kleine letters", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Toegepast op de selectie. Ze wonen allemaal in het menu `Opmaak`."),
            .table(
                headers: ["Opdracht", "`tổng doanh thu` wordt"],
                rows: [
                    ["HOOFDLETTERS", "`TỔNG DOANH THU`"],
                    ["kleine letters", "`tổng doanh thu`"],
                    ["Elk Woord Met Hoofdletter", "`Tổng Doanh Thu`"],
                    ["Hoofdletter aan het zinsbegin", "`Tổng doanh thu`"],
                    ["Hoofdletters omkeren", "Draait elk teken om"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                De laatste drie halen de Vietnamese accenten weg, omdat ze **codenamen** opleveren — waar \
                letters met accenten meestal niet toegestaan zijn.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Commentaar en haakjes",
        summary: "⌘/ gebruikt het eigen teken van elke taal; ⌃⌘B springt naar het bijbehorende haakje.",
        keywords: ["commentaar", "haakje", "cmd+/", "koppelen"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` kiest het commentaarteken **naar de taal van het document**: `#` voor Python, `//` \
                voor Rust en C, `<!-- -->` voor XML en HTML.
                """),
            .heading("Het hele blok gaat één kant op"),
            .paragraph("""
                Als ook maar één regel in het blok nog zonder commentaar is, becommentarieert de opdracht \
                **alles**. Regel voor regel beslissen zou van een half becommentarieerd blok een schaakbord \
                maken. Het teken wordt op de ondiepste inspringing van het blok gezet, zodat het blok zijn \
                vorm houdt.
                """),
            .heading("Naar het bijbehorende haakje springen"),
            .bullets([
                "`⌃⌘B` springt naar het haakje dat past bij dat onder de cursor.",
                "Haakjes binnen **tekenreeksen** of **commentaar** tellen niet mee — een lichte ontleder onderscheidt ze.",
                "Voorbij **1 MB** weigert de opdracht en zegt het, in plaats van halverwege te ankeren en te raden. Het verkeerde paar oplichten is erger dan er geen oplichten.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Ongedaan maken en klembord",
        summary: "Onbeperkte geschiedenis van ongedaan maken, en een klembord met meerdere plaatsen.",
        keywords: ["ongedaan maken", "opnieuw", "klembord", "plakken", "geschiedenis"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Ongedaan maken / Opnieuw"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Knippen / Kopiëren / Plakken"),
                HelpShortcut("⇧⌘V", "Klembordgeschiedenis"),
            ]),
            .heading("Een massale bewerking is ÉÉN stap"),
            .paragraph("""
                Een miljoen regels sorteren, tienduizend voorkomens vervangen, in vijfduizend regels \
                invoegen met de kolombewerker — elk daarvan wordt met **één** `⌘Z` ongedaan gemaakt.
                """),
            .paragraph("""
                De geschiedenis van ongedaan maken woont in GEditors eigen tekstbuffer en niet in de \
                `UndoManager` van het systeem, juist daarom: de `UndoManager` telt toetsaanslagen.
                """),
            .heading("Klembordgeschiedenis"),
            .paragraph("""
                `⇧⌘V` opent een lijst van wat u onlangs hebt gekopieerd en plakt het item dat u kiest. \
                Handig wanneer u twee fragmenten op veel plaatsen moet afwisselen.
                """),
        ]
    )
}
