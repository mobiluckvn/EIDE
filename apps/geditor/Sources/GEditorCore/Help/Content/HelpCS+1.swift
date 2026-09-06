import Foundation

/// Česká nápověda — část 1: začínáme a úpravy.
///
/// **Identifikátory `id` témat se NIKDY nepřekládají.** Na ně míří `.seeAlso`, ty otevírá nabídka a
/// díky nim může okno nápovědy přepnout jazyk, **aniž by čtenáře vrátilo zpět na obsah**. Změna
/// jednoho id rozbije všechny odkazy — ve všech knihách naráz.
///
/// Názvy příkazů v `commands:` zůstávají vietnamsky: musí se znak po znaku shodovat se skutečnými
/// položkami nabídky, což `HelpCoverage` kontroluje právě přes ten řetězec.
enum HelpCS {}

extension HelpCS {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Začínáme",
        summary: "Co GEditor umí a kde se vyplatí strávit prvních pět minut.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Co je GEditor",
        summary: "Textový a datový editor gigabajtového měřítka pro macOS, který mluví vietnamsky.",
        keywords: ["úvod", "vítejte", "přehled", "o aplikaci"],
        blocks: [
            .paragraph("""
                GEditor otevře **soubor o velikosti 1 GB, aniž by načetl 1 GB do paměti**. Čte přes \
                posuvné okno nad souborem namapovaným do paměti, takže log s 200 miliony řádků nebo \
                CSV s milionem řádků se otevře asi za sekundu a plynule se posouvá.
                """),
            .paragraph("""
                Kromě úprav je to **pracovní stůl pro data**: zobrazte CSV jako tabulku, vyčistěte ji, \
                ohodnoťte její kvalitu, dotazujte se na ni v SQL, hledejte v ní odchylky a trendy a \
                pak vykreslete zprávu. A čte staré vietnamské znakové sady, na které dnešní nástroje \
                většinou zapomněly.
                """),
            .heading("Šest věcí, které stojí za vyzkoušení jako první"),
            .table(
                headers: ["Úkol", "Kam jít"],
                rows: [
                    ["Otevřít velký soubor bez čekání", "Přetáhněte ho do okna — viz `Otevírání velkých souborů`"],
                    ["Upravit mnoho míst najednou", "`⌘D` přidá další výskyt, pak píšete jednou"],
                    ["Hledat regulárním výrazem", "`⌘F`, zapněte Regex — jádrem je PCRE2 s JIT"],
                    ["Zobrazit CSV jako tabulku", "`⌥⌘T` — milion řádků se stále plynule posouvá"],
                    ["Vyčistit rozházenou datovou tabulku", "`⇧⌘L` Čisticí stůl — náhled před použitím"],
                    ["Otevřít vietnamský soubor, který ukazuje nesmysly", "Klepněte na znakovou sadu ve stavovém řádku"],
                ]
            ),
            .note("""
                Přicházíte z Notepad++? Existuje stránka porovnávající obě klávesové mapy, protože \
                několik kláves si na macOS **prohodí místa**, místo aby se `Ctrl` prostě změnilo na \
                `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Vašich prvních pět minut",
        summary: "Dvanáct zkratek pokryje většinu každodenní práce.",
        keywords: ["zkratka", "klávesy", "začátek", "základy"],
        blocks: [
            .paragraph("""
                Nemusíte se učit všechno. Dvanáct kláves níže pokryje většinu běžné práce; zbytek si \
                dohledáte, až ho budete potřebovat.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Otevřít soubor"),
                HelpShortcut("⇧⌘O", "Otevřít celou složku jako pracovní prostor"),
                HelpShortcut("⌘T", "Nová karta"),
                HelpShortcut("⌘S", "Uložit"),
                HelpShortcut("⌘F", "Hledat"),
                HelpShortcut("⌥⌘F", "Hledat a nahradit"),
                HelpShortcut("⇧⌘F", "Hledat v celé složce"),
                HelpShortcut("⌘D", "Přidat další výskyt výběru"),
                HelpShortcut("⌘L", "Přejít na řádek"),
                HelpShortcut("⌘/", "Zakomentovat řádek značkou daného jazyka"),
                HelpShortcut("⌥⌘T", "Přepnout mezi tabulkou a textem (soubory CSV)"),
                HelpShortcut("⌘?", "Znovu otevřít toto okno nápovědy"),
            ]),
            .heading("Tři věci, které nové uživatele překvapí"),
            .bullets([
                "**Hromadná operace je JEDEN krok zpět**, i když se dotkne milionu řádků. Špatně seřazeno? Jedno `⌘Z` a je to pryč.",
                "**Sezení se obnoví samo.** Ukončete a otevřete znovu: karty se vrátí tam, kde byly, včetně neuložených. Není co stisknout.",
                "**Psaní bez diakritiky přesto najde slova s ní** ve všech vyhledávacích a filtrovacích polích — napište `hue` a získáte `Huế`, `da nang` a získáte `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Co se snažíte udělat?",
        summary: "Vyhledávací tabulka od skutečných úkolů ke kapitole, která je pokrývá.",
        keywords: ["rejstřík", "vyhledání", "jak"],
        blocks: [
            .paragraph("""
                Obsah vlevo je uspořádán podle **funkce**. Tato tabulka je uspořádána podle **úkolu**, \
                protože ta dvě pořadí se nekryjí.
                """),
            .table(
                headers: ["Potřebuji…", "Viz"],
                rows: [
                    ["Upravit stejné místo na stovkách řádků", "Více kurzorů · Blokový výběr sloupce"],
                    ["Hromadně přeformátovat regulárním výrazem", "Hledat a nahradit · Regulární výrazy"],
                    ["Zopakovat sled akcí", "Makra"],
                    ["Otevřít CSV, které mi někdo poslal", "Tabulka CSV"],
                    ["Vyčistit rozházenou tabulku: smíchaná data, čísla jako text", "Postup čištění"],
                    ["Posoudit, zda se tabulce dá věřit", "Hodnocení kvality dat"],
                    ["Najít odchylky, trendy, shluky", "Postup dolování"],
                    ["Klást otázky v SQL", "Dotazování CSV v SQL"],
                    ["Vydat zprávu, jejíž čísla se přepočítají", "Zprávy `.greport.md`"],
                    ["Nakreslit diagram uvnitř dokumentu", "Mermaid"],
                    ["Otevřít vietnamský soubor, který ukazuje nesmysly", "Vietnamské znakové sady"],
                    ["Automatizovat z shellu nebo AppleScriptu", "Automatizace"],
                    ["Obarvit formát, který si vymyslela naše firma", "Vlastní jazyky"],
                ]
            ),
            .note("""
                Není v seznamu? Vyhledávací pole vlevo nahoře prohledává **hlavní text i ukázky kódu**, \
                takže napsání holého konfiguračního klíče jako `fail_under` přistane na správné \
                stránce.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Otevírání velkých souborů",
        summary: "Proč se 1 GB vůbec otevře a kde GEditor záměrně odmítne místo hádání.",
        keywords: ["velký soubor", "gigabajt", "1gb", "log", "mmap", "pomalé", "výkon"],
        blocks: [
            .paragraph("""
                Soubor je **namapován do paměti** a čte se přes posuvné okno; část, kterou upravujete, \
                žije v tabulce kousků. V praxi: doba otevření téměř nezávisí na velikosti souboru a \
                stejně tak paměť, kterou aplikace drží.
                """),
            .heading("Kde záměrně odmítne"),
            .paragraph("""
                Několik výpočtů by muselo načíst celý soubor do jednoho řetězce — přesně to, čemu se \
                tato architektura vyhýbá. Tam GEditor **řekne, že to neudělá**, místo aby se tiše \
                plazil nebo hádal:
                """),
            .table(
                headers: ["Operace", "Strop", "Nad ním"],
                rows: [
                    ["Párování závorek", "1 MB", "Odmítne a řekne to — zvýraznit špatný pár je horší než nic"],
                    ["Viditelný sloupec ve stavovém řádku", "200 kB", "Vrátí se k počítání bajtů a označí to `~`, aby byl význam vidět"],
                    ["Náhled Markdownu", "4 MB", "Odmítne a vysvětlí"],
                ]
            ),
            .warning("""
                Číslo, které vypadá stejně, ale znamená něco jiného, je nejhorší druh chyby. Proto \
                sloupec nad stropem hlásí `~1234`, ne `1234`.
                """),
            .heading("Tipy pro logy"),
            .bullets([
                "`Soubor ▸ Sledovat soubor (tail -f)` připojuje to, co se zapisuje na konec. Dokument se během sledování stane **jen ke čtení** — psát, zatímco přitéká nový text, znamená dva zapisovatele nad jedním dokumentem a poraženým je vždy to, co jste právě napsali.",
                "Řádky logu se **obarvují podle závažnosti** a lze je filtrovat podle úrovně.",
                "**Mapa dokumentu** (`⌥⌘M`) popisuje celý soubor, ne jen viditelnou část.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "Verze z App Store proti přímému stažení",
        summary: "Tři funkce, které má jen přímá verze, a proč.",
        keywords: ["app store", "sandbox", "stažení", "cli", "zásuvný modul", "rozdíl"],
        blocks: [
            .paragraph("""
                GEditor vychází ve dvou verzích. Pocházejí ze **stejného zdrojového kódu** a aplikace \
                při spuštění pozná, kterou z nich je. Rozdíl je v tom, co dovolí App Sandbox.
                """),
            .table(
                headers: ["Funkce", "App Store", "Přímé stažení"],
                rows: [
                    ["Veškeré úpravy, CSV, čištění, dolování, zprávy", "Ano", "Ano"],
                    ["Nástroj příkazového řádku `geditor`", "Ne", "Ano"],
                    ["Filtrování textu vnějším příkazem", "Ne", "Ano"],
                    ["Nativní zásuvné moduly (vlastní proces)", "Ne", "Ano"],
                    ["Vlastní aktualizace", "Přes App Store", "Uvnitř aplikace"],
                ]
            ),
            .paragraph("""
                Každé »Ne« výše plyne ze stejného pravidla: sandbox **zakazuje spouštět kód mimo \
                aplikaci**. To je cena za distribuci v App Store, ne opomenutí.
                """),
            .note("""
                Ve verzi z App Store ty příkazy **zůstávají v nabídce** a vysvětlují, proč nejsou \
                dostupné, místo aby zmizely. Chybějící položka nabídky je dotaz na podporu; odpověď na \
                místě není.
                """),
            .heading("Přístup k souborům ve verzi z App Store"),
            .paragraph("""
                Verze v sandboxu se může dotknout jen souborů, které jste sami otevřeli nebo \
                přetáhli. GEditor si pro každou kartu a pro složku pracovního prostoru drží \
                **bezpečnostně vymezenou záložku**, takže se vaše sezení po ukončení znovu otevře, aniž \
                by znovu žádalo o povolení.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Úpravy

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Úpravy",
        summary: "Upravujte mnoho míst najednou, pracujte s řádky a poznejte skrytá pravidla, která je dobré znát nejdřív.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Více kurzorů",
        summary: "Vyberte všechna odpovídající místa, napište jednou, změňte je všechna.",
        keywords: ["více kurzorů", "cmd+d", "vícenásobný výběr"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Tohle nahradí většinu okamžiků, kdy jste se chystali psát regulární výraz. Vyberte \
                slovo, několikrát stiskněte `⌘D`, čímž nasbíráte další výskyty, a pak pište — všechna \
                místa se změní najednou.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Přidat další výskyt do výběru"),
                HelpShortcut("⌘ + klepnutí", "Umístit další kurzor tam, kam klepnete"),
                HelpShortcut("Esc", "Zrušit je všechny, zpět k jednomu kurzoru"),
                HelpShortcut("⌥ + tažení", "Blokový výběr sloupce (další cesta k mnoha kurzorům)"),
            ]),
            .heading("Pravidla, která je dobré znát"),
            .bullets([
                "Psaní, mazání a vkládání přes mnoho kurzorů je **jeden** krok zpět, ne jeden na kurzor.",
                "Kurzory přežijí pohyb šipkami — celá skupina se posune spolu.",
                "`⌘D` přeskakuje místa již ve výběru, takže přehnané mačkání nikdy nenaskládá kurzory na sebe.",
            ]),
            .note("""
                `⌘D` na slově uvnitř dlouhého řetězce bývalo pomalé. Rozpoznávání hranic slov teď čte \
                po dávkách — asi **42× rychleji** na řetězci o 1 MB, což tohle činí použitelným na \
                datových souborech, ne jen na zdrojovém kódu.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Blokový výběr sloupce",
        summary: "Vyberte obdélník přes mnoho řádků — myší nebo z klávesnice.",
        keywords: ["sloupcový režim", "blokový výběr", "alt tažení", "obdélník", "klávesnice"],
        blocks: [
            .paragraph("""
                Podržte `⌥` a táhněte, čímž vyberete **obdélníkový blok**. Psaní, mazání i vkládání \
                blok následují. Vložení bloku na jediný kurzor si obdélník přesto zachová.
                """),
            .shortcuts([
                HelpShortcut("⌥ + tažení", "Vybrat blok"),
                HelpShortcut("⌥⌘← →", "Rozšířit blok o sloupec vlevo/vpravo"),
                HelpShortcut("⌥⌘↑ ↓", "Rozšířit blok o řádek nahoru/dolů"),
            ]),
            .paragraph("""
                Klávesová cesta není náhradou myši: vybrat 40řádkový blok tažením znamená táhnout přes \
                posun, kdežto `⌥⌘` + šipky zachovají přesnost po sloupcích. Jakákoli **jiná** klávesa \
                (nebo psaní) ukončí blok, který jste rozšiřovali.
                """),
            .heading("Sloupce jsou zde VIDITELNÉ sloupce"),
            .paragraph("""
                TAB se roztáhne na další zarážku podle vaší šířky tabulátoru, místo aby se počítal jako \
                jeden sloupec. Právě to působí, že řádky odsazené tabulátory a mezerami **lícují tak, \
                jak to vidíte na obrazovce**.
                """),
            .paragraph("Vícebajtový text je stále jeden sloupec: `Nguyễn` zabírá šest sloupců, ne devět."),
            .table(
                headers: ["Situace", "Co GEditor udělá"],
                rows: [
                    ["Cílový sloupec padne doprostřed TABu", "Přichytí se k bližšímu okraji; při rovnosti doleva"],
                    ["Řádek je kratší než počáteční sloupec", "Ten řádek přispěje prázdným výběrem a přesto přijme psaný text"],
                    ["Vložení bloku na jediný kurzor", "Zachová obdélník a vkládá dolů po následujících řádcích"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Editor sloupců",
        summary: "Vložte text, číselnou řadu nebo řadu dat na každý řádek bloku.",
        keywords: ["editor sloupců", "číslování", "posloupnost", "řada"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Vyberte sloupcový blok a pak otevřete `Upravit ▸ Column Editor…` (`⌥⌘C`). Dialog má \
                **náhled** ještě předtím, než se cokoli použije.
                """),
            .table(
                headers: ["Režim", "Parametry", "Použijte když"],
                rows: [
                    ["Text", "Pevný řetězec", "Přidáváte stejnou předponu/příponu ke každému řádku"],
                    ["Číselná řada", "Začátek · krok · základ 2·8·10·16 · doplnění nulami", "Číslujete řádky nebo tvoříte kódy"],
                    ["Řada dat", "První datum · krok ve dnech", "Vytváříte sloupec po sobě jdoucích dat"],
                ]
            ),
            .code(language: "text", caption: "Číslování s doplněním nulami, začátek 1, krok 1",
                  source: """
                    Před:             Po (číselná řada, doplněno na 3 číslice):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "**Záporný** krok je platný — počítání dolů funguje.",
                "Vložení do 5 000 řádků je stále **jeden** krok zpět.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Operace s řádky",
        summary: "Řadit, odstranit duplicity, přesunout, spojit, rozdělit, zdvojit, smazat.",
        keywords: ["řadit", "zdvojit", "duplicity", "přesunout řádek", "spojit", "rozdělit"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                S výběrem příkaz běží na výběru; bez něj běží na **celém dokumentu**. Každý zdejší \
                příkaz je jediný krok zpět.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Zdvojit řádek"),
                HelpShortcut("⌘K", "Smazat řádek"),
                HelpShortcut("⌥↑ / ⌥↓", "Přesunout řádek nahoru / dolů"),
            ]),
            .heading("Tři druhy řazení a který zvolit"),
            .table(
                headers: ["Druh", "`file2` vs. `file10`", "Použití"],
                rows: [
                    ["A→Z / Z→A", "`file10` jde před `file2`", "Obyčejné seznamy slov"],
                    ["Přirozené", "`file2` jde před `file10`", "Názvy souborů, kódovaná ID, verze"],
                ]
            ),
            .paragraph("""
                **Přirozené** řazení čte sledy číslic jako čísla. To je téměř vždy to, co chcete, když \
                je seznam číslovaný.
                """),
            .heading("Odstranění duplicit"),
            .bullets([
                "**Celý dokument** — zahodit každý řádek, který se objevil dříve, ponechat první.",
                "**Jen sousední** — sloučit shodné sousední řádky, jako unixové `uniq`.",
            ]),
            .heading("Spojování a dělení"),
            .bullets([
                "**Spojit řádky** sloučí vybrané řádky do jednoho.",
                "**Rozdělit podle délky** rozřízne dlouhé řádky na daném počtu znaků.",
                "**Rozdělit podle znaku** rozřízne u každého výskytu znaku, který napíšete — třeba pro rozdělení jednoho řádku CSV na buňky.",
            ]),
            .note("""
                Zdvojení **posledního řádku** souboru doplní chybějící konec řádku; mazání přes konec \
                dokumentu spolkne i konec předchozího řádku. Obojí se liší od naivní implementace a \
                obojí existuje proto, aby soubor neskončil s osamělým prázdným řádkem — nebo bez něj.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Bílé znaky a odsazení",
        summary: "Uklidit zbloudilé bílé znaky, převést TAB ↔ mezeru a jeden přepínač, nad kterým stojí za to přemýšlet.",
        keywords: ["bílé znaky", "tabulátor", "mezera", "odsazení", "prázdné řádky"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Příkaz", "Co dělá"],
                rows: [
                    ["Odstranit prázdné řádky", "Zahodí každý řádek, na kterém nic není"],
                    ["Sloučit po sobě jdoucí prázdné řádky", "Z několika prázdných řádků za sebou bude jeden"],
                    ["Ořezat bílé znaky na konci řádku", "Odstraní zbloudilé mezery a tabulátory na konci každého řádku"],
                    ["Tab → mezera", "Převede TABy na mezery při aktuální šířce tabulátoru"],
                    ["Mezera → Tab", "Opačný směr"],
                ]
            ),
            .heading("Odsazení podle jazyka"),
            .paragraph("""
                Klepněte na `Tab: 4` ve stavovém řádku. Horní část nabídky to změní pro **celou \
                aplikaci**; dolní — `Jen pro Go`, `Jen pro Python`… — platí jen pro jazyk otevřeného \
                souboru a pamatuje si, zda použít tabulátory, nebo mezery.
                """),
            .paragraph("""
                Lidé nevolí odsazení podle vkusu, ale podle **zvyklosti komunity**: Go používá \
                tabulátory (`gofmt` přebije cokoli jiného), Python čtyři mezery podle PEP 8, \
                JavaScript a YAML obvykle dvě. Jedno číslo pro všechny jazyky znamená, že každému \
                souboru, kterého se dotknete, přibudou řádky, které jste nikdy neupravovali.
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
                Deklarovat to v `settings.json` funguje také — klíčem je kód jazyka (`go`, `python`, \
                `javascript`…). Jazyky, které tam nejsou, používají společné `tabWidth`.
                """),
            .heading("Proč je »ořezat při ukládání« ve výchozím stavu VYPNUTO"),
            .paragraph("""
                Přepínač `Soubor ▸ Ořezat bílé znaky na konci řádku při ukládání` upravuje **řádky, \
                kterých jste se nikdy nedotkli**. Zapnutý ve výchozím stavu promění jednoslovnou opravu \
                v cizím repozitáři v tisícřádkový rozdíl a recenzent nenajde skutečnou změnu.
                """),
            .paragraph("""
                Když je zapnutý, ořezání je **samostatný krok zpět** umístěný před zápis — jedno \
                vrácení vrátí dokument do původního stavu, aniž byste ztratili, co jste právě uložili.
                """),
            .heading("Automatické odsazení"),
            .bullets([
                "Nový řádek zdědí odsazení předchozího plus jednu úroveň po otevírací značce — `{` v jazycích se složenými závorkami, `:` v Pythonu a YAMLu.",
                "Měří se ve **viditelných sloupcích**, takže soubory míchající tabulátory a mezery na obrazovce přesto lícují.",
                "**Neexistuje** pravidlo »napsání `}` přeodsadí řádek«. To pravidlo upravuje řádek, který jste už dokončili, a je to nejčastěji kritizované chování v každém editoru, který ho má.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Velikost písmen a konvence pojmenování",
        summary: "Osm převodů včetně camelCase, snake_case a kebab-case.",
        keywords: ["velikost písmen", "velká", "malá", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Použijí se na výběr. Všechny jsou v nabídce `Formát`."),
            .table(
                headers: ["Příkaz", "`tổng doanh thu` se změní na"],
                rows: [
                    ["VELKÁ PÍSMENA", "`TỔNG DOANH THU`"],
                    ["malá písmena", "`tổng doanh thu`"],
                    ["Velká Písmena Slov", "`Tổng Doanh Thu`"],
                    ["Velké písmeno věty", "`Tổng doanh thu`"],
                    ["Obrátit velikost", "Převrátí každý znak"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Poslední tři odstraňují vietnamskou diakritiku, protože tvoří **identifikátory v \
                kódu** — kde písmena s diakritikou obvykle nejsou dovolena.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Komentáře a párování závorek",
        summary: "⌘/ použije značku daného jazyka; ⌃⌘B skočí na odpovídající závorku.",
        keywords: ["komentář", "závorka", "cmd+/", "párování"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` vybere značku komentáře **podle jazyka dokumentu**: `#` pro Python, `//` pro Rust \
                a C, `<!-- -->` pro XML a HTML.
                """),
            .heading("Celý blok jde jedním směrem"),
            .paragraph("""
                Pokud je byť jediný řádek v bloku ještě nezakomentovaný, příkaz zakomentuje **všechno**. \
                Rozhodovat po řádcích by z napůl zakomentovaného bloku udělalo šachovnici. Značka se \
                vkládá na nejmenší odsazení bloku, takže si blok zachová svůj tvar.
                """),
            .heading("Skok na odpovídající závorku"),
            .bullets([
                "`⌃⌘B` skočí na závorku odpovídající té u kurzoru.",
                "Závorky uvnitř **řetězců** nebo **komentářů** se nepočítají — lehký lexer je rozliší.",
                "Nad **1 MB** příkaz odmítne a řekne to, místo aby se zakotvil v půli cesty a hádal. Zvýraznit špatný pár je horší než nezvýraznit žádný.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Zpět a schránka",
        summary: "Neomezená historie kroků zpět a schránka s více místy.",
        keywords: ["zpět", "znovu", "schránka", "vložit", "historie"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Zpět / znovu"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Vyjmout / kopírovat / vložit"),
                HelpShortcut("⇧⌘V", "Historie schránky"),
            ]),
            .heading("Hromadná operace je JEDEN krok"),
            .paragraph("""
                Seřazení milionu řádků, nahrazení deseti tisíc výskytů, vložení do pěti tisíc řádků \
                editorem sloupců — každé z nich se vrátí **jedním** `⌘Z`.
                """),
            .paragraph("""
                Historie kroků zpět žije ve vlastní textové vyrovnávací paměti GEditoru, a ne v \
                systémovém `UndoManageru`, právě z toho důvodu: `UndoManager` počítá stisky kláves.
                """),
            .heading("Historie schránky"),
            .paragraph("""
                `⇧⌘V` otevře seznam toho, co jste nedávno kopírovali, a vloží vybranou položku. Hodí \
                se, když musíte na mnoha místech střídat dva úryvky.
                """),
        ]
    )
}
