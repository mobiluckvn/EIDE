import Foundation

/// Dansk hjælpeindhold — del 1: kom i gang og redigering.
///
/// **Emnernes `id` oversættes ALDRIG.** Det er dem, `.seeAlso` peger på, dem menuen åbner, og de gør
/// det muligt for hjælpevinduet at skifte sprog **uden at kaste læseren tilbage til indholdsfortegnelsen**.
/// Ændrer man et id, går alle links i stykker — i alle bøger på én gang.
///
/// Menutitlerne i `commands:` bliver stående på vietnamesisk: de skal stemme ord for ord med de
/// virkelige menupunkter, hvilket `HelpCoverage` kontrollerer netop gennem den streng.
enum HelpDA {}

extension HelpDA {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Kom i gang",
        summary: "Hvad GEditor gør, og hvor de første fem minutter gør mest gavn.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Hvad GEditor er",
        summary: "En tekst- og dataeditor i gigabyteskala til macOS, der taler vietnamesisk.",
        keywords: ["introduktion", "velkommen", "oversigt", "om"],
        blocks: [
            .paragraph("""
                GEditor åbner en **fil på 1 GB uden at læse 1 GB ind i hukommelsen**. Den læser gennem \
                et glidende vindue over en hukommelsesafbildet fil, så en log med 200 millioner linjer \
                eller en CSV med en million rækker åbner på omkring et sekund og ruller jævnt.
                """),
            .paragraph("""
                Ud over redigering er den en **arbejdsbænk til data**: se en CSV som tabel, rens den, \
                bedøm dens kvalitet, spørg den med SQL, gennemgrav den for afvigelser og tendenser, og \
                lav så en rapport. Og den læser de gamle vietnamesiske tegnkodninger, som de fleste \
                værktøjer i dag har glemt.
                """),
            .heading("Seks ting værd at prøve først"),
            .table(
                headers: ["Opgave", "Hvor"],
                rows: [
                    ["Åbne en stor fil uden at vente", "Træk den ind i vinduet — se `At åbne store filer`"],
                    ["Rette mange steder på én gang", "`⌘D` tilføjer det næste træf, så skriver du én gang"],
                    ["Søge med et regulært udtryk", "`⌘F`, slå Regex til — motoren er PCRE2 med JIT"],
                    ["Se en CSV som tabel", "`⌥⌘T` — en million rækker ruller stadig jævnt"],
                    ["Rense en rodet datatabel", "`⇧⌘L` Rensebænken — se resultatet før du anvender"],
                    ["Åbne en vietnamesisk fil, der viser volapyk", "Klik på tegnkodningen på statuslinjen"],
                ]
            ),
            .note("""
                Kommer du fra Notepad++? Der findes en side, der sammenligner de to tastaturopsætninger, \
                for nogle få taster **bytter plads** på macOS i stedet for blot at gøre `Ctrl` til `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Dine første fem minutter",
        summary: "Tolv genveje dækker det meste af det daglige arbejde.",
        keywords: ["genvej", "taster", "start", "grundlag", "hurtig start"],
        blocks: [
            .paragraph("""
                Du behøver ikke at lære det hele. De tolv taster nedenfor dækker det meste af det \
                daglige arbejde; slå resten op, når du får brug for det.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Åbn en fil"),
                HelpShortcut("⇧⌘O", "Åbn en hel mappe som arbejdsområde"),
                HelpShortcut("⌘T", "Nyt faneblad"),
                HelpShortcut("⌘S", "Gem"),
                HelpShortcut("⌘F", "Søg"),
                HelpShortcut("⌥⌘F", "Søg og erstat"),
                HelpShortcut("⇧⌘F", "Søg i en hel mappe"),
                HelpShortcut("⌘D", "Tilføj næste forekomst af markeringen"),
                HelpShortcut("⌘L", "Gå til linje"),
                HelpShortcut("⌘/", "Udkommentér linjen med sprogets eget tegn"),
                HelpShortcut("⌥⌘T", "Skift mellem tabel og tekst (CSV-filer)"),
                HelpShortcut("⌘?", "Åbn dette hjælpevindue igen"),
            ]),
            .heading("Tre ting, der overrasker nye brugere"),
            .bullets([
                "**En masseoperation er ÉT fortrydelsestrin**, også når den rører en million linjer. Sorteret forkert? Ét `⌘Z`, og det er væk.",
                "**Arbejdsomgangen genskaber sig selv.** Slut og åbn igen: fanebladene kommer tilbage, hvor de var, også de ugemte. Intet at trykke på.",
                "**At skrive uden accenter finder stadig ord med dem** i alle søge- og filterfelter — skriv `hue` for at få `Huế`, `da nang` for at få `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Hvad prøver du at gøre?",
        summary: "En opslagstabel fra virkelige opgaver til det kapitel, der dækker dem.",
        keywords: ["indeks", "opslag", "hvordan", "hvordan gør jeg"],
        blocks: [
            .paragraph("""
                Indholdsfortegnelsen til venstre er ordnet efter **funktion**. Denne tabel er ordnet \
                efter **opgave**, for de to rækkefølger falder ikke sammen.
                """),
            .table(
                headers: ["Jeg har brug for at…", "Se"],
                rows: [
                    ["Rette samme sted på hundredvis af linjer", "Flere markører · Blokmarkering"],
                    ["Omformatere i mængde med et regulært udtryk", "Søg og erstat · Regulære udtryk"],
                    ["Gentage en række handlinger", "Makroer"],
                    ["Åbne en CSV, nogen har sendt mig", "CSV-tabellen"],
                    ["Rense en rodet tabel: blandede datoer, tal som tekst", "Renseforløbet"],
                    ["Bedømme om en tabel kan stoles på", "Datakvalitetsbedømmelse"],
                    ["Finde afvigelser, tendenser, klynger", "Udgravningsforløbet"],
                    ["Stille spørgsmål i SQL", "At spørge en CSV med SQL"],
                    ["Udgive en rapport, hvis tal genberegnes", "`.greport.md`-rapporter"],
                    ["Tegne et diagram inde i et dokument", "Mermaid"],
                    ["Åbne en vietnamesisk fil, der viser volapyk", "Vietnamesiske tegnkodninger"],
                    ["Automatisere fra skallen eller AppleScript", "Automatisering"],
                    ["Farve et format, mit firma har fundet på", "Selvdefinerede sprog"],
                ]
            ),
            .note("""
                Ikke nævnt? Søgefeltet øverst til venstre kigger i **brødtekst og kodeeksempler**, så \
                det at skrive en nøgen konfigurationsnøgle som `fail_under` lander på den rigtige side.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "At åbne store filer",
        summary: "Hvorfor 1 GB overhovedet åbner, og hvor GEditor nægter med vilje i stedet for at gætte.",
        keywords: ["stor fil", "gigabyte", "1gb", "log", "mmap", "langsom", "ydelse"],
        blocks: [
            .paragraph("""
                Filen er **hukommelsesafbildet** og læses gennem et glidende vindue; den del, du \
                redigerer, ligger i en stykketabel. I praksis: åbningstiden afhænger næsten ikke af \
                filstørrelsen, og det gør den hukommelse, programmet holder på, heller ikke.
                """),
            .heading("Hvor den nægter med vilje"),
            .paragraph("""
                Nogle få beregninger ville skulle læse hele filen ind i én streng — netop det, denne \
                arkitektur undgår. Dér **siger GEditor fra** i stedet for stille at kravle eller gætte:
                """),
            .table(
                headers: ["Handling", "Loft", "Derover"],
                rows: [
                    ["Parentesmatchning", "1 MB", "Nægter og siger det — at fremhæve det forkerte par er værre end intet"],
                    ["Synlig kolonne på statuslinjen", "200 KB", "Falder tilbage til at tælle bytes og markerer det med `~`, så betydningen er synlig"],
                    ["Markdown-forhåndsvisning", "4 MB", "Nægter og forklarer"],
                ]
            ),
            .warning("""
                Et tal, der ser ens ud, men betyder noget andet, er den værste slags forkert. Derfor \
                står der `~1234` og ikke `1234`, når kolonnen er over loftet.
                """),
            .heading("Tips til logfiler"),
            .bullets([
                "`Fil ▸ Følg fil (tail -f)` føjer til, hvad der bliver skrevet til slutningen. Dokumentet bliver **skrivebeskyttet**, mens det følges — at skrive, mens ny tekst strømmer ind, betyder to skrivere om ét dokument, og taberen er altid det, du lige skrev.",
                "Loglinjer **farves efter alvorsgrad** og kan filtreres efter niveau.",
                "**Dokumentkortet** (`⌥⌘M`) beskriver hele filen, ikke kun den synlige del.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App Store-udgaven mod direkte hentning",
        summary: "Tre funktioner, kun den direkte udgave har, og hvorfor.",
        keywords: ["app store", "sandkasse", "hentning", "cli", "plugin", "forskel"],
        blocks: [
            .paragraph("""
                GEditor udkommer i to udgaver. De kommer fra **samme kildekode**, og programmet ved ved \
                start, hvilken det er. Forskellen er, hvad App Sandbox tillader.
                """),
            .table(
                headers: ["Funktion", "App Store", "Direkte hentning"],
                rows: [
                    ["Al redigering, CSV, rensning, udgravning, rapportering", "Ja", "Ja"],
                    ["Kommandolinjeværktøjet `geditor`", "Nej", "Ja"],
                    ["At filtrere tekst gennem en ydre kommando", "Nej", "Ja"],
                    ["Indbyggede plugins (egen proces)", "Nej", "Ja"],
                    ["Selvopdatering", "Gennem App Store", "Inde i programmet"],
                ]
            ),
            .paragraph("""
                Hvert »Nej« ovenfor kommer af samme regel: sandkassen **forbyder at køre kode uden for \
                programmet**. Det er prisen for at udkomme i App Store, ikke en forglemmelse.
                """),
            .note("""
                I App Store-udgaven **bliver de kommandoer stående i menuen** og forklarer, hvorfor de \
                ikke er til rådighed, i stedet for at forsvinde. Et manglende menupunkt er et spørgsmål \
                til supporten; et svar på stedet er ikke.
                """),
            .heading("Filadgang i App Store-udgaven"),
            .paragraph("""
                Den indkapslede udgave kan kun røre filer, du selv har åbnet eller trukket ind. GEditor \
                gemmer et **sikkerhedsafgrænset bogmærke** for hvert faneblad og for arbejdsmappen, så \
                din arbejdsomgang åbner igen efter afslutning uden at spørge om lov på ny.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Redigering

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Redigering",
        summary: "Ret mange steder på én gang, arbejd med linjer, og de skjulte regler, det er værd at kende først.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Flere markører",
        summary: "Markér alle steder, der passer, skriv én gang, ret dem alle.",
        keywords: ["multimarkør", "flere markører", "cmd+d", "flere markeringer"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Dette erstatter de fleste af de øjeblikke, hvor du var ved at skrive et regulært \
                udtryk. Markér et ord, tryk `⌘D` nogle gange for at samle de næste forekomster, og \
                skriv så — hvert sted ændres på én gang.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Føj næste forekomst til markeringen"),
                HelpShortcut("⌘ + klik", "Sæt endnu en markør, hvor du klikker"),
                HelpShortcut("Esc", "Fjern dem alle, tilbage til én markør"),
                HelpShortcut("⌥ + træk", "Blokmarkering (en anden vej til mange markører)"),
            ]),
            .heading("Regler, det er værd at kende"),
            .bullets([
                "At skrive, slette og indsætte på tværs af mange markører er **ét** fortrydelsestrin, ikke ét pr. markør.",
                "Markørerne overlever piletastebevægelse — hele gruppen flytter sig sammen.",
                "`⌘D` springer steder over, der allerede er i markeringen, så for mange tryk aldrig stabler markører oven på hinanden.",
            ]),
            .note("""
                `⌘D` på et ord inde i en lang streng plejede at være langsomt. Ordgrænseregistreringen \
                læser nu i portioner — omkring **42× hurtigere** på en streng på 1 MB, hvilket gør \
                dette brugbart på datafiler og ikke kun på kildekode.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Blokmarkering af kolonner",
        summary: "Markér et rektangel over mange linjer — med musen eller fra tastaturet.",
        keywords: ["kolonnetilstand", "blokmarkering", "alt-træk", "rektangel", "tastatur", "piletaster"],
        blocks: [
            .paragraph("""
                Hold `⌥` nede og træk for at markere en **rektangulær blok**. At skrive, slette og \
                indsætte følger alle blokken. At indsætte en blok ved en enkelt markør bevarer stadig \
                rektanglet.
                """),
            .shortcuts([
                HelpShortcut("⌥ + træk", "Markér en blok"),
                HelpShortcut("⌥⌘← →", "Udvid blokken én kolonne til venstre/højre"),
                HelpShortcut("⌥⌘↑ ↓", "Udvid blokken én linje op/ned"),
            ]),
            .paragraph("""
                Tastaturvejen er ikke en nødløsning for musen: at markere en blok på 40 linjer ved at \
                trække betyder at trække gennem en rulning, mens `⌥⌘` + piletaster bevarer præcision \
                kolonne for kolonne. Enhver **anden** tast (eller det at skrive) afslutter den blok, du \
                var i gang med at udvide.
                """),
            .heading("Kolonner her er SYNLIGE kolonner"),
            .paragraph("""
                En TAB udvides til næste stop ved din tabulatorbredde i stedet for at tælle som én \
                kolonne. Det er det, der får tabulatorindrykkede og mellemrumsindrykkede linjer til at \
                **flugte, som de gør på skærmen**.
                """),
            .paragraph("Flerbytetekst er stadig én kolonne: `Nguyễn` fylder seks kolonner, ikke ni."),
            .table(
                headers: ["Situation", "Hvad GEditor gør"],
                rows: [
                    ["Målkolonnen lander midt i en TAB", "Springer til nærmeste kant; uafgjort går til venstre"],
                    ["En linje er kortere end startkolonnen", "Den linje bidrager med en tom markering og tager stadig imod skrevet tekst"],
                    ["At indsætte en blok ved en enkelt markør", "Bevarer rektanglet og indsætter ned ad linjerne nedenfor"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Kolonneeditoren",
        summary: "Indsæt tekst, en talrække eller en datorække på hver linje i en blok.",
        keywords: ["kolonneeditor", "nummerering", "sekvens", "række"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Markér en kolonneblok, og åbn så `Rediger ▸ Column Editor…` (`⌥⌘C`). Dialogen har en \
                **forhåndsvisning**, før noget anvendes.
                """),
            .table(
                headers: ["Tilstand", "Parametre", "Brug når"],
                rows: [
                    ["Tekst", "En fast streng", "Du føjer samme for-/efterstavelse til hver linje"],
                    ["Talrække", "Start · trin · grundtal 2·8·10·16 · nulfyld", "Du nummererer rækker eller danner koder"],
                    ["Datorække", "Første dato · trin i dage", "Du laver en kolonne med fortløbende datoer"],
                ]
            ),
            .code(language: "text", caption: "Nummerering med nulfyld, start 1, trin 1",
                  source: """
                    Før:              Efter (talrække, fyldt til 3 cifre):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Et **negativt** trin er gyldigt — at tælle ned virker.",
                "At indsætte i 5.000 linjer er stadig **ét** fortrydelsestrin.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Linjehandlinger",
        summary: "Sortér, fjern dubletter, flyt, sammenføj, opdel, fordobl, slet.",
        keywords: ["sortér", "fordobl", "dubletter", "flyt linje", "sammenføj", "opdel"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Med en markering kører kommandoen på markeringen; uden en kører den på **hele \
                dokumentet**. Hver kommando her er ét fortrydelsestrin.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Fordobl linjen"),
                HelpShortcut("⌘K", "Slet linjen"),
                HelpShortcut("⌥↑ / ⌥↓", "Flyt linjen op / ned"),
            ]),
            .heading("Tre slags sortering, og hvilken man vælger"),
            .table(
                headers: ["Slags", "`file2` mod `file10`", "Brug til"],
                rows: [
                    ["A→Z / Z→A", "`file10` kommer før `file2`", "Almindelige ordlister"],
                    ["Naturlig", "`file2` kommer før `file10`", "Filnavne, kodede id'er, versioner"],
                ]
            ),
            .paragraph("""
                **Naturlig** sortering læser cifferløb som tal. Det er næsten altid det, man vil have, \
                når listen er nummereret.
                """),
            .heading("Fjernelse af dubletter"),
            .bullets([
                "**Hele dokumentet** — fjern hver linje, der er set før, behold den første.",
                "**Kun nabolinjer** — slå ens nabolinjer sammen, som Unix' `uniq`.",
            ]),
            .heading("At sammenføje og opdele"),
            .bullets([
                "**Sammenføj linjer** slår de markerede linjer sammen til én.",
                "**Opdel efter længde** klipper lange linjer ved et givet antal tegn.",
                "**Opdel efter tegn** klipper ved hver forekomst af et tegn, du skriver — for eksempel til at dele én CSV-række i dens celler.",
            ]),
            .note("""
                At fordoble filens **sidste linje** tilføjer det manglende linjeskift; at slette gennem \
                dokumentets ende sluger også den foregående linjes linjeskift. Begge dele adskiller sig \
                fra den naive udførelse, og begge findes, for at filen ikke skal ende med en løs tom \
                linje — eller uden en.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Blanktegn og indrykning",
        summary: "Ryd op i løse blanktegn, omsæt TAB ↔ mellemrum, og én kontakt, det er værd at tænke over.",
        keywords: ["blanktegn", "tabulator", "mellemrum", "trim", "indrykning", "tomme linjer"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Kommando", "Hvad den gør"],
                rows: [
                    ["Fjern tomme linjer", "Fjerner hver linje uden noget på"],
                    ["Slå tomme linjer i træk sammen", "Flere tomme linjer i træk bliver til én"],
                    ["Klip blanktegn i linjeslutningen", "Fjerner løse mellemrum og tabulatorer i slutningen af hver linje"],
                    ["Tab → mellemrum", "Omsætter TAB til mellemrum ved den aktuelle tabulatorbredde"],
                    ["Mellemrum → Tab", "Den anden vej"],
                ]
            ),
            .heading("Indrykning pr. sprog"),
            .paragraph("""
                Klik på `Tab: 4` på statuslinjen. Den øverste del af menuen ændrer den for **hele \
                programmet**; den nederste — `Kun for Go`, `Kun for Python`… — gælder kun for den åbne \
                fils sprog og husker, om der skal bruges tabulatorer eller mellemrum.
                """),
            .paragraph("""
                Folk vælger ikke indrykning efter smag, men efter **sædvane i fællesskabet**: Go bruger \
                tabulatorer (`gofmt` overtrumfer alt andet), Python fire mellemrum efter PEP 8, \
                JavaScript og YAML som regel to. Ét tal for alle sprog betyder, at hver fil, du rører, \
                får linjer, du aldrig har redigeret.
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
                At erklære det i `settings.json` virker også — nøglen er sprogkoden (`go`, `python`, \
                `javascript`…). Sprog, der ikke står der, bruger den fælles `tabWidth`.
                """),
            .heading("Hvorfor »trim ved gemning« er SLÅET FRA som standard"),
            .paragraph("""
                Kontakten `Fil ▸ Klip blanktegn i linjeslutningen ved gemning` redigerer **linjer, du \
                aldrig har rørt**. Slået til som standard bliver en rettelse på ét ord i en andens \
                arkiv til en forskel på tusind linjer, og korrekturlæseren kan ikke finde den virkelige \
                ændring.
                """),
            .paragraph("""
                Når den er slået til, er klipningen et **selvstændigt fortrydelsestrin** lagt før \
                skrivningen — én fortrydelse fører dokumentet tilbage, som det var, uden at miste det, \
                du netop gemte.
                """),
            .heading("Automatisk indrykning"),
            .bullets([
                "En ny linje arver den foregående linjes indrykning plus ét niveau efter et åbnende tegn — `{` i klammesprog, `:` i Python og YAML.",
                "Målingen sker i **synlige kolonner**, så filer, der blander tabulatorer og mellemrum, stadig flugter på skærmen.",
                "Der er **ingen** regel om, at »at skrive `}` retter linjens indrykning«. Den regel redigerer en linje, du allerede er færdig med, og den er den mest beklagede adfærd i enhver editor, der har den.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Store/små bogstaver og navnekonventioner",
        summary: "Otte omsætninger, deriblandt camelCase, snake_case og kebab-case.",
        keywords: ["versaler", "store bogstaver", "små bogstaver", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Anvendes på markeringen. De ligger alle i menuen `Format`."),
            .table(
                headers: ["Kommando", "`tổng doanh thu` bliver"],
                rows: [
                    ["STORE BOGSTAVER", "`TỔNG DOANH THU`"],
                    ["små bogstaver", "`tổng doanh thu`"],
                    ["Stort Forbogstav I Hvert Ord", "`Tổng Doanh Thu`"],
                    ["Stort forbogstav i sætningen", "`Tổng doanh thu`"],
                    ["Byt om", "Vender hvert tegn"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                De sidste tre fjerner vietnamesiske accenter, fordi de laver **navne i kode** — hvor \
                bogstaver med accent som regel ikke er tilladt.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Kommentarer og parentesmatchning",
        summary: "⌘/ bruger hvert sprogs eget tegn; ⌃⌘B springer til den modsvarende parentes.",
        keywords: ["kommentar", "parentes", "cmd+/", "matchning"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` vælger kommentartegnet **efter dokumentets sprog**: `#` til Python, `//` til Rust \
                og C, `<!-- -->` til XML og HTML.
                """),
            .heading("Hele blokken går samme vej"),
            .paragraph("""
                Er blot én linje i blokken stadig ukommenteret, kommenterer kommandoen **det hele**. At \
                afgøre det linje for linje ville gøre en halvt kommenteret blok til et skakbræt. Tegnet \
                indsættes ved blokkens laveste indrykning, så blokken beholder sin form.
                """),
            .heading("At springe til den modsvarende parentes"),
            .bullets([
                "`⌃⌘B` springer til den parentes, der modsvarer den ved markøren.",
                "Parenteser inde i **strenge** eller **kommentarer** tæller ikke — en let lekser skelner dem.",
                "Over **1 MB** nægter kommandoen og siger det i stedet for at forankre sig halvvejs og gætte. At fremhæve det forkerte par er værre end at fremhæve intet.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Fortryd og udklipsholderen",
        summary: "Ubegrænset fortrydelseshistorik og en udklipsholder med flere pladser.",
        keywords: ["fortryd", "gentag", "udklipsholder", "indsæt", "historik"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Fortryd / gentag"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Klip / kopiér / indsæt"),
                HelpShortcut("⇧⌘V", "Udklipsholderens historik"),
            ]),
            .heading("En masseoperation er ÉT trin"),
            .paragraph("""
                At sortere en million linjer, at erstatte ti tusind træf, at indsætte i fem tusind \
                linjer med kolonneeditoren — hver af dem fortrydes med **ét** `⌘Z`.
                """),
            .paragraph("""
                Fortrydelseshistorikken lever i GEditors egen tekstbuffer frem for i systemets \
                `UndoManager`, netop af den grund: `UndoManager` tæller tastetryk.
                """),
            .heading("Udklipsholderens historik"),
            .paragraph("""
                `⇧⌘V` åbner en liste over det, du har kopieret for nylig, og indsætter det, du vælger. \
                Nyttigt, når du skal skifte mellem to stumper mange steder.
                """),
        ]
    )
}
