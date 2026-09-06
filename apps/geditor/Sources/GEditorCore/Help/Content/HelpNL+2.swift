import Foundation

/// Nederlandse helpinhoud — deel 2: zoeken, bestanden en sessies.
extension HelpNL {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Zoeken",
        summary: "Zoeken, vervangen, reguliere uitdrukkingen, zoeken over een map en regelmarkeringen.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Zoeken en vervangen",
        summary: "Drie zoekmodi, en waarom ^ standaard REGELbegin betekent.",
        keywords: ["zoeken", "vervangen", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Zoeken"),
                HelpShortcut("⌥⌘F", "Zoeken en vervangen"),
                HelpShortcut("⌘G / ⇧⌘G", "Volgend / vorig resultaat"),
            ]),
            .heading("Drie modi"),
            .table(
                headers: ["Modus", "Begrijpt", "Voor"],
                rows: [
                    ["Normaal", "Kale tekst, helemaal geen bijzondere tekens", "De meeste zoekopdrachten"],
                    ["Uitgebreid", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Regelovergangen, tabs, bepaalde bytes vinden"],
                    ["Regex", "Volledig PCRE2", "Zoeken op patroon"],
                ]
            ),
            .note("""
                De **uitgebreide** modus begrijpt geen regex-syntaxis. Hij vertaalt alleen een paar \
                ontsnappingsreeksen — daar naar `a.b` zoeken vindt precies die drie tekens; de punt is geen \
                jokerteken.
                """),
            .heading("Twee schakelaars"),
            .bullets([
                "**Hoofdlettergevoelig** — standaard uit.",
                "**Heel woord** — komt alleen overeen als beide uiteinden woordgrenzen zijn.",
            ]),
            .heading("`^` en `$` passen op de randen van elke REGEL"),
            .paragraph("""
                Standaard aan. Wie van Notepad++ komt verwacht dat `^` «regelbegin» betekent; zonder dat \
                zou `^abc` alleen passen als het hele document met `abc` begon — dat wil bijna niemand in \
                een tekstbewerker.
                """),
            .heading("Een slechte uitdrukking laat de toepassing niet vastlopen"),
            .paragraph("""
                De motor is **PCRE2 met JIT-vertaling** en heeft een terugloopbudget. Een patroon dat \
                combinatorisch ontploft wordt gestopt en gemeld, in plaats van het venster te bevriezen.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Reguliere uitdrukkingen",
        summary: "De PCRE2-syntaxis die u echt gebruikt, met voorbeelden die op Vietnamese gegevens draaien.",
        keywords: ["regex", "pcre", "patroon"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor gebruikt **PCRE2**, dezelfde motor als PHP en veel opdrachtregelgereedschap. Open \
                `Zoek ▸ Reguliere uitdrukking uitproberen…` om een patroon op voorbeeldtekst te proberen en \
                te zien wat elke groep vangt **voordat** u het op een echt document loslaat.
                """),
            .heading("Tekenklassen"),
            .table(
                headers: ["Schrijf", "Past op"],
                rows: [
                    ["`.`", "Elk teken behalve een regelovergang"],
                    ["`\\d` · `\\D`", "Een cijfer · geen cijfer"],
                    ["`\\w` · `\\W`", "Een woordteken (letter, cijfer, `_`) · het tegendeel"],
                    ["`\\s` · `\\S`", "Witruimte · geen witruimte"],
                    ["`[abc]`", "Een van de tekens tussen de haken"],
                    ["`[^abc]`", "Een teken dat NIET tussen de haken staat"],
                    ["`[a-z]`", "Een teken uit het bereik"],
                ]
            ),
            .heading("Herhaling"),
            .table(
                headers: ["Schrijf", "Betekenis"],
                rows: [
                    ["`*`", "Nul of meer"],
                    ["`+`", "Een of meer"],
                    ["`?`", "Nul of een"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Precies 3 · tussen 2 en 5 · 2 of meer"],
                    ["`*?` `+?` `??`", "De **luie** vormen — zo weinig mogelijk pakken"],
                ]
            ),
            .warning("""
                `.*` is **gulzig**: het eet tot het einde van de regel en trekt zich dan terug. Bij het \
                scheiden van velden binnen een regel hebt u bijna altijd `.*?` of een nauwe klasse als \
                `[^,]*` nodig.
                """),
            .heading("Ankers en groepen"),
            .table(
                headers: ["Schrijf", "Betekenis"],
                rows: [
                    ["`^` · `$`", "Regelbegin · regeleinde"],
                    ["`\\b`", "Woordgrens"],
                    ["`(…)`", "Een **vangende** groep — herbruikbaar in de vervanging"],
                    ["`(?:…)`", "Niet-vangende groep"],
                    ["`(?<name>…)`", "Groep met naam"],
                    ["`a|b`", "a of b"],
                    ["`(?=…)` · `(?!…)`", "Vooruitkijken: moet volgen · mag niet volgen"],
                    ["`(?<=…)` · `(?<!…)`", "Terugkijken: moet voorafgaan · mag niet voorafgaan"],
                ]
            ),
            .heading("Voorbeelden die werken"),
            .code(language: "regex", caption: "Elk Vietnamees telefoonnummer van 10 cijfers",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Een datum 31/12/2026 in drie groepen breken",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "De derde cel van een eenvoudige CSV-regel (zonder aanhalingstekens)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Logregels met ERROR of FATAL, met hun tijdstempel",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Lege regels, of regels met alleen witruimte",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Vietnamese letters met accenten — gebruik de Unicode-klasse, som ze niet op",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` betekent «elke Unicode-letter», dus het vangt ook `ế` en `đ`. Elke klinker met \
                accent met de hand opsommen is de zekere manier om er een paar te vergeten.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Vervangingsteksten",
        summary: "Gevangen groepen hergebruiken en tijdens het vervangen hoofdletters veranderen.",
        keywords: ["vervangen", "terugverwijzing", "groep", "$1", "\\U"],
        blocks: [
            .heading("Een gevangen groep terugroepen"),
            .table(
                headers: ["Schrijf", "Betekenis"],
                rows: [
                    ["`$1` … `$9`", "De inhoud van groep n"],
                    ["`${1}`", "Hetzelfde met duidelijke grenzen — gebruik het wanneer er een cijfer volgt"],
                    ["`\\1`", "Wordt ook aanvaard; GEditor herschrijft het als `${1}`"],
                    ["`$0`", "De hele overeenkomst"],
                ]
            ),
            .note("""
                Schrijf `${1}` in plaats van `$1` wanneer het volgende teken een cijfer is. `$123` leest als \
                groep 123; `${1}23` is groep 1 gevolgd door twee cijfers.
                """),
            .heading("Hoofdletters veranderen tijdens een vervanging"),
            .table(
                headers: ["Schrijf", "Betekenis"],
                rows: [
                    ["`\\U`", "HOOFDLETTERS vanaf hier"],
                    ["`\\L`", "kleine letters vanaf hier"],
                    ["`\\u`", "Alleen het volgende teken als hoofdletter"],
                    ["`\\l`", "Alleen het volgende teken als kleine letter"],
                    ["`\\E`", "Einde van het `\\U`- of `\\L`-gebied"],
                ]
            ),
            .heading("Voorbeelden"),
            .code(language: "text", caption: "31/12/2026 omzetten in 2026-12-31",
                  source: """
                    Zoek:     (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Vervang:  $3-$2-$1
                    """),
            .code(language: "text", caption: "De provinciecode aan het regelbegin in hoofdletters, de rest houden",
                  source: """
                    Zoek:     ^([a-z]{2,3})(\\s)
                    Vervang:  \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Elke regel als JSON-tekenreeks omhullen",
                  source: """
                    Zoek:     ^(.+)$
                    Vervang:  "$1",
                    """),
            .paragraph("""
                Een groep die **niet meedeed** aan de overeenkomst wordt een lege tekenreeks, geen fout — \
                zo vervangt een patroon met alternatieven als `(a)|(b)` netjes zonder het twee keer te \
                schrijven.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Zoeken en vervangen over een map",
        summary: "Veel bestanden tegelijk doorlopen en de resultaten zien voordat er iets geschreven wordt.",
        keywords: ["zoeken in bestanden", "grep", "massaal vervangen", "map"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "In een map zoeken")]),
            .paragraph("""
                Kies de hoofdmap, filter op bestandsnaampatroon en doorloop. De resultaten verschijnen per \
                bestand gegroepeerd; op een regel klikken opent dat bestand op die plek.
                """),
            .bullets([
                "Dezelfde drie zoekmodi en dezelfde regex-motor als het zoekveld in het document.",
                "Vervangen over een map **toont vooraf** hoeveel bestanden en hoeveel voorkomens zullen veranderen voordat er geschreven wordt.",
                "Het doorlopen gaat parallel en **kan halverwege worden afgebroken**.",
            ]),
            .warning("""
                Vervangen over een map schrijft rechtstreeks in bestanden die **niet open** staan. Die \
                bestanden staan niet in de geschiedenis van ongedaan maken van het geopende document — \
                bekijk eerst het voorbeeld en houd een reservekopie of een repository met versies bij.
                """),
            .heading("Eerdere zoekopdrachten en resultaten uitvoeren"),
            .paragraph("""
                Het resultatenpaneel **bewaart de zoekopdrachten van deze sessie**. Het menu bovenaan somt \
                ze op met hun aantal treffers — zoek `TODO`, lees half, zoek `FIXME` om te vergelijken en \
                keer terug naar de eerste lijst zonder de hele map opnieuw te doorlopen.
                """),
            .paragraph("""
                De knop **Exporteren** opent de huidige zoekopdracht als teksttabblad, één resultaat per \
                regel als `pad:regel:kolom: tekst` — de vorm die `grep -n` gebruikt en die compilers voor \
                fouten gebruiken. Elke regel plakt zo in het `Ga naar`-veld van dit product zelf, en uw \
                `grep`, `awk` en `sed` lezen ze zonder eigen ontleder.
                """),
            .note("""
                De geschiedenis woont **in het geheugen** en wordt nooit naar schijf geschreven: \
                zoekresultaten dragen de inhoud van elke gevonden regel, en dat is dezelfde soort gegevens \
                die de klembordgeschiedenis met opzet niet bewaart.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Regelmarkeringen",
        summary: "Negen markeerkleuren en vier opdrachten die gemarkeerde regels in een resultaat veranderen.",
        keywords: ["bladwijzer", "markering", "f2", "regels filteren"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Markeren is de manier om een document te filteren **zonder het te veranderen**. Markeer elke \
                regel die op een patroon past, en kopieer dan alleen die eruit, of houd alleen die over.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Elke regel markeren die op de huidige zoekopdracht past"),
                HelpShortcut("⌘F2", "De huidige regel markeren / demarkeren"),
                HelpShortcut("F2 / ⇧F2", "Naar de volgende / vorige markering springen"),
            ]),
            .heading("Een gebruikelijke werkwijze"),
            .steps([
                "`⌘F` met het patroon waarop u wilt filteren, bv. `\\bERROR\\b`.",
                "`⌘M` markeert elke passende regel.",
                "`Zoek ▸ Gemarkeerde regels kopiëren` haalt ze naar een nieuw tabblad — of `Alleen gemarkeerde regels houden` filtert ter plaatse.",
            ]),
            .heading("Negen kleuren"),
            .paragraph("""
                Eén regel kan **meerdere kleuren tegelijk** dragen. Gebruik verschillende kleuren voor \
                verschillende criteria en combineer ze: rood voor foutregels, geel voor regels van hetzelfde \
                bestelnummer, en zoek dan de regels die beide dragen.
                """),
            .bullets([
                "`Markeringen omkeren` — gemarkeerde regels worden ongemarkeerd en omgekeerd.",
                "`Alle markeringen wissen` — haalt elke markering weg zonder de inhoud aan te raken.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Naar regel gaan",
        summary: "Naar een regel, een kolom of een bytepositie springen.",
        keywords: ["ga naar", "regelnummer", "cmd+l", "positie", "kolom"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Naar regel gaan")]),
            .paragraph("""
                Het veld begrijpt **drie schrijfwijzen** en onderscheidt ze aan wat u typt — er is geen \
                extra keuzeknop aan te klikken.
                """),
            .table(
                headers: ["Typ", "Gaat naar"],
                rows: [
                    ["`120`", "het begin van regel 120"],
                    ["`120,5` of `120:5`", "regel 120, kolom 5 — de kolom telt TEKENS"],
                    ["`@1024`", "bytepositie 1024 in het bestand"],
                ]
            ),
            .note("""
                `regel:kolom` is precies hoe compilers en linters een positie afdrukken, dus een regel die u \
                net uit een terminal hebt gekopieerd plakt er zo in.

                De `@` voor byteposities heeft een reden: is `1234` een regel of een byte? Er is geen juist \
                antwoord, en verkeerd raden stuurt de cursor ergens heel anders heen, zonder enig signaal. \
                Dat bytegetal is ook wat de statusbalk in het positiesegment toont (`@1024`): wat u daar \
                leest, kunt u hier typen.
                """),
            .bullets([
                "Een kolom **voorbij de lengte van de regel** stopt aan het regeleinde; hij loopt niet door naar de volgende.",
                "Een bytepositie **voorbij het bestand** brengt u naar het einde — dat getal komt meestal uit een eerdere ronde, en het bestand kan gekrompen zijn.",
                "Tekst die hij niet kan lezen wordt **gemeld**, en de cursor blijft staan; hij springt niet naar het begin van het bestand.",
            ]),
            .paragraph("""
                Bij zeer grote bestanden leest GEditor niet het hele bestand om er te komen — de regelindex \
                wordt stap voor stap op de achtergrond opgebouwd.
                """),
            .note("""
                Ook het opdrachtregelgereedschap aanvaardt een positie: `geditor rapport.csv:120:5` opent het \
                bestand met de cursor op regel 120, kolom 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Bestanden en sessies

    static let files = HelpChapter(
        id: "tep",
        title: "Bestanden en sessies",
        summary: "Openen, bewaren, tabbladen, vensters, werkruimtes, en hoe de sessie terugkomt.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Openen en bewaren",
        summary: "Een bestand van elke omvang openen en het met een andere codering of regelovergang bewaren.",
        keywords: ["openen", "bewaren", "dupliceren", "hernoemen", "verplaatsen"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Nieuw document"),
                HelpShortcut("⌘O", "Een bestand openen"),
                HelpShortcut("⌘S", "Bewaren"),
                HelpShortcut("⇧⌘S", "Bewaren als"),
            ]),
            .paragraph("""
                Een bestand in het venster slepen opent het ook. `Bestand ▸ Open recente` bewaart de lijst \
                van bestanden waaraan u net werkte.
                """),
            .heading("Bewaren als: drie dingen die u kunt veranderen"),
            .table(
                headers: ["Verandering", "Betekenis"],
                rows: [
                    ["Codering", "Schrijven in UTF-8, TCVN3, VNI-Windows… — 36 coderingen"],
                    ["Regelovergangen", "LF (Unix) · CRLF (Windows) · CR (klassieke Mac)"],
                    ["Naam en plaats", "Zoals in elk bewaarvenster van macOS"],
                ]
            ),
            .paragraph("""
                De statusbalk toont altijd de codering, de stijl van regelovergang en de herkende taal. **Op \
                een daarvan klikken verandert het meteen**, zonder een dialoogvenster.
                """),
            .heading("Dupliceren · hernoemen · verplaatsen"),
            .paragraph("""
                Deze drie werken op het BESTAND en niet op de inhoud ervan — en het geopende tabblad volgt \
                het bestand, zodat u nooit uw plaats kwijtraakt.
                """),
            .table(
                headers: ["Opdracht", "Wat ze doet"],
                rows: [
                    ["`Bestand dupliceren`",
                     "Kopieert het als `naam 2.txt` naast het origineel en **opent de kopie** — want men dupliceert om de kopie te bewerken"],
                    ["`Bestand hernoemen…`", "Hernoemt op schijf; het tabblad volgt de nieuwe naam"],
                    ["`Bestand verplaatsen naar…`", "Verplaatst naar een andere map; het tabblad volgt"],
                ]
            ),
            .note("""
                Alle drie **weigeren als er op de bestemming al een bestand met die naam bestaat**; ze \
                overschrijven nooit. En alle drie hebben een bestand nodig dat minstens één keer is bewaard — \
                een document dat nooit op schijf stond heeft niets om te dupliceren of te verplaatsen.
                """),
            .heading("Veilig schrijven"),
            .bullets([
                "Het schrijven is **atomair**: een stroomuitval halverwege laat nooit een afgekapt bestand achter.",
                "Verandert een ander programma het bestand terwijl u het open hebt, dan merkt GEditor dat en vraagt vóór het overschrijven.",
                "Bestanden op iCloud Drive of een netwerkvolume gaan via de bestandscoördinator van het systeem, zodat twee machines elkaar niet in de weg lopen.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Tabbladen, vensters en gedeelde weergave",
        summary: "Veel tabbladen per venster, veel vensters, en tabbladen die u ertussen kunt slepen.",
        keywords: ["tabblad", "venster", "delen", "deelvenster"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Nieuw tabblad"),
                HelpShortcut("⌘W", "Tabblad sluiten"),
                HelpShortcut("⇧⌘T", "Het laatst gesloten tabblad opnieuw openen"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Volgend / vorig tabblad"),
                HelpShortcut("⌥⌘N", "Nieuw venster"),
                HelpShortcut("⌃⌘N", "Het huidige tabblad in een eigen venster losmaken"),
            ]),
            .paragraph("""
                U kunt een tabblad naar een ander venster slepen, of het op lege ruimte laten vallen om een \
                venster te maken. **Een vastgezet tabblad reist niet mee** — vastzetten betekent «laat deze \
                hier».
                """),
            .note("""
                `⇧⌘T` opent het laatst gesloten tabblad opnieuw, ook een **niet-bewaard** tabblad: de inhoud \
                is er nog.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Een map als werkruimte openen",
        summary: "Een bestandsboom in de navigatiekolom, zoeken over het hele project en openen met één klik.",
        keywords: ["werkruimte", "map", "project", "navigatiekolom"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Een map als werkruimte openen")]),
            .paragraph("""
                De boom verschijnt in de navigatiekolom (`⌘0`). Klik op een bestand om het te openen, en \
                `⇧⌘F` zoekt in de hele map.
                """),
            .note("""
                In de App Store-uitgave wordt de toegang tot de map vastgehouden door een **bladwijzer met \
                veiligheidsbereik**, zodat de volgende start er nog bij kan zonder u opnieuw om de map te \
                vragen.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "De sessie herstelt zichzelf",
        summary: "Sluit af en open opnieuw: elk tabblad komt terug, ook de niet-bewaarde.",
        keywords: ["sessie", "herstellen", "niet bewaard", "terughalen"],
        blocks: [
            .paragraph("""
                Niets aan te zetten. Sluit GEditor af en open hem weer: de tabbladen, hun volgorde, de \
                cursor- en schuifposities komen allemaal terug.
                """),
            .heading("En de niet-bewaarde tabbladen"),
            .paragraph("""
                Hun inhoud wordt in een aparte momentopname bewaard, dus ze komen ook terug. Eindigt de \
                toepassing abnormaal, dan **vraagt** de volgende start voordat verweesde kladversies worden \
                hersteld — in plaats van stilletjes een stapel tabbladen op te bouwen die u zich niet \
                herinnert.
                """),
            .warning("""
                Een sessie **is geen reservekopie**. Ze bewaart de werktoestand, niet de geschiedenis. Alles \
                wat telt moet nog steeds in een bestand worden bewaard.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Eerder bewaarde versies",
        summary: "Oudere versies van een bestand doorbladeren en terugzetten.",
        keywords: ["versies", "geschiedenis", "terugzetten", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Bij elk bewaren legt GEditor de **vorige** versie vast voordat hij overschrijft. `Macro ▸ \
                Bewaarde versies…` opent de bladeraar ervoor.
                """),
            .bullets([
                "De versieopslag is die van het **besturingssysteem**, hetzelfde mechanisme dat Apples eigen programma's gebruiken.",
                "Een oudere versie terugzetten is een **gewone bewerking** — `⌘Z` maakt haar ongedaan.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Een bestand volgen dat nog wordt geschreven",
        summary: "Zoals `tail -f`: wat erbij komt verschijnt zodra het aankomt.",
        keywords: ["tail", "volgen", "logboek", "realtime"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Bestand ▸ Bestand volgen (tail -f)` laadt wat aan het einde van het bestand verschijnt en \
                schuift mee.
                """),
            .warning("""
                Tijdens het volgen wordt het document **alleen-lezen**. Typen terwijl er nieuwe tekst van \
                schijf wordt geladen, zijn twee schrijvers die om één document vechten, en de verliezer is \
                altijd wat u net typte.
                """),
            .note("""
                De statusbalk zegt de hele tijd **Aan het volgen**, zodat u minuten later nog weet waarom het \
                bestand geen invoer aanneemt. Op het segment **alleen-lezen** klikken geeft de reden \
                onomwonden.

                Het volgen hoort bij het **tabblad dat het startte**, niet bij het venster: open een ander \
                tabblad en typ verder, en nieuwe logregels blijven in hun eigen tabblad stromen zonder het \
                bestand aan te raken dat u bewerkt.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Afdrukken",
        summary: "Afdrukken via het standaard afdrukvenster van macOS.",
        keywords: ["afdrukken", "papier", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Afdrukken")]),
            .paragraph("""
                Het gebruikt het afdrukvenster van het systeem, dus ook naar PDF uitvoeren gebeurt daar — de \
                knop `PDF` linksonder.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Afbeeldingen, PDF, Office-bestanden, audio, video en archieven",
        summary: "Acht soorten bestanden gaan binnen GEditor open zonder een ander programma.",
        keywords: ["afbeelding", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "archief",
                   "audio", "video"],
        blocks: [
            .table(
                headers: ["Soort", "Wat u kunt doen"],
                rows: [
                    ["Afbeeldingen", "Bekijken, inzoomen, draaien; **bewegende afbeeldingen spelen af** en zijn te pauzeren"],
                    ["Audio", "Afspelen, zoeken, volume wijzigen"],
                    ["Video", "Afspelen, zoeken, schermvullend, beeld-in-beeld"],
                    ["PDF", "Lezen, zoeken, **annoteren**"],
                    ["Word · Excel · PowerPoint", "Bekijken **en bewerken** — `⌘S` schrijft rechtstreeks terug in het bestand"],
                    ["ZIP · TAR · GZ · XZ", "Onderdelen opsommen en elk als tabblad openen"],
                    ["7z · RAR en nog zeven formaten", "Hetzelfde, via libarchive"],
                ]
            ),
            .paragraph("""
                Een onderdeel van een archief openen maakt een tabblad met de inhoud ervan. Vietnamese \
                accenten overleven zowel in namen als in inhoud.
                """),
            .note("""
                Bewerk een van de drie Office-formaten, druk op `⌘S`, en het wordt terug in het bestand \
                geschreven — LibreOffice leest het resultaat. Dit pad is van begin tot eind getest, niet \
                slechts naar een kopie uitgevoerd.
                """),
            .heading("Audio en video gebruiken de spelers van macOS"),
            .paragraph("""
                Het afspelen loopt via de decoders van het systeem, dus er wordt niets extra's opgehaald en \
                niets extra's meegeleverd. In ruil daarvoor **spelen enkele formaten niet** — `.mkv`, \
                `.webm`, `.avi`, `.wmv` — omdat macOS er geen ingebouwde decoder voor heeft.
                """),
            .paragraph("""
                Voor zo'n bestand **zegt GEditor waarom** in plaats van een zwarte rechthoek te tonen, en \
                biedt de binaire weergave of een ander programma aan.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "PDF-gereedschap",
        summary: "Lezen, annoteren, en een hele paginalaag: draaien · verplaatsen · wissen · uittrekken · samenvoegen.",
        keywords: ["pdf", "pagina", "draaien", "pagina wissen", "uittrekken", "samenvoegen",
                   "annoteren", "markeren", "ondertekenen"],
        blocks: [
            .paragraph("""
                De PDF-weergave heeft **twee knoppenbalken**, die verschillende vragen beantwoorden. De \
                bovenste rij werkt op de **inhoud** van één pagina; de onderste op de **verzameling \
                pagina's**.
                """),
            .heading("Bovenste rij — lezen en annoteren"),
            .table(
                headers: ["Knop", "Wat ze doet"],
                rows: [
                    ["Markeren · Onderstrepen", "De geselecteerde tekst markeren"],
                    ["Notitie…", "Een notitie aan de pagina hechten"],
                    ["Annotaties verwijderen", "Elke annotatie van de huidige pagina weghalen"],
                    ["Tekst naar een tabblad uittrekken", "Alle tekst naar een tabblad halen om te zoeken, filteren, ander gereedschap te gebruiken"],
                    ["Zoekveld", "In de PDF zoeken — **zonder accenten typen vindt toch tekst mét accenten**"],
                ]
            ),
            .note("""
                Een gescande PDF heeft geen tekstlaag. De uittrekopdracht **zegt dat** in plaats van een leeg \
                tabblad te openen en u te laten raden.
                """),
            .heading("Onderste rij — bewerkingen op pagina's"),
            .table(
                headers: ["Knop", "Wat ze doet", "Ongedaan te maken"],
                rows: [
                    ["Links · rechts draaien", "De huidige pagina 90° draaien", "Ja"],
                    ["Pagina omhoog · omlaag", "De huidige pagina met haar buur verwisselen", "Ja"],
                    ["Pagina's wissen…", "Wissen per bereik, bv. `2-4,7`", "Ja"],
                    ["Pagina's uittrekken…", "Een paginabereik als **nieuw bestand** schrijven", "Raakt het geopende bestand niet aan"],
                    ["Een PDF samenvoegen…", "Een andere PDF vlak na de huidige pagina invoegen", "Ja"],
                    ["Ondertekenen…", "Een handtekeningafbeelding op de huidige pagina plaatsen", "Ja"],
                    ["Tekst bewerken…", "Vervangende tekst over de selectie tekenen", "Ja"],
                    ["Volgend leeg veld", "Naar het volgende niet-ingevulde formulierveld springen", "—"],
                    ["Ingevulde waarden wissen", "Elk formulierveld leegmaken", "Ja"],
                    ["Paginawijziging ongedaan maken", "Eén paginabewerking terug", "—"],
                    ["De bewerkte kopie bewaren…", "Een nieuw bestand schrijven en het dan **opnieuw openen ter controle**", "—"],
                ]
            ),
            .heading("Invulbare formulieren"),
            .paragraph("""
                Open een PDF met formuliervelden en de statusbalk zegt **hoeveel** er zijn. Typ rechtstreeks \
                in de velden op de pagina, en daarna `De bewerkte kopie bewaren…`.
                """),
            .bullets([
                "De waarden worden bewaard als **levende formuliervelden**, niet als platgeslagen tekst — zo ziet de Acrobat van de ontvanger nog steeds een ingevuld formulier en kan hij het verbeteren.",
                "Vietnamese accenten overleven de ronde schrijven-en-heropenen. Een test bewaakt precies dat, met de naam `Nguyễn Văn Anh`.",
                "`Volgend leeg veld` springt naar het volgende lege — de natuurlijke weg door een lang formulier.",
            ]),
            .heading("Ondertekenen"),
            .paragraph("""
                Maak een handtekeningafbeelding klaar (een PNG met doorzichtige achtergrond werkt het best), \
                **selecteer de plek om te tekenen** — meestal de lijn of het woord «Handtekening» — en druk \
                op `Ondertekenen…`. Zonder selectie belandt de handtekening rechtsonder.
                """),
            .note("""
                De handtekening houdt de **verhoudingen** van de afbeelding: een geplette of uitgerekte \
                handtekening ziet er meteen vals uit.
                """),
            .heading("Tekst bewerken — en drie dingen om eerst te weten"),
            .paragraph("""
                Selecteer de tekst die u wilt veranderen en druk op `Tekst bewerken…`. GEditor **dekt dat \
                gebied af met een achtergrondkleur die vlak ernaast is bemonsterd** en tekent de nieuwe tekst \
                erover.
                """),
            .warning("""
                **De oude tekst is AFGEDEKT, niet VERWIJDERD.** Hij staat nog in het bestand en is nog steeds \
                uit te trekken met `Tekst naar een tabblad uittrekken` of met elk ander gereedschap. Dit is \
                **geen onleesbaar maken**: een identiteitsnummer zo verbergen verbergt het voor een menselijk \
                oog, niet voor een machine.
                """),
            .bullets([
                "**De nieuwe tekst blijft vindbaar met `⌘F`.** Hij wordt als echte tekst getekend, niet als afbeelding — gemeten door een test, niet aangenomen.",
                "**Het lettertype is een systeemlettertype**, niet dat van het document. Met opzet: in een PDF ingebedde lettertypen missen vaak de Vietnamese accenten, en `Nguyễn` zou als `Nguy?n` aankomen.",
                "**Op een achtergrond met patroon valt de lap op** — de dekkleur wordt op één enkel punt vlak links van de selectie bemonsterd.",
            ]),
            .heading("Waarom overtekenen in plaats van de inhoudsstroom bewerken"),
            .paragraph("""
                De inhoudsstroom van een PDF rechtstreeks bewerken betekent omgaan met deelverzamelingen van \
                lettertypen met een eigen codering, zinnen die door onderlinge letterafstand in drie stukken \
                zijn gebroken, en tabellen met tekenbreedtes die opnieuw berekend moeten worden. Dat voor \
                **elk** bestand goed doen is een project op zich; het slecht doen bederft andermans document.
                """),
            .paragraph("""
                In ruil verandert de rest van de pagina **geen enkele byte**, en blijft de pagina een pagina — \
                tekst is nog steeds te selecteren, te kopiëren en te doorzoeken. Overtekenen maakt er **geen** \
                afbeelding van.
                """),
            .heading("Syntaxis van paginabereiken"),
            .table(
                headers: ["Typ", "Betekenis"],
                rows: [
                    ["`5`", "Alleen pagina 5"],
                    ["`2-4`", "Pagina's 2, 3, 4"],
                    ["`-3`", "Van het begin tot pagina 3"],
                    ["`8-`", "Van pagina 8 tot het einde"],
                    ["`1-3,5,9-`", "Meerdere delen, verbonden door komma's"],
                ]
            ),
            .paragraph("Pagina's tellen **vanaf 1**, het nummer dat u op het scherm ziet."),
            .warning("""
                Een omgekeerd bereik (`5-2`) en een bereik voorbij het einde (`1-999`) worden beide **met een \
                reden geweigerd**, nooit stilletjes tot iets vergelijkbaars bijgesteld. Bij een opdracht die \
                pagina's wist betekent verkeerd raden pagina's kwijtraken, en stil bijknippen maakt van een \
                typefout een geldige opdracht.
                """),
            .heading("Het oorspronkelijke bestand wordt nooit overschreven"),
            .paragraph("""
                Alles hierboven verandert het document **in het geheugen**. Pas wanneer u op `De bewerkte \
                kopie bewaren…` drukt en een plaats kiest, wordt er een bestand geschreven — en na het \
                schrijven **opent GEditor juist dat bestand opnieuw** om te bevestigen dat het nog al zijn \
                pagina's heeft.
                """),
            .paragraph("""
                De reden: een slecht geschreven bestand ligt volkomen normaal ogend op de schijf, en de \
                gebruiker merkt het pas nadat hij het heeft verstuurd.
                """),
            .note("""
                De statusregel van de weergave zegt **· bewerkt, niet bewaard** zodra het document afwijkt van \
                het bestand op schijf.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
