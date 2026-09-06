import Foundation

/// Magyar súgótartalom — 1. rész: kezdés és szerkesztés.
///
/// **A témák `id` azonosítóit SOHA nem fordítjuk.** Ezekre mutat a `.seeAlso`, ezeket nyitja meg a
/// menü, és ezek teszik lehetővé, hogy a súgóablak nyelvet váltson **anélkül, hogy az olvasót
/// visszadobná a tartalomjegyzékhez**. Egy id megváltoztatása minden hivatkozást eltör — az összes
/// könyvben egyszerre.
///
/// A `commands:` menücímei vietnamiul maradnak: szóról szóra egyezniük kell a valódi
/// menüpontokkal, amit a `HelpCoverage` épp ezen a karakterláncon keresztül ellenőriz.
enum HelpHU {}

extension HelpHU {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Kezdés",
        summary: "Mit tud a GEditor, és hová érdemes szánni az első öt percet.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Mi a GEditor",
        summary: "Gigabájtos léptékű szöveg- és adatszerkesztő macOS-re, amely beszél vietnamiul.",
        keywords: ["bevezetés", "üdvözlés", "áttekintés", "névjegy"],
        blocks: [
            .paragraph("""
                A GEditor megnyit **egy 1 GB-os fájlt anélkül, hogy 1 GB-ot betöltene a memóriába**. \
                Csúszóablakon át olvas egy memóriába leképezett fájlt, így egy 200 millió soros napló \
                vagy egy egymillió soros CSV körülbelül egy másodperc alatt nyílik meg, és simán \
                gördül.
                """),
            .paragraph("""
                A szerkesztésen túl **adatműhely**: nézze a CSV-t táblázatként, tisztítsa meg, \
                pontozza a minőségét, kérdezze le SQL-lel, bányásszon benne rendellenességeket és \
                trendeket, majd készítsen jelentést. És olvassa azokat a régi vietnami \
                karakterkódolásokat, amelyeket a mai eszközök nagy része elfelejtett.
                """),
            .heading("Hat dolog, amit érdemes először kipróbálni"),
            .table(
                headers: ["Feladat", "Hová menjen"],
                rows: [
                    ["Nagy fájl megnyitása várakozás nélkül", "Húzza az ablakba — lásd `Nagy fájlok megnyitása`"],
                    ["Sok helyen egyszerre szerkeszteni", "`⌘D` hozzáadja a következő találatot, aztán egyszer gépel"],
                    ["Reguláris kifejezéssel keresni", "`⌘F`, kapcsolja be a Regexet — a motor PCRE2 JIT-tel"],
                    ["CSV-t táblázatként nézni", "`⌥⌘T` — egymillió sor is simán gördül"],
                    ["Rendetlen adattáblát tisztítani", "`⇧⌘L` Tisztítópad — előnézet az alkalmazás előtt"],
                    ["Kacatot mutató vietnami fájl megnyitása", "Kattintson a kódolásra az állapotsorban"],
                ]
            ),
            .note("""
                Notepad++-ról jön? Van egy oldal, amely összeveti a két billentyűkiosztást, mert néhány \
                billentyű macOS-en **helyet cserél** ahelyett, hogy a `Ctrl`-ból egyszerűen `⌘` lenne.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Az első öt perce",
        summary: "Tizenkét gyorsbillentyű lefedi a napi munka nagy részét.",
        keywords: ["gyorsbillentyű", "billentyűk", "kezdés", "alapok"],
        blocks: [
            .paragraph("""
                Nem kell mindent megtanulnia. Az alábbi tizenkét billentyű a mindennapok nagy részét \
                lefedi; a többit akkor nézze meg, amikor szüksége lesz rá.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Fájl megnyitása"),
                HelpShortcut("⇧⌘O", "Egész mappa megnyitása munkaterületként"),
                HelpShortcut("⌘T", "Új lap"),
                HelpShortcut("⌘S", "Mentés"),
                HelpShortcut("⌘F", "Keresés"),
                HelpShortcut("⌥⌘F", "Keresés és csere"),
                HelpShortcut("⇧⌘F", "Keresés egész mappában"),
                HelpShortcut("⌘D", "A kijelölés következő előfordulásának hozzáadása"),
                HelpShortcut("⌘L", "Ugrás sorra"),
                HelpShortcut("⌘/", "Sor megjegyzésbe a nyelv saját jelével"),
                HelpShortcut("⌥⌘T", "Váltás táblázat és szöveg között (CSV-fájlok)"),
                HelpShortcut("⌘?", "Ennek a súgóablaknak az újranyitása"),
            ]),
            .heading("Három dolog, ami meglepi az újakat"),
            .bullets([
                "**Egy tömeges művelet EGY visszavonási lépés**, akkor is, ha egymillió sort érint. Rosszul rendezett? Egy `⌘Z`, és eltűnt.",
                "**A munkamenet magától visszaáll.** Lépjen ki, nyissa meg újra: a lapok visszatérnek oda, ahol voltak, a mentetlenek is. Nincs mit megnyomni.",
                "**Az ékezet nélküli gépelés is megtalálja az ékezetes szavakat** minden kereső- és szűrőmezőben — írja be, hogy `hue`, és megkapja: `Huế`; `da nang` → `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Mit szeretne csinálni?",
        summary: "Kereszttábla valós feladatoktól az azokat lefedő fejezethez.",
        keywords: ["tárgymutató", "keresés", "hogyan"],
        blocks: [
            .paragraph("""
                A bal oldali tartalomjegyzék **funkció** szerint van rendezve. Ez a táblázat **feladat** \
                szerint, mert a két sorrend nem esik egybe.
                """),
            .table(
                headers: ["Szükségem van rá, hogy…", "Lásd"],
                rows: [
                    ["Ugyanazt a helyet javítsam több száz soron", "Több kurzor · Oszlopblokk-kijelölés"],
                    ["Tömegesen formázzak reguláris kifejezéssel", "Keresés és csere · Reguláris kifejezések"],
                    ["Megismételjek egy műveletsort", "Makrók"],
                    ["Megnyissak egy CSV-t, amit küldtek", "A CSV-táblázat"],
                    ["Rendetlen táblát tisztítsak: kevert dátumok, számok szövegként", "A tisztítási folyamat"],
                    ["Megítéljem, megbízható-e egy tábla", "Adatminőség-pontozás"],
                    ["Rendellenességeket, trendeket, csoportokat találjak", "A bányászati folyamat"],
                    ["SQL-ben tegyek fel kérdéseket", "CSV lekérdezése SQL-lel"],
                    ["Jelentést adjak ki, amelynek számai újraszámolódnak", "`.greport.md` jelentések"],
                    ["Diagramot rajzoljak egy dokumentumba", "Mermaid"],
                    ["Kacatot mutató vietnami fájlt nyissak meg", "Vietnami karakterkódolások"],
                    ["Héjból vagy AppleScriptből automatizáljak", "Automatizálás"],
                    ["Színezzek egy formátumot, amit a cégem talált ki", "Saját nyelvek"],
                ]
            ),
            .note("""
                Nincs a listán? A bal felső keresőmező a **törzsszövegben és a kódmintákban** is néz, \
                így egy csupasz beállításkulcs, mint a `fail_under`, a megfelelő oldalra visz.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Nagy fájlok megnyitása",
        summary: "Miért nyílik meg egyáltalán az 1 GB, és hol tagadja meg a GEditor szándékosan a találgatás helyett.",
        keywords: ["nagy fájl", "gigabájt", "1gb", "napló", "mmap", "lassú", "teljesítmény"],
        blocks: [
            .paragraph("""
                A fájl **memóriába van leképezve**, és csúszóablakon át olvassuk; az a rész, amit \
                szerkeszt, egy darabtáblában él. A gyakorlatban: a megnyitási idő alig függ a fájl \
                méretétől, és a program által lefoglalt memória sem.
                """),
            .heading("Hol tagadja meg szándékosan"),
            .paragraph("""
                Néhány számításnak az egész fájlt egyetlen karakterláncba kellene olvasnia — épp ezt \
                kerüli ez a felépítés. Ott a GEditor **megmondja, hogy nem fogja**, ahelyett hogy \
                csendben kúszna vagy találgatna:
                """),
            .table(
                headers: ["Művelet", "Plafon", "Fölötte"],
                rows: [
                    ["Zárójelpárosítás", "1 MB", "Megtagadja és megmondja — rossz párt kiemelni rosszabb, mint semmit"],
                    ["Látható oszlop az állapotsoron", "200 kB", "Visszaáll bájtszámlálásra, és `~`-vel jelzi, hogy látszódjon a jelentése"],
                    ["Markdown-előnézet", "4 MB", "Megtagadja és megmagyarázza"],
                ]
            ),
            .warning("""
                Egy szám, amely ugyanúgy néz ki, de mást jelent, a legrosszabb fajta tévedés. Ezért ír \
                a plafon fölötti oszlop `~1234`-et, nem `1234`-et.
                """),
            .heading("Tippek naplófájlokhoz"),
            .bullets([
                "A `Fájl ▸ Fájl követése (tail -f)` hozzáfűzi, amit a végére írnak. A dokumentum követés közben **csak olvasható** lesz — gépelni, miközben új szöveg érkezik, két írót jelent egy dokumentumon, és a vesztes mindig az, amit épp beírt.",
                "A naplósorok **súlyosság szerint színeződnek**, és szint szerint szűrhetők.",
                "A **dokumentumtérkép** (`⌥⌘M`) az egész fájlt írja le, nem csak a látható részt.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App Store-kiadás kontra közvetlen letöltés",
        summary: "Három funkció, ami csak a közvetlen kiadásban van, és hogy miért.",
        keywords: ["app store", "homokozó", "letöltés", "cli", "bővítmény", "különbség"],
        blocks: [
            .paragraph("""
                A GEditor két kiadásban jelenik meg. **Ugyanabból a forráskódból** származnak, és az \
                alkalmazás indításkor felismeri, melyik ő. A különbség az, hogy mit enged az App \
                Sandbox.
                """),
            .table(
                headers: ["Funkció", "App Store", "Közvetlen letöltés"],
                rows: [
                    ["Minden szerkesztés, CSV, tisztítás, bányászat, jelentés", "Igen", "Igen"],
                    ["A `geditor` parancssori eszköz", "Nem", "Igen"],
                    ["Szöveg szűrése külső paranccsal", "Nem", "Igen"],
                    ["Natív bővítmények (külön folyamat)", "Nem", "Igen"],
                    ["Önfrissítés", "Az App Store-on át", "Az alkalmazáson belül"],
                ]
            ),
            .paragraph("""
                A fenti minden »Nem« ugyanabból a szabályból jön: a homokozó **tiltja az alkalmazáson \
                kívüli kód futtatását**. Ez az App Store-os terjesztés ára, nem mulasztás.
                """),
            .note("""
                Az App Store-kiadásban ezek a parancsok **a menüben maradnak**, és megmagyarázzák, \
                miért nem érhetők el, ahelyett hogy eltűnnének. Egy hiányzó menüpont kérdés a \
                támogatásnak; egy helyben adott válasz nem az.
                """),
            .heading("Fájlhozzáférés az App Store-kiadásban"),
            .paragraph("""
                A homokozós kiadás csak azokhoz a fájlokhoz nyúlhat, amelyeket Ön nyitott meg vagy \
                húzott be. A GEditor minden laphoz és a munkaterület mappájához **biztonsági hatókörű \
                könyvjelzőt** tart, így a munkamenete kilépés után újranyílik anélkül, hogy újra \
                engedélyt kérne.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Szerkesztés

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Szerkesztés",
        summary: "Szerkesszen sok helyen egyszerre, dolgozzon sorokkal, és ismerje meg a rejtett szabályokat.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Több kurzor",
        summary: "Jelöljön ki minden illeszkedő helyet, gépeljen egyszer, változtassa meg mindet.",
        keywords: ["többkurzoros", "cmd+d", "többszörös kijelölés"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Ez váltja ki a legtöbb pillanatot, amikor épp reguláris kifejezést kezdett volna írni. \
                Jelöljön ki egy szót, nyomja meg néhányszor a `⌘D`-t a következő előfordulások \
                begyűjtéséhez, aztán gépeljen — minden hely egyszerre változik.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "A következő előfordulás hozzáadása a kijelöléshez"),
                HelpShortcut("⌘ + kattintás", "Újabb kurzor oda, ahová kattint"),
                HelpShortcut("Esc", "Mind eldobása, vissza egy kurzorra"),
                HelpShortcut("⌥ + húzás", "Oszlopblokk-kijelölés (másik út sok kurzorhoz)"),
            ]),
            .heading("Érdemes tudni ezeket a szabályokat"),
            .bullets([
                "A gépelés, törlés és beillesztés sok kurzoron át **egy** visszavonási lépés, nem kurzoronként egy.",
                "A kurzorok túlélik a nyílbillentyűs mozgást — az egész csoport együtt mozdul.",
                "A `⌘D` átugorja a kijelölésben már benne lévő helyeket, így a túl sok nyomás sosem halmoz kurzorokat egymásra.",
            ]),
            .note("""
                A `⌘D` egy hosszú karakterláncon belüli szóra régen lassú volt. A szóhatár-felismerés \
                most kötegekben olvas — 1 MB-os karakterláncon nagyjából **42×-szer gyorsabban**, ami \
                ezt adatfájlokon is használhatóvá teszi, nem csak forráskódon.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Oszlopblokk-kijelölés",
        summary: "Jelöljön ki téglalapot sok soron át — egérrel vagy billentyűzetről.",
        keywords: ["oszlopmód", "blokk-kijelölés", "alt húzás", "téglalap", "billentyűzet"],
        blocks: [
            .paragraph("""
                Tartsa lenyomva az `⌥`-t és húzzon, hogy **téglalap alakú blokkot** jelöljön ki. A \
                gépelés, törlés és beillesztés mind a blokkot követi. Egy blokk beillesztése egyetlen \
                kurzornál is megtartja a téglalapot.
                """),
            .shortcuts([
                HelpShortcut("⌥ + húzás", "Blokk kijelölése"),
                HelpShortcut("⌥⌘← →", "A blokk szélesítése egy oszloppal balra/jobbra"),
                HelpShortcut("⌥⌘↑ ↓", "A blokk nyújtása egy sorral fel/le"),
            ]),
            .paragraph("""
                A billentyűzetes út nem az egér pótléka: 40 soros blokkot húzással kijelölni annyi, \
                mint görgetésen át húzni, míg az `⌥⌘` + nyilak oszloponkénti pontosságot tartanak. \
                Bármely **más** billentyű (vagy a gépelés) lezárja a bővített blokkot.
                """),
            .heading("Az oszlopok itt LÁTHATÓ oszlopok"),
            .paragraph("""
                Egy TAB a tabulátorszélessége szerinti következő ütközőig tágul, ahelyett hogy egy \
                oszlopnak számítana. Épp ez teszi, hogy a tabulátorral és szóközzel behúzott sorok \
                **úgy állnak egy vonalban, ahogy a képernyőn látszanak**.
                """),
            .paragraph("A többbájtos szöveg így is egy oszlop: a `Nguyễn` hat oszlopot foglal, nem kilencet."),
            .table(
                headers: ["Helyzet", "Mit tesz a GEditor"],
                rows: [
                    ["A céloszlop egy TAB közepére esik", "A közelebbi élhez pattan; döntetlennél balra"],
                    ["Egy sor rövidebb a kezdőoszlopnál", "Az a sor üres kijelöléssel járul hozzá, és így is fogadja a gépelt szöveget"],
                    ["Blokk beillesztése egyetlen kurzornál", "Megtartja a téglalapot, lefelé szúrva be az alatta lévő sorokba"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Oszlopszerkesztő",
        summary: "Szúrjon szöveget, számsort vagy dátumsort egy blokk minden sorába.",
        keywords: ["oszlopszerkesztő", "számozás", "sorozat"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Jelöljön ki egy oszlopblokkot, majd nyissa meg a `Szerkesztés ▸ Column Editor…` \
                (`⌥⌘C`) menüpontot. A párbeszédablakban **előnézet** van, mielőtt bármi alkalmazódna.
                """),
            .table(
                headers: ["Mód", "Paraméterek", "Használja, ha"],
                rows: [
                    ["Szöveg", "Rögzített karakterlánc", "Ugyanazt az elő-/utótagot adja minden sorhoz"],
                    ["Számsor", "Kezdet · lépés · alap 2·8·10·16 · nullákkal feltöltés", "Sorokat számoz vagy kódokat állít elő"],
                    ["Dátumsor", "Első dátum · lépés napokban", "Egymást követő dátumok oszlopát készíti"],
                ]
            ),
            .code(language: "text", caption: "Számozás nullákkal, kezdet 1, lépés 1",
                  source: """
                    Előtte:           Utána (számsor, 3 jegyre feltöltve):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "A **negatív** lépés érvényes — a visszaszámlálás működik.",
                "5000 sorba beszúrni ugyanúgy **egy** visszavonási lépés.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Sorműveletek",
        summary: "Rendezés, ismétlődések kiszűrése, mozgatás, összefűzés, felbontás, kettőzés, törlés.",
        keywords: ["rendezés", "kettőzés", "ismétlődés", "sor mozgatása", "összefűzés", "felbontás"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Kijelöléssel a parancs a kijelölésen fut; anélkül **az egész dokumentumon**. Minden \
                itteni parancs egyetlen visszavonási lépés.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Sor kettőzése"),
                HelpShortcut("⌘K", "Sor törlése"),
                HelpShortcut("⌥↑ / ⌥↓", "Sor mozgatása fel / le"),
            ]),
            .heading("Háromféle rendezés, és melyiket válassza"),
            .table(
                headers: ["Fajta", "`file2` kontra `file10`", "Mire jó"],
                rows: [
                    ["A→Z / Z→A", "A `file10` megelőzi a `file2`-t", "Egyszerű szólistákhoz"],
                    ["Természetes", "A `file2` megelőzi a `file10`-et", "Fájlnevekhez, kódolt azonosítókhoz, verziókhoz"],
                ]
            ),
            .paragraph("""
                A **természetes** rendezés a számjegysorozatokat számként olvassa. Szinte mindig ezt \
                akarja, ha a lista számozott.
                """),
            .heading("Ismétlődések kiszűrése"),
            .bullets([
                "**Egész dokumentum** — dobjon el minden sort, ami korábban már szerepelt, tartsa meg az elsőt.",
                "**Csak szomszédos** — vonja össze az azonos szomszédos sorokat, mint a Unix `uniq`.",
            ]),
            .heading("Összefűzés és felbontás"),
            .bullets([
                "A **sorok összefűzése** a kijelölt sorokat egybe olvasztja.",
                "A **felbontás hossz szerint** adott karakterszámnál vágja el a hosszú sorokat.",
                "A **felbontás karakter szerint** a beírt karakter minden előfordulásánál vág — például egy CSV-sort a celláira bontva.",
            ]),
            .note("""
                A fájl **utolsó sorának** kettőzése pótolja a hiányzó sorvéget; a dokumentum végéig \
                törölve az előző sor sorvégét is elnyeli. Mindkettő eltér a naiv megvalósítástól, és \
                mindkettő azért van, hogy a fájl ne végződjön egy elárvult üres sorral — vagy anélkül.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Üres karakterek és behúzás",
        summary: "Takarítson el elkószált szóközöket, váltson TAB ↔ szóköz, és egy kapcsoló, amin érdemes gondolkodni.",
        keywords: ["üres karakter", "tabulátor", "szóköz", "behúzás", "üres sorok"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Parancs", "Mit csinál"],
                rows: [
                    ["Üres sorok eltávolítása", "Eldob minden sort, amin nincs semmi"],
                    ["Egymás utáni üres sorok összevonása", "Több egymás utáni üres sorból egy lesz"],
                    ["Sorvégi üres karakterek levágása", "Eltávolítja az elkószált szóközöket és tabulátorokat minden sor végéről"],
                    ["Tab → szóköz", "TAB-okat szóközzé alakít az aktuális tabulátorszélességgel"],
                    ["Szóköz → Tab", "A másik irány"],
                ]
            ),
            .heading("Nyelvenkénti behúzás"),
            .paragraph("""
                Kattintson a `Tab: 4` mezőre az állapotsoron. A menü felső része **az egész \
                alkalmazásra** változtatja; az alsó — `Csak Go-hoz`, `Csak Pythonhoz`… — csak a nyitott \
                fájl nyelvére vonatkozik, és megjegyzi, tabulátor vagy szóköz legyen-e.
                """),
            .paragraph("""
                Az emberek nem ízlés, hanem **közösségi szokás** szerint választanak behúzást: a Go \
                tabulátort használ (a `gofmt` mindent felülír), a Python négy szóközt a PEP 8 szerint, \
                a JavaScript és a YAML rendszerint kettőt. Egyetlen szám minden nyelvre azt jelenti, \
                hogy minden megérintett fájlban keletkeznek sorok, amelyeket sosem szerkesztett.
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
                A `settings.json`-ban való megadás is működik — a kulcs a nyelvkód (`go`, `python`, \
                `javascript`…). A hiányzó nyelvek a közös `tabWidth`-et használják.
                """),
            .heading("Miért van a »levágás mentéskor« alapból KIKAPCSOLVA"),
            .paragraph("""
                A `Fájl ▸ Sorvégi üres karakterek levágása mentéskor` kapcsoló **olyan sorokat \
                szerkeszt, amelyekhez hozzá sem nyúlt**. Alapból bekapcsolva egy egyszavas javítás \
                valaki más tárolójában ezersoros különbséggé válik, és a bíráló nem találja meg a \
                valódi változást.
                """),
            .paragraph("""
                Ha be van kapcsolva, a levágás **külön visszavonási lépés** az írás előtt — egyetlen \
                visszavonás visszaadja a dokumentumot úgy, ahogy volt, anélkül hogy elveszne, amit épp \
                mentett.
                """),
            .heading("Automatikus behúzás"),
            .bullets([
                "Egy új sor örökli az előző behúzását, plusz egy szintet nyitó jel után — `{` a kapcsos nyelvekben, `:` Pythonban és YAML-ban.",
                "A mérés **látható oszlopokban** történik, így a tabulátort és szóközt keverő fájlok is egy vonalban maradnak a képernyőn.",
                "**Nincs** olyan szabály, hogy »a `}` beírása újrahúzza a sort«. Az a szabály egy már befejezett sort szerkeszt, és minden szerkesztőben, ahol van, ez a legtöbbet panaszolt viselkedés.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Kis-/nagybetű és elnevezési szokások",
        summary: "Nyolc átalakítás, köztük camelCase, snake_case és kebab-case.",
        keywords: ["kisbetű", "nagybetű", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("A kijelölésre alkalmazódnak. Mind a `Formátum` menüben vannak."),
            .table(
                headers: ["Parancs", "A `tổng doanh thu` így lesz"],
                rows: [
                    ["NAGYBETŰS", "`TỔNG DOANH THU`"],
                    ["kisbetűs", "`tổng doanh thu`"],
                    ["Minden Szó Nagybetűvel", "`Tổng Doanh Thu`"],
                    ["Mondatkezdő nagybetű", "`Tổng doanh thu`"],
                    ["Megfordítás", "Minden karaktert megfordít"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Az utolsó három eltávolítja a vietnami ékezeteket, mert **kódbeli azonosítókat** \
                állítanak elő — ahol az ékezetes betűk általában nem megengedettek.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Megjegyzések és zárójelpárosítás",
        summary: "A ⌘/ az adott nyelv jelét használja; a ⌃⌘B a megfelelő zárójelre ugrik.",
        keywords: ["megjegyzés", "zárójel", "cmd+/", "párosítás"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                A `⌘/` **a dokumentum nyelve szerint** választ megjegyzésjelet: `#` Pythonhoz, `//` \
                Rusthoz és C-hez, `<!-- -->` XML-hez és HTML-hez.
                """),
            .heading("Az egész blokk egy irányba megy"),
            .paragraph("""
                Ha akár egyetlen sor is megjegyzés nélküli a blokkban, a parancs **mindent** \
                megjegyzésbe tesz. Soronként dönteni sakktáblává tenne egy félig megjegyzett blokkot. A \
                jel a blokk legkisebb behúzásához kerül, így a blokk megtartja az alakját.
                """),
            .heading("Ugrás a megfelelő zárójelre"),
            .bullets([
                "A `⌃⌘B` a kurzornál lévőnek megfelelő zárójelre ugrik.",
                "A **karakterláncokon** vagy **megjegyzéseken** belüli zárójelek nem számítanak — egy könnyű lexer különbséget tesz.",
                "**1 MB** fölött a parancs megtagadja és megmondja, ahelyett hogy félúton lehorgonyozna és találgatna. Rossz párt kiemelni rosszabb, mint egyet sem.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Visszavonás és vágólap",
        summary: "Korlátlan visszavonási előzmény és többhelyes vágólap-előzmény.",
        keywords: ["visszavonás", "újra", "vágólap", "beillesztés", "előzmény"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Visszavonás / újra"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Kivágás / másolás / beillesztés"),
                HelpShortcut("⇧⌘V", "Vágólap-előzmény"),
            ]),
            .heading("Egy tömeges művelet EGY lépés"),
            .paragraph("""
                Egymillió sor rendezése, tízezer találat cseréje, ötezer sorba beszúrás az \
                oszlopszerkesztővel — mindegyiket **egy** `⌘Z` vonja vissza.
                """),
            .paragraph("""
                A visszavonási előzmény a GEditor saját szövegpufferében él, nem a rendszer \
                `UndoManager`-ében, épp ezért: az `UndoManager` billentyűleütéseket számol.
                """),
            .heading("Vágólap-előzmény"),
            .paragraph("""
                A `⇧⌘V` megnyitja a nemrég másoltak listáját, és beilleszti a kiválasztottat. Hasznos, \
                ha sok helyen kell két részletet váltogatnia.
                """),
        ]
    )
}
