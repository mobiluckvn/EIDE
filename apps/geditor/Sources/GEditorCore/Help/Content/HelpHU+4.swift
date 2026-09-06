import Foundation

/// Magyar súgótartalom — 4. rész: táblázatos adatok, adattisztítás és adatbányászat.
extension HelpHU {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Táblázatos adatok",
        summary: "Nézze a CSV-t táblázatként, szűrjön, rendezzen, ellenőrizze a szerkezetet, kérdezze SQL-lel, alakítsa át.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "CSV megtekintése táblázatként",
        summary: "Egymillió sor is simán gördül, a fejlécek maradnak, a forrásszöveghez nem nyúlunk.",
        keywords: ["csv", "táblázat", "rács", "tsv", "excel", "oszlopok"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Váltás táblázat és szöveg között")]),
            .paragraph("""
                A táblázat **virtualizált**: csak a látható sorok épülnek fel, így egy egymillió soros \
                fájl úgy gördül, mint egy százsoros.
                """),
            .bullets([
                "**A fejlécsor a helyén marad** görgetés közben — a 40 000. sornál is tudja, mi a kilencedik oszlop.",
                "Szerkesszen egy cellát a táblázatban; a változás egyenesen a forrásszövegbe megy.",
                "A táblázat és a szöveg **egy fájl két nézete**, nem két másolat.",
                "**A ⌘C a kijelölt sort másolja**, a cellákat TAB-bal elválasztva — illessze be egyenesen Excelbe vagy Numbersbe, és minden cella a helyére kerül. A TAB-ot vagy sorvéget tartalmazó cellák idézőjelbe kerülnek, hogy a célhely ne vágja ketté őket.",
            ]),
            .note("""
                Az elválasztót megnyitáskor ismeri fel (vessző, pontosvessző, TAB, függőleges vonal). Ha \
                a tipp rossz, a `CSV ▸ Elválasztó módosítása…` paranccsal változtathat rajta.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Több munkalapos táblázatok",
        summary: "Nyissa meg egy .xlsx bármely munkalapját, és a ⌘S abba a lapba ír vissza, amelyet néz.",
        keywords: ["excel", "xlsx", "munkalap", "munkafüzet", "több lap"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Nyisson meg egy `.xlsx`-et, és a GEditor az **első munkalapot** mutatja CSV-rácsként. A \
                `CSV ▸ Munkalap választása…` felsorolja a fájl minden lapját, és a kiválasztottat \
                ugyanabban a lapban nyitja meg.
                """),
            .heading("Visszaírás a HELYES munkalapba"),
            .paragraph("""
                A `⌘S` a módosításait **abba a munkalapba** írja, amelyet néz, nem az elsőbe. A többi \
                laphoz egyetlen bájt erejéig sem nyúl.
                """),
            .note("""
                A munkalapot **név szerint** jegyzi meg, nem pozíció szerint. Így a lapok Excelben \
                történő átrendezése két munkamenet között nem tereli félre az írást.
                """),
            .warning("""
                Ha a nyitott lapot azóta **átnevezték vagy törölték** Excelben, hogy megnyitotta, a `⌘S` \
                **megtagadja az írást**, és megmondja. Az első lapra visszaesni annyit jelentene, hogy \
                egyik lap tartalmát ráöntjük a másikra — a fájl mentődne, újranyílna, csak épp rossz \
                helyen tartaná az adatot.
                """),
            .heading("Munkalapváltás mentetlen módosításokkal"),
            .paragraph("""
                A munkalapváltás lecseréli a lap teljes tartalmát, így ha bármi mentetlen, a GEditor \
                **előbb megkérdezi**. A `⌘Z` nem hozza vissza, mert az egész dokumentum cserélődött.
                """),
            .heading("Mibe kerül az Excelt rácsra egyszerűsíteni"),
            .paragraph("""
                Az **értékek** maradnak — a képletek eredményei is, pontosan azok a számok, amelyeket az \
                Excel mutat. Ami nem: betűtípusok, színek, egyesített cellák, beágyazott diagramok és \
                maguk a képletek.
                """),
            .paragraph("""
                Cserébe az a munkalap megkapja a termék teljes többi részét: szűrés, rendezés, \
                SQL-lekérdezések, tisztítópad, minőségpontozás, bányászat, diagramok.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Szűrés és rendezés a táblázatban",
        summary: "Oszloponként egy szűrőmező, amely érti a számösszehasonlítást és az ékezet nélküli gépelést.",
        keywords: ["szűrő", "rendezés", "oszlop", "keresés a táblázatban"],
        blocks: [
            .paragraph("Kattintson egy oszlopfejlécre a rendezéshez. Az alatta lévő szűrőmező elfogadja:"),
            .table(
                headers: ["Írja a szűrőbe", "Jelentés"],
                rows: [
                    ["`hue`", "Tartalmazza: `hue`, **ékezetfüggetlenül** — megtalálja a `Huế`-t is"],
                    ["`=Huế`", "Pontosan `Huế` (továbbra is ékezetfüggetlenül)"],
                    ["`>100`", "Nagyobb, mint 100"],
                    ["`>=100`", "100 vagy több"],
                    ["`<0`", "Kisebb, mint 0"],
                    ["`100..200`", "100 és 200 között"],
                    ["üres", "Nincs szűrő ezen az oszlopon"],
                ]
            ),
            .paragraph("""
                Több oszlop szűrése **és** kapcsolat: egy sornak mindet teljesítenie kell. A \
                számösszehasonlítás átugorja a nem numerikus cellákat, ahelyett hogy nullának venné őket.
                """),
            .note("""
                A szűrés **nézési mód**, nem törlés. Törölje a szűrőt, és minden sor visszatér.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "A táblaszerkezet ellenőrzése",
        summary: "Keressen rossz oszlopszámú sorokat és rossz típusú cellákat — ezt csinálja először.",
        keywords: ["ellenőrzés", "oszlopszám", "rossz típus", "sérült adat"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Ezt futtassa **minden más előtt** egy fájlon, amit valaki küldött. Két kérdésre válaszol:
                """),
            .bullets([
                "**Mely soroknak rossz az oszlopszáma?** Rendszerint egy vesszőt tartalmazó, idézőjel nélküli cella — és ez minden utána következő sort elcsúsztat.",
                "**Mely cellák típusa tér el az oszlop többi részétől?** Például egy `n/a` a számok oszlopában.",
            ]),
            .paragraph("Az eredmények listaként jelennek meg; kattintson egyre, hogy arra a sorra ugorjon."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Oszlopok törlése",
        summary: "Távolítson el egy vagy több oszlopot teljesen a fájlból.",
        keywords: ["oszlop törlése", "oszlop eltávolítása"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Válassza ki a listából az eltávolítandó oszlopokat, és alkalmazza. Ez **egy** \
                visszavonási lépés, akárhány sora is van a fájlnak.
                """),
            .warning("""
                A szűréssel ellentétben ez **a valódi fájlt szerkeszti**. Ha csak elrejteni akar \
                oszlopokat, használjon SQL-lekérdezést, amely felsorolja a kívánt oszlopokat.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "CSV lekérdezése SQL-lel",
        summary: "A DuckDB teljes SQL-je, közvetlenül a nyitott fájlon futtatva — csak olvasásra.",
        keywords: ["sql", "lekérdezés", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                A nyitott tábla neve **`t`**. A motor a **DuckDB**, így a `JOIN`, `DISTINCT`, `HAVING`, \
                `IN`, `LIKE`, `BETWEEN`, az ablakfüggvények és az alkérdések mind működnek.
                """),
            .code(language: "sql", caption: "Bevétel tartományonként, a legnagyobbal kezdve",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Szűrés dátum és szöveges feltétel szerint",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Minden tartomány részesedése az egészből — ablakfüggvénnyel",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Összekapcsolás egy másik lemezen lévő fájllal",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Csak olvasható, és ez kemény garancia"),
            .bullets([
                "Az adatbázis **a memóriában** él; a forrásfájlt csak olvassuk.",
                "Pontosan **egy utasítás** fogadható el, és annak **`SELECT`-nek kell lennie**. Minden más — beleértve a `COPY … TO 'file'`-t is, amellyel a DuckDB simán tudna lemezre írni — blokkolódik, mielőtt bármilyen adathoz érne.",
            ]),
            .warning("""
                A DuckDB **fájlokat** olvas, nem memóriát. Ha a dokumentumban mentetlen módosítás van, a \
                GEditornak ideiglenes másolatot kell írnia a lekérdezés előtt. Nagyon nagy, mentetlen \
                fájlnál **megáll és megmondja**, ahelyett hogy egyetlen lekérdezésért csendben több száz \
                megabájtot írna lemezre.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Kimutatások és gyors diagramok",
        summary: "Készítsen kimutatást és diagramot közvetlenül egy lekérdezés eredményéből.",
        keywords: ["kimutatás", "diagram", "kereszttábla", "aggregálás"],
        blocks: [
            .paragraph("""
                Mindkettő az **eredménytáblából** nyílik: futtasson egy SQL-utasítást, majd használja a \
                panel Kimutatás vagy Diagram gombját.
                """),
            .heading("Kimutatás"),
            .paragraph("""
                Válassza ki a **sor**oszlopot, az **oszlop**oszlopot, az **érték**oszlopot és az \
                aggregálást (összeg, darab, átlag, minimum, maximum) — mint egy táblázatkezelő \
                kimutatásában.
                """),
            .heading("Diagramok"),
            .paragraph("""
                Oszlop, vonal, torta, pont. Vietnami vagy európai módon formázott számokkal, és a \
                diagram PNG-ként vagy SVG-ként exportálható máshová beillesztéshez.
                """),
            .note("""
                Olyan diagram kell, amely minden építéskor **az adatokkal együtt újraszámolódik**? Az a \
                `chart` blokk egy `.greport.md` jelentésben.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Tábla átalakítása másik formátumba",
        summary: "TSV, JSON, XML, Markdown-táblák, SQL INSERT utasítások — előnézettel.",
        keywords: ["átalakítás", "exportálás", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Formátum", "Mire jó"],
                rows: [
                    ["TSV", "Táblázatkezelőbe illesztéshez a cellákban lévő vesszők miatti aggodalom nélkül"],
                    ["JSON", "API, szkript vagy másik eszköz etetéséhez"],
                    ["XML", "Régi rendszerekhez, amelyek XML-t követelnek"],
                    ["Markdown-tábla", "Dokumentációba, README-be, jegybe illesztéshez"],
                    ["SQL INSERT utasítások", "Adatbázisba töltéshez"],
                ]
            ),
            .paragraph("""
                A párbeszédablak **megmutatja az első öt sort**, mielőtt létrehozná az új lapot — öt sor \
                elég a táblanév, az idézőjelezés és annak megerősítéséhez, mely oszlopokból lettek \
                számok.
                """),
            .note("""
                Az előnézet **ugyanazt a függvényt** hívja, amely a valódi kimenetet állítja elő, öt \
                sorra korlátozva. Nem szimuláció, amely eltérhetne a végeredménytől.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Elválasztó módosítása",
        summary: "Alakítson át egy fájlt vessző, pontosvessző, TAB és függőleges vonal között.",
        keywords: ["elválasztó", "vessző", "pontosvessző", "tab", "európai csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                A vietnami vagy európai Excelből exportált fájlok rendszerint **pontosvesszőt** \
                használnak, mert ott a vessző a tizedesjel.
                """),
            .warning("""
                Az elválasztó módosítása **újraírja az egész fájlt**. Az új elválasztót tartalmazó cellák \
                idézőjelbe kerülnek — különben eltörne a tábla szerkezete.
                """),
            .note("""
                **Ha a felismerés volt rossz, nem ez a parancs kell.** Itt két különböző munkáról van \
                szó, pontosan mint a kódolások »újraértelmez« / »átalakít« párjánál:

                • *A fájl valóban pontosvesszős, és mi vesszőt tippeltünk* — kattintson a `CSV · …` \
                mezőre az **állapotsoron**, és válassza a helyeset. A fájlból egy bájt sem változik; csak \
                az, ahogy olvassuk.

                • *A fájl valóban vesszős, és Ön pontosvesszőt akar* — használja az ezen az oldalon lévő \
                parancsot. Az újraírja a fájlt.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Adattisztítás

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Adattisztítás — a teljes folyamat",
        summary: "Egy nyers, kapott fájltól használható tábláig, és egy szabvány, amit havonta újra lehet futtatni.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "A tisztítási folyamat végponttól végpontig",
        summary: "Hat lépés ismeretlen fájltól megbízható tábláig, és egy szabvány a jövő hónapra.",
        keywords: ["tisztítás", "folyamat", "normalizálás", "rendezett adat"],
        blocks: [
            .paragraph("""
                Az adattisztítás **ritkán egyszeri**. Az emberek minden hónapban ugyanazt a jelentéssablont \
                kapják, és minden hónapban ugyanazokat az oszlopokat kell ugyanúgy normalizálni. Ez a \
                folyamat épp erre készült: egyszer kézzel megcsinálja, aztán egyetlen paranccsal újra \
                lefuttatja.
                """),
            .heading("Hat lépés"),
            .steps([
                "**Előbb nézze meg a szerkezetet.** `CSV ▸ Adatok ellenőrzése` — mely soroknak rossz az oszlopszáma, mely cellák típusa rossz. Ez jön először, mert egyetlen elcsúszott sor minden későbbi statisztikát értelmetlenné tesz.",
                "**Olvassa el az adatprofilt.** Oszloponként: hány üres cella, hány különböző érték, milyen típus, hol vannak a kiugrók. Itt érti meg a fájlt, mielőtt bármit módosítana.",
                "**Nyissa meg a tisztítópadot** (`⇧⌘L`). Felismeri a kevert dátumformátumokat, az európaiakkal kevert vietnami számokat, az elkószált szóközöket, a hiányzó értékeket. **Előnézet előtte→utána**, aztán alkalmazza.",
                "**Kezelje a homályos ismétlődéseket**, ha egy név- vagy címoszlopban kézzel írt változatok vannak. Itt Ön dönt; a gép csak javasol.",
                "**Mentse receptként.** Az imént végrehajtott lépéssor egy megnevezett JSON-fájlba íródik — az a fájl a tudása erről az adatról.",
                "**Írjon minőségi szabálykészletet** `.gquality.yaml` néven, és pontozzon. Innentől a jövő havi fájl végigmegy a recepten és pontozódik, és a **parancssori kapu** nem nulla kilépési kódot ad, ha megbukik.",
            ]),
            .heading("Miért ez a sorrend"),
            .bullets([
                "Szerkezet a profil **előtt**: egy elcsúszott táblán a statisztika másik oszlopról szól.",
                "Profil a tisztítás **előtt**: tudnia kell, hogy `2 % üres`, mielőtt eldönti, hogy tölt vagy dob.",
                "Homályos ismétlődések a normalizálás **után**: a `CÔNG TY  A` és a `Công ty A` csak akkor mutatkozik egynek, ha a szóközök és a kis-/nagybetűk rendeződtek.",
                "Recept a szabálykészlet **előtt**: a recept javít, a szabályok ítélnek — javítatlan táblát pontozni csak egy alacsony számot ad, amire már számított.",
            ]),
            .heading("Az első alkalom után minden hónap egyetlen parancs"),
            .code(language: "bash", caption: "Tisztítás és pontozás, kilépési kóddal a CI-hez",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                A **0** kilépési kód sikert, az **1** bukást, a **2** futásidejű hibát jelent. A \
                `--record-history` sort fűz az előzményfájlhoz, hogy a következő futás összevethesse az \
                elmozdulást.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Adatprofil",
        summary: "Oszloponként egy leírás: típus, üresek, különböző értékek, eloszlás.",
        keywords: ["profil", "oszlopstatisztika", "null", "különböző"],
        blocks: [
            .paragraph("""
                A profil **leír**; nem ítél. Azt mondja: *»ez az oszlop 2 %-ban üres«*; hogy a 2 % \
                elfogadható-e, az a minőségi szabálykészletre tartozik.
                """),
            .table(
                headers: ["Mérőszám", "Hogyan olvassa"],
                rows: [
                    ["Típus", "Magukból az adatokból következtetve, nem az oszlopnévből"],
                    ["Üres cellák", "A hiányzó értékek száma és aránya"],
                    ["Különböző értékek", "Az 1 állandó oszlopot jelent; a sorszámmal egyenlő kulcsoszlopot"],
                    ["Min · max · átlag", "Csak numerikus oszlopoknál"],
                    ["Leggyakoribb értékek", "Azonnal észreveszi a hibakódot vagy a túlhasznált alapértéket"],
                ]
            ),
            .warning("""
                A különböző értékek számlálásának küszöbe van. Fölötte a megjelenített szám **alsó \
                korlát**, és a profil **kimondja, hogy becslés**, ahelyett hogy pontos számokkal keverné.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Az adattisztító pad",
        summary: "Hét normalizálás, mindig előnézettel, mindig egy visszavonási lépés, sosem találgatva.",
        keywords: ["tisztítás", "normalizálás", "dátumok", "számok", "hiányzók pótlása"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "A tisztítópad megnyitása")]),
            .table(
                headers: ["Művelet", "Mit csinál"],
                rows: [
                    ["Dátumok normalizálása", "Az oszlop minden dátumalakját egyre hozza"],
                    ["Számok normalizálása", "Rendezi a tizedesjelet és az ezreselválasztót"],
                    ["Szóközök levágása", "Eltávolítja őket mindkét végről; opcionálisan a belső sorozatokat is összevonja"],
                    ["Kis-/nagybetű módosítása", "Egységesíti az oszlop betűalakját"],
                    ["Feltöltés rögzített értékkel", "A beírt értékkel pótolja az üres cellákat"],
                    ["Feltöltés a szomszédból", "A fenti vagy a lenti sor értékét veszi"],
                    ["Üres cellás sorok törlése", "Eldobja azokat a sorokat, amelyekből hiányzik adat"],
                ]
            ),
            .heading("Az egész pad három garanciája"),
            .bullets([
                "**Mindig előnézet.** Előtte→utána tábla, a változó cellák számával.",
                "**Egy visszavonási lépés** az egész menetre, akkor is, ha egymillió cellát érint.",
                "**Utána jelentés**: hány cella változott, és melyeket nem sikerült beolvasni.",
            ]),
            .heading("Az elv: soha ne találgass"),
            .paragraph("""
                Az a cella, amelyet nem lehet biztosan beolvasni, **megjelölve érintetlenül marad**. \
                Vegyük a `03/04/2026`-ot egy olyan oszlopban, amely mindkét szokást keveri — április 3. \
                vagy március 4.? A GEditor megkérdezi a nap/hónap sorrendet, ahelyett hogy Ön helyett \
                döntene.
                """),
            .warning("""
                Egy dátumoszlopot rosszul normalizálni az a fajta romlás, amely **szinte lehetetlen \
                észrevenni**: a számok továbbra is helyesnek látszanak, csak épp más dátumot jelentenek. \
                Ezért inkább megtagadja ez a pad, mint hogy következtessen.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Homályos ismétlődések",
        summary: "Találja meg ugyanannak a névnek a kézzel írt változatait — és sose egyesítse őket magától.",
        keywords: ["homályos", "ismétlődés", "egyesítés", "változatok", "elgépelés"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — háromféleképpen \
                leírva egy ügyfél. A szokásos ismétlődés-kiszűrés nem látja őket azonosnak.
                """),
            .steps([
                "Válassza ki a vizsgálandó oszlopot és egy hasonlósági küszöböt.",
                "A GEditor **fürtökbe** rendezi a közeli értékeket, és megmutatja az összehasonlítási alakot.",
                "**Minden fürtnél** Ön választja, melyik értéket tartsa meg — vagy átugorja a fürtöt.",
                "Alkalmazza. Egy visszavonási lépés.",
            ]),
            .warning("""
                Ez az eszköz **sosem egyesít magától**, és nincs »mindet egyesít« gomb. Két 92 %-ban \
                hasonló karakterlánc lehet elgépelés, vagy két valóban különböző, egy szóban eltérő cég — \
                ezt gép nem tudja eldönteni.
                """),
            .paragraph("""
                Két rekordot rosszul egyesíteni **csendes** adatvesztés: egyetlen cella sem ürül ki, \
                egyetlen sor sem pirosodik ki, két entitásból egyszerűen egy lesz, és senki nem veszi \
                észre, amíg a könyveket nem egyeztetik.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Tisztítási receptek",
        summary: "Rögzítse a lépéssort JSON-fájlként, és futtassa a jövő havi adaton.",
        keywords: ["recept", "ismétlés", "automatizálás", "havi", "köteg"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Tisztítás után mentse a lépéseket **receptként**. Ez ember által olvasható JSON-fájl, \
                amelyet az adat mellett tarthat, kollégának küldhet, és tárolóba tehet, hogy a \
                változások nyomon követhetők legyenek.
                """),
            .code(language: "json", caption: "sales-standard.json — rövidítve",
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
                Minden lépés **kikapcsolható** (`enabled`), így egy recept több, csaknem azonos \
                fájlfajtát is kiszolgálhat.
                """),
            .heading("Újrafuttatás"),
            .bullets([
                "Az alkalmazásban: `CSV ▸ Tisztítási recept futtatása…`",
                "Héjból, egész mappán: lásd a parancssori oldalt.",
            ]),
            .code(language: "bash", caption: "Próbafutás, mielőtt bármi íródna — egyetlen fájlhoz sem nyúl",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Alapból az eredmény új fájlba íródik az eredeti mellé (`sales-clean.csv`). Az eredeti \
                felülírását kifejezetten kérni kell a `--overwrite` kapcsolóval.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Adatminőség-pontozás",
        summary: "Hat dimenzió, egy 0–100 pontszám, és minden képlet kinyomtatva, hogy újraszámolhassa.",
        keywords: ["minőség", "pontszám", "dqr", "hat dimenzió"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Egy alapvető dologban tér el az adatprofiltól: a profil **leír**, a pontszám **az Ön \
                által deklarált szabvány szerint ítél**, egy `.gquality.yaml` fájlban.
                """),
            .table(
                headers: ["Dimenzió", "Mit mér"],
                rows: [
                    ["Teljesség", "A kitöltött cellák aránya a `not_null` szabályok szerint"],
                    ["Érvényesség", "Az átmenő formátum-, típus-, tartomány- és regex-szabályok aránya"],
                    ["Egyediség", "Az `uniqueness_key`-ben deklarált kulcs szerint"],
                    ["Következetesség", "Oszlopok közti és fájlok közti szabályok"],
                    ["Pontosság (becsült)", "Kiugró értékek az Ön által megjelölt numerikus oszlopokban"],
                    ["Frissesség", "Mennyire régi az adat a `freshness` küszöbhöz képest"],
                ]
            ),
            .heading("Három garancia a pontszámról"),
            .bullets([
                "**A képlet ki van nyomtatva az eredményben** — kézzel újraszámolhatja.",
                "**Determinisztikus**: ugyanaz az adat és ugyanazok a szabályok ugyanazt a pontszámot adják. Csak a *Frissesség* függ a pillanattól, így a `now` **paraméter**, és bekerül az eredménybe.",
                "**A nem pontozható dimenzió indoklással üresen marad**, sosem kap csendben 100-at.",
            ]),
            .warning("""
                Ez az utolsó garancia számít. Egy tábla, amelyben nincs deklarált `uniqueness_key`, és \
                mégis 100-at kap »egyediségre«, hazudó pontszám — és a hízelgő irányba hazudik, ami a \
                veszélyes.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "A `.gquality.yaml` szintaxisa",
        summary: "A szabályfájl minden kulcsa, egy teljes, működő szabálykészlettel.",
        keywords: ["gquality", "yaml", "szabályok", "szintaxis", "adatszabvány"],
        blocks: [
            .paragraph("""
                A fájl **az adat mellett** van, nem az alkalmazáson belül: egy adatszabványt át kell \
                tudni tekinteni, és épp ezt teszik az emberek a szabványokkal.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — teljes szabálykészlet",
                  source: """
                    schemaVersion: 1

                    # A hat dimenzió súlyai. A hiányzó dimenzió súlya 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # A kulcs, amely egyedivé tesz egy sort. Enélkül az "Egyediség"
                    # dimenzió NEM pontozható — és az összegzés meg is mondja.
                    uniqueness_key: [ma_don]

                    # A "Pontosság (becsült)" kiugró értékeihez vizsgált numerikus oszlopok.
                    accuracy_columns: [doanh_thu, so_luong]

                    # A "Frissesség" dimenzió.
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Figyelmeztessen, ha ez a futás az előzőhöz képest esik.
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
                        max_null_pct: 2          # 2 % üres megengedett
                      # Oszlopok közti szabály: nem kell `col`
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Fájlok közti szabály: az értéknek másik fájlban kell léteznie
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("A szabálytípusok"),
            .table(
                headers: ["Kulcs", "Jelentés", "Dimenzió"],
                rows: [
                    ["`not_null: true`", "A cellának kitöltöttnek kell lennie; a `max_null_pct` lazít rajta", "Teljesség"],
                    ["`unique: true`", "Nincs ismétlődő érték az oszlopban", "Egyediség"],
                    ["`dtype: int\\|float\\|date\\|text`", "Helyes típus", "Érvényesség"],
                    ["`range: { min:, max: }`", "Számtartományon belül", "Érvényesség"],
                    ["`length: { min:, max: }`", "Karakterlánc hossza", "Érvényesség"],
                    ["`regex: \"…\"`", "Illeszkedik reguláris kifejezésre", "Érvényesség"],
                    ["`in_set: [ … ]`", "Egy adott listából", "Érvényesség"],
                    ["`date_format: \"…\"`", "Helyes dátumalak", "Érvényesség"],
                    ["`compare: { a:, op:, b: }`", "Két oszlop összevetése; az `op` `<` `<=` `=` `>=` `>` `<>`", "Következetesség"],
                    ["`foreign_key: { file:, column: }`", "Az értéknek másik fájlban kell léteznie", "Következetesség"],
                    ["`severity: error\\|warn`", "A szabály súlyossága; alapból `error`", "—"],
                ]
            ),
            .warning("""
                Ha elgépel egy szabálykulcsot, a fájl **üzenettel elutasításra kerül**, ahelyett hogy azt \
                a szabályt csendben átugorná. A csendes átugrás azt jelenti, hogy azt hiszi, az adatot \
                olyan szabállyal ellenőrizték, amely sosem futott le.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Minőségi kapu a CI-ben",
        summary: "Állítsa meg a bukó adatot a futószalagon, kilépési kódokkal.",
        keywords: ["ci", "kapu", "fail-under", "kilépési kód", "automatizálás", "előzmény", "elmozdulás"],
        blocks: [
            .code(language: "bash", caption: "Pontozás kilépési kóddal",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Kapcsoló", "Jelentés"],
                rows: [
                    ["`--quality <fájl.yaml>`", "A szabálykészlet, amely szerint pontoz"],
                    ["`--fail-under <0…100>`", "Ez alatt a pontszám alatt BUKÁS"],
                    ["`--json <fájl\\|->`", "Gépi olvasható eredmény; a `-` a szabványos kimenetre ír"],
                    ["`--record-history`", "Sort fűz a `sales-standard.history.jsonl` fájlhoz"],
                    ["`--now <ÉÉÉÉ-HH-NN>`", "Rögzíti a *Frissesség* viszonyítási dátumát"],
                    ["`--recipe <fájl.json>`", "Tisztít **a memóriában** a pontozás előtt, fájl írása nélkül"],
                ]
            ),
            .table(
                headers: ["Kilépési kód", "Jelentés"],
                rows: [["`0`", "Sikeres"], ["`1`", "Bukás"], ["`2`", "Futásidejű hiba"]]
            ),
            .heading("Miért adjon a CI `--now`-t"),
            .paragraph("""
                Enélkül a *Frissesség* a futás pillanatához hasonlítja az adatot — így ugyanaz a fájl \
                napról napra pontot veszít, és egy reggel a futószalag pirosra vált anélkül, hogy bárki \
                bármit változtatott volna.
                """),
            .heading("Elmozdulás követése"),
            .paragraph("""
                A `--record-history` hatására minden futás sort fűz egy JSONL-előzményfájlhoz. Legközelebb \
                a `drift:` blokk küszöbei a legutóbbi futáshoz hasonlítanak, és figyelmeztetnek, ha az \
                esés túl nagy.
                """),
            .note("""
                Minden elmozdulási küszöb **alapból ki van kapcsolva**, kivéve a `warn_on_new_failure`-t. \
                Egy alapból bekapcsolt figyelmeztetés az alkalmazás által választott számmal mindenkinél \
                a második futáskor szólalna meg — és ami az első napon farkast kiált, azt a harmadikon \
                figyelmen kívül hagyják.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Adatbányászat

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Adatbányászat — a teljes folyamat",
        summary: "Rendellenességek, korreláció, klaszterezés, előrejelzések, asszociációs szabályok — és hogyan olvassuk őket.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "A bányászati folyamat végponttól végpontig",
        summary: "Hat eszköz, a használatuk sorrendje, és egy szabály: mérés nélkül nincs következtetés.",
        keywords: ["bányászat", "elemzés", "folyamat", "statisztika"],
        blocks: [
            .warning("""
                **Előbb tisztítson, aztán bányásszon.** Egy nem normalizált dátumoszlop hibás \
                előrejelzést ad; egy európai ezreselválasztókat keverő számoszlop kísértet-kiugrókat \
                termel. Az alábbi minden eszköz azt feltételezi, hogy a tábla tiszta.
                """),
            .heading("Milyen sorrendben haladjon"),
            .steps([
                "**Keressen rendellenességeket** — arra válaszol: *»furcsa-e valamelyik sor«*. A legolcsóbb, és gyakran azonnal hasznos.",
                "**Korrelációs mátrix** — arra válaszol: *»melyik oszlop mozog melyikkel«*. Ez irányítja az utána következőket.",
                "**Klaszterezés** — arra válaszol: *»hány természetes csoport van itt«*.",
                "**Előrejelzés** — csak időoszloppal és legalább **két teljes ciklussal**.",
                "**Asszociációs szabályok** — csak kosárformájú adatra: soronként egy tranzakció, vagy két oszlop tranzakcióazonosítóval és tétellel.",
                "**Csoportonkénti bányászat** — az első hármat **minden csoporton belül külön** futtatja újra. Ez a lépés gyakran megfordítja az összevont táblából levont következtetést.",
            ]),
            .heading("Három szabály az egész családra"),
            .bullets([
                "**Minden eredmény visel egy »Módszer« blokkot**: algoritmus, paraméterek, mag, képlet. Nem kapcsolható ki — egy háromszámos táblát, amely nem mondja meg, honnan jöttek, nem lehet döntésre használni.",
                "**Mérés nélkül nincs következtetés.** Túl kicsi minta, nulla szórás, szinguláris mátrix — a GEditor megtagadja és megmondja, miért, ahelyett hogy olyan számot adna, amely csak helyesnek látszik.",
                "**Determinisztikus eredmények.** Ugyanaz az adat ugyanazt az eredményt adja; ahol véletlen kell, a mag bekerül a kimenetbe.",
            ]),
            .heading("Az eredménytől vissza az adathoz"),
            .paragraph("""
                Minden panel **visszajelöl a forrásadatba**: kattintson egy kiugró sorra, egy \
                korrelációs cellára vagy egy asszociációs szabályra, és a vonatkozó sorok megjelölődnek \
                a táblázatban. Így jut el a *»valami furcsa«*-tól a *»pontosan ezekben a sorokban \
                furcsa«*-ig.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Kiugró sorok keresése",
        summary: "Négy mérőszám, három súlyossági szint, és magyarázat arra, miért furcsa egy sor.",
        keywords: ["kiugró", "rendellenesség", "z-érték", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Mérőszám", "Használja, ha"],
                rows: [
                    ["z-érték", "Az oszlop nagyjából normális eloszlású"],
                    ["IQR", "Az oszlop ferde, hosszú farokkal — a biztonságos alapértelmezés"],
                    ["MAD", "Az oszlopban már sok kiugró van, és robusztus mérőszám kell"],
                    ["Mahalanobis", "**Több oszlop egyszerre** — elfogja azokat a sorokat, amelyek kombinációban furcsák, egyetlen oszlopban sem"],
                ]
            ),
            .paragraph("""
                Az eredmények **három súlyossági szint** szerint színeződnek, nem egyetlen sík színnel — \
                különben egy enyhén szokatlan sor nem különböztethető meg egy vadul szokatlantól.
                """),
            .heading("A miért magyarázata"),
            .paragraph("""
                A többoszlopos mérőszámnál a GEditor lebontja az egyes oszlopok hozzájárulását, és olyan \
                mondatot ad, mint *«főként a bevétel (50 %) × mennyiség (50 %) kombináción keresztül \
                kiugró»*.
                """),
            .note("""
                Ez a százalék *a megmagyarázható részből* való, nem *a távolságból*. A Módszer blokk ezt \
                közvetlenül a tábla alatt kimondja.
                """),
            .warning("""
                Az az oszlop, amelynek IQR-je vagy MAD-je nulla, arra készteti a mérőszámot, hogy \
                **megtagadja a futást**, ahelyett hogy valami parányival osztana, és óriási pontszámot \
                adna. A többoszlopos esetben, ha a kovarianciamátrix szinguláris, **a GEditor megmondja, \
                melyik oszlopot dobja el**, ahelyett hogy pszeudoinverzzel »működésre bírná«.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Korrelációs mátrix",
        summary: "Pearson és Spearman minden párra, kattintásra pontdiagrammal.",
        keywords: ["korreláció", "pearson", "spearman", "hőtérkép", "pontdiagram"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Együttható", "Mit mér"],
                rows: [
                    ["Pearson", "**Lineáris** kapcsolat"],
                    ["Spearman", "**Bármely monoton** kapcsolat, a görbéket is beleértve — rangokon számolva"],
                ]
            ),
            .paragraph("""
                Kattintson a hőtérkép egy cellájára, hogy lássa annak a párnak a pontdiagramját, \
                regressziós egyenessel és R²-tel.
                """),
            .heading("Négy részlet, amely megváltoztatja az olvasatot"),
            .bullets([
                "**A holtversenyek átlagrangot kapnak**, így a tábla újrarendezése nem változtatja meg a Spearman-együtthatót.",
                "**Az üres cellákat páronként kezeljük**, és minden cella `n`-je ott van a táblában — a `0,93` hat soron nem ugyanazt jelenti, mint a `0,93` 6000 soron.",
                "**Az állandó oszlop üreset ad**, nem 0-t. A nulla azt jelenti: *megmérve, kapcsolat nem található*.",
                "**A színskála kék↔narancs**, nem piros-zöld: a férfiak 8 %-a egyetlen szürke masszaként látja a piros-zöld skálát, amitől a `+0,9` és a `−0,9` egyformának tűnik.",
            ]),
            .warning("""
                **A korreláció nem jelent okságot.** Ez a mondat **magába a diagramba** rajzolódik, így \
                a képpel együtt utazik, amikor exportálja.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Klaszterezés",
        summary: "k-means és DBSCAN, kétféle mód a k kiválasztására — és figyelmeztetés a skálázásról.",
        keywords: ["klaszter", "kmeans", "dbscan", "csoportok", "sziluett", "könyök"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritmus", "Használja, ha"],
                rows: [
                    ["k-means", "Ismeri (vagy ki akarja próbálni) a klaszterszámot; a klaszterek folt alakúak"],
                    ["DBSCAN", "Nem ismeri a számot; a klaszterek tetszőleges alakúak; el akarja különíteni a zajt"],
                ]
            ),
            .heading("A skálázás alapból be van kapcsolva — és hogy miért"),
            .paragraph("""
                Egy `bevétel` oszlop (milliókban) egy `mennyiség` oszlop (darabban) mellett: két sor \
                távolságát szinte teljesen a nagyobbik dönti el. Ez nem »kevésbé optimális« — ez **másik \
                kérdésre válaszolás**. Az érvényes skálázás bekerül az eredménybe.
                """),
            .heading("A klaszterszám megválasztása"),
            .bullets([
                "**Sziluett** — minél magasabb a pontszám, annál jobban elkülönülnek a klaszterek. Nagy táblán **mintavételez** (egyenletesen, nem az első 2000 sort), és az eredmény kimondja, hogy becslés.",
                "**Könyök** — a klasztereken belüli négyzetösszeget ábrázolja a k függvényében. Ez **egy diagram olvasási módja**, nem optimalizálás: az a mennyiség a k növekedésével mindig csökken, így statisztikailag nincs »optimális k«.",
            ]),
            .note("""
                A DBSCAN-nál a **k-távolság** ábra segít a sugár megválasztásában: a görbe térde \
                rendszerint ésszerű kiindulási érték.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Idősor-előrejelzés",
        summary: "Trend és szezonalitás bontása, Holt-Winters, és egy alapmodell, amely mindig mellette fut.",
        keywords: ["előrejelzés", "idősor", "szezonalitás", "holt-winters", "trend"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Válasszon egy időoszlopot és egy értékoszlopot. A GEditor a sorozatot **trend · \
                szezonalitás · maradék** részekre bontja, majd Holt-Wintersszel jelez előre (additív \
                vagy multiplikatív), 80 %-os és 95 %-os intervallumokkal.
                """),
            .heading("Az alapmodell mindig lefut, és nyíltan megmondja, ki nyert"),
            .paragraph("""
                A modell mellett a GEditor két naiv módszert futtat: *vedd az előző időszakot* és *vedd \
                az előző szezon azonos időszakát*. Ha a modell **veszít** egy alapmodellel szemben, az a \
                mondat **az első sorban, más színnel** jelenik meg — nem egy számtábla alatt.
                """),
            .paragraph("""
                Az ok: az előrejelző eszközök hajlamosak tényként bemutatni a modellt, és a \
                felhasználónak nincs módja megtudni, hogy a »vedd csak a múlt havi számot« pontosabb \
                lett volna.
                """),
            .heading("Három hely, ahol a GEditor megtagadja vagy bevallja magát"),
            .bullets([
                "**Két teljes ciklus nélkül visszaesik a naiv módszerre.** Egyetlen ciklus zajára szezonalitást illeszteni és a jövőbe ismételni nagyon meggyőző, teljesen kitalált előrejelzést ad.",
                "**A nullába ütköző MAPE ezt kimondja**, és ha az időszakok több mint 25 %-a nulla, visszatartja a mutatót — a csendes átugrásuk szisztematikusan torzított részhalmazon számolt számot ad.",
                "**A konfidenciaintervallum kimondja, hogy közelítő**, és hogy hosszú horizonton túl lassan szélesedik.",
            ]),
            .note("""
                A szezonperiódust az **első differencián** ismeri fel, nem a nyers soron: a trend minden \
                késleltetést erősen korrelálttá tesz, és elnyeli a szezoncsúcsot.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Asszociációs szabályok",
        summary: "Aki A-t vesz, gyakran B-t is — és miért lift, nem bizalom szerint rendezünk.",
        keywords: ["apriori", "asszociációs szabályok", "vásárlói kosár", "lift", "támogatás"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Kétféle adatalakot fogad el:"),
            .bullets([
                "**Soronként egy kosár** — egy oszlop, amely tételek listáját tartalmazza.",
                "**Két oszlop** — tranzakcióazonosító és tétel, soronként egy tétel.",
            ]),
            .table(
                headers: ["Mutató", "Jelentés"],
                rows: [
                    ["támogatás", "Azon kosarak aránya, amelyek mindkét oldalt tartalmazzák"],
                    ["bizalom", "A bal oldalt tartalmazó kosarak közül mekkora hányadban van ott a jobb"],
                    ["**lift**", "A bizalom osztva a jobb oldal alapgyakoriságával"],
                    ["emelő", "Az eltérés attól, amit a függetlenség jósolna"],
                ]
            ),
            .heading("Lift szerint rendezve, nem bizalom szerint"),
            .paragraph("""
                Ha a jobb oldal amúgy is a kosarak 95 %-ában szerepel, akkor **minden** hozzá vezető \
                szabálynak nagyjából 95 % a bizalma — miközben semmit sem mond. A bizalom szerinti \
                rendezés épp a legértelmetlenebb szabályokat teszi felülre.
                """),
            .warning("""
                A `lift < 1` **magában a sorban meg van jelölve**: 80 % bizalom valami felé, aminek 95 % \
                az alapgyakorisága, **fordított** kapcsolatot jelent — helyes szám, amely rossz \
                következtetéshez vezet.
                """),
            .bullets([
                "Két doboz tejet venni továbbra is **egy** tejet tartalmazó tranzakció: a kosáron belüli ismétlődéseket eldobjuk, különben a támogatás a mennyiséggel együtt felfújódik.",
                "A támogatási küszöb túl alacsonyra állítása kombinatorikusan felrobbantja a jelöltkészletet; a plafont elérve a **GEditor megáll, és kimondja, hogy a tábla hiányos**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Csoportonkénti bányászat",
        summary: "Futtassa újra az elemzést csoportonként külön — ez a lépés fordítja meg leggyakrabban a következtetést.",
        keywords: ["csoportosítás", "csoportonként", "simpson", "fiókok", "csoportok összevetése"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Válasszon egy szövegoszlopot csoportosítási kulcsnak. Minden csoport **teljesen \
                függetlenül** kap rendellenesség-keresést, előrejelzést és korrelációt, majd az Ön által \
                választott szempont szerint rangsorolódnak.
                """),
            .heading("Miért kell a csoportokat elkülöníteni, nem összevonni"),
            .paragraph("""
                Két fiók, az egyik 10 körül, a másik 100 körül. Az **összevont** táblán számolt \
                kiugró-kerítés ±135 körül landol — és **mindkét irányban** hibázik:
                """),
            .bullets([
                "**Hamis negatívok**: egy 20-as érték, amely a kis fióknál nyilvánvalóan kiugró, kényelmesen belefér a közös kerítésbe. Minél több a csoport, annál vakabb.",
                "**Hamis pozitívok**: egy szélesen szóró csoportnak a közös kerítés levágja a normális farkát, és teljesen szokványos sorok tömege jelölődik meg.",
            ]),
            .heading("A »korrelációs eltérés« oszlop elfogja a Simpson-paradoxont"),
            .paragraph("""
                Három csoport, amelyben **minden** csoport két oszlopa `−1`-en korrelál, összevonva mégis \
                `> 0,9`-en. Aki csak az összevont táblát olvassa, **pont az ellenkezőjére** jut. Ez az \
                oszlop épp az ilyen esetekre mutat rá.
                """),
            .note("""
                A panel csak **szövegoszlopokat** kínál csoportosítási kulcsként, és 1000 csoportnál \
                figyelmeztetéssel megáll — hogy ne lehessen rendelésazonosító-oszlopot választani, és \
                minden sorból saját csoportot csinálni.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Szövegbányászat",
        summary: "n-gramok és TF-IDF egy szövegoszlopon — jellemző kifejezések keresése.",
        keywords: ["szövegbányászat", "n-gram", "tf-idf", "kulcsszavak", "kifejezések"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Egy szövegoszlopon fut — termékleírásokon, ügyfél-visszajelzéseken, megjegyzésmezőkön.
                """),
            .bullets([
                "**n-gramok** — a leggyakoribb 1, 2 és 3 szavas kifejezések.",
                "**TF-IDF** — az egyes dokumentumcsoportokra **jellemző** szavak, azaz itt gyakoriak, máshol ritkák.",
            ]),
            .paragraph("""
                A különbség: az n-gramok azt mondják meg, *»mit emlegetnek folyton az ügyfelek«*, a \
                TF-IDF azt, *»miben tér el ez a csoport a többitől«*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
