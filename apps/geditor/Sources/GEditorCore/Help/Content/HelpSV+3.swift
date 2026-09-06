import Foundation

/// Svenskt hjälpinnehåll — del 3: sätt att se, vietnamesiska, språk och format.
extension HelpSV {

    static let views = HelpChapter(
        id: "xem",
        title: "Sätt att se ett dokument",
        summary: "Sidopanel, karta, hopfällning, delad vy, radbrytning, osynliga tecken, färglägen.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Sidopanel och funktionslista",
        summary: "Filträdet och den öppna filens funktionslista, i samma spalt.",
        keywords: ["sidopanel", "funktionslista", "disposition", "filträd"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Visa / dölja sidopanelen")]),
            .paragraph("""
                Funktionslistan byggs ur språkets **syntaxträd**, så den följer den verkliga uppbyggnaden i \
                stället för att gissa den ur indragen. Klicka på en post för att hoppa dit.
                """),
            .note("Listans filterfält **hittar text med tecken fast ni skriver utan dem**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Dokumentkartan",
        summary: "Hela filen i en smal spalt till höger — även vid hundratals MB.",
        keywords: ["minikarta", "karta", "överblick"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Visa / dölja dokumentkartan")]),
            .paragraph("""
                Kartan beskriver **hela filen**, inte bara det som är på skärmen. Att dra på den hoppar till \
                motsvarande område.
                """),
            .paragraph("""
                Sökträffar och markerade rader syns på kartan, så ni ser om de är utspridda eller samlade \
                innan ni rullar dit.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Hopfällning",
        summary: "Fäll ihop funktioner, block och listor efter uppbyggnad — eller fäll hela filen till en nivå.",
        keywords: ["fälla ihop", "code folding", "fälla in"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Fäll ihop / fäll ut blocket vid markören"),
                HelpShortcut("⌥⇧⌘←", "Fäll ihop allt"),
                HelpShortcut("⌥⌘→", "Fäll ut allt"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Fäll hela filen till nivå 1…8"),
            ]),
            .paragraph("""
                För språk med syntaxträd följer hopfällningen den **verkliga uppbyggnaden**. För filer utan \
                grammatik följer den indragen.
                """),
            .paragraph("""
                `Fäll till nivå` gör verklig nytta på djup JSON och YAML: fällt till nivå 2 ryms hela filens \
                form på en skärm.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Delad vy",
        summary: "Två rutor sida vid sida, för två filer — eller två ställen i samma fil.",
        keywords: ["dela", "rutor", "jämföra"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Dela lodrätt"),
                HelpShortcut("⌥⌘-", "Dela vågrätt"),
                HelpShortcut("⌥⌘0", "Ta bort delningen"),
                HelpShortcut("⌥⌘]", "Öppna denna flik i den andra rutan"),
                HelpShortcut("⌥⌘[", "Hoppa till den andra rutan"),
            ]),
            .paragraph("""
                Varje ruta har sin egen flikrad. Att öppna **samma fil** i båda går alldeles utmärkt — de \
                rullar oberoende av varandra, vilket gör det lätt att jämföra början och slutet av en fil.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Automatisk radbrytning",
        summary: "Tre lägen: av, vid fönsterkanten, eller vid en fast kolumn.",
        keywords: ["radbrytning", "mjuk brytning"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Läge", "En lång rad"],
                rows: [
                    ["Av", "Rullar i sidled"],
                    ["Vid fönstret", "Bryts vid fönsterkanten och följer dess storlek"],
                    ["Vid en kolumn", "Bryts vid den kolumn ni anger — säg 80 eller 100"],
                ]
            ),
            .paragraph("""
                Radbrytning är ett **sätt att se**, inte en ändring: ingen radbrytning infogas, och den \
                hamnar aldrig i ångra-historiken.
                """),
            .note("Den snabba vägen är delen `Ngắt: …` i statusraden."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Teckenstorlek",
        summary: "Zooma mellan 8 och 32 pt.",
        keywords: ["zoom", "storlek", "större", "mindre"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Större"),
                HelpShortcut("⌘-", "Mindre"),
                HelpShortcut("⌃⌘0", "Tillbaka till standardstorleken"),
            ]),
            .paragraph("""
                Begränsat mellan 8 och 32 pt. Även detta är ett **sätt att se**: ingen ändring, inget i \
                ångra-historiken. Standardstorleken bor i `Inställningar…`.
                """),
            .note("`⌘0` är **inte** standardstorleken — den tangenten visar och döljer sidopanelen."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Visa osynliga tecken",
        summary: "En grupp i taget, för allihop på en gång är oftast för mycket.",
        keywords: ["osynlig", "blanktecken", "nbsp", "nollbredd", "tabb"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Visa / dölja alla osynliga tecken")]),
            .paragraph("""
                Fyra grupper slås på var för sig, för att tända dem allihop på en gång begraver innehållet \
                under en skog av prickar.
                """),
            .table(
                headers: ["Grupp", "Vad den fångar"],
                rows: [
                    ["Blanksteg", "Blanksteg i radslutet, ojämna indrag"],
                    ["Tabbar", "Filer som blandar tabbar med blanksteg"],
                    ["Radbrytningar", "Filer som blandar CRLF med LF"],
                    ["NBSP · nollbredd · styrtecken", "Osynliga tecken från Word, från webben, från kalkylblad"],
                ]
            ),
            .warning("""
                Den sista gruppen är den som räddar folk. Ett hårt blanksteg (NBSP) inklistrat från en \
                webbsida ser **exakt** ut som ett vanligt blanksteg, och ändå får det varje strängjämförelse \
                och varje filter att missa — och det går inte att se utan att den gruppen är på.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV-läge och loggläge",
        summary: "Två färgläggningar som ersätter syntaxfärgning, för två slags datafiler.",
        keywords: ["csv-läge", "loggläge", "färgning", "kolumner", "nivå"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV-läge"),
            .paragraph("""
                Ger varje kolumn en egen färg i **textvyn**, så att ni ser vilken cell som glidit en kolumn \
                utan att byta till tabellen.
                """),
            .heading("Loggläge"),
            .paragraph("""
                Färgar efter den **allvarlighet** den läser ur raden: fel i rött, varningar i bärnsten, \
                medan `debug` och `trace` dämpas — de utgör större delen av en logg, och att lyfta fram dem \
                dämpar just det ni letar efter.
                """),
            .paragraph("`Filtrera logg efter nivå…` döljer helt de nivåer ni inte behöver."),
            .note("""
                Dessa två färgar **i stället för** syntaxfärgningen, inte ovanpå den. En logg har ingen \
                syntax att färga, och två färgkällor som skriver i samma byteområde lämnar ingen förutsägbar \
                vinnare.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Binär vy",
        summary: "En hex-tabell för vilken fil som helst — även en på 1 GB, som öppnas nästan genast.",
        keywords: ["hex", "binär", "byte", "position", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Visa ▸ Binär vy` visar varje byte som en tabell med tre spalter: **position · hex · text**. \
                Det fungerar för **vilken** fil som helst på disken, inte bara bilder eller video.
                """),
            .table(
                headers: ["Spalt", "Innehåll"],
                rows: [
                    ["Position", "Bytens position, i hexadecimal form"],
                    ["Hex", "16 byte per rad, delade efter den åttonde för att lättare räknas"],
                    ["Text", "Utskrivbara ASCII-byte; allt annat blir en `.`"],
                ]
            ),
            .note("""
                Textspalten **avkodar inte UTF-8**. En vietnamesisk bokstav tar två eller tre byte, så att \
                visa den skulle skjuta textspalten ur linje med hex-spalten — och just den linjen är hela \
                poängen med spalten. För att läsa text med tecken, använd den vanliga vyn.
                """),
            .heading("Stora filer"),
            .paragraph("""
                Filen är **minnesavbildad**, så att öppna en fil på 1 GB i binär vy kostar bara det ni \
                tittar på. Mätt i självprovsviten: **under en millisekund**.
                """),
            .paragraph("""
                Vyn visar **ett 4 MB-fönster** i taget, och den övre raden säger vilket område ni är i. Det \
                är en gräns hos systemets tabellritare, inte hos läsningen: 1 GB är 62,5 miljoner rader, och \
                efter en viss punkt börjar rader hoppa när man rullar — och en hex-tabell som hoppar är till \
                ingen nytta.
                """),
            .heading("Hoppa till en position"),
            .table(
                headers: ["Skriv i positionsfältet", "Betydelse"],
                rows: [
                    ["`1F400`", "Hexadecimalt — det förvalda"],
                    ["`0x1F400`", "Detsamma, med uttryckligt prefix"],
                    ["`#128000`", "Decimalt, när ni har ett antal byte och inte en hex-position"],
                ]
            ),
            .bullets([
                "`‹` och `›` går till föregående / nästa fönster.",
                "**Kopiera markerade rader** kopierar exakt det ni ser — utan markering kopieras hela fönstret.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown-förhandsvisning",
        summary: "Visa Markdown som formaterad text — och säga rakt ut vad den inte visar.",
        keywords: ["markdown", "förhandsvisning", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("Ritas med systemets Markdown-stöd: fetstil, kursiv, kod, länkar, listor."),
            .warning("""
                **Inga tabeller, och ingen syntaxfärg inne i kodblock.** Förhandsvisningsfönstret säger det \
                längst ner. Dokument större än **4 MB** avvisas.
                """),
            .paragraph("""
                Behöver ni tabeller och diagram i ett dokument som ska ges ut? Det är vad \
                `.greport.md`-rapporter är till för, inte denna förhandsvisning.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Två lägen: Vy och Kod",
        summary: "En tangent växlar mellan den ritade formen och den redigerbara källan, för varje filslag.",
        keywords: ["vy", "kod", "läge", "källa", "ritad", "förhandsvisning"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Växla mellan Vy och Kod")]),
            .paragraph("""
                Reglaget sitter i **raden strax under flikarna** — på samma plats för varje filslag: en \
                `View | Code`-växlare, och sedan namnet på det filslagets Vy-läge («Dokumentsidor», \
                «Nyckel-värde-träd», «Schema»…). En fil med bara ett läge gör växlaren grå och raden säger \
                varför. Vid högerkanten sitter varje slags egna knappar: `.xlsx` har **Tabell** \
                (redigerbar, skriven rakt tillbaka), `.pptx` har **Disposition**.
                """),
            .note("""
                **Word och PowerPoint uppför sig som en dokumentläsare.** Deras Vy-läge bygger riktiga sidor \
                — rätt teckensnitt, storlekar och färger, med bilder, tabeller, sidhuvuden och sidfötter med \
                sidnummer. En sida är **exakt lika bred som ramen** och går att zooma. Excel är ett medvetet \
                undantag: dess Vy är ett **redigerbart kalkylblad**, för ett kalkylblad har ingen \
                pappersstorlek förrän det skrivs ut.
                """),
            .note("""
                I gengäld är sidorna **skrivskyddade** och ritar **kopian på disken**: redigera i Kod utan \
                att spara, så visar sidorna den gamla versionen — raden säger det, med en knapp `Spara och \
                rita om`.
                """),
            .heading("Bestämningar"),
            .bullets([
                "**Kod** är den **redigerbara källan**. För en textfil är det texten själv. För en binär fil — PDF, bild, ljud, video — finns ingen textkälla, så Kod är **byten**, visade hexadecimalt.",
                "**Vy** är det som **ritas** ur Koden. Den kan vara vackrare, kortare eller körbar — men den är alltid en följd, aldrig originalet.",
            ]),
            .paragraph("""
                Att säga om en PDF att *«det slaget har ingen Kod»* vore bekvämt men fel: byten är verkligen \
                dess källa.
                """),
            .heading("Var redigeringen sker"),
            .paragraph("""
                Redigeringen sker i **Kod**. Det finns exakt **två undantag**, båda för att redigera i Vy är \
                mycket naturligare: **cellerna i CSV-tabellen** och **PDF:ens formulärfält**. Båda skriver \
                rakt i källan, så det dyker inte upp en andra kopia att tvista med.
                """),
            .heading("Per filslag"),
            .table(
                headers: ["Filslag", "Vy", "Kod", "Redigera i"],
                rows: [
                    ["CSV · TSV", "Tabell", "Rå text", "**Båda**"],
                    ["Excel `.xlsx`", "Tabell över det öppna bladet", "Det bladet som CSV", "**Båda**"],
                    ["PDF", "Ritade sidor", "Binärt", "**Båda** — anteckningar, fält, sidor"],
                    ["Markdown `.md`", "Ritad text", "Markdown-källa", "Kod"],
                    ["Rapport `.greport.md`", "Rapport med körda frågor och ritade diagram", "Källa", "Kod"],
                    ["JSON", "Nyckel-värde-träd, hopfällbart", "JSON-källa", "Kod"],
                    ["XML · HTML", "Taggträd, hopfällbart", "XML-källa", "Kod"],
                    ["YAML", "Nyckel-värde-träd efter indrag", "YAML-källa", "Kod"],
                    ["Scheman `.mmd` · `.dot`", "Det ritade schemat, som fyller fliken", "mermaid- eller DOT-källa", "Kod"],
                    ["Word `.docx`", "Ritade dokumentsidor", "Uttagen Markdown", "Kod"],
                    ["PowerPoint `.pptx`", "Ritade bildsidor", "Markdown-disposition", "Kod"],
                    ["Loggfiler", "Färgade efter nivå, filtrerbara", "Rå text", "Kod"],
                    ["Bilder", "Bilden (rörliga spelas upp)", "Binärt", "Skrivskyddat"],
                    ["Ljud · video", "En spelare", "Binärt", "Skrivskyddat"],
                    ["Arkiv", "Lista över poster", "Binärt", "Skrivskyddat"],
                    ["Källkod, ren text", "— ingen", "Texten själv", "Kod"],
                ]
            ),
            .note("""
                Källkod har **ingen Vy**, och det är normalt snarare än en brist: en Swift-fil har ingen \
                ritad form värd att titta på.
                """),
            .heading("Sidläsaren för Word och PowerPoint"),
            .paragraph("""
                Sidorna staplas lodrätt och rullar i ett svep, var och en ett vitt blad på grå botten — som \
                i varje dokumentläsare. Dess reglage sitter till höger i raden.
                """),
            .table(
                headers: ["Knapp / tangent", "Vad den gör"],
                rows: [
                    ["`Anpassa bredden`", "Bladet är exakt lika brett som ramen — det förvalda"],
                    ["`Anpassa sidan`", "Hela bladet ryms i ramen"],
                    ["`−` `+`", "Zooma stegvis; eller nypa, eller ⌘ + rulla"],
                    ["Fältet `Sök`, eller ⌘F", "Söka inne i sidorna, hoppa dit och lyfta fram"],
                    ["Retur i sökfältet", "Nästa träff"],
                    ["Dra", "Markera text; dubbelklick för ett ord, trippelklick för ett stycke"],
                    ["⌘A · ⌘C", "Markera allt · kopiera markeringen"],
                    ["Page Up · Page Down · Home · End", "Röra sig genom dokumentet"],
                ]
            ),
            .paragraph("""
                Sökfältet **bortser från diakritiska tecken och versaler**: att skriva `vuong quoc` hittar \
                `Vương quốc`. Etiketten «Sida 12/363» i raden säger var ni är.
                """),
            .note("""
                **Vad som inte ritas, sagt rakt ut:** flytande förankrade bilder (text som löper runt en \
                figur) visas som bilder i löptexten; fotnoter, diagram och PowerPoints SmartArt ritas inte. \
                När ni behöver exakt överensstämmelse med utskriften, öppna det i Word.
                """),
            .heading("Att klicka på en nod leder tillbaka till källan"),
            .paragraph("""
                Ett JSON-träd är ingen prydlig utskrift: att klicka på en nod flyttar markören **till den \
                nodens VÄRDE** i texten och för fliken tillbaka till Kod — för det ni vill härnäst är nästan \
                alltid att redigera det ni just klickade på.
                """),
            .bullets([
                "Behållarnoder visar sitt **antal element** (`{12}`, `[340]`) i stället för sitt innehåll — det är det som svarar på «är detta värt att öppna».",
                "De **två första nivåerna** är utfällda: att fälla ut en fil med tiotusen noder helt ger en lista längre än källan, medan att fälla ihop den helt betyder att man måste klicka för att upptäcka något alls.",
                "En fil med **ogiltig syntax** får inte ett halvt träd — ett avhugget träd ser ut som ett dokument som helt enkelt innehåller så lite.",
                "I ett XML-träd bär attribut prefixet `@` i riktig XPath-form, och **blanktecken mellan taggar blir ingen nod** — det är formatering, inte innehåll.",
                "Ett YAML-träd läser **flerdokumentfiler** (`---`): varje dokument har sin egen rot. Samlingar skrivna på en rad (`ports: [80, 443]`) förblir ett löv — ni ser redan allt, och att fälla ut skulle kosta ett klick. **Indrag med tabbar** rapporteras med exakt rad: det är ett YAML-fel som ögat inte ser.",
                "PowerPoint-dispositionen byggs ur den **öppna texten**, inte ur filen på disken: har ni just redigerat dispositionen i Kod måste trädet beskriva den nya versionen och dess noder hoppa in i den nya versionen. Talarens anteckningar fälls ihop till en nod, så att en pratsam bild inte ser ut som en innehållsrik bild.",
                "**Ett schema som fyller hela fliken följer samma regel**: klicka på en nod och ni är tillbaka i Kod med markören på dess deklaration. I panelen `Mermaid Studio` bredvid stängs fliken inte — redigeraren står precis där, och det räcker att flytta markören för att se det.",
                "Scheman **öppnas också där ni står**: det element som hör till markörens rad är framhävt så snart fliken visas, så ni slipper leta efter det.",
            ]),
            .heading("Filterfältet: i ett träd med tiotusen noder är sökandet arbetet"),
            .paragraph("""
                Strax under nodräkningen sitter ett filterfält. Skriv i det, så behåller trädet bara noder \
                som stämmer — **jämte vägen från roten ned till dem**, för när en nyckel `name` dyker upp på \
                tio ställen är den verkliga frågan «vilken», och bara grenen som innehåller den svarar på \
                det. Resten fälls ut åt er: att låta er klicka upp varje nivå är att låta er filtrera en \
                gång till för hand.
                """),
            .bullets([
                "Det filtrerar på **etiketter och värden**: att söka `Huế` är lika vanligt som att söka nyckeln `province`.",
                "**Att skriva utan tecken stämmer ändå mot text med dem** — `da nang` hittar `Đà Nẵng`. Samma jämförelse som CSV-tabellens filter och funktionslistans, så att ni slipper minnas tre sökregler i ett och samma program.",
                "Utan träffar säger rubriken **«Inga resultat»** i stället för att lämna er stirrande på ett tomt träd och undra om filen är trasig.",
                "Att byta fil eller gå in i Vy på nytt **rensar filtret**: ett träd som öppnas redan avhugget, utan något som förklarar det, är det mest förvirrande läget av alla.",
            ]),
            .heading("Hela trädet går att sköta från tangentbordet"),
            .paragraph("""
                Att gå in i Vy lägger fokus på trädet; ni behöver inte klicka på det först. Upp och ned rör \
                sig mellan noder, vänster och höger fäller ihop och ut, och två tangenter avslutar tittandet \
                — och gör då **olika** saker:
                """),
            .bullets([
                "**Retur** — gå till den valda noden: tillbaka till Kod med markören inne i den nodens byteområde. Precis som ett klick.",
                "**Tabb** — röra sig mellan trädet och filterfältet.",
                "**⌘C** — kopierar den valda nodens **väg**, inte texten bakom trädet. JSON och YAML ger JSONPath (`$.customer['name']`) som klistras rakt in i det här programmets eget JSONPath-fält, eller i `yq`; XML ger XPath (`/order/item[2]/@code`) med index när två taggar delar namn; en PowerPoint-disposition kopierar radens text, för en disposition har inget vägspråk att hitta på.",
                "**Esc** — vägen tillbaka: åter till Kod med markören **precis där den var**. Ni tittade på ett träd, ni reste ingenstans.",
            ]),
            .heading("Och åt andra hållet: trädet öppnas där markören står"),
            .paragraph("""
                Att gå in i Vy från mitten av en fil på tiotusen rader öppnar **inte** trädet högst upp: det \
                fäller ut vägen ned till den nod som svarar mot markörens plats och väljer den. Detta är den \
                andra halvan av hoppet till källan — utan den vore Vy och Kod två blickar på ett dokument \
                bara i **en** riktning.
                """),
            .bullets([
                "Det fäller ut **djupare än två nivåer** när det behövs: tvånivåregeln svarar på «hur ser den här filen ut», medan frågan här är en annan — «var är jag i det här trädet».",
                "En markör på en **nyckel** (`\"address\":`) väljer den posten, trots att nodens byteområde bara täcker värdet. Text omedelbart före en nod hör till den noden.",
                "En markör vid ett **blocks början** — ett YAML-blocks nyckel, en bildtitel, ett XML-taggnamn — väljer det blocket i stället för att dyka ned i dess första barn.",
                "Att gå in i Vy **flyttar inte markören**. Lämna Vy och ni är precis där ni var; Vy är ett sätt att se, inte ett kommando som byter plats.",
            ]),
            .heading("Inget slag saknar längre en Vy"),
            .paragraph("""
                **Varje filslag med utrymme för ett Vy-läge ritar nu ett.** Listan över slag som saknades \
                blev tom och togs bort.

                Källkod och ren text har fortfarande ingen Vy — det är normalt, inte en brist, så de stod \
                aldrig på den listan.

                Kommer ett nytt filslag vars Vy ännu inte är byggd säger växlingskommandot det och namnger \
                vad som saknas, i stället för att öppna en tom ram — en tom ram är ett tomt löfte, medan ett \
                nej med namn är upplysning.
                """),
            .heading("De sex äldre kommandona finns kvar"),
            .paragraph("""
                `Tabell-/textvy`, `Markdown-förhandsvisning`, `Binär vy`, `Rapportförhandsvisning`, \
                `Mermaid-schemaförhandsvisning`, `Loggläge` — alla står kvar precis där de var. `⌥⌘V` är en \
                **gemensam ingång**, inte en ersättare.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamesiska

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamesiska",
        summary: "Gamla teckenkodningar, Unicode-normalisering, sökning utan tecken och inmatningsmetoder.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnamesiska teckenkodningar",
        summary: "Läsa och skriva TCVN3, VISCII, VNI-Windows och 33 till, igenkända av sig själva.",
        keywords: ["teckenkodning", "tcvn3", "abc", "viscii", "vni", "kråkfötter"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Öppnade ni en gammal vietnamesisk fil och fick `Tr¦êng §¹i häc` i stället för `Trường Đại \
                học`? Filen är inte skadad — den sparades i en teckenkodning från tiden före Unicode.
                """),
            .steps([
                "Klicka på teckenkodningen i **statusraden** (eller `Format ▸ Teckenkodning…`).",
                "Välj rätt — för gamla vietnamesiska filer oftast `TCVN3 (ABC)`, `VNI-Windows` eller `VISCII`.",
                "Texten rättar sig genast; filen behöver inte öppnas på nytt.",
                "För att den ska förbli så: `Spara som…` med teckenkodningen `UTF-8`.",
            ]),
            .heading("De tre gamla vietnamesiska teckenkodningarna"),
            .table(
                headers: ["Teckenkodning", "Påträffas mest i"],
                rows: [
                    ["TCVN3 (ABC)", "Myndighetspapper och äldre Word-dokument i norr"],
                    ["VNI-Windows", "Förlag, press och tryckerier — vanligt i söder"],
                    ["VISCII", "Tidig e-post och Usenet"],
                ]
            ),
            .paragraph("""
                GEditor **känner igen teckenkodningen** vid öppning. Gissar den fel rättar ett klick det, och \
                innehållet avkodas på nytt i stället för att lappas bokstav för bokstav.
                """),
            .warning("""
                Att skriva till en gammal teckenkodning tappar de tecken den saknar. GEditor **räknar dem och \
                säger det i förväg** — till exempel *«12 tecken finns inte i TCVN3»* — i stället för att tyst \
                göra dem till frågetecken.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Radbrytningar",
        summary: "LF, CRLF, CR — omvandlade för hela filen med ett klick.",
        keywords: ["eol", "crlf", "lf", "radbrytning", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Stil", "Används av", "Byte"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac före 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Gällande stil syns i statusraden; klicka på den för att ändra. En fil som **blandar** två \
                stilar rapporteras också där — slå på `Visa osynliga ▸ Radbrytningar` för att se exakt var.
                """),
            .note("Radbrytningsstilen för **nya** filer ställs in i `Inställningar…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode-normalisering",
        summary: "Varför en sökning på «ế» ibland inte hittar något, och hur man lagar en hel fil.",
        keywords: ["unicode", "nfc", "nfd", "sammansatt", "uppdelad", "normalisera"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                I Unicode kan `ế` skrivas på **två sätt**: som en förhandssammansatt kodpunkt (NFC), eller \
                som `e` plus två fristående tecken (NFD). På skärmen ser de likadana ut; för en maskin är det \
                två olika strängar.
                """),
            .paragraph("""
                Följden: att söka `ế` i en NFD-fil hittar **ingenting**, och användaren drar slutsatsen att \
                uppgiften inte finns där.
                """),
            .steps([
                "`Format ▸ Normalisera Unicode…`",
                "Välj **NFC** (förhandssammansatt) — den form som nästan allt annat använder.",
                "Tillämpa. Det är ett enda ångra-steg.",
            ]),
            .note("""
                Filer som kommer från macOS är ofta NFD, eftersom Apples filsystem lagrar namn så. Det är den \
                överlägset vanligaste orsaken till att data kopierade ur Finder inte går att hitta igen.
                """),
            .paragraph("""
                Det finns en inställning **normalisera till NFC vid sparande** i `Inställningar…`. Av som \
                standard, eftersom den ändrar filens byte.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Att skriva utan tecken hittar ändå text med tecken",
        summary: "Varje sök- och filterfält jämför med tecknen borttagna.",
        keywords: ["diakritiska tecken", "accenter", "sökning", "filter"],
        blocks: [
            .paragraph("""
                Skriv `hue` för att hitta `Huế`. Skriv `da nang` för att hitta `Đà Nẵng`. Regeln gäller \
                CSV-tabellens filter, funktionssökningen, sökningen i hjälpen och de övriga filterfälten.
                """),
            .note("""
                `Đ` behandlas för sig, för i Unicode är det **en egen bokstav** och inte ett `D` med ett \
                tecken — vanlig borttagning av tecken rör den inte.
                """),
            .paragraph("""
                CSV-filtret godtar också prefixet `=` för exakt jämförelse. Formen med `=` är **likaså \
                okänslig för tecken**, för ett filter som skiljer på diakritiska tecken lämnar användaren i \
                tron att uppgiften saknas.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnamesiska inmatningsmetoder",
        summary: "EVKey, OpenKey, Unikey och macOS inmatningskälla skriver rakt in i dokumentet.",
        keywords: ["inmatningsmetod", "evkey", "unikey", "openkey", "telex", "vni"],
        blocks: [
            .paragraph("""
                Inget att ställa in. Telex och VNI fungerar båda, även över **flera markörer** — skriv en \
                gång och varje markör får den rätt tecknade bokstaven.
                """),
            .paragraph("""
                Sökfält, filterfält och varje dialogruta tar emot inmatningsmetoden precis som redigeraren.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Språk och format

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Språk och format",
        summary: "Tjugo inbyggda språk, egendefinierade språk, och verktyg för JSON · XML · YAML · loggar.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Tjugo inbyggda språk",
        summary: "Färgning ur ett riktigt syntaxträd, med varje språks kommentartecken.",
        keywords: ["syntax", "färgning", "språk", "tree-sitter", "grammatik"],
        blocks: [
            .paragraph("""
                Språket känns igen på **filändelsen** (plus några särskilda namn som `Makefile`, \
                `Dockerfile`, `Gemfile`). Ni kan byta det för hand i statusraden.
                """),
            .table(
                headers: ["Språk", "Ändelser", "Rad- · blockkommentar"],
                rows: [
                    ["Shell", "`sh` `bash` `zsh` `command`", "`#` · —"],
                    ["C", "`c` `h`", "`//` · `/* */`"],
                    ["C++", "`cpp` `cc` `cxx` `hpp` `hh` `hxx`", "`//` · `/* */`"],
                    ["C#", "`cs`", "`//` · `/* */`"],
                    ["CSS", "`css`", "— · `/* */`"],
                    ["Go", "`go`", "`//` · `/* */`"],
                    ["HTML", "`html` `htm` `xhtml`", "— · `<!-- -->`"],
                    ["Java", "`java`", "`//` · `/* */`"],
                    ["JavaScript", "`js` `mjs` `cjs` `jsx`", "`//` · `/* */`"],
                    ["JSON", "`json` `jsonl` `geojson`", "— · —"],
                    ["Lua", "`lua`", "`--` · `--[[ ]]`"],
                    ["PHP", "`php` `phtml`", "`//` · `/* */`"],
                    ["Python", "`py` `pyw` `pyi`", "`#` · —"],
                    ["Regex", "—", "— · —"],
                    ["Ruby", "`rb` `rake` `gemspec`", "`#` · —"],
                    ["Rust", "`rs`", "`//` · `/* */`"],
                    ["TOML", "`toml`", "`#` · —"],
                    ["TypeScript", "`ts` `mts` `cts`", "`//` · `/* */`"],
                    ["XML", "`xml` `xsd` `xsl` `svg` `plist`", "— · `<!-- -->`"],
                    ["YAML", "`yaml` `yml`", "`#` · —"],
                ]
            ),
            .paragraph("""
                Sista spalten är vad `⌘/` använder. Språk utan radkommentar (JSON, CSS, XML) får blockformen \
                i stället.
                """),
            .heading("Vad som följer med ett syntaxträd"),
            .bullets([
                "**Funktionslistan** i sidopanelen följer den verkliga uppbyggnaden, inte gissningar ur indragen.",
                "**Hopfällning** efter uppbyggnad.",
                "**Parentesmatchning** som hoppar över parenteser inne i strängar och kommentarer.",
                "**Automatiskt indrag** som lägger till en nivå efter `{`, och efter `:` i Python och YAML.",
            ]),
            .note("""
                Tre tunga grammatiker (C++, C#, Ruby) bor i ett **lat inläst** bibliotek — de läses in först \
                när ni öppnar en fil i något av de språken. Det är så starttiden hålls under en halv sekund.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Egendefinierade språk",
        summary: "Färglägg ert eget format med en JSON-fil — utan att skriva någon grammatik.",
        keywords: ["udl", "eget språk", "egen logg"],
        blocks: [
            .paragraph("""
                Ett företags interna loggformat, ett eget inställningsspråk, ett litet DSL — inget av dem har \
                en tree-sitter-grammatik, och att skriva en kräver en kompilator och en del \
                tolkningsteori.
                """),
            .paragraph("""
                I stället godtar GEditor en **tabellstyrd lexer** angiven i JSON. Lägg filen i mappen \
                `grammars/` inne i GEditors inställningskatalog och starta om.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — ett fullständigt språk",
                  source: """
                    {
                      "name": "Internal log",
                      "extensions": ["nklog", "trace"],
                      "caseSensitive": false,
                      "lineComment": ";",
                      "blockComment": ["/*", "*/"],
                      "stringDelimiters": ["\\"", "'"],
                      "escapeCharacter": "\\\\",
                      "keywordGroups": {
                        "keyword": ["BEGIN", "END", "RETRY", "COMMIT", "ROLLBACK"],
                        "type":    ["INT", "TEXT", "DATE", "MONEY"],
                        "constant": ["TRUE", "FALSE", "NULL"]
                      }
                    }
                    """),
            .heading("Varje nyckel"),
            .table(
                headers: ["Nyckel", "Typ", "Betydelse"],
                rows: [
                    ["`name`", "sträng", "Namnet som visas i statusraden"],
                    ["`extensions`", "lista av strängar", "Filändelser, **utan punkten**"],
                    ["`caseSensitive`", "sanningsvärde", "Om nyckelord skiljer på versaler och gemener"],
                    ["`lineComment`", "sträng", "Tecken för kommentar till radslut; utelämna om det saknas"],
                    ["`blockComment`", "lista av 2 strängar", "`[öppnande, stängande]`"],
                    ["`stringDelimiters`", "lista av strängar", "Varje post är **ett** tecken som öppnar/stänger en sträng"],
                    ["`escapeCharacter`", "sträng", "Undantagstecken inne i strängar; tomt betyder att språket saknar sådant"],
                    ["`keywordGroups`", "objekt", "Gruppnamn → lista av nyckelord; tre grupper får tre färger"],
                ]
            ),
            .paragraph("De tre gruppnamnen med egen färg är `keyword`, `type` och `constant`."),
            .warning("""
                Denna lexer **förstår inte nästling**. Hopfällning efter uppbyggnad, funktionslistan och den \
                kloka parentesmatchningen förblir de tjugo inbyggda språkens ensak. Det är ett medvetet byte: \
                i gengäld anger ni ett språk på tio minuter i stället för på en dag.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON-verktyg",
        summary: "Formatera om, förminska, sortera nycklar och pröva mot ett JSON Schema.",
        keywords: ["json", "formatera", "förminska", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Kommando", "Vad det gör"],
                rows: [
                    ["Formatera om", "Bryter rader och drar in för läsbarhet"],
                    ["Förminska", "Tar bort allt överflödigt blanktecken"],
                    ["Sortera nycklar", "Ordnar varje objekts nycklar i bokstavsordning — så att två JSON-filer går att **jämföra**"],
                    ["Pröva mot JSON Schema…", "Prövar dokumentet mot en schemafil och räknar upp varje problem med dess rad"],
                ]
            ),
            .paragraph("""
                Reglerna som gäller är **strikt RFC 8259**: inga avslutande kommatecken, inga kommentarer, \
                inget `NaN`. Ett syntaxfel pekar på exakt rad och kolumn.
                """),
            .note("""
                **JSONL**-filer (ett objekt per rad) känns också igen och har egna verktyg i kapitlet om \
                kunskapspaketet.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath-frågor",
        summary: "Dra ut exakt den del ni behöver ur en stor JSON-fil.",
        keywords: ["jsonpath", "json-fråga", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Skriv ett uttryck; resultaten visas som en lista man kan hoppa in i."),
            .table(
                headers: ["Skriv", "Betydelse"],
                rows: [
                    ["`$`", "Dokumentets rot"],
                    ["`$.name`", "Nyckeln `name` vid roten"],
                    ["`$.orders[0]`", "Första elementet i en lista"],
                    ["`$.orders[*].total`", "Nyckeln `total` i **varje** element"],
                    ["`$..province`", "Nyckeln `province` på **valfritt djup**"],
                    ["`$.orders[1:3]`", "En skiva: elementen 1 och 2"],
                ]
            ),
            .code(language: "text", caption: "Varje orders provinskod, hur djupt nästlad den än är",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML-verktyg",
        summary: "Formatera om, förminska, pröva syntaxen och pröva mot en DTD eller ett XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "pröva", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Kommando", "Vad det gör"],
                rows: [
                    ["Formatera om", "Drar in efter taggdjup"],
                    ["Förminska", "Tar bort blanktecken mellan taggar"],
                    ["Pröva syntaxen", "Saknade slutmärken, felaktig nästling, ogiltiga tecken"],
                    ["Pröva mot DTD/XSD…", "Prövar mot ett schema och rapporterar varje problem med dess rad"],
                    ["Utvärdera XPath…", "Kör ett XPath-uttryck; resultaten öppnas i en ny flik"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Skriv ett uttryck, så öppnas resultaten som **en textflik**, en nod per rad. Till exempel: \
                `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Resultaten hoppar INTE till en plats i källfilen.** Systemets XPath-utvärderare bygger ett \
                eget träd och behåller inte varje nods byteposition, så det som kommer tillbaka är INNEHÅLL \
                och inte koordinater. För att nå den exakta platsen, använd `⌘F` på strängen ni just hittat.
                """),
            .paragraph("""
                I `.xml`- och `.html`-filer får ett `>` som avslutar en öppningstagg **slutmärket att dyka \
                upp** med markören emellan. Självstängande taggar (`<br/>`), deklarationer (`<?xml …?>`) och \
                kommentarer gör det inte — de har inget att stänga.
                """),
            .warning("""
                Att formatera om XML **ändrar blanktecknen mellan taggar**. I dokument där de blanktecknen \
                betyder något — XHTML med text inne i taggar till exempel — ändrar det vad som visas. Det är \
                ett enda ångra-steg, så `⌘Z` vänder det.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML-kontroll",
        summary: "Fånga de två vanligaste YAML-felen: dubblerade nycklar och indrag med tabbar.",
        keywords: ["yaml", "yml", "lint", "dubblerad nyckel", "indrag"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Dubblerade nycklar** i samma avbildning — de flesta YAML-läsare tar den **sista** och släpper tyst de tidigare, så en inställningsfil kan bete sig helt annorlunda än ni tror.",
                "**Indrag med tabbar** — YAML förbjuder tabbar i indrag, och bibliotekens felmeddelanden om detta brukar vara obegripliga.",
            ]),
            .note("Slå på `Visa osynliga ▸ Tabbar` för att genast se vilket blanktecken som är en tabb."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Loggfiler",
        summary: "Sju allvarlighetsnivåer, filtrering efter nivå och hur man läser en mycket stor logg.",
        keywords: ["logg", "fel", "varning", "filter", "nivå"],
        blocks: [
            .paragraph("""
                Slå på `Visa ▸ Loggläge (färga efter nivå)`. GEditor läser allvarligheten i **början av varje \
                rad** — efter tidsstämpeln och processnamnet.
                """),
            .table(
                headers: ["Nivå", "Färg"],
                rows: [
                    ["CRITICAL · ERROR", "Röd"],
                    ["WARNING", "Bärnsten"],
                    ["NOTICE", "Framhävningsfärg"],
                    ["INFO", "Vanlig text"],
                    ["DEBUG · TRACE", "Dämpad"],
                ]
            ),
            .paragraph("""
                `Filtrera logg efter nivå…` döljer de lägre nivåerna helt. Rader vars nivå **inte känns \
                igen** — fortsättningen på en stackspårning till exempel — lämnas i fred i stället för att få \
                föregående rads nivå.
                """),
            .heading("Att läsa en stor logg, steg för steg"),
            .steps([
                "Öppna filen — även i gigabyteskala öppnas den nästan genast.",
                "`Visa ▸ Loggläge` för att se var det röda finns.",
                "`⌥⌘M` för dokumentkartan: är det röda samlat på en sträcka eller utspritt över hela filen?",
                "`⌘F` efter felkoden, `⌘M` för att markera varje träffad rad.",
                "`Sök ▸ Kopiera markerade rader` för att dra dem till en ny flik.",
                "Kör den fortfarande? `Arkiv ▸ Följ fil (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
