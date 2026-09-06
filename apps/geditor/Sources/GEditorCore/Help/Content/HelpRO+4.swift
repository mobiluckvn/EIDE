import Foundation

/// Conținut de ajutor în română — partea 4: date tabelare, curățarea și explorarea datelor.
extension HelpRO {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Date tabelare",
        summary: "Vedeți CSV ca tabel, filtrați, sortați, verificați structura, interogați cu SQL, convertiți.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Vizualizarea CSV ca tabel",
        summary: "Un milion de rânduri derulează tot lin, antetele rămân, iar textul-sursă rămâne neatins.",
        keywords: ["csv", "tabel", "grilă", "tsv", "excel", "coloane"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Comută între tabel și text")]),
            .paragraph("""
                Tabelul este **virtualizat**: se construiesc doar rândurile vizibile, așa că un fișier cu \
                un milion de rânduri derulează ca unul cu o sută.
                """),
            .bullets([
                "**Rândul de antet rămâne fixat** la derulare — la rândul 40.000 tot știți care e a noua coloană.",
                "Editați o celulă în tabel; schimbarea merge direct în textul-sursă.",
                "Tabelul și textul sunt **două vederi ale unui fișier**, nu două copii.",
                "**⌘C copiază rândul selectat**, cu celulele despărțite prin TAB — lipiți direct în Excel sau Numbers și fiecare celulă ajunge corect. Celulele cu TAB-uri sau sfârșituri de linie se pun între ghilimele, ca destinația să nu le rupă în două.",
            ]),
            .note("""
                Separatorul se detectează la deschidere (virgulă, punct și virgulă, TAB, bară verticală). \
                Dacă presupunerea e greșită, schimbați-l cu `CSV ▸ Schimbă separatorul…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Registre cu mai multe foi",
        summary: "Deschideți orice foaie a unui .xlsx, iar ⌘S scrie înapoi în foaia pe care o priviți.",
        keywords: ["excel", "xlsx", "foaie", "registru", "mai multe foi"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Deschideți un `.xlsx` și GEditor arată **prima foaie** ca grilă CSV. `CSV ▸ Alege foaia…` \
                enumeră fiecare foaie din fișier și o deschide pe cea aleasă în aceeași filă.
                """),
            .heading("Scrierea înapoi în foaia POTRIVITĂ"),
            .paragraph("""
                `⌘S` scrie modificările în **foaia pe care o priviți**, nu în prima. Celelalte foi nu sunt \
                atinse nici cu un octet.
                """),
            .note("""
                Foaia e ținută minte după **nume**, nu după poziție. Astfel, rearanjarea foilor în Excel \
                între două sesiuni nu duce scrierea pe drum greșit.
                """),
            .warning("""
                Dacă foaia deschisă a fost **redenumită sau ștearsă** în Excel de când ați deschis-o, \
                `⌘S` **refuză să scrie** și o spune. A reveni la prima foaie ar însemna să reverși \
                conținutul unei foi peste alta — fișierul s-ar salva la fel, s-ar redeschide la fel, doar \
                că ar ține datele în locul greșit.
                """),
            .heading("Schimbarea foii cu modificări nesalvate"),
            .paragraph("""
                Schimbarea foii înlocuiește tot conținutul filei, așa că, dacă ceva e nesalvat, GEditor \
                **întreabă mai întâi**. `⌘Z` nu-l poate aduce înapoi, pentru că s-a schimbat tot \
                documentul.
                """),
            .heading("Ce costă reducerea Excel la o grilă"),
            .paragraph("""
                Supraviețuiesc **valorile** — inclusiv rezultatele formulelor, exact numerele pe care le \
                arată Excel. Nu supraviețuiesc: fonturile, culorile, celulele îmbinate, graficele \
                încorporate și formulele înseși.
                """),
            .paragraph("""
                În schimb, acea foaie câștigă tot restul produsului: filtrare, sortare, interogări SQL, \
                bancul de curățare, evaluarea calității, explorare, grafice.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtrare și sortare în tabel",
        summary: "Un câmp de filtrare pe coloană, care înțelege comparația numerică și scrisul fără diacritice.",
        keywords: ["filtru", "sortare", "coloană", "căutare în tabel"],
        blocks: [
            .paragraph("Faceți clic pe un antet de coloană ca să sortați. Câmpul de filtrare de sub el acceptă:"),
            .table(
                headers: ["Scrieți în filtru", "Sens"],
                rows: [
                    ["`hue`", "Conține `hue`, **fără diacritice** — găsește și `Huế`"],
                    ["`=Huế`", "Exact `Huế` (tot fără diacritice)"],
                    ["`>100`", "Mai mare decât 100"],
                    ["`>=100`", "100 sau mai mult"],
                    ["`<0`", "Mai mic decât 0"],
                    ["`100..200`", "Între 100 și 200"],
                    ["gol", "Niciun filtru pe această coloană"],
                ]
            ),
            .paragraph("""
                Filtrarea mai multor coloane este un **și**: un rând trebuie să le satisfacă pe toate. \
                Comparația numerică sare peste celulele nenumerice în loc să le trateze ca zero.
                """),
            .note("""
                Filtrarea este un **fel de a privi**, nu o ștergere. Goliți filtrul și fiecare rând revine.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Verificarea structurii tabelului",
        summary: "Găsiți rândurile cu număr greșit de coloane și celulele de tip greșit — faceți asta întâi.",
        keywords: ["verificare", "număr de coloane", "tip greșit", "date stricate"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Asta rulați **înaintea** oricărui alt lucru pe un fișier trimis de cineva. Răspunde la \
                două întrebări:
                """),
            .bullets([
                "**Care rânduri au număr greșit de coloane?** De obicei o celulă cu o virgulă care n-a fost pusă între ghilimele — și dă peste cap fiecare rând de după ea.",
                "**Care celule au un tip diferit de restul coloanei lor?** De pildă un `n/a` într-o coloană de numere.",
            ]),
            .paragraph("Rezultatele apar ca listă; faceți clic pe unul ca să săriți la acel rând."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Ștergerea coloanelor",
        summary: "Eliminați una sau mai multe coloane cu totul din fișier.",
        keywords: ["șterge coloana", "elimină coloana"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Alegeți din listă coloanele de eliminat și aplicați. Este **un singur** pas de anulare, \
                oricâte rânduri ar avea fișierul.
                """),
            .warning("""
                Spre deosebire de filtrare, asta **editează fișierul real**. Ca să ascundeți doar \
                coloane, folosiți o interogare SQL care enumeră coloanele dorite.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Interogarea CSV cu SQL",
        summary: "SQL-ul complet al DuckDB, rulat direct pe fișierul deschis — doar pentru citire.",
        keywords: ["sql", "interogare", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Tabelul deschis se numește **`t`**. Motorul este **DuckDB**, așa că `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, funcțiile de fereastră și subinterogările funcționează \
                toate.
                """),
            .code(language: "sql", caption: "Venituri pe provincii, cele mai mari întâi",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Filtrare după dată și după o condiție textuală",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Ponderea fiecărei provincii în total — cu o funcție de fereastră",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Îmbinare cu alt fișier de pe disc",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Doar pentru citire, și asta e o garanție fermă"),
            .bullets([
                "Baza de date trăiește **în memorie**; fișierul-sursă este doar citit.",
                "Se acceptă exact **o singură instrucțiune**, și ea **trebuie să fie un `SELECT`**. Orice altceva — inclusiv `COPY … TO 'file'`, pe care DuckDB îl poate folosi foarte bine ca să scrie pe disc — este blocat înainte de a atinge vreo dată.",
            ]),
            .warning("""
                DuckDB citește **fișiere**, nu memorie. Dacă documentul are modificări nesalvate, GEditor \
                trebuie să scrie o copie temporară înainte de interogare. Pentru un fișier foarte mare cu \
                modificări nesalvate, **se oprește și o spune**, în loc să scrie în tăcere sute de \
                megaocteți pe disc pentru o singură interogare.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Tabele pivot și grafice rapide",
        summary: "Pivotați și desenați direct dintr-un rezultat de interogare.",
        keywords: ["pivot", "grafic", "tabel încrucișat", "agregare"],
        blocks: [
            .paragraph("""
                Amândouă se deschid din **tabelul de rezultate**: rulați o instrucțiune SQL, apoi folosiți \
                butonul Pivot sau Grafic din panou.
                """),
            .heading("Pivot"),
            .paragraph("""
                Alegeți coloana de **rânduri**, coloana de **coloane**, coloana de **valori** și agregarea \
                (sumă, număr, medie, minim, maxim) — ca tabelul pivot dintr-o foaie de calcul.
                """),
            .heading("Grafice"),
            .paragraph("""
                Bare, linie, plăcintă, dispersie. Numere formatate în stil vietnamez sau european, iar \
                graficul se exportă ca PNG sau SVG pentru a fi lipit altundeva.
                """),
            .note("""
                Vreți un grafic care **se recalculează odată cu datele** la fiecare construire? Acela e \
                blocul `chart` dintr-un raport `.greport.md`.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Convertirea unui tabel în alt format",
        summary: "TSV, JSON, XML, tabele Markdown, instrucțiuni SQL INSERT — cu previzualizare.",
        keywords: ["conversie", "export", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Format", "Util pentru"],
                rows: [
                    ["TSV", "Lipirea într-o foaie de calcul fără grija virgulelor din celule"],
                    ["JSON", "Alimentarea unui API, a unui script sau a altei unelte"],
                    ["XML", "Sisteme vechi care cer XML"],
                    ["Tabel Markdown", "Lipirea în documentație, într-un README, într-un tichet"],
                    ["Instrucțiuni SQL INSERT", "Încărcarea într-o bază de date"],
                ]
            ),
            .paragraph("""
                Dialogul **previzualizează primele cinci rânduri** înainte de a crea fila nouă — cinci \
                rânduri sunt de ajuns ca să confirmați numele tabelului, ghilimelele și ce coloane au \
                devenit numere.
                """),
            .note("""
                Previzualizarea apelează **aceeași funcție** care produce ieșirea reală, limitată la cinci \
                rânduri. Nu e o simulare care ar putea să nu se potrivească cu rezultatul final.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Schimbarea separatorului",
        summary: "Convertiți un fișier între virgulă, punct și virgulă, TAB și bară verticală.",
        keywords: ["separator", "virgulă", "punct și virgulă", "tab", "csv european"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Fișierele exportate dintr-un Excel vietnamez sau european folosesc de obicei **punct și \
                virgulă**, pentru că acolo virgula e separatorul zecimal.
                """),
            .warning("""
                Schimbarea separatorului **rescrie tot fișierul**. Celulele care conțin noul separator se \
                pun între ghilimele — altfel se rupe structura tabelului.
                """),
            .note("""
                **Dacă detectarea a fost greșită, nu asta e comanda pe care o vreți.** Sunt două munci \
                diferite aici, exact ca la perechea de codificări »reinterpretează« / »convertește«:

                • *Fișierul chiar e separat prin punct și virgulă, iar noi am ghicit virgula* — faceți \
                clic pe segmentul `CSV · …` din **bara de stare** și alegeți-l pe cel corect. Nu se schimbă \
                niciun octet din fișier; doar felul în care e citit.

                • *Fișierul chiar e separat prin virgulă, iar dumneavoastră vreți punct și virgulă* — \
                folosiți comanda de pe această pagină. Ea rescrie fișierul.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Curățarea datelor

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Curățarea datelor — tot fluxul",
        summary: "De la un fișier brut primit la un tabel utilizabil, și un standard de rulat lunar.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Fluxul de curățare, cap la cap",
        summary: "Șase pași de la un fișier necunoscut la un tabel de încredere, și un standard pentru luna viitoare.",
        keywords: ["curățare", "flux", "normalizare", "date ordonate"],
        blocks: [
            .paragraph("""
                Curățarea datelor este **rareori de o singură dată**. Oamenii primesc același șablon de \
                raport în fiecare lună, iar în fiecare lună aceleași coloane trebuie normalizate la fel. \
                Acest flux e făcut exact pentru asta: o faceți manual o dată, apoi o rulați din nou cu o \
                singură comandă.
                """),
            .heading("Șase pași"),
            .steps([
                "**Priviți întâi structura.** `CSV ▸ Verifică datele` — ce rânduri au număr greșit de coloane, ce celule au tip greșit. Asta e prima, pentru că un singur rând deplasat face fără sens orice statistică ulterioară.",
                "**Citiți profilul de date.** Pe coloane: câte celule goale, câte valori distincte, ce tip, unde sunt valorile extreme. Aici înțelegeți fișierul, înainte de a schimba ceva.",
                "**Deschideți bancul de curățare** (`⇧⌘L`). Detectează formate de dată amestecate, numere vietnameze amestecate cu europene, spații rătăcite, valori lipsă. **Previzualizare înainte→după**, apoi aplicați.",
                "**Rezolvați duplicatele aproximative** dacă o coloană de nume sau adrese are variante scrise de mână. Aici decideți dumneavoastră; mașina doar propune.",
                "**Salvați ca rețetă.** Succesiunea pe care tocmai ați executat-o se scrie într-un fișier JSON denumit — acel fișier e cunoașterea dumneavoastră despre aceste date.",
                "**Scrieți un set de reguli de calitate** `.gquality.yaml` și evaluați. De acum, fișierul lunii viitoare trece prin rețetă și se evaluează, iar **poarta din linia de comandă** întoarce un cod de ieșire diferit de zero când pică.",
            ]),
            .heading("De ce această ordine"),
            .bullets([
                "Structura **înaintea** profilului: statistica pe un tabel deplasat este statistică despre altă coloană.",
                "Profilul **înaintea** curățării: trebuie să știți `2 % gol` înainte de a decide să completați sau să eliminați.",
                "Duplicatele aproximative **după** normalizare: `CÔNG TY  A` și `Công ty A` se dovedesc a fi unul singur abia după ce spațiile și majusculele s-au așezat.",
                "Rețeta **înaintea** setului de reguli: rețeta repară, regulile judecă — a evalua un tabel nereparat dă doar un număr mic pe care îl așteptați deja.",
            ]),
            .heading("După prima dată, fiecare lună e o singură comandă"),
            .code(language: "bash", caption: "Curăță și evaluează, cu cod de ieșire pentru CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Codul de ieșire **0** înseamnă trecut, **1** picat, **2** eroare la execuție. \
                `--record-history` adaugă o linie în fișierul de istoric, ca rularea următoare să poată \
                compara abaterea.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Profil de date",
        summary: "O descriere per coloană: tip, goluri, valori distincte, distribuție.",
        keywords: ["profil", "statistici pe coloană", "null", "distincte"],
        blocks: [
            .paragraph("""
                Un profil **descrie**; nu judecă. Spune *»această coloană e 2 % goală«*; dacă 2 % e \
                acceptabil ține de setul de reguli de calitate.
                """),
            .table(
                headers: ["Măsură", "Cum se citește"],
                rows: [
                    ["Tip", "Dedus din datele înseși, nu din numele coloanei"],
                    ["Celule goale", "Numărul și proporția valorilor lipsă"],
                    ["Valori distincte", "1 înseamnă coloană constantă; egal cu numărul de rânduri înseamnă coloană-cheie"],
                    ["Min · max · medie", "Doar coloane numerice"],
                    ["Valorile cele mai frecvente", "Observați imediat un cod de eroare sau o valoare implicită suprafolosită"],
                ]
            ),
            .warning("""
                Numărarea valorilor distincte are un prag. Peste el, numărul afișat este o **limită \
                inferioară**, iar profilul **spune că e o estimare**, în loc s-o amestece cu numărători \
                exacte.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Bancul de curățare a datelor",
        summary: "Șapte normalizări, mereu previzualizate, mereu un singur pas de anulare, niciodată ghicind.",
        keywords: ["curățare", "normalizare", "date", "numere", "completare goluri"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Deschide bancul de curățare")]),
            .table(
                headers: ["Operație", "Ce face"],
                rows: [
                    ["Normalizează datele calendaristice", "Aduce fiecare formă de dată din coloană la una singură"],
                    ["Normalizează numerele", "Stabilește separatorul zecimal și pe cel de mii"],
                    ["Taie spațiile", "Le elimină la ambele capete; opțional comprimă și seriile interioare"],
                    ["Schimbă majusculele", "Uniformizează scrierea coloanei"],
                    ["Completează cu o valoare fixă", "Înlocuiește celulele goale cu o valoare scrisă de dumneavoastră"],
                    ["Completează de la vecin", "Ia valoarea din rândul de deasupra sau de dedesubt"],
                    ["Șterge rândurile cu celule goale", "Elimină rândurile cărora le lipsesc date"],
                ]
            ),
            .heading("Trei garanții ale întregului banc"),
            .bullets([
                "**Mereu previzualizat.** Un tabel înainte→după, cu numărul de celule care se vor schimba.",
                "**Un singur pas de anulare** pentru toată trecerea, chiar dacă atinge un milion de celule.",
                "**Un raport după aceea**: câte celule s-au schimbat și care n-au putut fi citite.",
            ]),
            .heading("Principiul: nu ghici niciodată"),
            .paragraph("""
                O celulă care nu poate fi citită cu certitudine este **marcată și lăsată în pace**. Luați \
                `03/04/2026` într-o coloană care amestecă ambele convenții — e 3 aprilie sau 4 martie? \
                GEditor vă întreabă ordinea zi/lună în loc să aleagă în locul dumneavoastră.
                """),
            .warning("""
                A normaliza greșit o coloană de date calendaristice e genul de stricăciune **aproape \
                imposibil de depistat**: numerele arată tot corect, sunt doar altă dată. De aceea acest \
                banc preferă să refuze decât să deducă.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Duplicate aproximative",
        summary: "Găsiți variantele scrise de mână ale aceluiași nume — și nu le îmbinați niciodată automat.",
        keywords: ["aproximativ", "duplicate", "îmbinare", "variante", "greșeli de tastare"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — trei feluri de a \
                scrie un client. Eliminarea obișnuită a duplicatelor nu le vede ca fiind același lucru.
                """),
            .steps([
                "Alegeți coloana de examinat și un prag de similaritate.",
                "GEditor grupează valorile apropiate în **grupuri** și arată forma de comparație.",
                "Pentru **fiecare grup** alegeți ce valoare se păstrează — sau săriți peste grup.",
                "Aplicați. Un singur pas de anulare.",
            ]),
            .warning("""
                Această unealtă **nu îmbină niciodată singură** și nu există buton »îmbină tot«. Două \
                șiruri asemănătoare în proporție de 92 % pot fi o greșeală de tastare sau două firme cu \
                adevărat diferite care se deosebesc printr-un cuvânt — o mașină nu poate decide.
                """),
            .paragraph("""
                A îmbina greșit două înregistrări este pierdere **tăcută** de date: nicio celulă nu se \
                golește, niciun rând nu devine roșu, două entități devin pur și simplu una, și nimeni nu \
                observă până când nu se reconciliază conturile.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Rețete de curățare",
        summary: "Înregistrați succesiunea ca fișier JSON și rulați-o pe datele lunii viitoare.",
        keywords: ["rețetă", "repetare", "automatizare", "lunar", "lot"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                După curățare, salvați pașii ca **rețetă**. Este un fișier JSON lizibil pe care îl puteți \
                ține lângă date, îl puteți trimite unui coleg și îl puteți pune într-un depozit, ca \
                schimbările să fie urmărite.
                """),
            .code(language: "json", caption: "sales-standard.json — pe scurt",
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
                Fiecare pas poate fi **dezactivat** (`enabled`), așa că o rețetă poate servi mai multe \
                feluri de fișiere aproape identice.
                """),
            .heading("Rulare din nou"),
            .bullets([
                "În aplicație: `CSV ▸ Rulează rețeta de curățare…`",
                "Din shell, pe un dosar întreg: vedeți pagina despre linia de comandă.",
            ]),
            .code(language: "bash", caption: "O rulare de probă înainte de a scrie ceva — niciun fișier nu e atins",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Implicit, rezultatul se scrie într-un fișier nou lângă original (`sales-clean.csv`). \
                Suprascrierea originalului trebuie cerută explicit cu `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Evaluarea calității datelor",
        summary: "Șase dimensiuni, un scor 0–100 și fiecare formulă tipărită ca să o puteți recalcula.",
        keywords: ["calitate", "scor", "dqr", "șase dimensiuni"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Diferă de profilul de date într-un punct fundamental: profilul **descrie**, scorul \
                **judecă după standardul pe care l-ați declarat** într-un fișier `.gquality.yaml`.
                """),
            .table(
                headers: ["Dimensiune", "Ce măsoară"],
                rows: [
                    ["Completitudine", "Proporția celulelor completate, după regulile `not_null`"],
                    ["Validitate", "Proporția regulilor de format, tip, interval și regex care trec"],
                    ["Unicitate", "Față de cheia declarată în `uniqueness_key`"],
                    ["Consecvență", "Reguli între coloane și între fișiere"],
                    ["Acuratețe (estimată)", "Valori extreme în coloanele numerice pe care le indicați"],
                    ["Actualitate", "Cât de vechi sunt datele față de pragul `freshness`"],
                ]
            ),
            .heading("Trei garanții despre scor"),
            .bullets([
                "**Formula e tipărită în rezultat** — o puteți recalcula manual.",
                "**Determinist**: aceleași date și aceleași reguli dau același scor. Doar *Actualitatea* depinde de moment, așa că `now` este un **parametru** și se consemnează în rezultat.",
                "**O dimensiune care nu poate fi evaluată rămâne goală cu un motiv**, nu primește niciodată 100 în tăcere.",
            ]),
            .warning("""
                Ultima garanție contează. Un tabel fără `uniqueness_key` declarat, căruia i se dă 100 la \
                »unicitate«, e un scor care minte — și minte în direcția măgulitoare, care e cea \
                periculoasă.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Sintaxa `.gquality.yaml`",
        summary: "Fiecare cheie a fișierului de reguli, cu un set complet care rulează.",
        keywords: ["gquality", "yaml", "reguli", "sintaxă", "standard de date"],
        blocks: [
            .paragraph("""
                Fișierul stă **lângă date**, nu în aplicație: un standard de date trebuie să poată fi \
                revizuit, iar revizuirea e tocmai ce fac oamenii cu standardele.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — set complet de reguli",
                  source: """
                    schemaVersion: 1

                    # Ponderile celor șase dimensiuni. O dimensiune lipsă cântărește 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Cheia care face un rând unic. Fără ea, dimensiunea "Unicitate"
                    # NU poate fi evaluată — iar totalul o va spune.
                    uniqueness_key: [ma_don]

                    # Coloane numerice examinate pentru valori extreme la "Acuratețe (estimată)".
                    accuracy_columns: [doanh_thu, so_luong]

                    # Dimensiunea "Actualitate".
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Avertizează când această rulare scade față de cea precedentă.
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
                        max_null_pct: 2          # se permit 2 % goluri
                      # Regulă între coloane: nu e nevoie de `col`
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Regulă între fișiere: valoarea trebuie să existe în alt fișier
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Tipurile de reguli"),
            .table(
                headers: ["Cheie", "Sens", "Dimensiune"],
                rows: [
                    ["`not_null: true`", "Celula trebuie completată; `max_null_pct` slăbește regula", "Completitudine"],
                    ["`unique: true`", "Nicio valoare repetată în coloană", "Unicitate"],
                    ["`dtype: int\\|float\\|date\\|text`", "Tip corect", "Validitate"],
                    ["`range: { min:, max: }`", "În interval numeric", "Validitate"],
                    ["`length: { min:, max: }`", "Lungimea șirului", "Validitate"],
                    ["`regex: \"…\"`", "Se potrivește cu o expresie regulată", "Validitate"],
                    ["`in_set: [ … ]`", "Una dintr-o listă dată", "Validitate"],
                    ["`date_format: \"…\"`", "Formă corectă de dată", "Validitate"],
                    ["`compare: { a:, op:, b: }`", "Compară două coloane; `op` este `<` `<=` `=` `>=` `>` `<>`", "Consecvență"],
                    ["`foreign_key: { file:, column: }`", "Valoarea trebuie să existe în alt fișier", "Consecvență"],
                    ["`severity: error\\|warn`", "Gravitatea regulii; implicit `error`", "—"],
                ]
            ),
            .warning("""
                Scrieți greșit o cheie de regulă și fișierul este **respins cu un mesaj**, în loc ca acea \
                regulă să fie sărită în tăcere. Sărirea tăcută înseamnă că sunteți convins că datele au \
                fost verificate cu o regulă care n-a rulat niciodată.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "O poartă de calitate în CI",
        summary: "Opriți datele care nu trec, chiar în conductă, folosind coduri de ieșire.",
        keywords: ["ci", "poartă", "fail-under", "cod de ieșire", "automatizare", "istoric", "abatere"],
        blocks: [
            .code(language: "bash", caption: "Evaluează și întoarce un cod de ieșire",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Opțiune", "Sens"],
                rows: [
                    ["`--quality <fișier.yaml>`", "Setul de reguli după care se evaluează"],
                    ["`--fail-under <0…100>`", "Sub acest scor înseamnă PICAT"],
                    ["`--json <fișier\\|->`", "Rezultat citibil de mașină; `-` scrie la ieșirea standard"],
                    ["`--record-history`", "Adaugă o linie în `sales-standard.history.jsonl`"],
                    ["`--now <AAAA-LL-ZZ>`", "Fixează data de referință pentru *Actualitate*"],
                    ["`--recipe <fișier.json>`", "Curăță **în memorie** înainte de evaluare, fără a scrie un fișier"],
                ]
            ),
            .table(
                headers: ["Cod de ieșire", "Sens"],
                rows: [["`0`", "Trecut"], ["`1`", "Picat"], ["`2`", "Eroare la execuție"]]
            ),
            .heading("De ce CI ar trebui să dea `--now`"),
            .paragraph("""
                Fără el, *Actualitatea* compară datele cu momentul rulării — așa că același fișier pierde \
                puncte pe măsură ce trec zilele, iar într-o dimineață conducta devine roșie fără ca nimeni \
                să fi schimbat ceva.
                """),
            .heading("Urmărirea abaterii"),
            .paragraph("""
                Cu `--record-history`, fiecare rulare adaugă o linie într-un fișier de istoric JSONL. Data \
                viitoare, pragurile din blocul `drift:` compară cu ultima rulare și avertizează când \
                scăderea e prea mare.
                """),
            .note("""
                Fiecare prag de abatere este **dezactivat implicit**, în afară de `warn_on_new_failure`. \
                Un avertisment activat din start cu un număr ales de aplicație s-ar declanșa la a doua \
                rulare a fiecăruia — iar ce strigă lupul în prima zi este ignorat în a treia.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Explorarea datelor

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Explorarea datelor — tot fluxul",
        summary: "Anomalii, corelație, grupare, prognoze, reguli de asociere — și cum se citesc.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Fluxul de explorare, cap la cap",
        summary: "Șase unelte, ordinea în care se folosesc, și o regulă: fără măsurare, nicio concluzie.",
        keywords: ["explorare", "analiză", "flux", "statistică"],
        blocks: [
            .warning("""
                **Curățați întâi, explorați apoi.** O coloană de dată nenormalizată dă prognoze greșite; o \
                coloană numerică ce amestecă separatori europeni de mii produce valori extreme fantomă. \
                Fiecare unealtă de mai jos presupune că tabelul e curat.
                """),
            .heading("Ordinea în care mergeți"),
            .steps([
                "**Găsiți anomalii** — răspunde la *»e vreun rând ciudat«*. Cel mai ieftin și adesea util imediat.",
                "**Matricea de corelație** — răspunde la *»ce coloană se mișcă odată cu care«*. Ea îndrumă tot ce urmează.",
                "**Gruparea** — răspunde la *»câte grupuri naturale sunt aici«*.",
                "**Prognoza** — doar cu o coloană de timp și cel puțin **două cicluri complete**.",
                "**Reguli de asociere** — doar pentru date în formă de coș: o tranzacție pe rând, sau două coloane cu identificatorul tranzacției și articolul.",
                "**Explorare pe grupuri** — rulează primele trei din nou, **independent în fiecare grup**. Acest pas răsucește frecvent concluzia trasă din tabelul unificat.",
            ]),
            .heading("Trei reguli pentru toată familia"),
            .bullets([
                "**Fiecare rezultat poartă un bloc »Metodă«**: algoritm, parametri, sămânță, formulă. Nu poate fi dezactivat — un tabel de trei numere care nu spune de unde vin nu poate fi folosit pentru o decizie.",
                "**Fără măsurare, nicio concluzie.** Eșantion prea mic, varianță zero, matrice singulară — GEditor refuză și spune de ce, în loc să întoarcă un număr care doar pare corect.",
                "**Rezultate deterministe.** Aceleași date dau același rezultat; unde e nevoie de aleatoriu, sămânța se consemnează în ieșire.",
            ]),
            .heading("De la rezultat înapoi la date"),
            .paragraph("""
                Fiecare panou **marchează înapoi în datele-sursă**: faceți clic pe un rând anormal, pe o \
                celulă de corelație sau pe o regulă de asociere, iar liniile relevante se marchează în \
                tabel. Așa treceți de la *»ceva e ciudat«* la *»ciudat exact pe aceste rânduri«*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Găsirea rândurilor anormale",
        summary: "Patru măsuri, trei niveluri de gravitate și o explicație a motivului pentru care un rând e ciudat.",
        keywords: ["valoare extremă", "anomalie", "scor z", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Măsură", "Folosiți când"],
                rows: [
                    ["scor z", "Coloana are aproximativ distribuție normală"],
                    ["IQR", "Coloana e asimetrică, cu o coadă lungă — alegerea implicită sigură"],
                    ["MAD", "Coloana are deja multe valori extreme și trebuie o măsură robustă"],
                    ["Mahalanobis", "**Mai multe coloane deodată** — prinde rândurile ciudate prin combinație, nu într-o singură coloană"],
                ]
            ),
            .paragraph("""
                Rezultatele se colorează pe **trei niveluri de gravitate**, nu cu o singură culoare plată \
                — altfel un rând ușor neobișnuit nu se deosebește de unul sălbatic de neobișnuit.
                """),
            .heading("Explicarea motivului"),
            .paragraph("""
                Pentru măsura pe mai multe coloane, GEditor descompune contribuția fiecărei coloane și \
                produce o frază precum *«anormal mai ales prin combinația venit (50 %) × cantitate (50 \
                %)»*.
                """),
            .note("""
                Acel procent este *din partea explicabilă*, nu *din distanță*. Blocul Metodă o spune chiar \
                sub tabel.
                """),
            .warning("""
                O coloană al cărei IQR sau MAD e zero face măsura **să refuze să ruleze**, în loc să \
                împartă la ceva infim și să dea un scor uriaș. Pentru cazul cu mai multe coloane, dacă \
                matricea de covarianță e singulară, **GEditor spune ce coloană să eliminați**, în loc să \
                folosească o pseudoinversă ca »să meargă«.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Matricea de corelație",
        summary: "Pearson și Spearman pentru fiecare pereche, cu grafic de dispersie la clic.",
        keywords: ["corelație", "pearson", "spearman", "hartă termică", "dispersie"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Coeficient", "Ce măsoară"],
                rows: [
                    ["Pearson", "O relație **liniară**"],
                    ["Spearman", "**Orice relație monotonă**, inclusiv curbată — calculată pe ranguri"],
                ]
            ),
            .paragraph("""
                Faceți clic pe o celulă din harta termică ca să vedeți graficul de dispersie al acelei \
                perechi, cu dreapta de regresie și R².
                """),
            .heading("Patru detalii care schimbă lectura"),
            .bullets([
                "**Egalitățile folosesc ranguri medii**, așa că resortarea tabelului nu schimbă coeficientul Spearman.",
                "**Celulele goale se tratează pereche cu pereche**, iar `n`-ul fiecărei celule e chiar în tabel — `0,93` pe 6 rânduri nu înseamnă ce înseamnă `0,93` pe 6.000 de rânduri.",
                "**O coloană constantă întoarce gol**, nu 0. Zero înseamnă *măsurat, nicio relație găsită*.",
                "**Scara de culori e albastru↔portocaliu**, nu roșu-verde: 8 % dintre bărbați văd o scară roșu-verde ca o singură masă cenușie, ceea ce face ca `+0,9` și `−0,9` să arate la fel.",
            ]),
            .warning("""
                **Corelația nu implică o cauză.** Această frază se desenează **chiar în interiorul \
                graficului**, ca să călătorească odată cu imaginea când o exportați.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Grupare",
        summary: "k-means și DBSCAN, două feluri de a alege k — și un avertisment despre scalare.",
        keywords: ["grup", "kmeans", "dbscan", "grupuri", "siluetă", "cot"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritm", "Folosiți când"],
                rows: [
                    ["k-means", "Cunoașteți (sau vreți să încercați) numărul de grupuri; grupurile au formă de pată"],
                    ["DBSCAN", "Nu cunoașteți numărul; grupurile au forme arbitrare; vreți zgomotul separat"],
                ]
            ),
            .heading("Scalarea e activată implicit — și de ce"),
            .paragraph("""
                O coloană `venit` (în milioane) lângă o coloană `cantitate` (în bucăți): distanța dintre \
                două rânduri e hotărâtă aproape în întregime de cea mai mare. Asta nu e »ușor \
                suboptimal« — este **a răspunde la altă întrebare**. Scalarea în vigoare se consemnează în \
                rezultat.
                """),
            .heading("Alegerea numărului de grupuri"),
            .bullets([
                "**Siluetă** — cu cât scorul e mai mare, cu atât grupurile sunt mai bine separate. Pe un tabel mare **eșantionează** (uniform, nu primele 2.000 de rânduri), iar rezultatul se declară o estimare.",
                "**Cot** — desenează suma pătratelor din interiorul grupurilor față de k. E un **fel de a citi un grafic**, nu o optimizare: acea mărime scade mereu când k crește, deci nu există statistic un »k optim«.",
            ]),
            .note("""
                Pentru DBSCAN, graficul **k-distanță** ajută la alegerea razei: genunchiul curbei e de \
                obicei o valoare de pornire rezonabilă.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Prognoza seriilor de timp",
        summary: "Descompunere în tendință și sezonalitate, Holt-Winters, și o linie de bază care rulează mereu alături.",
        keywords: ["prognoză", "serie de timp", "sezonalitate", "holt-winters", "tendință"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Alegeți o coloană de timp și una de valori. GEditor descompune seria în **tendință · \
                sezonalitate · reziduu**, apoi prognozează cu Holt-Winters (aditiv sau multiplicativ), cu \
                intervale de 80 % și 95 %.
                """),
            .heading("Linia de bază rulează mereu și spune deschis cine a câștigat"),
            .paragraph("""
                Alături de model, GEditor rulează două metode naive: *ia perioada precedentă* și *ia \
                aceeași perioadă din sezonul trecut*. Dacă modelul **pierde** în fața unei linii de bază, \
                acea frază apare pe **primul rând, în altă culoare** — nu sub un tabel de numere.
                """),
            .paragraph("""
                Motivul: uneltele de prognoză tind să prezinte modelul ca pe un fapt, iar utilizatorul nu \
                are cum să afle că »ia pur și simplu cifra de luna trecută« ar fi fost mai exact.
                """),
            .heading("Trei locuri unde GEditor refuză sau se declară"),
            .bullets([
                "**Fără două cicluri complete, revine la metoda naivă.** A potrivi sezonalitatea pe zgomotul unui singur ciclu și a o repeta în viitor dă o prognoză foarte convingătoare și complet inventată.",
                "**Un MAPE care întâlnește un zero o spune**, iar dacă peste 25 % din perioade sunt zero, reține indicatorul — a le sări în tăcere dă un număr calculat pe un subansamblu sistematic distorsionat.",
                "**Intervalul de încredere se declară aproximativ** și spune că se lărgește prea încet la orizonturi lungi.",
            ]),
            .note("""
                Perioada sezonieră se detectează pe **prima diferență**, nu pe seria brută: o tendință face \
                fiecare decalaj puternic corelat și îneacă vârful sezonier.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Reguli de asociere",
        summary: "Cine cumpără A, cumpără des B — și de ce tabelul se sortează după lift, nu după încredere.",
        keywords: ["apriori", "reguli de asociere", "coș de cumpărături", "lift", "suport"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Se acceptă două forme de date:"),
            .bullets([
                "**Un coș pe rând** — o coloană care conține o listă de articole.",
                "**Două coloane** — identificatorul tranzacției și articolul, un articol pe rând.",
            ]),
            .table(
                headers: ["Indicator", "Sens"],
                rows: [
                    ["suport", "Proporția coșurilor care conțin ambele părți"],
                    ["încredere", "Din coșurile cu partea stângă, ce proporție are partea dreaptă"],
                    ["**lift**", "Încrederea împărțită la rata de bază a părții drepte"],
                    ["pârghie", "Diferența față de ce ar prezice independența"],
                ]
            ),
            .heading("Sortat după lift, nu după încredere"),
            .paragraph("""
                Dacă partea dreaptă apare oricum în 95 % dintre coșuri, atunci **fiecare** regulă care duce \
                la ea are în jur de 95 % încredere — fără să spună nimic. Sortarea după încredere pune \
                exact regulile cele mai lipsite de sens în frunte.
                """),
            .warning("""
                `lift < 1` este **semnalat chiar pe rând**: 80 % încredere către ceva cu rată de bază de 95 \
                % înseamnă o relație **inversă** — un număr corect care duce la o concluzie greșită.
                """),
            .bullets([
                "A cumpăra două cutii de lapte rămâne **o singură** tranzacție care conține lapte: duplicatele din interiorul unui coș se elimină, altfel suportul se umflă odată cu cantitatea.",
                "Un prag de suport prea mic face ca mulțimea de candidați să explodeze combinatoriu; la atingerea plafonului, **GEditor se oprește și declară că tabelul e incomplet**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Explorare pe grupuri",
        summary: "Rulați analiza din nou, independent pe grupuri — pasul care răstoarnă cel mai des o concluzie.",
        keywords: ["grupare", "pe grupuri", "simpson", "filiale", "comparare grupuri"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Alegeți o coloană de text drept cheie de grupare. Fiecare grup primește anomalii, prognoză \
                și corelație rulate **complet independent**, apoi sunt clasate după criteriul ales de \
                dumneavoastră.
                """),
            .heading("De ce grupurile trebuie separate, nu unificate"),
            .paragraph("""
                Două filiale, una în jur de 10 și alta în jur de 100. Un gard pentru valori extreme \
                calculat pe tabelul **unificat** aterizează pe la ±135 — și eșuează în **ambele direcții**:
                """),
            .bullets([
                "**Fals negative**: o valoare de 20, vădit anormală pentru filiala mică, stă comod în interiorul gardului comun. Cu cât sunt mai multe grupuri, cu atât devine mai orb.",
                "**Fals pozitive**: unui grup larg împrăștiat gardul comun îi retează coada normală, și un șir de rânduri absolut obișnuite ajung semnalate.",
            ]),
            .heading("Coloana »divergență de corelație« prinde paradoxul lui Simpson"),
            .paragraph("""
                Trei grupuri în care cele două coloane ale **fiecărui** grup corelează la `−1`, dar \
                unificate corelează la `> 0,9`. Cine citește doar tabelul unificat trage exact concluzia \
                **opusă**. Această coloană arată tocmai spre asemenea cazuri.
                """),
            .note("""
                Panoul oferă drept chei de grupare doar **coloane de text** și se oprește la 1.000 de \
                grupuri cu un avertisment — ca să nu se aleagă o coloană cu identificatori de comandă și să \
                se facă din fiecare rând un grup propriu.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Explorarea textului",
        summary: "n-grame și TF-IDF pe o coloană de text — găsirea expresiilor caracteristice.",
        keywords: ["explorarea textului", "n-gramă", "tf-idf", "cuvinte-cheie", "expresii"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Rulează pe o coloană de text — descrieri de produse, feedback de la clienți, câmpuri de \
                notițe.
                """),
            .bullets([
                "**n-grame** — cele mai frecvente expresii de 1, 2 și 3 cuvinte.",
                "**TF-IDF** — cuvinte **caracteristice** fiecărui grup de documente, adică frecvente aici și rare în altă parte.",
            ]),
            .paragraph("""
                Diferența: n-gramele vă spun *»ce menționează clienții mereu«*, iar TF-IDF vă spune *»prin \
                ce se deosebește acest grup de celelalte«*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
