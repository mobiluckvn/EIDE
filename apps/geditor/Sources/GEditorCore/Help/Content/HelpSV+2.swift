import Foundation

/// Svenskt hjälpinnehåll — del 2: sökning, filer och arbetspass.
extension HelpSV {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Sökning",
        summary: "Söka, ersätta, reguljära uttryck, sökning över en mapp och radmarkeringar.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Sök och ersätt",
        summary: "Tre söklägen, och varför ^ betyder RADens början som standard.",
        keywords: ["söka", "ersätta", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Söka"),
                HelpShortcut("⌥⌘F", "Söka och ersätta"),
                HelpShortcut("⌘G / ⇧⌘G", "Nästa / föregående träff"),
            ]),
            .heading("Tre lägen"),
            .table(
                headers: ["Läge", "Förstår", "För"],
                rows: [
                    ["Vanligt", "Ren text, inga specialtecken alls", "De flesta sökningar"],
                    ["Utökat", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Att hitta radbrytningar, tabbar, bestämda byte"],
                    ["Regex", "Fullständig PCRE2", "Att söka efter mönster"],
                ]
            ),
            .note("""
                Det **utökade** läget förstår inte regex-syntax. Det tolkar bara några få \
                undantagsföljder — att söka efter `a.b` där hittar exakt de tre tecknen; punkten är inget \
                jokertecken.
                """),
            .heading("Två inställningar"),
            .bullets([
                "**Skilj på versaler och gemener** — av som standard.",
                "**Helt ord** — träffar bara när båda ändarna är ordgränser.",
            ]),
            .heading("`^` och `$` träffar vid varje RADs kanter"),
            .paragraph("""
                På som standard. Den som kommer från Notepad++ väntar sig att `^` betyder «radens början»; \
                utan det skulle `^abc` bara träffa om hela dokumentet började med `abc` — nästan ingen vill \
                ha det i en textredigerare.
                """),
            .heading("Ett dåligt uttryck låser inte programmet"),
            .paragraph("""
                Motorn är **PCRE2 med JIT-kompilering** och har en budget för bakåtspårning. Ett mönster \
                som växer explosionsartat stoppas och rapporteras i stället för att frysa fönstret.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Reguljära uttryck",
        summary: "Den PCRE2-syntax man verkligen använder, med exempel som körs på vietnamesiska data.",
        keywords: ["regex", "pcre", "mönster"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor använder **PCRE2**, samma motor som PHP och många kommandoradsverktyg. Öppna `Sök ▸ \
                Pröva reguljärt uttryck…` för att pröva ett mönster mot exempeltext och se vad varje grupp \
                fångar **innan** ni släpper det på ett riktigt dokument.
                """),
            .heading("Teckenklasser"),
            .table(
                headers: ["Skriv", "Träffar"],
                rows: [
                    ["`.`", "Vilket tecken som helst utom radbrytning"],
                    ["`\\d` · `\\D`", "En siffra · inte en siffra"],
                    ["`\\w` · `\\W`", "Ett ordtecken (bokstav, siffra, `_`) · motsatsen"],
                    ["`\\s` · `\\S`", "Blanktecken · inte blanktecken"],
                    ["`[abc]`", "Ett av tecknen inom hakparenteserna"],
                    ["`[^abc]`", "Ett tecken som INTE står inom hakparenteserna"],
                    ["`[a-z]`", "Ett tecken ur intervallet"],
                ]
            ),
            .heading("Upprepning"),
            .table(
                headers: ["Skriv", "Betydelse"],
                rows: [
                    ["`*`", "Noll eller fler"],
                    ["`+`", "En eller fler"],
                    ["`?`", "Noll eller en"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Exakt 3 · mellan 2 och 5 · 2 eller fler"],
                    ["`*?` `+?` `??`", "De **lata** formerna — ta så lite som möjligt"],
                ]
            ),
            .warning("""
                `.*` är **girigt**: det äter till radens slut och backar sedan. När ni delar upp fält inom \
                en rad behöver ni nästan alltid `.*?` eller en snäv klass som `[^,]*`.
                """),
            .heading("Ankare och grupper"),
            .table(
                headers: ["Skriv", "Betydelse"],
                rows: [
                    ["`^` · `$`", "Radens början · radens slut"],
                    ["`\\b`", "Ordgräns"],
                    ["`(…)`", "En **fångande** grupp — går att återanvända i ersättningen"],
                    ["`(?:…)`", "Icke-fångande grupp"],
                    ["`(?<name>…)`", "Namngiven grupp"],
                    ["`a|b`", "a eller b"],
                    ["`(?=…)` · `(?!…)`", "Framåtblick: måste följa · får inte följa"],
                    ["`(?<=…)` · `(?<!…)`", "Bakåtblick: måste föregå · får inte föregå"],
                ]
            ),
            .heading("Exempel som fungerar"),
            .code(language: "regex", caption: "Varje tiosiffrigt vietnamesiskt telefonnummer",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Dela ett datum 31/12/2026 i tre grupper",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "Tredje cellen i en enkel CSV-rad (utan citattecken)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Loggrader med ERROR eller FATAL, med tidsstämpel",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Tomma rader, eller rader med bara blanktecken",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Vietnamesiska bokstäver med tecken — använd Unicode-klassen, räkna dem inte upp",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` betyder «vilken Unicode-bokstav som helst», så det fångar även `ế` och `đ`. Att \
                räkna upp varje vokal med tecken för hand är det säkra sättet att missa några.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Ersättningssträngar",
        summary: "Återanvända fångade grupper och ändra versaler under ersättningen.",
        keywords: ["ersätta", "bakåtreferens", "grupp", "$1", "\\U"],
        blocks: [
            .heading("Kalla på en fångad grupp"),
            .table(
                headers: ["Skriv", "Betydelse"],
                rows: [
                    ["`$1` … `$9`", "Innehållet i grupp n"],
                    ["`${1}`", "Detsamma med tydliga gränser — använd det när en siffra följer"],
                    ["`\\1`", "Godtas också; GEditor skriver om det till `${1}`"],
                    ["`$0`", "Hela träffen"],
                ]
            ),
            .note("""
                Skriv `${1}` i stället för `$1` när nästa tecken är en siffra. `$123` läses som grupp 123; \
                `${1}23` är grupp 1 följd av två siffror.
                """),
            .heading("Ändra versaler under en ersättning"),
            .table(
                headers: ["Skriv", "Betydelse"],
                rows: [
                    ["`\\U`", "VERSALER härifrån"],
                    ["`\\L`", "gemener härifrån"],
                    ["`\\u`", "Bara nästa tecken som versal"],
                    ["`\\l`", "Bara nästa tecken som gemen"],
                    ["`\\E`", "Slut på `\\U`- eller `\\L`-området"],
                ]
            ),
            .heading("Exempel"),
            .code(language: "text", caption: "Gör om 31/12/2026 till 2026-12-31",
                  source: """
                    Sök:     (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Ersätt:  $3-$2-$1
                    """),
            .code(language: "text", caption: "Versalisera provinskoden i radens början, behåll resten",
                  source: """
                    Sök:     ^([a-z]{2,3})(\\s)
                    Ersätt:  \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Svep varje rad som en JSON-sträng",
                  source: """
                    Sök:     ^(.+)$
                    Ersätt:  "$1",
                    """),
            .paragraph("""
                En grupp som **inte deltog** i träffen blir en tom sträng, inte ett fel — så ett mönster med \
                alternativ som `(a)|(b)` ersätter rent utan att skrivas två gånger.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Söka och ersätta över en mapp",
        summary: "Gå igenom många filer samtidigt och se resultaten innan något skrivs.",
        keywords: ["söka i filer", "grep", "massersättning", "mapp"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Söka i en mapp")]),
            .paragraph("""
                Välj rotmappen, filtrera efter filnamnsmönster och gå igenom. Resultaten visas grupperade \
                per fil; att klicka på en rad öppnar den filen på den platsen.
                """),
            .bullets([
                "Samma tre söklägen och samma regex-motor som sökfältet i dokumentet.",
                "Ersättning över en mapp **förhandsvisar** hur många filer och hur många träffar som kommer att ändras innan något skrivs.",
                "Genomgången löper parallellt och **går att avbryta** halvvägs.",
            ]),
            .warning("""
                Ersättning över en mapp skriver rakt in i filer som **inte är öppna**. De filerna finns inte \
                i det öppna dokumentets ångra-historik — se förhandsvisningen först och ha en säkerhetskopia \
                eller ett versionshanterat arkiv.
                """),
            .heading("Tidigare sökningar och att exportera resultat"),
            .paragraph("""
                Resultatpanelen **behåller det här arbetspassets sökningar**. Menyn högst upp räknar upp dem \
                med antal träffar — sök `TODO`, läs halvvägs, sök `FIXME` för att jämföra och gå tillbaka \
                till första listan utan att gå igenom hela mappen på nytt.
                """),
            .paragraph("""
                Knappen **Exportera** öppnar den aktuella sökningen som en textflik, ett resultat per rad i \
                formen `sökväg:rad:kolumn: text` — samma form som `grep -n` använder och som kompilatorer \
                använder för fel. Varje rad klistras rakt in i det här programmets eget `Gå till`-fält, och \
                era `grep`, `awk` och `sed` läser den utan egen tolk.
                """),
            .note("""
                Historiken bor **i minnet** och skrivs aldrig till disk: sökresultaten bär innehållet i \
                varje träffad rad, alltså samma slags uppgifter som urklippshistoriken med flit inte sparar.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Radmarkeringar",
        summary: "Nio markeringsfärger och fyra kommandon som gör markerade rader till ett resultat.",
        keywords: ["bokmärke", "markering", "f2", "filtrera rader"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Att markera är sättet att filtrera ett dokument **utan att ändra det**. Markera varje rad \
                som stämmer med ett mönster och kopiera sedan bara dem, eller behåll bara dem.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Markera varje rad som stämmer med den aktuella sökningen"),
                HelpShortcut("⌘F2", "Markera / avmarkera aktuell rad"),
                HelpShortcut("F2 / ⇧F2", "Gå till nästa / föregående markering"),
            ]),
            .heading("Ett vanligt förlopp"),
            .steps([
                "`⌘F` med mönstret ni vill filtrera på, t.ex. `\\bERROR\\b`.",
                "`⌘M` markerar varje träffad rad.",
                "`Sök ▸ Kopiera markerade rader` drar dem till en ny flik — eller `Behåll bara markerade rader` filtrerar på plats.",
            ]),
            .heading("Nio färger"),
            .paragraph("""
                En rad kan bära **flera färger samtidigt**. Använd olika färger för olika villkor och \
                kombinera dem: rött för felrader, gult för rader med samma ordernummer, och leta sedan efter \
                rader som bär båda.
                """),
            .bullets([
                "`Kasta om markeringar` — markerade rader blir omarkerade och tvärtom.",
                "`Rensa alla markeringar` — tar bort varje markering utan att röra innehållet.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Gå till rad",
        summary: "Hoppa till en rad, en kolumn eller en byteposition.",
        keywords: ["gå till", "radnummer", "cmd+l", "position", "kolumn"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Gå till rad")]),
            .paragraph("""
                Fältet förstår **tre skrivsätt** och skiljer dem åt utifrån vad ni skriver — det finns ingen \
                extra väljare att klicka på.
                """),
            .table(
                headers: ["Skriv", "Går till"],
                rows: [
                    ["`120`", "början av rad 120"],
                    ["`120,5` eller `120:5`", "rad 120, kolumn 5 — kolumnen räknar TECKEN"],
                    ["`@1024`", "byteposition 1024 i filen"],
                ]
            ),
            .note("""
                `rad:kolumn` är precis så kompilatorer och luddare skriver ut en position, så en rad ni just \
                kopierat från en terminal klistras in som den är.

                `@` för bytepositioner har ett skäl: är `1234` en rad eller en byte? Det finns inget rätt \
                svar, och att gissa fel skickar markören någon helt annanstans utan minsta signal. Den \
                bytesiffran är också det som statusraden visar i positionsdelen (`@1024`): det ni läser där \
                kan ni skriva här.
                """),
            .bullets([
                "En kolumn **bortom radens längd** stannar vid radens slut; den rinner inte över till nästa.",
                "En byteposition **bortom filen** för er till slutet — den siffran kommer oftast från en tidigare körning, och filen kan ha krympt.",
                "Text den inte kan tyda **rapporteras**, och markören står kvar; den hoppar inte till filens början.",
            ]),
            .paragraph("""
                I mycket stora filer läser GEditor inte hela filen för att ta sig dit — radregistret byggs \
                undan för undan i bakgrunden.
                """),
            .note("""
                Kommandoradsverktyget tar också en position: `geditor rapport.csv:120:5` öppnar filen med \
                markören på rad 120, kolumn 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Filer och arbetspass

    static let files = HelpChapter(
        id: "tep",
        title: "Filer och arbetspass",
        summary: "Öppna, spara, flikar, fönster, arbetsytor och hur arbetspasset kommer tillbaka.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Öppna och spara",
        summary: "Öppna en fil av vilken storlek som helst och spara den med annan teckenkodning eller radbrytning.",
        keywords: ["öppna", "spara", "dubblera", "byta namn", "flytta"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Nytt dokument"),
                HelpShortcut("⌘O", "Öppna en fil"),
                HelpShortcut("⌘S", "Spara"),
                HelpShortcut("⇧⌘S", "Spara som"),
            ]),
            .paragraph("""
                Att dra en fil till fönstret öppnar den också. `Arkiv ▸ Öppna senaste` behåller listan över \
                filerna ni nyss arbetade med.
                """),
            .heading("Spara som: tre saker ni kan ändra"),
            .table(
                headers: ["Ändring", "Betydelse"],
                rows: [
                    ["Teckenkodning", "Skriva i UTF-8, TCVN3, VNI-Windows… — 36 kodningar"],
                    ["Radbrytningar", "LF (Unix) · CRLF (Windows) · CR (klassisk Mac)"],
                    ["Namn och plats", "Som i varje spara-ruta i macOS"],
                ]
            ),
            .paragraph("""
                Statusraden visar alltid teckenkodning, radbrytningsstil och det språk som känts igen. **Att \
                klicka på någon av dem ändrar den genast**, utan att gå via en dialogruta.
                """),
            .heading("Dubblera · byt namn · flytta"),
            .paragraph("""
                Dessa tre verkar på FILEN och inte på dess innehåll — och den öppna fliken följer med filen, \
                så ni tappar aldrig er plats.
                """),
            .table(
                headers: ["Kommando", "Vad det gör"],
                rows: [
                    ["`Dubblera fil`",
                     "Kopierar den som `namn 2.txt` bredvid originalet och **öppnar kopian** — för man dubblerar för att redigera kopian"],
                    ["`Byt namn på fil…`", "Byter namn på disken; fliken följer det nya namnet"],
                    ["`Flytta fil till…`", "Flyttar till en annan mapp; fliken följer med"],
                ]
            ),
            .note("""
                Alla tre **avstår om det redan finns en fil med det namnet** på målplatsen; de skriver aldrig \
                över. Och alla tre kräver en fil som sparats minst en gång — ett dokument som aldrig legat på \
                disk har inget att dubblera eller flytta.
                """),
            .heading("Säker skrivning"),
            .bullets([
                "Skrivningen är **odelbar**: ett strömavbrott halvvägs lämnar aldrig en avhuggen fil.",
                "Om ett annat program ändrar filen medan ni har den öppen märker GEditor det och frågar innan den skriver över.",
                "Filer på iCloud Drive eller en nätverksvolym går via systemets filsamordnare, så att två maskiner inte trampar på varandra.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Flikar, fönster och delad vy",
        summary: "Många flikar per fönster, många fönster, och flikar man kan dra mellan dem.",
        keywords: ["flik", "fönster", "dela", "ruta"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Ny flik"),
                HelpShortcut("⌘W", "Stäng flik"),
                HelpShortcut("⇧⌘T", "Öppna den senast stängda fliken igen"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Nästa / föregående flik"),
                HelpShortcut("⌥⌘N", "Nytt fönster"),
                HelpShortcut("⌃⌘N", "Lossa aktuell flik till ett eget fönster"),
            ]),
            .paragraph("""
                Ni kan dra en flik till ett annat fönster, eller släppa den på tom yta för att skapa ett \
                fönster. **En fastnålad flik reser inte** — att nåla fast betyder «låt den här vara kvar».
                """),
            .note("""
                `⇧⌘T` öppnar den senast stängda fliken igen, även en **osparad**: dess innehåll finns kvar.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Öppna en mapp som arbetsyta",
        summary: "Ett filträd i sidopanelen, sökning i hela projektet och öppning med ett klick.",
        keywords: ["arbetsyta", "mapp", "projekt", "sidopanel"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Öppna en mapp som arbetsyta")]),
            .paragraph("""
                Trädet syns i sidopanelen (`⌘0`). Klicka på en fil för att öppna den, och `⇧⌘F` söker i hela \
                mappen.
                """),
            .note("""
                I App Store-utgåvan hålls åtkomsten till mappen av ett **bokmärke med säkerhetsomfång**, så \
                nästa start når den ändå utan att be er välja mappen på nytt.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "Arbetspasset återställer sig självt",
        summary: "Avsluta och öppna igen: varje flik kommer tillbaka, även de osparade.",
        keywords: ["arbetspass", "återställa", "osparat", "återfå"],
        blocks: [
            .paragraph("""
                Inget att slå på. Avsluta GEditor och öppna den igen: flikarna, deras ordning, markörens och \
                rullningens lägen kommer alla tillbaka.
                """),
            .heading("Och de osparade flikarna"),
            .paragraph("""
                Deras innehåll hålls i en egen ögonblicksbild, så de kommer också tillbaka. Slutar programmet \
                onormalt **frågar** nästa start innan föräldralösa utkast återställs — i stället för att tyst \
                bygga upp en hög flikar ni inte minns.
                """),
            .warning("""
                Ett arbetspass **är ingen säkerhetskopia**. Det bevarar arbetsläget, inte historiken. Allt \
                som betyder något måste ändå sparas till en fil.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Tidigare sparade versioner",
        summary: "Bläddra bland och återställa äldre versioner av en fil.",
        keywords: ["versioner", "historik", "återställa", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Vid varje sparande antecknar GEditor den **föregående** versionen innan den skriver över. \
                `Makro ▸ Sparade versioner…` öppnar bläddraren för dem.
                """),
            .bullets([
                "Versionslagret är **operativsystemets**, samma mekanism som Apples egna program använder.",
                "Att återställa en äldre version är en **vanlig redigering** — `⌘Z` ångrar den.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Följa en fil som fortfarande skrivs",
        summary: "Som `tail -f`: det som läggs till visas allteftersom det kommer.",
        keywords: ["tail", "följa", "logg", "i realtid"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Arkiv ▸ Följ fil (tail -f)` läser in det som dyker upp i filens slut och rullar med.
                """),
            .warning("""
                Medan följandet pågår blir dokumentet **skrivskyddat**. Att skriva medan ny text läses in \
                från disken är två skrivare som slåss om ett dokument, och förloraren är alltid det ni just \
                skrev.
                """),
            .note("""
                Statusraden säger **Följer** hela tiden, så några minuter senare vet ni fortfarande varför \
                filen inte tar emot skrift. Att klicka på delen **skrivskyddad** ger skälet rakt ut.

                Följandet hör till **den flik som startade det**, inte till fönstret: öppna en annan flik och \
                skriv vidare, så fortsätter nya loggrader att strömma in i sin egen flik utan att röra filen \
                ni redigerar.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Utskrift",
        summary: "Skriva ut genom macOS vanliga utskriftsruta.",
        keywords: ["skriva ut", "papper", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Skriva ut")]),
            .paragraph("""
                Den använder systemets utskriftsruta, så export till PDF sker också där — knappen `PDF` nere \
                till vänster.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Bilder, PDF, Office-filer, ljud, video och arkiv",
        summary: "Åtta slags filer öppnas inne i GEditor utan något annat program.",
        keywords: ["bild", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "arkiv",
                   "ljud", "video"],
        blocks: [
            .table(
                headers: ["Slag", "Vad ni kan göra"],
                rows: [
                    ["Bilder", "Se, zooma, vrida; **rörliga bilder spelas upp** och går att pausa"],
                    ["Ljud", "Spela, spola, ändra volym"],
                    ["Video", "Spela, spola, helskärm, bild-i-bild"],
                    ["PDF", "Läsa, söka, **anteckna**"],
                    ["Word · Excel · PowerPoint", "Se **och redigera** — `⌘S` skriver rakt tillbaka i filen"],
                    ["ZIP · TAR · GZ · XZ", "Räkna upp poster och öppna var och en som en flik"],
                    ["7z · RAR och sju format till", "Detsamma, via libarchive"],
                ]
            ),
            .paragraph("""
                Att öppna en post i ett arkiv skapar en flik med dess innehåll. De vietnamesiska tecknen \
                överlever både i namn och i innehåll.
                """),
            .note("""
                Redigera ett av de tre Office-formaten, tryck `⌘S`, och det skrivs tillbaka i filen — \
                LibreOffice läser resultatet. Den vägen är prövad från början till slut, inte bara exporterad \
                till en kopia.
                """),
            .heading("Ljud och video använder macOS spelare"),
            .paragraph("""
                Uppspelningen går genom systemets avkodare, så inget extra hämtas och inget extra levereras. \
                I gengäld **spelas några format inte** — `.mkv`, `.webm`, `.avi`, `.wmv` — eftersom macOS \
                saknar inbyggd avkodare för dem.
                """),
            .paragraph("""
                För en sådan fil **säger GEditor varför** i stället för att visa en svart rektangel, och \
                erbjuder den binära vyn eller ett annat program.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "PDF-verktyg",
        summary: "Läsa, anteckna och ett helt sidlager: vrida · flytta · radera · plocka ut · slå ihop.",
        keywords: ["pdf", "sida", "vrida", "radera sida", "plocka ut", "slå ihop",
                   "anteckna", "markera", "signera"],
        blocks: [
            .paragraph("""
                PDF-vyn har **två verktygsrader**, som svarar på olika frågor. Den övre raden verkar på \
                **innehållet** i en sida; den nedre på **mängden sidor**.
                """),
            .heading("Övre raden — läsa och anteckna"),
            .table(
                headers: ["Knapp", "Vad den gör"],
                rows: [
                    ["Markera · Stryk under", "Märka den markerade texten"],
                    ["Anteckning…", "Fästa en anteckning på sidan"],
                    ["Ta bort anteckningar", "Ta bort varje anteckning från aktuell sida"],
                    ["Plocka ut texten till en flik", "Föra all text till en flik för att söka, filtrera, använda andra verktyg"],
                    ["Sökfält", "Söka inne i PDF:en — **att skriva utan tecken hittar ändå text med dem**"],
                ]
            ),
            .note("""
                En inskannad PDF har inget textlager. Uttagskommandot **säger det** i stället för att öppna \
                en tom flik och låta er gissa.
                """),
            .heading("Nedre raden — sidåtgärder"),
            .table(
                headers: ["Knapp", "Vad den gör", "Går att ångra"],
                rows: [
                    ["Vrid vänster · höger", "Vrida aktuell sida 90°", "Ja"],
                    ["Sida upp · ned", "Byta plats på aktuell sida och grannen", "Ja"],
                    ["Radera sidor…", "Radera efter intervall, t.ex. `2-4,7`", "Ja"],
                    ["Plocka ut sidor…", "Skriva ett sidintervall som en **ny fil**", "Rör inte den öppna filen"],
                    ["Slå ihop en PDF…", "Foga in en annan PDF direkt efter aktuell sida", "Ja"],
                    ["Signera…", "Placera en signaturbild på aktuell sida", "Ja"],
                    ["Redigera text…", "Rita ersättningstext över markeringen", "Ja"],
                    ["Nästa tomma fält", "Hoppa till nästa ifyllningsbara fält som är tomt", "—"],
                    ["Rensa ifyllda värden", "Tömma varje formulärfält", "Ja"],
                    ["Ångra sidändring", "Backa en sidåtgärd", "—"],
                    ["Spara den redigerade kopian…", "Skriva en ny fil och sedan **öppna den igen för att kontrollera**", "—"],
                ]
            ),
            .heading("Ifyllningsbara formulär"),
            .paragraph("""
                Öppna en PDF med formulärfält, så säger statusraden **hur många** de är. Skriv rakt i fälten \
                på sidan och därefter `Spara den redigerade kopian…`.
                """),
            .bullets([
                "Värdena sparas som **levande formulärfält**, inte som utplattad text — så mottagarens Acrobat ser fortfarande ett ifyllt formulär och kan rätta det.",
                "De vietnamesiska tecknen överlever varvet skriva-och-öppna-igen. Ett prov vaktar just det, med namnet `Nguyễn Văn Anh`.",
                "`Nästa tomma fält` hoppar till nästa tomma — den naturliga vägen genom ett långt formulär.",
            ]),
            .heading("Att signera"),
            .paragraph("""
                Gör i ordning en signaturbild (en PNG med genomskinlig bakgrund passar bäst), **markera \
                stället där ni ska signera** — oftast linjen eller ordet «Signatur» — och tryck `Signera…`. \
                Utan markering hamnar signaturen nere till höger.
                """),
            .note("""
                Signaturen behåller bildens **proportioner**: en hoptryckt eller utdragen signatur ser \
                omedelbart falsk ut.
                """),
            .heading("Att redigera text — och tre saker att veta först"),
            .paragraph("""
                Markera texten som ska ändras och tryck `Redigera text…`. GEditor **täcker det området med \
                en bakgrundsfärg tagen alldeles bredvid** och ritar den nya texten ovanpå.
                """),
            .warning("""
                **Den gamla texten är TÄCKT, inte BORTTAGEN.** Den finns kvar i filen och går fortfarande \
                att plocka ut med `Plocka ut texten till en flik` eller något annat verktyg. Detta är **ingen \
                maskering**: att dölja ett personnummer så här döljer det för ett mänskligt öga, inte för en \
                maskin.
                """),
            .bullets([
                "**Den nya texten går fortfarande att hitta med `⌘F`.** Den ritas som riktig text, inte som en bild — mätt av ett prov, inte antaget.",
                "**Teckensnittet är ett systemsnitt**, inte dokumentets eget. Med flit: teckensnitt inbäddade i en PDF saknar ofta de vietnamesiska tecknen, och `Nguyễn` skulle komma fram som `Nguy?n`.",
                "**Mot en mönstrad bakgrund syns lappen** — täckfärgen tas i en enda punkt strax till vänster om markeringen.",
            ]),
            .heading("Varför man målar över i stället för att redigera innehållsströmmen"),
            .paragraph("""
                Att redigera en PDF:s innehållsström direkt betyder att man tampas med delmängdssnitt som bär \
                sin egen kodning, meningar som kerningen brutit i tre bitar, och tabeller över teckenbredder \
                som måste räknas om. Att göra det rätt för **varje** fil är ett eget projekt; att göra det \
                fel förstör någons dokument.
                """),
            .paragraph("""
                I gengäld ändras resten av sidan **inte med en enda byte**, och sidan förblir en sida — \
                texten går fortfarande att markera, kopiera och söka i. Att rita om gör den **inte** till en \
                bild.
                """),
            .heading("Syntax för sidintervall"),
            .table(
                headers: ["Skriv", "Betydelse"],
                rows: [
                    ["`5`", "Bara sida 5"],
                    ["`2-4`", "Sidorna 2, 3, 4"],
                    ["`-3`", "Från början till sida 3"],
                    ["`8-`", "Från sida 8 till slutet"],
                    ["`1-3,5,9-`", "Flera delar sammanfogade med kommatecken"],
                ]
            ),
            .paragraph("Sidorna räknas **från 1**, det tal ni ser på skärmen."),
            .warning("""
                Ett omvänt intervall (`5-2`) och ett intervall bortom slutet (`1-999`) **avvisas båda med \
                ett skäl**, aldrig tyst rättade till något närliggande. I ett kommando som raderar sidor \
                betyder en felgissning förlorade sidor, och tyst beskärning gör ett skrivfel till ett giltigt \
                kommando.
                """),
            .heading("Originalfilen skrivs aldrig över"),
            .paragraph("""
                Allt ovan ändrar dokumentet **i minnet**. Först när ni trycker `Spara den redigerade \
                kopian…` och väljer en plats skrivs en fil — och efter skrivningen **öppnar GEditor just den \
                filen igen** för att bekräfta att den fortfarande har alla sina sidor.
                """),
            .paragraph("""
                Skälet: en illa skriven fil ligger på disken och ser fullkomligt normal ut, och användaren \
                märker det först efter att ha skickat den.
                """),
            .note("""
                Vyns statusrad säger **· redigerad, inte sparad** så snart dokumentet skiljer sig från filen \
                på disken.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
