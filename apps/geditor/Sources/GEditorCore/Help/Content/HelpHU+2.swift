import Foundation

/// Magyar súgótartalom — 2. rész: keresés, fájlok és munkamenetek.
extension HelpHU {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Keresés",
        summary: "Keresés, csere, reguláris kifejezések, mappa szintű keresés és sorjelölők.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Keresés és csere",
        summary: "Három keresési mód, és hogy miért jelent a ^ alapból SOR elejét.",
        keywords: ["keresés", "csere", "megtalálás", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Keresés"),
                HelpShortcut("⌥⌘F", "Keresés és csere"),
                HelpShortcut("⌘G / ⇧⌘G", "Következő / előző találat"),
            ]),
            .heading("Három mód"),
            .table(
                headers: ["Mód", "Érti", "Mire jó"],
                rows: [
                    ["Normál", "Egyszerű szöveg, egyáltalán nincsenek különleges karakterek", "A legtöbb kereséshez"],
                    ["Kiterjesztett", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Sorvégek, TAB-ok, adott bájtok megtalálásához"],
                    ["Regex", "Teljes PCRE2", "Mintázat szerinti illesztéshez"],
                ]
            ),
            .note("""
                A **kiterjesztett** mód nem érti a regex szintaxist. Csak néhány escape-sorozatot bont \
                ki — így az `a.b` keresése ott pontosan azt a három karaktert találja meg; a pont nem \
                helyettesítő jel.
                """),
            .heading("Két kapcsoló"),
            .bullets([
                "**Kis- és nagybetű megkülönböztetése** — alapból kikapcsolva.",
                "**Csak egész szó** — csak akkor illeszkedik, ha mindkét vége szóhatár.",
            ]),
            .heading("A `^` és a `$` minden SOR szélén illeszkedik"),
            .paragraph("""
                Alapból bekapcsolva. A Notepad++-ról érkezők azt várják, hogy a `^` »sor eleje« legyen; \
                kikapcsolva a `^abc` csak akkor illeszkedne, ha az egész dokumentum `abc`-vel kezdődne \
                — ezt szövegszerkesztőben szinte senki sem akarja.
                """),
            .heading("Egy rossz kifejezés nem fagyasztja le az alkalmazást"),
            .paragraph("""
                A motor **PCRE2 JIT-fordítással**, és van visszalépési keret. Egy kombinatorikusan \
                robbanó mintát megállít és jelent, ahelyett hogy befagyasztaná az ablakot.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Reguláris kifejezések",
        summary: "A ténylegesen használt PCRE2-szintaxis, vietnami adatokon futó példákkal.",
        keywords: ["regex", "regexp", "pcre", "minta"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                A GEditor **PCRE2**-t használ, ugyanazt a motort, mint a PHP és sok parancssori eszköz. \
                Nyissa meg a `Keresés ▸ Reguláris kifejezés kipróbálása…` menüpontot, hogy mintát \
                próbáljon ki mintaszövegen, és lássa, mit fog el az egyes csoportok — **mielőtt** valódi \
                dokumentumra alkalmazná.
                """),
            .heading("Karakterosztályok"),
            .table(
                headers: ["Írja", "Illeszkedik"],
                rows: [
                    ["`.`", "Bármely karakterre a sorvég kivételével"],
                    ["`\\d` · `\\D`", "Számjegy · nem számjegy"],
                    ["`\\w` · `\\W`", "Szókarakter (betű, számjegy, `_`) · az ellenkezője"],
                    ["`\\s` · `\\S`", "Üres karakter · nem üres karakter"],
                    ["`[abc]`", "A szögletes zárójelben lévők egyikére"],
                    ["`[^abc]`", "Egy karakterre, ami NINCS a zárójelben"],
                    ["`[a-z]`", "Egy karakterre a tartományból"],
                ]
            ),
            .heading("Ismétlés"),
            .table(
                headers: ["Írja", "Jelentés"],
                rows: [
                    ["`*`", "Nulla vagy több"],
                    ["`+`", "Egy vagy több"],
                    ["`?`", "Nulla vagy egy"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Pontosan 3 · 2 és 5 között · 2 vagy több"],
                    ["`*?` `+?` `??`", "A **lusta** alakok — vegyen amennyit csak lehet keveset"],
                ]
            ),
            .warning("""
                A `.*` **mohó**: a sor végéig eszik, aztán visszalép. Ha mezőket bont egy soron belül, \
                szinte mindig `.*?` vagy szűk karakterosztály, például `[^,]*` kell.
                """),
            .heading("Horgonyok és csoportok"),
            .table(
                headers: ["Írja", "Jelentés"],
                rows: [
                    ["`^` · `$`", "Sor eleje · sor vége"],
                    ["`\\b`", "Szóhatár"],
                    ["`(…)`", "**Elfogó** csoport — újrahasználható a cserében"],
                    ["`(?:…)`", "Nem elfogó csoport"],
                    ["`(?<name>…)`", "Nevesített csoport"],
                    ["`a|b`", "a vagy b"],
                    ["`(?=…)` · `(?!…)`", "Előretekintés: követnie kell · nem követheti"],
                    ["`(?<=…)` · `(?<!…)`", "Hátratekintés: meg kell előznie · nem előzheti meg"],
                ]
            ),
            .heading("Futó példák"),
            .code(language: "regex", caption: "Minden tízjegyű vietnami telefonszám",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "A 31/12/2026 dátum három csoportra bontása",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "Egy egyszerű CSV-sor harmadik cellája (idézőjelek nélkül)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "ERROR vagy FATAL szintű naplósorok, időbélyeggel",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Üres sorok, vagy csak üres karaktereket tartalmazó sorok",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Ékezetes vietnami betűk — használja az Unicode-osztályt, ne sorolja fel őket",
                  source: "\\p{L}+"),
            .note("""
                A `\\p{L}` azt jelenti: »bármely Unicode-betű«, így az `ế`-re és a `đ`-re is \
                illeszkedik. Minden ékezetes magánhangzót kézzel felsorolni biztos módja annak, hogy \
                néhány kimaradjon.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Cserekarakterláncok",
        summary: "Használja újra az elfogott csoportokat, és váltson kis-/nagybetűt csere közben.",
        keywords: ["csere", "visszahivatkozás", "csoport", "$1", "\\U"],
        blocks: [
            .heading("Elfogott csoport visszahívása"),
            .table(
                headers: ["Írja", "Jelentés"],
                rows: [
                    ["`$1` … `$9`", "Az n-edik csoport tartalma"],
                    ["`${1}`", "Ugyanaz, kifejezett határokkal — használja, ha számjegy követi"],
                    ["`\\1`", "Ezt is elfogadja; a GEditor `${1}`-re írja át"],
                    ["`$0`", "A teljes találat"],
                ]
            ),
            .note("""
                Írjon `${1}`-et `$1` helyett, ha a következő karakter számjegy. A `$123` a 123-as \
                csoportként olvasódik; a `${1}23` az 1-es csoport, majd két számjegy.
                """),
            .heading("Kis-/nagybetű váltása csere közben"),
            .table(
                headers: ["Írja", "Jelentés"],
                rows: [
                    ["`\\U`", "NAGYBETŰS innentől"],
                    ["`\\L`", "kisbetűs innentől"],
                    ["`\\u`", "Csak a következő karakter nagybetűs"],
                    ["`\\l`", "Csak a következő karakter kisbetűs"],
                    ["`\\E`", "Lezárja a `\\U` vagy `\\L` tartományt"],
                ]
            ),
            .heading("Példák"),
            .code(language: "text", caption: "A 31/12/2026 átalakítása 2026-12-31 alakra",
                  source: """
                    Keresés: (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Csere:   $3-$2-$1
                    """),
            .code(language: "text", caption: "A sor eleji tartománykód nagybetűssé, a többi marad",
                  source: """
                    Keresés: ^([a-z]{2,3})(\\s)
                    Csere:   \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Minden sor JSON-karakterláncba csomagolása",
                  source: """
                    Keresés: ^(.+)$
                    Csere:   "$1",
                    """),
            .paragraph("""
                Az a csoport, amely **nem vett részt** a találatban, üres karakterlánccá válik, nem \
                hibává — így egy `(a)|(b)` alakú, alternatívákat tartalmazó minta is tisztán cserél, \
                anélkül hogy kétszer kellene megírni.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Keresés és csere egész mappában",
        summary: "Pásztázzon sok fájlt egyszerre, és lássa az eredményt, mielőtt bármit írna.",
        keywords: ["keresés fájlokban", "grep", "tömeges csere", "mappa"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Keresés egész mappában")]),
            .paragraph("""
                Válassza ki a gyökérmappát, szűrjön fájlnévmintára, majd pásztázzon. Az eredmények \
                fájlonként csoportosított listaként jelennek meg; egy sorra kattintva megnyílik az a \
                fájl azon a helyen.
                """),
            .bullets([
                "Ugyanaz a három keresési mód és ugyanaz a regex-motor, mint a dokumentum keresőmezőjében.",
                "A mappa szintű csere **előre megmutatja**, hány fájl és hány találat változik, mielőtt írna.",
                "A pásztázás párhuzamosan fut, és **félbeszakítható**.",
            ]),
            .warning("""
                A mappa szintű csere közvetlenül olyan fájlokba ír, amelyek **nincsenek megnyitva**. Azok \
                a fájlok nincsenek benne a nyitott dokumentum visszavonási előzményében — előbb nézze meg \
                az előnézetet, és legyen mentése vagy verziókövetett tárolója.
                """),
            .heading("Korábbi keresések és az eredmények exportálása"),
            .paragraph("""
                Az eredménypanel **megtartja ennek a munkamenetnek a kereséseit**. A panel tetején lévő \
                felugró menü felsorolja őket a találatszámokkal — keressen `TODO`-ra, olvasson bele, \
                keressen `FIXME`-re az összevetéshez, majd térjen vissza az első listához anélkül, hogy \
                újra átpásztázná az egész mappát.
                """),
            .paragraph("""
                Az **Exportálás** gomb az aktuális keresést szöveges lapként nyitja meg, soronként egy \
                eredménnyel `útvonal:sor:oszlop: szöveg` alakban — ezt a formát használja a `grep -n`, és \
                ezt használják a fordítók a hibákhoz. Minden sor közvetlenül beilleszthető a termék saját \
                `Ugrás` mezőjébe, és a `grep`, `awk`, `sed` saját elemző nélkül olvassa.
                """),
            .note("""
                Az előzmény a **memóriában** él, és soha nem kerül lemezre: a keresési eredmények minden \
                illeszkedő sor tartalmát hordozzák, ami ugyanaz az adatosztály, amit a vágólap-előzmény \
                szándékosan nem tárol.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Sorjelölők",
        summary: "Kilenc jelölőszín és négy parancs, amely eredménnyé teszi a megjelölt sorokat.",
        keywords: ["könyvjelző", "jelölő", "f2", "sorok szűrése"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                A jelölés az a mód, ahogy dokumentumot szűrhet **anélkül, hogy megváltoztatná**. Jelölje \
                meg a mintára illeszkedő minden sort, aztán csak azokat másolja ki — vagy csak azokat \
                tartsa meg.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Az aktuális keresésre illeszkedő minden sor megjelölése"),
                HelpShortcut("⌘F2", "Jelölés be/ki az aktuális soron"),
                HelpShortcut("F2 / ⇧F2", "Ugrás a következő / előző jelölőre"),
            ]),
            .heading("Egy megszokott menet"),
            .steps([
                "`⌘F` arra a mintára, amire szűrni akar, pl. `\\bERROR\\b`.",
                "`⌘M` megjelöl minden illeszkedő sort.",
                "A `Keresés ▸ Megjelölt sorok másolása` új lapra húzza őket — vagy a `Csak a megjelölt sorok megtartása` helyben szűr.",
            ]),
            .heading("Kilenc szín"),
            .paragraph("""
                Egy sor **több színt is viselhet egyszerre**. Használjon különböző színeket különböző \
                szempontokhoz, és kombinálja őket: pirosat a hibás sorokhoz, sárgát az egy \
                rendelésazonosítóhoz tartozókhoz, majd keresse azokat, amelyek mindkettőt viselik.
                """),
            .bullets([
                "`Jelölők megfordítása` — a megjelölt sorok jelöletlenné válnak és fordítva.",
                "`Minden jelölő törlése` — eltávolít minden jelölőt anélkül, hogy a tartalomhoz nyúlna.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Ugrás sorra",
        summary: "Ugorjon sorra, oszlopra vagy bájtpozícióra.",
        keywords: ["ugrás", "sorszám", "cmd+l", "pozíció", "oszlop"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Ugrás sorra")]),
            .paragraph("""
                A mező **háromféle írásmódot** ért, és abból különbözteti meg őket, amit beír — nincs \
                külön választó, amire kattintani kellene.
                """),
            .table(
                headers: ["Írja", "Ide megy"],
                rows: [
                    ["`120`", "a 120. sor elejére"],
                    ["`120,5` vagy `120:5`", "a 120. sor 5. oszlopába — az oszlop KARAKTEREKET számol"],
                    ["`@1024`", "az 1024. bájtpozícióra a fájlban"],
                ]
            ),
            .note("""
                A `sor:oszlop` pontosan úgy néz ki, ahogy a fordítók és linterek kiírják a pozíciót, így \
                a terminálból épp kimásolt sor közvetlenül beilleszthető.

                A bájtpozíciók `@` jelének oka van: az `1234` sor vagy bájt? Nincs helyes válasz, és egy \
                rossz tipp egészen máshová viszi a kurzort anélkül, hogy bármi jelezné. Ez a bájtszám az \
                is, amit az állapotsor a pozíciómezőben mutat (`@1024`), így amit ott olvas, azt ide \
                beírhatja.
                """),
            .bullets([
                "A **sor hosszán túli** oszlop az adott sor végén megáll; nem csordul át a következőre.",
                "A **fájlon túli** bájtpozíció a végére visz — azt a számot rendszerint egy korábbi futásból másolta, és a fájl közben zsugorodhatott.",
                "Az olvashatatlan szöveget **jelenti**, és a kurzor helyben marad; nem ugrik a fájl elejére.",
            ]),
            .paragraph("""
                Nagyon nagy fájloknál a GEditor nem olvassa végig a fájlt, hogy odaérjen — a sorindex \
                fokozatosan épül a háttérben.
                """),
            .note("""
                A parancssori eszköz is elfogad pozíciót: a `geditor report.csv:120:5` a fájlt a 120. \
                sor 5. oszlopában lévő kurzorral nyitja meg.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Fájlok és munkamenetek

    static let files = HelpChapter(
        id: "tep",
        title: "Fájlok és munkamenetek",
        summary: "Megnyitás, mentés, lapok, ablakok, munkaterületek, és hogyan tér vissza a munkamenet.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Megnyitás és mentés",
        summary: "Nyisson meg bármekkora fájlt, és mentse más kódolással vagy sorvéggel.",
        keywords: ["megnyitás", "mentés", "mentés másként", "kettőzés", "átnevezés", "áthelyezés"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Új dokumentum"),
                HelpShortcut("⌘O", "Fájl megnyitása"),
                HelpShortcut("⌘S", "Mentés"),
                HelpShortcut("⇧⌘S", "Mentés másként"),
            ]),
            .paragraph("""
                Egy fájl behúzása az ablakba is megnyitja. A `Fájl ▸ Legutóbbiak megnyitása` őrzi azon \
                fájlok listáját, amelyekkel épp dolgozott.
                """),
            .heading("Mentés másként: három dolog, amit módosíthat"),
            .table(
                headers: ["Módosítás", "Jelentés"],
                rows: [
                    ["Kódolás", "Kiírás UTF-8, TCVN3, VNI-Windows… — 36 kódolás"],
                    ["Sorvégek", "LF (Unix) · CRLF (Windows) · CR (klasszikus Mac)"],
                    ["Név és hely", "Mint minden macOS mentési ablakban"],
                ]
            ),
            .paragraph("""
                Az állapotsor mindig mutatja a kódolást, a sorvégstílust és a felismert nyelvet. \
                **Bármelyikre kattintva azonnal megváltozik**, párbeszédablak nélkül.
                """),
            .heading("Kettőzés · átnevezés · áthelyezés"),
            .paragraph("""
                Ez a három a FÁJLLAL dolgozik, nem a tartalmával — és a nyitott lap követi a fájlt, így \
                sosem veszíti el a helyét.
                """),
            .table(
                headers: ["Parancs", "Mit csinál"],
                rows: [
                    ["`Fájl kettőzése`",
                     "`név 2.txt` néven másolja az eredeti mellé, és **megnyitja a másolatot** — mert az emberek azért kettőznek, hogy a másolatot szerkesszék"],
                    ["`Fájl átnevezése…`", "Átnevezi a lemezen; a lap követi az új nevet"],
                    ["`Fájl áthelyezése…`", "Másik mappába helyezi; a lap vele megy"],
                ]
            ),
            .note("""
                Mindhárom **megtagadja, ha a célban már van ilyen nevű fájl**; soha nem írnak felül. És \
                mindháromhoz legalább egyszer már mentett fájl kell — egy dokumentumnak, amely sosem \
                volt lemezen, nincs mit kettőznie vagy áthelyeznie.
                """),
            .heading("Biztonságos írás"),
            .bullets([
                "Az írás **atomi**: a félbeszakadó áram sosem hagy csonka fájlt.",
                "Ha egy másik program módosítja a fájlt, miközben nyitva van Önnél, a GEditor észreveszi, és felülírás előtt megkérdezi.",
                "Az iCloud Drive-on vagy hálózati köteten lévő fájlok a rendszer fájlkoordinátorán át mennek, hogy két gép ne lépjen egymásra.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Lapok, ablakok és osztott nézet",
        summary: "Sok lap ablakonként, sok ablak, és lapok, amelyeket köztük húzhat.",
        keywords: ["lap", "ablak", "osztás", "panel"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Új lap"),
                HelpShortcut("⌘W", "Lap bezárása"),
                HelpShortcut("⇧⌘T", "A legutóbb bezárt lap újranyitása"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Következő / előző lap"),
                HelpShortcut("⌥⌘N", "Új ablak"),
                HelpShortcut("⌃⌘N", "Az aktuális lap leválasztása saját ablakba"),
            ]),
            .paragraph("""
                Egy lapot áthúzhat másik ablakba, vagy üres helyre ejtve új ablakot csinálhat. **A \
                rögzített lap nem utazik** — a rögzítés azt jelenti: »ez maradjon itt«.
                """),
            .note("""
                A `⇧⌘T` a legutóbb bezárt lapot nyitja meg újra, akár **mentetlent** is: a tartalma \
                megvan.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Mappa megnyitása munkaterületként",
        summary: "Fájlfa az oldalsávban, projekt szintű keresés és egykattintásos megnyitás.",
        keywords: ["munkaterület", "mappa", "projekt", "oldalsáv"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Mappa megnyitása munkaterületként")]),
            .paragraph("""
                A fa az oldalsávban jelenik meg (`⌘0`). Kattintson egy fájlra a megnyitáshoz, és a \
                `⇧⌘F` az egész mappában keres.
                """),
            .note("""
                Az App Store-kiadásban a mappa elérését **biztonsági hatókörű könyvjelző** tartja, így a \
                következő indítás is eléri anélkül, hogy újra kérné a mappa kiválasztását.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "A munkamenet magától visszaáll",
        summary: "Lépjen ki és nyissa meg újra: minden lap visszatér, a mentetlenek is.",
        keywords: ["munkamenet", "visszaállítás", "mentetlen"],
        blocks: [
            .paragraph("""
                Nincs mit bekapcsolni. Lépjen ki a GEditorból, és nyissa meg újra: a lapok, a \
                sorrendjük, a kurzorpozíciók és a görgetési helyek mind visszatérnek.
                """),
            .heading("Mi van a mentetlen lapokkal"),
            .paragraph("""
                A tartalmuk külön pillanatképben marad meg, így ők is visszatérnek. Ha az alkalmazás \
                rendellenesen lép ki, a következő indítás **megkérdezi**, mielőtt visszaállítaná az \
                árva piszkozatokat — ahelyett hogy csendben újraépítene egy halom lapot, amire nem \
                emlékszik.
                """),
            .warning("""
                A munkamenet **nem biztonsági mentés**. Munkaállapotot őriz, nem előzményt. Ami \
                számít, azt így is fájlba kell menteni.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Korábban mentett változatok",
        summary: "Böngéssze és állítsa vissza egy fájl régebbi változatait.",
        keywords: ["változatok", "előzmény", "visszaállítás", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Minden mentéskor a GEditor felülírás előtt feljegyzi az **előző** változatot. A \
                `Makró ▸ Mentett változatok…` nyitja meg a böngészőjüket.
                """),
            .bullets([
                "A változattár **az operációs rendszeré**, ugyanaz a mechanizmus, amit az Apple saját alkalmazásai használnak.",
                "Egy régebbi változat visszaállítása **közönséges szerkesztés** — a `⌘Z` visszavonja.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Még íródó fájl követése",
        summary: "Mint a `tail -f`: ami hozzáíródik, megjelenik, ahogy érkezik.",
        keywords: ["tail", "követés", "napló", "valós idő"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                A `Fájl ▸ Fájl követése (tail -f)` betölti, ami a fájl végén megjelenik, és görget vele.
                """),
            .warning("""
                Követés közben a dokumentum **csak olvashatóvá** válik. Gépelni, miközben a lemezről új \
                szöveg töltődik, két írót jelent egy dokumentumon, és a vesztes mindig az, amit épp \
                beírt.
                """),
            .note("""
                Az állapotsor végig **Követés alatt** feliratot mutat, így percekkel később is tudja, \
                miért nem fogadja a fájl a gépelést. A **csak olvasható** mezőre kattintva az ok \
                nyíltan kimondódik.

                A követés **ahhoz a laphoz tartozik, amely elindította**, nem az ablakhoz: nyisson másik \
                lapot és gépeljen tovább, az új naplósorok akkor is a saját lapjukba folynak, anélkül \
                hogy a szerkesztett fájlhoz nyúlnának.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Nyomtatás",
        summary: "Nyomtasson a macOS szokásos nyomtatási ablakán át.",
        keywords: ["nyomtatás", "papír", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Nyomtatás")]),
            .paragraph("""
                A rendszer nyomtatási ablakát használja, így a PDF-be exportálás is ott történik — a \
                bal alsó `PDF` gomb.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Képek, PDF-ek, Office-fájlok, hang, videó és archívumok",
        summary: "Nyolcféle fájl nyílik meg a GEditoron belül másik alkalmazás nélkül.",
        keywords: ["kép", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "archívum",
                   "hang", "videó", "mp3", "mp4"],
        blocks: [
            .table(
                headers: ["Fajta", "Mit tehet"],
                rows: [
                    ["Képek", "Megtekintés, nagyítás, forgatás; **az animált képek lejátszódnak** és megállíthatók"],
                    ["Hang", "Lejátszás, tekerés, hangerő módosítása"],
                    ["Videó", "Lejátszás, tekerés, teljes képernyő, kép a képben"],
                    ["PDF", "Olvasás, keresés, **jegyzetelés**"],
                    ["Word · Excel · PowerPoint", "Megtekintés **és szerkesztés** — a `⌘S` egyenesen a fájlba ír vissza"],
                    ["ZIP · TAR · GZ · XZ", "Bejegyzések listázása és mindegyik megnyitása lapként"],
                    ["7z · RAR és további hét formátum", "Ugyanaz, a libarchive-on át"],
                ]
            ),
            .paragraph("""
                Egy archívumon belüli bejegyzés megnyitása új lapot hoz létre annak tartalmával. A \
                vietnami ékezetek a nevekben és a tartalomban is túlélik.
                """),
            .note("""
                Szerkesszen a három Office-formátum egyikében, nyomjon `⌘S`-t, és visszaíródik a fájlba \
                — a LibreOffice elolvassa az eredményt. Ez az út végponttól végpontig tesztelt, nem \
                pusztán másolatba exportált.
                """),
            .heading("A hang és a videó a macOS lejátszóit használja"),
            .paragraph("""
                A lejátszás a rendszer saját dekódolóin megy át, így semmi extra nem töltődik le, és \
                semmi extra nem szállítódik. Cserébe néhány formátum **nem játszható le** — `.mkv`, \
                `.webm`, `.avi`, `.wmv` — mert a macOS-nek nincs beépített dekódolója hozzájuk.
                """),
            .paragraph("""
                Ilyen fájlnál a GEditor **megmondja, miért**, ahelyett hogy fekete téglalapot mutatna, \
                és felajánlja a bináris nézegetőt vagy másik alkalmazást.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "PDF-eszközök",
        summary: "Olvasás, jegyzetelés, és egy egész oldalréteg: forgatás · mozgatás · törlés · kivonás · összefűzés.",
        keywords: ["pdf", "oldal", "forgatás", "oldal törlése", "kivonás", "összefűzés",
                   "jegyzet", "kiemelés", "aláírás"],
        blocks: [
            .paragraph("""
                A PDF-nézetnek **két eszközsora** van, és különböző kérdésekre válaszolnak. A felső sor \
                egy oldal **tartalmán** dolgozik; az alsó **az oldalak halmazán**.
                """),
            .heading("Felső sor — olvasás és jegyzetelés"),
            .table(
                headers: ["Gomb", "Mit csinál"],
                rows: [
                    ["Kiemelés · Aláhúzás", "Megjelöli a kijelölt szöveget"],
                    ["Jegyzet…", "Jegyzetet csatol az oldalhoz"],
                    ["Jegyzetek eltávolítása", "Eltávolít minden jegyzetet az aktuális oldalról"],
                    ["Szöveg kivonása új lapra", "Az egész szöveget lapra viszi, hogy kereshessen, szűrhessen, más eszközöket futtathasson"],
                    ["Keresőmező", "Keresés a PDF-en belül — **az ékezet nélküli gépelés is megtalálja az ékezetes szöveget**"],
                ]
            ),
            .note("""
                A beolvasott PDF-nek nincs szövegrétege. A kivonó parancs **megmondja ezt**, ahelyett \
                hogy üres lapot nyitna, és Önre bízná a találgatást.
                """),
            .heading("Alsó sor — oldalműveletek"),
            .table(
                headers: ["Gomb", "Mit csinál", "Visszavonható"],
                rows: [
                    ["Forgatás balra · jobbra", "Az aktuális oldalt 90°-kal fordítja", "Igen"],
                    ["Oldal fel · le", "Megcseréli az aktuális oldalt a szomszédjával", "Igen"],
                    ["Oldalak törlése…", "Tartomány szerint töröl, pl. `2-4,7`", "Igen"],
                    ["Oldalak kivonása…", "Oldaltartományt ír ki **új fájlként**", "A nyitott fájlhoz nem nyúl"],
                    ["PDF összefűzése…", "Másik PDF-et szúr be közvetlenül az aktuális oldal után", "Igen"],
                    ["Aláírás…", "Aláíráskép elhelyezése az aktuális oldalon", "Igen"],
                    ["Szöveg szerkesztése…", "Csereszöveget rajzol a kijelölés fölé", "Igen"],
                    ["Következő üres mező", "A következő kitöltetlen űrlapmezőre ugrik", "—"],
                    ["Kitöltött értékek törlése", "Kiüríti az összes űrlapmezőt", "Igen"],
                    ["Oldalváltoztatás visszavonása", "Egy oldalművelettel visszalép", "—"],
                    ["A szerkesztett másolat mentése…", "Új fájlt ír, majd **újranyitja ellenőrzésre**", "—"],
                ]
            ),
            .heading("Kitölthető űrlapok"),
            .paragraph("""
                Nyisson meg egy űrlapmezőket tartalmazó PDF-et, és az állapotsor megmondja, **hány** van \
                belőlük. Gépeljen közvetlenül az oldal mezőibe, majd `A szerkesztett másolat mentése…`.
                """),
            .bullets([
                "Az értékek **élő űrlapmezőként** tárolódnak, nem lapított szövegként — így a címzett Acrobatja továbbra is kitöltött űrlapot lát, és javíthatja.",
                "A vietnami ékezetek túlélik az írás-és-újranyitás kört. Egy teszt épp ezt őrzi, a `Nguyễn Văn Anh` névvel.",
                "A `Következő üres mező` a következő üresre ugrik — ez a természetes út egy hosszú űrlapon át.",
            ]),
            .heading("Aláírás"),
            .paragraph("""
                Készítsen elő aláírásképet (átlátszó hátterű PNG a legjobb), **jelölje ki az aláírás \
                helyét** — általában a kipontozott vonalat vagy az »Aláírás« szót —, majd nyomja meg az \
                `Aláírás…` gombot. Kijelölés nélkül az aláírás jobbra lent landol.
                """),
            .note("""
                Az aláírás megtartja a kép **oldalarányát**: egy összenyomott vagy megnyújtott aláírás \
                azonnal hamisnak látszik.
                """),
            .heading("Szöveg szerkesztése — és három dolog, amit előbb tudni kell"),
            .paragraph("""
                Jelölje ki a módosítandó szöveget, és nyomja meg a `Szöveg szerkesztése…` gombot. A \
                GEditor **lefedi azt a területet a közvetlenül mellőle vett háttérszínnel**, majd rárajzolja \
                az új szöveget.
                """),
            .warning("""
                **A régi szöveg LE VAN FEDVE, nem TÖRÖLVE.** Még a fájlban van, és továbbra is kivonható \
                a `Szöveg kivonása új lapra` paranccsal vagy bármely más eszközzel. Ez **nem kitakarás**: \
                egy személyi szám így elrejtve emberi szem elől rejtőzik, gép elől nem.
                """),
            .bullets([
                "**Az új szöveg továbbra is megtalálható a `⌘F`-fel.** Valódi szövegként rajzolódik, nem képként — teszttel mérve, nem feltételezve.",
                "**A betűtípus rendszerbetűtípus**, nem a dokumentum eredetije. Szándékosan: a PDF-be ágyazott betűtípusokból gyakran hiányoznak a vietnami ékezetek, és a `Nguyễn` `Nguy?n`-ként érkezne.",
                "**Mintás háttéren látszik a folt** — a fedőszín egyetlen pontból vevődik, közvetlenül a kijelölés balján.",
            ]),
            .heading("Miért rajzolunk fölé a tartalomfolyam szerkesztése helyett"),
            .paragraph("""
                Egy PDF tartalomfolyamának közvetlen szerkesztése azt jelenti, hogy saját kódolású \
                részhalmaz-betűtípusokkal, alávágás miatt három darabra tört mondatokkal és újraszámolandó \
                karakterszélesség-táblákkal kell megküzdeni. **Minden** fájlra helyesen megcsinálni önálló \
                projekt; rosszul megcsinálni tönkreteszi valakinek a dokumentumát.
                """),
            .paragraph("""
                Cserébe az oldal többi része **egyetlen bájtot sem változik**, és az oldal oldal marad — \
                a szöveg továbbra is kijelölhető, másolható, kereshető. A ráfestés **nem** teszi képpé.
                """),
            .heading("Az oldaltartomány szintaxisa"),
            .table(
                headers: ["Írja", "Jelentés"],
                rows: [
                    ["`5`", "Csak az 5. oldal"],
                    ["`2-4`", "A 2., 3., 4. oldal"],
                    ["`-3`", "Az elejétől a 3. oldalig"],
                    ["`8-`", "A 8. oldaltól a végéig"],
                    ["`1-3,5,9-`", "Több rész vesszővel összekötve"],
                ]
            ),
            .paragraph("Az oldalak **1-től** számozódnak, azzal a számmal, amit a képernyőn lát."),
            .warning("""
                A fordított tartományt (`5-2`) és a végen túlnyúlót (`1-999`) is **okkal utasítja el**, \
                soha nem javítja csendben valami közelire. Oldaltörlő parancsnál a rossz tipp elveszett \
                oldalakat jelent, a csendes levágás pedig egy elgépelést érvényes paranccsá tesz.
                """),
            .heading("Az eredeti fájl sosem íródik felül"),
            .paragraph("""
                A fentiek mind **a memóriában** változtatják a dokumentumot. Csak amikor megnyomja `A \
                szerkesztett másolat mentése…` gombot és helyet választ, akkor íródik fájl — és írás \
                után a GEditor **újranyitja épp azt a fájlt**, hogy megerősítse: minden oldala megvan.
                """),
            .paragraph("""
                Az ok: egy rosszul megírt fájl teljesen normálisnak látszva ül a lemezen, és a \
                felhasználó csak azután tudja meg, hogy elküldte.
                """),
            .note("""
                A nézet állapotsora **· szerkesztve, nem mentve** feliratot mutat, valahányszor a \
                dokumentum eltér a lemezen lévő fájltól.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
