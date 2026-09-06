import Foundation

/// Česká nápověda — část 3: zobrazení, vietnamština a jazyky s formáty.
extension HelpCS {

    static let views = HelpChapter(
        id: "xem",
        title: "Způsoby zobrazení dokumentu",
        summary: "Postranní panel, mapa, skládání, rozdělené zobrazení, zalamování, neviditelné znaky, režimy obarvení.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Postranní panel a seznam funkcí",
        summary: "Strom složek a seznam funkcí otevřeného souboru v jednom sloupci.",
        keywords: ["postranní panel", "seznam funkcí", "osnova", "strom souborů"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Zobrazit / skrýt postranní panel")]),
            .paragraph("""
                Seznam funkcí se staví ze **syntaktického stromu** jazyka, takže sleduje skutečnou \
                strukturu, místo aby hádal z odsazení. Klepnutím na položku tam skočíte.
                """),
            .note("Filtrovací pole v seznamu funkcí **najde text s diakritikou z psaní bez ní**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Mapa dokumentu",
        summary: "Celý soubor v úzkém sloupci vpravo — i při stovkách MB.",
        keywords: ["minimapa", "mapa", "přehled"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Zobrazit / skrýt mapu dokumentu")]),
            .paragraph("""
                Mapa popisuje **celý soubor**, ne jen to, co je na obrazovce. Tažením po ní skočíte na \
                odpovídající místo.
                """),
            .paragraph("""
                Nalezené výskyty a označené řádky se na mapě objeví, takže vidíte, zda jsou rozptýlené, \
                nebo shluknuté, ještě než tam odrolujete.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Skládání",
        summary: "Složte funkce, bloky a pole podle struktury — nebo složte soubor na úroveň.",
        keywords: ["složit", "skládání kódu", "sbalit"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Složit / rozložit blok u kurzoru"),
                HelpShortcut("⌥⇧⌘←", "Složit vše"),
                HelpShortcut("⌥⌘→", "Rozložit vše"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Složit celý soubor na úroveň 1…8"),
            ]),
            .paragraph("""
                U jazyků se syntaktickým stromem skládání sleduje **skutečnou strukturu**. U souborů \
                bez gramatiky sleduje odsazení.
                """),
            .paragraph("""
                `Složit na úroveň` se vyplatí u hlubokého JSONu a YAMLu: složení na úroveň 2 dostane \
                tvar celého souboru na jednu obrazovku.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Rozdělené zobrazení",
        summary: "Dva panely vedle sebe, pro dva soubory — nebo dvě místa v jednom souboru.",
        keywords: ["rozdělit", "panely", "porovnat"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Rozdělit svisle"),
                HelpShortcut("⌥⌘-", "Rozdělit vodorovně"),
                HelpShortcut("⌥⌘0", "Zrušit rozdělení"),
                HelpShortcut("⌥⌘]", "Otevřít tuto kartu v druhém panelu"),
                HelpShortcut("⌥⌘[", "Skočit do druhého panelu"),
            ]),
            .paragraph("""
                Každý panel má vlastní lištu karet. Otevřít **stejný soubor** v obou panelech je v \
                pořádku — posouvají se nezávisle, což usnadňuje porovnání začátku a konce souboru.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Zalamování řádků",
        summary: "Tři režimy: vypnuto, na okraji okna nebo na pevném sloupci.",
        keywords: ["zalamování", "měkké zalomení"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Režim", "Dlouhý řádek"],
                rows: [
                    ["Vypnuto", "Posouvá se vodorovně"],
                    ["Na okně", "Zalomí se na okraji okna a sleduje jeho velikost"],
                    ["Na sloupci", "Zalomí se na sloupci, který nastavíte — třeba 80 nebo 100"],
                ]
            ),
            .paragraph("""
                Zalamování je **způsob pohledu**, ne úprava: nevkládá se žádný konec řádku a nikdy se \
                nedostane do historie kroků zpět.
                """),
            .note("Rychlá cesta sem je pole `Zalomení: …` ve stavovém řádku."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Velikost písma",
        summary: "Přiblížení mezi 8 a 32 body.",
        keywords: ["přiblížení", "velikost písma", "větší", "menší"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Větší text"),
                HelpShortcut("⌘-", "Menší text"),
                HelpShortcut("⌃⌘0", "Zpět na výchozí velikost"),
            ]),
            .paragraph("""
                Omezeno mezi 8 a 32 body. I tohle je **způsob pohledu**: žádná úprava, nic v historii \
                kroků zpět. Výchozí velikost je v `Nastavení…`.
                """),
            .note("`⌘0` NENÍ výchozí velikost — ta klávesa zobrazuje a skrývá postranní panel."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Zobrazení neviditelných znaků",
        summary: "Zapínejte po jedné skupině, protože všechny naráz je obvykle příliš.",
        keywords: ["neviditelný", "bílé znaky", "nbsp", "nulová šířka", "tabulátor"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Zobrazit / skrýt všechny neviditelné znaky")]),
            .paragraph("""
                Čtyři skupiny se zapínají zvlášť, protože zapnout je všechny naráz pohřbí obsah pod \
                lesem teček.
                """),
            .table(
                headers: ["Skupina", "Co odhalí"],
                rows: [
                    ["Mezery", "Mezery na konci řádku, nejednotné odsazení"],
                    ["Tabulátory", "Soubory míchající TABy s mezerami"],
                    ["Konce řádků", "Soubory míchající CRLF s LF"],
                    ["NBSP · nulová šířka · řídicí", "Neviditelné znaky z Wordu, z webu, z tabulkových procesorů"],
                ]
            ),
            .warning("""
                Poslední skupina je ta, která lidi zachraňuje. Nezlomitelná mezera (NBSP) vložená z \
                webové stránky vypadá **přesně** jako obyčejná mezera, ale kvůli ní každé porovnání \
                řetězců i každý filtr mine — a bez zapnutí této skupiny ji nelze nijak spatřit.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "Režim CSV a režim logu",
        summary: "Dvě schémata obarvení, která nahrazují zvýrazňování syntaxe, pro dva druhy datových souborů.",
        keywords: ["režim csv", "režim logu", "zvýraznění", "sloupce", "úroveň logu"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("Režim CSV"),
            .paragraph("""
                Dá každému sloupci vlastní barvu v **textovém** zobrazení, takže vidíte, která buňka \
                sklouzla o sloupec, aniž byste přepínali do tabulky.
                """),
            .heading("Režim logu"),
            .paragraph("""
                Obarvuje podle **závažnosti**, kterou z řádku vyčte: chyby červeně, varování \
                oranžově, zatímco `debug` a `trace` ztlumí — tvoří většinu logu a jejich zvýraznění \
                ztlumí právě to, co hledáte.
                """),
            .paragraph("`Filtrovat log podle úrovně…` skryje úrovně, které vůbec nepotřebujete."),
            .note("""
                Tyto dva obarvují **místo** zvýrazňování syntaxe, ne přes ně. Log nemá syntaxi, kterou \
                by šlo obarvit, a dva zdroje barev zapisující do stejného rozsahu bajtů nezanechají \
                předvídatelného vítěze.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Binární zobrazení",
        summary: "Šestnáctková tabulka pro libovolný soubor — i pro 1GB, otevře se téměř okamžitě.",
        keywords: ["hex", "binární", "bajt", "posun", "výpis"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Zobrazit ▸ Binární zobrazení` ukáže každý bajt jako tabulku o třech sloupcích: **posun \
                · hex · text**. Funguje pro **libovolný** soubor na disku, ne jen pro obrázky či video.
                """),
            .table(
                headers: ["Sloupec", "Obsah"],
                rows: [
                    ["Posun", "Bajtová pozice, šestnáctkově"],
                    ["Hex", "16 bajtů na řádek, rozděleno po osmém pro snazší počítání"],
                    ["Text", "Tisknutelné bajty ASCII; vše ostatní je `.`"],
                ]
            ),
            .note("""
                Textový sloupec **nedekóduje UTF-8**. Vietnamské písmeno zabere dva nebo tři bajty, \
                takže jeho vykreslení by textový sloupec rozhodilo vůči šestnáctkovému — a právě to \
                zarovnání je celý smysl toho sloupce. Ke čtení textu s diakritikou použijte běžné \
                zobrazení.
                """),
            .heading("Velké soubory"),
            .paragraph("""
                Soubor je **namapován do paměti**, takže otevření 1GB souboru v binárním zobrazení \
                stojí jen to, na co se díváte. Změřeno v sadě autotestů: **pod jednu milisekundu**.
                """),
            .paragraph("""
                Zobrazení ukazuje **jedno okno o 4 MB** naráz a horní lišta uvádí, ve kterém rozsahu \
                jste. To je omezení systémového vykreslovače tabulek, ne čtení: 1GB soubor má 62,5 \
                milionu řádků a od jistého bodu začnou řádky při posunu poskakovat — a poskakující \
                šestnáctková tabulka je k ničemu.
                """),
            .heading("Skok na pozici"),
            .table(
                headers: ["Napište do pole posunu", "Význam"],
                rows: [
                    ["`1F400`", "Šestnáctkově — výchozí"],
                    ["`0x1F400`", "Totéž s výslovnou předponou"],
                    ["`#128000`", "Desítkově, když máte počet bajtů, a ne šestnáctkový posun"],
                ]
            ),
            .bullets([
                "`‹` a `›` přejdou na předchozí / další okno.",
                "**Kopírovat vybrané řádky** zkopíruje přesně to, co vidíte — bez výběru zkopíruje celé okno.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Náhled Markdownu",
        summary: "Vykreslí Markdown jako formátovaný text — a naplno řekne, co nevykreslí.",
        keywords: ["markdown", "náhled", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("""
                Vykresleno systémovou podporou Markdownu: tučné, kurzíva, kód, odkazy, seznamy.
                """),
            .warning("""
                **Žádné tabulky a žádné obarvení syntaxe uvnitř bloků kódu.** Okno náhledu to říká \
                dole. Dokumenty větší než **4 MB** se odmítají.
                """),
            .paragraph("""
                Potřebujete tabulky a grafy v dokumentu, který lze vydat? K tomu slouží zprávy \
                `.greport.md`, ne tento náhled.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Dva režimy: View a Code",
        summary: "Jedna klávesa přepíná mezi vykreslenou podobou a upravitelným zdrojem, pro každý typ souboru.",
        keywords: ["view", "code", "režim", "zdroj", "vykreslené", "náhled"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Přepnout mezi View a Code")]),
            .paragraph("""
                Ovládání sedí v **liště hned pod pruhem karet** — na stejném místě pro každý typ \
                souboru: přepínač `View | Code` a pak název režimu View toho souboru (»Stránky \
                dokumentu«, »Strom klíč–hodnota«, »Diagram«…). Soubor s jediným režimem přepínač \
                zešedne a lišta řekne proč. U pravého okraje sedí vlastní tlačítka každého typu: \
                `.xlsx` má **Tabulku** (upravitelnou, zapisuje se rovnou zpět), `.pptx` má **Osnovu**.
                """),
            .note("""
                **Word a PowerPoint se chovají jako čtečka dokumentů.** Jejich režim View staví \
                skutečné stránky — správná písma, velikosti a barvy, s obrázky, tabulkami, záhlavími a \
                zápatími včetně čísel stránek. Stránka je **přesně tak široká jako rám** a lze ji \
                přiblížit. Excel je záměrná výjimka: jeho View je **upravitelný tabulkový list**, \
                protože tabulkový list nemá velikost papíru, dokud se nevytiskne.
                """),
            .note("""
                Na oplátku jsou stránky **jen ke čtení** a vykreslují **kopii na disku**: upravte v \
                Code bez uložení a stránky ukáží starou verzi — lišta to říká, s tlačítkem `Uložit a \
                vykreslit znovu`.
                """),
            .heading("Definice"),
            .bullets([
                "**Code** je **upravitelný zdroj**. U textového souboru je to samotný text. U binárního souboru — PDF, obrázek, zvuk, video — textový zdroj neexistuje, takže Code jsou **bajty**, zobrazené šestnáctkově.",
                "**View** je to, co se z Code **vykreslí**. Může to být hezčí, kratší nebo spustitelné — ale je to vždy důsledek, nikdy originál.",
            ]),
            .paragraph("""
                Říct o PDF *»tento typ nemá Code«* by bylo pohodlné, ale nesprávné: ty bajty jsou \
                skutečně jeho zdrojem.
                """),
            .heading("Kde probíhá úprava"),
            .paragraph("""
                Úprava probíhá v **Code**. Existují přesně **dvě výjimky**, obě proto, že upravovat ve \
                View je mnohem přirozenější: **buňky tabulky CSV** a **pole formulářů PDF**. Obě \
                zapisují rovnou do zdroje, takže se neobjeví druhá kopie, se kterou by šlo se přít.
                """),
            .heading("Podle typu souboru"),
            .table(
                headers: ["Typ souboru", "View", "Code", "Upravovat v"],
                rows: [
                    ["CSV · TSV", "Tabulka", "Holý text", "**Obojí**"],
                    ["Excel `.xlsx`", "Tabulka otevřeného listu", "Ten list jako CSV", "**Obojí**"],
                    ["PDF", "Vykreslené stránky", "Binárně", "**Obojí** — poznámky, pole formulářů, stránky"],
                    ["Markdown `.md`", "Vykreslený text", "Zdroj Markdownu", "Code"],
                    ["Zpráva `.greport.md`", "Zpráva se spuštěnými dotazy a nakreslenými grafy", "Zdroj", "Code"],
                    ["JSON", "Strom klíč–hodnota, skládatelný", "Zdroj JSON", "Code"],
                    ["XML · HTML", "Strom značek, skládatelný", "Zdroj XML", "Code"],
                    ["YAML", "Strom klíč–hodnota podle odsazení", "Zdroj YAML", "Code"],
                    ["Diagramy `.mmd` · `.dot`", "Nakreslený diagram přes celou kartu", "Zdroj mermaid nebo DOT", "Code"],
                    ["Word `.docx`", "Vykreslené stránky dokumentu", "Vytažený Markdown", "Code"],
                    ["PowerPoint `.pptx`", "Vykreslené stránky snímků", "Osnova v Markdownu", "Code"],
                    ["Soubory logu", "Obarvené podle úrovně, filtrovatelné", "Holý text", "Code"],
                    ["Obrázky", "Obrázek (animované se přehrávají)", "Binárně", "Jen ke čtení"],
                    ["Zvuk · video", "Přehrávač", "Binárně", "Jen ke čtení"],
                    ["Archivy", "Seznam položek", "Binárně", "Jen ke čtení"],
                    ["Zdrojový kód, prostý text", "— žádné", "Samotný text", "Code"],
                ]
            ),
            .note("""
                Zdrojový kód **nemá View**, a to je normální, ne mezera: soubor ve Swiftu nemá \
                vykreslenou podobu, na kterou by stálo za to se dívat.
                """),
            .heading("Čtečka stránek pro Word a PowerPoint"),
            .paragraph("""
                Stránky se skládají svisle a posouvají se plynule, každá jako bílý list na šedém pozadí \
                — jako v každé čtečce dokumentů. Její ovládání sedí vpravo v liště.
                """),
            .table(
                headers: ["Tlačítko / klávesa", "Co dělá"],
                rows: [
                    ["`Přizpůsobit šířce`", "List je přesně tak široký jako rám — výchozí"],
                    ["`Přizpůsobit stránku`", "Celý list se vejde do rámu"],
                    ["`−` `+`", "Přiblížení po krocích; nebo štípnutí, nebo ⌘ + posun"],
                    ["Pole `Hledat`, nebo ⌘F", "Hledá uvnitř stránek, skočí tam a zvýrazní"],
                    ["Enter v poli hledání", "Další výskyt"],
                    ["Tažení", "Vybrat text; dvojklik na slovo, trojklik na odstavec"],
                    ["⌘A · ⌘C", "Vybrat vše · kopírovat výběr"],
                    ["Page Up · Page Down · Home · End", "Pohyb dokumentem"],
                ]
            ),
            .paragraph("""
                Pole hledání **nedbá na diakritiku ani velikost písmen**: napsání `vuong quoc` najde \
                `Vương quốc`. Popisek »Stránka 12/363« v liště říká, kde jste.
                """),
            .note("""
                **Co se nevykresluje, řečeno naplno:** plovoucí ukotvené obrázky (text obtékající \
                obrázek) se objeví jako obrázky v řádku; poznámky pod čarou, grafy a SmartArt z \
                PowerPointu se nekreslí. Když potřebujete přesnou shodu s tištěnou verzí, otevřete to \
                ve Wordu.
                """),
            .heading("Klepnutí na uzel skočí zpět do zdroje"),
            .paragraph("""
                Strom JSON není pěkný výpis: klepnutí na uzel přesune kurzor **na HODNOTU toho uzlu** v \
                textu a vrátí kartu do Code — protože to, co chcete dál, je téměř vždy upravit to, na \
                co jste právě klepli.
                """),
            .bullets([
                "Uzly kontejnerů ukazují svůj **počet prvků** (`{12}`, `[340]`) místo obsahu — právě to odpovídá na otázku »stojí za to tohle otevřít«.",
                "**První dvě úrovně** jsou rozbalené: rozbalit soubor s deseti tisíci uzly celý dá seznam delší než zdroj, kdežto zabalit ho celý znamená, že bez klepání nic neobjevíte.",
                "Soubor s **neplatnou syntaxí** nedostane půl stromu — useknutý strom vypadá jako dokument, který prostě tak málo obsahuje.",
                "Ve stromu XML nesou atributy předponu `@` v řádném zápisu XPath a **bílé znaky mezi značkami se uzlem nestanou** — je to formátování, ne obsah.",
                "Strom YAML čte **vícedokumentové soubory** (`---`): každý dokument je vlastní kořen. Kolekce zapsané v řádku (`ports: [80, 443]`) zůstávají jediným listem — už vidíte všechno a rozbalení by stálo klepnutí. **Odsazení tabulátory** se ohlásí i s přesným řádkem: to je chyba YAMLu, kterou oko nevidí.",
                "Osnova PowerPointu se staví z **otevřeného textu**, ne ze souboru na disku: pokud jste právě upravili osnovu v Code, strom musí popisovat novou verzi a jeho uzly do té nové verze skákat. Poznámky přednášejícího se sbalí do jednoho uzlu, aby snímek, který hodně říká, nevypadal jako snímek, který hodně obsahuje.",
                "**Diagram přes celou kartu se řídí stejným pravidlem**: klepněte na uzel a jste zpět v Code s kurzorem na deklaraci toho uzlu. V panelu `Mermaid Studio` vedle sebe se karta nezavře — editor je hned tam a stačí pohnout kurzorem, aby to bylo vidět.",
                "Diagramy se také **otevírají tam, kde stojíte**: prvek odpovídající řádku kurzoru se zvýrazní v okamžiku, kdy se karta objeví, takže ho nemusíte hledat.",
            ]),
            .heading("Filtrovací pole: ve stromu s deseti tisíci uzly je hledání ta práce"),
            .paragraph("""
                Hned pod počtem uzlů sedí filtrovací pole. Napište do něj a strom ponechá jen \
                odpovídající uzly — **spolu s cestou od kořene až k nim**, protože když se klíč `name` \
                objeví na deseti různých místech, skutečná otázka zní »který«, a odpoví na ni jen \
                větev, která ho obsahuje. Zbytek se rozbalí za vás: nutit vás rozklepávat každou úroveň \
                by znamenalo nutit vás filtrovat znovu ručně.
                """),
            .bullets([
                "Filtruje **popisky i hodnoty**: hledat `Huế` je stejně běžné jako hledat klíč `province`.",
                "**Psaní bez diakritiky přesto odpovídá textu s ní** — `da nang` najde `Đà Nẵng`. Stejné porovnání jako filtr tabulky CSV a jako seznam funkcí, abyste si v jedné aplikaci nemuseli pamatovat tři pravidla hledání.",
                "Bez shody hlavička hlásí **»Žádné výsledky«**, místo aby vás nechala zírat na prázdný strom s otázkou, zda je soubor rozbitý.",
                "Přepnutí souboru nebo opětovný vstup do View **vymaže filtr**: strom, který se otevře už useknutý a nic to nevysvětluje, je nejmatoucnější stav ze všech.",
            ]),
            .heading("Celý strom funguje z klávesnice"),
            .paragraph("""
                Vstup do View přesune zaměření na strom; nemusíte na něj nejdřív klepnout. Nahoru a \
                dolů se pohybují mezi uzly, vlevo a vpravo skládají a rozkládají a dvě klávesy \
                prohlížení ukončí — a dělají **různé** věci:
                """),
            .bullets([
                "**Enter** — jít na vybraný uzel: zpět do Code s kurzorem uvnitř bajtového rozsahu toho uzlu. Přesně jako klepnutí na něj.",
                "**Tab** — přepínat mezi stromem a filtrovacím polem.",
                "**⌘C** — zkopíruje **cestu** vybraného uzlu, ne text za stromem. JSON a YAML dají JSONPath (`$.customer['name']`), který lze vložit rovnou do vlastního pole JSONPath tohoto produktu nebo do `yq`; XML dá XPath (`/order/item[2]/@code`) s indexy, když dvě značky sdílejí název; osnova PowerPointu zkopíruje text řádku, protože osnova nemá jazyk cest, který by šlo vymyslet.",
                "**Esc** — cesta zpět: návrat do Code s kurzorem **přesně tam, kde byl**. Dívali jste se na strom, nikam jste necestovali.",
            ]),
            .heading("A opačným směrem: strom se otevře tam, kde stojí kurzor"),
            .paragraph("""
                Vstup do View z prostředku souboru o deseti tisících řádcích **neotevře** strom nahoře: \
                rozbalí cestu dolů k uzlu odpovídajícímu tomu, kde byl kurzor, a vybere ho. To je druhá \
                polovina skoku-do-zdroje — bez ní by View a Code byly dvěma pohledy na jeden dokument \
                jen **jedním** směrem.
                """),
            .bullets([
                "Když je třeba, rozbalí **hlouběji než dvě úrovně**: pravidlo dvou úrovní odpovídá na »jak tenhle soubor vypadá«, kdežto zde je otázka jiná — »kde v tomhle stromu jsem«.",
                "Kurzor na **klíči** (`\"address\":`) vybere tu položku, ačkoli bajtový rozsah uzlu pokrývá jen hodnotu. Text bezprostředně před uzlem patří tomu uzlu.",
                "Kurzor na **začátku bloku** — klíč bloku YAML, název snímku, jméno značky XML — vybere ten blok, místo aby se nořil k jeho prvnímu potomkovi.",
                "Vstup do View **kurzorem nehýbe**. Opusťte View a jste přesně tam, kde jste byli; View je způsob pohledu, ne příkaz měnící polohu.",
            ]),
            .heading("Žádnému typu už View nechybí"),
            .paragraph("""
                **Každý typ souboru, kde má režim View smysl, ho teď vykresluje.** Seznam chybějících \
                typů se vyprázdnil a byl odstraněn.

                Zdrojový kód a prostý text stále View nemají — to je normální, ne mezera, takže na tom \
                seznamu nikdy nebyly.

                Přijde-li nový typ souboru, jehož View ještě není postaveno, přepínací příkaz to řekne \
                a pojmenuje, co chybí, místo aby otevřel prázdný rám — prázdný rám je prázdný slib, \
                kdežto odmítnutí se jménem je informace.
                """),
            .heading("Šest starších příkazů tu stále je"),
            .paragraph("""
                `Zobrazení tabulky/textu`, `Náhled Markdownu`, `Binární zobrazení`, `Náhled zprávy`, \
                `Náhled diagramu Mermaid`, `Režim logu` — všechny zůstávají přesně tam, kde byly. \
                `⌥⌘V` je **společný vchod**, ne náhrada.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamština

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamština",
        summary: "Staré znakové sady, normalizace Unicode, hledání bez ohledu na diakritiku a metody vstupu.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnamské znakové sady",
        summary: "Čtěte a zapisujte TCVN3, VISCII, VNI-Windows a 33 dalších, rozpoznané samy.",
        keywords: ["znaková sada", "tcvn3", "abc", "viscii", "vni", "mojibake"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Otevřeli jste starý vietnamský soubor a dostali `Tr¦êng §¹i häc` místo `Trường Đại \
                học`? Soubor není poškozený — byl uložen ve znakové sadě z doby před Unicode.
                """),
            .steps([
                "Klepněte na znakovou sadu ve **stavovém řádku** (nebo `Formát ▸ Znaková sada…`).",
                "Zvolte tu správnou — u starých vietnamských souborů je to obvykle `TCVN3 (ABC)`, `VNI-Windows` nebo `VISCII`.",
                "Text se opraví okamžitě; soubor není třeba otevírat znovu.",
                "Chcete-li to tak ponechat, `Uložit jako…` se znakovou sadou `UTF-8`.",
            ]),
            .heading("Tři staré vietnamské znakové sady"),
            .table(
                headers: ["Znaková sada", "Obvykle se najde"],
                rows: [
                    ["TCVN3 (ABC)", "V úředních dokumentech a starších dokumentech Wordu na severu"],
                    ["VNI-Windows", "V nakladatelstvích, novinách a tiskárnách — běžná na jihu"],
                    ["VISCII", "V rané elektronické poště a na Usenetu"],
                ]
            ),
            .paragraph("""
                GEditor **znakovou sadu rozpozná** při otevření. Když se splete, jedno klepnutí to \
                opraví a obsah se dekóduje znovu, místo aby se opravoval písmeno po písmenu.
                """),
            .warning("""
                Zápis do staré znakové sady ztratí znaky, které ta sada nemá. GEditor je **spočítá a \
                řekne to předem** — například *»12 znaků není v TCVN3«* — místo aby je tiše proměnil v \
                otazníky.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Konce řádků",
        summary: "LF, CRLF, CR — převedené pro celý soubor jedním klepnutím.",
        keywords: ["eol", "crlf", "lf", "konec řádku", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Styl", "Používá", "Bajty"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac před rokem 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Aktuální styl ukazuje stavový řádek; klepnutím ho změníte. Soubor, který dva styly \
                **míchá**, se tam ohlásí také — zapněte `Zobrazit neviditelné ▸ Konce řádků`, abyste \
                viděli přesně kde.
                """),
            .note("Styl konce řádku pro **nové** soubory se nastavuje v `Nastavení…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Normalizace Unicode",
        summary: "Proč hledání «ế» někdy nic nenajde a jak opravit celý soubor.",
        keywords: ["unicode", "nfc", "nfd", "složené", "rozložené", "normalizovat", "žádné výsledky"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                V Unicode lze `ế` zapsat **dvěma různými způsoby**: jako jeden předsložený kódový bod \
                (NFC), nebo jako `e` plus dvě samostatné značky (NFD). Na obrazovce vypadají shodně; \
                pro stroj jsou to různé řetězce.
                """),
            .paragraph("""
                Důsledek: hledání `ế` v souboru NFD **nenajde nic** a uživatel usoudí, že data tam \
                nejsou.
                """),
            .steps([
                "`Formát ▸ Normalizovat Unicode…`",
                "Zvolte **NFC** (předsložené) — tvar, který používá téměř všechno ostatní.",
                "Použijte. Je to jediný krok zpět.",
            ]),
            .note("""
                Soubory pocházející z macOS jsou často NFD, protože souborový systém Applu takto ukládá \
                názvy souborů. To je zdaleka nejčastější důvod, proč data zkopírovaná z Finderu už \
                nejdou najít.
                """),
            .paragraph("""
                V `Nastavení…` je přepínač **normalizovat na NFC při ukládání**. Ve výchozím stavu \
                vypnutý, protože mění bajty souboru.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Psaní bez diakritiky přesto najde text s ní",
        summary: "Každé vyhledávací a filtrovací pole porovnává s odstraněnou diakritikou.",
        keywords: ["diakritika", "hledání", "filtr", "bez diakritiky"],
        blocks: [
            .paragraph("""
                Napište `hue` a najdete `Huế`. Napište `da nang` a najdete `Đà Nẵng`. Pravidlo platí \
                pro filtr tabulky CSV, hledání funkcí, hledání v nápovědě i pro ostatní filtrovací \
                pole.
                """),
            .note("""
                `Đ` se zpracovává zvlášť, protože v Unicode je to **samostatné písmeno**, ne `D` s \
                nesenou značkou — běžné odstranění diakritiky se ho nedotkne.
                """),
            .paragraph("""
                Filtr CSV přijímá i předponu `=` pro přesné porovnání. Tvar s `=` je **rovněž bez \
                ohledu na diakritiku**, protože filtr, který diakritiku rozlišuje, nechá uživatele v \
                domnění, že data chybí.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnamské metody vstupu",
        summary: "EVKey, OpenKey, Unikey i vlastní zdroj vstupu macOS píší rovnou do dokumentu.",
        keywords: ["ime", "evkey", "unikey", "openkey", "telex", "vni", "metoda vstupu"],
        blocks: [
            .paragraph("""
                Není co nastavovat. Telex i VNI fungují, včetně napříč **více kurzory** — napište \
                jednou a každý kurzor dostane správně opatřené písmeno.
                """),
            .paragraph("""
                Vyhledávací pole, filtrovací pole i každý dialog přijímají metodu vstupu stejně jako \
                editor.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Jazyky a formáty

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Jazyky a formáty",
        summary: "Dvacet vestavěných jazyků, vlastní jazyky a nástroje pro JSON · XML · YAML · logy.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Dvacet vestavěných jazyků",
        summary: "Obarvení ze skutečného syntaktického stromu, se značkami komentářů každého jazyka.",
        keywords: ["syntaxe", "zvýraznění", "jazyk", "tree-sitter", "gramatika"],
        blocks: [
            .paragraph("""
                Jazyk se rozpozná z **přípony souboru** (plus několik zvláštních názvů jako `Makefile`, \
                `Dockerfile`, `Gemfile`). Ručně ho můžete změnit ve stavovém řádku.
                """),
            .table(
                headers: ["Jazyk", "Přípony", "Řádkový · blokový komentář"],
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
                Poslední sloupec je to, co používá `⌘/`. Jazyky bez řádkového komentáře (JSON, CSS, \
                XML) dostanou místo něj blokovou podobu.
                """),
            .heading("Co přichází se syntaktickým stromem"),
            .bullets([
                "**Seznam funkcí** v postranním panelu sleduje skutečnou strukturu, ne odhady z odsazení.",
                "**Skládání** podle struktury.",
                "**Párování závorek**, které přeskakuje závorky uvnitř řetězců a komentářů.",
                "**Automatické odsazení** přidávající úroveň po `{` a po `:` v Pythonu a YAMLu.",
            ]),
            .note("""
                Tři těžké gramatiky (C++, C#, Ruby) žijí v **líně načítané** knihovně — načtou se, jen \
                když otevřete soubor v jednom z těch jazyků. Tak zůstává doba spuštění pod půl \
                sekundou.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Vlastní jazyky",
        summary: "Obarvěte svůj formát jediným souborem JSON — žádnou gramatiku psát nemusíte.",
        keywords: ["udl", "vlastní jazyk", "vlastní log"],
        blocks: [
            .paragraph("""
                Vnitrofiremní formát logu, soukromý konfigurační jazyk, malé DSL — žádný z nich nemá \
                gramatiku tree-sitter a napsat ji vyžaduje překladač a trochu teorie syntaktické \
                analýzy.
                """),
            .paragraph("""
                Místo toho GEditor přijme **tabulkou řízený lexer** deklarovaný v JSON. Vložte soubor \
                do složky `grammars/` uvnitř konfiguračního adresáře GEditoru a aplikaci restartujte.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — celý jazyk",
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
            .heading("Každý klíč"),
            .table(
                headers: ["Klíč", "Typ", "Význam"],
                rows: [
                    ["`name`", "řetězec", "Název zobrazený ve stavovém řádku"],
                    ["`extensions`", "pole řetězců", "Přípony souborů, **bez tečky**"],
                    ["`caseSensitive`", "boolean", "Zda klíčová slova rozlišují velikost písmen"],
                    ["`lineComment`", "řetězec", "Značka komentáře do konce řádku; vynechte, pokud žádná není"],
                    ["`blockComment`", "pole 2 řetězců", "`[otevřít, zavřít]`"],
                    ["`stringDelimiters`", "pole řetězců", "Každá položka je **jeden** znak otevírající/uzavírající řetězec"],
                    ["`escapeCharacter`", "řetězec", "Únikový znak uvnitř řetězců; prázdné znamená, že jazyk žádný nemá"],
                    ["`keywordGroups`", "objekt", "Název skupiny → seznam klíčových slov; tři skupiny dostanou tři barvy"],
                ]
            ),
            .paragraph("""
                Tři názvy skupin, které dostanou vlastní barvy, jsou `keyword`, `type` a `constant`.
                """),
            .warning("""
                Tento lexer **nerozumí vnořování**. Strukturální skládání, seznam funkcí a chytré \
                párování závorek zůstávají výsadou dvaceti vestavěných jazyků. Je to záměrný kompromis: \
                na oplátku deklarujete jazyk za deset minut místo za den.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "Nástroje pro JSON",
        summary: "Přeformátovat, zhustit, seřadit klíče a ověřit proti JSON Schema.",
        keywords: ["json", "formát", "zhustit", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Příkaz", "Co dělá"],
                rows: [
                    ["Přeformátovat", "Zalomí a odsadí pro čtení"],
                    ["Zhustit", "Odstraní všechny nadbytečné bílé znaky"],
                    ["Seřadit klíče", "Seřadí klíče každého objektu abecedně — aby šlo dva soubory JSON **porovnat**"],
                    ["Ověřit proti JSON Schema…", "Zkontroluje dokument proti souboru schématu a vypíše každý problém i s řádkem"],
                ]
            ),
            .paragraph("""
                Uplatňují se pravidla **přísného RFC 8259**: žádné koncové čárky, žádné komentáře, \
                žádné `NaN`. Chyba syntaxe ukáže přesný řádek a sloupec.
                """),
            .note("""
                Rozpoznávají se i soubory **JSONL** (jeden objekt na řádek) a mají vlastní sadu \
                nástrojů v kapitole o znalostním balíku.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "Dotazy JSONPath",
        summary: "Vytáhněte z velkého souboru JSON přesně tu část, kterou potřebujete.",
        keywords: ["jsonpath", "dotaz json", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Napište výraz; výsledky se objeví jako seznam, do kterého lze skočit."),
            .table(
                headers: ["Napište", "Význam"],
                rows: [
                    ["`$`", "Kořen dokumentu"],
                    ["`$.name`", "Klíč `name` v kořeni"],
                    ["`$.orders[0]`", "První prvek pole"],
                    ["`$.orders[*].total`", "Klíč `total` **každého** prvku"],
                    ["`$..province`", "Klíč `province` v **libovolné hloubce**"],
                    ["`$.orders[1:3]`", "Řez: prvky 1 a 2"],
                ]
            ),
            .code(language: "text", caption: "Kód provincie každé objednávky, ať je vnořený jakkoli hluboko",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "Nástroje pro XML",
        summary: "Přeformátovat, zhustit, zkontrolovat syntaxi a ověřit proti DTD nebo XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "ověřit", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Příkaz", "Co dělá"],
                rows: [
                    ["Přeformátovat", "Odsadí podle hloubky značek"],
                    ["Zhustit", "Odstraní bílé znaky mezi značkami"],
                    ["Zkontrolovat syntaxi", "Chybějící uzavírací značky, špatné vnoření, neplatné znaky"],
                    ["Ověřit proti DTD/XSD…", "Zkontroluje proti schématu a ohlásí každý problém i s řádkem"],
                    ["Vyhodnotit XPath…", "Spustí výraz XPath; výsledky se otevřou v nové kartě"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Napište výraz a výsledky se otevřou jako **textová karta**, jeden uzel na řádek. \
                Například: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Výsledky NESKOČÍ na pozici ve zdrojovém souboru.** Systémový vyhodnocovač XPath si \
                staví vlastní strom a neuchovává bajtový posun každého uzlu, takže se vrací OBSAH, ne \
                souřadnice. Chcete-li se dostat na přesné místo, použijte `⌘F` na řetězec, který jste \
                právě našli.
                """),
            .paragraph("""
                V souborech `.xml` a `.html` způsobí napsání `>` ukončující otevírací značku, že se \
                **objeví uzavírací značka** s kurzorem mezi nimi. Samouzavírací značky (`<br/>`), \
                deklarace (`<?xml …?>`) a komentáře ne — nemají co uzavírat.
                """),
            .warning("""
                Přeformátování XML **mění bílé znaky mezi značkami**. V dokumentech, kde ty bílé znaky \
                nesou význam — třeba XHTML s textem uvnitř značek — to mění, co se zobrazí. Je to \
                jediný krok zpět, takže `⌘Z` to vrátí.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "Kontrola YAML",
        summary: "Odhalte dvě nejčastější chyby v YAML: opakované klíče a odsazení tabulátory.",
        keywords: ["yaml", "yml", "lint", "opakovaný klíč", "odsazení"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Opakované klíče** v jednom mapování — většina čteček YAML vezme **poslední** a dřívější tiše zahodí, takže konfigurační soubor se může chovat úplně jinak, než čekáte.",
                "**Odsazení tabulátory** — YAML zakazuje tabulátory v odsazení a chybové zprávy knihoven o tom bývají nesrozumitelné.",
            ]),
            .note("Zapněte `Zobrazit neviditelné ▸ Tabulátory`, ať hned vidíte, který bílý znak je tabulátor."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Soubory logu",
        summary: "Sedm úrovní závažnosti, filtrování podle úrovně a jak číst velmi velký log.",
        keywords: ["log", "chyba", "varování", "filtr", "úroveň"],
        blocks: [
            .paragraph("""
                Zapněte `Zobrazit ▸ Režim logu (obarvit podle úrovně)`. GEditor čte závažnost ze \
                **začátku každého řádku** — po časovém razítku a názvu procesu.
                """),
            .table(
                headers: ["Úroveň", "Barva"],
                rows: [
                    ["CRITICAL · ERROR", "Červená"],
                    ["WARNING", "Oranžová"],
                    ["NOTICE", "Zvýrazňovací barva"],
                    ["INFO", "Obyčejný text"],
                    ["DEBUG · TRACE", "Ztlumené"],
                ]
            ),
            .paragraph("""
                `Filtrovat log podle úrovně…` nižší úrovně zcela skryje. Řádky, jejichž úroveň se \
                **nerozpozná** — třeba pokračování výpisu zásobníku — se nechají být, místo aby dostaly \
                úroveň předchozího řádku.
                """),
            .heading("Čtení velkého logu krok za krokem"),
            .steps([
                "Otevřete soubor — i v gigabajtovém měřítku se otevře téměř okamžitě.",
                "`Zobrazit ▸ Režim logu`, ať vidíte červená místa.",
                "`⌥⌘M` pro mapu dokumentu: je červená shluknutá na jednom úseku, nebo rozeseta po souboru?",
                "`⌘F` na chybový kód, `⌘M` pro označení každého odpovídajícího řádku.",
                "`Hledání ▸ Kopírovat označené řádky`, ať je vytáhnete do nové karty.",
                "Pořád běží? `Soubor ▸ Sledovat soubor (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
