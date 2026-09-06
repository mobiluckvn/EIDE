import Foundation

/// Polska treść pomocy — część 4: dane tabelaryczne, czyszczenie i eksploracja.
extension HelpPL {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Dane tabelaryczne",
        summary: "Oglądać CSV jako tabelę, filtrować, sortować, sprawdzać budowę, odpytywać w SQL, przekształcać.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Oglądanie CSV jako tabeli",
        summary: "Milion wierszy nadal przewija się płynnie, nagłówek stoi w miejscu, a tekst źródłowy pozostaje nietknięty.",
        keywords: ["csv", "tabela", "siatka", "tsv", "excel", "kolumny"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Przełączać tabelę i tekst")]),
            .paragraph("""
                Tabela jest **zwirtualizowana**: budowane są tylko wiersze widoczne, więc plik o milionie \
                wierszy przewija się jak stuwierszowy.
                """),
            .bullets([
                "**Wiersz nagłówka trzyma się na miejscu** podczas przewijania — przy wierszu 40 000 wciąż wiecie, czym jest dziewiąta kolumna.",
                "Zmieńcie komórkę w tabeli; zmiana idzie wprost do tekstu źródłowego.",
                "Tabela i tekst to **dwa spojrzenia na jeden plik**, a nie dwie kopie.",
                "**⌘C kopiuje zaznaczony wiersz**, komórki rozdzielone tabulatorami — wklejcie wprost do Excela albo Numbers i każda komórka trafi we właściwe miejsce. Komórki z tabulatorami albo końcami wierszy są ujmowane w cudzysłów, żeby cel nie przeciął ich na dwoje.",
            ]),
            .note("""
                Znak rozdzielający rozpoznawany jest przy otwarciu (przecinek, średnik, tabulator, kreska \
                pionowa). Jeśli domysł jest zły, zmieńcie go poleceniem `CSV ▸ Zmień znak rozdzielający…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Skoroszyty o wielu arkuszach",
        summary: "Otworzyć dowolny arkusz pliku .xlsx, a ⌘S zapisuje z powrotem do arkusza, który oglądacie.",
        keywords: ["excel", "xlsx", "arkusz", "skoroszyt"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Otwórzcie `.xlsx`, a GEditor pokaże **pierwszy arkusz** jako tabelę CSV. `CSV ▸ Wybierz \
                arkusz…` wylicza każdy arkusz pliku i otwiera wybrany w tej samej karcie.
                """),
            .heading("Zapis z powrotem do WŁAŚCIWEGO arkusza"),
            .paragraph("""
                `⌘S` zapisuje wasze zmiany do **arkusza, który oglądacie**, a nie do pierwszego. Pozostałe \
                arkusze nie są tknięte ani o bajt.
                """),
            .note("""
                Arkusz zapamiętywany jest po **nazwie**, a nie po położeniu. Dzięki temu przestawienie \
                arkuszy w Excelu między dwiema sesjami nie kieruje zapisu w złe miejsce.
                """),
            .warning("""
                Jeśli otwarty arkusz został w Excelu **przemianowany albo usunięty** od czasu, gdy go \
                otworzyliście, `⌘S` **odmawia zapisu** i mówi to. Sięgnięcie po pierwszy arkusz oznaczałoby \
                wylanie treści jednego arkusza na drugi — plik i tak by się zapisał, i tak by się otworzył, \
                tyle że dane byłyby w złym miejscu.
                """),
            .heading("Zmiana arkusza przy niezapisanych zmianach"),
            .paragraph("""
                Zmiana arkusza zastępuje całą treść karty, więc jeśli coś jest niezapisane, GEditor **pyta \
                najpierw**. `⌘Z` tego nie przywróci, bo wymieniony został cały dokument.
                """),
            .heading("Ile kosztuje sprowadzenie Excela do tabeli"),
            .paragraph("""
                To, co przeżywa, to **wartości** — łącznie z wynikami formuł, dokładnie te liczby, które \
                pokazuje Excel. To, co nie: kroje pisma, barwy, komórki scalone, wykresy osadzone i same \
                formuły.
                """),
            .paragraph("""
                W zamian ten arkusz zyskuje całą resztę programu: filtrowanie, sortowanie, zapytania SQL, \
                warsztat czyszczenia, ocenę jakości, eksplorację, wykresy.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtrowanie i sortowanie w tabeli",
        summary: "Pole filtra przy każdej kolumnie, rozumiejące porównanie liczbowe i pisanie bez znaków diakrytycznych.",
        keywords: ["filtr", "sortowanie", "kolumna", "szukanie w tabeli"],
        blocks: [
            .paragraph("Kliknijcie nagłówek kolumny, żeby posortować. Pole filtra pod nim przyjmuje:"),
            .table(
                headers: ["Wpiszcie w filtr", "Znaczenie"],
                rows: [
                    ["`hue`", "Zawiera `hue`, **nieczułe na znaki** — znajdzie też `Huế`"],
                    ["`=Huế`", "Dokładnie `Huế` (nadal nieczułe na znaki)"],
                    ["`>100`", "Większe niż 100"],
                    ["`>=100`", "100 albo więcej"],
                    ["`<0`", "Mniejsze niż 0"],
                    ["`100..200`", "Między 100 a 200"],
                    ["puste", "Brak filtra na tej kolumnie"],
                ]
            ),
            .paragraph("""
                Filtrowanie wielu kolumn to **i**: wiersz musi spełnić wszystkie. Porównanie liczbowe pomija \
                komórki nieliczbowe, zamiast traktować je jak zero.
                """),
            .note("""
                Filtrowanie to **sposób patrzenia**, a nie usuwanie. Wyczyśćcie filtr, a wszystkie wiersze \
                wracają.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Sprawdzenie budowy tabeli",
        summary: "Znaleźć wiersze o złej liczbie kolumn i komórki o złym typie — to najpierw.",
        keywords: ["sprawdzić", "liczba kolumn", "zły typ", "popsute dane"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                To właśnie należy uruchomić **przed** wszystkim innym na pliku, który ktoś wam przysłał. \
                Odpowiada na dwa pytania:
                """),
            .bullets([
                "**Które wiersze mają złą liczbę kolumn?** Zwykle komórka z przecinkiem bez cudzysłowów — i rozstraja każdy kolejny wiersz.",
                "**Które komórki mają typ inny niż reszta ich kolumny?** Na przykład `n/a` w kolumnie liczb.",
            ]),
            .paragraph("Wyniki pojawiają się jako lista; kliknijcie któryś, żeby skoczyć do tego wiersza."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Usuwanie kolumn",
        summary: "Wyjąć z pliku jedną albo więcej kolumn na dobre.",
        keywords: ["usunąć kolumnę", "wyjąć kolumnę"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Wybierzcie z listy kolumny do odrzucenia i zastosujcie. To **jeden** krok cofnięcia, ile by \
                plik nie miał wierszy.
                """),
            .warning("""
                W odróżnieniu od filtrowania to **zmienia prawdziwy plik**. Żeby tylko ukryć kolumny, \
                użyjcie zapytania SQL wyliczającego te, których chcecie.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Odpytywanie CSV w SQL",
        summary: "Pełny SQL DuckDB, wykonywany wprost na otwartym pliku — tylko do odczytu.",
        keywords: ["sql", "zapytanie", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Otwarta tabela nazywa się **`t`**. Silnikiem jest **DuckDB**, więc `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, funkcje okna i podzapytania — wszystko działa.
                """),
            .code(language: "sql", caption: "Przychód wedle prowincji, od największego",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Filtrowanie po dacie i po warunku tekstowym",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Udział każdej prowincji w całości — z funkcją okna",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Złączenie z innym plikiem na dysku",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Tylko do odczytu, i to twarda obietnica"),
            .bullets([
                "Baza mieszka **w pamięci**; plik źródłowy jest wyłącznie czytany.",
                "Przyjmowana jest dokładnie **jedna instrukcja** i **musi to być `SELECT`**. Cała reszta — łącznie z `COPY … TO 'plik'`, którego DuckDB doskonale może użyć do zapisu na dysk — jest blokowana, zanim w ogóle dotrze do danych.",
            ]),
            .warning("""
                DuckDB czyta **pliki**, a nie pamięć. Jeśli dokument ma niezapisane zmiany, GEditor musi \
                przed zapytaniem zapisać kopię tymczasową. Przy bardzo dużym pliku z niezapisanymi zmianami \
                **zatrzymuje się i mówi to**, zamiast po cichu zapisywać setki megabajtów na dysk dla jednego \
                zapytania.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Tabele przestawne i szybkie wykresy",
        summary: "Przestawiać i rysować wprost z wyniku zapytania.",
        keywords: ["tabela przestawna", "wykres", "tabela krzyżowa", "agregat"],
        blocks: [
            .paragraph("""
                Oba otwierają się z **tabeli wyników**: wykonajcie instrukcję SQL, a potem użyjcie przycisku \
                Przestawna albo Wykres w panelu.
                """),
            .heading("Tabela przestawna"),
            .paragraph("""
                Wybierzcie kolumnę **wierszy**, kolumnę **kolumn**, kolumnę **wartości** i agregat (suma, \
                liczność, średnia, min, maks) — jak tabela przestawna w arkuszu.
                """),
            .heading("Wykresy"),
            .paragraph("""
                Słupkowy, liniowy, kołowy, punktowy. Liczby w formacie wietnamskim albo europejskim, a wykres \
                daje się wywieźć jako PNG albo SVG, żeby wkleić gdzie indziej.
                """),
            .note("""
                Chcecie wykres, który **odświeża się razem z danymi** przy każdej przebudowie? To blok \
                `chart` w raporcie `.greport.md`.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Przekształcenie tabeli w inny format",
        summary: "TSV, JSON, XML, tabele Markdown, instrukcje SQL INSERT — z podglądem.",
        keywords: ["przekształcić", "wywieźć", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Format", "Przydatny do"],
                rows: [
                    ["TSV", "Wklejania do arkusza bez martwienia się o przecinki w komórkach"],
                    ["JSON", "Zasilenia API, skryptu albo innego narzędzia"],
                    ["XML", "Starych układów, które żądają XML"],
                    ["Tabela Markdown", "Wklejenia do dokumentacji, pliku README, zgłoszenia"],
                    ["Instrukcje SQL INSERT", "Wczytania do bazy danych"],
                ]
            ),
            .paragraph("""
                Okno **pokazuje wcześniej pierwsze pięć wierszy**, zanim powstanie nowa karta — pięć wierszy \
                wystarczy, żeby potwierdzić nazwę tabeli, cudzysłowy i to, które kolumny stały się liczbami.
                """),
            .note("""
                Podgląd woła **tę samą funkcję**, która wytwarza prawdziwy wynik, ograniczoną do pięciu \
                wierszy. To nie jest naśladownictwo, które mogłoby rozejść się z wynikiem końcowym.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Zmiana znaku rozdzielającego",
        summary: "Przekształcić plik między przecinkiem, średnikiem, tabulatorem a kreską pionową.",
        keywords: ["znak rozdzielający", "przecinek", "średnik", "tabulator", "csv europejski"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Pliki wywiezione z wietnamskiego albo europejskiego Excela zwykle używają **średników**, bo \
                tam przecinek jest znakiem dziesiętnym.
                """),
            .warning("""
                Zmiana znaku rozdzielającego **przepisuje cały plik**. Komórki zawierające nowy znak są \
                ujmowane w cudzysłów — inaczej budowa tabeli się rozpada.
                """),
            .note("""
                **Jeśli rozpoznanie było błędne, to nie jest polecenie, którego chcecie.** Są tu dwa różne \
                zadania, dokładnie jak w parze kodowania «zinterpretuj na nowo» / «przekształć»:

                • *Plik naprawdę jest rozdzielony średnikami, a my zgadliśmy przecinek* — kliknijcie człon \
                `CSV · …` na **pasku stanu** i wybierzcie właściwy. Nie zmienia się ani bajt pliku; zmienia \
                się tylko sposób jego czytania.

                • *Plik naprawdę jest rozdzielony przecinkami, a wy chcecie średników* — użyjcie polecenia z \
                tej strony. Ono przepisuje plik.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Czyszczenie

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Czyszczenie danych — cały przebieg",
        summary: "Od surowego pliku, który ktoś przysłał, do użytecznej tabeli, i norma do powtarzania co miesiąc.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Przebieg czyszczenia, od początku do końca",
        summary: "Sześć kroków od nieznanego pliku do tabeli godnej zaufania i norma na przyszły miesiąc.",
        keywords: ["czyszczenie", "przebieg", "normalizować", "czyste dane"],
        blocks: [
            .paragraph("""
                Czyszczenie danych **rzadko bywa jednorazowe**. Ludzie dostają co miesiąc ten sam wzór \
                raportu i co miesiąc trzeba tak samo znormalizować te same kolumny. Ten przebieg jest do tego \
                stworzony: robicie to raz ręcznie, a potem powtarzacie jednym poleceniem.
                """),
            .heading("Sześć kroków"),
            .steps([
                "**Najpierw obejrzyjcie budowę.** `CSV ▸ Sprawdź dane` — które wiersze mają złą liczbę kolumn, które komórki zły typ. To idzie pierwsze, bo jeden rozstrojony wiersz pozbawia sensu każdą późniejszą statystykę.",
                "**Przeczytajcie profil danych.** Dla każdej kolumny: ile pustych komórek, ile różnych wartości, jaki typ, gdzie są wartości odstające. Tu rozumiecie plik, zanim cokolwiek zmienicie.",
                "**Otwórzcie warsztat czyszczenia** (`⇧⌘L`). Rozpoznaje mieszane postacie dat, liczby wietnamskie zmieszane z europejskimi, zabłąkane odstępy, wartości brakujące. **Podgląd przed→po**, a potem zastosowanie.",
                "**Zajmijcie się przybliżonymi powtórzeniami**, jeśli kolumna nazw albo adresów ma odmiany wpisane ręcznie. Tu decydujecie wy; maszyna tylko proponuje.",
                "**Zapiszcie to jako przepis.** Ciąg, który właśnie wykonaliście, zostaje zapisany w nazwanym pliku JSON — ten plik to wasza wiedza o tych danych.",
                "**Napiszcie zestaw zasad jakości** `.gquality.yaml` i oceńcie. Odtąd plik przyszłego miesiąca przechodzi przez przepis i dostaje ocenę, a **brama wiersza poleceń** zwraca kod wyjścia różny od zera, gdy nie przejdzie.",
            ]),
            .heading("Dlaczego taka kolejność"),
            .bullets([
                "Budowa **przed** profilem: statystyki na rozstrojonej tabeli to statystyki o innej kolumnie.",
                "Profil **przed** czyszczeniem: trzeba wiedzieć «2 % pustych», zanim zdecydujecie o wypełnieniu albo odrzuceniu.",
                "Przybliżone powtórzenia **po** normalizacji: `CÔNG TY  A` i `Công ty A` okazują się jednym dopiero wtedy, gdy odstępy i wielkość liter są uporządkowane.",
                "Przepis **przed** zestawem zasad: przepis naprawia, zasady oceniają — ocenianie nienaprawionej tabeli daje tylko niską liczbę, której i tak się spodziewaliście.",
            ]),
            .heading("Po pierwszym razie każdy miesiąc to jedno polecenie"),
            .code(language: "bash", caption: "Wyczyścić, a potem ocenić, zwracając kod wyjścia dla CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Kod wyjścia **0** znaczy zaliczone, **1** niezaliczone, **2** błąd wykonania. \
                `--record-history` dopisuje wiersz do pliku historii, żeby kolejny przebieg mógł porównać \
                odchylenie.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Profil danych",
        summary: "Jeden opis dla każdej kolumny: typ, puste miejsca, różne wartości, rozkład.",
        keywords: ["profil", "statystyka kolumny", "null", "różne"],
        blocks: [
            .paragraph("""
                Profil **opisuje**; nie ocenia. Mówi *«ta kolumna jest w 2 % pusta»*; czy 2 % jest do \
                przyjęcia, należy do zestawu zasad jakości.
                """),
            .table(
                headers: ["Miara", "Jak ją czytać"],
                rows: [
                    ["Typ", "Wywnioskowany z samych danych, a nie z nazwy kolumny"],
                    ["Puste komórki", "Liczba i udział wartości brakujących"],
                    ["Różne wartości", "1 znaczy kolumnę stałą; równe liczbie wierszy — kolumnę kluczową"],
                    ["Min · maks · średnia", "Tylko kolumny liczbowe"],
                    ["Najczęstsze wartości", "Od razu wypatrzyć kod błędu albo nadużywaną wartość domyślną"],
                ]
            ),
            .warning("""
                Liczenie różnych wartości ma próg. Powyżej niego pokazana liczba jest **dolnym \
                ograniczeniem**, a profil **mówi, że to oszacowanie**, zamiast mieszać ją z liczeniami \
                dokładnymi.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Warsztat czyszczenia danych",
        summary: "Siedem normalizacji, zawsze z podglądem, zawsze jeden krok cofnięcia, nigdy zgadywania.",
        keywords: ["czyścić", "normalizować", "daty", "liczby", "wypełnić"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Otworzyć warsztat czyszczenia")]),
            .table(
                headers: ["Operacja", "Co robi"],
                rows: [
                    ["Znormalizuj daty", "Sprowadzić każdą postać daty w kolumnie do jednej"],
                    ["Znormalizuj liczby", "Uporządkować znak dziesiętny i znak grupowania"],
                    ["Obetnij odstępy", "Usunąć je z obu końców; opcjonalnie ścisnąć też wewnętrzne"],
                    ["Zmień wielkość liter", "Ujednolicić wielkość liter w kolumnie"],
                    ["Wypełnij stałą wartością", "Zastąpić puste komórki wartością, którą wpiszecie"],
                    ["Wypełnij z sąsiada", "Wziąć wartość z wiersza wyżej albo niżej"],
                    ["Usuń wiersze z pustymi komórkami", "Odrzucić wiersze, którym brakuje danych"],
                ]
            ),
            .heading("Trzy obietnice całego warsztatu"),
            .bullets([
                "**Zawsze z podglądem.** Tabela przed→po, z liczbą komórek, które się zmienią.",
                "**Jeden krok cofnięcia** na całe przejście, nawet gdy dotyka miliona komórek.",
                "**Sprawozdanie po fakcie**: ile komórek się zmieniło i których nie dało się odczytać.",
            ]),
            .heading("Zasada: nigdy nie zgadywać"),
            .paragraph("""
                Komórka, której nie da się odczytać z pewnością, zostaje **oznaczona i zostawiona w \
                spokoju**. Weźcie `03/04/2026` w kolumnie mieszającej obie konwencje — to 3 kwietnia czy 4 \
                marca? GEditor pyta was o kolejność dzień/miesiąc, zamiast wybierać za was.
                """),
            .warning("""
                Złe znormalizowanie kolumny dat to rodzaj uszkodzenia **niemal niewykrywalny**: liczby nadal \
                wyglądają poprawnie, tyle że to inna data. Dlatego ten warsztat woli odmówić, niż \
                wnioskować.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Przybliżone powtórzenia",
        summary: "Znaleźć ręcznie wpisane odmiany tej samej nazwy — i nigdy nie scalać ich samoczynnie.",
        keywords: ["przybliżone", "powtórzenia", "scalić", "odmiany", "literówki"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — trzy sposoby zapisania \
                jednego klienta. Zwykłe usuwanie powtórzeń nie widzi ich jako tych samych.
                """),
            .steps([
                "Wybierzcie kolumnę do zbadania i próg podobieństwa.",
                "GEditor grupuje bliskie wartości w **skupienia** i pokazuje postać porównawczą.",
                "Dla **każdego skupienia** wy wybieracie wartość do zachowania — albo je pomijacie.",
                "Zastosujcie. Jeden krok cofnięcia.",
            ]),
            .warning("""
                To narzędzie **nigdy nie scala samo z siebie** i nie ma przycisku «scal wszystko». Dwa \
                łańcuchy podobne w 92 % mogą być literówką albo dwiema naprawdę różnymi firmami różniącymi \
                się jednym słowem — maszyna tego nie rozstrzygnie.
                """),
            .paragraph("""
                Złe scalenie dwóch zapisów to **ciche** utracenie danych: żadna komórka nie pustoszeje, żaden \
                wiersz nie czerwienieje, dwa byty po prostu stają się jednym i nikt tego nie zauważa aż do \
                uzgadniania ksiąg.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Przepisy czyszczenia",
        summary: "Zapisać ciąg jako plik JSON i powtórzyć go na danych przyszłego miesiąca.",
        keywords: ["przepis", "powtórzyć", "zautomatyzować", "miesięcznie", "wsad"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Po czyszczeniu zapiszcie kroki jako **przepis**. To czytelny dla człowieka plik JSON, który \
                można trzymać obok danych, wysłać koledze i włożyć do repozytorium, żeby zmiany były \
                odnotowywane.
                """),
            .code(language: "json", caption: "sales-standard.json — skrócony",
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
                Każdy krok da się **wyłączyć** (`enabled`), więc jeden przepis może obsłużyć kilka niemal \
                jednakowych rodzajów plików.
                """),
            .heading("Powtórzenie"),
            .bullets([
                "W programie: `CSV ▸ Wykonaj przepis czyszczenia…`",
                "Z powłoki, na całym katalogu: zobaczcie stronę o wierszu poleceń.",
            ]),
            .code(language: "bash", caption: "Próba na sucho przed jakimkolwiek zapisem — żaden plik nie jest tykany",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Domyślnie wynik zapisywany jest do nowego pliku obok pierwowzoru (`sales-clean.csv`). \
                Nadpisanie pierwowzoru trzeba wyraźnie zażądać przez `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Ocena jakości danych",
        summary: "Sześć wymiarów, jedna ocena od 0 do 100 i każdy wzór wydrukowany, żebyście mogli go przeliczyć.",
        keywords: ["jakość", "ocena", "dqr", "sześć wymiarów"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Różni się od profilu danych w rzeczy zasadniczej: profil **opisuje**, a ocena **osądza wobec \
                normy, którą zadeklarowaliście** w pliku `.gquality.yaml`.
                """),
            .table(
                headers: ["Wymiar", "Co mierzy"],
                rows: [
                    ["Kompletność", "Udział wypełnionych komórek wedle zasad `not_null`"],
                    ["Poprawność", "Udział zdanych zasad postaci, typu, zakresu i wyrażeń regularnych"],
                    ["Jednoznaczność", "Wobec klucza zadeklarowanego w `uniqueness_key`"],
                    ["Spójność", "Zasady międzykolumnowe i międzyplikowe"],
                    ["Dokładność (szacowana)", "Wartości odstające w kolumnach liczbowych, które wskażecie"],
                    ["Aktualność", "Jak stare są dane wobec progu `freshness`"],
                ]
            ),
            .heading("Trzy obietnice co do oceny"),
            .bullets([
                "**Wzór wydrukowany jest w wyniku** — możecie go przeliczyć ręcznie.",
                "**Powtarzalna**: te same dane i te same zasady dają tę samą ocenę. Tylko *Aktualność* zależy od chwili, więc `now` jest **parametrem** i zostaje odnotowany w wyniku.",
                "**Wymiar, którego nie da się ocenić, zostaje pusty wraz z powodem**, nigdy po cichu ze setką.",
            ]),
            .warning("""
                Ta ostatnia obietnica ma znaczenie. Tabela bez zadeklarowanego `uniqueness_key`, której \
                przyznano 100 za «jednoznaczność», to ocena, która kłamie — i kłamie w stronę pochlebną, \
                czyli tę niebezpieczną.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Składnia `.gquality.yaml`",
        summary: "Każdy klucz pliku zasad, wraz z pełnym zestawem, który działa.",
        keywords: ["gquality", "yaml", "zasady", "składnia", "norma danych"],
        blocks: [
            .paragraph("""
                Plik mieszka **obok danych**, a nie w programie: norma danych musi dać się przejrzeć, a \
                przeglądanie to właśnie to, co ludzie robią z normami.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — pełny zestaw zasad",
                  source: """
                    schemaVersion: 1

                    # Wagi sześciu wymiarów. Wymiar nieobecny waży 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Klucz czyniący wiersz jednoznacznym. Bez niego wymiaru «Jednoznaczność»
                    # NIE DA SIĘ ocenić — i suma to powie.
                    uniqueness_key: [ma_don]

                    # Kolumny liczbowe badane pod kątem wartości odstających w «Dokładności (szacowanej)».
                    accuracy_columns: [doanh_thu, so_luong]

                    # Wymiar «Aktualność».
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Ostrzegać, gdy ten przebieg spada wobec poprzedniego.
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
                        max_null_pct: 2          # dopuszcza 2 % pustych
                      # Zasada międzykolumnowa: `col` niepotrzebne
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Zasada międzyplikowa: wartość musi istnieć w innym pliku
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Rodzaje zasad"),
            .table(
                headers: ["Klucz", "Znaczenie", "Wymiar"],
                rows: [
                    ["`not_null: true`", "Komórka musi być wypełniona; `max_null_pct` to luzuje", "Kompletność"],
                    ["`unique: true`", "Żadnych powtórzonych wartości w kolumnie", "Jednoznaczność"],
                    ["`dtype: int\\|float\\|date\\|text`", "Właściwy typ", "Poprawność"],
                    ["`range: { min:, max: }`", "W zakresie liczbowym", "Poprawność"],
                    ["`length: { min:, max: }`", "Długość łańcucha", "Poprawność"],
                    ["`regex: \"…\"`", "Pasuje do wyrażenia regularnego", "Poprawność"],
                    ["`in_set: [ … ]`", "Jedna z podanej listy", "Poprawność"],
                    ["`date_format: \"…\"`", "Właściwa postać daty", "Poprawność"],
                    ["`compare: { a:, op:, b: }`", "Porównać dwie kolumny; `op` to `<` `<=` `=` `>=` `>` `<>`", "Spójność"],
                    ["`foreign_key: { file:, column: }`", "Wartość musi istnieć w innym pliku", "Spójność"],
                    ["`severity: error\\|warn`", "Waga zasady; domyślnie `error`", "—"],
                ]
            ),
            .warning("""
                Źle napisany klucz zasady sprawia, że plik zostaje **odrzucony z komunikatem**, zamiast po \
                cichu pominąć tę zasadę. Ciche pominięcie znaczy, że wierzycie, iż dane sprawdzono wobec \
                zasady, która nigdy nie zadziałała.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Brama jakości w CI",
        summary: "Zatrzymać wadliwe dane w potoku, przy użyciu kodów wyjścia.",
        keywords: ["ci", "brama", "fail-under", "kod wyjścia", "historia", "odchylenie"],
        blocks: [
            .code(language: "bash", caption: "Ocenić i zwrócić kod wyjścia",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Opcja", "Znaczenie"],
                rows: [
                    ["`--quality <plik.yaml>`", "Zestaw zasad, wobec którego się ocenia"],
                    ["`--fail-under <0…100>`", "Poniżej tej oceny to NIEZALICZONE"],
                    ["`--json <plik\\|->`", "Wynik czytelny dla maszyny; `-` pisze na wyjście standardowe"],
                    ["`--record-history`", "Dopisuje wiersz do `sales-standard.history.jsonl`"],
                    ["`--now <RRRR-MM-DD>`", "Ustala datę odniesienia dla *Aktualności*"],
                    ["`--recipe <plik.json>`", "Wyczyścić **w pamięci** przed oceną, bez zapisu pliku"],
                ]
            ),
            .table(
                headers: ["Kod wyjścia", "Znaczenie"],
                rows: [["`0`", "Zaliczone"], ["`1`", "Niezaliczone"], ["`2`", "Błąd wykonania"]]
            ),
            .heading("Dlaczego CI powinno podawać `--now`"),
            .paragraph("""
                Bez tego *Aktualność* porównuje dane z chwilą przebiegu — więc ten sam plik traci punkty w \
                miarę upływu dni, a pewnego ranka potok czerwienieje, choć nikt niczego nie zmienił.
                """),
            .heading("Śledzenie odchylenia"),
            .paragraph("""
                Z `--record-history` każdy przebieg dopisuje wiersz do pliku historii JSONL. Następnym razem \
                progi w bloku `drift:` porównują z najnowszym przebiegiem i ostrzegają, gdy spadek jest zbyt \
                duży.
                """),
            .note("""
                Każdy próg odchylenia jest **domyślnie wyłączony**, poza `warn_on_new_failure`. Ostrzeżenie \
                włączone fabrycznie z liczbą wybraną przez program odzywałoby się u każdego już przy drugim \
                przebiegu — a to, co pierwszego dnia krzyczy «wilk», trzeciego dnia jest ignorowane.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Eksploracja

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Eksploracja danych — cały przebieg",
        summary: "Odchylenia, korelacja, skupienia, prognoza, reguły skojarzeń — i jak je czytać.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Przebieg eksploracji, od początku do końca",
        summary: "Sześć narzędzi, kolejność ich użycia i jedna zasada: bez pomiaru nie ma wniosku.",
        keywords: ["eksploracja", "analiza", "przebieg", "statystyka"],
        blocks: [
            .warning("""
                **Najpierw czyścić, potem eksplorować.** Nieznormalizowana kolumna dat daje błędne prognozy; \
                kolumna liczbowa mieszająca europejskie znaki grupowania daje widmowe wartości odstające. \
                Każde narzędzie poniżej zakłada, że tabela jest czysta.
                """),
            .heading("Kolejność"),
            .steps([
                "**Znaleźć odchylenia** — odpowiada na *«czy jakiś wiersz jest dziwny?»*. Najtańsze i często od razu przydatne.",
                "**Macierz korelacji** — odpowiada na *«która kolumna porusza się z którą?»*. Kieruje wszystkim, co potem.",
                "**Skupienia** — odpowiada na *«ile naturalnych grup tu jest?»*.",
                "**Prognoza** — tylko przy kolumnie czasu i przynajmniej **dwóch pełnych cyklach**.",
                "**Reguły skojarzeń** — tylko dla danych w kształcie koszyka: jedna transakcja na wiersz albo dwie kolumny z numerem transakcji i towarem.",
                "**Eksploracja wedle grup** — powtarza pierwsze trzy **niezależnie w każdej grupie**. Ten krok często odwraca wniosek wyciągnięty z tabeli zbiorczej.",
            ]),
            .heading("Trzy zasady dla całej rodziny"),
            .bullets([
                "**Każdy wynik nosi blok «Metoda»**: algorytm, parametry, ziarno, wzór. Nie da się go wyłączyć — tabela trzech liczb, która nie mówi, skąd się wzięły, nie nadaje się do podjęcia decyzji.",
                "**Bez pomiaru nie ma wniosku.** Za mała próba, zerowa wariancja, macierz osobliwa — GEditor odmawia i mówi dlaczego, zamiast zwracać liczbę, która tylko wygląda poprawnie.",
                "**Wyniki powtarzalne.** Te same dane dają ten sam wynik; wszędzie tam, gdzie potrzebna jest losowość, ziarno odnotowane jest w wyjściu.",
            ]),
            .heading("Od wyniku z powrotem do danych"),
            .paragraph("""
                Każdy panel **oznacza z powrotem w danych źródłowych**: kliknijcie odbiegający wiersz, \
                komórkę korelacji albo regułę skojarzeń, a odpowiednie wiersze zostaną oznaczone w tabeli. Tak \
                przechodzi się od *«coś jest nie tak»* do *«nie tak jest dokładnie w tych wierszach»*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Znajdowanie odbiegających wierszy",
        summary: "Cztery miary, trzy poziomy wagi i wyjaśnienie, dlaczego wiersz jest dziwny.",
        keywords: ["wartość odstająca", "odchylenie", "z-score", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Miara", "Kiedy jej użyć"],
                rows: [
                    ["z-score", "Kolumna ma z grubsza rozkład normalny"],
                    ["IQR", "Kolumna jest skośna z długim ogonem — bezpieczny wybór domyślny"],
                    ["MAD", "Kolumna zawiera już wiele wartości odstających i potrzebuje miary odpornej"],
                    ["Mahalanobis", "**Kilka kolumn naraz** — łapie wiersze dziwne w połączeniu, a nie w żadnej pojedynczej kolumnie"],
                ]
            ),
            .paragraph("""
                Wyniki barwione są wedle **trzech poziomów wagi**, a nie jedną płaską barwą — inaczej wiersz \
                nieco niezwykły nie odróżniałby się od wiersza szalenie niezwykłego.
                """),
            .heading("Wyjaśnienie dlaczego"),
            .paragraph("""
                Dla miary wielokolumnowej GEditor rozkłada wkład każdej kolumny i podaje zdanie w rodzaju \
                *«odbiegający głównie przez połączenie przychód (50 %) × ilość (50 %)»*.
                """),
            .note("""
                Ten odsetek dotyczy *części wyjaśnialnej*, a nie *odległości*. Blok Metoda mówi to tuż pod \
                tabelą.
                """),
            .warning("""
                Kolumna, której IQR albo MAD wynosi zero, sprawia, że miara **odmawia działania**, zamiast \
                dzielić przez coś maleńkiego i dawać ogromny wynik. W przypadku wielokolumnowym, jeśli \
                macierz kowariancji jest osobliwa, GEditor **mówi, którą kolumnę usunąć**, zamiast użyć \
                pseudoodwrotności, żeby «to zadziałało».
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Macierz korelacji",
        summary: "Pearson i Spearman dla każdej pary, z wykresem rozrzutu po kliknięciu.",
        keywords: ["korelacja", "pearson", "spearman", "mapa ciepła", "rozrzut"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Współczynnik", "Co mierzy"],
                rows: [
                    ["Pearson", "Zależność **liniową**"],
                    ["Spearman", "**Dowolną monotoniczną** zależność, także krzywoliniową — liczoną na rangach"],
                ]
            ),
            .paragraph("""
                Kliknijcie komórkę mapy ciepła, żeby zobaczyć wykres rozrzutu tej pary, z prostą regresji i \
                R².
                """),
            .heading("Cztery szczegóły zmieniające odczyt"),
            .bullets([
                "**Wartości równe dostają rangi średnie**, więc przesortowanie tabeli nie zmienia współczynnika Spearmana.",
                "**Puste komórki traktowane są parami**, a `n` każdej komórki stoi wprost w tabeli — `0,93` na 6 wierszach nie znaczy tego, co `0,93` na 6000 wierszy.",
                "**Kolumna stała zwraca pustkę**, a nie 0. Zero znaczy *zmierzone, zależności nie znaleziono*.",
                "**Skala barw jest niebiesko↔pomarańczowa**, a nie czerwono-zielona: 8 % mężczyzn widzi skalę czerwono-zieloną jako jedną szarą masę, przez co `+0,9` i `−0,9` wyglądają tak samo.",
            ]),
            .warning("""
                **Korelacja nie oznacza przyczynowości.** To zdanie rysowane jest **wewnątrz samego \
                wykresu**, więc podróżuje z obrazem, gdy go wywozicie.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Skupianie",
        summary: "k-średnich i DBSCAN, dwa sposoby wyboru k — i ostrzeżenie o skalowaniu.",
        keywords: ["skupienie", "klaster", "kmeans", "dbscan", "sylwetka", "łokieć"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algorytm", "Kiedy go użyć"],
                rows: [
                    ["k-średnich", "Znacie (albo chcecie wypróbować) liczbę skupień; skupienia są w kształcie plam"],
                    ["DBSCAN", "Nie znacie liczby; skupienia mają dowolne kształty; chcecie oddzielić szum"],
                ]
            ),
            .heading("Skalowanie jest domyślnie włączone — i dlaczego"),
            .paragraph("""
                Kolumna `przychód` (w milionach) obok kolumny `ilość` (w sztukach): odległość między dwoma \
                wierszami rozstrzyga niemal w całości ta większa. To nie jest «nieoptymalne» — to **odpowiedź \
                na inne pytanie**. Obowiązujące skalowanie odnotowane jest w wyniku.
                """),
            .heading("Wybór liczby skupień"),
            .bullets([
                "**Sylwetka** — im wyższy wynik, tym lepiej rozdzielone skupienia. Na dużej tabeli **pobiera próbę** (równomiernie rozłożoną, a nie pierwsze 2000 wierszy), a wynik sam ogłasza się oszacowaniem.",
                "**Łokieć** — rysuje sumę kwadratów wewnątrz skupienia wobec k. To **sposób czytania wykresu**, a nie optymalizacja: ta wielkość zawsze spada, gdy k rośnie, więc statystycznie nie istnieje «optymalne k».",
            ]),
            .note("""
                Dla DBSCAN wykres **k-odległości** pomaga wybrać promień: kolano krzywej to zwykle rozsądna \
                wartość początkowa.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Prognozowanie szeregów czasowych",
        summary: "Rozkład na trend i sezonowość, Holt-Winters oraz punkt odniesienia biegnący zawsze obok.",
        keywords: ["prognoza", "szereg czasowy", "sezonowość", "holt-winters", "trend"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Wybierzcie kolumnę czasu i kolumnę wartości. GEditor rozkłada szereg na **trend · sezonowość \
                · resztę**, a potem prognozuje metodą Holta-Wintersa (addytywną albo multiplikatywną), z \
                przedziałami 80 % i 95 %.
                """),
            .heading("Punkt odniesienia biegnie zawsze i wprost mówi, kto wygrał"),
            .paragraph("""
                Obok modelu GEditor wykonuje dwie metody naiwne: *weź poprzedni okres* i *weź ten sam okres \
                zeszłego sezonu*. Jeśli model **przegrywa** z punktem odniesienia, to zdanie pojawia się w \
                **pierwszym wierszu, inną barwą** — a nie pod tabelą liczb.
                """),
            .paragraph("""
                Powód: narzędzia prognostyczne mają skłonność do przedstawiania modelu jako faktu, a \
                użytkownik nie ma jak się dowiedzieć, że «wziąć po prostu liczbę z zeszłego miesiąca» byłoby \
                dokładniejsze.
                """),
            .heading("Trzy miejsca, gdzie GEditor odmawia albo się deklaruje"),
            .bullets([
                "**Bez dwóch pełnych cykli wraca do metody naiwnej.** Dopasowanie sezonowości do szumu jednego cyklu i powtórzenie go w przyszłość daje prognozę bardzo przekonującą i całkiem wymyśloną.",
                "**Gdy MAPE trafia na zero, mówi to**, a jeśli ponad 25 % okresów jest zerowych, wstrzymuje tę miarę — ciche ich pominięcie daje liczbę policzoną na podzbiorze systematycznie obciążonym.",
                "**Przedział ufności ogłasza się przybliżonym** i mówi, że przy dalekich horyzontach poszerza się zbyt wolno.",
            ]),
            .note("""
                Okres sezonowy rozpoznawany jest na **pierwszej różnicy**, a nie na surowym szeregu: trend \
                sprawia, że każde opóźnienie jest silnie skorelowane, i topi szczyt sezonowy.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Reguły skojarzeń",
        summary: "Kupuje A, często kupuje też B — i dlaczego tabela sortowana jest po podniesieniu, a nie po ufności.",
        keywords: ["apriori", "reguły skojarzeń", "koszyk", "lift", "wsparcie"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Przyjmowane są dwa kształty danych:"),
            .bullets([
                "**Jeden koszyk na wiersz** — kolumna zawierająca listę towarów.",
                "**Dwie kolumny** — numer transakcji i towar, po jednym towarze na wiersz.",
            ]),
            .table(
                headers: ["Miara", "Znaczenie"],
                rows: [
                    ["wsparcie", "Udział koszyków zawierających obie strony"],
                    ["ufność", "Wśród koszyków z lewą stroną, jaki udział ma prawą"],
                    ["**podniesienie (lift)**", "Ufność podzielona przez częstość podstawową prawej strony"],
                    ["leverage", "Odstęp od tego, co przewidywałaby niezależność"],
                ]
            ),
            .heading("Sortowane po podniesieniu, a nie po ufności"),
            .paragraph("""
                Jeśli prawa strona i tak występuje w 95 % koszyków, to **każda** reguła do niej prowadząca ma \
                około 95 % ufności — nie mówiąc przy tym absolutnie nic. Sortowanie po ufności wypycha na \
                górę właśnie reguły najbardziej pozbawione sensu.
                """),
            .warning("""
                `lift < 1` jest **oznaczane w samym wierszu**: 80 % ufności ku czemuś o częstości podstawowej \
                95 % znaczy zależność **odwrotną** — poprawna liczba prowadząca do błędnego wniosku.
                """),
            .bullets([
                "Kupno dwóch kartonów mleka to nadal **jedna** transakcja z mlekiem: powtórzenia w obrębie koszyka są odrzucane, inaczej wsparcie puchnie wraz z ilością.",
                "Zbyt niski próg wsparcia sprawia, że zbiór kandydatów wybucha kombinatorycznie; po dobiciu do pułapu GEditor **zatrzymuje się i ogłasza tabelę niepełną**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Eksploracja wedle grup",
        summary: "Powtórzyć analizę niezależnie dla każdej grupy — krok najczęściej odwracający wniosek.",
        keywords: ["wedle grup", "simpson", "oddziały", "porównać grupy"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Wybierzcie kolumnę tekstową jako klucz grupowania. Każda grupa dostaje odchylenia, prognozę i \
                korelację wykonane **całkiem niezależnie**, a potem uszeregowane wedle kryterium, które \
                wybierzecie.
                """),
            .heading("Dlaczego grupy trzeba rozdzielać, a nie zbierać razem"),
            .paragraph("""
                Dwa oddziały, jeden w okolicach 10, drugi w okolicach 100. Ogrodzenie wartości odstających \
                policzone na tabeli **zbiorczej** wypada w okolicach ±135 — i chybia **w obie strony**:
                """),
            .bullets([
                "**Fałszywe zaprzeczenia**: wartość 20, dla małego oddziału jawnie odbiegająca, mieści się dobrze wewnątrz wspólnego ogrodzenia. Im więcej grup, tym bardziej ślepe.",
                "**Fałszywe potwierdzenia**: grupie mocno rozrzuconej wspólne ogrodzenie ucina normalny ogon, i mnóstwo zwyczajnych wierszy zostaje oznaczonych.",
            ]),
            .heading("Kolumna «rozbieżność korelacji» łapie paradoks Simpsona"),
            .paragraph("""
                Trzy grupy, w których **każda** grupa koreluje swoje dwie kolumny na `−1`, a jednak zebrane \
                razem korelują na `> 0,9`. Kto czyta tylko tabelę zbiorczą, wnioskuje **dokładnie odwrotnie**. \
                Ta kolumna wskazuje właśnie takie przypadki.
                """),
            .note("""
                Panel podaje jako klucz grupowania wyłącznie **kolumny tekstowe** i zatrzymuje się przy 1000 \
                grup z ostrzeżeniem — żeby nie dało się wybrać kolumny numerów zamówień i zamienić każdego \
                wiersza we własną grupę.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Eksploracja tekstu",
        summary: "n-gramy i TF-IDF na kolumnie tekstowej — znaleźć zwroty charakterystyczne.",
        keywords: ["eksploracja tekstu", "n-gram", "tf-idf", "słowa kluczowe", "zwroty"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Działa na jednej kolumnie tekstowej — opisy towarów, opinie klientów, pola uwag.
                """),
            .bullets([
                "**n-gramy** — najczęstsze zwroty jedno-, dwu- i trzywyrazowe.",
                "**TF-IDF** — wyrazy **charakterystyczne** dla każdej grupy dokumentów, czyli częste tutaj, a rzadkie gdzie indziej.",
            ]),
            .paragraph("""
                Różnica: n-gramy mówią wam *«co klienci wciąż wymieniają»*, a TF-IDF mówi *«czym ta grupa \
                różni się od pozostałych»*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
