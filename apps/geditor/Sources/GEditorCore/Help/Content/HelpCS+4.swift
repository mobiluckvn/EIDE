import Foundation

/// Česká nápověda — část 4: tabulková data, čištění dat a dolování dat.
extension HelpCS {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Tabulková data",
        summary: "Zobrazit CSV jako tabulku, filtrovat, řadit, zkontrolovat strukturu, dotazovat se v SQL, převádět.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Zobrazení CSV jako tabulky",
        summary: "Milion řádků se stále plynule posouvá, záhlaví drží a zdrojový text zůstává netknutý.",
        keywords: ["csv", "tabulka", "mřížka", "tsv", "excel", "sloupce"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Přepnout mezi tabulkou a textem")]),
            .paragraph("""
                Tabulka je **virtualizovaná**: staví se jen viditelné řádky, takže soubor s milionem \
                řádků se posouvá jako stořádkový.
                """),
            .bullets([
                "**Řádek záhlaví drží na místě** při posunu — na řádku 40 000 stále víte, co je devátý sloupec.",
                "Upravte buňku v tabulce; změna jde rovnou do zdrojového textu.",
                "Tabulka a text jsou **dva pohledy na jeden soubor**, ne dvě kopie.",
                "**⌘C zkopíruje vybraný řádek**, buňky oddělené TABem — vložte rovnou do Excelu nebo Numbers a každá buňka padne správně. Buňky obsahující TABy nebo konce řádků se uzavřou do uvozovek, aby je cíl nerozdělil vejpůl.",
            ]),
            .note("""
                Oddělovač se rozpozná při otevření (čárka, středník, TAB, svislítko). Je-li odhad \
                špatný, změňte ho pomocí `CSV ▸ Změnit oddělovač…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Sešity s více listy",
        summary: "Otevřete libovolný list souboru .xlsx a ⌘S zapíše zpět do listu, na který se díváte.",
        keywords: ["excel", "xlsx", "list", "sešit", "více listů"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Otevřete `.xlsx` a GEditor zobrazí **první list** jako mřížku CSV. `CSV ▸ Zvolit list…` \
                vypíše každý list souboru a otevře ten vybraný ve stejné kartě.
                """),
            .heading("Zápis zpět do SPRÁVNÉHO listu"),
            .paragraph("""
                `⌘S` zapíše vaše úpravy do **listu, na který se díváte**, ne do prvního. Ostatních \
                listů se nedotkne ani o jediný bajt.
                """),
            .note("""
                List se pamatuje podle **názvu**, ne podle pořadí. Tak přeuspořádání listů v Excelu \
                mezi dvěma sezeními zápis nesvede na scestí.
                """),
            .warning("""
                Byl-li otevřený list v Excelu od té doby **přejmenován nebo smazán**, `⌘S` **odmítne \
                zapsat** a řekne to. Vrátit se k prvnímu listu by znamenalo vylít obsah jednoho listu \
                přes druhý — soubor by se stejně uložil, stejně otevřel a jen by měl data na špatném \
                místě.
                """),
            .heading("Přepnutí listu s neuloženými změnami"),
            .paragraph("""
                Přepnutí listu nahradí celý obsah karty, takže je-li něco neuloženo, GEditor se \
                **nejdřív zeptá**. `⌘Z` to nevrátí, protože se vyměnil celý dokument.
                """),
            .heading("Co stojí převedení Excelu na mřížku"),
            .paragraph("""
                Přežijí **hodnoty** — včetně výsledků vzorců, přesně těch čísel, která Excel ukazuje. \
                Nepřežijí: písma, barvy, sloučené buňky, vložené grafy a samotné vzorce.
                """),
            .paragraph("""
                Na oplátku ten list získá celý zbytek produktu: filtrování, řazení, dotazy SQL, čisticí \
                stůl, hodnocení kvality, dolování, grafy.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtrování a řazení v tabulce",
        summary: "Filtrovací pole u každého sloupce, které rozumí číselnému porovnání a psaní bez diakritiky.",
        keywords: ["filtr", "řadit", "sloupec", "hledat v tabulce"],
        blocks: [
            .paragraph("Klepnutím na záhlaví sloupce řadíte. Filtrovací pole pod ním přijímá:"),
            .table(
                headers: ["Napište do filtru", "Význam"],
                rows: [
                    ["`hue`", "Obsahuje `hue`, **bez ohledu na diakritiku** — najde i `Huế`"],
                    ["`=Huế`", "Přesně `Huế` (stále bez ohledu na diakritiku)"],
                    ["`>100`", "Větší než 100"],
                    ["`>=100`", "100 nebo více"],
                    ["`<0`", "Menší než 0"],
                    ["`100..200`", "Mezi 100 a 200"],
                    ["prázdné", "Na tomto sloupci žádný filtr"],
                ]
            ),
            .paragraph("""
                Filtrování více sloupců je **a zároveň**: řádek musí splnit všechny. Číselné porovnání \
                nečíselné buňky přeskočí, místo aby je bralo jako nulu.
                """),
            .note("""
                Filtrování je **způsob pohledu**, ne mazání. Vymažte filtr a každý řádek se vrátí.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Kontrola struktury tabulky",
        summary: "Najděte řádky se špatným počtem sloupců a buňky špatného typu — udělejte to nejdřív.",
        keywords: ["zkontrolovat", "počet sloupců", "špatný typ", "rozbitá data"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Tohle se spouští **před** vším ostatním na souboru, který vám někdo poslal. Odpovídá na \
                dvě otázky:
                """),
            .bullets([
                "**Které řádky mají špatný počet sloupců?** Obvykle buňka s čárkou, která nebyla v uvozovkách — a rozhodí každý řádek za ní.",
                "**Které buňky mají typ odlišný od zbytku svého sloupce?** Například `n/a` ve sloupci čísel.",
            ]),
            .paragraph("Výsledky se objeví jako seznam; klepnutím na jeden skočíte na ten řádek."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Mazání sloupců",
        summary: "Odstraňte jeden nebo více sloupců ze souboru úplně.",
        keywords: ["smazat sloupec", "odstranit sloupec"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Vyberte ze seznamu sloupce k odstranění a použijte. Je to **jeden** krok zpět bez \
                ohledu na to, kolik řádků soubor má.
                """),
            .warning("""
                Na rozdíl od filtrování tohle **upravuje skutečný soubor**. Chcete-li sloupce jen \
                skrýt, použijte dotaz SQL vypisující sloupce, které chcete.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Dotazování CSV v SQL",
        summary: "Plné SQL DuckDB, spuštěné přímo proti otevřenému souboru — jen ke čtení.",
        keywords: ["sql", "dotaz", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Otevřená tabulka se jmenuje **`t`**. Jádrem je **DuckDB**, takže `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, okenní funkce i poddotazy fungují.
                """),
            .code(language: "sql", caption: "Tržby podle provincie, největší první",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Filtrování podle data a podle textové podmínky",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Podíl každé provincie na celku — s okenní funkcí",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Spojení s jiným souborem na disku",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Jen ke čtení, a to je tvrdá záruka"),
            .bullets([
                "Databáze žije **v paměti**; zdrojový soubor se pouze čte.",
                "Přijímá se přesně **jeden příkaz** a **musí to být `SELECT`**. Vše ostatní — včetně `COPY … TO 'file'`, kterým DuckDB umí zapisovat na disk — se zablokuje dřív, než dosáhne jakýchkoli dat.",
            ]),
            .warning("""
                DuckDB čte **soubory**, ne paměť. Má-li dokument neuložené úpravy, musí GEditor před \
                dotazem zapsat dočasnou kopii. U velmi velkého souboru s neuloženými úpravami se \
                **zastaví a řekne to**, místo aby kvůli jednomu dotazu tiše zapsal stovky megabajtů na \
                disk.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Kontingenční tabulky a rychlé grafy",
        summary: "Pivotujte a kreslete rovnou z výsledku dotazu.",
        keywords: ["pivot", "graf", "kontingenční", "agregace"],
        blocks: [
            .paragraph("""
                Obojí se otevírá z **tabulky výsledku dotazu**: spusťte příkaz SQL a pak použijte na \
                panelu tlačítko Pivot nebo Graf.
                """),
            .heading("Pivot"),
            .paragraph("""
                Zvolte sloupec pro **řádky**, sloupec pro **sloupce**, sloupec s **hodnotou** a \
                agregaci (součet, počet, průměr, minimum, maximum) — jako kontingenční tabulka v \
                tabulkovém procesoru.
                """),
            .heading("Grafy"),
            .paragraph("""
                Sloupcový, čárový, koláčový, bodový. Čísla formátovaná po vietnamsku nebo po evropsku a \
                graf lze exportovat jako PNG nebo SVG a vložit jinam.
                """),
            .note("""
                Chcete graf, který se **přepočítá s daty** při každém sestavení? To je blok `chart` ve \
                zprávě `.greport.md`.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Převod tabulky do jiného formátu",
        summary: "TSV, JSON, XML, tabulky Markdownu, příkazy SQL INSERT — s náhledem.",
        keywords: ["převést", "exportovat", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Formát", "Hodí se na"],
                rows: [
                    ["TSV", "Vkládání do tabulkového procesoru bez starostí o čárky v buňkách"],
                    ["JSON", "Nakrmení API, skriptu nebo jiného nástroje"],
                    ["XML", "Starší systémy, které vyžadují XML"],
                    ["Tabulka Markdownu", "Vkládání do dokumentace, do README, do tiketu"],
                    ["Příkazy SQL INSERT", "Načtení do databáze"],
                ]
            ),
            .paragraph("""
                Dialog **ukáže náhled prvních pěti řádků** ještě před vytvořením nové karty — pět řádků \
                stačí k potvrzení názvu tabulky, uvozování a toho, ze kterých sloupců se stala čísla.
                """),
            .note("""
                Náhled volá **tutéž funkci**, která vytváří skutečný výstup, omezenou na pět řádků. \
                Není to simulace, která by se s konečným výsledkem mohla rozejít.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Změna oddělovače",
        summary: "Převeďte soubor mezi čárkou, středníkem, TABem a svislítkem.",
        keywords: ["oddělovač", "čárka", "středník", "tab", "evropské csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Soubory exportované z vietnamského nebo evropského Excelu obvykle používají **středník**, \
                protože tam je čárka desetinným oddělovačem.
                """),
            .warning("""
                Změna oddělovače **přepíše celý soubor**. Buňky obsahující nový oddělovač se uzavřou do \
                uvozovek — jinak by se struktura tabulky rozpadla.
                """),
            .note("""
                **Bylo-li rozpoznání špatné, tohle není příkaz, který chcete.** Jde tu o dvě různé \
                práce, přesně jako u dvojice znakových sad »přečíst jinak« / »převést«:

                • *Soubor je opravdu oddělený středníky a my jsme hádali čárku* — klepněte na pole \
                `CSV · …` ve **stavovém řádku** a zvolte ten správný. Nezmění se ani bajt souboru; jen \
                způsob, jakým se čte.

                • *Soubor je opravdu oddělený čárkami a chcete středníky* — použijte příkaz na této \
                stránce. Ten soubor přepíše.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Čištění dat

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Čištění dat — celý postup",
        summary: "Od surového souboru, který vám někdo poslal, k použitelné tabulce a ke standardu, který lze spouštět měsíčně.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Postup čištění od začátku do konce",
        summary: "Šest kroků od neznámého souboru k důvěryhodné tabulce a standard na příští měsíc.",
        keywords: ["čištění", "vyčistit", "postup", "normalizovat", "uklizená data"],
        blocks: [
            .paragraph("""
                Čištění dat je **málokdy jednorázové**. Lidé dostávají tutéž šablonu zprávy každý měsíc \
                a každý měsíc je třeba stejné sloupce normalizovat stejně. Tenhle postup je navržen \
                přesně na to: uděláte to jednou ručně a pak to spustíte znovu jediným příkazem.
                """),
            .heading("Šest kroků"),
            .steps([
                "**Nejdřív se podívejte na strukturu.** `CSV ▸ Zkontrolovat data` — které řádky mají špatný počet sloupců, které buňky špatný typ. Tohle je první, protože jediný posunutý řádek činí každou pozdější statistiku bezvýznamnou.",
                "**Přečtěte si profil dat.** Po sloupcích: kolik prázdných buněk, kolik různých hodnot, jaký typ, kde jsou odlehlé. Tady souboru porozumíte, ještě než cokoli změníte.",
                "**Otevřete čisticí stůl** (`⇧⌘L`). Odhalí smíchané formáty dat, vietnamská čísla smíchaná s evropskými, zbloudilé bílé znaky, chybějící hodnoty. **Náhled před→po**, pak použijte.",
                "**Vyřešte neostré duplicity**, má-li sloupec jmen či adres ručně psané varianty. Tady rozhodujete vy; stroj jen navrhuje.",
                "**Uložte to jako recept.** Sled kroků, který jste právě provedli, se zapíše do pojmenovaného souboru JSON — ten soubor je vaše znalost o těchto datech.",
                "**Napište sadu pravidel kvality** `.gquality.yaml` a ohodnoťte. Od teď příští měsíční soubor projde receptem a ohodnotí se a **brána příkazového řádku** vrátí nenulový návratový kód, když neprojde.",
            ]),
            .heading("Proč právě v tomto pořadí"),
            .bullets([
                "Struktura **před** profilem: statistika nad posunutou tabulkou je statistikou o jiném sloupci.",
                "Profil **před** čištěním: potřebujete vědět `2 % prázdných`, než se rozhodnete doplňovat, nebo mazat.",
                "Neostré duplicity **po** normalizaci: `CÔNG TY  A` a `Công ty A` se ukáží jako jedno až poté, co se vyřeší bílé znaky a velikost písmen.",
                "Recept **před** sadou pravidel: recept opravuje, pravidla soudí — ohodnotit neopravenou tabulku dá jen nízké číslo, které jste už čekali.",
            ]),
            .heading("Po prvním provedení je každý měsíc jediný příkaz"),
            .code(language: "bash", caption: "Vyčistit a ohodnotit s návratovým kódem pro CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Návratový kód **0** znamená prošlo, **1** neprošlo, **2** chybu za běhu. \
                `--record-history` připojí řádek do souboru historie, aby příští běh mohl porovnat \
                posun.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Profil dat",
        summary: "Jeden popis na sloupec: typ, prázdné, různé hodnoty, rozložení.",
        keywords: ["profil", "statistika sloupce", "null", "různé"],
        blocks: [
            .paragraph("""
                Profil **popisuje**; nesoudí. Říká *»tenhle sloupec je z 2 % prázdný«*; zda jsou 2 % \
                přijatelná, patří sadě pravidel kvality.
                """),
            .table(
                headers: ["Míra", "Jak ji číst"],
                rows: [
                    ["Typ", "Odvozen ze samotných dat, ne z názvu sloupce"],
                    ["Prázdné buňky", "Počet a podíl chybějících hodnot"],
                    ["Různé hodnoty", "1 znamená konstantní sloupec; rovná se počtu řádků znamená klíčový sloupec"],
                    ["Minimum · maximum · průměr", "Jen číselné sloupce"],
                    ["Nejčastější hodnoty", "Okamžitě si všimnete chybového kódu nebo přehnaně užité výchozí hodnoty"],
                ]
            ),
            .warning("""
                Počítání různých hodnot má práh. Nad ním je zobrazené číslo **dolní mez** a profil \
                **říká, že jde o odhad**, místo aby to míchal s přesnými počty.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Čisticí stůl",
        summary: "Sedm normalizací, vždy s náhledem, vždy jeden krok zpět, nikdy hádání.",
        keywords: ["vyčistit", "normalizovat", "data", "čísla", "doplnit chybějící"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Otevřít čisticí stůl")]),
            .table(
                headers: ["Operace", "Co dělá"],
                rows: [
                    ["Normalizovat data", "Převede každý tvar data ve sloupci na jeden tvar"],
                    ["Normalizovat čísla", "Vyřeší desetinný oddělovač a oddělovač tisíců"],
                    ["Ořezat bílé znaky", "Odstraní je na obou koncích; volitelně sloučí i vnitřní série"],
                    ["Změnit velikost písmen", "Sjednotí velikost písmen ve sloupci"],
                    ["Doplnit pevnou hodnotou", "Nahradí prázdné buňky hodnotou, kterou napíšete"],
                    ["Doplnit ze souseda", "Vezme hodnotu z řádku nad nebo pod"],
                    ["Smazat řádky s prázdnými buňkami", "Zahodí řádky, kterým chybí data"],
                ]
            ),
            .heading("Tři záruky celého stolu"),
            .bullets([
                "**Vždy s náhledem.** Tabulka před→po s počtem buněk, které se změní.",
                "**Jeden krok zpět** pro celý průchod, i když se dotkne milionu buněk.",
                "**Zpráva poté**: kolik buněk se změnilo a které se nepodařilo přečíst.",
            ]),
            .heading("Zásada: nikdy nehádat"),
            .paragraph("""
                Buňka, kterou nelze přečíst s jistotou, se **označí a nechá být**. Vezměte `03/04/2026` \
                ve sloupci, který obě konvence míchá — je to 3. dubna, nebo 4. března? GEditor se vás \
                zeptá na pořadí den/měsíc, místo aby volil za vás.
                """),
            .warning("""
                Špatně normalizovat sloupec s daty je takové poškození, které je **téměř nemožné \
                odhalit**: čísla pořád vypadají správně, jen jsou to jiná data. Proto tenhle stůl raději \
                odmítne, než by odvozoval.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Neostré duplicity",
        summary: "Najděte ručně psané varianty téhož jména — a nikdy je neslučujte samočinně.",
        keywords: ["neostré", "duplicity", "sloučit", "varianty", "překlepy"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — tři způsoby, jak \
                napsat jednoho zákazníka. Běžné odstranění duplicit je za totéž nepovažuje.
                """),
            .steps([
                "Zvolte sloupec k prozkoumání a práh podobnosti.",
                "GEditor seskupí blízké hodnoty do **shluků** a ukáže srovnávací tvar.",
                "U **každého shluku** zvolíte, kterou hodnotu ponechat — nebo shluk přeskočíte.",
                "Použijte. Jeden krok zpět.",
            ]),
            .warning("""
                Tenhle nástroj **nikdy neslučuje sám** a tlačítko »sloučit vše« neexistuje. Dva \
                řetězce podobné z 92 % mohou být překlep, nebo dvě skutečně různé firmy lišící se \
                jedním slovem — stroj to nedokáže rozhodnout.
                """),
            .paragraph("""
                Špatně sloučit dva záznamy je **tichá** ztráta dat: žádná buňka nezůstane prázdná, \
                žádný řádek nezčervená, dvě entity se prostě stanou jednou a nikdo si toho nevšimne, \
                dokud se neuzavírají účty.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Čisticí recepty",
        summary: "Zaznamenejte sled kroků jako soubor JSON a spusťte ho na datech příštího měsíce.",
        keywords: ["recept", "opakovat", "automatizovat", "měsíčně", "dávka"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Po vyčištění uložte kroky jako **recept**. Je to lidsky čitelný soubor JSON, který \
                můžete držet vedle dat, poslat kolegovi a uložit do repozitáře, aby se změny \
                sledovaly.
                """),
            .code(language: "json", caption: "sales-standard.json — zkráceně",
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
                Každý krok lze **vypnout** (`enabled`), takže jeden recept může sloužit několika téměř \
                shodným druhům souborů.
                """),
            .heading("Opětovné spuštění"),
            .bullets([
                "V aplikaci: `CSV ▸ Spustit čisticí recept…`",
                "Z shellu, přes celou složku: viz stránka o příkazovém řádku.",
            ]),
            .code(language: "bash", caption: "Zkušební běh před jakýmkoli zápisem — žádného souboru se nedotkne",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Ve výchozím stavu se výsledek zapíše do nového souboru vedle originálu \
                (`sales-clean.csv`). O přepsání originálu je nutné výslovně požádat pomocí \
                `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Hodnocení kvality dat",
        summary: "Šest rozměrů, jedno skóre 0–100 a každý vzorec vytištěn, abyste si ho mohli přepočítat.",
        keywords: ["kvalita", "skóre", "dqr", "šest rozměrů"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Od profilu dat se liší jednou zásadní věcí: profil **popisuje**, skóre **soudí proti \
                standardu, který jste deklarovali** v souboru `.gquality.yaml`.
                """),
            .table(
                headers: ["Rozměr", "Co měří"],
                rows: [
                    ["Úplnost", "Podíl vyplněných buněk podle pravidel `not_null`"],
                    ["Platnost", "Podíl pravidel formátu, typu, rozsahu a regexu, která projdou"],
                    ["Jedinečnost", "Vůči klíči, který jste deklarovali v `uniqueness_key`"],
                    ["Konzistence", "Pravidla napříč sloupci a napříč soubory"],
                    ["Přesnost (odhad)", "Odlehlé hodnoty v číselných sloupcích, které určíte"],
                    ["Aktuálnost", "Jak stará data jsou vůči prahu `freshness`"],
                ]
            ),
            .heading("Tři záruky o skóre"),
            .bullets([
                "**Vzorec je vytištěn ve výsledku** — můžete si ho přepočítat ručně.",
                "**Deterministické**: stejná data a stejná pravidla dají stejné skóre. Jen *Aktuálnost* závisí na okamžiku, takže `now` je **parametr** a zaznamenává se do výsledku.",
                "**Rozměr, který nelze ohodnotit, zůstane prázdný i s důvodem**, nikdy tiše nedostane 100.",
            ]),
            .warning("""
                Ta poslední záruka je důležitá. Tabulka bez deklarovaného `uniqueness_key`, které se \
                udělí 100 za »jedinečnost«, je skóre, které lže — a lže lichotivým směrem, což je ten \
                nebezpečný.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Syntaxe `.gquality.yaml`",
        summary: "Každý klíč souboru pravidel, s jednou úplnou fungující sadou.",
        keywords: ["gquality", "yaml", "pravidla", "syntaxe", "datový standard"],
        blocks: [
            .paragraph("""
                Soubor leží **vedle dat**, ne uvnitř aplikace: datový standard musí být \
                přezkoumatelný, a přezkoumávat je právě to, co lidé se standardy dělají.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — úplná sada pravidel",
                  source: """
                    schemaVersion: 1

                    # Váhy šesti rozměrů. Chybějící rozměr má váhu 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Klíč, který činí řádek jedinečným. Bez něj rozměr "Jedinečnost"
                    # NELZE ohodnotit — a celkový výsledek řekne, že chybí.
                    uniqueness_key: [ma_don]

                    # Číselné sloupce zkoumané na odlehlé hodnoty v "Přesnost (odhad)".
                    accuracy_columns: [doanh_thu, so_luong]

                    # Rozměr "Aktuálnost".
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Varuj, když tento běh klesne oproti předchozímu.
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
                        max_null_pct: 2          # povolit 2 % prázdných
                      # Pravidlo napříč sloupci: `col` není potřeba
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Pravidlo napříč soubory: hodnota musí existovat v jiném souboru
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Typy pravidel"),
            .table(
                headers: ["Klíč", "Význam", "Rozměr"],
                rows: [
                    ["`not_null: true`", "Buňka musí být vyplněna; `max_null_pct` to uvolní", "Úplnost"],
                    ["`unique: true`", "Ve sloupci žádné opakované hodnoty", "Jedinečnost"],
                    ["`dtype: int\\|float\\|date\\|text`", "Správný typ", "Platnost"],
                    ["`range: { min:, max: }`", "V číselném rozsahu", "Platnost"],
                    ["`length: { min:, max: }`", "Délka řetězce", "Platnost"],
                    ["`regex: \"…\"`", "Odpovídá regulárnímu výrazu", "Platnost"],
                    ["`in_set: [ … ]`", "Jedna z daného seznamu", "Platnost"],
                    ["`date_format: \"…\"`", "Správný tvar data", "Platnost"],
                    ["`compare: { a:, op:, b: }`", "Porovnat dva sloupce; `op` je `<` `<=` `=` `>=` `>` `<>`", "Konzistence"],
                    ["`foreign_key: { file:, column: }`", "Hodnota musí existovat v jiném souboru", "Konzistence"],
                    ["`severity: error\\|warn`", "Závažnost pravidla; ve výchozím stavu `error`", "—"],
                ]
            ),
            .warning("""
                Napište klíč pravidla s překlepem a soubor se **odmítne se zprávou**, místo aby se to \
                pravidlo tiše přeskočilo. Tiché přeskočení znamená, že věříte, že data byla \
                zkontrolována proti pravidlu, které nikdy neproběhlo.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Brána kvality v CI",
        summary: "Zastavte nevyhovující data na potrubí pomocí návratových kódů.",
        keywords: ["ci", "brána", "fail-under", "návratový kód", "automatizace", "historie", "posun"],
        blocks: [
            .code(language: "bash", caption: "Ohodnotit a vrátit návratový kód",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Volba", "Význam"],
                rows: [
                    ["`--quality <soubor.yaml>`", "Sada pravidel, proti níž se hodnotí"],
                    ["`--fail-under <0…100>`", "Pod tímto skóre je to NEPROŠLO"],
                    ["`--json <soubor\\|->`", "Strojově čitelný výsledek; `-` tiskne na standardní výstup"],
                    ["`--record-history`", "Připojí řádek do `sales-standard.history.jsonl`"],
                    ["`--now <RRRR-MM-DD>`", "Ukotví referenční datum pro *Aktuálnost*"],
                    ["`--recipe <soubor.json>`", "Vyčistí **v paměti** před hodnocením, bez zápisu souboru"],
                ]
            ),
            .table(
                headers: ["Návratový kód", "Význam"],
                rows: [["`0`", "Prošlo"], ["`1`", "Neprošlo"], ["`2`", "Chyba za běhu"]]
            ),
            .heading("Proč by CI mělo předávat `--now`"),
            .paragraph("""
                Bez toho *Aktuálnost* porovnává data s okamžikem běhu — takže tentýž soubor s \
                přibývajícími dny ztrácí body a jednoho rána zčervená potrubí, aniž by kdokoli cokoli \
                změnil.
                """),
            .heading("Sledování posunu"),
            .paragraph("""
                S `--record-history` každý běh připojí řádek do souboru historie JSONL. Příště prahy z \
                bloku `drift:` porovnají s posledním během a varují, když je pokles příliš velký.
                """),
            .note("""
                Každý práh posunu je **ve výchozím stavu vypnutý**, kromě `warn_on_new_failure`. \
                Varování zapnuté od začátku s číslem, které za vás vybrala aplikace, by se spustilo \
                každému při druhém běhu — a co volá vlka první den, to se třetí den ignoruje.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Dolování dat

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Dolování dat — celý postup",
        summary: "Odchylky, korelace, shlukování, předpovědi, asociační pravidla — a jak je číst.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Postup dolování od začátku do konce",
        summary: "Šest nástrojů, pořadí jejich použití a jedno pravidlo: bez měření žádný závěr.",
        keywords: ["dolování", "analýza", "postup", "statistika"],
        blocks: [
            .warning("""
                **Nejdřív vyčistit, pak dolovat.** Nenormalizovaný sloupec s daty vede ke špatným \
                předpovědím; číselný sloupec míchající evropské oddělovače tisíců plodí přízračné \
                odlehlé hodnoty. Každý nástroj níže předpokládá, že tabulka je čistá.
                """),
            .heading("V jakém pořadí postupovat"),
            .steps([
                "**Najít odchylky** — odpovídá na *»je nějaký řádek divný«*. Nejlevnější a často hned užitečné.",
                "**Korelační matice** — odpovídá na *»který sloupec se pohybuje se kterým«*. Řídí vše, co následuje.",
                "**Shlukování** — odpovídá na *»kolik přirozených skupin tu je«*.",
                "**Předpovídání** — jen s časovým sloupcem a alespoň **dvěma úplnými cykly**.",
                "**Asociační pravidla** — jen pro data tvaru košíku: jedna transakce na řádek, nebo dva sloupce s ID transakce a položkou.",
                "**Dolování po skupinách** — spustí první tři znovu **nezávisle uvnitř každé skupiny**. Tento krok často obrátí závěr vyvozený ze sloučené tabulky.",
            ]),
            .heading("Tři pravidla pro celou rodinu"),
            .bullets([
                "**Každý výsledek nese blok »Metoda«**: algoritmus, parametry, semínko, vzorec. Nelze ho vypnout — tabulku tří čísel, která neříká, odkud pocházejí, nelze použít pro rozhodnutí.",
                "**Bez měření žádný závěr.** Příliš malý vzorek, nulový rozptyl, singulární matice — GEditor odmítne a řekne proč, místo aby vrátil číslo, které jen vypadá správně.",
                "**Deterministické výsledky.** Stejná data dají stejný výsledek; kde je potřeba náhoda, semínko se zaznamená do výstupu.",
            ]),
            .heading("Od výsledku zpět k datům"),
            .paragraph("""
                Každý panel **označí zpět ve zdrojových datech**: klepněte na odlehlý řádek, korelační \
                buňku nebo asociační pravidlo a příslušné řádky se v tabulce označí. Tak přejdete od \
                *»něco je divné«* k *»divné přesně na těchto řádcích«*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Hledání odlehlých řádků",
        summary: "Čtyři míry, tři stupně závažnosti a vysvětlení, proč je řádek divný.",
        keywords: ["odlehlá hodnota", "odchylka", "z-skóre", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Míra", "Použijte když"],
                rows: [
                    ["z-skóre", "Sloupec má zhruba normální rozdělení"],
                    ["IQR", "Sloupec je zešikmený s dlouhým chvostem — bezpečná výchozí volba"],
                    ["MAD", "Sloupec už obsahuje mnoho odlehlých hodnot a je třeba robustní míra"],
                    ["Mahalanobis", "**Několik sloupců naráz** — zachytí řádky divné v kombinaci, ne v jednotlivém sloupci"],
                ]
            ),
            .paragraph("""
                Výsledky se obarvují podle **tří stupňů závažnosti**, ne jednou plochou barvou — jinak \
                by mírně neobvyklý řádek nešel odlišit od divoce neobvyklého.
                """),
            .heading("Vysvětlení proč"),
            .paragraph("""
                U vícesloupcové míry GEditor rozloží příspěvek každého sloupce a vytvoří větu jako \
                *«odlehlé hlavně kombinací tržby (50 %) × množství (50 %)»*.
                """),
            .note("""
                To procento je *z vysvětlitelné části*, ne *ze vzdálenosti*. Blok Metoda to říká přímo \
                pod tabulkou.
                """),
            .warning("""
                Sloupec, jehož IQR nebo MAD je nula, přiměje míru **odmítnout běh**, místo aby dělila \
                něčím nepatrným a vytvořila obrovské skóre. U vícesloupcového případu: je-li kovarianční \
                matice singulární, **GEditor řekne, který sloupec vypustit**, místo aby použil \
                pseudoinverzi a »zařídil, ať to funguje«.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Korelační matice",
        summary: "Pearson a Spearman pro každou dvojici, s bodovým grafem po klepnutí.",
        keywords: ["korelace", "pearson", "spearman", "teplotní mapa", "bodový graf"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Koeficient", "Co měří"],
                rows: [
                    ["Pearson", "**Lineární** vztah"],
                    ["Spearman", "**Libovolný monotónní** vztah, včetně zakřivených — počítán z pořadí"],
                ]
            ),
            .paragraph("""
                Klepnutím na buňku v teplotní mapě uvidíte bodový graf té dvojice s regresní přímkou a \
                R².
                """),
            .heading("Čtyři detaily, které mění, jak to číst"),
            .bullets([
                "**Shody používají průměrná pořadí**, takže přeřazení tabulky Spearmanův koeficient nezmění.",
                "**Prázdné buňky se řeší po dvojicích** a `n` každé buňky je přímo v tabulce — `0,93` přes 6 řádků neznamená totéž co `0,93` přes 6 000 řádků.",
                "**Konstantní sloupec vrátí prázdno**, ne 0. Nula znamená *změřeno, žádný vztah nenalezen*.",
                "**Barevná škála je modrá↔oranžová**, ne červeno-zelená: 8 % mužů vidí červeno-zelenou škálu jako jednu šedou masu, takže `+0,9` a `−0,9` vypadají stejně.",
            ]),
            .warning("""
                **Korelace neznamená příčinnost.** Ta věta se kreslí **přímo do grafu**, takže cestuje s \
                obrázkem, když ho vyexportujete.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Shlukování",
        summary: "k-means a DBSCAN, dva způsoby volby k — a varování o škálování.",
        keywords: ["shluk", "kmeans", "dbscan", "skupiny", "silueta", "loket"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritmus", "Použijte když"],
                rows: [
                    ["k-means", "Znáte (nebo chcete zkusit) počet shluků; shluky mají tvar kapek"],
                    ["DBSCAN", "Počet neznáte; shluky mají libovolné tvary; chcete oddělit šum"],
                ]
            ),
            .heading("Škálování je ve výchozím stavu zapnuté — a proč"),
            .paragraph("""
                Sloupec `tržby` (v milionech) vedle sloupce `množství` (v kusech): vzdálenost dvou \
                řádků rozhoduje téměř úplně ten větší. To není »trochu neoptimální« — to je \
                **odpovídání na jinou otázku**. Použité škálování se zaznamená do výsledku.
                """),
            .heading("Volba počtu shluků"),
            .bullets([
                "**Silueta** — čím vyšší skóre, tím lépe oddělené shluky. U velké tabulky **vzorkuje** (rovnoměrně rozmístěně, ne prvních 2 000 řádků) a výsledek se sám prohlašuje za odhad.",
                "**Loket** — vykreslí vnitroshlukový součet čtverců proti k. To je **způsob čtení grafu**, ne optimalizace: ta veličina s rostoucím k vždy klesá, takže statisticky »optimální k« neexistuje.",
            ]),
            .note("""
                U DBSCAN pomáhá s volbou poloměru graf **k-vzdálenosti**: koleno křivky bývá rozumnou \
                počáteční hodnotou.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Předpovědi časových řad",
        summary: "Rozklad na trend a sezónnost, Holt-Winters a základní model, který běží vždy vedle.",
        keywords: ["předpověď", "časová řada", "sezónnost", "holt-winters", "trend"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Zvolte časový sloupec a hodnotový sloupec. GEditor rozloží řadu na **trend · sezónnost \
                · zbytek** a pak předpovídá metodou Holt-Winters (aditivní nebo multiplikativní), s \
                intervaly 80 % a 95 %.
                """),
            .heading("Základní model běží vždy a naplno řekne, kdo vyhrál"),
            .paragraph("""
                Vedle modelu spouští GEditor dvě naivní metody: *vezmi předchozí období* a *vezmi \
                stejné období minulé sezóny*. Pokud model **prohraje** se základním modelem, ta věta se \
                objeví na **prvním řádku, jinou barvou** — ne pod tabulkou čísel.
                """),
            .paragraph("""
                Důvod: nástroje na předpovědi mají sklon podávat model jako fakt a uživatel nemá jak \
                zjistit, že »prostě vezmi číslo minulého měsíce« by bylo přesnější.
                """),
            .heading("Tři místa, kde GEditor odmítne nebo se sám přizná"),
            .bullets([
                "**Bez dvou úplných cyklů se vrátí k naivní metodě.** Napasovat sezónnost na šum jediného cyklu a zopakovat ji do budoucna dá velmi přesvědčivou, zcela vymyšlenou předpověď.",
                "**MAPE narazivší na nulu to řekne**, a je-li nulových více než 25 % období, metriku zadrží — tiché přeskočení dá číslo spočítané ze systematicky zkresleného podsouboru.",
                "**Interval spolehlivosti se prohlašuje za přibližný** a uvádí, že se u dlouhých horizontů rozšiřuje příliš pomalu.",
            ]),
            .note("""
                Sezónní perioda se rozpoznává na **první diferenci**, ne na surové řadě: trend činí \
                každé zpoždění silně korelovaným a sezónní vrchol utopí.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Asociační pravidla",
        summary: "Kdo kupuje A, kupuje často B — a proč se tabulka řadí podle liftu, ne podle spolehlivosti.",
        keywords: ["apriori", "asociační pravidla", "nákupní košík", "lift", "podpora"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Přijímají se dva tvary dat:"),
            .bullets([
                "**Jeden košík na řádek** — sloupec obsahující seznam položek.",
                "**Dva sloupce** — ID transakce a položka, jedna položka na řádek.",
            ]),
            .table(
                headers: ["Metrika", "Význam"],
                rows: [
                    ["podpora", "Podíl košíků obsahujících obě strany"],
                    ["spolehlivost", "Z košíků s levou stranou podíl těch, které mají pravou"],
                    ["**lift**", "Spolehlivost dělená základní četností pravé strany"],
                    ["páka", "Rozdíl oproti tomu, co by předpovídala nezávislost"],
                ]
            ),
            .heading("Řazeno podle liftu, ne podle spolehlivosti"),
            .paragraph("""
                Pokud se pravá strana stejně objevuje v 95 % košíků, pak **každé** pravidlo k ní \
                vedoucí má spolehlivost kolem 95 % — a neříká vůbec nic. Řazení podle spolehlivosti dá \
                nahoru právě ta nejbezvýznamnější pravidla.
                """),
            .warning("""
                `lift < 1` se **označí přímo v řádku**: 80% spolehlivost k něčemu se základní četností \
                95 % znamená **obrácený** vztah — správné číslo vedoucí ke špatnému závěru.
                """),
            .bullets([
                "Koupit dvě krabice mléka je pořád **jedna** transakce obsahující mléko: duplicity uvnitř košíku se zahodí, jinak podpora roste s množstvím.",
                "Nastavit práh podpory příliš nízko způsobí kombinatorickou explozi množiny kandidátů; při dosažení stropu se **GEditor zastaví a uvede, že tabulka je neúplná**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Dolování po skupinách",
        summary: "Spusťte analýzu znovu nezávisle po skupinách — krok, který nejčastěji obrátí závěr.",
        keywords: ["seskupit", "po skupinách", "simpson", "pobočky", "porovnat skupiny"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Zvolte textový sloupec jako klíč seskupení. Každá skupina dostane odchylky, předpověď a \
                korelaci spuštěné **zcela nezávisle** a pak se seřadí podle kritéria, které zvolíte.
                """),
            .heading("Proč je nutné skupiny oddělit, ne sloučit"),
            .paragraph("""
                Dvě pobočky, jedna kolem 10 a druhá kolem 100. Plot odlehlých hodnot spočítaný na \
                **sloučené** tabulce padne kolem ±135 — a selže v **obou směrech**:
                """),
            .bullets([
                "**Falešně negativní**: hodnota 20, pro malou pobočku zjevně odlehlá, leží pohodlně uvnitř společného plotu. Čím více skupin, tím je to slepější.",
                "**Falešně pozitivní**: široce rozptýlené skupině společný plot ustřihne normální chvost a označí se celá řada zcela běžných řádků.",
            ]),
            .heading("Sloupec »rozchod korelace« zachytí Simpsonův paradox"),
            .paragraph("""
                Tři skupiny, v nichž dva sloupce **každé** skupiny korelují na `−1`, ale sloučeně \
                korelují na `> 0,9`. Kdokoli čte jen sloučenou tabulku, vyvodí **přesný opak**. Tento \
                sloupec míří právě na takové případy.
                """),
            .note("""
                Panel nabízí jako klíče seskupení jen **textové sloupce** a s varováním se zastaví u \
                1 000 skupin — aby nešlo zvolit sloupec s ID objednávky a udělat z každého řádku \
                vlastní skupinu.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Dolování v textu",
        summary: "n-gramy a TF-IDF nad textovým sloupcem — hledání charakteristických obratů.",
        keywords: ["dolování textu", "n-gram", "tf-idf", "klíčová slova", "obraty"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Běží nad jedním textovým sloupcem — popisy produktů, zpětná vazba zákazníků, poznámková \
                pole.
                """),
            .bullets([
                "**n-gramy** — nejčastější jedno-, dvou- a tříslovné obraty.",
                "**TF-IDF** — slova **charakteristická** pro každou skupinu dokumentů, tedy častá zde a vzácná jinde.",
            ]),
            .paragraph("""
                Rozdíl: n-gramy vám řeknou *»co zákazníci pořád zmiňují«*, TF-IDF vám řekne *»čím se \
                tahle skupina liší od ostatních«*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
