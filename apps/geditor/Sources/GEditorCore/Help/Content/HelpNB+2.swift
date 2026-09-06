import Foundation

/// Norsk hjelpeinnhold (bokmål) — del 2: søk samt filer og økter.
extension HelpNB {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Søk",
        summary: "Søk, erstatt, regulære uttrykk, søk i en hel mappe og linjemerker.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Søk og erstatt",
        summary: "Tre søkemodi, og hvorfor ^ som standard betyr LINJENS begynnelse.",
        keywords: ["søk", "erstatt", "finn", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Søk"),
                HelpShortcut("⌥⌘F", "Søk og erstatt"),
                HelpShortcut("⌘G / ⇧⌘G", "Neste / forrige treff"),
            ]),
            .heading("Tre modi"),
            .table(
                headers: ["Modus", "Forstår", "Brukes til"],
                rows: [
                    ["Normal", "Ren tekst, ingen spesialtegn i det hele tatt", "De fleste søk"],
                    ["Utvidet", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Å finne linjeskift, TAB, bestemte byte"],
                    ["Regex", "Full PCRE2", "Å treffe etter mønster"],
                ]
            ),
            .note("""
                **Utvidet** modus forstår ikke regex-syntaks. Den utfolder bare noen få unnvikelser — \
                så et søk på `a.b` der finner nøyaktig de tre tegnene; punktumet er ikke et jokertegn.
                """),
            .heading("To brytere"),
            .bullets([
                "**Skill store og små bokstaver** — av som standard.",
                "**Bare hele ord** — treffer bare når begge ender er ordgrenser.",
            ]),
            .heading("`^` og `$` treffer ved hver LINJES kanter"),
            .paragraph("""
                På som standard. Folk som kommer fra Notepad++, forventer at `^` betyr «linjens \
                begynnelse»; med det av ville `^abc` bare treffe hvis hele dokumentet begynte med \
                `abc` — det vil nesten ingen ha i en tekstredigerer.
                """),
            .heading("Et dårlig uttrykk henger ikke opp programmet"),
            .paragraph("""
                Motoren er **PCRE2 med JIT-kompilering**, og den har et budsjett for tilbakesporing. \
                Et mønster som eksploderer kombinatorisk, stanses og meldes i stedet for å fryse \
                vinduet.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Regulære uttrykk",
        summary: "Den PCRE2-syntaksen du faktisk bruker, med eksempler som kjører på vietnamesiske data.",
        keywords: ["regex", "regexp", "pcre", "mønster"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor bruker **PCRE2**, samme motor som PHP og mange kommandolinjeverktøy. Åpne \
                `Søk ▸ Prøv regulært uttrykk…` for å prøve et mønster mot en prøvetekst og se hva hver \
                gruppe fanger, **før** du bruker det på et virkelig dokument.
                """),
            .heading("Tegnklasser"),
            .table(
                headers: ["Skriv", "Treffer"],
                rows: [
                    ["`.`", "Ethvert tegn unntatt et linjeskift"],
                    ["`\\d` · `\\D`", "Et siffer · ikke et siffer"],
                    ["`\\w` · `\\W`", "Et ordtegn (bokstav, siffer, `_`) · det motsatte"],
                    ["`\\s` · `\\S`", "Blanktegn · ikke blanktegn"],
                    ["`[abc]`", "Ett av tegnene i klammene"],
                    ["`[^abc]`", "Ett tegn som IKKE er i klammene"],
                    ["`[a-z]`", "Ett tegn i intervallet"],
                ]
            ),
            .heading("Gjentakelse"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`*`", "Null eller flere"],
                    ["`+`", "En eller flere"],
                    ["`?`", "Null eller en"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Nøyaktig 3 · mellom 2 og 5 · 2 eller flere"],
                    ["`*?` `+?` `??`", "De **late** formene — ta så lite som mulig"],
                ]
            ),
            .warning("""
                `.*` er **grådig**: den spiser til linjens slutt og trekker seg så tilbake. Når man \
                deler felter inne i en linje, trenger man nesten alltid `.*?` eller en smal tegnklasse \
                som `[^,]*`.
                """),
            .heading("Ankre og grupper"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`^` · `$`", "Linjens begynnelse · linjens slutt"],
                    ["`\\b`", "Ordgrense"],
                    ["`(…)`", "En **fangende** gruppe — kan brukes igjen i erstatningen"],
                    ["`(?:…)`", "Ikke-fangende gruppe"],
                    ["`(?<name>…)`", "Navngitt gruppe"],
                    ["`a|b`", "a eller b"],
                    ["`(?=…)` · `(?!…)`", "Framoverkikk: må følge · må ikke følge"],
                    ["`(?<=…)` · `(?<!…)`", "Bakoverkikk: må gå foran · må ikke gå foran"],
                ]
            ),
            .heading("Eksempler som kjører"),
            .code(language: "regex", caption: "Ethvert vietnamesisk telefonnummer på 10 sifre",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Del en dato som 31/12/2026 i tre grupper",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "Tredje celle i en enkel CSV-rad (uten anførselstegn)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Logglinjer på ERROR eller FATAL, med tidsstempelet",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Tomme linjer, eller linjer med bare blanktegn",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Vietnamesiske bokstaver med aksent — bruk Unicode-klassen, ikke list dem",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` betyr «enhver Unicode-bokstav», så den treffer også `ế` og `đ`. Å liste hver \
                vokal med aksent for hånd er en sikker måte å overse noen på.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Erstatningsstrenger",
        summary: "Gjenbruk fangede grupper, og endre store/små bokstaver mens du erstatter.",
        keywords: ["erstatt", "tilbakereferanse", "gruppe", "$1", "\\U"],
        blocks: [
            .heading("Å kalle en fanget gruppe tilbake"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`$1` … `$9`", "Innholdet i gruppe n"],
                    ["`${1}`", "Det samme, med tydelige grenser — bruk den når et siffer følger"],
                    ["`\\1`", "Godtas også; GEditor skriver den om til `${1}`"],
                    ["`$0`", "Hele treffet"],
                ]
            ),
            .note("""
                Skriv `${1}` heller enn `$1` når neste tegn er et siffer. `$123` leses som gruppe 123; \
                `${1}23` er gruppe 1 fulgt av to sifre.
                """),
            .heading("Å endre store/små bokstaver under en erstatning"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`\\U`", "STORE BOKSTAVER herfra"],
                    ["`\\L`", "små bokstaver herfra"],
                    ["`\\u`", "Bare neste tegn stort"],
                    ["`\\l`", "Bare neste tegn lite"],
                    ["`\\E`", "Avslutt området med `\\U` eller `\\L`"],
                ]
            ),
            .heading("Eksempler"),
            .code(language: "text", caption: "Gjør 31/12/2026 om til 2026-12-31",
                  source: """
                    Søk:      (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Erstatt:  $3-$2-$1
                    """),
            .code(language: "text", caption: "Gjør provinskoden i begynnelsen av hver linje stor, behold resten",
                  source: """
                    Søk:      ^([a-z]{2,3})(\\s)
                    Erstatt:  \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Pakk hver linje som en JSON-streng",
                  source: """
                    Søk:      ^(.+)$
                    Erstatt:  "$1",
                    """),
            .paragraph("""
                En gruppe som **ikke deltok** i treffet, blir til en tom streng og ikke en feil — så \
                et mønster med alternativer som `(a)|(b)` erstatter likevel pent uten å måtte skrives \
                to ganger.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Søk og erstatt i en hel mappe",
        summary: "Gå gjennom mange filer samtidig, og se resultatet før noe skrives.",
        keywords: ["søk i filer", "grep", "masseerstatning", "mappe"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Søk i en hel mappe")]),
            .paragraph("""
                Velg rotmappen, filtrer etter filnavnmønster, og gå gjennom. Resultatene vises som en \
                liste gruppert etter fil; å klikke på en linje åpner den filen på det stedet.
                """),
            .bullets([
                "Samme tre søkemodi og samme regex-motor som søkefeltet i dokumentet.",
                "Erstatning i en hel mappe **forhåndsviser** hvor mange filer og hvor mange treff som vil endres før det skrives.",
                "Gjennomgangen kjører parallelt og **kan avbrytes** underveis.",
            ]),
            .warning("""
                Erstatning i en hel mappe skriver direkte inn i filer som **ikke er åpne**. De filene \
                er ikke i det åpne dokumentets angrehistorikk — forhåndsvis først, og ha en \
                sikkerhetskopi eller et versjonsstyrt arkiv.
                """),
            .heading("Tidligere søk, og eksport av resultater"),
            .paragraph("""
                Resultatpanelet **beholder denne øktens søk**. Hurtigmenyen øverst i panelet lister dem \
                med treffantallene — søk `TODO`, les et stykke, søk `FIXME` for å sammenligne, og gå \
                tilbake til den første listen uten å gå gjennom hele mappen på nytt.
                """),
            .paragraph("""
                Knappen **Eksporter** åpner det gjeldende søket som en tekstfane, ett resultat per \
                linje som `sti:linje:kolonne: tekst` — formen `grep -n` bruker, og formen kompilatorer \
                bruker til feil. Hver linje kan limes rett inn i dette produktets eget `Gå til`-felt, \
                og dine `grep`, `awk` og `sed` leser den uten en egen tolker.
                """),
            .note("""
                Historikken bor i **minnet** og skrives aldri til disk: søkeresultater bærer innholdet \
                i hver treffende linje, og det er samme slags data som utklippstavlens historikk med \
                vilje ikke lagrer.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Linjemerker",
        summary: "Ni merkefarger og fire kommandoer som gjør merkede linjer til et resultat.",
        keywords: ["bokmerke", "merke", "f2", "filtrer linjer"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Merking er måten å filtrere et dokument **uten å endre det**. Merk hver linje som \
                passer et mønster, og kopier så bare dem ut — eller behold bare dem.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Merk hver linje som passer det gjeldende søket"),
                HelpShortcut("⌘F2", "Sett / fjern merke på den gjeldende linjen"),
                HelpShortcut("F2 / ⇧F2", "Hopp til neste / forrige merke"),
            ]),
            .heading("En vanlig arbeidsgang"),
            .steps([
                "`⌘F` etter mønsteret du vil filtrere på, f.eks. `\\bERROR\\b`.",
                "`⌘M` merker hver linje som passer.",
                "`Søk ▸ Kopier merkede linjer` drar dem over i en ny fane — eller `Behold bare merkede linjer` filtrerer på stedet.",
            ]),
            .heading("Ni farger"),
            .paragraph("""
                En linje kan bære **flere farger samtidig**. Bruk ulike farger til ulike kriterier og \
                kombiner dem: rødt for feillinjer, gult for linjer som hører til én ordre-id, og se så \
                etter linjer som bærer begge.
                """),
            .bullets([
                "`Bytt om merker` — merkede linjer blir umerkede og omvendt.",
                "`Fjern alle merker` — fjerner hvert merke uten å røre innholdet.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Gå til linje",
        summary: "Hopp til en linje, en kolonne eller en byteposisjon.",
        keywords: ["gå til", "linjenummer", "cmd+l", "posisjon", "kolonne"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Gå til linje")]),
            .paragraph("""
                Feltet forstår **tre skrivemåter** og skiller dem ut fra det du skriver — det finnes \
                ingen ekstra velger å klikke på.
                """),
            .table(
                headers: ["Skriv", "Går til"],
                rows: [
                    ["`120`", "begynnelsen av linje 120"],
                    ["`120,5` eller `120:5`", "linje 120, kolonne 5 — kolonnen teller TEGN"],
                    ["`@1024`", "byteposisjon 1024 i filen"],
                ]
            ),
            .note("""
                `linje:kolonne` er nøyaktig slik kompilatorer og lintere skriver en posisjon, så en \
                linje du nettopp har kopiert fra en terminal, kan limes rett inn.

                `@` for byteposisjoner har en grunn: er `1234` en linje eller en byte? Det finnes \
                ikke noe riktig svar, og en feil gjetning sender markøren et helt annet sted uten noe \
                signal. Det bytetallet er også det statuslinjen viser i posisjonsfeltet (`@1024`), så \
                det du leser der, kan du skrive her.
                """),
            .bullets([
                "En kolonne **utover linjens lengde** stopper ved den linjens slutt; den renner ikke over på den neste.",
                "En byteposisjon **utover filen** fører deg til slutten — som regel har du kopiert det tallet fra en tidligere kjøring, og filen kan ha krympet.",
                "Tekst den ikke kan lese, blir **meldt**, og markøren blir stående; den hopper ikke til filens topp.",
            ]),
            .paragraph("""
                På svært store filer leser ikke GEditor hele filen for å komme dit — linjeregisteret \
                bygges gradvis i bakgrunnen.
                """),
            .note("""
                Kommandolinjeverktøyet tar også en posisjon: `geditor report.csv:120:5` åpner filen \
                med markøren på linje 120, kolonne 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Filer og økter

    static let files = HelpChapter(
        id: "tep",
        title: "Filer og økter",
        summary: "Åpning, lagring, faner, vinduer, arbeidsområder og hvordan økten kommer tilbake.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Å åpne og lagre",
        summary: "Åpne en fil av enhver størrelse, og lagre den med en annen tegnkoding eller linjeslutt.",
        keywords: ["åpne", "lagre", "lagre som", "dupliser", "gi nytt navn", "flytt"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Nytt dokument"),
                HelpShortcut("⌘O", "Åpne en fil"),
                HelpShortcut("⌘S", "Lagre"),
                HelpShortcut("⇧⌘S", "Lagre som"),
            ]),
            .paragraph("""
                Å dra en fil inn i vinduet åpner den også. `Fil ▸ Åpne nylige` holder på listen over \
                filene du nettopp arbeidet med.
                """),
            .heading("Lagre som: tre ting du kan endre"),
            .table(
                headers: ["Endring", "Betydning"],
                rows: [
                    ["Tegnkoding", "Skriv ut som UTF-8, TCVN3, VNI-Windows… — 36 tegnkodinger"],
                    ["Linjeslutt", "LF (Unix) · CRLF (Windows) · CR (klassisk Mac)"],
                    ["Navn og sted", "Som i enhver macOS-lagringsdialog"],
                ]
            ),
            .paragraph("""
                Statuslinjen viser alltid tegnkodingen, linjesluttstilen og det gjenkjente språket. **Å \
                klikke på hver av dem endrer den umiddelbart**, uten å gå gjennom en dialog.
                """),
            .heading("Dupliser · gi nytt navn · flytt"),
            .paragraph("""
                Disse tre gjelder FILEN og ikke innholdet — og den åpne fanen følger filen, så du \
                mister aldri plassen din.
                """),
            .table(
                headers: ["Kommando", "Hva den gjør"],
                rows: [
                    ["`Dupliser fil`",
                     "Kopierer den som `navn 2.txt` ved siden av originalen og **åpner kopien** — for folk dupliserer for å redigere kopien"],
                    ["`Gi filen nytt navn…`", "Gir nytt navn på disken; fanen følger det nye navnet"],
                    ["`Flytt filen til…`", "Flytter til en annen mappe; fanen følger med"],
                ]
            ),
            .note("""
                Alle tre **nekter når en fil med det navnet allerede finnes** på målet; de overskriver \
                aldri. Og alle tre trenger en fil som er lagret minst én gang — et dokument som aldri \
                har vært på disken, har ingenting å duplisere eller flytte.
                """),
            .heading("Trygg skriving"),
            .bullets([
                "Skrivingen er **atomær**: strømbrudd midtveis etterlater aldri en avkortet fil.",
                "Endrer et annet program filen mens du har den åpen, oppdager GEditor det og spør før den overskriver.",
                "Filer på iCloud Drive eller et nettverksvolum går gjennom systemets filkoordinator, så to maskiner ikke tråkker på hverandre.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Faner, vinduer og delt visning",
        summary: "Mange faner per vindu, mange vinduer, og faner du kan dra mellom dem.",
        keywords: ["fane", "vindu", "del", "rute"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Ny fane"),
                HelpShortcut("⌘W", "Lukk fane"),
                HelpShortcut("⇧⌘T", "Åpne den sist lukkede fanen igjen"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Neste / forrige fane"),
                HelpShortcut("⌥⌘N", "Nytt vindu"),
                HelpShortcut("⌃⌘N", "Løsne den gjeldende fanen til sitt eget vindu"),
            ]),
            .paragraph("""
                Du kan dra en fane inn i et annet vindu eller slippe den på tom plass for å lage et \
                nytt vindu. **En festet fane reiser ikke** — å feste betyr «behold denne her».
                """),
            .note("""
                `⇧⌘T` åpner den sist lukkede fanen igjen, også en **ulagret**: innholdet er fortsatt \
                der.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Å åpne en mappe som arbeidsområde",
        summary: "Et filtre i sidepanelet, søk i hele prosjektet og åpning med ett klikk.",
        keywords: ["arbeidsområde", "mappe", "prosjekt", "sidepanel"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Åpne en mappe som arbeidsområde")]),
            .paragraph("""
                Treet dukker opp i sidepanelet (`⌘0`). Klikk på en fil for å åpne den, og `⇧⌘F` søker \
                i hele mappen.
                """),
            .note("""
                I App Store-utgaven holdes tilgangen til mappen av et **sikkerhetsavgrenset \
                bokmerke**, så neste oppstart når den fortsatt uten å be deg velge mappen på nytt.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "Økten gjenoppretter seg selv",
        summary: "Avslutt og åpne igjen: hver fane kommer tilbake, også de ulagrede.",
        keywords: ["økt", "gjenoppretting", "ulagret"],
        blocks: [
            .paragraph("""
                Ingenting å slå på. Avslutt GEditor og åpne den igjen: faner, rekkefølgen deres, \
                markørposisjoner og rulleposisjoner kommer alle tilbake.
                """),
            .heading("Hva med ulagrede faner"),
            .paragraph("""
                Innholdet deres tas vare på i et eget øyeblikksbilde, så også de kommer tilbake. \
                Avsluttes programmet unormalt, **spør** neste oppstart før foreldreløse utkast \
                gjenopprettes — heller enn stille å bygge opp en haug faner du ikke husker.
                """),
            .warning("""
                En økt er **ikke en sikkerhetskopi**. Den bevarer arbeidstilstand, ikke historikk. Alt \
                som betyr noe, må fortsatt lagres i en fil.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Tidligere lagrede versjoner",
        summary: "Bla i og gjenopprett eldre versjoner av en fil.",
        keywords: ["versjoner", "historikk", "gjenopprett", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Ved hver lagring noterer GEditor den **forrige** versjonen før den overskriver. \
                `Makro ▸ Lagrede versjoner…` åpner oversikten over dem.
                """),
            .bullets([
                "Versjonslageret er **operativsystemets**, samme mekanisme som Apples egne programmer bruker.",
                "Å gjenopprette en eldre versjon er en **vanlig redigering** — `⌘Z` angrer den.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Å følge en fil som fortsatt skrives",
        summary: "Som `tail -f`: det som legges til, dukker opp etter hvert som det kommer.",
        keywords: ["tail", "følg", "logg", "sanntid"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Fil ▸ Følg fil (tail -f)` laster inn det som dukker opp i enden av filen, og ruller \
                med.
                """),
            .warning("""
                Mens den følges, blir dokumentet **skrivebeskyttet**. Å skrive mens ny tekst lastes \
                inn fra disken, betyr to skrivere om ett dokument, og taperen er alltid det du \
                nettopp skrev.
                """),
            .note("""
                Statuslinjen viser **Følger** hele tiden, så minutter senere vet du fortsatt hvorfor \
                filen ikke tar imot tastetrykk. Å klikke på feltet **skrivebeskyttet** sier grunnen \
                rett ut.

                Å følge hører til **fanen som startet det**, ikke til vinduet: åpne en annen fane og \
                skriv videre, og nye logglinjer strømmer fortsatt inn i sin egen fane uten å røre \
                filen du redigerer.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Utskrift",
        summary: "Skriv ut gjennom macOS' vanlige utskriftsdialog.",
        keywords: ["skriv ut", "papir", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Skriv ut")]),
            .paragraph("""
                Den bruker systemets utskriftsdialog, så eksport til PDF skjer også der — \
                `PDF`-knappen nederst til venstre.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Bilder, PDF-er, Office-filer, lyd, video og arkiver",
        summary: "Åtte slags filer åpnes inne i GEditor uten et annet program.",
        keywords: ["bilde", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "arkiv",
                   "lyd", "video", "mp3", "mp4"],
        blocks: [
            .table(
                headers: ["Slag", "Hva du kan gjøre"],
                rows: [
                    ["Bilder", "Se, zoome, rotere; **animerte bilder spilles av** og kan settes på pause"],
                    ["Lyd", "Spille av, spole, endre lydstyrke"],
                    ["Video", "Spille av, spole, fullskjerm, bilde-i-bilde"],
                    ["PDF", "Lese, søke, **kommentere**"],
                    ["Word · Excel · PowerPoint", "Se **og redigere** — `⌘S` skriver rett tilbake i filen"],
                    ["ZIP · TAR · GZ · XZ", "Vise innholdet og åpne hvert element som en fane"],
                    ["7z · RAR og sju formater til", "Det samme, via libarchive"],
                ]
            ),
            .paragraph("""
                Å åpne et element inne i et arkiv lager en ny fane med det elementets innhold. \
                Vietnamesiske aksenter overlever både i navn og innhold.
                """),
            .note("""
                Rediger ett av de tre Office-formatene, trykk `⌘S`, og det skrives tilbake i filen — \
                LibreOffice leser resultatet. Denne veien er prøvd fra ende til annen, ikke bare \
                eksportert til en kopi.
                """),
            .heading("Lyd og video bruker macOS' spillere"),
            .paragraph("""
                Avspillingen går gjennom systemets egne dekodere, så ingenting ekstra lastes ned og \
                ingenting ekstra følger med. Til gjengjeld **spilles noen få formater ikke** — `.mkv`, \
                `.webm`, `.avi`, `.wmv` — fordi macOS ikke har en innebygd dekoder for dem.
                """),
            .paragraph("""
                For en slik fil **sier GEditor hvorfor** i stedet for å vise et svart rektangel, og \
                tilbyr den binære viseren eller et annet program.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "PDF-verktøy",
        summary: "Les, kommenter, og et helt sidelag: roter · flytt · slett · trekk ut · slå sammen.",
        keywords: ["pdf", "side", "roter", "slett side", "trekk ut", "slå sammen",
                   "kommentar", "uthev", "signatur"],
        blocks: [
            .paragraph("""
                PDF-visningen har **to verktøylinjer**, og de svarer på ulike spørsmål. Den øvre raden \
                arbeider på **innholdet** i én side; den nedre på **mengden av sider**.
                """),
            .heading("Øvre rad — å lese og kommentere"),
            .table(
                headers: ["Knapp", "Hva den gjør"],
                rows: [
                    ["Uthev · Understrek", "Merk den valgte teksten"],
                    ["Notat…", "Fest et notat på siden"],
                    ["Fjern kommentarer", "Fjern hver kommentar fra den gjeldende siden"],
                    ["Trekk ut tekst til en ny fane", "Flytt hele teksten over i en fane, så du kan søke, filtrere og bruke andre verktøy"],
                    ["Søkefelt", "Søk inne i PDF-en — **å skrive uten aksenter finner likevel tekst med aksent**"],
                ]
            ),
            .note("""
                En skannet PDF har ikke noe tekstlag. Uttrekkskommandoen **sier det** i stedet for å \
                åpne en tom fane og la deg gjette.
                """),
            .heading("Nedre rad — sidehandlinger"),
            .table(
                headers: ["Knapp", "Hva den gjør", "Kan angres"],
                rows: [
                    ["Roter venstre · høyre", "Snu den gjeldende siden 90°", "Ja"],
                    ["Side opp · side ned", "Bytt den gjeldende siden med naboen", "Ja"],
                    ["Slett sider…", "Slett etter intervall, f.eks. `2-4,7`", "Ja"],
                    ["Trekk ut sider…", "Skriv et sideintervall ut som en **ny fil**", "Rører ikke den åpne filen"],
                    ["Slå sammen en PDF…", "Sett inn en annen PDF rett etter den gjeldende siden", "Ja"],
                    ["Signer…", "Plasser et signaturbilde på den gjeldende siden", "Ja"],
                    ["Rediger tekst…", "Tegn erstatningstekst over markeringen", "Ja"],
                    ["Neste tomme felt", "Hopp til neste uutfylte skjemafelt", "—"],
                    ["Tøm utfylte verdier", "Tøm hvert skjemafelt", "Ja"],
                    ["Angre sideendring", "Gå ett sidegrep tilbake", "—"],
                    ["Lagre den redigerte kopien…", "Skriv en ny fil, og **åpne den igjen for å kontrollere**", "—"],
                ]
            ),
            .heading("Skjemaer som kan fylles ut"),
            .paragraph("""
                Åpne en PDF med skjemafelt, og statuslinjen sier **hvor mange** det er. Skriv rett inn \
                i feltene på siden, og bruk så `Lagre den redigerte kopien…`.
                """),
            .bullets([
                "Verdiene lagres som **levende skjemafelt**, ikke som flatet tekst — så mottakerens Acrobat ser fortsatt et utfylt skjema og kan rette i det.",
                "Vietnamesiske aksenter overlever runden skriv-og-åpne-igjen. En prøve vokter nettopp det, med navnet `Nguyễn Văn Anh`.",
                "`Neste tomme felt` hopper til neste tomme — den naturlige veien gjennom et langt skjema.",
            ]),
            .heading("Å signere"),
            .paragraph("""
                Forbered et signaturbilde (en PNG med gjennomsiktig bakgrunn virker best), **marker \
                stedet som skal signeres** — som regel den opptrukne linjen eller ordet «Signatur» — og \
                trykk så `Signer…`. Uten en markering lander signaturen nederst til høyre.
                """),
            .note("""
                Signaturen beholder bildets **høyde/bredde-forhold**: en signatur som er klemt eller \
                strukket, ser straks falsk ut.
                """),
            .heading("Å redigere tekst — og tre ting man må vite først"),
            .paragraph("""
                Marker teksten som skal endres, og trykk `Rediger tekst…`. GEditor **dekker det \
                området med en bakgrunnsfarge hentet rett ved siden av**, og tegner så den nye teksten \
                oppå.
                """),
            .warning("""
                **Den gamle teksten er DEKKET, ikke FJERNET.** Den er fortsatt i filen og fortsatt \
                mulig å trekke ut med `Trekk ut tekst til en ny fane` eller et hvilket som helst annet \
                verktøy. Dette er **ikke sladding**: å skjule et personnummer på den måten skjuler det \
                for et menneskeøye, ikke for en maskin.
                """),
            .bullets([
                "**Den nye teksten kan fortsatt finnes med `⌘F`.** Den tegnes som virkelig tekst, ikke som et bilde — målt av en prøve, ikke antatt.",
                "**Skriften er en systemskrift**, ikke dokumentets opprinnelige. Med vilje: skrifter som er bygd inn i en PDF, mangler ofte vietnamesiske aksenter, og `Nguyễn` ville kommet fram som `Nguy?n`.",
                "**På en mønstret bakgrunn synes lappen** — dekkfargen hentes fra ett enkelt sted like til venstre for markeringen.",
            ]),
            .heading("Hvorfor tegne over i stedet for å redigere innholdsstrømmen"),
            .paragraph("""
                Å redigere en PDF-innholdsstrøm direkte betyr å håndtere delmengdeskrifter med sin egen \
                koding, setninger brutt i tre biter av knipingen og tegnbreddetabeller som må regnes ut \
                på nytt. Å gjøre det riktig for **hver** fil er et prosjekt i seg selv; å gjøre det galt \
                ødelegger noens dokument.
                """),
            .paragraph("""
                Til gjengjeld endres resten av siden **ikke med en eneste byte**, og siden forblir en \
                side — teksten markeres, kopieres og søkes i fortsatt. Å tegne over gjør den **ikke** \
                til et bilde.
                """),
            .heading("Sideintervallets syntaks"),
            .table(
                headers: ["Skriv", "Betydning"],
                rows: [
                    ["`5`", "Bare side 5"],
                    ["`2-4`", "Side 2, 3, 4"],
                    ["`-3`", "Fra begynnelsen til side 3"],
                    ["`8-`", "Fra side 8 til slutten"],
                    ["`1-3,5,9-`", "Flere deler forbundet med komma"],
                ]
            ),
            .paragraph("Sider telles **fra 1**, tallet du ser på skjermen."),
            .warning("""
                Et omvendt intervall (`5-2`) og et intervall utover slutten (`1-999`) blir begge \
                **avvist med en grunn**, aldri stille rettet til noe i nærheten. For en kommando som \
                sletter sider, betyr en gal gjetning tapte sider, og en stille beskjæring gjør en \
                skrivefeil til en gyldig kommando.
                """),
            .heading("Den opprinnelige filen overskrives aldri"),
            .paragraph("""
                Alt ovenfor endrer dokumentet **i minnet**. Først når du trykker `Lagre den redigerte \
                kopien…` og velger et sted, blir en fil skrevet — og etter skrivingen **åpner GEditor \
                nettopp den filen igjen** for å bekrefte at den fortsatt har alle sidene sine.
                """),
            .paragraph("""
                Grunnen: en dårlig skrevet fil ligger på disken og ser helt normal ut, og brukeren \
                finner det ut først etter å ha sendt den.
                """),
            .note("""
                Visningens statuslinje viser **· redigert, ikke lagret** når dokumentet avviker fra \
                filen på disken.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
