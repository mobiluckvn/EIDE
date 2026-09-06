import Foundation

/// Nederlandse helpinhoud — deel 3: manieren van kijken, Vietnamees, talen en formaten.
extension HelpNL {

    static let views = HelpChapter(
        id: "xem",
        title: "Manieren om een document te bekijken",
        summary: "Navigatiekolom, kaart, invouwen, gedeelde weergave, regelafbreking, onzichtbaren, kleurmodi.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Navigatiekolom en functielijst",
        summary: "De bestandsboom en de functielijst van het geopende bestand, in één kolom.",
        keywords: ["navigatiekolom", "functielijst", "overzicht", "bestandsboom"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "De navigatiekolom tonen / verbergen")]),
            .paragraph("""
                De functielijst wordt gebouwd op de **syntaxisboom** van de taal, dus hij volgt de echte \
                structuur in plaats van haar uit de inspringing te raden. Klik op een item om ernaartoe te \
                springen.
                """),
            .note("Het filterveld van de lijst **vindt tekst mét accenten terwijl u zonder accenten typt**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Documentkaart",
        summary: "Het hele bestand in een smalle kolom rechts — ook bij honderden MB.",
        keywords: ["minikaart", "kaart", "overzicht"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "De documentkaart tonen / verbergen")]),
            .paragraph("""
                De kaart beschrijft het **hele bestand**, niet alleen wat op het scherm staat. Erop slepen \
                springt naar het bijbehorende gebied.
                """),
            .paragraph("""
                Zoektreffers en gemarkeerde regels verschijnen op de kaart, zodat u ziet of ze verspreid of \
                geclusterd zijn voordat u erheen schuift.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Invouwen",
        summary: "Functies, blokken en reeksen invouwen op structuur — of het hele bestand tot een niveau invouwen.",
        keywords: ["invouwen", "code folding", "inklappen"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Het blok bij de cursor in-/uitvouwen"),
                HelpShortcut("⌥⇧⌘←", "Alles invouwen"),
                HelpShortcut("⌥⌘→", "Alles uitvouwen"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Het hele bestand tot niveau 1…8 invouwen"),
            ]),
            .paragraph("""
                Bij talen met een syntaxisboom volgt het invouwen de **echte structuur**. Bij bestanden \
                zonder grammatica volgt het de inspringing.
                """),
            .paragraph("""
                `Invouwen tot niveau` verdient zijn plaats bij diepe JSON en YAML: invouwen tot niveau 2 zet \
                de vorm van het hele bestand op één scherm.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Gedeelde weergave",
        summary: "Twee deelvensters naast elkaar, voor twee bestanden — of twee plekken in één bestand.",
        keywords: ["delen", "deelvensters", "vergelijken"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Verticaal delen"),
                HelpShortcut("⌥⌘-", "Horizontaal delen"),
                HelpShortcut("⌥⌘0", "De deling opheffen"),
                HelpShortcut("⌥⌘]", "Dit tabblad in het andere deelvenster openen"),
                HelpShortcut("⌥⌘[", "Naar het andere deelvenster springen"),
            ]),
            .paragraph("""
                Elk deelvenster heeft zijn eigen tabbladbalk. **Hetzelfde bestand** in beide openen kan \
                prima — ze schuiven onafhankelijk, wat het vergelijken van begin en einde van een bestand \
                makkelijk maakt.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Automatische regelafbreking",
        summary: "Drie modi: uit, aan de vensterrand, of op een vaste kolom.",
        keywords: ["regelafbreking", "zachte afbreking"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Modus", "Een lange regel"],
                rows: [
                    ["Uit", "Schuift horizontaal"],
                    ["Aan het venster", "Breekt af aan de vensterrand, volgend op de grootte ervan"],
                    ["Op een kolom", "Breekt af op de kolom die u instelt — 80 of 100, bijvoorbeeld"],
                ]
            ),
            .paragraph("""
                Afbreken is een **manier van kijken**, geen bewerking: er wordt geen regelovergang ingevoegd, \
                en het komt nooit in de geschiedenis van ongedaan maken.
                """),
            .note("De snelle weg is het segment `Ngắt: …` in de statusbalk."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Tekengrootte",
        summary: "In- en uitzoomen tussen 8 en 32 pt.",
        keywords: ["zoom", "grootte", "groter", "kleiner"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Groter"),
                HelpShortcut("⌘-", "Kleiner"),
                HelpShortcut("⌃⌘0", "Terug naar de standaardgrootte"),
            ]),
            .paragraph("""
                Begrensd tussen 8 en 32 pt. Ook dit is een **manier van kijken**: geen bewerking, niets in \
                de geschiedenis van ongedaan maken. De standaardgrootte woont in `Instellingen…`.
                """),
            .note("`⌘0` is **niet** de standaardgrootte — die toets toont en verbergt de navigatiekolom."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Onzichtbare tekens tonen",
        summary: "Eén groep tegelijk, want allemaal tegelijk is meestal te veel.",
        keywords: ["onzichtbaar", "witruimte", "nbsp", "nulbreedte", "tab"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Alle onzichtbare tekens tonen / verbergen")]),
            .paragraph("""
                Vier groepen gaan apart aan, want ze allemaal tegelijk aanzetten begraaft de inhoud onder een \
                woud van puntjes.
                """),
            .table(
                headers: ["Groep", "Wat ze vangt"],
                rows: [
                    ["Spaties", "Spaties aan het regeleinde, inconsistente inspringing"],
                    ["Tabs", "Bestanden die tabs met spaties mengen"],
                    ["Regelovergangen", "Bestanden die CRLF met LF mengen"],
                    ["NBSP · nulbreedte · besturing", "Onzichtbare tekens uit Word, van het web, uit rekenbladen"],
                ]
            ),
            .warning("""
                De laatste groep is degene die mensen redt. Een harde spatie (NBSP) die uit een webpagina is \
                geplakt ziet er **precies** uit als een gewone spatie, en toch laat hij elke \
                tekenreeksvergelijking en elk filter missen — en zonder deze groep aan is er geen manier om \
                hem te zien.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV-modus en Logboekmodus",
        summary: "Twee kleuringen die de syntaxiskleuring vervangen, voor twee soorten gegevensbestanden.",
        keywords: ["csv-modus", "logboekmodus", "kleuring", "kolommen", "niveau"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV-modus"),
            .paragraph("""
                Geeft elke kolom een eigen kleur in de **tekstweergave**, zodat u ziet welke cel een kolom is \
                opgeschoven zonder naar de tabel over te schakelen.
                """),
            .heading("Logboekmodus"),
            .paragraph("""
                Kleurt naar de **ernst** die hij uit de regel leest: fouten rood, waarschuwingen amber, \
                terwijl `debug` en `trace` gedempt worden — ze vormen het grootste deel van een logboek, en ze \
                oplichten dempt juist wat u zoekt.
                """),
            .paragraph("`Logboek filteren op niveau…` verbergt de niveaus die u niet nodig hebt helemaal."),
            .note("""
                Deze twee kleuren **in plaats van** de syntaxiskleuring, niet erbovenop. Een logboek heeft \
                geen syntaxis om te kleuren, en twee kleurbronnen die naar hetzelfde bytebereik schrijven \
                laten geen voorspelbare winnaar achter.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Binaire weergave",
        summary: "Een hex-tabel voor elk bestand — ook een van 1 GB, die bijna onmiddellijk opengaat.",
        keywords: ["hex", "binair", "byte", "positie", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Weergave ▸ Binaire weergave` toont elke byte als een tabel met drie kolommen: **positie · \
                hex · tekst**. Het werkt voor **elk** bestand op schijf, niet alleen voor afbeeldingen of \
                video.
                """),
            .table(
                headers: ["Kolom", "Inhoud"],
                rows: [
                    ["Positie", "Positie van de byte, in hexadecimaal"],
                    ["Hex", "16 bytes per regel, na de achtste gescheiden om makkelijker te tellen"],
                    ["Tekst", "Afdrukbare ASCII-bytes; al het andere is een `.`"],
                ]
            ),
            .note("""
                De tekstkolom **ontcijfert geen UTF-8**. Een Vietnamese letter beslaat twee of drie bytes, dus \
                haar tonen zou de tekstkolom uit de pas brengen met de hex-kolom — en juist die uitlijning is \
                het hele nut van de kolom. Om tekst mét accenten te lezen gebruikt u de normale weergave.
                """),
            .heading("Grote bestanden"),
            .paragraph("""
                Het bestand is **in het geheugen afgebeeld**, dus een bestand van 1 GB in binaire weergave \
                openen kost alleen wat u bekijkt. Gemeten in de reeks zelftests: **minder dan een \
                milliseconde**.
                """),
            .paragraph("""
                De weergave toont **één venster van 4 MB** tegelijk, en de bovenbalk zegt in welk bereik u \
                zit. Dat is een grens van de tabeltekenaar van het systeem, niet van het lezen: 1 GB is 62,5 \
                miljoen regels, en voorbij een bepaald punt beginnen regels te springen tijdens het schuiven — \
                en een hex-tabel die springt is nutteloos.
                """),
            .heading("Naar een positie springen"),
            .table(
                headers: ["Typ in het positieveld", "Betekenis"],
                rows: [
                    ["`1F400`", "Hexadecimaal — het standaardgedrag"],
                    ["`0x1F400`", "Hetzelfde, met een uitdrukkelijk voorvoegsel"],
                    ["`#128000`", "Decimaal, wanneer u een aantal bytes hebt en geen hex-positie"],
                ]
            ),
            .bullets([
                "`‹` en `›` gaan naar het vorige / volgende venster.",
                "**Geselecteerde regels kopiëren** kopieert precies wat u ziet — zonder selectie kopieert het het hele venster.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown-voorbeeld",
        summary: "Markdown als opgemaakte tekst tonen — en duidelijk zeggen wat het niet toont.",
        keywords: ["markdown", "voorbeeld", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("Getoond met de Markdown-ondersteuning van het systeem: vet, cursief, code, koppelingen, lijsten."),
            .warning("""
                **Geen tabellen, en geen syntaxiskleur binnen codeblokken.** Het voorbeeldvenster zegt dat \
                onderaan. Documenten groter dan **4 MB** worden geweigerd.
                """),
            .paragraph("""
                Hebt u tabellen en grafieken nodig in een document dat u kunt publiceren? Daarvoor bestaan de \
                `.greport.md`-rapporten, niet dit voorbeeld.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Twee modi: Weergave en Code",
        summary: "Eén toets wisselt tussen de getoonde vorm en de bewerkbare bron, voor elk bestandstype.",
        keywords: ["weergave", "code", "modus", "bron", "getoond", "voorbeeld"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Wisselen tussen Weergave en Code")]),
            .paragraph("""
                De schakelaar zit in de **balk vlak onder de tabbladen** — op dezelfde plaats voor elk \
                bestandstype: een `View | Code`-schakelaar, dan de naam van de weergavemodus van dat bestand \
                («Documentpagina's», «Sleutel-waardeboom», «Schema»…). Een bestand met maar één modus maakt de \
                schakelaar grijs en de balk zegt waarom. Aan de rechterrand zitten de eigen knoppen van elk \
                type: `.xlsx` heeft **Tabel** (bewerkbaar, rechtstreeks teruggeschreven), `.pptx` heeft \
                **Overzicht**.
                """),
            .note("""
                **Word en PowerPoint gedragen zich als een documentlezer.** Hun weergavemodus bouwt echte \
                pagina's — juiste lettertypen, groottes en kleuren, met afbeeldingen, tabellen, kop- en \
                voetteksten met paginanummers. Een pagina is **precies zo breed als het kader** en is te \
                zoomen. Excel is een bewuste uitzondering: zijn weergave is een **bewerkbaar rekenblad**, \
                omdat een rekenblad geen papierformaat heeft tot het gedrukt wordt.
                """),
            .note("""
                In ruil zijn de pagina's **alleen-lezen** en tonen ze de **kopie op schijf**: bewerk in Code \
                zonder te bewaren en de pagina's tonen de oude versie — de balk zegt dat, met een knop \
                `Bewaren en opnieuw tekenen`.
                """),
            .heading("Definities"),
            .bullets([
                "**Code** is de **bewerkbare bron**. Bij een tekstbestand is dat de tekst zelf. Bij een binair bestand — PDF, afbeelding, audio, video — is er geen tekstbron, dus Code zijn de **bytes**, in hexadecimaal getoond.",
                "**Weergave** is wat uit de Code wordt **getoond**. Het kan mooier, korter of uitvoerbaar zijn — maar het is altijd een gevolg, nooit het origineel.",
            ]),
            .paragraph("""
                Van een PDF zeggen dat *«dit type geen Code heeft»* zou handig zijn, maar onjuist: de bytes \
                zijn echt zijn bron.
                """),
            .heading("Waar er bewerkt wordt"),
            .paragraph("""
                Het bewerken gebeurt in **Code**. Er zijn precies **twee uitzonderingen**, beide omdat \
                bewerken in de Weergave veel natuurlijker is: de **cellen van de CSV-tabel** en de \
                **formuliervelden van een PDF**. Beide schrijven rechtstreeks in de bron, zodat er geen tweede \
                kopie opduikt om mee te twisten.
                """),
            .heading("Per bestandstype"),
            .table(
                headers: ["Bestandstype", "Weergave", "Code", "Bewerken in"],
                rows: [
                    ["CSV · TSV", "Tabel", "Kale tekst", "**Beide**"],
                    ["Excel `.xlsx`", "Tabel van het geopende blad", "Dat blad als CSV", "**Beide**"],
                    ["PDF", "Getoonde pagina's", "Binair", "**Beide** — annotaties, velden, pagina's"],
                    ["Markdown `.md`", "Getoonde tekst", "Markdown-bron", "Code"],
                    ["Rapport `.greport.md`", "Rapport met uitgevoerde bevragingen en getekende grafieken", "Bron", "Code"],
                    ["JSON", "Sleutel-waardeboom, invouwbaar", "JSON-bron", "Code"],
                    ["XML · HTML", "Boom van tags, invouwbaar", "XML-bron", "Code"],
                    ["YAML", "Sleutel-waardeboom op inspringing", "YAML-bron", "Code"],
                    ["Schema's `.mmd` · `.dot`", "Het getekende schema, dat het tabblad vult", "mermaid- of DOT-bron", "Code"],
                    ["Word `.docx`", "Getoonde documentpagina's", "Uitgetrokken Markdown", "Code"],
                    ["PowerPoint `.pptx`", "Getoonde diapagina's", "Markdown-overzicht", "Code"],
                    ["Logbestanden", "Gekleurd op niveau, te filteren", "Kale tekst", "Code"],
                    ["Afbeeldingen", "De afbeelding (bewegende spelen af)", "Binair", "Alleen-lezen"],
                    ["Audio · video", "Een speler", "Binair", "Alleen-lezen"],
                    ["Archieven", "Lijst van onderdelen", "Binair", "Alleen-lezen"],
                    ["Broncode, kale tekst", "— geen", "De tekst zelf", "Code"],
                ]
            ),
            .note("""
                Broncode heeft **geen Weergave**, en dat is normaal in plaats van een gemis: een \
                Swift-bestand heeft geen getoonde vorm die het bekijken waard is.
                """),
            .heading("De paginalezer voor Word en PowerPoint"),
            .paragraph("""
                De pagina's stapelen verticaal en schuiven doorlopend, elk een wit blad op een grijze \
                achtergrond — zoals bij elke documentlezer. De knoppen ervoor zitten rechts in de balk.
                """),
            .table(
                headers: ["Knop / toets", "Wat ze doet"],
                rows: [
                    ["`Passend in de breedte`", "Het blad is precies zo breed als het kader — het standaardgedrag"],
                    ["`Hele pagina passend`", "Het hele blad past in het kader"],
                    ["`−` `+`", "Zoomen in stappen; of knijpen, of ⌘ + schuiven"],
                    ["Het veld `Zoek`, of ⌘F", "In de pagina's zoeken, ernaartoe springen en oplichten"],
                    ["Enter in het zoekveld", "Volgende treffer"],
                    ["Slepen", "Tekst selecteren; dubbelklik voor een woord, drievoudige klik voor een alinea"],
                    ["⌘A · ⌘C", "Alles selecteren · de selectie kopiëren"],
                    ["Page Up · Page Down · Home · End", "Door het document bewegen"],
                ]
            ),
            .paragraph("""
                Het zoekveld **negeert accenten en hoofdletters**: `vuong quoc` typen vindt `Vương quốc`. Het \
                label «Pagina 12/363» in de balk zegt waar u bent.
                """),
            .note("""
                **Wat niet getoond wordt, ronduit gezegd:** zwevende verankerde afbeeldingen (tekst die om een \
                figuur loopt) verschijnen als afbeeldingen in de tekstloop; voetnoten, grafieken en SmartArt \
                van PowerPoint worden niet getekend. Als u exacte overeenkomst met het gedrukte exemplaar \
                nodig hebt, opent u het in Word.
                """),
            .heading("Op een knooppunt klikken brengt terug naar de bron"),
            .paragraph("""
                Een JSON-boom is geen mooie afdruk: op een knooppunt klikken verplaatst de cursor **naar de \
                WAARDE van dat knooppunt** in de tekst en brengt het tabblad terug naar Code — want wat u \
                daarna wilt, is bijna altijd bewerken waarop u net klikte.
                """),
            .bullets([
                "Houderknooppunten tonen hun **aantal elementen** (`{12}`, `[340]`) in plaats van hun inhoud — dat is wat de vraag «is dit het openen waard?» beantwoordt.",
                "De **eerste twee niveaus** staan open: een bestand van tienduizend knooppunten helemaal openvouwen levert een lijst die langer is dan de bron, terwijl het helemaal dichtvouwen betekent dat u moet klikken om ook maar iets te ontdekken.",
                "Een bestand met **ongeldige syntaxis** krijgt geen halve boom — een afgekapte boom ziet eruit als een document dat eenvoudigweg zo weinig bevat.",
                "In een XML-boom dragen attributen een `@`-voorvoegsel in nette XPath-schrijfwijze, en **witruimte tussen tags wordt geen knooppunt** — dat is opmaak, geen inhoud.",
                "Een YAML-boom leest **bestanden met meerdere documenten** (`---`): elk document heeft zijn eigen wortel. Verzamelingen die op één regel zijn geschreven (`ports: [80, 443]`) blijven één blad — u ziet al alles, en openvouwen zou een klik kosten. **Inspringing met tabs** wordt met de precieze regel gemeld: dat is een YAML-fout die het oog niet ziet.",
                "Het PowerPoint-overzicht wordt gebouwd uit de **geopende tekst**, niet uit het bestand op schijf: hebt u het overzicht net in Code bewerkt, dan moet de boom de nieuwe versie beschrijven en moeten zijn knooppunten in die nieuwe versie springen. Notities van de spreker vouwen in één knooppunt, zodat een praatgrage dia er niet uitziet als een dia met veel inhoud.",
                "**Een schema dat het hele tabblad vult volgt dezelfde regel**: klik op een knooppunt en u bent terug in Code met de cursor op de declaratie ervan. In het paneel `Mermaid Studio` ernaast sluit het tabblad niet — de bewerker staat er vlak naast, en de cursor verplaatsen is genoeg om het te zien.",
                "Schema's **openen ook waar u staat**: het element dat bij de regel van de cursor hoort is opgelicht zodra het tabblad verschijnt, zodat u er niet naar hoeft te zoeken.",
            ]),
            .heading("Het filterveld: in een boom van tienduizend knooppunten is zoeken het werk"),
            .paragraph("""
                Vlak onder het aantal knooppunten zit een filterveld. Typ erin en de boom houdt alleen de \
                passende knooppunten over — **samen met het pad van de wortel naar hen toe**, want wanneer een \
                sleutel `name` op tien plaatsen voorkomt, is de echte vraag «welke», en alleen de tak die hem \
                bevat antwoordt daarop. De rest wordt voor u opengevouwen: u elk niveau laten openklikken is u \
                een tweede keer met de hand laten filteren.
                """),
            .bullets([
                "Het filtert op **labels en waarden**: naar `Huế` zoeken is even gewoon als naar de sleutel `province` zoeken.",
                "**Zonder accenten typen past nog steeds op tekst mét accenten** — `da nang` vindt `Đà Nẵng`. Dezelfde vergelijking als het filter van de CSV-tabel en dat van de functielijst, zodat u geen drie zoekregels in één programma hoeft te onthouden.",
                "Zonder treffers zegt de kop **«Geen resultaten»** in plaats van u naar een lege boom te laten staren met de vraag of het bestand stuk is.",
                "Van bestand wisselen of de Weergave opnieuw betreden **wist het filter**: een boom die al afgekapt opengaat, zonder dat iets het uitlegt, is de meest verwarrende toestand van allemaal.",
            ]),
            .heading("De hele boom werkt vanaf het toetsenbord"),
            .paragraph("""
                De Weergave betreden legt de aandacht op de boom; u hoeft er niet eerst op te klikken. Omhoog \
                en omlaag bewegen tussen knooppunten, links en rechts vouwen in en uit, en twee toetsen \
                beëindigen het kijken — en doen daarbij **verschillende** dingen:
                """),
            .bullets([
                "**Enter** — naar het geselecteerde knooppunt gaan: terug in Code met de cursor binnen het bytebereik van dat knooppunt. Precies zoals erop klikken.",
                "**Tab** — tussen de boom en het filterveld bewegen.",
                "**⌘C** — kopieert het **pad** van het geselecteerde knooppunt, niet de tekst achter de boom. JSON en YAML leveren JSONPath (`$.customer['name']`) die zo in het eigen JSONPath-veld van dit product plakt, of in `yq`; XML levert XPath (`/order/item[2]/@code`) met volgnummers wanneer twee tags een naam delen; een PowerPoint-overzicht kopieert de tekst van de regel, want een overzicht heeft geen padtaal om te verzinnen.",
                "**Esc** — de weg terug: terug naar Code met de cursor **precies waar hij was**. U keek naar een boom, u reisde nergens heen.",
            ]),
            .heading("En andersom: de boom opent waar de cursor staat"),
            .paragraph("""
                De Weergave betreden vanuit het midden van een bestand van tienduizend regels opent de boom \
                **niet** bovenaan: hij vouwt het pad open tot het knooppunt dat hoort bij de plek waar de \
                cursor stond, en selecteert het. Dit is de andere helft van de sprong naar de bron — zonder \
                haar zouden Weergave en Code slechts in **één** richting twee blikken op één document zijn.
                """),
            .bullets([
                "Hij vouwt zo nodig **verder dan twee niveaus** open: de tweeniveauregel beantwoordt «hoe ziet dit bestand eruit», terwijl de vraag hier een andere is — «waar ben ik in deze boom».",
                "Een cursor op een **sleutel** (`\"address\":`) selecteert dat item, ook al beslaat het bytebereik van het knooppunt alleen de waarde. Tekst vlak vóór een knooppunt hoort bij dat knooppunt.",
                "Een cursor aan het **begin van een blok** — de sleutel van een YAML-blok, een diatitel, een XML-tagnaam — selecteert dat blok in plaats van in zijn eerste kind te duiken.",
                "De Weergave betreden **verplaatst de cursor niet**. Verlaat de Weergave en u bent precies waar u was; de Weergave is een manier van kijken, geen opdracht die van plaats verandert.",
            ]),
            .heading("Geen enkel type mist nog een Weergave"),
            .paragraph("""
                **Elk bestandstype met ruimte voor een weergavemodus toont er nu een.** De lijst met \
                ontbrekende types raakte leeg en is verwijderd.

                Broncode en kale tekst hebben nog steeds geen Weergave — dat is normaal, geen gemis, dus ze \
                stonden nooit op die lijst.

                Komt er een nieuw bestandstype waarvan de Weergave nog niet gebouwd is, dan zegt de \
                wisselopdracht dat en noemt ze wat ontbreekt, in plaats van een leeg kader te openen — een \
                leeg kader is een lege belofte, terwijl een weigering met een naam informatie is.
                """),
            .heading("De zes oudere opdrachten zijn er nog"),
            .paragraph("""
                `Tabel-/tekstweergave`, `Markdown-voorbeeld`, `Binaire weergave`, `Rapportvoorbeeld`, \
                `Mermaid-schemavoorbeeld`, `Logboekmodus` — ze blijven allemaal precies waar ze waren. `⌥⌘V` \
                is een **gedeelde ingang**, geen vervanging.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamees

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamees",
        summary: "Oude coderingen, Unicode-normalisatie, zoeken zonder accenten en invoermethoden.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnamese coderingen",
        summary: "TCVN3, VISCII, VNI-Windows en 33 andere lezen en schrijven, automatisch herkend.",
        keywords: ["codering", "tcvn3", "abc", "viscii", "vni", "tekenbrij"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Hebt u een oud Vietnamees bestand geopend en kreeg u `Tr¦êng §¹i häc` in plaats van `Trường \
                Đại học`? Het bestand is niet beschadigd — het is bewaard in een codering van vóór Unicode.
                """),
            .steps([
                "Klik op de codering in de **statusbalk** (of `Opmaak ▸ Codering…`).",
                "Kies de juiste — bij oude Vietnamese bestanden meestal `TCVN3 (ABC)`, `VNI-Windows` of `VISCII`.",
                "De tekst herstelt zich meteen; het bestand hoeft niet opnieuw geopend te worden.",
                "Om het zo te houden: `Bewaar als…` met de codering `UTF-8`.",
            ]),
            .heading("De drie oude Vietnamese coderingen"),
            .table(
                headers: ["Codering", "Vooral te vinden in"],
                rows: [
                    ["TCVN3 (ABC)", "Overheidsstukken en oudere Word-documenten in het noorden"],
                    ["VNI-Windows", "Uitgeverij, pers en drukkerijen — gebruikelijk in het zuiden"],
                    ["VISCII", "Vroege e-mail en Usenet"],
                ]
            ),
            .paragraph("""
                GEditor **herkent de codering** bij het openen. Raadt hij verkeerd, dan lost één klik het op, \
                en de inhoud wordt opnieuw ontcijferd in plaats van letter voor letter opgelapt.
                """),
            .warning("""
                Naar een oude codering schrijven verliest de tekens die die codering niet heeft. GEditor **telt \
                ze en zegt het u vooraf** — bijvoorbeeld *«12 tekens zitten niet in TCVN3»* — in plaats van ze \
                stilletjes in vraagtekens te veranderen.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Regelovergangen",
        summary: "LF, CRLF, CR — met één klik voor het hele bestand omgezet.",
        keywords: ["eol", "crlf", "lf", "regelovergang", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Stijl", "Gebruikt door", "Bytes"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac van vóór 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                De huidige stijl staat in de statusbalk; klik erop om hem te wijzigen. Een bestand dat twee \
                stijlen **mengt** wordt daar ook gemeld — zet `Onzichtbaren tonen ▸ Regelovergangen` aan om \
                precies te zien waar.
                """),
            .note("De stijl van regelovergang voor **nieuwe** bestanden staat in `Instellingen…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode-normalisatie",
        summary: "Waarom zoeken naar «ế» soms niets vindt, en hoe u een heel bestand herstelt.",
        keywords: ["unicode", "nfc", "nfd", "samengesteld", "ontleed", "normaliseren"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                In Unicode kan `ế` op **twee manieren** worden geschreven: als één voorafgesteld codepunt \
                (NFC), of als `e` plus twee losse tekens (NFD). Op het scherm zien ze er hetzelfde uit; voor \
                een machine zijn het twee verschillende tekenreeksen.
                """),
            .paragraph("""
                Het gevolg: naar `ế` zoeken in een NFD-bestand vindt **niets**, en de gebruiker besluit dat de \
                gegevens er niet zijn.
                """),
            .steps([
                "`Opmaak ▸ Unicode normaliseren…`",
                "Kies **NFC** (voorafgesteld) — de vorm die vrijwel al het andere gebruikt.",
                "Toepassen. Het is één stap terug.",
            ]),
            .note("""
                Bestanden die van macOS komen zijn vaak NFD, omdat Apples bestandssysteem namen zo bewaart. \
                Dit is verreweg de meest voorkomende reden waarom gegevens die uit de Finder zijn gekopieerd \
                niet meer te vinden zijn.
                """),
            .paragraph("""
                Er is een schakelaar **bij bewaren naar NFC normaliseren** in `Instellingen…`. Standaard uit, \
                omdat hij de bytes van het bestand verandert.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Zonder accenten typen vindt toch tekst mét accenten",
        summary: "Elk zoek- en filterveld vergelijkt met de accenten weggehaald.",
        keywords: ["accenten", "diakritische tekens", "zoeken", "filter"],
        blocks: [
            .paragraph("""
                Typ `hue` om `Huế` te vinden. Typ `da nang` om `Đà Nẵng` te vinden. De regel geldt voor het \
                filter van de CSV-tabel, het zoeken naar functies, het zoeken in de help en de overige \
                filtervelden.
                """),
            .note("""
                De `Đ` wordt apart behandeld, want in Unicode is het **een eigen letter** en geen `D` met een \
                teken erop — gewoon accenten weghalen raakt hem niet.
                """),
            .paragraph("""
                Het CSV-filter aanvaardt ook een `=`-voorvoegsel voor een exacte vergelijking. De `=`-vorm is \
                **eveneens ongevoelig voor accenten**, want een filter dat diakritische tekens onderscheidt \
                laat de gebruiker geloven dat de gegevens ontbreken.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnamese invoermethoden",
        summary: "EVKey, OpenKey, Unikey en de invoerbron van macOS typen rechtstreeks in het document.",
        keywords: ["invoermethode", "evkey", "unikey", "openkey", "telex", "vni"],
        blocks: [
            .paragraph("""
                Niets in te stellen. Telex en VNI werken allebei, ook over **meerdere cursors** — typ één keer \
                en elke cursor krijgt de juist geaccentueerde letter.
                """),
            .paragraph("""
                Zoekvelden, filtervelden en elk dialoogvenster aanvaarden de invoermethode net als de \
                bewerker.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Talen en formaten

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Talen en formaten",
        summary: "Twintig ingebouwde talen, zelfgedefinieerde talen, en gereedschap voor JSON · XML · YAML · logboeken.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Twintig ingebouwde talen",
        summary: "Kleuring uit een echte syntaxisboom, met de commentaartekens van elke taal.",
        keywords: ["syntaxis", "kleuring", "taal", "tree-sitter", "grammatica"],
        blocks: [
            .paragraph("""
                De taal wordt herkend aan de **bestandsextensie** (plus enkele bijzondere namen zoals \
                `Makefile`, `Dockerfile`, `Gemfile`). U kunt hem met de hand wijzigen in de statusbalk.
                """),
            .table(
                headers: ["Taal", "Extensies", "Regel- · blokcommentaar"],
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
                De laatste kolom is wat `⌘/` gebruikt. Talen zonder regelcommentaar (JSON, CSS, XML) krijgen \
                in plaats daarvan de blokvorm.
                """),
            .heading("Wat er met een syntaxisboom meekomt"),
            .bullets([
                "De **functielijst** in de navigatiekolom volgt de echte structuur, geen gokken op inspringing.",
                "**Invouwen** op structuur.",
                "**Haakjes koppelen** dat haakjes binnen tekenreeksen en commentaar overslaat.",
                "**Automatisch inspringen** dat een niveau toevoegt na `{`, en na `:` in Python en YAML.",
            ]),
            .note("""
                Drie zware grammatica's (C++, C#, Ruby) wonen in een **lui geladen** bibliotheek — ze worden \
                pas geladen wanneer u een bestand in die talen opent. Zo blijft de starttijd onder de halve \
                seconde.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Zelfgedefinieerde talen",
        summary: "Uw eigen formaat inkleuren met één JSON-bestand — zonder grammatica te schrijven.",
        keywords: ["udl", "eigen taal", "eigen logboek"],
        blocks: [
            .paragraph("""
                Het interne logboekformaat van een bedrijf, een eigen configuratietaal, een kleine DSL — geen \
                daarvan heeft een tree-sitter-grammatica, en er een schrijven vraagt een vertaler en wat \
                ontleedtheorie.
                """),
            .paragraph("""
                In plaats daarvan aanvaardt GEditor een **tabelgestuurde lexer** die in JSON is verklaard. Zet \
                het bestand in de map `grammars/` binnen de configuratiemap van GEditor en start opnieuw.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — een volledige taal",
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
            .heading("Elke sleutel"),
            .table(
                headers: ["Sleutel", "Type", "Betekenis"],
                rows: [
                    ["`name`", "tekenreeks", "De naam die in de statusbalk wordt getoond"],
                    ["`extensions`", "lijst van tekenreeksen", "Bestandsextensies, **zonder de punt**"],
                    ["`caseSensitive`", "booleaans", "Of trefwoorden hoofdlettergevoelig zijn"],
                    ["`lineComment`", "tekenreeks", "Teken voor commentaar tot regeleinde; laat weg als er geen is"],
                    ["`blockComment`", "lijst van 2 tekenreeksen", "`[open, sluit]`"],
                    ["`stringDelimiters`", "lijst van tekenreeksen", "Elk item is **één** teken dat een tekenreeks opent/sluit"],
                    ["`escapeCharacter`", "tekenreeks", "Ontsnappingsteken binnen tekenreeksen; leeg betekent dat de taal er geen heeft"],
                    ["`keywordGroups`", "object", "Groepsnaam → lijst met trefwoorden; drie groepen krijgen drie kleuren"],
                ]
            ),
            .paragraph("De drie groepsnamen met een eigen kleur zijn `keyword`, `type` en `constant`."),
            .warning("""
                Deze lexer **begrijpt geen nesting**. Structureel invouwen, de functielijst en het slimme \
                koppelen van haakjes blijven voorbehouden aan de twintig ingebouwde talen. Dat is een bewuste \
                ruil: in plaats daarvan verklaart u een taal in tien minuten in plaats van in een dag.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON-gereedschap",
        summary: "Opnieuw opmaken, verkleinen, sleutels sorteren en toetsen aan een JSON Schema.",
        keywords: ["json", "opmaken", "verkleinen", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Opdracht", "Wat ze doet"],
                rows: [
                    ["Opnieuw opmaken", "Breekt af en springt in om te kunnen lezen"],
                    ["Verkleinen", "Haalt alle overbodige witruimte weg"],
                    ["Sleutels sorteren", "Zet de sleutels van elk object op alfabet — zodat twee JSON-bestanden **te vergelijken** zijn"],
                    ["Toetsen aan JSON Schema…", "Toetst het document aan een schemabestand en somt elk probleem met zijn regel op"],
                ]
            ),
            .paragraph("""
                De toegepaste regels zijn **strikt RFC 8259**: geen komma's aan het einde, geen commentaar, \
                geen `NaN`. Een syntaxisfout wijst de precieze regel en kolom aan.
                """),
            .note("""
                **JSONL**-bestanden (één object per regel) worden ook herkend en hebben hun eigen gereedschap \
                in het hoofdstuk over het kennispakket.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath-bevragingen",
        summary: "Precies het deel eruit halen dat u nodig hebt uit een groot JSON-bestand.",
        keywords: ["jsonpath", "json-bevraging", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Typ een uitdrukking; de resultaten verschijnen als lijst waarin u kunt springen."),
            .table(
                headers: ["Schrijf", "Betekenis"],
                rows: [
                    ["`$`", "De wortel van het document"],
                    ["`$.name`", "De sleutel `name` bij de wortel"],
                    ["`$.orders[0]`", "Het eerste element van een reeks"],
                    ["`$.orders[*].total`", "De sleutel `total` van **elk** element"],
                    ["`$..province`", "De sleutel `province` op **elke diepte**"],
                    ["`$.orders[1:3]`", "Een plak: elementen 1 en 2"],
                ]
            ),
            .code(language: "text", caption: "De provinciecode van elke bestelling, hoe diep ook genest",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML-gereedschap",
        summary: "Opnieuw opmaken, verkleinen, syntaxis nakijken en toetsen aan een DTD of XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "toetsen", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Opdracht", "Wat ze doet"],
                rows: [
                    ["Opnieuw opmaken", "Springt in naar de diepte van de tags"],
                    ["Verkleinen", "Haalt de witruimte tussen tags weg"],
                    ["Syntaxis nakijken", "Ontbrekende sluittags, verkeerde nesting, ongeldige tekens"],
                    ["Toetsen aan DTD/XSD…", "Toetst aan een schema en meldt elk probleem met zijn regel"],
                    ["XPath uitvoeren…", "Voert een XPath-uitdrukking uit; de resultaten gaan in een nieuw tabblad open"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Typ een uitdrukking en de resultaten gaan open als **een teksttabblad**, één knooppunt per \
                regel. Bijvoorbeeld: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **De resultaten springen NIET naar een plek in het bronbestand.** De XPath-uitvoerder van het \
                systeem bouwt een eigen boom en bewaart de bytepositie van elk knooppunt niet, dus wat \
                terugkomt is INHOUD en geen coördinaten. Om de precieze plek te bereiken gebruikt u `⌘F` op de \
                tekenreeks die u net vond.
                """),
            .paragraph("""
                In `.xml`- en `.html`-bestanden laat `>` typen om een openingstag af te sluiten de **sluittag \
                verschijnen** met de cursor ertussen. Zelfsluitende tags (`<br/>`), verklaringen (`<?xml …?>`) \
                en commentaar niet — die hebben niets te sluiten.
                """),
            .warning("""
                XML opnieuw opmaken **verandert de witruimte tussen tags**. In documenten waar die witruimte \
                betekenis heeft — XHTML met tekst binnen tags bijvoorbeeld — verandert dat wat er wordt \
                getoond. Het is één stap terug, dus `⌘Z` draait het terug.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML nakijken",
        summary: "De twee meest voorkomende YAML-fouten vangen: dubbele sleutels en inspringing met tabs.",
        keywords: ["yaml", "yml", "lint", "dubbele sleutel", "inspringing"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Dubbele sleutels** in één toewijzing — de meeste YAML-lezers nemen de **laatste** en laten de eerdere stilletjes vallen, zodat een configuratiebestand zich heel anders kan gedragen dan u denkt.",
                "**Inspringing met tabs** — YAML verbiedt tabs in de inspringing, en de foutmeldingen van bibliotheken daarover zijn meestal onbegrijpelijk.",
            ]),
            .note("Zet `Onzichtbaren tonen ▸ Tabs` aan om meteen te zien welke witruimte een tab is."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Logbestanden",
        summary: "Zeven ernstniveaus, filteren per niveau, en hoe u een heel groot logboek leest.",
        keywords: ["logboek", "log", "fout", "waarschuwing", "filter", "niveau"],
        blocks: [
            .paragraph("""
                Zet `Weergave ▸ Logboekmodus (kleuren op niveau)` aan. GEditor leest de ernst aan het **begin \
                van elke regel** — na het tijdstempel en de procesnaam.
                """),
            .table(
                headers: ["Niveau", "Kleur"],
                rows: [
                    ["CRITICAL · ERROR", "Rood"],
                    ["WARNING", "Amber"],
                    ["NOTICE", "Accentkleur"],
                    ["INFO", "Gewone tekst"],
                    ["DEBUG · TRACE", "Gedempt"],
                ]
            ),
            .paragraph("""
                `Logboek filteren op niveau…` verbergt de lagere niveaus helemaal. Regels waarvan het niveau \
                **niet wordt herkend** — het vervolg van een stapelspoor bijvoorbeeld — blijven met rust in \
                plaats van het niveau van de vorige regel te krijgen.
                """),
            .heading("Een groot logboek lezen, stap voor stap"),
            .steps([
                "Open het bestand — ook op gigabyteschaal gaat het bijna onmiddellijk open.",
                "`Weergave ▸ Logboekmodus` om te zien waar het rood zit.",
                "`⌥⌘M` voor de documentkaart: zit het rood in één stuk bij elkaar of verspreid over het hele bestand?",
                "`⌘F` voor de foutcode, `⌘M` om elke passende regel te markeren.",
                "`Zoek ▸ Gemarkeerde regels kopiëren` om ze naar een nieuw tabblad te halen.",
                "Loopt het nog? `Bestand ▸ Bestand volgen (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
