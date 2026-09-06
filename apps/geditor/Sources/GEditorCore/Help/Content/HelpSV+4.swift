import Foundation

/// Svenskt hjälpinnehåll — del 4: tabelldata, städning och utvinning.
extension HelpSV {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Tabelldata",
        summary: "Se CSV som tabell, filtrera, sortera, pröva uppbyggnaden, fråga med SQL, omvandla.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Se en CSV som tabell",
        summary: "En miljon rader rullar ändå mjukt, rubrikraden står stilla och källtexten rörs inte.",
        keywords: ["csv", "tabell", "rutnät", "tsv", "excel", "kolumner"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Växla mellan tabell och text")]),
            .paragraph("""
                Tabellen är **virtualiserad**: bara synliga rader byggs, så en fil med en miljon rader rullar \
                som en med hundra.
                """),
            .bullets([
                "**Rubrikraden sitter kvar** medan man rullar — vid rad 40 000 vet ni fortfarande vad nionde kolumnen är.",
                "Ändra en cell i tabellen; ändringen går rakt in i källtexten.",
                "Tabell och text är **två blickar på en fil**, inte två kopior.",
                "**⌘C kopierar den markerade raden**, med celler åtskilda av tabbar — klistra rakt in i Excel eller Numbers och varje cell hamnar rätt. Celler med tabbar eller radbrytningar sätts inom citattecken, så att målet inte klyver dem itu.",
            ]),
            .note("""
                Avgränsaren känns igen vid öppning (komma, semikolon, tabb, lodstreck). Är gissningen fel, \
                ändra den med `CSV ▸ Byt avgränsare…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Arbetsböcker med flera blad",
        summary: "Öppna vilket blad som helst i en .xlsx, och ⌘S skriver tillbaka i det blad ni tittar på.",
        keywords: ["excel", "xlsx", "blad", "arbetsbok"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Öppna en `.xlsx`, så visar GEditor **första bladet** som CSV-tabell. `CSV ▸ Välj blad…` \
                räknar upp varje blad i filen och öppnar det ni väljer i samma flik.
                """),
            .heading("Att skriva tillbaka i RÄTT blad"),
            .paragraph("""
                `⌘S` skriver era ändringar i **det blad ni tittar på**, inte i det första. De övriga bladen \
                rörs inte med en enda byte.
                """),
            .note("""
                Bladet minns efter **namn**, inte efter plats. Så att kasta om bladen i Excel mellan två \
                arbetspass leder inte skrivningen fel.
                """),
            .warning("""
                Har det öppna bladet **bytt namn eller raderats** i Excel sedan ni öppnade det, **vägrar `⌘S` \
                att skriva** och säger det. Att falla tillbaka på första bladet vore att hälla ett blads \
                innehåll över ett annat — filen skulle sparas ändå, öppnas ändå, och helt enkelt ha \
                uppgifterna på fel plats.
                """),
            .heading("Byta blad med osparade ändringar"),
            .paragraph("""
                Att byta blad ersätter hela flikens innehåll, så finns något osparat **frågar GEditor först**. \
                `⌘Z` kan inte hämta tillbaka det, för hela dokumentet byttes ut.
                """),
            .heading("Vad det kostar att föra ner Excel till en tabell"),
            .paragraph("""
                Det som överlever är **värdena** — inklusive formlernas resultat, precis de tal Excel visar. \
                Det som inte gör det: teckensnitt, färger, sammanfogade celler, inbäddade diagram och \
                formlerna själva.
                """),
            .paragraph("""
                I gengäld får det bladet hela resten av programmet: filtrering, sortering, SQL-frågor, \
                städbänken, kvalitetsbetyg, utvinning, diagram.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtrera och sortera i tabellen",
        summary: "Ett filterfält per kolumn, som förstår taljämförelse och skrivning utan tecken.",
        keywords: ["filter", "sortera", "kolumn", "söka i tabellen"],
        blocks: [
            .paragraph("Klicka på en kolumnrubrik för att sortera. Filterfältet under den godtar:"),
            .table(
                headers: ["Skriv i filtret", "Betydelse"],
                rows: [
                    ["`hue`", "Innehåller `hue`, **okänsligt för tecken** — hittar också `Huế`"],
                    ["`=Huế`", "Exakt `Huế` (fortfarande okänsligt för tecken)"],
                    ["`>100`", "Större än 100"],
                    ["`>=100`", "100 eller mer"],
                    ["`<0`", "Mindre än 0"],
                    ["`100..200`", "Mellan 100 och 200"],
                    ["tomt", "Inget filter på denna kolumn"],
                ]
            ),
            .paragraph("""
                Att filtrera flera kolumner är ett **och**: en rad måste uppfylla alla. Taljämförelsen hoppar \
                över icke-numeriska celler i stället för att behandla dem som noll.
                """),
            .note("""
                Att filtrera är ett **sätt att se**, inte en radering. Rensa filtret så kommer alla rader \
                tillbaka.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Pröva tabellens uppbyggnad",
        summary: "Hitta rader med fel antal kolumner och celler av fel slag — detta först.",
        keywords: ["pröva", "antal kolumner", "fel slag", "trasiga data"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Det här kör man **före** allt annat på en fil som någon skickat. Den svarar på två frågor:
                """),
            .bullets([
                "**Vilka rader har fel antal kolumner?** Oftast en cell med ett komma som inte satts inom citattecken — och den rubbar varje följande rad.",
                "**Vilka celler har ett annat slag än resten av sin kolumn?** Till exempel ett `n/a` i en talkolumn.",
            ]),
            .paragraph("Resultaten visas som en lista; klicka på ett för att hoppa till den raden."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Radera kolumner",
        summary: "Ta bort en eller flera kolumner ur filen helt och hållet.",
        keywords: ["radera kolumn", "ta bort kolumn"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Välj ur listan de kolumner som ska bort och tillämpa. Det är **ett** ångra-steg, hur många \
                rader filen än har.
                """),
            .warning("""
                Till skillnad från filtrering **ändrar detta den riktiga filen**. För att bara dölja kolumner, \
                använd en SQL-fråga som räknar upp dem ni vill ha.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Fråga CSV med SQL",
        summary: "DuckDB:s fullständiga SQL, kört rakt på den öppna filen — endast läsning.",
        keywords: ["sql", "fråga", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Den öppna tabellen heter **`t`**. Motorn är **DuckDB**, så `JOIN`, `DISTINCT`, `HAVING`, \
                `IN`, `LIKE`, `BETWEEN`, fönsterfunktioner och underfrågor fungerar allihop.
                """),
            .code(language: "sql", caption: "Intäkt per provins, störst först",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Filtrera på datum och på ett textvillkor",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Varje provins andel av summan — med en fönsterfunktion",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Foga samman med en annan fil på disken",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Endast läsning, och det är ett fast löfte"),
            .bullets([
                "Databasen bor **i minnet**; källfilen blir bara läst.",
                "Exakt **en sats** godtas, och den **måste vara ett `SELECT`**. Allt annat — även `COPY … TO 'fil'`, som DuckDB mycket väl kan använda för att skriva till disk — spärras innan det ens når några data.",
            ]),
            .warning("""
                DuckDB läser **filer**, inte minne. Har dokumentet osparade ändringar måste GEditor skriva en \
                tillfällig kopia innan det frågar. För en mycket stor fil med osparade ändringar **stannar \
                den och säger det**, i stället för att tyst skriva hundratals megabyte till disk för en enda \
                fråga.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Pivottabeller och snabba diagram",
        summary: "Pivotera och rita rakt ur ett frågeresultat.",
        keywords: ["pivottabell", "diagram", "korstabell", "sammanräkning"],
        blocks: [
            .paragraph("""
                Båda öppnas ur **resultattabellen**: kör en SQL-sats och använd sedan knappen Pivot eller \
                Diagram i panelen.
                """),
            .heading("Pivot"),
            .paragraph("""
                Välj kolumn för **rader**, kolumn för **kolumner**, kolumn för **värden** och \
                sammanräkningen (summa, antal, medel, min, max) — som ett kalkylblads pivottabell.
                """),
            .heading("Diagram"),
            .paragraph("""
                Stapel, linje, cirkel, spridning. Tal i vietnamesiskt eller europeiskt format, och diagrammet \
                går att exportera som PNG eller SVG för att klistras in någon annanstans.
                """),
            .note("""
                Vill ni ha ett diagram som **uppdateras med data** vid varje ombyggnad? Det är blocket \
                `chart` i en `.greport.md`-rapport.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Omvandla en tabell till ett annat format",
        summary: "TSV, JSON, XML, Markdown-tabeller, SQL INSERT-satser — med förhandsvisning.",
        keywords: ["omvandla", "exportera", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Format", "Bra till"],
                rows: [
                    ["TSV", "Att klistra in i ett kalkylblad utan att oroa sig för komman i celler"],
                    ["JSON", "Att mata ett API, ett skript eller ett annat verktyg"],
                    ["XML", "Gamla system som kräver XML"],
                    ["Markdown-tabell", "Att klistra in i dokumentation, en README, ett ärende"],
                    ["SQL INSERT-satser", "Att läsa in i en databas"],
                ]
            ),
            .paragraph("""
                Rutan **förhandsvisar de fem första raderna** innan den nya fliken skapas — fem rader räcker \
                för att bekräfta tabellnamnet, citattecknen och vilka kolumner som blivit tal.
                """),
            .note("""
                Förhandsvisningen kallar **samma funktion** som skapar den riktiga utdatan, begränsad till \
                fem rader. Det är ingen efterhärmning som skulle kunna avvika från slutresultatet.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Byta avgränsare",
        summary: "Omvandla en fil mellan komma, semikolon, tabb och lodstreck.",
        keywords: ["avgränsare", "komma", "semikolon", "tabb", "europeisk csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Filer som exporterats ur ett vietnamesiskt eller europeiskt Excel använder oftast \
                **semikolon**, eftersom kommat där är decimaltecken.
                """),
            .warning("""
                Att byta avgränsare **skriver om hela filen**. Celler som innehåller den nya avgränsaren sätts \
                inom citattecken — annars faller tabellens uppbyggnad samman.
                """),
            .note("""
                **Om igenkänningen var fel är detta inte kommandot ni vill ha.** Här finns två olika \
                uppgifter, precis som i teckenkodningsparet «tolka om» / «omvandla»:

                • *Filen är verkligen semikolonavgränsad och vi gissade komma* — klicka på delen `CSV · …` i \
                **statusraden** och välj rätt. Inte en byte i filen ändras; bara hur den läses.

                • *Filen är verkligen kommaavgränsad och ni vill ha semikolon* — använd kommandot på den här \
                sidan. Det skriver om filen.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Städning

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Datastädning — hela flödet",
        summary: "Från en rå fil någon skickat till en brukbar tabell, och en norm att köra om varje månad.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Städflödet, från början till slut",
        summary: "Sex steg från en okänd fil till en pålitlig tabell, och en norm för nästa månad.",
        keywords: ["städning", "flöde", "normalisera", "rena data"],
        blocks: [
            .paragraph("""
                Att städa data är **sällan en engångssak**. Folk får samma rapportmall varje månad, och varje \
                månad ska samma kolumner normaliseras på samma sätt. Det här flödet är gjort för det: ni gör \
                det en gång för hand och kör sedan om det med ett enda kommando.
                """),
            .heading("Sex steg"),
            .steps([
                "**Titta på uppbyggnaden först.** `CSV ▸ Pröva data` — vilka rader har fel antal kolumner, vilka celler fel slag. Detta kommer först för att en enda rubbad rad gör varje senare statistik meningslös.",
                "**Läs dataprofilen.** Per kolumn: hur många tomma celler, hur många skilda värden, vilket slag, var de avvikande värdena finns. Här förstår ni filen, innan ni ändrar något.",
                "**Öppna städbänken** (`⇧⌘L`). Den känner igen blandade datumformer, vietnamesiska tal blandade med europeiska, vilsna blanktecken, saknade värden. **Förhandsvisa före→efter**, och tillämpa sedan.",
                "**Ta hand om ungefärliga dubbletter** om en kolumn med namn eller adresser har varianter inskrivna för hand. Här bestämmer ni; maskinen bara föreslår.",
                "**Spara det som ett recept.** Följden ni just utförde skrivs till en namngiven JSON-fil — den filen är er kunskap om dessa data.",
                "**Skriv en uppsättning kvalitetsregler** `.gquality.yaml` och betygsätt. Härefter går nästa månads fil genom receptet och får ett betyg, och **kommandoradsgrinden** ger en avslutskod skild från noll när den inte går igenom.",
            ]),
            .heading("Varför denna ordning"),
            .bullets([
                "Uppbyggnad **före** profil: statistik på en rubbad tabell är statistik om en annan kolumn.",
                "Profil **före** städning: man måste veta «2 % tomt» innan man beslutar att fylla eller kasta.",
                "Ungefärliga dubbletter **efter** normaliseringen: `CÔNG TY  A` och `Công ty A` visar sig vara en och samma först när blanktecken och versaler är i ordning.",
                "Recept **före** regeluppsättning: receptet lagar, reglerna dömer — att betygsätta en olagad tabell ger bara ett lågt tal ni ändå väntade er.",
            ]),
            .heading("Efter första gången är varje månad ett kommando"),
            .code(language: "bash", caption: "Städa och sedan betygsätta, med avslutskod för CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Avslutskod **0** betyder godkänt, **1** underkänt, **2** körningsfel. `--record-history` \
                lägger en rad till historikfilen så att nästa körning kan jämföra avdriften.
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
        summary: "En beskrivning per kolumn: slag, tomrum, skilda värden, fördelning.",
        keywords: ["profil", "kolumnstatistik", "null", "skilda"],
        blocks: [
            .paragraph("""
                En profil **beskriver**; den dömer inte. Den säger *«den här kolumnen är 2 % tom»*; om 2 % är \
                godtagbart hör till kvalitetsreglerna.
                """),
            .table(
                headers: ["Mått", "Hur man läser det"],
                rows: [
                    ["Slag", "Härlett ur uppgifterna själva, inte ur kolumnnamnet"],
                    ["Tomma celler", "Antal och andel saknade värden"],
                    ["Skilda värden", "1 betyder en oföränderlig kolumn; lika med radantalet betyder en nyckelkolumn"],
                    ["Min · max · medel", "Bara numeriska kolumner"],
                    ["Vanligaste värdena", "Att genast upptäcka en felkod eller ett överanvänt förvalt värde"],
                ]
            ),
            .warning("""
                Räkningen av skilda värden har en tröskel. Ovanför den är det visade talet en **undre gräns**, \
                och profilen **säger att det är en uppskattning** i stället för att blanda in det bland de \
                exakta räkningarna.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Städbänken för data",
        summary: "Sju normaliseringar, alltid med förhandsvisning, alltid ett ångra-steg, aldrig gissningar.",
        keywords: ["städa", "normalisera", "datum", "tal", "fylla"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Öppna städbänken")]),
            .table(
                headers: ["Åtgärd", "Vad den gör"],
                rows: [
                    ["Normalisera datum", "Föra varje datumform i kolumnen till en enda"],
                    ["Normalisera tal", "Reda ut decimaltecken och grupperingstecken"],
                    ["Klipp blanktecken", "Ta bort dem i båda ändar; om ni vill även pressa ihop de inre"],
                    ["Ändra versaler", "Göra kolumnens versalbruk enhetligt"],
                    ["Fyll med ett fast värde", "Ersätta tomma celler med ett värde ni skriver"],
                    ["Fyll från en granne", "Ta värdet från raden ovanför eller nedanför"],
                    ["Radera rader med tomma celler", "Kasta rader som saknar uppgifter"],
                ]
            ),
            .heading("Tre löften från hela bänken"),
            .bullets([
                "**Alltid förhandsvisad.** En tabell före→efter, med antalet celler som kommer att ändras.",
                "**Ett ångra-steg** för hela omgången, även när den rör en miljon celler.",
                "**En redogörelse efteråt**: hur många celler som ändrades och vilka som inte gick att tyda.",
            ]),
            .heading("Grundsatsen: aldrig gissa"),
            .paragraph("""
                En cell som inte går att tyda med säkerhet blir **utmärkt och lämnad i fred**. Ta `03/04/2026` \
                i en kolumn som blandar båda bruken — är det 3 april eller 4 mars? GEditor frågar er om \
                dag/månad-ordningen i stället för att välja åt er.
                """),
            .warning("""
                Att normalisera en datumkolumn fel är den sorts skada som är **nästan omöjlig att upptäcka**: \
                talen ser fortfarande rätt ut, de är bara ett annat datum. Därför avstår denna bänk hellre än \
                sluter sig till något.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Ungefärliga dubbletter",
        summary: "Hitta varianter av samma namn inskrivna för hand — och aldrig slå ihop dem av sig själv.",
        keywords: ["ungefärlig", "dubbletter", "slå ihop", "varianter", "skrivfel"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — tre sätt att skriva \
                samma kund. Vanlig dubblettrensning ser dem inte som samma.
                """),
            .steps([
                "Välj kolumnen att granska och en likhetströskel.",
                "GEditor grupperar närliggande värden i **klasar** och visar jämförelseformen.",
                "För **varje klase** väljer ni vilket värde som ska behållas — eller hoppar över den.",
                "Tillämpa. Ett ångra-steg.",
            ]),
            .warning("""
                Detta verktyg **slår aldrig ihop av sig själv**, och det finns ingen knapp för «slå ihop \
                alla». Två strängar som liknar varandra till 92 % kan vara ett skrivfel, eller två verkligt \
                skilda företag som skiljer sig åt med ett ord — en maskin kan inte avgöra det.
                """),
            .paragraph("""
                Att slå ihop två poster fel är **tyst** dataförlust: ingen cell blir tom, ingen rad blir röd, \
                två enheter blir helt enkelt en och ingen märker det förrän böckerna stäms av.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Städrecept",
        summary: "Teckna ned följden som en JSON-fil och köra om den på nästa månads data.",
        keywords: ["recept", "upprepa", "automatisera", "månadsvis", "sats"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Spara stegen som ett **recept** efter städningen. Det är en JSON-fil som en människa kan läsa, \
                som ni kan förvara bredvid uppgifterna, skicka till en kollega och lägga i ett arkiv så att \
                ändringar följs.
                """),
            .code(language: "json", caption: "sales-standard.json — förkortat",
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
                Varje steg går att **stänga av** (`enabled`), så ett recept kan tjäna flera nästan lika slags \
                filer.
                """),
            .heading("Att köra om"),
            .bullets([
                "I programmet: `CSV ▸ Kör städrecept…`",
                "Från skalet, över en hel mapp: se sidan om kommandoraden.",
            ]),
            .code(language: "bash", caption: "En torrkörning innan något skrivs — ingen fil rörs",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Som standard skrivs resultatet till en ny fil bredvid originalet (`sales-clean.csv`). Att \
                skriva över originalet måste begäras uttryckligen med `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Kvalitetsbetyg för data",
        summary: "Sex dimensioner, ett betyg mellan 0 och 100, och varje formel utskriven så att ni kan räkna om den.",
        keywords: ["kvalitet", "betyg", "dqr", "sex dimensioner"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Det skiljer sig från dataprofilen i en grundläggande sak: en profil **beskriver**, ett betyg \
                **dömer mot den norm ni angivit** i en `.gquality.yaml`-fil.
                """),
            .table(
                headers: ["Dimension", "Vad den mäter"],
                rows: [
                    ["Fullständighet", "Andelen ifyllda celler enligt `not_null`-reglerna"],
                    ["Giltighet", "Andelen godkända regler för form, slag, intervall och reguljära uttryck"],
                    ["Entydighet", "Mot nyckeln angiven i `uniqueness_key`"],
                    ["Samstämmighet", "Regler över kolumner och över filer"],
                    ["Noggrannhet (uppskattad)", "Avvikande värden i de numeriska kolumner ni pekar ut"],
                    ["Aktualitet", "Hur gamla uppgifterna är mot tröskeln `freshness`"],
                ]
            ),
            .heading("Tre löften om betyget"),
            .bullets([
                "**Formeln står utskriven i resultatet** — ni kan räkna om den för hand.",
                "**Förutsägbart**: samma data och samma regler ger samma betyg. Bara *Aktualitet* beror på ögonblicket, så `now` är en **parameter** och antecknas i resultatet.",
                "**En dimension som inte går att betygsätta lämnas tom med sitt skäl**, aldrig tyst med en hundra.",
            ]),
            .warning("""
                Det sista löftet betyder något. En tabell utan angiven `uniqueness_key` som ges 100 för \
                «entydighet» är ett betyg som ljuger — och det ljuger åt det smickrande hållet, det farliga.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Syntax för `.gquality.yaml`",
        summary: "Varje nyckel i regelfilen, med en fullständig uppsättning som fungerar.",
        keywords: ["gquality", "yaml", "regler", "syntax", "datanorm"],
        blocks: [
            .paragraph("""
                Filen bor **bredvid uppgifterna**, inte inne i programmet: en datanorm måste gå att granska, \
                och att granska är just det folk gör med normer.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — en fullständig regeluppsättning",
                  source: """
                    schemaVersion: 1

                    # Vikter för de sex dimensionerna. En dimension som saknas väger 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Nyckeln som gör en rad entydig. Utan den KAN dimensionen «Entydighet»
                    # inte betygsättas — och summan säger det.
                    uniqueness_key: [ma_don]

                    # Numeriska kolumner som granskas för avvikande värden i «Noggrannhet (uppskattad)».
                    accuracy_columns: [doanh_thu, so_luong]

                    # Dimensionen «Aktualitet».
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Varna när denna körning sjunker mot den föregående.
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
                        max_null_pct: 2          # tillåter 2 % tomt
                      # Regel över kolumner: `col` behövs inte
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Regel över filer: värdet måste finnas i en annan fil
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Regelslagen"),
            .table(
                headers: ["Nyckel", "Betydelse", "Dimension"],
                rows: [
                    ["`not_null: true`", "Cellen måste vara ifylld; `max_null_pct` mjukar upp det", "Fullständighet"],
                    ["`unique: true`", "Inga upprepade värden i kolumnen", "Entydighet"],
                    ["`dtype: int\\|float\\|date\\|text`", "Rätt slag", "Giltighet"],
                    ["`range: { min:, max: }`", "Inom ett talintervall", "Giltighet"],
                    ["`length: { min:, max: }`", "Strängens längd", "Giltighet"],
                    ["`regex: \"…\"`", "Stämmer mot ett reguljärt uttryck", "Giltighet"],
                    ["`in_set: [ … ]`", "En ur en given lista", "Giltighet"],
                    ["`date_format: \"…\"`", "Rätt datumform", "Giltighet"],
                    ["`compare: { a:, op:, b: }`", "Jämför två kolumner; `op` är `<` `<=` `=` `>=` `>` `<>`", "Samstämmighet"],
                    ["`foreign_key: { file:, column: }`", "Värdet måste finnas i en annan fil", "Samstämmighet"],
                    ["`severity: error\\|warn`", "Regelns allvar; `error` som standard", "—"],
                ]
            ),
            .warning("""
                En felstavad regelnyckel gör att filen **avvisas med ett meddelande**, i stället för att den \
                regeln tyst hoppas över. Att tyst hoppa över betyder att ni tror att uppgifterna prövats mot \
                en regel som aldrig kördes.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "En kvalitetsgrind i CI",
        summary: "Stoppa bristfälliga data i kedjan, med hjälp av avslutskoder.",
        keywords: ["ci", "grind", "fail-under", "avslutskod", "historik", "avdrift"],
        blocks: [
            .code(language: "bash", caption: "Betygsätta och ge en avslutskod",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Väljare", "Betydelse"],
                rows: [
                    ["`--quality <fil.yaml>`", "Regeluppsättningen att betygsätta mot"],
                    ["`--fail-under <0…100>`", "Under detta betyg är det UNDERKÄNT"],
                    ["`--json <fil\\|->`", "Maskinläsbart resultat; `-` skriver till standardutdata"],
                    ["`--record-history`", "Lägger en rad till `sales-standard.history.jsonl`"],
                    ["`--now <ÅÅÅÅ-MM-DD>`", "Fastställer referensdatum för *Aktualitet*"],
                    ["`--recipe <fil.json>`", "Städa **i minnet** före betygsättning, utan att skriva någon fil"],
                ]
            ),
            .table(
                headers: ["Avslutskod", "Betydelse"],
                rows: [["`0`", "Godkänt"], ["`1`", "Underkänt"], ["`2`", "Körningsfel"]]
            ),
            .heading("Varför CI bör skicka med `--now`"),
            .paragraph("""
                Utan det jämför *Aktualitet* uppgifterna med körningens ögonblick — så samma fil tappar poäng \
                allteftersom dagarna går, och en morgon blir kedjan röd utan att någon ändrat något.
                """),
            .heading("Att följa avdriften"),
            .paragraph("""
                Med `--record-history` lägger varje körning en rad till en JSONL-historikfil. Nästa gång \
                jämför trösklarna i blocket `drift:` mot den senaste körningen och varnar när fallet är för \
                stort.
                """),
            .note("""
                Varje avdriftströskel är **av som standard**, utom `warn_on_new_failure`. En varning påslagen \
                från fabrik med ett tal som programmet valt åt er skulle slå till redan vid allas andra \
                körning — och det som ropar «varg» dag ett struntar man i dag tre.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Utvinning

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Datautvinning — hela flödet",
        summary: "Avvikelser, samvariation, klasar, prognos, sambandsregler — och hur man läser dem.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Utvinningsflödet, från början till slut",
        summary: "Sex verktyg, ordningen att bruka dem i, och en regel: ingen mätning, ingen slutsats.",
        keywords: ["utvinning", "analys", "flöde", "statistik"],
        blocks: [
            .warning("""
                **Städa först, utvinn sedan.** En onormaliserad datumkolumn ger felaktiga prognoser; en \
                talkolumn som blandar europeiska grupperingstecken ger spökavvikelser. Varje verktyg nedan \
                utgår från att tabellen är ren.
                """),
            .heading("Ordningen att gå i"),
            .steps([
                "**Hitta avvikelser** — svarar på *«är någon rad besynnerlig?»*. Billigast och ofta genast till nytta.",
                "**Samvariationsmatris** — svarar på *«vilken kolumn rör sig med vilken?»*. Den styr allt som kommer efter.",
                "**Klasar** — svarar på *«hur många naturliga grupper finns här inne?»*.",
                "**Prognos** — bara med en tidskolumn och minst **två fullständiga cykler**.",
                "**Sambandsregler** — bara för data i korgform: en transaktion per rad, eller två kolumner med transaktionsnummer och vara.",
                "**Utvinning per grupp** — kör om de tre första **oberoende inom varje grupp**. Det steget vänder ofta på slutsatsen dragen ur den samlade tabellen.",
            ]),
            .heading("Tre regler för hela familjen"),
            .bullets([
                "**Varje resultat bär ett «Metod»-block**: algoritm, inställningar, frö, formel. Det går inte att stänga av — en tabell med tre tal som inte säger varifrån de kommer duger inte som beslutsunderlag.",
                "**Ingen mätning, ingen slutsats.** För litet urval, ingen spridning, singulär matris — GEditor avstår och säger varför, i stället för att lämna ett tal som bara ser rätt ut.",
                "**Förutsägbara resultat.** Samma data ger samma resultat; där slump behövs antecknas fröet i utdatan.",
            ]),
            .heading("Från resultatet tillbaka till uppgifterna"),
            .paragraph("""
                Varje panel **märker tillbaka i källdata**: klicka på en avvikande rad, en samvariationscell \
                eller en sambandsregel, så märks de berörda raderna i tabellen. Så går man från *«något är \
                besynnerligt»* till *«besynnerligt just i dessa rader»*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Hitta avvikande rader",
        summary: "Fyra mått, tre allvarlighetsnivåer och en förklaring till varför en rad är besynnerlig.",
        keywords: ["avvikare", "avvikelse", "z-värde", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Mått", "När man använder det"],
                rows: [
                    ["z-värde", "Kolumnen är ungefär normalfördelad"],
                    ["IQR", "Kolumnen är sned med lång svans — det trygga förvalet"],
                    ["MAD", "Kolumnen har redan många avvikare och behöver ett robust mått"],
                    ["Mahalanobis", "**Flera kolumner samtidigt** — fångar rader som är besynnerliga i kombinationen, inte i någon enskild kolumn"],
                ]
            ),
            .paragraph("""
                Resultaten färgas efter **tre allvarlighetsnivåer** i stället för en enda platt färg — annars \
                skulle en något ovanlig rad inte gå att skilja från en vansinnigt ovanlig.
                """),
            .heading("Att förklara varför"),
            .paragraph("""
                För flerkolumnsmåttet delar GEditor upp varje kolumns bidrag och ger en mening som *«avvikande \
                främst genom kombinationen intäkt (50 %) × antal (50 %)»*.
                """),
            .note("""
                Den andelen gäller den *förklarbara delen*, inte *avståndet*. Metod-blocket säger det strax \
                under tabellen.
                """),
            .warning("""
                En kolumn vars IQR eller MAD är noll får måttet att **vägra köra**, i stället för att dela med \
                något ytterst litet och ge ett väldigt värde. I flerkolumnsfallet, om kovariansmatrisen är \
                singulär, **säger GEditor vilken kolumn som ska bort** i stället för att ta till en \
                pseudoinvers för att «få det att gå».
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Samvariationsmatris",
        summary: "Pearson och Spearman för varje par, med spridningsdiagram vid klick.",
        keywords: ["samvariation", "pearson", "spearman", "värmekarta", "spridning"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Koefficient", "Vad den mäter"],
                rows: [
                    ["Pearson", "Ett **linjärt** samband"],
                    ["Spearman", "**Varje monotont** samband, även krökta — beräknat på rangordning"],
                ]
            ),
            .paragraph("""
                Klicka på en cell i värmekartan för att se det parets spridningsdiagram, med regressionslinje \
                och R².
                """),
            .heading("Fyra detaljer som ändrar läsningen"),
            .bullets([
                "**Lika värden får medelrang**, så att sortera om tabellen ändrar inte Spearman-koefficienten.",
                "**Tomma celler hanteras parvis**, och varje cells `n` står där i tabellen — `0,93` över 6 rader betyder inte det `0,93` över 6 000 rader betyder.",
                "**En oföränderlig kolumn ger tomt**, inte 0. Noll betyder *uppmätt, inget samband funnet*.",
                "**Färgskalan är blå↔orange**, inte röd-grön: 8 % av männen ser en röd-grön skala som en enda grå massa, vilket får `+0,9` och `−0,9` att se lika ut.",
            ]),
            .warning("""
                **Samvariation innebär inte orsakssamband.** Den meningen ritas **inne i själva diagrammet**, \
                så den följer med bilden när ni exporterar den.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Klasindelning",
        summary: "k-medel och DBSCAN, två sätt att välja k — och en varning om skalning.",
        keywords: ["klase", "kluster", "kmeans", "dbscan", "silhuett", "armbåge"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritm", "När man använder den"],
                rows: [
                    ["k-medel", "Ni känner (eller vill pröva) antalet klasar; klasarna är fläckformade"],
                    ["DBSCAN", "Ni känner inte antalet; klasarna har godtyckliga former; ni vill skilja ut bruset"],
                ]
            ),
            .heading("Skalningen är på som standard — och varför"),
            .paragraph("""
                En kolumn `intäkt` (i miljoner) bredvid en kolumn `antal` (i styck): avståndet mellan två \
                rader avgörs nästan helt av den större. Det är inte «suboptimalt» — det är att **svara på en \
                annan fråga**. Den gällande skalningen antecknas i resultatet.
                """),
            .heading("Att välja antalet klasar"),
            .bullets([
                "**Silhuett** — ju högre värde, desto bättre åtskilda klasar. På en stor tabell **tar den ett urval** (jämnt utspritt, inte de första 2 000 raderna), och resultatet förklarar sig självt som en uppskattning.",
                "**Armbåge** — ritar kvadratsumman inom klasen mot k. Det är ett **sätt att läsa ett diagram**, inte en optimering: den storheten sjunker alltid när k stiger, så statistiskt finns inget «optimalt k».",
            ]),
            .note("""
                För DBSCAN hjälper diagrammet över **k-avstånd** till att välja en radie: kurvans knä är \
                oftast ett rimligt utgångsvärde.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Prognos för tidsserier",
        summary: "Uppdelning i trend och säsong, Holt-Winters, och en jämförelsepunkt som alltid löper bredvid.",
        keywords: ["prognos", "tidsserie", "säsong", "holt-winters", "trend"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Välj en tidskolumn och en värdekolumn. GEditor delar upp serien i **trend · säsong · rest** \
                och gör sedan en prognos med Holt-Winters (additiv eller multiplikativ), med intervall på \
                80 % och 95 %.
                """),
            .heading("Jämförelsepunkten löper alltid med och säger rakt ut vem som vann"),
            .paragraph("""
                Vid sidan av modellen kör GEditor två naiva metoder: *ta föregående period* och *ta samma \
                period förra säsongen*. **Förlorar** modellen mot en jämförelsepunkt står den meningen på \
                **första raden, i en annan färg** — och inte under en tabell med tal.
                """),
            .paragraph("""
                Skälet: prognosverktyg brukar lägga fram modellen som ett faktum, och användaren har ingen \
                möjlighet att få veta att «ta helt enkelt förra månadens tal» hade varit noggrannare.
                """),
            .heading("Tre ställen där GEditor avstår eller förklarar sig"),
            .bullets([
                "**Utan två fullständiga cykler faller den tillbaka på den naiva metoden.** Att anpassa säsongen till bruset i en enda cykel och upprepa det in i framtiden ger en mycket övertygande och helt påhittad prognos.",
                "**Möter MAPE en nolla säger den det**, och är mer än 25 % av perioderna noll håller den inne måttet — att tyst hoppa över dem ger ett tal beräknat på en systematiskt skev delmängd.",
                "**Konfidensintervallet förklarar sig ungefärligt** och säger att det vidgas för långsamt på långa horisonter.",
            ]),
            .note("""
                Säsongsperioden känns igen på **första differensen**, inte på den råa serien: en trend gör \
                varje eftersläpning starkt samvarierande och dränker säsongstoppen.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Sambandsregler",
        summary: "Köper A, köper ofta B — och varför tabellen sorteras efter lyft och inte efter tillit.",
        keywords: ["apriori", "sambandsregler", "korg", "lyft", "stöd"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Två dataformer godtas:"),
            .bullets([
                "**En korg per rad** — en kolumn med en lista över varor.",
                "**Två kolumner** — transaktionsnummer och vara, en vara per rad.",
            ]),
            .table(
                headers: ["Mått", "Betydelse"],
                rows: [
                    ["stöd", "Andelen korgar som innehåller båda sidorna"],
                    ["tillit", "Av korgarna med vänstersidan, hur stor andel som har högersidan"],
                    ["**lyft**", "Tilliten delad med högersidans grundfrekvens"],
                    ["leverage", "Avståndet till vad oberoende skulle förutsäga"],
                ]
            ),
            .heading("Sorterat efter lyft, inte efter tillit"),
            .paragraph("""
                Om högersidan ändå förekommer i 95 % av korgarna har **varje** regel som leder dit omkring \
                95 % tillit — utan att säga någonting alls. Att sortera efter tillit lyfter just de mest \
                innehållslösa reglerna högst upp.
                """),
            .warning("""
                `lyft < 1` **märks ut i själva raden**: 80 % tillit mot något med grundfrekvensen 95 % \
                betyder ett **omvänt** samband — ett riktigt tal som leder till en felaktig slutsats.
                """),
            .bullets([
                "Att köpa två paket mjölk är fortfarande **en** transaktion med mjölk: dubbletter inom en korg kastas, annars sväller stödet med antalet.",
                "En för låg stödtröskel får mängden kandidater att växa explosionsartat; när taket nås **stannar GEditor och förklarar tabellen ofullständig**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Utvinning per grupp",
        summary: "Köra om analysen oberoende per grupp — det steg som oftast vänder på en slutsats.",
        keywords: ["per grupp", "simpson", "kontor", "jämföra grupper"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Välj en textkolumn som grupperingsnyckel. Varje grupp får avvikelser, prognos och \
                samvariation körda **helt oberoende**, och rangordnas sedan efter det villkor ni väljer.
                """),
            .heading("Varför grupper måste hållas isär och inte slås ihop"),
            .paragraph("""
                Två kontor, ett kring 10 och ett kring 100. Ett avvikarstaket beräknat på den **samlade** \
                tabellen hamnar kring ±135 — och det missar **åt båda hållen**:
                """),
            .bullets([
                "**Falska negativ**: ett värde på 20, uppenbart avvikande för det lilla kontoret, ligger väl inne i det gemensamma staketet. Ju fler grupper, desto blindare blir det.",
                "**Falska positiv**: för en vitt spridd grupp klipper det gemensamma staketet av den normala svansen, och en mängd vanliga rader märks ut.",
            ]),
            .heading("Spalten «samvariationsavvikelse» fångar Simpsons paradox"),
            .paragraph("""
                Tre grupper där **varje** grupp samvarierar sina två kolumner till `−1`, men ihopslagna \
                samvarierar de till `> 0,9`. Den som bara läser den samlade tabellen drar **precis motsatt** \
                slutsats. Den spalten pekar just på sådana fall.
                """),
            .note("""
                Panelen erbjuder bara **textkolumner** som grupperingsnyckel och stannar vid 1 000 grupper med \
                en varning — för att hindra att någon väljer en kolumn med ordernummer och gör varje rad till \
                en egen grupp.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Textutvinning",
        summary: "n-gram och TF-IDF över en textkolumn — hitta de kännetecknande uttrycken.",
        keywords: ["textutvinning", "n-gram", "tf-idf", "nyckelord", "uttryck"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Körs på en textkolumn — varubeskrivningar, kundomdömen, anteckningsfält.
                """),
            .bullets([
                "**n-gram** — de vanligaste uttrycken om 1, 2 och 3 ord.",
                "**TF-IDF** — ord som är **kännetecknande** för varje dokumentgrupp, alltså vanliga här och sällsynta annorstädes.",
            ]),
            .paragraph("""
                Skillnaden: n-gram säger er *«vad kunderna nämner gång på gång»*, TF-IDF säger er *«hur den \
                här gruppen skiljer sig från de andra»*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
