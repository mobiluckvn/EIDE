import Foundation

/// Dansk hjælpeindhold — del 2: søgning samt filer og arbejdsomgange.
extension HelpDA {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Søgning",
        summary: "Søg, erstat, regulære udtryk, søgning i en hel mappe og linjemærker.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Søg og erstat",
        summary: "Tre søgetilstande, og hvorfor ^ som standard betyder LINJENS begyndelse.",
        keywords: ["søg", "erstat", "find", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Søg"),
                HelpShortcut("⌥⌘F", "Søg og erstat"),
                HelpShortcut("⌘G / ⇧⌘G", "Næste / forrige træf"),
            ]),
            .heading("Tre tilstande"),
            .table(
                headers: ["Tilstand", "Forstår", "Brug til"],
                rows: [
                    ["Normal", "Ren tekst, slet ingen særtegn", "De fleste søgninger"],
                    ["Udvidet", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "At finde linjeskift, TAB, bestemte bytes"],
                    ["Regex", "Fuld PCRE2", "At matche efter mønster"],
                ]
            ),
            .note("""
                **Udvidet** tilstand forstår ikke regex-syntaks. Den udfolder kun nogle få undvigetegn \
                — så en søgning på `a.b` dér finder præcis de tre tegn; punktummet er ikke et jokertegn.
                """),
            .heading("To kontakter"),
            .bullets([
                "**Forskel på store og små bogstaver** — slået fra som standard.",
                "**Kun hele ord** — matcher kun, når begge ender er ordgrænser.",
            ]),
            .heading("`^` og `$` matcher ved hver LINJES kanter"),
            .paragraph("""
                Slået til som standard. Folk, der kommer fra Notepad++, forventer, at `^` betyder \
                »linjens begyndelse«; med det slået fra ville `^abc` kun matche, hvis hele dokumentet \
                begyndte med `abc` — det ønsker næsten ingen i en teksteditor.
                """),
            .heading("Et dårligt udtryk får ikke programmet til at hænge"),
            .paragraph("""
                Motoren er **PCRE2 med JIT-oversættelse**, og den har et budget for tilbagesporing. Et \
                mønster, der eksploderer kombinatorisk, standses og meldes i stedet for at fryse \
                vinduet.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Regulære udtryk",
        summary: "Den PCRE2-syntaks, man faktisk bruger, med eksempler, der kører på vietnamesiske data.",
        keywords: ["regex", "regexp", "pcre", "mønster"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor bruger **PCRE2**, samme motor som PHP og mange kommandolinjeværktøjer. Åbn \
                `Søg ▸ Prøv regulært udtryk…` for at prøve et mønster mod en prøvetekst og se, hvad \
                hver gruppe fanger, **før** du anvender det på et virkeligt dokument.
                """),
            .heading("Tegnklasser"),
            .table(
                headers: ["Skriv", "Matcher"],
                rows: [
                    ["`.`", "Ethvert tegn undtagen et linjeskift"],
                    ["`\\d` · `\\D`", "Et ciffer · ikke et ciffer"],
                    ["`\\w` · `\\W`", "Et ordtegn (bogstav, ciffer, `_`) · det modsatte"],
                    ["`\\s` · `\\S`", "Blanktegn · ikke blanktegn"],
                    ["`[abc]`", "Ét af tegnene i klammerne"],
                    ["`[^abc]`", "Ét tegn, der IKKE er i klammerne"],
                    ["`[a-z]`", "Ét tegn i intervallet"],
                ]
            ),
            .heading("Gentagelse"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`*`", "Nul eller flere"],
                    ["`+`", "En eller flere"],
                    ["`?`", "Nul eller en"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Præcis 3 · mellem 2 og 5 · 2 eller flere"],
                    ["`*?` `+?` `??`", "De **dovne** former — tag så lidt som muligt"],
                ]
            ),
            .warning("""
                `.*` er **grådig**: den æder til linjens slutning og trækker sig så tilbage. Når man \
                deler felter inde i en linje, har man næsten altid brug for `.*?` eller en snæver \
                tegnklasse som `[^,]*`.
                """),
            .heading("Ankre og grupper"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`^` · `$`", "Linjens begyndelse · linjens slutning"],
                    ["`\\b`", "Ordgrænse"],
                    ["`(…)`", "En **fangende** gruppe — kan bruges igen i erstatningen"],
                    ["`(?:…)`", "Ikke-fangende gruppe"],
                    ["`(?<name>…)`", "Navngiven gruppe"],
                    ["`a|b`", "a eller b"],
                    ["`(?=…)` · `(?!…)`", "Fremadkig: skal følge · må ikke følge"],
                    ["`(?<=…)` · `(?<!…)`", "Bagudkig: skal gå forud · må ikke gå forud"],
                ]
            ),
            .heading("Eksempler, der kører"),
            .code(language: "regex", caption: "Ethvert vietnamesisk telefonnummer på 10 cifre",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Del en dato som 31/12/2026 i tre grupper",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "Tredje celle i en simpel CSV-række (uden citater)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Loglinjer på ERROR eller FATAL, med deres tidsstempel",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Tomme linjer, eller linjer med kun blanktegn",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Vietnamesiske bogstaver med accent — brug Unicode-klassen, list dem ikke",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` betyder »ethvert Unicode-bogstav«, så det matcher også `ế` og `đ`. At liste \
                hver vokal med accent i hånden er en sikker måde at overse nogle på.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Erstatningsstrenge",
        summary: "Genbrug fangede grupper, og skift store/små bogstaver undervejs.",
        keywords: ["erstat", "tilbagereference", "gruppe", "$1", "\\U"],
        blocks: [
            .heading("At kalde en fanget gruppe tilbage"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`$1` … `$9`", "Indholdet af gruppe n"],
                    ["`${1}`", "Det samme, med tydelige grænser — brug den, når et ciffer følger"],
                    ["`\\1`", "Accepteres også; GEditor skriver den om til `${1}`"],
                    ["`$0`", "Hele træffet"],
                ]
            ),
            .note("""
                Skriv `${1}` frem for `$1`, når næste tegn er et ciffer. `$123` læses som gruppe 123; \
                `${1}23` er gruppe 1 fulgt af to cifre.
                """),
            .heading("At skifte store/små bogstaver under en erstatning"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`\\U`", "STORE BOGSTAVER herfra"],
                    ["`\\L`", "små bogstaver herfra"],
                    ["`\\u`", "Kun næste tegn med stort"],
                    ["`\\l`", "Kun næste tegn med lille"],
                    ["`\\E`", "Afslut området med `\\U` eller `\\L`"],
                ]
            ),
            .heading("Eksempler"),
            .code(language: "text", caption: "Gør 31/12/2026 til 2026-12-31",
                  source: """
                    Søg:     (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Erstat:  $3-$2-$1
                    """),
            .code(language: "text", caption: "Sæt provinskoden i begyndelsen af hver linje med stort, behold resten",
                  source: """
                    Søg:     ^([a-z]{2,3})(\\s)
                    Erstat:  \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Pak hver linje som en JSON-streng",
                  source: """
                    Søg:     ^(.+)$
                    Erstat:  "$1",
                    """),
            .paragraph("""
                En gruppe, der **ikke deltog** i træffet, bliver til en tom streng og ikke en fejl — så \
                et mønster med alternativer som `(a)|(b)` erstatter stadig pænt uden at skulle skrives \
                to gange.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Søg og erstat i en hel mappe",
        summary: "Gennemsøg mange filer på én gang, og se resultatet, før noget skrives.",
        keywords: ["søg i filer", "grep", "masseerstatning", "mappe"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Søg i en hel mappe")]),
            .paragraph("""
                Vælg rodmappen, filtrér efter filnavnsmønster, og gennemsøg. Resultaterne vises som en \
                liste grupperet efter fil; et klik på en linje åbner den fil på det sted.
                """),
            .bullets([
                "Samme tre søgetilstande og samme regex-motor som søgefeltet i dokumentet.",
                "Erstatning i en hel mappe **viser først**, hvor mange filer og hvor mange træf der vil blive ændret, før der skrives.",
                "Gennemsøgningen kører parallelt og **kan afbrydes** undervejs.",
            ]),
            .warning("""
                Erstatning i en hel mappe skriver direkte i filer, der **ikke er åbne**. De filer \
                findes ikke i det åbne dokuments fortrydelseshistorik — se det først, og hav en \
                sikkerhedskopi eller et versionsstyret arkiv.
                """),
            .heading("Tidligere søgninger og eksport af resultater"),
            .paragraph("""
                Resultatpanelet **bevarer denne omgangs søgninger**. Pop op-menuen øverst i panelet \
                lister dem med deres antal træf — søg `TODO`, læs et stykke, søg `FIXME` for at \
                sammenligne, og vend tilbage til den første liste uden at gennemsøge hele mappen igen.
                """),
            .paragraph("""
                Knappen **Eksportér** åbner den aktuelle søgning som et tekstfaneblad, ét resultat pr. \
                linje som `sti:linje:kolonne: tekst` — den form, `grep -n` bruger, og den form, \
                oversættere bruger til fejl. Hver linje kan indsættes direkte i dette produkts eget \
                `Gå til`-felt, og dine `grep`, `awk` og `sed` læser den uden en særlig fortolker.
                """),
            .note("""
                Historikken ligger i **hukommelsen** og skrives aldrig til disk: søgeresultater bærer \
                indholdet af hver træffende linje, og det er samme slags data, som udklipsholderens \
                historik med vilje ikke gemmer.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Linjemærker",
        summary: "Ni mærkefarver og fire kommandoer, der gør mærkede linjer til et resultat.",
        keywords: ["bogmærke", "mærke", "f2", "filtrér linjer"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Mærkning er måden at filtrere et dokument **uden at ændre det**. Mærk hver linje, der \
                passer til et mønster, og kopiér så kun dem ud — eller behold kun dem.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Mærk hver linje, der passer til den aktuelle søgning"),
                HelpShortcut("⌘F2", "Sæt / fjern mærke på den aktuelle linje"),
                HelpShortcut("F2 / ⇧F2", "Spring til næste / forrige mærke"),
            ]),
            .heading("Et almindeligt forløb"),
            .steps([
                "`⌘F` efter det mønster, du vil filtrere på, f.eks. `\\bERROR\\b`.",
                "`⌘M` mærker hver linje, der passer.",
                "`Søg ▸ Kopiér mærkede linjer` trækker dem over i et nyt faneblad — eller `Behold kun mærkede linjer` filtrerer på stedet.",
            ]),
            .heading("Ni farver"),
            .paragraph("""
                En linje kan bære **flere farver på én gang**. Brug forskellige farver til forskellige \
                kriterier og kombinér dem: rød til fejllinjer, gul til linjer, der hører til ét \
                ordre-id, og se så efter linjer, der bærer begge.
                """),
            .bullets([
                "`Byt mærker om` — mærkede linjer bliver umærkede og omvendt.",
                "`Fjern alle mærker` — fjerner hvert mærke uden at røre indholdet.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Gå til linje",
        summary: "Spring til en linje, en kolonne eller en byteposition.",
        keywords: ["gå til", "linjenummer", "cmd+l", "position", "kolonne"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Gå til linje")]),
            .paragraph("""
                Feltet forstår **tre skrivemåder** og skelner dem ud fra det, du skriver — der er ingen \
                ekstra vælger at klikke på.
                """),
            .table(
                headers: ["Skriv", "Går til"],
                rows: [
                    ["`120`", "begyndelsen af linje 120"],
                    ["`120,5` eller `120:5`", "linje 120, kolonne 5 — kolonnen tæller TEGN"],
                    ["`@1024`", "byteposition 1024 i filen"],
                ]
            ),
            .note("""
                `linje:kolonne` er præcis, som oversættere og lintere skriver en position, så en linje, \
                du netop har kopieret fra en terminal, kan indsættes direkte.

                `@` til bytepositioner har en grund: er `1234` en linje eller en byte? Der findes intet \
                rigtigt svar, og et forkert gæt sender markøren et helt andet sted hen uden noget \
                signal. Det bytetal er også det, statuslinjen viser i positionsfeltet (`@1024`), så det, \
                du læser dér, kan du skrive her.
                """),
            .bullets([
                "En kolonne **ud over linjens længde** standser ved den linjes slutning; den løber ikke over på den næste.",
                "En byteposition **ud over filen** fører dig til slutningen — som regel har du kopieret det tal fra en tidligere kørsel, og filen kan være blevet mindre.",
                "Tekst, den ikke kan læse, bliver **meldt**, og markøren bliver stående; den springer ikke til filens top.",
            ]),
            .paragraph("""
                På meget store filer læser GEditor ikke hele filen for at komme derhen — linjeindekset \
                bygges gradvist i baggrunden.
                """),
            .note("""
                Kommandolinjeværktøjet tager også en position: `geditor report.csv:120:5` åbner filen \
                med markøren på linje 120, kolonne 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Filer og arbejdsomgange

    static let files = HelpChapter(
        id: "tep",
        title: "Filer og arbejdsomgange",
        summary: "At åbne, gemme, faneblade, vinduer, arbejdsområder, og hvordan omgangen kommer tilbage.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "At åbne og gemme",
        summary: "Åbn en fil af enhver størrelse, og gem den med en anden tegnkodning eller linjeslutning.",
        keywords: ["åbn", "gem", "gem som", "dublér", "omdøb", "flyt"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Nyt dokument"),
                HelpShortcut("⌘O", "Åbn en fil"),
                HelpShortcut("⌘S", "Gem"),
                HelpShortcut("⇧⌘S", "Gem som"),
            ]),
            .paragraph("""
                At trække en fil ind i vinduet åbner den også. `Fil ▸ Åbn seneste` husker listen over \
                de filer, du lige har arbejdet med.
                """),
            .heading("Gem som: tre ting, du kan ændre"),
            .table(
                headers: ["Ændring", "Betydning"],
                rows: [
                    ["Tegnkodning", "Skriv ud som UTF-8, TCVN3, VNI-Windows… — 36 tegnkodninger"],
                    ["Linjeslutninger", "LF (Unix) · CRLF (Windows) · CR (klassisk Mac)"],
                    ["Navn og sted", "Som i enhver macOS-gemmedialog"],
                ]
            ),
            .paragraph("""
                Statuslinjen viser altid tegnkodningen, linjeslutningsstilen og det genkendte sprog. \
                **Et klik på hver af dem ændrer den med det samme**, uden at gå gennem en dialog.
                """),
            .heading("Dublér · omdøb · flyt"),
            .paragraph("""
                Disse tre arbejder på FILEN frem for på dens indhold — og det åbne faneblad følger \
                filen, så du aldrig mister din plads.
                """),
            .table(
                headers: ["Kommando", "Hvad den gør"],
                rows: [
                    ["`Dublér fil`",
                     "Kopierer den som `navn 2.txt` ved siden af originalen og **åbner kopien** — for folk dublerer for at redigere kopien"],
                    ["`Omdøb fil…`", "Omdøber på disken; fanebladet følger det nye navn"],
                    ["`Flyt fil til…`", "Flytter til en anden mappe; fanebladet følger med"],
                ]
            ),
            .note("""
                Alle tre **nægter, når en fil med det navn allerede findes** på målet; de overskriver \
                aldrig. Og alle tre kræver en fil, der er gemt mindst én gang — et dokument, der aldrig \
                har været på disken, har intet at dublere eller flytte.
                """),
            .heading("Sikker skrivning"),
            .bullets([
                "Skrivningen er **atomar**: strømsvigt midtvejs efterlader aldrig en afkortet fil.",
                "Ændrer et andet program filen, mens du har den åben, opdager GEditor det og spørger, før den overskriver.",
                "Filer på iCloud Drive eller et netværksdrev går gennem systemets filkoordinator, så to maskiner ikke træder på hinanden.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Faneblade, vinduer og delt visning",
        summary: "Mange faneblade pr. vindue, mange vinduer, og faneblade, du kan trække imellem dem.",
        keywords: ["faneblad", "vindue", "del", "rude"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Nyt faneblad"),
                HelpShortcut("⌘W", "Luk faneblad"),
                HelpShortcut("⇧⌘T", "Åbn det senest lukkede faneblad igen"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Næste / forrige faneblad"),
                HelpShortcut("⌥⌘N", "Nyt vindue"),
                HelpShortcut("⌃⌘N", "Løsriv det aktuelle faneblad til sit eget vindue"),
            ]),
            .paragraph("""
                Du kan trække et faneblad ind i et andet vindue eller slippe det på tom plads for at \
                lave et nyt vindue. **Et fastgjort faneblad rejser ikke** — at fastgøre betyder »behold \
                dette her«.
                """),
            .note("""
                `⇧⌘T` åbner det senest lukkede faneblad igen, også et **ugemt**: indholdet er der stadig.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "At åbne en mappe som arbejdsområde",
        summary: "Et filtræ i sidepanelet, søgning i hele projektet og åbning med ét klik.",
        keywords: ["arbejdsområde", "mappe", "projekt", "sidepanel"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Åbn en mappe som arbejdsområde")]),
            .paragraph("""
                Træet vises i sidepanelet (`⌘0`). Klik på en fil for at åbne den, og `⇧⌘F` søger i hele \
                mappen.
                """),
            .note("""
                I App Store-udgaven holdes adgangen til mappen af et **sikkerhedsafgrænset bogmærke**, \
                så næste start stadig kan nå den uden at bede dig om at vælge mappen igen.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "Arbejdsomgangen genskaber sig selv",
        summary: "Slut og åbn igen: hvert faneblad kommer tilbage, også de ugemte.",
        keywords: ["omgang", "session", "genskab", "ugemt"],
        blocks: [
            .paragraph("""
                Intet at slå til. Slut GEditor, og åbn den igen: faneblade, deres rækkefølge, \
                markørpositioner og rullepositioner kommer alle tilbage.
                """),
            .heading("Hvad med ugemte faneblade"),
            .paragraph("""
                Deres indhold gemmes i et særskilt øjebliksbillede, så de kommer også tilbage. Slutter \
                programmet unormalt, **spørger** næste start, før forældreløse kladder genskabes — \
                frem for stille at genopbygge en bunke faneblade, du ikke husker.
                """),
            .warning("""
                En arbejdsomgang er **ikke en sikkerhedskopi**. Den bevarer arbejdstilstand, ikke \
                historik. Alt, der betyder noget, skal stadig gemmes i en fil.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Tidligere gemte versioner",
        summary: "Gennemse og genskab ældre versioner af en fil.",
        keywords: ["versioner", "historik", "genskab", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Ved hver gemning noterer GEditor den **forrige** version, før den overskriver. \
                `Makro ▸ Gemte versioner…` åbner oversigten over dem.
                """),
            .bullets([
                "Versionslageret er **operativsystemets**, samme mekanisme som Apples egne programmer bruger.",
                "At genskabe en ældre version er en **almindelig redigering** — `⌘Z` fortryder den.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "At følge en fil, der stadig skrives",
        summary: "Som `tail -f`: det, der føjes til, dukker op, efterhånden som det kommer.",
        keywords: ["tail", "følg", "log", "realtid"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Fil ▸ Følg fil (tail -f)` indlæser det, der dukker op i filens ende, og ruller med.
                """),
            .warning("""
                Mens der følges, bliver dokumentet **skrivebeskyttet**. At skrive, mens ny tekst \
                indlæses fra disken, betyder to skrivere om ét dokument, og taberen er altid det, du \
                lige skrev.
                """),
            .note("""
                Statuslinjen viser **Følger** hele tiden, så du minutter senere stadig ved, hvorfor \
                filen ikke tager imod tastetryk. Et klik på feltet **skrivebeskyttet** siger grunden \
                lige ud.

                At følge hører til det **faneblad, der begyndte det**, ikke til vinduet: åbn et andet \
                faneblad og skriv videre, og nye loglinjer strømmer stadig ind i deres eget faneblad \
                uden at røre den fil, du redigerer.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Udskrivning",
        summary: "Udskriv gennem macOS' almindelige udskriftsdialog.",
        keywords: ["udskriv", "papir", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Udskriv")]),
            .paragraph("""
                Den bruger systemets udskriftsdialog, så eksport til PDF sker også dér — `PDF`-knappen \
                nederst til venstre.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Billeder, PDF'er, Office-filer, lyd, video og arkiver",
        summary: "Otte slags filer åbner inde i GEditor uden et andet program.",
        keywords: ["billede", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "arkiv",
                   "lyd", "video", "mp3", "mp4"],
        blocks: [
            .table(
                headers: ["Slags", "Hvad du kan gøre"],
                rows: [
                    ["Billeder", "Se, zoome, rotere; **animerede billeder afspilles** og kan sættes på pause"],
                    ["Lyd", "Afspille, søge, ændre lydstyrke"],
                    ["Video", "Afspille, søge, fuld skærm, billede-i-billede"],
                    ["PDF", "Læse, søge, **kommentere**"],
                    ["Word · Excel · PowerPoint", "Se **og redigere** — `⌘S` skriver direkte tilbage i filen"],
                    ["ZIP · TAR · GZ · XZ", "Vise indhold og åbne hvert element som et faneblad"],
                    ["7z · RAR og syv formater mere", "Det samme, via libarchive"],
                ]
            ),
            .paragraph("""
                At åbne et element inde i et arkiv laver et nyt faneblad med det elements indhold. \
                Vietnamesiske accenter overlever både i navne og indhold.
                """),
            .note("""
                Redigér et af de tre Office-formater, tryk `⌘S`, og det skrives tilbage i filen — \
                LibreOffice læser resultatet. Den vej er afprøvet fra ende til anden, ikke blot \
                eksporteret til en kopi.
                """),
            .heading("Lyd og video bruger macOS' afspillere"),
            .paragraph("""
                Afspilningen går gennem systemets egne dekodere, så der hentes intet ekstra, og der \
                følger intet ekstra med. Til gengæld **spiller nogle få formater ikke** — `.mkv`, \
                `.webm`, `.avi`, `.wmv` — fordi macOS ikke har en indbygget dekoder til dem.
                """),
            .paragraph("""
                For en sådan fil **siger GEditor hvorfor** i stedet for at vise et sort rektangel og \
                tilbyder den binære fremviser eller et andet program.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "PDF-værktøjer",
        summary: "Læs, kommentér, og et helt sidelag: rotér · flyt · slet · udtræk · flet.",
        keywords: ["pdf", "side", "rotér", "slet side", "udtræk", "flet", "opdel",
                   "kommentér", "fremhæv", "underskriv"],
        blocks: [
            .paragraph("""
                PDF-visningen har **to værktøjslinjer**, og de besvarer forskellige spørgsmål. Den \
                øverste række arbejder på **indholdet** af én side; den nederste på **mængden af \
                sider**.
                """),
            .heading("Øverste række — at læse og kommentere"),
            .table(
                headers: ["Knap", "Hvad den gør"],
                rows: [
                    ["Fremhæv · Understreg", "Markér den valgte tekst"],
                    ["Note…", "Hæft en note på siden"],
                    ["Fjern kommentarer", "Fjern hver kommentar fra den aktuelle side"],
                    ["Udtræk tekst til et nyt faneblad", "Flyt al teksten over i et faneblad, så du kan søge, filtrere og bruge andre værktøjer"],
                    ["Søgefelt", "Søg inde i PDF'en — **at skrive uden accenter finder stadig tekst med accent**"],
                ]
            ),
            .note("""
                En skannet PDF har ikke noget tekstlag. Udtrækskommandoen **siger det** frem for at \
                åbne et tomt faneblad og lade dig gætte.
                """),
            .heading("Nederste række — sidehandlinger"),
            .table(
                headers: ["Knap", "Hvad den gør", "Kan fortrydes"],
                rows: [
                    ["Rotér mod venstre · højre", "Drej den aktuelle side 90°", "Ja"],
                    ["Side op · side ned", "Byt den aktuelle side med naboen", "Ja"],
                    ["Slet sider…", "Slet efter interval, f.eks. `2-4,7`", "Ja"],
                    ["Udtræk sider…", "Skriv et sideinterval ud som en **ny fil**", "Rører ikke den åbne fil"],
                    ["Flet en PDF ind…", "Indsæt en anden PDF lige efter den aktuelle side", "Ja"],
                    ["Underskriv…", "Placér et underskriftsbillede på den aktuelle side", "Ja"],
                    ["Redigér tekst…", "Tegn erstatningstekst over markeringen", "Ja"],
                    ["Næste tomme felt", "Spring til næste uudfyldte formularfelt", "—"],
                    ["Ryd udfyldte værdier", "Tøm hvert formularfelt", "Ja"],
                    ["Fortryd sideændring", "Gå ét sideindgreb tilbage", "—"],
                    ["Gem den redigerede kopi…", "Skriv en ny fil, og **åbn den igen for at kontrollere**", "—"],
                ]
            ),
            .heading("Formularer, der kan udfyldes"),
            .paragraph("""
                Åbn en PDF med formularfelter, og statuslinjen siger, **hvor mange** der er. Skriv \
                direkte i felterne på siden, og brug så `Gem den redigerede kopi…`.
                """),
            .bullets([
                "Værdierne gemmes som **levende formularfelter**, ikke som fladtrykt tekst — så modtagerens Acrobat ser stadig en udfyldt formular og kan rette i den.",
                "Vietnamesiske accenter overlever turen skriv-og-åbn-igen. En prøve vogter netop det med navnet `Nguyễn Văn Anh`.",
                "`Næste tomme felt` springer til næste tomme — den naturlige vej gennem en lang formular.",
            ]),
            .heading("At underskrive"),
            .paragraph("""
                Forbered et underskriftsbillede (en PNG med gennemsigtig baggrund virker bedst), \
                **markér stedet, der skal underskrives** — som regel den optrukne linje eller ordet \
                »Underskrift« — og tryk så `Underskriv…`. Uden en markering lander underskriften nederst \
                til højre.
                """),
            .note("""
                Underskriften bevarer billedets **højde-bredde-forhold**: en underskrift, der er klemt \
                eller strakt, ser med det samme falsk ud.
                """),
            .heading("At redigere tekst — og tre ting, man skal vide først"),
            .paragraph("""
                Markér den tekst, der skal ændres, og tryk `Redigér tekst…`. GEditor **dækker det \
                område med en baggrundsfarve taget lige ved siden af** og tegner så den nye tekst \
                ovenpå.
                """),
            .warning("""
                **Den gamle tekst er DÆKKET, ikke FJERNET.** Den er stadig i filen og kan stadig \
                udtrækkes med `Udtræk tekst til et nyt faneblad` eller ethvert andet værktøj. Dette er \
                **ikke sløring**: at skjule et personnummer på den måde skjuler det for et menneskeligt \
                øje, ikke for en maskine.
                """),
            .bullets([
                "**Den nye tekst kan stadig findes med `⌘F`.** Den tegnes som virkelig tekst, ikke som et billede — målt af en prøve, ikke antaget.",
                "**Skrifttypen er en systemskrift**, ikke dokumentets oprindelige. Med vilje: skrifter indlejret i en PDF mangler ofte vietnamesiske accenter, og `Nguyễn` ville ankomme som `Nguy?n`.",
                "**På en mønstret baggrund ses lappen** — dækfarven tages fra ét enkelt sted lige til venstre for markeringen.",
            ]),
            .heading("Hvorfor tegne over i stedet for at redigere indholdsstrømmen"),
            .paragraph("""
                At redigere en PDF's indholdsstrøm direkte betyder at håndtere delmængdeskrifter med \
                deres egen kodning, sætninger brudt i tre stumper af knibning og tegnbreddetabeller, \
                der skal genberegnes. At gøre det rigtigt for **hver** fil er et projekt i sig selv; at \
                gøre det forkert ødelægger nogens dokument.
                """),
            .paragraph("""
                Til gengæld ændres resten af siden **ikke med en eneste byte**, og siden bliver ved med \
                at være en side — teksten kan stadig markeres, kopieres og søges i. At tegne over gør \
                den **ikke** til et billede.
                """),
            .heading("Sideintervallets syntaks"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`5`", "Kun side 5"],
                    ["`2-4`", "Side 2, 3, 4"],
                    ["`-3`", "Fra begyndelsen til side 3"],
                    ["`8-`", "Fra side 8 til slutningen"],
                    ["`1-3,5,9-`", "Flere dele forbundet med kommaer"],
                ]
            ),
            .paragraph("Sider tælles **fra 1**, det tal du ser på skærmen."),
            .warning("""
                Et omvendt interval (`5-2`) og et interval ud over slutningen (`1-999`) bliver begge \
                **afvist med en grund**, aldrig stille rettet til noget nærliggende. For en kommando, \
                der sletter sider, betyder et forkert gæt tabte sider, og en stille beskæring gør en \
                slåfejl til en gyldig kommando.
                """),
            .heading("Den oprindelige fil overskrives aldrig"),
            .paragraph("""
                Alt ovenstående ændrer dokumentet **i hukommelsen**. Først når du trykker `Gem den \
                redigerede kopi…` og vælger et sted, bliver der skrevet en fil — og efter skrivningen \
                **åbner GEditor netop den fil igen** for at bekræfte, at den stadig har alle sine sider.
                """),
            .paragraph("""
                Grunden: en dårligt skrevet fil ligger på disken og ser helt normal ud, og brugeren \
                opdager det først, efter at have sendt den.
                """),
            .note("""
                Visningens statuslinje viser **· redigeret, ikke gemt**, når dokumentet afviger fra \
                filen på disken.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
