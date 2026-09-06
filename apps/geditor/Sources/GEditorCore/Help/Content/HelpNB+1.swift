import Foundation

/// Norsk hjelpeinnhold (bokmål) — del 1: kom i gang og redigering.
///
/// **Emnenes `id` oversettes ALDRI.** Det er dem `.seeAlso` peker på, dem menyen åpner, og de lar
/// hjelpevinduet bytte språk **uten å kaste leseren tilbake til innholdsfortegnelsen**. Endrer man en
/// id, ryker alle lenkene — i alle bøkene på én gang.
///
/// Menytitlene i `commands:` blir stående på vietnamesisk: de må stemme ord for ord med de virkelige
/// menypunktene, noe `HelpCoverage` kontrollerer nettopp gjennom den strengen.
enum HelpNB {}

extension HelpNB {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Kom i gang",
        summary: "Hva GEditor gjør, og hvor de første fem minuttene gjør mest nytte.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Hva GEditor er",
        summary: "En tekst- og dataredigerer i gigabyteskala for macOS som snakker vietnamesisk.",
        keywords: ["introduksjon", "velkommen", "oversikt", "om"],
        blocks: [
            .paragraph("""
                GEditor åpner en **fil på 1 GB uten å lese 1 GB inn i minnet**. Den leser gjennom et \
                glidende vindu over en minnekartlagt fil, så en logg med 200 millioner linjer eller en \
                CSV med en million rader åpnes på omtrent et sekund og ruller jevnt.
                """),
            .paragraph("""
                Utover redigering er den en **arbeidsbenk for data**: se en CSV som tabell, rydd i \
                den, vurder kvaliteten, spør den med SQL, grav etter avvik og tendenser, og lag så en \
                rapport. Og den leser de gamle vietnamesiske tegnkodingene som de fleste verktøy i dag \
                har glemt.
                """),
            .heading("Seks ting verdt å prøve først"),
            .table(
                headers: ["Oppgave", "Hvor"],
                rows: [
                    ["Åpne en stor fil uten å vente", "Dra den inn i vinduet — se `Å åpne store filer`"],
                    ["Rette mange steder samtidig", "`⌘D` legger til neste treff, så skriver du én gang"],
                    ["Søke med et regulært uttrykk", "`⌘F`, slå på Regex — motoren er PCRE2 med JIT"],
                    ["Se en CSV som tabell", "`⌥⌘T` — en million rader ruller fortsatt jevnt"],
                    ["Rydde i en rotete datatabell", "`⇧⌘L` Ryddebenken — forhåndsvis før du bruker"],
                    ["Åpne en vietnamesisk fil som viser rot", "Klikk på tegnkodingen på statuslinjen"],
                ]
            ),
            .note("""
                Kommer du fra Notepad++? Det finnes en side som sammenligner de to tastaturoppsettene, \
                for noen få taster **bytter plass** på macOS i stedet for bare å gjøre `Ctrl` om til \
                `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Dine første fem minutter",
        summary: "Tolv snarveier dekker det meste av det daglige arbeidet.",
        keywords: ["snarvei", "taster", "start", "grunnlag"],
        blocks: [
            .paragraph("""
                Du trenger ikke å lære alt. De tolv tastene nedenfor dekker det meste av hverdagen; \
                slå opp resten når du trenger det.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Åpne en fil"),
                HelpShortcut("⇧⌘O", "Åpne en hel mappe som arbeidsområde"),
                HelpShortcut("⌘T", "Ny fane"),
                HelpShortcut("⌘S", "Lagre"),
                HelpShortcut("⌘F", "Søk"),
                HelpShortcut("⌥⌘F", "Søk og erstatt"),
                HelpShortcut("⇧⌘F", "Søk i en hel mappe"),
                HelpShortcut("⌘D", "Legg til neste forekomst av markeringen"),
                HelpShortcut("⌘L", "Gå til linje"),
                HelpShortcut("⌘/", "Kommenter linjen med språkets eget tegn"),
                HelpShortcut("⌥⌘T", "Veksle mellom tabell og tekst (CSV-filer)"),
                HelpShortcut("⌘?", "Åpne dette hjelpevinduet igjen"),
            ]),
            .heading("Tre ting som overrasker nye brukere"),
            .bullets([
                "**En masseoperasjon er ETT angretrinn**, selv når den berører en million linjer. Sortert feil? Én `⌘Z`, og den er borte.",
                "**Økten gjenoppretter seg selv.** Avslutt og åpne igjen: fanene kommer tilbake der de var, også de ulagrede. Ingenting å trykke på.",
                "**Å skrive uten aksenter finner likevel ord med dem** i alle søke- og filterfelt — skriv `hue` for å få `Huế`, `da nang` for å få `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Hva prøver du å gjøre?",
        summary: "En oppslagstabell fra virkelige oppgaver til kapittelet som dekker dem.",
        keywords: ["indeks", "oppslag", "hvordan"],
        blocks: [
            .paragraph("""
                Innholdsfortegnelsen til venstre er ordnet etter **funksjon**. Denne tabellen er \
                ordnet etter **oppgave**, for de to rekkefølgene faller ikke sammen.
                """),
            .table(
                headers: ["Jeg trenger å…", "Se"],
                rows: [
                    ["Rette samme sted på hundrevis av linjer", "Flere markører · Blokkmarkering"],
                    ["Omformatere i mengde med et regulært uttrykk", "Søk og erstatt · Regulære uttrykk"],
                    ["Gjenta en rekke handlinger", "Makroer"],
                    ["Åpne en CSV noen har sendt meg", "CSV-tabellen"],
                    ["Rydde i en rotete tabell: blandede datoer, tall som tekst", "Ryddeprosessen"],
                    ["Vurdere om en tabell kan stoles på", "Vurdering av datakvalitet"],
                    ["Finne avvik, tendenser, klynger", "Graveprosessen"],
                    ["Stille spørsmål i SQL", "Å spørre en CSV med SQL"],
                    ["Utgi en rapport med tall som regnes om", "`.greport.md`-rapporter"],
                    ["Tegne et diagram inne i et dokument", "Mermaid"],
                    ["Åpne en vietnamesisk fil som viser rot", "Vietnamesiske tegnkodinger"],
                    ["Automatisere fra skallet eller AppleScript", "Automatisering"],
                    ["Farge et format firmaet mitt fant på", "Selvdefinerte språk"],
                ]
            ),
            .note("""
                Ikke nevnt? Søkefeltet øverst til venstre ser i **brødtekst og kodeeksempler**, så det \
                å skrive en naken innstillingsnøkkel som `fail_under` lander på riktig side.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Å åpne store filer",
        summary: "Hvorfor 1 GB i det hele tatt åpnes, og hvor GEditor nekter med vilje i stedet for å gjette.",
        keywords: ["stor fil", "gigabyte", "1gb", "logg", "mmap", "treg", "ytelse"],
        blocks: [
            .paragraph("""
                Filen er **minnekartlagt** og leses gjennom et glidende vindu; den delen du redigerer, \
                bor i en stykketabell. I praksis: åpningstiden avhenger nesten ikke av filstørrelsen, \
                og det gjør heller ikke minnet programmet holder på.
                """),
            .heading("Hvor den nekter med vilje"),
            .paragraph("""
                Noen få beregninger måtte ha lest hele filen inn i én streng — nettopp det denne \
                arkitekturen unngår. Der **sier GEditor fra** i stedet for stille å krype eller gjette:
                """),
            .table(
                headers: ["Handling", "Tak", "Over det"],
                rows: [
                    ["Parentesmatching", "1 MB", "Nekter og sier det — å utheve feil par er verre enn ingenting"],
                    ["Synlig kolonne på statuslinjen", "200 kB", "Faller tilbake til å telle byte og merker det med `~`, så betydningen er synlig"],
                    ["Markdown-forhåndsvisning", "4 MB", "Nekter og forklarer"],
                ]
            ),
            .warning("""
                Et tall som ser likt ut, men betyr noe annet, er den verste sorten feil. Derfor står \
                det `~1234` og ikke `1234` når kolonnen er over taket.
                """),
            .heading("Tips til loggfiler"),
            .bullets([
                "`Fil ▸ Følg fil (tail -f)` legger til det som skrives til slutten. Dokumentet blir **skrivebeskyttet** mens det følges — å skrive mens ny tekst strømmer inn betyr to skrivere om ett dokument, og taperen er alltid det du nettopp skrev.",
                "Logglinjer **farges etter alvorlighetsgrad** og kan filtreres etter nivå.",
                "**Dokumentkartet** (`⌥⌘M`) beskriver hele filen, ikke bare den synlige delen.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App Store-utgaven mot direkte nedlasting",
        summary: "Tre funksjoner bare den direkte utgaven har, og hvorfor.",
        keywords: ["app store", "sandkasse", "nedlasting", "cli", "programtillegg", "forskjell"],
        blocks: [
            .paragraph("""
                GEditor kommer i to utgaver. De kommer fra **samme kildekode**, og programmet vet ved \
                oppstart hvilken det er. Forskjellen er hva App Sandbox tillater.
                """),
            .table(
                headers: ["Funksjon", "App Store", "Direkte nedlasting"],
                rows: [
                    ["All redigering, CSV, rydding, graving, rapportering", "Ja", "Ja"],
                    ["Kommandolinjeverktøyet `geditor`", "Nei", "Ja"],
                    ["Å filtrere tekst gjennom en ytre kommando", "Nei", "Ja"],
                    ["Innebygde programtillegg (egen prosess)", "Nei", "Ja"],
                    ["Selvoppdatering", "Gjennom App Store", "Inne i programmet"],
                ]
            ),
            .paragraph("""
                Hvert «Nei» ovenfor kommer av samme regel: sandkassen **forbyr å kjøre kode utenfor \
                programmet**. Det er prisen for App Store-distribusjon, ikke en forglemmelse.
                """),
            .note("""
                I App Store-utgaven **blir de kommandoene stående i menyen** og forklarer hvorfor de \
                ikke er tilgjengelige, i stedet for å forsvinne. Et manglende menypunkt er et spørsmål \
                til brukerstøtten; et svar på stedet er det ikke.
                """),
            .heading("Filtilgang i App Store-utgaven"),
            .paragraph("""
                Den sandkasseinnesperrede utgaven kan bare berøre filer du selv har åpnet eller dratt \
                inn. GEditor holder et **sikkerhetsavgrenset bokmerke** for hver fane og for \
                arbeidsmappen, så økten din åpnes igjen etter avslutning uten å spørre om lov på nytt.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Redigering

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Redigering",
        summary: "Rett mange steder samtidig, arbeid med linjer, og de skjulte reglene det er verdt å kunne først.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Flere markører",
        summary: "Marker alle stedene som passer, skriv én gang, endre dem alle.",
        keywords: ["multimarkør", "cmd+d", "flere markeringer"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Dette erstatter de fleste av øyeblikkene der du var i ferd med å skrive et regulært \
                uttrykk. Marker et ord, trykk `⌘D` noen ganger for å samle de neste forekomstene, og \
                skriv så — hvert sted endres samtidig.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Legg neste forekomst til markeringen"),
                HelpShortcut("⌘ + klikk", "Sett enda en markør der du klikker"),
                HelpShortcut("Esc", "Fjern dem alle, tilbake til én markør"),
                HelpShortcut("⌥ + dra", "Blokkmarkering (en annen vei til mange markører)"),
            ]),
            .heading("Regler det er verdt å kunne"),
            .bullets([
                "Å skrive, slette og lime inn på tvers av mange markører er **ett** angretrinn, ikke ett per markør.",
                "Markørene overlever piltastbevegelse — hele gruppen flytter seg sammen.",
                "`⌘D` hopper over steder som allerede er i markeringen, så for mange trykk stabler aldri markører oppå hverandre.",
            ]),
            .note("""
                `⌘D` på et ord inne i en lang streng pleide å være tregt. Ordgrensegjenkjenningen \
                leser nå i porsjoner — omtrent **42× raskere** på en streng på 1 MB, noe som gjør \
                dette brukbart på datafiler og ikke bare på kildekode.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Blokkmarkering av kolonner",
        summary: "Marker et rektangel over mange linjer — med musen eller fra tastaturet.",
        keywords: ["kolonnemodus", "blokkmarkering", "alt-dra", "rektangel", "tastatur"],
        blocks: [
            .paragraph("""
                Hold `⌥` nede og dra for å markere en **rektangulær blokk**. Å skrive, slette og lime \
                inn følger alle blokken. Å lime inn en blokk ved én markør bevarer likevel rektangelet.
                """),
            .shortcuts([
                HelpShortcut("⌥ + dra", "Marker en blokk"),
                HelpShortcut("⌥⌘← →", "Utvid blokken én kolonne til venstre/høyre"),
                HelpShortcut("⌥⌘↑ ↓", "Utvid blokken én linje opp/ned"),
            ]),
            .paragraph("""
                Tastaturveien er ikke en nødløsning for musen: å markere en blokk på 40 linjer ved å \
                dra betyr å dra gjennom en rulling, mens `⌥⌘` + piler beholder presisjon kolonne for \
                kolonne. Enhver **annen** tast (eller det å skrive) avslutter blokken du holdt på å \
                utvide.
                """),
            .heading("Kolonner her er SYNLIGE kolonner"),
            .paragraph("""
                En TAB utvides til neste stopp ved din tabulatorbredde i stedet for å telle som én \
                kolonne. Det er det som får tabulatorinnrykkede og mellomromsinnrykkede linjer til å \
                **stå på linje slik de gjør på skjermen**.
                """),
            .paragraph("Flerbytetekst er fortsatt én kolonne: `Nguyễn` opptar seks kolonner, ikke ni."),
            .table(
                headers: ["Situasjon", "Hva GEditor gjør"],
                rows: [
                    ["Målkolonnen lander midt i en TAB", "Klikker til nærmeste kant; uavgjort går til venstre"],
                    ["En linje er kortere enn startkolonnen", "Den linjen bidrar med en tom markering og tar likevel imot skrevet tekst"],
                    ["Å lime inn en blokk ved én markør", "Beholder rektangelet og setter inn nedover linjene under"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Kolonneredigereren",
        summary: "Sett inn tekst, en tallrekke eller en datorekke på hver linje i en blokk.",
        keywords: ["kolonneredigerer", "nummerering", "sekvens", "rekke"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Marker en kolonneblokk, og åpne så `Rediger ▸ Column Editor…` (`⌥⌘C`). Dialogen har en \
                **forhåndsvisning** før noe brukes.
                """),
            .table(
                headers: ["Modus", "Parametre", "Bruk når"],
                rows: [
                    ["Tekst", "En fast streng", "Du legger til samme for-/etterstavelse på hver linje"],
                    ["Tallrekke", "Start · steg · grunntall 2·8·10·16 · nullfyll", "Du nummererer rader eller lager koder"],
                    ["Datorekke", "Første dato · steg i dager", "Du lager en kolonne med fortløpende datoer"],
                ]
            ),
            .code(language: "text", caption: "Nummerering med nullfyll, start 1, steg 1",
                  source: """
                    Før:              Etter (tallrekke, fylt til 3 sifre):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Et **negativt** steg er gyldig — å telle ned virker.",
                "Å sette inn i 5 000 linjer er fortsatt **ett** angretrinn.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Linjehandlinger",
        summary: "Sorter, fjern duplikater, flytt, slå sammen, del, dupliser, slett.",
        keywords: ["sorter", "dupliser", "duplikater", "flytt linje", "slå sammen", "del"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Med en markering kjører kommandoen på markeringen; uten en kjører den på **hele \
                dokumentet**. Hver kommando her er ett angretrinn.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Dupliser linjen"),
                HelpShortcut("⌘K", "Slett linjen"),
                HelpShortcut("⌥↑ / ⌥↓", "Flytt linjen opp / ned"),
            ]),
            .heading("Tre sorteringsmåter, og hvilken man velger"),
            .table(
                headers: ["Slag", "`file2` mot `file10`", "Brukes til"],
                rows: [
                    ["A→Z / Z→A", "`file10` kommer før `file2`", "Vanlige ordlister"],
                    ["Naturlig", "`file2` kommer før `file10`", "Filnavn, kodede id-er, versjoner"],
                ]
            ),
            .paragraph("""
                **Naturlig** sortering leser sifferløp som tall. Det er nesten alltid det du vil ha \
                når listen er nummerert.
                """),
            .heading("Fjerning av duplikater"),
            .bullets([
                "**Hele dokumentet** — fjern hver linje som har vært der før, behold den første.",
                "**Bare nabolinjer** — slå sammen like nabolinjer, som Unix' `uniq`.",
            ]),
            .heading("Å slå sammen og dele"),
            .bullets([
                "**Slå sammen linjer** smelter de markerte linjene til én.",
                "**Del etter lengde** kutter lange linjer ved et gitt tegnantall.",
                "**Del etter tegn** kutter ved hver forekomst av et tegn du skriver — for eksempel for å dele én CSV-rad i cellene sine.",
            ]),
            .note("""
                Å duplisere filens **siste linje** legger til det manglende linjeskiftet; å slette \
                gjennom dokumentets slutt sluker også den forrige linjens linjeskift. Begge skiller \
                seg fra den naive utførelsen, og begge finnes for at filen ikke skal ende med en løs \
                tom linje — eller uten en.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Blanktegn og innrykk",
        summary: "Rydd løse blanktegn, gjør om TAB ↔ mellomrom, og én bryter verdt å tenke over.",
        keywords: ["blanktegn", "tabulator", "mellomrom", "innrykk", "tomme linjer"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Kommando", "Hva den gjør"],
                rows: [
                    ["Fjern tomme linjer", "Fjerner hver linje uten noe på"],
                    ["Slå sammen tomme linjer på rad", "Flere tomme linjer på rad blir til én"],
                    ["Klipp blanktegn i linjeslutt", "Fjerner løse mellomrom og tabulatorer i slutten av hver linje"],
                    ["Tab → mellomrom", "Gjør TAB om til mellomrom ved gjeldende tabulatorbredde"],
                    ["Mellomrom → Tab", "Den andre veien"],
                ]
            ),
            .heading("Innrykk per språk"),
            .paragraph("""
                Klikk på `Tab: 4` på statuslinjen. Den øvre delen av menyen endrer det for **hele \
                programmet**; den nedre — `Bare for Go`, `Bare for Python`… — gjelder bare språket til \
                den åpne filen, og husker om det skal brukes tabulatorer eller mellomrom.
                """),
            .paragraph("""
                Folk velger ikke innrykk etter smak, men etter **skikk i fellesskapet**: Go bruker \
                tabulatorer (`gofmt` overstyrer alt annet), Python fire mellomrom etter PEP 8, \
                JavaScript og YAML som regel to. Ett tall for alle språk betyr at hver fil du rører, \
                får linjer du aldri har redigert.
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
                Å erklære det i `settings.json` virker også — nøkkelen er språkkoden (`go`, `python`, \
                `javascript`…). Språk som ikke står der, bruker den felles `tabWidth`.
                """),
            .heading("Hvorfor «klipp ved lagring» er AV som standard"),
            .paragraph("""
                Bryteren `Fil ▸ Klipp blanktegn i linjeslutt ved lagring` redigerer **linjer du aldri \
                har rørt**. Slått på som standard blir en rettelse på ett ord i en annens arkiv til en \
                forskjell på tusen linjer, og korrekturleseren finner ikke den virkelige endringen.
                """),
            .paragraph("""
                Når den er på, er klippingen et **eget angretrinn** lagt før skrivingen — én angring \
                fører dokumentet tilbake slik det var, uten å miste det du nettopp lagret.
                """),
            .heading("Automatisk innrykk"),
            .bullets([
                "En ny linje arver den forrige linjens innrykk, pluss ett nivå etter et åpnende tegn — `{` i krøllparentesspråk, `:` i Python og YAML.",
                "Målingen skjer i **synlige kolonner**, så filer som blander tabulatorer og mellomrom, står likevel på linje på skjermen.",
                "Det finnes **ingen** regel om at «å skrive `}` retter linjens innrykk». Den regelen redigerer en linje du allerede er ferdig med, og den er den mest påklagede oppførselen i enhver redigerer som har den.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Store/små bokstaver og navnekonvensjoner",
        summary: "Åtte omgjøringer, blant dem camelCase, snake_case og kebab-case.",
        keywords: ["store bokstaver", "små bokstaver", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Brukes på markeringen. Alle ligger i menyen `Format`."),
            .table(
                headers: ["Kommando", "`tổng doanh thu` blir"],
                rows: [
                    ["STORE BOKSTAVER", "`TỔNG DOANH THU`"],
                    ["små bokstaver", "`tổng doanh thu`"],
                    ["Stor Forbokstav I Hvert Ord", "`Tổng Doanh Thu`"],
                    ["Stor forbokstav i setningen", "`Tổng doanh thu`"],
                    ["Bytt om", "Snur hvert tegn"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                De tre siste fjerner vietnamesiske aksenter, fordi de lager **navn i kode** — der \
                bokstaver med aksent som regel ikke er tillatt.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Kommentarer og parentesmatching",
        summary: "⌘/ bruker hvert språks eget tegn; ⌃⌘B hopper til den motsvarende parentesen.",
        keywords: ["kommentar", "parentes", "cmd+/", "matching"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` velger kommentartegnet **etter dokumentets språk**: `#` for Python, `//` for Rust \
                og C, `<!-- -->` for XML og HTML.
                """),
            .heading("Hele blokken går samme vei"),
            .paragraph("""
                Er bare én linje i blokken fortsatt ukommentert, kommenterer kommandoen **alt**. Å \
                avgjøre det linje for linje ville gjøre en halvt kommentert blokk til et sjakkbrett. \
                Tegnet settes inn ved blokkens laveste innrykk, så blokken beholder formen sin.
                """),
            .heading("Å hoppe til den motsvarende parentesen"),
            .bullets([
                "`⌃⌘B` hopper til parentesen som motsvarer den ved markøren.",
                "Parenteser inne i **strenger** eller **kommentarer** teller ikke — en lett lekser skiller dem.",
                "Over **1 MB** nekter kommandoen og sier det, i stedet for å forankre seg halvveis og gjette. Å utheve feil par er verre enn å utheve ingen.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Angre og utklippstavlen",
        summary: "Ubegrenset angrehistorikk og en utklippstavle med flere plasser.",
        keywords: ["angre", "gjenta", "utklippstavle", "lim inn", "historikk"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Angre / gjenta"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Klipp ut / kopier / lim inn"),
                HelpShortcut("⇧⌘V", "Utklippstavlens historikk"),
            ]),
            .heading("En masseoperasjon er ETT trinn"),
            .paragraph("""
                Å sortere en million linjer, å erstatte ti tusen treff, å sette inn i fem tusen linjer \
                med kolonneredigereren — hver av dem angres med **én** `⌘Z`.
                """),
            .paragraph("""
                Angrehistorikken bor i GEditors egen tekstbuffer i stedet for i systemets \
                `UndoManager`, nettopp av den grunn: `UndoManager` teller tastetrykk.
                """),
            .heading("Utklippstavlens historikk"),
            .paragraph("""
                `⇧⌘V` åpner en liste over det du har kopiert nylig, og limer inn det du velger. \
                Nyttig når du må veksle mellom to biter mange steder.
                """),
        ]
    )
}
