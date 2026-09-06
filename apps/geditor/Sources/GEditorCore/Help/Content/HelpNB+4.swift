import Foundation

/// Norsk hjelpeinnhold (bokmål) — del 4: tabelldata, datarydding og datagraving.
extension HelpNB {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Tabelldata",
        summary: "Se CSV som tabell, filtrer, sorter, kontroller oppbygning, spør med SQL, konverter.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Å se CSV som tabell",
        summary: "En million rader ruller fortsatt jevnt, overskriftene blir stående, og kildeteksten røres ikke.",
        keywords: ["csv", "tabell", "rutenett", "tsv", "excel", "kolonner"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Veksle mellom tabell og tekst")]),
            .paragraph("""
                Tabellen er **virtualisert**: bare synlige rader bygges, så en fil med en million rader \
                ruller som en med hundre.
                """),
            .bullets([
                "**Overskriftsraden blir stående** under rulling — ved rad 40 000 vet du fortsatt hva den niende kolonnen er.",
                "Rediger en celle i tabellen; endringen går rett inn i kildeteksten.",
                "Tabell og tekst er **to visninger av én fil**, ikke to kopier.",
                "**⌘C kopierer den markerte raden**, celler skilt med TAB — lim rett inn i Excel eller Numbers, og hver celle lander riktig. Celler med TAB eller linjeskift settes i anførselstegn, så mottakeren ikke deler dem i to.",
            ]),
            .note("""
                Skilletegnet gjenkjennes ved åpning (komma, semikolon, TAB, loddrett strek). Er \
                gjetningen gal, endrer du det med `CSV ▸ Endre skilletegn…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Regneark med flere ark",
        summary: "Åpne et hvilket som helst ark i en .xlsx, og ⌘S skriver tilbake til arket du ser på.",
        keywords: ["excel", "xlsx", "ark", "arbeidsbok", "flere ark"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Åpne en `.xlsx`, og GEditor viser det **første arket** som et CSV-rutenett. `CSV ▸ Velg \
                ark…` lister hvert ark i filen og åpner det du velger, i samme fane.
                """),
            .heading("Å skrive tilbake til RIKTIG ark"),
            .paragraph("""
                `⌘S` skriver endringene dine inn i **arket du ser på**, ikke det første. De andre \
                arkene røres ikke med en eneste byte.
                """),
            .note("""
                Arket huskes ved **navn**, ikke ved plassering. Slik fører ikke omrokering av arkene i \
                Excel mellom to økter skrivingen på villspor.
                """),
            .warning("""
                Er det åpne arket blitt **gitt nytt navn eller slettet** i Excel siden du åpnet det, \
                **nekter `⌘S` å skrive** og sier det. Å falle tilbake til det første arket ville bety å \
                helle ett arks innhold over et annet — filen ville fortsatt lagres, fortsatt åpnes \
                igjen, og bare ha dataene på feil sted.
                """),
            .heading("Å bytte ark med ulagrede endringer"),
            .paragraph("""
                Å bytte ark erstatter hele fanens innhold, så hvis noe er ulagret, **spør GEditor \
                først**. `⌘Z` kan ikke hente det tilbake, for hele dokumentet ble byttet ut.
                """),
            .heading("Hva det koster å bringe Excel ned til et rutenett"),
            .paragraph("""
                Det som overlever, er **verdier** — også formelresultater, nøyaktig de tallene Excel \
                viser. Det som ikke gjør det: skrifter, farger, sammenslåtte celler, innebygde \
                diagrammer og selve formlene.
                """),
            .paragraph("""
                Til gjengjeld får det arket hele resten av produktet: filtrering, sortering, \
                SQL-spørringer, ryddebenken, kvalitetsvurdering, graving, diagrammer.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Å filtrere og sortere i tabellen",
        summary: "Et filterfelt per kolonne, som forstår tallsammenligning og skrift uten aksenter.",
        keywords: ["filter", "sorter", "kolonne", "søk i tabell"],
        blocks: [
            .paragraph("Klikk på en kolonneoverskrift for å sortere. Filterfeltet under den tar imot:"),
            .table(
                headers: ["Skriv i filteret", "Betydning"],
                rows: [
                    ["`hue`", "Inneholder `hue`, **aksentufølsomt** — finner også `Huế`"],
                    ["`=Huế`", "Nøyaktig `Huế` (fortsatt aksentufølsomt)"],
                    ["`>100`", "Større enn 100"],
                    ["`>=100`", "100 eller mer"],
                    ["`<0`", "Mindre enn 0"],
                    ["`100..200`", "Mellom 100 og 200"],
                    ["tomt", "Ikke noe filter på denne kolonnen"],
                ]
            ),
            .paragraph("""
                Å filtrere flere kolonner er et **og**: en rad må oppfylle dem alle. Tallsammenligning \
                hopper over ikke-numeriske celler i stedet for å behandle dem som null.
                """),
            .note("""
                Filtrering er en **måte å se på**, ikke en sletting. Tøm filteret, og hver rad kommer \
                tilbake.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Å kontrollere tabellens oppbygning",
        summary: "Finn rader med feil kolonneantall og celler av feil type — gjør dette først.",
        keywords: ["kontroller", "kolonneantall", "feil type", "ødelagte data"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Dette er det man kjører **før** alt annet på en fil noen har sendt. Det svarer på to \
                spørsmål:
                """),
            .bullets([
                "**Hvilke rader har feil kolonneantall?** Som regel en celle med et komma som ikke ble satt i anførselstegn — og den forskyver hver rad etter seg.",
                "**Hvilke celler har en type ulik resten av kolonnen sin?** For eksempel `n/a` i en kolonne med tall.",
            ]),
            .paragraph("Resultatene vises som en liste; klikk på ett for å hoppe til den raden."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Å slette kolonner",
        summary: "Fjern én eller flere kolonner helt fra filen.",
        keywords: ["slett kolonne", "fjern kolonne"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Velg kolonnene som skal fjernes, fra listen og bruk. Det er **ett** angretrinn uansett \
                hvor mange rader filen har.
                """),
            .warning("""
                I motsetning til filtrering **redigerer dette den virkelige filen**. Vil du bare skjule \
                kolonner, bruk en SQL-spørring som nevner kolonnene du vil ha.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Å spørre en CSV med SQL",
        summary: "DuckDBs fulle SQL, kjørt direkte mot den åpne filen — skrivebeskyttet.",
        keywords: ["sql", "spørring", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Den åpne tabellen heter **`t`**. Motoren er **DuckDB**, så `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, vindusfunksjoner og delspørringer virker alle.
                """),
            .code(language: "sql", caption: "Omsetning per provins, størst først",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Å filtrere etter dato og etter en tekstbetingelse",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Hver provins' andel av det hele — med en vindusfunksjon",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Å koble mot en annen fil på disken",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Skrivebeskyttet, og det er en hard garanti"),
            .bullets([
                "Databasen bor **i minnet**; kildefilen blir bare lest.",
                "Nøyaktig **én setning** tas imot, og den **må være en `SELECT`**. Alt annet — også `COPY … TO 'file'`, som DuckDB utmerket kan bruke til å skrive til disken — blokkeres før det når noen data.",
            ]),
            .warning("""
                DuckDB leser **filer**, ikke minne. Har dokumentet ulagrede endringer, må GEditor skrive \
                en midlertidig kopi før spørringen. For en svært stor fil med ulagrede endringer \
                **stanser den og sier det** heller enn stille å skrive hundrevis av megabyte til disken \
                for én spørring.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Pivottabeller og hurtigdiagrammer",
        summary: "Pivoter og tegn rett fra et spørringsresultat.",
        keywords: ["pivot", "diagram", "krysstabell", "aggregat"],
        blocks: [
            .paragraph("""
                Begge åpnes fra **resultattabellen**: kjør en SQL-setning, og bruk så knappen Pivot \
                eller Diagram på panelet.
                """),
            .heading("Pivot"),
            .paragraph("""
                Velg **rad**kolonnen, **kolonne**kolonnen, **verdi**kolonnen og aggregatet (sum, \
                antall, gjennomsnitt, minste, største) — som i et regnearks pivottabell.
                """),
            .heading("Diagrammer"),
            .paragraph("""
                Søyle, linje, kake, punkt. Tall formatert på vietnamesisk eller europeisk vis, og \
                diagrammet eksporteres som PNG eller SVG for å limes inn andre steder.
                """),
            .note("""
                Vil du ha et diagram som **regnes om med dataene** ved hver bygging? Det er \
                `chart`-blokken i en `.greport.md`-rapport.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Å konvertere en tabell til et annet format",
        summary: "TSV, JSON, XML, Markdown-tabeller, SQL INSERT-setninger — med forhåndsvisning.",
        keywords: ["konverter", "eksporter", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Format", "Nyttig til"],
                rows: [
                    ["TSV", "Å lime inn i et regneark uten å bekymre seg for komma i celler"],
                    ["JSON", "Å mate et API, et skript eller et annet verktøy"],
                    ["XML", "Eldre systemer som krever XML"],
                    ["Markdown-tabell", "Å lime inn i dokumentasjon, en README, en sak"],
                    ["SQL INSERT-setninger", "Å laste inn i en database"],
                ]
            ),
            .paragraph("""
                Dialogen **forhåndsviser de fem første radene** før den nye fanen lages — fem linjer er \
                nok til å bekrefte tabellnavnet, anførselstegnene og hvilke kolonner som ble tall.
                """),
            .note("""
                Forhåndsvisningen kaller **samme funksjon** som lager den virkelige utdataen, begrenset \
                til fem rader. Det er ikke en etterligning som kunne være uenig med sluttresultatet.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Å endre skilletegn",
        summary: "Konverter en fil mellom komma, semikolon, TAB og loddrett strek.",
        keywords: ["skilletegn", "komma", "semikolon", "tab", "europeisk csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Filer eksportert fra et vietnamesisk eller europeisk Excel bruker som regel \
                **semikolon**, fordi kommaet der er desimaltegnet.
                """),
            .warning("""
                Å endre skilletegn **skriver om hele filen**. Celler som inneholder det nye \
                skilletegnet, settes i anførselstegn — ellers ryker tabellens oppbygning.
                """),
            .note("""
                **Var gjenkjenningen gal, er ikke dette kommandoen du vil ha.** Det er to ulike jobber \
                her, nøyaktig som i tegnkodingsparet «tolk på nytt» / «konverter»:

                • *Filen er virkelig semikolonskilt, og vi gjettet komma* — klikk på feltet `CSV · …` på \
                **statuslinjen**, og velg det rette. Ikke en byte i filen endres; bare måten den leses \
                på.

                • *Filen er virkelig kommaskilt, og du vil ha semikolon* — bruk kommandoen på denne \
                siden. Den skriver om filen.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Datarydding

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Datarydding — hele prosessen",
        summary: "Fra en rå fil noen har sendt deg, til en brukbar tabell, og en standard du kan kjøre hver måned.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Ryddeprosessen fra ende til annen",
        summary: "Seks trinn fra en ukjent fil til en troverdig tabell, og en standard til neste måned.",
        keywords: ["rydding", "rydd", "prosess", "normaliser", "ryddige data"],
        blocks: [
            .paragraph("""
                Å rydde i data er **sjelden en engangsjobb**. Folk får den samme rapportmalen hver \
                måned, og hver måned må de samme kolonnene normaliseres på samme måte. Denne prosessen \
                er laget for nettopp det: du gjør det for hånd én gang og kjører det så på nytt med én \
                kommando.
                """),
            .heading("Seks trinn"),
            .steps([
                "**Se på oppbygningen først.** `CSV ▸ Kontroller data` — hvilke rader har feil kolonneantall, hvilke celler feil type. Dette kommer først fordi én forskjøvet rad gjør hver senere statistikk meningsløs.",
                "**Les dataprofilen.** Per kolonne: hvor mange tomme celler, hvor mange ulike verdier, hvilken type, hvor de avvikende ligger. Det er her du forstår filen, før du endrer noe.",
                "**Åpne ryddebenken** (`⇧⌘L`). Den oppdager blandede datoformater, vietnamesiske tall blandet med europeiske, løse blanktegn, manglende verdier. **Forhåndsvis før→etter**, og bruk så.",
                "**Håndter uklare duplikater** hvis en navne- eller adressekolonne har håndskrevne varianter. Her bestemmer du; maskinen bare foreslår.",
                "**Lagre det som en oppskrift.** Rekken av trinn du nettopp utførte, skrives til en navngitt JSON-fil — den filen er din kunnskap om disse dataene.",
                "**Skriv et kvalitetsregelsett** `.gquality.yaml` og vurder. Fra nå av kjøres neste måneds fil gjennom oppskriften og vurderes, og **kommandolinjeporten** gir en utgangskode ulik null når den ikke består.",
            ]),
            .heading("Hvorfor denne rekkefølgen"),
            .bullets([
                "Oppbygning **før** profil: statistikk på en forskjøvet tabell er statistikk om en annen kolonne.",
                "Profil **før** rydding: du må vite `2 % tomme` før du bestemmer deg for å fylle eller fjerne.",
                "Uklare duplikater **etter** normalisering: `CÔNG TY  A` og `Công ty A` viser seg først som ett når blanktegn og bokstavstørrelse er avklart.",
                "Oppskrift **før** regelsett: oppskriften retter, reglene dømmer — å vurdere en urettet tabell gir bare et lavt tall du allerede ventet.",
            ]),
            .heading("Etter første gang er hver måned én kommando"),
            .code(language: "bash", caption: "Rydd og vurder, med en utgangskode for CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Utgangskode **0** betyr bestått, **1** ikke bestått, **2** en feil under kjøringen. \
                `--record-history` legger til en linje i historikkfilen, så neste kjøring kan \
                sammenligne drift.
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
        summary: "Én beskrivelse per kolonne: type, tomme, ulike verdier, fordeling.",
        keywords: ["profil", "kolonnestatistikk", "null", "ulike"],
        blocks: [
            .paragraph("""
                En profil **beskriver**; den dømmer ikke. Den sier *«denne kolonnen er 2 % tom»*; om 2 % \
                er akseptabelt, hører til kvalitetsregelsettet.
                """),
            .table(
                headers: ["Mål", "Slik leses det"],
                rows: [
                    ["Type", "Utledet av selve dataene, ikke av kolonnenavnet"],
                    ["Tomme celler", "Antall og andel av manglende verdier"],
                    ["Ulike verdier", "1 betyr en konstant kolonne; lik radantallet betyr en nøkkelkolonne"],
                    ["Minste · største · gjennomsnitt", "Bare numeriske kolonner"],
                    ["Hyppigste verdier", "Få straks øye på en feilkode eller en overbrukt standardverdi"],
                ]
            ),
            .warning("""
                Telling av ulike verdier har en terskel. Over den er tallet som vises, en **nedre \
                grense**, og profilen **sier at det er et anslag** heller enn å blande det med \
                nøyaktige tall.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Ryddebenken",
        summary: "Sju normaliseringer, alltid forhåndsvist, alltid ett angretrinn, aldri gjettet.",
        keywords: ["rydd", "normaliser", "datoer", "tall", "fyll manglende"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Åpne ryddebenken")]),
            .table(
                headers: ["Handling", "Hva den gjør"],
                rows: [
                    ["Normaliser datoer", "Bring hver datoform i kolonnen til én form"],
                    ["Normaliser tall", "Avklar desimaltegnet og tusenskilletegnet"],
                    ["Klipp blanktegn", "Fjern dem i begge ender; eventuelt slå sammen indre serier òg"],
                    ["Endre bokstavstørrelse", "Gjør kolonnens store/små bokstaver ensartet"],
                    ["Fyll med en fast verdi", "Erstatt tomme celler med en verdi du skriver"],
                    ["Fyll fra en nabo", "Ta verdien fra raden over eller under"],
                    ["Slett rader med tomme celler", "Fjern rader som mangler data"],
                ]
            ),
            .heading("Tre garantier fra hele benken"),
            .bullets([
                "**Alltid forhåndsvist.** En før→etter-tabell med antallet celler som vil endres.",
                "**Ett angretrinn** for hele omgangen, selv når den berører en million celler.",
                "**En rapport etterpå**: hvor mange celler som endret seg, og hvilke som ikke lot seg lese.",
            ]),
            .heading("Prinsippet: gjett aldri"),
            .paragraph("""
                En celle som ikke kan leses med sikkerhet, blir **merket og latt i fred**. Ta \
                `03/04/2026` i en kolonne som blander begge konvensjonene — er det 3. april eller 4. \
                mars? GEditor spør deg om dag/måned-rekkefølgen heller enn å velge for deg.
                """),
            .warning("""
                Å normalisere en datokolonne galt er den typen ødeleggelse som er **nesten umulig å \
                oppdage**: tallene ser fortsatt riktige ut, de er bare en annen dato. Derfor vil denne \
                benken heller nekte enn å utlede.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Uklare duplikater",
        summary: "Finn håndskrevne varianter av samme navn — og slå dem aldri sammen av seg selv.",
        keywords: ["uklar", "duplikater", "slå sammen", "varianter", "skrivefeil"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — tre måter å \
                skrive én kunde på. Vanlig duplikathåndtering ser dem ikke som den samme.
                """),
            .steps([
                "Velg kolonnen som skal undersøkes, og en likhetsterskel.",
                "GEditor grupperer nære verdier i **klynger** og viser sammenligningsformen.",
                "For **hver klynge** velger du hvilken verdi som skal beholdes — eller hopper over klyngen.",
                "Bruk. Ett angretrinn.",
            ]),
            .warning("""
                Dette verktøyet **slår aldri sammen av seg selv**, og det finnes ingen «slå sammen \
                alle»-knapp. To strenger som ligner hverandre 92 %, kan være en skrivefeil eller to \
                virkelig ulike firmaer som skiller seg med ett ord — det kan ikke en maskin avgjøre.
                """),
            .paragraph("""
                Å slå sammen to poster galt er **stille** datatap: ingen celle blir tom, ingen rad blir \
                rød, to enheter blir bare til én, og ingen oppdager det før regnskapet skal avstemmes.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Ryddeoppskrifter",
        summary: "Noter rekkefølgen som en JSON-fil, og kjør den på neste måneds data.",
        keywords: ["oppskrift", "gjenta", "automatiser", "månedlig", "bunke"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Etter ryddingen lagrer du trinnene som en **oppskrift**. Det er en lesbar JSON-fil du \
                kan ha ved siden av dataene, sende til en kollega og legge i et arkiv, så endringer \
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
                Hvert trinn kan **slås av** (`enabled`), så én oppskrift kan tjene flere nesten like \
                filslag.
                """),
            .heading("Å kjøre på nytt"),
            .bullets([
                "I programmet: `CSV ▸ Kjør ryddeoppskrift…`",
                "Fra skallet, på tvers av en mappe: se kommandolinjesiden.",
            ]),
            .code(language: "bash", caption: "En prøvekjøring før noe skrives — ingen fil røres",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Som standard skrives resultatet til en ny fil ved siden av originalen \
                (`sales-clean.csv`). Å overskrive originalen må bes om uttrykkelig med `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Vurdering av datakvalitet",
        summary: "Seks dimensjoner, én poengsum 0–100, og hver formel trykt så du kan regne den ut igjen.",
        keywords: ["kvalitet", "poengsum", "dqr", "seks dimensjoner"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Den skiller seg fra dataprofilen på én grunnleggende måte: en profil **beskriver**, en \
                poengsum **dømmer mot den standarden du erklærte** i en `.gquality.yaml`-fil.
                """),
            .table(
                headers: ["Dimensjon", "Hva den måler"],
                rows: [
                    ["Fullstendighet", "Andel utfylte celler, etter `not_null`-reglene"],
                    ["Gyldighet", "Andel format-, type-, intervall- og regex-regler som består"],
                    ["Entydighet", "Mot nøkkelen du erklærte i `uniqueness_key`"],
                    ["Konsistens", "Regler på tvers av kolonner og på tvers av filer"],
                    ["Nøyaktighet (anslått)", "Avvikere i de numeriske kolonnene du peker ut"],
                    ["Aktualitet", "Hvor gamle dataene er mot terskelen `freshness`"],
                ]
            ),
            .heading("Tre garantier om poengsummen"),
            .bullets([
                "**Formelen er trykt i resultatet** — du kan regne den ut igjen for hånd.",
                "**Deterministisk**: samme data og samme regler gir samme poengsum. Bare *Aktualitet* avhenger av øyeblikket, så `now` er en **parameter** og noteres i resultatet.",
                "**En dimensjon som ikke kan vurderes, står tom med en grunn**, aldri stille gitt 100.",
            ]),
            .warning("""
                Den siste garantien betyr noe. En tabell uten erklært `uniqueness_key`, tildelt 100 for \
                «entydighet», er en poengsum som lyver — og den lyver i den smigrende retningen, som er \
                den farlige.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "`.gquality.yaml`-syntaks",
        summary: "Hver nøkkel i regelfilen, med ett fullstendig regelsett som kjører.",
        keywords: ["gquality", "yaml", "regler", "syntaks", "datastandard"],
        blocks: [
            .paragraph("""
                Filen ligger **ved siden av dataene**, ikke inne i programmet: en datastandard må kunne \
                gjennomgås, og å gjennomgå er nettopp det folk gjør med standarder.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — et fullstendig regelsett",
                  source: """
                    schemaVersion: 1

                    # Vekter for de seks dimensjonene. En manglende dimensjon veier 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Nøkkelen som gjør en rad entydig. Uten den KAN ikke dimensjonen
                    # "Entydighet" vurderes — og totalen vil si at den mangler.
                    uniqueness_key: [ma_don]

                    # Numeriske kolonner undersøkt for avvikere i "Nøyaktighet (anslått)".
                    accuracy_columns: [doanh_thu, so_luong]

                    # Dimensjonen "Aktualitet".
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Advar når denne kjøringen faller sammenlignet med den forrige.
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
                        max_null_pct: 2          # tillat 2 % tomme
                      # Regel på tvers av kolonner: ingen `col` nødvendig
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Regel på tvers av filer: verdien må finnes i en annen fil
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Regeltypene"),
            .table(
                headers: ["Nøkkel", "Betydning", "Dimensjon"],
                rows: [
                    ["`not_null: true`", "Cellen må være utfylt; `max_null_pct` løsner det", "Fullstendighet"],
                    ["`unique: true`", "Ingen gjentatte verdier i kolonnen", "Entydighet"],
                    ["`dtype: int\\|float\\|date\\|text`", "Riktig type", "Gyldighet"],
                    ["`range: { min:, max: }`", "Innenfor et tallintervall", "Gyldighet"],
                    ["`length: { min:, max: }`", "Strenglengde", "Gyldighet"],
                    ["`regex: \"…\"`", "Passer et regulært uttrykk", "Gyldighet"],
                    ["`in_set: [ … ]`", "Ett av en gitt liste", "Gyldighet"],
                    ["`date_format: \"…\"`", "Riktig datoform", "Gyldighet"],
                    ["`compare: { a:, op:, b: }`", "Sammenlign to kolonner; `op` er `<` `<=` `=` `>=` `>` `<>`", "Konsistens"],
                    ["`foreign_key: { file:, column: }`", "Verdien må finnes i en annen fil", "Konsistens"],
                    ["`severity: error\\|warn`", "Regelens alvorlighetsgrad; `error` som standard", "—"],
                ]
            ),
            .warning("""
                Stav en regelnøkkel galt, og filen blir **avvist med en melding**, heller enn at den \
                regelen hoppes stille over. Å hoppe stille over betyr at du tror dataene ble \
                kontrollert mot en regel som aldri kjørte.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "En kvalitetsport i CI",
        summary: "Stopp data som ikke består, ved rørledningen, ved hjelp av utgangskoder.",
        keywords: ["ci", "port", "fail-under", "utgangskode", "automatisering", "historikk", "drift"],
        blocks: [
            .code(language: "bash", caption: "Vurder og gi en utgangskode",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Valg", "Betydning"],
                rows: [
                    ["`--quality <fil.yaml>`", "Regelsettet det vurderes mot"],
                    ["`--fail-under <0…100>`", "Under denne poengsummen er det IKKE BESTÅTT"],
                    ["`--json <fil\\|->`", "Maskinlesbart resultat; `-` skriver til standardutdata"],
                    ["`--record-history`", "Legg til en linje i `sales-standard.history.jsonl`"],
                    ["`--now <ÅÅÅÅ-MM-DD>`", "Fastsett referansedatoen for *Aktualitet*"],
                    ["`--recipe <fil.json>`", "Rydd **i minnet** før vurderingen, uten å skrive en fil"],
                ]
            ),
            .table(
                headers: ["Utgangskode", "Betydning"],
                rows: [["`0`", "Bestått"], ["`1`", "Ikke bestått"], ["`2`", "Feil under kjøringen"]]
            ),
            .heading("Hvorfor CI bør gi `--now`"),
            .paragraph("""
                Uten den sammenligner *Aktualitet* dataene med kjøringens øyeblikk — så den samme filen \
                mister poeng etter hvert som dagene går, og en morgen blir rørledningen rød uten at \
                noen har endret noe.
                """),
            .heading("Sporing av drift"),
            .paragraph("""
                Med `--record-history` legger hver kjøring til en linje i en JSONL-historikkfil. Neste \
                gang sammenligner tersklene i blokken `drift:` med den siste kjøringen og advarer når \
                fallet er for stort.
                """),
            .note("""
                Hver driftsterskel er **av som standard**, unntatt `warn_on_new_failure`. En advarsel \
                slått på fra start med et tall programmet valgte for deg, ville utløses ved alles andre \
                kjøring — og noe som roper ulv på dag én, blir ignorert på dag tre.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Datagraving

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Datagraving — hele prosessen",
        summary: "Avvik, samvariasjon, klyngedannelse, prognoser, assosiasjonsregler — og hvordan de leses.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Graveprosessen fra ende til annen",
        summary: "Seks verktøy, rekkefølgen å bruke dem i, og én regel: ingen måling, ingen slutning.",
        keywords: ["graving", "analyse", "prosess", "statistikk"],
        blocks: [
            .warning("""
                **Rydd først, grav etterpå.** En unormalisert datokolonne gir gale prognoser; en \
                tallkolonne som blander europeiske tusenskilletegn, gir spøkelsesavvikere. Hvert \
                verktøy nedenfor går ut fra at tabellen er ryddig.
                """),
            .heading("Rekkefølgen å gå i"),
            .steps([
                "**Finn avvik** — svarer på *«er noen rad rar»*. Billigst, og ofte straks nyttig.",
                "**Samvariasjonsmatrise** — svarer på *«hvilken kolonne beveger seg med hvilken»*. Den styrer alt etterpå.",
                "**Klyngedannelse** — svarer på *«hvor mange naturlige grupper er her»*.",
                "**Prognose** — bare med en tidskolonne og minst **to fulle sykluser**.",
                "**Assosiasjonsregler** — bare for kurvformede data: én transaksjon per rad, eller to kolonner med transaksjons-id og vare.",
                "**Graving per gruppe** — kjører de tre første på nytt **uavhengig innenfor hver gruppe**. Dette trinnet snur ofte slutningen fra den samlede tabellen på hodet.",
            ]),
            .heading("Tre regler for hele familien"),
            .bullets([
                "**Hvert resultat bærer en «Metode»-blokk**: algoritme, parametre, frø, formel. Den kan ikke slås av — en tabell med tre tall som ikke sier hvor de kom fra, kan ikke brukes til en beslutning.",
                "**Ingen måling, ingen slutning.** For lite utvalg, null varians, en singulær matrise — GEditor nekter og sier hvorfor, heller enn å gi et tall som bare ser riktig ut.",
                "**Deterministiske resultater.** Samme data gir samme resultat; der tilfeldighet trengs, noteres frøet i utdataen.",
            ]),
            .heading("Fra et resultat tilbake til dataene"),
            .paragraph("""
                Hvert panel **merker tilbake i kildedataene**: klikk på en avvikende rad, en \
                samvariasjonscelle eller en assosiasjonsregel, og de aktuelle linjene merkes i \
                tabellen. Slik går du fra *«noe er rart»* til *«rart i nøyaktig disse radene»*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Å finne avvikende rader",
        summary: "Fire mål, tre alvorlighetsgrader, og en forklaring på hvorfor en rad er rar.",
        keywords: ["avviker", "avvik", "z-verdi", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Mål", "Bruk når"],
                rows: [
                    ["z-verdi", "Kolonnen er omtrent normalfordelt"],
                    ["IQR", "Kolonnen er skjev med en lang hale — det trygge standardvalget"],
                    ["MAD", "Kolonnen har allerede mange avvikere og trenger et robust mål"],
                    ["Mahalanobis", "**Flere kolonner samtidig** — fanger rader som er rare i kombinasjon, ikke i noen enkelt kolonne"],
                ]
            ),
            .paragraph("""
                Resultatene farges etter **tre alvorlighetsgrader** heller enn én flat farge — ellers \
                kan ikke en litt uvanlig rad skilles fra en vilt uvanlig.
                """),
            .heading("Å forklare hvorfor"),
            .paragraph("""
                For flerkolonnemålet bryter GEditor ned hver kolonnes bidrag og lager en setning som \
                *«avvikende hovedsakelig gjennom kombinasjonen omsetning (50 %) × mengde (50 %)»*.
                """),
            .note("""
                Den prosenten er *av den forklarlige delen*, ikke *av avstanden*. Metode-blokken sier \
                det rett under tabellen.
                """),
            .warning("""
                En kolonne hvis IQR eller MAD er null, får målet til å **nekte å kjøre** heller enn å \
                dele på noe forsvinnende lite og gi en enorm verdi. For flerkolonnetilfellet: er \
                kovariansmatrisen singulær, **sier GEditor hvilken kolonne som bør fjernes**, i stedet \
                for å bruke en pseudoinvers for å «få det til å virke».
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Samvariasjonsmatrise",
        summary: "Pearson og Spearman for hvert par, med et punktdiagram ved klikk.",
        keywords: ["samvariasjon", "korrelasjon", "pearson", "spearman", "varmekart"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Koeffisient", "Hva den måler"],
                rows: [
                    ["Pearson", "Et **lineært** forhold"],
                    ["Spearman", "**Ethvert monotont** forhold, også buede — regnet på rangtall"],
                ]
            ),
            .paragraph("""
                Klikk på en celle i varmekartet for å se det parets punktdiagram med en regresjonslinje \
                og R².
                """),
            .heading("Fire detaljer som endrer hvordan man leser det"),
            .bullets([
                "**Like verdier bruker gjennomsnittlige rangtall**, så en ny sortering av tabellen endrer ikke Spearman-koeffisienten.",
                "**Tomme celler håndteres parvis**, og hver celles `n` står der i tabellen — `0,93` over 6 rader betyr ikke det samme som `0,93` over 6 000 rader.",
                "**En konstant kolonne gir tomt**, ikke 0. Null betyr *målt, ingen sammenheng funnet*.",
                "**Fargeskalaen er blå↔oransje**, ikke rød–grønn: 8 % av menn ser en rød-grønn skala som én grå masse, som gjør at `+0,9` og `−0,9` ser like ut.",
            ]),
            .warning("""
                **Samvariasjon betyr ikke årsak.** Den setningen tegnes **inne i selve diagrammet**, så \
                den reiser med bildet når du eksporterer det.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Klyngedannelse",
        summary: "k-means og DBSCAN, to måter å velge k på — og en advarsel om skalering.",
        keywords: ["klynge", "kmeans", "dbscan", "grupper", "silhuett", "albue"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritme", "Bruk når"],
                rows: [
                    ["k-means", "Du kjenner (eller vil prøve) antallet klynger; klyngene er klumpformede"],
                    ["DBSCAN", "Du kjenner ikke antallet; klyngene har vilkårlige former; du vil ha støyen skilt ut"],
                ]
            ),
            .heading("Skalering er på som standard — og hvorfor"),
            .paragraph("""
                En `omsetning`-kolonne (i millioner) ved siden av en `mengde`-kolonne (i stykker): \
                avstanden mellom to rader avgjøres nesten helt av den største. Det er ikke «litt \
                suboptimalt» — det er å **svare på et annet spørsmål**. Skaleringen som gjelder, \
                noteres i resultatet.
                """),
            .heading("Å velge antall klynger"),
            .bullets([
                "**Silhuett** — jo høyere verdi, jo bedre atskilte klynger. På en stor tabell **tar den utvalg** (jevnt fordelt, ikke de første 2 000 radene), og resultatet erklærer seg selv et anslag.",
                "**Albue** — tegner summen av kvadrater innenfor klyngene mot k. Det er en **måte å lese et diagram på**, ikke en optimering: den størrelsen faller alltid når k øker, så det finnes ingen statistisk «optimal k».",
            ]),
            .note("""
                For DBSCAN hjelper **k-avstands**diagrammet med å velge en radius: kurvens kne er som \
                regel en fornuftig startverdi.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Prognoser for tidsserier",
        summary: "Oppdeling i trend og sesong, Holt-Winters, og en grunnlinje som alltid kjører ved siden av.",
        keywords: ["prognose", "tidsserie", "sesong", "holt-winters", "trend"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Velg en tidskolonne og en verdikolonne. GEditor deler serien i **trend · sesong · \
                rest** og lager så en prognose med Holt-Winters (additiv eller multiplikativ), med 80 % \
                og 95 % intervaller.
                """),
            .heading("Grunnlinjen kjører alltid, og den sier rett ut hvem som vant"),
            .paragraph("""
                Ved siden av modellen kjører GEditor to naive metoder: *ta forrige periode* og *ta \
                samme periode forrige sesong*. **Taper** modellen mot en grunnlinje, dukker den \
                setningen opp på **første linje, i en annen farge** — ikke under en tabell med tall.
                """),
            .paragraph("""
                Grunnen: prognoseverktøy har for vane å framstille modellen som et faktum, og brukeren \
                har ingen mulighet til å oppdage at «ta bare forrige måneds tall» ville vært mer \
                nøyaktig.
                """),
            .heading("Tre steder der GEditor nekter eller erklærer seg"),
            .bullets([
                "**Uten to fulle sykluser faller den tilbake til den naive metoden.** Å tilpasse sesong til støyen i én enkelt syklus og gjenta den inn i framtiden gir en svært overbevisende, helt oppdiktet prognose.",
                "**En MAPE som møter et null, sier det**, og er mer enn 25 % av periodene null, holder den målet tilbake — å hoppe stille over dem gir et tall regnet på en systematisk skjev delmengde.",
                "**Konfidensintervallet erklærer seg tilnærmet** og sier at det utvider seg for sakte ved lange horisonter.",
            ]),
            .note("""
                Sesongperioden gjenkjennes på **første differanse**, ikke på den rå serien: en trend \
                gjør hvert etterslep sterkt samvarierende og drukner sesongtoppen.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Assosiasjonsregler",
        summary: "Kjøper A, kjøper ofte B — og hvorfor tabellen sorteres etter lift, ikke etter tillit.",
        keywords: ["apriori", "assosiasjonsregler", "handlekurv", "lift", "støtte"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("To dataformer tas imot:"),
            .bullets([
                "**Én kurv per rad** — en kolonne med en liste over varer.",
                "**To kolonner** — transaksjons-id og vare, én vare per rad.",
            ]),
            .table(
                headers: ["Mål", "Betydning"],
                rows: [
                    ["støtte", "Andel kurver som inneholder begge sider"],
                    ["tillit", "Av kurvene med venstre side, hvor stor andel som har høyre"],
                    ["**lift**", "Tillit delt på høyre sides grunnrate"],
                    ["vektstang", "Avstanden fra det uavhengighet ville forutsi"],
                ]
            ),
            .heading("Sortert etter lift, ikke etter tillit"),
            .paragraph("""
                Hvis høyre side uansett dukker opp i 95 % av kurvene, har **hver** regel som fører til \
                den, omtrent 95 % tillit — mens den ikke sier noe som helst. Å sortere etter tillit \
                setter nettopp de mest meningsløse reglene øverst.
                """),
            .warning("""
                `lift < 1` **merkes i selve raden**: 80 % tillit mot noe med en grunnrate på 95 % betyr \
                et **omvendt** forhold — et riktig tall som fører til en gal slutning.
                """),
            .bullets([
                "Å kjøpe to kartonger melk er fortsatt **én** transaksjon som inneholder melk: duplikater inne i en kurv fjernes, ellers vokser støtten med mengden.",
                "Å sette støtteterskelen for lavt får kandidatmengden til å eksplodere kombinatorisk; når taket nås, **stanser GEditor og melder at tabellen er ufullstendig**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Graving per gruppe",
        summary: "Kjør analysen på nytt uavhengig per gruppe — trinnet som oftest snur en slutning.",
        keywords: ["grupper", "per gruppe", "simpson", "avdelinger", "sammenlign grupper"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Velg en tekstkolonne som grupperingsnøkkel. Hver gruppe får avvik, prognose og \
                samvariasjon kjørt **helt uavhengig**, og rangeres så etter kriteriet du velger.
                """),
            .heading("Hvorfor grupper må skilles, ikke slås sammen"),
            .paragraph("""
                To avdelinger, den ene rundt 10 og den andre rundt 100. Et avvikergjerde regnet ut på \
                den **samlede** tabellen lander rundt ±135 — og det svikter i **begge retninger**:
                """),
            .bullets([
                "**Falske negative**: en verdi på 20, åpenbart avvikende for den lille avdelingen, ligger godt innenfor det felles gjerdet. Jo flere grupper, jo blindere blir det.",
                "**Falske positive**: en vidt spredt gruppe får den normale halen sin kappet av det felles gjerdet, og en rekke helt vanlige rader blir merket.",
            ]),
            .heading("Spalten «samvariasjonsavvik» fanger Simpsons paradoks"),
            .paragraph("""
                Tre grupper der **hver** gruppes to kolonner samvarierer med `−1`, men samlet \
                samvarierer de med `> 0,9`. Enhver som bare leser den samlede tabellen, slutter det \
                **stikk motsatte**. Denne spalten peker på nøyaktig de tilfellene.
                """),
            .note("""
                Panelet tilbyr bare **tekstkolonner** som grupperingsnøkler og stanser ved 1 000 \
                grupper med en advarsel — for å hindre at man velger en ordre-id-kolonne og gjør hver \
                rad til sin egen gruppe.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Tekstgraving",
        summary: "n-gram og TF-IDF over en tekstkolonne — å finne karakteristiske uttrykk.",
        keywords: ["tekstgraving", "n-gram", "tf-idf", "nøkkelord", "uttrykk"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Kjører på én tekstkolonne — varebeskrivelser, kundetilbakemeldinger, notatfelt.
                """),
            .bullets([
                "**n-gram** — de hyppigste uttrykkene på 1, 2 og 3 ord.",
                "**TF-IDF** — ord som er **karakteristiske** for hver dokumentgruppe, altså hyppige her og sjeldne andre steder.",
            ]),
            .paragraph("""
                Forskjellen: n-gram forteller deg *«hva kundene stadig nevner»*, TF-IDF forteller deg \
                *«hvordan denne gruppen skiller seg fra de andre»*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
