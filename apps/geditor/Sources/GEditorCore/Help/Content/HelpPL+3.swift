import Foundation

/// Polska treść pomocy — część 3: sposoby patrzenia, wietnamski, języki i formaty.
extension HelpPL {

    static let views = HelpChapter(
        id: "xem",
        title: "Sposoby oglądania dokumentu",
        summary: "Pasek boczny, mapa, zwijanie, widok podzielony, zawijanie, znaki niewidoczne, tryby barwienia.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Pasek boczny i lista funkcji",
        summary: "Drzewo plików i lista funkcji otwartego pliku, w jednej kolumnie.",
        keywords: ["pasek boczny", "lista funkcji", "konspekt", "drzewo plików"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Pokazać / ukryć pasek boczny")]),
            .paragraph("""
                Lista funkcji budowana jest z **drzewa składniowego** języka, więc idzie za prawdziwą \
                strukturą, zamiast zgadywać ją z wcięć. Kliknijcie pozycję, żeby tam skoczyć.
                """),
            .note("Pole filtra listy **znajduje tekst ze znakami diakrytycznymi, gdy piszecie bez nich**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Mapa dokumentu",
        summary: "Cały plik w wąskiej kolumnie po prawej — nawet przy setkach MB.",
        keywords: ["minimapa", "mapa", "przegląd"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Pokazać / ukryć mapę dokumentu")]),
            .paragraph("""
                Mapa opisuje **cały plik**, a nie tylko to, co jest na ekranie. Przeciąganie po niej skacze \
                do odpowiedniego obszaru.
                """),
            .paragraph("""
                Trafienia wyszukiwania i oznaczone wiersze pojawiają się na mapie, więc widzicie, czy są \
                rozproszone, czy skupione, zanim tam przewiniecie.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Zwijanie",
        summary: "Zwijać funkcje, bloki i tablice wedle struktury — albo zwinąć cały plik do poziomu.",
        keywords: ["zwijać", "code folding", "składać"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Zwinąć / rozwinąć blok przy karetce"),
                HelpShortcut("⌥⇧⌘←", "Zwinąć wszystko"),
                HelpShortcut("⌥⌘→", "Rozwinąć wszystko"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Zwinąć cały plik do poziomu 1…8"),
            ]),
            .paragraph("""
                W językach z drzewem składniowym zwijanie idzie za **prawdziwą strukturą**. W plikach bez \
                gramatyki idzie za wcięciami.
                """),
            .paragraph("""
                `Zwiń do poziomu` zarabia na siebie przy głębokim JSON-ie i YAML-u: zwinięcie do poziomu 2 \
                mieści kształt całego pliku na jednym ekranie.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Widok podzielony",
        summary: "Dwa panele obok siebie, na dwa pliki — albo na dwa miejsca jednego pliku.",
        keywords: ["podział", "panele", "porównać"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Podzielić pionowo"),
                HelpShortcut("⌥⌘-", "Podzielić poziomo"),
                HelpShortcut("⌥⌘0", "Znieść podział"),
                HelpShortcut("⌥⌘]", "Otworzyć tę kartę w drugim panelu"),
                HelpShortcut("⌥⌘[", "Skoczyć do drugiego panelu"),
            ]),
            .paragraph("""
                Każdy panel ma własny pasek kart. Otwarcie **tego samego pliku** w obu jest zupełnie w \
                porządku — przewijają się niezależnie, co ułatwia porównanie początku i końca pliku.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Zawijanie wierszy",
        summary: "Trzy tryby: wyłączone, przy krawędzi okna albo na stałej kolumnie.",
        keywords: ["zawijanie", "miękki podział"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Tryb", "Długi wiersz"],
                rows: [
                    ["Wyłączone", "Przewija się poziomo"],
                    ["Przy oknie", "Zawija się przy krawędzi okna, podążając za jego wielkością"],
                    ["Na kolumnie", "Zawija się na kolumnie, którą ustawicie — powiedzmy 80 albo 100"],
                ]
            ),
            .paragraph("""
                Zawijanie to **sposób patrzenia**, a nie zmiana: żaden znak końca wiersza nie jest \
                wstawiany i nigdy nie trafia to do historii cofnięć.
                """),
            .note("Szybka droga to człon `Ngắt: …` na pasku stanu."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Wielkość pisma",
        summary: "Powiększać między 8 a 32 pt.",
        keywords: ["powiększenie", "wielkość", "większe", "mniejsze"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Większe"),
                HelpShortcut("⌘-", "Mniejsze"),
                HelpShortcut("⌃⌘0", "Wrócić do wielkości domyślnej"),
            ]),
            .paragraph("""
                Ograniczone od 8 do 32 pt. To również **sposób patrzenia**: żadnej zmiany, nic w historii \
                cofnięć. Wielkość domyślna mieszka w `Ustawieniach…`.
                """),
            .note("`⌘0` **nie** jest wielkością domyślną — ten klawisz pokazuje i ukrywa pasek boczny."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Pokazywanie znaków niewidocznych",
        summary: "Po jednej grupie naraz, bo wszystkie razem to zwykle za dużo.",
        keywords: ["niewidoczne", "odstępy", "nbsp", "zerowa szerokość", "tabulator"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Pokazać / ukryć wszystkie znaki niewidoczne")]),
            .paragraph("""
                Cztery grupy włączają się osobno, bo włączenie ich wszystkich naraz grzebie treść pod lasem \
                kropek.
                """),
            .table(
                headers: ["Grupa", "Co łapie"],
                rows: [
                    ["Spacje", "Spacje na końcu wiersza, niespójne wcięcia"],
                    ["Tabulatory", "Pliki mieszające tabulatory ze spacjami"],
                    ["Końce wierszy", "Pliki mieszające CRLF z LF"],
                    ["NBSP · zerowa szerokość · sterujące", "Znaki niewidoczne z Worda, z sieci, z arkuszy"],
                ]
            ),
            .warning("""
                Ostatnia grupa jest tą, która ratuje ludzi. Spacja nierozdzielająca (NBSP) wklejona ze \
                strony internetowej wygląda **dokładnie** jak zwykła spacja, a mimo to sprawia, że każde \
                porównanie łańcuchów i każdy filtr chybia — i nie sposób jej zobaczyć bez włączonej tej \
                grupy.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "Tryb CSV i tryb dziennika",
        summary: "Dwa barwienia zastępujące podświetlanie składni, dla dwóch rodzajów plików z danymi.",
        keywords: ["tryb csv", "tryb dziennika", "podświetlanie", "kolumny", "poziom"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("Tryb CSV"),
            .paragraph("""
                Nadaje każdej kolumnie własną barwę w widoku **tekstowym**, żebyście widzieli, która komórka \
                zsunęła się o kolumnę, bez przechodzenia do tabeli.
                """),
            .heading("Tryb dziennika"),
            .paragraph("""
                Barwi wedle **wagi**, którą odczytuje z wiersza: błędy na czerwono, ostrzeżenia na \
                bursztynowo, a `debug` i `trace` są przygaszone — stanowią większość dziennika, a ich \
                podświetlenie przygasza właśnie to, czego szukacie.
                """),
            .paragraph("`Filtruj dziennik po poziomie…` całkiem ukrywa poziomy, których nie potrzebujecie."),
            .note("""
                Te dwa barwią **zamiast** podświetlania składni, a nie na wierzchu. Dziennik nie ma składni \
                do barwienia, a dwa źródła barwy piszące w ten sam zakres bajtów nie zostawiają \
                przewidywalnego zwycięzcy.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Widok binarny",
        summary: "Tablica szesnastkowa dla dowolnego pliku — nawet dla 1 GB, otwierana niemal natychmiast.",
        keywords: ["hex", "binarny", "bajt", "położenie", "zrzut"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Widok ▸ Widok binarny` pokazuje każdy bajt jako tablicę o trzech kolumnach: **położenie · \
                szesnastkowo · tekst**. Działa dla **dowolnego** pliku na dysku, nie tylko dla obrazów czy \
                wideo.
                """),
            .table(
                headers: ["Kolumna", "Zawartość"],
                rows: [
                    ["Położenie", "Położenie bajtu, szesnastkowo"],
                    ["Szesnastkowo", "16 bajtów w wierszu, rozdzielone po ósmym, żeby łatwiej liczyć"],
                    ["Tekst", "Drukowalne bajty ASCII; cała reszta to `.`"],
                ]
            ),
            .note("""
                Kolumna tekstowa **nie dekoduje UTF-8**. Wietnamska litera zajmuje dwa albo trzy bajty, więc \
                jej wyświetlenie rozjechałoby kolumnę tekstową względem szesnastkowej — a to wyrównanie jest \
                całym sensem tej kolumny. Żeby czytać tekst ze znakami diakrytycznymi, użyjcie zwykłego \
                widoku.
                """),
            .heading("Duże pliki"),
            .paragraph("""
                Plik jest **odwzorowany w pamięci**, więc otwarcie pliku 1 GB w widoku binarnym kosztuje \
                tylko tyle, ile obejrzycie. Zmierzone w zestawie samosprawdzeń: **poniżej milisekundy**.
                """),
            .paragraph("""
                Widok pokazuje **jedno okno 4 MB** naraz, a górny pasek mówi, w jakim zakresie jesteście. To \
                granica systemowego rysownika tablic, a nie czytania: 1 GB to 62,5 miliona wierszy, a powyżej \
                pewnego punktu wiersze zaczynają skakać podczas przewijania — a skacząca tablica \
                szesnastkowa jest bezużyteczna.
                """),
            .heading("Skok do położenia"),
            .table(
                headers: ["Wpiszcie w pole położenia", "Znaczenie"],
                rows: [
                    ["`1F400`", "Szesnastkowo — domyślnie"],
                    ["`0x1F400`", "To samo, z wyraźnym przedrostkiem"],
                    ["`#128000`", "Dziesiętnie, gdy macie liczbę bajtów, a nie położenie szesnastkowe"],
                ]
            ),
            .bullets([
                "`‹` i `›` przechodzą do poprzedniego / następnego okna.",
                "**Skopiuj zaznaczone wiersze** kopiuje dokładnie to, co widzicie — bez zaznaczenia kopiuje całe okno.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Podgląd Markdown",
        summary: "Pokazać Markdown jako sformatowany tekst — i wprost powiedzieć, czego nie pokazuje.",
        keywords: ["markdown", "podgląd", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("Rysowane systemową obsługą Markdown: pogrubienie, kursywa, kod, odsyłacze, listy."),
            .warning("""
                **Bez tabel i bez barw składni w blokach kodu.** Okno podglądu mówi to u dołu. Dokumenty \
                większe niż **4 MB** są odrzucane.
                """),
            .paragraph("""
                Potrzebujecie tabel i wykresów w dokumencie do opublikowania? Do tego służą raporty \
                `.greport.md`, a nie ten podgląd.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Dwa tryby: Widok i Kod",
        summary: "Jeden klawisz przełącza między postacią narysowaną a źródłem do edycji, dla każdego rodzaju pliku.",
        keywords: ["widok", "kod", "tryb", "źródło", "narysowane", "podgląd"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Przełączać między Widokiem a Kodem")]),
            .paragraph("""
                Przełącznik siedzi w **pasku tuż pod kartami** — w tym samym miejscu dla każdego rodzaju \
                pliku: przełącznik `View | Code`, a potem nazwa trybu Widoku dla tego pliku («Strony \
                dokumentu», «Drzewo klucz-wartość», «Schemat»…). Plik mający tylko jeden tryb wyszarza \
                przełącznik, a pasek mówi dlaczego. Przy prawej krawędzi siedzą przyciski właściwe każdemu \
                rodzajowi: `.xlsx` ma **Tabelę** (do edycji, zapisywaną wprost z powrotem), `.pptx` ma \
                **Konspekt**.
                """),
            .note("""
                **Word i PowerPoint zachowują się jak czytnik dokumentów.** Ich tryb Widoku buduje prawdziwe \
                strony — właściwe kroje, wielkości i barwy, z obrazami, tabelami, nagłówkami i stopkami z \
                numerami stron. Strona jest **dokładnie tak szeroka jak ramka** i daje się powiększać. Excel \
                jest celowym wyjątkiem: jego Widok to **arkusz do edycji**, bo arkusz nie ma formatu papieru, \
                dopóki nie zostanie wydrukowany.
                """),
            .note("""
                W zamian strony są **tylko do odczytu** i rysują **kopię z dysku**: zmieńcie coś w Kodzie bez \
                zapisu, a strony pokażą starą wersję — pasek to mówi, wraz z przyciskiem `Zapisz i narysuj \
                ponownie`.
                """),
            .heading("Określenia"),
            .bullets([
                "**Kod** to **źródło do edycji**. Dla pliku tekstowego jest nim sam tekst. Dla pliku binarnego — PDF, obraz, dźwięk, wideo — nie ma źródła tekstowego, więc Kodem są **bajty**, pokazane szesnastkowo.",
                "**Widok** to to, co zostaje **narysowane** z Kodu. Może być ładniejszy, krótszy albo wykonywalny — ale zawsze jest następstwem, nigdy oryginałem.",
            ]),
            .paragraph("""
                Powiedzenie o PDF-ie, że *«ten rodzaj nie ma Kodu»*, byłoby wygodne, ale fałszywe: bajty \
                naprawdę są jego źródłem.
                """),
            .heading("Gdzie się edytuje"),
            .paragraph("""
                Edycja odbywa się w **Kodzie**. Są dokładnie **dwa wyjątki**, oba dlatego, że edytowanie w \
                Widoku jest o wiele naturalniejsze: **komórki tabeli CSV** i **pola formularza PDF**. Oba \
                piszą wprost do źródła, więc nie pojawia się druga kopia, z którą trzeba by się spierać.
                """),
            .heading("Wedle rodzaju pliku"),
            .table(
                headers: ["Rodzaj pliku", "Widok", "Kod", "Edycja w"],
                rows: [
                    ["CSV · TSV", "Tabela", "Surowy tekst", "**Obu**"],
                    ["Excel `.xlsx`", "Tabela otwartego arkusza", "Ten arkusz jako CSV", "**Obu**"],
                    ["PDF", "Narysowane strony", "Binarnie", "**Obu** — komentarze, pola, strony"],
                    ["Markdown `.md`", "Narysowany tekst", "Źródło Markdown", "Kodzie"],
                    ["Raport `.greport.md`", "Raport z wykonanymi zapytaniami i narysowanymi wykresami", "Źródło", "Kodzie"],
                    ["JSON", "Drzewo klucz-wartość, zwijalne", "Źródło JSON", "Kodzie"],
                    ["XML · HTML", "Drzewo znaczników, zwijalne", "Źródło XML", "Kodzie"],
                    ["YAML", "Drzewo klucz-wartość wedle wcięć", "Źródło YAML", "Kodzie"],
                    ["Schematy `.mmd` · `.dot`", "Narysowany schemat wypełniający kartę", "Źródło mermaid albo DOT", "Kodzie"],
                    ["Word `.docx`", "Narysowane strony dokumentu", "Wydobyty Markdown", "Kodzie"],
                    ["PowerPoint `.pptx`", "Narysowane strony slajdów", "Konspekt w Markdown", "Kodzie"],
                    ["Pliki dziennika", "Barwione wedle poziomu, filtrowalne", "Surowy tekst", "Kodzie"],
                    ["Obrazy", "Obraz (ruchome się odtwarzają)", "Binarnie", "Tylko odczyt"],
                    ["Dźwięk · wideo", "Odtwarzacz", "Binarnie", "Tylko odczyt"],
                    ["Archiwa", "Lista wpisów", "Binarnie", "Tylko odczyt"],
                    ["Kod źródłowy, zwykły tekst", "— żaden", "Sam tekst", "Kodzie"],
                ]
            ),
            .note("""
                Kod źródłowy **nie ma Widoku** i to normalne, a nie brak: plik Swift nie ma narysowanej \
                postaci wartej oglądania.
                """),
            .heading("Czytnik stron dla Worda i PowerPointa"),
            .paragraph("""
                Strony układają się pionowo i przewijają ciągle, każda to biała kartka na szarym tle — jak w \
                każdym czytniku dokumentów. Jego przyciski siedzą po prawej stronie paska.
                """),
            .table(
                headers: ["Przycisk / klawisz", "Co robi"],
                rows: [
                    ["`Dopasuj szerokość`", "Kartka jest dokładnie tak szeroka jak ramka — domyślnie"],
                    ["`Dopasuj stronę`", "Cała kartka mieści się w ramce"],
                    ["`−` `+`", "Powiększanie stopniowe; albo szczypanie, albo ⌘ + przewijanie"],
                    ["Pole `Szukaj` albo ⌘F", "Szukać w stronach, skoczyć tam i podświetlić"],
                    ["Enter w polu wyszukiwania", "Następne trafienie"],
                    ["Przeciąganie", "Zaznaczać tekst; dwuklik dla słowa, trzykrotny dla akapitu"],
                    ["⌘A · ⌘C", "Zaznaczyć wszystko · skopiować zaznaczenie"],
                    ["Page Up · Page Down · Home · End", "Poruszać się po dokumencie"],
                ]
            ),
            .paragraph("""
                Pole wyszukiwania **pomija znaki diakrytyczne i wielkość liter**: wpisanie `vuong quoc` \
                znajduje `Vương quốc`. Etykieta «Strona 12/363» na pasku mówi, gdzie jesteście.
                """),
            .note("""
                **Czego nie rysuje, powiedziane wprost:** pływające obrazy zakotwiczone (tekst opływający \
                rysunek) pojawiają się jako obrazy w wierszu; przypisy, wykresy i SmartArt PowerPointa nie są \
                rysowane. Gdy potrzebujecie ścisłej zgodności z wydrukiem, otwórzcie to w Wordzie.
                """),
            .heading("Kliknięcie węzła wraca do źródła"),
            .paragraph("""
                Drzewo JSON to nie ładny wydruk: kliknięcie węzła przenosi karetkę **na WARTOŚĆ tego węzła** \
                w tekście i wraca kartą do Kodu — bo tym, czego chcecie potem, jest prawie zawsze edycja \
                tego, co właśnie kliknęliście.
                """),
            .bullets([
                "Węzły-pojemniki pokazują swoją **liczbę elementów** (`{12}`, `[340]`) zamiast zawartości — to właśnie odpowiada na pytanie «czy warto to otwierać».",
                "**Pierwsze dwa poziomy** są rozwinięte: rozwinięcie do końca pliku o dziesięciu tysiącach węzłów daje listę dłuższą niż źródło, a zwinięcie do końca znaczy, że trzeba klikać, żeby cokolwiek odkryć.",
                "Plik o **niepoprawnej składni** nie dostaje pół drzewa — obcięte drzewo wygląda jak dokument, który po prostu tyle zawiera.",
                "W drzewie XML atrybuty noszą przedrostek `@` w zapisie XPath, a **odstęp między znacznikami nie staje się węzłem** — to formatowanie, a nie treść.",
                "Drzewo YAML czyta **pliki wielodokumentowe** (`---`): każdy dokument ma własny korzeń. Zbiory zapisane w jednym wierszu (`ports: [80, 443]`) pozostają liściem — widzicie już wszystko, a rozwinięcie kosztowałoby kliknięcie. **Wcięcie tabulatorami** jest zgłaszane z dokładnym wierszem: to błąd YAML, którego oko nie widzi.",
                "Konspekt PowerPointa budowany jest z **otwartego tekstu**, a nie z pliku na dysku: jeśli właśnie zmieniliście konspekt w Kodzie, drzewo musi opisywać nową wersję, a jego węzły muszą skakać w tę nową wersję. Notatki prelegenta zwijają się w jeden węzeł, żeby gadatliwy slajd nie wyglądał jak slajd o wielkiej zawartości.",
                "**Schemat wypełniający całą kartę idzie za tą samą zasadą**: kliknijcie węzeł, a wracacie do Kodu z karetką na jego deklaracji. W panelu `Mermaid Studio` obok karta się nie zamyka — edytor jest tuż obok, a wystarczy przesunąć karetkę, żeby to zobaczyć.",
                "Schematy **otwierają się także tam, gdzie stoicie**: element odpowiadający wierszowi karetki jest podświetlony, gdy tylko karta się pojawi, więc nie trzeba go szukać.",
            ]),
            .heading("Pole filtra: w drzewie o dziesięciu tysiącach węzłów szukanie jest pracą"),
            .paragraph("""
                Tuż pod liczbą węzłów siedzi pole filtra. Piszcie w nim, a drzewo zostawia tylko pasujące \
                węzły — **wraz ze ścieżką od korzenia do nich**, bo gdy klucz `name` pojawia się w dziesięciu \
                miejscach, prawdziwym pytaniem jest «który», a odpowiada na nie tylko gałąź, która go \
                zawiera. Reszta jest rozwijana za was: kazać wam rozklikiwać każdy poziom to kazać wam \
                filtrować po raz drugi ręcznie.
                """),
            .bullets([
                "Filtruje po **etykietach i wartościach**: szukanie `Huế` jest równie częste jak szukanie klucza `province`.",
                "**Pisanie bez znaków diakrytycznych i tak pasuje do tekstu z nimi** — `da nang` znajduje `Đà Nẵng`. To samo porównanie co w filtrze tabeli CSV i w liście funkcji, żeby nie trzeba było pamiętać trzech zasad szukania w jednym programie.",
                "Gdy nic nie pasuje, nagłówek mówi **«Brak wyników»**, zamiast zostawiać was przed pustym drzewem z pytaniem, czy plik jest zepsuty.",
                "Zmiana pliku albo ponowne wejście w Widok **czyści filtr**: drzewo otwierające się już obcięte, bez niczego, co by to wyjaśniało, to najbardziej mylący stan ze wszystkich.",
            ]),
            .heading("Całe drzewo działa z klawiatury"),
            .paragraph("""
                Wejście w Widok przenosi uwagę na drzewo; nie trzeba go najpierw klikać. W górę i w dół \
                poruszają się między węzłami, w lewo i w prawo zwijają i rozwijają, a dwa klawisze kończą \
                oglądanie — robiąc przy tym **różne** rzeczy:
                """),
            .bullets([
                "**Enter** — przejść do zaznaczonego węzła: powrót do Kodu z karetką w zakresie bajtów tego węzła. Dokładnie jak kliknięcie.",
                "**Tab** — przechodzić między drzewem a polem filtra.",
                "**⌘C** — kopiuje **ścieżkę** zaznaczonego węzła, a nie tekst kryjący się za drzewem. JSON i YAML dają JSONPath (`$.customer['name']`), który wkleja się wprost w pole zapytań JSONPath tego samego programu albo w `yq`; XML daje XPath (`/order/item[2]/@code`) z numerami, gdy dwa znaczniki dzielą nazwę; konspekt PowerPointa kopiuje tekst wiersza, bo konspekt nie ma języka ścieżek, który dałoby się wymyślić.",
                "**Esc** — droga powrotna: wrócić do Kodu z karetką **dokładnie tam, gdzie była**. Oglądaliście drzewo, a nie podróżowaliście dokądkolwiek.",
            ]),
            .heading("I odwrotnie: drzewo otwiera się tam, gdzie stoi karetka"),
            .paragraph("""
                Wejście w Widok ze środka pliku o dziesięciu tysiącach wierszy **nie** otwiera drzewa od \
                góry: rozwija ścieżkę do węzła odpowiadającego miejscu, w którym była karetka, i zaznacza go. \
                To druga połowa skoku do źródła — bez niej Widok i Kod byłyby dwoma spojrzeniami na jeden \
                dokument tylko w **jednym** kierunku.
                """),
            .bullets([
                "Rozwija **głębiej niż dwa poziomy**, gdy trzeba: zasada dwóch poziomów odpowiada na «jak wygląda ten plik», a tutaj pytanie jest inne — «gdzie jestem w tym drzewie».",
                "Karetka na **kluczu** (`\"address\":`) zaznacza tę pozycję, choć zakres bajtów węzła obejmuje tylko wartość. Tekst tuż przed węzłem należy do tego węzła.",
                "Karetka na **początku bloku** — klucz bloku YAML, tytuł slajdu, nazwa znacznika XML — zaznacza ten blok, zamiast nurkować w jego pierwsze dziecko.",
                "Wejście w Widok **nie przesuwa karetki**. Wyjdźcie z Widoku, a jesteście dokładnie tam, gdzie byliście; Widok to sposób patrzenia, a nie polecenie zmieniające miejsce.",
            ]),
            .heading("Żadnemu rodzajowi nie brakuje już Widoku"),
            .paragraph("""
                **Każdy rodzaj pliku, w którym jest miejsce na tryb Widoku, teraz go rysuje.** Lista \
                brakujących rodzajów opustoszała i została usunięta.

                Kod źródłowy i zwykły tekst nadal nie mają Widoku — to normalne, a nie brak, więc nigdy nie \
                były na tej liście.

                Jeśli pojawi się nowy rodzaj pliku, którego Widok nie jest jeszcze zbudowany, polecenie \
                przełączania powie to i nazwie, czego brakuje, zamiast otwierać pustą ramkę — pusta ramka to \
                pusta obietnica, a odmowa z nazwą to informacja.
                """),
            .heading("Sześć dawnych poleceń nadal jest"),
            .paragraph("""
                `Widok tabeli / tekstu`, `Podgląd Markdown`, `Widok binarny`, `Podgląd raportu`, `Podgląd \
                schematu Mermaid`, `Tryb dziennika` — wszystkie zostają dokładnie tam, gdzie były. `⌥⌘V` to \
                **wspólne wejście**, a nie zastępstwo.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Wietnamski

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Wietnamski",
        summary: "Dawne kodowania, normalizacja Unicode, szukanie bez znaków diakrytycznych i metody wprowadzania.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Kodowania wietnamskie",
        summary: "Czytać i zapisywać TCVN3, VISCII, VNI-Windows i 33 inne, rozpoznawane samoczynnie.",
        keywords: ["kodowanie", "tcvn3", "abc", "viscii", "vni", "krzaki"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Otworzyliście stary wietnamski plik i zamiast `Trường Đại học` dostaliście `Tr¦êng §¹i häc`? \
                Plik nie jest uszkodzony — zapisano go w kodowaniu sprzed Unicode.
                """),
            .steps([
                "Kliknijcie kodowanie na **pasku stanu** (albo `Format ▸ Kodowanie…`).",
                "Wybierzcie właściwe — dla starych plików wietnamskich zwykle `TCVN3 (ABC)`, `VNI-Windows` albo `VISCII`.",
                "Tekst naprawia się natychmiast; nie trzeba otwierać pliku ponownie.",
                "Żeby tak zostało: `Zapisz jako…` z kodowaniem `UTF-8`.",
            ]),
            .heading("Trzy dawne kodowania wietnamskie"),
            .table(
                headers: ["Kodowanie", "Spotykane głównie w"],
                rows: [
                    ["TCVN3 (ABC)", "Pismach urzędowych i starszych dokumentach Worda na północy"],
                    ["VNI-Windows", "Wydawnictwie, prasie i drukarniach — częste na południu"],
                    ["VISCII", "Wczesnej poczcie elektronicznej i Usenecie"],
                ]
            ),
            .paragraph("""
                GEditor **rozpoznaje kodowanie** przy otwarciu. Gdy zgadnie źle, jedno kliknięcie to \
                naprawia, a treść jest odkodowywana na nowo, a nie łatana litera po literze.
                """),
            .warning("""
                Zapis do dawnego kodowania gubi znaki, których to kodowanie nie ma. GEditor **liczy je i mówi \
                wam wcześniej** — na przykład *«12 znaków nie ma w TCVN3»* — zamiast po cichu zamieniać je w \
                pytajniki.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Końce wierszy",
        summary: "LF, CRLF, CR — przekształcane dla całego pliku jednym kliknięciem.",
        keywords: ["eol", "crlf", "lf", "koniec wiersza", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Styl", "Używany przez", "Bajty"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Maca sprzed 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Bieżący styl widnieje na pasku stanu; kliknijcie go, żeby zmienić. Plik **mieszający** dwa \
                style też jest tam zgłaszany — włączcie `Pokaż niewidoczne ▸ Końce wierszy`, żeby zobaczyć \
                dokładnie gdzie.
                """),
            .note("Styl końca wiersza dla **nowych** plików ustawia się w `Ustawieniach…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Normalizacja Unicode",
        summary: "Dlaczego szukanie «ế» czasem nic nie znajduje i jak naprawić cały plik.",
        keywords: ["unicode", "nfc", "nfd", "złożony", "rozłożony", "normalizować"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                W Unicode `ế` można zapisać na **dwa sposoby**: jako jeden punkt kodowy złożony wstępnie \
                (NFC) albo jako `e` plus dwa osobne znaki (NFD). Na ekranie wyglądają tak samo; dla maszyny \
                to dwa różne łańcuchy znaków.
                """),
            .paragraph("""
                Skutek: szukanie `ế` w pliku NFD nie znajduje **nic**, a użytkownik wnioskuje, że danych tam \
                nie ma.
                """),
            .steps([
                "`Format ▸ Znormalizuj Unicode…`",
                "Wybierzcie **NFC** (złożony wstępnie) — postać, której używa prawie wszystko inne.",
                "Zastosujcie. To jeden krok cofnięcia.",
            ]),
            .note("""
                Pliki pochodzące z macOS często są w NFD, bo system plików Apple tak przechowuje nazwy. To \
                zdecydowanie najczęstszy powód, dla którego dane skopiowane z Findera nie dają się już \
                odnaleźć.
                """),
            .paragraph("""
                W `Ustawieniach…` jest przełącznik **normalizuj do NFC przy zapisie**. Domyślnie wyłączony, \
                bo zmienia bajty pliku.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Pisanie bez znaków diakrytycznych i tak znajduje tekst z nimi",
        summary: "Każde pole wyszukiwania i filtra porównuje po zdjęciu znaków.",
        keywords: ["znaki diakrytyczne", "akcenty", "wyszukiwanie", "filtr"],
        blocks: [
            .paragraph("""
                Wpiszcie `hue`, żeby znaleźć `Huế`. Wpiszcie `da nang`, żeby znaleźć `Đà Nẵng`. Zasada \
                dotyczy filtra tabeli CSV, wyszukiwania funkcji, wyszukiwania w pomocy i pozostałych pól \
                filtrów.
                """),
            .note("""
                `Đ` traktowane jest osobno, bo w Unicode to **osobna litera**, a nie `D` ze znakiem — zwykłe \
                zdejmowanie znaków go nie dotyka.
                """),
            .paragraph("""
                Filtr CSV przyjmuje też przedrostek `=` dla porównania dokładnego. Postać z `=` jest \
                **również nieczuła na znaki diakrytyczne**, bo filtr rozróżniający znaki zostawia użytkownika \
                w przekonaniu, że danych brakuje.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Wietnamskie metody wprowadzania",
        summary: "EVKey, OpenKey, Unikey i systemowe źródło wprowadzania piszą wprost w dokumencie.",
        keywords: ["metoda wprowadzania", "evkey", "unikey", "openkey", "telex", "vni"],
        blocks: [
            .paragraph("""
                Nic nie trzeba ustawiać. Telex i VNI działają oba, także na **wielu karetkach** — napiszcie \
                raz, a każda karetka dostanie poprawnie oznaczoną literę.
                """),
            .paragraph("""
                Pola wyszukiwania, pola filtrów i każde okno dialogowe przyjmują metodę wprowadzania tak samo \
                jak edytor.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Języki i formaty

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Języki i formaty",
        summary: "Dwadzieścia języków wbudowanych, języki własne oraz narzędzia do JSON · XML · YAML · dzienników.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Dwadzieścia języków wbudowanych",
        summary: "Barwienie z prawdziwego drzewa składniowego, ze znacznikami komentarza każdego języka.",
        keywords: ["składnia", "podświetlanie", "język", "tree-sitter", "gramatyka"],
        blocks: [
            .paragraph("""
                Język rozpoznawany jest po **rozszerzeniu pliku** (plus kilka szczególnych nazw jak \
                `Makefile`, `Dockerfile`, `Gemfile`). Można go zmienić ręcznie na pasku stanu.
                """),
            .table(
                headers: ["Język", "Rozszerzenia", "Komentarz wiersza · bloku"],
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
                Ostatnia kolumna to to, czego używa `⌘/`. Języki bez komentarza wierszowego (JSON, CSS, XML) \
                dostają zamiast tego postać blokową.
                """),
            .heading("Co przychodzi wraz z drzewem składniowym"),
            .bullets([
                "**Lista funkcji** na pasku bocznym idzie za prawdziwą strukturą, a nie za domysłami z wcięć.",
                "**Zwijanie** wedle struktury.",
                "**Dopasowanie nawiasów** pomijające te w łańcuchach znaków i komentarzach.",
                "**Wcięcie samoczynne** dodające poziom po `{`, a w Pythonie i YAML po `:`.",
            ]),
            .note("""
                Trzy ciężkie gramatyki (C++, C#, Ruby) mieszkają w bibliotece **wczytywanej leniwie** — \
                wczytują się dopiero, gdy otworzycie plik w jednym z tych języków. Właśnie dlatego czas \
                uruchomienia pozostaje poniżej pół sekundy.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Języki definiowane przez użytkownika",
        summary: "Pokolorować własny format jednym plikiem JSON — bez pisania gramatyki.",
        keywords: ["udl", "własny język", "własny dziennik"],
        blocks: [
            .paragraph("""
                Wewnętrzny format dziennika firmy, własny język konfiguracji, mały DSL — żaden z nich nie ma \
                gramatyki tree-sitter, a napisanie takiej wymaga kompilatora i trochę teorii analizy \
                składniowej.
                """),
            .paragraph("""
                Zamiast tego GEditor przyjmuje **analizator leksykalny sterowany tablicami**, zadeklarowany w \
                JSON. Włóżcie plik do katalogu `grammars/` w katalogu konfiguracji GEditora i uruchomcie \
                program ponownie.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — pełny język",
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
            .heading("Każdy klucz"),
            .table(
                headers: ["Klucz", "Typ", "Znaczenie"],
                rows: [
                    ["`name`", "łańcuch", "Nazwa pokazywana na pasku stanu"],
                    ["`extensions`", "lista łańcuchów", "Rozszerzenia plików, **bez kropki**"],
                    ["`caseSensitive`", "wartość logiczna", "Czy słowa kluczowe rozróżniają wielkość liter"],
                    ["`lineComment`", "łańcuch", "Znacznik komentarza do końca wiersza; pominąć, gdy go nie ma"],
                    ["`blockComment`", "lista 2 łańcuchów", "`[otwierający, zamykający]`"],
                    ["`stringDelimiters`", "lista łańcuchów", "Każda pozycja to **jeden** znak otwierający/zamykający łańcuch"],
                    ["`escapeCharacter`", "łańcuch", "Znak ucieczki w łańcuchach; pusty znaczy, że język go nie ma"],
                    ["`keywordGroups`", "obiekt", "Nazwa grupy → lista słów kluczowych; trzy grupy dostają trzy barwy"],
                ]
            ),
            .paragraph("Trzy nazwy grup z własną barwą to `keyword`, `type` i `constant`."),
            .warning("""
                Ten analizator **nie rozumie zagnieżdżeń**. Zwijanie strukturalne, lista funkcji i sprytne \
                dopasowanie nawiasów pozostają zastrzeżone dla dwudziestu języków wbudowanych. To celowa \
                wymiana: w zamian deklarujecie język w dziesięć minut, a nie w dzień.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "Narzędzia JSON",
        summary: "Przeformatować, zmniejszyć, posortować klucze i sprawdzić względem JSON Schema.",
        keywords: ["json", "formatować", "zmniejszyć", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Polecenie", "Co robi"],
                rows: [
                    ["Przeformatuj", "Łamie wiersze i wcina, żeby dało się czytać"],
                    ["Zmniejsz", "Usuwa wszystkie zbędne odstępy"],
                    ["Posortuj klucze", "Układa klucze każdego obiektu alfabetycznie — żeby dwa pliki JSON dało się **porównać**"],
                    ["Sprawdź względem JSON Schema…", "Sprawdza dokument względem pliku schematu, wyliczając każdy problem z wierszem"],
                ]
            ),
            .paragraph("""
                Stosowane zasady to **ścisłe RFC 8259**: żadnych przecinków na końcu, żadnych komentarzy, \
                żadnego `NaN`. Błąd składni wskazuje dokładny wiersz i kolumnę.
                """),
            .note("""
                Pliki **JSONL** (jeden obiekt na wiersz) też są rozpoznawane i mają własne narzędzia w \
                rozdziale o pakiecie wiedzy.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "Zapytania JSONPath",
        summary: "Wyciągnąć dokładnie tę część, której potrzebujecie, z dużego pliku JSON.",
        keywords: ["jsonpath", "zapytanie json", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Wpiszcie wyrażenie; wyniki pojawią się jako lista, w którą można skoczyć."),
            .table(
                headers: ["Piszcie", "Znaczenie"],
                rows: [
                    ["`$`", "Korzeń dokumentu"],
                    ["`$.name`", "Klucz `name` przy korzeniu"],
                    ["`$.orders[0]`", "Pierwszy element tablicy"],
                    ["`$.orders[*].total`", "Klucz `total` **każdego** elementu"],
                    ["`$..province`", "Klucz `province` na **dowolnej głębokości**"],
                    ["`$.orders[1:3]`", "Wycinek: elementy 1 i 2"],
                ]
            ),
            .code(language: "text", caption: "Kod prowincji każdego zamówienia, choćby najgłębiej zagnieżdżony",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "Narzędzia XML",
        summary: "Przeformatować, zmniejszyć, sprawdzić składnię i sprawdzić względem DTD albo XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "sprawdzić", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Polecenie", "Co robi"],
                rows: [
                    ["Przeformatuj", "Wcina wedle głębokości znaczników"],
                    ["Zmniejsz", "Usuwa odstępy między znacznikami"],
                    ["Sprawdź składnię", "Brakujące znaczniki zamykające, złe zagnieżdżenie, niedozwolone znaki"],
                    ["Sprawdź względem DTD/XSD…", "Sprawdza względem schematu, zgłaszając każdy problem z wierszem"],
                    ["Oblicz XPath…", "Wykonuje wyrażenie XPath; wyniki otwierają się w nowej karcie"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Wpiszcie wyrażenie, a wyniki otworzą się jako **karta tekstowa**, po jednym węźle w wierszu. \
                Na przykład: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Wyniki NIE skaczą do miejsca w pliku źródłowym.** Systemowy obliczacz XPath buduje własne \
                drzewo i nie przechowuje położenia bajtowego każdego węzła, więc wraca TREŚĆ, a nie \
                współrzędne. Żeby trafić w dokładne miejsce, użyjcie `⌘F` na łańcuchu, który właśnie \
                znaleźliście.
                """),
            .paragraph("""
                W plikach `.xml` i `.html` napisanie `>` kończące znacznik otwierający sprawia, że \
                **pojawia się znacznik zamykający** z karetką pomiędzy. Znaczniki samozamykające (`<br/>`), \
                deklaracje (`<?xml …?>`) i komentarze — nie; nie mają czego zamykać.
                """),
            .warning("""
                Przeformatowanie XML **zmienia odstępy między znacznikami**. W dokumentach, gdzie te odstępy \
                mają znaczenie — na przykład XHTML z tekstem w znacznikach — zmienia to wyświetlaną treść. To \
                jeden krok cofnięcia, więc `⌘Z` to odwraca.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "Sprawdzanie YAML",
        summary: "Złapać dwa najczęstsze błędy YAML: powtórzone klucze i wcięcie tabulatorami.",
        keywords: ["yaml", "yml", "lint", "powtórzony klucz", "wcięcie"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Powtórzone klucze** w jednym odwzorowaniu — większość czytników YAML bierze **ostatni** i po cichu odrzuca wcześniejsze, więc plik konfiguracji może zachowywać się zupełnie inaczej, niż sądzicie.",
                "**Wcięcie tabulatorami** — YAML zabrania tabulatorów we wcięciu, a komunikaty błędów bibliotek na ten temat bywają niezrozumiałe.",
            ]),
            .note("Włączcie `Pokaż niewidoczne ▸ Tabulatory`, żeby od razu zobaczyć, który odstęp jest tabulatorem."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Pliki dziennika",
        summary: "Siedem poziomów wagi, filtrowanie po poziomie i jak czytać bardzo duży dziennik.",
        keywords: ["dziennik", "log", "błąd", "ostrzeżenie", "filtr", "poziom"],
        blocks: [
            .paragraph("""
                Włączcie `Widok ▸ Tryb dziennika (barwienie wedle poziomu)`. GEditor odczytuje wagę na \
                **początku każdego wiersza** — po znaczniku czasu i nazwie procesu.
                """),
            .table(
                headers: ["Poziom", "Barwa"],
                rows: [
                    ["CRITICAL · ERROR", "Czerwona"],
                    ["WARNING", "Bursztynowa"],
                    ["NOTICE", "Barwa wyróżnienia"],
                    ["INFO", "Zwykły tekst"],
                    ["DEBUG · TRACE", "Przygaszone"],
                ]
            ),
            .paragraph("""
                `Filtruj dziennik po poziomie…` całkiem ukrywa poziomy niższe. Wiersze, których poziomu **nie \
                rozpoznano** — na przykład dalszy ciąg śladu stosu — zostają nietknięte, zamiast dostać \
                poziom wiersza poprzedniego.
                """),
            .heading("Czytanie dużego dziennika, krok po kroku"),
            .steps([
                "Otwórzcie plik — nawet w skali gigabajtów otwiera się niemal natychmiast.",
                "`Widok ▸ Tryb dziennika`, żeby zobaczyć, gdzie jest czerwień.",
                "`⌥⌘M` po mapę dokumentu: czy czerwień skupia się na jednym odcinku, czy rozsypana jest po całym pliku?",
                "`⌘F` po kod błędu, `⌘M` żeby oznaczyć każdy pasujący wiersz.",
                "`Szukaj ▸ Skopiuj oznaczone wiersze`, żeby przenieść je do nowej karty.",
                "Wciąż działa? `Plik ▸ Śledź plik (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
