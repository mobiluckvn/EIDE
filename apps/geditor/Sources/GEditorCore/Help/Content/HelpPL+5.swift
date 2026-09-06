import Foundation

/// Polska treść pomocy — część 5: raporty, wiedza, automatyzacja i sam program.
extension HelpPL {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Raporty i schematy",
        summary: "Plik tekstowy dający raport HTML, którego liczby są przeliczane, oraz schematy Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "Raporty `.greport.md`",
        summary: "Markdown plus cztery rodzaje bloków wykonywalnych — pisać po lewej, podglądać po prawej.",
        keywords: ["raport", "greport", "html", "wywóz", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Plik `.greport.md` to **zwykły Markdown** plus kilka wykonywalnych bloków ogrodzonych. Jego \
                narysowanie daje **samodzielny** plik HTML — bez sieci, bez plików towarzyszących — który \
                każdy może otworzyć.
                """),
            .paragraph("""
                Ponieważ to zwykły tekst, daje się go **porównywać, wersjonować i udostępniać** — ta sama \
                myśl co przy przepisach czyszczenia i zestawach zasad jakości.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — pełny raport",
                  source: """
                    ---
                    title: Raport sprzedaży za sierpień
                    source: sales-2026-08.csv
                    ---

                    # Raport sprzedaży za sierpień

                    Liczby na 31 sierpnia 2026.

                    ## Przychód wedle prowincji

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Przychód wedle prowincji
                    y_label: Przychód
                    number_format: vi
                    suffix: " ₫"
                    source: Źródło — sales-2026-08.csv
                    ```

                    ## Jakość danych źródłowych

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Rodzaje bloków"),
            .table(
                headers: ["Blok", "Daje"],
                rows: [
                    ["`query`", "Tabelę, z instrukcji SQL DuckDB"],
                    ["`chart`", "Wykres"],
                    ["`quality`", "Kartę oceny jakości danych"],
                    ["`mining`", "Tabelę uszeregowania z eksploracji wedle grup"],
                    ["`mermaid`", "Schemat"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                Blok `---` na górze deklaruje `title` i `source` — domyślne źródło danych dla każdego bloku, \
                który nie podaje własnego.
                """),
            .note("""
                Podgląd przebudowuje się, gdy przestajecie pisać, ale **tylko analizuje**; nie wykonuje zapytań \
                przy każdym naciśnięciu klawisza. Błędy dokumentu i błędy danych zgłaszane są osobno — *«blok \
                chart nie ma klucza `kind`»* to błąd pliku, *«kolumna `doanh_thu` nie istnieje»* to błąd \
                danych.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "Blok `query`",
        summary: "Jedna instrukcja DuckDB staje się jedną tabelą w raporcie.",
        keywords: ["zapytanie", "sql", "tabela", "raport", "blok"],
        blocks: [
            .paragraph("""
                Zawartość bloku to **jedna instrukcja SQL**, wykonywana na źródle raportu. Tabela nazywa się \
                `t`, w tym samym dialekcie co w panelu zapytań.
                """),
            .code(language: "text", caption: "Blok query z parametrem",
                  source: """
                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu
                    FROM t
                    WHERE thang = :thang
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    ```
                    """),
            .paragraph("""
                `:thang` to **parametr**. Podawany jest przy rysowaniu — z powłoki przez `--param thang=8` \
                albo z pliku listy przy wytwarzaniu raportów wsadowo.
                """),
            .note("""
                Tabele w raporcie danych **powinny pochodzić z bloku query**, a nie być wpisane ręcznie. \
                Tabela wpisana ręcznie nie przelicza się, gdy liczby się zmieniają, i prędzej czy później \
                zaczyna przeczyć reszcie raportu.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "Blok `chart`",
        summary: "Ustawienie w YAML staje się wykresem — i najważniejsza zasada tego formatu.",
        keywords: ["wykres", "yaml", "raport", "rysować"],
        blocks: [
            .code(language: "yaml", caption: "Każdy klucz bloku chart",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Przychód wedle prowincji
                    x_label: Prowincja
                    y_label: Przychód
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Źródło — sales.csv, stan na 26 sierpnia 2026
                    """),
            .heading("Bez `query` używa wyniku bloku query BEZPOŚREDNIO POWYŻEJ"),
            .paragraph("""
                To najważniejsza zasada tego formatu. Dzięki niej zwykły raport «tabela, a potem wykres tej \
                tabeli» nie powtarza SQL-a — a powtórzenie znaczy, że dwie kopie w końcu się rozjadą, i wtedy \
                tabela i wykres mówią na jednej stronie różne rzeczy.
                """),
            .warning("""
                W zamian **kolejność bloków ma znaczenie**: wstawienie bloku query pomiędzy zmienia dane \
                wykresu poniżej.
                """),
            .heading("Dlaczego `source` jest osobnym kluczem"),
            .paragraph("""
                Wzmianka o źródle napisana prozą pod wykresem wyświetla się doskonale — na ekranie. Ale wykres \
                zostanie wywieziony jako PNG i wklejony gdzie indziej, a proza zostaje z tyłu. Jako klucz jest \
                rysowana **wewnątrz obrazu** i podróżuje razem z nim.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "Blok `quality`",
        summary: "Karta oceny jakości danych wewnątrz raportu.",
        keywords: ["jakość", "karta oceny", "raport", "blok"],
        blocks: [
            .code(language: "yaml", caption: "Każdy klucz bloku quality",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # puste znaczy własne źródło raportu
                    title: Jakość danych sprzedaży za sierpień
                    rules: true                 # pokazać tabelę zasad zdanych/niezdanych
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # ustalić datę odniesienia dla «Aktualności»
                    fail_under: 90              # poniżej karta zmienia barwę na ostrzegawczą
                    """),
            .table(
                headers: ["`chart`", "Rysuje"],
                rows: [
                    ["`violations`", "Liczbę wierszy dla zasad **niezdanych** — odpowiada na «co naprawić najpierw»"],
                    ["`dimensions`", "Oceny sześciu wymiarów"],
                    ["`none`", "Tylko tabela, bez wykresu"],
                ]
            ),
            .note("""
                Ustawcie `now:` w raporcie okresowym. Bez tego *Aktualność* porównuje się z chwilą rysowania, \
                więc ponowne narysowanie zeszłomiesięcznego raportu daje ocenę inną niż ta, którą \
                opublikowaliście.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "Blok `mining`",
        summary: "Uszeregować grupy wedle odchyleń, błędu prognozy albo rozbieżności korelacji.",
        keywords: ["eksploracja", "raport", "uszeregowanie grup"],
        blocks: [
            .code(language: "yaml", caption: "Każdy klucz bloku mining",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # kolumna do odchyleń i prognozy
                    pair: chi_phi             # druga kolumna, do korelacji wedle grup
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # puste znaczy własne źródło raportu
                    title: Eksploracja wedle prowincji
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Szereguje wedle"],
                rows: [
                    ["`anomalies`", "Grupy o największej liczbie odbiegających wierszy"],
                    ["`forecast_error`", "Grupy o najgorszej prognozie"],
                    ["`correlation_gap`", "Grupy, której korelacja najbardziej rozchodzi się z tabelą zbiorczą — łapie paradoks Simpsona"],
                ]
            ),
            .warning("""
                **Żaden klucz nie wyłącza bloku «Metoda».** Uszeregowanie grup bez metody nie daje \
                czytelnikowi sposobu, by dowiedzieć się, wobec jakiego ogrodzenia zmierzono «najwięcej \
                odchyleń». Kto chce to ukryć, zna już odpowiedź, której pragnie.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Wytwarzanie raportów wsadowo",
        summary: "Jeden wzór, jedna lista parametrów, wiele raportów.",
        keywords: ["wsad", "masowo", "parametry", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Jeden wzór raportu, wykonywany dla każdego oddziału albo każdego miesiąca. Lista parametrów to \
                plik CSV albo JSON — **jeden wiersz na raport**.
                """),
            .code(language: "text", caption: "list.csv — jeden wiersz na raport",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Narysować cały wsad z powłoki",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Albo jeden raport z parametrami podanymi ręcznie",
                  source: """
                    geditor --report template.greport.md \\
                            --param thang=8 --param tinh="Hà Nội" \\
                            --out ./reports/
                    """),
            .seeAlso(["khoi-query", "dong-lenh"]),
        ]
    )

    static let mermaid = HelpTopic(
        id: "mermaid",
        title: "Schematy Mermaid",
        summary: "Rysować schematy tekstem, zmieniać je poleceniami, podglądać ze zgodnością w obie strony.",
        keywords: ["mermaid", "schemat", "schemat blokowy", "sekwencja", "rysować"],
        commands: [
            "Sơ đồ Mermaid: xem trước", "Sơ đồ Mermaid: chèn mẫu…",
            "Sơ đồ Mermaid: thêm phần tử…", "Sơ đồ Mermaid: nối hai phần tử đang chọn",
            "Sơ đồ Mermaid: sửa nhãn phần tử đang chọn…", "Sơ đồ Mermaid: xoá phần tử đang chọn",
            "Sơ đồ Mermaid: đưa message lên trên", "Sơ đồ Mermaid: đưa message xuống dưới",
            "Sơ đồ Mermaid: định dạng lại", "Sơ đồ Mermaid: tách khối ra tệp .mmd…",
            "Sơ đồ Mermaid: nhúng tệp tham chiếu trở lại",
        ],
        blocks: [
            .paragraph("""
                Mermaid rysuje schematy **z tekstu**: wy piszecie opis, a maszyna go rysuje. Dzięki temu \
                schemat daje się porównywać i wersjonować — czego plik obrazu nie potrafi.
                """),
            .paragraph("""
                Otwórzcie `Schemat Mermaid: podgląd`, żeby mieć widok obok edytora. Oba są **zgodne w obie \
                strony**: zaznaczcie element na obrazie, a karetka skoczy do jego wiersza.
                """),
            .heading("Zmieniać poleceniami, a nie przepisując"),
            .table(
                headers: ["Polecenie", "Co robi"],
                rows: [
                    ["Wstaw wzór…", "Wstawić gotowy szkielet dla każdego rodzaju schematu"],
                    ["Dodaj element…", "Dodać węzeł albo uczestnika"],
                    ["Połącz dwa zaznaczone elementy", "Narysować strzałkę między nimi"],
                    ["Zmień etykietę zaznaczonego elementu…", "Zmienić tekst bez szukania wiersza"],
                    ["Usuń zaznaczony element", "Usunąć węzeł **oraz** każdą krawędź, która go dotyka"],
                    ["Przesuń wiadomość w górę / w dół", "Przestawić kroki w schemacie sekwencji"],
                    ["Przeformatuj", "Wciąć i wyrównać cały blok"],
                ]
            ),
            .heading("Wydzielenie do pliku i ponowne osadzenie"),
            .paragraph("""
                Duże schematy zasługują na własny plik `.mmd`: `Wydziel blok do pliku .mmd…` przenosi go i \
                zostawia odsyłacz. `Osadź z powrotem plik z odsyłacza` robi odwrotnie, gdy musicie wysłać \
                jeden plik.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Częsta składnia Mermaid",
        summary: "Cztery najczęściej używane rodzaje schematów, każdy ze wzorem, który działa.",
        keywords: ["mermaid", "składnia", "blokowy", "sekwencja", "gantt", "klasy", "wzór"],
        blocks: [
            .code(language: "mermaid", caption: "Schemat blokowy — proces zatwierdzania zamówienia",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Schemat sekwencji — przebieg płatności",
                  source: """
                    sequenceDiagram
                        participant K as Khách
                        participant W as Website
                        participant T as Cổng thanh toán
                        K->>W: Đặt hàng
                        W->>T: Tạo giao dịch
                        T-->>W: Mã giao dịch
                        W-->>K: Chuyển tới trang thanh toán
                        K->>T: Xác nhận
                        T-->>W: Kết quả
                    """),
            .code(language: "mermaid", caption: "Schemat klas — model danych",
                  source: """
                    classDiagram
                        class DonHang {
                            +String maDon
                            +Date ngayDat
                            +tongTien() Double
                        }
                        class KhachHang {
                            +String ten
                            +String soDienThoai
                        }
                        KhachHang "1" --> "*" DonHang : đặt
                    """),
            .code(language: "mermaid", caption: "Gantt — plan wydania",
                  source: """
                    gantt
                        title Kế hoạch phát hành
                        dateFormat YYYY-MM-DD
                        section Chuẩn bị
                        Viết tài liệu     :a1, 2026-09-01, 10d
                        Kiểm thử          :a2, after a1, 7d
                        section Phát hành
                        Nộp App Store     :a3, after a2, 3d
                    """),
            .table(
                headers: ["Kształt węzła", "Piszcie"],
                rows: [
                    ["Prostokąt", "`A[Label]`"],
                    ["Zaokrąglony", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Romb (decyzja)", "`A{Label}`"],
                    ["Walec (dane)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Strzałka", "Piszcie"],
                rows: [
                    ["Ciągła, z grotem", "`A --> B`"],
                    ["Kropkowana", "`A -.-> B`"],
                    ["Gruba", "`A ==> B`"],
                    ["Z etykietą", "`A -- label --> B`"],
                ]
            ),
            .note("""
                Kierunek schematu blokowego idzie zaraz po `flowchart`: `TD` z góry na dół, `LR` z lewej na \
                prawo, a także `BT` i `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Pakiet wiedzy

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Pakiet wiedzy",
        summary: "Krojenie, indeksy wyszukiwania, grafy wiedzy, byty i ocena wyszukiwania.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Czym jest pakiet wiedzy",
        summary: "Narzędzia do przygotowania i sprawdzenia danych dla układu odpowiadającego na pytania z dokumentów.",
        keywords: ["rag", "wiedza", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Gdy buduje się układ odpowiadający na pytania ze zbioru dokumentów, większość pracy leży nie w \
                modelu, lecz w **przygotowaniu danych**: pokrojeniu dokumentów na sensowne fragmenty, \
                sprawdzeniu jakości tych fragmentów, zbudowaniu indeksu i **zmierzeniu, czy wyszukiwanie \
                naprawdę znajduje to, co trzeba**.
                """),
            .paragraph("""
                Ten rozdział to dokładnie narzędzia do tego. Działa **w całości na waszej maszynie** i nigdy \
                nie sięga do sieci.
                """),
            .table(
                headers: ["Zadanie", "Narzędzie"],
                rows: [
                    ["Pokroić dokumenty na fragmenty", "Podgląd krojenia"],
                    ["Obejrzeć i ocenić fragmenty", "Sprawdzanie kawałków JSONL"],
                    ["Przekształcać między postaciami danych", "Przekształcanie wiedzy"],
                    ["Zbudować i obejrzeć graf powiązań", "Graf wiedzy"],
                    ["Znaleźć nazwy własne w tekście", "Oznaczanie bytów"],
                    ["Zmierzyć jakość wyszukiwania", "Pracownia wyszukiwania"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Krojenie i sprawdzanie zbioru JSONL",
        summary: "Podejrzeć granice krojenia na samym tekście, a potem ocenić cały zbiór.",
        keywords: ["chunk", "jsonl", "zbiór", "zachodzenie", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Podgląd krojenia"),
            .paragraph("""
                Otwórzcie dokument tekstowy albo Markdown, wybierzcie sposób i wielkość kawałka. Granice są \
                **podświetlone na samym tekście**, więc widzicie, gdzie cięcie wypada w środku zdania albo \
                przez tabelę, zanim cokolwiek wywieziecie.
                """),
            .bullets([
                "**Stała wielkość** z zachodzeniem.",
                "**Wedle budowy** — na nagłówkach Markdown, zachowując nienaruszony tok dokumentu.",
                "**Wedle akapitów**, łącząc je aż do osiągnięcia wielkości.",
            ]),
            .heading("Sprawdzanie istniejącego zbioru JSONL"),
            .paragraph("""
                Dla zbioru, który już macie (jeden kawałek JSON na wiersz), `JSONL: sprawdź kawałki…` \
                odpowiada: które wiersze nie są poprawnym JSON-em, które kawałki są za krótkie albo za \
                długie, które się powtarzają i które ucięto w środku zdania.
                """),
            .note("""
                Zbiór też da się ocenić **tą samą ramą sześciu wymiarów** co dane tabelaryczne — użyjcie \
                klucza `corpus:` w bloku `quality` raportu.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Przekształcanie formatów wiedzy",
        summary: "Kawałki między JSONL · CSV · Markdown, grafy między DOT · Mermaid · listami krawędzi.",
        keywords: ["przekształcić", "jsonl", "dot", "mermaid", "lista krawędzi"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Z", "Na"],
                rows: [
                    ["Kawałki JSONL", "CSV · Markdown"],
                    ["Kawałki CSV", "JSONL · Markdown"],
                    ["Graf DOT", "Mermaid · lista krawędzi"],
                    ["Lista krawędzi", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Przed utworzeniem nowej karty jest **podgląd pięciu wierszy**, ten sam mechanizm co przy \
                przekształcaniu CSV.
                """),
            .paragraph("""
                `Otwórz trójki/krawędzie jako tabelę` pokazuje plik trójek albo listę krawędzi jako tabelę — \
                filtrujcie i sortujcie jak w każdym innym CSV.
                """),
            .note("""
                Kierunku **Markdown → JSONL** w tym poleceniu nie ma: ten kierunek *jest* krojeniem, a \
                polecenie odsyła was tam. Dwa wykonania jednego cięcia dałyby dwa różne wyniki.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Grafy wiedzy",
        summary: "Sprawdzić składnię, ocenić kondycję i wykonać algorytmy na grafach o milionie krawędzi.",
        keywords: ["graf", "dot", "cypher", "pagerank", "louvain", "sprawdzenie składni"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor czyta grafy jako **DOT**, jako **listy krawędzi** i jako **trójki**. `Sprawdź składnię \
                grafu` łapie błędy składni, węzły wiszące i krawędzie wskazujące na węzły nieistniejące.
                """),
            .heading("Dostępne algorytmy"),
            .table(
                headers: ["Algorytm", "Odpowiada na"],
                rows: [
                    ["Sąsiedztwo o k skokach", "Co wiąże się z tym węzłem w k krokach"],
                    ["Składowe spójne", "Z ilu rozłącznych kawałków składa się graf"],
                    ["PageRank", "Które węzły są ważne"],
                    ["Louvain", "Jak graf dzieli się na społeczności"],
                ]
            ),
            .paragraph("""
                Na grafie o **milionie krawędzi** wszystkie cztery działają w czasie od kilku milisekund do \
                mniej więcej sekundy.
                """),
            .note("""
                Graf też da się ocenić **ramą sześciu wymiarów** używaną do tabel i zbiorów — użyjcie klucza \
                `graph:` w bloku `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Oznaczanie bytów z listy",
        summary: "Wczytać listę nazw własnych i znaleźć każde wystąpienie — wedle trzech zasad stworzonych dla wietnamskiego.",
        keywords: ["byt", "nazwa własna", "ner", "oznaczanie", "dopasowanie"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Wczytajcie listę nazw (firmy, wyroby, miejsca), a GEditor podświetli każde wystąpienie w \
                dokumencie, wraz z tabelą liczności.
                """),
            .heading("Trzy zasady dopasowania, wszystkie z wietnamskich danych"),
            .bullets([
                "**Wygrywa dopasowanie najdłuższe.** Gdy na liście są i `An Phát`, i `Công ty An Phát`, zdanie zawierające dłuższy zwrot musi pasować do dłuższego — inaczej zostanie przecięte na dwoje i policzone jako dwa byty, co **zawyża** statystyki.",
                "**Wymagane są granice wyrazu.** `An` nie może pasować wewnątrz `Anh` ani `Hoàn`. Wietnamskie nazwy własne są krótkie i dzielą sylaby z niezliczonymi zwykłymi wyrazami.",
                "**Nieczułe na wielkość liter, ale CZUŁE na znaki diakrytyczne.** `CÔNG TY` i `Công ty` to jedno; `má` i `ma` — nie.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Uzgadnianie odmian bytów",
        summary: "Rozpoznać `Cty An Phát` i `Công ty An Phát` jako jeden — zostawiając wam decyzję.",
        keywords: ["uzgadnianie bytów", "odmiany", "normalizacja nazw", "powtórzenia"],
        blocks: [
            .paragraph("""
                To samo skupianie co przy **przybliżonych powtórzeniach** w tabeli CSV — jedno wspólne \
                wykonanie, a nie dwa.
                """),
            .paragraph("""
                Wynikiem jest **propozycja**: przeglądacie każde skupienie i wybieracie postać wzorcową. Nie \
                ma przycisku «scal wszystko», bo dwie nazwy podobne w 92 % mogą być dwiema prawdziwymi \
                organizacjami.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Pracownia wyszukiwania",
        summary: "Zmierzyć, czy indeks znajduje to, co trzeba, przy pomocy zestawu pytań z odpowiedziami.",
        keywords: ["wyszukiwanie", "bm25", "recall", "mrr", "ndcg", "ocena"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Wczytajcie **zestaw oceniający** — każdy wiersz to pytanie wraz z numerami kawałków, które \
                powinny zostać zwrócone — a potem puśćcie cały wsad na indeks.
                """),
            .table(
                headers: ["Miara", "Odpowiada na"],
                rows: [
                    ["recall@k", "Ile ze zbioru odpowiedzi pojawia się w pierwszych k"],
                    ["MRR", "Jak głęboko stoi pierwszy poprawny wynik"],
                    ["nDCG@k", "Czy uszeregowanie jest dobre, z uwzględnieniem położenia"],
                ]
            ),
            .paragraph("""
                Wyniki przychodzą też **dla każdego pytania**, najgorsze najpierw — to wasza lista rzeczy do \
                naprawienia w zbiorze, w kolejności, która najbardziej się opłaca.
                """),
            .warning("""
                Wszystkie trzy miary to **średnie**, a średnia bardzo wiele ukrywa. Zawsze przeczytajcie \
                tabelę dla poszczególnych pytań, zanim uznacie, że «indeks jest już dość dobry».
                """),
            .paragraph("""
                Dwa ustawienia da się porównać obok siebie, a wynik wpada wprost do raportu `.greport.md`, \
                żeby kolejny przebieg był taki sam.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Makra i automatyzacja

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Makra i automatyzacja",
        summary: "Nagrywać czynności, wykonywać je wsadowo, pisać skrypty i sterować tym z powłoki.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Nagrywanie i odtwarzanie makr",
        summary: "Nagrać ciąg czynności i powtórzyć — cały przebieg to jeden krok cofnięcia.",
        keywords: ["makro", "nagrywać", "odtwarzać", "powtarzać", "automatyzować"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Zacząć / zatrzymać nagrywanie"),
                HelpShortcut("⌃P", "Odtworzyć"),
            ]),
            .steps([
                "`⌃R` zaczyna nagrywanie.",
                "Zróbcie to, co chcecie powtórzyć — pisać, przesuwać karetkę, szukać, zamieniać.",
                "`⌃R` ponownie, żeby zatrzymać.",
                "`⌃P` to odtwarza, a `Makro ▸ Odtwarzaj do końca dokumentu` puszcza do samego końca.",
                "`Makro ▸ Zapisz makro…` nadaje mu nazwę na kolejne sesje.",
            ]),
            .heading("Nagrywa POLECENIA, a nie surowe naciśnięcia klawiszy"),
            .paragraph("""
                Makro przechowuje **to, co zrobiliście**, a nie to, jakie klawisze naciskaliście. Dzięki temu \
                jest niezależne od układu klawiatury i od aktywnej metody wprowadzania, a plik makra jest \
                **czytelny**, gdy go otworzycie.
                """),
            .heading("Kiedy makro się zatrzymuje"),
            .table(
                headers: ["Powód", "Znaczenie"],
                rows: [
                    ["Wyczerpała się liczba powtórzeń", "Zwyczajnie"],
                    ["Krok `find` nic nie znalazł", "Tak właśnie «odtwarzaj do końca pliku» samo się zatrzymuje"],
                    ["Osiągnięto koniec dokumentu", "Nie ma dokąd dalej iść"],
                    ["Odwołaliście", "`Makro ▸ Odwołaj działające makro`"],
                    ["Przebieg niczego nie zmienił ani nie przesunął", "Zatrzymane, żeby nie kręciło się bez końca"],
                ]
            ),
            .note("Cały przebieg — choćby dziesięć tysięcy powtórzeń — to **jeden** krok cofnięcia."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Wykonywanie makra wsadowo",
        summary: "Na wszystkich otwartych kartach albo na katalogu plików nieotwartych.",
        keywords: ["wsad", "wszystkie karty", "katalog", "makro", "maska"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Polecenie", "Zakres", "Da się cofnąć"],
                rows: [
                    ["Wykonaj na wszystkich kartach", "Otwarte karty", "Tak — jeden krok cofnięcia na kartę"],
                    ["Wykonaj na katalogu…", "Pliki na dysku **nieotwarte**", "Nie"],
                ]
            ),
            .warning("""
                Wykonanie na katalogu dotyka plików, które nie są otwarte w żadnej karcie, więc **nie ma \
                cofania**. Domyślnie GEditor **zapisuje nowe pliki**, zamiast nadpisywać pierwowzory. \
                Zostawcie to ustawienie, chyba że macie kopię zapasową albo repozytorium z wersjami.
                """),
            .heading("Filtrowanie plików maską"),
            .paragraph("""
                Wybierak katalogu ma **filtr nazw plików**: wpiszcie `*.csv;*.log`, a makro dotknie tylko \
                tych. To ta sama składnia maski, której używa `Szukaj w katalogu`, z kilkoma wzorcami \
                rozdzielonymi przez `;` albo `,`.
                """),
            .bullets([
                "Zostawcie go **pustym**, a weźmie każdy plik tekstowy, który GEditor umie przeczytać — dawne zachowanie.",
                "Maska **zastępuje** tę listę rozszerzeń, a nie zawęża jej dalej: wpiszcie `*.bak`, a zadziała na plikach `.bak`, choć tego rozszerzenia nie ma na liście tekstowej.",
                "Gdy nic nie pasuje, komunikat **powtarza wam waszą maskę**, zamiast obwiniać pusty katalog.",
            ]),
            .paragraph("""
                To pole ma bardzo praktyczny powód: katalog zawiera 400 plików `.json` i 12 plików `.log`, a \
                wasze makro porządkuje tylko dzienniki. Bez maski przetworzone zostanie także te 400 — a \
                ponieważ wsad zapisuje nowe pliki, jedna pomyłka zostawia 400 kawałków śmieci.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Składnia pliku makra",
        summary: "Siedem rodzajów kroków, pełny format JSON i dwa makra, które działają.",
        keywords: ["makro", "json", "składnia", "format", "zmieniać ręcznie", "udostępniać"],
        blocks: [
            .paragraph("""
                Każde makro to **własny plik JSON** w katalogu `macros/` GEditora. Uszkodzenie zostaje w \
                obrębie jednego makra, a udostępnienie jednego koledze znaczy wysłanie jednego pliku.
                """),
            .code(language: "text", caption: "Gdzie mieszkają pliki",
                  source: "~/Library/Application Support/GEditor/macros/<nazwa-makra>.json"),
            .heading("Siedem rodzajów kroków"),
            .table(
                headers: ["Krok", "Zapisywany jako", "Znaczenie"],
                rows: [
                    ["Wstaw tekst", "`{\"insert\": {\"_0\": \"tekst\"}}`", "Pisać przy karetce; przy zaznaczeniu je zastępuje"],
                    ["Kasuj wstecz", "`{\"deleteBackward\": {}}`", "Jak klawisz kasowania"],
                    ["Kasuj wprzód", "`{\"deleteForward\": {}}`", "Jak ⌦"],
                    ["Przesuń", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Zobaczcie listę kierunków poniżej"],
                    ["Zaznacz wiersz", "`{\"selectLine\": {}}`", "Bez znaku końca wiersza"],
                    ["Szukaj", "`{\"find\": { … }}`", "Znajduje i **zaznacza** kolejne wystąpienie"],
                    ["Zamień zaznaczenie", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` działa, gdy poprzednim krokiem było `find` z regexem"],
                ]
            ),
            .heading("Kierunki przesunięcia"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Pełny krok `find`"),
            .code(language: "json", caption: "Cztery klucze kroku find",
                  source: """
                    {
                      "find": {
                        "pattern": "^([a-z]{2})\\\\t",
                        "mode": "regex",
                        "matchCase": false,
                        "wholeWord": false
                      }
                    }
                    """),
            .paragraph("`mode` przyjmuje `normal`, `extended` albo `regex` — te same trzy tryby co pole wyszukiwania."),
            .heading("Przykład 1 — kod prowincji na początku wiersza wielkimi literami"),
            .code(language: "json", caption: "macros/uppercase-province.json",
                  source: """
                    {
                      "name": "Uppercase province code",
                      "steps": [
                        {
                          "find": {
                            "pattern": "^([a-z]{2,3})\\\\t",
                            "mode": "regex",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "replaceSelection": { "_0": "\\\\U$1\\\\E\\t" } }
                      ]
                    }
                    """),
            .paragraph("""
                Wykonajcie je przez `Makro ▸ Odtwarzaj do końca dokumentu`: to, że krok `find` niczego już nie \
                znajduje, jest właśnie warunkiem zatrzymania.
                """),
            .heading("Przykład 2 — skasować wiersz po każdym wierszu zawierającym TODO"),
            .code(language: "json", caption: "macros/delete-line-after-todo.json",
                  source: """
                    {
                      "name": "Delete line after TODO",
                      "steps": [
                        {
                          "find": {
                            "pattern": "TODO",
                            "mode": "normal",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "move": { "_0": "nextLine" } },
                        { "move": { "_0": "lineStart" } },
                        { "selectLine": {} },
                        { "deleteForward": {} },
                        { "deleteForward": {} }
                      ]
                    }
                    """),
            .warning("""
                Ręcznie zmienione makro wypróbujcie najpierw na kopii. Źle napisany krok `find` sprawia, że \
                makro natychmiast się zatrzymuje — to przypadek łagodny. Złośliwy to wzorzec pasujący szerzej, \
                niż sądziliście, zmieniający tysiące miejsc w obrębie jednego kroku cofnięcia.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "Skrypty JavaScript",
        summary: "Cztery funkcje, jeden plik `.js`, a wszystko, co robi, to jeden krok cofnięcia.",
        keywords: ["skrypt", "javascript", "js", "automatyzować", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Włóżcie plik `.js` do katalogu `scripts/` GEditora i wykonajcie go z `Makro ▸ Skrypt…`. Skrypt \
                widzi dokładnie **cztery** rzeczy:
                """),
            .table(
                headers: ["Wywołanie", "Znaczenie"],
                rows: [
                    ["`doc.text`", "Cały tekst dokumentu"],
                    ["`doc.selection`", "Zaznaczenie (pusty łańcuch, gdy nic nie jest zaznaczone)"],
                    ["`doc.replace(s)`", "Zastąpić **cały dokument** przez `s` — jeden krok cofnięcia"],
                    ["`doc.log(s)`", "Napisać wiersz w panelu wyników"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Ponumerować każdy wiersz.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — zostawić pierwsze trzy kolumny CSV",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Trzy granice, które warto znać"),
            .bullets([
                "**Brak dostępu do plików, brak sieci, brak uruchamiania procesów.** Powierzchnia API jest celowo wąska: poszerzyć ją później jest łatwo, zwęzić — psuje każdy skrypt, który użytkownicy już napisali.",
                "**To nie jest granica bezpieczeństwa.** Skrypty działają w tym samym procesie. Nie uruchamiajcie skryptu, którego nie przeczytaliście.",
                "**Jest granica pięciu sekund.** Powyżej dostajecie komunikat, a program pozostaje używalny — ale wątek tego skryptu **kręci się dalej aż do zamknięcia programu**, zjadając rdzeń. Komunikat to mówi.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filtrowanie przez polecenie zewnętrzne",
        summary: "Przepuścić zaznaczenie przez polecenie uniksowe i wziąć wynik z powrotem.",
        keywords: ["filtr", "polecenie zewnętrzne", "powłoka", "potok", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Zaznaczenie (albo cały dokument) trafia na `stdin` polecenia, a `stdout` tego polecenia je \
                zastępuje.
                """),
            .code(language: "bash", caption: "Kilka częstych",
                  source: """
                    sort -u                     # posortować i usunąć powtórzenia
                    jq .                        # przeformatować JSON
                    tr 'a-z' 'A-Z'              # na wielkie litery
                    grep -v '^#'                # usunąć wiersze komentarza
                    awk -F, '{print $3","$1}'   # zamienić kolejność kolumn
                    """),
            .note("""
                Wynik to **jeden** krok cofnięcia. Jeśli polecenie zwróci kod błędu, GEditor zostawia tekst w \
                spokoju i pokazuje `stderr`.
                """),
            .warning("""
                To polecenie istnieje **tylko w wydaniu z pobrania bezpośredniego**. App Sandbox zabrania \
                uruchamiać kod poza programem, więc w wydaniu z App Store pozycja menu zostaje i wyjaśnia, \
                dlaczego jest niedostępna.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Narzędzie wiersza poleceń `geditor`",
        summary: "Otwierać, czyścić, odpytywać, oceniać i rysować raporty — bez otwierania programu.",
        keywords: ["cli", "wiersz poleceń", "terminal", "geditor", "skrypt", "ci"],
        blocks: [
            .warning("""
                Dostępne tylko w wydaniu z **pobrania bezpośredniego**. Wydanie z App Store działa w \
                piaskownicy, więc zewnętrzny proces wiersza poleceń nie może się z nim połączyć.
                """),
            .heading("Otwieranie plików"),
            .code(language: "bash", caption: "Otworzyć, skoczyć do położenia, czytać z potoku",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # wiersz 120, kolumna 5
                    geditor -w notes.md            # poczekać na zamknięcie pliku przed wyjściem
                    geditor -r app.log             # otworzyć tylko do odczytu
                    git diff | geditor             # wczytać wejście standardowe do nowej karty
                    """),
            .table(
                headers: ["Opcja", "Znaczenie"],
                rows: [
                    ["`-w`, `--wait`", "Poczekać na zamknięcie pliku przed wyjściem — do użycia jako edytor `gita`"],
                    ["`-n`, `--new-window`", "Otworzyć w nowym oknie"],
                    ["`-r`, `--read-only`", "Otworzyć tylko do odczytu"],
                    ["`-i`, `--info`", "Wypisać kodowanie, końce wierszy i liczbę wierszy, potem wyjść — **bez** otwierania programu"],
                    ["`-h`, `--help`", "Pokazać pomoc"],
                    ["`-v`, `--version`", "Pokazać wersję"],
                ]
            ),
            .heading("Działanie bez otwierania programu"),
            .paragraph("""
                Cztery grupy poleceń poniżej działają **w całości w procesie wiersza poleceń**, więc \
                sprawdzają się w CI, gdzie nikt nie jest zalogowany do sesji graficznej.
                """),
            .code(language: "bash", caption: "Czyszczenie przepisem",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Odpytywanie",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Brama jakości — kod 0 zaliczone · 1 niezaliczone · 2 błąd",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Rysowanie raportów",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript i menu Usługi",
        summary: "Czytać i zapisywać dokument z AppleScriptu albo wysyłać tekst do GEditora z innego programu.",
        keywords: ["applescript", "osascript", "usługi", "automatyzacja", "skróty"],
        blocks: [
            .code(language: "applescript", caption: "Odczytać otwarty dokument",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Nadpisać treść i odczytać zaznaczenie",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Otworzyć plik",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Menu Usługi"),
            .paragraph("""
                Zaznaczcie tekst w dowolnym programie, a potem użyjcie menu `Usługi`, żeby wysłać go do \
                GEditora jako nową kartę.
                """),
            .note("""
                Przy pierwszym uruchomieniu AppleScriptu macOS prosi o pozwolenie na automatyzację. To okno \
                systemu, a nie GEditora.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Pakiety rozszerzeń i wtyczki",
        summary: "Dwa rodzaje rozszerzeń i to, w którym wydaniu działa każdy z nich.",
        keywords: ["wtyczka", "rozszerzenie", "pakiet", "natywna"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Pakiety rozszerzeń"),
            .paragraph("""
                Pakiet to **jeden plik JSON** zbierający motyw, skrypty i języki definiowane przez \
                użytkownika. Instalacja kopiuje jeden plik, usunięcie kasuje jeden — a lista pakietów \
                wyprowadzana jest z **dysku**, a nie z rejestru, który mógłby kłamać.
                """),
            .paragraph("Działa w **obu wydaniach**."),
            .heading("Wtyczki natywne"),
            .paragraph("""
                Wtyczki wstępnie skompilowane działają w **osobnym procesie** o wąskiej powierzchni API — \
                wtyczka, która się wywala, nie pociąga za sobą programu.
                """),
            .warning("""
                Wtyczki natywne istnieją **tylko w wydaniu z pobrania bezpośredniego**, bo App Sandbox \
                zabrania wczytywać kod spoza programu. Każda wtyczka musi zostać **raz ręcznie zatwierdzona**, \
                po swoim skrócie, zanim zadziała.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Ustawienia i program

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Ustawienia i program",
        summary: "Ustawienia, skróty, motywy, aktualizacje, przejście z Notepad++, rozwiązywanie kłopotów.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Ustawienia",
        summary: "Każda opcja mieszka w jednym czytelnym pliku JSON, który można skopiować na innego Maca.",
        keywords: ["ustawienia", "preferencje", "opcje", "konfiguracja", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Otworzyć ustawienia")]),
            .paragraph("""
                Nie ma OK ani Anuluj — zmiana działa i zostaje zapisana natychmiast, na sposób macOS.
                """),
            .heading("Plik konfiguracji"),
            .code(language: "text", caption: "Gdzie mieszka",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                To **wcięty plik JSON, który można czytać i zmieniać ręcznie**. Skopiujcie go na innego Maca, \
                a cała wasza konfiguracja pojedzie z nim. Przycisk `Otwórz plik konfiguracji` w ustawieniach \
                prowadzi tam wprost.
                """),
            .heading("Klucze"),
            .table(
                headers: ["Klucz", "Domyślnie", "Znaczenie"],
                rows: [
                    ["`fontSize`", "`13`", "Wielkość pisma edytora"],
                    ["`tabWidth`", "`4`", "Ile kolumn szerokości ma tabulator"],
                    ["`usesTabsForIndent`", "`false`", "Wcinać tabulatorami zamiast spacjami"],
                    ["`languageIndent`", "`{}`", "Wcięcie osobne dla języka — zobaczcie stronę o odstępach"],
                    ["`smartIndent`", "`true`", "Wcięcie samoczynne w nowym wierszu"],
                    ["`highlightAllMatches`", "`true`", "Podświetlać każde trafienie wyszukiwania"],
                    ["`ligatures`", "`false`", "Ligatury — zobaczcie uwagę pod tabelą"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Obcinać odstępy na końcu przy zapisie"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalizować Unicode do NFC przy zapisie"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Kodowanie nowych plików"],
                    ["`defaultEOL`", "`\"lf\"`", "Końce wierszy nowych plików"],
                    ["`language`", "`\"system\"`", "Język interfejsu"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "motyw domyślny", "Który motyw barw jest w użyciu"],
                    ["`showWelcomeOnLaunch`", "`true`", "Otwierać okno powitania przy starcie"],
                    ["`keyBindings`", "`{}`", "Tylko te klawisze, które zmieniliście"],
                ]
            ),
            .note("""
                **Dlaczego ligatury są domyślnie WYŁĄCZONE.** Ligatura zlewa `!=` albo `->` w **jeden** znak \
                graficzny, więc znaki widziane na ekranie przestają odpowiadać znakom w pliku — a edytor \
                kolumn, tryb kolumnowy i zawijanie na kolumnie mierzą wszystkie w kolumnach. Włączcie je do \
                pisania prozy albo jeśli wybraliście krój programistyczny (Fira Code, JetBrains Mono) właśnie \
                dla ligatur.
                """),
            .heading("Sąsiednie katalogi"),
            .table(
                headers: ["Katalog", "Zawiera"],
                rows: [
                    ["`macros/`", "Zapisane makra, po jednym pliku JSON każde"],
                    ["`scripts/`", "Skrypty JavaScript"],
                    ["`themes/`", "Motywy barw"],
                    ["`grammars/`", "Języki definiowane przez użytkownika"],
                ]
            ),
            .warning("""
                Pliku konfiguracji zapisanego przez **nowszego** GEditora **nie nadpisuje** starszy — ten \
                działa na wartościach domyślnych i mówi to. Nadpisanie to najpewniejszy sposób, żeby zniszczyć \
                konfigurację kogoś, kto zgrywa dwie maszyny, a on nigdy by się nie dowiedział dlaczego.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Pasek stanu",
        summary: "Dziesięć członów na dole — każdy czytelny i każdy klikalny.",
        keywords: ["pasek stanu", "położenie", "kodowanie", "tylko odczyt", "wielkość"],
        blocks: [
            .paragraph("""
                To największa różnica wobec pasków stanu innych edytorów: **żaden człon nie jest tylko do \
                odczytu**. Widzicie złą wartość — kliknięcie jej jest sposobem na poprawienie, a nie \
                przetrząsanie menu.
                """),
            .table(
                headers: ["Człon", "Mówi wam", "Po kliknięciu"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "położenie karetki — kolumna w ZNAKACH, `@340` to położenie w bajtach",
                     "otwiera pole `Przejdź do`"],
                    ["`11 byte · 3 dòng`", "wielkość dokumentu",
                     "liczy bajty · znaki · wyrazy · wiersze"],
                    ["`🔒 Chỉ đọc`", "pokazywany tylko wtedy, gdy dokument jest zablokowany",
                     "mówi DLACZEGO jest zablokowany i odblokowuje, gdy to możliwe"],
                    ["`View` / `Code`", "w którym widoku jesteście", "przełącza (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "tryb CSV i używany znak rozdzielający",
                     "przełącza tryb CSV albo **wybiera znak rozdzielający na nowo**"],
                    ["`Đang theo dõi`", "`tail -f` działa", "—"],
                    ["`UTF-8`", "kodowanie", "zinterpretować na nowo albo przekształcić na inne kodowanie"],
                    ["`LF`", "styl końca wiersza", "przełączać LF · CRLF · CR"],
                    ["`Python`", "język barwienia składni", "wybrać inny albo wrócić do rozpoznawania po rozszerzeniu"],
                    ["`Tab: 4`", "szerokość wcięcia", "2 · 4 · 8, ogólnie albo **tylko dla tego języka**"],
                    ["`Ngắt: tắt`", "tryb zawijania", "przechodzi przez trzy tryby"],
                ]
            ),
            .heading("Trzy człony warte drugiego spojrzenia"),
            .bullets([
                "**`@340` — położenie w bajtach.** To liczba, którą mówi każde inne narzędzie w programie: błędy JSON i XML, wyjście `--doc-sweep`, podgląd binarny oraz pole `Przejdź do @340`. Odczytajcie tutaj, wpiszcie tam.",
                "**`~` przy kolumnie** znaczy, że liczba liczy BAJTY, a nie kolumny wzrokowe — zdarza się to tylko w wierszach dłuższych niż 200 KB, gdzie liczenie znaków spowalniałoby każdy ruch karetki.",
                "**`CSV · …` jest klikalny, żeby na nowo wybrać znak rozdzielający.** Rozpoznanie może się mylić, a wtedy każda operacja na kolumnach jest przesunięta, bez żadnego sygnału. Tak mówicie inaczej — to tylko CZYTA plik NA NOWO, nie zmieniając ani bajtu (inaczej niż `CSV ▸ Zmień znak rozdzielający…`, które go przepisuje).",
            ]),
            .note("""
                Człon niedotyczący otwartego pliku jest **ukryty**, a nie wyszarzony: `Tylko do odczytu` \
                pojawia się tylko wtedy, gdy dokument naprawdę jest zablokowany, a `CSV · …` tylko w trybie \
                CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Zmiana skrótów klawiszowych",
        summary: "Zmieniać pojedyncze klawisze albo przejąć w całości układ Notepad++.",
        keywords: ["skrót", "układ klawiszy", "nastawa"],
        blocks: [
            .paragraph("""
                `Ustawienia…` mają dział Skróty z dwoma szybkimi przyciskami: **Użyj nastawy Notepad++** i \
                **Wróć do wartości domyślnych**.
                """),
            .paragraph("""
                Plik konfiguracji odnotowuje tylko to, co **zmieniliście wobec wartości domyślnych**. Dzięki \
                temu, gdy GEditor zmieni domyślny klawisz w nowej wersji, nie utkniecie przy starym układzie \
                bez niczyjej wiadomości.
                """),
            .note("""
                Dwa polecenia nie mogą dzielić skrótu. Gdy dzielą, AppKit po cichu uruchamia tylko **pierwszą** \
                pozycję menu, a drugie polecenie wygląda na zepsute — dlatego GEditor ma sprawdzenie, które \
                temu zapobiega.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Motywy, jasny i ciemny",
        summary: "Podążać za systemem, jasny albo ciemny; a motyw to plik JSON, który można zmieniać.",
        keywords: ["motyw", "barwy", "tryb ciemny", "jasny", "wygląd"],
        blocks: [
            .paragraph("`Ustawienia…` wybierają `Podążaj za systemem`, `Jasny` albo `Ciemny` i wskazują motyw barw."),
            .paragraph("""
                Motyw to plik JSON w `themes/`. Przycisk `Wywieź bieżący motyw` zapisuje jeden jako punkt \
                wyjścia dla waszego.
                """),
            .note("""
                Źle wpisana barwa w pliku motywu wraca do barwy **motywu domyślnego**, a nie do czerni. Czerń \
                wygląda jak decyzja projektowa, a użytkownik poszedłby szukać kłopotu gdzie indziej.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Aktualizacje, wersje i wyjście",
        summary: "Czym różni się aktualizowanie między dwoma wydaniami.",
        keywords: ["aktualizacja", "wersja", "o programie", "wyjść"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Wydanie", "Aktualizuje się przez"],
                rows: [
                    ["App Store", "App Store, jak każdy inny program"],
                    ["Pobranie bezpośrednie", "`Sprawdź aktualizacje…` w programie"],
                ]
            ),
            .paragraph("""
                `O GEditorze` pokazuje działającą wersję i to, którym wydaniem jest — przydatne przy \
                zgłaszaniu kłopotu.
                """),
            .note("""
                W wydaniu z App Store `Sprawdź aktualizacje…` **zostaje w menu** i wyjaśnia, dlaczego nie ma \
                zastosowania, zamiast zniknąć. Brakująca pozycja menu staje się pytaniem do wsparcia.
                """),
            .paragraph("Wyjście nie traci pracy: sesja wraca przy następnym otwarciu."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Korzystanie z tego okna pomocy",
        summary: "Szukać w księdze, zmienić jej język i przywrócić okno powitania.",
        keywords: ["pomoc", "przewodnik", "szukanie", "powitanie", "język"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Otworzyć okno pomocy")]),
            .bullets([
                "Pole wyszukiwania w lewym górnym rogu zagląda w **tekst i przykłady kodu** — wpisanie samego klucza konfiguracji w rodzaju `fail_under` prowadzi na właściwą stronę.",
                "Pisanie **bez znaków diakrytycznych** i tak znajduje tekst z nimi.",
                "Przycisk `Wstecz` wraca do poprzedniej strony.",
                "Przycisk `Kopiuj` przy każdym bloku kodu kopiuje ten blok.",
            ]),
            .heading("Czytanie w innym języku"),
            .paragraph("""
                Menu w prawym górnym rogu tego okna wybiera **język księgi**, niezależnie od języka \
                interfejsu. Zmiana zostawia was **na stronie, którą czytacie** — identyfikatory stron celowo \
                nie są tłumaczone, właśnie po to, żeby to działało.
                """),
            .note("""
                Wyliczane są tylko języki, które naprawdę mają księgę. Pozycja menu przełączająca na coś i \
                zostawiająca tekst bez zmian byłaby pozycją menu, która kłamie.
                """),
            .heading("Przywrócenie okna powitania"),
            .paragraph("""
                Jeśli zaznaczyliście **Nie otwieraj tego okna przy starcie**, otwórzcie je ponownie przez \
                `Pomoc ▸ Obchód funkcji` — pole wyboru u dołu okna pojawia się znowu i można je odznaczyć.
                """),
            .paragraph("Albo przywróćcie `showWelcomeOnLaunch` na `true` w `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Z Notepad++ do GEditora",
        summary: "Które klawisze zamieniają się miejscami, co działa inaczej i czego brakuje.",
        keywords: ["notepad++", "przejście", "windows", "skróty"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Kilka klawiszy **zamienia się miejscami** w macOS, zamiast tylko zamienić `Ctrl` na `⌘`. Oto \
                porównanie.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Dlaczego"],
                rows: [
                    ["`Ctrl+D` Powiel wiersz", "**⇧⌘D**", "Tutaj `⌘D` to wiele karetek, jak w każdym edytorze na Maca"],
                    ["`Ctrl+L` Skasuj wiersz", "**⌘K**", "W macOS `⌘L` znaczy «przejdź do wiersza»"],
                    ["`Ctrl+G` Przejdź do wiersza", "**⌘L**", "Te dwa zamieniają się miejscami"],
                    ["`Ctrl+Q` Zakomentuj", "**⌘/**", "Zwyczaj macOS"],
                    ["`Ctrl+Shift+↑/↓` Przenieś wiersz", "**⌥↑ / ⌥↓**", "W macOS `⌃` należy do Mission Control"],
                    ["`F3` Znajdź następne", "**⌘G**", "Zwyczaj macOS"],
                    ["`Ctrl+F2` Przełącz zakładkę", "**⌘F2**", "F2 i ⇧F2 nadal skaczą między znacznikami"],
                    ["`Alt` + przeciąganie dla kolumn", "**⌥ + przeciąganie**", "Tak samo"],
                    ["`Ctrl+Alt+Shift+↓` Edytor kolumn", "**⌥⌘C**", "Zwyczaj macOS"],
                ]
            ),
            .note("Wolicie się nie uczyć na nowo? `Ustawienia ▸ Skróty ▸ Użyj nastawy Notepad++`."),
            .heading("Rzeczy, które Notepad++ ma, a tutaj działają inaczej"),
            .bullets([
                "**Sesje** odtwarzają się same, łącznie z niezapisanymi kartami — nic nie trzeba włączać.",
                "**Zakładki mają dziewięć barw**, a jeden wiersz może nosić kilka naraz.",
                "**Mapa dokumentu** opisuje *cały* plik, a nie tylko część widoczną.",
                "**Makra** mogą działać «do końca dokumentu» i «na wszystkich kartach», a cały przebieg to jeden krok cofnięcia.",
            ]),
            .heading("Co GEditor dokłada"),
            .bullets([
                "**Warsztat czyszczenia danych** i **profile danych** dla plików CSV.",
                "**Zapytania SQL** wprost na pliku CSV.",
                "**Dawne kodowania wietnamskie** — TCVN3, VISCII, VNI-Windows, czytane, zapisywane i rozpoznawane samoczynnie.",
                "**Wyszukiwanie nieczułe na znaki diakrytyczne** w każdym polu filtra.",
                "**Raporty `.greport.md`** z tabelami i wykresami, które się przeliczają.",
                "**Narzędzie wiersza poleceń `geditor`** w wydaniu z pobrania bezpośredniego.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Częste kłopoty",
        summary: "Sześć sytuacji, przez które ludzie sądzą, że program jest zepsuty.",
        keywords: ["błąd", "kłopot", "nie działa", "rozwiązać", "dlaczego"],
        blocks: [
            .table(
                headers: ["Objaw", "Zwykła przyczyna"],
                rows: [
                    ["Tekst wietnamski wygląda jak krzaki", "Złe kodowanie — kliknijcie kodowanie na pasku stanu"],
                    ["Szukanie tekstu ze znakami nic nie znajduje", "Plik jest w rozłożonym Unicode — wykonajcie `Znormalizuj Unicode` do NFC"],
                    ["Pozycja menu jest wyszarzona", "Wydanie z App Store nie może wykonać tego polecenia — pozycja wyjaśnia dlaczego"],
                    ["Dopasowanie nawiasów odmawia", "Dokument przekracza 1 MB — podświetlenie złej pary jest gorsze niż żadne"],
                    ["Kolumna na pasku stanu ma `~`", "Dokument przekracza 200 KB, więc to liczba bajtów, a nie kolumna wzrokowa"],
                    ["Zapytanie SQL mówi, że trzeba najpierw zapisać", "DuckDB czyta **pliki**, a nie bufor, który edytujecie"],
                ]
            ),
            .heading("Gdy GEditor kończy niespodziewanie"),
            .paragraph("""
                Przy kolejnym starcie mówi o tym pasek, z przyciskiem **Otwórz sprawozdanie** — sprawozdanie \
                otwiera się jako karta, którą można czytać i z której można kopiować jak z każdego pliku \
                tekstowego.
                """),
            .bullets([
                "Sprawozdanie niesie tylko **wersję, wydanie macOS, budowę maszyny, nazwę sygnału i stos wywołań**.",
                "**Żadnej treści dokumentu, ani też ścieżek plików** — ścieżka w rodzaju `~/Biurko/pensje-grudzien.xlsx` ujawniła już trzy rzeczy prywatne, zanim ktokolwiek ją otworzy.",
                "**Nic nigdzie nie jest wysyłane.** Nie ma samoczynnego przesyłania ani serwera, który by to odebrał; plik zostaje w `~/Library/Application Support/GEditor/crash/`, dopóki go nie otworzycie albo nie skasujecie.",
                "Gdy raz otworzyliście sprawozdanie, kolejny start już o nim nie wspomina.",
            ]),
            .heading("Gdzie szukać dalej"),
            .bullets([
                "Pasek stanu pokazuje kodowanie, końce wierszy, język i tryb zawijania — każdy człon jest klikalny.",
                "`settings.json` da się zmieniać ręcznie, gdy okno ustawień nie wystarcza.",
                "`O GEditorze` podaje wersję i odmianę, których potrzebuje zgłoszenie błędu.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
