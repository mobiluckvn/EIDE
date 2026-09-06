import Foundation

/// Svenskt hjälpinnehåll — del 1: kom igång och redigera.
///
/// **Ämnenas `id` översätts ALDRIG.** Det är dem `.seeAlso` pekar på, dem menyn öppnar, och de gör
/// att hjälpfönstret kan byta språk **utan att kasta tillbaka läsaren till innehållsförteckningen**.
/// Ändrar man ett id går alla länkar sönder — i alla böcker på en gång.
///
/// Menytitlarna i `commands:` står kvar på vietnamesiska: de måste stämma ord för ord med de riktiga
/// menyposterna, som `HelpCoverage` kontrollerar just via den strängen.
enum HelpSV {}

extension HelpSV {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Kom igång",
        summary: "Vad GEditor gör, och var de första fem minuterna gör mest nytta.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Vad GEditor är",
        summary: "En text- och dataredigerare i gigabyteskala för macOS som talar vietnamesiska.",
        keywords: ["introduktion", "välkommen", "översikt", "om"],
        blocks: [
            .paragraph("""
                GEditor öppnar en **fil på 1 GB utan att läsa in 1 GB i minnet**. Den läser genom ett \
                glidande fönster över en minnesavbildad fil, så en logg med 200 miljoner rader eller en \
                CSV med en miljon rader öppnas på ungefär en sekund och rullar mjukt.
                """),
            .paragraph("""
                Utöver redigering är den en **arbetsbänk för data**: se en CSV som tabell, städa den, \
                betygsätt kvaliteten, fråga med SQL, leta avvikelser och trender och gör sedan en \
                rapport. Och den läser de gamla vietnamesiska teckenkodningarna som de flesta verktyg \
                idag har glömt.
                """),
            .heading("Sex saker värda att pröva först"),
            .table(
                headers: ["Uppgift", "Vart"],
                rows: [
                    ["Öppna en stor fil utan att vänta", "Dra in den i fönstret — se «Öppna stora filer»"],
                    ["Ändra många ställen samtidigt", "`⌘D` lägger till nästa förekomst, skriv sedan en enda gång"],
                    ["Söka med reguljärt uttryck", "`⌘F`, slå på Regex — motorn är PCRE2 med JIT"],
                    ["Se en CSV som tabell", "`⌥⌘T` — en miljon rader rullar ändå mjukt"],
                    ["Städa en rörig datatabell", "`⇧⌘L` städbänken — förhandsvisning innan något tillämpas"],
                    ["Öppna en vietnamesisk fil som visas som kråkfötter", "Klicka på teckenkodningen i statusraden"],
                ]
            ),
            .note("""
                Kommer ni från Notepad++? Det finns en sida som jämför de båda tangentuppsättningarna, för \
                några tangenter **byter plats** på macOS i stället för att bara byta `Ctrl` mot `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Era första fem minuter",
        summary: "Tolv kortkommandon täcker det mesta av det dagliga arbetet.",
        keywords: ["kortkommando", "tangenter", "start", "grunder"],
        blocks: [
            .paragraph("""
                Ni behöver inte lära er allt. De tolv tangenterna nedan täcker det mesta av det dagliga \
                arbetet; resten slår ni upp när ni behöver den.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Öppna en fil"),
                HelpShortcut("⇧⌘O", "Öppna en hel mapp som arbetsyta"),
                HelpShortcut("⌘T", "Ny flik"),
                HelpShortcut("⌘S", "Spara"),
                HelpShortcut("⌘F", "Sök"),
                HelpShortcut("⌥⌘F", "Sök och ersätt"),
                HelpShortcut("⇧⌘F", "Sök i en mapp"),
                HelpShortcut("⌘D", "Lägg nästa förekomst till markeringen"),
                HelpShortcut("⌘L", "Gå till rad"),
                HelpShortcut("⌘/", "Kommentera raden med språkets egen syntax"),
                HelpShortcut("⌥⌘T", "Växla mellan tabell och text (CSV-filer)"),
                HelpShortcut("⌘?", "Öppna detta hjälpfönster igen"),
            ]),
            .heading("Tre saker som överraskar nykomlingar"),
            .bullets([
                "**En massåtgärd är ETT ångra-steg**, även om den rör en miljon rader. Fel sorterat? Ett `⌘Z` och det är borta.",
                "**Arbetspasset återställer sig självt.** Avsluta och öppna igen: flikarna kommer tillbaka på sina platser, även de osparade. Inget att trycka på.",
                "**Att skriva utan diakritiska tecken hittar ändå ord med dem** i varje sök- och filterfält — skriv `hue` och ni får `Huế`, `da nang` ger `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Vad vill ni göra?",
        summary: "En tabell som går från riktiga uppgifter till kapitlet som behandlar dem.",
        keywords: ["register", "slå upp", "hur gör man"],
        blocks: [
            .paragraph("""
                Innehållsförteckningen till vänster är ordnad efter **funktion**. Den här tabellen är \
                ordnad efter **uppgift**, eftersom de två ordningarna inte sammanfaller.
                """),
            .table(
                headers: ["Jag behöver…", "Se"],
                rows: [
                    ["Ändra samma ställe på hundratals rader", "Flera markörer · Blockmarkering"],
                    ["Formatera om i mängd med ett reguljärt uttryck", "Sök och ersätt · Reguljära uttryck"],
                    ["Upprepa en följd av handlingar", "Makron"],
                    ["Öppna en CSV som någon skickat mig", "CSV-tabellen"],
                    ["Städa en rörig tabell: blandade datum, tal som text", "Städflödet för data"],
                    ["Bedöma om en tabell går att lita på", "Kvalitetsbetyg för data"],
                    ["Hitta avvikelser, trender, grupper", "Utvinningsflödet för data"],
                    ["Ställa frågor i SQL", "Fråga CSV med SQL"],
                    ["Ge ut en rapport vars siffror uppdaterar sig", "`.greport.md`-rapporter"],
                    ["Rita ett schema i ett dokument", "Mermaid"],
                    ["Öppna en oläslig vietnamesisk fil", "Vietnamesiska teckenkodningar"],
                    ["Automatisera från skalet eller AppleScript", "Automatisering"],
                    ["Färglägga ett format som mitt företag hittat på", "Egendefinierade språk"],
                ]
            ),
            .note("""
                Står det inte med? Sökfältet uppe till vänster tittar i **brödtext och kodexempel**, så att \
                skriva en konfigurationsnyckel som `fail_under` leder till rätt sida.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Öppna stora filer",
        summary: "Varför 1 GB alls går att öppna, och var GEditor avstår med flit i stället för att gissa.",
        keywords: ["stor fil", "gigabyte", "logg", "mmap", "långsam", "prestanda"],
        blocks: [
            .paragraph("""
                Filen är **minnesavbildad** och läses genom ett glidande fönster; den del ni redigerar bor \
                i en piece table. I praktiken: öppningstiden beror knappt på filstorleken, och inte heller \
                det minne som tas i anspråk.
                """),
            .heading("Där den avstår med flit"),
            .paragraph("""
                Några beräkningar skulle behöva läsa hela filen till en enda sträng — precis det som denna \
                uppbyggnad undviker. Där **säger GEditor att den inte gör det** i stället för att tyst \
                kravla eller gissa:
                """),
            .table(
                headers: ["Åtgärd", "Tak", "Ovanför"],
                rows: [
                    ["Parentesmatchning", "1 MB", "Avstår och säger det — att markera fel par är värre än inget"],
                    ["Synlig kolumn i statusraden", "200 KB", "Faller tillbaka på att räkna byte och märker det med `~` så att innebörden syns"],
                    ["Markdown-förhandsvisning", "4 MB", "Avstår och förklarar"],
                ]
            ),
            .warning("""
                Ett tal som ser likadant ut men betyder något annat är det värsta slaget av fel. Därför står \
                det `~1234` och inte `1234` för en kolumn ovanför taket.
                """),
            .heading("Knep för loggfiler"),
            .bullets([
                "`Arkiv ▸ Följ fil (tail -f)` hämtar in det som skrivs i slutet. Dokumentet blir **skrivskyddat** medan följandet pågår — att skriva medan ny text strömmar in är två skrivare som slåss om ett dokument, och förloraren är alltid det ni just skrev.",
                "Loggrader **färgas efter allvarlighet** och går att filtrera efter nivå.",
                "**Dokumentkartan** (`⌥⌘M`) beskriver hela filen, inte bara det som syns på skärmen.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App Store-utgåvan mot direkt hämtning",
        summary: "Tre funktioner som bara den direkta utgåvan har, och varför.",
        keywords: ["app store", "sandlåda", "hämtning", "cli", "tillägg", "skillnad"],
        blocks: [
            .paragraph("""
                GEditor ges ut i två utgåvor. De kommer ur **samma källkod** och programmet känner vid \
                start igen vilken det är. Skillnaden ligger i vad App Sandbox tillåter.
                """),
            .table(
                headers: ["Funktion", "App Store", "Direkt hämtning"],
                rows: [
                    ["All redigering, CSV, städning, utvinning, rapporter", "Ja", "Ja"],
                    ["Kommandoradsverktyget `geditor`", "Nej", "Ja"],
                    ["Filtrera text genom ett yttre kommando", "Nej", "Ja"],
                    ["Inbyggda insticksmoduler (egen process)", "Nej", "Ja"],
                    ["Egen uppdatering", "Genom App Store", "I programmet"],
                ]
            ),
            .paragraph("""
                Varje «Nej» ovan kommer ur samma regel: sandlådan **förbjuder att köra kod utanför \
                programmet**. Det är priset för spridning via App Store, inte ett förbiseende.
                """),
            .note("""
                I App Store-utgåvan **står de kommandona kvar i menyn** och förklarar varför de inte är \
                tillgängliga, i stället för att försvinna. En saknad menypost blir en fråga till supporten; \
                ett svar på plats blir det inte.
                """),
            .heading("Filåtkomst i App Store-utgåvan"),
            .paragraph("""
                Sandlådeutgåvan rör bara filer som ni själva öppnat eller dragit in. GEditor behåller ett \
                **bokmärke med säkerhetsomfång** för varje flik och för arbetsytans mapp, så att ert \
                arbetspass öppnas igen efter avslut utan att fråga om lov på nytt.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Redigering

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Redigering",
        summary: "Ändra många ställen samtidigt, arbeta med rader, och de dolda reglerna som är värda att kunna först.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Flera markörer",
        summary: "Markera varje ställe som stämmer, skriv en gång, ändra dem alla.",
        keywords: ["flermarkör", "cmd+d", "flervalsmarkering"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Detta ersätter de flesta stunder då ni var på väg att skriva ett reguljärt uttryck. Markera \
                ett ord, tryck `⌘D` några gånger för att plocka upp följande förekomster, och skriv — alla \
                ställen ändras samtidigt.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Lägg nästa förekomst till markeringen"),
                HelpShortcut("⌘ + klick", "Sätt ytterligare en markör där ni klickar"),
                HelpShortcut("Esc", "Släpp dem alla, tillbaka till en markör"),
                HelpShortcut("⌥ + dragning", "Blockmarkering (ett annat sätt att få många markörer)"),
            ]),
            .heading("Regler värda att känna till"),
            .bullets([
                "Att skriva, radera och klistra in över många markörer är **ett** ångra-steg, inte ett per markör.",
                "Markörerna överlever piltangenterna — hela gruppen flyttar sig tillsammans.",
                "`⌘D` hoppar över ställen som redan finns i markeringen, så att trycka för många gånger staplar aldrig två markörer på varandra.",
            ]),
            .note("""
                `⌘D` på ett ord inne i en lång sträng var långsamt förr. Igenkänningen av ordgränser läser \
                nu i satser — omkring **42× snabbare** på en sträng på 1 MB, vilket gör detta användbart på \
                datafiler och inte bara på källkod.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Blockmarkering av kolumner",
        summary: "Markera en rektangel över många rader — med musen eller från tangentbordet.",
        keywords: ["kolumnläge", "block", "alt dragning", "rektangel", "tangentbord", "pilar"],
        blocks: [
            .paragraph("""
                Håll `⌥` och dra för att markera ett **rektangulärt block**. Skrivning, radering och \
                inklistring följer blocket. Att klistra in ett block vid en enda markör behåller dess \
                rektangel.
                """),
            .shortcuts([
                HelpShortcut("⌥ + dragning", "Markera ett block"),
                HelpShortcut("⌥⌘← →", "Vidga blocket en kolumn åt vänster/höger"),
                HelpShortcut("⌥⌘↑ ↓", "Sträck blocket en rad uppåt/nedåt"),
            ]),
            .paragraph("""
                Tangentbordsvägen är ingen nödlösning för musen: att markera ett block på 40 rader genom \
                dragning tvingar er att dra genom en rullning, medan `⌥⌘` + pilar behåller noggrannheten \
                kolumn för kolumn. Att trycka på **vilken annan** tangent som helst (eller skriva) avslutar \
                blocket ni höll på att sträcka ut.
                """),
            .heading("Kolumner här är SYNLIGA kolumner"),
            .paragraph("""
                En tabb sträcker sig till nästa stopp efter er tabbredd, i stället för att räknas som en \
                kolumn. Det är det som gör att rader indragna med tabbar och med blanksteg **ställer upp \
                sig så som de ser ut på skärmen**.
                """),
            .paragraph("Flerbytestext är fortfarande en kolumn: `Nguyễn` upptar sex kolumner, inte nio."),
            .table(
                headers: ["Läge", "Vad GEditor gör"],
                rows: [
                    ["Målkolumnen hamnar mitt i en tabb", "Fäster vid närmaste kant; vid lika åt vänster"],
                    ["En rad är kortare än startkolumnen", "Den raden bidrar med en tom markering och tar ändå emot skriven text"],
                    ["Klistra in ett block vid en enda markör", "Behåller rektangeln och infogar på raderna nedanför"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Kolumnredigeraren",
        summary: "Infoga text, en talserie eller en datumserie på varje rad i ett block.",
        keywords: ["kolumnredigerare", "numrering", "följd", "serie"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Markera ett kolumnblock och öppna `Redigera ▸ Kolumnredigeraren…` (`⌥⌘C`). Rutan har en \
                **förhandsvisning** innan något tillämpas.
                """),
            .table(
                headers: ["Läge", "Inställningar", "När"],
                rows: [
                    ["Text", "En fast sträng", "Lägga samma för-/eftertext på varje rad"],
                    ["Talserie", "Start · steg · bas 2·8·10·16 · inledande nollor", "Numrera rader, skapa koder"],
                    ["Datumserie", "Första datum · steg i dagar", "Skapa en kolumn med datum i följd"],
                ]
            ),
            .code(language: "text", caption: "Numrering med inledande nollor, start 1, steg 1",
                  source: """
                    Före:             Efter (talserie, 3 siffror):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Ett **negativt** steg är giltigt — att räkna baklänges fungerar.",
                "Att infoga i 5 000 rader är fortfarande **ett** ångra-steg.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Radåtgärder",
        summary: "Sortera, rensa dubbletter, flytta, foga samman, dela, dubblera, radera.",
        keywords: ["sortera", "dubblera", "foga samman", "dela", "flytta rad"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Med en markering verkar kommandot på markeringen; utan en verkar det på **hela \
                dokumentet**. Varje kommando här är ett enda ångra-steg.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Dubblera raden"),
                HelpShortcut("⌘K", "Radera raden"),
                HelpShortcut("⌥↑ / ⌥↓", "Flytta raden upp / ned"),
            ]),
            .heading("Tre sorters sortering, och vilken man väljer"),
            .table(
                headers: ["Sort", "`file2` mot `file10`", "För"],
                rows: [
                    ["A→Ö / Ö→A", "`file10` kommer före `file2`", "Enkla ordlistor"],
                    ["Naturlig", "`file2` kommer före `file10`", "Filnamn, kodade beteckningar, versioner"],
                ]
            ),
            .paragraph("""
                **Naturlig** sortering läser sifferföljder som tal. Det är nästan alltid det ni vill ha när \
                listan är numrerad.
                """),
            .heading("Rensa dubbletter"),
            .bullets([
                "**Hela dokumentet** — kastar varje rad som redan förekommit och behåller den första.",
                "**Bara intilliggande** — slår ihop lika grannrader, som `uniq` i Unix.",
            ]),
            .heading("Foga samman och dela"),
            .bullets([
                "**Foga samman rader** smälter de markerade raderna till en.",
                "**Dela efter längd** klipper långa rader vid ett givet antal tecken.",
                "**Dela efter tecken** klipper vid varje förekomst av ett tecken ni skriver — till exempel för att bryta upp en CSV-rad i dess celler.",
            ]),
            .note("""
                Att dubblera **sista raden** i en fil lägger till radbrytningen som saknas; att radera fram \
                till dokumentets slut sväljer också föregående rads radbrytning. Båda avviker från den \
                naiva lösningen, och båda finns för att filen inte ska sluta med en tom rad för mycket — \
                eller sakna den som behövdes.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Blanktecken och indrag",
        summary: "Rensa vilsna blanktecken, växla tabb ↔ blanksteg, och en inställning värd ett ögonblicks eftertanke.",
        keywords: ["blanktecken", "tabb", "indrag", "tomma rader"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Kommando", "Vad det gör"],
                rows: [
                    ["Ta bort tomma rader", "Kastar varje rad utan innehåll"],
                    ["Pressa ihop tomma rader i följd", "Flera tomma rader i rad blir en"],
                    ["Klipp blanktecken i radslutet", "Tar bort vilsna blanksteg och tabbar sist på varje rad"],
                    ["Tabb → Blanksteg", "Gör om tabbar till blanksteg vid gällande bredd"],
                    ["Blanksteg → Tabb", "Andra hållet"],
                ]
            ),
            .heading("Indrag per språk"),
            .paragraph("""
                Klicka på `Tab: 4` i statusraden. Menyns övre del ändrar det för **hela programmet**; den \
                nedre — `Bara för Go`, `Bara för Python`… — gäller enbart språket i den öppna filen och \
                minns om tabbar eller blanksteg ska användas.
                """),
            .paragraph("""
                Folk väljer inte indrag efter smak utan efter **gemenskapens sedvänja**: Go använder tabbar \
                (`gofmt` går före allt annat), Python fyra blanksteg enligt PEP 8, JavaScript och YAML \
                oftast två. Ett enda tal för alla språk gör att varje fil ni rör vid får rader ni aldrig \
                redigerat.
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
                Att ange det i `settings.json` fungerar också — nyckeln är språkkoden (`go`, `python`, \
                `javascript`…). Språk som saknas där använder den gemensamma `tabWidth`.
                """),
            .heading("Varför «klipp vid sparande» är AV som standard"),
            .paragraph("""
                Inställningen `Arkiv ▸ Klipp blanktecken i radslutet vid sparande` redigerar **rader ni \
                aldrig rört**. Påslagen som standard gör den en enordsrättelse i någon annans arkiv till en \
                diff på tusen rader, och granskaren hittar inte längre den verkliga ändringen.
                """),
            .paragraph("""
                När den är på är klippningen ett **eget ångra-steg** placerat före skrivningen — ett ångra \
                återför dokumentet till hur det var, utan att förlora det ni just sparade.
                """),
            .heading("Automatiskt indrag"),
            .bullets([
                "En ny rad ärver föregående rads indrag, plus en nivå efter ett öppnande tecken — `{` i klammerspråk, `:` i Python och YAML.",
                "Måttet är i **synliga kolumner**, så filer som blandar tabbar och blanksteg ligger ändå i linje på skärmen.",
                "Det finns **ingen** regel om att «skriva `}` drar in raden på nytt». Den regeln redigerar en rad ni redan gjort färdig, och den är det mest klagade beteendet i varje redigerare som har den.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Versaler och namnsedvänjor",
        summary: "Åtta omvandlingar, däribland camelCase, snake_case och kebab-case.",
        keywords: ["versaler", "gemener", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Tillämpas på markeringen. Alla bor i menyn `Format`."),
            .table(
                headers: ["Kommando", "`tổng doanh thu` blir"],
                rows: [
                    ["VERSALER", "`TỔNG DOANH THU`"],
                    ["gemener", "`tổng doanh thu`"],
                    ["Versal I Varje Ord", "`Tổng Doanh Thu`"],
                    ["Versal i meningens början", "`Tổng doanh thu`"],
                    ["Kasta om versaler", "Vänder varje tecken"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                De tre sista tar bort de vietnamesiska diakritiska tecknen, eftersom de skapar \
                **beteckningar i kod** — där bokstäver med tecken vanligen inte är tillåtna.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Kommentarer och parenteser",
        summary: "⌘/ använder varje språks eget tecken; ⌃⌘B hoppar till den matchande parentesen.",
        keywords: ["kommentar", "parentes", "cmd+/", "matchning"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` väljer kommentartecken **efter dokumentets språk**: `#` för Python, `//` för Rust och \
                C, `<!-- -->` för XML och HTML.
                """),
            .heading("Hela blocket går åt samma håll"),
            .paragraph("""
                Om en enda rad i blocket ännu är okommenterad kommenterar kommandot **allt**. Att avgöra \
                rad för rad skulle göra ett halvkommenterat block till ett schackbräde. Tecknet infogas vid \
                blockets grundaste indrag, så att blocket behåller sin form.
                """),
            .heading("Hoppa till den matchande parentesen"),
            .bullets([
                "`⌃⌘B` hoppar till den parentes som bildar par med den under markören.",
                "Parenteser inne i **strängar** eller **kommentarer** räknas inte — en lätt tolk skiljer dem åt.",
                "Ovanför **1 MB** avstår kommandot och säger det, i stället för att förankra sig halvvägs och gissa. Att markera fel par är värre än att inte markera något alls.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Ångra och urklipp",
        summary: "Obegränsad ångra-historik och ett urklipp med flera platser.",
        keywords: ["ångra", "gör om", "urklipp", "klistra in", "historik"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Ångra / Gör om"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Klipp ut / Kopiera / Klistra in"),
                HelpShortcut("⇧⌘V", "Urklippshistorik"),
            ]),
            .heading("En massåtgärd är ETT steg"),
            .paragraph("""
                Att sortera en miljon rader, ersätta tiotusen träffar, infoga i femtusen rader med \
                kolumnredigeraren — var och en av dem ångras med **ett** `⌘Z`.
                """),
            .paragraph("""
                Ångra-historiken bor i GEditors egen textbuffert och inte i systemets `UndoManager`, just \
                därför: `UndoManager` räknar tangenttryckningar.
                """),
            .heading("Urklippshistorik"),
            .paragraph("""
                `⇧⌘V` öppnar en lista över det ni kopierat nyligen och klistrar in den post ni väljer. \
                Bra när ni måste växla mellan två stycken på många ställen.
                """),
        ]
    )
}
