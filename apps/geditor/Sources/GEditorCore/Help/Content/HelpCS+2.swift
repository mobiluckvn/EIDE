import Foundation

/// Česká nápověda — část 2: hledání a soubory se sezeními.
extension HelpCS {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Hledání",
        summary: "Hledat, nahradit, regulární výrazy, hledání v celé složce a značky řádků.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Hledat a nahradit",
        summary: "Tři režimy hledání a proč ^ ve výchozím stavu znamená začátek ŘÁDKU.",
        keywords: ["hledat", "nahradit", "najít", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Hledat"),
                HelpShortcut("⌥⌘F", "Hledat a nahradit"),
                HelpShortcut("⌘G / ⇧⌘G", "Další / předchozí výskyt"),
            ]),
            .heading("Tři režimy"),
            .table(
                headers: ["Režim", "Rozumí", "Použití"],
                rows: [
                    ["Normální", "Prostý text, vůbec žádné zvláštní znaky", "Většina hledání"],
                    ["Rozšířený", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Hledání konců řádků, TABů, konkrétních bajtů"],
                    ["Regex", "Plné PCRE2", "Hledání podle vzoru"],
                ]
            ),
            .note("""
                **Rozšířený** režim nerozumí syntaxi regexů. Rozvine jen několik únikových sekvencí — \
                takže hledání `a.b` tam najde přesně tyto tři znaky; tečka není zástupný znak.
                """),
            .heading("Dva přepínače"),
            .bullets([
                "**Rozlišovat velikost písmen** — ve výchozím stavu vypnuto.",
                "**Celá slova** — odpovídá jen tehdy, když jsou oba konce hranicemi slova.",
            ]),
            .heading("`^` a `$` odpovídají okrajům každého ŘÁDKU"),
            .paragraph("""
                Ve výchozím stavu zapnuto. Lidé přicházející z Notepad++ očekávají, že `^` znamená \
                »začátek řádku«; s tímto vypnutým by `^abc` odpovídalo, jen kdyby celý dokument \
                začínal `abc` — to v textovém editoru nechce téměř nikdo.
                """),
            .heading("Špatný výraz aplikaci nezasekne"),
            .paragraph("""
                Jádrem je **PCRE2 s JIT překladem** a má rozpočet na zpětné navracení. Vzor, který \
                kombinatoricky exploduje, se zastaví a ohlásí, místo aby okno zamrzlo.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Regulární výrazy",
        summary: "Syntaxe PCRE2, kterou skutečně používáte, s příklady běžícími na vietnamských datech.",
        keywords: ["regex", "regexp", "pcre", "vzor"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor používá **PCRE2**, stejné jádro jako PHP a mnoho nástrojů příkazového řádku. \
                Otevřete `Hledání ▸ Vyzkoušet regulární výraz…` a vyzkoušejte vzor na ukázkovém textu, \
                abyste viděli, co která skupina zachytí, **dřív** než ho použijete na skutečný dokument.
                """),
            .heading("Znakové třídy"),
            .table(
                headers: ["Napište", "Odpovídá"],
                rows: [
                    ["`.`", "Libovolnému znaku kromě konce řádku"],
                    ["`\\d` · `\\D`", "Číslici · nečíslici"],
                    ["`\\w` · `\\W`", "Znaku slova (písmeno, číslice, `_`) · opaku"],
                    ["`[abc]`", "Jednomu ze znaků v závorkách"],
                    ["`\\s` · `\\S`", "Bílému znaku · nebílému znaku"],
                    ["`[^abc]`", "Jednomu znaku, který NENÍ v závorkách"],
                    ["`[a-z]`", "Jednomu znaku z rozsahu"],
                ]
            ),
            .heading("Opakování"),
            .table(
                headers: ["Napište", "Význam"],
                rows: [
                    ["`*`", "Nula nebo více"],
                    ["`+`", "Jeden nebo více"],
                    ["`?`", "Nula nebo jeden"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Přesně 3 · mezi 2 a 5 · 2 nebo více"],
                    ["`*?` `+?` `??`", "**Líné** tvary — vezmi co nejméně"],
                ]
            ),
            .warning("""
                `.*` je **hladové**: sní to až do konce řádku a pak couvá. Při dělení polí uvnitř řádku \
                téměř vždy potřebujete `.*?` nebo úzkou znakovou třídu jako `[^,]*`.
                """),
            .heading("Kotvy a skupiny"),
            .table(
                headers: ["Napište", "Význam"],
                rows: [
                    ["`^` · `$`", "Začátek řádku · konec řádku"],
                    ["`\\b`", "Hranice slova"],
                    ["`(…)`", "**Zachycující** skupina — použitelná v náhradě"],
                    ["`(?:…)`", "Nezachycující skupina"],
                    ["`(?<name>…)`", "Pojmenovaná skupina"],
                    ["`a|b`", "a nebo b"],
                    ["`(?=…)` · `(?!…)`", "Pohled vpřed: musí následovat · nesmí následovat"],
                    ["`(?<=…)` · `(?<!…)`", "Pohled vzad: musí předcházet · nesmí předcházet"],
                ]
            ),
            .heading("Fungující příklady"),
            .code(language: "regex", caption: "Každé desetimístné vietnamské telefonní číslo",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Rozdělit datum jako 31/12/2026 do tří skupin",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "Třetí buňka jednoduchého řádku CSV (bez uvozovek)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Řádky logu úrovně ERROR nebo FATAL i s časovým razítkem",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Prázdné řádky nebo řádky obsahující jen bílé znaky",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Vietnamská písmena s diakritikou — použijte třídu Unicode, nevypisujte je",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` znamená »libovolné písmeno Unicode«, takže odpovídá i `ế` a `đ`. Vypisovat \
                ručně každou samohlásku s diakritikou je zaručený způsob, jak některé přehlédnout.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Náhradní řetězce",
        summary: "Znovu použijte zachycené skupiny a při nahrazování měňte velikost písmen.",
        keywords: ["nahradit", "zpětný odkaz", "skupina", "$1", "\\U"],
        blocks: [
            .heading("Volání zachycené skupiny"),
            .table(
                headers: ["Napište", "Význam"],
                rows: [
                    ["`$1` … `$9`", "Obsah skupiny n"],
                    ["`${1}`", "Totéž s výslovnými hranicemi — použijte, když následuje číslice"],
                    ["`\\1`", "Přijímá se také; GEditor to přepíše na `${1}`"],
                    ["`$0`", "Celý nalezený úsek"],
                ]
            ),
            .note("""
                Pište `${1}` spíš než `$1`, když je dalším znakem číslice. `$123` se čte jako skupina \
                123; `${1}23` je skupina 1 následovaná dvěma číslicemi.
                """),
            .heading("Změna velikosti písmen během náhrady"),
            .table(
                headers: ["Napište", "Význam"],
                rows: [
                    ["`\\U`", "VELKÁ PÍSMENA odsud dál"],
                    ["`\\L`", "malá písmena odsud dál"],
                    ["`\\u`", "Jen následující znak velkým"],
                    ["`\\l`", "Jen následující znak malým"],
                    ["`\\E`", "Ukončí oblast `\\U` nebo `\\L`"],
                ]
            ),
            .heading("Příklady"),
            .code(language: "text", caption: "Změnit 31/12/2026 na 2026-12-31",
                  source: """
                    Hledat:   (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Nahradit: $3-$2-$1
                    """),
            .code(language: "text", caption: "Kód provincie na začátku každého řádku velkými, zbytek ponechat",
                  source: """
                    Hledat:   ^([a-z]{2,3})(\\s)
                    Nahradit: \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Zabalit každý řádek jako řetězec JSON",
                  source: """
                    Hledat:   ^(.+)$
                    Nahradit: "$1",
                    """),
            .paragraph("""
                Skupina, která se shody **nezúčastnila**, se stane prázdným řetězcem, ne chybou — takže \
                vzor s alternativami jako `(a)|(b)` přesto čistě nahradí, aniž byste ho museli psát \
                dvakrát.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Hledat a nahradit v celé složce",
        summary: "Projděte mnoho souborů najednou a uvidíte výsledky dřív, než se cokoli zapíše.",
        keywords: ["hledat v souborech", "grep", "hromadná náhrada", "složka"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Hledat v celé složce")]),
            .paragraph("""
                Vyberte kořenovou složku, filtrujte podle vzoru názvu souboru a projděte. Výsledky se \
                objeví jako seznam seskupený podle souborů; klepnutím na řádek se ten soubor otevře na \
                daném místě.
                """),
            .bullets([
                "Stejné tři režimy hledání a stejné jádro regexů jako vyhledávací pole v dokumentu.",
                "Náhrada v celé složce **předem ukáže**, kolik souborů a kolik výskytů se změní, ještě před zápisem.",
                "Průchod běží paralelně a **lze ho v půli přerušit**.",
            ]),
            .warning("""
                Náhrada v celé složce zapisuje přímo do souborů, které **nejsou otevřené**. Ty soubory \
                nejsou v historii kroků zpět otevřeného dokumentu — nejdřív si výsledek prohlédněte a \
                mějte zálohu nebo verzovaný repozitář.
                """),
            .heading("Dřívější hledání a export výsledků"),
            .paragraph("""
                Panel výsledků **uchovává hledání tohoto sezení**. Rozbalovací nabídka nahoře v panelu \
                je vypíše s počty výskytů — vyhledejte `TODO`, přečtěte kus, vyhledejte `FIXME` pro \
                srovnání a vraťte se k prvnímu seznamu, aniž byste znovu procházeli celou složku.
                """),
            .paragraph("""
                Tlačítko **Exportovat** otevře aktuální hledání jako textovou kartu, jeden výsledek na \
                řádek ve tvaru `cesta:řádek:sloupec: text` — tvar, který používá `grep -n` a který \
                používají překladače pro chyby. Každý řádek lze vložit rovnou do vlastního pole \
                `Přejít na` tohoto produktu a vaše `grep`, `awk` a `sed` ho přečtou bez vlastního \
                parseru.
                """),
            .note("""
                Historie žije v **paměti** a nikdy se nezapisuje na disk: výsledky hledání nesou obsah \
                každého odpovídajícího řádku, což je stejná třída dat, jakou historie schránky záměrně \
                neuchovává.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Značky řádků",
        summary: "Devět barev značek a čtyři příkazy, které ze značených řádků udělají výsledek.",
        keywords: ["záložka", "značka", "f2", "filtrovat řádky"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Značkování je způsob, jak dokument filtrovat, **aniž byste ho měnili**. Označte každý \
                řádek odpovídající vzoru a pak jen ty vykopírujte — nebo ponechte jen je.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Označit každý řádek odpovídající aktuálnímu hledání"),
                HelpShortcut("⌘F2", "Nastavit / zrušit značku na aktuálním řádku"),
                HelpShortcut("F2 / ⇧F2", "Skočit na další / předchozí značku"),
            ]),
            .heading("Obvyklý postup"),
            .steps([
                "`⌘F` na vzor, podle kterého chcete filtrovat, např. `\\bERROR\\b`.",
                "`⌘M` označí každý odpovídající řádek.",
                "`Hledání ▸ Kopírovat označené řádky` je vytáhne do nové karty — nebo `Ponechat jen označené řádky` filtruje na místě.",
            ]),
            .heading("Devět barev"),
            .paragraph("""
                Řádek může nést **několik barev najednou**. Použijte různé barvy pro různá kritéria a \
                kombinujte je: červenou pro chybové řádky, žlutou pro řádky patřící k jednomu ID \
                objednávky, a pak hledejte řádky nesoucí obě.
                """),
            .bullets([
                "`Obrátit značky` — označené řádky se stanou neoznačenými a naopak.",
                "`Zrušit všechny značky` — odstraní každou značku, aniž by se dotkla obsahu.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Přejít na řádek",
        summary: "Skočte na řádek, sloupec nebo bajtovou pozici.",
        keywords: ["přejít", "číslo řádku", "cmd+l", "pozice", "sloupec"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Přejít na řádek")]),
            .paragraph("""
                Pole rozumí **třem zápisům** a rozliší je podle toho, co napíšete — není zde žádný další \
                přepínač, na který by bylo třeba klepnout.
                """),
            .table(
                headers: ["Napište", "Přejde"],
                rows: [
                    ["`120`", "na začátek řádku 120"],
                    ["`120,5` nebo `120:5`", "na řádek 120, sloupec 5 — sloupec počítá ZNAKY"],
                    ["`@1024`", "na bajtovou pozici 1024 v souboru"],
                ]
            ),
            .note("""
                `řádek:sloupec` je přesně to, jak pozici vypisují překladače a lintery, takže řádek, \
                který jste právě zkopírovali z terminálu, lze vložit rovnou sem.

                `@` pro bajtové pozice má důvod: je `1234` řádek, nebo bajt? Správná odpověď \
                neexistuje a špatný odhad pošle kurzor někam úplně jinam, aniž by to cokoli \
                signalizovalo. To bajtové číslo je také to, co ukazuje stavový řádek v poli pozice \
                (`@1024`), takže co si přečtete tam, můžete napsat sem.
                """),
            .bullets([
                "Sloupec **za délkou řádku** se zastaví na konci toho řádku; nepřeteče na následující.",
                "Bajtová pozice **za koncem souboru** vás vezme na konec — obvykle jste to číslo zkopírovali z dřívějšího běhu a soubor se mohl zmenšit.",
                "Text, který nedokáže přečíst, se **ohlásí** a kurzor zůstane na místě; neskočí na začátek souboru.",
            ]),
            .paragraph("""
                U velmi velkých souborů GEditor nečte celý soubor, aby se tam dostal — rejstřík řádků \
                se buduje postupně na pozadí.
                """),
            .note("""
                Nástroj příkazového řádku přijímá pozici také: `geditor report.csv:120:5` otevře soubor \
                s kurzorem na řádku 120, sloupci 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Soubory a sezení

    static let files = HelpChapter(
        id: "tep",
        title: "Soubory a sezení",
        summary: "Otevírání, ukládání, karty, okna, pracovní prostory a jak se sezení vrátí.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Otevírání a ukládání",
        summary: "Otevřete soubor libovolné velikosti a uložte ho s jinou znakovou sadou či koncem řádku.",
        keywords: ["otevřít", "uložit", "uložit jako", "duplikovat", "přejmenovat", "přesunout"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Nový dokument"),
                HelpShortcut("⌘O", "Otevřít soubor"),
                HelpShortcut("⌘S", "Uložit"),
                HelpShortcut("⇧⌘S", "Uložit jako"),
            ]),
            .paragraph("""
                Přetažení souboru do okna ho také otevře. `Soubor ▸ Otevřít nedávné` uchovává seznam \
                souborů, se kterými jste právě pracovali.
                """),
            .heading("Uložit jako: tři věci, které můžete změnit"),
            .table(
                headers: ["Změna", "Význam"],
                rows: [
                    ["Znaková sada", "Zapsat jako UTF-8, TCVN3, VNI-Windows… — 36 znakových sad"],
                    ["Konce řádků", "LF (Unix) · CRLF (Windows) · CR (klasický Mac)"],
                    ["Název a umístění", "Jako v každém dialogu ukládání na macOS"],
                ]
            ),
            .paragraph("""
                Stavový řádek vždy ukazuje znakovou sadu, styl konce řádku a rozpoznaný jazyk. \
                **Klepnutí na kterýkoli z nich to okamžitě změní**, bez procházení dialogem.
                """),
            .heading("Duplikovat · přejmenovat · přesunout"),
            .paragraph("""
                Tyto tři pracují se SOUBOREM, ne s jeho obsahem — a otevřená karta soubor následuje, \
                takže nikdy neztratíte své místo.
                """),
            .table(
                headers: ["Příkaz", "Co dělá"],
                rows: [
                    ["`Duplikovat soubor`",
                     "Zkopíruje ho jako `název 2.txt` vedle originálu a **otevře kopii** — protože lidé duplikují proto, aby upravovali kopii"],
                    ["`Přejmenovat soubor…`", "Přejmenuje na disku; karta následuje nový název"],
                    ["`Přesunout soubor do…`", "Přesune do jiné složky; karta jde s ním"],
                ]
            ),
            .note("""
                Všechny tři **odmítnou, když soubor toho jména už v cíli existuje**; nikdy nepřepisují. \
                A všechny tři potřebují soubor, který byl alespoň jednou uložen — dokument, který nikdy \
                nebyl na disku, nemá co duplikovat ani přesouvat.
                """),
            .heading("Bezpečný zápis"),
            .bullets([
                "Zápis je **atomický**: výpadek proudu v půli nikdy nezanechá useknutý soubor.",
                "Změní-li soubor jiný program, zatímco ho máte otevřený, GEditor si toho všimne a před přepsáním se zeptá.",
                "Soubory na iCloud Drive nebo síťovém svazku procházejí systémovým koordinátorem souborů, aby si dva stroje nešlapaly po nohou.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Karty, okna a rozdělené zobrazení",
        summary: "Mnoho karet na okno, mnoho oken a karty, které mezi nimi můžete přetahovat.",
        keywords: ["karta", "okno", "rozdělit", "panel"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Nová karta"),
                HelpShortcut("⌘W", "Zavřít kartu"),
                HelpShortcut("⇧⌘T", "Znovu otevřít naposledy zavřenou kartu"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Další / předchozí karta"),
                HelpShortcut("⌥⌘N", "Nové okno"),
                HelpShortcut("⌃⌘N", "Oddělit aktuální kartu do vlastního okna"),
            ]),
            .paragraph("""
                Kartu můžete přetáhnout do jiného okna nebo ji upustit na prázdné místo a vytvořit tak \
                nové okno. **Připnutá karta necestuje** — připnutí znamená »nech tuhle tady«.
                """),
            .note("""
                `⇧⌘T` znovu otevře naposledy zavřenou kartu, i **neuloženou**: její obsah tam pořád je.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Otevření složky jako pracovního prostoru",
        summary: "Strom souborů v postranním panelu, hledání v celém projektu a otevření jedním klepnutím.",
        keywords: ["pracovní prostor", "složka", "projekt", "postranní panel"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Otevřít složku jako pracovní prostor")]),
            .paragraph("""
                Strom se objeví v postranním panelu (`⌘0`). Klepnutím na soubor ho otevřete a `⇧⌘F` \
                prohledá celou složku.
                """),
            .note("""
                Ve verzi z App Store přístup ke složce drží **bezpečnostně vymezená záložka**, takže \
                další spuštění na ni stále dosáhne, aniž by vás žádalo o opětovný výběr složky.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "Sezení se obnoví samo",
        summary: "Ukončete a otevřete znovu: každá karta se vrátí, i ty neuložené.",
        keywords: ["sezení", "obnovení", "neuložené"],
        blocks: [
            .paragraph("""
                Není co zapínat. Ukončete GEditor a otevřete ho znovu: karty, jejich pořadí, pozice \
                kurzorů i pozice posunu se všechny vrátí.
                """),
            .heading("Co s neuloženými kartami"),
            .paragraph("""
                Jejich obsah se uchovává v samostatném snímku, takže se vrátí také. Skončí-li aplikace \
                neobvykle, další spuštění se **zeptá**, než osiřelé koncepty obnoví — místo aby tiše \
                znovu postavilo hromadu karet, které si nepamatujete.
                """),
            .warning("""
                Sezení **není záloha**. Uchovává pracovní stav, ne historii. Cokoli důležitého se musí \
                stejně uložit do souboru.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Dříve uložené verze",
        summary: "Procházejte a obnovujte starší verze souboru.",
        keywords: ["verze", "historie", "obnovit", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Při každém uložení si GEditor před přepsáním poznamená **předchozí** verzi. \
                `Makro ▸ Uložené verze…` otevře jejich prohlížeč.
                """),
            .bullets([
                "Úložiště verzí je **operačního systému**, stejný mechanismus, jaký používají vlastní aplikace Applu.",
                "Obnovení starší verze je **běžná úprava** — `⌘Z` ji vrátí.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Sledování souboru, do kterého se stále zapisuje",
        summary: "Jako `tail -f`: co se připojí na konec, objeví se, jakmile to přijde.",
        keywords: ["tail", "sledovat", "log", "reálný čas"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Soubor ▸ Sledovat soubor (tail -f)` načítá to, co se objeví na konci souboru, a \
                posouvá se s tím.
                """),
            .warning("""
                Během sledování se dokument stane **jen ke čtení**. Psát, zatímco se z disku načítá \
                nový text, znamená dva zapisovatele nad jedním dokumentem a poraženým je vždy to, co \
                jste právě napsali.
                """),
            .note("""
                Stavový řádek po celou dobu hlásí **Sleduji**, takže i o minuty později víte, proč \
                soubor nepřijímá psaní. Klepnutí na pole **jen ke čtení** řekne důvod naplno.

                Sledování patří **kartě, která ho zahájila**, ne oknu: otevřete jinou kartu a pište \
                dál a nové řádky logu stále přitékají do své vlastní karty, aniž by se dotkly souboru, \
                který upravujete.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Tisk",
        summary: "Tiskněte přes standardní tiskový dialog macOS.",
        keywords: ["tisk", "papír", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Tisknout")]),
            .paragraph("""
                Používá systémový tiskový dialog, takže export do PDF probíhá také tam — tlačítko `PDF` \
                vlevo dole.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Obrázky, PDF, soubory Office, zvuk, video a archivy",
        summary: "Osm druhů souborů se otevře uvnitř GEditoru bez jiné aplikace.",
        keywords: ["obrázek", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "archiv",
                   "zvuk", "video", "mp3", "mp4"],
        blocks: [
            .table(
                headers: ["Druh", "Co můžete dělat"],
                rows: [
                    ["Obrázky", "Prohlížet, přiblížit, otočit; **animované obrázky se přehrávají** a lze je pozastavit"],
                    ["Zvuk", "Přehrávat, převíjet, měnit hlasitost"],
                    ["Video", "Přehrávat, převíjet, celá obrazovka, obraz v obraze"],
                    ["PDF", "Číst, hledat, **komentovat**"],
                    ["Word · Excel · PowerPoint", "Prohlížet **a upravovat** — `⌘S` zapíše rovnou zpět do souboru"],
                    ["ZIP · TAR · GZ · XZ", "Vypsat položky a otevřít každou jako kartu"],
                    ["7z · RAR a sedm dalších formátů", "Totéž, přes libarchive"],
                ]
            ),
            .paragraph("""
                Otevření položky uvnitř archivu vytvoří novou kartu s obsahem té položky. Vietnamská \
                diakritika přežije v názvech i v obsahu.
                """),
            .note("""
                Upravte jeden ze tří formátů Office, stiskněte `⌘S` a zapíše se zpět do souboru — \
                LibreOffice výsledek přečte. Tato cesta je otestována od začátku do konce, ne jen \
                vyexportována do kopie.
                """),
            .heading("Zvuk a video používají přehrávače macOS"),
            .paragraph("""
                Přehrávání jde přes vlastní dekodéry systému, takže se nic navíc nestahuje a nic navíc \
                se nedodává. Na oplátku se pár formátů **nepřehraje** — `.mkv`, `.webm`, `.avi`, `.wmv` \
                — protože pro ně macOS nemá vestavěný dekodér.
                """),
            .paragraph("""
                U takového souboru GEditor **řekne proč**, místo aby ukázal černý obdélník, a nabídne \
                binární prohlížeč nebo jinou aplikaci.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "Nástroje pro PDF",
        summary: "Číst, komentovat a celá stránková vrstva: otočit · přesunout · smazat · vytáhnout · sloučit.",
        keywords: ["pdf", "stránka", "otočit", "smazat stránku", "vytáhnout", "sloučit",
                   "poznámka", "zvýraznit", "podpis"],
        blocks: [
            .paragraph("""
                Zobrazení PDF má **dvě lišty nástrojů** a odpovídají na různé otázky. Horní řada \
                pracuje s **obsahem** jedné stránky; dolní řada se **množinou stránek**.
                """),
            .heading("Horní řada — čtení a poznámky"),
            .table(
                headers: ["Tlačítko", "Co dělá"],
                rows: [
                    ["Zvýraznit · Podtrhnout", "Označí vybraný text"],
                    ["Poznámka…", "Připojí poznámku ke stránce"],
                    ["Odstranit poznámky", "Odstraní každou poznámku z aktuální stránky"],
                    ["Vytáhnout text do nové karty", "Přesune celý text do karty, abyste mohli hledat, filtrovat a používat další nástroje"],
                    ["Vyhledávací pole", "Hledá uvnitř PDF — **psaní bez diakritiky přesto najde text s ní**"],
                ]
            ),
            .note("""
                Naskenované PDF nemá textovou vrstvu. Příkaz pro vytažení to **řekne**, místo aby \
                otevřel prázdnou kartu a nechal vás hádat.
                """),
            .heading("Dolní řada — operace se stránkami"),
            .table(
                headers: ["Tlačítko", "Co dělá", "Lze vrátit"],
                rows: [
                    ["Otočit vlevo · vpravo", "Otočí aktuální stránku o 90°", "Ano"],
                    ["Stránka nahoru · dolů", "Prohodí aktuální stránku se sousední", "Ano"],
                    ["Smazat stránky…", "Smaže podle rozsahu, např. `2-4,7`", "Ano"],
                    ["Vytáhnout stránky…", "Zapíše rozsah stránek jako **nový soubor**", "Otevřeného souboru se nedotkne"],
                    ["Sloučit PDF…", "Vloží jiné PDF hned za aktuální stránku", "Ano"],
                    ["Podepsat…", "Umístí obrázek podpisu na aktuální stránku", "Ano"],
                    ["Upravit text…", "Nakreslí náhradní text přes výběr", "Ano"],
                    ["Další prázdné pole", "Skočí na další nevyplněné pole formuláře", "—"],
                    ["Vymazat vyplněné hodnoty", "Vyprázdní každé pole formuláře", "Ano"],
                    ["Vrátit změnu stránky", "Krok zpět o jednu operaci se stránkou", "—"],
                    ["Uložit upravenou kopii…", "Zapíše nový soubor a pak ho **znovu otevře pro ověření**", "—"],
                ]
            ),
            .heading("Vyplnitelné formuláře"),
            .paragraph("""
                Otevřete PDF s poli formuláře a stavový řádek uvede, **kolik** jich je. Pište přímo do \
                polí na stránce a pak použijte `Uložit upravenou kopii…`.
                """),
            .bullets([
                "Hodnoty se ukládají jako **živá pole formuláře**, ne jako zploštělý text — takže Acrobat příjemce stále vidí vyplněný formulář a může ho opravit.",
                "Vietnamská diakritika přežije okruh zápis-a-otevření. Test hlídá právě to, se jménem `Nguyễn Văn Anh`.",
                "`Další prázdné pole` skočí na další prázdné — přirozená cesta dlouhým formulářem.",
            ]),
            .heading("Podepisování"),
            .paragraph("""
                Připravte si obrázek podpisu (PNG s průhledným pozadím funguje nejlépe), **vyberte \
                místo k podpisu** — obvykle vytečkovanou linku nebo slovo »Podpis« — a pak stiskněte \
                `Podepsat…`. Bez výběru podpis přistane vpravo dole.
                """),
            .note("""
                Podpis zachovává **poměr stran** obrázku: zmáčknutý nebo natažený podpis vypadá ihned \
                falešně.
                """),
            .heading("Úprava textu — a tři věci, které je třeba vědět předem"),
            .paragraph("""
                Vyberte text ke změně a stiskněte `Upravit text…`. GEditor **překryje tu oblast barvou \
                pozadí odebranou hned vedle** a pak na ni nakreslí nový text.
                """),
            .warning("""
                **Starý text je PŘEKRYTÝ, ne ODSTRANĚNÝ.** Stále je v souboru a stále ho lze vytáhnout \
                příkazem `Vytáhnout text do nové karty` nebo jakýmkoli jiným nástrojem. Tohle **není \
                začernění**: skrýt takto rodné číslo ho skryje lidskému oku, ne stroji.
                """),
            .bullets([
                "**Nový text lze stále najít pomocí `⌘F`.** Kreslí se jako skutečný text, ne jako obrázek — změřeno testem, ne předpokládáno.",
                "**Písmo je systémové**, ne původní písmo dokumentu. Záměrně: písma vložená v PDF často postrádají vietnamskou diakritiku a `Nguyễn` by dorazilo jako `Nguy?n`.",
                "**Na vzorovaném pozadí je záplata vidět** — barva překrytí se odebírá z jediného místa hned vlevo od výběru.",
            ]),
            .heading("Proč kreslit přes, místo upravovat proud obsahu"),
            .paragraph("""
                Upravovat proud obsahu PDF přímo znamená vypořádat se s podmnožinovými písmy s vlastním \
                kódováním, s větami rozlámanými prostrkáním do tří kousků a s tabulkami šířek znaků, \
                které je nutné přepočítat. Udělat to správně pro **každý** soubor je projekt sám o \
                sobě; udělat to špatně poškodí něčí dokument.
                """),
            .paragraph("""
                Na oplátku se zbytek stránky **nezmění ani o jediný bajt** a stránka zůstane stránkou — \
                text se stále vybírá, kopíruje a hledá. Překreslení z ní **neudělá** obrázek.
                """),
            .heading("Syntaxe rozsahu stránek"),
            .table(
                headers: ["Napište", "Význam"],
                rows: [
                    ["`5`", "Jen stránka 5"],
                    ["`2-4`", "Stránky 2, 3, 4"],
                    ["`-3`", "Od začátku po stránku 3"],
                    ["`8-`", "Od stránky 8 do konce"],
                    ["`1-3,5,9-`", "Několik částí spojených čárkami"],
                ]
            ),
            .paragraph("Stránky se počítají **od 1**, tedy číslem, které vidíte na obrazovce."),
            .warning("""
                Obrácený rozsah (`5-2`) i rozsah za koncem (`1-999`) se oba **odmítnou s důvodem**, \
                nikdy tiše neopraví na něco blízkého. U příkazu mazání stránek znamená špatný odhad \
                ztracené stránky a tiché oříznutí promění překlep v platný příkaz.
                """),
            .heading("Původní soubor se nikdy nepřepisuje"),
            .paragraph("""
                Vše výše mění dokument **v paměti**. Teprve když stisknete `Uložit upravenou kopii…` a \
                zvolíte umístění, zapíše se soubor — a po zápisu GEditor **ten soubor znovu otevře**, \
                aby potvrdil, že má stále všechny své stránky.
                """),
            .paragraph("""
                Důvod: špatně zapsaný soubor leží na disku a vypadá naprosto normálně, a uživatel to \
                zjistí až poté, co ho odešle.
                """),
            .note("""
                Stavový řádek zobrazení hlásí **· upraveno, neuloženo**, kdykoli se dokument liší od \
                souboru na disku.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
