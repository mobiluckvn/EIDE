import Foundation

/// Polska treść pomocy — część 1: pierwsze kroki i edycja.
///
/// **Identyfikatory `id` tematów NIGDY nie są tłumaczone.** To na nie wskazuje `.seeAlso`, to je
/// otwiera menu i dzięki nim okno pomocy może zmienić język **bez odsyłania czytelnika do spisu
/// treści**. Zmiana identyfikatora zrywa wszystkie odsyłacze — we wszystkich księgach naraz.
///
/// Nazwy poleceń w `commands:` pozostają po wietnamsku: muszą co do słowa odpowiadać prawdziwym
/// pozycjom menu, które `HelpCoverage` sprawdza właśnie po tym łańcuchu znaków.
enum HelpPL {}

extension HelpPL {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Pierwsze kroki",
        summary: "Co robi GEditor i na co poświęcić pierwsze pięć minut.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Czym jest GEditor",
        summary: "Edytor tekstu i danych w skali gigabajtów dla macOS, mówiący po wietnamsku.",
        keywords: ["wprowadzenie", "witamy", "przegląd", "o programie"],
        blocks: [
            .paragraph("""
                GEditor otwiera **plik o wielkości 1 GB, nie wczytując 1 GB do pamięci**. Czyta przez \
                przesuwane okno na pliku odwzorowanym w pamięci, więc dziennik o 200 milionach wierszy \
                albo CSV o milionie wierszy otwiera się w około sekundę i płynnie się przewija.
                """),
            .paragraph("""
                Poza edycją jest to **warsztat do danych**: oglądać CSV jako tabelę, czyścić ją, oceniać \
                jakość, odpytywać w SQL, szukać w niej odchyleń i tendencji, a potem sporządzić raport. \
                Czyta też dawne kodowania wietnamskie, o których większość dzisiejszych narzędzi \
                zapomniała.
                """),
            .heading("Sześć rzeczy, które warto wypróbować najpierw"),
            .table(
                headers: ["Zadanie", "Dokąd pójść"],
                rows: [
                    ["Otworzyć duży plik bez czekania", "Przeciągnąć go do okna — zob. «Otwieranie dużych plików»"],
                    ["Zmienić wiele miejsc naraz", "`⌘D` dokłada kolejne wystąpienie, potem pisze się raz"],
                    ["Szukać wyrażeniem regularnym", "`⌘F`, włączyć Regex — silnikiem jest PCRE2 z JIT"],
                    ["Oglądać CSV jako tabelę", "`⌥⌘T` — milion wierszy nadal przewija się płynnie"],
                    ["Uporządkować bałaganiarską tabelę", "`⇧⌘L` warsztat czyszczenia — podgląd przed zastosowaniem"],
                    ["Otworzyć wietnamski plik wyglądający jak krzaki", "Kliknąć kodowanie na pasku stanu"],
                ]
            ),
            .note("""
                Przechodzicie z Notepad++? Jest strona porównująca oba układy klawiszy, bo kilka klawiszy \
                **zamienia się miejscami** w macOS, zamiast tylko zamienić `Ctrl` na `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Pierwsze pięć minut",
        summary: "Dwanaście skrótów pokrywa większość codziennej pracy.",
        keywords: ["skrót", "klawisze", "start", "podstawy"],
        blocks: [
            .paragraph("""
                Nie trzeba uczyć się wszystkiego. Dwanaście klawiszy poniżej pokrywa większość codziennej \
                pracy; resztę sprawdzicie, gdy będzie potrzebna.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Otworzyć plik"),
                HelpShortcut("⇧⌘O", "Otworzyć cały katalog jako przestrzeń roboczą"),
                HelpShortcut("⌘T", "Nowa karta"),
                HelpShortcut("⌘S", "Zapisać"),
                HelpShortcut("⌘F", "Szukać"),
                HelpShortcut("⌥⌘F", "Szukać i zamieniać"),
                HelpShortcut("⇧⌘F", "Szukać w katalogu"),
                HelpShortcut("⌘D", "Dodać kolejne wystąpienie do zaznaczenia"),
                HelpShortcut("⌘L", "Przejść do wiersza"),
                HelpShortcut("⌘/", "Zakomentować wiersz składnią samego języka"),
                HelpShortcut("⌥⌘T", "Przełączać tabelę i tekst (pliki CSV)"),
                HelpShortcut("⌘?", "Otworzyć to okno pomocy ponownie"),
            ]),
            .heading("Trzy rzeczy, które zaskakują nowych"),
            .bullets([
                "**Operacja masowa to JEDEN krok cofnięcia**, choćby dotknęła miliona wierszy. Źle posortowane? Jedno `⌘Z` i po sprawie.",
                "**Sesja odtwarza się sama.** Zamknijcie i otwórzcie ponownie: karty wracają na swoje miejsca, także te niezapisane. Nic nie trzeba naciskać.",
                "**Pisanie bez znaków diakrytycznych i tak znajduje wyrazy z nimi** w każdym polu wyszukiwania i filtra — wpiszcie `hue`, a dostaniecie `Huế`, `da nang` — `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Co chcecie zrobić?",
        summary: "Tabela prowadząca od prawdziwych zadań do rozdziału, który je omawia.",
        keywords: ["indeks", "szukać", "jak zrobić"],
        blocks: [
            .paragraph("""
                Spis treści po lewej jest ułożony według **funkcji**. Ta tabela jest ułożona według \
                **zadania**, bo te dwa porządki się nie pokrywają.
                """),
            .table(
                headers: ["Muszę…", "Zobacz"],
                rows: [
                    ["Zmienić to samo miejsce w setkach wierszy", "Wiele karetek · Zaznaczanie blokowe"],
                    ["Masowo przeformatować wyrażeniem regularnym", "Szukaj i zamień · Wyrażenia regularne"],
                    ["Powtórzyć ciąg czynności", "Makra"],
                    ["Otworzyć CSV, który ktoś mi przysłał", "Tabela CSV"],
                    ["Uporządkować bałaganiarską tabelę: mieszane daty, liczby jako tekst", "Przebieg czyszczenia danych"],
                    ["Ocenić, czy tabeli można ufać", "Ocena jakości danych"],
                    ["Znaleźć odchylenia, tendencje, skupienia", "Przebieg eksploracji danych"],
                    ["Zadawać pytania w SQL", "Odpytywanie CSV w SQL"],
                    ["Opublikować raport, którego liczby się odświeżają", "Raporty `.greport.md`"],
                    ["Narysować schemat w dokumencie", "Mermaid"],
                    ["Otworzyć nieczytelny wietnamski plik", "Kodowania wietnamskie"],
                    ["Zautomatyzować z powłoki lub AppleScript", "Automatyzacja"],
                    ["Pokolorować format wymyślony przez moją firmę", "Języki definiowane przez użytkownika"],
                ]
            ),
            .note("""
                Nie ma na liście? Pole wyszukiwania w lewym górnym rogu zagląda w **tekst i przykłady \
                kodu**, więc wpisanie klucza konfiguracji w rodzaju `fail_under` prowadzi na właściwą \
                stronę.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Otwieranie dużych plików",
        summary: "Dlaczego 1 GB w ogóle się otwiera i gdzie GEditor celowo odmawia zamiast zgadywać.",
        keywords: ["duży plik", "gigabajt", "dziennik", "mmap", "wolno", "wydajność"],
        blocks: [
            .paragraph("""
                Plik jest **odwzorowany w pamięci** i czytany przez przesuwane okno; część, którą \
                edytujecie, mieszka w piece table. W praktyce: czas otwierania prawie nie zależy od \
                wielkości pliku, a zajęta pamięć również nie.
                """),
            .heading("Gdzie odmawia celowo"),
            .paragraph("""
                Kilka obliczeń musiałoby wczytać cały plik do jednego łańcucha znaków — dokładnie tego ta \
                architektura unika. Tam GEditor **mówi, że tego nie zrobi**, zamiast po cichu się wlec \
                albo zgadywać:
                """),
            .table(
                headers: ["Operacja", "Granica", "Powyżej"],
                rows: [
                    ["Dopasowanie nawiasów", "1 MB", "Odmawia i mówi to — podświetlenie złej pary jest gorsze niż żadne"],
                    ["Kolumna wzrokowa na pasku stanu", "200 KB", "Wraca do liczenia bajtów i znaczy to `~`, żeby znaczenie było widoczne"],
                    ["Podgląd Markdown", "4 MB", "Odmawia i wyjaśnia"],
                ]
            ),
            .warning("""
                Liczba, która wygląda tak samo, ale znaczy co innego, to najgorszy rodzaj błędu. Dlatego \
                kolumna powyżej granicy czyta się `~1234`, a nie `1234`.
                """),
            .heading("Wskazówki do plików dziennika"),
            .bullets([
                "`Plik ▸ Śledź plik (tail -f)` wciąga to, co dopisywane jest na końcu. Dokument staje się **tylko do odczytu** na czas śledzenia — pisanie, gdy napływa nowy tekst, to dwaj piszący spierający się o jeden dokument, a przegranym zawsze jest to, co właśnie napisaliście.",
                "Wiersze dziennika są **kolorowane według wagi** i można je filtrować po poziomie.",
                "**Mapa dokumentu** (`⌥⌘M`) opisuje cały plik, a nie tylko część na ekranie.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "Wydanie z App Store a pobranie bezpośrednie",
        summary: "Trzy funkcje, które ma tylko wydanie bezpośrednie, i dlaczego.",
        keywords: ["app store", "piaskownica", "pobranie", "cli", "wtyczka", "różnica"],
        blocks: [
            .paragraph("""
                GEditor ukazuje się w dwóch wydaniach. Pochodzą z **tego samego kodu źródłowego**, a \
                program rozpoznaje przy starcie, którym jest. Różnica polega na tym, co pozwala App \
                Sandbox.
                """),
            .table(
                headers: ["Funkcja", "App Store", "Pobranie bezpośrednie"],
                rows: [
                    ["Cała edycja, CSV, czyszczenie, eksploracja, raporty", "Tak", "Tak"],
                    ["Narzędzie wiersza poleceń `geditor`", "Nie", "Tak"],
                    ["Filtrowanie tekstu przez polecenie zewnętrzne", "Nie", "Tak"],
                    ["Wtyczki natywne (osobny proces)", "Nie", "Tak"],
                    ["Samodzielna aktualizacja", "Przez App Store", "W programie"],
                ]
            ),
            .paragraph("""
                Każde «Nie» powyżej wynika z tej samej zasady: piaskownica **zabrania uruchamiać kod poza \
                programem**. To cena dystrybucji przez App Store, a nie przeoczenie.
                """),
            .note("""
                W wydaniu z App Store te polecenia **pozostają w menu** i wyjaśniają, dlaczego są \
                niedostępne, zamiast znikać. Brakująca pozycja menu staje się pytaniem do wsparcia; \
                odpowiedź na miejscu — nie.
                """),
            .heading("Dostęp do plików w wydaniu z App Store"),
            .paragraph("""
                Wydanie w piaskownicy dotyka tylko plików, które sami otworzyliście lub przeciągnęliście. \
                GEditor przechowuje **zakładkę o zasięgu bezpieczeństwa** dla każdej karty i dla katalogu \
                przestrzeni roboczej, dzięki czemu wasza sesja otwiera się po zamknięciu bez ponownego \
                pytania o pozwolenie.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Edycja

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Edycja",
        summary: "Zmieniać wiele miejsc naraz, pracować na wierszach i ukryte zasady, które warto poznać najpierw.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Wiele karetek",
        summary: "Zaznaczyć każde pasujące miejsce, napisać raz, zmienić wszystkie.",
        keywords: ["wiele kursorów", "cmd+d", "zaznaczenie wielokrotne"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                To zastępuje większość chwil, w których zamierzaliście napisać wyrażenie regularne. \
                Zaznaczcie słowo, naciśnijcie kilka razy `⌘D`, żeby zebrać kolejne wystąpienia, i \
                piszcie — wszystkie miejsca zmieniają się naraz.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Dodać kolejne wystąpienie do zaznaczenia"),
                HelpShortcut("⌘ + kliknięcie", "Postawić kolejną karetkę w miejscu kliknięcia"),
                HelpShortcut("Esc", "Porzucić wszystkie, wrócić do jednej karetki"),
                HelpShortcut("⌥ + przeciąganie", "Zaznaczenie blokowe (inny sposób na wiele karetek)"),
            ]),
            .heading("Zasady, które warto znać"),
            .bullets([
                "Pisanie, kasowanie i wklejanie na wielu karetkach to **jeden** krok cofnięcia, a nie jeden na karetkę.",
                "Karetki przeżywają ruch strzałkami — cała grupa przesuwa się razem.",
                "`⌘D` omija miejsca już w zaznaczeniu, więc nadmierne naciskanie nigdy nie piętrzy dwóch karetek na sobie.",
            ]),
            .note("""
                `⌘D` na słowie w długim łańcuchu znaków bywało wolne. Wykrywanie granic wyrazów czyta \
                teraz partiami — około **42× szybciej** przy łańcuchu 1 MB, co czyni to użytecznym w \
                plikach danych, a nie tylko w kodzie źródłowym.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Zaznaczanie blokowe kolumn",
        summary: "Zaznaczyć prostokąt w wielu wierszach — myszą albo z klawiatury.",
        keywords: ["tryb kolumnowy", "blok", "alt przeciąganie", "prostokąt", "klawiatura", "strzałki"],
        blocks: [
            .paragraph("""
                Przytrzymajcie `⌥` i przeciągnijcie, żeby zaznaczyć **blok prostokątny**. Pisanie, \
                kasowanie i wklejanie idą za blokiem. Wklejenie bloku przy jednej karetce zachowuje jego \
                prostokąt.
                """),
            .shortcuts([
                HelpShortcut("⌥ + przeciąganie", "Zaznaczyć blok"),
                HelpShortcut("⌥⌘← →", "Poszerzyć blok o kolumnę w lewo/prawo"),
                HelpShortcut("⌥⌘↑ ↓", "Rozciągnąć blok o wiersz w górę/dół"),
            ]),
            .paragraph("""
                Droga klawiaturowa nie jest namiastką myszy: zaznaczanie bloku 40 wierszy przeciąganiem \
                zmusza do przeciągania przez przewijanie, podczas gdy `⌥⌘` + strzałki utrzymuje precyzję \
                kolumna po kolumnie. Naciśnięcie **dowolnego innego** klawisza (lub pisanie) kończy blok, \
                który rozciągaliście.
                """),
            .heading("Tutaj kolumny to kolumny WZROKOWE"),
            .paragraph("""
                Tabulator rozciąga się do następnego przystanku wedle waszej szerokości tabulatora, \
                zamiast liczyć się za jedną kolumnę. To właśnie sprawia, że wiersze wcięte tabulatorami i \
                spacjami **układają się tak, jak wyglądają na ekranie**.
                """),
            .paragraph("Tekst wielobajtowy nadal jest jedną kolumną: `Nguyễn` zajmuje sześć kolumn, nie dziewięć."),
            .table(
                headers: ["Sytuacja", "Co robi GEditor"],
                rows: [
                    ["Kolumna docelowa wypada w środku tabulatora", "Przyciąga do bliższej krawędzi; przy remisie w lewo"],
                    ["Wiersz jest krótszy niż kolumna początkowa", "Ten wiersz wnosi puste zaznaczenie i mimo to przyjmuje pisany tekst"],
                    ["Wklejenie bloku przy jednej karetce", "Zachowuje prostokąt i wstawia w wiersze poniżej"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Edytor kolumn",
        summary: "Wstawić tekst, serię liczb albo serię dat w każdy wiersz bloku.",
        keywords: ["edytor kolumn", "numerowanie", "sekwencja", "seria"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Zaznaczcie blok kolumnowy i otwórzcie `Edycja ▸ Edytor kolumn…` (`⌥⌘C`). Okno ma \
                **podgląd**, zanim cokolwiek zostanie zastosowane.
                """),
            .table(
                headers: ["Tryb", "Parametry", "Kiedy"],
                rows: [
                    ["Tekst", "Stały łańcuch znaków", "Dodać ten sam przedrostek/przyrostek do każdego wiersza"],
                    ["Seria liczb", "Początek · krok · podstawa 2·8·10·16 · zera wiodące", "Ponumerować wiersze, wygenerować kody"],
                    ["Seria dat", "Pierwsza data · krok w dniach", "Wytworzyć kolumnę kolejnych dat"],
                ]
            ),
            .code(language: "text", caption: "Numerowanie z zerami wiodącymi, początek 1, krok 1",
                  source: """
                    Przed:            Po (seria liczb, 3 cyfry):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Krok **ujemny** jest dozwolony — liczenie wstecz działa.",
                "Wstawienie w 5000 wierszy nadal jest **jednym** krokiem cofnięcia.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Operacje na wierszach",
        summary: "Sortować, usuwać powtórzenia, przenosić, łączyć, dzielić, powielać, kasować.",
        keywords: ["sortować", "powielać", "łączyć", "dzielić", "przenieść wiersz"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Przy zaznaczeniu polecenie działa na zaznaczeniu; bez niego działa na **całym \
                dokumencie**. Każde polecenie stąd to jeden krok cofnięcia.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Powielić wiersz"),
                HelpShortcut("⌘K", "Skasować wiersz"),
                HelpShortcut("⌥↑ / ⌥↓", "Przenieść wiersz w górę / w dół"),
            ]),
            .heading("Trzy rodzaje sortowania i który wybrać"),
            .table(
                headers: ["Rodzaj", "`file2` a `file10`", "Do"],
                rows: [
                    ["A→Z / Z→A", "`file10` idzie przed `file2`", "Prostych list słów"],
                    ["Naturalne", "`file2` idzie przed `file10`", "Nazw plików, oznaczeń, wersji"],
                ]
            ),
            .paragraph("""
                Sortowanie **naturalne** czyta ciągi cyfr jak liczby. To prawie zawsze to, czego chcecie, \
                gdy lista jest ponumerowana.
                """),
            .heading("Usuwanie powtórzeń"),
            .bullets([
                "**Cały dokument** — odrzuca każdy wiersz, który pojawił się wcześniej, i zachowuje pierwszy.",
                "**Tylko sąsiadujące** — scala jednakowe sąsiednie wiersze, jak uniksowy `uniq`.",
            ]),
            .heading("Łączenie i dzielenie"),
            .bullets([
                "**Połącz wiersze** scala zaznaczone wiersze w jeden.",
                "**Podziel po długości** tnie długie wiersze przy zadanej liczbie znaków.",
                "**Podziel po znaku** tnie przy każdym wystąpieniu znaku, który wpiszecie — na przykład żeby rozbić wiersz CSV na komórki.",
            ]),
            .note("""
                Powielenie **ostatniego wiersza** pliku dokłada brakujący znak końca wiersza; kasowanie do \
                końca dokumentu połyka też koniec wiersza poprzedniego. Oba odbiegają od naiwnej realizacji \
                i oba istnieją po to, by plik nie skończył się zbędnym pustym wierszem — ani bez tego, \
                który był potrzebny.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Odstępy i wcięcia",
        summary: "Uprzątnąć zabłąkane odstępy, zamienić tabulator ↔ spację i jeden przełącznik do przemyślenia.",
        keywords: ["odstępy", "tabulator", "wcięcie", "puste wiersze"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Polecenie", "Co robi"],
                rows: [
                    ["Usuń puste wiersze", "Odrzuca każdy wiersz bez treści"],
                    ["Ściśnij kolejne puste wiersze", "Kilka pustych wierszy z rzędu staje się jednym"],
                    ["Obetnij odstępy na końcu wiersza", "Usuwa zabłąkane spacje i tabulatory na końcu każdego wiersza"],
                    ["Tabulator → Spacja", "Zamienia tabulatory na spacje przy bieżącej szerokości"],
                    ["Spacja → Tabulator", "Kierunek odwrotny"],
                ]
            ),
            .heading("Wcięcie osobne dla każdego języka"),
            .paragraph("""
                Kliknijcie `Tab: 4` na pasku stanu. Górna część menu zmienia je dla **całego programu**; \
                dolna — `Tylko dla Go`, `Tylko dla Pythona`… — dotyczy wyłącznie języka otwartego pliku i \
                pamięta, czy używać tabulatorów, czy spacji.
                """),
            .paragraph("""
                Ludzie nie wybierają wcięcia z upodobania, lecz według **zwyczaju wspólnoty**: Go używa \
                tabulatorów (`gofmt` przeważa nad wszystkim innym), Python czterech spacji wedle PEP 8, \
                JavaScript i YAML zwykle dwóch. Jedna liczba dla wszystkich języków sprawia, że każdy plik, \
                którego dotkniecie, zyskuje wiersze, których nigdy nie edytowaliście.
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
                Zadeklarowanie tego w `settings.json` też działa — kluczem jest kod języka (`go`, `python`, \
                `javascript`…). Języki tam nieobecne używają wspólnego `tabWidth`.
                """),
            .heading("Dlaczego «obcinanie przy zapisie» jest domyślnie WYŁĄCZONE"),
            .paragraph("""
                Przełącznik `Plik ▸ Obcinaj odstępy na końcu przy zapisie` edytuje **wiersze, których nigdy \
                nie dotknęliście**. Włączony domyślnie zamienia poprawkę jednego słowa w cudzym repozytorium \
                w różnicę na tysiąc wierszy, a recenzent nie znajduje już prawdziwej zmiany.
                """),
            .paragraph("""
                Gdy jest włączony, obcięcie jest **osobnym krokiem cofnięcia** umieszczonym przed zapisem — \
                jedno cofnięcie przywraca dokument do poprzedniego stanu, nie tracąc tego, co właśnie \
                zapisaliście.
                """),
            .heading("Wcięcie samoczynne"),
            .bullets([
                "Nowy wiersz dziedziczy wcięcie poprzedniego, plus jeden poziom po znaku otwierającym — `{` w językach z klamrami, `:` w Pythonie i YAML.",
                "Miara jest w **kolumnach wzrokowych**, więc pliki mieszające tabulatory ze spacjami pozostają wyrównane na ekranie.",
                "**Nie** ma zasady «napisanie `}` ponownie wcina wiersz». Ta zasada edytuje wiersz, który już skończyliście, i jest najczęściej krytykowanym zachowaniem w każdym edytorze, który ją ma.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Wielkość liter i zwyczaje nazewnicze",
        summary: "Osiem przekształceń, w tym camelCase, snake_case i kebab-case.",
        keywords: ["wielkie litery", "małe litery", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Stosowane do zaznaczenia. Wszystkie mieszkają w menu `Format`."),
            .table(
                headers: ["Polecenie", "`tổng doanh thu` staje się"],
                rows: [
                    ["WIELKIE LITERY", "`TỔNG DOANH THU`"],
                    ["małe litery", "`tổng doanh thu`"],
                    ["Każdy Wyraz Wielką Literą", "`Tổng Doanh Thu`"],
                    ["Wielka litera na początku zdania", "`Tổng doanh thu`"],
                    ["Odwróć wielkość", "Odwraca każdy znak"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Trzy ostatnie usuwają wietnamskie znaki diakrytyczne, bo wytwarzają **identyfikatory w \
                kodzie** — gdzie litery ze znakami zwykle nie są dozwolone.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Komentarze i nawiasy",
        summary: "⌘/ używa własnego znacznika każdego języka; ⌃⌘B skacze do pasującego nawiasu.",
        keywords: ["komentarz", "nawias", "cmd+/", "dopasowanie"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` dobiera znacznik komentarza **wedle języka dokumentu**: `#` dla Pythona, `//` dla Rusta \
                i C, `<!-- -->` dla XML i HTML.
                """),
            .heading("Cały blok idzie w jedną stronę"),
            .paragraph("""
                Jeśli choć jeden wiersz bloku jest wciąż bez komentarza, polecenie komentuje **wszystko**. \
                Rozstrzyganie wiersz po wierszu zamieniłoby blok skomentowany do połowy w szachownicę. \
                Znacznik wstawiany jest przy najpłytszym wcięciu bloku, więc blok zachowuje kształt.
                """),
            .heading("Skok do pasującego nawiasu"),
            .bullets([
                "`⌃⌘B` skacze do nawiasu tworzącego parę z tym pod karetką.",
                "Nawiasy wewnątrz **łańcuchów znaków** albo **komentarzy** się nie liczą — lekki analizator je odróżnia.",
                "Powyżej **1 MB** polecenie odmawia i mówi to, zamiast zakotwiczyć się w połowie drogi i zgadywać. Podświetlenie złej pary jest gorsze niż niepodświetlenie żadnej.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Cofanie i schowek",
        summary: "Nieograniczona historia cofnięć i schowek o wielu miejscach.",
        keywords: ["cofnij", "ponów", "schowek", "wklej", "historia"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Cofnij / Ponów"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Wytnij / Kopiuj / Wklej"),
                HelpShortcut("⇧⌘V", "Historia schowka"),
            ]),
            .heading("Operacja masowa to JEDEN krok"),
            .paragraph("""
                Posortowanie miliona wierszy, zamiana dziesięciu tysięcy trafień, wstawienie w pięć tysięcy \
                wierszy edytorem kolumn — każde z nich cofa **jedno** `⌘Z`.
                """),
            .paragraph("""
                Historia cofnięć mieszka we własnym buforze tekstu GEditora, a nie w systemowym \
                `UndoManager`, właśnie dlatego: `UndoManager` liczy naciśnięcia klawiszy.
                """),
            .heading("Historia schowka"),
            .paragraph("""
                `⇧⌘V` otwiera listę tego, co ostatnio skopiowaliście, i wkleja wybraną pozycję. Przydatne, \
                gdy trzeba przeplatać dwa fragmenty w wielu miejscach.
                """),
        ]
    )
}
