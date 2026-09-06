import Foundation

/// Dansk hjælpeindhold — del 4: tabeldata, datarensning og datagravning.
extension HelpDA {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Tabeldata",
        summary: "Se CSV som tabel, filtrér, sortér, kontrollér opbygning, spørg med SQL, omsæt.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "At se CSV som tabel",
        summary: "En million rækker ruller stadig jævnt, overskrifterne bliver stående, og kildeteksten røres ikke.",
        keywords: ["csv", "tabel", "gitter", "tsv", "excel", "kolonner"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Skift mellem tabel og tekst")]),
            .paragraph("""
                Tabellen er **virtualiseret**: kun synlige rækker bygges, så en fil med en million \
                rækker ruller som en med hundrede.
                """),
            .bullets([
                "**Overskriftsrækken bliver stående** under rulning — ved række 40.000 ved du stadig, hvad den niende kolonne er.",
                "Redigér en celle i tabellen; ændringen går direkte ind i kildeteksten.",
                "Tabel og tekst er **to visninger af én fil**, ikke to kopier.",
                "**⌘C kopierer den markerede række**, celler adskilt af TAB — indsæt direkte i Excel eller Numbers, og hver celle lander rigtigt. Celler med TAB eller linjeskift sættes i citater, så modtageren ikke deler dem i to.",
            ]),
            .note("""
                Skilletegnet genkendes ved åbning (komma, semikolon, TAB, lodret streg). Er gættet \
                forkert, ændrer du det med `CSV ▸ Skift skilletegn…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Regneark med flere ark",
        summary: "Åbn ethvert ark i en .xlsx, og ⌘S skriver tilbage i det ark, du ser på.",
        keywords: ["excel", "xlsx", "ark", "projektmappe", "flere ark"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Åbn en `.xlsx`, og GEditor viser det **første ark** som en CSV-tabel. `CSV ▸ Vælg ark…` \
                lister hvert ark i filen og åbner det, du vælger, i samme faneblad.
                """),
            .heading("At skrive tilbage i det RIGTIGE ark"),
            .paragraph("""
                `⌘S` skriver dine ændringer ind i **det ark, du ser på**, ikke i det første. De andre \
                ark røres ikke med en eneste byte.
                """),
            .note("""
                Arket huskes efter **navn**, ikke efter placering. Derved leder en omordning af arkene i \
                Excel mellem to omgange ikke skrivningen på afveje.
                """),
            .warning("""
                Er det åbne ark blevet **omdøbt eller slettet** i Excel, siden du åbnede det, **nægter \
                `⌘S` at skrive** og siger det. At falde tilbage til det første ark ville betyde at \
                hælde ét arks indhold ud over et andet — filen ville stadig gemme, stadig åbne igen og \
                blot have dataene det forkerte sted.
                """),
            .heading("At skifte ark med ugemte ændringer"),
            .paragraph("""
                At skifte ark erstatter hele fanebladets indhold, så hvis noget er ugemt, **spørger \
                GEditor først**. `⌘Z` kan ikke hente det tilbage, for hele dokumentet blev byttet ud.
                """),
            .heading("Hvad det koster at bringe Excel ned til en tabel"),
            .paragraph("""
                Det, der overlever, er **værdier** — også formelresultater, præcis de tal Excel viser. \
                Det, der ikke gør: skrifter, farver, flettede celler, indlejrede diagrammer og selve \
                formlerne.
                """),
            .paragraph("""
                Til gengæld får det ark hele resten af produktet: filtrering, sortering, \
                SQL-forespørgsler, rensebænken, kvalitetsbedømmelse, udgravning, diagrammer.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "At filtrere og sortere i tabellen",
        summary: "Et filterfelt pr. kolonne, der forstår talsammenligning og skrift uden accenter.",
        keywords: ["filter", "sortér", "kolonne", "søg i tabel"],
        blocks: [
            .paragraph("Klik på en kolonneoverskrift for at sortere. Filterfeltet under den tager imod:"),
            .table(
                headers: ["Skriv i filteret", "Betydning"],
                rows: [
                    ["`hue`", "Indeholder `hue`, **accentufølsomt** — finder også `Huế`"],
                    ["`=Huế`", "Præcis `Huế` (stadig accentufølsomt)"],
                    ["`>100`", "Større end 100"],
                    ["`>=100`", "100 eller mere"],
                    ["`<0`", "Mindre end 0"],
                    ["`100..200`", "Mellem 100 og 200"],
                    ["tomt", "Intet filter på denne kolonne"],
                ]
            ),
            .paragraph("""
                At filtrere flere kolonner er et **og**: en række skal opfylde dem alle. \
                Talsammenligning springer ikke-numeriske celler over frem for at behandle dem som nul.
                """),
            .note("""
                Filtrering er en **måde at se på**, ikke en sletning. Ryd filteret, og hver række \
                kommer tilbage.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "At kontrollere tabellens opbygning",
        summary: "Find rækker med forkert kolonneantal og celler af forkert type — gør dette først.",
        keywords: ["kontrollér", "kolonneantal", "forkert type", "ødelagte data"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Dette er, hvad man kører **før** alt andet på en fil, nogen har sendt. Det besvarer to \
                spørgsmål:
                """),
            .bullets([
                "**Hvilke rækker har det forkerte kolonneantal?** Som regel en celle med et komma, der ikke blev sat i citater — og den forskubber hver række efter den.",
                "**Hvilke celler har en type ulig resten af deres kolonne?** For eksempel `n/a` i en kolonne med tal.",
            ]),
            .paragraph("Resultaterne vises som en liste; klik på et for at springe til den række."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "At slette kolonner",
        summary: "Fjern en eller flere kolonner helt fra filen.",
        keywords: ["slet kolonne", "fjern kolonne"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Vælg de kolonner, der skal fjernes, fra listen, og anvend. Det er **ét** \
                fortrydelsestrin, uanset hvor mange rækker filen har.
                """),
            .warning("""
                Til forskel fra filtrering **redigerer dette den virkelige fil**. Vil du blot skjule \
                kolonner, så brug en SQL-forespørgsel, der nævner de kolonner, du vil have.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "At spørge en CSV med SQL",
        summary: "DuckDB's fulde SQL, kørt direkte mod den åbne fil — skrivebeskyttet.",
        keywords: ["sql", "forespørgsel", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Den åbne tabel hedder **`t`**. Motoren er **DuckDB**, så `JOIN`, `DISTINCT`, `HAVING`, \
                `IN`, `LIKE`, `BETWEEN`, vinduesfunktioner og underforespørgsler virker alle.
                """),
            .code(language: "sql", caption: "Omsætning pr. provins, størst først",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "At filtrere efter dato og efter en tekstbetingelse",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Hver provins' andel af det samlede — med en vinduesfunktion",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "At sammenføje mod en anden fil på disken",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Skrivebeskyttet, og det er en hård garanti"),
            .bullets([
                "Databasen lever **i hukommelsen**; kildefilen bliver kun læst.",
                "Præcis **én sætning** tages imod, og den **skal være en `SELECT`**. Alt andet — også `COPY … TO 'file'`, som DuckDB udmærket kan bruge til at skrive til disken — blokeres, før det når nogen data.",
            ]),
            .warning("""
                DuckDB læser **filer**, ikke hukommelse. Har dokumentet ugemte ændringer, må GEditor \
                skrive en midlertidig kopi før forespørgslen. For en meget stor fil med ugemte \
                ændringer **standser den og siger det** frem for stille at skrive hundredvis af \
                megabytes til disken for én forespørgsel.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Pivottabeller og hurtige diagrammer",
        summary: "Pivotér og tegn direkte ud fra et forespørgselsresultat.",
        keywords: ["pivot", "diagram", "graf", "krydstabel", "aggregat"],
        blocks: [
            .paragraph("""
                Begge åbnes fra **resultattabellen**: kør en SQL-sætning, og brug så knappen Pivot \
                eller Diagram på panelet.
                """),
            .heading("Pivot"),
            .paragraph("""
                Vælg **række**kolonnen, **kolonne**kolonnen, **værdi**kolonnen og aggregatet (sum, \
                antal, gennemsnit, mindste, største) — som i et regnearks pivottabel.
                """),
            .heading("Diagrammer"),
            .paragraph("""
                Søjle, linje, cirkel, punkt. Tal formateret på vietnamesisk eller europæisk vis, og \
                diagrammet eksporteres som PNG eller SVG til at indsætte andetsteds.
                """),
            .note("""
                Vil du have et diagram, der **genberegnes med dataene** ved hver opbygning? Det er \
                `chart`-blokken i en `.greport.md`-rapport.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "At omsætte en tabel til et andet format",
        summary: "TSV, JSON, XML, Markdown-tabeller, SQL INSERT-sætninger — med en forhåndsvisning.",
        keywords: ["omsæt", "eksportér", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Format", "Nyttigt til"],
                rows: [
                    ["TSV", "At indsætte i et regneark uden at bekymre sig om kommaer i celler"],
                    ["JSON", "At fodre en API, et script eller et andet værktøj"],
                    ["XML", "Ældre systemer, der kræver XML"],
                    ["Markdown-tabel", "At indsætte i dokumentation, en README, en sag"],
                    ["SQL INSERT-sætninger", "At indlæse i en database"],
                ]
            ),
            .paragraph("""
                Dialogen **viser de første fem rækker**, før det nye faneblad laves — fem linjer er nok \
                til at bekræfte tabelnavnet, citeringen og hvilke kolonner der blev til tal.
                """),
            .note("""
                Forhåndsvisningen kalder **samme funktion**, som laver det virkelige uddata, begrænset \
                til fem rækker. Det er ikke en efterligning, der kunne være uenig med det endelige \
                resultat.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "At skifte skilletegn",
        summary: "Omsæt en fil mellem komma, semikolon, TAB og lodret streg.",
        keywords: ["skilletegn", "komma", "semikolon", "tab", "europæisk csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Filer eksporteret fra et vietnamesisk eller europæisk Excel bruger som regel \
                **semikolon**, fordi kommaet dér er decimaltegnet.
                """),
            .warning("""
                At skifte skilletegn **omskriver hele filen**. Celler, der indeholder det nye \
                skilletegn, sættes i citater — ellers går tabellens opbygning i stykker.
                """),
            .note("""
                **Var genkendelsen forkert, er dette ikke den kommando, du vil have.** Der er to \
                forskellige opgaver her, præcis som ved tegnkodningsparret »fortolk om« / »omsæt«:

                • *Filen er virkelig semikolonadskilt, og vi gættede komma* — klik på feltet `CSV · …` \
                på **statuslinjen**, og vælg den rigtige. Ikke en byte i filen ændres; kun måden den \
                læses på.

                • *Filen er virkelig kommaadskilt, og du vil have semikolon* — brug kommandoen på denne \
                side. Den omskriver filen.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Datarensning

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Datarensning — hele forløbet",
        summary: "Fra en rå fil, nogen har sendt dig, til en brugbar tabel, og en standard du kan køre hver måned.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Renseforløbet fra ende til anden",
        summary: "Seks trin fra en ukendt fil til en troværdig tabel, og en standard til næste måned.",
        keywords: ["rensning", "rens", "forløb", "normalisér", "ryddelige data"],
        blocks: [
            .paragraph("""
                At rense data er **sjældent en engangsopgave**. Folk får den samme rapportskabelon hver \
                måned, og hver måned skal de samme kolonner normaliseres på samme måde. Dette forløb er \
                lavet til netop det: du gør det i hånden én gang og kører det så igen med en enkelt \
                kommando.
                """),
            .heading("Seks trin"),
            .steps([
                "**Se på opbygningen først.** `CSV ▸ Kontrollér data` — hvilke rækker har forkert kolonneantal, hvilke celler forkert type. Dette kommer først, fordi én forskudt række gør hver senere statistik meningsløs.",
                "**Læs dataprofilen.** Pr. kolonne: hvor mange tomme celler, hvor mange forskellige værdier, hvilken type, hvor de afvigende ligger. Det er her, du forstår filen, før du ændrer noget.",
                "**Åbn rensebænken** (`⇧⌘L`). Den finder blandede datoformater, vietnamesiske tal blandet med europæiske, løse blanktegn, manglende værdier. **Se før→efter**, og anvend så.",
                "**Håndtér uklare dubletter**, hvis en navne- eller adressekolonne har håndskrevne varianter. Her bestemmer du; maskinen foreslår kun.",
                "**Gem det som en opskrift.** Den række skridt, du netop udførte, skrives til en navngiven JSON-fil — den fil er din viden om disse data.",
                "**Skriv et kvalitetsregelsæt** `.gquality.yaml`, og bedøm det. Fra nu af kører næste måneds fil gennem opskriften og bliver bedømt, og **kommandolinjeporten** giver en udgangskode forskellig fra nul, når den fejler.",
            ]),
            .heading("Hvorfor denne rækkefølge"),
            .bullets([
                "Opbygning **før** profil: statistik på en forskudt tabel er statistik om en anden kolonne.",
                "Profil **før** rensning: du skal vide `2 % tomme`, før du beslutter at udfylde eller fjerne.",
                "Uklare dubletter **efter** normalisering: `CÔNG TY  A` og `Công ty A` viser sig først som én, når blanktegn og bogstavstørrelse er afgjort.",
                "Opskrift **før** regelsæt: opskriften retter, reglerne dømmer — at bedømme en urettet tabel giver blot et lavt tal, du allerede havde forventet.",
            ]),
            .heading("Efter første gang er hver måned én kommando"),
            .code(language: "bash", caption: "Rens og bedøm, med en udgangskode til CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Udgangskode **0** betyder bestået, **1** betyder ikke bestået, **2** betyder en fejl \
                under kørslen. `--record-history` føjer en linje til historikfilen, så næste kørsel kan \
                sammenligne afdrift.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Dataprofil",
        summary: "Én beskrivelse pr. kolonne: type, tomme, forskellige værdier, fordeling.",
        keywords: ["profil", "kolonnestatistik", "null", "forskellige"],
        blocks: [
            .paragraph("""
                En profil **beskriver**; den dømmer ikke. Den siger *»denne kolonne er 2 % tom«*; om 2 % \
                er acceptabelt, hører til kvalitetsregelsættet.
                """),
            .table(
                headers: ["Mål", "Sådan læses det"],
                rows: [
                    ["Type", "Udledt af dataene selv, ikke af kolonnenavnet"],
                    ["Tomme celler", "Antal og andel af manglende værdier"],
                    ["Forskellige værdier", "1 betyder en konstant kolonne; lig med rækkeantallet betyder en nøglekolonne"],
                    ["Mindste · største · gennemsnit", "Kun numeriske kolonner"],
                    ["Hyppigste værdier", "Få straks øje på en fejlkode eller en overbrugt standardværdi"],
                ]
            ),
            .warning("""
                Optælling af forskellige værdier har en tærskel. Derover er det viste tal en **nedre \
                grænse**, og profilen **siger, at det er et skøn**, frem for at blande det sammen med \
                nøjagtige tal.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Rensebænken",
        summary: "Syv normaliseringer, altid med forhåndsvisning, altid ét fortrydelsestrin, aldrig gættet.",
        keywords: ["rens", "normalisér", "datoer", "tal", "trim", "udfyld manglende"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Åbn rensebænken")]),
            .table(
                headers: ["Handling", "Hvad den gør"],
                rows: [
                    ["Normalisér datoer", "Bring hver datoform i kolonnen til én form"],
                    ["Normalisér tal", "Afgør decimaltegnet og tusindtalstegnet"],
                    ["Klip blanktegn", "Fjern dem i begge ender; slå eventuelt indre serier sammen"],
                    ["Skift bogstavstørrelse", "Gør kolonnens store/små bogstaver ensartede"],
                    ["Udfyld med en fast værdi", "Erstat tomme celler med en værdi, du skriver"],
                    ["Udfyld fra en nabo", "Tag værdien fra rækken over eller under"],
                    ["Slet rækker med tomme celler", "Fjern rækker, der mangler data"],
                ]
            ),
            .heading("Tre garantier fra hele bænken"),
            .bullets([
                "**Altid med forhåndsvisning.** En før→efter-tabel med antallet af celler, der vil ændre sig.",
                "**Ét fortrydelsestrin** for hele omgangen, også når den rører en million celler.",
                "**En rapport bagefter**: hvor mange celler ændrede sig, og hvilke der ikke kunne læses.",
            ]),
            .heading("Princippet: gæt aldrig"),
            .paragraph("""
                En celle, der ikke kan læses med sikkerhed, bliver **markeret og ladt i fred**. Tag \
                `03/04/2026` i en kolonne, der blander begge konventioner — er det 3. april eller 4. \
                marts? GEditor spørger dig om dag/måned-rækkefølgen frem for at vælge for dig.
                """),
            .warning("""
                At normalisere en datokolonne forkert er den slags ødelæggelse, der er **næsten umulig \
                at opdage**: tallene ser stadig rigtige ud, de er blot en anden dato. Derfor vil denne \
                bænk hellere nægte end udlede.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Uklare dubletter",
        summary: "Find håndskrevne varianter af samme navn — og flet dem aldrig sammen af sig selv.",
        keywords: ["uklar", "dubletter", "flet", "varianter", "slåfejl"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — tre måder at \
                skrive én kunde på. Almindelig dublethåndtering ser dem ikke som den samme.
                """),
            .steps([
                "Vælg den kolonne, der skal undersøges, og en lighedstærskel.",
                "GEditor grupperer nære værdier i **klynger** og viser sammenligningsformen.",
                "For **hver klynge** vælger du, hvilken værdi der skal beholdes — eller springer klyngen over.",
                "Anvend. Ét fortrydelsestrin.",
            ]),
            .warning("""
                Dette værktøj **fletter aldrig af sig selv**, og der er ingen »flet alle«-knap. To \
                strenge, der ligner hinanden 92 %, kan være en slåfejl eller to virkeligt forskellige \
                firmaer, der adskiller sig ved ét ord — det kan en maskine ikke afgøre.
                """),
            .paragraph("""
                At flette to poster forkert er **stille** datatab: ingen celle bliver tom, ingen række \
                bliver rød, to enheder bliver blot til én, og ingen opdager det, før regnskabet skal \
                afstemmes.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Renseopskrifter",
        summary: "Optegn rækkefølgen som en JSON-fil, og kør den igen på næste måneds data.",
        keywords: ["opskrift", "gentag", "automatisér", "månedlig", "sats"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Efter rensningen gemmer du skridtene som en **opskrift**. Det er en læsbar JSON-fil, du \
                kan gemme ved siden af dataene, sende til en kollega og lægge i et arkiv, så ændringer \
                spores.
                """),
            .code(language: "json", caption: "sales-standard.json — forkortet",
                  source: """
                    {
                      "version": 1,
                      "name": "Sales report standardisation",
                      "sourceFile": "sales-2026-08.csv",
                      "steps": [
                        { "enabled": true, "column": "ngay",       "action": "normalizeDates" },
                        { "enabled": true, "column": "doanh_thu",  "action": "normalizeNumbers" },
                        { "enabled": true, "column": "khach_hang", "action": "trim" }
                      ]
                    }
                    """),
            .paragraph("""
                Hvert skridt kan **slås fra** (`enabled`), så én opskrift kan tjene flere næsten ens \
                slags filer.
                """),
            .heading("At køre igen"),
            .bullets([
                "I programmet: `CSV ▸ Kør renseopskrift…`",
                "Fra skallen, på tværs af en mappe: se siden om kommandolinjen.",
            ]),
            .code(language: "bash", caption: "En prøvekørsel, før noget skrives — ingen fil røres",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Som standard skrives resultatet til en ny fil ved siden af originalen \
                (`sales-clean.csv`). At overskrive originalen skal bedes om udtrykkeligt med \
                `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Bedømmelse af datakvalitet",
        summary: "Seks dimensioner, én karakter fra 0 til 100, og hver formel trykt, så du kan regne den efter.",
        keywords: ["kvalitet", "karakter", "dqr", "seks dimensioner"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Den adskiller sig fra dataprofilen på én grundlæggende måde: en profil **beskriver**, en \
                karakter **dømmer mod den standard, du erklærede** i en `.gquality.yaml`-fil.
                """),
            .table(
                headers: ["Dimension", "Hvad den måler"],
                rows: [
                    ["Fuldstændighed", "Andel af udfyldte celler, efter `not_null`-reglerne"],
                    ["Gyldighed", "Andel af format-, type-, interval- og regex-regler, der består"],
                    ["Entydighed", "Mod den nøgle, du erklærede i `uniqueness_key`"],
                    ["Sammenhæng", "Regler på tværs af kolonner og på tværs af filer"],
                    ["Nøjagtighed (skønnet)", "Afvigere i de numeriske kolonner, du udpeger"],
                    ["Aktualitet", "Hvor gamle dataene er mod tærsklen `freshness`"],
                ]
            ),
            .heading("Tre garantier om karakteren"),
            .bullets([
                "**Formlen er trykt i resultatet** — du kan regne den efter i hånden.",
                "**Deterministisk**: samme data og samme regler giver samme karakter. Kun *Aktualitet* afhænger af øjeblikket, så `now` er en **parameter** og noteres i resultatet.",
                "**En dimension, der ikke kan bedømmes, står tom med en grund**, aldrig stille givet 100.",
            ]),
            .warning("""
                Den sidste garanti betyder noget. En tabel uden erklæret `uniqueness_key`, tildelt 100 \
                for »entydighed«, er en karakter, der lyver — og den lyver i den smigrende retning, som \
                er den farlige.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "`.gquality.yaml`-syntaks",
        summary: "Hver nøgle i regelfilen, med ét fuldstændigt regelsæt, der kører.",
        keywords: ["gquality", "yaml", "regler", "syntaks", "datastandard"],
        blocks: [
            .paragraph("""
                Filen ligger **ved siden af dataene**, ikke inde i programmet: en datastandard skal \
                kunne gennemses, og at gennemse er, hvad folk gør med standarder.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — et fuldstændigt regelsæt",
                  source: """
                    schemaVersion: 1

                    # Vægte for de seks dimensioner. En manglende dimension vejer 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Nøglen, der gør en række entydig. Uden den KAN dimensionen "Entydighed"
                    # ikke bedømmes — og totalen vil sige, at den mangler.
                    uniqueness_key: [ma_don]

                    # Numeriske kolonner undersøgt for afvigere i "Nøjagtighed (skønnet)".
                    accuracy_columns: [doanh_thu, so_luong]

                    # Dimensionen "Aktualitet".
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Advar, når denne kørsel falder i forhold til den forrige.
                    drift:
                      max_total_drop: 3
                      max_dimension_drop: 5
                      max_row_change_pct: 20
                      max_null_increase_pct: 1
                      warn_on_new_failure: true

                    rules:
                      - col: ma_don
                        not_null: true
                      - col: ma_don
                        unique: true
                      - col: doanh_thu
                        dtype: float
                      - col: doanh_thu
                        range: { min: 0 }
                      - col: so_luong
                        dtype: int
                        severity: warn
                      - col: ngay
                        date_format: "yyyy-MM-dd"
                      - col: email
                        regex: "^[^@ ]+@[^@ ]+\\\\.[a-z]{2,}$"
                      - col: trang_thai
                        in_set: [moi, dang_giao, hoan_tat, huy]
                      - col: ghi_chu
                        length: { max: 500 }
                      - col: ma_tinh
                        not_null: true
                        max_null_pct: 2          # tillad 2 % tomme
                      # Regel på tværs af kolonner: ingen `col` nødvendig
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Regel på tværs af filer: værdien skal findes i en anden fil
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Regeltyperne"),
            .table(
                headers: ["Nøgle", "Betydning", "Dimension"],
                rows: [
                    ["`not_null: true`", "Cellen skal være udfyldt; `max_null_pct` løsner det", "Fuldstændighed"],
                    ["`unique: true`", "Ingen gentagne værdier i kolonnen", "Entydighed"],
                    ["`dtype: int\\|float\\|date\\|text`", "Rigtig type", "Gyldighed"],
                    ["`range: { min:, max: }`", "Inden for et talinterval", "Gyldighed"],
                    ["`length: { min:, max: }`", "Strenglængde", "Gyldighed"],
                    ["`regex: \"…\"`", "Passer til et regulært udtryk", "Gyldighed"],
                    ["`in_set: [ … ]`", "Ét af en given liste", "Gyldighed"],
                    ["`date_format: \"…\"`", "Rigtig datoform", "Gyldighed"],
                    ["`compare: { a:, op:, b: }`", "Sammenlign to kolonner; `op` er `<` `<=` `=` `>=` `>` `<>`", "Sammenhæng"],
                    ["`foreign_key: { file:, column: }`", "Værdien skal findes i en anden fil", "Sammenhæng"],
                    ["`severity: error\\|warn`", "Reglens alvorsgrad; `error` som standard", "—"],
                ]
            ),
            .warning("""
                Stav en regelnøgle forkert, og filen bliver **afvist med en besked**, frem for at den \
                regel springes stille over. At springe stille over betyder, at du tror, dataene blev \
                kontrolleret mod en regel, der aldrig kørte.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "En kvalitetsport i CI",
        summary: "Stands data, der ikke består, ved rørledningen, ved hjælp af udgangskoder.",
        keywords: ["ci", "port", "fail-under", "udgangskode", "automatisering", "historik", "afdrift"],
        blocks: [
            .code(language: "bash", caption: "Bedøm og giv en udgangskode",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Tilvalg", "Betydning"],
                rows: [
                    ["`--quality <fil.yaml>`", "Regelsættet, der bedømmes mod"],
                    ["`--fail-under <0…100>`", "Under denne karakter er det ikke bestået"],
                    ["`--json <fil\\|->`", "Maskinlæsbart resultat; `-` skriver til standarduddata"],
                    ["`--record-history`", "Føj en linje til `sales-standard.history.jsonl`"],
                    ["`--now <ÅÅÅÅ-MM-DD>`", "Fastsæt referencedatoen for *Aktualitet*"],
                    ["`--recipe <fil.json>`", "Rens **i hukommelsen** før bedømmelsen, uden at skrive en fil"],
                ]
            ),
            .table(
                headers: ["Udgangskode", "Betydning"],
                rows: [["`0`", "Bestået"], ["`1`", "Ikke bestået"], ["`2`", "Fejl under kørslen"]]
            ),
            .heading("Hvorfor CI bør give `--now`"),
            .paragraph("""
                Uden den sammenligner *Aktualitet* dataene med kørslens øjeblik — så den samme fil taber \
                point, efterhånden som dagene går, og en morgen bliver rørledningen rød, uden at nogen \
                har ændret noget.
                """),
            .heading("Sporing af afdrift"),
            .paragraph("""
                Med `--record-history` føjer hver kørsel en linje til en JSONL-historikfil. Næste gang \
                sammenligner tærsklerne i blokken `drift:` med den seneste kørsel og advarer, når \
                faldet er for stort.
                """),
            .note("""
                Hver afdriftstærskel er **slået fra som standard**, undtagen `warn_on_new_failure`. En \
                advarsel slået til fra begyndelsen med et tal, programmet valgte for dig, ville udløses \
                ved alles anden kørsel — og noget, der råber ulven kommer på dag ét, bliver ignoreret \
                på dag tre.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Datagravning

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Datagravning — hele forløbet",
        summary: "Afvigelser, samvariation, klyngedannelse, prognoser, associationsregler — og hvordan man læser dem.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Gravningsforløbet fra ende til anden",
        summary: "Seks værktøjer, rækkefølgen at bruge dem i, og én regel: ingen måling, ingen slutning.",
        keywords: ["gravning", "analyse", "forløb", "statistik"],
        blocks: [
            .warning("""
                **Rens først, grav bagefter.** En unormaliseret datokolonne giver forkerte prognoser; en \
                talkolonne, der blander europæiske tusindtalstegn, giver spøgelsesafvigere. Hvert \
                værktøj nedenfor går ud fra, at tabellen er ren.
                """),
            .heading("Rækkefølgen at gå i"),
            .steps([
                "**Find afvigelser** — besvarer *»er nogen række underlig«*. Billigst og ofte straks nyttigt.",
                "**Samvariationsmatrix** — besvarer *»hvilken kolonne bevæger sig med hvilken«*. Den styrer alt derefter.",
                "**Klyngedannelse** — besvarer *»hvor mange naturlige grupper er her«*.",
                "**Prognose** — kun med en tidskolonne og mindst **to fulde cyklusser**.",
                "**Associationsregler** — kun for kurveformede data: én transaktion pr. række, eller to kolonner med transaktions-id og vare.",
                "**Gravning pr. gruppe** — kører de første tre igen **uafhængigt inden for hver gruppe**. Dette trin vender hyppigt den slutning om, man drog af den samlede tabel.",
            ]),
            .heading("Tre regler for hele familien"),
            .bullets([
                "**Hvert resultat bærer en »Metode«-blok**: algoritme, parametre, frø, formel. Der findes ingen måde at slå den fra — en tabel med tre tal, der ikke siger, hvor de kommer fra, kan ikke bruges til en beslutning.",
                "**Ingen måling, ingen slutning.** For lille en stikprøve, nul varians, en singulær matrix — GEditor nægter og siger hvorfor, frem for at give et tal, der blot ser rigtigt ud.",
                "**Deterministiske resultater.** Samme data giver samme resultat; hvor tilfældighed er nødvendig, noteres frøet i uddataene.",
            ]),
            .heading("Fra et resultat tilbage til dataene"),
            .paragraph("""
                Hvert panel **mærker tilbage i kildedataene**: klik på en afvigende række, en \
                samvariationscelle eller en associationsregel, og de relevante linjer bliver mærket i \
                tabellen. Sådan går du fra *»noget er underligt«* til *»underligt i præcis disse \
                rækker«*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "At finde afvigende rækker",
        summary: "Fire mål, tre alvorsgrader, og en forklaring på, hvorfor en række er underlig.",
        keywords: ["afviger", "afvigelse", "z-score", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Mål", "Brug når"],
                rows: [
                    ["z-score", "Kolonnen er nogenlunde normalfordelt"],
                    ["IQR", "Kolonnen er skæv med en lang hale — den sikre standard"],
                    ["MAD", "Kolonnen rummer allerede mange afvigere og kræver et robust mål"],
                    ["Mahalanobis", "**Flere kolonner på én gang** — fanger rækker, der er underlige i kombination, ikke i nogen enkelt kolonne"],
                ]
            ),
            .paragraph("""
                Resultaterne farves efter **tre alvorsgrader** frem for én flad farve — ellers kan en \
                let usædvanlig række ikke skelnes fra en vildt usædvanlig.
                """),
            .heading("At forklare hvorfor"),
            .paragraph("""
                For flerkolonnemålet opdeler GEditor hver kolonnes bidrag og laver en sætning som \
                *«afvigende hovedsagelig gennem kombinationen omsætning (50 %) × mængde (50 %)»*.
                """),
            .note("""
                Den procentdel er *af den forklarlige del*, ikke *af afstanden*. Metode-blokken siger \
                det lige under tabellen.
                """),
            .warning("""
                En kolonne, hvis IQR eller MAD er nul, får målet til at **nægte at køre** frem for at \
                dividere med noget lillebitte og give en enorm karakter. For flerkolonnetilfældet: er \
                kovariansmatricen singulær, **siger GEditor, hvilken kolonne der skal fjernes**, i \
                stedet for at bruge en pseudoinvers til at »få det til at virke«.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Samvariationsmatrix",
        summary: "Pearson og Spearman for hvert par, med et punktdiagram ved klik.",
        keywords: ["samvariation", "korrelation", "pearson", "spearman", "varmekort"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Koefficient", "Hvad den måler"],
                rows: [
                    ["Pearson", "Et **lineært** forhold"],
                    ["Spearman", "**Ethvert monotont** forhold, også buede — beregnet på rangtal"],
                ]
            ),
            .paragraph("""
                Klik på en celle i varmekortet for at se det pars punktdiagram med en regressionslinje \
                og R².
                """),
            .heading("Fire detaljer, der ændrer, hvordan man læser det"),
            .bullets([
                "**Lige værdier bruger gennemsnitlige rangtal**, så en ny sortering af tabellen ændrer ikke Spearman-koefficienten.",
                "**Tomme celler håndteres parvis**, og hver celles `n` står lige der i tabellen — `0,93` over 6 rækker betyder ikke det samme som `0,93` over 6.000 rækker.",
                "**En konstant kolonne giver tomt**, ikke 0. Nul betyder *målt, intet forhold fundet*.",
                "**Farveskalaen er blå↔orange**, ikke rød–grøn: 8 % af mænd ser en rød-grøn skala som én grå masse, hvilket får `+0,9` og `−0,9` til at se ens ud.",
            ]),
            .warning("""
                **Samvariation betyder ikke årsag.** Den sætning tegnes **inde i selve diagrammet**, så \
                den rejser med billedet, når du eksporterer det.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Klyngedannelse",
        summary: "k-means og DBSCAN, to måder at vælge k på — og en advarsel om skalering.",
        keywords: ["klynge", "kmeans", "dbscan", "grupper", "silhuet", "albue"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritme", "Brug når"],
                rows: [
                    ["k-means", "Du kender (eller vil prøve) antallet af klynger; klyngerne er klatformede"],
                    ["DBSCAN", "Du kender ikke antallet; klyngerne har vilkårlige former; du vil have støjen skilt fra"],
                ]
            ),
            .heading("Skalering er slået til som standard — og hvorfor"),
            .paragraph("""
                En `omsætning`-kolonne (i millioner) ved siden af en `mængde`-kolonne (i stykker): \
                afstanden mellem to rækker afgøres næsten helt af den største. Det er ikke \
                »suboptimalt« — det er at **besvare et andet spørgsmål**. Den gældende skalering noteres \
                i resultatet.
                """),
            .heading("At vælge antallet af klynger"),
            .bullets([
                "**Silhuet** — jo højere karakter, jo bedre adskilte klynger. På en stor tabel **stikprøver** den (jævnt fordelt, ikke de første 2.000 rækker), og resultatet erklærer sig selv et skøn.",
                "**Albue** — tegner summen af kvadrater inden for klyngerne mod k. Det er en **måde at læse et diagram på**, ikke en optimering: den størrelse falder altid, når k stiger, så der findes intet statistisk »optimalt k«.",
            ]),
            .note("""
                For DBSCAN hjælper **k-afstands**diagrammet med at vælge en radius: kurvens knæ er som \
                regel en fornuftig startværdi.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Prognoser for tidsserier",
        summary: "Opdeling i tendens og sæson, Holt-Winters, og en grundlinje der altid kører ved siden af.",
        keywords: ["prognose", "tidsserie", "sæson", "holt-winters", "tendens"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Vælg en tidskolonne og en værdikolonne. GEditor opdeler serien i **tendens · sæson · \
                rest** og laver så en prognose med Holt-Winters (additiv eller multiplikativ), med 80 % \
                og 95 % intervaller.
                """),
            .heading("Grundlinjen kører altid, og den siger lige ud, hvem der vandt"),
            .paragraph("""
                Ved siden af modellen kører GEditor to naive metoder: *tag den forrige periode* og *tag \
                samme periode sidste sæson*. **Taber** modellen til en grundlinje, står den sætning på \
                **første linje, i en anden farve** — ikke under en tabel med tal.
                """),
            .paragraph("""
                Grunden: prognoseværktøjer har det med at fremstille modellen som en kendsgerning, og \
                brugeren har ingen mulighed for at opdage, at »tag bare sidste måneds tal« ville have \
                været mere præcist.
                """),
            .heading("Tre steder, hvor GEditor nægter eller erklærer sig"),
            .bullets([
                "**Uden to fulde cyklusser falder den tilbage til den naive metode.** At tilpasse sæson til støjen i en enkelt cyklus og gentage den ind i fremtiden giver en meget overbevisende, helt opdigtet prognose.",
                "**MAPE, der møder et nul, siger det**, og er mere end 25 % af perioderne nul, tilbageholder den målet — at springe dem stille over giver et tal beregnet på en systematisk skæv delmængde.",
                "**Konfidensintervallet erklærer sig omtrentligt** og siger, at det udvider sig for langsomt ved lange horisonter.",
            ]),
            .note("""
                Sæsonperioden findes på **første difference**, ikke på den rå serie: en tendens gør \
                hvert efterslæb stærkt samvarierende og drukner sæsontoppen.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Associationsregler",
        summary: "Køber A, køber ofte B — og hvorfor tabellen sorteres efter lift, ikke efter tiltro.",
        keywords: ["apriori", "associationsregler", "indkøbskurv", "lift", "støtte"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("To dataformer tages imod:"),
            .bullets([
                "**Én kurv pr. række** — en kolonne med en liste af varer.",
                "**To kolonner** — transaktions-id og vare, én vare pr. række.",
            ]),
            .table(
                headers: ["Mål", "Betydning"],
                rows: [
                    ["støtte", "Andel af kurve, der indeholder begge sider"],
                    ["tiltro", "Af kurvene med venstre side, hvor stor en andel har højre"],
                    ["**lift**", "Tiltro divideret med højre sides grundrate"],
                    ["løftestang", "Afstanden fra det, uafhængighed ville forudsige"],
                ]
            ),
            .heading("Sorteret efter lift, ikke efter tiltro"),
            .paragraph("""
                Hvis højre side alligevel optræder i 95 % af kurvene, har **hver** regel, der fører til \
                den, omkring 95 % tiltro — mens den slet intet siger. At sortere efter tiltro sætter \
                netop de mest meningsløse regler øverst.
                """),
            .warning("""
                `lift < 1` **markeres i selve rækken**: 80 % tiltro mod noget med en grundrate på 95 % \
                betyder et **omvendt** forhold — et rigtigt tal, der fører til en forkert slutning.
                """),
            .bullets([
                "At købe to kartoner mælk er stadig **én** transaktion, der indeholder mælk: dubletter inde i en kurv fjernes, ellers vokser støtten med mængden.",
                "At sætte støttetærsklen for lavt får kandidatmængden til at eksplodere kombinatorisk; når loftet nås, **standser GEditor og siger, at tabellen er ufuldstændig**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Gravning pr. gruppe",
        summary: "Kør analysen igen uafhængigt pr. gruppe — det trin, der oftest vender en slutning om.",
        keywords: ["gruppér", "pr. gruppe", "simpson", "afdelinger", "sammenlign grupper"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Vælg en tekstkolonne som grupperingsnøgle. Hver gruppe får afvigelser, prognose og \
                samvariation kørt **helt uafhængigt** og bliver så rangordnet efter det kriterium, du \
                vælger.
                """),
            .heading("Hvorfor grupper skal skilles ad, ikke lægges sammen"),
            .paragraph("""
                To afdelinger, den ene omkring 10 og den anden omkring 100. Et afvigerhegn beregnet på \
                den **samlede** tabel lander omkring ±135 — og det fejler i **begge retninger**:
                """),
            .bullets([
                "**Falske negativer**: en værdi på 20, tydeligt afvigende for den lille afdeling, ligger godt inde i det fælles hegn. Jo flere grupper, jo blindere bliver det.",
                "**Falske positiver**: en bredt spredt gruppe får sin normale hale klippet af det fælles hegn, og en stribe helt almindelige rækker bliver markeret.",
            ]),
            .heading("Spalten »samvariationsafvigelse« fanger Simpsons paradoks"),
            .paragraph("""
                Tre grupper, hvor **hver** gruppes to kolonner samvarierer med `−1`, men samlet \
                samvarierer de med `> 0,9`. Enhver, der kun læser den samlede tabel, slutter det \
                **stik modsatte**. Denne spalte peger på præcis de tilfælde.
                """),
            .note("""
                Panelet tilbyder kun **tekstkolonner** som grupperingsnøgler og standser ved 1.000 \
                grupper med en advarsel — for at hindre, at man vælger en ordre-id-kolonne og gør hver \
                række til sin egen gruppe.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Tekstgravning",
        summary: "n-gram og TF-IDF over en tekstkolonne — at finde karakteristiske vendinger.",
        keywords: ["tekstgravning", "n-gram", "tf-idf", "nøgleord", "vendinger"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Kører på én tekstkolonne — varebeskrivelser, kundetilbagemeldinger, notatfelter.
                """),
            .bullets([
                "**n-gram** — de hyppigste vendinger på 1, 2 og 3 ord.",
                "**TF-IDF** — ord, der er **karakteristiske** for hver dokumentgruppe, altså hyppige her og sjældne andetsteds.",
            ]),
            .paragraph("""
                Forskellen: n-gram fortæller dig *»hvad kunderne bliver ved med at nævne«*, TF-IDF \
                fortæller dig *»hvordan denne gruppe adskiller sig fra de andre«*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
