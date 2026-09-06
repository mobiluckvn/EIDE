import Foundation

/// Polska treść pomocy — część 2: wyszukiwanie, pliki i sesje.
extension HelpPL {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Wyszukiwanie",
        summary: "Szukanie, zamiana, wyrażenia regularne, szukanie w katalogu i znaczniki wierszy.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Szukaj i zamień",
        summary: "Trzy tryby szukania i dlaczego ^ domyślnie znaczy początek WIERSZA.",
        keywords: ["szukać", "zamieniać", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Szukać"),
                HelpShortcut("⌥⌘F", "Szukać i zamieniać"),
                HelpShortcut("⌘G / ⇧⌘G", "Następne / poprzednie trafienie"),
            ]),
            .heading("Trzy tryby"),
            .table(
                headers: ["Tryb", "Rozumie", "Do"],
                rows: [
                    ["Zwykły", "Zwykły tekst, żadnych znaków specjalnych", "Większości wyszukiwań"],
                    ["Rozszerzony", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Znajdowania końców wiersza, tabulatorów, konkretnych bajtów"],
                    ["Regex", "Pełne PCRE2", "Szukania wedle wzorca"],
                ]
            ),
            .note("""
                Tryb **rozszerzony** nie rozumie składni wyrażeń regularnych. Rozwija tylko kilka sekwencji \
                ucieczki — szukanie tam `a.b` znajduje dokładnie te trzy znaki; kropka nie jest znakiem \
                zastępczym.
                """),
            .heading("Dwa przełączniki"),
            .bullets([
                "**Uwzględniaj wielkość liter** — domyślnie wyłączone.",
                "**Całe słowo** — pasuje tylko wtedy, gdy oba końce są granicami wyrazu.",
            ]),
            .heading("`^` i `$` pasują na krawędziach każdego WIERSZA"),
            .paragraph("""
                Domyślnie włączone. Kto przychodzi z Notepad++, oczekuje, że `^` znaczy «początek wiersza»; \
                bez tego `^abc` pasowałoby tylko wtedy, gdyby cały dokument zaczynał się od `abc` — prawie \
                nikt tego nie chce w edytorze tekstu.
                """),
            .heading("Złe wyrażenie nie zawiesi programu"),
            .paragraph("""
                Silnikiem jest **PCRE2 z kompilacją JIT**, mający budżet nawrotów. Wzorzec, który wybucha \
                kombinatorycznie, zostaje zatrzymany i zgłoszony, zamiast zamrozić okno.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Wyrażenia regularne",
        summary: "Składnia PCRE2, której naprawdę się używa, z przykładami działającymi na wietnamskich danych.",
        keywords: ["regex", "pcre", "wzorzec"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor używa **PCRE2**, tego samego silnika co PHP i wiele narzędzi wiersza poleceń. \
                Otwórzcie `Szukaj ▸ Wypróbuj wyrażenie regularne…`, żeby sprawdzić wzorzec na przykładowym \
                tekście i zobaczyć, co przechwytuje każda grupa, **zanim** zastosujecie go do prawdziwego \
                dokumentu.
                """),
            .heading("Klasy znaków"),
            .table(
                headers: ["Piszcie", "Pasuje do"],
                rows: [
                    ["`.`", "Dowolnego znaku poza końcem wiersza"],
                    ["`\\d` · `\\D`", "Cyfry · nie-cyfry"],
                    ["`\\w` · `\\W`", "Znaku wyrazowego (litera, cyfra, `_`) · przeciwieństwa"],
                    ["`\\s` · `\\S`", "Odstępu · nie-odstępu"],
                    ["`[abc]`", "Jednego ze znaków w nawiasach"],
                    ["`[^abc]`", "Znaku, którego NIE ma w nawiasach"],
                    ["`[a-z]`", "Znaku z zakresu"],
                ]
            ),
            .heading("Powtórzenie"),
            .table(
                headers: ["Piszcie", "Znaczenie"],
                rows: [
                    ["`*`", "Zero lub więcej"],
                    ["`+`", "Jeden lub więcej"],
                    ["`?`", "Zero lub jeden"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Dokładnie 3 · od 2 do 5 · 2 lub więcej"],
                    ["`*?` `+?` `??`", "Postacie **leniwe** — brać jak najmniej"],
                ]
            ),
            .warning("""
                `.*` jest **zachłanne**: zjada do końca wiersza, a potem się cofa. Przy rozdzielaniu pól w \
                obrębie wiersza prawie zawsze potrzebujecie `.*?` albo wąskiej klasy w rodzaju `[^,]*`.
                """),
            .heading("Kotwice i grupy"),
            .table(
                headers: ["Piszcie", "Znaczenie"],
                rows: [
                    ["`^` · `$`", "Początek wiersza · koniec wiersza"],
                    ["`\\b`", "Granica wyrazu"],
                    ["`(…)`", "Grupa **przechwytująca** — do ponownego użycia w zamianie"],
                    ["`(?:…)`", "Grupa nieprzechwytująca"],
                    ["`(?<name>…)`", "Grupa nazwana"],
                    ["`a|b`", "a albo b"],
                    ["`(?=…)` · `(?!…)`", "Wgląd w przód: musi następować · nie może następować"],
                    ["`(?<=…)` · `(?<!…)`", "Wgląd wstecz: musi poprzedzać · nie może poprzedzać"],
                ]
            ),
            .heading("Przykłady, które działają"),
            .code(language: "regex", caption: "Każdy dziesięciocyfrowy wietnamski numer telefonu",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Rozbicie daty 31/12/2026 na trzy grupy",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "Trzecia komórka prostego wiersza CSV (bez cudzysłowów)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Wiersze dziennika z ERROR albo FATAL, ze znacznikiem czasu",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Wiersze puste albo zawierające same odstępy",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Wietnamskie litery ze znakami — użyjcie klasy Unicode, nie wyliczajcie ich",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` znaczy «dowolna litera Unicode», więc łapie też `ế` i `đ`. Wyliczanie ręcznie każdej \
                samogłoski ze znakiem to pewny sposób, żeby o którejś zapomnieć.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Łańcuchy zamiany",
        summary: "Używać ponownie przechwyconych grup i zmieniać wielkość liter podczas zamiany.",
        keywords: ["zamiana", "odwołanie wstecz", "grupa", "$1", "\\U"],
        blocks: [
            .heading("Przywołanie przechwyconej grupy"),
            .table(
                headers: ["Piszcie", "Znaczenie"],
                rows: [
                    ["`$1` … `$9`", "Zawartość grupy n"],
                    ["`${1}`", "To samo z wyraźnymi granicami — używajcie, gdy dalej idzie cyfra"],
                    ["`\\1`", "Też jest przyjmowane; GEditor przepisuje je na `${1}`"],
                    ["`$0`", "Całe trafienie"],
                ]
            ),
            .note("""
                Piszcie `${1}`, a nie `$1`, gdy następny znak jest cyfrą. `$123` czyta się jako grupę 123; \
                `${1}23` to grupa 1, po której idą dwie cyfry.
                """),
            .heading("Zmiana wielkości liter w trakcie zamiany"),
            .table(
                headers: ["Piszcie", "Znaczenie"],
                rows: [
                    ["`\\U`", "WIELKIE LITERY od tego miejsca"],
                    ["`\\L`", "małe litery od tego miejsca"],
                    ["`\\u`", "Tylko następny znak wielką literą"],
                    ["`\\l`", "Tylko następny znak małą literą"],
                    ["`\\E`", "Koniec obszaru `\\U` albo `\\L`"],
                ]
            ),
            .heading("Przykłady"),
            .code(language: "text", caption: "Zamiana 31/12/2026 na 2026-12-31",
                  source: """
                    Szukaj:  (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Zamień:  $3-$2-$1
                    """),
            .code(language: "text", caption: "Kod prowincji na początku wiersza wielkimi literami, reszta bez zmian",
                  source: """
                    Szukaj:  ^([a-z]{2,3})(\\s)
                    Zamień:  \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Owinięcie każdego wiersza jako łańcucha JSON",
                  source: """
                    Szukaj:  ^(.+)$
                    Zamień:  "$1",
                    """),
            .paragraph("""
                Grupa, która **nie brała udziału** w trafieniu, staje się pustym łańcuchem, a nie błędem — \
                dzięki temu wzorzec z alternatywami w rodzaju `(a)|(b)` zamienia czysto, bez pisania go dwa \
                razy.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Szukanie i zamiana w katalogu",
        summary: "Przejrzeć wiele plików naraz i zobaczyć wyniki, zanim cokolwiek zostanie zapisane.",
        keywords: ["szukanie w plikach", "grep", "zamiana masowa", "katalog"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Szukać w katalogu")]),
            .paragraph("""
                Wybierzcie katalog główny, odfiltrujcie po wzorcu nazwy pliku i przejrzyjcie. Wyniki \
                pojawiają się pogrupowane po plikach; kliknięcie wiersza otwiera dany plik w tym miejscu.
                """),
            .bullets([
                "Te same trzy tryby szukania i ten sam silnik wyrażeń regularnych co pole wyszukiwania w dokumencie.",
                "Zamiana w katalogu **pokazuje wcześniej**, ile plików i ile trafień się zmieni, zanim zacznie zapisywać.",
                "Przegląd idzie równolegle i **można go przerwać** w połowie.",
            ]),
            .warning("""
                Zamiana w katalogu zapisuje wprost do plików, które **nie są otwarte**. Tych plików nie ma w \
                historii cofnięć otwartego dokumentu — obejrzyjcie najpierw podgląd i miejcie kopię zapasową \
                albo repozytorium z wersjami.
                """),
            .heading("Wcześniejsze wyszukiwania i wywóz wyników"),
            .paragraph("""
                Panel wyników **zachowuje wyszukiwania z tej sesji**. Menu na górze wylicza je z liczbą \
                trafień — poszukajcie `TODO`, przeczytajcie do połowy, poszukajcie `FIXME` dla porównania i \
                wróćcie do pierwszej listy bez ponownego przeglądania całego katalogu.
                """),
            .paragraph("""
                Przycisk **Wywieź** otwiera bieżące wyszukiwanie jako kartę tekstową, po jednym wyniku w \
                wierszu w postaci `ścieżka:wiersz:kolumna: tekst` — kształt, jakiego używa `grep -n` i jakiego \
                kompilatory używają do błędów. Każdy wiersz wkleja się wprost w pole `Przejdź do` tego samego \
                programu, a wasze `grep`, `awk` i `sed` czytają go bez własnego analizatora.
                """),
            .note("""
                Historia mieszka **w pamięci** i nigdy nie trafia na dysk: wyniki wyszukiwania niosą treść \
                każdego trafionego wiersza, czyli tę samą klasę danych, której historia schowka celowo nie \
                przechowuje.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Znaczniki wierszy",
        summary: "Dziewięć barw znaczników i cztery polecenia, które zamieniają oznaczone wiersze w wynik.",
        keywords: ["zakładka", "znacznik", "f2", "filtrować wiersze"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Oznaczanie to sposób na filtrowanie dokumentu **bez jego zmieniania**. Oznaczcie każdy \
                wiersz pasujący do wzorca, a potem skopiujcie tylko te albo zostawcie tylko je.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Oznaczyć każdy wiersz pasujący do bieżącego wyszukiwania"),
                HelpShortcut("⌘F2", "Oznaczyć / odznaczyć bieżący wiersz"),
                HelpShortcut("F2 / ⇧F2", "Przejść do następnego / poprzedniego znacznika"),
            ]),
            .heading("Typowy przebieg"),
            .steps([
                "`⌘F` z wzorcem, po którym chcecie filtrować, np. `\\bERROR\\b`.",
                "`⌘M` oznacza każdy pasujący wiersz.",
                "`Szukaj ▸ Skopiuj oznaczone wiersze` przenosi je do nowej karty — albo `Zostaw tylko oznaczone wiersze` filtruje na miejscu.",
            ]),
            .heading("Dziewięć barw"),
            .paragraph("""
                Jeden wiersz może nosić **kilka barw naraz**. Używajcie różnych barw do różnych kryteriów i \
                łączcie je: czerwona dla wierszy z błędami, żółta dla wierszy jednego numeru zamówienia, a \
                potem szukajcie wierszy noszących obie.
                """),
            .bullets([
                "`Odwróć znaczniki` — wiersze oznaczone stają się nieoznaczone i odwrotnie.",
                "`Wyczyść wszystkie znaczniki` — usuwa każdy znacznik, nie tykając treści.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Przejście do wiersza",
        summary: "Skoczyć do wiersza, do kolumny albo do położenia w bajtach.",
        keywords: ["przejdź do", "numer wiersza", "cmd+l", "położenie", "kolumna"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Przejść do wiersza")]),
            .paragraph("""
                Pole rozumie **trzy zapisy** i rozróżnia je po tym, co wpisujecie — nie ma żadnego dodatkowego \
                przełącznika do klikania.
                """),
            .table(
                headers: ["Wpiszcie", "Prowadzi do"],
                rows: [
                    ["`120`", "początku wiersza 120"],
                    ["`120,5` albo `120:5`", "wiersz 120, kolumna 5 — kolumna liczy ZNAKI"],
                    ["`@1024`", "położenia 1024 w bajtach w pliku"],
                ]
            ),
            .note("""
                `wiersz:kolumna` to dokładnie sposób, w jaki kompilatory i lintery wypisują położenie, więc \
                wiersz właśnie skopiowany z terminala wkleja się bez zmian.

                `@` przy położeniach w bajtach ma swój powód: czy `1234` to wiersz, czy bajt? Nie ma dobrej \
                odpowiedzi, a złe zgadnięcie posyła karetkę zupełnie gdzie indziej, bez żadnego sygnału. Ta \
                liczba w bajtach to również to, co pasek stanu pokazuje w członie położenia (`@1024`): co tam \
                czytacie, możecie tu wpisać.
                """),
            .bullets([
                "Kolumna **poza długością wiersza** zatrzymuje się na jego końcu; nie przelewa się na następny.",
                "Położenie w bajtach **poza plikiem** prowadzi na koniec — ta liczba zwykle pochodzi z wcześniejszego przebiegu, a plik mógł się skurczyć.",
                "Tekst, którego nie umie odczytać, jest **zgłaszany**, a karetka zostaje na miejscu; nie skacze na początek pliku.",
            ]),
            .paragraph("""
                Przy bardzo dużych plikach GEditor nie czyta całego pliku, żeby tam dotrzeć — spis wierszy \
                budowany jest stopniowo w tle.
                """),
            .note("""
                Narzędzie wiersza poleceń też przyjmuje położenie: `geditor raport.csv:120:5` otwiera plik z \
                karetką w wierszu 120, kolumnie 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Pliki i sesje

    static let files = HelpChapter(
        id: "tep",
        title: "Pliki i sesje",
        summary: "Otwieranie, zapisywanie, karty, okna, przestrzenie robocze i to, jak wraca sesja.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Otwieranie i zapisywanie",
        summary: "Otworzyć plik dowolnej wielkości i zapisać go z innym kodowaniem albo końcem wiersza.",
        keywords: ["otworzyć", "zapisać", "powielić", "zmienić nazwę", "przenieść"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Nowy dokument"),
                HelpShortcut("⌘O", "Otworzyć plik"),
                HelpShortcut("⌘S", "Zapisać"),
                HelpShortcut("⇧⌘S", "Zapisać jako"),
            ]),
            .paragraph("""
                Przeciągnięcie pliku do okna też go otwiera. `Plik ▸ Otwórz ostatnie` przechowuje listę \
                plików, nad którymi właśnie pracowaliście.
                """),
            .heading("Zapisz jako: trzy rzeczy, które można zmienić"),
            .table(
                headers: ["Zmiana", "Znaczenie"],
                rows: [
                    ["Kodowanie", "Zapisać w UTF-8, TCVN3, VNI-Windows… — 36 kodowań"],
                    ["Końce wierszy", "LF (Unix) · CRLF (Windows) · CR (dawny Mac)"],
                    ["Nazwa i miejsce", "Jak w każdym oknie zapisu macOS"],
                ]
            ),
            .paragraph("""
                Pasek stanu zawsze pokazuje kodowanie, styl końca wiersza i rozpoznany język. **Kliknięcie \
                któregokolwiek z nich zmienia go natychmiast**, bez przechodzenia przez okno dialogowe.
                """),
            .heading("Powiel · zmień nazwę · przenieś"),
            .paragraph("""
                Te trzy działają na PLIKU, a nie na jego treści — a otwarta karta podąża za plikiem, więc \
                nigdy nie tracicie swojego miejsca.
                """),
            .table(
                headers: ["Polecenie", "Co robi"],
                rows: [
                    ["`Powiel plik`",
                     "Kopiuje go jako `nazwa 2.txt` obok oryginału i **otwiera kopię** — bo powiela się po to, żeby edytować kopię"],
                    ["`Zmień nazwę pliku…`", "Zmienia nazwę na dysku; karta podąża za nową nazwą"],
                    ["`Przenieś plik do…`", "Przenosi do innego katalogu; karta podąża"],
                ]
            ),
            .note("""
                Wszystkie trzy **odmawiają, gdy w miejscu docelowym już istnieje plik o tej nazwie**; nigdy \
                nie nadpisują. I wszystkie trzy wymagają pliku zapisanego przynajmniej raz — dokument, \
                którego nigdy nie było na dysku, nie ma czego powielać ani przenosić.
                """),
            .heading("Bezpieczny zapis"),
            .bullets([
                "Zapis jest **niepodzielny**: zanik zasilania w połowie nigdy nie zostawia obciętego pliku.",
                "Jeśli inny program zmieni plik, gdy macie go otwarty, GEditor to zauważa i pyta przed nadpisaniem.",
                "Pliki na iCloud Drive albo w zasobie sieciowym przechodzą przez systemowego koordynatora plików, żeby dwie maszyny sobie nie wchodziły w drogę.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Karty, okna i widok podzielony",
        summary: "Wiele kart w oknie, wiele okien i karty, które można przeciągać między nimi.",
        keywords: ["karta", "okno", "podział", "panel"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Nowa karta"),
                HelpShortcut("⌘W", "Zamknąć kartę"),
                HelpShortcut("⇧⌘T", "Otworzyć ponownie ostatnio zamkniętą kartę"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Następna / poprzednia karta"),
                HelpShortcut("⌥⌘N", "Nowe okno"),
                HelpShortcut("⌃⌘N", "Odłączyć bieżącą kartę do własnego okna"),
            ]),
            .paragraph("""
                Kartę można przeciągnąć do innego okna albo upuścić na pustym miejscu, żeby utworzyć okno. \
                **Karta przypięta nie podróżuje** — przypięcie znaczy «zostaw tę tutaj».
                """),
            .note("""
                `⇧⌘T` otwiera ponownie ostatnio zamkniętą kartę, także **niezapisaną**: jej treść wciąż tam \
                jest.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Otwarcie katalogu jako przestrzeni roboczej",
        summary: "Drzewo plików na pasku bocznym, wyszukiwanie w całym projekcie i otwieranie jednym kliknięciem.",
        keywords: ["przestrzeń robocza", "katalog", "projekt", "pasek boczny"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Otworzyć katalog jako przestrzeń roboczą")]),
            .paragraph("""
                Drzewo pojawia się na pasku bocznym (`⌘0`). Kliknijcie plik, żeby go otworzyć, a `⇧⌘F` szuka \
                w całym katalogu.
                """),
            .note("""
                W wydaniu z App Store dostęp do katalogu trzyma **zakładka o zasięgu bezpieczeństwa**, więc \
                kolejne uruchomienie wciąż do niego sięga, nie prosząc o ponowny wybór katalogu.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "Sesja odtwarza się sama",
        summary: "Zamknijcie i otwórzcie ponownie: każda karta wraca, także niezapisane.",
        keywords: ["sesja", "odtworzyć", "niezapisane", "odzyskać"],
        blocks: [
            .paragraph("""
                Nic nie trzeba włączać. Zamknijcie GEditora i otwórzcie go znowu: karty, ich kolejność, \
                położenia karetki i przewinięcia — wszystko wraca.
                """),
            .heading("A karty niezapisane"),
            .paragraph("""
                Ich treść trzymana jest w osobnej migawce, więc też wracają. Jeśli program zakończy się \
                nienormalnie, kolejne uruchomienie **pyta** przed odtworzeniem osieroconych szkiców — zamiast \
                po cichu odbudować stertę kart, których nie pamiętacie.
                """),
            .warning("""
                Sesja **nie jest kopią zapasową**. Zachowuje stan pracy, a nie historię. Wszystko, co ważne, \
                nadal trzeba zapisać do pliku.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Wcześniej zapisane wersje",
        summary: "Przeglądać i przywracać starsze wersje pliku.",
        keywords: ["wersje", "historia", "przywrócić", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Przy każdym zapisie GEditor odnotowuje **poprzednią** wersję, zanim nadpisze. `Makro ▸ \
                Zapisane wersje…` otwiera ich przeglądarkę.
                """),
            .bullets([
                "Magazyn wersji jest **systemu operacyjnego**, ten sam mechanizm, którego używają programy Apple.",
                "Przywrócenie starszej wersji to **zwykła edycja** — `⌘Z` ją cofa.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Śledzenie pliku wciąż zapisywanego",
        summary: "Jak `tail -f`: to, co jest dopisywane, pojawia się w miarę napływania.",
        keywords: ["tail", "śledzić", "dziennik", "na żywo"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Plik ▸ Śledź plik (tail -f)` wczytuje to, co pojawia się na końcu pliku, i przewija się \
                razem z nim.
                """),
            .warning("""
                W czasie śledzenia dokument staje się **tylko do odczytu**. Pisanie, gdy z dysku wczytywany \
                jest nowy tekst, to dwaj piszący spierający się o jeden dokument, a przegranym zawsze jest \
                to, co właśnie napisaliście.
                """),
            .note("""
                Pasek stanu przez cały czas mówi **Śledzenie**, więc kilka minut później wciąż wiecie, \
                dlaczego plik nie przyjmuje pisania. Kliknięcie członu **tylko do odczytu** podaje powód bez \
                ogródek.

                Śledzenie należy do **karty, która je uruchomiła**, a nie do okna: otwórzcie inną kartę i \
                piszcie dalej, a nowe wiersze dziennika nadal płyną do swojej karty, nie tykając pliku, który \
                edytujecie.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Drukowanie",
        summary: "Drukować przez standardowe okno drukowania macOS.",
        keywords: ["drukować", "papier", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Drukować")]),
            .paragraph("""
                Korzysta z systemowego okna drukowania, więc i wywóz do PDF odbywa się tam — przycisk `PDF` \
                w lewym dolnym rogu.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Obrazy, PDF, pliki Office, dźwięk, wideo i archiwa",
        summary: "Osiem rodzajów plików otwiera się w GEditorze bez innego programu.",
        keywords: ["obraz", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "archiwum",
                   "dźwięk", "wideo"],
        blocks: [
            .table(
                headers: ["Rodzaj", "Co można zrobić"],
                rows: [
                    ["Obrazy", "Oglądać, powiększać, obracać; **obrazy ruchome odtwarzają się** i można je wstrzymać"],
                    ["Dźwięk", "Odtwarzać, przewijać, zmieniać głośność"],
                    ["Wideo", "Odtwarzać, przewijać, pełny ekran, obraz w obrazie"],
                    ["PDF", "Czytać, szukać, **komentować**"],
                    ["Word · Excel · PowerPoint", "Oglądać **i edytować** — `⌘S` zapisuje wprost z powrotem do pliku"],
                    ["ZIP · TAR · GZ · XZ", "Wyliczyć wpisy i otworzyć każdy jako kartę"],
                    ["7z · RAR i siedem innych formatów", "To samo, przez libarchive"],
                ]
            ),
            .paragraph("""
                Otwarcie wpisu w archiwum tworzy kartę z jego treścią. Wietnamskie znaki diakrytyczne \
                przeżywają i w nazwach, i w treści.
                """),
            .note("""
                Zmieńcie jeden z trzech formatów Office, naciśnijcie `⌘S`, a zostanie zapisany z powrotem do \
                pliku — LibreOffice czyta wynik. Ta droga jest sprawdzona od początku do końca, a nie tylko \
                wywieziona do kopii.
                """),
            .heading("Dźwięk i wideo korzystają z odtwarzaczy macOS"),
            .paragraph("""
                Odtwarzanie idzie przez dekodery systemu, więc nic dodatkowego nie jest pobierane ani \
                dołączane. W zamian kilka formatów **się nie odtworzy** — `.mkv`, `.webm`, `.avi`, `.wmv` — \
                bo macOS nie ma dla nich wbudowanego dekodera.
                """),
            .paragraph("""
                Dla takiego pliku GEditor **mówi dlaczego**, zamiast pokazywać czarny prostokąt, i proponuje \
                podgląd binarny albo inny program.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "Narzędzia PDF",
        summary: "Czytać, komentować i cała warstwa stron: obracać · przesuwać · usuwać · wyodrębniać · scalać.",
        keywords: ["pdf", "strona", "obrócić", "usunąć stronę", "wyodrębnić", "scalić",
                   "komentować", "podświetlić", "podpisać"],
        blocks: [
            .paragraph("""
                Widok PDF ma **dwa paski narzędzi**, odpowiadające na różne pytania. Górny rząd działa na \
                **treści** jednej strony; dolny na **zbiorze stron**.
                """),
            .heading("Górny rząd — czytanie i komentowanie"),
            .table(
                headers: ["Przycisk", "Co robi"],
                rows: [
                    ["Podświetl · Podkreśl", "Oznaczyć zaznaczony tekst"],
                    ["Notatka…", "Doczepić notatkę do strony"],
                    ["Usuń komentarze", "Zdjąć każdy komentarz z bieżącej strony"],
                    ["Wyodrębnij tekst do karty", "Przenieść cały tekst do karty, żeby szukać, filtrować, użyć innych narzędzi"],
                    ["Pole wyszukiwania", "Szukać w PDF — **pisanie bez znaków diakrytycznych i tak znajduje tekst z nimi**"],
                ]
            ),
            .note("""
                Zeskanowany PDF nie ma warstwy tekstowej. Polecenie wyodrębniania **mówi to**, zamiast \
                otwierać pustą kartę i zostawiać was ze zgadywaniem.
                """),
            .heading("Dolny rząd — operacje na stronach"),
            .table(
                headers: ["Przycisk", "Co robi", "Da się cofnąć"],
                rows: [
                    ["Obróć w lewo · w prawo", "Obrócić bieżącą stronę o 90°", "Tak"],
                    ["Strona w górę · w dół", "Zamienić bieżącą stronę z sąsiednią", "Tak"],
                    ["Usuń strony…", "Usunąć zakresem, np. `2-4,7`", "Tak"],
                    ["Wyodrębnij strony…", "Zapisać zakres stron jako **nowy plik**", "Nie tyka otwartego pliku"],
                    ["Scal PDF…", "Wstawić inny PDF tuż za bieżącą stroną", "Tak"],
                    ["Podpisz…", "Umieścić obraz podpisu na bieżącej stronie", "Tak"],
                    ["Edytuj tekst…", "Narysować tekst zastępczy na zaznaczeniu", "Tak"],
                    ["Następne puste pole", "Przejść do kolejnego niewypełnionego pola formularza", "—"],
                    ["Wyczyść wpisane wartości", "Opróżnić każde pole formularza", "Tak"],
                    ["Cofnij zmianę strony", "Cofnąć jedną operację na stronach", "—"],
                    ["Zapisz zmienioną kopię…", "Zapisać nowy plik, a potem **otworzyć go ponownie dla sprawdzenia**", "—"],
                ]
            ),
            .heading("Formularze do wypełnienia"),
            .paragraph("""
                Otwórzcie PDF z polami formularza, a pasek stanu powie, **ile** ich jest. Piszcie wprost w \
                pola na stronie, a potem `Zapisz zmienioną kopię…`.
                """),
            .bullets([
                "Wartości przechowywane są jako **żywe pola formularza**, a nie spłaszczony tekst — dzięki temu Acrobat odbiorcy wciąż widzi wypełniony formularz i może go poprawić.",
                "Wietnamskie znaki diakrytyczne przeżywają obieg zapis-i-ponowne-otwarcie. Strzeże tego test, z nazwiskiem `Nguyễn Văn Anh`.",
                "`Następne puste pole` skacze do kolejnego pustego — naturalna droga przez długi formularz.",
            ]),
            .heading("Podpisywanie"),
            .paragraph("""
                Przygotujcie obraz podpisu (PNG z przezroczystym tłem sprawdza się najlepiej), **zaznaczcie \
                miejsce do podpisu** — zwykle linia albo słowo «Podpis» — i naciśnijcie `Podpisz…`. Bez \
                zaznaczenia podpis ląduje w prawym dolnym rogu.
                """),
            .note("""
                Podpis zachowuje **proporcje** obrazu: podpis ściśnięty albo rozciągnięty od razu wygląda \
                fałszywie.
                """),
            .heading("Edycja tekstu — i trzy rzeczy do poznania wcześniej"),
            .paragraph("""
                Zaznaczcie tekst do zmiany i naciśnijcie `Edytuj tekst…`. GEditor **zakrywa ten obszar barwą \
                tła pobraną tuż obok** i rysuje na wierzchu nowy tekst.
                """),
            .warning("""
                **Stary tekst jest ZAKRYTY, a nie USUNIĘTY.** Wciąż jest w pliku i wciąż da się go \
                wyodrębnić poleceniem `Wyodrębnij tekst do karty` albo dowolnym innym narzędziem. To **nie \
                jest zaczernianie**: ukryty w ten sposób numer dokumentu jest ukryty przed ludzkim okiem, a \
                nie przed maszyną.
                """),
            .bullets([
                "**Nowy tekst nadal daje się znaleźć przez `⌘F`.** Jest narysowany jako prawdziwy tekst, a nie obraz — zmierzone testem, nie założone.",
                "**Krój pisma jest systemowy**, a nie pierwotny krój dokumentu. Celowo: kroje osadzone w PDF często nie mają wietnamskich znaków diakrytycznych, a `Nguyễn` dotarłby jako `Nguy?n`.",
                "**Na tle we wzór łata jest widoczna** — barwa zakrycia pobierana jest w jednym punkcie tuż na lewo od zaznaczenia.",
            ]),
            .heading("Dlaczego zamalowywać, a nie edytować strumień treści"),
            .paragraph("""
                Edytowanie strumienia treści PDF wprost oznacza mierzenie się z podzbiorami krojów niosącymi \
                własne kodowanie, ze zdaniami rozbitymi kerningiem na trzy kawałki i z tablicami szerokości \
                znaków, które trzeba przeliczyć na nowo. Zrobienie tego poprawnie dla **każdego** pliku to \
                osobne przedsięwzięcie; zrobienie tego źle psuje czyjś dokument.
                """),
            .paragraph("""
                W zamian reszta strony **nie zmienia się ani o bajt**, a strona pozostaje stroną — tekst wciąż \
                się zaznacza, kopiuje i przeszukuje. Przerysowanie **nie** zamienia jej w obraz.
                """),
            .heading("Składnia zakresów stron"),
            .table(
                headers: ["Wpiszcie", "Znaczenie"],
                rows: [
                    ["`5`", "Tylko strona 5"],
                    ["`2-4`", "Strony 2, 3, 4"],
                    ["`-3`", "Od początku do strony 3"],
                    ["`8-`", "Od strony 8 do końca"],
                    ["`1-3,5,9-`", "Kilka części połączonych przecinkami"],
                ]
            ),
            .paragraph("Strony liczy się **od 1**, czyli od liczby, którą widzicie na ekranie."),
            .warning("""
                Zakres odwrócony (`5-2`) i zakres poza koniec (`1-999`) są oba **odrzucane z podaniem \
                powodu**, nigdy po cichu poprawiane na coś zbliżonego. W poleceniu usuwającym strony złe \
                zgadnięcie znaczy utratę stron, a ciche przycięcie zamienia literówkę w prawidłowe polecenie.
                """),
            .heading("Pierwotny plik nigdy nie jest nadpisywany"),
            .paragraph("""
                Wszystko powyżej zmienia dokument **w pamięci**. Dopiero gdy naciśniecie `Zapisz zmienioną \
                kopię…` i wybierzecie miejsce, zapisywany jest plik — a po zapisie GEditor **otwiera ten sam \
                plik ponownie**, żeby potwierdzić, że wciąż ma wszystkie strony.
                """),
            .paragraph("""
                Powód: źle zapisany plik leży na dysku, wyglądając zupełnie normalnie, a użytkownik dowiaduje \
                się dopiero po wysłaniu.
                """),
            .note("""
                Wiersz stanu widoku mówi **· zmieniony, niezapisany**, ilekroć dokument różni się od pliku na \
                dysku.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
