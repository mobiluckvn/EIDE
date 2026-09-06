import Foundation

/// Magyar súgótartalom — 3. rész: nézetek, vietnami, nyelvek és formátumok.
extension HelpHU {

    static let views = HelpChapter(
        id: "xem",
        title: "Dokumentumnézetek",
        summary: "Oldalsáv, térkép, összecsukás, osztott nézet, tördelés, láthatatlan karakterek, színezési módok.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Oldalsáv és függvénylista",
        summary: "A mappafa és a nyitott fájl függvénylistája egy oszlopban.",
        keywords: ["oldalsáv", "függvénylista", "vázlat", "fájlfa"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Oldalsáv megjelenítése / elrejtése")]),
            .paragraph("""
                A függvénylista a nyelv **szintaxisfájából** épül, így a valódi szerkezetet követi \
                ahelyett, hogy a behúzásból találgatna. Egy bejegyzésre kattintva odaugrik.
                """),
            .note("A függvénylista szűrőmezője **ékezet nélküli gépelésből is megtalálja az ékezetes szöveget**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Dokumentumtérkép",
        summary: "Az egész fájl egy keskeny oszlopban jobbra — több száz MB-nál is.",
        keywords: ["minitérkép", "térkép", "áttekintés"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Dokumentumtérkép megjelenítése / elrejtése")]),
            .paragraph("""
                A térkép **az egész fájlt** írja le, nem csak a képernyőn lévőt. Ha húz rajta, a \
                megfelelő területre ugrik.
                """),
            .paragraph("""
                A keresési találatok és a megjelölt sorok megjelennek a térképen, így látja, szórtak-e \
                vagy csoportosulnak, mielőtt odagörgetne.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Összecsukás",
        summary: "Csukja össze a függvényeket, blokkokat és tömböket szerkezet szerint — vagy csukja a fájlt egy szintre.",
        keywords: ["összecsukás", "kódösszecsukás"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "A kurzornál lévő blokk összecsukása / kinyitása"),
                HelpShortcut("⌥⇧⌘←", "Minden összecsukása"),
                HelpShortcut("⌥⌘→", "Minden kinyitása"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Az egész fájl összecsukása az 1…8. szintre"),
            ]),
            .paragraph("""
                Szintaxisfával rendelkező nyelveknél az összecsukás a **valódi szerkezetet** követi. \
                Nyelvtan nélküli fájloknál a behúzást.
                """),
            .paragraph("""
                Az `Összecsukás szintre` mély JSON-nál és YAML-nál mutatja meg értékét: a 2. szintre \
                csukás egy képernyőre teszi az egész fájl alakját.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Osztott nézet",
        summary: "Két panel egymás mellett, két fájlhoz — vagy egy fájl két helyéhez.",
        keywords: ["osztás", "panelek", "összehasonlítás"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Függőleges osztás"),
                HelpShortcut("⌥⌘-", "Vízszintes osztás"),
                HelpShortcut("⌥⌘0", "Osztás megszüntetése"),
                HelpShortcut("⌥⌘]", "Ennek a lapnak a megnyitása a másik panelen"),
                HelpShortcut("⌥⌘[", "Ugrás a másik panelre"),
            ]),
            .paragraph("""
                Minden panelnek saját lapsávja van. **Ugyanazt a fájlt** mindkét panelen megnyitni \
                rendben van — függetlenül görögnek, ami megkönnyíti egy fájl elejének és végének \
                összevetését.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Sortördelés",
        summary: "Három mód: kikapcsolva, az ablak szélén, vagy rögzített oszlopnál.",
        keywords: ["tördelés", "lágy tördelés"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Mód", "Egy hosszú sor"],
                rows: [
                    ["Kikapcsolva", "Vízszintesen görget"],
                    ["Az ablaknál", "Az ablak szélén tördel, a méretét követve"],
                    ["Oszlopnál", "A beállított oszlopnál tördel — mondjuk 80-nál vagy 100-nál"],
                ]
            ),
            .paragraph("""
                A tördelés **nézési mód**, nem szerkesztés: nem szúr be sorvéget, és sosem kerül a \
                visszavonási előzménybe.
                """),
            .note("A gyors út ide a `Tördelés: …` mező az állapotsoron."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Betűméret",
        summary: "Nagyítás 8 és 32 pont között.",
        keywords: ["nagyítás", "betűméret", "nagyobb", "kisebb"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Nagyobb szöveg"),
                HelpShortcut("⌘-", "Kisebb szöveg"),
                HelpShortcut("⌃⌘0", "Vissza az alapméretre"),
            ]),
            .paragraph("""
                8 és 32 pont közé szorítva. Ez is **nézési mód**: nincs szerkesztés, semmi nem kerül a \
                visszavonási előzménybe. Az alapméret a `Beállítások…` alatt van.
                """),
            .note("A `⌘0` NEM az alapméret — az a billentyű az oldalsávot mutatja és rejti."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Láthatatlan karakterek megjelenítése",
        summary: "Egyszerre egy csoportot kapcsoljon be, mert mind egyszerre általában sok.",
        keywords: ["láthatatlan", "üres karakter", "nbsp", "nulla szélességű", "tabulátor"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Minden láthatatlan karakter megjelenítése / elrejtése")]),
            .paragraph("""
                Négy csoport kapcsolható külön, mert mindet egyszerre bekapcsolni pontok erdeje alá \
                temeti a tartalmat.
                """),
            .table(
                headers: ["Csoport", "Mit fog el"],
                rows: [
                    ["Szóközök", "Sorvégi szóközök, következetlen behúzás"],
                    ["Tabulátorok", "TAB-ot és szóközt keverő fájlok"],
                    ["Sorvégek", "CRLF-et és LF-et keverő fájlok"],
                    ["NBSP · nulla szélességű · vezérlő", "Láthatatlan karakterek Wordből, a webről, táblázatkezelőkből"],
                ]
            ),
            .warning("""
                Az utolsó csoport az, ami embereket ment meg. A weboldalról beillesztett nem törhető \
                szóköz (NBSP) **pontosan** úgy néz ki, mint egy közönséges szóköz, mégis minden \
                karakterlánc-összehasonlítást és minden szűrőt eltéveszt — és e csoport bekapcsolása \
                nélkül nincs mód meglátni.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV-mód és naplómód",
        summary: "Két színezési séma, amely a szintaxiskiemelést váltja fel, kétféle adatfájlhoz.",
        keywords: ["csv-mód", "naplómód", "kiemelés", "oszlopok", "naplószint"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV-mód"),
            .paragraph("""
                Minden oszlopnak saját színt ad a **szöveg**nézetben, így látja, melyik cella csúszott \
                el egy oszloppal, anélkül hogy táblázatra váltana.
                """),
            .heading("Naplómód"),
            .paragraph("""
                A sorból kiolvasott **súlyosság** szerint színez: hibák pirosan, figyelmeztetések \
                borostyánsárgán, míg a `debug` és a `trace` halványul — ezek teszik ki a naplófájl nagy \
                részét, és kiemelni őket épp azt halványítja, amit keres.
                """),
            .paragraph("A `Napló szűrése szint szerint…` teljesen elrejti a nem kellő szinteket."),
            .note("""
                Ez a kettő a szintaxiskiemelés **helyett** színez, nem fölötte. Egy naplófájlnak nincs \
                színezhető szintaxisa, és két színforrás ugyanarra a bájttartományra írva nem hagy \
                kiszámítható győztest.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Bináris nézet",
        summary: "Hexatábla bármely fájlhoz — még egy 1 GB-oshoz is, szinte azonnal nyílik.",
        keywords: ["hex", "bináris", "bájt", "eltolás", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                A `Nézet ▸ Bináris nézet` minden bájtot háromoszlopos táblaként mutat: **eltolás · hex \
                · szöveg**. **Bármely** lemezen lévő fájlra működik, nem csak képekre vagy videóra.
                """),
            .table(
                headers: ["Oszlop", "Tartalom"],
                rows: [
                    ["Eltolás", "Bájtpozíció, tizenhatos számrendszerben"],
                    ["Hex", "16 bájt soronként, a nyolcadik után elválasztva a könnyebb számoláshoz"],
                    ["Szöveg", "Nyomtatható ASCII-bájtok; minden más egy `.`"],
                ]
            ),
            .note("""
                A szövegoszlop **nem dekódol UTF-8-at**. Egy vietnami betű két vagy három bájt, így a \
                megjelenítése kitolná a szövegoszlopot a hexaoszlop vonalából — és épp ez az \
                egyvonalúság a lényege ennek az oszlopnak. Ékezetes szöveg olvasásához használja a \
                szokásos nézetet.
                """),
            .heading("Nagy fájlok"),
            .paragraph("""
                A fájl **memóriába van leképezve**, így egy 1 GB-os fájl megnyitása bináris nézetben \
                csak annyiba kerül, amennyit megnéz. Az önteszt-készletben mérve: **egy ezredmásodperc \
                alatt**.
                """),
            .paragraph("""
                A nézet egyszerre **egy 4 MB-os ablakot** mutat, és a felső sáv megmondja, melyik \
                tartományban jár. Ez a rendszer táblarajzolójának korlátja, nem az olvasásé: egy 1 \
                GB-os fájl 62,5 millió sor, és egy ponton túl a sorok ugrálni kezdenek görgetés közben \
                — egy ugráló hexatábla pedig használhatatlan.
                """),
            .heading("Ugrás pozícióra"),
            .table(
                headers: ["Írja az eltolásmezőbe", "Jelentés"],
                rows: [
                    ["`1F400`", "Tizenhatos — az alapértelmezett"],
                    ["`0x1F400`", "Ugyanaz, kifejezett előtaggal"],
                    ["`#128000`", "Tízes, ha bájtszáma van, nem hexa eltolása"],
                ]
            ),
            .bullets([
                "A `‹` és a `›` az előző / következő ablakra lép.",
                "A **Kijelölt sorok másolása** pontosan azt másolja, amit lát — kijelölés nélkül az egész ablakot.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown-előnézet",
        summary: "Formázott szövegként jeleníti meg a Markdownt — és nyíltan megmondja, mit nem jelenít meg.",
        keywords: ["markdown", "előnézet", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("""
                A rendszer Markdown-támogatásával jelenik meg: félkövér, dőlt, kód, hivatkozások, \
                listák.
                """),
            .warning("""
                **Nincsenek táblázatok, és nincs szintaxisszínezés a kódblokkokon belül.** Az \
                előnézeti ablak ezt az alján kiírja. A **4 MB**-nál nagyobb dokumentumokat elutasítja.
                """),
            .paragraph("""
                Táblázatok és diagramok kellenek egy közzétehető dokumentumban? Arra valók a \
                `.greport.md` jelentések, nem ez az előnézet.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Két mód: View és Code",
        summary: "Egy billentyű vált a megjelenített alak és a szerkeszthető forrás között, minden fájltípusnál.",
        keywords: ["view", "code", "mód", "forrás", "megjelenített", "előnézet"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Váltás View és Code között")]),
            .paragraph("""
                A vezérlő **a lapsáv alatti sávban** ül — minden fájltípusnál ugyanott: egy `View | \
                Code` kapcsoló, majd az adott fájl View-módjának neve (»Dokumentumoldalak«, \
                »Kulcs–érték fa«, »Diagram«…). Egyetlen móddal rendelkező fájlnál a kapcsoló szürke, és \
                a sáv megmondja, miért. A jobb szélen az egyes típusok saját gombjai ülnek: az `.xlsx` \
                **Táblázat** (szerkeszthető, közvetlenül visszaíródik), a `.pptx` **Vázlat**.
                """),
            .note("""
                **A Word és a PowerPoint dokumentumolvasóként viselkedik.** A View-módjuk valódi \
                oldalakat épít — helyes betűtípusokkal, méretekkel és színekkel, képekkel, \
                táblázatokkal, élőfejjel és élőlábbal, oldalszámokkal együtt. Egy oldal **pontosan olyan \
                széles, mint a keret**, és nagyítható. Az Excel szándékos kivétel: a View-ja \
                **szerkeszthető táblázat**, mert egy munkalapnak nincs papírmérete, amíg ki nem nyomtatják.
                """),
            .note("""
                Cserébe az oldalak **csak olvashatók**, és a **lemezen lévő másolatot** jelenítik meg: \
                szerkesszen Code-ban mentés nélkül, és az oldalak a régi változatot mutatják — a sáv \
                ezt kiírja, `Mentés és újramegjelenítés` gombbal.
                """),
            .heading("Meghatározások"),
            .bullets([
                "A **Code** a **szerkeszthető forrás**. Szövegfájlnál maga a szöveg. Bináris fájlnál — PDF, kép, hang, videó — nincs szöveges forrás, így a Code a **bájtok**, hexában mutatva.",
                "A **View** az, ami a Code-ból **megjelenik**. Lehet szebb, rövidebb vagy futtatható — de mindig következmény, sosem az eredeti.",
            ]),
            .paragraph("""
                Azt mondani egy PDF-re, hogy *»ennek a típusnak nincs Code-ja«*, kényelmes volna, de \
                téves: a bájtok valóban a forrása.
                """),
            .heading("Hol történik a szerkesztés"),
            .paragraph("""
                A szerkesztés a **Code**-ban történik. Pontosan **két kivétel** van, mindkettő azért, \
                mert View-ban szerkeszteni sokkal természetesebb: a **CSV-táblázat cellái** és a \
                **PDF-űrlapmezők**. Mindkettő közvetlenül a forrásba ír, így nem születik második \
                másolat, amivel vitatkozni lehetne.
                """),
            .heading("Fájltípusonként"),
            .table(
                headers: ["Fájltípus", "View", "Code", "Szerkesztés"],
                rows: [
                    ["CSV · TSV", "Táblázat", "Nyers szöveg", "**Mindkettő**"],
                    ["Excel `.xlsx`", "A nyitott munkalap táblázata", "Az a lap CSV-ként", "**Mindkettő**"],
                    ["PDF", "Megjelenített oldalak", "Bináris", "**Mindkettő** — jegyzetek, űrlapmezők, oldalak"],
                    ["Markdown `.md`", "Megjelenített szöveg", "Markdown-forrás", "Code"],
                    ["Jelentés `.greport.md`", "Jelentés lefuttatott lekérdezésekkel és megrajzolt diagramokkal", "Forrás", "Code"],
                    ["JSON", "Kulcs–érték fa, összecsukható", "JSON-forrás", "Code"],
                    ["XML · HTML", "Címkefa, összecsukható", "XML-forrás", "Code"],
                    ["YAML", "Kulcs–érték fa behúzás szerint", "YAML-forrás", "Code"],
                    ["Diagramok `.mmd` · `.dot`", "A megrajzolt diagram, a lapot kitöltve", "mermaid- vagy DOT-forrás", "Code"],
                    ["Word `.docx`", "Megjelenített dokumentumoldalak", "Kivont Markdown", "Code"],
                    ["PowerPoint `.pptx`", "Megjelenített diaoldalak", "Markdown-vázlat", "Code"],
                    ["Naplófájlok", "Szint szerint színezve, szűrhetően", "Nyers szöveg", "Code"],
                    ["Képek", "A kép (az animáltak lejátszódnak)", "Bináris", "Csak olvasható"],
                    ["Hang · videó", "Lejátszó", "Bináris", "Csak olvasható"],
                    ["Archívumok", "Bejegyzéslista", "Bináris", "Csak olvasható"],
                    ["Forráskód, egyszerű szöveg", "— nincs", "Maga a szöveg", "Code"],
                ]
            ),
            .note("""
                A forráskódnak **nincs View-ja**, és ez normális, nem hiányosság: egy Swift-fájlnak \
                nincs megnézésre érdemes megjelenített alakja.
                """),
            .heading("A Word és PowerPoint oldalolvasója"),
            .paragraph("""
                Az oldalak függőlegesen egymásra épülnek és folyamatosan görögnek, mindegyik fehér lap \
                szürke háttéren — mint minden dokumentumolvasóban. A vezérlői a sáv jobb szélén ülnek.
                """),
            .table(
                headers: ["Gomb / billentyű", "Mit csinál"],
                rows: [
                    ["`Szélesség igazítása`", "A lap pontosan olyan széles, mint a keret — az alapértelmezett"],
                    ["`Oldal igazítása`", "Az egész lap belefér a keretbe"],
                    ["`−` `+`", "Nagyítás lépésekben; vagy csippentés, vagy ⌘ + görgetés"],
                    ["A `Keresés` mező vagy ⌘F", "Keresés az oldalakon belül, odaugrás és kiemelés"],
                    ["Enter a keresőmezőben", "Következő találat"],
                    ["Húzás", "Szöveg kijelölése; dupla kattintás szóra, hármas bekezdésre"],
                    ["⌘A · ⌘C", "Mindent kijelöl · a kijelölés másolása"],
                    ["Page Up · Page Down · Home · End", "Mozgás a dokumentumban"],
                ]
            ),
            .paragraph("""
                A keresőmező **figyelmen kívül hagyja az ékezeteket és a kis-/nagybetűt**: a `vuong \
                quoc` beírása megtalálja a `Vương quốc`-ot. A sávban lévő »12/363. oldal« felirat \
                mondja meg, hol jár.
                """),
            .note("""
                **Amit nem jelenít meg, nyíltan kimondva:** a lebegő rögzített képek (a képet körülfolyó \
                szöveg) beágyazott képekként jelennek meg; a lábjegyzetek, diagramok és a PowerPoint \
                SmartArtja nem rajzolódnak ki. Ha pontos egyezés kell a nyomtatott változattal, nyissa \
                meg Wordben.
                """),
            .heading("Egy csomópontra kattintva visszaugrik a forrásba"),
            .paragraph("""
                Egy JSON-fa nem szép kinyomat: egy csomópontra kattintva a kurzor **annak a \
                csomópontnak az ÉRTÉKÉHEZ** kerül a szövegben, és a lap visszatér a Code-ba — mert amit \
                utána akar, az szinte mindig az, hogy szerkessze, amire épp kattintott.
                """),
            .bullets([
                "A tárolócsomópontok az **elemszámukat** mutatják (`{12}`, `[340]`), nem a tartalmukat — épp ez válaszol arra, hogy »érdemes-e ezt kinyitni«.",
                "**Az első két szint** nyitva van: egy tízezer csomópontos fájl teljes kinyitása a forrásnál hosszabb listát ad, míg teljes összecsukása azt jelenti, hogy kattintgatás nélkül semmit sem fedez fel.",
                "**Érvénytelen szintaxisú** fájl nem kap fél fát — egy csonka fa úgy néz ki, mint egy dokumentum, ami egyszerűen ilyen keveset tartalmaz.",
                "XML-fában az attribútumok `@` előtagot viselnek szabályos XPath-jelöléssel, és **a címkék közötti üres karakterek nem lesznek csomóponttá** — ez formázás, nem tartalom.",
                "A YAML-fa **többdokumentumos fájlokat** olvas (`---`): minden dokumentum saját gyökér. Az egy sorban írt gyűjtemények (`ports: [80, 443]`) egyetlen levél maradnak — már mindent lát, a kinyitás egy kattintásba kerülne. A **tabulátoros behúzást** a pontos sorral jelenti: ez olyan YAML-hiba, amit a szem nem lát.",
                "A PowerPoint-vázlat a **nyitott szövegből** épül, nem a lemezen lévő fájlból: ha épp Code-ban szerkesztette a vázlatot, a fának az új változatot kell leírnia, és a csomópontjainak abba kell ugraniuk. Az előadói jegyzetek egy csomópontba csukódnak, hogy egy sokat mondó dia ne látsszon sokat tartalmazónak.",
                "**A lapot kitöltő diagram ugyanezt a szabályt követi**: kattintson egy csomópontra, és a Code-ban van, a kurzorral annak deklarációján. Az egymás melletti `Mermaid Studio` panelen a lap nem zárul be — a szerkesztő épp ott van, és elég a kurzort mozdítani.",
                "A diagramok **ott is nyílnak, ahol áll**: a kurzor sorának megfelelő elem abban a pillanatban kiemelődik, ahogy a lap megjelenik, így nem kell keresgélnie.",
            ]),
            .heading("A szűrőmező: tízezer csomópontos fában a keresés maga a munka"),
            .paragraph("""
                A csomópontszám alatt szűrőmező ül. Gépeljen bele, és a fa csak az illeszkedő \
                csomópontokat tartja meg — **a gyökértől hozzájuk vezető úttal együtt**, mert amikor egy \
                `name` kulcs tíz különböző helyen szerepel, a valódi kérdés az, hogy »melyik«, és erre \
                csak az azt tartalmazó ág válaszol. A többit kinyitja Ön helyett: minden szintet \
                végigkattintatni annyi volna, mint kézzel újraszűretni.
                """),
            .bullets([
                "**Címkékre és értékekre is** szűr: a `Huế` keresése ugyanolyan gyakori, mint a `province` kulcsé.",
                "**Az ékezet nélküli gépelés is illeszkedik ékezetes szövegre** — a `da nang` megtalálja a `Đà Nẵng`-ot. Ugyanaz az összehasonlítás, mint a CSV-táblázat szűrőjében és a függvénylistában, hogy egy alkalmazásban ne kelljen három keresési szabályt fejben tartani.",
                "Ha nincs találat, a fejléc **»Nincs eredmény«**-t ír, ahelyett hogy üres fát bámulva azon tűnődne, elromlott-e a fájl.",
                "Fájlváltás vagy a View-ba való visszatérés **törli a szűrőt**: egy fa, amely már csonkán nyílik, és semmi nem magyarázza, miért, a legzavaróbb állapot.",
            ]),
            .heading("Az egész fa működik billentyűzetről"),
            .paragraph("""
                A View-ba lépés a fára viszi a fókuszt; nem kell előbb rákattintani. A fel és le a \
                csomópontok között mozog, a bal és jobb csuk és nyit, két billentyű pedig lezárja a \
                nézést — **különböző** dolgokat téve:
                """),
            .bullets([
                "**Enter** — a kijelölt csomóponthoz: vissza a Code-ba, a kurzorral annak bájttartományán belül. Pontosan olyan, mint rákattintani.",
                "**Tab** — váltás a fa és a szűrőmező között.",
                "**⌘C** — a kijelölt csomópont **útvonalát** másolja, nem a fa mögötti szöveget. A JSON és a YAML JSONPath-t ad (`$.customer['name']`), amely közvetlenül beilleszthető a termék saját JSONPath-mezőjébe vagy a `yq`-ba; az XML XPath-t (`/order/item[2]/@code`) indexekkel, ha két címke nevet oszt; a PowerPoint-vázlat a sor szövegét másolja, mert a vázlathoz nincs kitalálható útvonalnyelv.",
                "**Esc** — a visszaút: vissza a Code-ba, a kurzorral **pontosan ott, ahol volt**. Fát nézett, nem utazott sehová.",
            ]),
            .heading("És a másik irány: a fa ott nyílik, ahol a kurzor áll"),
            .paragraph("""
                Egy tízezer soros fájl közepéből a View-ba lépve a fa **nem** a tetején nyílik: kinyitja \
                az utat addig a csomópontig, amely a kurzor helyének felel meg, és kijelöli. Ez az \
                ugrás-a-forrásba másik fele — enélkül a View és a Code egy dokumentum két nézete volna, \
                de csak **egy** irányban.
                """),
            .bullets([
                "Ha kell, **két szintnél mélyebbre** nyit: a kétszintes szabály arra válaszol, »hogy néz ki ez a fájl«, míg itt más a kérdés — »hol vagyok ebben a fában«.",
                "Egy **kulcson** álló kurzor (`\"address\":`) azt a bejegyzést jelöli ki, noha a csomópont bájttartománya csak az értéket fedi. A csomópont előtti szöveg ahhoz a csomóponthoz tartozik.",
                "Egy **blokk elején** álló kurzor — egy YAML-blokk kulcsa, egy diacím, egy XML-címke neve — azt a blokkot jelöli ki, ahelyett hogy az első gyerekéhez merülne.",
                "A View-ba lépés **nem mozdítja a kurzort**. Hagyja el a View-t, és pontosan ott van, ahol volt; a View nézési mód, nem pozíciót változtató parancs.",
            ]),
            .heading("Egyetlen típusnak sem hiányzik többé a View"),
            .paragraph("""
                **Minden fájltípus, amelynél van értelme View-módnak, most megjelenít egyet.** A hiányzó \
                típusok listája kiürült és megszűnt.

                A forráskódnak és az egyszerű szövegnek továbbra sincs View-ja — ez normális, nem hiány, \
                így sosem szerepeltek azon a listán.

                Ha új fájltípus érkezik, amelynek a View-ja még nem készült el, a váltóparancs ezt \
                megmondja és megnevezi, mi hiányzik, ahelyett hogy üres keretet nyitna — az üres keret \
                üres ígéret, míg a névvel adott elutasítás információ.
                """),
            .heading("A hat régebbi parancs továbbra is megvan"),
            .paragraph("""
                `Táblázat-/szövegnézet`, `Markdown-előnézet`, `Bináris nézet`, `Jelentés-előnézet`, \
                `Mermaid-diagram előnézete`, `Naplómód` — mind pontosan ott maradnak, ahol voltak. A \
                `⌥⌘V` **közös bejárat**, nem helyettesítés.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnami

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnami",
        summary: "Régi karakterkódolások, Unicode-normalizálás, ékezetfüggetlen keresés és beviteli módok.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnami karakterkódolások",
        summary: "Olvasson és írjon TCVN3, VISCII, VNI-Windows és 33 további kódolást, automatikus felismeréssel.",
        keywords: ["kódolás", "tcvn3", "abc", "viscii", "vni", "mojibake"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Megnyitott egy régi vietnami fájlt, és `Tr¦êng §¹i häc` jött a `Trường Đại học` helyett? \
                A fájl nem sérült — Unicode előtti kódolással mentették.
                """),
            .steps([
                "Kattintson a kódolásra az **állapotsoron** (vagy `Formátum ▸ Kódolás…`).",
                "Válassza a helyeset — régi vietnami fájloknál általában `TCVN3 (ABC)`, `VNI-Windows` vagy `VISCII`.",
                "A szöveg azonnal helyreáll; nem kell újranyitni a fájlt.",
                "Hogy így maradjon: `Mentés másként…` `UTF-8` kódolással.",
            ]),
            .heading("A három régi vietnami kódolás"),
            .table(
                headers: ["Kódolás", "Általában itt fordul elő"],
                rows: [
                    ["TCVN3 (ABC)", "Hivatali iratokban és régebbi Word-dokumentumokban északon"],
                    ["VNI-Windows", "Kiadóknál, újságoknál és nyomdákban — délen gyakori"],
                    ["VISCII", "Korai e-mailben és a Useneten"],
                ]
            ),
            .paragraph("""
                A GEditor **felismeri a kódolást** megnyitáskor. Ha rosszul tippel, egy kattintás \
                javítja, és a tartalom újra dekódolódik, nem betűnként foltozódik.
                """),
            .warning("""
                Régi kódolásba írva elvesznek azok a karakterek, amelyek abban nincsenek. A GEditor \
                **megszámolja és előre megmondja** — például *»12 karakter nincs a TCVN3-ban«* — \
                ahelyett hogy csendben kérdőjelekké tenné őket.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Sorvégek",
        summary: "LF, CRLF, CR — az egész fájlra átalakítva egy kattintással.",
        keywords: ["eol", "crlf", "lf", "sorvég", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Stílus", "Használja", "Bájtok"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac 2001 előtt", "`\\r`"],
                ]
            ),
            .paragraph("""
                Az aktuális stílus az állapotsoron látszik; kattintson rá a módosításhoz. A két stílust \
                **keverő** fájlt is ott jelenti — kapcsolja be a `Láthatatlanok megjelenítése ▸ \
                Sorvégek` beállítást, hogy pontosan lássa, hol.
                """),
            .note("Az **új** fájlok sorvégstílusa a `Beállítások…` alatt állítható."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode-normalizálás",
        summary: "Miért nem talál néha semmit az «ế» keresése, és hogyan javítható az egész fájl.",
        keywords: ["unicode", "nfc", "nfd", "összetett", "felbontott", "normalizálás"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                Unicode-ban az `ế` **kétféleképpen** írható: egyetlen előre összetett kódponttal (NFC), \
                vagy `e`-ként plusz két külön jellel (NFD). A képernyőn egyformán néznek ki; a gép \
                számára különböző karakterláncok.
                """),
            .paragraph("""
                A következmény: az `ế` keresése egy NFD-fájlban **semmit** nem talál, és a felhasználó \
                arra jut, hogy az adat nincs ott.
                """),
            .steps([
                "`Formátum ▸ Unicode normalizálása…`",
                "Válassza az **NFC**-t (előre összetett) — azt az alakot, amelyet szinte minden más használ.",
                "Alkalmazza. Ez egyetlen visszavonási lépés.",
            ]),
            .note("""
                A macOS-ről érkező fájlok gyakran NFD-k, mert az Apple fájlrendszere így tárolja a \
                fájlneveket. Ez messze a leggyakoribb oka annak, hogy a Finderből kimásolt adat nem \
                található meg újra.
                """),
            .paragraph("""
                A `Beállítások…` alatt van egy **normalizálás NFC-re mentéskor** kapcsoló. Alapból ki \
                van kapcsolva, mert megváltoztatja a fájl bájtjait.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Az ékezet nélküli gépelés is megtalálja az ékezetes szöveget",
        summary: "Minden kereső- és szűrőmező ékezetek nélkül hasonlít össze.",
        keywords: ["ékezetek", "keresés", "szűrő", "ékezet nélküli"],
        blocks: [
            .paragraph("""
                Írja be, hogy `hue`, és megtalálja a `Huế`-t. Írja be, hogy `da nang`, és megtalálja a \
                `Đà Nẵng`-ot. A szabály érvényes a CSV-táblázat szűrőjére, a függvénykeresésre, a \
                súgókeresésre és a többi szűrőmezőre.
                """),
            .note("""
                A `Đ`-t külön kezeljük, mert Unicode-ban **önálló betű**, nem jelet viselő `D` — a \
                szokásos ékezeteltávolítás nem nyúl hozzá.
                """),
            .paragraph("""
                A CSV-szűrő `=` előtagot is elfogad a pontos összehasonlításhoz. Az `=` alak **szintén \
                ékezetfüggetlen**, mert egy ékezetet megkülönböztető szűrő azt hiteti el a \
                felhasználóval, hogy az adat hiányzik.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnami beviteli módok",
        summary: "Az EVKey, az OpenKey, a Unikey és a macOS saját beviteli forrása mind közvetlenül a dokumentumba ír.",
        keywords: ["ime", "evkey", "unikey", "openkey", "telex", "vni", "beviteli mód"],
        blocks: [
            .paragraph("""
                Nincs mit beállítani. A Telex és a VNI is működik, **több kurzoron** át is — gépeljen \
                egyszer, és minden kurzor a helyesen ékezett betűt kapja.
                """),
            .paragraph("""
                A keresőmezők, szűrőmezők és minden párbeszédablak ugyanúgy fogadja a beviteli módot, \
                mint a szerkesztő.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Nyelvek és formátumok

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Nyelvek és formátumok",
        summary: "Húsz beépített nyelv, saját nyelvek, és eszközök JSON-hoz · XML-hez · YAML-hoz · naplókhoz.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Húsz beépített nyelv",
        summary: "Színezés valódi szintaxisfából, minden nyelv saját megjegyzésjelével.",
        keywords: ["szintaxis", "kiemelés", "nyelv", "tree-sitter", "nyelvtan"],
        blocks: [
            .paragraph("""
                A nyelvet a **fájlkiterjesztésből** ismeri fel (plusz néhány különleges név, mint a \
                `Makefile`, `Dockerfile`, `Gemfile`). Kézzel az állapotsoron változtathatja meg.
                """),
            .table(
                headers: ["Nyelv", "Kiterjesztések", "Sor- · blokkmegjegyzés"],
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
                Az utolsó oszlop az, amit a `⌘/` használ. A sormegjegyzés nélküli nyelvek (JSON, CSS, \
                XML) helyette a blokkalakot kapják.
                """),
            .heading("Mi jár a szintaxisfával"),
            .bullets([
                "Az oldalsáv **függvénylistája** a valódi szerkezetet követi, nem behúzásból tippel.",
                "**Összecsukás** szerkezet szerint.",
                "**Zárójelpárosítás**, amely átugorja a karakterláncokon és megjegyzéseken belüli zárójeleket.",
                "**Automatikus behúzás**, amely `{` után, illetve Pythonban és YAML-ban `:` után ad hozzá egy szintet.",
            ]),
            .note("""
                Három nehéz nyelvtan (C++, C#, Ruby) **lustán betöltött** könyvtárban él — csak akkor \
                töltődnek be, ha olyan nyelvű fájlt nyit meg. Így marad az indítási idő fél másodperc \
                alatt.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Saját nyelvek",
        summary: "Színezze a saját formátumát egyetlen JSON-fájllal — nyelvtant nem kell írni.",
        keywords: ["udl", "saját nyelv", "egyedi napló"],
        blocks: [
            .paragraph("""
                Egy cég belső naplóformátuma, egy magánhasználatú konfigurációs nyelv, egy kis DSL — \
                egyiküknek sincs tree-sitter nyelvtana, és megírni fordítót és némi elemzéselméletet \
                igényel.
                """),
            .paragraph("""
                Helyette a GEditor elfogad egy JSON-ban megadott, **táblavezérelt lexert**. Tegye a \
                fájlt a GEditor konfigurációs könyvtárán belüli `grammars/` mappába, és indítsa újra.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — egy teljes nyelv",
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
            .heading("Minden kulcs"),
            .table(
                headers: ["Kulcs", "Típus", "Jelentés"],
                rows: [
                    ["`name`", "karakterlánc", "Az állapotsoron megjelenő név"],
                    ["`extensions`", "karakterlánctömb", "Fájlkiterjesztések, **pont nélkül**"],
                    ["`caseSensitive`", "logikai", "Megkülönböztetik-e a kulcsszavak a kis-/nagybetűt"],
                    ["`lineComment`", "karakterlánc", "Sor végéig tartó megjegyzés jele; hagyja el, ha nincs"],
                    ["`blockComment`", "2 karakterlánc tömbje", "`[nyitó, záró]`"],
                    ["`stringDelimiters`", "karakterlánctömb", "Minden elem **egy** karakter, amely nyit/zár egy karakterláncot"],
                    ["`escapeCharacter`", "karakterlánc", "Escape-karakter a karakterláncokban; üres, ha a nyelvnek nincs"],
                    ["`keywordGroups`", "objektum", "Csoportnév → kulcsszólista; három csoport három színt kap"],
                ]
            ),
            .paragraph("""
                A három csoportnév, amely saját színt kap: `keyword`, `type` és `constant`.
                """),
            .warning("""
                Ez a lexer **nem érti a beágyazást**. A szerkezeti összecsukás, a függvénylista és az \
                okos zárójelpárosítás a húsz beépített nyelv kiváltsága marad. Ez tudatos csere: \
                cserébe egy nyelvet tíz perc alatt ad meg, nem egy nap alatt.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON-eszközök",
        summary: "Újraformázás, tömörítés, kulcsok rendezése és ellenőrzés JSON Schema szerint.",
        keywords: ["json", "formázás", "tömörítés", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Parancs", "Mit csinál"],
                rows: [
                    ["Újraformázás", "Tördel és behúz az olvashatóságért"],
                    ["Tömörítés", "Eltávolít minden felesleges üres karaktert"],
                    ["Kulcsok rendezése", "Minden objektum kulcsait ábécébe rendezi — hogy két JSON-fájl **összevethető** legyen"],
                    ["Ellenőrzés JSON Schema szerint…", "Sémafájl alapján ellenőrzi a dokumentumot, minden problémát a sorával felsorolva"],
                ]
            ),
            .paragraph("""
                Az alkalmazott szabályok **szigorú RFC 8259**: nincs záró vessző, nincs megjegyzés, \
                nincs `NaN`. A szintaktikai hiba a pontos sorra és oszlopra mutat.
                """),
            .note("""
                A **JSONL**-fájlokat (soronként egy objektum) is felismeri, és saját eszközkészletük \
                van a tudáscsomag fejezetében.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath-lekérdezések",
        summary: "Húzza ki pontosan azt a részt, amire szüksége van, egy nagy JSON-fájlból.",
        keywords: ["jsonpath", "json-lekérdezés", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Írjon be egy kifejezést; az eredmények listaként jelennek meg, amelybe beleugorhat."),
            .table(
                headers: ["Írja", "Jelentés"],
                rows: [
                    ["`$`", "A dokumentum gyökere"],
                    ["`$.name`", "A `name` kulcs a gyökérben"],
                    ["`$.orders[0]`", "Egy tömb első eleme"],
                    ["`$.orders[*].total`", "**Minden** elem `total` kulcsa"],
                    ["`$..province`", "A `province` kulcs **bármely mélységben**"],
                    ["`$.orders[1:3]`", "Szelet: az 1. és 2. elem"],
                ]
            ),
            .code(language: "text", caption: "Minden rendelés tartománykódja, bármilyen mélyen is van",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML-eszközök",
        summary: "Újraformázás, tömörítés, szintaxis-ellenőrzés és ellenőrzés DTD vagy XSD szerint.",
        keywords: ["xml", "xsd", "dtd", "schema", "ellenőrzés", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Parancs", "Mit csinál"],
                rows: [
                    ["Újraformázás", "Címkemélység szerint húz be"],
                    ["Tömörítés", "Eltávolítja a címkék közti üres karaktereket"],
                    ["Szintaxis ellenőrzése", "Hiányzó zárócímkék, hibás beágyazás, érvénytelen karakterek"],
                    ["Ellenőrzés DTD/XSD szerint…", "Séma alapján ellenőriz, minden problémát a sorával jelentve"],
                    ["XPath kiértékelése…", "Lefuttat egy XPath-kifejezést; az eredmények új lapon nyílnak"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Írjon be egy kifejezést, és az eredmények **szöveges lapként** nyílnak, soronként egy \
                csomóponttal. Például: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Az eredmények NEM ugranak a forrásfájlban lévő pozícióra.** A rendszer \
                XPath-kiértékelője saját fát épít, és nem tartja meg az egyes csomópontok bájteltolását, \
                így ami visszajön, az TARTALOM, nem koordináta. A pontos hely eléréséhez használja a \
                `⌘F`-et a most talált karakterláncra.
                """),
            .paragraph("""
                `.xml` és `.html` fájlokban a nyitócímkét lezáró `>` beírására **megjelenik a \
                zárócímke**, a kurzorral a kettő között. Az önzáró címkék (`<br/>`), a deklarációk \
                (`<?xml …?>`) és a megjegyzések nem — nincs mit lezárniuk.
                """),
            .warning("""
                Az XML újraformázása **megváltoztatja a címkék közti üres karaktereket**. Olyan \
                dokumentumokban, ahol ezek jelentéssel bírnak — mondjuk XHTML-ben, ahol szöveg van a \
                címkékben —, ez megváltoztatja a megjelenítést. Ez egyetlen visszavonási lépés, így a \
                `⌘Z` visszafordítja.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML-ellenőrzés",
        summary: "Fogja el a két leggyakoribb YAML-hibát: ismétlődő kulcsok és tabulátoros behúzás.",
        keywords: ["yaml", "yml", "lint", "ismétlődő kulcs", "behúzás"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Ismétlődő kulcsok** egy leképezésben — a legtöbb YAML-olvasó az **utolsót** veszi, és csendben eldobja a korábbiakat, így egy konfigurációs fájl egészen másként viselkedhet, mint várná.",
                "**Tabulátoros behúzás** — a YAML tiltja a tabulátort a behúzásban, és a könyvtárak erről szóló hibaüzenetei rendszerint érthetetlenek.",
            ]),
            .note("Kapcsolja be a `Láthatatlanok megjelenítése ▸ Tabulátorok` beállítást, hogy azonnal lássa, melyik üres karakter tabulátor."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Naplófájlok",
        summary: "Hét súlyossági szint, szűrés szint szerint, és hogyan olvassunk nagyon nagy naplót.",
        keywords: ["napló", "hiba", "figyelmeztetés", "szűrő", "szint"],
        blocks: [
            .paragraph("""
                Kapcsolja be a `Nézet ▸ Naplómód (színezés szint szerint)` beállítást. A GEditor **minden \
                sor elejéről** olvassa a súlyosságot — az időbélyeg és a folyamatnév után.
                """),
            .table(
                headers: ["Szint", "Szín"],
                rows: [
                    ["CRITICAL · ERROR", "Piros"],
                    ["WARNING", "Borostyánsárga"],
                    ["NOTICE", "Kiemelőszín"],
                    ["INFO", "Közönséges szöveg"],
                    ["DEBUG · TRACE", "Halványítva"],
                ]
            ),
            .paragraph("""
                A `Napló szűrése szint szerint…` teljesen elrejti az alacsonyabb szinteket. Azokat a \
                sorokat, amelyek szintjét **nem ismeri fel** — például egy veremkiírás folytatását — \
                békén hagyja, ahelyett hogy az előző sor szintjét adná nekik.
                """),
            .heading("Nagy napló olvasása lépésről lépésre"),
            .steps([
                "Nyissa meg a fájlt — gigabájtos léptékben is szinte azonnal nyílik.",
                "`Nézet ▸ Naplómód`, hogy lássa a piros foltokat.",
                "`⌥⌘M` a dokumentumtérképhez: a piros egy szakaszon csoportosul, vagy szét van szórva a fájlban?",
                "`⌘F` a hibakódra, `⌘M` minden illeszkedő sor megjelölésére.",
                "`Keresés ▸ Megjelölt sorok másolása`, hogy új lapra húzza őket.",
                "Még fut? `Fájl ▸ Fájl követése (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
