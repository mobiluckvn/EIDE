import Foundation

/// Nederlandse helpinhoud — deel 4: tabelgegevens, opschonen en mining.
extension HelpNL {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Tabelgegevens",
        summary: "Een CSV als tabel bekijken, filteren, sorteren, de structuur nakijken, met SQL bevragen, omzetten.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Een CSV als tabel bekijken",
        summary: "Een miljoen regels schuift nog steeds soepel, de kop blijft staan, en de brontekst blijft ongemoeid.",
        keywords: ["csv", "tabel", "raster", "tsv", "excel", "kolommen"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Wisselen tussen tabel en tekst")]),
            .paragraph("""
                De tabel is **gevirtualiseerd**: alleen zichtbare regels worden gebouwd, zodat een bestand met \
                een miljoen regels schuift als een met honderd.
                """),
            .bullets([
                "**De kopregel blijft plakken** tijdens het schuiven — bij regel 40 000 weet u nog steeds wat de negende kolom is.",
                "Bewerk een cel in de tabel; de wijziging gaat rechtstreeks de brontekst in.",
                "Tabel en tekst zijn **twee blikken op één bestand**, geen twee kopieën.",
                "**⌘C kopieert de geselecteerde regel**, met cellen gescheiden door tabs — plak rechtstreeks in Excel of Numbers en elke cel belandt goed. Cellen met tabs of regelovergangen krijgen aanhalingstekens, zodat de bestemming ze niet in tweeën knipt.",
            ]),
            .note("""
                Het scheidingsteken wordt bij het openen herkend (komma, puntkomma, tab, verticale streep). Is \
                de gok verkeerd, wijzig het dan met `CSV ▸ Scheidingsteken wijzigen…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Werkmappen met meerdere bladen",
        summary: "Elk blad van een .xlsx openen, en ⌘S schrijft terug in het blad dat u bekijkt.",
        keywords: ["excel", "xlsx", "blad", "werkmap"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Open een `.xlsx` en GEditor toont het **eerste blad** als CSV-tabel. `CSV ▸ Blad kiezen…` \
                somt elk blad in het bestand op en opent het gekozen blad in hetzelfde tabblad.
                """),
            .heading("Terugschrijven in het JUISTE blad"),
            .paragraph("""
                `⌘S` schrijft uw wijzigingen in **het blad dat u bekijkt**, niet in het eerste. De overige \
                bladen worden geen byte aangeraakt.
                """),
            .note("""
                Het blad wordt onthouden op **naam**, niet op plaats. Zo leidt het herschikken van bladen in \
                Excel tussen twee sessies het schrijven niet de verkeerde kant op.
                """),
            .warning("""
                Is het geopende blad in Excel **hernoemd of gewist** sinds u het opende, dan **weigert `⌘S` te \
                schrijven** en zegt het. Terugvallen op het eerste blad zou betekenen dat de inhoud van het \
                ene blad over het andere wordt gegoten — het bestand zou toch bewaard worden, toch weer \
                opengaan, en simpelweg de gegevens op de verkeerde plaats hebben.
                """),
            .heading("Van blad wisselen met niet-bewaarde wijzigingen"),
            .paragraph("""
                Van blad wisselen vervangt de hele inhoud van het tabblad, dus als er iets niet bewaard is \
                **vraagt GEditor eerst**. `⌘Z` kan het niet terughalen, want het hele document is verwisseld.
                """),
            .heading("Wat het kost om Excel tot een tabel terug te brengen"),
            .paragraph("""
                Wat overleeft zijn de **waarden** — inclusief formuleresultaten, precies de getallen die Excel \
                toont. Wat niet: lettertypen, kleuren, samengevoegde cellen, ingebedde grafieken en de \
                formules zelf.
                """),
            .paragraph("""
                In ruil krijgt dat blad de hele rest van het product: filteren, sorteren, SQL-bevragingen, de \
                opschoonbank, kwaliteitsbeoordeling, mining, grafieken.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filteren en sorteren in de tabel",
        summary: "Eén filterveld per kolom, dat numerieke vergelijking en typen zonder accenten begrijpt.",
        keywords: ["filter", "sorteren", "kolom", "zoeken in de tabel"],
        blocks: [
            .paragraph("Klik op een kolomkop om te sorteren. Het filterveld eronder aanvaardt:"),
            .table(
                headers: ["Typ in het filter", "Betekenis"],
                rows: [
                    ["`hue`", "Bevat `hue`, **ongevoelig voor accenten** — vindt ook `Huế`"],
                    ["`=Huế`", "Precies `Huế` (nog steeds ongevoelig voor accenten)"],
                    ["`>100`", "Groter dan 100"],
                    ["`>=100`", "100 of meer"],
                    ["`<0`", "Kleiner dan 0"],
                    ["`100..200`", "Tussen 100 en 200"],
                    ["leeg", "Geen filter op deze kolom"],
                ]
            ),
            .paragraph("""
                Meerdere kolommen filteren is een **en**: een regel moet aan alle voldoen. De numerieke \
                vergelijking slaat niet-numerieke cellen over in plaats van ze als nul te behandelen.
                """),
            .note("""
                Filteren is een **manier van kijken**, geen verwijdering. Wis het filter en alle regels komen \
                terug.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "De structuur van de tabel nakijken",
        summary: "Regels met het verkeerde aantal kolommen en cellen van het verkeerde type vinden — dit eerst.",
        keywords: ["toetsen", "nakijken", "aantal kolommen", "verkeerd type", "kapotte gegevens"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Dit is wat u **vóór** al het andere uitvoert op een bestand dat iemand u stuurde. Het \
                beantwoordt twee vragen:
                """),
            .bullets([
                "**Welke regels hebben het verkeerde aantal kolommen?** Meestal een cel met een komma zonder aanhalingstekens — en die zet elke volgende regel scheef.",
                "**Welke cellen hebben een ander type dan de rest van hun kolom?** Bijvoorbeeld een `n/a` in een kolom met getallen.",
            ]),
            .paragraph("De resultaten verschijnen als lijst; klik op er een om naar die regel te springen."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Kolommen wissen",
        summary: "Een of meer kolommen helemaal uit het bestand halen.",
        keywords: ["kolom wissen", "kolom verwijderen"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Kies uit de lijst de kolommen die weg moeten en pas toe. Het is **één** stap terug, hoeveel \
                regels het bestand ook heeft.
                """),
            .warning("""
                Anders dan filteren **bewerkt dit het echte bestand**. Om kolommen alleen te verbergen \
                gebruikt u een SQL-bevraging die de kolommen opsomt die u wilt.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Een CSV bevragen met SQL",
        summary: "Het volledige SQL van DuckDB, rechtstreeks op het geopende bestand — alleen-lezen.",
        keywords: ["sql", "bevraging", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                De geopende tabel heet **`t`**. De motor is **DuckDB**, dus `JOIN`, `DISTINCT`, `HAVING`, \
                `IN`, `LIKE`, `BETWEEN`, vensterfuncties en subbevragingen werken allemaal.
                """),
            .code(language: "sql", caption: "Omzet per provincie, van groot naar klein",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Filteren op datum en op een tekstvoorwaarde",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Het aandeel van elke provincie in het totaal — met een vensterfunctie",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Samenvoegen met een ander bestand op schijf",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Alleen-lezen, en dat is een harde garantie"),
            .bullets([
                "De databank woont **in het geheugen**; het bronbestand wordt alleen gelezen.",
                "Er wordt precies **één instructie** aanvaard, en die **moet een `SELECT` zijn**. Al het andere — ook `COPY … TO 'bestand'`, dat DuckDB heel goed kan gebruiken om naar schijf te schrijven — wordt geblokkeerd voordat het ook maar gegevens bereikt.",
            ]),
            .warning("""
                DuckDB leest **bestanden**, geen geheugen. Heeft het document niet-bewaarde wijzigingen, dan \
                moet GEditor eerst een tijdelijke kopie schrijven voordat hij bevraagt. Bij een heel groot \
                bestand met niet-bewaarde wijzigingen **stopt hij en zegt het**, in plaats van voor één \
                bevraging stilletjes honderden megabytes naar schijf te schrijven.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Draaitabellen en snelle grafieken",
        summary: "Draaien en tekenen rechtstreeks vanuit een bevragingsresultaat.",
        keywords: ["draaitabel", "grafiek", "kruistabel", "samenvatting"],
        blocks: [
            .paragraph("""
                Beide gaan open vanuit de **resultatentabel**: voer een SQL-instructie uit en gebruik dan de \
                knop Draaitabel of Grafiek in het paneel.
                """),
            .heading("Draaitabel"),
            .paragraph("""
                Kies de kolom voor de **rijen**, die voor de **kolommen**, die voor de **waarden** en de \
                samenvatting (som, aantal, gemiddelde, min, max) — zoals de draaitabel van een rekenblad.
                """),
            .heading("Grafieken"),
            .paragraph("""
                Staaf, lijn, taart, spreiding. Getallen in Vietnamese of Europese opmaak, en de grafiek is \
                als PNG of SVG uit te voeren om elders te plakken.
                """),
            .note("""
                Wilt u een grafiek die **met de gegevens meevernieuwt** bij elke herbouw? Dat is het \
                `chart`-blok in een `.greport.md`-rapport.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Een tabel naar een ander formaat omzetten",
        summary: "TSV, JSON, XML, Markdown-tabellen, SQL INSERT-instructies — met voorbeeld.",
        keywords: ["omzetten", "uitvoeren", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Formaat", "Nuttig voor"],
                rows: [
                    ["TSV", "Plakken in een rekenblad zonder zorgen over komma's in cellen"],
                    ["JSON", "Een API, een script of ander gereedschap voeden"],
                    ["XML", "Oude systemen die XML eisen"],
                    ["Markdown-tabel", "Plakken in documentatie, een README, een ticket"],
                    ["SQL INSERT-instructies", "Laden in een databank"],
                ]
            ),
            .paragraph("""
                Het venster **toont de eerste vijf regels vooraf** voordat het nieuwe tabblad wordt gemaakt — \
                vijf regels volstaan om de tabelnaam, de aanhalingstekens en welke kolommen getallen zijn \
                geworden te bevestigen.
                """),
            .note("""
                Het voorbeeld roept **dezelfde functie** aan die de echte uitvoer maakt, beperkt tot vijf \
                regels. Het is geen nabootsing die van het eindresultaat zou kunnen afwijken.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Het scheidingsteken wijzigen",
        summary: "Een bestand omzetten tussen komma, puntkomma, tab en verticale streep.",
        keywords: ["scheidingsteken", "komma", "puntkomma", "tab", "europese csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Bestanden die uit een Vietnamese of Europese Excel komen gebruiken meestal **puntkomma's**, \
                omdat daar de komma het decimaalteken is.
                """),
            .warning("""
                Het scheidingsteken wijzigen **herschrijft het hele bestand**. Cellen die het nieuwe \
                scheidingsteken bevatten krijgen aanhalingstekens — anders breekt de structuur van de tabel.
                """),
            .note("""
                **Als de herkenning fout zat, is dit niet de opdracht die u wilt.** Hier zitten twee \
                verschillende taken in, precies als bij het coderingspaar «opnieuw uitleggen» / «omzetten»:

                • *Het bestand is echt met puntkomma's gescheiden en wij gokten komma* — klik op het segment \
                `CSV · …` in de **statusbalk** en kies het juiste. Er verandert geen byte in het bestand; \
                alleen hoe het gelezen wordt.

                • *Het bestand is echt met komma's gescheiden en u wilt puntkomma's* — gebruik de opdracht op \
                deze pagina. Die herschrijft het bestand.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Opschonen

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Gegevens opschonen — de hele stroom",
        summary: "Van een ruw bestand dat iemand u stuurde tot een bruikbare tabel, en een norm om elke maand te herhalen.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "De opschoonstroom, van begin tot eind",
        summary: "Zes stappen van een onbekend bestand naar een betrouwbare tabel, en een norm voor volgende maand.",
        keywords: ["opschonen", "stroom", "normaliseren", "schone gegevens"],
        blocks: [
            .paragraph("""
                Gegevens opschonen is **zelden eenmalig**. Mensen krijgen elke maand hetzelfde rapportsjabloon, \
                en elke maand moeten dezelfde kolommen op dezelfde manier genormaliseerd worden. Deze stroom is \
                daarvoor gemaakt: u doet het één keer met de hand en herhaalt het daarna met één opdracht.
                """),
            .heading("Zes stappen"),
            .steps([
                "**Kijk eerst naar de structuur.** `CSV ▸ Gegevens nakijken` — welke regels hebben het verkeerde aantal kolommen, welke cellen het verkeerde type. Dit komt eerst omdat één scheve regel elke latere statistiek zinloos maakt.",
                "**Lees het gegevensprofiel.** Per kolom: hoeveel lege cellen, hoeveel verschillende waarden, welk type, waar de uitschieters zitten. Hier begrijpt u het bestand, vóór u iets verandert.",
                "**Open de opschoonbank** (`⇧⌘L`). Hij herkent gemengde datumvormen, Vietnamese getallen door Europese gemengd, zwervende witruimte, ontbrekende waarden. **Voorbeeld vóór→na**, en dan toepassen.",
                "**Pak de vage dubbelen aan** als een kolom met namen of adressen met de hand getypte varianten bevat. Hier beslist u; de machine stelt alleen voor.",
                "**Bewaar het als recept.** De reeks die u net uitvoerde wordt in een JSON-bestand met naam geschreven — dat bestand is uw kennis over deze gegevens.",
                "**Schrijf een set kwaliteitsregels** `.gquality.yaml` en beoordeel. Vanaf nu gaat het bestand van volgende maand door het recept en krijgt een cijfer, en de **poort op de opdrachtregel** geeft een afsluitcode ongelijk aan nul wanneer het niet slaagt.",
            ]),
            .heading("Waarom deze volgorde"),
            .bullets([
                "Structuur **vóór** profiel: statistieken op een scheve tabel zijn statistieken over een andere kolom.",
                "Profiel **vóór** opschonen: u moet «2 % leeg» weten voordat u besluit te vullen of weg te gooien.",
                "Vage dubbelen **na** het normaliseren: `CÔNG TY  A` en `Công ty A` blijken pas één te zijn als witruimte en hoofdletters geregeld zijn.",
                "Recept **vóór** de regelset: het recept herstelt, de regels oordelen — een niet-herstelde tabel beoordelen levert alleen een laag getal op dat u toch al verwachtte.",
            ]),
            .heading("Na de eerste keer is elke maand één opdracht"),
            .code(language: "bash", caption: "Opschonen en dan beoordelen, met een afsluitcode voor de CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Afsluitcode **0** betekent geslaagd, **1** niet geslaagd, **2** uitvoerfout. \
                `--record-history` voegt een regel toe aan het geschiedenisbestand zodat de volgende ronde de \
                afwijking kan vergelijken.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Gegevensprofiel",
        summary: "Eén beschrijving per kolom: type, lege plekken, verschillende waarden, verdeling.",
        keywords: ["profiel", "kolomstatistiek", "nul", "verschillend"],
        blocks: [
            .paragraph("""
                Een profiel **beschrijft**; het oordeelt niet. Het zegt *«deze kolom is 2 % leeg»*; of 2 % \
                aanvaardbaar is hoort bij de set kwaliteitsregels.
                """),
            .table(
                headers: ["Maat", "Hoe u die leest"],
                rows: [
                    ["Type", "Afgeleid uit de gegevens zelf, niet uit de kolomnaam"],
                    ["Lege cellen", "Aantal en aandeel ontbrekende waarden"],
                    ["Verschillende waarden", "1 betekent een constante kolom; gelijk aan het aantal regels betekent een sleutelkolom"],
                    ["Min · max · gemiddelde", "Alleen numerieke kolommen"],
                    ["Meest voorkomende waarden", "Meteen een foutcode of een te vaak gebruikte standaardwaarde opmerken"],
                ]
            ),
            .warning("""
                Het tellen van verschillende waarden heeft een drempel. Daarboven is het getoonde getal een \
                **ondergrens**, en het profiel **zegt dat het een schatting is** in plaats van het onder de \
                precieze tellingen te mengen.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "De opschoonbank voor gegevens",
        summary: "Zeven normalisaties, altijd met voorbeeld, altijd één stap terug, nooit gokken.",
        keywords: ["opschonen", "normaliseren", "datums", "getallen", "vullen"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "De opschoonbank openen")]),
            .table(
                headers: ["Bewerking", "Wat ze doet"],
                rows: [
                    ["Datums normaliseren", "Elke datumvorm in de kolom naar één vorm brengen"],
                    ["Getallen normaliseren", "Het decimaalteken en het duizendtalteken regelen"],
                    ["Witruimte afknippen", "Aan beide uiteinden weghalen; desgewenst ook de reeksen binnenin samenpersen"],
                    ["Hoofdletters wijzigen", "De hoofdlettergebruik van de kolom eenduidig maken"],
                    ["Met een vaste waarde vullen", "Lege cellen vervangen door een waarde die u typt"],
                    ["Vanaf een buur vullen", "De waarde van de regel erboven of eronder nemen"],
                    ["Regels met lege cellen wissen", "Regels weggooien waaraan gegevens ontbreken"],
                ]
            ),
            .heading("Drie garanties van de hele bank"),
            .bullets([
                "**Altijd met voorbeeld.** Een tabel vóór→na, met het aantal cellen dat zal veranderen.",
                "**Eén stap terug** voor de hele ronde, ook als ze een miljoen cellen raakt.",
                "**Een verslag achteraf**: hoeveel cellen veranderden, en welke niet gelezen konden worden.",
            ]),
            .heading("Het beginsel: nooit gokken"),
            .paragraph("""
                Een cel die niet met zekerheid te lezen is wordt **gemarkeerd en met rust gelaten**. Neem \
                `03/04/2026` in een kolom die beide afspraken mengt — is dat 3 april of 4 maart? GEditor vraagt \
                u de dag/maand-volgorde in plaats van voor u te kiezen.
                """),
            .warning("""
                Een datumkolom verkeerd normaliseren is de soort beschadiging die **bijna niet te ontdekken \
                is**: de getallen zien er nog steeds goed uit, ze zijn alleen een andere datum. Daarom weigert \
                deze bank liever dan af te leiden.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Vage dubbelen",
        summary: "Met de hand getypte varianten van dezelfde naam vinden — en ze nooit automatisch samenvoegen.",
        keywords: ["vaag", "dubbelen", "samenvoegen", "varianten", "typfouten"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — drie manieren om \
                dezelfde klant te schrijven. Gewoon dubbelen verwijderen ziet ze niet als dezelfde.
                """),
            .steps([
                "Kies de kolom die u wilt bekijken en een gelijkenisdrempel.",
                "GEditor groepeert nabije waarden in **trossen** en toont de vergelijkingsvorm.",
                "Voor **elke tros** kiest u welke waarde blijft — of u slaat die tros over.",
                "Toepassen. Eén stap terug.",
            ]),
            .warning("""
                Dit gereedschap **voegt nooit uit zichzelf samen**, en er is geen knop «alles samenvoegen». Twee \
                tekenreeksen die voor 92 % gelijk zijn, kunnen een typfout zijn, of twee werkelijk \
                verschillende bedrijven die één woord schelen — een machine kan dat niet uitmaken.
                """),
            .paragraph("""
                Twee records verkeerd samenvoegen is **stil** gegevensverlies: geen cel wordt leeg, geen regel \
                wordt rood, twee entiteiten worden gewoon één en niemand merkt het tot de boeken worden \
                afgestemd.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Opschoonrecepten",
        summary: "De reeks als JSON-bestand vastleggen en op de gegevens van volgende maand herhalen.",
        keywords: ["recept", "herhalen", "automatiseren", "maandelijks", "partij"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Bewaar na het opschonen de stappen als **recept**. Het is een voor mensen leesbaar \
                JSON-bestand dat u naast de gegevens kunt bewaren, naar een collega kunt sturen en in een \
                repository kunt zetten zodat wijzigingen worden bijgehouden.
                """),
            .code(language: "json", caption: "sales-standard.json — ingekort",
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
                Elke stap kan **uitgezet** worden (`enabled`), zodat één recept meerdere bijna gelijke soorten \
                bestanden kan bedienen.
                """),
            .heading("Herhalen"),
            .bullets([
                "In de toepassing: `CSV ▸ Opschoonrecept uitvoeren…`",
                "Vanaf de shell, over een hele map: zie de pagina over de opdrachtregel.",
            ]),
            .code(language: "bash", caption: "Een droge oefening voordat er iets geschreven wordt — geen bestand wordt aangeraakt",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Standaard wordt het resultaat naar een nieuw bestand naast het origineel geschreven \
                (`sales-clean.csv`). Het origineel overschrijven moet uitdrukkelijk met `--overwrite` gevraagd \
                worden.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Kwaliteitsbeoordeling van gegevens",
        summary: "Zes dimensies, één cijfer van 0 tot 100, en elke formule afgedrukt zodat u ze kunt narekenen.",
        keywords: ["kwaliteit", "cijfer", "dqr", "zes dimensies"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Het verschilt op één wezenlijk punt van het gegevensprofiel: een profiel **beschrijft**, een \
                cijfer **oordeelt tegen de norm die u hebt verklaard** in een `.gquality.yaml`-bestand.
                """),
            .table(
                headers: ["Dimensie", "Wat ze meet"],
                rows: [
                    ["Volledigheid", "Aandeel gevulde cellen volgens de `not_null`-regels"],
                    ["Geldigheid", "Aandeel geslaagde regels voor vorm, type, bereik en regex"],
                    ["Uniciteit", "Tegen de sleutel die in `uniqueness_key` is verklaard"],
                    ["Samenhang", "Regels over kolommen en over bestanden heen"],
                    ["Nauwkeurigheid (geschat)", "Uitschieters in de numerieke kolommen die u aanwijst"],
                    ["Tijdigheid", "Hoe oud de gegevens zijn tegen de `freshness`-drempel"],
                ]
            ),
            .heading("Drie garanties over het cijfer"),
            .bullets([
                "**De formule staat afgedrukt in het resultaat** — u kunt haar met de hand narekenen.",
                "**Voorspelbaar**: dezelfde gegevens en dezelfde regels geven hetzelfde cijfer. Alleen *Tijdigheid* hangt van het moment af, dus `now` is een **parameter** en wordt in het resultaat vastgelegd.",
                "**Een dimensie die niet te beoordelen is blijft leeg met een reden**, nooit stilletjes met een 100.",
            ]),
            .warning("""
                Die laatste garantie telt. Een tabel zonder verklaarde `uniqueness_key` die een 100 voor \
                «uniciteit» krijgt, is een cijfer dat liegt — en het liegt in de vleiende richting, de \
                gevaarlijke.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Syntaxis van `.gquality.yaml`",
        summary: "Elke sleutel van het regelbestand, met één volledige regelset die draait.",
        keywords: ["gquality", "yaml", "regels", "syntaxis", "gegevensnorm"],
        blocks: [
            .paragraph("""
                Het bestand woont **naast de gegevens**, niet in de toepassing: een gegevensnorm moet \
                nakijkbaar zijn, en nakijken is wat mensen met normen doen.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — een volledige regelset",
                  source: """
                    schemaVersion: 1

                    # Gewichten van de zes dimensies. Een ontbrekende dimensie weegt 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # De sleutel die een regel uniek maakt. Zonder die sleutel KAN de dimensie
                    # «Uniciteit» niet worden beoordeeld — en het totaal zegt dat.
                    uniqueness_key: [ma_don]

                    # Numerieke kolommen die op uitschieters worden bekeken voor «Nauwkeurigheid (geschat)».
                    accuracy_columns: [doanh_thu, so_luong]

                    # De dimensie «Tijdigheid».
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Waarschuwen wanneer deze ronde daalt ten opzichte van de vorige.
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
                        max_null_pct: 2          # 2 % leeg is toegestaan
                      # Regel over kolommen heen: `col` is niet nodig
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Regel over bestanden heen: de waarde moet in een ander bestand bestaan
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("De regelsoorten"),
            .table(
                headers: ["Sleutel", "Betekenis", "Dimensie"],
                rows: [
                    ["`not_null: true`", "De cel moet gevuld zijn; `max_null_pct` versoepelt dat", "Volledigheid"],
                    ["`unique: true`", "Geen herhaalde waarden in de kolom", "Uniciteit"],
                    ["`dtype: int\\|float\\|date\\|text`", "Juist type", "Geldigheid"],
                    ["`range: { min:, max: }`", "Binnen een numeriek bereik", "Geldigheid"],
                    ["`length: { min:, max: }`", "Lengte van de tekenreeks", "Geldigheid"],
                    ["`regex: \"…\"`", "Past op een reguliere uitdrukking", "Geldigheid"],
                    ["`in_set: [ … ]`", "Een uit een gegeven lijst", "Geldigheid"],
                    ["`date_format: \"…\"`", "Juiste datumvorm", "Geldigheid"],
                    ["`compare: { a:, op:, b: }`", "Twee kolommen vergelijken; `op` is `<` `<=` `=` `>=` `>` `<>`", "Samenhang"],
                    ["`foreign_key: { file:, column: }`", "De waarde moet in een ander bestand bestaan", "Samenhang"],
                    ["`severity: error\\|warn`", "Ernst van de regel; standaard `error`", "—"],
                ]
            ),
            .warning("""
                Schrijft u een regelsleutel verkeerd, dan wordt het bestand **met een melding geweigerd**, in \
                plaats van die regel stilletjes over te slaan. Stilletjes overslaan betekent dat u gelooft dat \
                de gegevens getoetst zijn aan een regel die nooit gedraaid heeft.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Een kwaliteitspoort in de CI",
        summary: "Gebrekkige gegevens in de keten tegenhouden, met afsluitcodes.",
        keywords: ["ci", "poort", "fail-under", "afsluitcode", "geschiedenis", "afwijking"],
        blocks: [
            .code(language: "bash", caption: "Beoordelen en een afsluitcode teruggeven",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Optie", "Betekenis"],
                rows: [
                    ["`--quality <bestand.yaml>`", "De regelset waartegen wordt beoordeeld"],
                    ["`--fail-under <0…100>`", "Onder dit cijfer is het NIET GESLAAGD"],
                    ["`--json <bestand\\|->`", "Machineleesbaar resultaat; `-` schrijft naar de standaarduitvoer"],
                    ["`--record-history`", "Voegt een regel toe aan `sales-standard.history.jsonl`"],
                    ["`--now <JJJJ-MM-DD>`", "Legt de peildatum voor *Tijdigheid* vast"],
                    ["`--recipe <bestand.json>`", "Vóór het beoordelen **in het geheugen** opschonen, zonder bestand te schrijven"],
                ]
            ),
            .table(
                headers: ["Afsluitcode", "Betekenis"],
                rows: [["`0`", "Geslaagd"], ["`1`", "Niet geslaagd"], ["`2`", "Uitvoerfout"]]
            ),
            .heading("Waarom de CI `--now` zou moeten meegeven"),
            .paragraph("""
                Zonder dat vergelijkt *Tijdigheid* de gegevens met het moment van uitvoeren — zodat hetzelfde \
                bestand naarmate de dagen verstrijken punten verliest, en op een ochtend de keten rood wordt \
                zonder dat iemand iets heeft veranderd.
                """),
            .heading("Afwijking volgen"),
            .paragraph("""
                Met `--record-history` voegt elke ronde een regel toe aan een JSONL-geschiedenisbestand. De \
                volgende keer vergelijken de drempels in het `drift:`-blok met de meest recente ronde en \
                waarschuwen wanneer de daling te groot is.
                """),
            .note("""
                Elke afwijkingsdrempel staat **standaard uit**, behalve `warn_on_new_failure`. Een \
                waarschuwing die van huis uit aanstaat met een getal dat de toepassing voor u koos, zou bij \
                iedereen al bij de tweede ronde afgaan — en wat op dag één «wolf» roept, wordt op dag drie \
                genegeerd.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Mining

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Datamining — de hele stroom",
        summary: "Afwijkingen, correlatie, trossen, voorspelling, associatieregels — en hoe u ze leest.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "De miningstroom, van begin tot eind",
        summary: "Zes stuks gereedschap, de volgorde waarin u ze gebruikt, en één regel: geen meting, geen conclusie.",
        keywords: ["mining", "analyse", "stroom", "statistiek"],
        blocks: [
            .warning("""
                **Eerst opschonen, dan minen.** Een niet-genormaliseerde datumkolom levert verkeerde \
                voorspellingen; een numerieke kolom die Europese duizendtaltekens mengt levert spookuitschieters. \
                Elk stuk gereedschap hieronder gaat ervan uit dat de tabel schoon is.
                """),
            .heading("De volgorde"),
            .steps([
                "**Afwijkingen zoeken** — beantwoordt *«is er een rare regel?»*. Het goedkoopst, en vaak meteen nuttig.",
                "**Correlatiematrix** — beantwoordt *«welke kolom beweegt met welke mee?»*. Ze stuurt alles wat erna komt.",
                "**Trossen** — beantwoordt *«hoeveel natuurlijke groepen zitten hierin?»*.",
                "**Voorspelling** — alleen met een tijdkolom en ten minste **twee volledige cycli**.",
                "**Associatieregels** — alleen voor gegevens in mandvorm: één transactie per regel, of twee kolommen met transactienummer en artikel.",
                "**Mining per groep** — voert de eerste drie **onafhankelijk binnen elke groep** opnieuw uit. Deze stap keert vaak de conclusie om die uit de samengevoegde tabel werd getrokken.",
            ]),
            .heading("Drie regels voor de hele familie"),
            .bullets([
                "**Elk resultaat draagt een «Methode»-blok**: algoritme, parameters, zaad, formule. Het is niet uit te zetten — een tabel met drie getallen die niet zegt waar ze vandaan komen, kan geen besluit dragen.",
                "**Geen meting, geen conclusie.** Te kleine steekproef, geen spreiding, enkelvoudige matrix — GEditor weigert en zegt waarom, in plaats van een getal terug te geven dat er alleen maar juist uitziet.",
                "**Voorspelbare resultaten.** Dezelfde gegevens geven hetzelfde resultaat; waar toeval nodig is, staat het zaad in de uitvoer.",
            ]),
            .heading("Van het resultaat terug naar de gegevens"),
            .paragraph("""
                Elk paneel **markeert terug in de brongegevens**: klik op een afwijkende regel, op een cel van \
                de correlatie of op een associatieregel en de betrokken regels worden in de tabel gemarkeerd. Zo \
                gaat u van *«er is iets vreemds»* naar *«vreemd precies in deze regels»*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Afwijkende regels vinden",
        summary: "Vier maten, drie ernstniveaus, en een uitleg waarom een regel vreemd is.",
        keywords: ["uitschieter", "afwijking", "z-score", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Maat", "Wanneer te gebruiken"],
                rows: [
                    ["z-score", "De kolom is ongeveer normaal verdeeld"],
                    ["IQR", "De kolom is scheef met een lange staart — de veilige standaardkeuze"],
                    ["MAD", "De kolom bevat al veel uitschieters en heeft een robuuste maat nodig"],
                    ["Mahalanobis", "**Meerdere kolommen tegelijk** — vangt regels die in de combinatie vreemd zijn, niet in één enkele kolom"],
                ]
            ),
            .paragraph("""
                De resultaten worden op **drie ernstniveaus** gekleurd in plaats van in één vlakke kleur — \
                anders zou een licht ongewone regel niet te onderscheiden zijn van een uitzinnig ongewone.
                """),
            .heading("Het waarom uitleggen"),
            .paragraph("""
                Voor de meerkolomsmaat ontleedt GEditor de bijdrage van elke kolom en levert een zin als \
                *«afwijkend vooral door de combinatie omzet (50 %) × aantal (50 %)»*.
                """),
            .note("""
                Dat percentage gaat over het *verklaarbare deel*, niet over de *afstand*. Het Methodeblok zegt \
                dat vlak onder de tabel.
                """),
            .warning("""
                Een kolom waarvan de IQR of MAD nul is, laat de maat **weigeren te draaien**, in plaats van door \
                iets minuscuuls te delen en een enorme score te leveren. Is in het meerkolomsgeval de \
                covariantiematrix enkelvoudig, dan **zegt GEditor welke kolom eruit moet** in plaats van een \
                pseudo-inverse te gebruiken om «het te laten werken».
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Correlatiematrix",
        summary: "Pearson en Spearman voor elk paar, met een spreidingsdiagram bij een klik.",
        keywords: ["correlatie", "pearson", "spearman", "warmtekaart", "spreiding"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Coëfficiënt", "Wat ze meet"],
                rows: [
                    ["Pearson", "Een **lineair** verband"],
                    ["Spearman", "**Elk monotoon** verband, ook gebogen — berekend op rangen"],
                ]
            ),
            .paragraph("""
                Klik op een cel in de warmtekaart om het spreidingsdiagram van dat paar te zien, met \
                regressielijn en R².
                """),
            .heading("Vier details die de lezing veranderen"),
            .bullets([
                "**Gelijke waarden krijgen gemiddelde rangen**, dus de tabel opnieuw sorteren verandert de Spearman-coëfficiënt niet.",
                "**Lege cellen worden per paar behandeld**, en de `n` van elke cel staat gewoon in de tabel — `0,93` over 6 regels betekent niet wat `0,93` over 6000 regels betekent.",
                "**Een constante kolom levert leeg op**, geen 0. Nul betekent *gemeten, geen verband gevonden*.",
                "**De kleurschaal is blauw↔oranje**, geen rood-groen: 8 % van de mannen ziet een rood-groene schaal als één grijze massa, waardoor `+0,9` en `−0,9` er hetzelfde uitzien.",
            ]),
            .warning("""
                **Correlatie betekent geen oorzakelijk verband.** Die zin wordt **in de grafiek zelf** \
                getekend, zodat hij met de afbeelding meereist wanneer u die uitvoert.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Trosvorming",
        summary: "k-middelen en DBSCAN, twee manieren om k te kiezen — en een waarschuwing over schaling.",
        keywords: ["tros", "cluster", "kmeans", "dbscan", "silhouet", "elleboog"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritme", "Wanneer te gebruiken"],
                rows: [
                    ["k-middelen", "U kent (of wilt proberen) het aantal trossen; de trossen zijn vlekvormig"],
                    ["DBSCAN", "U kent het aantal niet; de trossen hebben willekeurige vormen; u wilt ruis afscheiden"],
                ]
            ),
            .heading("Schaling staat standaard aan — en waarom"),
            .paragraph("""
                Een kolom `omzet` (in miljoenen) naast een kolom `aantal` (in stuks): de afstand tussen twee \
                regels wordt bijna volledig door de grootste bepaald. Dat is niet «suboptimaal» — het is **een \
                andere vraag beantwoorden**. De geldende schaling wordt in het resultaat vastgelegd.
                """),
            .heading("Het aantal trossen kiezen"),
            .bullets([
                "**Silhouet** — hoe hoger de score, hoe beter de trossen gescheiden zijn. Op een grote tabel **neemt hij een steekproef** (gelijkmatig verspreid, niet de eerste 2000 regels), en het resultaat verklaart zichzelf een schatting.",
                "**Elleboog** — tekent de kwadratensom binnen de tros tegen k. Dat is een **manier om een grafiek te lezen**, geen optimalisatie: die grootheid daalt altijd als k stijgt, dus statistisch bestaat er geen «optimale k».",
            ]),
            .note("""
                Voor DBSCAN helpt de grafiek van de **k-afstanden** bij het kiezen van een straal: de knie van \
                de kromme is meestal een verstandige startwaarde.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Voorspellen van tijdreeksen",
        summary: "Ontleding in trend en seizoen, Holt-Winters, en een vergelijkingspunt dat altijd meedraait.",
        keywords: ["voorspelling", "tijdreeks", "seizoen", "holt-winters", "trend"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Kies een tijdkolom en een waardekolom. GEditor ontleedt de reeks in **trend · seizoen · rest** \
                en voorspelt dan met Holt-Winters (optellend of vermenigvuldigend), met intervallen van 80 % en \
                95 %.
                """),
            .heading("Het vergelijkingspunt draait altijd mee, en zegt ronduit wie won"),
            .paragraph("""
                Naast het model voert GEditor twee naïeve methoden uit: *neem de vorige periode* en *neem \
                dezelfde periode van vorig seizoen*. **Verliest** het model van een vergelijkingspunt, dan \
                verschijnt die zin op de **eerste regel, in een andere kleur** — en niet onder een tabel met \
                getallen.
                """),
            .paragraph("""
                De reden: voorspellingsgereedschap neigt ertoe het model als feit te tonen, en de gebruiker \
                heeft geen manier om te weten te komen dat «gewoon het cijfer van vorige maand nemen» \
                nauwkeuriger zou zijn geweest.
                """),
            .heading("Drie plekken waar GEditor weigert, of zichzelf verklaart"),
            .bullets([
                "**Zonder twee volledige cycli valt hij terug op de naïeve methode.** Seizoen aanpassen aan de ruis van één cyclus en dat naar de toekomst herhalen levert een zeer overtuigende, volledig verzonnen voorspelling op.",
                "**Loopt de MAPE tegen een nul aan, dan zegt hij dat**, en zijn meer dan 25 % van de perioden nul, dan houdt hij de maat achter — ze stilletjes overslaan levert een getal dat op een stelselmatig vertekende deelverzameling is berekend.",
                "**Het betrouwbaarheidsinterval verklaart zichzelf benaderend**, en zegt dat het bij lange horizonten te traag breder wordt.",
            ]),
            .note("""
                De seizoenperiode wordt op het **eerste verschil** herkend, niet op de ruwe reeks: een trend \
                maakt elke vertraging sterk gecorreleerd en verdrinkt de seizoenspiek.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Associatieregels",
        summary: "Koopt A, koopt vaak ook B — en waarom de tabel op lift is gesorteerd en niet op vertrouwen.",
        keywords: ["apriori", "associatieregels", "mand", "lift", "steun"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Er worden twee gegevensvormen aanvaard:"),
            .bullets([
                "**Eén mand per regel** — een kolom met een lijst artikelen.",
                "**Twee kolommen** — transactienummer en artikel, één artikel per regel.",
            ]),
            .table(
                headers: ["Maat", "Betekenis"],
                rows: [
                    ["steun", "Aandeel manden dat beide kanten bevat"],
                    ["vertrouwen", "Van de manden met de linkerkant, welk aandeel de rechterkant heeft"],
                    ["**lift**", "Het vertrouwen gedeeld door het basispercentage van de rechterkant"],
                    ["leverage", "De afstand tot wat onafhankelijkheid zou voorspellen"],
                ]
            ),
            .heading("Op lift gesorteerd, niet op vertrouwen"),
            .paragraph("""
                Komt de rechterkant sowieso in 95 % van de manden voor, dan heeft **elke** regel die ernaartoe \
                leidt ongeveer 95 % vertrouwen — en zegt daarbij helemaal niets. Op vertrouwen sorteren zet \
                juist de meest betekenisloze regels bovenaan.
                """),
            .warning("""
                `lift < 1` wordt **in de regel zelf gemarkeerd**: 80 % vertrouwen naar iets met een \
                basispercentage van 95 % betekent een **omgekeerd** verband — een juist getal dat naar een \
                verkeerde conclusie leidt.
                """),
            .bullets([
                "Twee pakken melk kopen blijft **één** transactie met melk: dubbelen binnen een mand worden weggegooid, anders zwelt de steun mee met het aantal.",
                "De steundrempel te laag zetten laat de verzameling kandidaten combinatorisch ontploffen; bij het bereiken van het plafond **stopt GEditor en verklaart de tabel onvolledig**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Minen per groep",
        summary: "De analyse per groep onafhankelijk herhalen — de stap die het vaakst een conclusie omkeert.",
        keywords: ["per groep", "simpson", "filialen", "groepen vergelijken"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Kies een tekstkolom als groeperingssleutel. Elke groep krijgt afwijkingen, voorspelling en \
                correlatie **volstrekt onafhankelijk** uitgevoerd, en wordt dan gerangschikt naar het criterium \
                dat u kiest.
                """),
            .heading("Waarom groepen gescheiden moeten blijven en niet samengevoegd"),
            .paragraph("""
                Twee filialen, één rond 10 en één rond 100. Een uitschietergrens die op de **samengevoegde** \
                tabel is berekend, komt rond ±135 uit — en faalt **in beide richtingen**:
                """),
            .bullets([
                "**Vals negatief**: een waarde van 20, voor het kleine filiaal duidelijk afwijkend, ligt ruim binnen de gedeelde grens. Hoe meer groepen, hoe blinder ze wordt.",
                "**Vals positief**: bij een sterk gespreide groep snijdt de gedeelde grens de normale staart af, en wordt een menigte gewone regels gemarkeerd.",
            ]),
            .heading("De kolom «correlatieafwijking» vangt de paradox van Simpson"),
            .paragraph("""
                Drie groepen waarin **elke** groep haar twee kolommen op `−1` correleert, en toch samengevoegd \
                op `> 0,9` correleren. Wie alleen de samengevoegde tabel leest, besluit **precies het \
                tegenovergestelde**. Deze kolom wijst juist die gevallen aan.
                """),
            .note("""
                Het paneel biedt alleen **tekstkolommen** als groeperingssleutel aan en stopt bij 1000 groepen \
                met een waarschuwing — om te voorkomen dat iemand een kolom met bestelnummers kiest en elke \
                regel een eigen groep wordt.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Tekstmining",
        summary: "n-grammen en TF-IDF over een tekstkolom — kenmerkende uitdrukkingen vinden.",
        keywords: ["tekstmining", "n-gram", "tf-idf", "trefwoorden", "uitdrukkingen"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Draait op één tekstkolom — productbeschrijvingen, klantreacties, notitievelden.
                """),
            .bullets([
                "**n-grammen** — de meest voorkomende uitdrukkingen van 1, 2 en 3 woorden.",
                "**TF-IDF** — woorden die **kenmerkend** zijn voor elke documentgroep, dus hier vaak en elders zeldzaam.",
            ]),
            .paragraph("""
                Het verschil: n-grammen vertellen u *«wat klanten steeds noemen»*, TF-IDF vertelt u *«waarin \
                deze groep van de andere verschilt»*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
